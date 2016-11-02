#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status.

source ./config.conf

if [ -z $AWS_ACCESS_KEY_ID ]; then
    echo "Please supply your AWS_ACCESS_KEY_ID"
    exit 1
fi
if [ -z $AWS_SECRET_ACCESS_KEY ]; then
    echo "Please supply your AWS_SECRET_ACCESS_KEY"
    exit 1
fi
if [ -z $AWS_AMI ]; then
    echo "Please supply your AWS_AMI"
    exit 1
fi
if [ -z $AWS_VPC_ID ]; then
    echo "Please supply your AWS_VPC_ID"
    exit 1
fi
if [ -z $AWS_INSTANCE_TYPE ]; then
    echo "Please supply your AWS_INSTANCE_TYPE"
    exit 1
fi
if [ -z $AWS_DEFAULT_REGION ]; then
    echo "Please supply your AWS_DEFAULT_REGION"
    exit 1
fi
if [ -z $SWARM_WORKERS ]; then
    echo "Please supply your SWARM_WORKERS"
    exit 1
fi

echo "Configuring security group..."
aws ec2 create-security-group --group-name "minerCluster" --description "minerCluster"
# Docker ports
aws ec2 authorize-security-group-ingress --group-name "minerCluster" --protocol tcp --port 2376 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name "minerCluster" --protocol tcp --port 2377 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name "minerCluster" --protocol tcp --port 7946 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name "minerCluster" --protocol udp --port 7946 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name "minerCluster" --protocol tcp --port 4789 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name "minerCluster" --protocol udp --port 4789 --cidr 0.0.0.0/0
# Miner port
aws ec2 authorize-security-group-ingress --group-name "minerCluster" --protocol tcp --port 8233 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name "minerCluster" --protocol tcp --port 18233 --cidr 0.0.0.0/0


echo "Creating swarm manager..."
docker-machine create \
    --driver amazonec2 \
    --amazonec2-security-group "minerCluster" \
    --amazonec2-instance-type "t2.micro" \
    --amazonec2-vpc-id $AWS_VPC_ID \
    --amazonec2-region $AWS_DEFAULT_REGION \
    --amazonec2-ami $AWS_AMI \
    --amazonec2-access-key $AWS_ACCESS_KEY_ID \
    --amazonec2-secret-key $AWS_SECRET_ACCESS_KEY \
    manager

echo "Creating swarm workers..."
for i in $(seq 1 $SWARM_WORKERS); do
    docker-machine create \
        --driver amazonec2 \
        --amazonec2-security-group "minerCluster" \
        --amazonec2-instance-type $AWS_INSTANCE_TYPE \
        --amazonec2-vpc-id $AWS_VPC_ID \
        --amazonec2-region $AWS_DEFAULT_REGION \
        --amazonec2-ami $AWS_AMI \
        --amazonec2-access-key $AWS_ACCESS_KEY_ID \
        --amazonec2-secret-key $AWS_SECRET_ACCESS_KEY \
        miner$i
done

echo "Setting up the swarm..."
docker-machine ssh manager sudo docker swarm init
TOKEN=$(docker $(docker-machine config manager) swarm join-token worker -q)
for i in $(seq 1 $SWARM_WORKERS); do
    docker-machine ssh miner$i sudo docker swarm join \
        --token $TOKEN \
        $(docker-machine ip manager):2377
done

echo "Creating overlay network..."
eval $(docker-machine env manager)
docker network create -d overlay miner-network

echo "Deploying the mining service..."
docker-machine ssh manager sudo docker service create \
    --name miner \
    --publish 8233:8233 \
    --publish 18233:18233 \
    --network miner-network \
    rootio/zcash-miner
