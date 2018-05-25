#############
# TERRAFORM #
#############

provider "aws" {
  region = "eu-west-1" # Ireland
}

################
# DATA SOURCES #
################



#############
# VARIABLES #
#############

variable "key_name" {
  description = "Nombre de la pareja de claves definida en Amazon"
  default     = "terraform"
}

variable "ami" {
  description = "Amazon Linux AMI 2018.03.0 (HVM), SSD Volume Type"
  default     = "ami-ca0135b3" # eu-west-1 - Irlanda
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
  default = {
    "master"  = "cdh-master"
    "worker"  = "cdh-worker"
    "gateway" = "cdh-gateway"
  }
}

variable "num" {
  default = {
    "master"  = 1 
    "worker"  = 1
    "gateway" = 1
  }
}


##############
# NETWORKING # 
##############

### DNS
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

resource "aws_route53_zone" "main" {
  name = "${var.domain}"

  tags {
    Environment = "test"
  }
}
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


resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true" # default: true
  enable_dns_hostnames = "true" # Instances receive a hostname, default: false

  tags {
    Name = "main"
  }
}

resource "aws_subnet" "private" {
  cidr_block             = "10.0.0.0/24"
  vpc_id                 = "${aws_vpc.main.id}"
  #map_public_ip_on_launch = "true" # Asigna una IP pública a las instancias asociadas

  tags {
    Name = "private"
  }
}

resource "aws_subnet" "public" {
  cidr_block = "10.0.1.0/24"
  vpc_id     = "${aws_vpc.main.id}"
  map_public_ip_on_launch = "true" # Asigna una IP pública a las instancias asociadas

  tags {
    Name = "public"
  }
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

resource "aws_security_group" "internal" {
  name   = "internal"
  vpc_id = "${aws_vpc.main.id}"

  # Default no ingress
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = "true" # The security group itself will be added as a source
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound traffic to internet
  }

  tags {
    Name = "Internal Traffic"
  }
}

# NOT ALLOWED TRAFFIC BY DEFAULT
resource "aws_security_group" "external" {
  name   = "external"
  vpc_id = "${aws_vpc.main.id}"

  /*** FIXME
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ***/

  ingress {
    description = "Allow SSH from the outside"
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "External Traffic"
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
  subnet_id                    = "${aws_subnet.public.id}"
  vpc_security_group_ids       = ["${aws_security_group.internal.id}", "${aws_security_group.external.id}"]

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
  vpc_security_group_ids = ["${aws_security_group.internal.id}"]

  tags {
    Name = "Master-${count.index}"
    Role = "Master"
  }

  count = "${lookup(var.count, "master")}"

}

resource "aws_instance" "worker" {
  ami           = "${var.ami}"
  instance_type = "${var.instance_type}"

  key_name               = "${var.key_name}"
  subnet_id              = "${aws_subnet.private.id}"
  vpc_security_group_ids = ["${aws_security_group.internal.id}"]

  tags {
    Name = "Worker-${count.index}"
    Role = "Worker"
  }

  count = "${lookup(var.count, "worker")}"
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

output "worker_dns" {
  value = "${aws_instance.worker.*.public_dns}"
}
