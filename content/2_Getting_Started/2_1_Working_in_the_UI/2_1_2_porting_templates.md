---
title: "Registering Templates"
menuTitle: "Registering Templates"
weight: 2
---

How to add Terraform templates to the UI via the template registry.

## Overview

The UI uses a **template registry** to manage templates. Instead of placing templates in a local directory, you register a git repository URL and the backend clones it, parses `variables.tf`, and generates a scaffold `tfvars.ui` file with UI annotations.

---

## Step 1: Prepare Your Template

Your template repository must contain at minimum:

```
my-template/
├── main.tf                      # Required - Terraform configuration
├── variables.tf                 # Required - Variable definitions (parsed for scaffold)
├── outputs.tf                   # Optional
└── terraform.tfvars.example     # Recommended - Pre-annotated defaults
```

The scaffold generator reads `variables.tf` for variable names, types, defaults, and descriptions. If `terraform.tfvars.example` exists, its `@ui-` annotations are merged into the scaffold.

## Step 2: Register via UI

1. Click the **"+"** button next to the template dropdown
2. Fill in the registration form:
   - **Name** — Display name (e.g., "AWS Autoscale Template")
   - **Repository URL** — Git clone URL (e.g., `https://github.com/org/repo.git`)
   - **Branch** — Branch to track (default: `main`)
   - **Path in Repo** — Subdirectory containing the template (e.g., `terraform/aws/autoscale_template`)
3. Click **Register**

The backend will:
1. Clone the repository
2. Verify the path exists
3. Scan all files and store SHA-256 hashes
4. Auto-generate a scaffold `tfvars.ui`

### Register via API

```bash
curl -X POST http://127.0.0.1:8000/api/templates/ \
  -H "Content-Type: application/json" \
  -d '{
    "name": "AWS Autoscale Template",
    "repo_url": "https://github.com/FortinetCloudCSE/fortinet-ui-terraform.git",
    "branch": "main",
    "repo_path": "terraform/aws/autoscale_template"
  }'
```

## Step 3: Review and Enrich the Scaffold

After registration, the scaffold `tfvars.ui` is auto-generated with basic annotations. To improve the UI:

1. Click **Export** to download the `tfvars.ui` file
2. Edit annotations to add:
   - Better `@ui-label` values
   - `@ui-description` help text
   - `@ui-group` for organizing fields
   - `@ui-show-if` for conditional visibility
   - `@ui-source` for dynamic dropdowns (e.g., `aws-regions`, `aws-keypairs`)
   - `@ui-options` for static select lists
3. Click **Import** to upload the enriched file

### Export/Import via API

```bash
# Export scaffold
curl http://127.0.0.1:8000/api/templates/1/export

# Import enriched tfvars.ui
curl -X POST http://127.0.0.1:8000/api/templates/1/import \
  -H "Content-Type: application/json" \
  -d '{"content": "# @ui-label AWS Region\n# @ui-type select\naws_region = \"us-west-2\"\n"}'
```

## Step 4: Verify in UI

1. Select your template from the dropdown
2. Verify all fields render correctly
3. Test conditional fields (`@ui-show-if`)
4. Test dynamic dropdowns (`@ui-source`)
5. Check drift status indicator (should show "Clean")

---

## Drift Detection

After registration, the backend tracks file hashes. When the upstream repository changes:

- **Warning drift** (non-critical `.tf` files changed): Yellow banner, does not block plan/apply
- **Hard-stop drift** (critical files like `variables.tf`, `terraform.tfvars.example`): Red indicator, blocks plan/apply until resolved

To resolve drift:
1. Click the drift indicator to open the resolution UI
2. Review changed files (side-by-side diff)
3. Re-scaffold if needed (pulls latest `variables.tf` changes)
4. Save & re-hash to clear the drift

---

## Updating a Template

When the upstream repo changes:

```bash
# Update repo URL or branch
curl -X PUT http://127.0.0.1:8000/api/templates/1 \
  -H "Content-Type: application/json" \
  -d '{"branch": "v2.0"}'
```

The backend re-clones and re-hashes. If critical files changed, drift will be detected.

## Deleting a Template

```bash
curl -X DELETE http://127.0.0.1:8000/api/templates/1
```

This removes the template record, file hashes, and cloned directory.

---

## Best Practices

1. **Write good `variables.tf` descriptions** — The scaffold generator uses them for `@ui-description`
2. **Use validation rules** — HCL `validation` blocks with `condition` expressions generate `@ui-options` automatically
3. **Pre-annotate `terraform.tfvars.example`** — Existing `@ui-` annotations are preserved during scaffold generation
4. **Group related fields** — Use `@ui-group` to organize the form
5. **Use `@ui-show-if` for conditional fields** — Keeps the form clean
6. **Mark sensitive fields as `@ui-type password`** — Masks input appropriately
7. **Set sensible `@ui-default` values** — Reduces required user input
8. **Track a stable branch** — Avoid tracking `main` if it changes frequently (causes frequent drift)
