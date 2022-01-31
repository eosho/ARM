# Application Insights `[Microsoft.Insights/components]`

## Resource Types

| Resource Type | API Version |
| :-- | :-- |
| `Microsoft.Insights/components` | 2020-02-02 |

## Parameters

| Parameter Name | Type | Default Value | Possible Values | Description |
| :-- | :-- | :-- | :-- | :-- |
| `appInsightsPublicNetworkAccessForIngestion` | string | `Enabled` | `[Enabled, Disabled]` | Optional. The network access type for accessing Application Insights ingestion. - Enabled or Disabled |
| `appInsightsPublicNetworkAccessForQuery` | string | `Enabled` | `[Enabled, Disabled]` | Optional. The network access type for accessing Application Insights query. - Enabled or Disabled |
| `appInsightsType` | string | `web` | `[web, other]` | Optional. Application type |
| `appInsightsWorkspaceResourceId` | string |  |  | Required. Resource ID of the log analytics workspace which the data will be ingested to. This property is required to create an application with this API version. Applications from older versions will not have this property. |
| `kind` | string |  |  | Optional. The kind of application that this component refers to, used to customize UI. This value is a freeform string, values should typically be one of the following: web, ios, other, store, java, phone. |
| `location` | string | `[resourceGroup().location]` |  | Optional. Location for all Resources |
| `name` | string |  |  | Required. Name of the Application Insights |
| `tags` | object | `{object}` |  | Optional. Tags of the resource. |


### Parameter Usage: `tags`

Tag names and tag values can be provided as needed. A tag can be left without a value.

```json
"tags": {
    "value": {
        "Environment": "Non-Prod",
        "Contact": "test.user@testcompany.com",
        "PurchaseOrder": "1234",
        "CostCenter": "7890",
        "ServiceName": "DeploymentValidation",
        "Role": "DeploymentValidation"
    }
}
```

## Outputs

| Output Name | Type | Description |
| :-- | :-- | :-- |
| `appInsightsAppId` | string | The application ID of the application insights component |
| `appInsightsName` | string | The name of the application insights component |
| `appInsightsResourceGroup` | string | The resource group the application insights component was deployed into |
| `appInsightsResourceId` | string | The resource ID of the application insights component |

## Template references

- [Components](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Insights/2020-02-02/components)
