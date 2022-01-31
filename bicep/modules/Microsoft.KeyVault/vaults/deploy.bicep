@description('The name of the deployment environment.')
param environmentName string

@description('Optional. Resource tags.')
param tags object = {}

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Name of the Key Vault. If no name is provided, then unique name will be created.')
@maxLength(24)
param name string = ''

@metadata({
  description: 'The Azure Active Directory tenant ID that should be used for authenticating requests to the key vault.'
  required: 'yes'
})
param tenantId string = ''

@metadata({
  description: 'SKU family name'
  required: 'yes'
})
@allowed([
  'A'
])
param skuFamily string = 'A'

@metadata({
  description: 'SKU name to specify whether the key vault is a standard vault or a premium vault.'
  required: 'yes'
})
@allowed([
  'premium'
])
param skuName string = 'premium'

@description('Optional. Array of access policies object')
param accessPolicies array = []

@description('Optional. All secrets to create')
param secrets array = []

@description('Optional. All keys to create')
param keys array = []

@metadata({
  description: 'Property to specify whether Azure Virtual Machines are permitted to retrieve certificates stored as secrets from the key vault.'
  required: 'no'
})
param enabledForDeployment bool = false

@metadata({
  description: 'Property to specify whether Azure Disk Encryption is permitted to retrieve secrets from the vault and unwrap keys.'
  required: 'no'
})
param enabledForDiskEncryption bool = false

@metadata({
  description: 'Property to specify whether Azure Resource Manager is permitted to retrieve secrets from the key vault.'
  required: 'no'
})
@allowed([
  true
])
param enabledForTemplateDeployment bool = true

@metadata({
  description: 'Property to specify whether the \'soft delete\' functionality is enabled for this key vault. If it\'s not set to any value(true or false) when creating new key vault, it will be set to true by default. Once set to true, it cannot be reverted to false.'
  required: 'no'
})
@allowed([
  true
])
param enableSoftDelete bool = true

@metadata({
  description: 'softDelete data retention days. It accepts >=7 and <=90.'
  required: 'no'
})
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@metadata({
  description: 'Property that controls how data actions are authorized. When true, the key vault will use Role Based Access Control (RBAC) for authorization of data actions, and the access policies specified in vault properties will be ignored (warning: this is a preview feature). When false, the key vault will use the access policies specified in vault properties, and any policy stored on Azure Resource Manager will be ignored. If null or not specified, the vault is created with the default value of false. Note that management actions are always authorized with RBAC.'
  required: 'no'
})
param enableRbacAuthorization bool = false

@metadata({
  description: 'The vault\'s create mode to indicate whether the vault need to be recovered or not.'
  required: 'no'
})
@allowed([
  'default'
  'recover'
])
param createMode string = 'default'

@metadata({
  description: 'Property specifying whether protection against purge is enabled for this vault. Setting this property to true activates protection against purge for this vault and its content - only the Key Vault service may initiate a hard, irrecoverable deletion. The setting is effective only if soft delete is also enabled. Enabling this functionality is irreversible - that is, the property does not accept false as its value.'
  required: 'no'
})
@allowed([
  true
])
param enablePurgeProtection bool = true

@metadata({
  description: 'The default action when no rule from ipRules and from virtualNetworkRules match. This is only used after the bypass property has been evaluated.'
  required: 'no'
})
@allowed([
  'Deny'
])
param networkAclsDefaultAction string = 'Deny'

@metadata({
  description: 'The list of IPv4 address range in CIDR notation, such as \'124.56.78.91\' (simple IP address) or \'124.56.78.0/24\' (all addresses that start with 124.56.78).'
  required: 'no'
  subType: 'ipv4'
})
param allowedIpAddresses array = []

@metadata({
  description: 'The list of full resource id of a vnet subnet, such as \'/subscriptions/subid/resourceGroups/rg1/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/subnet1\'.'
  required: 'no'
  subType: 'resourceId'
})
param allowedVirtualNetworks array = []

