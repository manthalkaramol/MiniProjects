#------------------------------------------------------------------------------
# AWS PROVIDER
#------------------------------------------------------------------------------
provider "aws"{
	region = "ap-south-1"
	access_key = var.restAPI-access-key
	secret_key = var.restAPI-secret-key
}


#------------------------------------------------------------------------------
# VPC
#------------------------------------------------------------------------------
resource "aws_vpc" "restAPI-vpc" {
  cidr_block       = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "aws-restAPI-vpc"
  }
}


#------------------------------------------------------------------------------
# SUBNETS
#------------------------------------------------------------------------------
resource "aws_subnet" "restAPI-subnet1" {
  vpc_id     = aws_vpc.restAPI-vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "aws-restAPI-subnet1"
  }
}

resource "aws_subnet" "restAPI-subnet2" {
  vpc_id     = aws_vpc.restAPI-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "aws-restAPI-subnet2"
  }
}

resource "aws_internet_gateway" "restAPI-gateway" {
	vpc_id = aws_vpc.restAPI-vpc.id
}

resource "aws_route" "restAPI-route" {
	route_table_id = aws_vpc.restAPI-vpc.main_route_table_id
	destination_cidr_block = "0.0.0.0/0"
	gateway_id = aws_internet_gateway.restAPI-gateway.id
}


#------------------------------------------------------------------------------
# SECURITY GROUP
#------------------------------------------------------------------------------
resource "aws_security_group" "restAPI-LB-sg" {
  name        = "aws-restAPI-LB-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.restAPI-vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aws-restAPI-LB-sg"
  }
}

resource "aws_security_group" "restAPI-EC2-sg" {
  name        = "aws-restAPI-EC2-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.restAPI-vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
	#cidr_blocks = ["0.0.0.0/0"]
	security_groups = [aws_security_group.restAPI-LB-sg.id]
  }
  
 ingress {
    description = "SSH to EC2"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aws-restAPI-EC2-sg"
  }
}

#------------------------------------------------------------------------------
# ECS TASK EXECUTION ROLE
#------------------------------------------------------------------------------
resource "aws_iam_role" "restAPI-ecs_task_execution_role" {
  name = "restAPI_ecs_task_execution_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

#------------------------------------------------------------------------------
# ECS TASK EXECUTION POLICY
#------------------------------------------------------------------------------
resource "aws_iam_policy" "restAPI-ecs_task_execution_policy" {
  name = "restAPI_ecs_task_execution_policy"
  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
			"Resource": "*"
        }
    ]
  }
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role = aws_iam_role.restAPI-ecs_task_execution_role.id
  policy_arn = aws_iam_policy.restAPI-ecs_task_execution_policy.arn
}

#------------------------------------------------------------------------------
# ECS CLUSTER
#------------------------------------------------------------------------------
resource "aws_ecs_cluster" "restAPI-cluster" {
  name = "aws-restAPI-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

#------------------------------------------------------------------------------
# CLOUDWATCH LOG GROUP
#------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "restAPI-log-group" {
  name = "/ecs/restAPI-task-family"
}


#------------------------------------------------------------------------------
# ECS TASK DEFINITION
#------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "restAPI-task-definition" {
	family = "restAPI-task-family"
	memory = var.task-memory
	cpu = var.task-cpu
	network_mode = "bridge"
	requires_compatibilities = ["EC2"]
	execution_role_arn = aws_iam_role.restAPI-ecs_task_execution_role.arn
	task_role_arn = aws_iam_role.restAPI-ecs_task_execution_role.arn
	container_definitions = <<TASK_DEFINITION
	[
		{
			"command": null,
			"entryPoint": null,
			"environment": [],
			"essential": true,
			"image": ${jsonencode(var.docker-image)},
			"memoryReservation": ${jsonencode(var.docker-memory)},
			"name": "aws-restAPI-image",
			"logConfiguration": {
				"logDriver": "awslogs",
				"secretOptions": null,
				"options": {
					"awslogs-group": "/ecs/restAPI-task-family",
					"awslogs-region": "ap-south-1",
					"awslogs-stream-prefix": "ecs"
				}
			},
			"requiresCompatibilities": [
				"EC2"
			],
			"networkMode": "bridge",
			"cpu": ${jsonencode(var.docker-cpu)},
			"revision": 3,
			"status": "ACTIVE",
			"inferenceAccelerators": null,
			"proxyConfiguration": null,
			"volumes": [],
			"portMappings": [
				{
					"hostPort": 80,
					"protocol": "tcp",
					"containerPort": 5000
				}
			],
			"resourceRequirements": null
		}
	]
	TASK_DEFINITION	
	tags = {
    Name = "aws-restAPI-task-definition"
  }
}


