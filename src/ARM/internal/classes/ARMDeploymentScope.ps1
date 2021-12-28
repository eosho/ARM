class ARMDeploymentScope {
  [string] $Scope
  [string] $Type
  [string] $Name
  [string] $ResourceProvider
  [string] $Resource
  [string] $SubscriptionDisplayName
  [string] $SubscriptionId
  [string] $ManagementGroup
  [string] $ManagementGroupDisplayName

  hidden [regex]$regex_tenant = '/$'
  hidden [regex]$regex_managementgroup = '(?i)^/providers/Microsoft.Management/managementgroups/[^/]+$'
  hidden [regex]$regex_managementgroupExtract = '(?i)^/providers/Microsoft.Management/managementgroups/'

  hidden [regex]$regex_resourceGroup = '(?i)^/subscriptions/.*/resourcegroups/[^/]*$'
  hidden [regex]$regex_resourceGroupExtract = '(?i)^/subscriptions/.*/resourcegroups/'

  hidden [regex]$regex_subscription = '(?i)^/subscriptions/[^/]*$'
  hidden [regex]$regex_subscriptionExtract = '(?i)^/subscriptions/'

  ARMDeploymentScope() { }

  # Method: Check if the scope is a management group, subscription or a resource group
  ARMDeploymentScope([string] $Scope) {
    $this.InitializeScopeVariables($Scope)
  }

  # Method: Initialize scope variables
  hidden [object] InitializeScopeVariables([string] $Scope) {
    $this.Scope = $Scope

    if ($this.IsResourceGroup()) {
      $this.Type = "resourcegroups"
      $this.ResourceProvider = "Microsoft.Resources"
      $this.Resource = "resourcegroups"
      $this.Name = $this.IsResourceGroup()
      $this.SubscriptionDisplayName = $this.GetSubscription().Name
      $this.SubscriptionId = $this.GetSubscription().Id
      $this.ManagementGroup = $this.GetManagementGroup().Id
      $this.ManagementGroupDisplayName = $this.GetManagementGroup().Name
    } elseif ($this.IsSubscription()) {
      $this.Type = "subscriptions"
      $this.ResourceProvider = "Microsoft.Subscriptions"
      $this.Resource = "subscriptions"
      $this.Name = $this.IsSubscription()
      $this.SubscriptionDisplayName = $this.GetSubscription().Name
      $this.SubscriptionId = $this.GetSubscription().Id
      $this.ManagementGroup = $this.GetManagementGroup().Id
      $this.ManagementGroupDisplayName = $this.GetManagementGroup().Name
    } elseif ($this.IsManagementGroup()) {
      $this.Type = "managementGroups"
      $this.ResourceProvider = "Microsoft.Management"
      $this.Resource = "managementGroups"
      $this.Name = $this.IsManagementGroup()
      $this.ManagementGroup = $this.GetManagementGroup().Id
      $this.ManagementGroupDisplayName = $this.GetManagementGroup().Name
    } elseif ($this.IsTenant()) {
      $this.Type = "root"
      $this.Name = "/"
    } else {
      throw New-Object System.ArgumentException("Invalid scope: $($this.Scope). Valid scopes are: resourcegroups, subscriptions, managementgroups and tenant levels")
    }

    return $this.ScopeObject
  }

  [string] ToString() {
    return $this.Scope
  }

  # Method: Check management group tenant root scope
  [bool] IsTenant() {
    if (($this.Scope -match $this.regex_tenant)) {
      return ($this.Scope.Split('/')[1])
    }
    return $null
  }

  # Method: Check if management group scope
  [bool] IsManagementGroup() {
    if (($this.Scope -match $this.regex_managementgroup)) {
      return ($this.Scope.Split('/')[4])
    }
    return $null
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

  # Get Management Group info
  [object] GetManagementGroup() {
    if ($this.Scope -match $this.regex_managementgroupExtract) {
      $mgmtGroupId = $this.Scope -split $this.regex_managementgroupExtract -split '/' | Where-Object { $_ } | Select-Object -First 1
      
      if ($this.GetManagementGroup()) {
        $mgmt = Get-AzManagementGroup -ErrorAction SilentlyContinue | Where-Object { $_.GroupName -eq $mgmtGroupId }
        if ($mgmt.DisplayName -eq $mgmtGroupName) {
          return $mgmt
        }
      }

      if ($this.Subscription) {
        $mgmt = Get-AzManagementGroup -Expand -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.GroupName -eq $mgmtGroupId }
        foreach ($child in $mgmt.Children) {
          if ($child.DisplayName -eq $this.subscriptionDisplayName) {
            return $mgmt
          }
        }
      }
    }
  
    return $null
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
}
