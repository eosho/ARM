@description('Required. The name of the app service plan to deploy.')
@minLength(1)
@maxLength(40)
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@metadata({
  description: 'Current number of instances assigned to the resource.'
})
@minValue(0)
@maxValue(100)
param skuCapacity int = 1

@metadata({
  description: 'Name of the resource SKU.'
  required: 'no'
})
@allowed([
  'S1'
  'S2'
  'S3'
  'P1'
  'P2'
  'P3'
  'P1V2'
  'P2V2'
  'P3V2'
  'P1V3'
  'P2V3'
  'P3V3'
  'I1'
  'I2'
  'I3'
  'EP1'
  'EP2'
  'EP3'
])
param skuName string

@metadata({
  description: 'Family code of the resource SKU.'
})
@allowed([
  ''
])
param skuFamily string = ''

@metadata({
  description: 'Size specifier of the resource SKU.'
})
@allowed([
  ''
])
param skuSize string = ''

@description('Optional. Kind of server OS.')
@allowed([
  'Windows'
  'Linux'
])
param serverOS string = 'Windows'

@description('Optional. The Resource ID of the App Service Environment to use for the App Service Plan.')
param appServiceEnvironmentId string = ''

@description('Optional. Target worker tier assigned to the App Service plan.')
param workerTierName string = ''

@description('Optional. If true, apps assigned to this App Service plan can be scaled independently. If false, apps assigned to this App Service plan will scale to all instances of the plan.')
param perSiteScaling bool = false

@description('Optional. Maximum number of total workers allowed for this ElasticScaleEnabled App Service Plan.')
param maximumElasticWorkerCount int = 1

@description('Optional. Scaling worker count.')
param targetWorkerCount int = 0

@description('Optional. The instance size of the hosting plan (small, medium, or large).')
@allowed([
  0
  1
  2
])
param targetWorkerSize int = 0

@description('Optional. Tags of the resource.')
param tags object = {}

var skuTiers = {
  S: 'Standard'
  P: 'Premium'
  E: 'ElasticPremium'
  I: 'Isolated'
}
var skuTier = '${skuTiers[first(skuName)]}${(contains(skuName, 'V2') ? 'V2' : '')}'
var hostingEnvironmentProfile = {
  id: appServiceEnvironmentId
}

resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: name
  kind: serverOS == 'Windows' ? '' : 'linux'
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
    capacity: skuCapacity
    size: skuSize
    family: skuFamily
  }
  properties: {
    workerTierName: workerTierName
    hostingEnvironmentProfile: !empty(appServiceEnvironmentId) ? hostingEnvironmentProfile : null
    perSiteScaling: perSiteScaling
    maximumElasticWorkerCount: maximumElasticWorkerCount
    reserved: serverOS == 'Linux'
    targetWorkerCount: targetWorkerCount
    targetWorkerSizeId: targetWorkerSize
  }
}

@description('The resource group the app service plan was deployed into')
output appServicePlanResourceGroup string = resourceGroup().name

@description('The name of the app service plan')
output appServicePlanName string = appServicePlan.name

@description('The resource ID of the app service plan')
output appServicePlanResourceId string = appServicePlan.id
