#!/bin/bash
# Carrega todas as nossas variáveis de nomenclatura do arquivo de configuração.
source ./config.sh

# --- Configurações da Instância EC2 ---
# A Tag de nome e o Key Name agora também vêm do config.sh para consistência.
TAG_NAME="${PROJECT_NAME}-${ENVIRONMENT}-ec2-bastion"
AMI_ID="ami-0cbbe2c6a1bb2ad63"
INSTANCE_TYPE="t2.micro"
SUBNET_ID="subnet-047f0eb2f79b50fba" # Este ID é específico da sua VPC/AZ
IAM_PROFILE_ARN=""

# --- Configurações da Integração ---
SG_CREATION_SCRIPT="create_security_group_go.sh"
# A variável API_SECURITY_GROUP_NAME foi removida. Usaremos $SG_API_NAME do config.sh diretamente.

# --- Lógica do Script ---

# 1. Validação e Preparação do Security Group
echo "-----------------------------------------------------"
# Agora, ele busca pelo nome correto definido no config.sh
echo "🔎 Gerenciando Security Group: ${SG_API_NAME}"
echo "-----------------------------------------------------"

if [ ! -f "$SG_CREATION_SCRIPT" ]; then
    echo "❌ Erro: O script '${SG_CREATION_SCRIPT}' não foi encontrado."
    exit 1
fi

# Tenta obter o ID do SG da API usando o nome do config.sh
FINAL_SG_ID=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=group-name,Values=${SG_API_NAME}" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "None")

if [ "$FINAL_SG_ID" == "None" ]; then
    echo "⚠️ Security Group '${SG_API_NAME}' não encontrado. Executando script de criação..."
    chmod +x "$SG_CREATION_SCRIPT"
    ./"$SG_CREATION_SCRIPT"
    
    # Após a execução, tenta obter o ID novamente
    FINAL_SG_ID=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=group-name,Values=${SG_API_NAME}" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "None")
else
    echo "✔️ Security Group '${SG_API_NAME}' já existe com o ID: ${FINAL_SG_ID}"
fi

if [ "$FINAL_SG_ID" == "None" ]; then
    echo "❌ Erro crítico: Não foi possível criar ou encontrar o Security Group '${SG_API_NAME}'."
    exit 1
fi

# 2. Validação da Instância EC2 (Idempotência)
echo "-----------------------------------------------------"
echo "🔎 Verificando se a instância EC2 '${TAG_NAME}' já existe..."
INSTANCE_ID=$(aws ec2 describe-instances --region "${AWS_REGION}" --filters "Name=tag:Name,Values=${TAG_NAME}" "Name=instance-state-name,Values=running,pending" --query "Reservations[*].Instances[*].Id" --output text)
if [ -n "$INSTANCE_ID" ]; then
    echo "✔️ Uma instância ativa com o nome '${TAG_NAME}' (ID: ${INSTANCE_ID}) já existe."
    exit 0
fi

# 3. Criação da Instância EC2
echo "⚠️ Nenhuma instância ativa encontrada. Prosseguindo com a criação..."
echo "-----------------------------------------------------"
echo "🚀 Iniciando a criação da instância EC2 '${TAG_NAME}' com o SG ID: ${FINAL_SG_ID}"
echo "-----------------------------------------------------"

TAG_SPECIFICATIONS="ResourceType=instance,Tags=[{Key=Name,Value=${TAG_NAME}}]"
AWS_COMMAND="aws ec2 run-instances \
    --region ${AWS_REGION} \
    --image-id ${AMI_ID} \
    --instance-type ${INSTANCE_TYPE} \
    --key-name ${KEY_NAME} \
    --subnet-id ${SUBNET_ID} \
    --security-group-ids ${FINAL_SG_ID} \
    --tag-specifications '${TAG_SPECIFICATIONS}'"

if [ -n "$IAM_PROFILE_ARN" ]; then
    AWS_COMMAND+=" --iam-instance-profile Arn=${IAM_PROFILE_ARN}"
fi

# Executa o comando final
eval $AWS_COMMAND

if [ $? -eq 0 ]; then
  echo "✅ Comando de criação da instância EC2 enviado com sucesso."
else
  echo "❌ Ocorreu um erro ao tentar criar a instância EC2."
fi