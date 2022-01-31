@description('Required. Private DNS zone name.')
param name string

@description('Optional. Array of custom objects describing vNet links of the DNS zone. Each object should contain properties \'vnetResourceId\' and \'registrationEnabled\'. The \'vnetResourceId\' is a resource ID of a vNet to link, \'registrationEnabled\' (bool) enables automatic DNS registration in the zone for the linked vNet.')
param virtualNetworkLinks array = []

@description('Optional. The location of the PrivateDNSZone. Should be global.')
param location string = 'global'

@description('Optional. Tags of the resource.')
param tags object = {}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: name
  location: location
  tags: tags
}

module privateDnsZone_virtualNetworkLinks 'virtualNetworkLinks/deploy.bicep' = [for (virtualNetworkLinks, index) in virtualNetworkLinks: {
  name: '${uniqueString(deployment().name, location)}-PrivateDnsZone-VirtualNetworkLink-${index}'
  params: {
    privateDnsZoneName: privateDnsZone.name
    name: contains(virtualNetworkLinks, 'name') ? virtualNetworkLinks.name : '${last(split(virtualNetworkLinks.virtualNetworkResourceId, '/'))}-vnetlink'
    virtualNetworkResourceId: virtualNetworkLinks.virtualNetworkResourceId
    location: contains(virtualNetworkLinks, 'location') ? virtualNetworkLinks.location : 'global'
    registrationEnabled: contains(virtualNetworkLinks, 'registrationEnabled') ? virtualNetworkLinks.registrationEnabled : false
    tags: contains(virtualNetworkLinks, 'tags') ? virtualNetworkLinks.tags : {}
  }
}]

@description('The resource group the private DNS zone was deployed into')
output privateDnsZoneResourceGroup string = resourceGroup().name

@description('The name of the private DNS zone')
output privateDnsZoneName string = privateDnsZone.name

@description('The resource ID of the private DNS zone')
output privateDnsZoneResourceId string = privateDnsZone.id
