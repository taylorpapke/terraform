# Configure the AWS provider
provider "aws" {
  region = "us-west-2"
}

# Set up a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "MyVPC"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "MyInternetGateway"
  }
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"
  map_public_ip_on_launch = true  # Enable public IP on instance launch

  tags = {
    Name = "PublicSubnet"
  }
}

# Create a route table for the public subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

# Associate the route table with the public subnet
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
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
  ami           = "ami-004a0173a724e2261" # Amazon Linux 2 AMI (use an AMI ID for your region)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id

  # Use vpc_security_group_ids for VPC deployments
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Optional: Attach an SSH key for access
  key_name = "experiential4" # Replace with your SSH key name

  # User data script to set up the PHP app
  user_data = <<-EOF
    #!/bin/bash
    # Update packages and install Apache & PHP
    yum update -y

    # Install EPEL repository
    amazon-linux-extras install epel -y

    # Install the PHP 7.x and required extensions
    amazon-linux-extras install php8.1 -y

    yum install -y httpd git php-mbstring php-xml php-mysqlnd

    # Start Apache and ensure it starts on boot
    systemctl start httpd
    systemctl enable httpd

    # Install Composer
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    php -r "unlink('composer-setup.php');"

    # Clone the PHP app code from GitHub
    cd /var/www/html

    # Clear the existing content
    rm -rf *

    git clone https://github.com/taylorpapke/php-sso-login.git .

    # Install Composer dependencies
    composer install
    
    # Give Apache ownership of the files
    chown -R apache:apache /var/www/html
    find /var/www/html -type d -exec chmod 755 {} \;
    find /var/www/html -type f -exec chmod 644 {} \;

    cat <<EOT > /var/www/html/config.php
    <?php
    return [
      'YOUR_GOOGLE_CLIENT_ID' => 'YOUR_GOOGLE_CLIENT_ID',  # <--These must be updated with actual ID
      'YOUR_GOOGLE_CLIENT_SECRET' => 'YOUR_GOOGLE_CLIENT_SECRET',
      'YOUR_GOOGLE_REDIRECT_URI' => 'YOUR_GOOGLE_REDIRECT_URI',

      'microsoft_client_id' => 'microsoft_client_id',  # <--These must be updated with actual ID
      'microsoft_client_secret' => 'microsoft_client_secret',
      'microsoft_redirect_uri' => 'microsoft_redirect_uri',  # <--Update URI with instance here and in OAuth provider console (for Amazon Cognito, Microsoft, or Google)

      'amazon_client_id' => 'amazon_client_id',  # <--These must be updated with actual ID
      'amazon_client_secret' => 'amazon_client_secret',
      'amazon_redirect_uri' => 'amazon_redirect_uri',  # <--Update URI with instance here and in OAuth provider console (for Amazon Cognito, Microsoft, or Google)
      'amazon_user_pool_id' => 'amazon_user_pool_id',
      'amazon_region' => 'amazon_region',
      'amazon_domain' => 'amazon_domain',
    ];
    EOT

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
