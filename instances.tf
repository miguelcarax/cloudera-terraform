#############
# INSTANCES # 
#############

provider "aws" {
  region = "${var.region}"
}

resource "aws_instance" "gateway" {
  ami                          = "${var.ami}"
  instance_type                = "${var.instance_type}"

  key_name                     = "${var.key_name}"
  subnet_id                    = "${aws_subnet.public.id}"
  vpc_security_group_ids       = ["${aws_security_group.internal.id}", "${aws_security_group.external.id}"]

  tags {
    Name = "Cloudera"
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
    Name = "Cloudera"
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
    Name = "Cloudera"
    Role = "Worker"
  }

  count = "${lookup(var.count, "worker")}"
}
                      
