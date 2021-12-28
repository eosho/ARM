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

    .PARAMETER Scope
      The deployment scope - resource group or subscription.

    .PARAMETER ResourceGroupName
      The name of the resource group if scope is resource group deployment.

    .PARAMETER SubscriptionId
      The name of the subscription. Required for both resource group or subscription scopes.

    .PARAMETER DefaultDeploymentRegion
      The default deployment region. E.g. EastUS.

    .PARAMETER Validate
      Switch to validate deployment against the ARM API.

    .PARAMETER ValidateWhatIf
      Switch to perform a what-if deployment validation against the ARM API.

    .PARAMETER TearDownEnvironment
      Switch to delete the entire resource group and its contents.

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
        DeploymentTemplate        = '.\aks\bicep\main.json'
        TemplateParameterFilePath = 'parameters.json'
        DefaultDeploymentRegion   = "eastus2"
        ResourceGroupName         = 'demo-rg'
      }
      Invoke-ARMDeployment -Validate

      Runs the ARM template validation on a resource group deployment.

    .EXAMPLE
      New-ARMDeployment -Scope "resourcegroup" -SubscriptionId 'xxxx' -ResourceGroupName 'some-rg' -TearDownEnvironment

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
    [Alias('TemplatePath')]
    [string] $TemplateFilePath,

    [Parameter(Mandatory = $true)]
    [Alias('ParameterPath')]
    [string] $TemplateParameterFilePath,

    [Parameter(Mandatory = $true, ParameterSetName = "scope")]
    [ValidateSet("resourcegroup", "subscription", "managementgroup", "tenant")]
    [string] $Scope,

    [Parameter(Mandatory = $false)]
    [Alias('RGName')]
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [Alias('SubId')]
    [string] $SubscriptionId = (Get-AzContext).Subscription.Id,

    [Parameter(Mandatory = $false)]
    [Alias('Location')]
    [string] $DefaultDeploymentRegion = "EastUS",

    [Parameter(Mandatory = $false)]
    [switch] $Validate,

    [Parameter(Mandatory = $false)]
    [switch] $ValidateWhatIf,

    [Parameter(Mandatory = $false)]
    [switch] $TearDownEnvironment,

    [Parameter(Mandatory = $false)]
    [switch] $RemoveDeploymentHistory
  )

  begin {
    Write-Debug ("{0} entered" -f $MyInvocation.MyCommand)

    #region Initialize deployment service
    Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.DeploymentService.Initializing"
    $deploymentService = [ARMDeploymentService]::new()
    #endregion Initialize deployment service
  }
  process {
    Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Processing"

    #region Parse Content
    Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Resolving.TemplateFilePath"
    if (Test-Path -Path $TemplateFilePath) {
      $templateObj = Get-TemplateType -TemplateFilePath $TemplateFilePath
    } else {
      Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.Resolving.Content.TemplateFilePath.NotFound"
      return
    }
    #endregion Parse Content

    #region Resolve template parameters
    Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Resolving.TemplateParameterFilePath"
    if (Test-Path -Path $TemplateParameterFilePath) {
      $templateParameterObj = Get-Content -Path $TemplateParameterFilePath -Raw | ConvertFrom-Json -Depth 99
    } else {
      Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.Resolving.TemplateParameters.TemplateParameterFilePath.NotFound"
      return
    }
    #endregion Resolve template parameters

    #region Resolve Scope
    try {
      Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.ScopeObject.Create"
      switch ($Scope) {
        'resourcegroup' {
          if ($templateObj.'$schema' -match [regex]::Escape('deploymentTemplate.json')) {
            $scopeObject = New-ARMScope -Scope $scope -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -ErrorAction Stop -WhatIf:$false
          } else {
            Write-PipelineLogger -LogType "warning" -Message "Deployment Template does not match scope resourcegroup."
            return
          }
        }
        'subscription' {
          if ($templateObj.'$schema' -match [regex]::Escape('subscriptionDeploymentTemplate.json')) {
            $scopeObject = New-ARMScope -Scope $scope -SubscriptionId $SubscriptionId -ErrorAction Stop -WhatIf:$false
          } else {
            Write-PipelineLogger -LogType "warning" -Message "Deployment Template does not match scope subscription."
            return
          }
        }
        'managementgroup' {
          if ($templateObj.'$schema' -match [regex]::Escape('managementGroupDeploymentTemplate.json')) {
            $scopeObject = New-ARMScope -Scope $scope -ErrorAction Stop -WhatIf:$false
          } else {
            Write-PipelineLogger -LogType "warning" -Message "Deployment Template does not match scope managementgroup."
            return
          }
        }
        'tenant' {
          if ($templateObj.'$schema' -match [regex]::Escape('tenantDeploymentTemplate.json')) {
            $scopeObject = New-ARMScope -Scope $scope -ErrorAction Stop -WhatIf:$false
          } else {
            Write-PipelineLogger -LogType "warning" -Message "Deployment Template does not match scope tenant."
            return
          }
        }
        default {
          throw "Invalid scope. Valid scopes are resourcegroup and subscription"
        }
      }
    } catch {
      Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.Scope.Failed. Details: $($_.Exception.Message)"
    }

    Write-PipelineLogger -LogType "success" -Message "New-ARMDeployment.ScopeObject.Successful"

    if (-not $scopeObject) {
      Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.Scope.Empty"
      return
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

    Write-PipelineLogger -LogType "success" -Message "New-ARMDeployment.Subscription.Context.Initialized"
    #endregion set subscription context

    #region deployment stage
    try {
      if (-not ($TeardownEnvironment.IsPresent)) {
        if ($Validate.IsPresent) {
          Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Validate.Processing"
          if ($PSCmdlet.ShouldProcess("Validation - Scope [$scope]", 'Validate')) {
            $deploymentService.ExecuteValidation(
              $scopeObject,
              $templateObj,
              $templateParameterObj,
              $DefaultDeploymentRegion
            )
          }
        } elseif ($ValidateWhatIf.IsPresent) {
          Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Validate.WhatIf.Processing"
          if ($PSCmdlet.ShouldProcess("WhatIf Validation - Scope [$scope]", 'ValidateWhatIf')) {
            $deploymentService.ExecuteValidationWhatIf(
              $scopeObject,
              $templateObj,
              $templateParameterObj,
              $DefaultDeploymentRegion
            )
          }
        } else {
          Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Deployment.Processing"

          if ($PSCmdlet.ShouldProcess("ARM Deployment [$scope]", 'Create')) {
            $deployment = $deploymentService.ExecuteDeployment(
              $scopeObject,
              $templateObj,
              $templateParameterObj,
              $DefaultDeploymentRegion
            )

            Write-PipelineLogger -LogType "success" -Message "New-ARMDeployment.Deployment.Completed"
          }

          if ($deployment -and $RemoveDeploymentHistory.IsPresent) {
            Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Removing.DeploymentHistory"
            if ($PSCmdlet.ShouldProcess("Remove Deployment History [$scope]", 'Remove')) {
              $cleanup = $deploymentService.RemoveDeploymentHistory(
                $scopeObject,
                $deployment
              )

              if ($cleanup -eq "true") {
                Write-PipelineLogger -LogType "success" -Message "New-ARMDeployment.Removing.DeploymentHistory.Success"
              } else {
                Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.Removing.DeploymentHistory.Failed" -NoFailOnError
              }
            }
          }
        }
      } elseif ($TeardownEnvironment.IsPresent) {
        Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.Teardown.Processing"
        if ($PSCmdlet.ShouldProcess("Environment Teardown - Scope [$scope]", 'Destroy')) {
          $rgFound = $deploymentService.GetResourceGroup(
            $scopeObject
          )

          # Let's check if the resource group exists and the resource group name & its not in a deleting state
          if ($null -ne $rgFound -and ($rgFound.ProvisioningState -ne "Deleting")) {
            # Start deleting the resource group locks (if any) and resource group
            Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.ResourceLock.Deleting"
            $deploymentService.RemoveResourceGroupLock(
              $scopeObject
            )

            Write-PipelineLogger -LogType "info" -Message "New-ARMDeployment.ResourceGroup.Deleting"
            $deploymentService.RemoveResourceGroup(
              $ScopeObj
            )
          }
        }
      } else {
        Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.Operation.NotSupported"
      }
    } catch {
      Write-PipelineLogger -LogType "error" -Message "New-ARMDeployment.Failed" -NoFailOnError
      throw "$($_.Exception.Message)"
    }
    #endregion deployment stage
    #endregion Process Scope

    #region completed
    Write-PipelineLogger -LogType "success" -Message "New-ARMDeployment.Completed"
    #endregion completed
  }

  end {
    Write-Debug ("{0} exited" -f $MyInvocation.MyCommand)
  }
}
