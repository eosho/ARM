function Get-PipelineLoggerTimeStamp {
  <#
  .SYNOPSIS
    Time stamp generator

  .DESCRIPTION
    Time stamp generator

  .NOTES
    General notes
  #>
  return $(Get-Date).ToUniversalTime().ToString("[yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z']") + ' -'
}

function Write-PipelineLogger {
  <#
  .SYNOPSIS
    Script logging function

  .DESCRIPTION
    Script logging function to log Azure DevOps console

  .INPUTS
    Inputs (if any)

  .OUTPUTS
    Output (if any)

  .NOTES
    General notes
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("info", "debug", "error", "warning", "success")]
    [string] $LogType,

    [Parameter(Mandatory = $true)]
    [string] $Message,

    [switch] $NoFailOnError
  )

  begin { }

  process {

    # print appropriate logging message
    if ($LogType -eq "info") {
      $color = "gray"
      $message = "$(Get-PipelineLoggerTimeStamp) [info]: $Message"
    } elseif ($LogType -eq "debug") {
      $color = "magenta"
      $message = "$(Get-PipelineLoggerTimeStamp) [debug]: $Message"
    } elseif ($LogType -eq "error") {
      $color = "red"
      $message = "$(Get-PipelineLoggerTimeStamp) [error]: $Message"
    } elseif ($LogType -eq "warning") {
      $color = "yellow"
      $message = "$(Get-PipelineLoggerTimeStamp) [warning]: $Message"
    } elseif ($LogType -eq "success") {
      $color = "green"
      $message = "##[section]$(Get-PipelineLoggerTimeStamp) [success]: $Message"
    } else {
      Throw "Invalid Log Type selected."
    }

    if (($LogType -eq "error") -and (-not $NoFailOnError.IsPresent)) {
      Write-Error $message -ErrorAction Stop
    } elseif ($SilentMode) {
      return
    } else {
      Write-Host $message -ForegroundColor $color
    }
  }

  end {}
}


function ConvertTo-HashTable {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $false)]
    $InputObject
  )

  if ($InputObject) {
    # Convert to string prior to converting to hashtable
    $objectString = ConvertTo-Json -InputObject $InputObject -Depth 100

    # Convert string to hashtable and return it
    return ConvertFrom-Json -InputObject $objectString -AsHashtable;
  } else {
    return $null;
  }
}

function Get-NestedResourceList {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [object] $TemplateContent
  )

  $res = @()
  $currLevelResources = @()
  if ($TemplateContent.resources) {
    $currLevelResources += $TemplateContent.resources
  }
  foreach ($resource in $currLevelResources) {
    $res += $resource

    if ($resource.type -eq 'Microsoft.Resources/deployments') {
      $res += Get-NestedResourceList -TemplateContent $resource.properties.template
    } else {
      $res += Get-NestedResourceList -TemplateContent $resource
    }
  }
  return $res
}

function Convert-PSObjectToHashtable {
  param (
    [Parameter(ValueFromPipeline)]
    $InputObject
  )

  process {
    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
      $collection = @(
        foreach ($object in $InputObject) { Convert-PSObjectToHashtable $object }
      )

      Write-Output -NoEnumerate $collection
    } elseif ($InputObject -is [psobject]) {
      $hash = @{}

      foreach ($property in $InputObject.PSObject.Properties) {
        $hash[$property.Name] = Convert-PSObjectToHashtable $property.Value
      }

      $hash
    } else {
      $InputObject
    }
  }
}
