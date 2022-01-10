@description('Specify the name of the Azure Redis Cache to create.')
param name string

@description('Location of all resources')
param location string = resourceGroup().location

@description('Specify the pricing tier of the new Azure Redis Cache.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param redisCacheSKU string = 'Standard'

@description('Specify the family for the sku. C = Basic/Standard, P = Premium.')
@allowed([
  'C'
  'P'
])
param redisCacheFamily string = 'C'

@description('Specify the size of the new Azure Redis Cache instance. Valid values: for C (Basic/Standard) family (0, 1, 2, 3, 4, 5, 6), for P (Premium) family (1, 2, 3, 4)')
@allowed([
  0
  1
  2
  3
  4
  5
  6
])
param redisCacheCapacity int = 1

@description('The minimum allowed TLS version.')
@allowed([
  '1.0'
  '1.1'
  '1.2'
])
param minimumTlsVersion string = '1.2'

@description('The resource group of the existing Virtual Network.')
param existingVirtualNetworkResourceGroupName string = resourceGroup().name

@description('The name of the existing Virtual Network.')
param existingVirtualNetworkName string

@description('The name of the existing subnet.')
param existingSubnetName string

@description('Specify a boolean value that indicates whether to allow access via non-SSL ports.')
param enableNonSslPort bool = false

@description('Resource Id for the log analytics workspace for diagnostics logs.')
param workspaceResourceId string

@description('Optional. Tags of the resource.')
param tags object = {}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-03-01' existing = {
  name: '${existingVirtualNetworkName}/${existingSubnetName}'
  scope: resourceGroup(existingVirtualNetworkResourceGroupName)
}

resource redisCache 'Microsoft.Cache/redis@2020-12-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    enableNonSslPort: enableNonSslPort
    minimumTlsVersion: minimumTlsVersion
    sku: {
      capacity: redisCacheCapacity
      family: redisCacheFamily
      name: redisCacheSKU
    }
    subnetId: empty(subnet.id) ? null : subnet.id
  }
}

resource redisDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: redisCache
  name: redisCache.name
  properties: {
    logAnalyticsDestinationType: 'AzureDiagnosis'
    workspaceId: workspaceResourceId
    logs: [
      {
        enabled: true
      }
    ]
    metrics: [
      {
        timeGrain: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

@description('The resource ID of the deployed redis cache.')
output redisCacheResourceId string = redisCache.id

@description('The name of the deployed redis cache')
output redisCacheName string = redisCache.name

@description('The resource group of the deployed redis cache')
output redisCacheResourceGroup string = resourceGroup().name
