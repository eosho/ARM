<#
.SYNOPSIS
  This script performs QA tests on your entire repository.

.DESCRIPTION
  This script performs QA tests on your entire repository.
  It will grab all bicep file and build them to ARM JSON for testing.

.EXAMPLE
  PS C:\> tests\qa\QA.tests.ps1

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
  [string] $rootDirectory = (Join-Path -Path $projectDirectory -ChildPath "../../../"),
  [string] $bicepDirectory = (Join-Path -Path $projectDirectory -ChildPath "../../../bicep/modules"),
  [array] $moduleFolderPaths = ((Get-ChildItem (Split-Path $bicepDirectory -Parent) -Recurse -Directory -Force).FullName | Where-Object {
      (Get-ChildItem $_ -File -Depth 0 -Include @('deploy.json', 'deploy.bicep') -Force).Count -gt 0
    })
)

$script:rgDeployment = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
$script:subscriptionDeployment = 'https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#'

# check pester module is installed
$pesterInstalled = Get-Command -Name Invoke-Pester -ErrorAction SilentlyContinue
if ($null -eq $pesterInstalled) {
  Write-Error 'Pester is not installed but is required to run QA. Fix by installing Pester (Install-Module Pester)' -ErrorAction Stop
}

Describe 'Repo structure' {
  Context 'Repo structure' {
    It 'Project file and directory structure should be as expected' {
      $projectItems = Get-ChildItem -Path $rootDirectory -Force

      '.azdo',
      '.codeanalysis',
      '.config',
      'bicep',
      'docs',
      'external',
      'hooks',
      'src' | Should -BeIn $projectItems.Where{ $_.PSIsContainer }.Name

      'CODE_OF_CONDUCT.md',
      'CONTRIBUTING.md',
      'SUPPORT.md'
      'README.md',
      'Setup.ps1'
      '.gitignore' | Should -BeIn $projectItems.Where{ -not $_.PSIsContainer }.Name
    }
  }
}

