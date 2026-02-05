---
title: "Terraform Configuration Web UI"
linkTitle: "Terraform Web UI"
weight: 1
archetype: "home"
description: "A graphical interface for configuring Terraform deployments"
summary: "A graphical interface for configuring Terraform deployments"
---

A graphical interface for configuring Terraform deployments.

<!--more-->

![Terraform Configuration Web UI](ui-screenshot.png)

Generate `terraform.tfvars` files through a graphical interface. The UI dynamically builds forms from annotated `terraform.tfvars.example` files, making any Terraform template configurable without editing text files.

## Included Templates

| Template | Description |
|----------|-------------|
| **existing_vpc_resources** | Base AWS infrastructure: Management VPC, Transit Gateway, spoke VPCs |
| **autoscale_template** | Elastic FortiGate cluster with Gateway Load Balancer |
| **ha_pair** | Fixed Active-Passive FortiGate cluster with FGCP |

## Quick Start

```bash
git clone https://github.com/FortinetCloudCSE/fortinet-ui-terraform.git
cd fortinet-ui-terraform/ui
./SETUP.sh      # First time only
./RESTART.sh
```

Open http://localhost:3000 and follow the **[Getting Started](2_getting_started/)** guide.
