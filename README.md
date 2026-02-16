# Annotation-Driven UI for Infrastructure-as-Code

A system that **dynamically generates interactive web forms directly from annotated IaC configuration files** — no template-specific UI code required.

Add `@ui-` annotations as comments in your Terraform `.tfvars.example` files. The system parses them and renders a fully functional web UI with grouped fields, live cloud API dropdowns, conditional visibility, cross-template resource discovery, validation, and one-click deployment.

```hcl
# @ui-group: Region Configuration
# @ui-label: AWS Region
# @ui-type: select
# @ui-source: aws-regions
aws_region = "us-west-2"

# @ui-label: Key Pair
# @ui-type: select
# @ui-source: aws-keypairs
# @ui-depends-on: aws_region
keypair = ""

# @ui-label: Enable FortiManager
# @ui-type: checkbox
enable_fortimanager = false

# @ui-label: FortiManager IP
# @ui-show-if: enable_fortimanager=true
fortimanager_ip = ""
```

The annotations above produce a web form with a region dropdown populated from your AWS account, a keypair dropdown that refreshes when you change regions, and a checkbox that reveals additional fields when enabled — all without writing a single line of frontend code.

**Workshop Documentation**: [fortinetcloudcse.github.io/fortinet-ui-terraform](https://fortinetcloudcse.github.io/fortinet-ui-terraform/)

## The Problem

IaC tools like Terraform are powerful but have real usability barriers:

- **Configuration complexity.** A typical template has 50+ variables across networking, security, licensing, and cloud-provider settings. Users edit raw `.tfvars` files with no guidance.
- **Static, tightly-coupled UIs.** Solutions that add a web UI require building and maintaining separate, hardcoded forms for each template. Every template change requires UI changes.
- **No live cloud context.** Users must manually look up valid regions, VPC IDs, keypair names. There's no way to declare in the config file that a field should be populated from a live API.
- **No cross-template awareness.** Multi-stage deployments require manually copying resource IDs between config files.
- **No reactive behavior.** Flat variable files can't express conditional visibility or mutual exclusivity between fields.

## How It Solves Them

**The configuration file IS the UI definition.** Annotations are embedded as comments — invisible to Terraform, meaningful to the UI system.

- **Zero-code UI generation.** Annotate a config file, get a complete web form. No frontend changes, no backend changes, no new deployments.
- **Single source of truth.** The annotated file is simultaneously the variable definition, UI schema, validation rules, and documentation. No schema drift.
- **Live cloud data in annotations.** Declare `@ui-source: aws-keypairs` in a config file comment and the system queries your AWS account at runtime.
- **Cross-template resource discovery.** Tag patterns like `@ui-tag-pattern: {cp}-{env}-inspection-vpc` resolve against live cloud resources, auto-populating fields with IDs from previously deployed infrastructure.
- **Reactive forms.** `@ui-show-if`, `@ui-hide-if`, and `@ui-exclusive-with` create dynamic form behavior declared entirely in config file comments.
- **IaC-tool and vendor agnostic.** The `@ui-` annotation pattern works with any config format that supports comments (HCL, YAML, TOML, INI). Currently demonstrated with Terraform, but the parser and renderer are generic.

## Annotation Reference

### Core Tags

| Tag | Purpose | Example |
|-----|---------|---------|
| `@ui-type` | Input widget | `select`, `text`, `checkbox`, `number`, `password`, `slider`, `list` |
| `@ui-label` | Display name | `EC2 Key Pair` |
| `@ui-description` | Help text | `Select an existing keypair` |
| `@ui-source` | Live data source | `aws-regions`, `aws-keypairs`, `gcp-networks` |
| `@ui-depends-on` | Data source dependency chain | `aws_region` |
| `@ui-group` | Field grouping | `Network Settings` |
| `@ui-show-if` | Conditional visibility | `enable_ha == true` |
| `@ui-hide-if` | Conditional hide | `mode != advanced` |
| `@ui-required` | Mandatory field | `true` |
| `@ui-default` | Pre-filled value | `us-west-2` |
| `@ui-options` | Static dropdown values | `dev\|staging\|prod` |
| `@ui-exclusive-with` | Mutual exclusion | `enable_autoscale` |
| `@ui-validation` | Validation rules | `cidr`, `min:1,max:100` |
| `@ui-compute` | Computed value | `cidrsubnet(vpc_cidr, subnet_bits, 0)` |

### Dynamic Data Sources

| Source | Queries |
|--------|---------|
| `aws-regions` | Available AWS regions |
| `aws-availability-zones` | AZs in selected region |
| `aws-keypairs` | EC2 keypairs in selected region |
| `aws-vpcs` | VPCs in selected region |
| `aws-fortinet-resource` | Resources by Fortinet-Role tag pattern |
| `gcp-projects` | Accessible GCP projects |
| `gcp-regions` / `gcp-zones` / `gcp-networks` | GCP resources |

### Cross-Template Resource Discovery

```hcl
# @ui-type: select
# @ui-source: aws-fortinet-resource
# @ui-tag-key: Fortinet-Role
# @ui-tag-pattern: {cp}-{env}-inspection-vpc
# @ui-tag-resource-type: vpc
inspection_vpc = ""
```

Placeholders `{cp}`, `{env}`, `{region}`, `{az1}`, `{az2}` resolve from current form values at runtime. Works across providers — AWS uses tags, GCP uses labels with parallel `@ui-label-*` annotations.

## Template Registry

Templates live in external git repos. The app maintains a SQLite registry that tracks them with drift detection.

### Workflow

1. **Register** — provide a git repo URL, branch, and path to the template directory
2. **Scaffold** — the system clones the repo, parses `variables.tf` and `terraform.tfvars.example`, and auto-generates a `tfvars.ui` skeleton with annotations inferred from variable metadata
3. **Enrich** — export the scaffold, add `@ui-source`, `@ui-group`, `@ui-show-if`, and other annotations, then import it back
4. **Deploy** — fill in the form and run plan/apply/destroy with streaming terminal output

### Drift Detection

Two-tier system based on SHA-256 file hashes stored at import time:

- **Hard stop** — `variables.tf` or `terraform.tfvars.example` changed upstream. Blocks plan/apply until resolved via the drift resolution UI.
- **Warning** — other `.tf` files changed. Informational banner, does not block execution.

## Quick Start

### Prerequisites

- Python 3.11+ with [uv](https://docs.astral.sh/uv/)
- Node.js 18+
- Git

### Setup and Run

```bash
cd ui && ./SETUP.sh    # Install dependencies
./RESTART.sh            # Start backend + frontend
```

- **Frontend**: http://localhost:3000
- **Backend API**: http://127.0.0.1:8000
- **Swagger Docs**: http://127.0.0.1:8000/docs

### Container Deployment

```bash
cd ui && docker compose up --build
```

### Register Your First Template

1. Click **+** in the template selector
2. Enter a git repo URL, branch, and path to the Terraform template directory
3. Review the auto-generated scaffold, export it, enrich the `@ui-` annotations, and import it back
4. Fill in the form and deploy

## Architecture

```
ui/
├── backend/                         # Python FastAPI
│   ├── app/
│   │   ├── api/
│   │   │   ├── templates.py         # Template registry CRUD
│   │   │   ├── tfvars_ui.py         # Scaffold, export/import, drift, schema
│   │   │   ├── template_terraform.py # Plan/apply/destroy (streaming)
│   │   │   ├── aws.py               # AWS resource discovery
│   │   │   └── gcp.py               # GCP resource discovery
│   │   ├── services/
│   │   │   ├── git_service.py       # Async git clone/pull
│   │   │   ├── hcl_parser.py        # variables.tf parser
│   │   │   ├── tfvars_example_parser.py  # @ui- annotation parser
│   │   │   ├── scaffold_generator.py     # tfvars.ui generation
│   │   │   ├── file_hash_service.py      # SHA-256 file scanning
│   │   │   └── drift_service.py          # Two-tier drift detection
│   │   └── db/                      # SQLite via aiosqlite
│   └── tests/                       # 250+ pytest tests
├── frontend/                        # React + Vite
│   └── src/components/
│       ├── TerraformConfig.jsx      # Main UI: selector, form, build controls
│       ├── TemplateRegistration.jsx  # Registration modal
│       ├── DriftResolution.jsx      # Side-by-side drift resolution
│       └── FormField.jsx            # Dynamic field renderer
└── docker-compose.yml
```

## Cloud Credentials

### AWS

```bash
# Local development
source ~/.local/bin/aws_login.sh [profile]

# Container/remote — POST session credentials
curl -X POST http://127.0.0.1:8000/api/aws/credentials/set \
  -H "Content-Type: application/json" \
  -d '{"access_key":"...","secret_key":"...","session_token":"..."}'
```

### GCP

```bash
curl -X POST http://127.0.0.1:8000/api/gcp/credentials/set \
  -H "Content-Type: application/json" \
  -d @/path/to/service-account-key.json
```

## Example Templates

The `terraform/` directory contains working examples with full annotations:

| Template | Description |
|----------|-------------|
| `terraform/aws/existing_vpc_resources` | Base AWS infrastructure (VPCs, TGW, subnets) |
| `terraform/aws/autoscale_template` | FortiGate autoscale group with GWLB |
| `terraform/aws/ha_pair` | FortiGate HA active-passive pair |
| `terraform/gcp/existing_vpc_resources` | Base GCP infrastructure |

These demonstrate cross-template resource discovery via Fortinet-Role tags, conditional field groups, and multi-stage deployment workflows.

## Testing

```bash
cd ui/backend && uv run python -m pytest tests/ -v
```

250+ tests covering services, database operations, and API endpoints.

## Documentation

Full developer docs at the [workshop site](https://fortinetcloudcse.github.io/fortinet-ui-terraform/) under **Working in the UI** — annotation reference, template registration, backend APIs, parsers, cloud providers, frontend development, and troubleshooting.
