#!/usr/bin/env bash
# ==============================================================================
# Script: 00_eliminar_laboratorio_6_aurora.sh
# Propósito: Eliminar los recursos creados para el Laboratorio 6
#            "Gestión de conexiones con RDS Proxy" en Aurora PostgreSQL.
#
# Ejecutar en AWS CloudShell:
#   chmod +x 00_eliminar_laboratorio_6_aurora.sh
#   ./00_eliminar_laboratorio_6_aurora.sh
#
# Si existe el archivo de variables generado por la preparación:
#   ./lab6_aurora_env.sh
#
# el script lo cargará automáticamente.
#
# Importante:
# - Este script elimina recursos de AWS.
# - Primero elimina RDS Proxy y sus targets.
# - Después elimina secreto, IAM Role e infraestructura Aurora si existe.
# - No crea snapshot final.
# - Está diseñado para ambiente de laboratorio, no producción.
# ==============================================================================

set -Eeuo pipefail

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✖ %s\033[0m\n' "$*" >&2; exit 1; }

ENV_FILE="${ENV_FILE:-./lab6_aurora_env.sh}"

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
export AURORA_PARAM_GROUP="${AURORA_PARAM_GROUP:-${LAB_PREFIX}-cluster-pg}"
export DB_SUBNET_GROUP_NAME="${DB_SUBNET_GROUP_NAME:-${LAB_PREFIX}-db-subnet-group}"
export AURORA_SG_NAME="${AURORA_SG_NAME:-${LAB_PREFIX}-aurora-sg}"
export AURORA_DBNAME="${AURORA_DBNAME:-lab_performance}"

export RDS_PROXY_NAME="${RDS_PROXY_NAME:-aurora-pg-proxy-lab}"
export RDS_PROXY_SECRET_NAME="${RDS_PROXY_SECRET_NAME:-${RDS_PROXY_NAME}-secret}"
export RDS_PROXY_ROLE_NAME="${RDS_PROXY_ROLE_NAME:-${RDS_PROXY_NAME}-role}"
export RDS_PROXY_POLICY_NAME="${RDS_PROXY_POLICY_NAME:-${RDS_PROXY_NAME}-read-secret-policy}"

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
RDS Proxy:           $RDS_PROXY_NAME
Secret Name:         $RDS_PROXY_SECRET_NAME
Role Name:           $RDS_PROXY_ROLE_NAME
EOF

# -----------------------------
# Eliminar RDS Proxy
# -----------------------------
log "Eliminando RDS Proxy y targets"

if aws rds describe-db-proxies \
  --region "$AWS_REGION" \
  --db-proxy-name "$RDS_PROXY_NAME" >/dev/null 2>&1; then

  warn "Desregistrando targets del proxy si existen"

  aws rds deregister-db-proxy-targets \
    --region "$AWS_REGION" \
    --db-proxy-name "$RDS_PROXY_NAME" \
    --db-cluster-identifiers "$AURORA_CLUSTER_ID" >/dev/null 2>&1 \
    || warn "No se pudo desregistrar el clúster como target o no estaba registrado."

  sleep 10

  PROXY_STATUS=$(aws rds describe-db-proxies \
    --region "$AWS_REGION" \
    --db-proxy-name "$RDS_PROXY_NAME" \
    --query "DBProxies[0].Status" \
    --output text)

  ok "Proxy encontrado: $RDS_PROXY_NAME | Estado: $PROXY_STATUS"

  if [[ "$PROXY_STATUS" == "deleting" ]]; then
    warn "El proxy ya está en proceso de eliminación."
  else
    aws rds delete-db-proxy \
      --region "$AWS_REGION" \
      --db-proxy-name "$RDS_PROXY_NAME" >/dev/null

    ok "Eliminación solicitada para RDS Proxy: $RDS_PROXY_NAME"
  fi

  log "Esperando eliminación del RDS Proxy"

  for i in {1..60}; do
    if aws rds describe-db-proxies \
      --region "$AWS_REGION" \
      --db-proxy-name "$RDS_PROXY_NAME" >/dev/null 2>&1; then
      printf "."
      sleep 10
    else
      printf "\n"
      ok "RDS Proxy eliminado: $RDS_PROXY_NAME"
      break
    fi

    if [[ "$i" -eq 60 ]]; then
      fail "El RDS Proxy no terminó de eliminarse en el tiempo esperado."
    fi
  done
else
  warn "No existe el RDS Proxy: $RDS_PROXY_NAME"
fi

# -----------------------------
# Eliminar secreto
# -----------------------------
log "Eliminando secreto de Secrets Manager"

if aws secretsmanager describe-secret \
  --region "$AWS_REGION" \
  --secret-id "$RDS_PROXY_SECRET_NAME" >/dev/null 2>&1; then

  aws secretsmanager delete-secret \
    --region "$AWS_REGION" \
    --secret-id "$RDS_PROXY_SECRET_NAME" \
    --force-delete-without-recovery >/dev/null

  ok "Secreto eliminado sin ventana de recuperación: $RDS_PROXY_SECRET_NAME"
else
  warn "No existe el secreto: $RDS_PROXY_SECRET_NAME"
fi

# -----------------------------
# Eliminar IAM Role
# -----------------------------
log "Eliminando IAM Role del RDS Proxy"

if aws iam get-role \
  --role-name "$RDS_PROXY_ROLE_NAME" >/dev/null 2>&1; then

  aws iam delete-role-policy \
    --role-name "$RDS_PROXY_ROLE_NAME" \
    --policy-name "$RDS_PROXY_POLICY_NAME" >/dev/null 2>&1 \
    || warn "No se pudo eliminar la política inline o no existía: $RDS_PROXY_POLICY_NAME"

  aws iam delete-role \
    --role-name "$RDS_PROXY_ROLE_NAME" >/dev/null

  ok "IAM Role eliminado: $RDS_PROXY_ROLE_NAME"
else
  warn "No existe el IAM Role: $RDS_PROXY_ROLE_NAME"
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

warn "Se conservan archivos de evidencia 06_* si existen."
warn "Para eliminarlos manualmente ejecuta: rm -f 06_*"

# -----------------------------
# Validación final
# -----------------------------
log "Validación final"

PROXY_EXISTS="no"
SECRET_EXISTS="no"
ROLE_EXISTS="no"
INSTANCE_EXISTS="no"
CLUSTER_EXISTS="no"
SUBNET_GROUP_EXISTS="no"
PARAM_GROUP_EXISTS="no"
SG_EXISTS="no"

if aws rds describe-db-proxies \
  --region "$AWS_REGION" \
  --db-proxy-name "$RDS_PROXY_NAME" >/dev/null 2>&1; then
  PROXY_EXISTS="sí"
fi

if aws secretsmanager describe-secret \
  --region "$AWS_REGION" \
  --secret-id "$RDS_PROXY_SECRET_NAME" >/dev/null 2>&1; then
  SECRET_EXISTS="sí"
fi

if aws iam get-role \
  --role-name "$RDS_PROXY_ROLE_NAME" >/dev/null 2>&1; then
  ROLE_EXISTS="sí"
fi

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
RDS Proxy existe:         $PROXY_EXISTS
Secreto existe:           $SECRET_EXISTS
IAM Role existe:          $ROLE_EXISTS
Instancia existe:         $INSTANCE_EXISTS
Clúster existe:           $CLUSTER_EXISTS
DB Subnet Group existe:   $SUBNET_GROUP_EXISTS
Parameter Group existe:   $PARAM_GROUP_EXISTS
Security Group existe:    $SG_EXISTS
EOF

ok "Eliminación del Laboratorio 6 completada"
