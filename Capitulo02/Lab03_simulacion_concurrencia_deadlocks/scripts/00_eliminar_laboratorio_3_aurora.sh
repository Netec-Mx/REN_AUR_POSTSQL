#!/usr/bin/env bash
# ==============================================================================
# Script: 00_eliminar_laboratorio_3_aurora.sh
# Propósito: Eliminar los recursos creados para el Laboratorio 3
#            "Carga controlada y métricas operativas" en Aurora PostgreSQL.
#
# Ejecutar en AWS CloudShell:
#   chmod +x 00_eliminar_laboratorio_3_aurora.sh
#   ./00_eliminar_laboratorio_3_aurora.sh
#
# Si existe el archivo de variables generado por la preparación:
#   $HOME/lab-02-00-02/lab3_aurora_env.sh
#
# el script lo cargará automáticamente.
#
# También puedes sobrescribir valores antes de ejecutar:
#   export AWS_REGION="us-west-2"
#   export LAB_PREFIX="aurora-performance-lab"
#   ./00_eliminar_laboratorio_3_aurora.sh
#
# Importante:
# - Este script elimina recursos de AWS.
# - No crea snapshot final.
# - Elimina backups automatizados de la instancia.
# - Está diseñado para ambiente de laboratorio, no producción.
# ==============================================================================

