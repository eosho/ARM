<#
.SYNOPSIS
  Queue an infrastructure deployment build through the Common Cloud Platforms pipeline

.LINK
  For a full documentation on how to use the script, please visit this link:
  https://dev.azure.com/WBA/IT%20Services/_git/ccp-ent-infra-build?path=%2FPIPELINE_TRIGGER.md&version=GBmaster&_a=preview&anchor=powershell-script
#>

[CmdletBinding()]
param (
  [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][Alias("ParameterFile")][string[]]$ParameterFiles,
  [Alias("TemplateFile")][string[]]$TemplateFiles,
  [string]$BranchName = "master",
  [switch]$OpenInBrowser,
  [ValidateSet("buildOnly", "buildAndDeploy")][string]$PipelineStage = "buildOnly",
  [switch]$ScriptDebug,
  [switch]$SilentMode
)

function Get-TimeStamp {
  return (Get-Date -F "yyyy-MM-dd HH:mm:ss") + " ::"
}

function Logger {
  [CmdletBinding()]
  param (
    [ValidateSet("error", "warning", "success", "info", "debug")][string]$type,
    [Parameter(Mandatory = $true)][string]$message,
    [int]$exitCode
  )

  if ($type -eq "debug" -and -Not $ScriptDebug) {
    return
  }

  # just to mark the script running from an ado pipeline so proper write-host message get printed there
  if ($env:SYSTEM_DEFAULTWORKINGDIRECTORY) {
    $pipelineErrorMessageRed = "##[error]"            # red
    $pipelineWarningMessageOrange = "##[warning]"     # orange
    $pipelineSuccessMessageGreen = "##[section]##[success]"      # green
    $pipelineInfoMessageBlue = "##[command]##[info]"          # blue
    $pipelineDebugMessagePurple = "##[debug]"         # purple
  }

  if ($type -eq "error") {
    $message = "$pipelineErrorMessageRed$(Get-TimeStamp) ERROR: $message" # red
    $foregroundColor = "red"
  } elseif ($type -eq "warning") {
    $message = "$pipelineWarningMessageOrange$(Get-TimeStamp) WARNING: $message" # orange
    $foregroundColor = "DarkYellow"
  } elseif ($type -eq "success") {
    $message = "$pipelineSuccessMessageGreen$(Get-TimeStamp) SUCCESS: $message" # green
    $foregroundColor = "green"
  } elseif ($type -eq "info") {
    $message = "$pipelineInfoMessageBlue$(Get-TimeStamp) INFO: $message" # blue
    $foregroundColor = "blue"
  } elseif ($type -eq "debug") {
    $message = "$pipelineDebugMessagePurple$(Get-TimeStamp) DEBUG: $message" # purple
    $foregroundColor = "yellow"
  }

  if ($type -eq 'error') {
    if (-Not $exitCode) {
      Throw "You need to pass exit code when it's error message"
    }

    Logger -type 'warning' -message "Triggering the CCP Pipeline failed"
    Logger -type 'warning' -message "For more details about trigger-ccp-pipeline.ps1 script, please visit https://dev.azure.com/WBA/IT%20Services/_git/ccp-ent-infra-build?path=%2FPIPELINE_TRIGGER.md&_a=preview"

    Write-Host $message -ForegroundColor $foregroundColor
    # Logger -type 'error' -message "Error Message: $exceptionMessage"
    Logger -type 'warning' -message "If you still need help with your deployment, please send an email to [CommonCloudPlatform@walgreens.com] including the above details, the script output and the parameter file your using"
    Logger -type 'warning' -message  "If you're deployment is not being queued at all, run the script with -ScriptDebug switch and include that output with your email as well"
    $scriptFinishTime = Get-Date
    $timeSpan = New-TimeSpan -Start $scriptStartTime -End $scriptFinishTime
    $timeSpanFormatted = '{0:hh}:{0:mm}:{0:ss}' -f $timeSpan
    Logger -type 'info' -message "PowerShell exited with code '$exitCode'"
    Logger -type 'info' -message "Script Finished. Took $timeSpanFormatted to finish"
    exit $exitCode
  } elseif ($SilentMode) {
    return
  } else {
    Write-Host $message -ForegroundColor $foregroundColor
  }
}

