# Terraform UI Annotation Reference Guide

## Overview

This guide documents the annotation format used to create self-configuring Terraform configuration UIs. By adding special `@ui-*` comments to your `terraform.tfvars.example` file, you can automatically generate dynamic web forms with validation, AWS integration, and smart field dependencies.

## Table of Contents

- [Quick Start](#quick-start)
- [Annotation Directives](#annotation-directives)
  - [Group Directives](#group-directives)
  - [Field Configuration](#field-configuration)
  - [Data Sources](#data-sources)
  - [Validation](#validation)
  - [Conditional Display](#conditional-display)
  - [Layout](#layout)
  - [Help and Documentation](#help-and-documentation)
- [Field Types](#field-types)
- [Data Source Types](#data-source-types)
- [Validation Rules](#validation-rules)
- [Expression Syntax](#expression-syntax)
- [Complete Examples](#complete-examples)
- [Best Practices](#best-practices)

---

## Quick Start

### Basic Field Annotation

```hcl
# @ui-type: text
# @ui-label: Customer Prefix
# @ui-description: Company or project identifier
# @ui-required: true
# @ui-placeholder: acme
# @ui-help: Use lowercase letters, numbers, and hyphens only
cp = "acme"
```

### Grouping Fields

```hcl
#====================================================================================================
# @ui-group: Security Configuration
# @ui-description: Configure security settings for SSH access
# @ui-order: 3
#====================================================================================================
```

### AWS Integration

```hcl
# @ui-type: select
# @ui-source: aws-regions
# @ui-label: AWS Region
# @ui-required: true
aws_region = "us-west-1"

# @ui-type: select
# @ui-source: aws-availability-zones
# @ui-depends-on: aws_region
# @ui-label: Availability Zone
availability_zone_1 = "a"
```

---

## Annotation Directives

### Group Directives

Group directives organize fields into logical sections.

#### `@ui-group`
**Purpose:** Name of the group/section
**Format:** `# @ui-group: <group_name>`
**Example:**
```hcl
# @ui-group: Network Configuration
```

#### `@ui-description` (Group Level)
**Purpose:** Description of what the group contains
**Format:** `# @ui-description: <description_text>`
**Example:**
```hcl
# @ui-description: Configure IP address ranges for all VPCs and subnets
```

#### `@ui-order`
**Purpose:** Sort order for groups (lower numbers appear first)
**Format:** `# @ui-order: <number>`
**Example:**
```hcl
# @ui-order: 1
```

#### `@ui-show-if` (Group Level)
**Purpose:** Conditional display of entire group
**Format:** `# @ui-show-if: <condition_expression>`
**Example:**
```hcl
# @ui-show-if: enable_build_management_vpc == true
```

---

### Field Configuration

#### `@ui-type`
**Purpose:** Type of input field to render
**Required:** Yes
**Format:** `# @ui-type: <type>`
**Values:** `text`, `select`, `boolean`, `number`, `cidr`, `password`, `file`, `multiselect`
**Example:**
```hcl
# @ui-type: select
```

#### `@ui-label`
**Purpose:** Display label for the field
**Required:** Yes
**Format:** `# @ui-label: <label_text>`
**Example:**
```hcl
# @ui-label: AWS Region
```

#### `@ui-description`
**Purpose:** Short description shown below the field
**Required:** Yes
**Format:** `# @ui-description: <description_text>`
**Example:**
```hcl
# @ui-description: AWS region where all resources will be deployed
```

#### `@ui-required`
**Purpose:** Whether the field must have a value
**Format:** `# @ui-required: true|false`
**Default:** `false`
**Example:**
```hcl
# @ui-required: true
```

#### `@ui-default`
**Purpose:** Default value if user doesn't specify
**Format:** `# @ui-default: <value>`
**Example:**
```hcl
# @ui-default: 8
```

#### `@ui-placeholder`
**Purpose:** Placeholder text shown in empty field
**Format:** `# @ui-placeholder: <text>`
**Example:**
```hcl
# @ui-placeholder: x.x.x.x/32
```

---

### Data Sources

Data sources determine where dropdown options come from.

#### `@ui-source`
**Purpose:** Where to get field options from
**Required:** For `select` and `multiselect` types
**Format:** `# @ui-source: <source_type>`
**Values:** `aws-regions`, `aws-availability-zones`, `aws-keypairs`, `aws-vpcs`, `static`
**Example:**
```hcl
# @ui-source: aws-regions
```

#### `@ui-options`
**Purpose:** Static options for select fields
**Required:** When `@ui-source: static`
**Format:** `# @ui-options: value1|Label 1,value2|Label 2,value3|Label 3`
**Example:**
```hcl
# @ui-options: eip|Elastic IP per instance,nat_gw|NAT Gateway (centralized)
```

**Example with multiline (split for readability):**
```hcl
# @ui-options: m5.large|2 vCPU / 8GB RAM - Small,m5.xlarge|4 vCPU / 16GB RAM - Medium,m5.2xlarge|8 vCPU / 32GB RAM - Large
```

#### `@ui-depends-on`
**Purpose:** Field that this field depends on (triggers refresh)
**Format:** `# @ui-depends-on: <field_name>`
**Example:**
```hcl
# @ui-depends-on: aws_region
```

**Use Case:** When region changes, availability zones dropdown refreshes:
```hcl
# @ui-type: select
# @ui-source: aws-regions
# @ui-label: AWS Region
aws_region = "us-west-1"

# @ui-type: select
# @ui-source: aws-availability-zones
# @ui-depends-on: aws_region  # ← Refreshes when region changes
# @ui-label: Availability Zone
availability_zone_1 = "a"
```

---

### Validation

#### `@ui-validation`
**Purpose:** Validation rules (comma-separated)
**Format:** `# @ui-validation: <rule1>,<rule2>,<rule3>`
**Example:**
```hcl
# @ui-validation: cidr,not-overlap
# @ui-validation: min-length:8
# @ui-validation: min:1,max:254
```

**Available Rules:**
- `not-empty` - Field cannot be empty
- `cidr` - Must be valid CIDR notation
- `ipv4` - Must be valid IPv4 address
- `min-length:<N>` - Minimum string length
- `max-length:<N>` - Maximum string length
- `min:<N>` - Minimum numeric value
- `max:<N>` - Maximum numeric value
- `regex:<pattern>` - Must match regex pattern
- `lowercase-alphanumeric` - Only lowercase letters, numbers, hyphens
- `single-letter` - Must be single letter (a-z)
- `different-from:<field>` - Must differ from another field
- `within:<parent_field>` - CIDR must be within parent CIDR
- `not-overlap` - CIDR must not overlap with other CIDRs
- `version-format` - Must be X.Y or X.Y.Z format

#### `@ui-pattern`
**Purpose:** Regex pattern for validation
**Format:** `# @ui-pattern: <regex>`
**Example:**
```hcl
# @ui-pattern: ^[a-z0-9-]+$
```

---

### Conditional Display

#### `@ui-show-if`
**Purpose:** Show field only when condition is true
**Format:** `# @ui-show-if: <condition_expression>`
**Example:**
```hcl
# @ui-show-if: enable_fortimanager == true
# @ui-show-if: enable_build_existing_subnets == true
# @ui-show-if: enable_build_existing_subnets == true && enable_build_management_vpc == true
```

#### `@ui-hide-if`
**Purpose:** Hide field when condition is true (inverse of show-if)
**Format:** `# @ui-hide-if: <condition_expression>`
**Example:**
```hcl
# @ui-hide-if: enable_build_management_vpc == false
```

---

### Layout

#### `@ui-width`
**Purpose:** Field width in responsive grid
**Format:** `# @ui-width: <width>`
**Values:** `full`, `half`, `third`, `quarter`
**Default:** `full`
**Example:**
```hcl
# @ui-width: half
```

**Use Case - Side-by-side fields:**
```hcl
# @ui-type: text
# @ui-label: Customer Prefix
# @ui-width: half
cp = "acme"

# @ui-type: text
# @ui-label: Environment
# @ui-width: half
env = "test"
```

---

### Help and Documentation

#### `@ui-help`
**Purpose:** Extended help text (shown in tooltip or expandable section)
**Format:** `# @ui-help: <help_text>`
**Example:**
```hcl
# @ui-help: Use lowercase letters, numbers, and hyphens only. Example: 'acme' creates 'acme-test-vpc'
```

#### `@ui-link`
**Purpose:** URL to external documentation
**Format:** `# @ui-link: <url>`
**Example:**
```hcl
# @ui-link: https://docs.fortinet.com/product/fortimanager/
```

---

## Field Types

### `text`
Standard text input field.

```hcl
# @ui-type: text
# @ui-label: Customer Prefix
# @ui-description: Company or project identifier
# @ui-required: true
# @ui-width: half
# @ui-pattern: ^[a-z0-9-]+$
# @ui-placeholder: acme
# @ui-validation: lowercase-alphanumeric
cp = "acme"
```

### `select`
Dropdown selection (single choice).

```hcl
# @ui-type: select
# @ui-source: static
# @ui-options: eip|Elastic IP,nat_gw|NAT Gateway
# @ui-label: Internet Access Mode
# @ui-description: How FortiGates access the internet
# @ui-required: true
# @ui-default: eip
access_internet_mode = "eip"
```

### `boolean`
Checkbox (true/false).

```hcl
# @ui-type: boolean
# @ui-label: Enable FortiManager
# @ui-description: Deploy FortiManager instance
# @ui-required: true
# @ui-default: false
enable_fortimanager = false
```

### `number`
Numeric input with validation.

```hcl
# @ui-type: number
# @ui-label: Subnet Bits
# @ui-description: Number of bits for subnet calculation
# @ui-required: true
# @ui-default: 8
# @ui-validation: min:4,max:16
# @ui-placeholder: 8
subnet_bits = 8
```

### `cidr`
CIDR notation input with validation.

```hcl
# @ui-type: cidr
# @ui-label: Management VPC CIDR
# @ui-description: CIDR block for management VPC
# @ui-required: true
# @ui-placeholder: 10.3.0.0/16
# @ui-validation: cidr,not-overlap
# @ui-help: Must not overlap with inspection or spoke VPC CIDRs
vpc_cidr_management = "10.3.0.0/16"
```

### `password`
Password input (masked).

```hcl
# @ui-type: password
# @ui-label: FortiManager Admin Password
# @ui-description: Password for admin user
# @ui-required: true
# @ui-placeholder: Minimum 8 characters
# @ui-validation: min-length:8
# @ui-show-if: enable_fortimanager == true
fortimanager_admin_password = ""
```

### `file`
File path input (may include file picker in future).

```hcl
# @ui-type: file
# @ui-label: FortiManager License File
# @ui-description: Path to BYOL license file
# @ui-required: false
# @ui-placeholder: ./licenses/fmgr_license.lic
# @ui-help: Leave empty for PAYG
# @ui-show-if: enable_fortimanager == true
fortimanager_license_file = "./licenses/fmgr_license.lic"
```

### `multiselect`
Multiple selection dropdown.

```hcl
# @ui-type: multiselect
# @ui-source: static
# @ui-options: http|HTTP Traffic,https|HTTPS Traffic,ssh|SSH Traffic
# @ui-label: Allowed Protocols
# @ui-description: Select protocols to allow
allowed_protocols = ["http", "https"]
```

---

## Data Source Types

### `aws-regions`
Fetches all AWS regions from `/api/aws/regions`.

**Returns:**
```json
[
  {"name": "us-east-1", "display_name": "us-east-1 - opt-in-not-required"},
  {"name": "us-west-1", "display_name": "us-west-1 - opt-in-not-required"}
]
```

**Example:**
```hcl
# @ui-type: select
# @ui-source: aws-regions
# @ui-label: AWS Region
aws_region = "us-west-1"
```

### `aws-availability-zones`
Fetches availability zones for selected region from `/api/aws/availability-zones?region=X`.

**Requires:** `@ui-depends-on: aws_region`

**Returns:**
```json
[
  {"zone_id": "usw1-az3", "zone_name": "us-west-1a", "region": "us-west-1", "state": "available"},
  {"zone_id": "usw1-az1", "zone_name": "us-west-1b", "region": "us-west-1", "state": "available"}
]
```

**Example:**
```hcl
# @ui-type: select
# @ui-source: aws-availability-zones
# @ui-depends-on: aws_region
# @ui-label: Availability Zone 1
availability_zone_1 = "a"
```

### `aws-keypairs`
Fetches EC2 keypairs in selected region from `/api/aws/keypairs?region=X`.

**Requires:** `@ui-depends-on: aws_region`

**Returns:**
```json
[
  {"name": "my-key", "key_pair_id": "key-082c6b...", "fingerprint": "ss:zr:eD..."}
]
```

**Example:**
```hcl
# @ui-type: select
# @ui-source: aws-keypairs
# @ui-depends-on: aws_region
# @ui-label: EC2 Key Pair
keypair = ""
```

### `aws-vpcs`
Fetches VPCs in selected region from `/api/aws/vpcs?region=X`.

**Requires:** `@ui-depends-on: aws_region`

**Returns:**
```json
[
  {"vpc_id": "vpc-123456", "name": "my-vpc", "cidr_block": "10.0.0.0/16", "is_default": false, "state": "available"}
]
```

**Example:**
```hcl
# @ui-type: select
# @ui-source: aws-vpcs
# @ui-depends-on: aws_region
# @ui-label: Existing VPC
vpc_id = ""
```

### `static`
Static options defined in `@ui-options`.

**Format:** `value1|Label 1,value2|Label 2`

**Example:**
```hcl
# @ui-type: select
# @ui-source: static
# @ui-options: m5.large|2 vCPU / 8GB RAM,m5.xlarge|4 vCPU / 16GB RAM,m5.2xlarge|8 vCPU / 32GB RAM
# @ui-label: Instance Type
instance_type = "m5.xlarge"
```

---

## Validation Rules

### String Validation

#### `not-empty`
Field cannot be empty string.

```hcl
# @ui-validation: not-empty
```

#### `min-length:<N>`
Minimum string length.

```hcl
# @ui-validation: min-length:8
```

#### `max-length:<N>`
Maximum string length.

```hcl
# @ui-validation: max-length:32
```

#### `lowercase-alphanumeric`
Only lowercase letters, numbers, and hyphens.

```hcl
# @ui-validation: lowercase-alphanumeric
# @ui-pattern: ^[a-z0-9-]+$
```

#### `single-letter`
Must be single letter (a-z).

```hcl
# @ui-validation: single-letter
```

#### `version-format`
Must be version format (X.Y or X.Y.Z).

```hcl
# @ui-validation: version-format
# Accepts: "7.6", "7.6.1", "7.6.0"
```

### Numeric Validation

#### `min:<N>`
Minimum numeric value.

```hcl
# @ui-validation: min:1
```

#### `max:<N>`
Maximum numeric value.

```hcl
# @ui-validation: max:254
```

#### Combined
```hcl
# @ui-validation: min:1,max:254
```

### Network Validation

#### `cidr`
Must be valid CIDR notation.

```hcl
# @ui-validation: cidr
# Accepts: "10.0.0.0/16", "192.168.1.0/24"
```

#### `ipv4`
Must be valid IPv4 address.

```hcl
# @ui-validation: ipv4
# Accepts: "10.0.0.1", "192.168.1.100"
```

#### `within:<parent_field>`
CIDR must be within parent CIDR block.

```hcl
# @ui-validation: cidr,within:vpc_cidr_east
```

**Example:**
```hcl
# Parent CIDR
vpc_cidr_east = "192.168.0.0/24"

# Child CIDR - must be within 192.168.0.0/24
# @ui-validation: cidr,within:vpc_cidr_east
vpc_cidr_east_public_az1 = "192.168.0.0/28"
```

#### `not-overlap`
CIDR must not overlap with other configured CIDRs.

```hcl
# @ui-validation: cidr,not-overlap
```

### Cross-Field Validation

#### `different-from:<field>`
Value must differ from another field.

```hcl
# @ui-validation: single-letter,different-from:availability_zone_1
```

**Example:**
```hcl
availability_zone_1 = "a"

# Must be different from AZ1
# @ui-validation: single-letter,different-from:availability_zone_1
availability_zone_2 = "b"
```

### Custom Regex

#### `regex:<pattern>`
Must match custom regex pattern.

```hcl
# @ui-validation: regex:^[A-Z]{2}-[0-9]{4}$
# Accepts: "US-1234", "CA-5678"
```

---

## Expression Syntax

Conditional expressions use simple comparison operators.

### Operators

- `==` - Equals
- `!=` - Not equals
- `&&` - Logical AND
- `||` - Logical OR

### Boolean Comparisons

```hcl
# @ui-show-if: enable_fortimanager == true
# @ui-show-if: enable_fortimanager == false
# @ui-hide-if: enable_fortimanager != true
```

### String Comparisons

```hcl
# @ui-show-if: access_internet_mode == "nat_gw"
# @ui-show-if: env != "prod"
```

### Logical AND

```hcl
# @ui-show-if: enable_build_existing_subnets == true && enable_build_management_vpc == true
```

### Logical OR

```hcl
# @ui-show-if: enable_fortimanager == true || enable_fortianalyzer == true
```

### Complex Expressions

```hcl
# @ui-show-if: (enable_build_existing_subnets == true && enable_linux_spoke_instances == true) || force_show == true
```

---

## Complete Examples

### Example 1: AWS Region Selection with Dependent AZs

```hcl
#====================================================================================================
# @ui-group: Region Configuration
# @ui-description: Select AWS region and availability zones
# @ui-order: 1
#====================================================================================================

# @ui-type: select
# @ui-source: aws-regions
# @ui-label: AWS Region
# @ui-description: Primary region for deployment
# @ui-required: true
# @ui-width: full
# @ui-help: All resources will be created in this region
aws_region = "us-west-1"

# @ui-type: select
# @ui-source: aws-availability-zones
# @ui-depends-on: aws_region
# @ui-label: Availability Zone 1
# @ui-description: First availability zone
# @ui-required: true
# @ui-width: half
# @ui-validation: single-letter
availability_zone_1 = "a"

# @ui-type: select
# @ui-source: aws-availability-zones
# @ui-depends-on: aws_region
# @ui-label: Availability Zone 2
# @ui-description: Second availability zone
# @ui-required: true
# @ui-width: half
# @ui-validation: single-letter,different-from:availability_zone_1
availability_zone_2 = "b"
```

### Example 2: Conditional FortiManager Configuration

```hcl
#====================================================================================================
# @ui-group: FortiManager
# @ui-description: Configure FortiManager for policy management
# @ui-order: 5
# @ui-show-if: enable_build_management_vpc == true
#====================================================================================================

# @ui-type: boolean
# @ui-label: Enable FortiManager
# @ui-description: Deploy FortiManager instance
# @ui-required: true
# @ui-default: false
enable_fortimanager = false

# @ui-type: select
# @ui-source: static
# @ui-options: m5.large|2 vCPU / 8GB RAM ($73/mo),m5.xlarge|4 vCPU / 16GB RAM ($146/mo),m5.2xlarge|8 vCPU / 32GB RAM ($292/mo)
# @ui-label: Instance Type
# @ui-description: EC2 instance size
# @ui-required: true
# @ui-default: m5.xlarge
# @ui-show-if: enable_fortimanager == true
fortimanager_instance_type = "m5.xlarge"

# @ui-type: password
# @ui-label: Admin Password
# @ui-description: FortiManager admin password
# @ui-required: true
# @ui-placeholder: Minimum 8 characters
# @ui-validation: min-length:8
# @ui-show-if: enable_fortimanager == true
# @ui-help: REQUIRED - you cannot login without this!
fortimanager_admin_password = ""
```

### Example 3: CIDR Configuration with Validation

```hcl
#====================================================================================================
# @ui-group: Network Configuration
# @ui-description: Configure VPC CIDR blocks
# @ui-order: 2
#====================================================================================================

# @ui-type: cidr
# @ui-label: Management VPC CIDR
# @ui-description: IP range for management VPC
# @ui-required: true
# @ui-placeholder: 10.3.0.0/16
# @ui-validation: cidr,not-overlap
# @ui-help: Must not overlap with other VPCs
vpc_cidr_management = "10.3.0.0/16"

# @ui-type: cidr
# @ui-label: Spoke VPC Supernet
# @ui-description: Supernet containing all spoke VPCs
# @ui-required: true
# @ui-placeholder: 192.168.0.0/16
# @ui-validation: cidr
vpc_cidr_spoke = "192.168.0.0/16"

# @ui-type: cidr
# @ui-label: East Spoke VPC CIDR
# @ui-description: IP range for east workload VPC
# @ui-required: true
# @ui-placeholder: 192.168.0.0/24
# @ui-validation: cidr,within:vpc_cidr_spoke
# @ui-help: Must be within spoke supernet
# @ui-show-if: enable_build_existing_subnets == true
vpc_cidr_east = "192.168.0.0/24"

# @ui-type: cidr
# @ui-label: East Public Subnet AZ1
# @ui-description: Public subnet in first AZ
# @ui-required: true
# @ui-placeholder: 192.168.0.0/28
# @ui-validation: cidr,within:vpc_cidr_east
# @ui-width: half
# @ui-show-if: enable_build_existing_subnets == true
vpc_cidr_east_public_az1 = "192.168.0.0/28"

# @ui-type: cidr
# @ui-label: East Public Subnet AZ2
# @ui-description: Public subnet in second AZ
# @ui-required: true
# @ui-placeholder: 192.168.0.16/28
# @ui-validation: cidr,within:vpc_cidr_east
# @ui-width: half
# @ui-show-if: enable_build_existing_subnets == true
vpc_cidr_east_public_az2 = "192.168.0.16/28"
```

---

## Best Practices

### 1. Group Related Fields

Always use groups to organize related fields:

```hcl
#====================================================================================================
# @ui-group: Security Settings
# @ui-description: Configure authentication and access controls
# @ui-order: 3
#====================================================================================================
```

### 2. Provide Helpful Descriptions

Make descriptions actionable:

✅ **Good:**
```hcl
# @ui-description: AWS region where all resources will be deployed
```

❌ **Bad:**
```hcl
# @ui-description: The region
```

### 3. Use Appropriate Field Widths

Put related short fields side-by-side:

```hcl
# @ui-width: half
cp = "acme"

# @ui-width: half
env = "test"
```

### 4. Always Validate

Add validation to prevent errors:

```hcl
# @ui-validation: cidr,not-overlap
# @ui-validation: min-length:8
# @ui-validation: min:1,max:254
```

### 5. Add Contextual Help

Use `@ui-help` for non-obvious fields:

```hcl
# @ui-help: Use X.Y for latest patch or X.Y.Z for specific version
fortimanager_os_version = "7.6"
```

### 6. Show/Hide Appropriately

Hide irrelevant fields to reduce complexity:

```hcl
# @ui-show-if: enable_fortimanager == true
fortimanager_admin_password = ""
```

### 7. Use Dependencies

Make dropdowns update automatically:

```hcl
# @ui-depends-on: aws_region
availability_zone_1 = "a"
```

### 8. Provide Placeholders

Help users understand expected format:

```hcl
# @ui-placeholder: x.x.x.x/32
# @ui-placeholder: acme
# @ui-placeholder: 10.3.0.0/16
```

### 9. Use Defaults Wisely

Set sensible defaults to speed up configuration:

```hcl
# @ui-default: true
# @ui-default: 8
# @ui-default: m5.xlarge
```

### 10. Document Costs

Include cost information in help text:

```hcl
# @ui-help: m5.xlarge recommended for most deployments (~$73/month)
```

---

## Future Enhancements

Potential additions to the annotation system:

- `@ui-tooltip` - Quick tooltip on hover
- `@ui-info-link` - Documentation link icon
- `@ui-warning` - Warning message for dangerous options
- `@ui-cost` - Estimated cost information
- `@ui-tag` - Tags for filtering/searching
- `@ui-advanced` - Mark field as "advanced" (hidden by default)
- `@ui-preview` - Show live preview of generated value
- `@ui-calculate` - Auto-calculate based on other fields

---

## Contributing

When adding new Terraform templates:

1. Copy this reference guide
2. Annotate your `terraform.tfvars.example`
3. Test with the UI parser
4. Document any new validation rules
5. Update this guide with examples

---

## Version History

- **v1.0** (2025-01-22) - Initial annotation format
  - Basic field types (text, select, boolean, number, cidr, password, file)
  - AWS data sources (regions, AZs, keypairs, VPCs)
  - Validation rules
  - Conditional display
  - Group organization

---

## Support

For questions or issues:
- Check the complete examples above
- Review annotated `terraform.tfvars.example` files
- See UI parser implementation in `backend/app/api/terraform.py`
- Frontend form renderer in `frontend/src/components/TerraformForm.jsx`
