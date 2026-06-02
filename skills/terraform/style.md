# Style Guidelines

## Code Conventions

### Variable Declarations

Variables are the **first line of defense** for module safety and correctness.

**Requirements:**
- **Type constraints**: REQUIRED for all variables
- **Defaults**: SET for all variables UNLESS enforced as required (fail-fast pattern)
- **Validation**: STRONGLY ENCOURAGED for business logic and constraints
- **Descriptions**: Concise, actionable

**Basic variable pattern:**

```hcl
variable "storage_account_name" {
  type        = string
  description = "Storage account name (3-24 chars, lowercase alphanumeric)"
}

variable "vm_count" {
  type        = number
  description = "Number of virtual machines to create"
  default     = 1
}
```

**Variable validation pattern:**

Azure resources have specific constraints. Use validation blocks to fail fast:

```hcl
variable "storage_account_name" {
  type        = string
  description = "Storage account name"
  
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 characters, lowercase letters and numbers only"
  }
}

variable "location" {
  type        = string
  description = "Azure region for resources"
  default     = "eastus"
  
  # Example: Organization-specific location allowlist
  # Uncomment and customize if you need to restrict deployments to specific regions
  # validation {
  #   condition     = contains(var.allowed_locations, var.location)
  #   error_message = "Location must be in the organization's approved regions list"
  # }
}

variable "sku_tier" {
  type        = string
  description = "Storage account SKU tier"
  default     = "Standard"
  
  validation {
    condition     = contains(["Standard", "Premium"], var.sku_tier)
    error_message = "SKU tier must be Standard or Premium"
  }
}

variable "retention_days" {
  type        = number
  description = "Log retention in days"
  default     = 90
  
  validation {
    condition     = var.retention_days >= 1 && var.retention_days <= 365
    error_message = "Retention days must be between 1 and 365"
  }
}
```

**Fail-fast pattern:**

Omit defaults for required infrastructure decisions to force explicit input:

```hcl
variable "resource_group_name" {
  type        = string
  description = "Resource group name"
  # No default - fail fast if not provided
  
  validation {
    condition     = length(var.resource_group_name) > 0
    error_message = "Resource group name cannot be empty"
  }
}
```

### Resource Naming

Pattern: `${var.prefix}${resource_type}`

```hcl
resource "azurerm_storage_account" "data" {
  name                = "${var.prefix}datastg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}
```

### Identifier Naming

Resource identifiers (the second label in a `resource` block) must be descriptive. Avoid `this` as a default name.

**Why:** When a module contains multiple resource types, generic identifiers become ambiguous. `azurerm_storage_account.this` and `azurerm_key_vault.this` in the same module tell you nothing - logs, state output, and diffs all become harder to read.

**Rule:** Use identifiers that describe what the resource *is* or what it *does*.

```hcl
# Good: identifier describes the resource's role
resource "azurerm_storage_account" "data" { ... }
resource "azurerm_key_vault" "secrets" { ... }
resource "spacelift_space" "org" { ... }
resource "spacelift_policy" "deploy" { ... }

# Bad: identifier is generic and ambiguous
resource "azurerm_storage_account" "this" { ... }
resource "azurerm_key_vault" "this" { ... }
```

**`for_each` exception:** When a resource uses `for_each` over a map, `this` is acceptable if the map key provides the semantic meaning. The key becomes the real identifier in state (`resource.this["meaningful_key"]`), so the block name is less critical.

```hcl
# Acceptable: for_each key provides identity
resource "spacelift_module" "this" {
  for_each = local.modules   # keys: "network", "storage-account", etc.
  name     = each.key
}

# Also acceptable: descriptive name on for_each resource
resource "spacelift_stack" "module" {
  for_each = local.modules
  name     = "module-${each.key}"
}
```

**Single-instance resources must always use descriptive identifiers.** The `for_each` exception does not apply to resources without iteration.

### Output Declarations

Export all consumable resource attributes:

```hcl
output "storage_account_id" {
  value       = azurerm_storage_account.data.id
  description = "Storage account resource ID"
}

output "storage_account_primary_endpoint" {
  value       = azurerm_storage_account.data.primary_blob_endpoint
  description = "Storage account primary blob endpoint"
}
```

### Comments

- Avoid unless clarifying complex logic
- Prefer self-documenting variable/resource names
- Use when business logic requires explanation

```hcl
# Calculate retention period based on compliance requirements
locals {
  retention_days = var.environment == "prod" ? 2555 : 90  # 7 years for prod
}
```

## Tagging Standards

### Required Azure Tags

All Azure resources must carry these base tags:

| Tag | Purpose | Source |
|---|---|---|
| `Environment` | Deployment environment (`dev`, `staging`, `prod`) | Variable |
| `ManagedBy` | IaC tool managing the resource | Static: `"OpenTofu"` |
| `Repository` | Source repository name | Variable |
| `CostCenter` | Cost attribution for FinOps | Variable |
| `Owner` | Team responsible for the resource | Variable |

### Global-to-Local Merge Pattern

Define global tags in a `locals` block. Merge with resource-specific tags at the point of use:

```hcl
locals {
  global_tags = {
    Environment = var.environment
    ManagedBy   = "OpenTofu"
    Repository  = var.repository_name
    CostCenter  = var.cost_center
    Owner       = var.team_name
  }
}

resource "azurerm_storage_account" "data" {
  name                     = "${var.prefix}datastg"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = merge(local.global_tags, {
    Purpose = "application-data"
  })
}
```

This ensures required tags are never omitted while allowing resource-specific context.

### Spacelift Label Conventions

Spacelift resources (stacks, modules, policies) use labels for autoattachment and categorization:

| Pattern | Purpose | Example |
|---|---|---|
| `autoattach:<group>` | Auto-attach policies to matching stacks | `autoattach:deploy-guard` |
| `managed-by:<repo>` | Track owning repository | `managed-by:platform-admin` |
| `module:<name>` | Identify which module a stack validates | `module:network` |
| Category labels | Classify resources by function | `module`, `validation`, `admin` |

Apply the same global-to-local pattern: shared labels (e.g., `managed-by`) on every resource, per-item labels (e.g., `module:${each.key}`) derived from iteration context.

## Formatting

- Use `tofu fmt` before committing
- 2-space indentation
- Align assignment operators in blocks
- Blank line between resource blocks
