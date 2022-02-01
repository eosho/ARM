targetScope = 'subscription'

@description('Required. The name of the Resource Group')
param name string

@description('Optional. Location of the Resource Group. It uses the deployment\'s location when not provided.')
param location string = deployment().location

@description('Optional. Tags of the storage account resource.')
param tags object = {}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  location: location
  name: name
  tags: tags
  properties: {}
}

@description('The name of the resource group')
output resourceGroupName string = resourceGroup.name

@description('The resource ID of the resource group')
output resourceGroupResourceId string = resourceGroup.id