set -Eeuo pipefail

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✖ %s\033[0m\n' "$*" >&2; exit 1; }

trap 'fail "Error en línea $LINENO. Revisa el mensaje anterior."' ERR

# -----------------------------
# Cargar variables del laboratorio si existen
# -----------------------------
export LAB_WORKDIR="${LAB_WORKDIR:-$HOME/lab-02-00-02}"
export WORKDIR="${WORKDIR:-$LAB_WORKDIR}"
ENV_FILE="${ENV_FILE:-$LAB_WORKDIR/lab3_aurora_env.sh}"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  ok "Archivo de variables cargado: $ENV_FILE"
else
  warn "No se encontró $ENV_FILE. Se usarán valores por defecto o variables exportadas."
fi

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
export AURORA_DBNAME="${AURORA_DBNAME:-lab_performance}"

# -----------------------------
# Validación de sesión AWS
# -----------------------------
log "Validando identidad AWS"

aws sts get-caller-identity --output table >/dev/null \
  || fail "No se pudo validar la identidad AWS. Revisa permisos o sesión de CloudShell."

aws configure set region "$AWS_REGION" >/dev/null
ok "Región configurada: $AWS_REGION"

log "Recursos objetivo"

cat <<EOF
Región:              $AWS_REGION
Cluster Aurora:      $AURORA_CLUSTER_ID
Instancia writer:    $AURORA_INSTANCE_ID
DB Subnet Group:     $DB_SUBNET_GROUP_NAME
Parameter Group:     $AURORA_PARAM_GROUP
Security Group Name: $AURORA_SG_NAME
Base de datos:       $AURORA_DBNAME
Directorio trabajo:  $LAB_WORKDIR
EOF

# -----------------------------
# Resolver Security Group si la variable no existe
# -----------------------------
log "Resolviendo Security Group del laboratorio"

AURORA_SG_ID="${AURORA_SG_ID:-}"

if [[ -z "$AURORA_SG_ID" || "$AURORA_SG_ID" == "None" ]]; then
  AURORA_SG_ID=$(aws ec2 describe-security-groups \
    --region "$AWS_REGION" \
    --filters "Name=group-name,Values=$AURORA_SG_NAME" \
    --query "SecurityGroups[0].GroupId" \
    --output text 2>/dev/null || true)
fi

if [[ -z "$AURORA_SG_ID" || "$AURORA_SG_ID" == "None" ]]; then
  warn "No se encontró Security Group por nombre: $AURORA_SG_NAME"
else
  ok "Security Group identificado: $AURORA_SG_ID"
fi

# -----------------------------
# Limpieza lógica dentro de la base, si Aurora sigue disponible
# -----------------------------
log "Intentando limpiar esquema lab_load dentro de la base"

AURORA_ENDPOINT="${AURORA_ENDPOINT:-}"

if [[ -z "$AURORA_ENDPOINT" || "$AURORA_ENDPOINT" == "None" ]]; then
  AURORA_ENDPOINT=$(aws rds describe-db-clusters \
    --region "$AWS_REGION" \
    --db-cluster-identifier "$AURORA_CLUSTER_ID" \
    --query "DBClusters[0].Endpoint" \
    --output text 2>/dev/null || true)
fi

if [[ -n "$AURORA_ENDPOINT" && "$AURORA_ENDPOINT" != "None" && -n "${AURORA_MASTER_USER:-}" && -n "${AURORA_MASTER_PASSWORD:-}" ]]; then
  if command -v psql >/dev/null 2>&1; then
    if psql "host=$AURORA_ENDPOINT port=${AURORA_PORT:-5432} dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require connect_timeout=10" \
      -v ON_ERROR_STOP=1 \
      -c "DROP SCHEMA IF EXISTS lab_load CASCADE;" >/dev/null 2>&1; then
      ok "Esquema lab_load eliminado o inexistente"
    else
      warn "No se pudo limpiar lab_load. Continuando con eliminación de infraestructura."
    fi
  else
    warn "psql no está disponible. Se omite limpieza lógica de lab_load."
  fi
else
  warn "No hay endpoint o credenciales suficientes para limpiar lab_load. Continuando."
fi

# -----------------------------
# Eliminar instancia Aurora
# -----------------------------
log "Eliminando instancia Aurora writer"

if aws rds describe-db-instances \
  --region "$AWS_REGION" \
  --db-instance-identifier "$AURORA_INSTANCE_ID" >/dev/null 2>&1; then

  INSTANCE_STATUS=$(aws rds describe-db-instances \
    --region "$AWS_REGION" \
    --db-instance-identifier "$AURORA_INSTANCE_ID" \
    --query "DBInstances[0].DBInstanceStatus" \
    --output text)

  ok "Instancia encontrada: $AURORA_INSTANCE_ID | Estado: $INSTANCE_STATUS"

  if [[ "$INSTANCE_STATUS" == "deleting" ]]; then
    warn "La instancia ya está en proceso de eliminación."
  else
    aws rds delete-db-instance \
      --region "$AWS_REGION" \
      --db-instance-identifier "$AURORA_INSTANCE_ID" \
      --skip-final-snapshot \
      --delete-automated-backups >/dev/null

    ok "Eliminación solicitada para instancia: $AURORA_INSTANCE_ID"
  fi

  log "Esperando eliminación de instancia"
  aws rds wait db-instance-deleted \
    --region "$AWS_REGION" \
    --db-instance-identifier "$AURORA_INSTANCE_ID"

  ok "Instancia eliminada: $AURORA_INSTANCE_ID"
else
  warn "No existe la instancia: $AURORA_INSTANCE_ID"
fi

# -----------------------------
# Eliminar clúster Aurora
# -----------------------------
log "Eliminando clúster Aurora"

if aws rds describe-db-clusters \
  --region "$AWS_REGION" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" >/dev/null 2>&1; then

  CLUSTER_STATUS=$(aws rds describe-db-clusters \
    --region "$AWS_REGION" \
    --db-cluster-identifier "$AURORA_CLUSTER_ID" \
    --query "DBClusters[0].Status" \
    --output text)

  ok "Clúster encontrado: $AURORA_CLUSTER_ID | Estado: $CLUSTER_STATUS"

  if [[ "$CLUSTER_STATUS" == "deleting" ]]; then
    warn "El clúster ya está en proceso de eliminación."
  else
    aws rds delete-db-cluster \
      --region "$AWS_REGION" \
      --db-cluster-identifier "$AURORA_CLUSTER_ID" \
      --skip-final-snapshot >/dev/null

    ok "Eliminación solicitada para clúster: $AURORA_CLUSTER_ID"
  fi

  log "Esperando eliminación del clúster"
  aws rds wait db-cluster-deleted \
    --region "$AWS_REGION" \
    --db-cluster-identifier "$AURORA_CLUSTER_ID"

  ok "Clúster eliminado: $AURORA_CLUSTER_ID"
else
  warn "No existe el clúster: $AURORA_CLUSTER_ID"
fi

# -----------------------------
# Eliminar DB Subnet Group
# -----------------------------
log "Eliminando DB Subnet Group"

if aws rds describe-db-subnet-groups \
  --region "$AWS_REGION" \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" >/dev/null 2>&1; then

  aws rds delete-db-subnet-group \
    --region "$AWS_REGION" \
    --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" >/dev/null

  ok "DB Subnet Group eliminado: $DB_SUBNET_GROUP_NAME"
else
  warn "No existe el DB Subnet Group: $DB_SUBNET_GROUP_NAME"
fi

# -----------------------------
# Eliminar DB Cluster Parameter Group
# -----------------------------
log "Eliminando DB Cluster Parameter Group"

if aws rds describe-db-cluster-parameter-groups \
  --region "$AWS_REGION" \
  --db-cluster-parameter-group-name "$AURORA_PARAM_GROUP" >/dev/null 2>&1; then

  aws rds delete-db-cluster-parameter-group \
    --region "$AWS_REGION" \
    --db-cluster-parameter-group-name "$AURORA_PARAM_GROUP" >/dev/null

  ok "Parameter Group eliminado: $AURORA_PARAM_GROUP"
else
  warn "No existe el Parameter Group: $AURORA_PARAM_GROUP"
fi

# -----------------------------
# Eliminar Security Group
# -----------------------------
log "Eliminando Security Group"

if [[ -z "$AURORA_SG_ID" || "$AURORA_SG_ID" == "None" ]]; then
  warn "No hay Security Group ID para eliminar."
else
  if aws ec2 describe-security-groups \
    --region "$AWS_REGION" \
    --group-ids "$AURORA_SG_ID" >/dev/null 2>&1; then

    if aws ec2 delete-security-group \
      --region "$AWS_REGION" \
      --group-id "$AURORA_SG_ID" >/dev/null 2>&1; then
      ok "Security Group eliminado: $AURORA_SG_ID"
    else
      warn "No se pudo eliminar el Security Group. Puede tener dependencias activas."
    fi
  else
    warn "No existe el Security Group: $AURORA_SG_ID"
  fi
fi

# -----------------------------
# Limpieza local
# -----------------------------
log "Limpieza local"

if [[ -f "$ENV_FILE" ]]; then
  rm -f "$ENV_FILE"
  ok "Archivo local eliminado: $ENV_FILE"
else
  warn "No existe archivo local de variables: $ENV_FILE"
fi

if [[ -d "$LAB_WORKDIR/scripts" || -d "$LAB_WORKDIR/logs" || -d "$LAB_WORKDIR/results" ]]; then
  warn "El directorio de trabajo contiene scripts/logs/results. Se conserva por evidencia del laboratorio:"
  echo "$LAB_WORKDIR"
  echo "Para eliminarlo manualmente:"
  echo "  rm -rf \"$LAB_WORKDIR\""
else
  warn "No se encontraron subdirectorios de evidencia en: $LAB_WORKDIR"
fi

# -----------------------------
# Validación final
# -----------------------------
log "Validación final"

INSTANCE_EXISTS="no"
CLUSTER_EXISTS="no"
SUBNET_GROUP_EXISTS="no"
PARAM_GROUP_EXISTS="no"
SG_EXISTS="no"

if aws rds describe-db-instances \
  --region "$AWS_REGION" \
  --db-instance-identifier "$AURORA_INSTANCE_ID" >/dev/null 2>&1; then
  INSTANCE_EXISTS="sí"
fi

if aws rds describe-db-clusters \
  --region "$AWS_REGION" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" >/dev/null 2>&1; then
  CLUSTER_EXISTS="sí"
fi

if aws rds describe-db-subnet-groups \
  --region "$AWS_REGION" \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" >/dev/null 2>&1; then
  SUBNET_GROUP_EXISTS="sí"
fi

if aws rds describe-db-cluster-parameter-groups \
  --region "$AWS_REGION" \
  --db-cluster-parameter-group-name "$AURORA_PARAM_GROUP" >/dev/null 2>&1; then
  PARAM_GROUP_EXISTS="sí"
fi

if [[ -n "${AURORA_SG_ID:-}" && "$AURORA_SG_ID" != "None" ]]; then
  if aws ec2 describe-security-groups \
    --region "$AWS_REGION" \
    --group-ids "$AURORA_SG_ID" >/dev/null 2>&1; then
    SG_EXISTS="sí"
  fi
fi

cat <<EOF
Instancia existe:        $INSTANCE_EXISTS
Clúster existe:          $CLUSTER_EXISTS
DB Subnet Group existe:  $SUBNET_GROUP_EXISTS
Parameter Group existe:  $PARAM_GROUP_EXISTS
Security Group existe:   $SG_EXISTS
EOF

ok "Eliminación del Laboratorio 3 completada"
