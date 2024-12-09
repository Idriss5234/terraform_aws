provider "aws" {
    region = "eu-north-1"  
}

variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip{}
variable public_key_location{}
variable private_key_location{}



resource "aws_vpc" "myapp-vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name: "${var.env_prefix}-vpc"
    }
}

resource "aws_subnet" "myapp-subnet-1" {
    vpc_id = aws_vpc.myapp-vpc.id
    cidr_block = var.subnet_cidr_block
    availability_zone = var.avail_zone
    tags = {
        Name: "${var.env_prefix}-subnet-1"
    }
}

resource "aws_internet_gateway" "myapp-igw" {
    vpc_id = aws_vpc.myapp-vpc.id
    tags = {
        Name: "${var.env_prefix}-vpc"
    }
}

resource "aws_route_table" "myapp-route-table"{
    vpc_id= aws_vpc.myapp-vpc.id
    route{
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-igw.id
    }
     tags = {
        Name: "${var.env_prefix}-rtb"
    }
}

resource "aws_route_table_association" "a-rtb-subnet" {
    subnet_id = aws_subnet.myapp-subnet-1.id
    route_table_id= aws_route_table.myapp-route-table.id
}

resource "aws_default_security_group" "default-sg"{
    vpc_id = aws_vpc.myapp-vpc.id
    ingress{
        from_port = 22
        to_port=22
        protocol = "tcp"
        cidr_blocks = [var.my_ip] #source who is allowed
    }
    ingress{
        from_port = 8080
        to_port= 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0 #any port
        to_port= 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

data "aws_ami" "latest_Amazon_linux_image"{
    most_recent=true
    owners=["amazon"]
    filter {
        name="name"
        values=["amzn2-ami-hvm-*-x86_64-gp2"]
    }
    filter{
        name="virtualization-type"
        values=["hvm"]
    }
}

output "aws_ami_id"{
    value=data.aws_ami.latest_Amazon_linux_image.id
}

resource "aws_key_pair""my_key_pair"{
    key_name="server-key"
    public_key="${file(var.public_key_location)}"
}

resource "aws_instance" "my-app-server"{
    ami= data.aws_ami.latest_Amazon_linux_image.id
    instance_type="t3.micro"
    subnet_id=aws_subnet.myapp-subnet-1.id
    availability_zone=var.avail_zone
    vpc_security_group_ids=[aws_default_security_group.default-sg.id]
    associate_public_ip_address=true

    key_name= aws_key_pair.my_key_pair.key_name

    tags={
        name="${var.env_prefix}-server"
    }

 connection{
    type="ssh"
    host = self.public_ip
    user="ec2-user"
    private_key=file(var.private_key_location)
 }

 provisioner "file"{
    source="/home/vboxuser/Downloads/terraform/entry-script.sh"
    destination="/home/ec2-user/entry-script.sh"
 }
 provisioner "remote-exec" {
    script = file("entry-script.sh")
 }
 provisioner "local-exec" {
    command ="echo ${self.public_ip}" 
 }
                    

}

