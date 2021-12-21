function Get-ARMToken {
  <#
    .SYNOPSIS
    Get a Token to work against Azure ARM API

    .DESCRIPTION
    Get a Token to work against Azure ARM API. When MSI is detected, a token will be resolved
    using MSI endpoint and secret, if no MSI is detected, the Az.Accounts context will be tried.

    .EXAMPLE
    Get-ARMToken
  #>
  $currentAzureContext = Get-AzContext
  if ($null -eq $currentAzureContext.Subscription.TenantId) {
    Write-PipelineLogger -LogType "error" -Message "[$($MyInvocation.MyCommand)] - No Azure context found. Use 'Connect-AzAccount' to create a context or 'Set-AzContext' to select subscription"
  }
  $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
  $profileClient = [Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient]::new($azureRmProfile)
  $token = $profileClient.AcquireAccessToken($currentAzureContext.Subscription.TenantId)

  [PSCustomObject]@{
    AccessToken = $token.AccessToken
    ExpiresOn   = $token.ExpiresOn
  }
}
