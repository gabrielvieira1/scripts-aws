#!/bin/bash

# Variáveis
REGION="us-east-1"
AMI_ID="ami-00a929b66ed6e0de6"
INSTANCE_TYPE="t2.micro"
KEY_NAME="ssh-gabriel-key"
SECURITY_GROUP_NAME="MeuWebServerSG"
INSTANCE_NAME="Meu Web Server"
SSH_KEY_FILE="$KEY_NAME.pem"
ENDPOINT_URL="http://localhost.localstack.cloud:4566"  # URL do LocalStack
PROFILE="localstack"  # Perfil local do LocalStack

# Verificar se o Security Group já existe
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --region "$REGION" \
    --profile "$PROFILE" --endpoint-url "$ENDPOINT_URL" \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
    --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [ "$SECURITY_GROUP_ID" == "None" ] || [ -z "$SECURITY_GROUP_ID" ]; then
    echo "Security Group não encontrado. Criando..."
    ./create_security_group_local.sh
    SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --region "$REGION" \
        --profile "$PROFILE" --endpoint-url "$ENDPOINT_URL" \
        --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
        --query "SecurityGroups[0].GroupId" --output text)
else
    echo "Security Group já existe: $SECURITY_GROUP_ID"
fi

# Criar chave SSH se não existir
if [ ! -f "$SSH_KEY_FILE" ]; then
    echo "Criando chave SSH RSA 2048 bits..."
    ssh-keygen -t rsa -b 2048 -f "$KEY_NAME" -N ""  # Sem senha (-N "")

    # Renomear chave privada para ter extensão .pem
    mv "$KEY_NAME" "$SSH_KEY_FILE"

    # Importar chave pública para a AWS
    aws ec2 import-key-pair --region "$REGION" --profile "$PROFILE" \
        --endpoint-url "$ENDPOINT_URL" --key-name "$KEY_NAME" \
        --public-key-material fileb://"$KEY_NAME.pub"

    chmod 400 "$SSH_KEY_FILE"
    echo "Chave SSH criada e salva como $SSH_KEY_FILE"
else
    echo "Chave SSH '$SSH_KEY_FILE' já existe."
fi

# Criar a instância EC2 com User Data e Tag Name
INSTANCE_ID=$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" --security-group-ids "$SECURITY_GROUP_ID" \
    --user-data file://install_httpd_local.sh \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value='$INSTANCE_NAME'}]" \
    --region "$REGION" --profile "$PROFILE" --endpoint-url "$ENDPOINT_URL" \
    --query 'Instances[0].InstanceId' --output text)

if [ -z "$INSTANCE_ID" ]; then
    echo "Erro ao criar a instância EC2."
    exit 1
fi

echo "Instância EC2 criada! ID: $INSTANCE_ID"

# Aguardar inicialização
echo "Aguardando a inicialização da instância..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION" \
    --profile "$PROFILE" --endpoint-url "$ENDPOINT_URL"

# Obter IP público da instância
IP_PUBLICO=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" \
    --profile "$PROFILE" --endpoint-url "$ENDPOINT_URL" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

if [ "$IP_PUBLICO" == "None" ] || [ -z "$IP_PUBLICO" ]; then
    echo "Nenhum IP público foi atribuído. A instância pode estar em uma VPC sem Internet Gateway."
    exit 1
fi

echo "Servidor Apache disponível em: http://$IP_PUBLICO"

# Exibir comando para acessar via SSH
echo "Para acessar a instância via SSH, execute:"
echo "ssh -i $SSH_KEY_FILE ec2-user@$IP_PUBLICO"
