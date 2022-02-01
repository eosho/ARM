[CmdletBinding()]
Param (
  [switch] $SkipTest
)

$rootPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$commandPath = @(
  "$rootPath\..\..\functions",
  "$rootPath\..\..\internal\functions"
)

if ($SkipTest) { return }

$failures = New-Object System.Collections.ArrayList

Describe 'Invoking PSScriptAnalyzer against commandbase' {
  $commandFiles = foreach ($path in $CommandPath) { Get-ChildItem -Path $path -Recurse | Where-Object Name -like "*.ps1" }
  $scriptAnalyzerRules = Get-ScriptAnalyzerRule

  foreach ($file in $commandFiles) {
    Context "Analyzing $($file.BaseName)" {
      $analysis = Invoke-ScriptAnalyzer -Path $file.FullName -ExcludeRule PSAvoidTrailingWhitespace, PSShouldProcess, PSUseShouldProcessForStateChangingFunctions

      forEach ($rule in $scriptAnalyzerRules) {
        It "Should pass $rule" -TestCases @{ analysis = $analysis; rule = $rule } {
          If ($analysis.RuleName -contains $rule) {
            $analysis | Where-Object RuleName -EQ $rule -OutVariable failures | ForEach-Object { $null = $failures.Add($_) }
            1 | Should -Be 0
          } else {
            0 | Should -Be 0
          }
        }
      }
    }
  }
}
