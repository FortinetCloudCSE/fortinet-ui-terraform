---
title: "Frontend Development"
menuTitle: "Frontend"
weight: 6
---

React components and API client development.

## Component Structure

```
frontend/src/
├── components/
│   ├── TerraformConfig.jsx       # Main UI: template selector, form, build controls
│   ├── TemplateRegistration.jsx  # Modal: register new template from git repo
│   ├── DriftResolution.jsx       # Modal: side-by-side drift resolution
│   └── FormField.jsx             # Individual field renderer (text, select, etc.)
├── services/
│   └── api.js                    # Backend API client
└── App.jsx
```

---

## Key Components

### TerraformConfig.jsx

The main UI component. Manages:
- **Template selector** — DB-driven dropdown populated from `/api/templates/`
- **Drift indicators** — Badge next to selector showing Clean/Warning/Hard Stop
- **Warning banner** — Non-blocking yellow banner for warning-level drift
- **Template metadata** — Repo URL, branch, last updated for selected template
- **Form rendering** — Dynamically generated from template schema
- **Build controls** — Plan/apply/destroy with streaming output

### TemplateRegistration.jsx

Two-step modal workflow:
1. **Registration form** — Name, repo URL, branch, path in repo
2. **Scaffold review** — Shows generated tfvars.ui with Export/Import buttons

### DriftResolution.jsx

Side-by-side modal for resolving hard-stop drift:
- **Left panel** — List of changed files with type icons (A=Added, M=Modified, D=Removed)
- **Right panel** — Inline tfvars.ui editor with Re-scaffold button
- **Save & Re-hash** — Persists changes and clears drift

---

## API Client

Location: `frontend/src/services/api.js`

### Template Registry Methods

```javascript
import { api } from './services/api';

// List registered templates
const templates = await api.templates.list();

// Register a new template
const template = await api.templates.create({
  name: "My Template",
  repo_url: "https://github.com/org/repo.git",
  branch: "main",
  repo_path: "terraform/aws/my_template"
});

// Generate scaffold
const scaffold = await api.templates.scaffold(template.id);

// Export/import tfvars.ui
const exported = await api.templates.export(template.id);
await api.templates.import(template.id, enrichedContent);

// Check drift
const drift = await api.templates.getDrift(template.id);

// Delete
await api.templates.delete(template.id);
```

### Cloud Provider Methods

```javascript
// AWS
const regions = await api.aws.getRegions();
const azs = await api.aws.getAvailabilityZones(region);
const keypairs = await api.aws.getKeypairs(region);
const resources = await api.aws.discoverFortinetResources(region, cp, env);

// GCP
const projects = await api.gcp.getProjects();
const regions = await api.gcp.getRegions(project);
const networks = await api.gcp.getNetworks(project);
```

---

## Adding Dynamic Dropdowns

To make a field populate from a cloud API:

### 1. Add Annotation

```hcl
# @ui-label AWS Region
# @ui-type select
# @ui-source aws-regions
aws_region = "us-west-2"
```

### 2. Handle in FormField

The `FormField.jsx` component checks the `source` annotation and fetches data from the appropriate API endpoint. Supported sources:

| Source | API Call |
|--------|---------|
| `aws-regions` | `api.aws.getRegions()` |
| `aws-availability-zones` | `api.aws.getAvailabilityZones(region)` |
| `aws-keypairs` | `api.aws.getKeypairs(region)` |
| `aws-vpcs` | `api.aws.getVpcs(region)` |
| `aws-fortinet-resource` | `api.aws.discoverResourceByTag(...)` |
| `gcp-projects` | `api.gcp.getProjects()` |
| `gcp-regions` | `api.gcp.getRegions(project)` |
| `gcp-zones` | `api.gcp.getZones(project, region)` |
| `gcp-networks` | `api.gcp.getNetworks(project)` |

### 3. Add a New Source

To add a new dynamic source (e.g., `aws-security-groups`):

1. Add the API endpoint in `app/api/aws.py`
2. Add the client method in `api.js` under `api.aws`
3. Add the source handler in `FormField.jsx`