function Invoke-ValidatePrerequisite {
  Logger -type 'debug' -message "Checking prerequisites"

  try {
    Logger -type 'debug' -message "Checking if Azure CLI is installed (by running 'az --version' command)"
    $version = az --version *>&1
  } catch {
    if ($_.Exception.Message -NotLike "*Consider updating your CLI installation*") {
      Logger -type 'error' -message $_.Exception.Message -exitCode 1
    }
  }

  try {
    $AzureCliVersion = $version | Where-Object { $_ -like "azure-cli*" }
    $AzureCliVersion = $AzureCliVersion.Split(" ")
    $AzureCliVersion = $AzureCliVersion | Where-Object { $_ -match "(?<number>\d)" }
  } catch {
    Logger -type 'debug' -message "Couldn't determine the version of Azure CLI currently installed"
  }
  Logger -type 'debug' -message "Azure CLI is installed with version [$AzureCliVersion]"

  # To check whether the user is logged in or not
  Logger -type 'debug' -message "Checking if Azure CLI is logged in (by running 'az account show' command)"
  az account show *>&1 | Out-Null
  if (-Not $?) {
    Logger -type 'error' -message "Azure CLI doesn't seem to be logged in ('az account show' command is failing).
    If you are using the script interactively, use 'az login' command first ad follow the steps.
    If you are using the script in an automated fashion (like running it from another pipeline) make sure you run 'az login -u <username>  -p <password>' before invoking the trigger-ccp-pipeline.ps1 script.
    IMPORTANT: passing the username and password as plain text is extremely dangerous, the best practice is to pass the credentials as variables to command above, maybe by getting those from a secured place like a keyvault" -exitCode 1
  } else {
    # TODO: need to add the user who is logged in in the debug message, need to re work the error handling above
    Logger -type 'debug' -message "Azure CLI is logged in"
  }

  # To check whether the DevOps extension is installed or not
  Logger -type 'debug' -message "Checking if Azure CLI devOps extension is installed (by running 'az pipelines -h' command)"
  az pipelines -h *>&1 | Out-Null
  if (-Not $?) {
    Write-Error "Azure CLI DevOps extension is not installed. Please refer to the below link for prerequisites details:
    https://dev.azure.com/WBA/IT%20Services/_git/ccp-ent-infra-build?path=%2FPIPELINE_TRIGGER.md&version=GBmaster&_a=preview&anchor=prerequisites"
  }
  Logger -type 'debug' -message "Azure CLI devOps extension is installed"
  Logger -type 'debug' -message "Client has all prerequisite required to run the script, proceeding"
}

function Invoke-FileNamesValidations ($ParameterFilesNamesList, $TemplateFilesNamesList) {
  # having the parameter word in the file name is required for the pipeline.
  foreach ($file in $ParameterFilesNamesList) {
    if (-Not ($file -Like "*parameter*") ) {
      Logger -type 'error' -message "$file does not have the word [parameter] in it, please make sure the name of the file has [parameter] word in it" -exitCode 1
    }
  }

  # having the template word in the file name is required for the pipeline.
  foreach ($file in $TemplateFilesNamesList) {
    if (-Not ($file -Like "*template*") ) {
      Logger -type 'error' -message "$file does not have the word [template] in it, please make sure the name of the file has [template] word in it" -exitCode 1
    }
  }
}

function Check-NameDuplicity ($ParameterFiles, $TemplateFiles) {
  # logic to prevent duplicate file names as all parameters/template files will reside in one directory
  $allArtifacts = @()
  $allArtifacts += $ParameterFiles

  if ($TemplateFiles) {
    $allArtifacts += $TemplateFiles
  }

  $allArtifactsFilesNames = Split-Path $allArtifacts -Leaf

  $allArtifactsFilesNamesUnique = $allArtifactsFilesNames | Select-Object -unique
  $duplicateFileNames = Compare-object -referenceobject $allArtifactsFilesNamesUnique -differenceobject $allArtifactsFilesNames
  if ($duplicateFileNames) {
    Logger -type 'error' -message "Using duplicate file names are not supported, make sure all file names are unique, duplicate files names: $($duplicateFileNames.InputObject)" -exitCode 1
  }

  foreach ($artifact in $allArtifacts) {
    if (-Not (Test-Path $artifact)) {
      Logger -type 'error' -message "Cannot find file '$artifact' because it does not exist" -exitCode 1
    }
  }
  return $allArtifacts
}

