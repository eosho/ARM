# Resource Group

This module deploys a Resource Group and assigns a resource lock to prevent accidental Deletion.

## Resource types

| Resource Type                        | ApiVersion |
| :----------------------------------- | :--------- |
| `Microsoft.Resources/resourceGroups` | 2021-04-01 |

## Parameters

| Parameter Name | Type   | Description                                                | DefaultValue | Possible values |
| :------------- | :----- | :--------------------------------------------------------- | :----------- | :-------------- |
| `location`     | string | **REQUIRED**. Location of the Resource Group.              | `deployment().location` |      |
| `name`         | string | **REQUIRED**. The name of the Resource Group               |              |                 |
| `tags`         | object | **Optional**. Tags of the Resource Group.                  |              |                 |

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

| Output Name         | Type   | Description                           |
| :------------------ | :----- | :------------------------------------ |
| `resourceGroupName` | string | The name of the Resource Group        |
| `resourceGroupResourceId`   | string | The resource id of the Resource Group |

### Scripts

- There is no Scripts for this Module

## Considerations

- There is no deployment considerations for this Module

## Additional resources

- [Microsoft Resource Group template reference](https://docs.microsoft.com/en-us/azure/templates/microsoft.resources/2019-05-01/resourcegroups)
- [Use tags to organize your Azure resources](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-using-tags)
