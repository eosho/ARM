@description('Required. The name of the of the API Management service.')
param apiManagementServiceName string

@description('Required. The name of the of the API.')
param apiName string

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

  resource api 'apis@2021-08-01' existing = {
    name: apiName
  }
}

resource policy 'Microsoft.ApiManagement/service/apis/policies@2021-08-01' = {
  name: name
  parent: service::api
  properties: {
    format: format
    value: value
  }
}

@description('The resource ID of the API policy')
output policyResourceId string = policy.id

@description('The name of the API policy')
output policyName string = policy.name

@description('The resource group the API policy was deployed into')
output policyResourceGroup string = resourceGroup().name