function Building-ArtifactsList ($ParameterFiles, $TemplateFiles) {
  if ($ParameterFiles) {
    if ( (Split-Path $ParameterFiles -Leaf ).count -eq 1 ) {
      $parameterFilesNamesList = (Split-Path $ParameterFiles -Leaf )
    } else {
      $parameterFilesNamesList = (Split-Path $ParameterFiles -Leaf ) -join ","
    }
  }

  if ( $TemplateFiles ) {
    if ((Split-Path $TemplateFiles -Leaf).count -eq 1) {
      $templateFilesNamesList = (Split-Path $TemplateFiles -Leaf)
    } else {
      $templateFilesNamesList = (Split-Path $TemplateFiles -Leaf) -join ","
    }
  }

  $artifactsFileNames = @{
    parameterFilesNamesList = $parameterFilesNamesList
    templateFilesNamesList  = $templateFilesNamesList
  }

  return $artifactsFileNames
}

function Invoke-QueuePipeline {
  param (
    [Parameter(Mandatory = $true)][string]$storageAccountSubscription,
    [Parameter(Mandatory = $true)][string]$storageAccountRg,
    [Parameter(Mandatory = $true)][string]$storageAccount,
    [Parameter(Mandatory = $true)][string]$blobContainer,
    [Parameter(Mandatory = $true)][string]$artifactGuid
  )

  if ($OpenInBrowser) {
    $azOpen = "--open"
  }

  $templateFileInDeploymentParameters = (get-content $ParameterFiles | ConvertFrom-Json).deploymentParameters.templateFile

  try {
    $triggerScriptName = Split-Path $PSCommandPath -Leaf
    $azPipelineResults = az pipelines build queue `
      --org $orgUrl `
      --project $project `
      --branch $BranchName `
      --definition-id $pipelineDefinitionId `
      --variables "scriptFileHash=$scriptFileHash" `
      "triggerBy=triggerScript" `
      "scriptDebug=$ScriptDebug" `
      "triggerScriptName=$triggerScriptName" `
      "artifactsGuid=$artifactGuid" `
      "parameterFiles=$parameterFilesNamesList" `
      "templateFiles=$templateFilesNamesList" `
      "templateFileInDeploymentParameters=$templateFileInDeploymentParameters" `
      "blobContainer=$blobContainer" `
      "storageAccount=$storageAccount" `
      "storageAccountRg=$storageAccountRg" `
      "storageAccountSubscription=$storageAccountSubscription" `
      "pipelineStage=$PipelineStage" $azOpen --debug *>&1
  } catch {

  }

  Logger -type 'debug' -message "azPipelineResults: $azPipelineResults"
  # check if the response content has an error in it. Then parse and error out
  foreach ($message in $azPipelineResults) {
    if ($message -like "*DEBUG: azext_devops.devops_sdk.client : Response content*" -and $message -like "*error*" -and $message -NotLike "*`"errorCode`":0*" ) {
      $errorMessage = $message | Out-String
      $errorMessage = $errorMessage.substring($errorMessage.LastIndexOf("'{`"$id"))
      Logger -type 'error' -message $errorMessage  -exitCode 10
    }
  }

  # no need to parse if -ScriptDebug switch is not passed
  foreach ($message in $azPipelineResults) {
    if ($message -like "*azext_devops.devops_sdk.client : Request content:*" -and $message -like "*definition*" ) {
      $debugMessage = $message | Out-String
      $debugMessage = $debugMessage.substring($debugMessage.IndexOf("{'definition':"))
      # TODO: need to convert to json to proper reading
      Logger -type 'debug' -message "Request content: $($debugMessage)"
    }
  }

  # Couldn't get the --debug result separately, the entire response with the --debug is one variable so I have to extract the response from there
  $previousRow = ""
  $starStoringResponse = $false
  $responseJson = ""
  foreach ($element in $azPipelineResults) {
    # the debugging messages get in the middle of the output in the array response !!
    if ($element -like "DEBUG:*" -or $element -like "INFO:*" -or $element -like "WARNING:*") {
      continue
    }
    if ($element -like "*`"buildNumber`": *") {
      $starStoringResponse = $true
    }
    if ($starStoringResponse) {
      $responseJson += $previousRow
    }
    if ($element -like "}*" -and $previousRow -like "*validationResults*") {
      $responseJson += $element
      break
    }
    $previousRow = $element
  }

  if (-Not $responseJson) {
    Logger -type 'error' -message "Didn't get any response to parse from 'az pipelines build queue', this more than likely related to an access issue. `nMake sure your session is logged in by running 'az login' before running the script" -exitCode 1
  }

  # incase the response is messed up for any reason and can't parse it as a json object (like DevOps is changing how they return the --debug output or changing how the response payload format)
  try {
    $azPipelineResultsObj = $responseJson | ConvertFrom-Json
  } catch {
    Logger -type 'error' -message "Failed to check the status of the build, cannot parse the response from [az pipelines build queue]
      $($_.Exception.Message)
      Open the below link in a browner to get more details about your build failure
      https://dev.azure.com/WBA/IT%20Services/_build/results?buildId=$($azPipelineResultsObj.id)&view=results]" -exitCode 10
  }

  Logger -type 'info' -message "Pipeline build queued successfully with Build ID: [$($azPipelineResultsObj.id)]"

  while (1) {
    Logger -type 'info' -message "build status: $($azPipelineResultsObj.status)"
    Logger -type 'info' -message "Checking status in 30 seconds"
    Start-Sleep 30

    # TODO:
    # try catch
    # az pipelines build show --id $azPipelineResultsObj.id --org $orgUrl --project $project *>&1
    try {
      $azPipelineResults = az pipelines build show --id $azPipelineResultsObj.id --org $orgUrl --project $project *>&1
    } catch {
    }

    try {
      $azPipelineResultsObj = $azPipelineResults | ConvertFrom-Json
    } catch {
      Logger -type 'error' -message "Cannot check the status of your build, the command 'az pipelines build show' is failing
      $azPipelineResultsObj
      Open the below link in a browner to get more details about your build failure
      https://dev.azure.com/WBA/IT%20Services/_build/results?buildId=$($azPipelineResultsObj.id)&view=results]" -exitCode 10
    }

    # checking the status of the queued build
    if ($azPipelineResultsObj.status -eq "completed") {
      if ($azPipelineResultsObj.result -eq "succeeded") {
        Logger -type 'success' -message "Pipeline build has been completed with a result of [$($azPipelineResultsObj.result)]"
      } else {
        Logger -type 'error' -message "Pipeline build has been completed with a result of [$($azPipelineResultsObj.result)] you can get more details about your build by opening the following link in your browser: `nhttps://dev.azure.com/WBA/IT%20Services/_build/results?buildId=$($azPipelineResultsObj.id)&view=results" -exitCode 10
      }
      Break
    }
  } # while loop for checking build status
}

function Send-FileToStorage ($storageAccount, $container, $path = "", $fileName, $fileContentBase64, $logicAppUri) {
  $headers = @{
    "content-type"      = "application/json"
    "StorageAccount"    = $storageAccount
    "Container"         = $container
    "Path"              = $path
    "FileName"          = $fileName
  }

  $body = @{
    "FileContentBase64" = $fileContentBase64
  }

  $retry = 3
  do {
    try {
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 # the use of TLS 1.2 is required by logic apps
      $response = Invoke-RestMethod -Method Post -Headers $headers -Body ($body | ConvertTo-Json) -Uri $logicAppUri #-ErrorAction Stop
      $success = $true
    } catch {
      Logger -type 'debug' -message "Failed to send, next attempt in 5 seconds"
      $exception = $_.Exception.Message
    }
    $count++
  } until($count -eq $retry -or $success)

  if (-not($success)) {
    throw $exception
  }
}

function Send-AllArtifacts ($allArtifacts) {
  foreach ($destination in $artifactsDestinations.GetEnumerator()) {
    $failedSending = $false
    Logger -type 'debug' -message "Sending artifacts through [$($destination.Name)] region"
    foreach ($fileToSend in $allArtifacts) {
      Logger -type 'debug' -message "Sending file: [$fileToSend]"
      try {
        $fileName = Split-Path $fileToSend -Leaf # to get the file name
        Logger -type 'debug' -message "fileName to send: $fileName"
        $fileToSendContent = Get-Content $fileToSend -Raw
        $fileContentBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($fileToSendContent))
        $response = Send-FileToStorage -storageAccount $destination.Value.StorageAccount -container $container -fileName $fileName -fileContentBase64 $fileContentBase64 -LogicAppUri $destination.Value.logicAppUri -path "$artifactGuid/"
        Logger -type 'debug' -message "File: [$fileToSend] sent Successfully"
      } catch {
        Logger -type 'debug' -message "Failed to send artifact [$fileToSend] through region [$($destination.Name)]"
        Logger -type 'warning' -message "$($_.Exception.Message)"
        $customExceptionMessage = ($_.Exception.Response.Headers | Where-Object { $_.Key -eq "NonSuccessfulBodyResponse" }).Value
        if ($customExceptionMessage) {
          Logger -type 'debug' -message "$customExceptionMessage"
        }
        $failedSending = $true
      }

      # to fail if any file in the list fails to get sent (by breaking the inner loop for all the files needs to be sent)
      if ($failedSending -eq $true) {
        break
      }
    }
    if ($($destination.Name) -eq "eastus2" -and $failedSending -eq $false ) {
      Logger -type 'debug' -message "Successfully sent all artifact through [eastus2]. No need to to try [centralus] region"
      $artifactsRegion = $destination
      break
    } elseif ($($destination.Name) -eq "centralus" -and $failedSending -eq $false) {
      Logger -type 'debug' -message "Successfully sent all artifacts through [centralus]."
      $artifactsRegion = $destination
      break
    } elseif ($($destination.Name) -eq "centralus" -and $failedSending -eq $true) {
      Logger -type 'error' -message "At least one artifact failed to get sent through [eastus2] or [centralus] regions" -exitCode 1
    }
  }
  return $artifactsRegion
}

###################################################################
#################### Script starts here ###########################
###################################################################
Logger -type 'info' -message "Script Started"

$scriptStartTime = Get-Date

if ($ScriptDebug) {
  $DebugPreference = 'Continue'
}


if ($env:SYSTEM_DEFAULTWORKINGDIRECTORY) {
  Logger -type 'debug' -message "Script has been triggered from another pipeline"
}

$artifactGuid = New-Guid
$container = "artifacts"

# az pipeline build queue related variables
$orgUrl = "https://dev.azure.com/WBA"
$project = "IT Services"
$pipelineDefinitionId = 51 # this is the definition number for the ccp-ent-infra-build pipeline. you can get it from this link https://dev.azure.com/WBA/IT%20Services/_build?definitionId=51&_a=summary
$artifactsDestinations = [ordered]@{
  eastus2   = @{
    "subscription"   = "gs-prod-am-management-01"
    "resourceGroup"  = "prod-ccp-pipeline-eastus2-01"
    "storageAccount" = "prodccppipelineeus201"
    "logicAppUri"    = "https://prod-08.eastus2.logic.azure.com:443/workflows/386c883e6bc943668854ef3d94053f17/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=1S8iWsLgEGW5WXN4L3lie5atl8A25aSM3o91ViB35Fw"
  }
  centralus = @{
    "subscription"   = "gs-prod-am-management-01"
    "resourceGroup"  = "prod-ccp-pipeline-centralus-01"
    "storageAccount" = "prodccppipelinecus01"
    "logicAppUri"    = "https://prod-11.centralus.logic.azure.com:443/workflows/7c8cdcf8b90e486dab10e577c8a8b12f/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=iu4cZz0qnhzksqhDwQlxJjZ-2ymH5I6uWDTxdaFT7Q0"
  }
}

if (($ParameterFile -like "*,*") -or ($TemplateFile -like "*,*") ) {
  Logger -type 'error' -message "Submitting multiple parameter files is not a supported feature, please submit one parameter at a time while you invoke the trigger script and try again, exiting ..." -exitCode 1
}

# TODO:
Invoke-ValidatePrerequisite
$artifactsFileNames = Building-ArtifactsList -ParameterFiles $ParameterFiles -TemplateFiles $TemplateFiles
$parameterFilesNamesList = $artifactsFileNames.parameterFilesNamesList
$templateFilesNamesList = $artifactsFileNames.templateFilesNamesList
Invoke-FileNamesValidations -ParameterFilesNamesList $parameterFilesNamesList -TemplateFilesNamesList $templateFilesNamesList
$allArtifacts = [array](Check-NameDuplicity -ParameterFiles $ParameterFiles -TemplateFiles $TemplateFiles)
$allArtifacts += $PSCommandPath # Send the trigger script itself to help debugging/troubleshooting and to verify if the user had made any changes on the script
Logger -type 'debug' -message "PSCommandPath: $PSCommandPath"
$artifactsRegionUsed = Send-AllArtifacts -allArtifacts $allArtifacts

$storageAccount = $artifactsRegionUsed.Value.storageAccount
$storageAccountRg = $artifactsRegionUsed.Value.resourceGroup
$storageAccountSubscription = $artifactsRegionUsed.Value.subscription

Invoke-QueuePipeline -storageAccountSubscription $storageAccountSubscription -storageAccountRg $storageAccountRg -storageAccount $storageAccount -blobContainer $container -artifactGuid $artifactGuid

$scriptFinishTime = Get-Date
$timeSpan = New-TimeSpan -Start $scriptStartTime -End $scriptFinishTime
$timeSpanFormatted = '{0:hh}:{0:mm}:{0:ss}' -f $timeSpan
Logger -type 'info' -message "Script Finished. Took $timeSpanFormatted to finish"
exit 0
