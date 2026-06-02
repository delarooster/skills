# Naming Conventions

## Principle

Names must be self-explanatory with no surrounding context. The reader -- six months from now, or a new hire -- should be able to understand what a parameter, variable, or resource represents without reading adjacent code.

**No abbreviations that lose context.** Compress only when the full form is universally unambiguous (e.g. `id`, `sku`, `ip`).

---

## Bicep Parameters and Variables

### Be explicit about what the value represents

Bad -- ambiguous without context:
```bicep
param hubRg string
param hubSub string
param rg string
```

Good -- self-describing:
```bicep
param networkHubResourceGroup string
param networkHubSubscriptionId string
param tierResourceGroup string
```

### Compound names: context first, kind last

Format: `[context][Qualifier][Kind]`

```bicep
param networkHubResourceGroup string       // context=networkHub, kind=ResourceGroup
param networkHubSubscriptionId string      // context=networkHub, kind=SubscriptionId
param sharedResourceGroup string           // context=shared, kind=ResourceGroup
param containerAppEnvironmentDefaultDomain string  // context=containerAppEnvironment, kind=DefaultDomain
```

### Type/resource name collisions

When an imported type name and a resource symbolic name would collide (e.g. type `virtualNetworkLink` and resource `virtualNetworkLink`), qualify the resource name to disambiguate -- prefix with the parent resource or add a plural:

```bicep
// type virtualNetworkLink imported from models
resource dnsVirtualNetworkLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [...]
```

### No positional or single-letter names

Bad:
```bicep
var rg1 = ...
var sub = ...
param s string
```

Good:
```bicep
var tierResourceGroup = ...
var networkHubSubscriptionId = ...
param location string
```

### Loop variables: name the item, not the index

Bad:
```bicep
[for i in range(0, length(zones)): { ... zones[i] ... }]
```

Good:
```bicep
[for zoneName in privateDnsZoneNames: { ... zoneName ... }]
[for principal in spokeDeploymentPrincipals: { ... principal.principalId ... }]
```

---

## Azure Resource Naming

Pattern: `[type]-[projectAffix]-[qualifier]-[env]`

All lowercase. Hyphens as separators. No underscores.

| Resource | Pattern | Example |
|---|---|---|
| Resource group | `rg-{project}-{qualifier}` or `rg-{project}-{qualifier}-{environment}` | `rg-app-network-hub-non-prod` |
| Virtual network | `{Env}{Project}Vnet` | `DvAppVnet` |
| Private DNS zone | Azure convention (unchanged) | `privatelink.blob.core.windows.net` |
| NSG | `{VNetName}Nsg` | `DvAppVnetNsg` |
| Private endpoint | `{resourceName}Pe_{uniqueString}` | `DvAppAdxPe_a3f2...` |

### Environment affixes

| Pipeline env | Resource suffix |
|---|---|
| `Dv`, `Qa`, `Sg` | `dv` (all non-prod share the hub) |
| `Pd` | `pd` |

### Hub resource group derivation

The network hub resource group is always derived from `projectAffix` and whether the hub is production or non-production. Do not use deployment environment names like `dv`, `qa`, or `sg` in the network hub resource group name.

```bicep
var networkHubResourceGroup = toLower('rg-${projectAffix}-network-hub-${isProduction ? 'prod' : 'non-prod'}')
```

Spokes should compute this from convention rather than hardcoding the string.

---

## Module Parameters: Name What You're Passing, Not Where It Came From

Bad -- describes the source:
```bicep
param hubParams object
param networkingConfig object
```

Good -- describes the content:
```bicep
param networkHubResourceGroup string
param networkHubSubscriptionId string
```

Avoid bundling unrelated values into a single `object` param to reduce verbosity. Pass discrete, named params. The compiler and future readers both benefit.
