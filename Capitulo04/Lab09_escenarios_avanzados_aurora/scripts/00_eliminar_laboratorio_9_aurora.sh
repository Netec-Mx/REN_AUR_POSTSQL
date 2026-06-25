#!/usr/bin/env bash
# ==============================================================================
# Script: 00_eliminar_laboratorio_9_aurora.sh
# Propósito: Cerrar y eliminar TODOS los recursos del Laboratorio 9
#            "Arquitectura Aurora: optimización, observabilidad y DR"
#            en Aurora PostgreSQL.
#
# Ejecutar en AWS CloudShell:
#   chmod +x 00_eliminar_laboratorio_9_aurora.sh
#   ./00_eliminar_laboratorio_9_aurora.sh
#
# Archivos cargados automáticamente si existen:
#   ./lab9_aurora_env.sh
#   ./09_globaldb_example_env.sh
#
# Importante:
# - Este script elimina recursos de AWS si existen.
# - Conserva evidencia 09_* y la empaqueta antes de eliminar variables.
# - Elimina Aurora Global Database, clúster secundario, instancia secundaria,
#   RDS Proxy, clúster primario, instancia(s), subnet groups, parameter group
#   y security groups del laboratorio.
# - No crea snapshot final.
# - Diseñado para ambiente de laboratorio, no producción.
# ==============================================================================

