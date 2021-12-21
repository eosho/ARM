@description('Deployment region name')
param location string = 'eastus2'

@description('Deployment resource group name')
param resourceGroupName string = 'eroshoko-rg'

@description('Keyvault resource name')
param keyVaultName string = 'eroshoko-kv'

module keyvault 'br/demoRegistry:microsoft.keyvault/vaults:1.0.0' = {
  name: keyVaultName
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    name: keyVaultName
    tags: {}
  }
}

output name string = keyvault.name
