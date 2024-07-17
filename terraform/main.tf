provider "aws" {
  region = "us-east-1"
}

# Create VPC
resource "aws_vpc" "quest_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create Subnets
resource "aws_subnet" "quest_subnet_1" {
  vpc_id            = aws_vpc.quest_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "quest_subnet_2" {
  vpc_id            = aws_vpc.quest_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

# Create Internet Gateway
resource "aws_internet_gateway" "quest_igw" {
  vpc_id = aws_vpc.quest_vpc.id
}

# Create Route Table
resource "aws_route_table" "quest_route_table" {
  vpc_id = aws_vpc.quest_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.quest_igw.id
  }
}

# Associate Route Table with Subnets
resource "aws_route_table_association" "quest_rta_1" {
  subnet_id      = aws_subnet.quest_subnet_1.id
  route_table_id = aws_route_table.quest_route_table.id
}

resource "aws_route_table_association" "quest_rta_2" {
  subnet_id      = aws_subnet.quest_subnet_2.id
  route_table_id = aws_route_table.quest_route_table.id
}

# Create Security Group for ALB
resource "aws_security_group" "quest_alb_sg" {
  vpc_id = aws_vpc.quest_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Security Group for ECS Service
resource "aws_security_group" "quest_ecs_sg" {
  vpc_id = aws_vpc.quest_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.quest_alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create ACM Certificate
resource "aws_acm_certificate" "quest_cert" {
  domain_name       = "your-domain.com" # Replace with your domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Create ALB
resource "aws_lb" "quest_alb" {
  name               = "quest-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.quest_alb_sg.id]
  subnets            = [aws_subnet.quest_subnet_1.id, aws_subnet.quest_subnet_2.id]

  enable_deletion_protection = false
}

# Create ALB Listener
resource "aws_lb_listener" "quest_alb_listener" {
  load_balancer_arn = aws_lb.quest_alb.arn
  port              = "443"
  protocol          = "HTTPS"

  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.quest_cert.arn

  default_action {
    type = "forward"

    target_group_arn = aws_lb_target_group.quest_tg.arn
  }
}

# Create ALB Target Group
resource "aws_lb_target_group" "quest_tg" {
  name     = "quest-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.quest_vpc.id

  health_check {
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
}

# Attach ECS Service to ALB Target Group
resource "aws_lb_target_group_attachment" "quest_tg_attachment" {
  target_group_arn = aws_lb_target_group.quest_tg.arn
  target_id        = aws_instance.quest_instance.id # This will be replaced with the ECS task ID later
  port             = 80
}

# Create ECS cluster
resource "aws_ecs_cluster" "quest" {
  name = "quest"
}

# Create ECS task definition
resource "aws_ecs_task_definition" "quest_api" {
  family                   = "quest-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "quest-api"
      image     = "231961697046.dkr.ecr.us-east-1.amazonaws.com/quest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_execution_role.arn
}

# Create IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Create ECS service
resource "aws_ecs_service" "quest_api" {
  name            = "quest-api"
  cluster         = aws_ecs_cluster.quest.id
  task_definition = aws_ecs_task_definition.quest_api.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.quest_subnet_1.id, aws_subnet.quest_subnet_2.id]
    security_groups  = [aws_security_group.quest_ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.quest_tg.arn
    container_name   = "quest-api"
    container_port   = 80
  }
}

