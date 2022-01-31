# Virtual Networks `[Microsoft.Network/virtualNetworks]`

This template deploys a virtual network (vNet).

## Resource types

| Resource Type | API Version |
| :-- | :-- |
| `Microsoft.Insights/diagnosticSettings` | 2021-05-01-preview |
| `Microsoft.Network/virtualNetworks` | 2021-03-01 |
| `Microsoft.Network/virtualNetworks/subnets` | 2021-03-01 |
| `Microsoft.Network/virtualNetworks/virtualNetworkPeerings` | 2021-02-01 |

## Parameters

| Parameter Name | Type | Default Value | Possible Values | Description |
| :-- | :-- | :-- | :-- | :-- |
| `addressPrefixes` | array |  |  | Required. An Array of 1 or more IP Address Prefixes for the Virtual Network. |
| `ddosProtectionPlanId` | string |  |  | Optional. Resource ID of the DDoS protection plan to assign the VNET to. If it's left blank, DDoS protection will not be configured. If it's provided, the VNET created by this template will be attached to the referenced DDoS protection plan. The DDoS protection plan can exist in the same or in a different subscription. |
| `diagnosticEventHubAuthorizationRuleId` | string |  |  | Optional. Resource ID of the diagnostic event hub authorization rule for the Event Hubs namespace in which the event hub should be created or streamed to. |
| `diagnosticEventHubName` | string |  |  | Optional. Name of the diagnostic event hub within the namespace to which logs are streamed. Without this, an event hub is created for each log category. |
| `diagnosticLogsRetentionInDays` | int | `365` |  | Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely. |
| `diagnosticStorageAccountId` | string |  |  | Optional. Resource ID of the diagnostic storage account. |
| `diagnosticWorkspaceId` | string |  |  | Optional. Resource ID of the diagnostic log analytics workspace. |
| `dnsServers` | array | `[]` |  | Optional. DNS Servers associated to the Virtual Network. |
| `location` | string | `[resourceGroup().location]` |  | Optional. Location for all resources. |
| `logsToEnable` | array | `[VMProtectionAlerts]` | `[VMProtectionAlerts]` | Optional. The name of logs that will be streamed. |
| `metricsToEnable` | array | `[AllMetrics]` | `[AllMetrics]` | Optional. The name of metrics that will be streamed. |
| `name` | string |  |  | Required. The Virtual Network (vNet) Name. |
| `subnets` | _[subnets](subnets/readme.md)_ array |  |  | Required. An Array of subnets to deploy to the Virual Network. |
| `tags` | object | `{object}` |  | Optional. Tags of the resource. |
| `virtualNetworkPeerings` | _[virtualNetworkPeerings](virtualNetworkPeerings/readme.md)_ array | `[]` |  | Optional. Virtual Network Peerings configurations |

### Parameter Usage: `virtualNetworkPeerings`

As the virtual network peering array allows you to deploy not only a one-way but also two-way peering (i.e reverse), you can use the following ***additional*** properties on top of what is documented in _[virtualNetworkPeerings](virtualNetworkPeerings/readme.md)_.

| Parameter Name | Type | Default Value | Possible Values | Description |
| :-- | :-- | :-- | :-- | :-- |
| `remotePeeringEnabled` | bool | `false` |  | Optional. Set to true to also deploy the reverse peering for the configured remote virtual networks to the local network |
| `remotePeeringName` | string | `'${last(split(peering.remoteVirtualNetworkId, '/'))}-${name}'` | | Optional. The Name of Vnet Peering resource. If not provided, default value will be <remoteVnetName>-<localVnetName> |
| `remotePeeringAllowForwardedTraffic` | bool | `true` | | Optional. Whether the forwarded traffic from the VMs in the local virtual network will be allowed/disallowed in remote virtual network. |
| `remotePeeringAllowGatewayTransit` | bool | `false` | | Optional. If gateway links can be used in remote virtual networking to link to this virtual network. |
| `remotePeeringAllowVirtualNetworkAccess` | bool | `true` | | Optional. Whether the VMs in the local virtual network space would be able to access the VMs in remote virtual network space. |
| `remotePeeringDoNotVerifyRemoteGateways` | bool | `true` | | Optional. If we need to verify the provisioning state of the remote gateway. |
| `remotePeeringUseRemoteGateways` | bool | `false` | |  Optional. If remote gateways can be used on this virtual network. If the flag is set to `true`, and allowGatewayTransit on local peering is also `true`, virtual network will use gateways of local virtual network for transit. Only one peering can have this flag set to `true`. This flag cannot be set if virtual network already has a gateway.  |

### Parameter Usage: `addressPrefixes`

The `addressPrefixes` parameter accepts a JSON Array of string values containing the IP Address Prefixes for the Virtual Network (vNet).

Here's an example of specifying a single Address Prefix:

```json
"addressPrefixes": {
    "value": [
        "10.1.0.0/16"
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

## Considerations

The network security group and route table resources must reside in the same resource group as the virtual network.

## Outputs

| Output Name | Type | Description |
| :-- | :-- | :-- |
| `subnetNames` | array | The names of the deployed subnets |
| `subnetResourceIds` | array | The resource IDs of the deployed subnets |
| `virtualNetworkName` | string | The name of the virtual network |
| `virtualNetworkResourceGroup` | string | The resource group the virtual network was deployed into |
| `virtualNetworkResourceId` | string | The resource ID of the virtual network |

## Template references

- [Diagnosticsettings](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Insights/2021-05-01-preview/diagnosticSettings)
- [Virtualnetworks](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Network/2021-03-01/virtualNetworks)
- [Virtualnetworks/Subnets](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Network/2021-03-01/virtualNetworks/subnets)
- [Virtualnetworks/Virtualnetworkpeerings](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Network/2021-02-01/virtualNetworks/virtualNetworkPeerings)
