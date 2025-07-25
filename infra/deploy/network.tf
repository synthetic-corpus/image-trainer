##########################
# Network infrastructure #
##########################

resource "aws_vpc" "main" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

######################################
# Internet gateway for public access #
######################################

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id # this is the ARN of the VPC we just created

  tags = {
    Name = "${local.prefix}-main"
  }
}

#################################################
# Public Subnets (connects to Internet Gateway) #
#################################################

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_region.current.name}a"

  tags = {
    Name = "${local.prefix}-public-subnet-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_region.current.name}b"

  tags = {
    Name = "${local.prefix}-public-subnet-b"
  }
}

##############################
# Routes for A and B subnets #
##############################

resource "aws_route_table" "public_a" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.prefix}-public-a-routes"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id      # again the ARN
  route_table_id = aws_route_table.public_a.id # if it's .id you can probably guess it's an ARN
}

resource "aws_route" "public_internet_access_a" {
  route_table_id         = aws_route_table.public_a.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table" "public_b" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.prefix}-public-b-routes"
  }
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id      # again the ARN
  route_table_id = aws_route_table.public_b.id # if it's .id you can probably guess it's an ARN
}

resource "aws_route" "public_internet_access_b" {
  route_table_id         = aws_route_table.public_b.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

########################################################
# Private  Subnets (No connection to Internet Gateway) #
########################################################

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.10.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_region.current.name}a"

  tags = {
    Name = "${local.prefix}-private-subnet-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.11.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_region.current.name}b"

  tags = {
    Name = "${local.prefix}-private-subnet-b"
  }
}

#####################################################
# Endpoints and their corresponding security groups #
#####################################################

resource "aws_security_group" "endpoint_access" {
  description = "Security group for end point access"
  name        = "${local.prefix}-endpoint-access"
  vpc_id      = aws_vpc.main.id

  # rules for ingress to endpoints.
  ingress {
    cidr_blocks = [aws_vpc.main.cidr_block] # only my vpc, not the entire internet
    from_port   = 443
    to_port     = 443 # ssl port
    protocol    = "tcp"
  }
}

resource "aws_vpc_endpoint" "ecr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  security_group_ids = [aws_security_group.endpoint_access.id]

  tags = {
    Name = "${local.prefix}-ecr-endpoint"
  }
}

resource "aws_vpc_endpoint" "dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  security_group_ids = [aws_security_group.endpoint_access.id]

  tags = {
    Name = "${local.prefix}-dkr-endpoint"
  }
}

resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  security_group_ids = [aws_security_group.endpoint_access.id]

  tags = {
    Name = "${local.prefix}-cwlogs-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  security_group_ids = [aws_security_group.endpoint_access.id]

  tags = {
    Name = "${local.prefix}-ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    aws_vpc.main.default_route_table_id
  ]

  tags = {
    Name = "${local.prefix}-s3-endpoint"
  }
}

# --- New Private Subnet with Dedicated NAT Gateway ---

resource "aws_subnet" "private_nat" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.12.0/24" # next available /24
  map_public_ip_on_launch = false
  availability_zone       = "us-west-2a"
  tags = {
    Name = "${local.prefix}-private-subnet-nat"
  }
}

resource "aws_eip" "nat_private" {
  domain = "vpc"
  tags = {
    Name = "${local.prefix}-nat-eip-private-subnet"
  }
}

resource "aws_nat_gateway" "private_nat" {
  allocation_id = aws_eip.nat_private.id
  subnet_id     = aws_subnet.public_a.id # Place NAT Gateway in public subnet A
  tags = {
    Name = "${local.prefix}-nat-gateway-private-subnet"
  }
}

resource "aws_route_table" "private_nat" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.prefix}-private-nat-route-table"
  }
}

resource "aws_route" "private_nat_internet" {
  route_table_id         = aws_route_table.private_nat.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.private_nat.id
}

resource "aws_route_table_association" "private_nat" {
  subnet_id      = aws_subnet.private_nat.id
  route_table_id = aws_route_table.private_nat.id
}

# --- New Network ACL for Private NAT Subnet ---
resource "aws_network_acl" "private_nat_nacl" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.private_nat.id]

  tags = {
    Name = "${local.prefix}-private-nat-nacl"
  }
}

# Inbound rules for Private NAT NACL
resource "aws_network_acl_rule" "private_nat_inbound_ssh_vpc" {
  network_acl_id = aws_network_acl.private_nat_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.main.cidr_block
  from_port      = 22
  to_port        = 22
  depends_on = [
    aws_network_acl.private_nat_nacl
  ]
}

resource "aws_network_acl_rule" "private_nat_inbound_ssh_ec2_connect" {
  network_acl_id = aws_network_acl.private_nat_nacl.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0" # For EC2 Instance Connect service
  from_port      = 22
  to_port        = 22
  depends_on = [
    aws_network_acl.private_nat_nacl
  ]
}

resource "aws_network_acl_rule" "private_nat_inbound_ephemeral" {
  network_acl_id = aws_network_acl.private_nat_nacl.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
  depends_on = [
    aws_network_acl.private_nat_nacl
  ]
}

# Outbound rules for Private NAT NACL
resource "aws_network_acl_rule" "private_nat_outbound_http_imds" {
  network_acl_id = aws_network_acl.private_nat_nacl.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "169.254.169.254/32"
  from_port      = 80
  to_port        = 80
  depends_on = [
    aws_network_acl.private_nat_nacl
  ]
}

resource "aws_network_acl_rule" "private_nat_outbound_all" {
  network_acl_id = aws_network_acl.private_nat_nacl.id
  rule_number    = 110
  egress         = true
  protocol       = "-1" # All protocols
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
  depends_on = [
    aws_network_acl.private_nat_nacl
  ]
}

resource "aws_network_acl_association" "private_nat" {
  subnet_id      = aws_subnet.private_nat.id
  network_acl_id = aws_network_acl.private_nat_nacl.id
}