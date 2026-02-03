
# FortiGate Autoscale Simplified Template
## Technical Deep Dive & UI Annotation System

**Presenter:** [Mike Wooten]
**Duration:** 30 minutes

---

# Agenda

1. **Motivation** - Why I built this (3 min)
2. **Architecture Overview** - How components fit together (7 min)
3. **UI Annotation System** - Self-configuring forms (8 min)
4. **Adding New Cloud Providers** - Extending the UI (4 min)
5. **Problems Left to Solve** - Deployment & credentials (6 min)
6. **Q&A** (2 min)

---

# Part 1: Motivation

---

# The Problem

**Fortinet's Official Module is Powerful but Complex**

```hcl
# terraform-aws-cloud-modules requires structures like this:
fgt_intf_mode    = "1-arm"
fgt_intf_byol    = { port1 = { ... }, port2 = { ... } }
gwlb_config      = { enable_cross_zone_lb = true, ... }
asg_config       = { byol = { min = 1, max = 2 }, ondemand = { ... } }
# ... 50+ nested parameters
```

**Pain Points:**
- Steep learning curve for new users
- Easy to misconfigure nested structures
- No validation until `terraform plan`
- Requires deep AWS + Fortinet knowledge

---

# Woot Solution

- Created in a few days of VIBE coding with Claude Code 

**Simplified Wrapper + Self-Configuring Web UI**

| Approach | Benefit |
|----------|---------|
| Terraform wrapper | Hide complexity, expose simple variables |
| Data sources | Auto-discover existing resources by tags |
| Annotation system | Generate UI from tfvars comments |
| Validation | Catch errors before Terraform runs |

**Result:** Deploy FortiGate autoscale in minutes, not hours

---

# Part 2: Architecture Overview

---

# Repository Structure

```
Autoscale-Simplified-Template/
├── terraform/
│   ├── existing_vpc_resources/   # Base infrastructure
│   ├── autoscale_template/       # FortiGate ASG + GWLB
│   └── ha_pair/                  # FortiGate HA (no GWLB)
├── ui/
│   ├── backend/                  # FastAPI + Python
│   └── frontend/                 # React + Vite
└── content/                      # Hugo documentation
```

---

# Deployment Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Step 1: existing_vpc_resources                             │
│  - Management VPC, Transit Gateway, Spoke VPCs              │
│  - Choose: GWLB subnets (autoscale) OR HA sync subnets      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 2: autoscale_template OR ha_pair                      │
│  - Uses data sources to find resources by tag               │
│  - Must match cp + env values from Step 1                   │
└─────────────────────────────────────────────────────────────┘
```

**Key Insight:** Templates discover each other via AWS tags
`{cp}-{env}-*` naming convention (e.g., `acme-test-inspection-vpc`)

---

# easy_autoscale.tf - The Magic Layer

```hcl
# Data sources find existing resources by tag
data "aws_vpc" "inspection" {
  filter {
    name   = "tag:Name"
    values = ["${var.cp}-${var.env}-inspection-vpc"]
  }
}

