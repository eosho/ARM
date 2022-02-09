<#
  .SYNOPSIS
    Run a template deployment using a given parameter file via a trigger script.

  .DESCRIPTION
    Run a template deployment using a given parameter file to invoke the CCP deployment pipeline via the trigger script.

  .PARAMETER TriggerScriptPath
    Path where trigger script is located.

  .PARAMETER PipelineStage
    Stages to trigger before the deployment starts

  .PARAMETER ModuleFolder
    The folder path of the module whose parameter file is to be used for the deployment.

  .PARAMETER DeploymentConfigFilePath
    The path to the environment config yaml file.

  .PARAMETER ServiceAccountId
      The user name of the service account (obtained via Key vault).

  .PARAMETER ServiceAccountPass
    The password of the service account (obtained via Key vault)

  .PARAMETER PassThru
    PassThru switch

  .EXAMPLE
    Invoke-CCPDeployment -TriggerScriptPath "c://external/trigger-ccp-pipeline.ps1" -PipelineStage "buildAndDeploy" -ModuleFolder 'c://acr/acr' -DeploymentConfigFilePath 'c://acr/dev.config.yaml' -PassThru

    Deploys a container registry using the given parameters via the trigger script.

  .EXAMPLE
    Invoke-CCPDeployment -TriggerScriptPath "c://external/trigger-ccp-pipeline.ps1" -PipelineStage "build" -ModuleFolder 'c://acr/acr' -DeploymentConfigFilePath 'c://acr/dev.config.yaml' -PassThru

    Validates the parameter file against CCP using the given parameters via the trigger script.

  .INPUTS
    <none>

  .OUTPUTS
    <none>

  .NOTES
    <none>
#>

