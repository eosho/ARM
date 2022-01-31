# Private Endpoints `[Microsoft.Network/privateEndpoints]`

This template deploys a private endpoint for a generic service.

## Resource types

| Resource Type | API Version |
| :-- | :-- |
| `Microsoft.Network/privateEndpoints` | 2021-03-01 |
| `Microsoft.Network/privateEndpoints/privateDnsZoneGroups` | 2021-03-01 |

### Resource dependency

The following resources are required to be able to deploy this resource:

- `PrivateDNSZone`
- `VirtualNetwork/subnet`
- The service that needs to be connected through private endpoint

**Important**: Destination subnet must be created with the following configuration option - `"privateEndpointNetworkPolicies": "Disabled"`.  Setting this option acknowledges that NSG rules are not applied to Private Endpoints (this capability is coming soon).

## Parameters

| Parameter Name | Type | Default Value | Possible Values | Description |
| :-- | :-- | :-- | :-- | :-- |
| `groupId` | array |  |  | Required. Subtype(s) of the connection to be created. The allowed values depend on the type serviceResourceId refers to. |
| `location` | string | `[resourceGroup().location]` |  | Optional. Location for all Resources. |
| `name` | string |  |  | Required. Name of the private endpoint resource to create. |
| `privateDnsZoneGroups` | _[privateDnsZoneGroups](privateDnsZoneGroups/readme.md)_ array | `[]` |  | Optional. Array of Private DNS zone groups configuration on the private endpoint. |
| `serviceResourceId` | string |  |  | Required. Resource ID of the resource that needs to be connected to the network. |
| `tags` | object | `{object}` |  | Optional. Tags to be applied on all resources/resource groups in this deployment. |
| `targetSubnetResourceId` | string |  |  | Required. Resource ID of the subnet where the endpoint needs to be created. |

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
| `privateEndpointName` | string | The name of the private endpoint |
| `privateEndpointResourceGroup` | string | The resource group the private endpoint was deployed into |
| `privateEndpointResourceId` | string | The resource ID of the private endpoint |

## Template references

- [Privateendpoints](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Network/2021-03-01/privateEndpoints)
- [Privateendpoints/Privatednszonegroups](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Network/2021-03-01/privateEndpoints/privateDnsZoneGroups)
