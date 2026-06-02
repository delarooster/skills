# Hub/Spoke Private DNS Architecture

## Model

The hub is a **DNS zone provider only**. It owns private DNS zones and VNet links. Spokes own private endpoints and attach DNS zone groups pointing to hub zones.

```
Hub RG
  Private DNS Zones (8)
    VNet links -> hub VNet + registered spoke VNets

Spoke RG
  Private Endpoint -> target resource
    DNS Zone Group -> hub DNS zone (by existing reference)
```

## Hub Responsibilities

| What | Where |
|---|---|
| Private DNS zones | `modules/privateZone.bicep` -- creates zones, calls virtualNetworkLink |
| VNet links | `modules/virtualNetworkLink.bicep` -- links VNets to a zone |
| Spoke access grants | `modules/roleAssignment.bicep` -- `Private DNS Zone Contributor` on hub RG |
| Zone list | Bicep variable in `env/main.bicep` -- changed via PR |
| VNet link list | Bicep variable in `env/main.bicep` -- changed via PR |
| Spoke principals | Bicep variable in `env/main.bicep` -- changed via PR |

## Spoke Onboarding

Two PRs to the hub repository are required before a spoke can attach DNS zone groups:

1. Add spoke VNet ID to `virtualNetworkLinks` in `env/main.bicep`
2. Add spoke deployment identity to `spokeDeploymentPrincipals` in `env/main.bicep`

After hub deployment completes, the spoke can deploy private endpoints independently -- no further hub involvement.

## Hub DNS Zones (example)

| Zone | Service |
|---|---|
| `privatelink.documents.azure.com` | Cosmos DB |
| `privatelink.<location>.kusto.windows.net` | ADX (Kusto) |
| `privatelink.blob.core.windows.net` | Blob Storage |
| `privatelink.queue.core.windows.net` | Queue Storage |
| `privatelink.table.core.windows.net` | Table Storage |
| `privatelink.servicebus.windows.net` | Service Bus |
| `privatelink.azure-devices.net` | IoT Hub |
| `privatelink.azurecr.io` | Container Registry |

## Spoke PE Pattern

**Rule: always reference hub DNS zones as `existing` resources. Never use `resourceId()` to construct zone IDs.**

The linter flags `resourceId()` in `privateDnsZoneId` assignments. The correct fix is `existing`, not `#disable-next-line use-resource-id-functions`.

Reference hub zones as `existing` resources scoped to the hub RG:

```bicep
// Parameters
param hubResourceGroupName string
param hubSubscriptionId string = subscription().subscriptionId

// Reference hub zone as existing
resource cosmosZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.documents.azure.com'
  scope: resourceGroup(hubSubscriptionId, hubResourceGroupName)
}

// Private endpoint
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${resourceName}-pe'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'connection'
        properties: {
          privateLinkServiceId: targetResource.id
          groupIds: ['<groupId>']
        }
      }
    ]
    subnet: { id: spokeVnet::subnet.id }
  }
}

// DNS zone group using symbolic reference
resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-zone-name'
        properties: {
          privateDnsZoneId: cosmosZone.id  // symbolic .id -- no resourceId() needed
        }
      }
    ]
  }
}
```

## VNet Link Object Shape

```bicep
{
  name: string            // short unique name for the link
  virtualNetworkId: string  // full ARM resource ID of the VNet
  registrationEnabled: bool // false for spokes
}
```

Always add spoke VNets by referencing them as `existing` resources and using symbolic `.id`. Do not paste full ARM IDs into arrays.

Spoke VNet registration must be optional deployment data so the hub can bootstrap before any spokes exist:

```bicep
@description('Spoke VNets to link to network hub private DNS zones. Empty for initial hub deployment.')
param spokeVirtualNetworkLinks array = []

resource spokeVirtualNetworks 'Microsoft.Network/virtualNetworks@2023-09-01' existing = [for spokeVirtualNetworkLink in spokeVirtualNetworkLinks: {
  name: spokeVirtualNetworkLink.virtualNetworkName
  scope: resourceGroup(spokeVirtualNetworkLink.subscriptionId, spokeVirtualNetworkLink.resourceGroupName)
}]

var virtualNetworkLinks = [
  {
    name: 'hub-vnet'
    virtualNetworkId: virtualNetwork.outputs.virtualNetworkId
    registrationEnabled: false
  }
  for (spokeVirtualNetworkLink, index) in spokeVirtualNetworkLinks: {
    name: spokeVirtualNetworkLink.name
    virtualNetworkId: spokeVirtualNetworks[index].id
    registrationEnabled: spokeVirtualNetworkLink.registrationEnabled
  }
]
```

Parameter entry shape:

```bicep
param spokeVirtualNetworkLinks = [
  {
    name: 'tier-dv-vnet'
    subscriptionId: '00000000-0000-0000-0000-000000000000'
    resourceGroupName: 'rg-app-dv'
    virtualNetworkName: 'DvAppVnet'
    registrationEnabled: false
  }
]
```

## Reference Implementations

The hub repository (`Contoso.Env.NetworkHub`) is the canonical home for spoke PE examples. All spoke teams reference these. Do not move or remove them.

See `examples/` in `Contoso.Env.NetworkHub`:
- `examples/adx-private-endpoint/` -- ADX cluster (4 zones: kusto, blob, queue, table)
- `examples/cosmos-private-endpoint/` -- Cosmos DB SQL API (1 zone)
