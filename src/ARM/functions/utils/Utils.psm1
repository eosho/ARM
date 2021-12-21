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
      $message = ""##[section]$(Get-PipelineLoggerTimeStamp) [success]: $Message""
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

function Get-TemplateType {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string] $TemplateFilePath
  )

  # Determine the template type - .bicep or .json
  if ((Split-Path -Path $TemplateFilePath -Extension) -eq '.bicep') {
    Write-PipelineLogger -LogType "info" -Message "[$($MyInvocation.MyCommand)] - Template is in .bicep format, converting it to an object"
    $templateObj = az bicep build --file $TemplateFilePath --stdout | ConvertFrom-Json
  } elseif ((Split-Path -Path $TemplateFilePath -Extension) -eq '.json') {
    Write-PipelineLogger -LogType "info" -Message "[$($MyInvocation.MyCommand)] - Template is in .json format, converting it to an object"
    $templateObj = Get-Content $TemplateFilePath | ConvertFrom-Json
  } else {
    Write-PipelineLogger -LogType "error" -Message "[$($MyInvocation.MyCommand)] - Template is not in .bicep or .json format"
  }

  return $templateObj
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
