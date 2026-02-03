# Verify the existing VPC resources using a bash script and AWS CLI commands. My credentials should be in the env.

## Read terraform/existing_vpc_resources/terraform.tfvars

## Go through the following checks and print a label and passed/failed for each check

## Management VPC Checks

0. get the regions and each availability zone the template should deploy in. 
1. get enable_management_vpc
2. if enable_management_vpc is true, get the vpc_cidr_management
3. if enable_management_vpc is false, skip to step 5
4. verify the management vpc items:
    1. vpc exists in correct region and across the correct availability zones
    2. vpc cidr matches vpc_cidr_management
    3. subnets exist in correct availability zones with correct cidrs based on subnet_bits variable
    4. route tables exist and are associated with correct subnets
    5. internet gateway exists and is attached to the vpc
    6. if enable_management_tgw_attachment is true, verify the tgw attachment exists and is associated with the correct tgw id and vpc id
    7.  verify correct settings within the subnet parameters 
        1. public subnets in each az: 
            + in az1 and az2 have a default route (0.0.0.0/0) to the internet gateway
            + a local route to the vpc cidr block
            + if enable_tgw_attachment is true, verify a route to the spoke cidrs point to the tgw attachment
            + a less specific route to inspection vpc cidr pointing to the TGW attachment
       2. verify ec2 instances exist:
           1. if enable_jump_box is true, verify: 
               + ec2 instance exists in the public subnet of az1
               + if enable_jump_box_public_ip is true, verify the ec2 instance has a public ip address assigned
               + if enable_jump_box_public_ip is false, verify the ec2 instance does not have a public ip address assigned
               + jump_box private ip host address matches jump_box_host_ip variable
           2. if enable_fortimanager is true, verify:
               + ec2 instance exists in the private subnet of az1
               + if fortimanager_assign_public_ip is true, verify the ec2 instance has a public ip address assigned
               + if fortimanager_assign_public_ip is false, verify the ec2 instance does not have a public ip address assigned
               + fortimanager private ip host address matches fortimanager_host_ip variable
               + 
## Inspection VPC Checks

5. verify the inspection_vpc items:
    1. vpc exists in correct region and across the correct availability zones
    2. vpc cidr matches vpc_cidr_inspection
    3. verify the following subnets exist in correct availability zones with correct cidrs based on subnet_bits variable:
        1. public subnets in az1 and az2
        2. private subnets in az1 and az2
        3. tgw subnets in az1 and az2
        4. gwlb subnets in az1 and az2
        5. if access_internet_mode is "nat_gw", verify nat gateway subnets exist in az1 and az2
        6. if enable_management_vpc is true, create_management_subnet_in_inspection_vpc cannot be true, skip this step
       7.  if create_management_subnet_in_inspection_vpc is true, verify management subnets exist in az1 and az2
    4. route tables exist and are associated with correct subnets:
        1. public route table exists and is associated with public subnets in both azs
        2. private route tables exist (one per az) and are associated with private subnets
        3. tgw route table exists and is associated with tgw subnets in both azs
        4. gwlb route table exists and is associated with gwlb subnets in both azs
           + keep in mind, the spk_tgw_gwlb_asg_fgt_igw module in ../autoscale_template will create the route table for the gwlb subnet and name it gwlb. So at this point, no route table or association for that subnet will exist. Always verify that is the case.
    5. internet gateway exists and is attached to the vpc
    6. if enable_tgw_attachment is true, verify:
        + tgw attachment exists and is associated with the correct tgw id and vpc id
        + tgw attachment uses the tgw subnets in both availability zones
        + appliance mode support is enabled on the tgw attachment
    7. verify correct settings within the subnet route tables:
        1. public subnets route table:
            + has a local route to the vpc cidr block
            + default route (0.0.0.0/0) points to internet gateway
        2. private subnets route tables (per az):
            + has a local route to the vpc cidr block
            + if access_internet_mode is "nat_gw" and create_nat_gateway is true, verify default route points to nat gateway in same az
            + if access_internet_mode is "eip", no default route should exist in private subnet route tables
        3. tgw subnets route table:
            + has a local route to the vpc cidr block
            + if enable_tgw_attachment is true, routes may be present for spoke vpc cidrs
        4. gwlb subnets route table:
            + has a local route to the vpc cidr block
    8. if access_internet_mode is "nat_gw" and create_nat_gateway is true, verify:
        + nat gateways exist in each availability zone
        + nat gateways are deployed in nat gateway subnets
        + nat gateways have elastic IPs assigned
    9. if create_tgw_routes_for_existing is true, verify tgw routes exist:
        + route to vpc_cidr_west points to west tgw attachment
        + route to vpc_cidr_east points to east tgw attachment

