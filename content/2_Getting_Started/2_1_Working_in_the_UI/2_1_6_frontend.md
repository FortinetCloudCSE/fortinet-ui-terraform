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
│   ├── TemplateSelector.jsx    # Template dropdown
│   ├── ConfigForm.jsx          # Dynamic form generator
│   ├── FormField.jsx           # Individual field renderer
│   └── GenerateButton.jsx      # Generate/download actions
├── services/
│   └── api.js                  # Backend API client
└── App.jsx
```

---

## API Client

Location: `frontend/src/services/api.js`

```javascript
const API_BASE = 'http://127.0.0.1:8000';

export async function getTemplates() {
  const response = await fetch(`${API_BASE}/api/templates`);
  return response.json();
}

export async function getTemplateVariables(templateName) {
  const response = await fetch(`${API_BASE}/api/templates/${templateName}/variables`);
  return response.json();
}

export async function generateTfvars(templateName, values) {
  const response = await fetch(`${API_BASE}/api/templates/${templateName}/generate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(values)
  });
  return response.json();
}
```

---

## Adding Dynamic Dropdowns

To make a field populate from an API:

### 1. Add Special Annotation Type

```hcl
# @label AWS Region
# @type aws-region
aws_region = "us-west-2"
```

### 2. Handle in FormField Component

```jsx
function FormField({ field, value, onChange }) {
  if (field.type === 'aws-region') {
    return <AWSRegionSelector value={value} onChange={onChange} />;
  }
  // ... other field types
}
```

### 3. Create the Selector Component

```jsx
function AWSRegionSelector({ value, onChange }) {
  const [regions, setRegions] = useState([]);

  useEffect(() => {
    fetch('/api/aws/regions')
      .then(r => r.json())
      .then(data => setRegions(data.regions));
  }, []);

  return (
    <select value={value} onChange={e => onChange(e.target.value)}>
      {regions.map(r => (
        <option key={r.id} value={r.id}>{r.name}</option>
      ))}
    </select>
  );
}
```

