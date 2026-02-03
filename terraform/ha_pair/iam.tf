#====================================================================================================
# IAM ROLE AND POLICY FOR FORTIGATE HA FAILOVER
#====================================================================================================

# IAM Role for FortiGate instances
resource "aws_iam_role" "fortigate_ha_role" {
  name = "${var.cp}-${var.env}-fortigate-ha-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-ha-role"
    Environment = var.env
    Terraform   = "true"
  }
}

# IAM Policy for FortiGate HA failover operations
resource "aws_iam_role_policy" "fortigate_ha_policy" {
  name = "${var.cp}-${var.env}-fortigate-ha-policy"
  role = aws_iam_role.fortigate_ha_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BootStrapFromS3"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "*"
      },
      {
        Sid    = "SDNConnectorFortiView"
        Effect = "Allow"
        Action = [
          "ec2:DescribeRegions",
          "eks:DescribeCluster",
          "eks:ListClusters",
          "inspector:DescribeFindings",
          "inspector:ListFindings"
        ]
        Resource = "*"
      },
      {
        Sid    = "HAGatherInfo"
        Effect = "Allow"
        Action = [
          "ec2:DescribeAddresses",
          "ec2:DescribeInstances",
          "ec2:DescribeRouteTables",
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      },
      {
        Sid    = "FailoverEIPs"
        Effect = "Allow"
        Action = [
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress"
        ]
        Resource = "*"
      },
      {
        Sid    = "FailoverVPCroutes"
        Effect = "Allow"
        Action = [
          "ec2:ReplaceRoute",
          "ec2:CreateRoute",
          "ec2:DeleteRoute"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "fortigate_ha_profile" {
  name = "${var.cp}-${var.env}-fortigate-ha-profile"
  role = aws_iam_role.fortigate_ha_role.name

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-ha-profile"
    Environment = var.env
    Terraform   = "true"
  }
}
