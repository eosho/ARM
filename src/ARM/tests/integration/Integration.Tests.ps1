<#
.SYNOPSIS
  This script performs integration tests on your entire repository.

.DESCRIPTION
  This script performs integration tests on your entire repository.
  It will grab all bicep file and build them to ARM JSON for testing.

.EXAMPLE
  PS C:\> tests\integration\integration.tests.ps1

.INPUTS
  Inputs (if any)

.OUTPUTS
  Output (if any)

.NOTES
  General notes
#>

#Requires -Version 7

# root folder
param (
  [string] $projectDirectory = (Split-Path -Path $PSScriptRoot -Parent),
  [string] $bicepDirectory = (Join-Path -Path $projectDirectory -ChildPath "../../../bicep/modules")
)

# check pester module is installed
$pesterInstalled = Get-Command -Name Invoke-Pester -ErrorAction SilentlyContinue
if ($null -eq $pesterInstalled) {
  Write-Error 'Pester is not installed but is required to run QA. Fix by installing Pester (Install-Module Pester)' -ErrorAction Stop
}

Describe 'Prepare Integration Tests' {

  BeforeAll {
    if ($null -eq $guid) {
      $script:newGuid = $true
      $guid = New-Guid
    }

    $script:deploymentScope = 'subscription'
    $script:location = 'EastUS2'
    $script:subscriptionId = $(Get-AzContext).Subscription.Id
  }

  Context 'Test Deployment' {
    It "Modules are imported successfully" {
      $preReqConditions = @(
        @{
          Label  = 'Modules are imported successfully'
          Test   = { (Get-Module -Name "ARM") }
          Action = {
            . "../../src/ARM/internal/scripts/preimport.ps1"
          }
        }
      )

      @($preReqConditions).ForEach( {
          if ( -not (& $_.Test)) {
            Write-Warning -Message "Test condition of [$($_.Label)] not passed. Remediating..."
            & $_.Action
          } else {
            Write-Verbose -Message "Test condition passed."
          }
        })
    }

    It "ARM template validation is successful" {

      $deploymentArgs = @{
        Scope                     = "$deploymentScope"
        SubscriptionId            = "$subscriptionId"
        TemplateFilePath          = "$bicepDirectory\main.json"
        TemplateParameterFilePath = "$bicepDirectory\main.parameters.int.json"
        Location                  = "$location"
        Validate                  = $true
      }

      $result = Invoke-ARMDeployment @deploymentArgs
      $result.error | Should -BeNullOrEmpty
    }
  }
}
