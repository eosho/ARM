targetScope = 'subscription'

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

@description('Name of the shared resource group.')
param sharedResourceGroupName string

@description('Name of the container registry.')
param containerRegistryName string

@description('Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(90)
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

/******************************************************************************
  Existing resources
*/

// Shared resource group
module sharedRg 'Microsoft.Resources/resourceGroups/deploy.bicep' = {
  name: sharedResourceGroupName
  params: {
    name: sharedResourceGroupName
    tags: resourceTags
  }
}

// APIM Network Security Group
module apimNsg 'Microsoft.Network/networkSecurityGroups/deploy.bicep' = {
  scope: resourceGroup(sharedRg.name)
  name: 'apimNsg'
  params: {
    name: 'apimNsg'
    networkSecurityGroupSecurityRules: [
      {
        name: 'ClientCommunicationToAPIManagementInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'SecureClientCommunicationToAPIManagementInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'ManagementEndpointForAzurePortalAndPowershellInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3443'
          sourceAddressPrefix: 'ApiManagement'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'DependencyOnRedisCacheInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6381-6383'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'AzureInfrastructureLoadBalancer'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 180
          direction: 'Inbound'
        }
      }
      {
        name: 'DependencyOnAzureSQLOutbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Sql'
          access: 'Allow'
          priority: 140
          direction: 'Outbound'
        }
      }
      {
        name: 'DependencyForLogToEventHubPolicyOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '5671'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'EventHub'
          access: 'Allow'
          priority: 150
          direction: 'Outbound'
        }
      }
      {
        name: 'DependencyOnRedisCacheOutbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6381-6383'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 160
          direction: 'Outbound'
        }
      }
      {
        name: 'DependencyOnAzureFileShareForGitOutbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '445'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          priority: 170
          direction: 'Outbound'
        }
      }
      {
        name: 'PublishDiagnosticLogsAndMetricsOutbound'
        properties: {
          description: 'APIM Logs and Metrics for consumption by admins and your IT team are all part of the management plane'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureMonitor'
          access: 'Allow'
          priority: 185
          direction: 'Outbound'
          destinationPortRanges: [
            '443'
            '12000'
            '1886'
          ]
        }
      }
      {
        name: 'ConnectToSmtpRelayForSendingEmailsOutbound'
        properties: {
          description: 'APIM features the ability to generate email traffic as part of the data plane and the management plane'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 190
          direction: 'Outbound'
          destinationPortRanges: [
            '25'
            '587'
            '25028'
          ]
        }
      }
      {
        name: 'AuthenticateToAzureActiveDirectoryOutbound'
        properties: {
          description: 'Connect to Azure Active Directory for Developer Portal Authentication or for Oauth2 flow during any Proxy Authentication'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureActiveDirectory'
          access: 'Allow'
          priority: 200
          direction: 'Outbound'
          destinationPortRanges: [
            '80'
            '443'
          ]
        }
      }
      {
        name: 'DependencyOnAzureStorageOutbound'
        properties: {
          description: 'APIM service dependency on Azure Blob and Azure Table Storage'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'PublishMonitoringLogsOutbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 300
          direction: 'Outbound'
        }
      }
    ]
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    diagnosticWorkspaceId: ''
    tags: resourceTags
  }
}

// Virtual Network
module vnet 'Microsoft.Network/virtualNetworks/deploy.bicep' = {
  scope: resourceGroup(sharedRg.name)
  name: '${namingPrefix}-vnet-01'
  params: {
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    name: '${namingPrefix}-vnet-01'
    subnets: [
      {
        name: 'ApiManagementSubnet'
        addressPrefix: '10.0.0.0/24'
        networkSecurityGroupName: apimNsg.name
      }
      {
        name: 'sharedSubnet'
        addressPrefix: '10.0.1.0/24'
        serviceEndpoints: [
          'Microsoft.Sql'
          'Microsoft.Storage'
          'Microsoft.KeyVault'
        ]
        privateLinkServiceNetworkPolicies: 'Disabled'
        privateEndpointNetworkPolicies: 'Disabled'
      }
      {
        name: 'asev3Subnet'
        addressPrefix: '10.0.2.0/24'
        delegations: [
          {
            name: 'Microsoft.Web.hostingEnvironments'
            properties: {
              serviceName: 'Microsoft.Web/hostingEnvironments'
            }
          }
        ]
        privateEndpointNetworkPolicies: 'Enabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
        //networkSecurityGroupName: 'asev3Nsg'
      }
    ]
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    workspaceId: ''
    tags: resourceTags
  }
}

// Container registry
module containerRegistry 'Microsoft.ContainerRegistry/registries/deploy.bicep' = {
  scope: resourceGroup(sharedRg.name)
  name: containerRegistryName
  params: {
    name: containerRegistryName
    acrSku: 'Premium'
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    diagnosticWorkspaceId: ''
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    tags: resourceTags
  }
}

// App Service Environment
module ase 'Microsoft.Web/hostingEnvironments/deploy.bicep' = {
  scope: resourceGroup(sharedRg.name)
  name: '${namingPrefix}-ase-01'
  params: {
    name: '${namingPrefix}-ase-01'
    kind: 'ASEV3'
    subnetResourceId: '${vnet.outputs.virtualNetworkResourceId}/subnets/asev3subnet'
    internalLoadBalancingMode: 'None'
    diagnosticWorkspaceId: ''
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
    tags: resourceTags
  }
}
