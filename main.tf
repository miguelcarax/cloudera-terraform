#############
# TERRAFORM #
#############

provider "aws" {
  region = "eu-west-1" # Ireland
}


#############
# VARIABLES #
#############

variable "key_name" {
  description = "Nombre de la pareja de claves definida en Amazon"
  default     = "terraform"
}

variable "ami" {
  description = "Amazon Linux AMI 2018.03.0 (HVM), SSD Volume Type"
  default    = "ami-ca0135b3" # eu-west-1 - Irlanda
}

variable "instance_type" {
  description = "Free tier instance"
  default     = "t2.micro"
}

variable "domain" {
  description = "Cluster network domain"
  default     = "caf.net"
}

variable "hostname" {
  type        = "map"
  default     = {
    "master"  = "cdh-master"
    "worker"  = "cdh-worker"
    "gateway" = "cdh-gateway"
  }
}

variable "count" {
  type    = "map"
  default = {
    "master"  = 1 
    "worker"  = 1
    "gateway" = 1
  }
}


##############
# NETWORKING # 
##############

resource "aws_internet_gateway" "gateway" {
  vpc_id  = "${aws_vpc.main.id}"

  tags {
    Name = "Internet gateway"
  }
}

# TODO
/*resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = ""
  subnet_id     = ""
}*/

resource "aws_route53_zone" "main" {
  name = "${var.domain}"

  tags {
    Environment = "test"
  }
}

resource "aws_route53_record" "master" {
  zone_id = "${aws_route53_zone.main.id}"
  name    = "${lookup(var.hostname, "master")}${count.index}.${var.domain}"
  type    = "A"
  ttl     = 300
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

# Default "local" routing it's implicit
resource "aws_route_table" "main" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gateway.id}"
  }

  tags {
    Name = "Main"
  }
}

# Define la ruta de tablas "main" como la principal
resource "aws_main_route_table_association" "main" {
  vpc_id         = "${aws_vpc.main.id}"
  route_table_id = "${aws_route_table.main.id}"
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0" # Internet traffic
    gateway_id = "${aws_internet_gateway.gateway.id}"
  }

  tags {
    Name = "Public"
  }
}

# FIXME Private and public route tables are the same
resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0" # Internet traffic
    gateway_id = "${aws_internet_gateway.gateway.id}"
    # FIXME nat_gateway_id = "${aws_nat_gateway.nat_gateway.id}"
  }

  tags {
    Name = "Private"
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true" # default: true
  enable_dns_hostnames = "true" # Instances receive a hostname, default: false

  tags {
    Name = "main"
  }
}

# FIXME No direct access to private subnet
resource "aws_subnet" "private" {
  cidr_block             = "10.0.0.0/24"
  vpc_id                 = "${aws_vpc.main.id}"
  map_public_ip_on_launch = "true" # Asigna una IP pública a las instancias asociadas

  tags {
    Name = "private"
  }
}

resource "aws_subnet" "public" {
  cidr_block = "10.0.3.0/24"
  vpc_id     = "${aws_vpc.main.id}"
  map_public_ip_on_launch = "true" # Asigna una IP pública a las instancias asociadas

  tags {
    Name = "public"
  }
}

# Asociar la tabla de rutas con la subnet
resource "aws_route_table_association" "private_private" {
  subnet_id      = "${aws_subnet.private.id}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_route_table_association" "public_public" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"
}

###################
# SECURITY GROUPS # 
###################

# Por defecto el security group que crea terraform no permite ningún tipo de tráfico
resource "aws_security_group" "ssh" {
  name        = "main"
  vpc_id      = "${aws_vpc.main.id}"

  # FIXME SECURITY RISK
  ingress {
    description = "Allow ALL traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Enable SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # FIXME
  ingress {
    description = "Allow PING from the outside"
    from_port   = "-1"
    to_port     = "-1"
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # TODO Crear otro security group para within the cluster
  ingress {
    description = "Allow ALL inbound traffic within the cluster"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${aws_subnet.public.cidr_block}", "${aws_subnet.private.cidr_block}"]
  }

  # TODO Crear otro security group para within the cluster
  egress {
    description = "Allow ALL outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # ALL protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#############
# INSTANCES # 
#############

resource "aws_instance" "gateway" {
  ami                          = "${var.ami}"
  instance_type                = "${var.instance_type}"
  #associate_public_ip_address = "true"          # Asocia una IP pública a la instancia

  # FIXME subnet_id            = "${aws_subnet.public.id}"
  key_name                     = "${var.key_name}"
  subnet_id                    = "${aws_subnet.private.id}"
  vpc_security_group_ids       = ["${aws_security_group.ssh.id}"]

  tags {
    Name = "Gateway-${count.index}"
    Role = "Gateway"
  }

  count = "${lookup(var.count, "gateway")}"

}

resource "aws_instance" "master" {
  ami                    = "${var.ami}"
  instance_type          = "${var.instance_type}"

  key_name               = "${var.key_name}"
  subnet_id              = "${aws_subnet.private.id}"
  vpc_security_group_ids = ["${aws_security_group.ssh.id}"]

  tags {
    Name = "Master-${count.index}"
    Role = "Master"
  }

  count = "${lookup(var.count, "master")}"

}

################
# DATA SOURCES #
################

data "aws_instances" "all" { }

data "template_file" "etc_hosts" {
  template = "${file(etc/hosts)}"

  vars {

  }
}


###########
# OUTPUTS #
###########

output "gateway_dns" {
  value = "${aws_instance.gateway.*.public_dns}"
}

output "master_dns" {
  value = "${aws_instance.master.*.public_dns}"
}
