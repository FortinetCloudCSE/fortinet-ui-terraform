---
title: "Autoscale Reference"
chapter: true
menuTitle: "Autoscale Reference"
weight: 10
---

Detailed explanations of autoscale template components, configuration options, and architectural considerations.

{{% notice tip %}}
**New to FortiGate AWS deployments?** Start with the [Getting Started](../../../2_getting_started/) guide to deploy your first environment using the Web UI. Return here for deeper architectural understanding.
{{% /notice %}}

## What You'll Learn

This section covers the major architectural elements available in the autoscale_template:

- **Internet Egress Options**: Choose between EIP or NAT Gateway architectures
- **Firewall Architecture**: Understand 1-ARM vs 2-ARM configurations
- **Management Isolation**: Configure dedicated management ENI and VPC options
- **Licensing**: Manage BYOL licenses and integrate FortiFlex API
- **FortiManager Integration**: Enable centralized management and policy orchestration
- **Capacity Planning**: Configure autoscale group sizing and scaling strategies (AutoScale only)
- **Primary Protection**: Implement scale-in protection for configuration stability (AutoScale only)
- **Additional Options**: Fine-tune instance specifications and advanced settings

Each component page includes:
- Configuration examples
- Architecture diagrams
- Best practices
- Troubleshooting guidance
- Use case recommendations

---

## Deployment Mode Comparison

| Component | autoscale_template | ha_pair |
|-----------|-------------------|---------|
| Internet Egress | EIP or NAT Gateway | Cluster EIP (moves on failover) |
| Firewall Architecture | 1-ARM or 2-ARM | 2-ARM (4 interfaces) |
| Management | Standard, ENI, or VPC | Dedicated management interface (Port4) |
| Licensing | BYOL, PAYG, FortiFlex | BYOL or PAYG (no FortiFlex) |
| FortiManager | Optional integration | Optional integration |
| Scaling | Auto scales 2-10+ | Fixed 2 instances (Primary/Secondary) |
| Failover | GWLB health checks | FGCP Active-Passive with session sync |

---

Select a component from the navigation menu to learn more about specific autoscale_template configuration options.
