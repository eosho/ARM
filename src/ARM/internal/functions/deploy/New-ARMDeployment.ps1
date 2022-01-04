function New-ARMDeployment {
  <#
    .SYNOPSIS
      Run a template deployment using a given parameter file, cleans up rgs, resource locks.

    .DESCRIPTION
      Run a template deployment using a given parameter file. Works on a resource group, subscription level.

    .PARAMETER TemplateFilePath
      Path where the ARM templates can be found.

    .PARAMETER TemplateParameterFilePath
      Path where the parameters of the ARM templates can be found.

    .PARAMETER TemplateParameterObject
      Object that contains the parameters of the ARM template.

    .PARAMETER DeploymentScope
      The deployment scope - resource group or subscription.

    .PARAMETER ResourceGroupName
      The name of the resource group if scope is resource group deployment.

    .PARAMETER SubscriptionId
      The name of the subscription. Required for both resource group or subscription scopes.

    .PARAMETER ManagementGroupId
      The Id of the management group for which to return a scope object.

    .PARAMETER DefaultDeploymentRegion
      The default deployment region. E.g. EastUS or WestUS.

    .PARAMETER Validate
      Switch to validate deployment against the ARM API.

    .PARAMETER ValidateWhatIf
      Switch to perform a what-if deployment validation against the ARM API.

    .PARAMETER TearDownEnvironment
      Switch to delete the entire resource group and its contents.

    .PARAMETER SkipModuleCheck
      Switch to validate latest Az module is installed locally.

    .PARAMETER Confirm
      If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

    .PARAMETER WhatIf
      If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

    .EXAMPLE
      $paramArgs = @{
        SubscriptionId        = $(Get-AzContext).Subscription.Id
        DeploymentTemplate    = '.\aks\bicep\main.json'
        DeploymentParameter   = '.\aks\bicep\main.parameters.json'
        Location              = "eastus2"
      }
      Invoke-ARMDeployment @paramArgs

      Deploy the ARM template with the parameter file 'parameters.json'

    .EXAMPLE
      $paramArgs = @{
        Scope                     = 'resourcegroup'
        SubscriptionId            = $(Get-AzContext).Subscription.Id
        DeploymentTemplate        = '.\aks\bicep\main.rg.json'
        TemplateParameterFilePath = 'parameters.json'
        DefaultDeploymentRegion   = "eastus2"
        ResourceGroupName         = 'demo-rg'
      }
      Invoke-ARMDeployment @paramArgs -Validate

      Runs the ARM template validation on a resource group deployment.

    .EXAMPLE
      $paramArgs = @{
        DeploymentScope           = 'subscription'
        SubscriptionId            = $(Get-AzContext).Subscription.Id
        DeploymentTemplate        = '.\aks\bicep\main.sub.json'
        TemplateParameterFilePath = 'parameters.json'
        DefaultDeploymentRegion   = "eastus2"
      }
      Invoke-ARMDeployment @paramArgs

      Runs the ARM template validation on a subscription deployment.

    .EXAMPLE
      $paramArgs = @{
        DeploymentScope           = 'managementgroup'
        SubscriptionId            = $(Get-AzContext).Subscription.Id
        ManagementGroupId         = 'demo-mg'
        DeploymentTemplate        = '.\aks\bicep\main.mg.json'
        TemplateParameterFilePath = 'parameters.json'
        DefaultDeploymentRegion   = "eastus2"
      }
      Invoke-ARMDeployment @paramArgs

      Runs the ARM template validation on a management group deployment.

    .EXAMPLE
      New-ARMDeployment -DeploymentScope "resourcegroup" -SubscriptionId 'xxxx' -ResourceGroupName 'some-rg' -TearDownEnvironment

      Cleans up the resources by cleaning the RG

    .INPUTS
      <none>

    .OUTPUTS
      <none>

    .NOTES
      <none>
  #>

  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
  [CmdletBinding(SupportsShouldProcess = $true)]
  [Alias("Invoke-ARMDeployment")]
  param (
    [Parameter(Mandatory = $true)]
    [Alias("TemplatePath")]
    [string] $TemplateFilePath,

    [Parameter(Mandatory = $false)]
    [Alias("ParameterPath")]
    [string] $TemplateParameterFilePath,

    [Parameter(Mandatory = $false)]
    [Alias("ParameterObject")]
    [string] $TemplateParameterObject,

    [Parameter(Mandatory = $true, ParameterSetName = "scope")]
    [ValidateSet("resourcegroup", "subscription", "managementgroup")]
    [Alias("Scope")]
    [string] $DeploymentScope,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [Alias("RGName", "rg")]
    [string] $ResourceGroupName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [Alias("MgId", "mg")]
    [string] $ManagementGroupId,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [Alias("SubId", "sub" )]
    [string] $SubscriptionId = (Get-AzContext).Subscription.Id,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [Alias("Location", "loc")]
    [string] $DefaultDeploymentRegion = "EastUS",

    [Parameter(Mandatory = $false)]
    [switch] $Validate,

    [Parameter(Mandatory = $false)]
    [switch] $ValidateWhatIf,

    [Parameter(Mandatory = $false)]
    [switch] $TearDownEnvironment,

    [Parameter(Mandatory = $false)]
    [switch] $RemoveDeploymentHistory,

    [Parameter(Mandatory = $false)]
    [switch] $SkipModuleCheck
  )

  begin {
    Write-Debug ("{0} entered" -f $MyInvocation.MyCommand)

    #region execution timer
    $start = $(Get-Date)
  }
  process {
    #region Initialize deployment service
    try {
      Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.DeploymentService.Initializing"
      $deploymentService = [ARMDeploymentService]::new()
    } catch {
      Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.DeploymentService.InitializationFailed"
    }
    #endregion Initialize deployment service

    #region Validate Az module
    if ($SkipModuleCheck.IsPresent) {
      Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.ValidateAzModule.Checking"
      $deploymentService.AzModuleIsInstalled()
    }
    #endregion

    Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Processing"

    #region Parse Content
    Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Resolving.TemplateFilePath"
    if (Test-Path -Path $TemplateFilePath) {
      # Determine the template type - .bicep or .json
      if ((Split-Path -Path $TemplateFilePath -Extension) -eq '.bicep') {
        Write-PipelineLogger -LogType "info" -Message "Template is in .bicep format, converting it to an object"
        $templateObj = az bicep build --file $TemplateFilePath --stdout | ConvertFrom-Json
      } elseif ((Split-Path -Path $TemplateFilePath -Extension) -eq '.json') {
        Write-PipelineLogger -LogType "info" -Message "Template is in .json format, converting it to an object"
        $templateObj = Get-Content $TemplateFilePath | ConvertFrom-Json
      } else {
        Write-PipelineLogger -LogType "error" -Message "Template is not in .bicep or .json format"
      }
    } else {
      Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.Resolving.Content.TemplateFilePath.NotFound"
      return
    }
    Write-PipelineLogger -LogType "success" -Message "New-ARMDeployment.Resolving.TemplateFilePath.Success"
    #endregion Parse Content

    #region Resolve template parameters
    Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Resolving.TemplateParameterFilePath"
    if (Test-Path -Path $TemplateParameterFilePath) {
      $templateParameterObj = Get-Content -Path $TemplateParameterFilePath -Raw | ConvertFrom-Json -Depth 99
    } elseif ($TemplateParameterObject) {
      $templateParameterObj = $TemplateParameterObject
    } else {
      Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.Resolving.TemplateParameters.TemplateParameterFilePath.NotFound"
      return
    }

    if ($templateParameterObj) {
      Write-PipelineLogger -LogType "success" -Message "New-ARMDeployment.Resolving.TemplateParameterObject.Success"
    } else {
      Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.Resolving.TemplateParameterObject.NotFound"
    }
    #endregion Resolve template parameters

    #region Resolve Deployment Scope
    try {
      Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.ScopeObject.Create"
      switch ($DeploymentScope) {
        'resourcegroup' {
          if ($templateObj.'$schema' -match [regex]::Escape('deploymentTemplate.json')) {
            $scopeObject = New-ARMDeploymentScope -DeploymentScope $DeploymentScope -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -ErrorAction Stop -WhatIf:$false
          } else {
            Write-PipelineLogger -LogType "warning" -Message "Deployment Template does not match deployment scope resourcegroup."
            return
          }
        }
        'subscription' {
          if ($templateObj.'$schema' -match [regex]::Escape('subscriptionDeploymentTemplate.json')) {
            $scopeObject = New-ARMDeploymentScope -DeploymentScope $DeploymentScope -SubscriptionId $SubscriptionId -ErrorAction Stop -WhatIf:$false
          } else {
            Write-PipelineLogger -LogType "warning" -Message "Deployment Template does not match deployment scope subscription."
            return
          }
        }
        'managementgroup' {
          if ($templateObj.'$schema' -match [regex]::Escape('managementGroupDeploymentTemplate.json')) {
            $scopeObject = New-ARMDeploymentScope -DeploymentScope $DeploymentScope -ManagementGroupId $ManagementGroupId -ErrorAction Stop -WhatIf:$false
          } else {
            Write-PipelineLogger -LogType "warning" -Message "Deployment Template does not match deployment scope managementgroup."
            return
          }
        }
        default {
          throw "Invalid deployment scope. Valid scopes are resourcegroup, subscription or managementgroup"
        }
      }
    } catch {
      Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.DeploymentScope.Failed. Details: $($_.Exception.Message)"
    }

    if (-not $scopeObject) {
      Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.DeploymentScope.NotFound"
      return
    } else {
      Write-PipelineLogger -LogType "success" -Message "New-ARMDeployment.DeploymentScope.Success"
    }
    #endregion Resolve Scope

    #region set subscription context
    try {
      Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Subscription.Context.Initializing"
      Set-ARMContext -Scope $scopeObject -ErrorAction Stop
    } catch {
      Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.Subscription.Context.Failed. Details: $($_.Exception.Message)"
      return
    }

    Write-PipelineLogger -LogType "success" -Message "New-ARMDeployment.Subscription.Context.Success"
    #endregion set subscription context

    #region deployment stage
    try {
      if (-not ($TeardownEnvironment.IsPresent)) {
        #region create rg if scope is resourcegroups
        if ($DeploymentScope -eq "resourcegroup") {
          Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Validate.ResourceGroup"

          if (-not ($deploymentService.GetResourceGroup($ScopeObject))) {
            Write-PipelineLogger -LogType "warning" -Message "New-ARMDeployment.Validate.ResourceGroup.NotFound"

            if ($PSCmdlet.ShouldProcess("Resource group [$ResourceGroupName] in location [$DefaultDeploymentRegion]", 'Create')) {
              $deploymentService.CreateResourceGroup($ScopeObject, $DefaultDeploymentRegion)
              Write-PipelineLogger -LogType "success" -Message "New-ARMDeployment.Validate.ResourceGroup.Created"
            }
          } else {
            Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Validate.ResourceGroup.Exists"
          }
        }
        #endregion

        if ($Validate.IsPresent) {
          #region validate deployment template
          Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Validate.Initializing"

          if ($PSCmdlet.ShouldProcess("Validation - Scope [$DeploymentScope]", 'Validate')) {
            $deploymentService.ExecuteValidation(
              $scopeObject,
              $templateObj,
              $templateParameterObj,
              $DefaultDeploymentRegion
            )
          }
          #endregion
        } elseif ($ValidateWhatIf.IsPresent) {
          #region validate whatif
          Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Validate.WhatIf.Initializing"

          if ($PSCmdlet.ShouldProcess("WhatIf Validation - Scope [$DeploymentScope]", 'ValidateWhatIf')) {
            $deploymentService.ExecuteValidationWhatIf(
              $scopeObject,
              $templateObj,
              $templateParameterObj,
              $DefaultDeploymentRegion
            )
            Write-PipelineLogger -LogType "success" -Message "New-ARMDeployment.Validate.WhatIf.Success"
          }
          #endregion
        } else {
          #region create deployment
          Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Deployment.Initializing"

          if ($PSCmdlet.ShouldProcess("ARM Deployment [$DeploymentScope]", 'Create')) {
            $deployment = $deploymentService.ExecuteDeployment(
              $scopeObject,
              $templateObj,
              $templateParameterObj,
              $DefaultDeploymentRegion
            )

            Write-PipelineLogger -LogType "success" -Message "New-ARMDeployment.Deployment.Success"
          }
          #endregion

          #region delete deployment history
          if ($deployment -and $RemoveDeploymentHistory.IsPresent) {
            Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.DeploymentHistory.Cleanup.Initializing"
            if ($PSCmdlet.ShouldProcess("Remove Deployment History [$DeploymentScope]", 'Remove')) {
              $cleanup = $deploymentService.RemoveDeploymentHistory(
                $scopeObject,
                $deployment
              )

              if ($cleanup -eq "true") {
                Write-PipelineLogger -LogType "success" -Message "New-ARMDeployment.DeploymentHistory.Cleanup.Success"
              } else {
                Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.Removing.DeploymentHistory.Failed" -NoFailOnError
              }
            }
          }
          #endregion
        }
      } elseif ($TeardownEnvironment.IsPresent) {
        #region teardown environment
        Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Teardown.Initializing"
        if ($PSCmdlet.ShouldProcess("Environment Teardown - Scope [$DeploymentScope]", 'Destroy')) {
          try {
            $rgFound = $deploymentService.GetResourceGroup(
              $scopeObject
            )

            # Let's check if the resource group exists and the resource group name & its not in a deleting state
            if ($null -ne $rgFound -and ($rgFound.ProvisioningState -ne "Deleting")) {
              # Start deleting the resource group locks (if any) and resource group
              Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.ResourceLock.Deleting"
              try {
                $deploymentService.RemoveResourceGroupLock(
                  $scopeObject
                )
                Write-PipelineLogger -LogType "success" -Message "New-ARMDeployment.ResourceLock.Deleted.Success"
              } catch {
                Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.ResourceLock.Deleted.Failed. Details: $($_.Exception.Message)"
              }

              Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.ResourceGroup.Deleting"
              $deploymentService.RemoveResourceGroup(
                $ScopeObj
              )

              Write-PipelineLogger -LogType "success" -Message "New-ARMDeployment.ResourceGroup.Deleted.Success"
            }
            Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Teardown.Completed"
          } catch {
            Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.Teardown.Failed. Details: $($_.Exception.Message)"
          }
        }
        #endregion
      } else {
        Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.Operation.NotSupported"
      }
    } catch {
      Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.Failed" -NoFailOnError
      throw "$($_.Exception.Message)"
    }
    #endregion deployment stage
    #endregion Process DeploymentScope

    #region completed
    Write-PipelineLogger -LogType "success" -Message "New-ARMDeployment.Completed"
    #endregion completed
  }

  end {
    $stop = $(Get-Date)
    Write-PipelineLogger -LogType "debug" -Message "Script execution time: $($($stop - $start).minutes) minutes and $($($stop - $start).seconds) seconds."

    Write-Debug ("{0} exited" -f $MyInvocation.MyCommand)
  }
}
