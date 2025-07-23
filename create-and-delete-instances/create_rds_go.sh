#!/bin/bash

# Garante que o script pare imediatamente se qualquer comando falhar.
set -e
# Carrega todas as nossas variáveis de nomenclatura do arquivo de configuração.
source ./config.sh

# --- Configurações da Instância RDS ---
DB_INSTANCE_ID="${RDS_INSTANCE_ID}"
DB_SUBNET_GROUP_NAME="${DB_SUBNET_GROUP_NAME}"
DB_NAME="root" 
MASTER_USERNAME="postgres"
DB_INSTANCE_CLASS="db.t4g.micro"
ALLOCATED_STORAGE=20
ENGINE_VERSION="13.21"

# --- Configurações da Integração ---
SG_CREATION_SCRIPT="create_security_group_go.sh"

# ==================================================================
# FUNÇÃO: Busca e imprime os detalhes de conexão.
# ==================================================================
function get_and_print_connection_details() {
    local instance_id="$1"
    local password_to_print="$2"
    echo "✅ Obtendo detalhes da conexão para '${instance_id}'..."
    echo "⏳ Verificando o status da instância..."
    aws rds wait db-instance-available --db-instance-identifier "${instance_id}" --region "${AWS_REGION}" || aws rds wait db-instance-stopped --db-instance-identifier "${instance_id}" --region "${AWS_REGION}"
    
    DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "${instance_id}" --query "DBInstances[0].Endpoint.Address" --output text --region "${AWS_REGION}")
    DB_PORT=$(aws rds describe-db-instances --db-instance-identifier "${instance_id}" --query "DBInstances[0].Endpoint.Port" --output text --region "${AWS_REGION}")
    DB_USER=$(aws rds describe-db-instances --db-instance-identifier "${instance_id}" --query "DBInstances[0].MasterUsername" --output text --region "${AWS_REGION}")
    DB_NAME_FROM_INSTANCE=$(aws rds describe-db-instances --db-instance-identifier "${instance_id}" --query "DBInstances[0].DBName" --output text --region "${AWS_REGION}")
    
    echo ""
    echo "-----------------------------------------------------"
    echo "✔️ Detalhes da Conexão do Banco de Dados:"
    echo "-----------------------------------------------------"
    echo "DB_HOST_PROD=${DB_ENDPOINT}"
    echo "DB_PORT_PROD=${DB_PORT}"
    echo "DB_USER_PROD=${DB_USER}"
    echo "DB_NAME_PROD=${DB_NAME_FROM_INSTANCE}"
    if [ -n "$password_to_print" ]; then
        echo "DB_PASSWORD_PROD=${password_to_print}"
        echo "-----------------------------------------------------"
        echo "⚠️ Atenção: Guarde a senha em um local seguro."
    else
        echo "DB_PASSWORD_PROD=[IMPOSSÍVEL OBTER - A senha não pode ser recuperada de uma instância existente]"
        echo "-----------------------------------------------------"
    fi
}

# ==================================================================
# LÓGICA PRINCIPAL DO SCRIPT
# ==================================================================

# 1. Validação da Instância RDS (Idempotência)
echo "🔎 Verificando se a instância RDS '${DB_INSTANCE_ID}' já existe..."
if aws rds describe-db-instances --db-instance-identifier "${DB_INSTANCE_ID}" --region "${AWS_REGION}" > /dev/null 2>&1; then
    echo "✔️ A instância RDS '${DB_INSTANCE_ID}' já existe."
    get_and_print_connection_details "${DB_INSTANCE_ID}"
    exit 0
fi
echo "⚠️ Instância RDS não encontrada. Prosseguindo com a criação..."
echo "-----------------------------------------------------"

# 2. Validação e Preparação do Security Group
echo "🔎 Gerenciando Security Group: ${SG_RDS_NAME}"
if [ ! -f "$SG_CREATION_SCRIPT" ]; then echo "❌ Erro: O script '${SG_CREATION_SCRIPT}' não foi encontrado."; exit 1; fi
FINAL_RDS_SG_ID=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=group-name,Values=${SG_RDS_NAME}" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "None")
if [ "$FINAL_RDS_SG_ID" == "None" ]; then
    echo "⚠️ Security Group '${SG_RDS_NAME}' não encontrado. Executando script de criação..."
    chmod +x "$SG_CREATION_SCRIPT" && ./"$SG_CREATION_SCRIPT"
    FINAL_RDS_SG_ID=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=group-name,Values=${SG_RDS_NAME}" --query "SecurityGroups[0].GroupId" --output text)
