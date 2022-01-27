@description('Required. The name of the of the API Management service.')
param apiManagementServiceName string

@description('Optional. The name of the policy')
param name string = 'policy'

@description('Optional. Format of the policyContent.')
@allowed([
  'rawxml'
  'rawxml-link'
  'xml'
  'xml-link'
])
param format string = 'xml'

@description('Required. Contents of the Policy as defined by the format.')
param value string

resource service 'Microsoft.ApiManagement/service@2021-08-01' existing = {
  name: apiManagementServiceName
}

resource policy 'Microsoft.ApiManagement/service/policies@2021-08-01' = {
  name: name
  parent: service
  properties: {
    format: format
    value: value
  }
}

@description('The resource ID of the API management service policy')
output policyResourceId string = policy.id

@description('The name of the API management service policy')
output policyName string = policy.name

@description('The resource group the API management service policy was deployed into')
output policyResourceGroup string = resourceGroup().name
