#!/bin/bash

# --- Configurações Globais ---
export AWS_REGION="us-east-1"
export PROJECT_NAME="api-go"
export ENVIRONMENT="dev"

# --- Nomenclatura dos Recursos ---

# Rede e Segurança
export SG_API_NAME="${PROJECT_NAME}-${ENVIRONMENT}-sg-app"
export SG_RDS_NAME="${PROJECT_NAME}-${ENVIRONMENT}-sg-db"
export KEY_NAME="API-Go-Dev"

# Banco de Dados (RDS)
export RDS_INSTANCE_ID="${PROJECT_NAME}-${ENVIRONMENT}-rds-main"
export DB_SUBNET_GROUP_NAME="${PROJECT_NAME}-${ENVIRONMENT}-sng-private"

# Aplicação (ECS)
export ECS_CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-ecs-cluster"
export ECS_TASK_FAMILY="${PROJECT_NAME}-${ENVIRONMENT}-taskdef-app"
export ECS_SERVICE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-ecs-svc-app"