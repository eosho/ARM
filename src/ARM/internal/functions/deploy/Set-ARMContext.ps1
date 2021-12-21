function Set-ARMContext {
  <#
    .SYNOPSIS
      Changes the currently active azure context to the subscription of the specified scope object.

    .DESCRIPTION
      Changes the currently active azure context to the subscription of the specified scope object.

    .PARAMETER ScopeObject
      The scope object into which context to change.

    .EXAMPLE
      > Set-ARMContext -ScopeObject $scopeObject
      Changes the current context to the subscription of $scopeObject.
  #>
  [CmdletBinding(ConfirmImpact='None')]
  param (
    [Parameter(Mandatory = $true)]
    [ARMDeploymentScope] $ScopeObject
  )

  begin {
    $context = Get-AzContext
  }

  process {
    if (-not $ScopeObject.SubscriptionId) { return }

    if ($context.Subscription.Id -ne $ScopeObject.SubscriptionId) {
      Write-PipelineLogger -LogType "info" -Message "Current context does not match subscription - '$($ScopeObject.SubscriptionId)'"
      $setContext = [ARMDeploymentScope]::new($ScopeObject)
      $setContext.SetSubscriptionContext()
    }
  }
}
