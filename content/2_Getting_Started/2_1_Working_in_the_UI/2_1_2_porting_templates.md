---
title: "Porting New Templates"
menuTitle: "Porting Templates"
weight: 2
---

How to add new Terraform templates to the UI.

## Step 1: Create Template Directory

Create your Terraform template under the `terraform/` directory:

```
terraform/
├── my_new_template/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example    <-- Add annotations here
```

## Step 2: Annotate Variables

Add annotations to `terraform.tfvars.example`:

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

## Step 3: Register the Template

The backend automatically detects templates with `terraform.tfvars.example` files. No code changes required.

## Step 4: Test in UI

1. Restart the backend to detect the new template
2. Select your template from the dropdown
3. Verify all fields render correctly
4. Test conditional fields and validation

---

## Best Practices

1. **Always include `@label`** - Makes the form readable
2. **Use descriptive `@description`** - Helps users understand each field
3. **Group related fields** - Improves form organization
4. **Set sensible `@default` values** - Reduces required user input
5. **Use `@depends` for conditional fields** - Keeps the form clean
6. **Mark sensitive fields as `@type password`** - Masks input appropriately

