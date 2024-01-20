import boto3
import json
import datetime
import os

def lambda_handler(event, context):
    autoscaling_group_name = os.environ['AUTOSCALING_GROUP_NAME']
    
    ec2_client = boto3.client('ec2')

    response = ec2_client.describe_auto_scaling_groups(AutoScalingGroupNames=["jdoodle_asg"])
    instances = response['AutoScalingGroups'][0]['Instances']
    
    new_launch_config_name = f"{autoscaling_group_name}-config-{datetime.datetime.utcnow().strftime('%Y%m%d%H%M%S')}"
    response = ec2_client.create_launch_template(
        LaunchTemplateName=new_launch_config_name,
        VersionDescription='Initial version',
        VersionNumber=1,
        LaunchTemplateData={
            'instanceType': 't3.micro',  
            'imageId': 'ami-0c7217cdde317cfec',
            'keyName': 'newdeploy',  
            'securitygroup': 'Please update it'
        }
    )
    
    # Update the Auto Scaling Group with the new launch configuration
    response = autoscaling_client.update_auto_scaling_group(
        AutoScalingGroupName=autoscaling_group_name,
        LaunchConfigurationName=new_launch_config_name
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps('Auto Scaling Group refreshed successfully!')
    }
