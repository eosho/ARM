function Register-ARMProviderFeature {
  <#
    .SYNOPSIS
      Registers a provider feature from ARM.

    .DESCRIPTION
      Registers a provider feature from ARM.

    .PARAMETER ProviderFeatures
      Json object of provider features to be enabled.

    .PARAMETER ScopeObject
      The current AzOps scope.

    .EXAMPLE
      PS C:\> Register-ARMProviderFeature -ProviderFeatures "" -ScopeObject $scopeObject
      Registers a provider feature from ARM.
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string[]] $ProviderFeatures,

    [Parameter(Mandatory = $true)]
    [ARMDeploymentScope] $ScopeObject
  )

  process {
    Write-PipelineLogger -LogType "info" -Message 'Register ProviderFeature processing'

    #region set subscription context
    Set-ARMContext -Scope $scopeObject -ErrorAction Stop
    #endregion set subscription context

    $features = ConvertFrom-Json -InputObject @($ProviderFeatures)
    foreach ($feature in $features) {
      if ((Get-AzProviderFeature -FeatureName $feature.FeatureName -ProviderNamespace $feature.ProviderNamespace).RegistrationState -contains 'NotRegistered' ) {
        try {
          Write-PipelineLogger -LogType "info" -Message "Registering ProviderFeature: $($feature.FeatureName)"
          Register-AzProviderFeature -FeatureName $feature.FeatureName -ProviderNamespace $feature.ProviderNamespace
        } catch {
          Write-PipelineLogger -LogType "error" -Message "Registering ProviderFeature: $($feature.FeatureName) failed with error: $($_.Exception.Message)"
        }
      }
    }
  }
}
