# Private DNS Zones `[Microsoft.Network/privateDnsZones]`

This template deploys a private DNS zone.

## Resource types

| Resource Type | API Version |
| :-- | :-- |
| `Microsoft.Network/privateDnsZones` | 2020-06-01 |
| `Microsoft.Network/privateDnsZones/virtualNetworkLinks` | 2020-06-01 |

## Parameters

| Parameter Name | Type | Default Value | Possible Values | Description |
| :-- | :-- | :-- | :-- | :-- |
| `location` | string | `global` |  | Optional. The location of the PrivateDNSZone. Should be global. |
| `name` | string |  |  | Required. Private DNS zone name. |
| `tags` | object | `{object}` |  | Optional. Tags of the resource. |
| `virtualNetworkLinks` | _[virtualNetworkLinks](virtualNetworkLinks/readme.md)_ array | `[]` |  | Optional. Array of custom objects describing vNet links of the DNS zone. Each object should contain properties 'vnetResourceId' and 'registrationEnabled'. The 'vnetResourceId' is a resource ID of a vNet to link, 'registrationEnabled' (bool) enables automatic DNS registration in the zone for the linked vNet. |

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
| `privateDnsZoneName` | string | The name of the private DNS zone |
| `privateDnsZoneResourceGroup` | string | The resource group the private DNS zone was deployed into |
| `privateDnsZoneResourceId` | string | The resource ID of the private DNS zone |

## Template references

- [Privatednszones](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Network/2020-06-01/privateDnsZones)
- [Privatednszones/Virtualnetworklinks](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Network/2020-06-01/privateDnsZones/virtualNetworkLinks)
