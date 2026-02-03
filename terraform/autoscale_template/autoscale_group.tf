
resource "aws_security_group" "management-vpc-sg" {
  count       = var.enable_dedicated_management_vpc || var.enable_dedicated_management_eni ? 1 : 0
  description = "Security Group for FortiGate management interfaces"
  vpc_id      = var.enable_dedicated_management_vpc ? data.aws_vpc.management_vpc[0].id : data.aws_vpc.inspection_vpc.id

  # HTTPS access
  dynamic "ingress" {
    for_each = length(var.fortigate_management_cidr) > 0 ? [1] : []
    content {
      description = "HTTPS management access"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.fortigate_management_cidr
    }
  }

  # ICMP access
  dynamic "ingress" {
    for_each = length(var.fortigate_management_cidr) > 0 ? [1] : []
    content {
      description = "ICMP from management CIDR"
      from_port   = -1
      to_port     = -1
      protocol    = "icmp"
      cidr_blocks = var.fortigate_management_cidr
    }
  }

  # SSH access
  dynamic "ingress" {
    for_each = length(var.fortigate_management_cidr) > 0 ? [1] : []
    content {
      description = "SSH management access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.fortigate_management_cidr
    }
  }

  # SNMP
  dynamic "ingress" {
    for_each = length(var.fortigate_management_cidr) > 0 ? [1] : []
    content {
      description = "SNMP access"
      from_port   = 161
      to_port     = 162
      protocol    = "udp"
      cidr_blocks = var.fortigate_management_cidr
    }
  }

  # FortiManager
  dynamic "ingress" {
    for_each = length(var.fortigate_management_cidr) > 0 ? [1] : []
    content {
      description = "FortiManager access"
      from_port   = 541
      to_port     = 541
      protocol    = "tcp"
      cidr_blocks = var.fortigate_management_cidr
    }
  }
  dynamic "ingress" {
    for_each = length(var.fortigate_management_cidr) > 0 ? [1] : []
    content {
      description = "Config Sync"
      from_port   = 703
      to_port     = 703
      protocol    = "tcp"
      cidr_blocks = var.fortigate_management_cidr
    }
  }

  # IPsec IKE
  dynamic "ingress" {
    for_each = length(var.fortigate_management_cidr) > 0 ? [1] : []
    content {
      description = "IPsec IKE"
      from_port   = 500
      to_port     = 500
      protocol    = "udp"
      cidr_blocks = var.fortigate_management_cidr
    }
  }

  # IPsec NAT-T
  dynamic "ingress" {
    for_each = length(var.fortigate_management_cidr) > 0 ? [1] : []
    content {
      description = "IPsec NAT traversal"
      from_port   = 4500
      to_port     = 4500
      protocol    = "udp"
      cidr_blocks = var.fortigate_management_cidr
    }
  }

  # IPsec ESP (Protocol 50)
  dynamic "ingress" {
    for_each = length(var.fortigate_management_cidr) > 0 ? [1] : []
    content {
      description = "IPsec ESP"
      from_port   = 0
      to_port     = 0
      protocol    = "50"
      cidr_blocks = var.fortigate_management_cidr
    }
  }

  # IPsec AH (Protocol 51)
  dynamic "ingress" {
    for_each = length(var.fortigate_management_cidr) > 0 ? [1] : []
    content {
      description = "IPsec AH"
      from_port   = 0
      to_port     = 0
      protocol    = "51"
      cidr_blocks = var.fortigate_management_cidr
    }
  }

  # IKEv2 (TCP 10000)
  dynamic "ingress" {
    for_each = length(var.fortigate_management_cidr) > 0 ? [1] : []
    content {
      description = "IKEv2 (some implementations)"
      from_port   = 10000
      to_port     = 10000
      protocol    = "tcp"
      cidr_blocks = var.fortigate_management_cidr
    }
  }

  # Syslog
  dynamic "ingress" {
    for_each = length(var.fortigate_management_cidr) > 0 ? [1] : []
    content {
      description = "Syslog"
      from_port   = 514
      to_port     = 514
      protocol    = "udp"
      cidr_blocks = var.fortigate_management_cidr
    }
  }

  # Allow all egress
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cp}-${var.env}-fortigate-management-sg"
  }
}

# Delete existing CloudWatch log group if it exists from previous deployment
resource "null_resource" "delete_existing_lambda_log_group" {
  provisioner "local-exec" {
    command = <<-EOT
      aws logs delete-log-group \
        --log-group-name /aws/lambda/asg-fgt_byol_asg_fgt-asg-lambda \
        --region ${var.aws_region} 2>/dev/null || true
    EOT
  }

  triggers = {
    # Always run before module deployment
    always_run = timestamp()
  }
}

