# FortiGate Terraform Configuration UI

A web-based application for generating and managing Terraform configurations for FortiGate deployments in AWS. The UI simplifies the complexity of configuring FortiGate autoscale groups and HA pairs by providing an intuitive form-based interface.

**Workshop Documentation**: [fortinetcloudcse.github.io/Autoscale-Simplified-Template](https://fortinetcloudcse.github.io/Autoscale-Simplified-Template/)

## Features

- **Visual Configuration**: Generate Terraform configurations through a web interface
- **Template Selection**: Support for multiple deployment templates
- **AWS Integration**: Discover AWS resources (regions, AZs, key pairs) directly in the UI
- **Validation**: Real-time form validation and configuration checks
- **Schema-Driven**: Dynamic forms generated from Terraform variable schemas

## Quick Start

### Backend

```bash
cd ui/backend
python3 -m venv venv
source venv/bin/activate
pip install fastapi uvicorn pydantic pydantic-settings python-dotenv boto3 requests
uvicorn app.main:app --reload
```

### Frontend

```bash
cd ui/frontend
npm install
npm run dev
```

Access the UI at `http://localhost:3000`

## UI Architecture

```
ui/
├── backend/                  # FastAPI Python backend
│   ├── app/
│   │   ├── main.py          # Application entry point
│   │   ├── config.py        # Environment configuration
│   │   ├── api/
│   │   │   ├── terraform.py # Terraform schema & config endpoints
│   │   │   └── aws.py       # AWS resource discovery
│   │   └── parsers/
│   │       └── tfvars_parser.py
│   └── .env.example         # Configuration template
│
└── frontend/                 # React application
    ├── src/
    │   ├── App.jsx          # Main application component
    │   ├── components/
    │   │   ├── TerraformConfig.jsx  # Configuration form
    │   │   ├── FormGroup.jsx        # Form section component
    │   │   └── FormField.jsx        # Individual field component
    │   └── services/
    │       └── api.js       # Backend API client
    └── vite.config.js       # Vite build configuration
```

### API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Health check |
| `GET /api/terraform/schema` | Get template variable schema |
| `GET /api/terraform/config/load` | Load existing configuration |
| `POST /api/terraform/config/save` | Save configuration to tfvars |
| `GET /api/aws/regions` | List AWS regions |
| `GET /api/aws/availability-zones` | List AZs for a region |
| `GET /api/aws/keypairs` | List EC2 key pairs |

### Configuration

Copy `.env.example` to `.env` in the backend directory:

```bash
cd ui/backend
cp .env.example .env
```

Environment variables:
- `HOST` - Backend host (default: 127.0.0.1)
- `PORT` - Backend port (default: 8000)
- `CORS_ORIGINS` - Allowed frontend origins
- `AWS_PROFILE` - AWS credentials profile (optional)
- `AWS_REGION` - Default AWS region

---

## Terraform Templates

The UI generates configurations for these Terraform templates, which are simplified wrappers around Fortinet's [terraform-aws-cloud-modules](https://github.com/fortinetdev/terraform-aws-cloud-modules).

### Supported Templates

| Template | Description |
|----------|-------------|
| `existing_vpc_resources` | Base infrastructure (VPCs, Transit Gateway, test instances) |
| `autoscale_template` | FortiGate Auto Scaling Group with Gateway Load Balancer |
| `ha_pair` | FortiGate Active-Passive HA Pair with FGCP |

### Template Structure

```
terraform/
├── existing_vpc_resources/   # Deploy first - creates base infrastructure
├── autoscale_template/       # Option A: AutoScale with GWLB
└── ha_pair/                  # Option B: HA Pair (Active-Passive)
```

### Deployment Order

1. **First**: Deploy `existing_vpc_resources` to create VPCs, Transit Gateway, and test instances
2. **Second**: Deploy either `autoscale_template` OR `ha_pair`

### Manual Deployment

If not using the UI, deploy templates manually:

```bash
cd terraform/existing_vpc_resources
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init && terraform apply

cd ../autoscale_template  # or ha_pair
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars - cp and env must match
terraform init && terraform apply
```

### Resource Naming

All resources use the pattern: `{cp}-{env}-{resource_name}`

The `cp` (customer prefix) and `env` (environment) values must match between templates for resource discovery.

### Architecture

```
                    ┌─────────────────────────────────────────────────┐
                    │              Management VPC                      │
                    │  (Jump Box, FortiManager, FortiAnalyzer)        │
                    └─────────────────────┬───────────────────────────┘
                                          │
                    ┌─────────────────────┴───────────────────────────┐
                    │              Transit Gateway                     │
                    └──────┬──────────────┬──────────────┬────────────┘
                           │              │              │
              ┌────────────┴───┐   ┌──────┴──────┐   ┌───┴────────────┐
              │   East VPC     │   │ Inspection  │   │   West VPC     │
              │  (Spoke)       │   │    VPC      │   │   (Spoke)      │
              └────────────────┘   │             │   └────────────────┘
                                   │ ┌─────────┐ │
                                   │ │FortiGate│ │
                                   │ │  ASG/HA │ │
                                   │ └─────────┘ │
                                   └─────────────┘
```

---

## Verification Scripts

Validate deployments from `terraform/existing_vpc_resources/`:

```bash
./verify_scripts/verify_all.sh --verify all
```

## Documentation

- **Workshop**: [fortinetcloudcse.github.io/Autoscale-Simplified-Template](https://fortinetcloudcse.github.io/Autoscale-Simplified-Template/)
- **Fortinet Docs**: [docs.fortinet.com](https://docs.fortinet.com/)
- **Upstream Module**: [terraform-aws-cloud-modules](https://github.com/fortinetdev/terraform-aws-cloud-modules)
