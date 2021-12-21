class ARMDeploymentScope {
  [string] $Scope
  [string] $Type
  [string] $Name
  [string] $ResourceProvider
  [string] $Resource
  [string] $SubscriptionDisplayName
  [string] $SubscriptionId

  hidden [regex]$regex_resourceGroup = '(?i)^/subscriptions/.*/resourcegroups/[^/]*$'
  hidden [regex]$regex_resourceGroupExtract = '(?i)^/subscriptions/.*/resourcegroups/'

  hidden [regex]$regex_subscription = '(?i)^/subscriptions/[^/]*$'
  hidden [regex]$regex_subscriptionExtract = '(?i)^/subscriptions/'

  ARMDeploymentScope() { }

  # Method: Check if the scope is a subscription or a resource group
  ARMDeploymentScope([string] $Scope) {
    $this.InitializeMemberVariables($Scope)
  }

  # Method: Initialize member variables
  hidden [object] InitializeMemberVariables([string] $Scope) {
    $this.Scope = $Scope

    if ($this.IsResourceGroup()) {
      $this.Type = "resourcegroups"
      $this.ResourceProvider = "Microsoft.Resources"
      $this.Resource = "resourcegroups"
      $this.Name = $this.IsResourceGroup()
      $this.SubscriptionDisplayName = $this.GetSubscription().Name
      $this.SubscriptionId = $this.GetSubscription().Id
    } elseif ($this.IsSubscription()) {
      $this.Type = "subscriptions"
      $this.ResourceProvider = "Microsoft.Subscriptions"
      $this.Resource = "subscriptions"
      $this.Name = $this.IsSubscription()
      $this.SubscriptionDisplayName = $this.GetSubscription().Name
      $this.SubscriptionId = $this.GetSubscription().Id
    } else {
      throw New-Object System.ArgumentException("Invalid scope: $($this.Scope). Valid scopes are: resourcegroups and subscriptions")
    }

    return $this.ScopeObject
  }

  [string] ToString() {
    return $this.Scope
  }

  # Method: Check if subscription scope
  [string] IsSubscription() {
    if (($this.Scope -match $this.regex_subscription)) {
      return ($this.Scope.Split('/')[2])
    }
    return $null
  }

  # Method: Check if resource group scope
  [string] IsResourceGroup() {
    if (($this.Scope -match $this.regex_resourceGroup)) {
      return ($this.Scope.Split('/')[4])
    }
    return $null
  }

  # Method: Get Subscription DisplayName
  [object] GetSubscription() {
    if ($this.Scope -match $this.regex_subscriptionExtract) {
      $subId = $this.Scope -split $this.regex_subscriptionExtract -split '/' | Where-Object { $_ } | Select-Object -First 1
      $subscription = Get-AzSubscription | Where-Object { $_.SubscriptionId -eq $subId }
      if ($subscription) {
        return $subscription
      } else {
        return $subId
      }
    }
    return $null
  }

  # Set the subscription context
  [void] SetSubscriptionContext() {
    try {
      if ($this.Scope -match $this.regex_subscriptionExtract) {
        $subId = $this.Scope -split $this.regex_subscriptionExtract -split '/' | Where-Object { $_ } | Select-Object -First 1
        Write-PipelineLogger -LogType "info" -Message "Setting subscription context: Subscription - [ $subId ]"
        $null = Set-AzContext $subId -Scope Process -ErrorAction Stop
      }
    } catch {
      Write-PipelineLogger -LogType "error" -Message "An error ocurred while running SetSubscriptionContext. Details $($_.Exception.Message)"
    }
  }

  # Get an existing resource group
  [object] GetResourceGroup() {
    try {
      if ($this.Scope -match $this.regex_resourceGroupExtract) {
        $rgName = $this.Scope -split $this.regex_resourceGroupExtract -split '/' | Where-Object { $_ } | Select-Object -First 1
        $rg = Get-AzResourceGroup -ErrorAction SilentlyContinue | Where-Object { $_.ResourceGroupName -eq $rgName }
        if ($rg) {
          return $rg
        } else {
          return $null
        }
      } else {
        return $null
      }
    } catch {
      Write-PipelineLogger -LogType "error" -Message "An error ocurred while running GetResourceGroup. Details: $($_.Exception.Message)"
      throw $_
    }
  }

  # Remove an existing resource group
  [void] RemoveResourceGroup() {
    try {
      if ($this.Scope -match $this.regex_resourceGroupExtract) {
        $resourceGroup = $this.GetResourceGroup()

        if ($null -ne $resourceGroup) {
          Remove-AzResourceGroup -Id $resourceGroup.ResourceId -Force -ErrorAction 'SilentlyContinue' -ErrorAction SilentlyContinue
        }
      }
    } catch {
      Write-PipelineLogger -LogType "error" -Message "An error ocurred while running RemoveResourceGroup. Details: $($_.Exception.Message)"
      throw $_
    }
  }

  # If there is any resource lock on the existing scope, we need it cleaned up
  [void] RemoveResourceLock() {
    try {
      $allLocks = Get-AzResourceLock -Scope $this.Scope -ErrorAction SilentlyContinue | Where-Object "ProvisioningState" -ne "Deleting"
      if ($null -ne $allLocks) {
        $allLocks | ForEach-Object {
          Remove-AzResourceLock -LockId $_.ResourceId -Force -ErrorAction 'SilentlyContinue'
        }
      }
    } catch {
      Write-PipelineLogger -LogType "error" -Message "An error ocurred while running RemoveResourceLock. Details: $($_.Exception.Message)"
      throw $_
    }
  }
}
