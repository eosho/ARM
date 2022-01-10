targetScope = 'subscription'

@description('The name of the deployment environment. Used for naming convention')
@allowed([
  'dev'
  'qa'
  'prod'
])
param environmentName string

@description('Name of the project. Used for naming convention')
param projectName string = 'cust-wap'

@description('Azure resource tags metadata')
param tags object = {
  CostCenter: 'Marketing Technology'
  LegalSubEntity: 'Walgreen Co'
  Sensitivity: 'Non-Sensitive'
  SubDivision: 'Digital Engineering'
  Department: 'Digital Engineering'
  SenType: 'Not Applicable'
}

@description('The name of the resource group for deployment.')
param resourceGroupName string

@description('The name of the virtual network.')
param virtualNetworkName string

@description('The name of the virtual network resource group.')
param virtualNetworkResourceGroupName string

@description('Name of the Storage Account.')
param storageAccountName string

@description('Name of the Application Gateway.')
param appGatewayName string

@description('Name of the shared APIM resource.')
param apiManagementName string

@description('Name of the shared APIM resource group.')
param apiManagementResourceGroupName string

@description('Name of the shared App Service Environment.')
param appServiceEnvironmentName string

@description('Name of the CosmosDB resource.')
param cosmosDbName string

@description('Name of the Redis cache resource.')
param redisCacheName string

@description('Name of the Key Vault.')
param keyVaultName string

@description('The name of the app service plan to deploy.')
param appServicePlanName string

@description('Name of the Log Analytics workspace')
param workspaceName string

@description('Name of the Application Insights')
param appInsightsName string

@description('Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(365)
param diagnosticLogsRetentionInDays int = 90

var environmentNamingPrefix = isProd ? 'prod' : 'nprod'
var namingPrefix = '${environmentNamingPrefix}-${projectName}'
var isProd = (environmentName == 'prod')
var nonProdEnvTypeTag = {
  EnvType: 'Non-Production'
}
var prodEnvTypeTag = {
  EnvType: 'Production'
}
var resourceTags = union(tags, (isProd ? prodEnvTypeTag : nonProdEnvTypeTag))

/*
  Existing resources
*/

// Virturl Network resource group
resource vnetRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: virtualNetworkResourceGroupName
}

// Virturl Network resource group
resource apimRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: apiManagementResourceGroupName
}

// Virtual Network
resource vnet 'Microsoft.Network/applicationGateways@2021-05-01' existing = {
  scope: resourceGroup(vnetRg.name)
  name: virtualNetworkName
}

// API Management (shared instance)
resource apim 'Microsoft.ApiManagement/service@2021-08-01' existing = {
  scope: resourceGroup(apimRg.name)
  name: apiManagementName
}

// App Gateway (shared instance)
resource appGateway 'Microsoft.Network/applicationGateways@2021-05-01' existing = {
  scope: resourceGroup(rg.name)
  name: appGatewayName
}

// App Service Environment (shared instance)
resource appServiceEnvironment 'Microsoft.Web/hostingEnvironments@2021-01-15' existing = {
  scope: resourceGroup(rg.name)
  name: appServiceEnvironmentName
}

/*
  New resources
*/

// Deploy resource group
module rg 'Microsoft.Resources/resourceGroups/deploy.bicep' = {
  name: '${resourceGroupName}-rg'
  params: {
    name: resourceGroupName
    tags: resourceTags
  }
}

// Redis Cache
module redisCache 'Microsoft.Cache/redis/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${redisCacheName}-redis'
  params: {
    existingSubnetName: ''
    existingVirtualNetworkName: vnet.name
    name: redisCacheName
    workspaceResourceId: workspace.outputs.logAnalyticsResourceId
    tags: resourceTags
  }
}

// Cosmos DB
module cosmosDb 'Microsoft.DocumentDB/databaseAccounts/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${cosmosDbName}-cosmosdb'
  params: {
    name: cosmosDbName
    publicNetworkAccess: 'Disabled'
    tags: resourceTags
  }
}

// Deploy Cosmos DB prvivate endpoint
module cosmosDbPrivateEndpoint 'Microsoft.Network/privateEndpoints/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${cosmosDbName}-private-endpoint'
  params: {
    name: '${uniqueString(deployment().name)}-CosmosDb-PrivateEndpoint'
    targetSubnetResourceId: ''
    groupId: [
      'sql'
    ]
    serviceResourceId: cosmosDb.outputs.cosmosDbResourceId
    tags: resourceTags
  }
}

// Event Hub


// Deploy log analytics workspace
module workspace 'Microsoft.OperationalInsights/workspaces/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${workspaceName}-workspace'
  params: {
    name: workspaceName
    tags: resourceTags
  }
}