set -Eeuo pipefail

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✖ %s\033[0m\n' "$*" >&2; exit 1; }

trap 'fail "Error en línea $LINENO. Revisa el mensaje anterior."' ERR

# -----------------------------
# Cargar variables
# -----------------------------
ENV_FILE="${ENV_FILE:-./lab9_aurora_env.sh}"
GLOBAL_ENV_FILE="${GLOBAL_ENV_FILE:-./09_globaldb_example_env.sh}"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  ok "Archivo de variables cargado: $ENV_FILE"
else
  warn "No se encontró $ENV_FILE. Se usarán valores por defecto o variables exportadas."
fi

if [[ -f "$GLOBAL_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$GLOBAL_ENV_FILE"
  ok "Archivo de variables Global DB cargado: $GLOBAL_ENV_FILE"
else
  warn "No se encontró $GLOBAL_ENV_FILE. Se usarán valores por defecto o variables exportadas."
fi

# -----------------------------
# Valores estandarizados
# -----------------------------
export AWS_REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}"
export AWS_REGION="${AWS_REGION:-us-west-2}"
export AWS_PRIMARY_REGION="${AWS_PRIMARY_REGION:-$AWS_REGION}"
export AWS_SECONDARY_REGION="${AWS_SECONDARY_REGION:-us-east-1}"

export LAB_PREFIX="${LAB_PREFIX:-aurora-performance-lab}"

export AURORA_CLUSTER_ID="${AURORA_CLUSTER_ID:-${LAB_PREFIX}-cluster}"
export AURORA_INSTANCE_ID="${AURORA_INSTANCE_ID:-${LAB_PREFIX}-instance-1}"
export AURORA_WRITER_INSTANCE="${AURORA_WRITER_INSTANCE:-$AURORA_INSTANCE_ID}"
export AURORA_PARAM_GROUP="${AURORA_PARAM_GROUP:-${LAB_PREFIX}-cluster-pg}"
export DB_SUBNET_GROUP_NAME="${DB_SUBNET_GROUP_NAME:-${LAB_PREFIX}-db-subnet-group}"
export AURORA_SG_NAME="${AURORA_SG_NAME:-${LAB_PREFIX}-aurora-sg}"
export AURORA_DBNAME="${AURORA_DBNAME:-lab_performance}"
export AURORA_PORT="${AURORA_PORT:-5432}"

export RDS_PROXY_NAME="${RDS_PROXY_NAME:-aurora-pg-proxy-lab}"

export AURORA_GLOBAL_CLUSTER_ID="${AURORA_GLOBAL_CLUSTER_ID:-aurora-lab-global}"
export AURORA_SECONDARY_CLUSTER_ID="${AURORA_SECONDARY_CLUSTER_ID:-aurora-lab-cluster-secondary}"
export AURORA_SECONDARY_INSTANCE_ID="${AURORA_SECONDARY_INSTANCE_ID:-aurora-lab-secondary-instance-1}"
export GLOBAL_SECONDARY_DB_SUBNET_GROUP="${GLOBAL_SECONDARY_DB_SUBNET_GROUP:-aurora-lab-global-secondary-subnet-group}"
export GLOBAL_SECONDARY_SG_NAME="${GLOBAL_SECONDARY_SG_NAME:-aurora-lab-global-secondary-sg}"

# Este script borra todo por defecto.
export DELETE_RDS_PROXY="${DELETE_RDS_PROXY:-true}"
export DELETE_GLOBAL_DB="${DELETE_GLOBAL_DB:-true}"
export DELETE_PRIMARY_AURORA="${DELETE_PRIMARY_AURORA:-true}"
export DELETE_NETWORK_RESOURCES="${DELETE_NETWORK_RESOURCES:-true}"
export DELETE_LOCAL_VARIABLES="${DELETE_LOCAL_VARIABLES:-true}"

# -----------------------------
# Funciones auxiliares
# -----------------------------
cluster_exists() {
  aws rds describe-db-clusters --region "$1" --db-cluster-identifier "$2" >/dev/null 2>&1
}

instance_exists() {
  aws rds describe-db-instances --region "$1" --db-instance-identifier "$2" >/dev/null 2>&1
}

proxy_exists() {
  aws rds describe-db-proxies --region "$1" --db-proxy-name "$2" >/dev/null 2>&1
}

global_exists() {
  aws rds describe-global-clusters --region "$1" --global-cluster-identifier "$2" >/dev/null 2>&1
}

cluster_arn() {
  aws rds describe-db-clusters \
    --region "$1" \
    --db-cluster-identifier "$2" \
    --query "DBClusters[0].DBClusterArn" \
    --output text 2>/dev/null || true
}

arn_region() {
  echo "$1" | awk -F: '{print $4}'
}

arn_cluster_id() {
  echo "$1" | awk -F: '{print $7}' | sed 's#^cluster/##' | sed 's#^cluster:##'
}

delete_instances_for_cluster() {
  local region="$1"
  local cluster_id="$2"

  log "Buscando instancias del clúster $cluster_id en $region"

  local instances
  instances=$(aws rds describe-db-instances \
    --region "$region" \
    --filters "Name=db-cluster-id,Values=$cluster_id" \
    --query "DBInstances[*].DBInstanceIdentifier" \
    --output text 2>/dev/null || true)

  if [[ -z "$instances" || "$instances" == "None" ]]; then
    warn "No se encontraron instancias para el clúster $cluster_id en $region."
    return 0
  fi

  for instance_id in $instances; do
    if instance_exists "$region" "$instance_id"; then
      local status
      status=$(aws rds describe-db-instances \
        --region "$region" \
        --db-instance-identifier "$instance_id" \
        --query "DBInstances[0].DBInstanceStatus" \
        --output text 2>/dev/null || echo "unknown")

      ok "Instancia encontrada: $instance_id | Estado: $status"

      if [[ "$status" == "deleting" ]]; then
        warn "La instancia $instance_id ya está en proceso de eliminación."
      else
        aws rds delete-db-instance \
          --region "$region" \
          --db-instance-identifier "$instance_id" \
          --skip-final-snapshot \
          --delete-automated-backups >/dev/null 2>&1 \
          || warn "No se pudo solicitar eliminación de instancia: $instance_id"
      fi
    fi
  done

  for instance_id in $instances; do
    log "Esperando eliminación de instancia: $instance_id"
    aws rds wait db-instance-deleted \
      --region "$region" \
      --db-instance-identifier "$instance_id" >/dev/null 2>&1 \
      && ok "Instancia eliminada: $instance_id" \
      || warn "No se confirmó eliminación de instancia: $instance_id"
  done
}

delete_cluster_if_exists() {
  local region="$1"
  local cluster_id="$2"

  if cluster_exists "$region" "$cluster_id"; then
    local status
    status=$(aws rds describe-db-clusters \
      --region "$region" \
      --db-cluster-identifier "$cluster_id" \
      --query "DBClusters[0].Status" \
      --output text 2>/dev/null || echo "unknown")

    ok "Clúster encontrado: $cluster_id | Estado: $status | Región: $region"

    if [[ "$status" == "deleting" ]]; then
      warn "El clúster $cluster_id ya está en proceso de eliminación."
    else
      aws rds delete-db-cluster \
        --region "$region" \
        --db-cluster-identifier "$cluster_id" \
        --skip-final-snapshot >/dev/null 2>&1 \
        || warn "No se pudo solicitar eliminación de clúster: $cluster_id"
    fi

    log "Esperando eliminación del clúster: $cluster_id"
    aws rds wait db-cluster-deleted \
      --region "$region" \
      --db-cluster-identifier "$cluster_id" >/dev/null 2>&1 \
      && ok "Clúster eliminado: $cluster_id" \
      || warn "No se confirmó eliminación del clúster: $cluster_id"
  else
    warn "No existe el clúster: $cluster_id en $region"
  fi
}

remove_cluster_from_global_if_member() {
  local global_id="$1"
  local cluster_identifier="$2"
  local global_region="$3"

  if [[ -z "$cluster_identifier" || "$cluster_identifier" == "None" ]]; then
    return 0
  fi

  if ! global_exists "$global_region" "$global_id"; then
    return 0
  fi

  log "Intentando remover miembro del Global Cluster"
  echo "Global Cluster: $global_id"
  echo "Miembro:        $cluster_identifier"

  aws rds remove-from-global-cluster \
    --region "$global_region" \
    --global-cluster-identifier "$global_id" \
    --db-cluster-identifier "$cluster_identifier" >/dev/null 2>&1 \
    && ok "Miembro removido del Global Cluster: $cluster_identifier" \
    || warn "No se pudo remover $cluster_identifier del Global Cluster o ya no era miembro."

  sleep 20
}

delete_global_cluster_if_empty() {
  local global_id="$1"
  local region="$2"

  if ! global_exists "$region" "$global_id"; then
    warn "Global Cluster no existe: $global_id"
    return 0
  fi

  local member_count
  member_count=$(aws rds describe-global-clusters \
    --region "$region" \
    --global-cluster-identifier "$global_id" \
    --query "length(GlobalClusters[0].GlobalClusterMembers)" \
    --output text 2>/dev/null || echo "0")

  if [[ "$member_count" == "0" ]]; then
    log "Eliminando Global Cluster vacío: $global_id"

    aws rds delete-global-cluster \
      --region "$region" \
      --global-cluster-identifier "$global_id" >/dev/null 2>&1 \
      && ok "Global Cluster eliminado: $global_id" \
      || warn "No se pudo eliminar Global Cluster: $global_id"
  else
    warn "Global Cluster $global_id conserva $member_count miembro(s). No se elimina todavía."
  fi
}

delete_security_group_by_name() {
  local region="$1"
  local sg_name="$2"

  local sg_id
  sg_id=$(aws ec2 describe-security-groups \
    --region "$region" \
    --filters "Name=group-name,Values=$sg_name" \
    --query "SecurityGroups[0].GroupId" \
    --output text 2>/dev/null || echo "None")

  if [[ -z "$sg_id" || "$sg_id" == "None" ]]; then
    warn "No se encontró Security Group: $sg_name en $region"
    return 0
  fi

  if aws ec2 delete-security-group \
    --region "$region" \
    --group-id "$sg_id" >/dev/null 2>&1; then
    ok "Security Group eliminado: $sg_id"
  else
    warn "No se pudo eliminar Security Group $sg_id. Puede tener dependencias activas."
  fi
}

# -----------------------------
# Validación AWS
# -----------------------------
log "Validando identidad AWS"

aws sts get-caller-identity --output table >/dev/null \
  || fail "No se pudo validar la identidad AWS. Revisa permisos o sesión de CloudShell."

aws configure set region "$AWS_PRIMARY_REGION" >/dev/null
ok "Región primaria configurada: $AWS_PRIMARY_REGION"

log "Recursos objetivo"

cat <<EOF
Región primaria:              $AWS_PRIMARY_REGION
Región secundaria:            $AWS_SECONDARY_REGION
Cluster Aurora primario:      $AURORA_CLUSTER_ID
Instancia writer esperada:    $AURORA_INSTANCE_ID
DB Subnet Group primario:     $DB_SUBNET_GROUP_NAME
Parameter Group primario:     $AURORA_PARAM_GROUP
Security Group primario:      $AURORA_SG_NAME
Base de datos:                $AURORA_DBNAME
RDS Proxy:                    $RDS_PROXY_NAME
Global DB:                    $AURORA_GLOBAL_CLUSTER_ID
Cluster secundario:           $AURORA_SECONDARY_CLUSTER_ID
Instancia secundaria:         $AURORA_SECONDARY_INSTANCE_ID
DB Subnet Group secundario:   $GLOBAL_SECONDARY_DB_SUBNET_GROUP
Security Group secundario:    $GLOBAL_SECONDARY_SG_NAME

DELETE_RDS_PROXY:             $DELETE_RDS_PROXY
DELETE_GLOBAL_DB:             $DELETE_GLOBAL_DB
DELETE_PRIMARY_AURORA:        $DELETE_PRIMARY_AURORA
DELETE_NETWORK_RESOURCES:     $DELETE_NETWORK_RESOURCES
DELETE_LOCAL_VARIABLES:       $DELETE_LOCAL_VARIABLES
EOF

# -----------------------------
# Empaquetar evidencia
# -----------------------------
log "Empaquetando evidencia local 09_* si existe"

if ls 09_* >/dev/null 2>&1; then
  tar -czf "09_evidencia_integrador_$(date +%Y%m%d-%H%M%S).tar.gz" 09_* 2>/dev/null || true
  ok "Evidencia 09_* empaquetada"
else
  warn "No se encontraron archivos 09_* para empaquetar."
fi

# -----------------------------
# Limpieza lógica si Aurora aún está disponible
# -----------------------------
log "Intentando limpiar objetos temporales de base de datos si existe conectividad"

AURORA_ENDPOINT="${AURORA_ENDPOINT:-}"

if [[ -z "$AURORA_ENDPOINT" || "$AURORA_ENDPOINT" == "None" ]]; then
  AURORA_ENDPOINT=$(aws rds describe-db-clusters \
    --region "$AWS_PRIMARY_REGION" \
    --db-cluster-identifier "$AURORA_CLUSTER_ID" \
    --query "DBClusters[0].Endpoint" \
    --output text 2>/dev/null || true)
fi

if [[ -n "$AURORA_ENDPOINT" && "$AURORA_ENDPOINT" != "None" && -n "${AURORA_MASTER_USER:-}" && -n "${AURORA_MASTER_PASSWORD:-}" ]]; then
  if command -v psql >/dev/null 2>&1; then
    PG_CONN_LAB="host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require connect_timeout=10"

    if psql "$PG_CONN_LAB" -v ON_ERROR_STOP=1 -c "SELECT 1;" >/dev/null 2>&1; then
      psql "$PG_CONN_LAB" -v ON_ERROR_STOP=1 -c "DROP TABLE IF EXISTS pgbench_accounts, pgbench_branches, pgbench_history, pgbench_tellers CASCADE;" >/dev/null 2>&1 || true
      psql "$PG_CONN_LAB" -v ON_ERROR_STOP=1 -c "DROP SCHEMA IF EXISTS lab9_benchmark CASCADE;" >/dev/null 2>&1 || true
      psql "$PG_CONN_LAB" -v ON_ERROR_STOP=1 -c "DROP SCHEMA IF EXISTS lab_globaldb CASCADE;" >/dev/null 2>&1 || true
      ok "Objetos temporales eliminados o inexistentes"
    else
      warn "No se pudo conectar a Aurora para limpieza lógica. Continuando."
    fi
  else
    warn "psql no está disponible. Se omite limpieza lógica."
  fi
else
  warn "No hay endpoint o credenciales suficientes para limpieza lógica. Continuando."
fi

# -----------------------------
# Eliminar RDS Proxy
# -----------------------------
log "Eliminando RDS Proxy si existe"

if [[ "$DELETE_RDS_PROXY" == "true" ]]; then
  if proxy_exists "$AWS_PRIMARY_REGION" "$RDS_PROXY_NAME"; then
    warn "Se eliminará RDS Proxy: $RDS_PROXY_NAME"

    aws rds delete-db-proxy \
      --region "$AWS_PRIMARY_REGION" \
      --db-proxy-name "$RDS_PROXY_NAME" >/dev/null 2>&1 \
      || warn "No se pudo solicitar eliminación de RDS Proxy."

    for i in {1..60}; do
      if proxy_exists "$AWS_PRIMARY_REGION" "$RDS_PROXY_NAME"; then
        printf "."
        sleep 10
      else
        printf "\n"
        ok "RDS Proxy eliminado: $RDS_PROXY_NAME"
        break
      fi
      [[ "$i" -eq 60 ]] && warn "El RDS Proxy no terminó de eliminarse en el tiempo esperado."
    done
  else
    warn "No existe el RDS Proxy: $RDS_PROXY_NAME"
  fi
else
  warn "DELETE_RDS_PROXY=false. No se elimina RDS Proxy."
fi

# -----------------------------
# Eliminar Aurora Global Database completo
# -----------------------------
log "Eliminando Aurora Global Database y recursos secundarios si existen"

if [[ "$DELETE_GLOBAL_DB" == "true" ]]; then

  if global_exists "$AWS_PRIMARY_REGION" "$AURORA_GLOBAL_CLUSTER_ID"; then
    log "Guardando descripción actual del Global Cluster"

    aws rds describe-global-clusters \
      --region "$AWS_PRIMARY_REGION" \
      --global-cluster-identifier "$AURORA_GLOBAL_CLUSTER_ID" \
      --output json > 09_global_database_pre_delete.json 2>/dev/null || true

    MEMBER_ARNS=$(aws rds describe-global-clusters \
      --region "$AWS_PRIMARY_REGION" \
      --global-cluster-identifier "$AURORA_GLOBAL_CLUSTER_ID" \
      --query "GlobalClusters[0].GlobalClusterMembers[*].DBClusterArn" \
      --output text 2>/dev/null || true)

    # Primero eliminar miembros secundarios detectados.
    for MEMBER_ARN in $MEMBER_ARNS; do
      MEMBER_REGION=$(arn_region "$MEMBER_ARN")
      MEMBER_CLUSTER_ID=$(arn_cluster_id "$MEMBER_ARN")

      if [[ "$MEMBER_CLUSTER_ID" == "$AURORA_CLUSTER_ID" ]]; then
        continue
      fi

      log "Procesando miembro secundario Global DB"
      echo "ARN:     $MEMBER_ARN"
      echo "Región:  $MEMBER_REGION"
      echo "Cluster: $MEMBER_CLUSTER_ID"

      delete_instances_for_cluster "$MEMBER_REGION" "$MEMBER_CLUSTER_ID"

      remove_cluster_from_global_if_member \
        "$AURORA_GLOBAL_CLUSTER_ID" \
        "$MEMBER_ARN" \
        "$AWS_PRIMARY_REGION"

      delete_cluster_if_exists "$MEMBER_REGION" "$MEMBER_CLUSTER_ID"
    done

    # También intentar con el nombre secundario estándar.
    if cluster_exists "$AWS_SECONDARY_REGION" "$AURORA_SECONDARY_CLUSTER_ID"; then
      delete_instances_for_cluster "$AWS_SECONDARY_REGION" "$AURORA_SECONDARY_CLUSTER_ID"

      SECONDARY_CLUSTER_ARN=$(cluster_arn "$AWS_SECONDARY_REGION" "$AURORA_SECONDARY_CLUSTER_ID")

      remove_cluster_from_global_if_member \
        "$AURORA_GLOBAL_CLUSTER_ID" \
        "$SECONDARY_CLUSTER_ARN" \
        "$AWS_PRIMARY_REGION"

      delete_cluster_if_exists "$AWS_SECONDARY_REGION" "$AURORA_SECONDARY_CLUSTER_ID"
    fi

    # Remover primario del Global Cluster para poder cerrar todo.
    PRIMARY_CLUSTER_ARN=$(cluster_arn "$AWS_PRIMARY_REGION" "$AURORA_CLUSTER_ID")

    if [[ -n "$PRIMARY_CLUSTER_ARN" && "$PRIMARY_CLUSTER_ARN" != "None" ]]; then
      remove_cluster_from_global_if_member \
        "$AURORA_GLOBAL_CLUSTER_ID" \
        "$PRIMARY_CLUSTER_ARN" \
        "$AWS_PRIMARY_REGION"
    fi

    delete_global_cluster_if_empty "$AURORA_GLOBAL_CLUSTER_ID" "$AWS_PRIMARY_REGION"

  else
    warn "No existe Aurora Global Database: $AURORA_GLOBAL_CLUSTER_ID"

    if cluster_exists "$AWS_SECONDARY_REGION" "$AURORA_SECONDARY_CLUSTER_ID"; then
      delete_instances_for_cluster "$AWS_SECONDARY_REGION" "$AURORA_SECONDARY_CLUSTER_ID"
      delete_cluster_if_exists "$AWS_SECONDARY_REGION" "$AURORA_SECONDARY_CLUSTER_ID"
    fi
  fi

else
  warn "DELETE_GLOBAL_DB=false. No se elimina Aurora Global Database."
fi

# -----------------------------
# Eliminar instancia(s) y clúster Aurora primario
# -----------------------------
log "Eliminando Aurora primario"

if [[ "$DELETE_PRIMARY_AURORA" == "true" ]]; then

  if global_exists "$AWS_PRIMARY_REGION" "$AURORA_GLOBAL_CLUSTER_ID"; then
    PRIMARY_CLUSTER_ARN=$(cluster_arn "$AWS_PRIMARY_REGION" "$AURORA_CLUSTER_ID")

    if [[ -n "$PRIMARY_CLUSTER_ARN" && "$PRIMARY_CLUSTER_ARN" != "None" ]]; then
      remove_cluster_from_global_if_member \
        "$AURORA_GLOBAL_CLUSTER_ID" \
        "$PRIMARY_CLUSTER_ARN" \
        "$AWS_PRIMARY_REGION"
    fi

    delete_global_cluster_if_empty "$AURORA_GLOBAL_CLUSTER_ID" "$AWS_PRIMARY_REGION"
  fi

  if cluster_exists "$AWS_PRIMARY_REGION" "$AURORA_CLUSTER_ID"; then
    delete_instances_for_cluster "$AWS_PRIMARY_REGION" "$AURORA_CLUSTER_ID"
    delete_cluster_if_exists "$AWS_PRIMARY_REGION" "$AURORA_CLUSTER_ID"
  else
    warn "No existe el clúster primario: $AURORA_CLUSTER_ID"
  fi

else
  warn "DELETE_PRIMARY_AURORA=false. No se elimina Aurora primario."
fi

# -----------------------------
# Eliminar DB Subnet Groups
# -----------------------------
log "Eliminando DB Subnet Groups"

if [[ "$DELETE_NETWORK_RESOURCES" == "true" ]]; then

  if aws rds describe-db-subnet-groups --region "$AWS_SECONDARY_REGION" --db-subnet-group-name "$GLOBAL_SECONDARY_DB_SUBNET_GROUP" >/dev/null 2>&1; then
    aws rds delete-db-subnet-group --region "$AWS_SECONDARY_REGION" --db-subnet-group-name "$GLOBAL_SECONDARY_DB_SUBNET_GROUP" >/dev/null 2>&1 \
      && ok "DB Subnet Group secundario eliminado: $GLOBAL_SECONDARY_DB_SUBNET_GROUP" \
      || warn "No se pudo eliminar DB Subnet Group secundario. Puede tener dependencias."
  else
    warn "No existe DB Subnet Group secundario: $GLOBAL_SECONDARY_DB_SUBNET_GROUP"
  fi

  if aws rds describe-db-subnet-groups --region "$AWS_PRIMARY_REGION" --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" >/dev/null 2>&1; then
    aws rds delete-db-subnet-group --region "$AWS_PRIMARY_REGION" --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" >/dev/null 2>&1 \
      && ok "DB Subnet Group primario eliminado: $DB_SUBNET_GROUP_NAME" \
      || warn "No se pudo eliminar DB Subnet Group primario. Puede tener dependencias."
  else
    warn "No existe DB Subnet Group primario: $DB_SUBNET_GROUP_NAME"
  fi

else
  warn "DELETE_NETWORK_RESOURCES=false. No se eliminan DB Subnet Groups."
fi

# -----------------------------
# Eliminar DB Cluster Parameter Group
# -----------------------------
log "Eliminando DB Cluster Parameter Group"

if aws rds describe-db-cluster-parameter-groups --region "$AWS_PRIMARY_REGION" --db-cluster-parameter-group-name "$AURORA_PARAM_GROUP" >/dev/null 2>&1; then
  aws rds delete-db-cluster-parameter-group --region "$AWS_PRIMARY_REGION" --db-cluster-parameter-group-name "$AURORA_PARAM_GROUP" >/dev/null 2>&1 \
    && ok "Parameter Group eliminado: $AURORA_PARAM_GROUP" \
    || warn "No se pudo eliminar Parameter Group. Puede tener dependencias."
else
  warn "No existe el Parameter Group: $AURORA_PARAM_GROUP"
fi

# -----------------------------
# Eliminar Security Groups
# -----------------------------
log "Resolviendo y eliminando Security Groups"

if [[ "$DELETE_NETWORK_RESOURCES" == "true" ]]; then
  delete_security_group_by_name "$AWS_PRIMARY_REGION" "$AURORA_SG_NAME"
  delete_security_group_by_name "$AWS_SECONDARY_REGION" "$GLOBAL_SECONDARY_SG_NAME"
else
  warn "DELETE_NETWORK_RESOURCES=false. No se eliminan Security Groups."
fi

# -----------------------------
# Limpieza local
# -----------------------------
log "Limpieza local"

if [[ "$DELETE_LOCAL_VARIABLES" == "true" ]]; then
  for file in "$ENV_FILE" "$GLOBAL_ENV_FILE" ./09_globaldb_network_fix_env.sh; do
    if [[ -f "$file" ]]; then
      rm -f "$file"
      ok "Archivo local eliminado: $file"
    else
      warn "No existe archivo local: $file"
    fi
  done
else
  warn "DELETE_LOCAL_VARIABLES=false. No se eliminan archivos locales de variables."
fi

warn "Se conservan archivos de evidencia 09_* si existen."
warn "Para eliminarlos manualmente ejecuta: rm -f 09_*"

# -----------------------------
# Validación final
# -----------------------------
log "Validación final"

INSTANCE_EXISTS="no"
CLUSTER_EXISTS="no"
SECONDARY_INSTANCE_EXISTS="no"
SECONDARY_CLUSTER_EXISTS="no"
SUBNET_GROUP_EXISTS="no"
SECONDARY_SUBNET_GROUP_EXISTS="no"
PARAM_GROUP_EXISTS="no"
PROXY_EXISTS="no"
GLOBAL_EXISTS="no"

instance_exists "$AWS_PRIMARY_REGION" "$AURORA_INSTANCE_ID" && INSTANCE_EXISTS="sí"
cluster_exists "$AWS_PRIMARY_REGION" "$AURORA_CLUSTER_ID" && CLUSTER_EXISTS="sí"
instance_exists "$AWS_SECONDARY_REGION" "$AURORA_SECONDARY_INSTANCE_ID" && SECONDARY_INSTANCE_EXISTS="sí"
cluster_exists "$AWS_SECONDARY_REGION" "$AURORA_SECONDARY_CLUSTER_ID" && SECONDARY_CLUSTER_EXISTS="sí"
aws rds describe-db-subnet-groups --region "$AWS_PRIMARY_REGION" --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" >/dev/null 2>&1 && SUBNET_GROUP_EXISTS="sí"
aws rds describe-db-subnet-groups --region "$AWS_SECONDARY_REGION" --db-subnet-group-name "$GLOBAL_SECONDARY_DB_SUBNET_GROUP" >/dev/null 2>&1 && SECONDARY_SUBNET_GROUP_EXISTS="sí"
aws rds describe-db-cluster-parameter-groups --region "$AWS_PRIMARY_REGION" --db-cluster-parameter-group-name "$AURORA_PARAM_GROUP" >/dev/null 2>&1 && PARAM_GROUP_EXISTS="sí"
proxy_exists "$AWS_PRIMARY_REGION" "$RDS_PROXY_NAME" && PROXY_EXISTS="sí"
global_exists "$AWS_PRIMARY_REGION" "$AURORA_GLOBAL_CLUSTER_ID" && GLOBAL_EXISTS="sí"

cat <<EOF | tee 09_eliminacion_estado_final.txt
Instancia primaria existe:          $INSTANCE_EXISTS
Clúster primario existe:            $CLUSTER_EXISTS
Instancia secundaria existe:        $SECONDARY_INSTANCE_EXISTS
Clúster secundario existe:          $SECONDARY_CLUSTER_EXISTS
DB Subnet Group primario existe:    $SUBNET_GROUP_EXISTS
DB Subnet Group secundario existe:  $SECONDARY_SUBNET_GROUP_EXISTS
Parameter Group existe:             $PARAM_GROUP_EXISTS
RDS Proxy existe:                   $PROXY_EXISTS
Aurora Global Database existe:      $GLOBAL_EXISTS
EOF

ok "Cierre/eliminación completa del Laboratorio 9 finalizada"

echo ""
echo "Evidencia conservada:"
ls -lh 09_evidencia_integrador_*.tar.gz 2>/dev/null || true
echo ""
echo "Estado final:"
cat 09_eliminacion_estado_final.txt
