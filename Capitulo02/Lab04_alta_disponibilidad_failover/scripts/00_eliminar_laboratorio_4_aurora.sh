#!/usr/bin/env bash
# ==============================================================================
# Script: 00_eliminar_laboratorio_4_aurora.sh
# Propósito: Eliminar los recursos creados para el Laboratorio 4
#            "Alta disponibilidad, endpoints y failover" en Aurora PostgreSQL.
#
# Ejecutar en AWS CloudShell:
#   chmod +x 00_eliminar_laboratorio_4_aurora.sh
#   ./00_eliminar_laboratorio_4_aurora.sh
#
# El script carga automáticamente ./lab4_aurora_env.sh si existe.
#
# Importante:
# - Este script elimina recursos de AWS.
# - No crea snapshot final.
# - Elimina backups automatizados de las instancias.
# - Está diseñado para ambiente de laboratorio, no producción.
# ==============================================================================

set -Eeuo pipefail

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✖ %s\033[0m\n' "$*" >&2; exit 1; }

ENV_FILE="${ENV_FILE:-./lab4_aurora_env.sh}"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  ok "Archivo de variables cargado: $ENV_FILE"
else
  warn "No se encontró $ENV_FILE. Se usarán valores por defecto o variables exportadas."
fi

export AWS_REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}"
export AWS_REGION="${AWS_REGION:-us-west-2}"

export LAB_PREFIX="${LAB_PREFIX:-aurora-performance-lab}"
export AURORA_CLUSTER_ID="${AURORA_CLUSTER_ID:-${LAB_PREFIX}-cluster}"
export AURORA_INSTANCE_ID="${AURORA_INSTANCE_ID:-${LAB_PREFIX}-instance-1}"
export AURORA_READER_INSTANCE_ID="${AURORA_READER_INSTANCE_ID:-${AURORA_CLUSTER_ID}-reader-1}"
export AURORA_PARAM_GROUP="${AURORA_PARAM_GROUP:-${LAB_PREFIX}-cluster-pg}"
export DB_SUBNET_GROUP_NAME="${DB_SUBNET_GROUP_NAME:-${LAB_PREFIX}-db-subnet-group}"
export AURORA_SG_NAME="${AURORA_SG_NAME:-${LAB_PREFIX}-aurora-sg}"

log "Validando identidad AWS"

aws sts get-caller-identity --output table >/dev/null \
  || fail "No se pudo validar la identidad AWS. Revisa permisos o sesión de CloudShell."

aws configure set region "$AWS_REGION" >/dev/null
ok "Región configurada: $AWS_REGION"

log "Recursos objetivo"

cat <<EOF
Región:              $AWS_REGION
Cluster Aurora:      $AURORA_CLUSTER_ID
Writer estándar:     $AURORA_INSTANCE_ID
Reader estándar:     $AURORA_READER_INSTANCE_ID
DB Subnet Group:     $DB_SUBNET_GROUP_NAME
Parameter Group:     $AURORA_PARAM_GROUP
Security Group Name: $AURORA_SG_NAME
EOF

log "Resolviendo instancias actuales del clúster"

if aws rds describe-db-clusters \
  --region "$AWS_REGION" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" >/dev/null 2>&1; then

  INSTANCE_IDS=$(aws rds describe-db-clusters \
    --region "$AWS_REGION" \
    --db-cluster-identifier "$AURORA_CLUSTER_ID" \
    --query "DBClusters[0].DBClusterMembers[*].DBInstanceIdentifier" \
    --output text)
else
  INSTANCE_IDS="$AURORA_READER_INSTANCE_ID $AURORA_INSTANCE_ID"
fi

log "Eliminando instancias del clúster"

for DB_INSTANCE_ID in $INSTANCE_IDS; do
  if [[ -z "$DB_INSTANCE_ID" || "$DB_INSTANCE_ID" == "None" ]]; then
    continue
  fi

  if aws rds describe-db-instances \
    --region "$AWS_REGION" \
    --db-instance-identifier "$DB_INSTANCE_ID" >/dev/null 2>&1; then

    INSTANCE_STATUS=$(aws rds describe-db-instances \
      --region "$AWS_REGION" \
      --db-instance-identifier "$DB_INSTANCE_ID" \
      --query "DBInstances[0].DBInstanceStatus" \
      --output text)

    ok "Instancia encontrada: $DB_INSTANCE_ID | Estado: $INSTANCE_STATUS"

    if [[ "$INSTANCE_STATUS" == "deleting" ]]; then
      warn "La instancia ya está en proceso de eliminación: $DB_INSTANCE_ID"
    else
      aws rds delete-db-instance \
        --region "$AWS_REGION" \
        --db-instance-identifier "$DB_INSTANCE_ID" \
        --skip-final-snapshot \
        --delete-automated-backups >/dev/null

      ok "Eliminación solicitada para instancia: $DB_INSTANCE_ID"
    fi
  else
    warn "No existe la instancia: $DB_INSTANCE_ID"
  fi
done

for DB_INSTANCE_ID in $INSTANCE_IDS; do
  if [[ -z "$DB_INSTANCE_ID" || "$DB_INSTANCE_ID" == "None" ]]; then
    continue
  fi

  if aws rds describe-db-instances \
    --region "$AWS_REGION" \
    --db-instance-identifier "$DB_INSTANCE_ID" >/dev/null 2>&1; then
    log "Esperando eliminación de instancia: $DB_INSTANCE_ID"
    aws rds wait db-instance-deleted \
      --region "$AWS_REGION" \
      --db-instance-identifier "$DB_INSTANCE_ID"
    ok "Instancia eliminada: $DB_INSTANCE_ID"
  fi
done

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

log "Resolviendo y eliminando Security Group"

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
  if aws ec2 delete-security-group \
    --region "$AWS_REGION" \
    --group-id "$AURORA_SG_ID" >/dev/null 2>&1; then
    ok "Security Group eliminado: $AURORA_SG_ID"
  else
    warn "No se pudo eliminar el Security Group. Puede tener dependencias activas."
  fi
fi

log "Limpieza local"

for FILE in \
  "./lab4_aurora_env.sh" \
  "./04_monitor_failover.py" \
  "./04_failover_log.csv" \
  "./04_topologia_final.txt" \
  "./04_resumen_failover.txt"; do
  if [[ -f "$FILE" ]]; then
    rm -f "$FILE"
    ok "Archivo eliminado: $FILE"
  fi
done

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
Instancia writer estándar existe: $INSTANCE_EXISTS
Clúster existe:                  $CLUSTER_EXISTS
DB Subnet Group existe:          $SUBNET_GROUP_EXISTS
Parameter Group existe:          $PARAM_GROUP_EXISTS
Security Group existe:           $SG_EXISTS
EOF

ok "Eliminación del Laboratorio 4 completada"