# Locals build the complex structures upstream module needs
locals {
  asg_fgt_info = {
    instance_type = var.fgt_instance_type
    fgt_config    = data.template_file.fgt_conf.rendered
    # ... assembled automatically
  }
}
```

**User provides:** `cp = "acme"`, `env = "test"`
**Template discovers:** VPCs, subnets, TGW, security groups

---

# Configuration Templates

| Mode | Interfaces | Use Case |
|------|------------|----------|
| 1-arm | Single port (hairpin) | Simple egress inspection |
| 2-arm | port1=Public, port2=GWLB | Traditional firewall |
| +dedicated mgmt | +port3 in mgmt VPC | Isolated management |
| +dedicated ENI | +port3 in inspection | Management via ENI |

**Auto-selected based on variables:**
- `firewall_policy_mode` (1-arm / 2-arm)
- `enable_dedicated_management_vpc`
- `enable_dedicated_management_eni`

---

# Part 3: UI Annotation System

---

# The Concept

**Problem:** Every Terraform template needs a different UI
**Solution:** Embed UI metadata in the tfvars file itself

```hcl
# @ui-type: select
# @ui-source: aws-regions
# @ui-label: AWS Region
# @ui-description: AWS region where resources will be deployed
# @ui-required: true
aws_region = "us-west-1"
```

**One file defines both:**
1. Terraform variable with default value
2. Complete UI field specification

---

# Annotation Categories

| Category | Directives | Purpose |
|----------|------------|---------|
| **Groups** | `@ui-group`, `@ui-order` | Organize fields into sections |
| **Field Config** | `@ui-type`, `@ui-label`, `@ui-description` | Basic field setup |
| **Data Sources** | `@ui-source`, `@ui-depends-on` | Populate dropdowns |
| **Validation** | `@ui-validation`, `@ui-pattern` | Input validation |
| **Conditional** | `@ui-show-if`, `@ui-hide-if` | Dynamic visibility |
| **Layout** | `@ui-width`, `@ui-placeholder` | Visual layout |

---

# Field Types

```hcl
# @ui-type: text          # Standard text input
# @ui-type: select        # Dropdown (single choice)
# @ui-type: boolean       # Checkbox
# @ui-type: number        # Numeric with min/max
# @ui-type: cidr          # CIDR notation with validation
# @ui-type: password      # Masked input
# @ui-type: file          # File path
# @ui-type: multiselect   # Multiple choice
```

---

# Data Sources

**Static Options:**
```hcl
# @ui-source: static
# @ui-options: eip|Elastic IP,nat_gw|NAT Gateway
```

**AWS Dynamic:**
```hcl
# @ui-source: aws-regions      # Fetches all regions
# @ui-source: aws-keypairs     # EC2 keypairs in region
# @ui-source: aws-availability-zones
# @ui-source: aws-vpcs
```

**Dependencies:**
```hcl
# @ui-depends-on: aws_region   # Refreshes when region changes
```

---

# Conditional Display

**Show/Hide Fields Based on Other Values:**

```hcl
# @ui-type: boolean
# @ui-label: Enable FortiManager
enable_fortimanager = false

# @ui-type: password
# @ui-show-if: enable_fortimanager == true
# @ui-label: FortiManager Admin Password
fortimanager_admin_password = ""
```

**Supports:**
- `==`, `!=` comparisons
- `&&`, `||` logical operators
- Complex expressions

---

# Validation Rules

```hcl
# String validation
# @ui-validation: min-length:8,max-length:32

# Network validation
# @ui-validation: cidr,not-overlap
# @ui-validation: within:vpc_cidr_east

# Cross-field validation
# @ui-validation: different-from:availability_zone_1

# Numeric validation
# @ui-validation: min:1,max:254
```

**Validation happens in browser before Terraform runs**

---

# Complete Example

```hcl
#====================================================================================================
# @ui-group: FortiManager Configuration
# @ui-description: Configure FortiManager integration
# @ui-order: 5
# @ui-show-if: enable_build_management_vpc == true
#====================================================================================================

# @ui-type: boolean
# @ui-label: Enable FortiManager
# @ui-description: Deploy FortiManager for centralized management
# @ui-required: true
# @ui-default: false
enable_fortimanager = false

# @ui-type: select
# @ui-source: static
# @ui-options: m5.large|2 vCPU / 8GB ($73/mo),m5.xlarge|4 vCPU / 16GB ($146/mo)
# @ui-label: Instance Type
# @ui-show-if: enable_fortimanager == true
fortimanager_instance_type = "m5.xlarge"
```

---

# Part 4: Adding New Cloud Providers 

- I haven't done this yet. 
- Volunteers?

---

# Architecture for Multi-Cloud

```
ui/backend/app/api/
├── aws.py           # AWS-specific endpoints
├── azure.py         # NEW: Azure endpoints
├── gcp.py           # NEW: GCP endpoints
└── terraform.py     # Cloud-agnostic schema parser

