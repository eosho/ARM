@description('Required. Name of the Log Analytics workspace')
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Required. Service Tier: PerGB2018, Free, Standalone, PerGB or PerNode')
@allowed([
  'Free'
  'Standalone'
  'PerNode'
  'PerGB2018'
])
param serviceTier string = 'PerGB2018'

@description('Optional. LAW gallerySolutions from the gallery.')
param solutions array = []

@description('Required. Number of days data will be retained for')
@minValue(0)
@maxValue(730)
param dataRetention int = 90

@description('Optional. The workspace daily quota for ingestion.')
@minValue(-1)
param dailyQuotaGb int = -1

@description('Optional. The network access type for accessing Log Analytics ingestion.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccessForIngestion string = 'Enabled'

@description('Optional. The network access type for accessing Log Analytics query.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccessForQuery string = 'Enabled'

@description('Optional. Set to \'true\' to use resource or workspace permissions and \'false\' (or leave empty) to require workspace permissions.')
param useResourcePermissions bool = false

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

@description('Optional. The name of logs that will be streamed.')
@allowed([
  'Audit'
])
param logsToEnable array = [
  'Audit'
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

var logAnalyticsSearchVersion = 1

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  location: location
  name: name
  tags: tags
  properties: {
    features: {
      searchVersion: logAnalyticsSearchVersion
      enableLogAccessUsingOnlyResourcePermissions: useResourcePermissions
    }
    sku: {
      name: serviceTier
    }
    retentionInDays: dataRetention
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
    publicNetworkAccessForIngestion: publicNetworkAccessForIngestion
    publicNetworkAccessForQuery: publicNetworkAccessForQuery
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if ((!empty(diagnosticStorageAccountId)) || (!empty(workspaceId)) || (!empty(eventHubAuthorizationRuleId)) || (!empty(eventHubName))) {
  name: '${logAnalyticsWorkspace.name}-diagnosticSettings'
  properties: {
    storageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : null
    workspaceId: !empty(workspaceId) ? workspaceId : null
    eventHubAuthorizationRuleId: !empty(eventHubAuthorizationRuleId) ? eventHubAuthorizationRuleId : null
    eventHubName: !empty(eventHubName) ? eventHubName : null
    metrics: diagnosticsMetrics
    logs: diagnosticsLogs
  }
  scope: logAnalyticsWorkspace
}

@batchSize(1)
resource logAnalyticsSolutions 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = [for i in range(0, ((length(solutions) > 0) ? length(solutions) : 1)): if (!empty(solutions)) {
  name: (empty(solutions) ? 'dummy' : '${solutions[i]}(${logAnalyticsWorkspace.name})')
  location: location
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
  }
  plan: {
    name: (empty(solutions) ? 'dummy' : '${solutions[i]}(${logAnalyticsWorkspace.name})')
    product: (empty(solutions) ? 'dummy' : 'OMSGallery/${solutions[i]}')
    promotionCode: ''
    publisher: 'Microsoft'
  }
}]

@description('The resource ID of the deployed log analytics workspace')
output logAnalyticsResourceId string = logAnalyticsWorkspace.id

@description('The resource group of the deployed log analytics workspace')
output logAnalyticsResourceGroup string = resourceGroup().name

@description('The name of the deployed log analytics workspace')
output logAnalyticsName string = logAnalyticsWorkspace.name

@description('The ID associated with the workspace')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.properties.customerId
