@metadata({
  description: 'Resource tags.'
  required: 'no'
})
param tags object

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Required. Name of the App Service Environment')
@minLength(1)
param name string

@description('Optional. Kind of resource.')
@allowed([
  'ASEV2'
  'ASEV3'
])
param kind string = 'ASEV2'

@description('Front-end VM size, e.g. "Medium", "Large".')
@allowed([
  'Small'
  'Medium'
  'Large'
  'ExtraLarge'
])
param multiSize string = 'Small'

@metadata({
  description: 'Scale factor for front-ends.'
  required: 'no'
})
@minValue(5)
@maxValue(15)
param frontEndScaleFactor int = 5

@metadata({
  description: 'DNS suffix of the App Service Environment.'
  required: 'no'
})
@minLength(0)
@maxLength(253)
param dnsSuffix string = ''

@metadata({
  description: 'Custom settings for changing the behavior of the App Service Environment.'
  required: 'no'
  subType: 'object'
  subTypeDefinition: {
    name: {
      type: 'string'
      metadata: {
        description: 'Pair name.'
        required: 'no'
      }
    }
    value: {
      type: 'string'
      metadata: {
        description: 'Pair value.'
        required: 'no'
      }
    }
  }
})
param clusterSettings array = []

@metadata({
  description: 'Number of IP SSL addresses reserved for the App Service Environment.'
  required: 'no'
})
@minValue(0)
@maxValue(100)
param ipsslAddressCount int = 0

@metadata({
  description: 'User added ip ranges to whitelist on ASE db'
  required: 'no'
})
param userWhitelistedIpRanges array = []

@description('Required. ResourceId for the sub net')
param subnetResourceId string

@description('Optional. Specifies which endpoints to serve internally in the Virtual Network for the App Service Environment. - None, Web, Publishing, Web,Publishing')
@allowed([
  'None'
  'Web'
  'Publishing'
])
param internalLoadBalancingMode string = 'None'

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

@description('Optional. The name of logs that will be streamed.')
@allowed([
  'AppServiceEnvironmentPlatformLogs'
])
param logsToEnable array = [
  'AppServiceEnvironmentPlatformLogs'
]

var diagnosticsLogs = [for log in logsToEnable: {
  category: log
  enabled: true
  retentionPolicy: {
    enabled: true
    days: diagnosticLogsRetentionInDays
  }
}]

var isV3 = (kind == 'ASEV3')
var vnetResourceId = split(subnetResourceId, '/')
var clusterSettings_var = [for item in clusterSettings: {
  name: (contains(item, 'name') ? item.name : null)
  value: (contains(item, 'value') ? item.value : null)
}]

resource appServiceEnvironment 'Microsoft.Web/hostingEnvironments@2021-02-01' = {
  name: name
  location: location
  kind: kind
  tags: tags
  properties: {
    multiSize: ((!isV3) ? multiSize : null)
    dnsSuffix: dnsSuffix
    ipsslAddressCount: ipsslAddressCount
    internalLoadBalancingMode: internalLoadBalancingMode
    frontEndScaleFactor: ((!isV3) ? frontEndScaleFactor : null)
    clusterSettings: clusterSettings_var
    userWhitelistedIpRanges: ((!isV3) ? userWhitelistedIpRanges : null)
    virtualNetwork: {
      id: subnetResourceId
      subnet: last(vnetResourceId)
    }
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(diagnosticStorageAccountId) || !empty(diagnosticWorkspaceId) || !empty(diagnosticEventHubAuthorizationRuleId) || !empty(diagnosticEventHubName)) {
  name: '${appServiceEnvironment.name}-diagnosticSettings'
  properties: {
    storageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : null
    workspaceId: !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : null
    eventHubAuthorizationRuleId: !empty(diagnosticEventHubAuthorizationRuleId) ? diagnosticEventHubAuthorizationRuleId : null
    eventHubName: !empty(diagnosticEventHubName) ? diagnosticEventHubName : null
    logs: diagnosticsLogs
  }
  scope: appServiceEnvironment
}

@description('The resource ID of the app service environment')
output appServiceEnvironmentResourceId string = appServiceEnvironment.id

@description('The resource group the app service environment was deployed into')
output appServiceEnvironmentResourceGroup string = resourceGroup().name

@description('The name of the app service environment')
output appServiceEnvironmentName string = appServiceEnvironment.name
