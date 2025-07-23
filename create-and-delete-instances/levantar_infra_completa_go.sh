#!/bin/bash
set -e
source ./config.sh

# --- INÍCIO DA EXECUÇÃO ---
echo "🚀 INICIANDO O PROVISIONAMENTO COMPLETO DO AMBIENTE '${ENVIRONMENT}'..."
echo "-----------------------------------------------------"

# PASSO 1: Segurança de Rede
echo "PASSO 1 de 5: Provisionando a Camada de Segurança (Security Groups)..."
./create_security_group_go.sh
echo "-----------------------------------------------------"

# PASSO 2: Load Balancer (depende da SG)
echo "PASSO 2 de 5: Provisionando o Application Load Balancer..."
# Captura o ARN do Target Group que o script criar_alb.sh retorna
export TARGET_GROUP_ARN=$(./criar_alb.sh)
if [ -z "$TARGET_GROUP_ARN" ]; then
    echo "❌ Falha ao obter o ARN do Target Group."
    exit 1
fi
echo "✔️  Target Group ARN: ${TARGET_GROUP_ARN}"
echo "-----------------------------------------------------"

# PASSO 3: Camada de Dados (RDS)
echo "PASSO 3 de 5: Provisionando a Camada de Dados (RDS)..."
./create_rds_go.sh
echo "-----------------------------------------------------"

# PASSO 4: Instância EC2 de Apoio
echo "PASSO 4 de 5: Provisionando a Instância EC2 de Apoio/Bastion..."
./criar_ec2_api_go.sh
echo "-----------------------------------------------------"

# PASSO 5: Camada de Aplicação (ECS)
echo "PASSO 5 de 5: Provisionando a Camada de Aplicação (ECS)..."
# O script de deploy agora usará a variável TARGET_GROUP_ARN
./deploy_api_go.sh
echo "-----------------------------------------------------"

echo "✅ SUCESSO! Provisionamento completo da infraestrutura concluído."