// Deploy storage account
module storage 'Microsoft.Storage/storageAccounts/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${storageAccountName}-storage'
  params: {
    name: storageAccountName
    storageAccountKind: 'StorageV2'
    vNetId: vnet.id
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
    }
    workspaceId: workspace.outputs.logAnalyticsResourceId
    storageAccountAccessTier: 'Hot'
    tags: resourceTags
  }
}

// Deploy storage prvivate endpoint
module storagePrivateEndpoint 'Microsoft.Network/privateEndpoints/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${storageAccountName}-private-endpoint'
  params: {
    name: '${uniqueString(deployment().name)}-Storage-PrivateEndpoint'
    targetSubnetResourceId: ''
    groupId: [
      'blob'
    ]
    serviceResourceId: storage.outputs.storageAccountResourceId
    tags: resourceTags
  }
}

// Deploy key vault
module keyVault 'Microsoft.KeyVault/vaults/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${keyVaultName}-keyvault'
  params: {
    name: keyVaultName
    accessPolicies: []
    enableVaultForDeployment: true
    enableVaultForTemplateDeployment: true
    enableVaultForDiskEncryption: false
    softDeleteRetentionInDays: 1
    vaultSku: 'premium'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
    }
    vNetId: vnet.id
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    workspaceId: workspace.outputs.logAnalyticsResourceId
    tags: resourceTags
  }
}

// Deploy key vault prvivate endpoint
module keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${keyVaultName}-private-endpoint'
  params: {
    name: '${uniqueString(deployment().name)}-KeyVault-PrivateEndpoint'
    targetSubnetResourceId: ''
    groupId: [
      'vault'
    ]
    serviceResourceId: keyVault.outputs.keyVaultResourceId
    tags: resourceTags
  }
}

// Deploy app insights
module appInsights 'Microsoft.Insights/components/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${appInsightsName}-app-insights'
  params: {
    appInsightsWorkspaceResourceId: workspace.outputs.logAnalyticsResourceId
    name: appInsightsName
    tags: resourceTags
  }
}

// Deploy app service plan
module appServicePlan 'Microsoft.Web/serverfarms/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${appServicePlanName}-app-service-plan'
  params: {
    name: appServicePlanName
    skuName: 'I1'
    skuFamily: ''
    skuCapacity: 1
    serverOS: 'Linux'
    appServiceEnvironmentId: ''
    tags: resourceTags
  }
}

// Deploy web app for api portal
module devPortalWebApp 'Microsoft.Web/sites/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'apiDevPortal'
  params: {
    kind: 'app'
    name: '${namingPrefix}-api-portal-app'
    storageAccountId: storage.outputs.storageAccountResourceId
    appInsightId: appInsights.outputs.appInsightsResourceId
    appServicePlanId: appServicePlan.outputs.appServicePlanResourceId
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    tags: resourceTags
  }
}

// Deploy function app for vendor setup API
module vendorSetupAPIFuncApp 'Microsoft.Web/sites/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'apiDevPortal'
  params: {
    kind: 'functionapp'
    name: '${namingPrefix}-vendor-setup-api-func'
    storageAccountId: storage.outputs.storageAccountResourceId
    functionsWorkerRuntime: 'java'
    appInsightId: appInsights.outputs.appInsightsResourceId
    appServicePlanId: appServicePlan.outputs.appServicePlanResourceId
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    tags: resourceTags
  }
}

// Deploy web app for vendor setup UI
module vendorSetupUIWebApp 'Microsoft.Web/sites/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'apiDevPortal'
  params: {
    kind: 'app'
    name: '${namingPrefix}-vendor-setup-ui-app'
    storageAccountId: storage.outputs.storageAccountResourceId
    appInsightId: appInsights.outputs.appInsightsResourceId
    appServicePlanId: appServicePlan.outputs.appServicePlanResourceId
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    tags: resourceTags
  }
}

// Deploy web app for photo prints HTML checkout
module photoPrintsWebApp 'Microsoft.Web/sites/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'apiDevPortal'
  params: {
    kind: 'app'
    name: '${namingPrefix}-photo-prints-app'
    storageAccountId: storage.outputs.storageAccountResourceId
    appInsightId: appInsights.outputs.appInsightsResourceId
    appServicePlanId: appServicePlan.outputs.appServicePlanResourceId
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    tags: resourceTags
  }
}

// Deploy web app for RxTransfer/RxRefill HTML checkout
module rxHTMLCheckoutWebApp 'Microsoft.Web/sites/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'apiDevPortal'
  params: {
    kind: 'app'
    name: '${namingPrefix}-rx-checkout-app'
    storageAccountId: storage.outputs.storageAccountResourceId
    appInsightId: appInsights.outputs.appInsightsResourceId
    appServicePlanId: appServicePlan.outputs.appServicePlanResourceId
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    tags: resourceTags
  }
}
