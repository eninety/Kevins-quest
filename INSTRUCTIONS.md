Deployment Instructions for A Quest in the Clouds

Introduction

This guide provides step-by-step instructions to deploy a Node.js and Golang web application using AWS ECS with EC2 launch type, setting up a load balancer with TLS, and ensuring the application is accessible and secure.

Prerequisites

AWS Account
AWS CLI configured with appropriate permissions
Terraform installed
Git installed
Docker installed
A domain name managed in Route 53
An SSH key pair for EC2 instances
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

Conclusion

This guide provides all the steps needed to deploy the web application using AWS services, including ECS, EC2, and Route 53, and to secure it with TLS. Follow these instructions to successfully complete the deployment.
