# ... (início do script)

# 4. Prepara a definição do serviço com rede e ALB dinâmicos
echo "4. Preparando a definição do serviço com rede e ALB dinâmicos..."
# ... (lógica para descobrir VPC e Subnets) ...

# 4.2. Usa 'jq' para criar um arquivo de serviço temporário com TODOS os valores dinâmicos
jq \
  --arg sg_id "$SG_API_ID" \
  --argjson subnets "$SUBNET_IDS_JSON" \
  --arg tg_arn "$TARGET_GROUP_ARN" \
  --arg cluster_name "$ECS_CLUSTER_NAME" \
  --arg service_name "$ECS_SERVICE_NAME" \
  --arg task_family "$ECS_TASK_FAMILY" \
  '.cluster = $cluster_name | .serviceName = $service_name | .taskDefinition = $task_family | .loadBalancers[0].targetGroupArn = $tg_arn | .networkConfiguration.awsvpcConfiguration.securityGroups = [$sg_id] | .networkConfiguration.awsvpcConfiguration.subnets = $subnets' \
  "$SERVICE_JSON" > "$TEMP_SERVICE_JSON"

echo "  - Arquivo de configuração de serviço temporário (${TEMP_SERVICE_JSON}) criado com sucesso."

# 5. Cria ou Atualiza o Serviço ECS
# ... (resto do script sem alterações) ...