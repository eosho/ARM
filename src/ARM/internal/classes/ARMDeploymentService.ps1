class ARMDeploymentService {
  [string] $ArmResourceGroupDeploymentUri
  [string] $ArmSubscriptionDeploymentUri
  [string] $ArmResourceGroupValidationUri
  [string] $ArmSubscriptionValidationUri
  [string] $ArmResourceGroupWhatIfValidationUri
  [string] $ArmSubscriptionWhatIfValidationUri
  [string] $ArmResourceGroupDeploymentOperationUri
  [string] $ArmSubscriptionDeploymentOperationUri 

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

  # Executes ARM operation for WhatIf validation
  [PSCustomObject] ExecuteValidationWhatIf([PSObject] $ScopeObject, [object] $DeploymentTemplate, [object] $DeploymentParameters, [string] $Location) {
    try {
      # call arm whatIf validation
      $whatIfValidation = $this.InvokeARMOperation(
        $ScopeObject,
        $DeploymentTemplate,
        $DeploymentParameters,
        $Location,
        "validateWhatIf"
      )

      # Did the validation succeed?
      if (($whatIfValidation.StatusMessage) -or ($whatIfValidation -like "*error*")) {
        # Throw an exception and pass the exception message from the ARM whatIf validation
        Throw ("WhatIf Validation failed with the error below: {0}" -f $($whatIfValidation))
      } else {
        $beforeChanges = $whatIfValidation.InvokeResult.properties.changes | Where-Object { $_.changeType -ne "ignore" } | Select-Object -ExpandProperty "before" | ConvertTo-Json -Depth 99
        $afterChanges = $whatIfValidation.InvokeResult.properties.changes | Where-Object { $_.changeType -ne "ignore" } | Select-Object -ExpandProperty "after" | ConvertTo-Json -Depth 99
        Write-PipelineLogger -LogType "info" -Message "WhatIf Validation passed"
        Write-PipelineLogger -LogType "debug" -Message "WhatIf Validation results - before: $($beforeChanges)"
        Write-PipelineLogger -LogType "debug" -Message "WhatIf Validation results - after: $($afterChanges)"
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
    $currentDeployment = $null

    # Check for deployment temple exists
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
        } elseif (($Operation -eq "validate") -or ($Operation -eq "validateWhatIf")) {
          $method = "POST"
        } else {
          throw "Invalid operation type"
        }

        # Call REST API to start the deployment
        try {
          $deployment = $this.InvokeARMRestMethod($method, $uri, $requestBody)
        } catch {
          throw $_.Exception.Message
        }

        # wait for arm deployment
        if ($null -ne $deployment.InvokeResult -and $operation -eq "deploy") {
          Write-PipelineLogger -LogType "info" -Message "Running a deployment..."
          Write-PipelineLogger -LogType "debug" -Message "Provisioning State: [ $($deployment.InvokeResult.properties.provisioningState) ]"
          Write-PipelineLogger -LogType "debug" -Message "Status Code: [ $($deployment.StatusCode) ]"

          # Get the deployment details via REST API
          $deploymentOperationUrl = $this.GetDeploymentOperation($ScopeObject, $Deployment)
          $deploymentDetails = $this.InvokeARMRestMethod("GET", $deploymentOperationUrl, "")
          
          # Wait for the async deployment operation to complete
          $currentDeployment = $this.GetAsyncOperationStatus($Deployment)
          if ((($currentDeployment.InvokeResult.status -eq "Failed") -or ($currentDeployment.InvokeResult.status -eq "Canceled") -or ($currentDeployment.InvokeResult.status -eq "Conflict")) -and $isSubscriptionDeployment -eq $false) {
            Write-PipelineLogger -LogType "error" -Message "Deployment: [ $($Deployment.InvokeResult.name) ] has failed. Provisioning State: $($deploymentDetails.InvokeResult.status)" -NoFailOnError
            Write-PipelineLogger -LogType "error" -Message "Deployment: [ $($Deployment.InvokeResult.name) ] has failed. Status Code: $($deploymentDetails.StatusCode)" -NoFailOnError
            Write-PipelineLogger -LogType "error" -Message "Deployment: [ $($Deployment.InvokeResult.name) ] has failed. Details from resource group deployment: $($deploymentDetails.StatusMessage)" -NoFailOnError
          } elseif ($currentDeployment.InvokeResult.status -eq "Succeeded") {
            Write-PipelineLogger -LogType "success" -Message "Deployment: [ $($Deployment.InvokeResult.name) ] has completed. Provisioning State: [ $($currentDeployment.InvokeResult.status) ]"
            $deploymentDetails = $currentDeployment
          } else {
            Write-PipelineLogger -LogType "error" -Message "Deployment: [ $($Deployment.InvokeResult.name) ] has an unknown error" -NoFailOnError
          }
        } elseif ($operation -eq "validateWhatIf") {
          Write-PipelineLogger -LogType "info" -Message "Running a WhatIf validation..."
          
          # get async operation details here
          $deploymentDetails = $this.GetAsyncOperationStatus($deployment)
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

  # Get ARM deployment operation
  hidden [object] GetDeploymentOperation([PSObject] $ScopeObject, [object] $Deployment) {
    # set the URL's from Discovery REST API call
    $this.SetAzureManagementUrls()

    switch ($ScopeObject.Type) {
      "resourcegroups" {
        Write-PipelineLogger -LogType "info" -Message "Getting resourceGroup level deployment operation status"
        $url = $this.ArmResourceGroupDeploymentOperationUri
        
        # construct the uri using the format for armSubscriptionDeploymentOperationUri
        $uri = $uri -f $ScopeObject.Name, $Deployment.InvokeResult.name, $Deployment.OperationId
      }
      "subscriptions" {
        Write-PipelineLogger -LogType "info" -Message "Getting subscription level deployment operation status"
        $url = $this.ArmSubscriptionDeploymentOperationUri

        # construct the uri using the format for armResourceGroupDeploymentOperationUri
        $uri = $uri -f $ScopeObject.SubscriptionId, $ScopeObject.Name, $Deployment.InvokeResult.name, $Deployment.OperationId
      }
      Default {
        Write-PipelineLogger -LogType "error" -Message "Invalid scope type. Supported scopes are: resourcegroups, subscriptions"
      }
    }

    if ($null -eq $uri) {
      Write-PipelineLogger -LogType "error" -Message "Failed to construct the deployment operation uri"
    }
 
    return $uri
  }

  # Clean up deployment history
  hidden [object] RemoveDeploymentHistory([PSObject] $ScopeObject, [object] $Deployment) {
    $removeHistory = $null

    switch ($ScopeObject.Type) {
      "resourcegroups" {
        Write-PipelineLogger -LogType "info" -Message "Cleaning resourceGroup level deployment history"
        $removeHistory = Remove-AzResourceGroupDeployment -ResourceGroupName $ScopeObject.Name -DeploymentName $Deployment.DeploymentName
      }
      "subscriptions" {
        Write-PipelineLogger -LogType "info" -Message "Cleaning subscription level deployment history"
        $removeHistory = Remove-AzDeployment -Name $Deployment.DeploymentName -SubscriptionId $ScopeObject.SubscriptionId
      }
      Default {
        Write-PipelineLogger -LogType "error" -Message "Invalid scope type. Supported scopes are: resourcegroups, subscriptions"
      }
    }

    return $removeHistory
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

  # Get a token to work against the ARM API
  hidden [PSCustomObject] GetARMToken() {
    $currentAzureContext = Get-AzContext
    if ($null -eq $currentAzureContext.Subscription.TenantId) {
      Write-PipelineLogger -LogType "error" -Message "[$($MyInvocation.MyCommand)] - No Azure context found. Use 'Connect-AzAccount' to create a context or 'Set-AzContext' to select subscription"
    }

    $token = Get-AzAccessToken

    return [PSCustomObject]@{
      AccessToken = $token.Token
      ExpiresOn   = $token.ExpiresOn
    }
  }

  # Get the status of an Async operation
  hidden [PSCustomObject] GetAsyncOperationStatus([PSObject] $HttpResponse) {
    $status = $null
    $statusCode = $HttpResponse.StatusCode
    if ($statusCode -notin @(201, 202)) {
      Write-PipelineLogger -LogType "error" -Message "HTTP response status code must be either '201' or '202' to indicate an asynchronous operation."
    }

    #region Extracts the HTTP response headers of the asynchronous operation.
    $azureAsyncOperation = $HttpResponse.ResponseHeader.'Azure-AsyncOperation' | Out-String
    $location = $HttpResponse.ResponseHeader.'Location' | Out-String

    if (-not ($azureAsyncOperation -or $location)) {
      Write-PipelineLogger -LogType "error" -Message "HTTP response does not contain required headers - 'Azure-AsyncOperation' or 'Location'."
    }

    if ($azureAsyncOperation) {
      $statusUrl = $azureAsyncOperation
    } else {
      $statusUrl = $location
    }

    try {
      #region Monitors the status of the asynchronous operation.
      $retries = 0
      $maxRetries = 100
      do {
        Write-PipelineLogger -LogType "info" -Message "Waiting for asynchronous operation to complete. Retry: [ $($retries+1) ]"
        $httpResponse = $this.InvokeARMRestMethod("GET", $statusUrl, "") # Body is empty here
        if ($HttpResponse) {
          $status = ($httpResponse | Select-Object -ExpandProperty InvokeResult).status
        }

        Write-PipelineLogger -LogType "debug" -Message "Provisioning State: [ $($HttpResponse.InvokeResult.status) ]"
        Write-PipelineLogger -LogType "debug" -Message "Status Code: [ $($HttpResponse.StatusCode) ]"

        if ($azureAsyncOperation) {
          if ($status -eq "Succeeded") {
            Write-PipelineLogger -LogType "success" -Message "The asynchronous operation has completed successfully."
            break
          } elseif ($status -in "Failed", "Canceled") {
            Write-PipelineLogger -LogType "error" -Message "The asynchronous operation has failed."
            break
          }
        } elseif ($location) {
          if ($HttpResponse.StatusCode -eq 200) {
            Write-PipelineLogger -LogType "success" -Message "The asynchronous operation has completed successfully."
            break
          } elseif ($HttpResponse.StatusCode -ne 202) {
            Write-PipelineLogger -LogType "warning" -Message "The asynchronous operation has a status code of '202' and is still in progress."
          }
        }

        Start-Sleep -Second 10
        $retries++
      } until ($retries -gt $maxRetries)

      if ($retries -gt $maxRetries) {
        Write-PipelineLogger -LogType "warning" -Message "Status of asynchronous operation '$($statusUrl)' could not be retrieved even after $($maxRetries) retries."
      }
    } catch {
      Write-PipelineLogger -LogType "error" -Message "AsyncOperation failed. Details: $($_.Exception.Message)."
    }

    return $HttpResponse
  }

  # Invokes a Rest call to azure and adds the token to header parameter
  hidden [PSCustomObject] InvokeARMRestMethod([string] $Method, [string] $Uri, [PSObject] $Body) {
    $respHeader = $null
    $invokeResult = $null
    $errorMessage = $null
    $statusCode = $null

    $token = $this.GetARMToken()

    $irmArgs = @{
      Headers                 = @{
        Authorization = 'Bearer {0}' -f $token.AccessToken
      }
      ErrorAction             = 'Continue'
      Method                  = $Method
      UseBasicParsing         = $true
      ResponseHeadersVariable = 'respHeader'
      StatusCodeVariable      = 'statusCode'
      Uri                     = $Uri
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
      [void] $irmArgs.Add('ContentType', 'application/json')
      [void] $irmArgs.Add('Body', $Body)
    }

    try {
      $invokeResult = Invoke-RestMethod @irmArgs
    } catch {
      $errorMessage = $_.ErrorDetails.Message
      Write-Error -ErrorRecord $_ -ErrorAction Continue
    }

    $operationId = $null
    if ($null -ne $respHeader.'x-ms-request-id') {
      $operationId = $respHeader.'x-ms-request-id'[0]
    }

    $correlationId = $null
    if ($null -ne $respHeader.'x-ms-correlation-request-id') {
      Write-Information -MessageData "[$($MyInvocation.MyCommand)] - Response contains 'CorrelationId' '$($respHeader.'x-ms-correlation-request-id'[0])'"
      $correlationId = $respHeader.'x-ms-correlation-request-id'[0]
    }

    return [PSCustomObject]@{
      InvokeResult   = $invokeResult
      StatusCode     = $statusCode
      ResponseHeader = $respHeader
      OperationId    = $operationId
      CorrelationId  = $correlationId
      StatusMessage  = $errorMessage
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
    # deployment urls
    $this.ArmResourceGroupDeploymentUri = "https://management.azure.com/subscriptions/{0}/resourcegroups/{1}/providers/Microsoft.Resources/deployments/{2}?api-version=2021-04-01"
    $this.ArmSubscriptionDeploymentUri = "https://management.azure.com/subscriptions/{0}/providers/Microsoft.Resources/deployments/{1}?api-version=2021-04-01"

    # validation urls
    $this.ArmResourceGroupValidationUri = "https://management.azure.com/subscriptions/{0}/resourcegroups/{1}/providers/Microsoft.Resources/deployments/{2}/validate?api-version=2021-04-01"
    $this.ArmSubscriptionValidationUri = "https://management.azure.com/subscriptions/{0}/providers/Microsoft.Resources/deployments/{1}/validate?api-version=2021-04-01"

    # whatIf validation urls
    $this.ArmResourceGroupWhatIfValidationUri = "https://management.azure.com/subscriptions/{0}/resourcegroups/{1}/providers/Microsoft.Resources/deployments/{2}/whatIf?api-version=2021-04-01"
    $this.ArmSubscriptionWhatIfValidationUri = "https://management.azure.com/subscriptions/{0}/providers/Microsoft.Resources/deployments/{1}/whatIf?api-version=2021-04-01"

    # deployment operation urls
    $this.ArmResourceGroupDeploymentOperationUri = "https://management.azure.com/subscriptions/{0}/resourcegroups/{1}/deployments/{2}/operations/{3}?api-version=2021-04-01"
    $this.ArmSubscriptionDeploymentOperationUri = "https://management.azure.com/subscriptions/{0}/providers/Microsoft.Resources/deployments/{1}/operations/{2}?api-version=2021-04-01"
  }
}
