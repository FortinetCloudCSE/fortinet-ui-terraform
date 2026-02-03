---
title: "Overview"
menuTitle: "Overview"
weight: 20
---

## Introduction

FortiOS natively supports AWS Autoscaling capabilities, enabling dynamic horizontal scaling of FortiGate clusters within AWS environments. This solution leverages AWS Gateway Load Balancer (GWLB) to intelligently distribute traffic across FortiGate instances in the autoscale group. The cluster dynamically adjusts its capacity based on configurable thresholds—automatically launching new instances when the cluster size falls below the minimum threshold and terminating instances when capacity exceeds the maximum threshold. As instances are added or removed, they are seamlessly registered with or deregistered from associated GWLB target groups, ensuring continuous traffic inspection capabilities while maintaining optimal cluster performance and capacity.

## Key Benefits

This autoscaling solution delivers several strategic advantages for AWS security architectures:

### Elastic Scalability
- **Horizontal scaling**: Automatically scales FortiGate cluster capacity in response to traffic patterns and resource utilization
- **Cost optimization**: Scales down during low-traffic periods to reduce operational costs
- **Performance assurance**: Scales up during peak demand to maintain consistent security inspection throughput

### Flexible Licensing Options
- **Hybrid licensing model**: Supports combination of BYOL (Bring Your Own License), FortiFlex usage-based licensing for baseline capacity, and AWS Marketplace PAYG (Pay-As-You-Go) for elastic burst capacity
- **License optimization**: Minimize costs by using BYOL/FortiFlex licenses for steady-state workloads and PAYG for temporary scale-out events
- **Simplified license management**: Automated license token injection during instance launch via Lambda functions

### High Availability and Configuration Management
- **Automated configuration synchronization**: Primary FortiGate instance automatically synchronizes security policies and configuration to secondary instances using FortiOS native HA sync mechanisms
- **FortiManager integration**: Optional centralized management through FortiManager for policy orchestration, compliance monitoring, and operational visibility across the autoscale group
- **Consistent security posture**: Configuration drift prevention ensures all instances enforce identical security policies

### Architectural Flexibility
- **Centralized inspection architecture**: Single inspection VPC model with Transit Gateway integration for hub-and-spoke topology
- **Distributed inspection architecture**: GWLB endpoints placed directly in spoke VPCs for bump-in-the-wire inspection without Transit Gateway
- **Deployment patterns**: Support for single-arm (1-ENI) and dual-arm (2-ENI) FortiGate deployments

### Internet Egress Options
- **Elastic IP (EIP) NAT**: Each FortiGate instance can leverage individual EIPs for source NAT, providing consistent egress IP addresses for allowlist scenarios
- **NAT Gateway integration**: Alternative architecture using shared NAT Gateways for cost-optimized egress traffic when static source IPs are not required
- **Distributed egress**: Traffic hairpins through FortiGate for transparent bump-in-the-wire inspection, then egresses via existing NAT Gateways or Internet Gateways in spoke VPCs

## Architecture Considerations

This simplified template streamlines the deployment of FortiGate autoscale groups by abstracting infrastructure complexity while providing customization options for:
- VPC and subnet configuration
- Licensing strategy selection
- FortiManager/FortiAnalyzer integration
- Network interface design (dedicated management ENI options)
- Scaling policies and thresholds
- Transit Gateway attachment and routing

