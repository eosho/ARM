# Network Security Groups `[Microsoft.Network/networkSecurityGroups]`

This template deploys a network security group (NSG) with optional security rules.

## Resource Types

| Resource Type | API Version |
| :-- | :-- |
| `Microsoft.Insights/diagnosticSettings` | 2021-05-01-preview |
| `Microsoft.Network/networkSecurityGroups` | 2021-02-01 |

## Parameters

| Parameter Name | Type | Default Value | Possible Values | Description |
| :-- | :-- | :-- | :-- | :-- |
| `diagnosticEventHubAuthorizationRuleId` | string |  |  | Optional. Resource ID of the diagnostic event hub authorization rule for the Event Hubs namespace in which the event hub should be created or streamed to. |
| `diagnosticEventHubName` | string |  |  | Optional. Name of the diagnostic event hub within the namespace to which logs are streamed. Without this, an event hub is created for each log category. |
| `diagnosticLogsRetentionInDays` | int | `365` |  | Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely. |
| `diagnosticStorageAccountId` | string |  |  | Optional. Resource ID of the diagnostic storage account. |
| `diagnosticWorkspaceId` | string |  |  | Optional. Resource ID of the diagnostic log analytics workspace. |
| `location` | string | `[resourceGroup().location]` |  | Optional. Location for all resources. |
| `logsToEnable` | array | `[NetworkSecurityGroupEvent, NetworkSecurityGroupRuleCounter]` | `[NetworkSecurityGroupEvent, NetworkSecurityGroupRuleCounter]` | Optional. The name of logs that will be streamed. |
| `name` | string |  |  | Required. Name of the Network Security Group. |
| `networkSecurityGroupSecurityRules` | array | `[]` |  | Optional. Array of Security Rules to deploy to the Network Security Group. When not provided, an NSG including only the built-in roles will be deployed. |
| `tags` | object | `{object}` |  | Optional. Tags of the NSG resource. |

### Parameter Usage: `networkSecurityGroupSecurityRules`

The `networkSecurityGroupSecurityRules` parameter accepts a JSON Array of `securityRule` to deploy to the Network Security Group (NSG).

Note that in case of using ASGs (Application Security Groups) - `sourceApplicationSecurityGroupIds` and `destinationApplicationSecurityGroupIds` properties - both the NSG and the ASG(s) have to be in the same Azure region. Currently an NSG can only handle one source and one destination ASG.
Here's an example of specifying a couple security rules:

```json
"networkSecurityGroupSecurityRules": {
  "value": [
    {
      "name": "Port_8080",
      "properties": {
        "description": "Allow inbound access on TCP 8080",
        "protocol": "*",
        "sourcePortRange": "*",
        "destinationPortRange": "8080",
        "sourceAddressPrefix": "*",
        "destinationAddressPrefix": "*",
        "access": "Allow",
        "priority": 100,
        "direction": "Inbound",
        "sourcePortRanges": [],
        "destinationPortRanges": [],
        "sourceAddressPrefixes": [],
        "destinationAddressPrefixes": [],
        "sourceApplicationSecurityGroupIds": [],
        "destinationApplicationSecurityGroupIds": []
      }
    },
    {
      "name": "Port_8081",
      "properties": {
        "description": "Allow inbound access on TCP 8081",
        "protocol": "*",
        "sourcePortRange": "*",
        "destinationPortRange": "8081",
        "sourceAddressPrefix": "*",
        "destinationAddressPrefix": "*",
        "access": "Allow",
        "priority": 101,
        "direction": "Inbound",
        "sourcePortRanges": [],
        "destinationPortRanges": [],
        "sourceAddressPrefixes": [],
        "destinationAddressPrefixes": [],
        "sourceApplicationSecurityGroupIds": [],
        "destinationApplicationSecurityGroupIds": []
      }
    },
    {
      "name": "Port_8082",
      "properties": {
        "description": "Allow inbound access on TCP 8082",
        "protocol": "*",
        "sourcePortRange": "*",
        "destinationPortRange": "8082",
        "sourceAddressPrefix": "",
        "destinationAddressPrefix": "",
        "access": "Allow",
        "priority": 102,
        "direction": "Inbound",
        "sourcePortRanges": [],
        "destinationPortRanges": [],
        "sourceAddressPrefixes": [],
        "destinationAddressPrefixes": [],
        //sourceApplicationSecurityGroupIds currently only supports 1 ID !
        "sourceApplicationSecurityGroupIds": [
          "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/<rgName>/providers/Microsoft.Network/applicationSecurityGroups/<Application Security Group Name 2>"
        ],
        //destinationApplicationSecurityGroupIds currently only supports 1 ID !
        "destinationApplicationSecurityGroupIds": [
          "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/<rgName>/providers/Microsoft.Network/applicationSecurityGroups/<Application Security Group Name 1>"
        ]
      }
    }
  ]
}
```

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
| `networkSecurityGroupName` | string | The name of the network security group |
| `networkSecurityGroupResourceGroup` | string | The resource group the network security group was deployed into |
| `networkSecurityGroupResourceId` | string | The resource ID of the network security group |

## Template references

- [Diagnosticsettings](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Insights/2021-05-01-preview/diagnosticSettings)
- [Networksecuritygroups](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Network/2021-02-01/networkSecurityGroups)
