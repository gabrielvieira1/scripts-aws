#!/bin/bash

# Garante que o script pare imediatamente se qualquer comando falhar.
set -e

# Carrega todas as nossas variáveis de nomenclatura do arquivo de configuração.
# Esta é a única fonte da verdade para os nomes.
source ./config.sh

# --- Descrições dos Security Groups (Apenas caracteres ASCII) ---
SG_API_DESCRIPTION="Security Group for the API Go application"
SG_RDS_DESCRIPTION="Security Group for the API Go RDS database"

# --- Lógica do Script ---

# 1. Validação de Idempotência: Verifica se os SGs já existem
echo "🔎 Verificando a existência dos Security Groups: ${SG_API_NAME} e ${SG_RDS_NAME}..."
SG_API_ID=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=group-name,Values=${SG_API_NAME}" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "None")
SG_RDS_ID=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=group-name,Values=${SG_RDS_NAME}" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "None")

if [ "$SG_API_ID" != "None" ] && [ "$SG_RDS_ID" != "None" ]; then
    echo "✔️ Ambos os Security Groups já existem. Nenhuma ação será tomada."
    exit 0
elif [ "$SG_API_ID" != "None" ] || [ "$SG_RDS_ID" != "None" ]; then
    echo "⚠️ Apenas um dos Security Groups existe. Para evitar um estado inconsistente, por favor, remova o grupo existente e execute o script novamente."
    exit 1
fi

# 2. Obter a VPC Padrão
echo "🔎 Obtendo a VPC Padrão..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text --region "$AWS_REGION")
if [ -z "$VPC_ID" ]; then
    echo "❌ Erro: Não foi possível encontrar a VPC Padrão."
    exit 1
fi
echo "✔️ Usando a VPC Default: $VPC_ID"
echo "-----------------------------------------------------"

# 3. Criar ambos os Security Groups primeiro para obter seus IDs
echo "🚀 Criando ambos os Security Groups..."
SG_API_ID=$(aws ec2 create-security-group --group-name "$SG_API_NAME" --description "$SG_API_DESCRIPTION" --vpc-id "$VPC_ID" --region "$AWS_REGION" --query 'GroupId' --output text)
echo "  - ${SG_API_NAME} criado com sucesso! ID: $SG_API_ID"

SG_RDS_ID=$(aws ec2 create-security-group --group-name "$SG_RDS_NAME" --description "$SG_RDS_DESCRIPTION" --vpc-id "$VPC_ID" --region "$AWS_REGION" --query 'GroupId' --output text)
echo "  - ${SG_RDS_NAME} criado com sucesso! ID: $SG_RDS_ID"
echo "-----------------------------------------------------"

# 4. Adicionar Regras de Entrada (Inbound) para SG da API
echo "📥 Adicionando regras de entrada para ${SG_API_NAME}..."
aws ec2 authorize-security-group-ingress --group-id "$SG_API_ID" --protocol tcp --port 8000 --cidr 0.0.0.0/0 --region "$AWS_REGION"
aws ec2 authorize-security-group-ingress --group-id "$SG_API_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$AWS_REGION"
aws ec2 authorize-security-group-ingress --group-id "$SG_API_ID" --protocol -1 --port -1 --source-group "$SG_RDS_ID" --region "$AWS_REGION"
echo "✔️ Regras para ${SG_API_NAME} configuradas."
echo "-----------------------------------------------------"

# 5. Adicionar Regras de Entrada (Inbound) para SG do RDS
echo "📥 Adicionando regras de entrada para ${SG_RDS_NAME}..."
aws ec2 authorize-security-group-ingress --group-id "$SG_RDS_ID" --protocol tcp --port 5432 --source-group "$SG_API_ID" --region "$AWS_REGION"
aws ec2 authorize-security-group-ingress --group-id "$SG_RDS_ID" --protocol -1 --port -1 --source-group "$SG_RDS_ID" --region "$AWS_REGION"
echo "✔️ Regras para ${SG_RDS_NAME} configuradas."
echo "-----------------------------------------------------"

# 6. Exibir o resultado final
echo "✅ Processo concluído! Detalhes dos Security Groups:"
aws ec2 describe-security-groups --group-ids "$SG_API_ID" "$SG_RDS_ID" --region "$AWS_REGION"