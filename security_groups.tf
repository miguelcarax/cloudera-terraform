###################
# SECURITY GROUPS # 
###################

# TERRAFORM : No ingress or egress traffic is allowed by default in custom security gruops
# AWS       : Only security group members ingress traffic is allowed, and all egress traffic as well
#
# ALLOW ALL TRAFFIC (ALL PROTOCOLS) IN TERRAFORM
#    from_port   = 0
#    to_port     = 0
#    protocol    = "-1"
#    cidr_blocks = ["0.0.0.0/0"]

resource "aws_security_group" "internal" {
  name        = "internal"
  vpc_id      = "${aws_vpc.main.id}"
  description = "ALL traffic within the cluster is allowed"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = "true" # The security group members 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound traffic to internet
  }

  tags {
    Name = "Internal"
  }
}

# No traffic allowed by default
resource "aws_security_group" "external" {
  name   = "external"
  vpc_id = "${aws_vpc.main.id}"

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
    from_port   = "-1" # No port because ICMP is a layer 3 protocol
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
    Name = "External"
  }
}
