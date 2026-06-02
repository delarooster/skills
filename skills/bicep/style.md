# Bicep Style Conventions

## Resource References: Always Use `existing`

Never use `resourceId()` to construct a resource ID string when you need to reference an existing Azure resource. Use the `existing` keyword instead. It is explicit, type-safe, and supported by the linter.

**Wrong:**
```bicep
var zoneId = resourceId(subId, rgName, 'Microsoft.Network/privateDnsZones', 'privatelink.documents.azure.com')
```

**Correct:**
```bicep
resource cosmosZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.documents.azure.com'
  scope: resourceGroup(hubSubscriptionId, hubResourceGroupName)
}
// Use: cosmosZone.id
```

The `existing` pattern:
- Eliminates `#disable-next-line use-resource-id-functions` suppressions
- Makes the resource type and API version explicit
- Enables symbolic name access (`.id`, `.name`, `.properties.*`)
- Works cross-resource-group and cross-subscription via `scope:`

## Cross-Scope References

Use `scope: resourceGroup(subscriptionId, resourceGroupName)` to reference resources in other resource groups or subscriptions:

```bicep
resource target 'Microsoft.Kusto/Clusters@2022-07-07' existing = {
  name: clusterName
  scope: resourceGroup(targetSubscriptionId, targetResourceGroupName)
}
```

Use `scope: subscription()` for subscription-scoped resources (e.g., resource groups, subscription-level role assignments).

## Nested Child Resources

Reference nested child resources using the `::` accessor after declaring the parent as `existing`:

```bicep
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroup)
  resource subnet 'subnets' existing = {
    name: subnetName
  }
}

// Use: vnet::subnet.id
```

## Parameters

- Every parameter must have `@description()`
- Use `@allowed([])` for constrained string values (e.g., env designators)
- Use `@minLength` / `@maxLength` for affixes and name segments
- Provide sensible defaults with `= <value>` where appropriate
- Do not use `object` type for structured params -- use typed objects or named properties

## Outputs

- Every output must have a description comment or be self-documenting by name
- Expose `id` and `name` for every primary resource created by a module
- Do not expose secrets or connection strings in outputs

## `dependsOn` Usage

Only add explicit `dependsOn` when Bicep cannot infer the dependency from symbolic name references in `params`. If a module already references `virtualNetwork.outputs.virtualNetworkId`, the dependency is implicit -- no `dependsOn` needed.

## Linter

Do not suppress linter warnings with `#disable-next-line` unless there is no correct alternative. If the warning points to a `resourceId()` call, replace it with `existing` instead of suppressing.

## File Header

Every Bicep file must start with the copyright comment:

```bicep
// Copyright © <year> <org>.  All rights reserved.
```
