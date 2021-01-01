module "iam_instance_profile" { #A
source = "scottwinkler/iip/aws"
actions = ["logs:*", "rds:*"] #B
}
data "template_cloudinit_config" "config" {
gzip = true
base64_encode = true
part {
content_type = "text/cloud-config"
content = templatefile("${path.module}/cloud_config.yaml", var.db_config) #C
}
}
data "aws_ami" "ubuntu" {
most_recent = true
filter {
name = "name"
values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
}
owners = ["099720109477"]
}
resource "aws_launch_template" "webserver" {
name_prefix = var.namespace
image_id = data.aws_ami.ubuntu.id #D
instance_type = "t2.micro"
user_data = data.template_cloudinit_config.config.rendered #D
key_name = var.ssh_keypair
iam_instance_profile {
name = module.iam_instance_profile.name #D
}
vpc_security_group_ids = [var.sg.websvr]
}
resource "aws_autoscaling_group" "webserver" {
name = "${var.namespace}-asg" #A
min_size = 1
max_size = 3
vpc_zone_identifier = var.vpc.private_subnets
target_group_arns = module.alb.target_group_arns
launch_template {
id = aws_launch_template.webserver.id #B
version = aws_launch_template.webserver.latest_version #B
}
}
module "alb" {
source = "terraform-aws-modules/alb/aws"
version = "~> 4.0"
load_balancer_name = "${var.namespace}-alb"
security_groups = [var.sg.lb] #C
subnets = var.vpc.public_subnets
vpc_id = var.vpc.vpc_id
logging_enabled = false
http_tcp_listeners = [{ port = 80, protocol = "HTTP" }]
http_tcp_listeners_count = "1"
target_groups = [{ name = "websvr", backend_protocol = "HTTP", backend_port = 8080 }]
target_groups_count = "1"
}