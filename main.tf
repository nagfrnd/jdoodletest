provider "aws" {
  region = var.aws_region
  profile = "" # update the profile accordingly
}

provider "null" {

}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


resource "aws_launch_configuration" "newdeploy" {
  name = "newdeploy config"
  image_id = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name = "newdeploy"  
  security_groups = [""] # Please update the Security Group


  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "jdoodle" {
  desired_capacity     = 2
  max_size             = 5
  min_size             = 2
  vpc_zone_identifier = [var.subnet1, var.subnet2, var.subnet3] 
  launch_configuration = aws_launch_configuration.newdeploy.id

  health_check_type          = "EC2"
  health_check_grace_period  = 300
  force_delete               = true

  tag {
    key                 = "Name"
    value               = "jdoodle_asg"
    propagate_at_launch = true
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                  = "scale-up"
  scaling_adjustment    = 1
  adjustment_type       = "ChangeInCapacity"
  cooldown              = 300
  metric_aggregation_type  = "Average"
  autoscaling_group_name = aws_autoscaling_group.jdoodle.name
}

resource "aws_cloudwatch_metric_alarm" "scaleup_alarm" {
  alarm_name          = "Scale-up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "load_avg_up"
  namespace           = "System/Linux"
  period              = 300
  statistic           = "Average"
  threshold           = 75

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.jdoodle.name
  }

  alarm_description = "This metric monitors ec2 Load"
  alarm_actions     = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down"
  scaling_adjustment    = -1
  adjustment_type       = "ChangeInCapacity"
  cooldown              = 300
  metric_aggregation_type  = "Average"
  autoscaling_group_name = aws_autoscaling_group.jdoodle.name
}

resource "aws_cloudwatch_metric_alarm" "scaledown_alarm" {
  alarm_name          = "Scale-down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "load_avg_down"
  namespace           = "System/Linux"
  period              = 300
  statistic           = "Average"
  threshold           = 50

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.jdoodle.name
  }

  alarm_description = "This metric monitors ec2 Load"
  alarm_actions     = [aws_autoscaling_policy.scale_down.arn]
}

