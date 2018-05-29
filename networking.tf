#########################
###### NETWORKING #######
#########################

############
# NETWORKS #
############

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true" # default: true
  enable_dns_hostnames = "true" # Instances receive a hostname, default: false

  tags {
    Name = "Main"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "10.0.0.0/24"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "Private"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"
  map_public_ip_on_launch = "true" # Assigns public IP

  tags {
    Name = "Public"
  }
}

#######
# DNS #
#######

resource "aws_route53_zone" "main" {
  name = "${var.domain}"

  tags {
    Environment = "Test"
  }
}

resource "aws_route53_record" "master" {
  name    = "${lookup(var.hostname, "master")}${count.index}.${var.domain}"
  type    = "A"
  ttl     = 300
  zone_id = "${aws_route53_zone.main.id}"
  records = ["${element(aws_instance.master.*.private_ip, count.index)}"]

  count = "${lookup(var.count, "master")}"
}

resource "aws_route53_record" "gateway" {
  zone_id = "${aws_route53_zone.main.id}"
  name    = "${lookup(var.hostname, "gateway")}${count.index}.${var.domain}"
  type    = "A"
  ttl     = 300
  records = ["${element(aws_instance.gateway.*.private_ip, count.index)}"]

  count = "${lookup(var.count, "gateway")}"
}

###########
# ROUTING #
###########

resource "aws_internet_gateway" "gateway" {
  vpc_id  = "${aws_vpc.main.id}"

  tags {
    Name = "Internet Gateway"
  }
}

resource "aws_nat_gateway" "gateway" {
  allocation_id = "${aws_eip.cluster.id}"
  subnet_id     = "${aws_subnet.private.id}" # Associated to the private network
  depends_on    = ["aws_internet_gateway.gateway"]

  tags {
    Name = "NAT Gateway"
  }
}

resource "aws_eip" "cluster" {
  vpc        = "true"
  depends_on = ["aws_internet_gateway.gateway"]
}

resource "aws_route_table" "main" {
  vpc_id = "${aws_vpc.main.id}"

  # Local routing within the VPC its implicit
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gateway.id}"
  }

  tags {
    Name = "Main"
  }
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  # Local routing within the VPC its implicit
  route {
    cidr_block = "0.0.0.0/0" 
    gateway_id = "${aws_internet_gateway.gateway.id}"
  }

  tags {
    Name = "Public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.main.id}"

  # Local routing within the VPC its implicit

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.gateway.id}"
  }

  tags {
    Name = "Private"
  }
}

resource "aws_main_route_table_association" "main" {
  vpc_id         = "${aws_vpc.main.id}"
  route_table_id = "${aws_route_table.main.id}"
}

resource "aws_route_table_association" "private_private" {
  subnet_id      = "${aws_subnet.private.id}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_route_table_association" "public_public" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"
}
