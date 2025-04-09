#!/bin/bash

# Variáveis
REGION="us-east-1"
INSTANCE_NAME="Meu Web Server"
KEY_NAME="ssh-gabriel-key"
SSH_KEY_FILE="$KEY_NAME.pem"
SECURITY_GROUP_NAME="MeuWebServerSG"

# Obter o ID da instância pelo nome
INSTANCE_ID=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].InstanceId" --output text 2>/dev/null)

if [ "$INSTANCE_ID" == "None" ] || [ -z "$INSTANCE_ID" ]; then
    echo "Nenhuma instância EC2 ativa encontrada com o nome '$INSTANCE_NAME'."
else
    echo "Encerrando instância EC2 ($INSTANCE_ID)..."
    aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$REGION"
    
    echo "Aguardando encerramento..."
    aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID" --region "$REGION"
    
    echo "Instância EC2 encerrada!"
fi

# Excluir par de chaves SSH
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "Excluindo par de chaves SSH '$KEY_NAME'..."
    aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$REGION"
    
    # Remover arquivos locais
    rm -f "$SSH_KEY_FILE" "$KEY_NAME.pub"
    echo "Chave SSH removida."
else
    echo "Par de chaves SSH '$KEY_NAME' não encontrado."
fi

# Obter ID do Security Group
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --region "$REGION" \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
    --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [ "$SECURITY_GROUP_ID" == "None" ] || [ -z "$SECURITY_GROUP_ID" ]; then
    echo "Security Group '$SECURITY_GROUP_NAME' não encontrado."
else
    echo "Excluindo Security Group ($SECURITY_GROUP_ID)..."
    aws ec2 delete-security-group --group-id "$SECURITY_GROUP_ID" --region "$REGION"
    echo "Security Group removido."
fi

echo "Recursos excluídos com sucesso!"
