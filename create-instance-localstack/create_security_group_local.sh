#!/bin/bash

# Variáveis
REGION="us-east-1"  # Região da AWS
SECURITY_GROUP_NAME="MeuWebServerSG"  # Nome do Security Group
DESCRIPTION="Security Group for SSH, HTTP, and HTTPS"  # Sem caracteres especiais
ENDPOINT_URL="http://localhost.localstack.cloud:4566"  # URL do LocalStack
PROFILE="localstack"  # Perfil local do LocalStack

# Obter a VPC Default automaticamente
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" \
    --query "Vpcs[0].VpcId" --output text --region "$REGION" \
    --profile "$PROFILE" --endpoint-url "$ENDPOINT_URL")

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    echo "Erro: Não foi possível encontrar a VPC Default."
    exit 1
fi

echo "Usando a VPC Default: $VPC_ID"

# Criar o Security Group
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name "$SECURITY_GROUP_NAME" \
    --description "$DESCRIPTION" \
    --vpc-id "$VPC_ID" \
    --region "$REGION" \
    --profile "$PROFILE" --endpoint-url "$ENDPOINT_URL" \
    --query 'GroupId' --output text 2>/dev/null)

# Verificar se o Security Group foi criado corretamente
if [ -z "$SECURITY_GROUP_ID" ]; then
    echo "Erro ao criar o Security Group."
    exit 1
fi

echo "Security Group criado! ID: $SECURITY_GROUP_ID"

# Adicionar regra para SSH (porta 22)
aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --region "$REGION" \
    --profile "$PROFILE" --endpoint-url "$ENDPOINT_URL"

echo "Regra SSH (22) adicionada."

# Adicionar regra para HTTP (porta 80)
aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region "$REGION" \
    --profile "$PROFILE" --endpoint-url "$ENDPOINT_URL"

echo "Regra HTTP (80) adicionada."

# Adicionar regra para HTTPS (porta 443)
aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --region "$REGION" \
    --profile "$PROFILE" --endpoint-url "$ENDPOINT_URL"

echo "Regra HTTPS (443) adicionada."

# Exibir detalhes do Security Group
aws ec2 describe-security-groups --group-ids "$SECURITY_GROUP_ID" \
    --region "$REGION" --profile "$PROFILE" --endpoint-url "$ENDPOINT_URL"
