function Invoke-DestroyEnvironment {
  <#
    .SYNOPSIS
      Deletes a resource group.

    .DESCRIPTION
      Deletes a resource group.

    .PARAMETER DeploymentScope
      The deployment scope - resource group or subscription.

    .PARAMETER ResourceGroupName
      The name of the resource group if scope is resource group deployment.

    .PARAMETER SubscriptionId
      The name of the subscription. Required for both resource group or subscription scopes.

    .PARAMETER ManagementGroupId
      The Id of the management group for which to return a scope object.

    .PARAMETER Confirm
      If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

    .PARAMETER WhatIf
      If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

    .EXAMPLE
      Invoke-DestroyEnvironment -DeploymentScope "resourcegroup" -SubscriptionId 'xxxx' -ResourceGroupName 'some-rg'

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
  param (
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
    [string] $SubscriptionId = (Get-AzContext).Subscription.Id
  )

  begin {
    Write-Debug ("{0} entered" -f $MyInvocation.MyCommand)

    #region execution timer
    $start = $(Get-Date)
  }
  process {
    #region Initialize deployment service
    try {
      Write-PipelineLogger -LogType "info" -Message "Invoke-DestroyEnvironment.DeploymentService.Initializing"
      $deploymentService = [ARMDeploymentService]::new()
    } catch {
      Write-PipelineLogger -LogType "error" -Message "Invoke-DestroyEnvironment.DeploymentService.InitializationFailed"
    }
    #endregion Initialize deployment service

    Write-PipelineLogger -LogType "info" -Message "Invoke-DestroyEnvironment.Processing"

    #region Resolve Deployment Scope
    try {
      Write-PipelineLogger -LogType "info" -Message "Invoke-DestroyEnvironment.ScopeObject.Create"
      switch ($DeploymentScope) {
        'resourcegroup' {
          $scopeObject = New-ARMDeploymentScope -DeploymentScope $DeploymentScope -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -ErrorAction Stop -WhatIf:$false
        }
        'subscription' {
          $scopeObject = New-ARMDeploymentScope -DeploymentScope $DeploymentScope -SubscriptionId $SubscriptionId -ErrorAction Stop -WhatIf:$false
        }
        'managementgroup' {
          $scopeObject = New-ARMDeploymentScope -DeploymentScope $DeploymentScope -ManagementGroupId $ManagementGroupId -ErrorAction Stop -WhatIf:$false
        }
        default {
          throw "Invalid deployment scope. Valid scopes are resourcegroup, subscription or managementgroup"
        }
      }
    } catch {
      Write-PipelineLogger -LogType "error" -Message "Invoke-DestroyEnvironment.DeploymentScope.Failed. Details: $($_.Exception.Message)"
    }

    if (-not $scopeObject) {
      Write-PipelineLogger -LogType "error" -Message "Invoke-DestroyEnvironment.DeploymentScope.NotFound"
      return
    } else {
      Write-PipelineLogger -LogType "success" -Message "Invoke-DestroyEnvironment.DeploymentScope.Success"
    }
    #endregion Resolve Scope

    #region set subscription context
    try {
      Write-PipelineLogger -LogType "info" -Message "Invoke-DestroyEnvironment.Subscription.Context.Initializing"
      Set-ARMContext -Scope $scopeObject -ErrorAction Stop
    } catch {
      Write-PipelineLogger -LogType "error" -Message "Invoke-DestroyEnvironment.Subscription.Context.Failed. Details: $($_.Exception.Message)"
      return
    }

    Write-PipelineLogger -LogType "success" -Message "Invoke-DestroyEnvironment.Subscription.Context.Success"
    #endregion set subscription context

    #region deployment stage
    try {
      #region teardown environment
      Write-PipelineLogger -LogType "info" -Message "Invoke-DestroyEnvironment.Teardown.Initializing"
      if ($PSCmdlet.ShouldProcess("Environment Teardown - Scope [$DeploymentScope]", 'Destroy')) {
        try {
          $rgFound = $deploymentService.GetResourceGroup(
            $scopeObject
          )

          # Let's check if the resource group exists and the resource group name & its not in a deleting state
          if ($null -ne $rgFound -and ($rgFound.ProvisioningState -ne "Deleting")) {
            Write-PipelineLogger -LogType "info" -Message "Invoke-DestroyEnvironment.ResourceGroup.Deleting"
            $deploymentService.RemoveResourceGroup(
              $scopeObject
            )

            Write-PipelineLogger -LogType "success" -Message "Invoke-DestroyEnvironment.ResourceGroup.Deleted.Success"
          }
          Write-PipelineLogger -LogType "info" -Message "Invoke-DestroyEnvironment.Teardown.Completed"
        } catch {
          Write-PipelineLogger -LogType "error" -Message "Invoke-DestroyEnvironment.Teardown.Failed. Details: $($_.Exception.Message)"
        }
      }
      #endregion
    } catch {
      Write-PipelineLogger -LogType "error" -Message "Invoke-DestroyEnvironment.Failed" -NoFailOnError
      throw "$($_.Exception.Message)"
    }
    #endregion deployment stage
    #endregion Process DeploymentScope
  }

  end {
    $stop = $(Get-Date)
    Write-PipelineLogger -LogType "debug" -Message "Script execution time: $($($stop - $start).minutes) minutes and $($($stop - $start).seconds) seconds."

    Write-Debug ("{0} exited" -f $MyInvocation.MyCommand)
  }
}