#------------------------------------------------------------------------------
# ECS SERVICE ROLE
#------------------------------------------------------------------------------
resource "aws_iam_role" "ecs-service-role" {
    name                = "ecs-service-role"
    path                = "/"
    assume_role_policy  = data.aws_iam_policy_document.ecs-service-policy.json
}

resource "aws_iam_role_policy_attachment" "ecs-service-role-attachment" {
    role       = aws_iam_role.ecs-service-role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

data "aws_iam_policy_document" "ecs-service-policy" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type        = "Service"
            identifiers = ["ecs.amazonaws.com"]
        }
    }
}


#------------------------------------------------------------------------------
# EC2 INSTANCE ROLE
#------------------------------------------------------------------------------
resource "aws_iam_role" "ecs-instance-role" {
    name                = "ecs-instance-role"
    path                = "/"
    assume_role_policy  = data.aws_iam_policy_document.ecs-instance-policy.json
}

data "aws_iam_policy_document" "ecs-instance-policy" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type        = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }
    }
}

resource "aws_iam_role_policy_attachment" "ecs-instance-role-attachment" {
    role       = aws_iam_role.ecs-instance-role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs-instance-profile" {
    name = "ecs-instance-profile"
    path = "/"
    role = aws_iam_role.ecs-instance-role.id
}

#------------------------------------------------------------------------------
# ECS SERVICE
#------------------------------------------------------------------------------
resource "aws_ecs_service" "restAPI-ecs-service" {
  name            = "aws-restAPI-ecs-service"
  cluster         = aws_ecs_cluster.restAPI-cluster.id
  task_definition = aws_ecs_task_definition.restAPI-task-definition.arn
  launch_type     = "EC2"
  desired_count   = var.desired-capacity
  load_balancer {
    	target_group_arn  = aws_alb_target_group.restAPI-target-group.arn
    	container_port    = 5000
    	container_name    = "aws-restAPI-image"
	}
}


#------------------------------------------------------------------------------
# Application Load Balancer
#------------------------------------------------------------------------------
resource "aws_alb" "restAPI-aws-lb" {
  name               = "restAPI-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.restAPI-LB-sg.id]
  #subnets            = aws_subnet.public.*.id
  subnets            = [aws_subnet.restAPI-subnet1.id,aws_subnet.restAPI-subnet2.id]
  tags = {
    Name = "restAPI-aws-lb"
  }
}

resource "aws_alb_target_group" "restAPI-target-group" {
    name                = "restAPI-target-group"
    port                = "80"
    protocol            = "HTTP"
    vpc_id              = aws_vpc.restAPI-vpc.id

    health_check {
        healthy_threshold   = "5"
        unhealthy_threshold = "2"
        interval            = "30"
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = "5"
    }
	depends_on = [aws_alb.restAPI-aws-lb]
}

resource "aws_alb_listener" "restAPI-alb-listener" {
    load_balancer_arn = aws_alb.restAPI-aws-lb.arn
    port              = "80"
    protocol          = "HTTP"

    default_action {
        target_group_arn = aws_alb_target_group.restAPI-target-group.arn
        type             = "forward"
    }
}


#------------------------------------------------------------------------------
# ECS Launch Configuration
#------------------------------------------------------------------------------
resource "aws_launch_configuration" "restAPI-ecs-launch-configuration" {
    name                        = "restAPI-ecs-launch-configuration"
    image_id                    = "ami-0bc4953043ba15f2f"
    instance_type               = "t2.micro"
    iam_instance_profile        = aws_iam_instance_profile.ecs-instance-profile.id


    lifecycle {
      create_before_destroy = true
    }

    security_groups             = [aws_security_group.restAPI-EC2-sg.id]
    associate_public_ip_address = "true"
    key_name                    = "jenkins-server"
    user_data                   = <<EOF
                                  #!/bin/bash
                                  echo ECS_CLUSTER=aws-restAPI-cluster >> /etc/ecs/ecs.config
                                  EOF
}


#------------------------------------------------------------------------------
# AutoScaling Group
#------------------------------------------------------------------------------
resource "aws_autoscaling_group" "restAPI-ecs-autoscaling-group" {
    name                        = "restAPI-ecs-autoscaling-group"
	min_size                    = var.desired-capacity
	max_size                    = var.desired-capacity
    desired_capacity            = var.desired-capacity
    vpc_zone_identifier         = [aws_subnet.restAPI-subnet1.id, aws_subnet.restAPI-subnet2.id]
    launch_configuration        = aws_launch_configuration.restAPI-ecs-launch-configuration.name
    health_check_type           = "ELB"
  }