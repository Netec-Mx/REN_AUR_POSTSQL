#!/usr/bin/env bash
# ==============================================================================
# Script: 00_preparar_laboratorio_5_aurora.sh
# Propósito: Preparar los prerrequisitos técnicos del Laboratorio 5
#            "Ajuste de parámetros y benchmark controlado" en AWS CloudShell.
#
# Ejecutar en AWS CloudShell:
#   chmod +x 00_preparar_laboratorio_5_aurora.sh
#   ./00_preparar_laboratorio_5_aurora.sh
#   source ./lab5_aurora_env.sh
#
# Opcional, antes de ejecutar puedes sobrescribir valores:
#   export AWS_REGION="us-west-2"
#   export AURORA_MASTER_PASSWORD='Cambia_Esta_Clave_2026!'
#   export ALLOW_CIDR="0.0.0.0/0"
#   ./00_preparar_laboratorio_5_aurora.sh
#
# Importante:
# - Este script crea recursos que pueden generar costo en AWS.
# - Para facilitar la conexión desde CloudShell, la instancia writer se crea pública.
# - El Security Group permite TCP/5432 desde 0.0.0.0/0 para laboratorio temporal.
# - Esta versión trabaja en la raíz actual de CloudShell.
# - No crea directorios scripts/logs/results.
# ==============================================================================

set -Eeuo pipefail

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✖ %s\033[0m\n' "$*" >&2; exit 1; }

# -----------------------------
# Valores estandarizados
# -----------------------------
export AWS_REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}"
export AWS_REGION="${AWS_REGION:-us-west-2}"

export LAB_PREFIX="${LAB_PREFIX:-aurora-performance-lab}"
export AURORA_CLUSTER_ID="${AURORA_CLUSTER_ID:-${LAB_PREFIX}-cluster}"
export AURORA_INSTANCE_ID="${AURORA_INSTANCE_ID:-${LAB_PREFIX}-instance-1}"
export AURORA_PARAM_GROUP="${AURORA_PARAM_GROUP:-${LAB_PREFIX}-cluster-pg}"
export DB_SUBNET_GROUP_NAME="${DB_SUBNET_GROUP_NAME:-${LAB_PREFIX}-db-subnet-group}"
export AURORA_SG_NAME="${AURORA_SG_NAME:-${LAB_PREFIX}-aurora-sg}"

export AURORA_DBNAME="${AURORA_DBNAME:-postgres}"
export PGBENCH_DBNAME="${PGBENCH_DBNAME:-pgbench_lab}"
export AURORA_PORT="${AURORA_PORT:-5432}"
export AURORA_MASTER_USER="${AURORA_MASTER_USER:-labadmin}"
export AURORA_MASTER_PASSWORD="${AURORA_MASTER_PASSWORD:-AuroraLab_2026_Temporal!}"
export AURORA_ENGINE="${AURORA_ENGINE:-aurora-postgresql}"
export AURORA_ENGINE_VERSION="${AURORA_ENGINE_VERSION:-16}"
export AURORA_INSTANCE_CLASS="${AURORA_INSTANCE_CLASS:-db.r6g.large}"
export ALLOW_CIDR="${ALLOW_CIDR:-0.0.0.0/0}"

# Lab 5 trabaja en la raíz actual.
export LAB_WORKDIR="${LAB_WORKDIR:-$PWD}"
export WORKDIR="${WORKDIR:-$LAB_WORKDIR}"

# Parámetros estándar del benchmark del laboratorio.
export PGBENCH_SCALE="${PGBENCH_SCALE:-5}"
export PGBENCH_CLIENTS="${PGBENCH_CLIENTS:-5}"
export PGBENCH_THREADS="${PGBENCH_THREADS:-2}"
export PGBENCH_DURATION="${PGBENCH_DURATION:-30}"
export PGBENCH_PROGRESS="${PGBENCH_PROGRESS:-10}"
export PGBENCH_TUNED_OPTIONS="${PGBENCH_TUNED_OPTIONS:--c work_mem=16MB -c effective_cache_size=3GB -c statement_timeout=30s -c default_statistics_target=200}"

ENV_FILE="${ENV_FILE:-./lab5_aurora_env.sh}"

# -----------------------------
# Resumen inicial
# -----------------------------
log "Parámetros de preparación del Laboratorio 5"

