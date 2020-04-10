# Specify the provider and access details

provider "aws" {
  region = "${var.aws_region}"
}

data "template_file" "script" {
  template = "${file("${path.module}/script.sh.tpl")}"
  vars = {
    ECR_REGISTRY = "${var.ECR_REGISTRY}"
  }
}

locals {
  env="${terraform.workspace}"
  
  elb = {
    "default"="terraform-example-stack-elb-default"
    "des"="terraform-example-stack-elb-desenv"
    "homol"="terraform-example-stack-elb-homol"
  }
  instances = {
    "default"="nginx-%03d-stack-default"
    "des"="nginx-%03d-stack-desenv"
    "homol"="nginx-%03d-stack-homol"
  }
  security = {
    "default"="allow-ssh-default"
    "des"="allow-ssh-stack-desenv"
    "homol"="allow-ssh-stack-homol"
  }
  aws_iam_role_ecr = {
    "default"="ecr_readOnly_role_default"
    "des"="ecr_readOnly_role_desenv"
    "homol"="ecr_readOnly_role_homol"
  }
  ecr_readOnly_profile = {
    "default"="ecr_readOnly_profile_default"
    "des"="ecr_readOnly_profile_desenv"
    "homol"="ecr_readOnly_profile_homol"
  }
  aws_iam_role_policy = {
    "default"="aws_iam_role_policy_default"
    "des"="aws_iam_role_policy_desenv"
    "homol"="aws_iam_role_policy_homol"
  }
  

  
  name_instance="${lookup(local.instances,local.env)}"
  name_elb="${lookup(local.elb,local.env)}"
  name_security_group="${lookup(local.security,local.env)}"
  name_aws_iam_role_ecr="${lookup(local.aws_iam_role_ecr,local.env)}"
  name_ecr_readOnly_profile="${lookup(local.ecr_readOnly_profile,local.env)}"
  name_aws_iam_role_policy="${lookup(local.aws_iam_role_policy,local.env)}"

}




variable "project" {
  default = "fiap-lab"
}

data "aws_vpc" "vpc" {
  tags = {
    Name = "${var.project}"
  }
}

data "aws_subnet_ids" "all" {
  vpc_id = "${data.aws_vpc.vpc.id}"

  tags = {
    Tier = "Public"
  }
}

data "aws_subnet" "public" {
  for_each = data.aws_subnet_ids.all.ids
  id = "${each.value}"
}

resource "random_shuffle" "random_subnet" {
  input        = [for s in data.aws_subnet.public : s.id]
  result_count = 1
}



resource "aws_elb" "web" {
  name = "${local.name_elb}"

  subnets         = data.aws_subnet_ids.all.ids
  security_groups = ["${aws_security_group.allow-ssh.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 6
  }

  # The instances are registered automatically
  instances = aws_instance.web.*.id
}

resource "aws_instance" "web" {
  instance_type = "t2.micro"
  ami           = "${lookup(var.aws_amis, var.aws_region)}"

  count = 1

  subnet_id              = "${random_shuffle.random_subnet.result[0]}"
  vpc_security_group_ids = ["${aws_security_group.allow-ssh.id}"]
  key_name               = "${var.KEY_NAME}"
  iam_instance_profile   = "${aws_iam_instance_profile.ecr_readOnly_profile.name}"

  provisioner "file" {
    content      = "${data.template_file.script.rendered}"
    destination = "$(pwd)/script.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x $(pwd)/script.sh",
      "sudo bash $(pwd)/script.sh"
    ]
  }

  connection {
    user        = "${var.INSTANCE_USERNAME}"
    private_key = "${file("${var.PATH_TO_KEY}")}"
    host = "${self.public_dns}"
  }

  tags = {
    Name = "${format("${local.name_instance}", count.index + 1)}"
  }
}


resource "aws_security_group" "allow-ssh" {
  vpc_id      = "${data.aws_vpc.vpc.id}"
  name        = "${local.name_security_group}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_security_group}"
  }
}


resource "aws_iam_role" "ecr_readOnly_role" {
  name = "${local.name_aws_iam_role_ecr}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
      Name = "${local.name_aws_iam_role_ecr}"
  }
}

resource "aws_iam_instance_profile" "ecr_readOnly_profile" {
   name = "${local.name_ecr_readOnly_profile}"
  role = "${aws_iam_role.ecr_readOnly_role.name}"
}

resource "aws_iam_role_policy" "ecr_readOnly_policy" {
  name = "${local.name_aws_iam_role_policy}"
  role = "${aws_iam_role.ecr_readOnly_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:DescribeImages",
                "ecr:BatchGetImage",
                "ecr:GetLifecyclePolicy",
                "ecr:GetLifecyclePolicyPreview",
                "ecr:ListTagsForResource",
                "ecr:DescribeImageScanFindings"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}