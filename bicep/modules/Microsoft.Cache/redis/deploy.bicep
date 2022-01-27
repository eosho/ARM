@description('The name of the deployment environment. Used for naming convention')
@allowed([
  'int'
  'dev'
  'qa'
  'prod'
])
param environmentName string

@metadata({
  description: 'Resource tags.'
  subTypeDefinition: {}
})
param tags object

@description('Location of all resources')
param location string = resourceGroup().location

@description('The name of the Redis cache.')
param redisName string

@description('The type of Redis cache to deploy. Valid values: (Basic, Standard, Premium)')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Premium'

@description('The size of the Redis cache to deploy. Valid values: for C (Basic/Standard) family (0, 1, 2, 3, 4, 5, 6), for P (Premium) family (1, 2, 3, 4).')
@minValue(0)
@maxValue(6)
param skuCapacity int = 1

@metadata({
  description: 'The full resource ID of a subnet in a virtual network to deploy the Redis cache in. Example format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/Microsoft.{Network|ClassicNetwork}/VirtualNetworks/vnet1/subnets/subnet1'
  subType: 'regex'
  pattern: '^/subscriptions/[^/]*/resourceGroups/[^/]*/providers/Microsoft.(ClassicNetwork|Network)/virtualNetworks/[^/]*/subnets/[^/]*$'
})
param subnetId string = ''

@metadata({
  description: 'Static IP address. Required when deploying a Redis cache inside an existing Azure Virtual Network.'
  subType: 'regex'
  pattern: '^\\d+\\.\\d+\\.\\d+\\.\\d+$'
})
param staticIP string = ''

@metadata({
  description: 'All Redis Settings. Few possible keys: rdb-backup-enabled,rdb-storage-connection-string,rdb-backup-frequency,maxmemory-delta,maxmemory-policy,notify-keyspace-events,maxmemory-samples,slowlog-log-slower-than,slowlog-max-len,list-max-ziplist-entries,list-max-ziplist-value,hash-max-ziplist-entries,hash-max-ziplist-value,set-max-intset-entries,zset-max-ziplist-entries,zset-max-ziplist-value etc.'
  subTypeDefinition: {}
})
param redisConfiguration object = {}

@description('Specifies whether the non-ssl Redis server port (6379) is enabled.')
@allowed([
  false
])
param enableNonSslPort bool = false

@description('Resource Id for the log analytics workspace for diagnostics logs.')
param workspaceResourceId string

@description('The number of replicas to be created per master.')
param replicasPerMaster int = 0

@metadata({
  description: 'A dictionary of tenant settings'
  subTypeDefinition: {}
})
param tenantSettings object = {}

@description('The number of shards to be created on a Premium Cluster Cache.')
param shardCount int = 0

@description('Optional: requires clients to use a specified TLS version (or higher) to connect (e,g, \'1.0\', \'1.1\', \'1.2\')')
@allowed([
  '1.2'
])
param minimumTlsVersion string = '1.2'

@metadata({
  description: 'A list of availability zones denoting where the resource needs to come from.'
  subType: 'string'
})
@allowed([
  '1'
  '2'
  '3'
])
param zones array = []

@description('Whether or not to create a secondary Redis Cache and link them for geo-replication. Only available with Premium Sku. If set to true, secondaryRedisName, and secondaryLocation must be set.')
param enableGeoReplication bool = false

@description('The name of the linked server that is being added to the Redis cache.')
param secondaryRedisName string = uniqueString(redisName)

@description('Location of the linked redis cache.')
param secondaryLocation string = location

@metadata({
  description: 'The full resource ID of a subnet in a virtual network to deploy the Redis cache in. Example format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/Microsoft.{Network|ClassicNetwork}/VirtualNetworks/vnet1/subnets/subnet1'
  subType: 'regex'
  pattern: '^/subscriptions/[^/]*/resourceGroups/[^/]*/providers/Microsoft.(ClassicNetwork|Network)/virtualNetworks/[^/]*/subnets/[^/]*$'
})
param secondarySubnetId string = ''

@metadata({
  description: 'Static IP address. Required when deploying a Redis cache inside an existing Azure Virtual Network.'
  subType: 'regex'
  pattern: '^\\d+\\.\\d+\\.\\d+\\.\\d+$'
})
param secondaryStaticIP string = ''

@description('Day of the week when a cache can be patched.')
@allowed([
  'Monday'
  'Tuesday'
  'Wednesday'
  'Thursday'
  'Friday'
  'Saturday'
  'Sunday'
  'Everyday'
  'Weekend'
])
param dayOfWeek string = 'Sunday'

