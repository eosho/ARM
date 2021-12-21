targetScope = 'subscription'

@description('Deployment region name')
param location string = 'eastus2'

@description('Deployment resource group name')
param resourceGroupName string = 'eroshoko-rg'

@description('Keyvault resource name')
param keyVaultName string = 'eroshoko-kv'

module rg 'br/demoRegistry:microsoft.resources/resourcegroups:1.0.0' = {
  name: 'eroshoko-rg'
  params: {
    location: location
    resourceGroupName: resourceGroupName
    tags: {}
  }
}

module keyvault 'br/demoRegistry:microsoft.keyvault/vaults:1.0.0' = {
  name: keyVaultName
  scope: resourceGroup(rg.name)
  params: {
    location: location
    name: keyVaultName
    tags: {}
  }
}

output rgName string = rg.name