terraform/
├── aws_autoscale/           # Existing AWS templates
├── azure_autoscale/         # NEW: Azure templates
│   └── terraform.tfvars.example  # With @ui-* annotations
└── gcp_autoscale/           # NEW: GCP templates
```

---

# Step 1: Add Cloud Provider API

**Create `ui/backend/app/api/azure.py`:**

```python
router = APIRouter(prefix="/api/azure", tags=["azure"])

@router.get("/regions")
async def list_regions():
    # Return Azure regions

@router.get("/resource-groups")
async def list_resource_groups(subscription_id: str):
    # Return resource groups
```

**Register in `main.py`:**
```python
from app.api import azure
app.include_router(azure.router)
```

---

# Step 2: Add Data Source Types

**Update annotation system to recognize new sources:**

```hcl
# @ui-source: azure-regions
# @ui-source: azure-resource-groups
# @ui-depends-on: azure_subscription_id

# @ui-source: gcp-regions
# @ui-source: gcp-projects
```

**Update `frontend/src/services/api.js`:**
```javascript
async fetchAzureRegions() {
  return this.get('/api/azure/regions');
}
```

---

# Step 3: Create Annotated Template

**`terraform/azure_autoscale/terraform.tfvars.example`:**

```hcl
#====================================================================================================
# @ui-group: Azure Configuration
# @ui-order: 1
#====================================================================================================

# @ui-type: select
# @ui-source: azure-regions
# @ui-label: Azure Region
# @ui-required: true
azure_region = "eastus"

