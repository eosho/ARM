targetScope = 'subscription'

/******************************************************************************
  Parameters
*/

@description('The name of the deployment environment. Used for naming convention')
@allowed([
  'int'
  'dev'
  'qa'
  'prod'
])
param environmentName string

@description('Name of the project. Used for naming convention')
param projectName string = 'cust-wap'

@description('Azure resource tags metadata')
param tags object = {
  DeptName: 'Innovation'
  LOB: 'Innovation'
  DeployDate: '01-07-2022'
  Deployer: 'Rudi Landolt'
  CostCenter: 'IT Innovation 5001'
  CostCode: '1000608610'
  LegalSubEntity: 'Walgreen Co'
  Sensitivity: 'Non-Sensitive'
  SubDivision: 'Innovation'
  Department: 'Innovation'
  SenType: 'Not Applicable'
}

@description('The name of the resource group for deployment.')
param resourceGroupName string

@description('The name of the virtual network.')
param virtualNetworkName string

@description('The name of the virtual network resource group.')
param virtualNetworkResourceGroupName string

@description('APIM APIs.')
param apimApis array

@description('APIM Policies.')
param apimPolicies array

@description('Optional. Authorization servers.')
param apimAuthorizationServers array = []

@description('Optional. Backends.')
param apimBackends array = []

@description('Optional. Caches.')
param apimCaches array = []

@description('Optional. Identity providers.')
param apimIdentityProviders array = []

@description('Optional. Named values.')
param apimNamedValues array = []

@description('Optional. Portal settings.')
param apimPortalSettings array = []

@description('Optional. Products.')
param apimProducts array = []

@description('Optional. Subscriptions.')
param apimSubscriptions array = []

@description('Name of the shared APIM resource group.')
param apimResourceGroupName string

@description('The email address of the owner of the service')
param apimPublisherEmail string = 'admin@contoso.com'

@description('The name of the publisher.')
param apimPublisherName string = 'Contoso'

@description('Optional. The pricing tier of this API Management service.')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Standard'
  'Premium'
])
param apimSku string = 'Developer'

@description('Name of the shared resource group.')
param sharedResourceGroupName string = 'rpu-nprod-digital-eastus2-ase-02-rg'

@description('Name of the shared App Service Environment.')
param appServiceEnvironmentName string = 'rpu-nprod-innov-eti-eastus2-asev3-01'

@description('The name of the app service plan to deploy.')
param appServicePlanName string = 'nprod-innov-eti-mvp-asp-01'

@description('Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(90)
param diagnosticLogsRetentionInDays int = 90

/******************************************************************************
  Variables
*/

var environmentNamingPrefix = isProd ? 'prod' : 'nprod'
var namingPrefixHyphen = 'rpu-${environmentNamingPrefix}-${projectName}'
var namingPrefixNoHyphen = 'rpu${environmentNamingPrefix}${projectName}'
var isProd = (environmentName == 'prod')
var nonProdEnvTypeTag = {
  EnvType: 'Non-Production'
}
var prodEnvTypeTag = {
  EnvType: 'Production'
}
var resourceTags = union(tags, (isProd ? prodEnvTypeTag : nonProdEnvTypeTag))
var storageAccountName = '${namingPrefixNoHyphen}storg01'
var keyVaultName = '${namingPrefixHyphen}-kv-01'
var workspaceName = '${namingPrefixHyphen}-ws-01'
var appInsightsName = '${namingPrefixHyphen}-appins-01'
var cosmosDbName = '${namingPrefixHyphen}-cosmosdb-01'
var redisCacheName = '${namingPrefixHyphen}-rediscache-01'
var appGatewayName = '${namingPrefixHyphen}-appgw-01'
var apimName = '${namingPrefixHyphen}-apim-01'
var containerRegistryName = '${namingPrefixNoHyphen}acr01'

/******************************************************************************
  Existing resources
*/

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  scope: resourceGroup(virtualNetworkResourceGroupName)
  name: virtualNetworkName
}

// App Gateway (shared instance)
resource appGateway 'Microsoft.Network/applicationGateways@2021-05-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: appGatewayName
}

// App Service Environment - deployed via CCP
resource appServiceEnvironment 'Microsoft.Web/hostingEnvironments@2021-01-15' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: appServiceEnvironmentName
}

// Container registry - deployed via CCP
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: containerRegistryName
}

/******************************************************************************
  New resources
*/

