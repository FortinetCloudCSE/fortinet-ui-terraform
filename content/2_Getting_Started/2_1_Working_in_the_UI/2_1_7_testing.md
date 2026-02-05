---
title: "Testing"
menuTitle: "Testing"
weight: 7
---

Backend and frontend testing.

## Backend Tests

```bash
cd ui/backend
uv run pytest
```

---

## Frontend Tests

```bash
cd ui/frontend
npm test
```

---

## Manual Testing Checklist

When adding new features:

- [ ] Template appears in dropdown
- [ ] All fields render with correct types
- [ ] Conditional fields show/hide correctly
- [ ] Required field validation works
- [ ] Generate produces valid terraform.tfvars
- [ ] AWS credential status displays correctly
- [ ] Dynamic dropdowns populate from AWS