## East VPC Checks

6. if enable_build_existing_subnets is true, verify the east vpc items:
    1. vpc exists in correct region and across the correct availability zones
    2. vpc cidr matches vpc_cidr_east
    3. verify the following subnets exist in correct availability zones with correct cidrs based on spoke_subnet_bits variable:
        1. public subnets in az1 and az2
        2. tgw subnets in az1 and az2
    4. route tables exist and are associated with correct subnets:
        1. default/main route table is used for all subnets (public and tgw)
    5. verify correct settings within the main route table:
        + has a local route to the vpc cidr block (vpc_cidr_east)
        + default route (0.0.0.0/0) points to transit gateway
        + if enable_build_management_vpc is true, route to vpc_cidr_management points to transit gateway
    6. verify tgw attachment exists:
        + tgw attachment is associated with the correct tgw id and vpc id
        + tgw attachment uses the tgw subnets in both availability zones
        + appliance mode support is enabled on the tgw attachment
    7. verify tgw route table for east vpc exists:
        + tgw route table named "${cp}-${env}-east-tgw-rtb" exists
        + tgw route table is associated with the east tgw attachment
        + if enable_build_management_vpc and enable_management_tgw_attachment are true, verify route to vpc_cidr_management points to management tgw attachment
        + default route (0.0.0.0/0) points to inspection vpc tgw attachment
    8. if enable_linux_spoke_instances is true, verify ec2 instances exist:
        + ec2 instance exists in public subnet of az1 with correct private ip (based on linux_host_ip variable)
        + ec2 instance exists in public subnet of az2 with correct private ip (based on linux_host_ip variable)
        + security group exists for east vpc and is attached to instances
        + if acl is "public", verify instances have public IPs assigned
        + if acl is "private", verify instances do not have public IPs assigned

## West VPC Checks

7. if enable_build_existing_subnets is true, verify the west vpc items:
    1. vpc exists in correct region and across the correct availability zones
    2. vpc cidr matches vpc_cidr_west
    3. verify the following subnets exist in correct availability zones with correct cidrs based on spoke_subnet_bits variable:
        1. public subnets in az1 and az2
        2. tgw subnets in az1 and az2
    4. route tables exist and are associated with correct subnets:
        1. default/main route table is used for all subnets (public and tgw)
    5. verify correct settings within the main route table:
        + has a local route to the vpc cidr block (vpc_cidr_west)
        + default route (0.0.0.0/0) points to transit gateway
        + if enable_build_management_vpc is true, route to vpc_cidr_management points to transit gateway
    6. verify tgw attachment exists:
        + tgw attachment is associated with the correct tgw id and vpc id
        + tgw attachment uses the tgw subnets in both availability zones
        + appliance mode support is enabled on the tgw attachment
    7. verify tgw route table for west vpc exists:
        + tgw route table named "${cp}-${env}-west-tgw-rtb" exists
        + tgw route table is associated with the west tgw attachment
        + if enable_build_management_vpc and enable_management_tgw_attachment are true, verify route to vpc_cidr_management points to management tgw attachment
        + default route (0.0.0.0/0) points to inspection vpc tgw attachment
    8. if enable_linux_spoke_instances is true, verify ec2 instances exist:
        + ec2 instance exists in public subnet of az1 with correct private ip (based on linux_host_ip variable)
        + ec2 instance exists in public subnet of az2 with correct private ip (based on linux_host_ip variable)
        + security group exists for west vpc and is attached to instances
        + if acl is "public", verify instances have public IPs assigned
        + if acl is "private", verify instances do not have public IPs assigned