cat <<EOF
Región AWS:            $AWS_REGION
Cluster ID:            $AURORA_CLUSTER_ID
Instance ID:           $AURORA_INSTANCE_ID
DB base:               $AURORA_DBNAME
DB benchmark:          $PGBENCH_DBNAME
Usuario master:        $AURORA_MASTER_USER
Directorio trabajo:    $LAB_WORKDIR
Archivo de variables:  $ENV_FILE
CIDR autorizado:       $ALLOW_CIDR
pgbench scale:         $PGBENCH_SCALE
pgbench clients:       $PGBENCH_CLIENTS
pgbench threads:       $PGBENCH_THREADS
pgbench duration:      $PGBENCH_DURATION
EOF

# -----------------------------
# Validaciones locales
# -----------------------------
log "Validando identidad AWS y herramientas base"

aws sts get-caller-identity --output table >/dev/null \
  || fail "No se pudo validar la identidad AWS. Revisa permisos o sesión de CloudShell."

ok "Identidad AWS validada"

aws configure set region "$AWS_REGION" >/dev/null
ok "Región configurada: $AWS_REGION"

if ! command -v jq >/dev/null 2>&1; then
  warn "jq no está disponible. Intentando instalar jq..."

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
  warn "psql no está disponible. Intentando instalar cliente PostgreSQL..."

  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y postgresql15 || sudo dnf install -y postgresql16 || sudo dnf install -y postgresql
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y postgresql15 || sudo yum install -y postgresql16 || sudo yum install -y postgresql
  else
    fail "No se encontró dnf ni yum para instalar psql."
  fi
fi

ok "psql disponible: $(psql --version)"

if ! command -v pgbench >/dev/null 2>&1; then
  warn "pgbench no está disponible. Intentando instalar herramientas contrib de PostgreSQL..."

  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y postgresql15-contrib || sudo dnf install -y postgresql16-contrib || sudo dnf install -y postgresql-contrib || sudo dnf install -y postgresql15
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y postgresql15-contrib || sudo yum install -y postgresql16-contrib || sudo yum install -y postgresql-contrib || sudo yum install -y postgresql15
  else
    fail "No se encontró dnf ni yum para instalar pgbench."
  fi
fi

if ! command -v pgbench >/dev/null 2>&1; then
  fail "pgbench no quedó disponible después de instalar paquetes PostgreSQL."
fi

ok "pgbench disponible: $(pgbench --version)"

if ! command -v python3 >/dev/null 2>&1; then
  fail "python3 no está disponible en CloudShell."
fi

ok "python3 disponible: $(python3 --version 2>&1)"

log "Directorio de trabajo del Laboratorio 5"
pwd
ok "LAB_WORKDIR configurado en raíz actual: $LAB_WORKDIR"

# -----------------------------
# Red base
# -----------------------------
log "Detectando o creando VPC default"

