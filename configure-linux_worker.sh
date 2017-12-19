#!/bin/bash

UCP_PUBLIC_FQDN=$1
echo "UCP_PUBLIC_FQDN: $UCP_PUBLIC_FQDN"
UCP_VERSION=$2
echo "UCP_VERSION: $UCP_VERSION"
DOCKER_VERSION=$3
echo "DOCKER_VERSION: $DOCKER_VERSION"
DOCKER_EE_URL=$4
echo "DOCKER_EE_URL: $DOCKER_EE_URL"
PRIVATE_IP=$5
echo "PRIVATE_IP: $PRIVATE_IP"

#  SECTION - CHECK VARIABLES EXIST

if [ -z "$DOCKER_VERSION" ]; then
    echo 'DOCKER_VERSION is undefined'
    #exit 1
fi

if [ -z "$UCP_VERSION" ]; then
    echo 'UCP_VERSION is undefined'
    #exit 1
fi


#  SECTION - INSTALL DOCKER
add-apt-repository "deb [arch=amd64] $DOCKER_EE_URL/ubuntu \
   $(lsb_release -cs) \
   $DOCKER_VERSION"

curl -fsSL $DOCKER_EE_URL/ubuntu/gpg | sudo apt-key add -

apt-get update

apt-get install docker-ee

service docker restart

sleep 10

# SECTION - JOIN SWARM 

#install UCP agents

docker pull docker/ucp-agent:$UCP_VERSION

Token=$(curl http://$PRIVATE_IP:9024/token/worker/)
echo "TOKEN: $token"
JoinTarget=$PRIVATE_IP:2377
docker swarm join --token $Token $JoinTarget
