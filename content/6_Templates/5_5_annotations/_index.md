---
title: "Annotation Reference"
menuTitle: "Annotation Reference"
weight: 50
---

## Overview

The Web UI dynamically generates configuration forms by reading annotations in `terraform.tfvars.example` files. This allows any Terraform template to be UI-enabled without modifying the UI code.

---

## Annotation Format

Add annotation comments directly above each variable:

```hcl
# @label AWS Region
# @description Select the AWS region for deployment
# @type select
# @options us-east-1, us-west-2, eu-west-1
# @default us-west-2
# @group Region Configuration
aws_region = "us-west-2"
```

---

## Supported Tags

| Tag | Description | Example |
|-----|-------------|---------|
| `@label` | Display name in the form | `# @label AWS Region` |
| `@description` | Help text below the field | `# @description Select the deployment region` |
| `@type` | Input control type | `# @type select` |
| `@options` | Values for select/radio | `# @options us-east-1, us-west-2` |
| `@default` | Pre-filled value | `# @default us-west-2` |
| `@required` | Field must be filled | `# @required true` |
| `@group` | Groups related fields | `# @group Network Settings` |
| `@depends` | Conditional visibility | `# @depends enable_tgw=true` |
| `@inherit` | Copy value from another template | `# @inherit existing_vpc_resources.cp` |

---

## Input Types

### text
Single-line text input.

```hcl
# @label Customer Prefix
# @type text
# @required true
cp = ""
```

### password
Masked text input for sensitive values.

```hcl
# @label Admin Password
# @type password
# @required true
admin_password = ""
```

### number
Numeric input with optional min/max.

```hcl
# @label Desired Capacity
# @type number
# @default 2
asg_desired_capacity = 2
```

### checkbox
Boolean toggle.

```hcl
# @label Enable FortiManager
# @type checkbox
# @default false
enable_fortimanager = false
```

### select
Dropdown with predefined options.

```hcl
# @label Instance Type
# @type select
# @options c5n.xlarge, c5n.2xlarge, c5n.4xlarge
# @default c5n.xlarge
instance_type = "c5n.xlarge"
```

### list
Multiple values as a list.

```hcl
# @label Management CIDRs
# @type list
# @description IP ranges allowed to access management interfaces
management_cidr_sg = ["0.0.0.0/0"]
```

---

## Grouping Fields

Use `@group` to organize related fields together:

```hcl
# @label AWS Region
# @group Region Configuration
aws_region = "us-west-2"

# @label Availability Zone 1
# @group Region Configuration
availability_zone_1 = "a"

# @label Enable FortiManager
# @group Optional Components
enable_fortimanager = false

# @label Enable FortiAnalyzer
# @group Optional Components
enable_fortianalyzer = false
```

Fields with the same `@group` value appear together in the UI.

---

## Conditional Fields

Use `@depends` to show fields only when a condition is met:

```hcl
# @label Enable FortiManager
# @type checkbox
enable_fortimanager = false

# @label FortiManager IP
# @type text
# @depends enable_fortimanager=true
fortimanager_ip = ""

# @label FortiManager Password
# @type password
# @depends enable_fortimanager=true
fortimanager_password = ""
```

The FortiManager IP and password fields only appear when the checkbox is enabled.

---

## Inheriting Values

Use `@inherit` to copy values from another template:

```hcl
# @label Customer Prefix
# @type text
# @inherit existing_vpc_resources.cp
# @readonly true
cp = ""
```

This ensures `cp` in autoscale_template matches `cp` in existing_vpc_resources.

---

## Adding a New Template

1. Create your Terraform template directory under `terraform/`
2. Create `terraform.tfvars.example` with annotated variables
3. The UI automatically detects templates with example files
4. Select your template from the dropdown in the UI

### Example Structure

```
terraform/
├── my_new_template/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example    ← Add annotations here
```

### Minimal Example

```hcl
# @label Project Name
# @description Name used for resource tagging
# @type text
# @required true
# @group General
project_name = ""

# @label Environment
# @type select
# @options dev, staging, prod
# @default dev
# @group General
environment = "dev"

# @label Enable Feature X
# @type checkbox
# @default false
# @group Features
enable_feature_x = false

# @label Feature X Setting
# @type text
# @depends enable_feature_x=true
# @group Features
feature_x_setting = ""
```

---

## Best Practices

1. **Always include `@label`** - Makes the form readable
2. **Use descriptive `@description`** - Helps users understand each field
3. **Group related fields** - Improves form organization
4. **Set sensible `@default` values** - Reduces required user input
5. **Use `@depends` for conditional fields** - Keeps the form clean
6. **Mark sensitive fields as `@type password`** - Masks input appropriately
