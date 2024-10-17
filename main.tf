#create vpc
resource "aws_vpc" "TEST" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "TEST"
  }
}
#create internet gateway
resource "aws_internet_gateway" "TEST_igw" {
  vpc_id = aws_vpc.TEST.id

  tags = {
    Name = "TEST_igw"
  }
}
#create custom Route table
resource "aws_route_table" "TEST-RT" {
  vpc_id = aws_vpc.TEST.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.TEST_igw.id
  }

  tags = {
    Name = "TEST_RT"
  }
}
#Create subnet
resource "aws_subnet" "PublicSubnet1" {
  vpc_id     = aws_vpc.TEST.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "PublicSubnet1"
  }
}
#Associate subnet route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.PublicSubnet1.id
  route_table_id = aws_route_table.TEST-RT.id
}
#Create security group to allow port 22, 80 & 443.
resource "aws_security_group" "allow_web" {
    name             = "Allow web traffic"
    description      = "Allow web inbound traffic"
    vpc_id = aws_vpc.TEST.id
  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
   ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
   ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1" #Allows traffic for all ipv4 addresses in all ports
    cidr_blocks      = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Allow web traffic" 
  }
}
#Create network interface with an IP in the subnet created in step 4.
resource "aws_network_interface" "test" {
  subnet_id       = aws_subnet.PublicSubnet1.id
  private_ips     = ["10.0.1.30"]
  security_groups = [aws_security_group.allow_web.id]
}
#Assign an elastic IP to the network created in step 7.
resource "aws_eip" "Test_EIP" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.test.id
  associate_with_private_ip = "10.0.1.30"
  depends_on = [ aws_internet_gateway.TEST_igw  ] #The command specificies how elastic IP explicitly depend on IGW
}
#Create key pair
resource "aws_key_pair" "main_key" {
  key_name   = "accesskey"
  public_key = file("accesskey.pub")
}
#Create ubuntu server and install/enable apache2
resource "aws_instance" "ubuntu_server_instance" {
  ami = "ami-0866a3c8686eaeeba"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main_key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.test.id
  }
  user_data = <<-EOF
  #!/bin/bash
  sudo apt update -y
  sudo apt install apache2 -y
  sudo systemctl start apache2
  sudo bash -c "echo Web server deployed > /var/www/html/index.html"
  EOF
  tags = {
    Name = "Ubuntu Apache Server"
  }
}