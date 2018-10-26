# terraform code
provider "aws" {
    region = "us-west-2"
}

#######
### NETWORKING INFRAESTRUCTURE
#######
# vpc
resource "aws_vpc" "auxisauxis-VPC" {
    cidr_block = "10.0.0.0/16"
}

# subnet
resource "aws_subnet" "auxis-Subnet" {
    vpc_id = "${aws_vpc.auxis-VPC.id}"
    cidr_block = "10.0.0.0/24"
    map_public_ip_on_launch = true
}

# internet gw
resource "aws_internet_gateway" "auxis-IGW" {
    vpc_id = "${aws_vpc.auxis-VPC.id}"
}

# route table
resource "aws_route" "auxis-Route" {
    route_table_id = "${aws_vpc.auxis-VPC.main_route_table_id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.auxis-IGW.id}"
}

# associate route table to subnet 10.0.0.0/24
resource "aws_route_table_association" "route_assoc" {
    subnet_id = "${aws_subnet.auxis-Subnet.id}"
    route_table_id = "${aws_route.auxis-Route.route_table_id}"
}

# security group
resource "aws_security_group" "auxis-SecGroup" {
    name = "main_security_group"
    vpc_id = "${aws_vpc.auxis-VPC.id}"
    
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1" # all protocols
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "auxis-SecGroup-Tomcat" {
    name = "tomcat_security_group"
    vpc_id = "${aws_vpc.auxis-VPC.id}"
    
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["10.0.0.0/16"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1" # all protocols
        cidr_blocks = ["0.0.0.0/0"]
    }
}

#######
### INSTANCES
#######

# ec2 instance
resource "aws_instance" "auxis-Tomcat" {
    ami = "ami-f2d3638a"
    instance_type = "t2.micro"

    key_name = "auxis_keypair"
    
    subnet_id = "${aws_subnet.auxis-Subnet.id}"
    vpc_security_group_ids = ["${aws_security_group.auxis-SecGroup-Tomcat.id}"]

    
    provisioner "chef" {
        server_url = "https://api.chef.io/organizations/auxis_test"
        node_name = "auxis_test"
        user_key = "${file("./chef-repo/.chef/cicatriz.pem")}"
        user_name = "cicatriz"
        recreate_client = true
        run_list = ["tomcat::default"]
        
        connection {
            type = "ssh"
            agent = true
            private_key = "${file("../auxis_keypair")}"
            user = "ec2-user"
        }
    }
#    provisioner "remote-exec" {
#        inline = [
#            "mkdir /tmp/test",
#        ]
#    }
}

# load balancer instance
resource "aws_elb" "auxis-ELB" {
    name = "auxis-ELB"
    instances = ["${aws_instance.auxis-Tomcat.id}"]
    security_groups = ["${aws_security_group.auxis-SecGroup.id}"]
    subnets = ["${aws_subnet.auxis-Subnet.id}"]

    listener {
        instance_port = 8080
        instance_protocol = "http"
        lb_port = 80
        lb_protocol = "http"
    }
}

output "Instace IPv4 address" {
  value = "${aws_instance.auxis-Tomcat.public_ip}"
}
output "ELB DNS address" {
  value = "${aws_elb.auxis-ELB.dns_name}"
}
output "Sample URL" {
  value = "http://${aws_elb.auxis-ELB.dns_name}/sample/"
}
