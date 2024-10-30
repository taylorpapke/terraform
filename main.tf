# Configure the AWS provider
provider "aws" {
  region = "us-east-1"
}

# Set up a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

# Security group allowing HTTP and SSH access
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.my_vpc.id

  # Allow HTTP (port 80) access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH (port 22) access (optional)
  ingress {
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
}

# Launch an EC2 instance
resource "aws_instance" "php_app_instance" {
  ami           = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (use an AMI ID for your region)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.web_sg.name]

  # Optional: Attach an SSH key for access
  key_name = "your-key-pair-name"  # Replace with your SSH key name

  # User data script to set up the PHP app
  user_data = <<-EOF
    #!/bin/bash
    # Update packages and install Apache & PHP
    yum update -y
    yum install -y httpd php git

    # Start Apache and ensure it starts on boot
    systemctl start httpd
    systemctl enable httpd

    # Clone the PHP app code from GitHub
    cd /var/www/html
    git clone https://github.com/your-github-username/your-repo-name.git .
    
    # Give Apache ownership of the files
    chown -R apache:apache /var/www/html

    # Restart Apache to load the new code
    systemctl restart httpd
  EOF

  tags = {
    Name = "PHPWebAppInstance"
  }
}

# Output the public IP of the instance for easy access
output "instance_public_ip" {
  value = aws_instance.php_app_instance.public_ip
  description = "The public IP of the EC2 instance hosting the PHP app."
}
