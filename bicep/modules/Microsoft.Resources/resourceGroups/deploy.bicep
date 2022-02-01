targetScope = 'subscription'

@description('Required. The name of the Resource Group')
param name string

@description('Optional. Location of the Resource Group. It uses the deployment\'s location when not provided.')
param location string = deployment().location

@allowed([
  'CanNotDelete'
  'NotSpecified'
  'ReadOnly'
])
@description('Optional. Specify the type of lock.')
param lockLevel string = 'NotSpecified'

@description('Optional. Tags of the storage account resource.')
param tags object = {}

var lockNotes = {
  CanNotDelete: 'Cannot delete resource or child resources.'
  ReadOnly: 'Cannot modify the resource or child resources.'
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  location: location
  name: name
  tags: tags
  properties: {}
}

resource lock 'Microsoft.Authorization/locks@2017-04-01' = if (lockLevel != 'NotSpecified') {
  name: '${resourceGroup.name}-lock'
  properties: {
    level: lockLevel
    notes: lockNotes[lockLevel]
  }
}

@description('The name of the resource group')
output resourceGroupName string = resourceGroup.name

@description('The resource ID of the resource group')
output resourceGroupResourceId string = resourceGroup.id
