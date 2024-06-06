# VPC AND COMPONENTS 

resource "aws_vpc" "myvpc" {

  cidr_block = var.Cidr_block

}

resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true


}

resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true


}
# CREATING AND ASSOCIATING IGW TO VPC

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id

}
# CREATING AND ASSOCIATING ROUTE TABLE TO VPC

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myvpc.id

  # USING ROUTE TO ESTABLISH CONNECTION BETWEEN VPC AND IGW

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# ROUTE ASSOCIATION TO SUBNETS MAKING THEM PUBLIC CONSIDERING THE ROUTE GOES TO IGW 
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id

}
resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.RT.id
}

# CREATING SECURITY GROUPS TO BE USED BY INSTANCES 

resource "aws_security_group" "webSg" {
  name   = "websg"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # THIS IS FOR JENKINS BEING INSTALLED ON THE SERVER 1
  ingress {
    description = "HTTP from VPC"
    from_port   = 8080
    to_port     = 8080
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
    Name = "Web-sg"
  }
}

#creating s3 to store or backup  any files 

resource "aws_s3_bucket" "example" {
  bucket = "ngahsterraforms3"
}

#CREATING INSTANCES WITH BASH SCRIPTS

resource "aws_instance" "webserver1" {
  ami                    = "ami-04b70fa74e45c3917"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id              = aws_subnet.sub1.id
  user_data              = base64encode(file("userdata.sh"))
}

resource "aws_instance" "webserver2" {
  ami                    = "ami-04b70fa74e45c3917"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id              = aws_subnet.sub2.id
  user_data              = base64encode(file("userdata1.sh"))
}

#CREATING AN APPLICATION LOAD BALANCER 

resource "aws_lb" "myalb" {
  name               = "myalb"
  load_balancer_type = "application"


  security_groups = [aws_security_group.webSg.id]
  subnets         = [aws_subnet.sub1.id, aws_subnet.sub2.id]

}

#CREATING A TARGET GROUP FOR THE LOAD BALANCER 

resource "aws_lb_target_group" "mytg" {
  name     = "mytg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }


}
#ADDING OR ATTACHING RESOURCES TO BE CONTROLED BY TARGET GROUP EG INNSTANCES 

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.mytg.arn
  target_id        = aws_instance.webserver1.id
  port             = 80

}
#ADDING THE TARGET GROUP TO THE LOAD BALANCER 

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.mytg.arn
    type             = "forward"
  }
}
output "loadbalancerdns" {
  value = aws_lb.myalb.dns_name
}