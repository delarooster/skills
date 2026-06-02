# Testing Patterns

## Test Directory Structure

```
tests/
├── helpers/
│   ├── naming/          # Unique name generation
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── fixtures/        # Common test data/resources
│   │   └── main.tf
│   └── cleanup/         # Post-test cleanup utilities
│       └── main.tf
├── plan/
│   ├── basic_validation.tftest.hcl
│   ├── variable_constraints.tftest.hcl
│   └── resource_config.tftest.hcl
└── apply/
    ├── quick_resources.tftest.hcl
    └── slow_api_management.tftest.hcl
```

## Test Segregation

**plan/**: Fast validation tests (no real resources created)
- Variable validation
- Resource configuration checks
- Constraint verification
- Run on every CI commit

**apply/**: Integration tests (real resources created)
- Quick resources: Run pre-merge
- Slow resources: Manual/conditional trigger
- Full infrastructure validation

## Run Block Chaining Pattern

Each test file uses chained `run` blocks with shared setup:

```hcl
# tests/plan/validation_test.tftest.hcl

run "setup" {
  command = plan
  
  variables {
    environment = "test"
    location    = "eastus"
  }
}

run "test_storage_account_naming" {
  command = plan
  
  variables {
    storage_account_name = "myapptest"
  }
  
  assert {
    condition     = azurerm_storage_account.main.name == var.storage_account_name
    error_message = "Storage account naming incorrect"
  }
}

run "test_storage_encryption" {
  command = plan
  
  variables {
    storage_account_name = "myapptest"
  }
  
  assert {
    condition     = azurerm_storage_account.main.enable_https_traffic_only == true
    error_message = "HTTPS traffic not enforced"
  }
}
```

## Helper Module Pattern

### Naming Helper (Collision Prevention)

```hcl
# tests/helpers/naming/main.tf

resource "random_id" "test_run" {
  byte_length = 4
}

locals {
  ci_run_id = coalesce(
    var.ci_build_id,
    formatdate("YYYYMMDDhhmmss", timestamp())
  )
  prefix = "test-${local.ci_run_id}-${random_id.test_run.hex}"
}

output "resource_prefix" {
  value = local.prefix
}

output "unique_suffix" {
  value = random_id.test_run.hex
}
```

### Using Helpers in Tests

```hcl
# tests/apply/quick_resources.tftest.hcl

run "setup_naming" {
  command = plan
  
  module {
    source = "../helpers/naming"
  }
  
  variables {
    ci_build_id = env("CI_BUILD_ID")
  }
}

run "create_storage_account" {
  command = apply
  
  variables {
    storage_account_name = "${run.setup_naming.unique_suffix}mystg"
    environment          = "test"
    location             = "eastus"
  }
  
  assert {
    condition     = azurerm_storage_account.main.name == var.storage_account_name
    error_message = "Storage account name mismatch"
  }
}
```

## Helper Module Types

**naming/**: Generate unique resource names to prevent CI collisions
**fixtures/**: Provide common test data (Virtual Networks, subnets, resource groups)
**cleanup/**: Resource cleanup utilities for failed test runs

## TDD-Inspired Testing Principles

### Test Structure Philosophy

Tests follow Test-Driven Development principles adapted for infrastructure:

1. **🟢 Happy Path First**: Test standard, expected usage patterns
2. **🔴 Edge Cases Second**: Test upper/lower bounds and constraints
3. **⚡ Single Assert Per Test**: One assertion per test block (preferred)
4. **🎯 Fail Fast**: Tests verify variables before expensive resource creation

### Happy Path Testing

Primary test focus: Standard configuration that represents real-world usage.

```hcl
# tests/plan/happy_path.tftest.hcl

run "standard_storage_account" {
  command = plan
  
  variables {
    storage_account_name = "myappstg"
    location             = "eastus"
    sku_tier             = "Standard"
  }
  
  assert {
    condition     = azurerm_storage_account.main.account_tier == "Standard"
    error_message = "Storage tier should be Standard"
  }
}
```

### Edge Case Testing

Test boundaries and constraints to catch validation errors:

```hcl
# tests/plan/edge_cases.tftest.hcl

run "storage_account_name_minimum_length" {
  command = plan
  
  variables {
    storage_account_name = "abc"  # Minimum: 3 chars
    location             = "eastus"
  }
  
  expect_failures = [
    var.storage_account_name
  ]
}

run "storage_account_name_maximum_length" {
  command = plan
  
  variables {
    storage_account_name = "abcdefghijklmnopqrstuvwxy"  # 25 chars: too long
    location             = "eastus"
  }
  
  expect_failures = [
    var.storage_account_name
  ]
}

run "retention_days_lower_bound" {
  command = plan
  
  variables {
    retention_days = 1  # Minimum allowed
  }
  
  assert {
    condition     = var.retention_days >= 1
    error_message = "Retention days lower bound validation failed"
  }
}

run "retention_days_upper_bound" {
  command = plan
  
  variables {
    retention_days = 365  # Maximum allowed
  }
  
  assert {
    condition     = var.retention_days <= 365
    error_message = "Retention days upper bound validation failed"
  }
}
```

### Single Assert Per Test

**Preferred**: One assertion per test for precise failure identification.

```hcl
# GOOD: Single assert - clear failure point
run "test_encryption_enabled" {
  command = plan
  
  assert {
    condition     = azurerm_storage_account.main.enable_https_traffic_only == true
    error_message = "HTTPS traffic not enforced"
  }
}

run "test_blob_versioning" {
  command = plan
  
  assert {
    condition     = azurerm_storage_account.main.blob_properties[0].versioning_enabled == true
    error_message = "Blob versioning not enabled"
  }
}
```

**Acceptable**: Multiple related asserts when testing object shape.

```hcl
# ACCEPTABLE: Multiple asserts for complex object validation
run "test_network_rules_configuration" {
  command = plan
  
  assert {
    condition     = azurerm_storage_account.main.network_rules[0].default_action == "Deny"
    error_message = "Network rules default action should be Deny"
  }
  
  assert {
    condition     = contains(azurerm_storage_account.main.network_rules[0].ip_rules, "203.0.113.0/24")
    error_message = "Expected IP range not in network rules"
  }
}
```

### Variable Validation Testing

Test variable validation blocks before resource creation:

```hcl
# tests/plan/variable_validation.tftest.hcl

run "valid_storage_account_name_pattern" {
  command = plan
  
  variables {
    storage_account_name = "validname123"
  }
  
  assert {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name validation pattern failed"
  }
}

run "invalid_storage_account_name_uppercase" {
  command = plan
  
  variables {
    storage_account_name = "InvalidName"
  }
  
  expect_failures = [
    var.storage_account_name
  ]
}

run "invalid_storage_account_name_special_chars" {
  command = plan
  
  variables {
    storage_account_name = "my-storage-account"
  }
  
  expect_failures = [
    var.storage_account_name
  ]
}
```

### Azure Resource Constraint Testing

Azure resources have specific naming and configuration constraints:

```hcl
# tests/plan/azure_constraints.tftest.hcl

run "storage_account_lowercase_only" {
  command = plan
  
  variables {
    storage_account_name = "mystorageaccount"
  }
  
  assert {
    condition     = var.storage_account_name == lower(var.storage_account_name)
    error_message = "Storage account name must be lowercase"
  }
}

run "storage_account_no_hyphens" {
  command = plan
  
  variables {
    storage_account_name = "mystorage"
  }
  
  assert {
    condition     = !can(regex("-", var.storage_account_name))
    error_message = "Storage account name cannot contain hyphens"
  }
}

run "valid_azure_location" {
  command = plan
  
  variables {
    location = "eastus"
  }
  
  assert {
    condition     = contains(["eastus", "westus", "centralus", "westeurope"], var.location)
    error_message = "Invalid Azure location specified"
  }
}
```

## CI Integration

```bash
# Every commit: Fast plan tests
tofu test -test-directory=tests/plan

# Pre-merge: Quick apply tests
tofu test -filter=tests/apply/quick_resources.tftest.hcl

# Manual/conditional: Slow apply tests
tofu test -filter=tests/apply/slow_api_management.tftest.hcl
```

## File Naming Convention

- `*.tftest.hcl` - Standard test files
- `*.tofutest.hcl` - OpenTofu-specific (takes precedence if both exist)
- Descriptive names: `resource_validation.tftest.hcl`, `integration_storage.tftest.hcl`