# Conditional ASG configurations based on license model
locals {
  # Common configuration for BYOL ASG
  byol_asg_config = {
    fgt_byol_asg = {
      fmg_integration = var.enable_fortimanager_integration ? {
        ip           = var.fortimanager_ip
        sn           = var.fortimanager_sn
        primary_only = true
        fgt_lic_mgmt = "module"
        vrf_select   = 1
      } : null
      primary_scalein_protection = var.primary_scalein_protection
      extra_network_interfaces = !var.enable_dedicated_management_vpc && !var.enable_dedicated_management_eni ? {} : {
        "dedicated_port" = {
          device_index     = local.management_device_index
          enable_public_ip = true
          subnet = [
            {
              id        = var.enable_dedicated_management_vpc ? data.aws_subnet.management_public_subnet_az1[0].id : data.aws_subnet.inspection_management_subnet_az1[0].id
              zone_name = local.availability_zone_1
            },
            {
              id        = var.enable_dedicated_management_vpc ? data.aws_subnet.management_public_subnet_az2[0].id : data.aws_subnet.inspection_management_subnet_az2[0].id
              zone_name = local.availability_zone_2
            }
          ]
          security_groups = [
            {
              id = aws_security_group.management-vpc-sg[0].id
            }
          ]
        }
      }
      template_name               = "fgt_asg_template"
      fgt_version                 = var.fortios_version
      license_type                = "byol"
      instance_type               = var.fgt_instance_type
      fgt_password                = var.fortigate_asg_password
      keypair_name                = var.keypair
      lic_folder_path             = var.asg_license_directory
      fortiflex_username          = var.fortiflex_username
      fortiflex_password          = var.fortiflex_password
      fortiflex_sn_list           = var.fortiflex_sn_list
      fortiflex_configid_list     = var.fortiflex_configid_list
      enable_fgt_system_autoscale = true
      intf_security_group = {
        login_port    = "secgrp1"
        internal_port = "secgrp1"
      }
      user_conf_file_path           = local.fgt_config_file
      asg_max_size                  = var.asg_byol_asg_max_size
      asg_min_size                  = var.asg_byol_asg_min_size
      asg_desired_capacity          = var.asg_byol_asg_desired_size
      asg_health_check_grace_period = var.asg_health_check_grace_period
      create_dynamodb_table         = true
      dynamodb_table_name           = "fgt_asg_track_table"
      # Scale policies for BYOL-only mode
      scale_policies = var.autoscale_license_model == "byol" ? {
        scale_out = {
          policy_type        = "SimpleScaling"
          adjustment_type    = "ChangeInCapacity"
          cooldown           = 60
          scaling_adjustment = 1
        }
        scale_in = {
          policy_type        = "SimpleScaling"
          adjustment_type    = "ChangeInCapacity"
          cooldown           = 60
          scaling_adjustment = -1
        }
      } : {}
    }
  }

  # Common configuration for On-Demand ASG
  ondemand_asg_config = {
    fgt_on_demand_asg = {
      fmg_integration = var.enable_fortimanager_integration ? {
        ip           = var.fortimanager_ip
        sn           = var.fortimanager_sn
        primary_only = true
        fgt_lic_mgmt = "module"
        vrf_select   = var.fortimanager_vrf_select
      } : null
      primary_scalein_protection = var.primary_scalein_protection
      extra_network_interfaces = !var.enable_dedicated_management_vpc && !var.enable_dedicated_management_eni ? {} : {
        "dedicated_port" = {
          device_index     = local.management_device_index
          enable_public_ip = true
          subnet = [
            {
              id        = var.enable_dedicated_management_vpc ? data.aws_subnet.management_public_subnet_az1[0].id : data.aws_subnet.inspection_management_subnet_az1[0].id
              zone_name = local.availability_zone_1
            },
            {
              id        = var.enable_dedicated_management_vpc ? data.aws_subnet.management_public_subnet_az2[0].id : data.aws_subnet.inspection_management_subnet_az2[0].id
              zone_name = local.availability_zone_2
            }
          ]
          security_groups = [
            {
              id = aws_security_group.management-vpc-sg[0].id
            }
          ]
        }
      }
      template_name               = "fgt_asg_template_on_demand"
      fgt_version                 = var.fortios_version
      license_type                = "on_demand"
      instance_type               = var.fgt_instance_type
      fgt_password                = var.fortigate_asg_password
      keypair_name                = var.keypair
      enable_fgt_system_autoscale = true
      intf_security_group = {
        login_port    = "secgrp1"
        internal_port = "secgrp1"
      }
      user_conf_file_path           = local.fgt_config_file
      asg_max_size                  = var.asg_ondemand_asg_max_size
      asg_min_size                  = var.asg_ondemand_asg_min_size
      asg_desired_capacity          = var.asg_ondemand_asg_desired_size
      asg_health_check_grace_period = var.asg_health_check_grace_period
      # On-demand only creates DynamoDB table when BYOL ASG doesn't exist
      create_dynamodb_table = var.autoscale_license_model == "on_demand"
      dynamodb_table_name   = "fgt_asg_track_table"
      scale_policies = {
        scale_out = {
          policy_type        = "SimpleScaling"
          adjustment_type    = "ChangeInCapacity"
          cooldown           = 60
          scaling_adjustment = 1
        }
        scale_in = {
          policy_type        = "SimpleScaling"
          adjustment_type    = "ChangeInCapacity"
          cooldown           = 60
          scaling_adjustment = -1
        }
      }
    }
  }

  # Build ASGs map based on license model
  # hybrid: both BYOL and On-Demand
  # byol: only BYOL
  # on_demand: only On-Demand
  asgs = merge(
    var.autoscale_license_model != "on_demand" ? local.byol_asg_config : {},
    var.autoscale_license_model != "byol" ? local.ondemand_asg_config : {}
  )

  # CloudWatch alarms based on license model
  # Determines which ASG to monitor and which ASG to scale
  monitor_asg_name = var.autoscale_license_model != "on_demand" ? "fgt_byol_asg" : "fgt_on_demand_asg"
  scale_asg_name   = var.autoscale_license_model == "hybrid" ? "fgt_on_demand_asg" : local.monitor_asg_name

  # Base alarms - always present
  base_cloudwatch_alarms = {
    cpu_scale_out = {
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 2
      metric_name         = "CPUUtilization"
      namespace           = "AWS/EC2"
      period              = 120
      statistic           = "Average"
      threshold           = var.asg_scale_out_threshold
      dimensions = {
        AutoScalingGroupName = local.monitor_asg_name
      }
      alarm_description   = "Scale out when CPU >= ${var.asg_scale_out_threshold}%"
      datapoints_to_alarm = 1
      alarm_asg_policies = {
        policy_name_map = {
          (local.scale_asg_name) = ["scale_out"]
        }
      }
    }
    cpu_scale_in = {
      comparison_operator = "LessThanThreshold"
      evaluation_periods  = 2
      metric_name         = "CPUUtilization"
      namespace           = "AWS/EC2"
      period              = 120
      statistic           = "Average"
      threshold           = var.asg_scale_in_threshold
      dimensions = {
        AutoScalingGroupName = local.monitor_asg_name
      }
      alarm_description   = "Scale in when CPU < ${var.asg_scale_in_threshold}%"
      datapoints_to_alarm = 1
      alarm_asg_policies = {
        policy_name_map = {
          (local.scale_asg_name) = ["scale_in"]
        }
      }
    }
  }

  # Additional alarms for hybrid mode - On-Demand self-scaling
  hybrid_cloudwatch_alarms = var.autoscale_license_model == "hybrid" ? {
    ondemand_cpu_scale_out = {
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 2
      metric_name         = "CPUUtilization"
      namespace           = "AWS/EC2"
      period              = 120
      statistic           = "Average"
      threshold           = var.asg_scale_out_threshold
      dimensions = {
        AutoScalingGroupName = "fgt_on_demand_asg"
      }
      alarm_description   = "On-demand self-scale out when CPU >= ${var.asg_scale_out_threshold}%"
      datapoints_to_alarm = 1
      alarm_asg_policies = {
        policy_name_map = {
          "fgt_on_demand_asg" = ["scale_out"]
        }
      }
    }
    ondemand_cpu_scale_in = {
      comparison_operator = "LessThanThreshold"
      evaluation_periods  = 2
      metric_name         = "CPUUtilization"
      namespace           = "AWS/EC2"
      period              = 120
      statistic           = "Average"
      threshold           = var.asg_scale_in_threshold
      dimensions = {
        AutoScalingGroupName = "fgt_on_demand_asg"
      }
      alarm_description   = "On-demand self-scale in when CPU < ${var.asg_scale_in_threshold}%"
      datapoints_to_alarm = 1
      alarm_asg_policies = {
        policy_name_map = {
          "fgt_on_demand_asg" = ["scale_in"]
        }
      }
    }
  } : {}

  # Merged CloudWatch alarms
  cloudwatch_alarms = merge(local.base_cloudwatch_alarms, local.hybrid_cloudwatch_alarms)
}

