@maxLength(24)
@description('Optional. Name of the Storage Account.')
param name string = ''

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Enables system assigned managed identity on the resource.')
param systemAssignedIdentity bool = false

@description('Optional. The ID(s) to assign to the resource.')
param userAssignedIdentities object = {}

@allowed([
  'Storage'
  'StorageV2'
  'BlobStorage'
  'FileStorage'
  'BlockBlobStorage'
])
@description('Optional. Type of Storage Account to create.')
param storageAccountKind string = 'StorageV2'

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
@description('Optional. Storage Account Sku Name.')
param storageAccountSku string = 'Standard_GRS'

@allowed([
  'Hot'
  'Cool'
])
@description('Optional. Storage Account Access Tier.')
param storageAccountAccessTier string = 'Hot'

@description('Optional. Virtual Network Identifier used to create a service endpoint.')
param vNetId string = ''

@description('Optional. Networks ACLs, this value contains IPs to whitelist and/or Subnet information.')
param networkAcls object = {}

@description('Optional. Indicates whether public access is enabled for all blobs or containers in the storage account.')
param allowBlobPublicAccess bool = true

@allowed([
  'TLS1_0'
  'TLS1_1'
  'TLS1_2'
])
@description('Optional. Set the minimum TLS version on request to storage.')
param minimumTlsVersion string = 'TLS1_2'

@description('Optional. If true, enables Hierarchical Namespace for the storage account')
param enableHierarchicalNamespace bool = false

@description('Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(365)
param diagnosticLogsRetentionInDays int = 90

@description('Optional. Resource ID of the diagnostic storage account.')
param diagnosticStorageAccountId string = ''

@description('Optional. Resource ID of a log analytics workspace.')
param workspaceId string = ''

@description('Optional. Resource ID of the event hub authorization rule for the Event Hubs namespace in which the event hub should be created or streamed to.')
param eventHubAuthorizationRuleId string = ''

@description('Optional. Name of the event hub within the namespace to which logs are streamed. Without this, an event hub is created for each log category.')
param eventHubName string = ''

@description('Optional. Tags of the resource.')
param tags object = {}

@description('Generated. Do not provide a value! This date value is used to generate a SAS token to access the modules.')
param basetime string = utcNow('u')

@description('Optional. The name of metrics that will be streamed.')
@allowed([
  'Transaction'
])
param metricsToEnable array = [
  'Transaction'
]

var diagnosticsMetrics = [for metric in metricsToEnable: {
  category: metric
  timeGrain: null
  enabled: true
  retentionPolicy: {
    enabled: true
    days: diagnosticLogsRetentionInDays
  }
}]

var virtualNetworkRules = [for index in range(0, (empty(networkAcls) ? 0 : length(networkAcls.virtualNetworkRules))): {
  id: '${vNetId}/subnets/${networkAcls.virtualNetworkRules[index].subnet}'
}]
var networkAcls_var = {
  bypass: (empty(networkAcls) ? null : networkAcls.bypass)
  defaultAction: (empty(networkAcls) ? null : networkAcls.defaultAction)
  virtualNetworkRules: (empty(networkAcls) ? null : virtualNetworkRules)
  ipRules: (empty(networkAcls) ? null : ((length(networkAcls.ipRules) == 0) ? null : networkAcls.ipRules))
}

var maxNameLength = 24
var uniqueStoragenameUntrim = '${uniqueString('Storage Account${basetime}')}'
var uniqueStoragename = length(uniqueStoragenameUntrim) > maxNameLength ? substring(uniqueStoragenameUntrim, 0, maxNameLength) : uniqueStoragenameUntrim

var saProperties = {
  encryption: {
    keySource: 'Microsoft.Storage'
    services: {
      blob: (((storageAccountKind == 'BlockBlobStorage') || (storageAccountKind == 'BlobStorage') || (storageAccountKind == 'StorageV2') || (storageAccountKind == 'Storage')) ? json('{"enabled": true}') : null)
    }
  }
  accessTier: (storageAccountKind == 'Storage') ? null : storageAccountAccessTier
  supportsHttpsTrafficOnly: true
  isHnsEnabled: ((!enableHierarchicalNamespace) ? null : enableHierarchicalNamespace)
  minimumTlsVersion: minimumTlsVersion
  networkAcls: (empty(networkAcls) ? null : networkAcls_var)
  allowBlobPublicAccess: allowBlobPublicAccess
}

var identityType = systemAssignedIdentity ? (!empty(userAssignedIdentities) ? 'SystemAssigned,UserAssigned' : 'SystemAssigned') : (!empty(userAssignedIdentities) ? 'UserAssigned' : 'None')

var identity = identityType != 'None' ? {
  type: identityType
  userAssignedIdentities: !empty(userAssignedIdentities) ? userAssignedIdentities : null
} : null

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: !empty(name) ? name : uniqueStoragename
  location: location
  kind: storageAccountKind
  sku: {
    name: storageAccountSku
  }
  identity: identity
  tags: tags
  properties: saProperties
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if ((!empty(diagnosticStorageAccountId)) || (!empty(workspaceId)) || (!empty(eventHubAuthorizationRuleId)) || (!empty(eventHubName))) {
  name: '${storageAccount.name}-diagnosticSettings'
  properties: {
    storageAccountId: empty(diagnosticStorageAccountId) ? null : diagnosticStorageAccountId
    workspaceId: empty(workspaceId) ? null : workspaceId
    eventHubAuthorizationRuleId: empty(eventHubAuthorizationRuleId) ? null : eventHubAuthorizationRuleId
    eventHubName: empty(eventHubName) ? null : eventHubName
    metrics: diagnosticsMetrics
  }
  scope: storageAccount
}

@description('The resource ID of the deployed storage account')
output storageAccountResourceId string = storageAccount.id

@description('The name of the deployed storage account')
output storageAccountName string = storageAccount.name

@description('The resource group of the deployed storage account')
output storageAccountResourceGroup string = resourceGroup().name
