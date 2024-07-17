A Quest in the Clouds

Introduction

This project demonstrates deploying a Node.js and Golang web application using AWS ECS with EC2 launch type, setting up a load balancer with TLS, and ensuring the application is accessible and secure. This README provides a step-by-step guide to set up the project, build and deploy the Docker image, and apply the necessary Terraform configuration.

Prerequisites

AWS Account
AWS CLI configured with appropriate permissions
Terraform installed
Git installed
Docker installed
A domain name managed in Route 53
An SSH key pair for EC2 instances
Project Structure

plaintext
Copy code
.
├── main.tf              # Terraform configuration file
├── Dockerfile           # Dockerfile to build the application image
├── app/                 # Directory containing the application code
└── README.md            # Instructional README file
Steps to Deploy

Step 1: Clone the Repository
Clone the repository to your local machine:

sh
Copy code
git clone <repository-url>
cd <repository-directory>
Step 2: Build the Docker Image
Build the Docker image locally to ensure it works:

sh
Copy code
docker build -t quest-app .
docker run -d -p 3000:3000 --name quest-app -e SECRET_WORD="your_secret_word" quest-app
Verify the application is running by navigating to http://localhost:3000.

Step 3: Push Docker Image to ECR
Create an ECR repository:

sh
Copy code
aws ecr create-repository --repository-name quest-app
Authenticate Docker to the ECR repository:

sh
Copy code
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 231961697046.dkr.ecr.us-east-1.amazonaws.com
Tag and push the Docker image:

sh
Copy code
docker tag quest-app:latest 231961697046.dkr.ecr.us-east-1.amazonaws.com/quest-app:latest
docker push 231961697046.dkr.ecr.us-east-1.amazonaws.com/quest-app:latest
Step 4: Configure Terraform
Ensure your Terraform configuration (main.tf) includes the correct domain name and Route 53 hosted zone ID. Update the placeholders:

your-domain-name
your-zone-id
your-key-pair
Here is the Terraform configuration used for this project:

hcl
Copy code
provider "aws" {
  region = "us-east-1"
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main_vpc"
  }
}

# Create Subnets
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet2"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main_igw"
  }
}

# Create Route Table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "main_rt"
  }
}

# Associate Route Table with Subnets
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rt.id
}

# Create Security Group
resource "aws_security_group" "sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
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
    Name = "main_sg"
  }
}

# Create Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  enable_deletion_protection = false

  tags = {
    Name = "app_lb"
  }
}

resource "aws_lb_target_group" "tg" {
  name        = "app-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # Set target type to "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }

  tags = {
    Name = "app_tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "your-domain-name"  # Replace with your domain name
  validation_method = "DNS"

  tags = {
    Name = "cert"
  }
}

resource "aws_route53_record" "cert_validation" {
  name    = aws_acm_certificate.cert.domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.cert.domain_validation_options[0].resource_record_type
  zone_id = "your-zone-id"  # Replace with your Route 53 hosted zone ID
  records = [aws_acm_certificate.cert.domain_validation_options[0].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
}

# Create CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/quest-task"
  retention_in_days = 7
}

# Create ECS Cluster
resource "aws_ecs_cluster" "quest_cluster" {
  name = "quest-cluster"
}

# Create IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}

# Create IAM Role for EC2 Instances
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  ]
}

# Create IAM Instance Profile for EC2 Instances
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}

# Create EC2 Launch Configuration
resource "aws_launch_configuration" "ecs_launch_config" {
  name_prefix          = "ecs-launch-config-"
  image_id             = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name
  key_name             = "your-key-pair" # Replace with your key pair name

  security_groups = [aws_security_group.sg.id]

  user_data = <<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.quest_cluster.name} >> /etc/ecs/ecs.config
EOF

  lifecycle {
    create_before_destroy = true
  }
}

# Create Auto Scaling Group
resource "aws_autoscaling_group" "ecs_asg" {
  desired_capacity     = 1
  max_size             = 2
  min_size             = 1
  vpc_zone_identifier  = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  launch_configuration = aws_launch_configuration.ecs_launch_config.id

  tag {
    key                 = "Name"
    value               = "ecs-instance"
    propagate_at_launch = true
  }

  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true

  lifecycle {
    create_before_destroy = true
  }
}

# Create ECS Task Definition
resource "aws_ecs_task_definition" "quest_task" {
  family                   = "quest-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "quest-app"
    image     = "231961697046.dkr.ecr.us-east-1.amazonaws.com/quest-app:latest"
    essential = true
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
    }]
    environment = [
      {
        name  = "SECRET_WORD"
        value = "your_secret_word"
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/quest-task"
        awslogs-region        = "us-east-1"
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

# Create ECS Service
resource "aws_ecs_service" "quest_service" {
  name            = "quest-service"
  cluster         = aws_ecs_cluster.quest_cluster.id
  task_definition = aws_ecs_task_definition.quest_task.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets         = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
    security_groups = [aws_security_group.sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "quest-app"
    container_port   = 3000
  }
}

output "ecs_cluster_id" {
  value = aws_ecs_cluster.quest_cluster.id
}

output "ecs_service_name" {
  value = aws_ecs_service.quest_service.name
}

output "load_balancer_dns" {
  value = aws_lb.app_lb.dns_name
}
Step 5: Initialize and Apply Terraform Configuration
Initialize Terraform:

sh
Copy code
terraform init
Apply the Terraform configuration:

sh
Copy code
terraform apply
Review the plan and confirm the changes by typing yes when prompted.

Step 6: Verify the Deployment
After the deployment is complete, you can verify the following:

Public cloud & index page: http(s)://<load_balancer_dns>/
Docker check: http(s)://<load_balancer_dns>/docker
Secret Word check: http(s)://<load_balancer_dns>/secret_word
Load Balancer check: http(s)://<load_balancer_dns>/loadbalanced
TLS check: http(s)://<load_balancer_dns>/tls
Replace <load_balancer_dns> with the DNS name provided in the Terraform output.

Proof of Completion

To submit your work, provide:

Your work assets:

A link to a hosted Git repository or a compressed file containing your project directory (including the .git sub-directory if you used Git).
Proof of completion:

Link(s) to hosted public cloud deployment(s).
One or more screenshots showing at least the index page of the final deployment.
Answer to the prompt:

"Given more time, I would improve..."
Notes
Discuss any shortcomings or immaturities in your solution and the reasons behind them.
This may carry as much weight as the code itself.
Conclusion

This project demonstrates your ability to deploy a web application using AWS services, including ECS, EC2, and Route 53, and to secure it with TLS. By following these instructions, you should be able to successfully complete the deployment and provide proof of your cloud skills.

Feel free to customize the README further based on your specific needs and project details.
