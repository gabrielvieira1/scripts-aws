#!/bin/bash

# Definindo o endpoint do LocalStack
endpoint_url="http://localhost.localstack.cloud:4566"
profile="localstack"  # Perfil local do LocalStack

# Definindo a chave SSH para usar
key_name="localstack-key"  # Nome da chave SSH (sem a extensão .pem)

# Gerar chave SSH se não existir
if [ ! -f "~/.ssh/$key_name.pem" ]; then
    echo "Chave SSH não encontrada, criando chave SSH..."
    ssh-keygen -t rsa -b 2048 -f ~/.ssh/$key_name.pem -N ""  # Sem senha
    echo "Chave SSH criada com sucesso."
fi

# Obter VPC default
vpc_id=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query "Vpcs[0].VpcId" --output text --endpoint-url=$endpoint_url --profile $profile)
if [ -z "$vpc_id" ]; then
    echo ">[ERRO] Não foi possível obter a VPC default"
    exit 1
fi

# Obter Subnet da zona A
subnet_id=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$vpc_id Name=availabilityZone,Values=us-east-1a --query "Subnets[0].SubnetId" --output text --endpoint-url=$endpoint_url --profile $profile)
if [ -z "$subnet_id" ]; then
    echo ">[ERRO] Não foi possível obter a Subnet da zona A"
    exit 1
fi

# Obter Security Group "bia-dev"
security_group_id=$(aws ec2 describe-security-groups --group-names "bia-dev" --query "SecurityGroups[0].GroupId" --output text --endpoint-url=$endpoint_url --profile $profile 2>/dev/null)
if [ -z "$security_group_id" ]; then
    echo ">[ERRO] Security group bia-dev não foi criado na VPC $vpc_id"
    exit 1
fi

# Lançar a instância EC2 com a chave SSH
instance_id=$(aws ec2 run-instances \
    --image-id ami-02f3f602d23f1659d \
    --count 1 \
    --instance-type t3.micro \
    --security-group-ids $security_group_id \
    --subnet-id $subnet_id \
    --associate-public-ip-address \
    --key-name $key_name \
    --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":15,"VolumeType":"gp2"}}]' \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=bia-dev}]' \
    --iam-instance-profile Name=role-acesso-ssm \
    --user-data file://user_data_ec2_zona_a.sh \
    --endpoint-url=$endpoint_url \
    --profile $profile \
    --query "Instances[0].InstanceId" \
    --output text)

if [ -z "$instance_id" ]; then
    echo ">[ERRO] Não foi possível lançar a instância EC2"
    exit 1
fi

echo "[OK] Instância EC2 lançada com sucesso! ID da instância: $instance_id"

# Obter o IP público da instância
public_ip=$(aws ec2 describe-instances \
    --instance-ids $instance_id \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text \
    --endpoint-url=$endpoint_url \
    --profile $profile)

if [ -z "$public_ip" ]; then
    echo ">[ERRO] Não foi possível obter o IP público da instância"
    exit 1
fi

echo "[OK] IP público da instância: $public_ip"

# Acessar a instância via SSH
echo "Tentando conectar via SSH..."
ssh -i ~/.ssh/$key_name.pem ec2-user@$public_ip
