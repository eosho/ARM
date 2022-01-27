@description('Required. Name of your Azure container registry')
@minLength(5)
@maxLength(50)
param name string

@description('Optional. Enable admin user that have push / pull permission to the registry.')
param acrAdminUserEnabled bool = false

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Tier of your Azure container registry.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Basic'

@description('Optional. The value that indicates whether the policy is enabled or not.')
param quarantinePolicyStatus string = ''

@description('Optional. The value that indicates whether the policy is enabled or not.')
param trustPolicyStatus string = ''

@description('Optional. The value that indicates whether the policy is enabled or not.')
param retentionPolicyStatus string = ''

@description('Optional. The number of days to retain an untagged manifest after which it gets purged.')
param retentionPolicyDays string = ''

@description('Optional. Enable a single data endpoint per region for serving data. Not relevant in case of disabled public access.')
param dataEndpointEnabled bool = false

@description('Optional. Whether or not public network access is allowed for the container registry. - Enabled or Disabled')
param publicNetworkAccess string = 'Enabled'

@description('Optional. Whether to allow trusted Azure services to access a network restricted registry. Not relevant in case of public access. - AzureServices or None')
param networkRuleBypassOptions string = 'AzureServices'

@description('Optional. Enables system assigned managed identity on the resource.')
param systemAssignedIdentity bool = false

@description('Optional. The ID(s) to assign to the resource.')
param userAssignedIdentities object = {}

@description('Optional. Tags of the resource.')
param tags object = {}

@description('Optional. The name of logs that will be streamed.')
@allowed([
  'ContainerRegistryRepositoryEvents'
  'ContainerRegistryLoginEvents'
])
param logsToEnable array = [
  'ContainerRegistryRepositoryEvents'
  'ContainerRegistryLoginEvents'
]

@description('Optional. The name of metrics that will be streamed.')
@allowed([
  'AllMetrics'
])
param metricsToEnable array = [
  'AllMetrics'
]

@description('Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(365)
param diagnosticLogsRetentionInDays int = 365

@description('Optional. Resource ID of the diagnostic storage account.')
param diagnosticStorageAccountId string = ''

@description('Optional. Resource ID of the diagnostic log analytics workspace.')
param diagnosticWorkspaceId string = ''

@description('Optional. Resource ID of the diagnostic event hub authorization rule for the Event Hubs namespace in which the event hub should be created or streamed to.')
param diagnosticEventHubAuthorizationRuleId string = ''

@description('Optional. Name of the diagnostic event hub within the namespace to which logs are streamed. Without this, an event hub is created for each log category.')
param diagnosticEventHubName string = ''

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

var identityType = systemAssignedIdentity ? (!empty(userAssignedIdentities) ? 'SystemAssigned,UserAssigned' : 'SystemAssigned') : (!empty(userAssignedIdentities) ? 'UserAssigned' : 'None')

var identity = identityType != 'None' ? {
  type: identityType
  userAssignedIdentities: !empty(userAssignedIdentities) ? userAssignedIdentities : null
} : null

resource registry 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' = {
  name: name
  location: location
  identity: identity
  tags: tags
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: acrAdminUserEnabled
    policies: {
      quarantinePolicy: {
        status: (empty(quarantinePolicyStatus) ? null : quarantinePolicyStatus)
      }
      trustPolicy: {
        type: 'Notary'
        status: (empty(trustPolicyStatus) ? null : trustPolicyStatus)
      }
      retentionPolicy: {
        days: (empty(retentionPolicyDays) ? null : int(retentionPolicyDays))
        status: (empty(retentionPolicyStatus) ? null : retentionPolicyStatus)
      }
    }
    dataEndpointEnabled: dataEndpointEnabled
    publicNetworkAccess: publicNetworkAccess
    networkRuleBypassOptions: networkRuleBypassOptions
  }
}

resource registry_diagnosticSettingName 'Microsoft.Insights/diagnosticsettings@2021-05-01-preview' = if ((!empty(diagnosticStorageAccountId)) || (!empty(diagnosticWorkspaceId)) || (!empty(diagnosticEventHubAuthorizationRuleId)) || (!empty(diagnosticEventHubName))) {
  name: '${registry.name}-diagnosticSettings'
  properties: {
    storageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : null
    workspaceId: !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : null
    eventHubAuthorizationRuleId: !empty(diagnosticEventHubAuthorizationRuleId) ? diagnosticEventHubAuthorizationRuleId : null
    eventHubName: !empty(diagnosticEventHubName) ? diagnosticEventHubName : null
    metrics: diagnosticsMetrics
    logs: diagnosticsLogs
  }
  scope: registry
}

@description('The Name of the Azure container registry.')
output acrName string = registry.name

@description('The reference to the Azure container registry.')
output acrLoginServer string = reference(registry.id, '2019-05-01').loginServer

@description('The name of the Azure container registry.')
output acrResourceGroup string = resourceGroup().name

@description('The resource ID of the Azure container registry.')
output acrResourceId string = registry.id

@description('The principal ID of the system assigned identity.')
output systemAssignedPrincipalId string = systemAssignedIdentity && contains(registry.identity, 'principalId') ? registry.identity.principalId : ''
