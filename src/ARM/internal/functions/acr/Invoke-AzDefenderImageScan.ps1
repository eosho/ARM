
function Invoke-AzDefenderImageScan {
  <#
  .SYNOPSIS
    Automation script to include ASC vulnerability assessment scan summary for provided image as a gate.
    Check result and assess whether to pass security gate by findings severity.

  .DESCRIPTION
    Microsoft Defender for Cloud scan Azure container registry (ACR) images for known vulnerabilities on multiple scenarios including image push.
    (https://docs.microsoft.com/en-us/azure/security-center/defender-for-container-registries-introduction#when-are-images-scanned)
    Using this tool you can have a security gate as part of image release(push). In case there's a major vulnerability in image, gate(script) will fail to allow exit in CI/CD pipelines.

  .PARAMETER SubscriptionId
    Azure subscription Id where your container registry is located. This is an optional parameter.

  .PARAMETER RegistryName
    Azure container registry resource name image is stored. This is a required parameter.

  .PARAMETER RepositoryName
    The name of the repository where the image is stored. This is a required parameter.

  .EXAMPLE
    PS C:\> Invoke-AzDefenderImageScan -SubscriptionId $SubscriptionId -RegistryName $RegistryName -RepositoryName $RepositoryName

    Sets subscription context and invokes the script to find vulnerabilities in provided repository.

  .EXAMPLE
    PS C:\> Invoke-AzDefenderImageScan -RegistryName $RegistryName -RepositoryName $RepositoryName

    Invokes the script to find vulnerabilities in provided repository.

  .INPUTS
    Inputs (if any)

  .OUTPUTS
    Output (if any)

  .NOTES
    General notes
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false)]
    [string] $SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string] $RegistryName,

    [Parameter(Mandatory = $true)]
    [string] $RepositoryName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Enable", "Disable")]
    [string] $QuarantineMode,

    [Parameter(Mandatory = $false)]
    [switch] $DeleteContainerRepository
  )

  # Get the running script name
  $scriptName = $($MyInvocation.MyCommand | Select-Object -ExpandProperty Name)

  # Initialize the class
  $initializeClass = [DefenderContainerScan]::new()

  # Set subscription context
  if (-not [string]::IsNullOrEmpty($SubscriptionId)) {
    Write-Output "[$scriptName] - Setting subscription context"
    $initializeClass.SetSubscriptionContext($SubscriptionId)
  }

  # Delete container repository
  if ($DeleteContainerRepository.IsPresent) {
    Write-Output "[$scriptName] - Deleting container repository -  $RepositoryName"
    $initializeClass.DeleteContainerRepository($RegistryName, $RepositoryName)
  } else {
    # Install Resource Graph module - optional
    # $initializeClass.InstallResourceGraphModule()

    # Get tag
    $tag = $initializeClass.GetContainerRegistryTag($RegistryName, $RepositoryName)
    if (-not [string]::IsNullOrEmpty($tag)) {
      Write-Output "[$scriptName] - Image tag version: $($tag.Name)"

      $imageDigest = $tag.Digest
      if ([string]::IsNullOrEmpty($imageDigest)) {
        Write-Error "[$scriptName] - Image '$($Repository):$($tag.Name)' was not found! (Registry: $RegistryName)" -ErrorAction Stop
      } else {
        Write-Output "[$scriptName] - Image digest: $imageDigest"
      }

      # Generate ARG query
      $query = $initializeClass.GenerateARGQuery($RegistryName, $RepositoryName, $imageDigest)

      # Get result with retry policy incase ASG is not ready
      $mediumFindingsCountFailThreshold = 5
      $lowFindingsCountFailThreshold = 15

      $retryCount = 5
      $i = 0

      try {
        # Generate ARG query
        $query = $initializeClass.GenerateARGQuery($RegistryName, $RepositoryName, $imageDigest)

        while ((($result = Search-AzGraph -Query $query).Count -eq 0) -and ($i = $i + 1) -lt $retryCount) {
          Write-Output "[$scriptName] - No results for image $($RepositoryName):$($tag.Name) yet - retry [$i/$($retryCount)]..."
          Start-Sleep -s 20
        }
      } catch {
        Write-Error "[$scriptName] - Error occurred while executing query: Details: $($_.Exception.Message)" -ErrorAction Stop
      }

      if ((-not $result) -or ($result.Count -eq 0)) {
        Write-Output "[$scriptName] - No results were found for digest: $imageDigest after [$retryCount] retries!"
      } else {
        # Extract scan summary from result
        $scanSummary = $result
        Write-Output "[$scriptName] - Scan summary: $($scanSummary | Out-String)"

        if ($scanSummary.ScanStatus -eq "healthy") {
          Write-Output "[$scriptName] - Healthy scan result, no major vulnerabilities found in image"
        } elseif ($scanSummary.ScanStatus -eq "unhealthy") {
          # Check if there are major vulnerabilities  found - customize by parameters
          if (($scanSummary.severitySummary.high -gt 0) -or ($scanSummary.severitySummary.medium -gt $mediumFindingsCountFailThreshold) -or ($scanSummary.severitySummary.low -gt $lowFindingsCountFailThreshold)) {
            Write-Error "[$scriptName] - Unhealthy scan result, major vulnerabilities found in image summary"
          } else {
            Write-Warning "[$scriptName] - Unhealthy scan result, some vulnerabilities found in image"

            # TODO: Print the high, medium and low vulnerabilities found

            # Enable or disable quarantine on the container registry
            # We should probably quarantine all registries by default so no one can pull from them yet until ASC scans the image and vulnerabilities are fixed
            try {
              $quarantineStatus = $initializeClass.InvokeRegistryQuarantine($RegistryName, $RepositoryName, $QuarantineMode)
              if ($quarantineStatus) {
                Write-Output "[$scriptName] - Registry $($RegistryName) quarantine mode: $($quarantineStatus)"
              } else {
                Write-Output "[$scriptName] - Registry $($RegistryName) was not quarantined"
              }
            } catch {
              Write-Error "[$scriptName] - Failed to quarantine registry $($RegistryName). Details: $($_.Exception.Message)"
            }
          }
        } else {
          Write-Error "[$scriptName] - Unknown scan result returned" -ErrorAction Stop
        }
      }
    } else {
      Write-Error "[$scriptName] - No tag found for image $($RepositoryName):$($tag.Name)" -ErrorAction Stop
    }
  }
}

#Invoke-DefenderImageScan -RegistryName "deveoacracr01" -RepositoryName "baseimages/alpine/current"

# $initializeClass = [DefenderContainerScan]::new()
# $initializeClass.InvokeRegistryQuarantine("deveoacracr01", "dev-eoacr-acr-rg-eastus2-01", "disable")