module "spk_tgw_gwlb_asg_fgt_igw" {
  #source = "git::https://github.com/fortinetdev/terraform-aws-cloud-modules.git//examples/spk_tgw_gwlb_asg_fgt_igw"
  #source = "/Users/mwooten/github/40netse/terraform-aws-cloud-modules//examples/spk_tgw_gwlb_asg_fgt_igw"
   source = "/Users/mwooten/github/AWSTerraformModules//examples/spk_tgw_gwlb_asg_fgt_igw"

  ## Note: Please go through all arguments in this file and replace the content with your configuration! This file is just an example.
  ## "<YOUR-OWN-VALUE>" are parameters that you need to specify your own value.

  ## Root config
  region     = var.aws_region

  module_prefix = var.asg_module_prefix
  existing_security_vpc = {
    id = data.aws_vpc.inspection_vpc.id
  }
  existing_igw = {
    id = data.aws_internet_gateway.inspection_igw.id
  }
  existing_tgw = {
    id = data.aws_ec2_transit_gateway.existing_tgw.id
  }
  existing_subnets = {
    fgt_login_az1 = {
      id = data.aws_subnet.inspection_public_subnet_az1.id
      availability_zone = local.availability_zone_1
    },
    fgt_login_az2 = {
      id = data.aws_subnet.inspection_public_subnet_az2.id
      availability_zone = local.availability_zone_2
    },
    gwlbe_az1 = {
      id = data.aws_subnet.inspection_gwlbe_subnet_az1.id
      availability_zone = local.availability_zone_1
    },
    gwlbe_az2 = {
      id = data.aws_subnet.inspection_gwlbe_subnet_az2.id
      availability_zone = local.availability_zone_2
    },
    fgt_internal_az1 = {
      id = data.aws_subnet.inspection_private_subnet_az1.id
      availability_zone = local.availability_zone_1
    },
    fgt_internal_az2 = {
      id = data.aws_subnet.inspection_private_subnet_az2.id
      availability_zone = local.availability_zone_2
    }
  }