function Invoke-CCPDeployment {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $TriggerScriptPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('buildAndDeploy', 'buildOnly')]
    [string] $PipelineStage = "buildAndDeploy",

    [Parameter(Mandatory = $true)]
    [string] $DeploymentConfigFilePath,

    [Parameter(Mandatory = $true)]
    [string] $ModuleFolder,

    [Parameter(Mandatory = $true)]
    [string] $ServiceAccountId,

    [Parameter(Mandatory = $true)]
    [string] $ServiceAccountPass,

    [switch] $PassThru
  )

  begin {
    enum ccPipelineStage {
      buildAndDeploy
      buildOnly
    }

    class ccDeploymentParameter {
      [string] $Name
      [string] $FolderPath
      [string] $ParameterFilePath
      [string] $DeploymentStatus
      [string] $Message
      [ccPipelineStage] $State
      [PSCustomObject] $Properties = [PSCustomObject]@{
        ParameterObj = $null
      }

      [string] ToString() {
        return $this.Name
      }

      ccDeploymentParameter([System.IO.DirectoryInfo] $FolderPath) {
        $this.Name = $FolderPath.Name
        $this.FolderPath = $FolderPath.FullName

        $ccpParameterFilePath = Join-Path -Path $this.FolderPath -ChildPath "$($this.Name)-parameters-full.json"
        if (Test-Path -Path $ccpParameterFilePath) {
          $this.ParameterFilePath = $ccpParameterFilePath
        } else {
          throw "Parameter file not found at $ccpParameterFilePath"
        }

        $this.Properties.ParameterObj = Get-Content -Path $($this.ParameterFilePath) -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
      }
    }

    class ccInvokeCCPDeployment {
      [string] $TriggerScriptPath
      [string] $ParameterFile
      [string] $PipelineStage

      ccInvokeCCPDeployment([string] $TriggerScriptPath, [string] $ParameterFile, [ccPipelineStage] $PipelineStage) {
        $this.TriggerScriptPath = $TriggerScriptPath
        $this.ParameterFile = $ParameterFile
        $this.PipelineStage = $PipelineStage

        try {
          & $this.TriggerScriptPath -ParameterFiles $this.ParameterFile -PipelineStage $this.PipelineStage -ScriptDebug

          # checking the exit code of the trigger script
          if ($LASTEXITCODE -ne 0) {
            Write-Error "Error occurred while executing the trigger script. Exit code: $LASTEXITCODE" -ErrorAction Stop
          } else {
            Write-Output "Deployment succeeded for parameter: [$($ParameterFile)]"
          }
        } catch {
          Write-Error "Trigger script deployment failed. Details: $($_.Exception.Message)" -ErrorAction Stop
        }
      }

      # Method: Performs an Azure CLI login using the service account credentials
      [bool] AzLogin([string] $ServiceAccountId, [string] $ServiceAccountPass) {
        $this.ServiceAccountId = $ServiceAccountId
        $this.ServiceAccountPass = $ServiceAccountPass

        az login -u $this.ServiceAccountId -p $this.ServiceAccountPass --tenant "92cb778e-8ba7-4f34-a011-4ba6e7366996" *>&1 | Out-Null
        if (-not $?) {
          Write-Error "Azure CLI login failed. Make sure you have the correct TenantId and/or service account credentials." -ErrorAction Stop
        }
        return $true
      }
      #endregion
    }
    #endregion

    class ccDeploymentPlan {
      [string] $SubscriptionId
      [string] $SubscriptionName
      [System.Collections.Generic.List[ccDeploymentParameter]] $ccpResourcesToDeploy = (New-Object -TypeName System.Collections.Generic.List[ccDeploymentParameter] -ErrorAction Stop)
      #[System.Collections.Generic.List[ccInvokeCCPDeployment]] $ccpResourcesToDeploy = (New-Object -TypeName System.Collections.Generic.List[ccInvokeCCPDeployment] -ErrorAction Stop)
    }
  }

  process {
    #region Get deploymentConfiguration
    try {
      Write-Output "Get deploymentConfiguration started"

      $deploymentConfigurationAsJson = Get-Content -Path $DeploymentConfigFilePath -Raw -ErrorAction Stop
      $deploymentConfiguration = $deploymentConfigurationAsJson | ConvertFrom-Yaml -ErrorAction Stop

      Write-Output "Get deploymentConfiguration completed"
    } catch {
      Write-Error -Message "Get deploymentConfiguration failed. Details: $($_.Exception.Message)" -ErrorAction Stop
    }
    #endregion

    #region Get deployment plan in Scope
    try {
      Write-Output "Get CCP Deployment plan started"

      $deploymentPlan = New-Object -TypeName System.Collections.Generic.List[ccDeploymentPlan] -ErrorAction Stop
      $plan = [ccDeploymentPlan]::new()
      $subscriptions = Get-AzSubscription -ErrorAction Stop
      $subscriptions.Where{ ($_.Id -eq $deploymentConfiguration.variables.SubscriptionId) }.ForEach{
        $plan.SubscriptionId = $_.Id
        $plan.SubscriptionName = $_.Name
        $deploymentPlan.Add($plan)
      }

      Write-Output "Get CCP Deployment plan completed"
    } catch {
      Write-Error -Message "Get CCP Deployment plan failed. Details: $($_.Exception.Message)" -ErrorAction Stop
    }
    #endregion

    #region Get parameter file
    try {
      Write-Output "Get CCP Deployment parameter(s) started"

      foreach ($dp in $deploymentPlan) {
        $ccpParameterDef = [ccDeploymentParameter]::new($ModuleFolder)

        #Add get parameter file to deployment plan
        $dp.ccpResourcesToDeploy.Add($ccpParameterDef)
      }

      Write-Output "Get CCP Deployment parameter(s) completed"
    } catch {
      Write-Error -Message "Get CCP Deployment parameter(s) failed. Details: $($_.Exception.Message)" -ErrorAction Stop
    }
    #endregion

    #region Trigger ccp deployment
    try {
      Write-Output "Deploy CCP started"

      $isLoggedIn = $false

      Write-Output "Initializing Azure CLI login"
      #$isLoggedIn = [ccInvokeCCPDeployment]::new().AzLogin($ServiceAccountId, $ServiceAccountPass)
      if ($isLoggedIn) {
        Write-Output "Azure CLI login successful. Starting deployment"
        foreach ($dp in $deploymentPlan) {
          [ccInvokeCCPDeployment]::new($TriggerScriptPath, $dp.ccpResourcesToDeploy.ParameterFilePath, $dp.ccpResourcesToDeploy.State)
          $dp.ccpResourcesToDeploy[0].DeploymentStatus = "Success"
        }
      }

      Write-Output "Deploy CCP completed"
    } catch {
      $dp.ccpResourcesToDeploy[0].DeploymentStatus = "Failed"
      $dp.ccpResourcesToDeploy[0].Message = $($_.Exception.Message)
      Write-Error -Message "Deploy CCP failed. Details: $($_.Exception.Message)" -ErrorAction Continue
    }
    #endregion

  }

  end {
    #Return Result
    if ($PassThru.IsPresent) {
      foreach ($dp in $deploymentPlan) {
        $dp.ccpResourcesToDeploy
      }
    }
    #endregion
  }
}
