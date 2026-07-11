#!/usr/bin/env bash
# ==============================================================================
# 00_preparar_laboratorio_9_aurora_CORREGIDO.sh
# Preparación Práctica 9 - Arquitectura Aurora: optimización, observabilidad y DR
#
# Ejecutar desde AWS CloudShell:
#
#   chmod +x 00_preparar_laboratorio_9_aurora_CORREGIDO.sh
#   ./00_preparar_laboratorio_9_aurora_CORREGIDO.sh
#   source ./lab9_aurora_env.sh
#
# Región estándar: us-west-2
#
# Este script crea o reutiliza el clúster Aurora PostgreSQL primario requerido
# para iniciar la práctica 9. No crea Aurora Global Database por adelantado:
# el ejemplo real de Global Database se crea durante el Reto 6.
# ==============================================================================

set -Eeuo pipefail
trap 'echo "ERROR en línea $LINENO. Revisa el mensaje anterior."' ERR

log(){ echo ""; echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"; }
warn(){ echo "ADVERTENCIA: $*" >&2; }
fail(){ echo "ERROR: $*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || fail "Falta comando requerido: $1"; }

# ------------------------------------------------------------------------------
# Variables estándar
# ------------------------------------------------------------------------------

export AWS_REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}"
export AWS_REGION="${AWS_REGION:-us-west-2}"
export AWS_PRIMARY_REGION="${AWS_PRIMARY_REGION:-$AWS_REGION}"
export AWS_SECONDARY_REGION="${AWS_SECONDARY_REGION:-us-east-1}"

export LAB_PREFIX="${LAB_PREFIX:-aurora-performance-lab}"
export AURORA_CLUSTER_ID="${AURORA_CLUSTER_ID:-${LAB_PREFIX}-cluster}"
export AURORA_INSTANCE_ID="${AURORA_INSTANCE_ID:-${LAB_PREFIX}-instance-1}"
export AURORA_WRITER_INSTANCE="${AURORA_WRITER_INSTANCE:-$AURORA_INSTANCE_ID}"

export AURORA_ENGINE="${AURORA_ENGINE:-aurora-postgresql}"
export AURORA_ENGINE_VERSION="${AURORA_ENGINE_VERSION:-16}"
export AURORA_INSTANCE_CLASS="${AURORA_INSTANCE_CLASS:-db.r6g.large}"

export AURORA_DBNAME="${AURORA_DBNAME:-lab_performance}"
export AURORA_MASTER_USER="${AURORA_MASTER_USER:-labadmin}"
export AURORA_MASTER_PASSWORD="${AURORA_MASTER_PASSWORD:-AuroraLab_2026_Temporal!}"
export AURORA_PORT="${AURORA_PORT:-5432}"

export AURORA_PARAM_GROUP="${AURORA_PARAM_GROUP:-${LAB_PREFIX}-cluster-pg}"
export DB_SUBNET_GROUP_NAME="${DB_SUBNET_GROUP_NAME:-${LAB_PREFIX}-db-subnet-group}"
export AURORA_SG_NAME="${AURORA_SG_NAME:-${LAB_PREFIX}-aurora-sg}"
export ALLOW_CIDR="${ALLOW_CIDR:-0.0.0.0/0}"

export RDS_PROXY_NAME="${RDS_PROXY_NAME:-aurora-pg-proxy-lab}"

export AURORA_GLOBAL_CLUSTER_ID="${AURORA_GLOBAL_CLUSTER_ID:-aurora-lab-global}"
export AURORA_SECONDARY_CLUSTER_ID="${AURORA_SECONDARY_CLUSTER_ID:-aurora-lab-cluster-secondary}"
export AURORA_SECONDARY_INSTANCE_ID="${AURORA_SECONDARY_INSTANCE_ID:-aurora-lab-secondary-instance-1}"
export GLOBAL_SECONDARY_DB_SUBNET_GROUP="${GLOBAL_SECONDARY_DB_SUBNET_GROUP:-aurora-lab-global-secondary-subnet-group}"
export GLOBAL_SECONDARY_SG_NAME="${GLOBAL_SECONDARY_SG_NAME:-aurora-lab-global-secondary-sg}"

ENV_FILE="./lab9_aurora_env.sh"

# ------------------------------------------------------------------------------
# Validaciones base
# ------------------------------------------------------------------------------

log "Validando herramientas"
need aws
need psql
need python3

aws sts get-caller-identity --output table
aws configure set region "$AWS_PRIMARY_REGION"

log "Configuración inicial"
cat <<EOF
AWS_PRIMARY_REGION=$AWS_PRIMARY_REGION
AWS_SECONDARY_REGION=$AWS_SECONDARY_REGION
AURORA_CLUSTER_ID=$AURORA_CLUSTER_ID
AURORA_INSTANCE_ID=$AURORA_INSTANCE_ID
AURORA_DBNAME=$AURORA_DBNAME
AURORA_INSTANCE_CLASS=$AURORA_INSTANCE_CLASS
EOF

# ------------------------------------------------------------------------------
# VPC default, subnets y SG primario
# ------------------------------------------------------------------------------

log "Validando VPC default en $AWS_PRIMARY_REGION"

VPC_ID=$(aws ec2 describe-vpcs \
  --region "$AWS_PRIMARY_REGION" \
  --filters "Name=is-default,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text 2>/dev/null || echo "None")

if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
  log "Creando VPC default..."
  VPC_ID=$(aws ec2 create-default-vpc \
    --region "$AWS_PRIMARY_REGION" \
    --query "Vpc.VpcId" \
    --output text)
fi

log "VPC primaria: $VPC_ID"

log "Validando subnets en al menos dos AZ"

for AZ in $(aws ec2 describe-availability-zones \
  --region "$AWS_PRIMARY_REGION" \
  --query "AvailabilityZones[?State=='available'].ZoneName" \
  --output text | awk '{print $1, $2}'); do

  SUBNET_IN_AZ=$(aws ec2 describe-subnets \
    --region "$AWS_PRIMARY_REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=availability-zone,Values=$AZ" \
    --query "Subnets[0].SubnetId" \
    --output text 2>/dev/null || echo "None")

  if [[ -z "$SUBNET_IN_AZ" || "$SUBNET_IN_AZ" == "None" ]]; then
    aws ec2 create-default-subnet \
      --availability-zone "$AZ" \
      --region "$AWS_PRIMARY_REGION" >/dev/null || true
  fi
done

SUBNET_IDS=$(aws ec2 describe-subnets \
  --region "$AWS_PRIMARY_REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[0:2].SubnetId" \
  --output text)

[[ "$(echo "$SUBNET_IDS" | wc -w)" -ge 2 ]] || fail "Se requieren al menos dos subnets."

log "Subnets primarias: $SUBNET_IDS"

log "Creando o reutilizando Security Group Aurora"

AURORA_SG_ID=$(aws ec2 describe-security-groups \
  --region "$AWS_PRIMARY_REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=$AURORA_SG_NAME" \
  --query "SecurityGroups[0].GroupId" \
  --output text 2>/dev/null || echo "None")

if [[ -z "$AURORA_SG_ID" || "$AURORA_SG_ID" == "None" ]]; then
  AURORA_SG_ID=$(aws ec2 create-security-group \
    --region "$AWS_PRIMARY_REGION" \
    --group-name "$AURORA_SG_NAME" \
    --description "Temporal SG Aurora PostgreSQL Lab 9" \
    --vpc-id "$VPC_ID" \
    --query "GroupId" \
    --output text)

  aws ec2 create-tags \
    --region "$AWS_PRIMARY_REGION" \
    --resources "$AURORA_SG_ID" \
    --tags Key=Lab,Value=09 Key=Name,Value="$AURORA_SG_NAME" >/dev/null
fi

aws ec2 authorize-security-group-ingress \
  --region "$AWS_PRIMARY_REGION" \
  --group-id "$AURORA_SG_ID" \
  --protocol tcp \
  --port "$AURORA_PORT" \
  --cidr "$ALLOW_CIDR" >/dev/null 2>&1 || true

log "Security Group Aurora: $AURORA_SG_ID"

# ------------------------------------------------------------------------------
# DB Subnet Group y Parameter Group
# ------------------------------------------------------------------------------

log "Creando o reutilizando DB Subnet Group"

if ! aws rds describe-db-subnet-groups \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --region "$AWS_PRIMARY_REGION" >/dev/null 2>&1; then

  aws rds create-db-subnet-group \
    --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
    --db-subnet-group-description "Subnet group for Aurora PostgreSQL Lab 9" \
    --subnet-ids $SUBNET_IDS \
    --region "$AWS_PRIMARY_REGION" \
    --tags Key=Lab,Value=09 Key=Component,Value=DBSubnetGroup >/dev/null
fi

log "DB Subnet Group: $DB_SUBNET_GROUP_NAME"

log "Creando o reutilizando Cluster Parameter Group"

if ! aws rds describe-db-cluster-parameter-groups \
  --db-cluster-parameter-group-name "$AURORA_PARAM_GROUP" \
  --region "$AWS_PRIMARY_REGION" >/dev/null 2>&1; then

  aws rds create-db-cluster-parameter-group \
    --db-cluster-parameter-group-name "$AURORA_PARAM_GROUP" \
    --db-parameter-group-family "aurora-postgresql16" \
    --description "Aurora PostgreSQL Lab 9 parameter group" \
    --region "$AWS_PRIMARY_REGION" \
    --tags Key=Lab,Value=09 Key=Component,Value=ParameterGroup >/dev/null
fi

aws rds modify-db-cluster-parameter-group \
  --db-cluster-parameter-group-name "$AURORA_PARAM_GROUP" \
  --region "$AWS_PRIMARY_REGION" \
  --parameters \
    "ParameterName=shared_preload_libraries,ParameterValue=pg_stat_statements,ApplyMethod=pending-reboot" \
    "ParameterName=pg_stat_statements.track,ParameterValue=ALL,ApplyMethod=pending-reboot" \
    "ParameterName=pg_stat_statements.max,ParameterValue=10000,ApplyMethod=pending-reboot" \
    "ParameterName=track_io_timing,ParameterValue=1,ApplyMethod=immediate" >/dev/null || warn "No se pudieron aplicar todos los parámetros."

log "Parameter Group: $AURORA_PARAM_GROUP"

# ------------------------------------------------------------------------------
# Aurora Cluster e instancia writer
# ------------------------------------------------------------------------------

log "Creando o reutilizando Aurora Cluster"

if ! aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_PRIMARY_REGION" >/dev/null 2>&1; then

  aws rds create-db-cluster \
    --db-cluster-identifier "$AURORA_CLUSTER_ID" \
    --engine "$AURORA_ENGINE" \
    --engine-version "$AURORA_ENGINE_VERSION" \
    --master-username "$AURORA_MASTER_USER" \
    --master-user-password "$AURORA_MASTER_PASSWORD" \
    --database-name "$AURORA_DBNAME" \
    --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
    --vpc-security-group-ids "$AURORA_SG_ID" \
    --db-cluster-parameter-group-name "$AURORA_PARAM_GROUP" \
    --backup-retention-period 1 \
    --enable-cloudwatch-logs-exports postgresql \
    --region "$AWS_PRIMARY_REGION" \
    --tags Key=Lab,Value=09 Key=Component,Value=AuroraCluster >/dev/null
fi

aws rds wait db-cluster-available \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_PRIMARY_REGION"

log "Creando o reutilizando instancia writer"

if ! aws rds describe-db-instances \
  --db-instance-identifier "$AURORA_INSTANCE_ID" \
  --region "$AWS_PRIMARY_REGION" >/dev/null 2>&1; then

  aws rds create-db-instance \
    --db-instance-identifier "$AURORA_INSTANCE_ID" \
    --db-cluster-identifier "$AURORA_CLUSTER_ID" \
    --engine "$AURORA_ENGINE" \
    --db-instance-class "$AURORA_INSTANCE_CLASS" \
    --publicly-accessible \
    --enable-performance-insights \
    --performance-insights-retention-period 7 \
    --monitoring-interval 0 \
    --region "$AWS_PRIMARY_REGION" \
    --tags Key=Lab,Value=09 Key=Component,Value=AuroraWriter >/dev/null
fi

aws rds wait db-instance-available \
  --db-instance-identifier "$AURORA_INSTANCE_ID" \
  --region "$AWS_PRIMARY_REGION"

aws rds wait db-cluster-available \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_PRIMARY_REGION"

# ------------------------------------------------------------------------------
# Reconstruir variables Aurora
# ------------------------------------------------------------------------------

log "Reconstruyendo variables Aurora"

AURORA_ENDPOINT=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_PRIMARY_REGION" \
  --query "DBClusters[0].Endpoint" \
  --output text)

AURORA_READER_ENDPOINT=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_PRIMARY_REGION" \
  --query "DBClusters[0].ReaderEndpoint" \
  --output text)

AURORA_WRITER_INSTANCE=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_PRIMARY_REGION" \
  --query "DBClusters[0].DBClusterMembers[?IsClusterWriter==\`true\`].DBInstanceIdentifier | [0]" \
  --output text)

AURORA_INSTANCE_ARN=$(aws rds describe-db-instances \
  --db-instance-identifier "$AURORA_WRITER_INSTANCE" \
  --region "$AWS_PRIMARY_REGION" \
  --query "DBInstances[0].DBInstanceArn" \
  --output text)

AURORA_DBI_RESOURCE_ID=$(aws rds describe-db-instances \
  --db-instance-identifier "$AURORA_WRITER_INSTANCE" \
  --region "$AWS_PRIMARY_REGION" \
  --query "DBInstances[0].DbiResourceId" \
  --output text)

# ------------------------------------------------------------------------------
# Validación SQL y pg_stat_statements
# ------------------------------------------------------------------------------

log "Validando base de datos"

if ! psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require connect_timeout=15" \
  -c "SELECT current_database();" >/dev/null 2>&1; then

  warn "La base $AURORA_DBNAME no respondió. Intentando crearla desde postgres."

  psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require connect_timeout=15" \
    -tc "SELECT 1 FROM pg_database WHERE datname = '$AURORA_DBNAME';" | grep -q 1 \
    || psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require connect_timeout=15" \
      -c "CREATE DATABASE $AURORA_DBNAME;"
fi

log "Validando pg_stat_statements"

if ! psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require connect_timeout=15" \
  -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;" >/dev/null 2>&1; then

  warn "pg_stat_statements no cargó. Reiniciando instancia para aplicar shared_preload_libraries."

  aws rds reboot-db-instance \
    --db-instance-identifier "$AURORA_WRITER_INSTANCE" \
    --region "$AWS_PRIMARY_REGION" >/dev/null

  aws rds wait db-instance-available \
    --db-instance-identifier "$AURORA_WRITER_INSTANCE" \
    --region "$AWS_PRIMARY_REGION"

  psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require connect_timeout=15" \
    -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
fi

# ------------------------------------------------------------------------------
# Estado herramientas y recursos opcionales
# ------------------------------------------------------------------------------

if command -v pgbench >/dev/null 2>&1; then
  pgbench --help >/dev/null 2>&1 || true
  PGBENCH_AVAILABLE="true"
else
  PGBENCH_AVAILABLE="false"
fi

if command -v jq >/dev/null 2>&1; then
  JQ_AVAILABLE="true"
else
  JQ_AVAILABLE="false"
fi

if aws rds describe-db-proxies \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_PRIMARY_REGION" >/dev/null 2>&1; then

  RDS_PROXY_EXISTS="true"
  RDS_PROXY_ENDPOINT=$(aws rds describe-db-proxies \
    --db-proxy-name "$RDS_PROXY_NAME" \
    --region "$AWS_PRIMARY_REGION" \
    --query "DBProxies[0].Endpoint" \
    --output text)
else
  RDS_PROXY_EXISTS="false"
  RDS_PROXY_ENDPOINT=""
fi

if aws rds describe-global-clusters \
  --global-cluster-identifier "$AURORA_GLOBAL_CLUSTER_ID" \
  --region "$AWS_PRIMARY_REGION" >/dev/null 2>&1; then
  AURORA_GLOBAL_EXISTS="true"
else
  AURORA_GLOBAL_EXISTS="false"
fi

# ------------------------------------------------------------------------------
# Archivo de variables
# ------------------------------------------------------------------------------

log "Generando $ENV_FILE"

cat > "$ENV_FILE" <<EOF
#!/usr/bin/env bash
export AWS_REGION='$AWS_PRIMARY_REGION'
export AWS_PRIMARY_REGION='$AWS_PRIMARY_REGION'
export AWS_SECONDARY_REGION='$AWS_SECONDARY_REGION'
export LAB_PREFIX='$LAB_PREFIX'
export AURORA_CLUSTER_ID='$AURORA_CLUSTER_ID'
export AURORA_INSTANCE_ID='$AURORA_INSTANCE_ID'
export AURORA_WRITER_INSTANCE='$AURORA_WRITER_INSTANCE'
export AURORA_ENGINE='$AURORA_ENGINE'
export AURORA_ENGINE_VERSION='$AURORA_ENGINE_VERSION'
export AURORA_INSTANCE_CLASS='$AURORA_INSTANCE_CLASS'
export AURORA_ENDPOINT='$AURORA_ENDPOINT'
export AURORA_READER_ENDPOINT='$AURORA_READER_ENDPOINT'
export AURORA_INSTANCE_ARN='$AURORA_INSTANCE_ARN'
export AURORA_DBI_RESOURCE_ID='$AURORA_DBI_RESOURCE_ID'
export AURORA_PORT='$AURORA_PORT'
export AURORA_DBNAME='$AURORA_DBNAME'
export AURORA_MASTER_USER='$AURORA_MASTER_USER'
export AURORA_MASTER_PASSWORD='$AURORA_MASTER_PASSWORD'
export AURORA_PARAM_GROUP='$AURORA_PARAM_GROUP'
export DB_SUBNET_GROUP_NAME='$DB_SUBNET_GROUP_NAME'
export AURORA_SG_NAME='$AURORA_SG_NAME'
export AURORA_SG_ID='$AURORA_SG_ID'
export VPC_ID='$VPC_ID'
export SUBNET_IDS='$SUBNET_IDS'
export RDS_PROXY_NAME='$RDS_PROXY_NAME'
export RDS_PROXY_EXISTS='$RDS_PROXY_EXISTS'
export RDS_PROXY_ENDPOINT='$RDS_PROXY_ENDPOINT'
export AURORA_GLOBAL_CLUSTER_ID='$AURORA_GLOBAL_CLUSTER_ID'
export AURORA_GLOBAL_EXISTS='$AURORA_GLOBAL_EXISTS'
export AURORA_SECONDARY_CLUSTER_ID='$AURORA_SECONDARY_CLUSTER_ID'
export AURORA_SECONDARY_INSTANCE_ID='$AURORA_SECONDARY_INSTANCE_ID'
export GLOBAL_SECONDARY_DB_SUBNET_GROUP='$GLOBAL_SECONDARY_DB_SUBNET_GROUP'
export GLOBAL_SECONDARY_SG_NAME='$GLOBAL_SECONDARY_SG_NAME'
export PGBENCH_AVAILABLE='$PGBENCH_AVAILABLE'
export JQ_AVAILABLE='$JQ_AVAILABLE'
EOF

chmod 600 "$ENV_FILE"

# ------------------------------------------------------------------------------
# Evidencia
# ------------------------------------------------------------------------------

log "Generando 09_preparacion_validacion.txt"

{
  echo "=== Validación preparación Laboratorio 9 ==="
  echo "Fecha UTC: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo ""
  echo "=== Identidad AWS ==="
  aws sts get-caller-identity --output json
  echo ""
  echo "=== Variables ==="
  echo "AWS_PRIMARY_REGION=$AWS_PRIMARY_REGION"
  echo "AWS_SECONDARY_REGION=$AWS_SECONDARY_REGION"
  echo "AURORA_CLUSTER_ID=$AURORA_CLUSTER_ID"
  echo "AURORA_ENDPOINT=$AURORA_ENDPOINT"
  echo "AURORA_READER_ENDPOINT=$AURORA_READER_ENDPOINT"
  echo "AURORA_WRITER_INSTANCE=$AURORA_WRITER_INSTANCE"
  echo "AURORA_DBI_RESOURCE_ID=$AURORA_DBI_RESOURCE_ID"
  echo "RDS_PROXY_EXISTS=$RDS_PROXY_EXISTS"
  echo "AURORA_GLOBAL_EXISTS=$AURORA_GLOBAL_EXISTS"
  echo "PGBENCH_AVAILABLE=$PGBENCH_AVAILABLE"
  echo "JQ_AVAILABLE=$JQ_AVAILABLE"
  echo ""
  echo "=== SQL ==="
  psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require connect_timeout=15" \
    -c "SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;" \
    -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_stat_statements';" \
    -c "SELECT name, setting FROM pg_settings WHERE name IN ('shared_preload_libraries','track_io_timing','pg_stat_statements.track') ORDER BY name;"
} | tee 09_preparacion_validacion.txt

log "Preparación completada"

cat <<EOF

Archivos generados:
  ./lab9_aurora_env.sh
  ./09_preparacion_validacion.txt

Siguiente paso:
  source ./lab9_aurora_env.sh

EOF
