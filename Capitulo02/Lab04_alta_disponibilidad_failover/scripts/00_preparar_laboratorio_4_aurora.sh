#!/usr/bin/env bash
# ==============================================================================
# Script: 00_preparar_laboratorio_4_aurora.sh
# Propósito: Preparar los prerrequisitos técnicos del Laboratorio 4
#            "Alta disponibilidad, endpoints y failover" en AWS CloudShell.
#
# Ejecutar en AWS CloudShell:
#   chmod +x 00_preparar_laboratorio_4_aurora.sh
#   ./00_preparar_laboratorio_4_aurora.sh
#   source ./lab4_aurora_env.sh
#
# Opcional, antes de ejecutar puedes sobrescribir valores:
#   export AWS_REGION="us-west-2"
#   export AURORA_MASTER_PASSWORD='Cambia_Esta_Clave_2026!'
#   export ALLOW_CIDR="0.0.0.0/0"
#   ./00_preparar_laboratorio_4_aurora.sh
#
# Importante:
# - Este script crea recursos que pueden generar costo en AWS.
# - Para practicar failover, asegura una instancia writer y una instancia reader.
# - Para facilitar la conexión desde CloudShell, las instancias se crean públicas.
# - El Security Group permite TCP/5432 desde 0.0.0.0/0 para laboratorio temporal.
# - Esta versión trabaja en la raíz actual de CloudShell.
# ==============================================================================

set -Eeuo pipefail

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✖ %s\033[0m\n' "$*" >&2; exit 1; }

export AWS_REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}"
export AWS_REGION="${AWS_REGION:-us-west-2}"

export LAB_PREFIX="${LAB_PREFIX:-aurora-performance-lab}"
export AURORA_CLUSTER_ID="${AURORA_CLUSTER_ID:-${LAB_PREFIX}-cluster}"
export AURORA_INSTANCE_ID="${AURORA_INSTANCE_ID:-${LAB_PREFIX}-instance-1}"
export AURORA_READER_INSTANCE_ID="${AURORA_READER_INSTANCE_ID:-${AURORA_CLUSTER_ID}-reader-1}"
export AURORA_PARAM_GROUP="${AURORA_PARAM_GROUP:-${LAB_PREFIX}-cluster-pg}"
export DB_SUBNET_GROUP_NAME="${DB_SUBNET_GROUP_NAME:-${LAB_PREFIX}-db-subnet-group}"
export AURORA_SG_NAME="${AURORA_SG_NAME:-${LAB_PREFIX}-aurora-sg}"

export AURORA_DBNAME="${AURORA_DBNAME:-lab_performance}"
export AURORA_PORT="${AURORA_PORT:-5432}"
export AURORA_MASTER_USER="${AURORA_MASTER_USER:-labadmin}"
export AURORA_MASTER_PASSWORD="${AURORA_MASTER_PASSWORD:-AuroraLab_2026_Temporal!}"
export AURORA_ENGINE="${AURORA_ENGINE:-aurora-postgresql}"
export AURORA_ENGINE_VERSION="${AURORA_ENGINE_VERSION:-16}"
export AURORA_INSTANCE_CLASS="${AURORA_INSTANCE_CLASS:-db.r6g.large}"
export ALLOW_CIDR="${ALLOW_CIDR:-0.0.0.0/0}"

export LAB_WORKDIR="${LAB_WORKDIR:-$PWD}"
export WORKDIR="${WORKDIR:-$LAB_WORKDIR}"
ENV_FILE="${ENV_FILE:-./lab4_aurora_env.sh}"

log "Parámetros de preparación del Laboratorio 4"

cat <<EOF
Región AWS:            $AWS_REGION
Cluster ID:            $AURORA_CLUSTER_ID
Writer Instance ID:    $AURORA_INSTANCE_ID
Reader Instance ID:    $AURORA_READER_INSTANCE_ID
DB Name:               $AURORA_DBNAME
Usuario master:        $AURORA_MASTER_USER
Directorio trabajo:    $LAB_WORKDIR
Archivo de variables:  $ENV_FILE
CIDR autorizado:       $ALLOW_CIDR
EOF

