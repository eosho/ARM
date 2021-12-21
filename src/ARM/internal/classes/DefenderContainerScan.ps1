# Interface
class IDefenderContainerScan {
  [void] SetSubscriptionContext([string] $SubscriptionId) {
    Throw "Method Not Implemented"
  }

  [void] InstallResourceGraphModule() {
    Throw "Method Not Implemented"
  }

  [object] GetContainerRegistry([string] $RegistryName, [string] $ResourceGroupName) {
    Throw "Method Not Implemented"
  }

  [string] GetContainerRegistryTag([string] $RegistryName, [string] $RepositoryName) {
    Throw "Method Not Implemented"
  }

  [string] GenerateARGQuery([string] $RegistryName, [string] $RepositoryName, [string] $ImageDigest) {
    Throw "Method Not Implemented"
  }

  [object] InvokeRegistryQuarantine([string] $RegistryName, [string] $ResourceGroupName, [string] $QuarantineMode) {
    Throw "Method Not Implemented"
  }

  [object] DeleteContainerRepository([string] $RegistryName, [string] $RepositoryName) {
    Throw "Method Not Implemented"
  }
}

# Helper extends to interface
class DefenderContainerScan : IDefenderContainerScan {
  [string] $SubscriptionId
  [string] $RegistryName
  [string] $RepositoryName
  [string] $ResourceGroupName
  [string] $ImageDigest
  [string] $QuarantineMode

  DefenderContainerScan() { }

  # Method: Sets the subscription context
  [void] SetSubscriptionContext([string] $SubscriptionId) {
    $this.SubscriptionId = $SubscriptionId

    try {
      $null = Set-AzContext $this.SubscriptionId -Scope Process -ErrorAction Stop
    } catch {
      Write-Error "$($_.Exception.Message)" -ErrorAction Stop
    }
  }

  # Method: Get the container registry
  [object] GetContainerRegistry([string] $RegistryName, [string] $ResourceGroupName) {
    $this.RegistryName = $RegistryName
    $this.ResourceGroupName = $ResourceGroupName

    return Get-AzContainerRegistry -Name $this.RegistryName -ResourceGroupName $this.ResourceGroupName -ErrorAction Stop
  }

  # Method: Get the container registry tags
  [object] GetContainerRegistryTag([string] $RegistryName, [string] $RepositoryName) {
    $this.RegistryName = $RegistryName
    $this.RepositoryName = $RepositoryName

    return (Get-AzContainerRegistryTag -RegistryName $this.RegistryName -RepositoryName $this.RepositoryName -ErrorAction Stop | Select-Object -ExpandProperty Tags | Select-Object -First 1)
  }

  # Install Resource Graph module
  [void] InstallResourceGraphModule() {
    try {
      $module = Get-InstalledModule -Name "Az.ResourceGraph" -ErrorAction SilentlyContinue
      if (-not $module) {
        $checkModule = Install-Module -Name "Az.ResourceGraph" -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
        if ($checkModule) {
          Write-Host "Resource Graph module installed successfully"
        } else {
          Write-Error "Resource Graph module installation failed"
        }
      } else {
        Write-Host "Resource Graph module already installed"
      }
    } catch {
      Write-Error "$($_.Exception.Message)" -ErrorAction Stop
    }
  }

  # Method: Get the container scan results
  [string] GenerateARGQuery([string] $RegistryName, [string] $RepositoryName, [string] $ImageDigest) {
    $this.RegistryName = $RegistryName
    $this.RepositoryName = $RepositoryName
    $this.ImageDigest = $ImageDigest

    $query = "securityresources
    | where type == 'microsoft.security/assessments/subassessments'
    | where id matches regex '(.+?)/providers/Microsoft.ContainerRegistry/registries/(.+)/providers/Microsoft.Security/assessments/dbd0cb49-b563-45e7-9724-889e799fa648/'
    | extend registryResourceId = tostring(split(id, '/providers/Microsoft.Security/assessments/')[0])
    | extend registryResourceName = tostring(split(registryResourceId, '/providers/Microsoft.ContainerRegistry/registries/')[1])
    | extend imageDigest = tostring(properties.additionalData.imageDigest)
    | extend repository = tostring(properties.additionalData.repositoryName)
    | extend scanFindingSeverity = tostring(properties.status.severity), scanStatus = tostring(properties.status.code)
    | summarize scanFindingSeverityCount = count() by scanFindingSeverity, scanStatus, registryResourceId, registryResourceName, repository, imageDigest
    | summarize  severitySummary = make_bag(pack(scanFindingSeverity, scanFindingSeverityCount)) by registryResourceId, registryResourceName, repository, imageDigest, scanStatus"

    # Add filter to get scan summary for specific provided image
    $filter = "| where imageDigest =~ '$($this.ImageDigest)' and repository =~ '$($this.RepositoryName)' and registryResourceName =~ '$($this.RegistryName)'"
    $query = @($query, $filter) | Out-String

    return $query
  }

  # Method: Quarantine the registry before vulnerability scan
  [object] InvokeRegistryQuarantine([string] $RegistryName, [string] $ResourceGroupName, [string] $QuarantineMode) {
    $this.RegistryName = $RegistryName
    $this.ResourceGroupName = $ResourceGroupName
    $this.QuarantineMode = $QuarantineMode.ToLower()

    if ($this.QuarantineMode -eq "disable") {
      $this.QuarantineMode = "disabled"
    } else {
      $this.QuarantineMode = "enabled"
    }

    $resourceId = $this.GetContainerRegistry($this.RegistryName, $this.ResourceGroupName)

    $resource = Get-AzResource -ResourceId $resourceId.Id -ErrorAction Stop
    $resource.Properties.policies.quarantinePolicy.status = "$($this.QuarantineMode)"
    $resource | Set-AzResource -Force -ErrorAction Stop
    return $resource.Properties.policies.quarantinePolicy.status
  }

  # Method: Deletes the entire container repository if required
  [object] DeleteContainerRepository([string] $RegistryName, [string] $RepositoryName) {
    $this.RegistryName = $RegistryName
    $this.RepositoryName = $RepositoryName

    return Remove-AzContainerRegistryRepository -Name $this.RepositoryName -RegistryName $this.RegistryName -ErrorAction Stop
  }
}
