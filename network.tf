# A VPC fica aqui porque sobrevive ao cluster (ADR-001). Sem NAT Gateway (ADR-002).

resource "aws_vpc" "principal" {
  cidr_block           = var.cidr_vpc
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.prefixo}-vpc" }
}

resource "aws_internet_gateway" "principal" {
  vpc_id = aws_vpc.principal.id
  tags   = { Name = "${var.prefixo}-igw" }
}

resource "aws_subnet" "publicas" {
  for_each = { for indice, az in var.zonas_disponibilidade : az => indice }

  vpc_id                  = aws_vpc.principal.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.cidr_vpc, 4, each.value)
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.prefixo}-publica-${each.key}"
    Tier                     = "publica"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "privadas" {
  for_each = { for indice, az in var.zonas_disponibilidade : az => indice }

  vpc_id            = aws_vpc.principal.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.cidr_vpc, 4, each.value + 8)

  tags = {
    Name                              = "${var.prefixo}-privada-${each.key}"
    Tier                              = "privada"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.principal.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.principal.id
  }

  tags = { Name = "${var.prefixo}-rt-publica" }
}

resource "aws_route_table_association" "publicas" {
  for_each = aws_subnet.publicas

  subnet_id      = each.value.id
  route_table_id = aws_route_table.publica.id
}

# Sem rota default: o tráfego das subnets privadas não sai da VPC.
resource "aws_route_table" "privada" {
  vpc_id = aws_vpc.principal.id
  tags   = { Name = "${var.prefixo}-rt-privada" }
}

resource "aws_route_table_association" "privadas" {
  for_each = aws_subnet.privadas

  subnet_id      = each.value.id
  route_table_id = aws_route_table.privada.id
}
