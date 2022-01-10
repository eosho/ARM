@description('Required. Name of the Application Insights')
param name string

@description('Optional. Application type')
@allowed([
  'web'
  'other'
])
param appInsightsType string = 'web'

@description('Required. Resource ID of the log analytics workspace which the data will be ingested to. This property is required to create an application with this API version. Applications from older versions will not have this property.')
param appInsightsWorkspaceResourceId string

@description('Optional. The network access type for accessing Application Insights ingestion. - Enabled or Disabled')
@allowed([
  'Enabled'
  'Disabled'
])
param appInsightsPublicNetworkAccessForIngestion string = 'Enabled'

@description('Optional. The network access type for accessing Application Insights query. - Enabled or Disabled')
@allowed([
  'Enabled'
  'Disabled'
])
param appInsightsPublicNetworkAccessForQuery string = 'Enabled'

@description('Optional. The kind of application that this component refers to, used to customize UI. This value is a freeform string, values should typically be one of the following: web, ios, other, store, java, phone.')
param kind string = ''

@description('Optional. Location for all Resources')
param location string = resourceGroup().location

@description('Optional. Tags of the resource.')
param tags object = {}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    Application_Type: appInsightsType
    WorkspaceResourceId: appInsightsWorkspaceResourceId
    publicNetworkAccessForIngestion: appInsightsPublicNetworkAccessForIngestion
    publicNetworkAccessForQuery: appInsightsPublicNetworkAccessForQuery
  }
}

@description('The name of the application insights component')
output appInsightsName string = appInsights.name

@description('The resource ID of the application insights component')
output appInsightsResourceId string = appInsights.id

@description('The resource group the application insights component was deployed into')
output appInsightsResourceGroup string = resourceGroup().name

@description('The application ID of the application insights component')
output appInsightsAppId string = appInsights.properties.AppId
