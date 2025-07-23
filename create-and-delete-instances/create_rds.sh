#!/bin/bash

# --- Configurações da Instância RDS ---
DB_INSTANCE_ID="db-api-go-test"
DB_NAME="root"
MASTER_USERNAME="postgres"
DB_INSTANCE_CLASS="db.t4g.micro"
ALLOCATED_STORAGE=20
ENGINE_VERSION="13.21"
AWS_REGION="us-east-1"
DB_SUBNET_GROUP_NAME="meu-db-subnet-group"

# ==================================================================
# FUNÇÃO: Busca e imprime os detalhes de conexão.
# Argumento 1: ID da instância.
# Argumento 2 (Opcional): A senha a ser impressa.
# ==================================================================
function get_and_print_connection_details() {
    local instance_id="$1"
    local password_to_print="$2"

    echo "✅ Obtendo detalhes da conexão para '${instance_id}'..."
    
    # Aguarda a instância estar em um estado estável antes de buscar detalhes
    echo "⏳ Verificando o status da instância..."
    aws rds wait db-instance-available --db-instance-identifier "${instance_id}" --region "${AWS_REGION}"
    if [ $? -ne 0 ]; then
      aws rds wait db-instance-stopped --db-instance-identifier "${instance_id}" --region "${AWS_REGION}"
    fi

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

# Validação: Verifica se a instância RDS já existe
echo "🔎 Verificando se a instância RDS '${DB_INSTANCE_ID}' já existe..."
aws rds describe-db-instances --db-instance-identifier "${DB_INSTANCE_ID}" --region "${AWS_REGION}" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✔️ A instância RDS '${DB_INSTANCE_ID}' já existe."
    get_and_print_connection_details "${DB_INSTANCE_ID}" # Chama a função sem a senha
    exit 0 # Sai do script com sucesso
fi

# Se não existe, prossegue com a criação
echo "⚠️ Instância RDS não encontrada. Prosseguindo com a criação..."
echo "-----------------------------------------------------"

# Lógica de busca de rede (VPC, SG, Subnet Group)
# ... (código para obter VPC_ID, DEFAULT_SG_ID e criar o subnet group) ...
# (O código desta seção foi omitido para brevity, mas ele está no script completo abaixo)
echo "🔎 Buscando configurações de rede na região ${AWS_REGION}..."
echo "Usando a versão de engine: ${ENGINE_VERSION}"
VPC_ID=$(aws ec2 describe-vpcs --region "${AWS_REGION}" --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text)
if [ -z "$VPC_ID" ]; then echo "❌ Erro: Não foi possível encontrar a VPC Padrão."; exit 1; fi
echo "✔️ VPC Padrão encontrada: ${VPC_ID}"
DEFAULT_SG_ID=$(aws ec2 describe-security-groups --region "${AWS_REGION}" --filters "Name=vpc-id,Values=${VPC_ID}" "Name=group-name,Values=default" --query "SecurityGroups[0].GroupId" --output text)
if [ -z "$DEFAULT_SG_ID" ]; then echo "❌ Erro: Não foi possível encontrar o Security Group 'default'."; exit 1; fi
echo "✔️ Security Group Padrão encontrado: ${DEFAULT_SG_ID}"
aws rds describe-db-subnet-groups --db-subnet-group-name "${DB_SUBNET_GROUP_NAME}" --region "${AWS_REGION}" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "⚠️ DB Subnet Group '${DB_SUBNET_GROUP_NAME}' não encontrado. Criando um novo..."
    SUBNET_IDS=$(aws ec2 describe-subnets --region "${AWS_REGION}" --filters "Name=vpc-id,Values=${VPC_ID}" --query "Subnets[*].SubnetId" --output text)
    if [ -z "$SUBNET_IDS" ]; then echo "❌ Erro: Nenhuma sub-rede encontrada na VPC Padrão."; exit 1; fi
    aws rds create-db-subnet-group --region "${AWS_REGION}" --db-subnet-group-name "${DB_SUBNET_GROUP_NAME}" --db-subnet-group-description "Subnet group para o banco de dados da aplicação" --subnet-ids ${SUBNET_IDS}
    if [ $? -eq 0 ]; then echo "✔️ DB Subnet Group criado com sucesso."; else echo "❌ Erro ao criar o DB Subnet Group."; exit 1; fi
else
    echo "✔️ DB Subnet Group '${DB_SUBNET_GROUP_NAME}' já existe."
fi

# Entrada Segura de Senha
echo "-----------------------------------------------------"
while true; do
    read -sp "Digite a senha do usuário master para o RDS: " MASTER_PASSWORD && echo
    read -sp "Confirme a senha: " MASTER_PASSWORD_CONFIRM && echo
    if [ "$MASTER_PASSWORD" = "$MASTER_PASSWORD_CONFIRM" ] && [ -n "$MASTER_PASSWORD" ]; then break; else echo "As senhas não coincidem ou estão em branco. Tente novamente."; fi
done

# Criação da Instância
echo "-----------------------------------------------------"
echo "🚀 Iniciando a criação da instância RDS: ${DB_INSTANCE_ID}"
echo "-----------------------------------------------------"
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
  --vpc-security-group-ids "${DEFAULT_SG_ID}" \
  --db-subnet-group-name "${DB_SUBNET_GROUP_NAME}" \
  --no-publicly-accessible \
  --no-multi-az \
  --storage-encrypted \
  --backup-retention-period 1 \
  --enable-performance-insights \
  --tags Key=Owner,Value=Gabriel Key=Project,Value=Learning

if [ $? -ne 0 ]; then
    echo "❌ Ocorreu um erro ao tentar criar a instância RDS."
    exit 1
fi

# Após a criação, chama a função para imprimir os detalhes, passando a senha.
get_and_print_connection_details "${DB_INSTANCE_ID}" "${MASTER_PASSWORD}"