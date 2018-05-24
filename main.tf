provider "aws" {
  region = "eu-west-1"
}

resource "aws_key_pair" "terraform" {
  key_name_prefix = "terraform-"
  public_key      = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0dFDv4t1IAXyawNCgu0OC0JpfqA8Pza4/FalTiZqs3zi3gTHYyWUqgfujFkFz9NjUWs9bYYhbdiiyIRQclG2Wm14fjQT4Kug3zxzitS5lR+/aL7i8s7QvEw8BOngINDvI+GHoM369Jku98YWPeXF9xiy+dPH2ZA3dMhR4ub+tXZvT/Dgiy3TsJkcS+xFGQa+haD/twy7jSxBBeaGuhRsK5u/WPF/4WisBcjAkK75yCphgWSeB+t/kZIWbpSABtVXbpnrCkVEeS3kIDHS+1Xbn3J96kSfxmYm6gb7zCpuQqTapHQ98GytwBEn2bdTNWfPH6T1RyKJh75UwfAIZZ8Bh miguel@PORTROBERT135"
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


# Por defecto el security group que creamos no permite ningún tipo de tráfico
resource "aws_security_group" "ssh" {
  name        = "main"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "Enable SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow PING from the outside"
    from_port   = "-1"
    to_port     = "-1"
    protocol    = "ICMP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow ALL inbound traffic within the cluster"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${aws_subnet.private.cidr_block}"]
  }

  egress {
    description = "Allow ALL outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # ALL protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "gw" {
  ami                          = "ami-895e69f0"
  instance_type                = "t2.micro"
  key_name                     = "${aws_key_pair.terraform.key_name}"
  #associate_public_ip_address = "true"          # Asocia una IP pública a la instancia

  # FIXME subnet_id                    = "${aws_subnet.public.id}"
  subnet_id               = "${aws_subnet.private.id}"
  vpc_security_group_ids       = ["${aws_security_group.ssh.id}"]

  user_data=<<-EOF
  nohup python -m SimpleHTTPServer 8080 &
  EOF

  tags {
    Name = "Gateway"
  }
}

resource "aws_instance" "master" {
  ami                     = "ami-895e69f0"
  instance_type           = "t2.micro"
  key_name                = "${aws_key_pair.terraform.key_name}"

  subnet_id               = "${aws_subnet.private.id}"
  #vpc_security_group_ids = ["${aws_security_group.ssh.id}"]

  tags {
    Name = "Master"
  }
}

output "gw_dns" {
  value = "${aws_instance.gw.public_dns}"
}

output "master_dns" {
  value = "${aws_instance.master.public_dns}"
}
