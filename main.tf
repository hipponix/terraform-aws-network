# ----------------------------------------------------------------------------
# Data
# ----------------------------------------------------------------------------
data "aws_default_tags" "this" {}

# ----------------------------------------------------------------------------
# Vpc
# ----------------------------------------------------------------------------
resource "aws_vpc" "this" {
  instance_tenancy     = "default"
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "${local.prefix}-vpc"
    CreatedAt = formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())
  }

  lifecycle {
    ignore_changes = [tags["CreatedAt"]]
  }
}

# ----------------------------------------------------------------------------
# Internet Gateway
# ----------------------------------------------------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name      = "${local.prefix}-eks-ig"
    CreatedAt = formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())
  }

  depends_on = [aws_vpc.this]

  lifecycle {
    ignore_changes = [tags["CreatedAt"]]
  }
}

# ----------------------------------------------------------------------------
# Elastic IP
# ----------------------------------------------------------------------------
resource "aws_eip" "this" {
  domain = "vpc"

  tags = {
    Name      = "${local.prefix}-eks-ng"
    CreatedAt = formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())
  }

  lifecycle {
    ignore_changes = [tags["CreatedAt"]]
  }
}

# ----------------------------------------------------------------------------
# Nat Gateway
# ----------------------------------------------------------------------------
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name      = "${local.prefix}-eks-ng"
    CreatedAt = formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())
  }

  depends_on = [aws_vpc.this, aws_eip.this]

  lifecycle {
    ignore_changes = [tags["CreatedAt"]]
  }
}

# ----------------------------------------------------------------------------
# Subnets
# ----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name      = "${local.prefix}-eks-private-${element(var.availability_zones, count.index)}"
    CreatedAt = formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())
  }

  depends_on = [aws_vpc.this]

  lifecycle {
    ignore_changes = [tags["CreatedAt"]]
  }
}

resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = element(var.private_subnet_cidrs, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = false

  tags = {
    Name      = "${local.prefix}-eks-private-${element(var.availability_zones, count.index)}"
    CreatedAt = formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())
  }

  depends_on = [aws_vpc.this]

  lifecycle {
    ignore_changes = [tags["CreatedAt"]]
  }
}

# ----------------------------------------------------------------------------
# Routing Tables
# ----------------------------------------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name      = "${local.prefix}-eks-private-rt"
    CreatedAt = formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())
  }

  # private
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  depends_on = [aws_vpc.this]

  lifecycle {
    ignore_changes = [tags["CreatedAt"]]
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name      = "${local.prefix}-eks-public-rt"
    CreatedAt = formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())
  }

  # public
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  depends_on = [aws_vpc.this]

  lifecycle {
    ignore_changes = [tags["CreatedAt"]]
  }
}
# ----------------------------------------------------------------------------
# Routing Associations
# ----------------------------------------------------------------------------
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
