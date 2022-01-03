class ARMDeploymentPayload {
  # Scope object
  [PSCustomObject] $ScopeObject = @{}

  # Deployment payload
  [string] $DeploymentId
  [string] $DeploymentName
  [object] $TemplateObject
  [object] $ParametersObject
  [string] $Location

  # Deployment results
  [string[]] $Errors
  [string[]] $Warnings
  [object] $Scripts
  [string[]] $Messages

  ARMDeploymentPayload() {}

  DeploymentPayload([string] $DeploymentId, [string] $DeploymentName, [object] $TemplateObject, [object] $ParametersObject, [string] $Location) {
    $this.DeploymentId = $DeploymentId
    $this.DeploymentName = $DeploymentName
    $this.TemplateObject = $TemplateObject
    $this.ParametersObject = $ParametersObject
    $this.Location = $Location
  }

  DeploymentResults([string[]] $Errors) {
    $this.Errors = $Errors
  }

  DeploymentResults([string[]] $Errors, [string[]] $Warnings) {
    $this.Errors = $Errors
    $this.Warnings = $Warnings
  }

  DeploymentResults([string[]] $Errors, [string[]] $Warnings, [object] $Scripts) {
    $this.Errors = $Errors
    $this.Warnings = $Warnings
    $this.Scripts = $Scripts
  }

  DeploymentResults([string[]] $Errors, [string[]] $Warnings, [object] $Scripts, [string[]] $Messages) {
    $this.Errors = $Errors
    $this.Warnings = $Warnings
    $this.Scripts = $Scripts
    $this.Messages = $Messages
  }

  hidden [object] WriteDeploymentObject([ARMDeploymentPayload] $DeploymentPayloadObj) {
    try {
      if ($DeploymentPayloadObj) {
        $deploymentPayloadJson = $DeploymentPayloadObj | ConvertTo-Json -Depth 100
        Out-File -InputObject $deploymentPayloadJson $($DeploymentPayloadObj.DeploymentName + ".json")

        if ($deploymentPayloadJson) {
          Write-PipelineLogger -LogType "success" -Message "Deployment payload object updated"
        } else {
          Write-PipelineLogger -LogType "error" -Message "Deployment payload object not updated"
        }
      } else {
        Write-PipelineLogger -LogType "error" -Message "Deployment payload object not found"
      }
    } catch {
      Write-PipelineLogger -LogType "error" -Message "$($_.Exception.Message)"
    }

    return $DeploymentPayloadObj
  }

  hidden [object] ReadDeploymentObject([ARMDeploymentPayload] $DeploymentPayloadObj) {
    try {
      $deploymentPayloadObj = Get-Content -Path $($DeploymentPayloadObj.DeploymentName + ".json") | Out-String | ConvertFrom-Json
      if ($deploymentPayloadObj) {
        Write-PipelineLogger -LogType "success" -Message "Deployment payload object read"
      } else {
        Write-PipelineLogger -LogType "error" -Message "Failed to read deployment payload object"
      }
    } catch {
      Write-PipelineLogger -LogType "error" -Message "$($_.Exception.Message)"
    }

    return $DeploymentPayloadObj
  }
}
