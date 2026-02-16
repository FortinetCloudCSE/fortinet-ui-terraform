---
title: "Annotation Reference"
menuTitle: "Annotation Reference"
weight: 1
---

The UI dynamically generates configuration forms by reading `@ui-` annotations in `terraform.tfvars.example` files. The scaffold generator auto-creates these annotations from `variables.tf` metadata; users enrich them for better UI presentation.

## Annotation Format

Add `@ui-` annotation comments directly above each variable assignment:

```hcl
# @ui-label AWS Region
# @ui-description Select the AWS region for deployment
# @ui-type select
# @ui-options us-east-1|us-west-2|eu-west-1
# @ui-default us-west-2
# @ui-group Region Configuration
aws_region = "us-west-2"
```

---

## Supported Tags

### Core Tags

| Tag | Description | Example |
|-----|-------------|---------|
| `@ui-label` | Display name in the form | `# @ui-label AWS Region` |
| `@ui-description` | Help text below the field | `# @ui-description Select the deployment region` |
| `@ui-type` | Input control type | `# @ui-type select` |
| `@ui-options` | Values for select (pipe-separated) | `# @ui-options dev\|staging\|prod` |
| `@ui-default` | Pre-filled value | `# @ui-default us-west-2` |
| `@ui-required` | Field must be filled | `# @ui-required true` |
| `@ui-group` | Groups related fields | `# @ui-group Network Settings` |
| `@ui-show-if` | Conditional visibility | `# @ui-show-if enable_tgw=true` |
| `@ui-source` | Dynamic data source | `# @ui-source aws-regions` |

### Resource Discovery Tags

Used with `@ui-source aws-fortinet-resource` for tag-based resource lookup:

| Tag | Description | Example |
|-----|-------------|---------|
| `@ui-tag-key` | Tag key for discovery | `# @ui-tag-key Fortinet-Role` |
| `@ui-tag-pattern` | Tag value with placeholders | `# @ui-tag-pattern {cp}-{env}-inspection-vpc` |
| `@ui-tag-resource-type` | AWS resource type | `# @ui-tag-resource-type vpc` |

### Mutual Exclusivity Tags

| Tag | Description | Example |
|-----|-------------|---------|
| `@ui-exclusive-with` | Mutually exclusive with another field | `# @ui-exclusive-with enable_ha_pair_deployment` |
| `@ui-collapsible` | Group can be collapsed | `# @ui-collapsible true` |
| `@ui-collapsed` | Group starts collapsed | `# @ui-collapsed true` |

---

## Input Types

### text
Single-line text input.

```hcl
# @ui-label Customer Prefix
# @ui-type text
# @ui-required true
cp = ""
```

### password
Masked text input for sensitive values.

```hcl
# @ui-label Admin Password
# @ui-type password
# @ui-required true
admin_password = ""
```

### number
Numeric input.

```hcl
# @ui-label Desired Capacity
# @ui-type number
# @ui-default 2
asg_desired_capacity = 2
```

### checkbox
Boolean toggle.

```hcl
# @ui-label Enable FortiManager
# @ui-type checkbox
# @ui-default false
enable_fortimanager = false
```

### select
Dropdown with predefined options.

```hcl
# @ui-label Instance Type
# @ui-type select
# @ui-options c5n.xlarge|c5n.2xlarge|c5n.4xlarge
# @ui-default c5n.xlarge
instance_type = "c5n.xlarge"
```

### list
Multiple values as a list.

```hcl
# @ui-label Management CIDRs
# @ui-type list
# @ui-description IP ranges allowed to access management interfaces
management_cidr_sg = ["0.0.0.0/0"]
```

---

## Grouping Fields

Use `@ui-group` to organize related fields together:

```hcl
# @ui-label AWS Region
# @ui-group Region Configuration
aws_region = "us-west-2"

# @ui-label Availability Zone 1
# @ui-group Region Configuration
availability_zone_1 = "a"

# @ui-label Enable FortiManager
# @ui-group Optional Components
enable_fortimanager = false
```

Fields with the same `@ui-group` value appear together in the UI.

---

## Conditional Fields

Use `@ui-show-if` to show fields only when a condition is met:

```hcl
# @ui-label Enable FortiManager
# @ui-type checkbox
enable_fortimanager = false

# @ui-label FortiManager IP
# @ui-type text
# @ui-show-if enable_fortimanager=true
fortimanager_ip = ""

# @ui-label FortiManager Password
# @ui-type password
# @ui-show-if enable_fortimanager=true
fortimanager_password = ""
```

The FortiManager IP and password fields only appear when the checkbox is enabled.

---

## Dynamic Data Sources

Use `@ui-source` to populate dropdowns from live cloud APIs:

```hcl
# @ui-label AWS Region
# @ui-type select
# @ui-source aws-regions
aws_region = ""

# @ui-label Key Pair
# @ui-type select
# @ui-source aws-keypairs
keypair = ""
```

### Fortinet-Role Tag Discovery

For fields that reference resources created by other templates:

```hcl
# @ui-type select
# @ui-source aws-fortinet-resource
# @ui-tag-key Fortinet-Role
# @ui-tag-pattern {cp}-{env}-inspection-vpc
# @ui-tag-resource-type vpc
inspection_vpc = ""
```

Supported `@ui-tag-resource-type` values: `vpc`, `subnet`, `igw`, `tgw`, `tgw-attachment`, `tgw-rtb`

Placeholder tokens `{cp}`, `{env}`, `{region}`, `{az1}`, `{az2}` are replaced with the corresponding field values from the current form.

---

## Scaffold Generation

When you register a template, the scaffold generator auto-creates annotations from `variables.tf`:

| HCL Type | Generated `@ui-type` |
|----------|---------------------|
| `string` | `text` |
| `number` | `number` |
| `bool` | `checkbox` |
| `list(*)` | `list` |
| `map(*)` | `text` |

Variable names are converted to labels (e.g., `enable_jump_box` becomes `Enable Jump Box`). HCL `description` fields become `@ui-description`. Validation rules with `condition` expressions generate `@ui-options`.

Existing annotations in `terraform.tfvars.example` are preserved and merged with the generated scaffold.
