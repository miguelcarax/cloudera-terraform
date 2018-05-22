provider "aws" 
{
  region = "eu-west-1"
}

resource "aws_instance" "master" 
{
  ami           = "ami-895e69f0"
  instance_type = "t2.micro" 


  count = 3
}