@description('Start hour after which cache patching can start.')
@minValue(0)
@maxValue(23)
param startHourUtc int = 2

@description('ISO8601 timespan specifying how much time cache patching can take. ')
param maintenanceWindow string = 'PT5H'

@metadata({
  subType: 'object'
  subTypeDefinition: {
    firewallRuleName: {
      type: 'string'
      metadata: {
        description: 'The name of the firewall rule.'
        required: 'yes'
      }
    }
    startIP: {
      type: 'string'
      metadata: {
        description: 'lowest IP address included in the range'
        required: 'yes'
      }
    }
    endIP: {
      type: 'string'
      metadata: {
        description: 'highest IP address included in the range'
        required: 'yes'
      }
    }
  }
})
param firewallRules array = []

@metadata({
  description: '**This feature is not currently supported.** The full resource ID of a storage account to use for persistence with Redis cache. Example format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/Microsoft.Storage/storageAccounts/name'
  subType: 'regex'
  pattern: '^/subscriptions/[^/]*/resourceGroups/[^/]*/providers/Microsoft.Storage/storageAccounts/[^/]*$'
})
param storageAccountId string = ''

@description('Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(365)
param diagnosticLogsRetentionInDays int = 90

@description('Optional. Resource ID of the diagnostic storage account.')
param diagnosticStorageAccountId string = ''

@description('Optional. Resource ID of log analytics.')
param workspaceId string = ''

@description('Optional. Resource ID of the event hub authorization rule for the Event Hubs namespace in which the event hub should be created or streamed to.')
param eventHubAuthorizationRuleId string = ''

@description('Optional. Name of the event hub within the namespace to which logs are streamed. Without this, an event hub is created for each log category.')
param eventHubName string = ''

var isPremium = (skuName == 'Premium')
var isReplicated = (isPremium && enableGeoReplication)
var isProd = (environmentName == 'prod')
var isNonProd = (!isProd)
var prodIpAddresses = [
  {
    firewallRuleName: 'prod_centralus'
    startIP: '40.67.188.50'
    endIP: '40.67.188.50'
  }
  {
    firewallRuleName: 'prod_eastus2'
    startIP: '52.177.84.230'
    endIP: '52.177.84.230'
  }
  {
    firewallRuleName: 'prod_northeurope'
    startIP: '52.155.224.242'
    endIP: '52.155.224.242'
  }
  {
    firewallRuleName: 'prod_westeurope'
    startIP: '51.105.163.210'
    endIP: '51.105.163.210'
  }
  {
    firewallRuleName: 'prod_preleap'
    startIP: '20.36.252.188'
    endIP: '20.36.252.188'
  }
]
var nprodIpAddresses = [
  {
    firewallRuleName: 'nprod_centralus'
    startIP: '52.230.220.128'
    endIP: '52.230.220.128'
  }
  {
    firewallRuleName: 'nprod_eastus2'
    startIP: '40.65.233.76'
    endIP: '40.65.233.76'
  }
  {
    firewallRuleName: 'nprod_northeurope'
    startIP: '52.155.224.148'
    endIP: '52.155.224.148'
  }
  {
    firewallRuleName: 'nprod_westeurope'
    startIP: '51.105.144.11'
    endIP: '51.105.144.11'
  }
  {
    firewallRuleName: 'nprod_legacy'
    startIP: '20.42.25.22'
    endIP: '20.42.25.22'
  }
]
var defaultFirewallRule = {
  firewallRuleName: 'DEFAULT'
  startIP: '0.0.0.0'
  endIP: '0.0.0.0'
}
var nprodFirewallRules = union(firewallRules, nprodIpAddresses)
var prodFirewallRules = (empty(firewallRules) ? array(defaultFirewallRule) : union(firewallRules, prodIpAddresses))
var firewallRules_var = (isNonProd ? nprodFirewallRules : prodFirewallRules)
var storageAccountName = last(split(storageAccountId, '/'))
var storageUri = 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys(storageAccountId, '2016-01-01').keys[0].value}'
var storageConfiguration = {
  'rdb-backup-enabled': true
  'rdb-backup-frequency': '60'
  'rdb-storage-connection-string': storageUri
}
var redisConfiguration_var = union(redisConfiguration, storageConfiguration)
var secondaryRedisName_var = ((!empty(secondaryRedisName)) ? secondaryRedisName : uniqueString(redisName))
@description('Optional. The name of metrics that will be streamed.')
@allowed([
  'AllMetrics'
])
param metricsToEnable array = [
  'AllMetrics'
]

