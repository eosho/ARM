@description('The name of the deployment environment.')
param environmentName string

@metadata({
  description: 'Sets a list of key value pairs that describe the resource. These tags can be used for viewing and grouping this resource (across resource groups). A maximum of 15 tags can be provided for a resource. Each tag must have a key with a length no greater than 128 characters and a value with a length no greater than 256 characters.'
  required: 'no'
})
param tags object

@maxLength(24)
@description('Optional. Name of the Storage Account.')
param name string = ''

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@metadata({
  description: 'The SKU name. Required for account creation; optional for update. Note that in older versions, SKU name was called accountType.'
  required: 'yes'
})
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
param skuName string = 'Standard_LRS'

@metadata({
  description: 'Required. Indicates the type of storage account.'
  required: 'yes'
})
@allowed([
  'StorageV2'
  'BlobStorage'
  'FileStorage'
  'BlockBlobStorage'
])
param kind string = 'StorageV2'

@metadata({
  description: 'Required for storage accounts. The access tier used for billing.'
  required: 'no'
})
@allowed([
  'Hot'
  'Cool'
])
param accessTier string = 'Hot'

@metadata({
  description: 'Allow large file shares if sets to Enabled. It cannot be disabled once it is enabled.'
  required: 'no'
})
@allowed([
  'Disabled'
  'Enabled'
])
param largeFileSharesState string = 'Disabled'

@metadata({
  description: 'List of virtual networks that are allowed to talk to this resource.'
  required: 'no'
  subType: 'string'
})
param allowedVirtualNetworks array = []

@metadata({
  description: 'List of IpRules'
  subType: 'ipv4'
})
param allowedIpAddresses array = []

@metadata({
  description: 'Routing Choice defines the kind of network routing opted by the user.'
  required: 'no'
})
@allowed([
  'MicrosoftRouting'
  'InternetRouting'
])
param routingPreference string = 'MicrosoftRouting'

@metadata({
  description: 'Allow or disallow public access to all blobs or containers in the storage account. The default interpretation is true for this property.'
  required: 'no'
})
param allowBlobPublicAccess bool = true

@allowed([
  'TLS1_0'
  'TLS1_1'
  'TLS1_2'
])
@description('Optional. Set the minimum TLS version on request to storage.')
param minimumTlsVersion string = 'TLS1_2'

@description('Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(365)
param diagnosticLogsRetentionInDays int = 90

@description('Optional. Resource ID of the diagnostic storage account.')
param diagnosticStorageAccountId string = ''

@description('Optional. Resource ID of a log analytics workspace.')
param diagnosticWorkspaceId string = ''

@description('Optional. Resource ID of the event hub authorization rule for the Event Hubs namespace in which the event hub should be created or streamed to.')
param eventHubAuthorizationRuleId string = ''

@description('Optional. Name of the event hub within the namespace to which logs are streamed. Without this, an event hub is created for each log category.')
param eventHubName string = ''

@description('Optional. The name of metrics that will be streamed.')
@allowed([
  'Transaction'
])
param metricsToEnable array = [
  'Transaction'
]

@description('Optional. The Storage Account ManagementPolicies Rules.')
param managementPolicyRules array = []

var diagnosticsMetrics = [for metric in metricsToEnable: {
  category: metric
  timeGrain: null
  enabled: true
  retentionPolicy: {
    enabled: true
    days: diagnosticLogsRetentionInDays
  }
}]
var isProd = (environmentName == 'prod')
var gatewayIpAddresses = [
  '204.15.117.96/30'
  '204.15.117.100/30'
  '204.15.117.104/29'
]
var datacenterIpAddresses = [
  '63.73.199.0/24'
  '63.239.17.0/24'
  '204.15.116.0/22'
  '209.65.11.0/24'
]
var prodIpAddresses = [
  '40.67.188.50'
  '52.177.84.230'
  '52.155.224.242'
  '51.105.163.210'
  '20.36.252.188'
]
var nonProdIpAddresses = [
  '52.230.220.128'
  '40.65.233.76'
  '52.155.224.148'
  '51.105.144.11'
]
var allowedIpAddresses_var = union(gatewayIpAddresses, datacenterIpAddresses, (isProd ? prodIpAddresses : nonProdIpAddresses), allowedIpAddresses)
var routingPreference_var = {
  routingChoice: routingPreference
  publishMicrosoftEndpoints: false
  publishInternetEndpoints: false
}
var skuTier = split(skuName, '_')[0]
var networkAclsVirtualNetworkRules = [for item in allowedVirtualNetworks: {
  id: item
  action: 'Allow'
}]
var networkAclsIpRules = [for item in allowedIpAddresses_var: {
  value: item
  action: 'Allow'
}]

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = if (true) {
  name: name
  location: location
  sku: {
    tier: skuTier
    name: skuName
  }
  kind: kind
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: networkAclsVirtualNetworkRules
      ipRules: networkAclsIpRules
      defaultAction: 'Deny'
    }
    accessTier: accessTier
    supportsHttpsTrafficOnly: true
    largeFileSharesState: largeFileSharesState
    routingPreference: routingPreference_var
    allowBlobPublicAccess: allowBlobPublicAccess
    minimumTlsVersion: minimumTlsVersion
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if ((!empty(diagnosticStorageAccountId)) || (!empty(diagnosticWorkspaceId)) || (!empty(eventHubAuthorizationRuleId)) || (!empty(eventHubName))) {
  name: '${storageAccount.name}-diagnosticSettings'
  properties: {
    storageAccountId: empty(diagnosticStorageAccountId) ? null : diagnosticStorageAccountId
    workspaceId: empty(diagnosticWorkspaceId) ? null : diagnosticWorkspaceId
    eventHubAuthorizationRuleId: empty(eventHubAuthorizationRuleId) ? null : eventHubAuthorizationRuleId
    eventHubName: empty(eventHubName) ? null : eventHubName
    metrics: diagnosticsMetrics
  }
  scope: storageAccount
}

module managementPolicies 'managementPolicies/deploy.bicep' = if (!empty(managementPolicyRules)) {
  name: '${uniqueString(deployment().name, location)}-Storage-ManagementPolicies'
  params: {
    storageAccountName: storageAccount.name
    rules: managementPolicyRules
  }
}

@description('The resource ID of the deployed storage account')
output storageAccountResourceId string = storageAccount.id

@description('The name of the deployed storage account')
output name string = storageAccount.name

@description('The resource group of the deployed storage account')
output resourceGroupName string = resourceGroup().name

@description('The principal ID of the system assigned identity.')
output systemAssignedPrincipalId string = storageAccount.identity.principalId
