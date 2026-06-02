# Repository Structure

## Root Layout

```
repository-root/
├── main.tf           # Primary resource definitions
├── variables.tf      # Input declarations
├── outputs.tf        # Output values
├── providers.tf      # Provider configurations (azurerm)
├── modules/          # Reusable modules
├── docs/             # Documentation
├── tests/            # Test suites
│   ├── helpers/      # Test utility modules
│   ├── plan/         # Plan-only validation tests
│   └── apply/        # Full apply integration tests
└── README.md         # Repository overview
```

## Module Structure

```
modules/<module-name>/
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
└── README.md
```

## File Responsibilities

**main.tf**: Primary resource definitions only
**variables.tf**: Input declarations with type constraints
**outputs.tf**: Exported resource attributes
**providers.tf**: Version constraints only, no configuration
**README.md**: Module documentation and usage examples

## File Organization Order

Files and blocks within files follow dependency flow for readability:

**main.tf ordering:**
1. **locals** - Computed values and transformations
2. **Top-level resources** - Primary infrastructure (resource groups, storage accounts, VMs)
3. **Dependent resources** - Resources that depend on top-level (role assignments, diagnostics)
4. **Module calls** - External module invocations
5. **outputs** - Exported values (moved to outputs.tf if file grows large)

**Example: main.tf with proper ordering**

```hcl
# 1. Locals first
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "OpenTofu"
  }
  storage_account_name = "${var.prefix}${var.environment}stg"
}

# 2. Top-level resource (Storage Account)
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-${var.environment}-rg"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_storage_account" "main" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.common_tags
}

# 3. Dependent resources
resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# 4. Module calls
module "monitoring" {
  source = "./modules/monitoring"
  
  storage_account_id = azurerm_storage_account.main.id
  location           = azurerm_resource_group.main.location
}
```

**Rationale:**
- **Dependency flow**: Read top-to-bottom matches resource creation order
- **Readability**: Primary infrastructure visible first, details follow
- **Maintenance**: Easy to locate resources by importance/dependency level

## Design Principles

- **Modules in modules/**: All reusable components organized under `modules/`
- **Documentation in docs/**: Centralized documentation directory
- **Minimal providers.tf**: Version constraints only, no provider config
- **Typed variables**: Explicit type constraints for all inputs
- **Descriptive outputs**: Export all consumable resource attributes
- **Flat module structure**: No nested modules for clarity
- **Ordered main.tf**: Follow locals → top-level → dependent → modules → outputs pattern
