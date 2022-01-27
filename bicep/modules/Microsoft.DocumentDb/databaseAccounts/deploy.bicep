@description('Required. Name of the Database Account')
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Tags of the Database Account resource.')
param tags object = {}

@description('Optional. Enables system assigned managed identity on the resource.')
param systemAssignedIdentity bool = false

@description('Optional. The ID(s) to assign to the resource.')
param userAssignedIdentities object = {}

@description('Optional. The offer type for the Cosmos DB database account.')
@allowed([
  'Standard'
])
param databaseAccountOfferType string = 'Standard'

@description('Required. Locations enabled for the Cosmos DB account.')
param locations array

@allowed([
  'Eventual'
  'ConsistentPrefix'
  'Session'
  'BoundedStaleness'
  'Strong'
])
@description('Optional. The default consistency level of the Cosmos DB account.')
param defaultConsistencyLevel string = 'Session'

@description('Optional. Enable automatic failover for regions')
param automaticFailover bool = true

@minValue(10)
@maxValue(2147483647)
@description('Optional. Max stale requests. Required for BoundedStaleness. Valid ranges, Single Region: 10 to 1000000. Multi Region: 100000 to 1000000.')
param maxStalenessPrefix int = 100000

@minValue(5)
@maxValue(86400)
@description('Optional. Max lag time (minutes). Required for BoundedStaleness. Valid ranges, Single Region: 5 to 84600. Multi Region: 300 to 86400.')
param maxIntervalInSeconds int = 300

@description('Optional. Specifies the MongoDB server version to use.')
@allowed([
  '3.2'
  '3.6'
  '4.0'
])
param serverVersion string = '4.0'

@description('Optional. SQL Databases configurations')
param sqlDatabases array = []

@description('Optional. MongoDB Databases configurations')
param mongodbDatabases array = []

@description('Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(365)
param diagnosticLogsRetentionInDays int = 365

@description('Optional. Resource ID of the diagnostic storage account.')
param diagnosticStorageAccountId string = ''

@description('Optional. Resource ID of the log analytics workspace.')
param workspaceId string = ''

@description('Optional. Resource ID of the event hub authorization rule for the Event Hubs namespace in which the event hub should be created or streamed to.')
param eventHubAuthorizationRuleId string = ''

@description('Optional. Name of the event hub within the namespace to which logs are streamed. Without this, an event hub is created for each log category.')
param eventHubName string = ''

@description('Optional. The name of logs that will be streamed.')
@allowed([
  'DataPlaneRequests'
  'MongoRequests'
  'QueryRuntimeStatistics'
  'PartitionKeyStatistics'
  'PartitionKeyRUConsumption'
  'ControlPlaneRequests'
  'CassandraRequests'
  'GremlinRequests'
  'TableApiRequests'
])
param logsToEnable array = [
  'DataPlaneRequests'
  'MongoRequests'
  'QueryRuntimeStatistics'
  'PartitionKeyStatistics'
  'PartitionKeyRUConsumption'
  'ControlPlaneRequests'
  'CassandraRequests'
  'GremlinRequests'
  'TableApiRequests'
]

@description('Optional. The name of metrics that will be streamed.')
@allowed([
  'Requests'
])
param metricsToEnable array = [
  'Requests'
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

var identityType = systemAssignedIdentity ? (!empty(userAssignedIdentities) ? 'SystemAssigned, UserAssigned' : 'SystemAssigned') : (!empty(userAssignedIdentities) ? 'UserAssigned' : 'None')

var identity = identityType != 'None' ? {
  type: identityType
  userAssignedIdentities: !empty(userAssignedIdentities) ? userAssignedIdentities : null
} : null

var consistencyPolicy = {
  Eventual: {
    defaultConsistencyLevel: 'Eventual'
  }
  ConsistentPrefix: {
    defaultConsistencyLevel: 'ConsistentPrefix'
  }
  Session: {
    defaultConsistencyLevel: 'Session'
  }
  BoundedStaleness: {
    defaultConsistencyLevel: 'BoundedStaleness'
    maxStalenessPrefix: maxStalenessPrefix
    maxIntervalInSeconds: maxIntervalInSeconds
  }
  Strong: {
    defaultConsistencyLevel: 'Strong'
  }
}

var databaseAccount_locations = [for location in locations: {
  failoverPriority: location.failoverPriority
  isZoneRedundant: location.isZoneRedundant
  locationName: location.locationName
}]

var kind = !empty(sqlDatabases) ? 'GlobalDocumentDB' : (!empty(mongodbDatabases) ? 'MongoDB' : 'Parse')

var databaseAccount_properties = !empty(sqlDatabases) ? {
  consistencyPolicy: consistencyPolicy[defaultConsistencyLevel]
  locations: databaseAccount_locations
  databaseAccountOfferType: databaseAccountOfferType
  enableAutomaticFailover: automaticFailover
} : (!empty(mongodbDatabases) ? {
  consistencyPolicy: consistencyPolicy[defaultConsistencyLevel]
  locations: databaseAccount_locations
  databaseAccountOfferType: databaseAccountOfferType
  apiProperties: {
    serverVersion: serverVersion
  }
} : {
  databaseAccountOfferType: databaseAccountOfferType
})

resource databaseAccount 'Microsoft.DocumentDB/databaseAccounts@2021-06-15' = {
  name: name
  location: location
  tags: tags
  identity: identity
  kind: kind
  properties: databaseAccount_properties
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticsettings@2021-05-01-preview' = if ((!empty(diagnosticStorageAccountId)) || (!empty(workspaceId)) || (!empty(eventHubAuthorizationRuleId)) || (!empty(eventHubName))) {
  name: '${databaseAccount.name}-diagnosticsetting'
  properties: {
    storageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : null
    workspaceId: !empty(workspaceId) ? workspaceId : null
    eventHubAuthorizationRuleId: !empty(eventHubAuthorizationRuleId) ? eventHubAuthorizationRuleId : null
    eventHubName: !empty(eventHubName) ? eventHubName : null
    metrics: diagnosticsMetrics
    logs: diagnosticsLogs
  }
  scope: databaseAccount
}

module sqlDatabases_resource 'sqlDatabases/deploy.bicep' = [for sqlDatabase in sqlDatabases: {
  name: '${uniqueString(deployment().name, location)}-sqldb-${sqlDatabase.name}'
  params: {
    databaseAccountName: databaseAccount.name
    name: sqlDatabase.name
    containers: contains(sqlDatabase, 'containers') ? sqlDatabase.containers : []
  }
}]

module mongodbDatabases_resource 'mongodbDatabases/deploy.bicep' = [for mongodbDatabase in mongodbDatabases: {
  name: '${uniqueString(deployment().name, location)}-mongodb-${mongodbDatabase.name}'
  params: {
    databaseAccountName: databaseAccount.name
    name: mongodbDatabase.name
    collections: contains(mongodbDatabase, 'collections') ? mongodbDatabase.collections : []
  }
}]

@description('The name of the database account.')
output databaseAccountName string = databaseAccount.name

@description('The resource ID of the database account.')
output databaseAccountResourceId string = databaseAccount.id

@description('The name of the resource group the database account was created in.')
output databaseAccountResourceGroup string = resourceGroup().name

@description('The principal ID of the system assigned identity.')
output systemAssignedPrincipalId string = systemAssignedIdentity ? databaseAccount.identity.principalId : ''