VPC_ID=$(aws ec2 describe-vpcs \
  --region "$AWS_REGION" \
  --filters "Name=isDefault,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text 2>/dev/null || true)

if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
  warn "No se encontró VPC default. Intentando crear VPC default..."

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

# -----------------------------
# Parameter Group opcional para consistencia con otros labs
# -----------------------------
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

# -----------------------------
# Aurora PostgreSQL
# -----------------------------
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
  ok "Instancia existente: $AURORA_INSTANCE_ID"

  PUBLICLY_ACCESSIBLE=$(aws rds describe-db-instances \
    --region "$AWS_REGION" \
    --db-instance-identifier "$AURORA_INSTANCE_ID" \
    --query "DBInstances[0].PubliclyAccessible" \
    --output text)

  if [[ "$PUBLICLY_ACCESSIBLE" != "True" ]]; then
    warn "La instancia existente no está pública. Aplicando --publicly-accessible..."

    aws rds modify-db-instance \
      --region "$AWS_REGION" \
      --db-instance-identifier "$AURORA_INSTANCE_ID" \
      --publicly-accessible \
      --apply-immediately >/dev/null

    ok "Modificación solicitada para instancia pública"
  fi
else
  aws rds create-db-instance \
    --region "$AWS_REGION" \
    --db-instance-identifier "$AURORA_INSTANCE_ID" \
    --db-cluster-identifier "$AURORA_CLUSTER_ID" \
    --engine "$AURORA_ENGINE" \
    --db-instance-class "$AURORA_INSTANCE_CLASS" \
    --publicly-accessible >/dev/null

  ok "Instancia solicitada: $AURORA_INSTANCE_ID"
fi

log "Esperando disponibilidad de Aurora"

aws rds wait db-instance-available \
  --region "$AWS_REGION" \
  --db-instance-identifier "$AURORA_INSTANCE_ID"

aws rds wait db-cluster-available \
  --region "$AWS_REGION" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID"

ok "Aurora disponible"

export AURORA_ENDPOINT=$(aws rds describe-db-clusters \
  --region "$AWS_REGION" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --query "DBClusters[0].Endpoint" \
  --output text)

export AURORA_READER_ENDPOINT=$(aws rds describe-db-clusters \
  --region "$AWS_REGION" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --query "DBClusters[0].ReaderEndpoint" \
  --output text 2>/dev/null || true)

export AURORA_WRITER_INSTANCE_ID=$(aws rds describe-db-clusters \
  --region "$AWS_REGION" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --query "DBClusters[0].DBClusterMembers[?IsClusterWriter==\`true\`].DBInstanceIdentifier | [0]" \
  --output text 2>/dev/null || true)

ok "Endpoint writer: $AURORA_ENDPOINT"
ok "Endpoint reader: $AURORA_READER_ENDPOINT"
ok "Instancia writer: $AURORA_WRITER_INSTANCE_ID"

# -----------------------------
# Base requerida por el laboratorio
# -----------------------------
log "Validando conexión al writer y base administrativa $AURORA_DBNAME"

PG_CONN_ADMIN="host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require"

psql "$PG_CONN_ADMIN" \
  -v ON_ERROR_STOP=1 \
  -c "SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;" \
  -c "SELECT version();" >/dev/null

psql "$PG_CONN_ADMIN" \
  -v ON_ERROR_STOP=1 \
  -c "SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;"

log "Validando que pgbench pueda conectar al writer"

PGPASSWORD="$AURORA_MASTER_PASSWORD" \
pgbench \
  -h "$AURORA_ENDPOINT" \
  -p "$AURORA_PORT" \
  -U "$AURORA_MASTER_USER" \
  -d "$AURORA_DBNAME" \
  --version >/dev/null

ok "pgbench validado"

# -----------------------------
# Archivo de variables para la práctica
# -----------------------------
log "Generando archivo de variables $ENV_FILE"

cat > "$ENV_FILE" <<EOF
# Variables generadas por 00_preparar_laboratorio_5_aurora.sh
# Ejecuta antes de iniciar la práctica:
#   source ./lab5_aurora_env.sh

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
export AURORA_WRITER_INSTANCE_ID='$AURORA_WRITER_INSTANCE_ID'
export AURORA_ENDPOINT='$AURORA_ENDPOINT'
export AURORA_READER_ENDPOINT='$AURORA_READER_ENDPOINT'
export AURORA_PORT='$AURORA_PORT'
export AURORA_DBNAME='$AURORA_DBNAME'
export PGBENCH_DBNAME='$PGBENCH_DBNAME'
export AURORA_MASTER_USER='$AURORA_MASTER_USER'
export AURORA_MASTER_PASSWORD='$AURORA_MASTER_PASSWORD'
export ALLOW_CIDR='$ALLOW_CIDR'
export LAB_WORKDIR='$LAB_WORKDIR'
export WORKDIR='$WORKDIR'
export PGBENCH_SCALE='$PGBENCH_SCALE'
export PGBENCH_CLIENTS='$PGBENCH_CLIENTS'
export PGBENCH_THREADS='$PGBENCH_THREADS'
export PGBENCH_DURATION='$PGBENCH_DURATION'
export PGBENCH_PROGRESS='$PGBENCH_PROGRESS'
export PGBENCH_TUNED_OPTIONS='$PGBENCH_TUNED_OPTIONS'
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
Instance:             $AURORA_INSTANCE_ID
Writer instance:      $AURORA_WRITER_INSTANCE_ID
Endpoint writer:      $AURORA_ENDPOINT
Base administrativa:  $AURORA_DBNAME
Base benchmark:       $PGBENCH_DBNAME
Usuario:              $AURORA_MASTER_USER
CIDR autorizado:      $ALLOW_CIDR
Archivo de variables: $ENV_FILE

Antes de iniciar el Laboratorio 5, ejecuta:
  source ./lab5_aurora_env.sh

Validación rápida:
  psql "host=\$AURORA_ENDPOINT port=\$AURORA_PORT dbname=postgres user=\$AURORA_MASTER_USER password=\$AURORA_MASTER_PASSWORD sslmode=require" -c "SELECT pg_is_in_recovery() AS es_replica;"
  pgbench --version

Luego continúa con el Reto 1 de la práctica.
EOF

ok "Preparación completada correctamente"
