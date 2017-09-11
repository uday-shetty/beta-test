#!/bin/bash
# 1ST SECTION - CAPTURE ARGUMENTS FROM ARM TEMPLATE AS VARIABLES

UCP_PUBLIC_FQDN=$1
echo "UCP_PUBLIC_FQDN: $UCP_PUBLIC_FQDN"
DTR_PUBLIC_FQDN=$2
echo "DTR_PUBLIC_FQDN: $DTR_PUBLIC_FQDN"
UCP_ADMIN_PASSWORD=$3
echo "UCP_ADMIN_PASSWORD: $UCP_ADMIN_PASSWORD"
UCP_VERSION=$4
echo "UCP_VERSION: $UCP_VERSION"
DTR_VERSION=$5
echo "DTR_VERSION: $DTR_VERSION"
DOCKER_VERSION=$6
echo "DOCKER_VERSION: $DOCKER_VERSION"
DOCKER_EE_URL=$7
echo "DOCKER_EE_URL: $DOCKER_EE_URL"
STORAGE_ACCOUNT=$8
echo "STORAGE_ACCOUNT: $STORAGE_ACCOUNT"
SUB_ID=$9
echo "SUB_ID: $SUB_ID"
RG_NAME=${10}
echo "RG_NAME: $RG_NAME"
AppId=${11}
echo "AppId: $AppId"
AppSecret=${12}
echo "AppSecret: $AppSecret"
TenantId=${13}
echo "TenantId: $TenantId"


PRODUCTION_UCP_ORG='docker'
UCP_ORG=${UCP_ORG:-"docker"}
UCP_IMAGE=${UCP_ORG}/ucp:${UCP_VERSION}
DTR_ORG=${DTR_ORG:-"docker"}
DTR_IMAGE=${DTR_ORG}/dtr:${DTR_VERSION}
IMAGE_LIST_ARGS=''


# 2ND SECTION - CHECK VARIABLES EXIST

if [ -z "$UCP_PUBLIC_FQDN" ]; then
    echo 'UCP_PUBLIC_FQDN is undefined'
    exit 1
fi

if [ -z "$UCP_ADMIN_PASSWORD" ]; then
    echo 'UCP_ADMIN_PASSWORD is undefined'
    exit 1
fi

if [ -z "$DTR_PUBLIC_FQDN" ]; then
    echo 'DTR_PUBLIC_FQDN is undefined'
    exit 1
fi

#i="0"
#while [ $i -lt 15 ] 
#do 
#if [ $(fuser /var/lib/dpkg/lock) ]; then 
#  i="0" 
#fi 
#sleep 1 
#i=$[$i+1] 
#done


# Install Python utilities

apt-get -y install jq
#apt-get -y install python 
#apt-get -y install python-dev 
#apt-get -y install linux-headers 
#apt-get -y install py-pip 
#apt-get -y install py-setuptools
#apt-get -y install python-pip
#apt-get -y install build-essential
#apt-get -y install libssl-dev 
#apt-get -y install libffi-dev 
#apt-get -y install openssl-dev
#apt-get -y install npm
apt-get update && apt-get install -y python python-pip libssl-dev libffi-dev python-dev build-essential npm
npm install -g azure-cli
pip install --upgrade pip
pip install cryptography
pip install msrest
pip install msrestazure
pip install --pre azure
#pip install -v azure-storage==0.30.0
pip install utils
pip install azure-storage --upgrade

# 3RD SECTION - INSTALL DOCKER EE

apt-get update
apt-get -y install dialog apt-utils
apt-get install -y --no-install-recommends \
    linux-image-extra-$(uname -r) \
    linux-image-extra-virtual \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
curl -fsSL $DOCKER_EE_URL/ubuntu/gpg | apt-key add -
add-apt-repository \
   "deb [arch=amd64] $DOCKER_EE_URL/ubuntu \
   $(lsb_release -cs) \
   stable-$DOCKER_VERSION"
apt-get update
apt-get -y install docker-ee

sleep 10


# 4TH SECTION - INSTALL UCP

echo "UCP_PUBLIC_FQDN=$UCP_PUBLIC_FQDN"
service docker restart
sleep 10

#docker pull docker/ucp:$UCP_VERSION

#Download Docker UCP images
images=$(docker run --rm $UCP_IMAGE images --list $IMAGE_LIST_ARGS)
for im in $images; do
    docker pull $im
done

#Download DTR images
images=$(docker run --rm $DTR_IMAGE images)
for im in $images; do
    docker pull $im
done

docker run --rm --name ucp \
  -v /var/run/docker.sock:/var/run/docker.sock \
  docker/ucp:$UCP_VERSION \
  install --controller-port 12390 --san $UCP_PUBLIC_FQDN --admin-password $UCP_ADMIN_PASSWORD --debug

sleep 30

# store swarm token

manager_ip=$(docker node inspect $(docker node ls --filter role=manager -q) | jq -r '.[] | select(.ManagerStatus.Reachability == "reachable") | .ManagerStatus.Addr | split(":")[0]')
echo "Manager IP: $manager_ip"
swarmtoken=$(docker swarm join-token worker -q)
python stoken.py add-id $SUB_ID $RG_NAME $STORAGE_ACCOUNT $manager_ip $AppId $AppSecret $TenantId
#key=$(python stoken.py get-key $SUB_ID $RG_NAME $STORAGE_ACCOUNT)
#echo "Storage Key: $key"
#python stoken.py create-table $key $STORAGE_ACCOUNT
#python stoken.py add-id $key $manager_ip $STORAGE_ACCOUNT

# 5TH SECTION - INSTALL DTR

if [ -z "$UCP_NODE"]; then
  export UCP_NODE=$(docker node ls | grep mgr0 | awk '{print $3}');
fi

#docker pull docker/dtr:$DTR_VERSION

docker run --rm \
  docker/dtr:$DTR_VERSION install \
  --replica-http-port 12392 \
  --replica-https-port 12391 \
  --ucp-url $UCP_PUBLIC_FQDN \
  --ucp-node $UCP_NODE \
  --dtr-external-url $DTR_PUBLIC_FQDN \
  --ucp-username admin --ucp-password $UCP_ADMIN_PASSWORD \
  --ucp-insecure-tls 
