echo "=== Validar conexión vía RDS Proxy usando CloudShell VPC Environment ==="

set -euo pipefail

if [ -f ./lab6_aurora_env.sh ]; then
  source ./lab6_aurora_env.sh
fi

mkdir -p "${LAB_DIR:-.}/results"

echo "=== Validar variables requeridas ==="

: "${AWS_REGION:?Falta AWS_REGION. Ejecuta: source ./lab6_aurora_env.sh}"
: "${RDS_PROXY_NAME:?Falta RDS_PROXY_NAME. Ejecuta: source ./lab6_aurora_env.sh}"
: "${AURORA_PORT:?Falta AURORA_PORT. Ejecuta: source ./lab6_aurora_env.sh}"
: "${AURORA_DBNAME:?Falta AURORA_DBNAME. Ejecuta: source ./lab6_aurora_env.sh}"
: "${AURORA_MASTER_USER:?Falta AURORA_MASTER_USER. Ejecuta: source ./lab6_aurora_env.sh}"
: "${AURORA_MASTER_PASSWORD:?Falta AURORA_MASTER_PASSWORD. Ejecuta: source ./lab6_aurora_env.sh}"

echo "=== Obtener datos actuales del RDS Proxy ==="

export RDS_PROXY_ENDPOINT=$(aws rds describe-db-proxies \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_REGION" \
  --query "DBProxies[0].Endpoint" \
  --output text)

export RDS_PROXY_VPC_ID=$(aws rds describe-db-proxies \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_REGION" \
  --query "DBProxies[0].VpcId" \
  --output text)

export RDS_PROXY_SUBNET_IDS=$(aws rds describe-db-proxies \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_REGION" \
  --query "join(',', DBProxies[0].VpcSubnetIds)" \
  --output text)

export RDS_PROXY_SECURITY_GROUP_IDS=$(aws rds describe-db-proxies \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_REGION" \
  --query "join(',', DBProxies[0].VpcSecurityGroupIds)" \
  --output text)

export RDS_PROXY_FIRST_SUBNET_ID=$(echo "$RDS_PROXY_SUBNET_IDS" | cut -d',' -f1)
export RDS_PROXY_FIRST_SG_ID=$(echo "$RDS_PROXY_SECURITY_GROUP_IDS" | cut -d',' -f1)

echo "Proxy endpoint: $RDS_PROXY_ENDPOINT"
echo "Proxy VPC:      $RDS_PROXY_VPC_ID"
echo "Proxy subnets:  $RDS_PROXY_SUBNET_IDS"
echo "Proxy SGs:      $RDS_PROXY_SECURITY_GROUP_IDS"

echo "=== Crear Security Group para CloudShell VPC Environment si no existe ==="

export CLOUDSHELL_VPC_SG_NAME="${CLOUDSHELL_VPC_SG_NAME:-lab6-cloudshell-vpc-rds-proxy-sg}"

export CLOUDSHELL_VPC_SG_ID=$(aws ec2 describe-security-groups \
  --region "$AWS_REGION" \
  --filters "Name=vpc-id,Values=$RDS_PROXY_VPC_ID" "Name=group-name,Values=$CLOUDSHELL_VPC_SG_NAME" \
  --query "SecurityGroups[0].GroupId" \
  --output text 2>/dev/null || true)

if [ -z "$CLOUDSHELL_VPC_SG_ID" ] || [ "$CLOUDSHELL_VPC_SG_ID" = "None" ]; then
  export CLOUDSHELL_VPC_SG_ID=$(aws ec2 create-security-group \
    --region "$AWS_REGION" \
    --group-name "$CLOUDSHELL_VPC_SG_NAME" \
    --description "Temporal SG para CloudShell VPC Environment hacia RDS Proxy Lab 6" \
    --vpc-id "$RDS_PROXY_VPC_ID" \
    --query "GroupId" \
    --output text)

  echo "Security Group creado para CloudShell VPC Environment: $CLOUDSHELL_VPC_SG_ID"
else
  echo "Security Group existente para CloudShell VPC Environment: $CLOUDSHELL_VPC_SG_ID"
fi

echo "=== Permitir que CloudShell VPC Environment llegue al Security Group del proxy ==="

for PROXY_SG in $(echo "$RDS_PROXY_SECURITY_GROUP_IDS" | tr ',' ' '); do
  aws ec2 authorize-security-group-ingress \
    --region "$AWS_REGION" \
    --group-id "$PROXY_SG" \
    --protocol tcp \
    --port "$AURORA_PORT" \
    --source-group "$CLOUDSHELL_VPC_SG_ID" >/dev/null 2>&1 \
    || echo "Regla ya existente o no duplicable en $PROXY_SG. Continuando."
done

echo "=== Valores para crear CloudShell VPC Environment ==="

cat <<EOF | tee "${LAB_DIR:-.}/results/cloudshell_vpc_environment_values.txt"

Crea o abre una pestaña de AWS CloudShell como VPC Environment con estos valores:

Name:            lab6-rds-proxy-vpc-shell
Region:          $AWS_REGION
VPC:             $RDS_PROXY_VPC_ID
Subnet:          $RDS_PROXY_FIRST_SUBNET_ID
Security Group:  $CLOUDSHELL_VPC_SG_ID

Después de crear esa pestaña VPC Environment, vuelve a ejecutar este mismo bloque allí.
EOF

echo "=== Prueba TCP rápida al endpoint del proxy ==="

TCP_OK="false"

if command -v nc >/dev/null 2>&1; then
  if nc -vz -w 10 "$RDS_PROXY_ENDPOINT" "$AURORA_PORT"; then
    TCP_OK="true"
  fi
else
  timeout 10 bash -c "cat < /dev/null > /dev/tcp/$RDS_PROXY_ENDPOINT/$AURORA_PORT" >/dev/null 2>&1 \
    && TCP_OK="true" || TCP_OK="false"
fi

if [ "$TCP_OK" != "true" ]; then
  echo ""
  echo "Aún no hay conectividad TCP al RDS Proxy desde esta sesión."
  echo "Esto es esperado si estás en CloudShell normal."
  echo ""
  echo "Acción requerida:"
  echo "1. En AWS CloudShell, abre una nueva pestaña."
  echo "2. Selecciona: Create VPC environment."
  echo "3. Usa los valores guardados en:"
  echo "   ${LAB_DIR:-.}/results/cloudshell_vpc_environment_values.txt"
  echo "4. En la nueva pestaña VPC Environment, ejecuta:"
  echo "   source ./lab6_aurora_env.sh"
  echo "5. Vuelve a ejecutar este bloque del Reto 5."
  echo ""
  exit 2
fi

echo "Conectividad TCP hacia RDS Proxy confirmada."

echo "=== Validar conexión SQL vía RDS Proxy ==="

psql "host=$RDS_PROXY_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require connect_timeout=10" \
  -c "SELECT 'Conectado via RDS Proxy' AS estado;" \
  -c "SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;" \
  2>&1 | tee "${LAB_DIR:-.}/results/proxy_connection_check.txt"

echo "=== Ver actividad desde conexión directa ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require connect_timeout=10" \
  -c "SELECT
        pid,
        usename,
        client_addr,
        state,
        backend_type,
        left(query, 80) AS query
      FROM pg_stat_activity
      WHERE usename = current_user
      ORDER BY backend_start DESC
      LIMIT 10;" \
  | tee "${LAB_DIR:-.}/results/pg_stat_activity_proxy_check.txt"

echo "=== Validación final del Reto 5 ==="

grep "Conectado via RDS Proxy" "${LAB_DIR:-.}/results/proxy_connection_check.txt"
