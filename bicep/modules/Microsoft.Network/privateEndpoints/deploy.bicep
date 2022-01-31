@description('Required. Name of the private endpoint resource to create.')
param name string

@description('Required. Resource ID of the subnet where the endpoint needs to be created.')
param targetSubnetResourceId string

@description('Required. Resource ID of the resource that needs to be connected to the network.')
param serviceResourceId string

@description('Required. Subtype(s) of the connection to be created. The allowed values depend on the type serviceResourceId refers to.')
param groupId array

@description('Optional. Array of Private DNS zone groups configuration on the private endpoint.')
param privateDnsZoneGroups array = []

@description('Optional. Location for all Resources.')
param location string = resourceGroup().location

@description('Optional. Tags to be applied on all resources/resource groups in this deployment.')
param tags object = {}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: name
        properties: {
          privateLinkServiceId: serviceResourceId
          groupIds: groupId
        }
      }
    ]
    manualPrivateLinkServiceConnections: []
    subnet: {
      id: targetSubnetResourceId
    }
    customDnsConfigs: []
  }
}

module privateEndpoint_privateDnsZoneGroups 'privateDnsZoneGroups/deploy.bicep' = [for (privateDnsZoneGroup, index) in privateDnsZoneGroups: {
  name: '${uniqueString(deployment().name, location)}-PrivateEndpoint-PrivateDnsZoneGroup-${index}'
  params: {
    privateDNSResourceIds: privateDnsZoneGroup.privateDNSResourceIds
    privateEndpointName: privateEndpoint.name
  }
}]

@description('The resource group the private endpoint was deployed into')
output privateEndpointResourceGroup string = resourceGroup().name

@description('The resource ID of the private endpoint')
output privateEndpointResourceId string = privateEndpoint.id

@description('The name of the private endpoint')
output privateEndpointName string = privateEndpoint.name
