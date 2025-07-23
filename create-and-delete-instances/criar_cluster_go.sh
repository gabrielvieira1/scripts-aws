#!/bin/bash
source ./config.sh # Carrega todas as nossas variáveis

CLUSTER_NAME="api-go-cluster" # Nome do novo cluster de teste
REGION="us-east-1"

# Verifica se o cluster já existe
EXISTING_CLUSTER=$(aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$REGION" --query "clusters[?status=='ACTIVE'].clusterName" --output text)

if [ -n "$EXISTING_CLUSTER" ]; then
    echo "✔️ Cluster ECS '${CLUSTER_NAME}' já existe."
else
    echo "🚀 Criando Cluster ECS '${CLUSTER_NAME}'..."
    aws ecs create-cluster --cluster-name "$CLUSTER_NAME" --region "$REGION" > /dev/null
    echo "✅ Cluster criado com sucesso!"
fi