else
    echo "✔️ Security Group '${SG_RDS_NAME}' já existe com o ID: ${FINAL_RDS_SG_ID}"
fi
if [ "$FINAL_RDS_SG_ID" == "None" ]; then echo "❌ Erro crítico: Não foi possível criar ou encontrar o Security Group '${SG_RDS_NAME}'."; exit 1; fi
echo "-----------------------------------------------------"

# 3. Preparação da Rede (DB Subnet Group)
echo "🔎 Gerenciando DB Subnet Group: ${DB_SUBNET_GROUP_NAME}"
VPC_ID=$(aws ec2 describe-vpcs --region "${AWS_REGION}" --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text)
if [ -z "$VPC_ID" ]; then echo "❌ Erro: Não foi possível encontrar a VPC Padrão."; exit 1; fi
if ! aws rds describe-db-subnet-groups --db-subnet-group-name "${DB_SUBNET_GROUP_NAME}" --region "${AWS_REGION}" > /dev/null 2>&1; then
    echo "⚠️ DB Subnet Group não encontrado. Criando um novo..."
    SUBNET_IDS=$(aws ec2 describe-subnets --region "${AWS_REGION}" --filters "Name=vpc-id,Values=${VPC_ID}" --query "Subnets[*].SubnetId" --output text)
    if [ -z "$SUBNET_IDS" ]; then echo "❌ Erro: Nenhuma sub-rede encontrada."; exit 1; fi
    aws rds create-db-subnet-group --region "${AWS_REGION}" --db-subnet-group-name "${DB_SUBNET_GROUP_NAME}" --db-subnet-group-description "Subnet group for ${PROJECT_NAME}-${ENVIRONMENT}" --subnet-ids ${SUBNET_IDS}
    echo "✔️ DB Subnet Group criado com sucesso."
else
    echo "✔️ DB Subnet Group já existe."
fi
echo "-----------------------------------------------------"

# 4. Entrada Segura de Senha
echo "🔎 Coletando senha do usuário master..."
if [ -z "$DB_PASSWORD_PROD" ]; then
    echo "   (Variável DB_PASSWORD_PROD não encontrada. Solicitando senha interativamente)"
    while true; do
        read -sp "   Digite a senha do usuário master para o RDS: " MASTER_PASSWORD && echo
        read -sp "   Confirme a senha: " MASTER_PASSWORD_CONFIRM && echo
        if [ "$MASTER_PASSWORD" = "$MASTER_PASSWORD_CONFIRM" ] && [ -n "$MASTER_PASSWORD" ]; then break; else echo "   As senhas não coincidem ou estão em branco. Tente novamente."; fi
    done
else
    echo "   ✔️ Usando a senha provida pela variável de ambiente DB_PASSWORD_PROD."
    MASTER_PASSWORD="$DB_PASSWORD_PROD"
fi
echo "-----------------------------------------------------"

# 5. Criação da Instância RDS
echo "🚀 Iniciando a criação da instância RDS '${DB_INSTANCE_ID}' com o SG ID: ${FINAL_RDS_SG_ID}"
aws rds create-db-instance \
  --region "${AWS_REGION}" \
  --db-instance-identifier "${DB_INSTANCE_ID}" \
  --db-name "${DB_NAME}" \
  --master-username "${MASTER_USERNAME}" \
  --master-user-password "${MASTER_PASSWORD}" \
  --db-instance-class "${DB_INSTANCE_CLASS}" \
  --engine "postgres" \
  --engine-version "${ENGINE_VERSION}" \
  --allocated-storage ${ALLOCATED_STORAGE} \
  --storage-type "gp2" \
  --vpc-security-group-ids "${FINAL_RDS_SG_ID}" \
  --db-subnet-group-name "${DB_SUBNET_GROUP_NAME}" \
  --no-publicly-accessible \
  --no-multi-az \
  --storage-encrypted \
  --backup-retention-period 1 \
  --enable-performance-insights \
  --tags Key=Owner,Value=Gabriel Key=Project,Value=${PROJECT_NAME}

# 6. Após a criação, chama a função para imprimir os detalhes
get_and_print_connection_details "${DB_INSTANCE_ID}" "${MASTER_PASSWORD}"