@description('Required. The Virtual Network (vNet) Name.')
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Required. An Array of 1 or more IP Address Prefixes for the Virtual Network.')
param addressPrefixes array

@description('Required. An Array of subnets to deploy to the Virual Network.')
@minLength(1)
param subnets array

@description('Optional. DNS Servers associated to the Virtual Network.')
param dnsServers array = []

@description('Optional. Resource ID of the DDoS protection plan to assign the VNET to. If it\'s left blank, DDoS protection will not be configured. If it\'s provided, the VNET created by this template will be attached to the referenced DDoS protection plan. The DDoS protection plan can exist in the same or in a different subscription.')
param ddosProtectionPlanId string = ''

@description('Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(365)
param diagnosticLogsRetentionInDays int = 90

@description('Optional. Resource ID of the diagnostic storage account.')
param diagnosticStorageAccountId string = ''

@description('Optional. Resource ID of log analytics.')
param workspaceId string = ''

@description('Optional. Resource ID of the event hub authorization rule for the Event Hubs namespace in which the event hub should be created or streamed to.')
param eventHubAuthorizationRuleId string = ''

@description('Optional. Name of the event hub within the namespace to which logs are streamed. Without this, an event hub is created for each log category.')
param eventHubName string = ''

@description('Optional. Tags of the resource.')
param tags object = {}

@description('Optional. The name of logs that will be streamed.')
@allowed([
  'VMProtectionAlerts'
])
param logsToEnable array = [
  'VMProtectionAlerts'
]

@description('Optional. The name of metrics that will be streamed.')
@allowed([
  'AllMetrics'
])
param metricsToEnable array = [
  'AllMetrics'
]

var diagnosticsLogs = [for log in logsToEnable: {
  category: log
  enabled: true
  retentionPolicy: {
    enabled: true
    days: diagnosticLogsRetentionInDays
  }
}]

var diagnosticsMetrics = [for metric in metricsToEnable: {
  category: metric
  timeGrain: null
  enabled: true
  retentionPolicy: {
    enabled: true
    days: diagnosticLogsRetentionInDays
  }
}]

var dnsServers_var = {
  dnsServers: array(dnsServers)
}
var ddosProtectionPlan = {
  id: ddosProtectionPlanId
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    ddosProtectionPlan: !empty(ddosProtectionPlanId) ? ddosProtectionPlan : null
    dhcpOptions: !empty(dnsServers) ? dnsServers_var : null
    enableDdosProtection: !empty(ddosProtectionPlanId)
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        delegations: contains(subnet, 'delegations') ? subnet.delegations : null
        privateEndpointNetworkPolicies: contains(subnet, 'privateEndpointNetworkPolicies') ? subnet.privateEndpointNetworkPolicies : null
        privateLinkServiceNetworkPolicies: contains(subnet, 'privateLinkServiceNetworkPolicies') ? subnet.privateLinkServiceNetworkPolicies : null
      }
    }]
  }
}

@batchSize(1)
module virtualNetwork_subnets 'subnets/deploy.bicep' = [for (subnet, index) in subnets: {
  name: '${uniqueString(deployment().name, location)}-subnet-${index}'
  params: {
    virtualNetworkName: virtualNetwork.name
    name: subnet.name
    addressPrefix: subnet.addressPrefix
    addressPrefixes: contains(subnet, 'addressPrefixes') ? subnet.addressPrefixes : []
    applicationGatewayIpConfigurations: contains(subnet, 'applicationGatewayIpConfigurations') ? subnet.applicationGatewayIpConfigurations : []
    delegations: contains(subnet, 'delegations') ? subnet.delegations : []
    ipAllocations: contains(subnet, 'ipAllocations') ? subnet.ipAllocations : []
    natGatewayName: contains(subnet, 'natGatewayName') ? subnet.natGatewayName : ''
    networkSecurityGroupName: contains(subnet, 'networkSecurityGroupName') ? subnet.networkSecurityGroupName : ''
    networkSecurityGroupNameResourceGroupName: contains(subnet, 'networkSecurityGroupNameResourceGroupName') ? subnet.networkSecurityGroupNameResourceGroupName : resourceGroup().name
    privateEndpointNetworkPolicies: contains(subnet, 'privateEndpointNetworkPolicies') ? subnet.privateEndpointNetworkPolicies : ''
    privateLinkServiceNetworkPolicies: contains(subnet, 'privateLinkServiceNetworkPolicies') ? subnet.privateLinkServiceNetworkPolicies : ''
    routeTableName: contains(subnet, 'routeTableName') ? subnet.routeTableName : ''
    serviceEndpointPolicies: contains(subnet, 'serviceEndpointPolicies') ? subnet.serviceEndpointPolicies : []
    serviceEndpoints: contains(subnet, 'serviceEndpoints') ? subnet.serviceEndpoints : []
  }
}]


resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(diagnosticStorageAccountId) || !empty(workspaceId) || !empty(eventHubAuthorizationRuleId) || !empty(eventHubName)) {
  name: '${virtualNetwork.name}-diagnosticSettings'
  properties: {
    storageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : null
    workspaceId: !empty(workspaceId) ? workspaceId : null
    eventHubAuthorizationRuleId: !empty(eventHubAuthorizationRuleId) ? eventHubAuthorizationRuleId : null
    eventHubName: !empty(eventHubName) ? eventHubName : null
    metrics: diagnosticsMetrics
    logs: diagnosticsLogs
  }
  scope: virtualNetwork
}

@description('The resource group the virtual network was deployed into')
output virtualNetworkResourceGroup string = resourceGroup().name

@description('The resource ID of the virtual network')
output virtualNetworkResourceId string = virtualNetwork.id

@description('The name of the virtual network')
output virtualNetworkName string = virtualNetwork.name

@description('The names of the deployed subnets')
output subnetNames array = [for subnet in subnets: subnet.name]

@description('The resource IDs of the deployed subnets')
output subnetResourceIds array = [for subnet in subnets: resourceId('Microsoft.Network/virtualNetworks/subnets', name, subnet.name)]