@description('Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(365)
param diagnosticLogsRetentionInDays int = 365

@description('Optional. Resource ID of the diagnostic storage account.')
param diagnosticStorageAccountId string = ''

@description('Optional. Resource ID of log analytics.')
param workspaceId string = ''

@description('Optional. Resource ID of the event hub authorization rule for the Event Hubs namespace in which the event hub should be created or streamed to.')
param eventHubAuthorizationRuleId string = ''

@description('Optional. Name of the event hub within the namespace to which logs are streamed. Without this, an event hub is created for each log category.')
param eventHubName string = ''

@description('Generated. Do not provide a value! This date value is used to generate a SAS token to access the modules.')
param baseTime string = utcNow('u')

@description('Optional. The name of logs that will be streamed.')
@allowed([
  'AuditEvent'
])
param logsToEnable array = [
  'AuditEvent'
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
var isProd = (environmentName == 'prod')
var datacenterIpAddresses = [
  '63.73.199.0/24'
  '63.239.17.0/24'
  '204.15.116.0/22'
  '209.65.11.0/24'
]
var prodIpAddresses = [
  '40.67.188.50'
  '52.177.84.230'
  '52.155.224.242'
  '51.105.163.210'
  '20.36.252.188'
]
var nonProdIpAddresses = [
  '52.230.220.128'
  '40.65.233.76'
  '52.155.224.148'
  '51.105.144.11'
]
var allowedIpAddresses_var = union(allowedIpAddresses, datacenterIpAddresses, (isProd ? prodIpAddresses : nonProdIpAddresses))
var networkAclsIpRules = [for item in allowedIpAddresses_var: {
  value: item
}]
var networkAclsVirtualNetworkRules = [for item in allowedVirtualNetworks: {
  id: item
}]
var formattedAccessPolicies = [for accessPolicy in accessPolicies: {
  applicationId: contains(accessPolicy, 'applicationId') ? accessPolicy.applicationId : ''
  objectId: contains(accessPolicy, 'objectId') ? accessPolicy.objectId : ''
  permissions: accessPolicy.permissions
  tenantId: contains(accessPolicy, 'tenantId') ? accessPolicy.tenantId : tenant().tenantId
}]
var maxNameLength = 24
var uniquenameUntrim = uniqueString('Key Vault${baseTime}')
var uniquename = (length(uniquenameUntrim) > maxNameLength ? substring(uniquenameUntrim, 0, maxNameLength) : uniquenameUntrim)
var name_var = empty(name) ? uniquename : name

resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = if (true) {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: skuFamily
      name: skuName
    }
    accessPolicies: formattedAccessPolicies
    enabledForDeployment: enabledForDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enableRbacAuthorization: enableRbacAuthorization
    createMode: createMode
    enablePurgeProtection: enablePurgeProtection
    networkAcls: {
      bypass: ((enabledForDeployment || enabledForTemplateDeployment) ? 'AzureServices' : 'None')
      defaultAction: networkAclsDefaultAction
      ipRules: networkAclsIpRules
      virtualNetworkRules: networkAclsVirtualNetworkRules
    }
  }
  dependsOn: []
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticsettings@2021-05-01-preview' = if ((!empty(diagnosticStorageAccountId)) || (!empty(workspaceId)) || (!empty(eventHubAuthorizationRuleId)) || (!empty(eventHubName))) {
  name: '${name_var}-diagnosticSettingName'
  properties: {
    storageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : null
    workspaceId: !empty(workspaceId) ? workspaceId : null
    eventHubAuthorizationRuleId: !empty(eventHubAuthorizationRuleId) ? eventHubAuthorizationRuleId : null
    eventHubName: !empty(eventHubName) ? eventHubName : null
    metrics: diagnosticsMetrics
    logs: diagnosticsLogs
  }
  scope: keyVault
}

module keyVault_accessPolicies 'accessPolicies/deploy.bicep' = if (!empty(accessPolicies)) {
  name: '${uniqueString(deployment().name, location)}-KeyVault-AccessPolicies'
  params: {
    keyVaultName: keyVault.name
    accessPolicies: formattedAccessPolicies
  }
}

module keyVault_secrets 'secrets/deploy.bicep' = [for (secret, index) in secrets: {
  name: '${uniqueString(deployment().name, location)}-KeyVault-Secret-${index}'
  params: {
    name: secret.name
    value: secret.value
    keyVaultName: keyVault.name
    attributesEnabled: contains(secret, 'attributesEnabled') ? secret.attributesEnabled : true
    attributesExp: contains(secret, 'attributesExp') ? secret.attributesExp : -1
    attributesNbf: contains(secret, 'attributesNbf') ? secret.attributesNbf : -1
    contentType: contains(secret, 'contentType') ? secret.contentType : ''
    tags: contains(secret, 'tags') ? secret.tags : {}
  }
}]

module keyVault_keys 'keys/deploy.bicep' = [for (key, index) in keys: {
  name: '${uniqueString(deployment().name, location)}-KeyVault-Key-${index}'
  params: {
    name: key.name
    keyVaultName: keyVault.name
    attributesEnabled: contains(key, 'attributesEnabled') ? key.attributesEnabled : true
    attributesExp: contains(key, 'attributesExp') ? key.attributesExp : -1
    attributesNbf: contains(key, 'attributesNbf') ? key.attributesNbf : -1
    curveName: contains(key, 'curveName') ? key.curveName : 'P-256'
    keyOps: contains(key, 'keyOps') ? key.keyOps : []
    keySize: contains(key, 'keySize') ? key.keySize : -1
    kty: contains(key, 'kty') ? key.kty : 'EC'
    tags: contains(key, 'tags') ? key.tags : {}
  }
}]

@description('The resource ID of the key vault.')
output keyVaultResourceId string = keyVault.id

@description('The name of the resource group the key vault was created in.')
output keyVaultResourceGroup string = resourceGroup().name

@description('The name of the key vault.')
output keyVaultName string = keyVault.name

@description('The URL of the key vault.')
output keyVaultUrl string = keyVault.properties.vaultUri
