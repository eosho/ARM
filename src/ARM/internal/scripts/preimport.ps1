﻿# Place all code that should be run before functions are imported here

[CmdletBinding()]
param (
  [Parameter()]
  [string] $ModuleInstallScope = 'CurrentUser'
)

# Import common & utility functions
Get-ChildItem -Path  $(Split-Path -Parent $MyInvocation.MyCommand.Definition) -Recurse -Filter '*.psm1' | ForEach-Object { $_.FullName } | ForEach-Object { Import-Module $_ -Force }

# Install required modules
$modules = @(
  @{
    Name       = 'Pester'
    Repository = 'PSGallery'
  }
  @{
    Name       = 'PSScriptAnalyzer'
    Repository = 'PSGallery'
  }
  @{
    Name       = 'PSModuleDevelopment'
    Repository = 'PSGallery'
  }
)

Write-Output "Starting module import..."
Write-Output "Checking module dependencies..."

foreach ($module in $modules) {
  try {
    $installedModule = Get-InstalledModule -Name $module.Name -ErrorAction SilentlyContinue

    if (-not ($installedModule)) {
      Write-Output "Installing: [$($module.Name)] from [$($module.Repository)]"
      $checkModule = Install-Module -Name $module.Name -Repository $module.Repository -Force -AllowClobber -SkipPublisherCheck -Scope $moduleInstallScope | Import-Module -Force

      if ($checkModule) {
        Write-Output "Installed the installed module: [$($checkModule.Name)] - [$($checkModule.Version)]"
      }
    } else {
      Write-Output "Located the installed module: [$($installedModule.Name)] - [$($installedModule.Version)]"
    }
  } catch {
    WWrite-Output "Failed to install module: [$($module.Name)] from [$($module.Repository)]. Details: $($_.Exception.Message)."
  }
}
