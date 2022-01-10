@description('Location for all resources.')
param location string = resourceGroup().location

@description('Cosmos DB account name (must contain only lowercase letters, digits, and hyphens)')
@maxLength(44)
@minLength(3)
param name string

@description('Enable public network traffic to access the account; if set to Disabled, public network traffic will be blocked even before the private endpoint is created')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Optional. Tags of the resource.')
param tags object = {}

var locations = [
  {
    locationName: location
    failoverPriority: 0
    isZoneRedundant: false
  }
]

resource databaseAccount 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' = {
  name: name
  location: location
  kind: 'GlobalDocumentDB'
  tags: tags
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: locations
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    publicNetworkAccess: publicNetworkAccess
  }
}

@description('The resource ID of the deployed cosmos DB account')
output cosmosDbResourceId string = databaseAccount.id

@description('The name of the deployed cosmos DB account')
output cosmosDbName string = databaseAccount.name

@description('The resource group of the deployed cosmos DB account')
output cosmosDbResourceGroup string = resourceGroup().name
