#############
# VARIABLES #
#############

variable "region" {
  description = "AWS Region"
  default     = "eu-west-1" # Ireland
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

variable "count" {
  default = {
    "master"  = 1 
    "worker"  = 1
    "gateway" = 1
  }
}

variable "key_name" {
  description = "key-pairs sotred in AWS"
  default     = "terraform"
}