# @ui-type: select
# @ui-source: azure-resource-groups
# @ui-depends-on: azure_subscription_id
# @ui-label: Resource Group
resource_group_name = ""
```

---

# Step 4: Register Template

**Update `terraform.py`:**
```python
valid_templates = [
    'existing_vpc_resources',
    'autoscale_template',
    'ha_pair',
    'azure_autoscale',    # NEW
    'gcp_autoscale'       # NEW
]
```

**Frontend automatically discovers new template**

---

# Part 5: Problems Left to Solve

---

# Current State: "Works on My Mac"

**Today's Setup:**
```
┌─────────────────────────────────────────┐
│  Mike's MacBook                         │
│  ├── Python backend (FastAPI)           │
│  ├── React frontend (Vite dev server)   │
│  ├── AWS credentials (~/.aws/*)         │
│  └── Terraform binary                   │
└─────────────────────────────────────────┘
```

**This doesn't scale to customers!**

---

# Deployment Options - Where Should This Run?

| Option                                 | Pros | Cons |
|----------------------------------------|------|------|
| **Containers (Docker/K8s)**            | Portable, standard deployment | Customer needs to host somewhere |
| **FortiManager Container Integration** | Already in customer environment | I don't know how to do this
| **Cloud-hosted (SaaS)**                | Zero customer infrastructure | We host & maintain, credential concerns |
| **Customer's Cloud**                   | Their infra, their control | Complex setup per customer |
| **Desktop App (Electron)**             | Runs locally like today | Distribution, updates, cross-platform |

**No clear winner yet - need to evaluate trade-offs**

---

# The Credential Problem

**Current approach:** Backend reads `~/.aws/credentials` directly

**For customers, we need to handle:**

| Scenario | Challenge |
|----------|-----------|
| **Multiple AWS accounts** | Which credentials to use? |
| **Cross-account roles** | AssumeRole workflows |
| **Temporary credentials** | Session tokens, expiration |
| **Azure/GCP** | Different auth mechanisms entirely |
| **Customer isolation** | Can't mix credentials between customers |

**Key Question:** Who owns the credentials?
- Customer provides at runtime? (security review needed)
- Pre-configured in deployment? (per-customer instances)
- Federated identity? (complex but cleanest)

---

# SSO / Identity Integration

**Will this work with enterprise SSO?**

| Integration Point | Complexity | Notes |
|-------------------|------------|-------|
| **UI Authentication** | Medium | OIDC/SAML for login - standard patterns |
| **Cloud Credentials** | Hard | SSO identity → cloud permissions |
| **FortiCloud SSO** | Unknown | Could leverage existing Fortinet identity |
| **IAM Identity Center** | Medium | AWS-native, maps SSO to IAM roles |

**The hard part:** Mapping SSO identity to cloud provider permissions
- Azure: App registrations, service principals
- AWS: IAM Identity Center, role mappings
- GCP: Workload identity federation

---

# Possible Architecture: SaaS Model

```
┌─────────────────────────────────────────────────────────────┐
│  Fortinet-Hosted Service                                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ React UI    │  │ FastAPI     │  │ Terraform   │         │
│  │ (CDN)       │  │ Backend     │  │ Runner      │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│         │               │                │                  │
│         └───────────────┼────────────────┘                  │
│                         │                                   │
│                   FortiCloud SSO                            │
└─────────────────────────┼───────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
   Customer AWS      Customer Azure    Customer GCP
   (AssumeRole)      (Service Principal) (Workload ID)
```

**Customer provides:** Cross-account role ARN or equivalent
**We never see:** Long-term credentials

---

# Possible Architecture: Container Model

```
┌─────────────────────────────────────────────────────────────┐
│  Customer Environment (EKS / AKS / GKE / On-prem)          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Docker Container                                    │   │
│  │  ├── React UI (nginx)                               │   │
│  │  ├── FastAPI Backend                                │   │
│  │  └── Terraform binary                               │   │
│  └─────────────────────────────────────────────────────┘   │
│         │                                                   │
│         │ (Instance role / Managed identity / Workload ID) │
│         ▼                                                   │
│    Cloud APIs (no explicit credentials needed)             │
└─────────────────────────────────────────────────────────────┘
```

**Simplest credential model** - container inherits cloud permissions
**Downside:** Customer must deploy and maintain

---

# Decision Matrix

| Requirement | SaaS | Container | FMG Plugin | Desktop |
|-------------|------|-----------|------------|---------|
| Easy for customer | ✅ | ⚠️ | ✅ | ✅ |
| Credential security | ⚠️ | ✅ | ✅ | ⚠️ |
| Multi-cloud support | ✅ | ✅ | ❓ | ✅ |
| SSO integration | ✅ | ⚠️ | ✅ | ❌ |
| Fortinet controls updates | ✅ | ⚠️ | ✅ | ⚠️ |
| Works offline | ❌ | ✅ | ✅ | ✅ |
| Dev effort | High | Medium | High | Medium |

**Need input from:** Security, Product Management, Field

---

# CloudFormation

**Not sure? Maybe, but I haven't looked at it yet.**

---

# Summary: What Makes This Extensible

| Component | Role |
|-----------|------|
| **tfvars_parser.py** | Cloud-agnostic, parses any annotated file |
| **Annotation system** | Works for any Terraform template |
| **api/{cloud}.py** | Isolated cloud-specific logic |
| **Data sources** | Pluggable via `@ui-source` |

**To add a new cloud:**
1. Create API endpoints (auth, list resources)
2. Add data source mappings
3. Write annotated terraform.tfvars.example (Easily VIBE'D)
4. Register template name

---

# Questions?

**Resources:**
- `ui/ANNOTATION_REFERENCE.md` - Complete annotation docs
- `ui/backend/app/parsers/tfvars_parser.py` - Parser implementation
- `ui/backend/app/api/aws.py` - Example cloud provider API

**Workshop Site:**
https://fortinetcloudcse.github.io/Autoscale-Simplified-Template/ 
-    Currently under add_ha branch. It doesn't belong here, but here by evolution
-    No workshop material on UI Annotation yet. 

---

# Appendix: Quick Reference

**Essential Annotations:**
```
@ui-group: <name>              # Section header
@ui-type: <text|select|...>    # Field type
@ui-label: <label>             # Display label
@ui-source: <aws-*|static>     # Data source
@ui-show-if: <expr>            # Conditional
@ui-validation: <rules>        # Validation
@ui-depends-on: <field>        # Refresh trigger
```
