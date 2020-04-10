locals {
  env="${terraform.workspace}"
  
  aws_vpc = {
    "default"="prod"
    "dev"="dev"
    "homol"="homol"
  }
  aws_subnet = {
    "default"="prod"
    "dev"="dev"
    "homol"="homol"
  }
  aws_internet_gateway = {
    "default"="prod"
    "dev"="dev"
    "homol"="homol"
  }
  
  project = {
    "default"="fiap-lab-prod"
    "dev"="fiap-lab-dev"
    "homol"="fiap-lab-homol"
  }

  name_aws_vpc="${lookup(local.aws_vpc,local.env)}"
  name_aws_subnet="${lookup(local.aws_subnet,local.env)}"
  name_aws_internet_gateway="${lookup(local.aws_internet_gateway,local.env)}"
  name_project="${lookup(local.project,local.env)}"
}


resource "aws_vpc" "vpc_created" {
  cidr_block         = "${var.vpc_cidr}"
  enable_dns_support = "true"
  enable_dns_hostnames = "true"  

  tags = {
    Name = "${local.name_project}"
    env  = "${local.name_aws_vpc}"
  }
}

resource "aws_subnet" "public_igw" {
  count                   = "${length(data.aws_availability_zones.available.names)}"
  vpc_id                  = "${aws_vpc.vpc_created.id}"
  cidr_block              = "${cidrsubnet("${var.vpc_cidr}", "${var.subnet_escale}", count.index+1)}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"

  tags = {
    Name = "${local.name_project}_public_igw_${data.aws_availability_zones.available.names[count.index]}"
    Tier = "Public"
    env  = "${local.name_aws_subnet}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc_created.id}"

  tags = {
    Name = "igw-${local.name_project}"
    env  = "${local.name_aws_internet_gateway}"
  }
}
