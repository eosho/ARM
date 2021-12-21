function Register-ARMResourceProvider {
  <#
    .SYNOPSIS
      Registers an azure resource provider.

    .DESCRIPTION
      Registers an azure resource provider.
      Assumes an ARM definition of a resource provider as input.

    .PARAMETER ResourceProviders
      The json object containing the resource providers to be enabled.

    .PARAMETER ScopeObject
      The current AzOps scope.

    .EXAMPLE
      PS C:\> Register-ARMResourceProvider -ResourceProviders "someJson" -ScopeObject $scopeObject
      Registers an azure resource provider.
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string[]] $ResourceProviders,

    [Parameter(Mandatory = $true)]
    [ARMDeploymentScope] $ScopeObject
  )

  process {
    Write-PipelineLogger -LogType "info" -Message "Registering ResourceProvider processing"

    #region set subscription context
    Set-ARMContext -Scope $scopeObject -ErrorAction Stop
    #endregion set subscription context

    $resourceProviders = ConvertFrom-Json -InputObject $ResourceProviders
    foreach ($resourceProvider in $resourceProviders) {
      if ((Get-AzResourceProvider -ProviderNamespace $resourceProvider).RegistrationState -contains 'NotRegistered' ) {
        try {
          Write-PipelineLogger -LogType "info" -Message "Registering ResourceProvider - $resourceProvider"
          Register-AzResourceProvider -ProviderNamespace $resourceProvider
        } catch {
          Write-PipelineLogger -LogType "error" -Message "Registering ResourceProvider failed - $resourceProvider. Details: $($_.Exception.Message)"
        }
      }
    }
  }
}