log "Validando identidad AWS y herramientas base"

aws sts get-caller-identity --output table >/dev/null \
  || fail "No se pudo validar la identidad AWS. Revisa permisos o sesión de CloudShell."

ok "Identidad AWS validada"

aws configure set region "$AWS_REGION" >/dev/null
ok "Región configurada: $AWS_REGION"

if ! command -v jq >/dev/null 2>&1; then
  warn "jq no está disponible. Intentando instalar jq."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y jq
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y jq
  else
    fail "No se encontró dnf ni yum para instalar jq."
  fi
fi
ok "jq disponible: $(jq --version)"

if ! command -v psql >/dev/null 2>&1; then
  warn "psql no está disponible. Intentando instalar cliente PostgreSQL."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y postgresql15 || sudo dnf install -y postgresql16 || sudo dnf install -y postgresql
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y postgresql15 || sudo yum install -y postgresql16 || sudo yum install -y postgresql
  else
    fail "No se encontró dnf ni yum para instalar psql."
  fi
fi
ok "psql disponible: $(psql --version)"

if ! command -v python3 >/dev/null 2>&1; then
  fail "python3 no está disponible en CloudShell."
fi
ok "python3 disponible: $(python3 --version 2>&1)"

log "Validando psycopg2 para el monitor de failover"

if python3 - <<'PY' >/dev/null 2>&1
import psycopg2
PY
then
  ok "psycopg2 ya está disponible"
else
  warn "psycopg2 no está disponible. Intentando instalar psycopg2-binary."
  python3 -m pip --version >/dev/null 2>&1 || python3 -m ensurepip >/dev/null 2>&1 || true

  if [[ -n "${VIRTUAL_ENV:-}" ]]; then
    python3 -m pip install psycopg2-binary >/dev/null
  else
    python3 -m pip install --user psycopg2-binary >/dev/null 2>&1 \
      || python3 -m pip install psycopg2-binary >/dev/null
  fi

  ok "psycopg2-binary instalado"
fi

python3 - <<'PY'
import psycopg2
print("psycopg2 disponible:", psycopg2.__version__)
PY

log "Detectando o creando VPC default"