@description('Optional. The name of logs that will be streamed.')
@allowed([
  'ConnectedClientList'
])
param logsToEnable array = [
  'ConnectedClientList'
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

resource primaryRedis 'Microsoft.Cache/Redis@2020-12-01' = {
  name: redisName
  tags: tags
  location: location
  zones: ((!empty(zones)) ? zones : json('null'))
  properties: {
    sku: {
      name: skuName
      family: (isPremium ? 'P' : 'C')
      capacity: skuCapacity
    }
    minimumTlsVersion: minimumTlsVersion
    enableNonSslPort: enableNonSslPort
    redisConfiguration: redisConfiguration_var
    replicasPerMaster: ((replicasPerMaster == 0) ? json('null') : replicasPerMaster)
    tenantSettings: tenantSettings
    subnetId: (isPremium ? subnetId : json('null'))
    staticIP: (isPremium ? staticIP : json('null'))
    shardCount: ((isPremium && (shardCount > 0)) ? shardCount : json('null'))
  }
  dependsOn: []
}

resource secondaryRedis 'Microsoft.Cache/Redis@2020-12-01' = if (isReplicated) {
  name: secondaryRedisName_var
  tags: tags
  location: secondaryLocation
  zones: zones
  properties: {
    sku: {
      name: 'Premium'
      family: 'P'
      capacity: skuCapacity
    }
    minimumTlsVersion: minimumTlsVersion
    enableNonSslPort: enableNonSslPort
    redisConfiguration: redisConfiguration
    replicasPerMaster: ((replicasPerMaster == 0) ? null : replicasPerMaster)
    tenantSettings: tenantSettings
    subnetId: secondarySubnetId
    staticIP: secondaryStaticIP
    shardCount: shardCount
  }
  dependsOn: []
}

resource redisName_secondaryRedisName 'Microsoft.Cache/Redis/linkedServers@2020-12-01' = if (isReplicated) {
  parent: primaryRedis
  name: secondaryRedisName_var
  properties: {
    linkedRedisCacheId: (isReplicated ? secondaryRedis.id : null)
    linkedRedisCacheLocation: secondaryLocation
    serverRole: 'Secondary'
  }
}

resource redisName_default 'Microsoft.Cache/Redis/patchSchedules@2020-12-01' = {
  parent: primaryRedis
  name: 'default'
  properties: {
    scheduleEntries: [
      {
        dayOfWeek: dayOfWeek
        startHourUtc: startHourUtc
        maintenanceWindow: maintenanceWindow
      }
    ]
  }
}

resource secondaryRedisName_default 'Microsoft.Cache/Redis/patchSchedules@2020-12-01' = if (isReplicated) {
  parent: secondaryRedis
  name: 'default'
  properties: {
    scheduleEntries: [
      {
        dayOfWeek: dayOfWeek
        startHourUtc: startHourUtc
        maintenanceWindow: maintenanceWindow
      }
    ]
  }
}

resource redisName_firewallRules 'Microsoft.Cache/Redis/firewallRules@2020-12-01' = [for item in firewallRules_var: if ((!isPremium) || (!empty(firewallRules))) {
  name: '${redisName}/${item.firewallRuleName}'
  properties: {
    startIP: item.startIP
    endIP: item.endIP
  }
  dependsOn: [
    primaryRedis
  ]
}]

resource secondaryRedisName_firewallRules 'Microsoft.Cache/Redis/firewallRules@2020-12-01' = [for item in firewallRules_var: if (isReplicated && (!empty(firewallRules))) {
  name: '${secondaryRedisName_var}/${item.firewallRuleName}'
  properties: {
    startIP: item.startIP
    endIP: item.endIP
  }
  dependsOn: [
    secondaryRedis
  ]
}]

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(diagnosticStorageAccountId) || !empty(workspaceId) || !empty(eventHubAuthorizationRuleId) || !empty(eventHubName)) {
  name: '${primaryRedis.name}-diagnosticSettings'
  properties: {
    storageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : null
    workspaceId: !empty(workspaceId) ? workspaceId : null
    eventHubAuthorizationRuleId: !empty(eventHubAuthorizationRuleId) ? eventHubAuthorizationRuleId : null
    eventHubName: !empty(eventHubName) ? eventHubName : null
    metrics: diagnosticsMetrics
    logs: diagnosticsLogs
  }
  scope: primaryRedis
}

@description('The resource ID of the deployed redis cache.')
output redisCacheResourceId string = primaryRedis.id

@description('The name of the deployed redis cache')
output redisCacheName string = primaryRedis.name

@description('The resource group of the deployed redis cache')
output redisCacheResourceGroup string = resourceGroup().name