Describe 'File/folder tests' -Tag Modules {

  Context 'General module folder tests' {

    $moduleFolderTestCases = [System.Collections.ArrayList] @()
    foreach ($moduleFolderPath in $moduleFolderPaths) {
      $moduleFolderTestCases += @{
        moduleFolderName = $moduleFolderPath.Replace('\', '/').Split('/bicep/modules/')[1]
        moduleFolderPath = $moduleFolderPath
      }
    }

    It '[<moduleFolderName>] Module should contain a [deploy.json/deploy.bicep] file' -TestCases $moduleFolderTestCases {
      param(
        $moduleFolderName,
        $moduleFolderPath
      )

      $hasARM = (Test-Path (Join-Path -Path $moduleFolderPath 'deploy.json'))
      $hasBicep = (Test-Path (Join-Path -Path $moduleFolderPath 'deploy.bicep'))
      ($hasARM -or $hasBicep) | Should -Be $true
    }
  }
}

Describe 'Quality Assurance Tests' {

  Context 'Deployment template tests' {
    $deploymentFolderTestCases = [System.Collections.ArrayList] @()
    foreach ($moduleFolderPath in $moduleFolderPaths) {

      if (Test-Path (Join-Path $moduleFolderPath 'deploy.bicep')) {
        $templateContent = az bicep build --file (Join-Path $moduleFolderPath 'deploy.bicep') --stdout | ConvertFrom-Json -AsHashtable
      } elseif (Test-Path (Join-Path $moduleFolderPath 'deploy.json')) {
        $templateContent = Get-Content (Join-Path $moduleFolderPath 'deploy.json') -Raw | ConvertFrom-Json -AsHashtable
      } else {
        throw "No template file found in folder [$moduleFolderPath]"
      }

      # Parameter file test cases
      $parameterFileTestCases = @()

      # Test file setup
      $deploymentFolderTestCases += @{
        moduleFolderName       = $moduleFolderPath.Replace('\', '/').Split('/bicep/modules/')[1]
        templateContent        = $templateContent
        parameterFileTestCases = $parameterFileTestCases
      }
    }

    It '[<moduleFolderName>] Template file should not be empty' -TestCases $deploymentFolderTestCases {
      param(
        $moduleFolderName,
        $templateContent
      )

      $templateContent | Should -Not -Be $null
    }

    It '[<moduleFolderName>] template file should contain required elements: schema, contentVersion, parameters, resources, outputs' -TestCases $deploymentFolderTestCases {
      param (
        $moduleFolderName,
        $templateContent
      )

      $templateContent.Keys | Should -Contain '$schema'
      $templateContent.Keys | Should -Contain 'contentVersion'
      $templateContent.Keys | Should -Contain 'parameters'
      $templateContent.Keys | Should -Contain 'resources'
      $templateContent.Keys | Should -Contain 'outputs'
    }

    It '[<moduleFolderName>] Schema URI should use https and latest apiVersion' -TestCases $deploymentFolderTestCases {
      # the actual value changes depending on the scope of the template (RG, subscription) !!
      # https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/template-syntax
      param (
        $moduleFolderName,
        $templateContent
      )

      $schemaVersion = $templateContent.'$schema'
      $schemaArray = @()
      if ($schemaVersion -eq $rgDeployment) {
        $schemaOutput = $true
      } elseif ($schemaVersion -eq $subscriptionDeployment) {
        $schemaOutput = $true
      } else {
        $schemaOutput = $false
      }

      $schemaArray += $schemaOutput
      $schemaArray | Should -Not -Contain $false
    }

    It '[<moduleFolderName>] Template schema should use HTTPS reference' -TestCases $deploymentFolderTestCases {
      param(
        $moduleFolderName,
        $templateContent
      )
      $schemaVersion = $templateContent.'$schema'
      ($schemaVersion.Substring(0, 5) -eq 'https') | Should -Be $true
    }

    It '[<moduleFolderName>] Parameter names should be camel-cased (no dashes or underscores and must start with lower-case letter)' -TestCases $deploymentFolderTestCases {
      param(
        $moduleFolderName,
        $templateContent
      )

      if (-not $templateContent.parameters) {
        $true | Should -Be $true
        return
      }

      $camelCasingFlag = @()
      $parameters = $templateContent.parameters.Keys
      foreach ($parameter in $parameters) {
        if ($parameter.substring(0, 1) -cnotmatch '[a-z]' -or $parameter -match '-' -or $parameter -match '_') {
          $camelCasingFlag += $false
        } else {
          $camelCasingFlag += $true
        }
      }
      $camelCasingFlag | Should -Not -Contain $false
    }

    It '[<moduleFolderName>] Variable names should be camel-cased (no dashes or underscores and must start with lower-case letter)' -TestCases $deploymentFolderTestCases {
      param(
        $moduleFolderName,
        $templateContent
      )

      if (-not $templateContent.variables) {
        $true | Should -Be $true
        return
      }

      $camelCasingFlag = @()
      $variables = $templateContent.variables.Keys

      foreach ($variable in $variables) {
        if ($variable.substring(0, 1) -cnotmatch '[a-z]' -or $variable -match '-') {
          $camelCasingFlag += $false
        } else {
          $camelCasingFlag += $true
        }
      }
      $camelCasingFlag | Should -Not -Contain $false
    }

    It '[<moduleFolderName>] Every parameter must have a {"metadata" : {"description":""}} element and value' -TestCases $deploymentFolderTestCases {
      param (
        $moduleFolderName,
        $templateContent
      )

      $templateParameters = $templateContent.parameters.Keys

      foreach ($parameter in $templateParameters) {
        if (($templateContent.parameters.$parameter.metadata).description) {
          $metadataPresent = $true
        } else {
          $metadataPresent = $false
        }
      }
      $metadataPresent | Should -Not -Be $false
    }

    It '[<moduleFolderName>] Every resource must have a literal apiVersion' -TestCases $deploymentFolderTestCases {
      param (
        $moduleFolderName,
        $templateContent
      )
      if ($templateContent.resources.Count -gt 0) {
        $templateContent.resources.ForEach{
          $_.apiVersion | Should -MatchExactly "^\d{4}-\d{2}-\d{2}(-preview)?"
        }
      }
    }

    # It '[<moduleFolderName>] Does not have unused parameters defined' -TestCases $deploymentFolderTestCases {
    #   param (
    #     $moduleFolderName,
    #     $templateContent
    #   )
    #   $rawContent = Get-Content -Path $File -Raw
    #   $templateContent.parameters.PSObject.Properties.Name.ForEach{
    #     $rawContent | Should -Match "parameters\('$_'\)" -Because "Unused Parameter '$_'"
    #   }
    # }

    # It '[<moduleFolderName>] Does not have unused variables defined' -TestCases $deploymentFolderTestCases {
    #   param (
    #     $moduleFolderName,
    #     $templateContent
    #   )
    #   $rawContent = Get-Content -Path $File -Raw
    #   $templateContent.variables.PSObject.Properties.Name.ForEach{
    #     # exclude copy variable name
    #     if ($_ -ne 'copy') {
    #       $rawContent | Should -Match "variables\('$_'\)" -Because "Unused Variable '$_'"
    #     }
    #   }
    # }

    It "[<moduleFolderName>] The Location should be defined as a parameter, with the default value of 'resourceGroup().Location' or global for ResourceGroup deployment scope" -TestCases $deploymentFolderTestCases {
      param(
        $moduleFolderName,
        $templateContent
      )

      $locationFlag = $true
      $schemaVersion = $templateContent.'$schema'
      if ((($schemaVersion.Split('/')[5]).Split('.')[0]) -eq (($RGdeployment.Split('/')[5]).Split('.')[0])) {
        $locationParamOutputValue = $templateContent.parameters.location.defaultValue
        $locationParamOutput = $templateContent.parameters.Keys
        if ($locationParamOutput -contains 'Location') {
          if ($locationParamOutputValue -eq '[resourceGroup().Location]' -or $locationParamOutputValue -eq 'global') {
            $locationFlag = $true
          } else {
            $locationFlag = $false
          }

          $locationFlag | Should -Contain $true
        }
      }
    }
  }
}
