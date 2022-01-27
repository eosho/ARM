@description('Required. The name of the of the API Management service.')
param apiManagementServiceName string

@description('Required. The name of the of the Product.')
param productName string

@description('Required. Name of the product group.')
param name string

resource service 'Microsoft.ApiManagement/service@2021-08-01' existing = {
  name: apiManagementServiceName

  resource product 'products@2021-04-01-preview' existing = {
    name: productName
  }
}

resource group 'Microsoft.ApiManagement/service/products/groups@2021-08-01' = {
  name: name
  parent: service::product
}

@description('The resource ID of the product group')
output groupResourceId string = group.id

@description('The name of the product group')
output groupName string = group.name

@description('The resource group the product group was deployed into')
output groupResourceGroup string = resourceGroup().name
