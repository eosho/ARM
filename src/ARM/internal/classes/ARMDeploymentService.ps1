class ARMDeploymentService {
  [string] $ArmResourceGroupDeploymentUri
  [string] $ArmSubscriptionDeploymentUri
  [string] $ArmResourceGroupValidationUri
  [string] $ArmSubscriptionValidationUri
  [string] $ArmResourceGroupWhatIfValidationUri
  [string] $ArmSubscriptionWhatIfValidationUri

  [bool] $IsSubscriptionDeployment = $false

  # Executes ARM operation for deployment
  [PSCustomObject] ExecuteDeployment([PSObject] $ScopeObject, [object] $DeploymentTemplate, [object] $DeploymentParameters, [string] $Location) {
    try {
      # call arm deployment
      $deployment = $this.InvokeARMOperation(
        $ScopeObject,
        $DeploymentTemplate,
        $DeploymentParameters,
        $Location,
        "deploy"
      )

      return $deployment
    } catch {
      Write-PipelineLogger -LogType "error" -Message "Error: $($_.Exception.Message)"
      throw $_.Exception.Message
    }
  }

  # Executes ARM operation for validation
  [PSCustomObject] ExecuteValidation([PSObject] $ScopeObject, [object] $DeploymentTemplate, [object] $DeploymentParameters, [string] $Location) {
    try {
      # call arm validation
      $validation = $this.InvokeARMOperation(
        $ScopeObject,
        $DeploymentTemplate,
        $DeploymentParameters,
        $Location,
        "validate"
      )

      # Did the validation succeed?
      if ($validation.error.code -eq "InvalidTemplateDeployment") {
        # Throw an exception and pass the exception message from the ARM validation
        Throw ("Validation failed with the error below: {0}" -f (ConvertTo-Json $validation -Depth 50))
      } else {
        Write-PipelineLogger -LogType "success" -Message "Deployment validation passed"
      }

      return $validation
    } catch {
      throw $_.Exception.Message
    }
  }

  # Executes ARM operation for validation
  [PSCustomObject] ExecuteValidationWhatIf([PSObject] $ScopeObject, [object] $DeploymentTemplate, [object] $DeploymentParameters, [string] $Location) {
    $resultsError = $null
    $results = $null
    $bicepTemplate = $null

    if ($DeploymentTemplate.metadata._generator.name -eq 'bicep') {
      # Detect bicep templates
      $bicepTemplate = $true
    }

    # try {
    #   # call arm whatif validation
    #   if ($ScopeObject.Type -eq "subscription") {
    #     $parameters = @{
    #       'TemplateObject'              = $DeploymentTemplate
    #       'Location'                    = $Location
    #       'TemplateParameterObject'     = $deploymentParameters
    #       'SkipTemplateParameterPrompt' = $true
    #     }

    #     $results = Get-AzDeploymentWhatIfResult @parameters -ErrorAction Continue -ErrorVariable resultsError
    #     if ($resultsError) {
    #       if ($resultsError.exception.InnerException.Message -match 'https://aka.ms/resource-manager-parameter-files' -and $true -eq $bicepTemplate) {
    #         Write-PipelineLogger -LogType "warning" -Message "Validation failed with the error below: $($resultsError.exception.InnerException.Message)"
    #       } else {
    #         Write-PipelineLogger -LogType 'warning' -Message "ExecuteValidationWhatIf failed. Details: $($resultsError.exception.InnerException.Message)"
    #       }
    #     } elseif ($results.Error) {
    #       Write-PipelineLogger -LogType "warning" -Message "ExecuteValidationWhatIf.TemplateError"
    #     } else {
    #       Write-PipelineLogger -LogType "success" -Message "$($results | Out-String)"
    #     }
    #   } else {
    #     $parameters = @{
    #       'TemplateObject'              = $DeploymentTemplate
    #       'ResourceGroupName '          = $ScopeObject.Name
    #       'TemplateParameterObject'     = $deploymentParameters
    #       'SkipTemplateParameterPrompt' = $true
    #     }

    #     $results = Get-AzResourceGroupDeploymentWhatIfResult @parameters -ErrorAction Continue -ErrorVariable resultsError
    #     if ($resultsError) {
    #       if ($resultsError.exception.InnerException.Message -match 'https://aka.ms/resource-manager-parameter-files' -and $true -eq $bicepTemplate) {
    #         Write-PipelineLogger -LogType "warning" -Message "Validation failed with the error below: $($resultsError.exception.InnerException.Message)"
    #       } else {
    #         Write-PipelineLogger -LogType 'warning' -Message "ExecuteValidationWhatIf failed. Details: $($resultsError.exception.InnerException.Message)"
    #       }
    #     } elseif ($results.Error) {
    #       Write-PipelineLogger -LogType "warning" -Message "ExecuteValidationWhatIf.TemplateError"
    #     } else {
    #       Write-PipelineLogger -LogType "success" -Message "$($results | Out-String)"
    #     }
    #   }
    #   return $results
    # } catch {
    #   throw $_.Exception.Message
    # }

    # via rest api
    try {
      # call arm validation
      $whatIfValidation = $this.InvokeARMOperation(
        $ScopeObject,
        $DeploymentTemplate,
        $DeploymentParameters,
        $Location,
        "validateWhatIf"
      )

      # Did the validation succeed?
      if ($whatIfValidation.error.code -eq "InvalidTemplateDeployment") {
        # Throw an exception and pass the exception message from the ARM validation
        Throw ("WhatIf Validation failed with the error below: {0}" -f (ConvertTo-Json $whatIfValidation -Depth 50))
      } else {
        Write-PipelineLogger -LogType "success" -Message "WhatIf Deployment validation passed"
      }

      return $whatIfValidation
    } catch {
      throw $_.Exception.Message
    }
  }


  # Generate a new guid for deployment name
  hidden [string] GenerateUniqueDeploymentName() {
    return [Guid]::NewGuid()
  }

  # Invoke ARM operation for deployment
  [object] InvokeARMOperation([PSObject] $ScopeObject, [object] $DeploymentTemplate, [object] $DeploymentParameters, [string] $Location, [string] $Operation) {

    $deploymentDetails = $null

    # Check for invariant
    if ([string]::IsNullOrEmpty($DeploymentTemplate)) {
      Write-PipelineLogger -LogType "error" -Message "DeploymentTemplate cannot be null or empty"
      throw "Deployment template contents cannot be empty"
    } else {
      # Construct the uri for the desired operation
      $uri = $this.ConstructUri(
        $ScopeObject,
        $Operation
      )

      # Prepare the request body for the REST API
      $requestBody = $this.PrepareRequestBodyForArm(
        $ScopeObject,
        $DeploymentTemplate,
        $DeploymentParameters,
        $Location
      )

      try {
        Write-PipelineLogger -LogType "debug" -Message "Invoking ARM REST API with Uri: [ $uri ]"

        if ($requestBody) {
          Write-PipelineLogger -LogType "debug" -Message "Request Body generated"
          #Write-PipelineLogger -LogType "debug" -Message "Request Body: $($requestBody | Out-String)"
        } else {
          Write-PipelineLogger -LogType "error" -Message "Request Body is empty"
        }

        # Switch REST Verb based on operation type
        if ($Operation -eq "deploy") {
          $method = "PUT"
        } elseif ($Operation -eq "validate") {
          $method = "POST"
        } elseif ($Operation -eq "validateWhatIf") {
          $method = "POST"
        } else {
          throw "Invalid operation type"
        }

        # Call REST API to start the deployment
        try {
          $deployment = (Invoke-ARMRestMethod -Method $method -Uri $uri -Body $requestBody).InvokeResult
        } catch {
          throw $_.Exception.Message
        }

        # wait for arm deployment
        if ($null -ne $deployment.Id -and $operation -eq "deploy") {
          Write-PipelineLogger -LogType "info" -Message "Running a deployment..."
          Write-PipelineLogger -LogType "debug" -Message "Provisioning State: [ $($deployment.properties.provisioningState) ]"

          $deploymentDetails = $this.WaitForDeploymentToComplete(
            $deployment,
            $this.isSubscriptionDeployment
          )

          if ($deploymentDetails.ProvisioningState -ne "Succeeded") {
            Write-PipelineLogger -LogType "error" -Message "Deployment failed" -NoFailOnError
          } else {
            Write-PipelineLogger -LogType "success" -Message "Deployment completed successfully"
          }
        }
        return $deploymentDetails

      } catch {
        # For deploy operation, the error is due malformed or incorrect inputs
        if ($operation -eq "deploy") {
          Write-PipelineLogger -LogType "error" -Message "An Exception Occurred While Invoking the Deployment. Please see the error below: $($_.Exception.Message)"
          throw $_.Exception.Message
        }
        # For validate operation, the error is due to validation failure
        else {
          return $_
        }
      }
    }
  }

  # Construct the request body for ARM REST API
  hidden [string] PrepareRequestBodyForArm([PSObject] $ScopeObject, [object] $DeploymentTemplate, [object] $DeploymentParameters, [string] $Location) {

    $templateJson = $null
    $parametersJson = $null

    # Let's analyze the deployment parameters if there's a schema, remove it
    if ($deploymentParameters) {
      $parametersJson = ConvertTo-Json $deploymentParameters.parameters -Compress -Depth 50
    }

    if ($DeploymentTemplate) {
      $templateJson = ConvertTo-Json $DeploymentTemplate -Compress -Depth 99
    }

    # Subscription level deployment
    if ($ScopeObject.Type -eq "subscriptions") {

      $this.isSubscriptionDeployment = $true

      # prepare the REST Call's body content format
      $requestBody = "{
        'location': '$location',
        'properties': {
            'mode': 'Incremental',
            'template': $templateJson,
            'parameters': $parametersJson
        }
      }"
    } else {
      # prepare the REST Call's body content format
      $requestBody = "{
        'properties': {
            'mode': 'Incremental',
            'template': $templateJson,
            'parameters': $parametersJson
        }
      }"
    }

    return $requestBody
  }

  # Construct the uri for the desired operation
  hidden [string] ConstructUri([PSObject] $ScopeObject, [string] $Operation) {

    $uniqueDeploymentName = $this.GenerateUniqueDeploymentName()

    Write-PipelineLogger -LogType "debug" -Message "Operation scope: [ $($ScopeObject.Type) ] Operation: [ $operation ]"

    # set the URL's from Discovery REST API call
    $this.SetAzureManagementUrls()

    # Subscription level deployment or resource group level deployment - lets construct the uri
    if ($ScopeObject.Type -eq "subscription") {
      Write-PipelineLogger -LogType "info" -Message "Detected a subscription level deployment"

      $this.isSubscriptionDeployment = $true

      if ($operation -eq "deploy") {
        $uri = $this.ArmSubscriptionDeploymentUri
      } elseif ($operation -eq "validate") {
        $uri = $this.ArmSubscriptionValidationUri
      } elseif ($operation -eq "validateWhatIf") {
        $uri = $this.ArmSubscriptionWhatIfValidationUri
      } else {
        throw "Invalid operation type"
      }

      # construct the uri using the format for armSubscriptionDeploymentUri
      $uri = $uri -f $ScopeObject.Name, $uniqueDeploymentName
    } else {
      Write-PipelineLogger -LogType "info" -Message "Detected a resourceGroup level deployment"

      if ($Operation -eq "deploy") {
        $uri = $this.ArmResourceGroupDeploymentUri
      } elseif ($operation -eq "validate") {
        $uri = $this.ArmResourceGroupValidationUri
      } elseif ($operation -eq "validateWhatIf") {
        $uri = $this.ArmResourceGroupWhatIfValidationUri
      } else {
        throw "Invalid operation type"
      }

      # construct the uri using the format for armResourceGroupDeploymentUri
      $uri = $uri -f $ScopeObject.SubscriptionId, $ScopeObject.Name, $uniqueDeploymentName

      if ($null -eq $uri) {
        Write-PipelineLogger -LogType "error" -Message "Failed to construct the uri"
      }
    }
    return $uri
  }

  # Wait for the deployment to complete
  hidden [object] WaitForDeploymentToComplete([object] $Deployment, [bool] $IsSubscriptionDeployment) {

    $currentDeployment = $null
    $deploymentDetails = $null

    # loop until the deployment succeeds or fails
    $wait = 10
    $loop = 0
    $phase = 1

    do {
      $loop++

      Write-PipelineLogger -LogType "info" -Message "Checking deployment status - Loop: [ $loop ]"

      # Increment the phase number after 10 loops
      if ($loop % 10 -eq 0) {
        Write-PipelineLogger -LogType "info" -Message "Wait phase: $phase, complete"
        $phase += 1

        # let's increase the wait time
        $wait = ($wait * 2)

        Write-PipelineLogger -LogType "info" -Message "Moving to next wait phase: $phase"
        Write-PipelineLogger -LogType "info" -Message "New wait time: $wait seconds"
      }

      Write-PipelineLogger -LogType "debug" -Message "Waiting for deployment: [ $($deployment.Name) ] to complete. Will check in $wait seconds."
      Start-Sleep -s $wait

      # Get-AzResourceGroupDeployment will only return minimal details about the deployment - This includes the ProvisioningState and DeploymentId
      if ($isSubscriptionDeployment) {
        $currentDeployment = Get-AzDeployment -Id $deployment.Id
      } else {
        $currentDeployment = Get-AzResourceGroupDeployment -Id $deployment.Id
      }

      Write-PipelineLogger -LogType "debug" -Message "Provisioning State: [ $($currentDeployment.ProvisioningState) ]"
    }
    while (@("Running", "Accepted") -match $currentDeployment.ProvisioningState)

    if ((($currentDeployment.ProvisioningState -eq "Failed") -or ($currentDeployment.ProvisioningState -eq "Canceled") -or ($currentDeployment.ProvisioningState -eq "Conflict")) -and $isSubscriptionDeployment -eq $false) {

      # If the deployment fails, get the deployment details via Get-AzResourceGroupDeploymentOperation or Get-AzDeploymentOperation
      $deploymentDetails = Get-AzResourceGroupDeploymentOperation -ResourceGroupName $currentDeployment.ResourceGroupName -DeploymentName $currentDeployment.DeploymentName | Where-Object { $_.ProvisioningState -eq "Failed" }
      Write-PipelineLogger -LogType "error" -Message "Deployment: [ $($currentDeployment.DeploymentName) ] has failed. Provisioning State: $($deploymentDetails.ProvisioningState)" -NoFailOnError
      Write-PipelineLogger -LogType "error" -Message "Deployment: [ $($currentDeployment.DeploymentName) ] has failed. Status Code: $($deploymentDetails.StatusCode)" -NoFailOnError
      Write-PipelineLogger -LogType "error" -Message "Deployment: [ $($currentDeployment.DeploymentName) ] has failed. Details from resource group deployment: $($deploymentDetails.StatusMessage)" -NoFailOnError
    } elseif ((($currentDeployment.ProvisioningState -eq "Failed") -or ($currentDeployment.ProvisioningState -eq "Canceled") -or ($currentDeployment.ProvisioningState -eq "Conflict")) -and $isSubscriptionDeployment -eq $true) {
      $deploymentDetails = Get-AzDeploymentOperation -DeploymentName $currentDeployment.DeploymentName | Where-Object { $_.ProvisioningState -eq "Failed" }
      Write-PipelineLogger -LogType "error" -Message "Deployment: [ $($currentDeployment.DeploymentName) ] has failed. Provisioning State: $($deploymentDetails.ProvisioningState)" -NoFailOnError
      Write-PipelineLogger -LogType "error" -Message "Deployment: [ $($currentDeployment.DeploymentName) ] has failed. Status Code: $($deploymentDetails.StatusCode)" -NoFailOnError
      Write-PipelineLogger -LogType "error" -Message "Deployment: [ $($currentDeployment.DeploymentName) ] has failed. Details from subscription deployment: $($deploymentDetails.StatusMessage)" -NoFailOnError
    } elseif ($currentDeployment.ProvisioningState -eq "Succeeded") {
      Write-PipelineLogger -LogType "success" -Message "Deployment: [ $($currentDeployment.DeploymentName) ] has completed. Provisioning State: [ $($currentDeployment.ProvisioningState) ]"
      $deploymentDetails = $currentDeployment
    } else {
      Write-PipelineLogger -LogType "error" -Message "Deployment: [ $($currentDeployment.DeploymentName) ] has an unknown error" -NoFailOnError
    }

    return $deploymentDetails
  }

  # Set the subscription context
  [void] SetSubscriptionContext([PSObject] $ScopeObject) {
    try {
      Write-PipelineLogger -LogType "info" -Message "Setting subscription context: Subscription - [ $($ScopeObject.SubscriptionId) ]"
      $null = Set-AzContext $ScopeObject.SubscriptionId -Scope Process -ErrorAction Stop
    } catch {
      Write-PipelineLogger -LogType "error" -Message "An error ocurred while running SetSubscriptionContext. Details $($_.Exception.Message)"
    }
  }

  # Get an existing resource group
  [object] GetResourceGroup([PSObject] $ScopeObject) {
    try {
      $resourceId = $ScopeObject.Scope
      return Get-AzResourceGroup -Id $resourceId -ErrorAction SilentlyContinue
    } catch {
      Write-PipelineLogger -LogType "error" -Message "An error ocurred while running GetResourceGroup. Details: $($_.Exception.Message)"
      throw $_
    }
  }

  # Remove an existing resource group
  [void] RemoveResourceGroup([PSObject] $ScopeObject) {

    try {
      $id = $ScopeObject.Scope
      $resourceGroup = $this.GetResourceGroup($ScopeObject)
      if ($null -ne $resourceGroup) {
        Remove-AzResourceGroup -Id $id -Force -ErrorAction 'SilentlyContinue' -AsJob
      }
    } catch {
      Write-PipelineLogger -LogType "error" -Message "An error ocurred while running RemoveResourceGroup. Details: $($_.Exception.Message)"
      throw $_
    }
  }

  # Delete resources in a resource group
  [void] RemoveResources([PSObject[]] $ResourceToRemove) {

    $ResourceToRemove | ForEach-Object { Write-PipelineLogger -LogType "info" -Message "Removing resource: $($_.ResourceId)" }
    try {
      foreach ($resource in $ResourceToRemove) {
        Remove-AzResource -Id $resource.ResourceId -Force -ErrorAction 'SilentlyContinue'
      }
    } catch {
      Write-PipelineLogger -LogType "error" -Message "An error ocurred while running RemoveResources. Details: $($_.Exception.Message)"
      throw $_
    }
  }

  # If there is any resource lock on the existing resource group, we need it cleaned up
  [void] RemoveResourceGroupLock([PSObject] $ScopeObject) {

    try {
      $resourceId = $ScopeObject.Scope
      $allLocks = Get-AzResourceLock -Scope $resourceId -ErrorAction SilentlyContinue | Where-Object "ProvisioningState" -ne "Deleting"

      if ($null -ne $allLocks) {
        $allLocks | ForEach-Object {
          Remove-AzResourceLock -LockId $_.ResourceId -Force -ErrorAction 'SilentlyContinue'
        }
      }
    } catch {
      Write-PipelineLogger -LogType "error" -Message "An error ocurred while running RemoveResourceGroupLock. Details: $($_.Exception.Message)"
      throw $_
    }
  }

  # Set azure management urls
  hidden [void] SetAzureManagementUrls() {
    Write-PipelineLogger -LogType "debug" -Message "Generating deployment Url"
    # deployment urls
    $this.ArmResourceGroupDeploymentUri = "https://management.azure.com/subscriptions/{0}/resourcegroups/{1}/providers/Microsoft.Resources/deployments/{2}?api-version=2021-04-01"
    $this.ArmSubscriptionDeploymentUri = "https://management.azure.com/subscriptions/{0}/providers/Microsoft.Resources/deployments/{1}?api-version=2021-04-01"

    # validation urls
    $this.ArmResourceGroupValidationUri = "https://management.azure.com/subscriptions/{0}/resourcegroups/{1}/providers/Microsoft.Resources/deployments/{2}/validate?api-version=2021-04-01"
    $this.ArmSubscriptionValidationUri = "https://management.azure.com/subscriptions/{0}/providers/Microsoft.Resources/deployments/{1}/validate?api-version=2021-04-01"

    # whatif validation urls
    $this.ArmResourceGroupWhatIfValidationUri = "https://management.azure.com/subscriptions/{0}/resourcegroups/{1}/providers/Microsoft.Resources/deployments/{2}/whatIf?api-version=2021-04-01"
    $this.ArmSubscriptionWhatIfValidationUri = "https://management.azure.com/subscriptions/{0}/providers/Microsoft.Resources/deployments/{1}/whatIf?api-version=2021-04-01"
  }
}
