role_name="role-acesso-ssm"
policy_name="AmazonSSMManagedInstanceCore"
policy_arn="arn:aws:iam::aws:policy/$policy_name"
endpoint_url="http://localhost.localstack.cloud:4566"  # Defina o endpoint do LocalStack

# Verifica se a role já existe, se não, tenta criar
if aws iam get-role --role-name "$role_name" --endpoint-url=$endpoint_url &> /dev/null; then
    echo "A IAM role $role_name já existe."
else
    echo "A IAM role $role_name não existe. Criando..."
    aws iam create-role --role-name $role_name --assume-role-policy-document file://ec2_principal.json --endpoint-url=$endpoint_url || { echo "Erro ao criar role"; exit 1; }

    # Cria o perfil de instância no LocalStack
    aws iam create-instance-profile --instance-profile-name $role_name --endpoint-url=$endpoint_url || { echo "Erro ao criar perfil de instância"; exit 1; }

    # Adiciona a função IAM ao perfil de instância no LocalStack
    aws iam add-role-to-instance-profile --instance-profile-name $role_name --role-name $role_name --endpoint-url=$endpoint_url || { echo "Erro ao adicionar role ao perfil de instância"; exit 1; }

    # Anexa a política à role no LocalStack
    if aws iam attach-role-policy --role-name $role_name --policy-arn $policy_arn --endpoint-url=$endpoint_url; then
        echo "Política $policy_name anexada com sucesso à role $role_name."
    else
        echo "Erro ao anexar a política $policy_name à role $role_name. A política pode não estar disponível no LocalStack."
        exit 1
    fi
fi