// Deploy resource group
module rg 'Microsoft.Resources/resourceGroups/deploy.bicep' = {
  name: resourceGroupName
  params: {
    name: resourceGroupName
    tags: resourceTags
  }
}

// Redis Cache
module redis 'Microsoft.Cache/redis/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: redisCacheName
  params: {
    environmentName: environmentName
    redisName: redisCacheName
    skuName: 'Premium'
    skuCapacity: 1
    storageAccountId: storage.outputs.storageAccountResourceId
    workspaceId: workspace.outputs.logAnalyticsResourceId
    subnetId: '${vnet.id}/subnets/sharedSubnet'
    tags: resourceTags
  }
}

// Cosmos DB
module cosmosDb 'Microsoft.DocumentDB/databaseAccounts/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: cosmosDbName
  params: {
    name: cosmosDbName
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: 'East US 2'
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    defaultConsistencyLevel: 'Session'
    sqlDatabases: [
      {
        name: '${cosmosDbName}-sql-db'
        containers: [
          {
            name: 'container-001'
            paths: [
              '/myPartitionKey'
            ]
            kind: 'Hash'
          }
        ]
      }
    ]
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    workspaceId: workspace.outputs.logAnalyticsResourceId
  }
}

// Deploy Cosmos DB private DNS zone
module cosmosDbPrivateDNSZone 'Microsoft.Network/privateDnsZones/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${cosmosDbName}-private-dns-zone'
  params: {
    name: 'privatelink.documents.azure.com'
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: vnet.id
        registrationEnabled: true
      }
    ]
    tags: resourceTags
  }
}

// Deploy Cosmos DB private endpoint
module cosmosDbPrivateEndpoint 'Microsoft.Network/privateEndpoints/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${cosmosDbName}-private-endpoint'
  params: {
    name: '${cosmosDbName}-private-endpoint'
    targetSubnetResourceId: '${vnet.id}/subnets/sharedSubnet'
    groupId: [
      'sql'
    ]
    serviceResourceId: cosmosDb.outputs.databaseAccountResourceId
    privateDnsZoneGroups: [
      {
        privateDNSResourceIds: [
          cosmosDbPrivateDNSZone.outputs.privateDnsZoneResourceId
        ]
      }
    ]
    tags: resourceTags
  }
}

// APIM
module apim 'Microsoft.ApiManagement/service/deploy.bicep' = {
  scope: resourceGroup(apimResourceGroupName)
  name: apimName
  params: {
    name: apimName
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    sku: apimSku
    skuCount: 1
    subnetResourceId: '${vnet.id}/subnets/ApiManagementSubnet'
    virtualNetworkType: 'External'
    diagnosticWorkspaceId: workspace.outputs.logAnalyticsResourceId
    keyVaultResourceId: keyVault.outputs.keyVaultResourceId
    apis: apimApis
    authorizationServers: apimAuthorizationServers
    backends: apimBackends
    caches: apimCaches
    policies: apimPolicies
    portalSettings: apimPortalSettings
    subscriptions: apimSubscriptions
    identityProviders: apimIdentityProviders
    namedValues: apimNamedValues
    products: apimProducts
    tags: resourceTags
  }
}

// Deploy log analytics workspace
module workspace 'Microsoft.OperationalInsights/workspaces/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: workspaceName
  params: {
    name: workspaceName
    serviceTier: 'PerGB2018'
    solutions: [
      'Updates'
      'AntiMalware'
      'SQLAssessment'
      'Security'
      'SecurityCenterFree'
      'ChangeTracking'
      'KeyVaultAnalytics'
      'AzureSQLAnalytics'
      'ServiceMap'
      'AgentHealthAssessment'
      'AlertManagement'
      'AzureActivity'
      'AzureDataFactoryAnalytics'
      'AzureNSGAnalytics'
      'InfrastructureInsights'
      'NetworkMonitoring'
      'VMInsights'
    ]
    tags: resourceTags
  }
}

// Deploy storage account
module storage 'Microsoft.Storage/storageAccounts/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: storageAccountName
  params: {
    environmentName: environmentName
    name: storageAccountName
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowedVirtualNetworks: [
      '${vnet.id}/subnets/sharedSubnet'
    ]
    routingPreference: 'MicrosoftRouting'
    minimumTlsVersion: 'TLS1_2'
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    diagnosticWorkspaceId: workspace.outputs.logAnalyticsResourceId
    tags: resourceTags
  }
}