VPC_ID=$(aws ec2 describe-vpcs \
  --region "$AWS_REGION" \
  --filters "Name=isDefault,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text 2>/dev/null || true)

if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
  warn "No se encontró VPC default. Intentando crear VPC default."
  VPC_ID=$(aws ec2 create-default-vpc \
    --region "$AWS_REGION" \
    --query "Vpc.VpcId" \
    --output text) || fail "No se pudo crear la VPC default."
fi

export VPC_ID
ok "VPC seleccionada: $VPC_ID"

log "Seleccionando al menos dos subnets de la VPC"

SUBNET_IDS=$(aws ec2 describe-subnets \
  --region "$AWS_REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets | sort_by(@,&AvailabilityZone)[0:2].SubnetId" \
  --output text)

if [[ "$(wc -w <<< "$SUBNET_IDS")" -lt 2 ]]; then
  fail "Se requieren al menos dos subnets en la VPC $VPC_ID para crear el DB Subnet Group."
fi

export SUBNET_IDS
ok "Subnets seleccionadas: $SUBNET_IDS"

log "Creando o reutilizando Security Group para Aurora"

AURORA_SG_ID=$(aws ec2 describe-security-groups \
  --region "$AWS_REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=$AURORA_SG_NAME" \
  --query "SecurityGroups[0].GroupId" \
  --output text 2>/dev/null || true)

if [[ -z "$AURORA_SG_ID" || "$AURORA_SG_ID" == "None" ]]; then
  AURORA_SG_ID=$(aws ec2 create-security-group \
    --region "$AWS_REGION" \
    --group-name "$AURORA_SG_NAME" \
    --description "Security Group temporal para laboratorios Aurora PostgreSQL" \
    --vpc-id "$VPC_ID" \
    --query "GroupId" \
    --output text)
  ok "Security Group creado: $AURORA_SG_ID"
else
  ok "Security Group existente: $AURORA_SG_ID"
fi

export AURORA_SG_ID

log "Autorizando acceso temporal a PostgreSQL TCP/$AURORA_PORT desde $ALLOW_CIDR"

aws ec2 authorize-security-group-ingress \
  --region "$AWS_REGION" \
  --group-id "$AURORA_SG_ID" \
  --protocol tcp \
  --port "$AURORA_PORT" \
  --cidr "$ALLOW_CIDR" >/dev/null 2>&1 \
  || warn "La regla de ingreso ya existía o no pudo duplicarse. Continuando."

ok "Regla TCP/$AURORA_PORT validada"

log "Creando o reutilizando DB Subnet Group"

if aws rds describe-db-subnet-groups \
  --region "$AWS_REGION" \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" >/dev/null 2>&1; then
  ok "DB Subnet Group existente: $DB_SUBNET_GROUP_NAME"
else
  aws rds create-db-subnet-group \
    --region "$AWS_REGION" \
    --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
    --db-subnet-group-description "DB Subnet Group temporal para laboratorios Aurora PostgreSQL" \
    --subnet-ids $SUBNET_IDS >/dev/null
  ok "DB Subnet Group creado: $DB_SUBNET_GROUP_NAME"
fi

log "Creando o reutilizando DB Cluster Parameter Group"

if aws rds describe-db-cluster-parameter-groups \
  --region "$AWS_REGION" \
  --db-cluster-parameter-group-name "$AURORA_PARAM_GROUP" >/dev/null 2>&1; then
  ok "Parameter Group existente: $AURORA_PARAM_GROUP"
else
  aws rds create-db-cluster-parameter-group \
    --region "$AWS_REGION" \
    --db-cluster-parameter-group-name "$AURORA_PARAM_GROUP" \
    --db-parameter-group-family "aurora-postgresql16" \
    --description "Parameter Group temporal para laboratorios Aurora PostgreSQL" >/dev/null
  ok "Parameter Group creado: $AURORA_PARAM_GROUP"
fi

log "Creando o reutilizando clúster Aurora PostgreSQL"

if aws rds describe-db-clusters \
  --region "$AWS_REGION" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" >/dev/null 2>&1; then
  ok "Clúster existente: $AURORA_CLUSTER_ID"
else
  aws rds create-db-cluster \
    --region "$AWS_REGION" \
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
    --port "$AURORA_PORT" >/dev/null
  ok "Clúster solicitado: $AURORA_CLUSTER_ID"
fi

log "Creando o reutilizando instancia writer"

if aws rds describe-db-instances \
  --region "$AWS_REGION" \
  --db-instance-identifier "$AURORA_INSTANCE_ID" >/dev/null 2>&1; then
  ok "Instancia writer existente: $AURORA_INSTANCE_ID"

  PUBLICLY_ACCESSIBLE=$(aws rds describe-db-instances \
    --region "$AWS_REGION" \
    --db-instance-identifier "$AURORA_INSTANCE_ID" \
    --query "DBInstances[0].PubliclyAccessible" \
    --output text)

  if [[ "$PUBLICLY_ACCESSIBLE" != "True" ]]; then
    warn "La instancia writer existente no está pública. Aplicando --publicly-accessible."
    aws rds modify-db-instance \
      --region "$AWS_REGION" \
      --db-instance-identifier "$AURORA_INSTANCE_ID" \
      --publicly-accessible \
      --apply-immediately >/dev/null
    ok "Modificación solicitada para instancia writer pública"
  fi
else
  aws rds create-db-instance \
    --region "$AWS_REGION" \
    --db-instance-identifier "$AURORA_INSTANCE_ID" \
    --db-cluster-identifier "$AURORA_CLUSTER_ID" \
    --engine "$AURORA_ENGINE" \
    --db-instance-class "$AURORA_INSTANCE_CLASS" \
    --publicly-accessible >/dev/null
  ok "Instancia writer solicitada: $AURORA_INSTANCE_ID"
fi

log "Esperando disponibilidad de writer"

aws rds wait db-instance-available \
  --region "$AWS_REGION" \
  --db-instance-identifier "$AURORA_INSTANCE_ID"

aws rds wait db-cluster-available \
  --region "$AWS_REGION" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID"

log "Validando o creando instancia reader para failover"

AURORA_READER_COUNT=$(aws rds describe-db-clusters \
  --region "$AWS_REGION" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --query "length(DBClusters[0].DBClusterMembers[?IsClusterWriter==\`false\`])" \
  --output text)

AURORA_READER_INSTANCE=$(aws rds describe-db-clusters \
  --region "$AWS_REGION" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --query "DBClusters[0].DBClusterMembers[?IsClusterWriter==\`false\`].DBInstanceIdentifier | [0]" \
  --output text)

if [[ "$AURORA_READER_COUNT" -ge 1 && -n "$AURORA_READER_INSTANCE" && "$AURORA_READER_INSTANCE" != "None" ]]; then
  ok "Reader existente para failover: $AURORA_READER_INSTANCE"
else
  warn "No existe reader. Se creará una réplica temporal: $AURORA_READER_INSTANCE_ID"

  if aws rds describe-db-instances \
    --region "$AWS_REGION" \
    --db-instance-identifier "$AURORA_READER_INSTANCE_ID" >/dev/null 2>&1; then
    ok "Instancia reader ya existe: $AURORA_READER_INSTANCE_ID"
  else
    aws rds create-db-instance \
      --region "$AWS_REGION" \
      --db-instance-identifier "$AURORA_READER_INSTANCE_ID" \
      --db-cluster-identifier "$AURORA_CLUSTER_ID" \
      --engine "$AURORA_ENGINE" \
      --db-instance-class "$AURORA_INSTANCE_CLASS" \
      --publicly-accessible >/dev/null
    ok "Instancia reader solicitada: $AURORA_READER_INSTANCE_ID"
  fi

  log "Esperando disponibilidad de reader"
  aws rds wait db-instance-available \
    --region "$AWS_REGION" \
    --db-instance-identifier "$AURORA_READER_INSTANCE_ID"

  AURORA_READER_INSTANCE="$AURORA_READER_INSTANCE_ID"
fi

log "Esperando disponibilidad final del clúster"

aws rds wait db-cluster-available \
  --region "$AWS_REGION" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID"

export AURORA_ENDPOINT=$(aws rds describe-db-clusters \
  --region "$AWS_REGION" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --query "DBClusters[0].Endpoint" \
  --output text)

export AURORA_READER_ENDPOINT=$(aws rds describe-db-clusters \
  --region "$AWS_REGION" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --query "DBClusters[0].ReaderEndpoint" \
  --output text)

export AURORA_WRITER_INSTANCE=$(aws rds describe-db-clusters \
  --region "$AWS_REGION" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --query "DBClusters[0].DBClusterMembers[?IsClusterWriter==\`true\`].DBInstanceIdentifier | [0]" \
  --output text)

export AURORA_READER_INSTANCE=$(aws rds describe-db-clusters \
  --region "$AWS_REGION" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --query "DBClusters[0].DBClusterMembers[?IsClusterWriter==\`false\`].DBInstanceIdentifier | [0]" \
  --output text)

export AURORA_READER_COUNT=$(aws rds describe-db-clusters \
  --region "$AWS_REGION" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --query "length(DBClusters[0].DBClusterMembers[?IsClusterWriter==\`false\`])" \
  --output text)

ok "Endpoint writer: $AURORA_ENDPOINT"
ok "Endpoint reader: $AURORA_READER_ENDPOINT"
ok "Instancia writer: $AURORA_WRITER_INSTANCE"
ok "Instancia reader: $AURORA_READER_INSTANCE"
ok "Readers disponibles: $AURORA_READER_COUNT"

log "Validando conexión y base de datos $AURORA_DBNAME"

PG_CONN_POSTGRES="host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require"
PG_CONN_LAB="host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require"

psql "$PG_CONN_POSTGRES" \
  -v ON_ERROR_STOP=1 \
  -c "SELECT version();" >/dev/null

DB_EXISTS=$(psql "$PG_CONN_POSTGRES" \
  -v ON_ERROR_STOP=1 \
  -tAc "SELECT 1 FROM pg_database WHERE datname = '$AURORA_DBNAME';")

if [[ "$DB_EXISTS" == "1" ]]; then
  ok "Base de datos existente: $AURORA_DBNAME"
else
  log "Creando base de datos $AURORA_DBNAME"
  psql "$PG_CONN_POSTGRES" \
    -v ON_ERROR_STOP=1 \
    -c "CREATE DATABASE $AURORA_DBNAME;" >/dev/null
  ok "Base de datos creada: $AURORA_DBNAME"
fi

psql "$PG_CONN_LAB" \
  -v ON_ERROR_STOP=1 \
  -c "SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;"

log "Generando archivo de variables $ENV_FILE"

cat > "$ENV_FILE" <<EOF
# Variables generadas por 00_preparar_laboratorio_4_aurora.sh
# Ejecuta antes de iniciar la práctica:
#   source ./lab4_aurora_env.sh

export AWS_REGION='$AWS_REGION'
export LAB_PREFIX='$LAB_PREFIX'
export VPC_ID='$VPC_ID'
export SUBNET_IDS='$SUBNET_IDS'
export AURORA_SG_ID='$AURORA_SG_ID'
export AURORA_SG_NAME='$AURORA_SG_NAME'
export DB_SUBNET_GROUP_NAME='$DB_SUBNET_GROUP_NAME'
export AURORA_PARAM_GROUP='$AURORA_PARAM_GROUP'
export AURORA_CLUSTER_ID='$AURORA_CLUSTER_ID'
export AURORA_INSTANCE_ID='$AURORA_INSTANCE_ID'
export AURORA_READER_INSTANCE_ID='$AURORA_READER_INSTANCE_ID'
export AURORA_WRITER_INSTANCE='$AURORA_WRITER_INSTANCE'
export AURORA_READER_INSTANCE='$AURORA_READER_INSTANCE'
export AURORA_READER_COUNT='$AURORA_READER_COUNT'
export AURORA_ENDPOINT='$AURORA_ENDPOINT'
export AURORA_READER_ENDPOINT='$AURORA_READER_ENDPOINT'
export AURORA_PORT='$AURORA_PORT'
export AURORA_DBNAME='$AURORA_DBNAME'
export AURORA_MASTER_USER='$AURORA_MASTER_USER'
export AURORA_MASTER_PASSWORD='$AURORA_MASTER_PASSWORD'
export ALLOW_CIDR='$ALLOW_CIDR'
export LAB_WORKDIR='$LAB_WORKDIR'
export WORKDIR='$WORKDIR'
EOF

chmod 600 "$ENV_FILE"
ok "Archivo generado: $ENV_FILE"

log "Resumen final"

cat <<EOF
Región:               $AWS_REGION
VPC:                  $VPC_ID
Subnets:              $SUBNET_IDS
Security Group:       $AURORA_SG_ID
DB Subnet Group:      $DB_SUBNET_GROUP_NAME
Parameter Group:      $AURORA_PARAM_GROUP
Cluster:              $AURORA_CLUSTER_ID
Writer actual:        $AURORA_WRITER_INSTANCE
Reader para failover: $AURORA_READER_INSTANCE
Readers disponibles:  $AURORA_READER_COUNT
Endpoint writer:      $AURORA_ENDPOINT
Endpoint reader:      $AURORA_READER_ENDPOINT
Base de datos:        $AURORA_DBNAME
Usuario:              $AURORA_MASTER_USER
CIDR autorizado:      $ALLOW_CIDR
Archivo de variables: $ENV_FILE

Antes de iniciar el Laboratorio 4, ejecuta:
  source ./lab4_aurora_env.sh

Luego continúa con el Reto 1 de la práctica.
EOF

ok "Preparación completada correctamente"
