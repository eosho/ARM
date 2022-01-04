targetScope = 'managementGroup'

@description('Deployment region name')
param location string = 'eastus2'

@description('Deployment resource group name')
param resourceGroupName string = 'eroshoko-rg'

@description('Keyvault resource name')
param keyVaultName string = 'eroshoko-kv'

param subscriptionID string = 'f2d85cf0-b21c-4794-a259-f508c89d08c2'

module rg 'br/demoRegistry:microsoft.resources/resourcegroups:1.0.0' = {
  scope: subscription(subscriptionID)
  name: 'eroshoko-rg'
  params: {
    location: location
    resourceGroupName: resourceGroupName
    tags: {}
  }
}

module keyvault 'br/demoRegistry:microsoft.keyvault/vaults:1.0.0' = {
  name: keyVaultName
  scope: resourceGroup(subscriptionID, rg.name)
  params: {
    location: location
    name: keyVaultName
    tags: {}
  }
}

output rgName string = rg.name
