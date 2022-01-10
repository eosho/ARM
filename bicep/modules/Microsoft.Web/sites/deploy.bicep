@description('Required. Name of the site.')
param name string

@description('Optional. Location for all Resources.')
param location string = resourceGroup().location

@description('Required. Type of site to deploy.')
@allowed([
  'functionapp'
  'app'
])
param kind string

@description('Optional. Configures a site to accept only HTTPS requests. Issues redirect for HTTP requests.')
param httpsOnly bool = true

@description('Optional. If client affinity is enabled.')
param clientAffinityEnabled bool = true

@description('Optional. Configuration of the app.')
param siteConfig object = {}

@description('Optional. Required if functionapp kind. The resource ID of the storage account to manage triggers and logging function executions.')
param storageAccountId string = ''

@description('Optional. Runtime of the function worker.')
@allowed([
  'dotnet'
  'node'
  'python'
  'java'
  'powershell'
  ''
])
param functionsWorkerRuntime string = ''

@description('Optional. Version if the function extension.')
param functionsExtensionVersion string = '~3'

@description('Optional. The resource ID of the app service plan to use for the site. If not provided, the appServicePlanObject is used to create a new plan.')
param appServicePlanId string = ''

@description('Optional. The resource ID of the existing app insight to leverage for the app. If the resource ID is not provided, the appInsightObject can be used to create a new app insight.')
param appInsightId string = ''

@description('Optional. The resource ID of the app service environment to use for this resource.')
param appServiceEnvironmentId string = ''

@description('Optional. Enables system assigned managed identity on the resource.')
param systemAssignedIdentity bool = false

@description('Optional. The ID(s) to assign to the resource.')
param userAssignedIdentities object = {}

@description('Optional. Tags of the resource.')
param tags object = {}

@description('Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(365)
param diagnosticLogsRetentionInDays int = 90

@description('Optional. Resource ID of the diagnostic storage account.')
param diagnosticStorageAccountId string = ''

@description('Optional. Resource ID of log analytics workspace.')
param workspaceId string = ''

@description('Optional. Resource ID of the event hub authorization rule for the event hub namespace in which the event hub should be created or streamed to.')
param eventHubAuthorizationRuleId string = ''

@description('Optional. Name of the event hub within the namespace to which logs are streamed. Without this, an event hub is created for each log category.')
param eventHubName string = ''

@description('Optional. The name of logs that will be streamed.')
@allowed([
  'AppServiceHTTPLogs'
  'AppServiceConsoleLogs'
  'AppServiceAppLogs'
  'AppServiceFileAuditLogs'
  'AppServiceAuditLogs'
  'FunctionAppLogs'
])
param logsToEnable array = kind == 'functionapp' ? [
  'FunctionAppLogs'
] : [
  'AppServiceHTTPLogs'
  'AppServiceConsoleLogs'
  'AppServiceAppLogs'
  'AppServiceFileAuditLogs'
  'AppServiceAuditLogs'
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

var identityType = systemAssignedIdentity ? (!empty(userAssignedIdentities) ? 'SystemAssigned,UserAssigned' : 'SystemAssigned') : (!empty(userAssignedIdentities) ? 'UserAssigned' : 'None')

var identity = identityType != 'None' ? {
  type: identityType
  userAssignedIdentities: !empty(userAssignedIdentities) ? userAssignedIdentities : null
} : null

resource appServicePlanExisting 'Microsoft.Web/serverfarms@2021-02-01' existing = if (!empty(appServicePlanId)) {
  name: last(split(appServicePlanId, '/'))
  scope: resourceGroup(split(appServicePlanId, '/')[2], split(appServicePlanId, '/')[4])
}

resource app 'Microsoft.Web/sites@2020-12-01' = {
  name: name
  location: location
  kind: kind
  tags: tags
  identity: identity
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: httpsOnly
    hostingEnvironmentProfile: !empty(appServiceEnvironmentId) ? {
      id: appServiceEnvironmentId
    } : null
    clientAffinityEnabled: clientAffinityEnabled
    siteConfig: siteConfig
  }
}

module appsettings 'config/deploy.bicep' = {
  name: '${uniqueString(deployment().name, location)}-Site-Config'
  params: {
    name: 'appsettings'
    appName: app.name
    storageAccountId: !empty(storageAccountId) ? storageAccountId : ''
    appInsightId: !empty(appInsightId) ? appInsightId : ''
    functionsWorkerRuntime: !empty(functionsWorkerRuntime) ? functionsWorkerRuntime : ''
    functionsExtensionVersion: !empty(functionsExtensionVersion) ? functionsExtensionVersion : '~3'
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(diagnosticStorageAccountId) || !empty(workspaceId) || !empty(eventHubAuthorizationRuleId) || !empty(eventHubName)) {
  name: '${app.name}-diagnosticSettings'
  properties: {
    storageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : null
    workspaceId: !empty(workspaceId) ? workspaceId : null
    eventHubAuthorizationRuleId: !empty(eventHubAuthorizationRuleId) ? eventHubAuthorizationRuleId : null
    eventHubName: !empty(eventHubName) ? eventHubName : null
    metrics: diagnosticsMetrics
    logs: diagnosticsLogs
  }
  scope: app
}

@description('The name of the site.')
output siteName string = app.name

@description('The resource ID of the site.')
output siteResourceId string = app.id

@description('The resource group the site was deployed into.')
output siteResourceGroup string = resourceGroup().name

@description('The principal ID of the system assigned identity.')
output systemAssignedPrincipalId string = systemAssignedIdentity ? app.identity.principalId : ''