// Deploy storage private endpoint
module storagePrivateEndpoint 'Microsoft.Network/privateEndpoints/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${storageAccountName}-private-endpoint'
  params: {
    name: '${storageAccountName}-private-endpoint'
    targetSubnetResourceId: '${vnet.id}/subnets/sharedSubnet'
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
    environmentName: environmentName
    name: keyVaultName
    tenantId: subscription().tenantId
    skuName: 'premium'
    accessPolicies: []
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    enabledForDeployment: true
    softDeleteRetentionInDays: 7
    allowedVirtualNetworks: [
      '${vnet.id}/subnets/sharedSubnet'
    ]
    allowedIpAddresses: []
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    workspaceId: workspace.outputs.logAnalyticsResourceId
    tags: resourceTags
  }
}

// Deploy key vault private endpoint
module keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${keyVaultName}-private-endpoint'
  params: {
    name: '${keyVaultName}-private-endpoint'
    targetSubnetResourceId: '${vnet.id}/subnets/sharedSubnet'
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
  name: '${appInsightsName}-appins'
  params: {
    appInsightsWorkspaceResourceId: workspace.outputs.logAnalyticsResourceId
    name: appInsightsName
    tags: resourceTags
  }
}

// Deploy app service plan
module appServicePlan 'Microsoft.Web/serverfarms/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: appServicePlanName
  params: {
    name: appServicePlanName
    skuName: 'I1V2'
    skuTier: 'IsolatedV2'
    appServiceEnvironmentId: appServiceEnvironment.id
    tags: resourceTags
  }
}

// Deploy web app for api portal
module devPortalWebApp 'Microsoft.Web/sites/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${namingPrefixHyphen}-api-portal-app'
  params: {
    kind: 'app'
    name: '${namingPrefixHyphen}-api-portal-app'
    storageAccountId: storage.outputs.storageAccountResourceId
    appInsightId: appInsights.outputs.appInsightsResourceId
    appServicePlanId: appServicePlan.outputs.appServicePlanResourceId
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    appServiceEnvironmentId: appServiceEnvironment.id
    tags: resourceTags
  }
}

// Deploy function app for vendor setup API
module vendorSetupAPIFuncApp 'Microsoft.Web/sites/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${namingPrefixHyphen}-vendor-setup-api-func'
  params: {
    kind: 'functionapp'
    name: '${namingPrefixHyphen}-vendor-setup-api-func'
    storageAccountId: storage.outputs.storageAccountResourceId
    functionsWorkerRuntime: 'java'
    appInsightId: appInsights.outputs.appInsightsResourceId
    appServicePlanId: appServicePlan.outputs.appServicePlanResourceId
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    appServiceEnvironmentId: appServiceEnvironment.id
    tags: resourceTags
  }
}

// Deploy web app for vendor setup UI
module vendorSetupUIWebApp 'Microsoft.Web/sites/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${namingPrefixHyphen}-vendor-setup-ui-app'
  params: {
    kind: 'app'
    name: '${namingPrefixHyphen}-vendor-setup-ui-app'
    storageAccountId: storage.outputs.storageAccountResourceId
    appInsightId: appInsights.outputs.appInsightsResourceId
    appServicePlanId: appServicePlan.outputs.appServicePlanResourceId
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    appServiceEnvironmentId: appServiceEnvironment.id
    tags: resourceTags
  }
}

// Deploy web app for photo prints HTML checkout
module photoPrintsWebApp 'Microsoft.Web/sites/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${namingPrefixHyphen}-photo-prints-app'
  params: {
    kind: 'app'
    name: '${namingPrefixHyphen}-photo-prints-app'
    storageAccountId: storage.outputs.storageAccountResourceId
    appInsightId: appInsights.outputs.appInsightsResourceId
    appServicePlanId: appServicePlan.outputs.appServicePlanResourceId
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    appServiceEnvironmentId: appServiceEnvironment.id
    tags: resourceTags
  }
}

// Deploy web app for RxTransfer/RxRefill HTML checkout
module rxHTMLCheckoutWebApp 'Microsoft.Web/sites/deploy.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${namingPrefixHyphen}-rx-checkout-app'
  params: {
    kind: 'app'
    name: '${namingPrefixHyphen}-rx-checkout-app'
    storageAccountId: storage.outputs.storageAccountResourceId
    appInsightId: appInsights.outputs.appInsightsResourceId
    appServicePlanId: appServicePlan.outputs.appServicePlanResourceId
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    appServiceEnvironmentId: appServiceEnvironment.id
    tags: resourceTags
  }
}