  ## VPC
  security_groups = {
    secgrp1 = {
      description = "Security group by Terraform"
      ingress = {
        all_traffic = {
          from_port   = "0"
          to_port     = "0"
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
      egress = {
        all_traffic = {
          from_port   = "0"
          to_port     = "0"
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }
    management_secgrp1 = {
      description = "Security group by Terraform for dedicated management port"
      ingress = {
        all_traffic = {
          from_port = "0"
          to_port   = "0"
          protocol  = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
      egress = {
        all_traffic = {
          from_port = "0"
          to_port   = "0"
          protocol  = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }
  }

  vpc_cidr_block     = local.inspection_vpc_cidr
# spoke_cidr_list    = [var.vpc_cidr_east, var.vpc_cidr_west]
  spoke_cidr_list    = [ ]
  availability_zones = [local.availability_zone_1, local.availability_zone_2]

  ## Transit Gateway
  tgw_name        = "${var.cp}-${var.env}-tgw"
  tgw_description = "tgw for fortigate autoscale group"

  ## Auto scale group
  # ASGs are created conditionally based on autoscale_license_model variable:
  # - hybrid: Both BYOL (baseline) and On-Demand (burst) ASGs
  # - byol: Only BYOL ASG
  # - on_demand: Only On-Demand ASG
  fgt_intf_mode            = var.firewall_policy_mode
  fgt_access_internet_mode = local.access_internet_mode
  asgs                     = local.asgs

  ## Cloudwatch Alarm
  # Alarms use generic names (cpu_scale_out, cpu_scale_in) with configurable thresholds
  # In hybrid mode, BYOL ASG is monitored and On-Demand ASG is scaled
  cloudwatch_alarms = local.cloudwatch_alarms

  ## Gateway Load Balancer
  enable_cross_zone_load_balancing = var.allow_cross_zone_load_balancing
  gwlb_health_check = {
      enabled             = true
      healthy_threshold   = var.gwlb_healthy_threshold
      interval            = var.gwlb_health_check_interval
      port                = var.gwlb_health_check_port
      protocol            = var.gwlb_health_check_protocol
      timeout             = var.gwlb_health_check_timeout
      unhealthy_threshold = var.gwlb_unhealthy_threshold
  }
  ## Spoke VPC - Distributed Inspection
  enable_east_west_inspection = true
  # Distributed inspection: GWLB endpoints in spoke VPCs (discovered by tag pattern)
  # When enable_distributed_inspection = true, the module creates GWLB endpoints
  # in discovered distributed VPCs and configures bump-in-the-wire inspection
  spk_vpc = local.distributed_spk_vpc

  ## Tag
  general_tags = {
    "purpose" = "ASG_TEST"
  }
}

