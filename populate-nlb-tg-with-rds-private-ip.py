import json
import os
import random
import sys
import boto3
import logging

from datetime import datetime
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

'''
This function populates a Network Load Balancer's target group with RDS IP addresses

Configure these environment variables in your Lambda environment

1. NLB_TG_ARN - The ARN of the Network Load Balancer's target group
2. RDS_PORT
3. RDS_SG_ID - RDS VPC Security Group Id
4. RDS_ID - RDS Identifier
'''

NLB_TG_ARN = os.environ['NLB_TG_ARN']
RDS_PORT = int(os.environ['RDS_PORT'])
RDS_SG_ID = os.environ['RDS_SG_ID']
RDS_ID = os.environ['RDS_ID']

try:
    elbv2client = boto3.client('elbv2')
except ClientError as e:
    logger.error(e.response['Error']['Message'])
    sys.exit(1)

try:
    rdsclient = boto3.client('rds')
except ClientError as e:
    logger.error(e.response['Error']['Message'])
    sys.exit(1)

try:
    ec2client = boto3.client('ec2')
except ClientError as e:
    logger.error(e.response['Error']['Message'])
    sys.exit(1)


def register_target(tg_arn, new_target_list):

    logger.info(f"INFO: Register new_target_list:{new_target_list}")

    try:
        elbv2client.register_targets(
            TargetGroupArn=tg_arn,
            Targets=new_target_list
        )
    except ClientError as e:
        logger.error(e.response['Error']['Message'])


def deregister_target(tg_arn, new_target_list):

    try:
        logger.info(f"INFO: Deregistering targets: {new_target_list}")
        elbv2client.deregister_targets(
            TargetGroupArn=tg_arn,
            Targets=new_target_list
        )
    except ClientError as e:
        logger.error(e.response['Error']['Message'])


def target_group_list(ip_list):

    target_list = []
    for ip in ip_list:
        target = {
            'Id': ip,
            'Port': RDS_PORT,
        }
        target_list.append(target)
    return target_list


def get_registered_ips(tg_arn):

    registered_ip_list = []
    try:
        response = elbv2client.describe_target_health(
            TargetGroupArn=tg_arn)
        registered_ip_count = len(response['TargetHealthDescriptions'])
        logger.info(f"INFO: Number of currently registered IP: {registered_ip_count}")
        for target in response['TargetHealthDescriptions']:
            registered_ip = target['Target']['Id']
            registered_ip_list.append(registered_ip)
    except ClientError as e:
        logger.error(e.response['Error']['Message'])
    return registered_ip_list


def get_rds_private_ips(rds_az):

    resp = ec2client.describe_network_interfaces(Filters=[{
        'Name': 'group-id',
        'Values': [RDS_SG_ID]
    }, {
        'Name': 'availability-zone',
        'Values': [rds_az]
    }])
    private_ip_address = []
    for interface in resp['NetworkInterfaces']:
        private_ip_address.append(interface['PrivateIpAddress'])
    return private_ip_address


def get_rds_az():

    logger.info(f"INFO: Get RDS current AZ: {RDS_ID}")
    az = None
    try:
        response = rdsclient.describe_db_instances(
            DBInstanceIdentifier=RDS_ID
        )
        if len(response['DBInstances']) > 0:
            az = response['DBInstances'][0]['AvailabilityZone']
            logger.info(f"INFO: RDS AZ is: {az}")

    except ClientError as e:
        logger.error(e.response['Error']['Message'])
        
    return az


def handler(event, context):

    registered_ip_list = get_registered_ips(NLB_TG_ARN)
    current_rds_az = get_rds_az()
    new_active_ip_set = get_rds_private_ips(current_rds_az)

    registration_ip_list = []
    # IPs that have not been registered
    if len(registered_ip_list) == 0 or registered_ip_list != new_active_ip_set:
        registration_ip_list = new_active_ip_set

    if registration_ip_list:
        registerTarget_list = target_group_list(registration_ip_list)
        register_target(NLB_TG_ARN, registerTarget_list)
        logger.info(f"INFO: Registering {registration_ip_list}")
    else:
        logger.info(f"INFO: No new target registered")

    deregistration_ip_list = []
    if registered_ip_list != new_active_ip_set:
        for ip in registered_ip_list:
            deregistration_ip_list.append(ip)
            logger.info(f"INFO: Deregistering IP: {ip}")
            deregisterTarget_list = target_group_list(deregistration_ip_list)
            deregister_target(NLB_TG_ARN, deregisterTarget_list)
    else:
        logger.info(f"INFO: No old target deregistered")
