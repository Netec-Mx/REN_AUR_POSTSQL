<h1 align="center">🔌 Laboratorio 6. Gestión de conexiones con RDS Proxy</h1>

---

## 1. 🧾 Información general de la práctica


## 📘 Descripción general

En este laboratorio vas a configurar y validar **Amazon RDS Proxy** como capa de gestión de conexiones para un clúster **AWS Aurora PostgreSQL**. Verificarás los prerrequisitos de IAM, Secrets Manager, red y seguridad; crearás o reutilizarás un proxy; registrarás el clúster Aurora como target; configurarás parámetros básicos de pooling; validarás conexión vía proxy; ejecutarás una comparación ligera entre conexión directa y conexión vía proxy; y revisarás métricas de CloudWatch para observar el comportamiento del pool.

El objetivo principal no es demostrar que RDS Proxy siempre aumenta el TPS. El aprendizaje correcto es entender que RDS Proxy ayuda a:

- Reducir churn de conexiones.
- Proteger la base de datos ante picos de clientes.
- Reutilizar conexiones hacia Aurora.
- Separar conexiones cliente de conexiones reales al motor.
- Mejorar resiliencia de conexión en ciertos escenarios.
- Observar métricas como `ClientConnections` y `DatabaseConnections`.

La práctica está diseñada para completarse en **35 minutos**, por eso asume que los recursos base de red, secreto e IAM ya existen o fueron preparados previamente por el script de preparación.

La práctica está diseñada como una serie de **retos guiados**. En cada reto primero intentarás resolver el objetivo con pistas. Si te bloqueas, podrás abrir la **solución sugerida**. La solución está oculta para fomentar el razonamiento, pero es completa y funcional para no extender el tiempo del laboratorio.

El enfoque principal es el ciclo básico de gestión de conexiones:

> **Preparar → Validar conexión directa → Crear proxy → Registrar target → Probar proxy → Comparar → Observar métricas → Validar → Limpiar**

---

## 🎯 Objetivos de aprendizaje

Al finalizar este laboratorio, podrás:

- Validar los prerrequisitos necesarios para usar RDS Proxy con Aurora PostgreSQL.
- Crear o reutilizar un RDS Proxy para PostgreSQL.
- Registrar un clúster Aurora PostgreSQL como target del proxy.
- Configurar parámetros básicos de connection pooling.
- Conectarte a Aurora PostgreSQL a través del endpoint del proxy.
- Comparar una conexión directa contra una conexión vía proxy con carga ligera.
- Consultar métricas de CloudWatch relacionadas con RDS Proxy.
- Explicar la diferencia entre `ClientConnections` y `DatabaseConnections`.
- Guardar evidencia técnica del laboratorio.
- Limpiar el proxy de forma opcional si no se usará después.

---

## ✅ Prerrequisitos

Antes de iniciar, debes contar con:

- Ejecutar antes de comenzar el script `00_preparar_laboratorio_6_aurora.sh` desde **AWS CloudShell** o contar con recursos equivalentes ya disponibles.
- Haber completado los laboratorios anteriores o contar con un clúster Aurora PostgreSQL activo.
- Acceso a AWS CloudShell.
- Permisos IAM para:
  - `rds:CreateDBProxy`
  - `rds:DescribeDBProxies`
  - `rds:DeleteDBProxy`
  - `rds:RegisterDBProxyTargets`
  - `rds:DeregisterDBProxyTargets`
  - `rds:DescribeDBProxyTargets`
  - `rds:DescribeDBProxyTargetGroups`
  - `rds:ModifyDBProxyTargetGroup`
  - `rds:DescribeDBClusters`
  - `secretsmanager:DescribeSecret`
  - `secretsmanager:GetSecretValue`
  - `iam:GetRole`
  - `ec2:DescribeSubnets`
  - `ec2:DescribeSecurityGroups`
  - `cloudwatch:GetMetricStatistics`
  - `cloudwatch:ListMetrics`
- Un secreto en AWS Secrets Manager con las credenciales de Aurora PostgreSQL.
- Un IAM Role para RDS Proxy con permiso para leer el secreto.
- Subnets válidas en la VPC del clúster Aurora.
- Security Group que permita tráfico TCP 5432 entre el proxy y Aurora.
- Cliente `psql` disponible.
- Cliente `pgbench` disponible.
- Python 3 disponible.

> ⚠️ **Importante:** Si debes crear desde cero el secreto, el IAM Role, las subnets o los security groups, esta práctica puede tomar más de 35 minutos. En ese caso, prepara esos recursos antes de iniciar el laboratorio.

---

## 🖥️ Hardware

| Recurso | Recomendación |
|---|---|
| Equipo local | Navegador web moderno |
| CPU local | No aplica, se usa AWS CloudShell |
| RAM local | No aplica |
| Almacenamiento local | No aplica |
| Red | Acceso estable a la consola AWS |
| Ambiente de ejecución | AWS CloudShell |

---

## 🧰 Software

| Software | Uso |
|---|---|
| AWS CloudShell | Ambiente principal de ejecución |
| Bash | Ejecución de comandos |
| AWS CLI | Creación, validación y limpieza de RDS Proxy |
| psql | Validación SQL directa y vía proxy |
| pgbench | Carga ligera comparativa |
| Python 3 | Extracción básica de métricas |
| jq | Procesamiento de JSON de Secrets Manager |
| CloudWatch | Métricas de conexiones del proxy |
| Aurora PostgreSQL | Motor de base de datos |

---

---

## 🧱 Valores estandarizados del laboratorio

Usa estos valores durante toda la práctica para mantener consistencia entre los retos, las validaciones y la limpieza final.

| Tipo | Nombre / valor estándar | Uso |
|---|---|---|
| Región | `$AWS_REGION` | Región activa de AWS CLI o `us-west-2` como valor por defecto del script previo |
| Cluster ID | `aurora-performance-lab-cluster` | Identificador esperado del clúster Aurora |
| Endpoint writer | `$AURORA_ENDPOINT` | Endpoint writer de Aurora PostgreSQL |
| Puerto | `5432` | Puerto estándar PostgreSQL |
| Base de datos | `lab_performance` | Base usada para validaciones y pruebas |
| Usuario administrador | `labadmin` | Usuario master del laboratorio |
| Contraseña temporal | `AuroraLab_2026_Temporal!` | Contraseña de laboratorio, cámbiala si tu instructor lo solicita |
| Nombre del proxy | `aurora-pg-proxy-lab` | RDS Proxy del laboratorio |
| Secreto | `$RDS_PROXY_SECRET_ARN` | Secreto con credenciales PostgreSQL |
| IAM Role | `$RDS_PROXY_ROLE_ARN` | Rol que RDS Proxy usa para leer el secreto |
| Subnets del proxy | `$RDS_PROXY_SUBNET_IDS` | Subnets usadas por RDS Proxy |
| Security Group del proxy | `$RDS_PROXY_SECURITY_GROUP_ID` | Security Group asociado al proxy |
| Endpoint del proxy | `$RDS_PROXY_ENDPOINT` | Endpoint para conectar vía RDS Proxy |
| Target group | `$RDS_PROXY_TARGET_GROUP` | Target group default del proxy |
| MaxConnectionsPercent | `80` | Porcentaje máximo de conexiones hacia la base |
| MaxIdleConnectionsPercent | `40` | Porcentaje máximo de conexiones inactivas |
| ConnectionBorrowTimeout | `120` | Tiempo máximo de espera para obtener conexión |
| IdleClientTimeout | `1800` | Tiempo de inactividad de cliente |
| Archivo de variables | `./lab6_aurora_env.sh` | Variables exportadas para el laboratorio |
| Evidencia conexión directa | `06_direct_connection_check.txt` | Validación directa contra Aurora |
| Evidencia proxy | `06_proxy_connection_check.txt` | Validación vía RDS Proxy |
| Métricas proxy | `06_proxy_metrics.txt` | Métricas CloudWatch consultadas |
| Resumen | `06_resumen_rds_proxy.md` | Resumen técnico del laboratorio |
| Paquete evidencia | `06_rds_proxy_evidencia_*.tar.gz` | Evidencia comprimida |

---

## 🚦 Preparación previa obligatoria antes de comenzar

Antes de iniciar el **Reto 1**, ejecuta el script de preparación desde **AWS CloudShell**. Este script crea o reutiliza los recursos mínimos requeridos para la práctica: clúster Aurora PostgreSQL, base `lab_performance`, secreto de Secrets Manager, IAM Role para RDS Proxy, subnets, Security Group, clientes `psql` y `pgbench`, y archivo de variables `lab6_aurora_env.sh`.

> ⚠️ **Costo y seguridad:** El script puede crear recursos que generan cargos. Usa esta configuración solo en laboratorio y elimina o restringe los recursos al terminar.

### Comandos de ejecución previa

```bash
chmod +x 00_preparar_laboratorio_6_aurora.sh
./00_preparar_laboratorio_6_aurora.sh
source ./lab6_aurora_env.sh
```

### Validación previa rápida

```bash
echo "$AURORA_ENDPOINT"
echo "$RDS_PROXY_NAME"
echo "$RDS_PROXY_SECRET_ARN"
echo "$RDS_PROXY_ROLE_ARN"
echo "$RDS_PROXY_SUBNET_IDS"
echo "$RDS_PROXY_SECURITY_GROUP_ID"

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;"
```

Resultado esperado:

```text
current_database = lab_performance
es_replica = f
variables RDS_PROXY_* definidas
```

Después de esta validación, continúa con el **Reto 1**.

## ⏱️ Tabla de tiempo, complejidad y nivel Bloom

| Elemento | Detalle |
|---|---|
| Duración total | 35 minutos |
| Complejidad | Media |
| Nivel Bloom | Aplicar / Analizar |
| Modalidad | Retos guiados con solución oculta |
| Motor | Amazon Aurora PostgreSQL |
| Servicio complementario | Amazon RDS Proxy |
| Entorno | AWS CloudShell |
| Enfoque | Connection pooling, validación de proxy y métricas |

---

## 🗓️ Distribución de tiempo por reto

| Reto | Actividad | Tiempo |
|---|---|---:|
| Reto 1 | Validar prerrequisitos y variables | 4 min |
| Reto 2 | Validar conexión directa a Aurora | 4 min |
| Reto 3 | Crear o verificar RDS Proxy | 7 min |
| Reto 4 | Registrar Aurora como target y configurar pooling | 5 min |
| Reto 5 | Validar conexión vía proxy | 4 min |
| Reto 6 | Comparar conexión directa vs proxy con carga ligera | 5 min |
| Reto 7 | Consultar métricas CloudWatch del proxy | 3 min |
| Reto 8 | Validar estado final previo a limpieza | 2 min |
| Reto 9 | Eliminar recursos del laboratorio | 1 min |
| **Total** |  | **35 min** |

> 💡 **Nota operativa:** RDS Proxy puede tardar varios minutos en quedar disponible. Si el proxy ya existe, el laboratorio será más fluido. Si se crea desde cero, el Reto 3 puede consumir más tiempo dependiendo de la región y del estado de la red.

---

# 2. 🧪 Desarrollo de la práctica

---

# 🧩 Reto 1. Validar prerrequisitos y variables

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Validar que existen los recursos mínimos para crear o reutilizar RDS Proxy: clúster Aurora, secreto en Secrets Manager, IAM Role, subnets y security group.

---

## 🧠 Escenario

RDS Proxy no funciona de forma aislada. Necesita un secreto para autenticarse contra la base, un rol IAM para leer ese secreto y conectividad de red hacia Aurora. Antes de crear el proxy, debes validar que todos esos elementos existen.

---

## 🛠️ Tu reto

Valida:

- Identidad AWS.
- Región.
- Variables `AURORA_*`.
- Variables `RDS_PROXY_*`.
- Secreto de Secrets Manager.
- IAM Role.
- Subnets.
- Security Group.
- Directorio de trabajo.

---

## 💡 Pistas

- Usa variables consistentes con los laboratorios anteriores.
- `RDS_PROXY_SUBNET_IDS` debe contener al menos dos subnets separadas por coma.
- El security group debe permitir conectividad hacia Aurora en el puerto 5432.
- El secreto debe contener usuario y contraseña compatibles con Aurora PostgreSQL.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Validar identidad AWS ==="
aws sts get-caller-identity --output table

echo "=== Configurar región ==="
export AWS_REGION="$(aws configure get region)"

if [ -z "$AWS_REGION" ]; then
  export AWS_REGION="us-east-1"
fi

echo "Región configurada: $AWS_REGION"

echo "=== Definir variables Aurora ==="

export AURORA_CLUSTER_ID="${AURORA_CLUSTER_ID:-aurora-performance-lab-cluster}"
export AURORA_PORT="${AURORA_PORT:-5432}"
export AURORA_DBNAME="${AURORA_DBNAME:-lab_performance}"
export AURORA_MASTER_USER="${AURORA_MASTER_USER:-labadmin}"
export AURORA_MASTER_PASSWORD="${AURORA_MASTER_PASSWORD:-AuroraLab_2026_Temporal!}"

if [ -z "$AURORA_ENDPOINT" ]; then
  export AURORA_ENDPOINT=$(aws rds describe-db-clusters \
    --db-cluster-identifier "$AURORA_CLUSTER_ID" \
    --region "$AWS_REGION" \
    --query "DBClusters[0].Endpoint" \
    --output text)
fi

echo "Cluster Aurora: $AURORA_CLUSTER_ID"
echo "Endpoint Aurora: $AURORA_ENDPOINT"
echo "Base: $AURORA_DBNAME"
echo "Usuario: $AURORA_MASTER_USER"

echo "=== Definir variables RDS Proxy ==="

# Ajusta estos valores con los recursos preparados para tu laboratorio.
export RDS_PROXY_NAME="${RDS_PROXY_NAME:-aurora-pg-proxy-lab}"
export RDS_PROXY_SECRET_ARN="${RDS_PROXY_SECRET_ARN:-<secret-arn>}"
export RDS_PROXY_ROLE_ARN="${RDS_PROXY_ROLE_ARN:-<iam-role-arn>}"
export RDS_PROXY_SUBNET_IDS="${RDS_PROXY_SUBNET_IDS:-<subnet-1>,<subnet-2>}"
export RDS_PROXY_SECURITY_GROUP_ID="${RDS_PROXY_SECURITY_GROUP_ID:-<sg-id>}"

echo "Proxy: $RDS_PROXY_NAME"
echo "Secret ARN: $RDS_PROXY_SECRET_ARN"
echo "Role ARN: $RDS_PROXY_ROLE_ARN"
echo "Subnets: $RDS_PROXY_SUBNET_IDS"
echo "Security Group: $RDS_PROXY_SECURITY_GROUP_ID"

if [[ "$RDS_PROXY_SECRET_ARN" == "<secret-arn>" ]]; then
  echo "ERROR: Debes definir RDS_PROXY_SECRET_ARN."
  exit 1
fi

if [[ "$RDS_PROXY_ROLE_ARN" == "<iam-role-arn>" ]]; then
  echo "ERROR: Debes definir RDS_PROXY_ROLE_ARN."
  exit 1
fi

if [[ "$RDS_PROXY_SUBNET_IDS" == "<subnet-1>,<subnet-2>" ]]; then
  echo "ERROR: Debes definir RDS_PROXY_SUBNET_IDS."
  exit 1
fi

if [[ "$RDS_PROXY_SECURITY_GROUP_ID" == "<sg-id>" ]]; then
  echo "ERROR: Debes definir RDS_PROXY_SECURITY_GROUP_ID."
  exit 1
fi

echo "=== Preparar directorios ==="

export LAB_DIR="$HOME/lab-03-00-02"
mkdir -p "$LAB_DIR"/{scripts,results}
cd "$LAB_DIR"

echo "Directorio de trabajo: $LAB_DIR"

echo "=== Validar secreto ==="

aws secretsmanager describe-secret \
  --secret-id "$RDS_PROXY_SECRET_ARN" \
  --region "$AWS_REGION" \
  --query "{Nombre:Name,ARN:ARN}" \
  --output table

echo "=== Validar IAM Role ==="

ROLE_NAME=$(basename "$RDS_PROXY_ROLE_ARN")

aws iam get-role \
  --role-name "$ROLE_NAME" \
  --query "Role.{RoleName:RoleName,Arn:Arn}" \
  --output table

echo "=== Validar subnets ==="

aws ec2 describe-subnets \
  --subnet-ids $(echo "$RDS_PROXY_SUBNET_IDS" | tr ',' ' ') \
  --region "$AWS_REGION" \
  --query "Subnets[*].{SubnetId:SubnetId,VpcId:VpcId,AZ:AvailabilityZone}" \
  --output table

echo "=== Validar security group ==="

aws ec2 describe-security-groups \
  --group-ids "$RDS_PROXY_SECURITY_GROUP_ID" \
  --region "$AWS_REGION" \
  --query "SecurityGroups[*].{GroupId:GroupId,GroupName:GroupName,VpcId:VpcId}" \
  --output table
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
echo "$RDS_PROXY_NAME"
echo "$RDS_PROXY_SECRET_ARN"
echo "$RDS_PROXY_ROLE_ARN"
echo "$RDS_PROXY_SUBNET_IDS"
echo "$RDS_PROXY_SECURITY_GROUP_ID"
```

---

## 📌 Resultado esperado

Debes tener todas las variables definidas con valores reales, no placeholders:

```text
RDS_PROXY_NAME definido
RDS_PROXY_SECRET_ARN definido
RDS_PROXY_ROLE_ARN definido
RDS_PROXY_SUBNET_IDS definido
RDS_PROXY_SECURITY_GROUP_ID definido
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20qu%C3%A9%20prerrequisitos%20necesita%20Amazon%20RDS%20Proxy%20para%20Aurora%20PostgreSQL%2C%20incluyendo%20Secrets%20Manager%2C%20IAM%20Role%2C%20subnets%20y%20security%20groups.)

---

# 🧩 Reto 2. Validar conexión directa a Aurora

## ⏱️ Tiempo estimado

**4 minutos**

---

## 🎯 Objetivo del reto

Confirmar que CloudShell puede conectarse directamente al writer endpoint de Aurora PostgreSQL antes de introducir RDS Proxy.

---

## 🧠 Escenario

Antes de probar el proxy, debes confirmar que la base está disponible y que las credenciales funcionan. Si la conexión directa falla, RDS Proxy también fallará o quedará sin target saludable.

---

## 🛠️ Tu reto

Valida:

- Conexión directa.
- Base de datos actual.
- Usuario actual.
- Rol writer con `pg_is_in_recovery()`.
- Disponibilidad de `pgbench`.

---

## 💡 Pistas

- `pg_is_in_recovery() = false` indica writer.
- Usa `sslmode=require`.
- Si la base `lab_performance` no existe, ajusta `AURORA_DBNAME` a `postgres`.
- El proxy usará las credenciales almacenadas en Secrets Manager, pero esta prueba directa confirma conectividad básica.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Validar herramientas ==="

if ! command -v psql >/dev/null 2>&1; then
  echo "psql no existe. Intentando instalar cliente PostgreSQL..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y postgresql15
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y postgresql15
  else
    echo "No se encontró dnf ni yum. Solicita al instructor un CloudShell con psql disponible."
    exit 1
  fi
fi

if ! command -v pgbench >/dev/null 2>&1; then
  echo "pgbench no existe. Intentando instalar herramientas contrib de PostgreSQL..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y postgresql15-contrib || sudo dnf install -y postgresql-contrib
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y postgresql15-contrib || sudo yum install -y postgresql-contrib
  else
    echo "No se encontró dnf ni yum. Solicita al instructor un CloudShell con pgbench disponible."
    exit 1
  fi
fi

psql --version
pgbench --version

echo "=== Validar conexión directa al writer ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;" \
  -c "SHOW max_connections;" \
  2>&1 | tee "$LAB_DIR/results/direct_connection_check.txt"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
grep "f" "$LAB_DIR/results/direct_connection_check.txt" || true
```

---

## 📌 Resultado esperado

Debes confirmar que `pg_is_in_recovery()` devuelve:

```text
f
```

Esto significa que estás conectado al writer.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20validar%20conexi%C3%B3n%20directa%20al%20writer%20endpoint%20de%20Aurora%20PostgreSQL%20antes%20de%20crear%20RDS%20Proxy.)

---

# 🧩 Reto 3. Crear o verificar RDS Proxy

## ⏱️ Tiempo estimado

**8 minutos**

---

## 🎯 Objetivo del reto

Crear un RDS Proxy para Aurora PostgreSQL o reutilizarlo si ya existe.

---

## 🧠 Escenario

RDS Proxy actúa como una capa intermedia entre clientes y Aurora. Los clientes se conectan al proxy y el proxy administra conexiones reales hacia la base de datos. Esto ayuda a controlar picos de conexión y mejorar el manejo de conexiones de corta duración.

---

## 🛠️ Tu reto

Realiza:

- Verificar si el proxy ya existe.
- Si no existe, crearlo.
- Esperar a que esté `available`.
- Capturar el endpoint del proxy.

---

## 💡 Pistas

- Usa `--engine-family POSTGRESQL`.
- Usa `--require-tls`.
- Usa `--idle-client-timeout 1800`.
- El proxy requiere subnets y security group en la VPC correcta.
- La creación puede tardar algunos minutos.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Verificar si el proxy ya existe ==="

if aws rds describe-db-proxies \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_REGION" >/dev/null 2>&1; then

  echo "El proxy ya existe. Se reutilizará: $RDS_PROXY_NAME"

else
  echo "El proxy no existe. Creando RDS Proxy..."

  aws rds create-db-proxy \
    --db-proxy-name "$RDS_PROXY_NAME" \
    --engine-family POSTGRESQL \
    --auth "AuthScheme=SECRETS,SecretArn=$RDS_PROXY_SECRET_ARN,IAMAuth=DISABLED" \
    --role-arn "$RDS_PROXY_ROLE_ARN" \
    --vpc-subnet-ids $(echo "$RDS_PROXY_SUBNET_IDS" | tr ',' ' ') \
    --vpc-security-group-ids "$RDS_PROXY_SECURITY_GROUP_ID" \
    --require-tls \
    --idle-client-timeout 1800 \
    --no-debug-logging \
    --tags Key=Lab,Value=03-00-02 Key=Environment,Value=training \
    --region "$AWS_REGION" \
    2>&1 | tee "$LAB_DIR/results/proxy_create.json"
fi

echo "=== Esperar proxy available ==="

for i in $(seq 1 60); do
  PROXY_STATUS=$(aws rds describe-db-proxies \
    --db-proxy-name "$RDS_PROXY_NAME" \
    --region "$AWS_REGION" \
    --query "DBProxies[0].Status" \
    --output text 2>/dev/null || echo "not-found")

  echo "Intento $i/60 - Estado del proxy: $PROXY_STATUS"

  if [ "$PROXY_STATUS" = "available" ]; then
    echo "RDS Proxy disponible."
    break
  fi

  sleep 10

  if [ "$i" -eq 60 ]; then
    echo "ERROR: El proxy no llegó a estado available en el tiempo esperado."
    exit 1
  fi
done

echo "=== Obtener endpoint del proxy ==="

export RDS_PROXY_ENDPOINT=$(aws rds describe-db-proxies \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_REGION" \
  --query "DBProxies[0].Endpoint" \
  --output text)

aws rds describe-db-proxies \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_REGION" \
  --query "DBProxies[0].{Nombre:DBProxyName,Estado:Status,Endpoint:Endpoint,TLS:RequireTLS,IdleTimeout:IdleClientTimeout}" \
  --output table \
  | tee "$LAB_DIR/results/proxy_status.txt"

echo "RDS_PROXY_ENDPOINT=$RDS_PROXY_ENDPOINT"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
aws rds describe-db-proxies \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_REGION" \
  --query "DBProxies[0].Status" \
  --output text
```

---

## 📌 Resultado esperado

Debes ver:

```text
available
```

Y tener definida la variable:

```bash
RDS_PROXY_ENDPOINT
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20crear%20o%20reutilizar%20un%20Amazon%20RDS%20Proxy%20para%20Aurora%20PostgreSQL%20usando%20AWS%20CLI.)

---

# 🧩 Reto 4. Registrar Aurora como target y configurar pooling

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Asociar el clúster Aurora PostgreSQL al RDS Proxy y configurar parámetros básicos del pool de conexiones.

---

## 🧠 Escenario

Un proxy sin target no puede enrutar conexiones a la base de datos. Debes registrar el clúster Aurora y ajustar el comportamiento del pool para controlar cuántas conexiones reales puede abrir el proxy hacia Aurora.

---

## 🛠️ Tu reto

Realiza:

- Obtener el target group default.
- Configurar pooling.
- Registrar el clúster Aurora como target.
- Validar que el target esté saludable.

---

## 💡 Pistas

- `MaxConnectionsPercent` controla el porcentaje de `max_connections` que puede usar el proxy.
- `MaxIdleConnectionsPercent` define cuántas conexiones inactivas mantiene.
- `ConnectionBorrowTimeout` define cuánto espera un cliente por una conexión disponible del pool.
- El target puede tardar un poco en aparecer como `AVAILABLE`.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Obtener target group default ==="

export RDS_PROXY_TARGET_GROUP=$(aws rds describe-db-proxy-target-groups \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_REGION" \
  --query "TargetGroups[0].TargetGroupName" \
  --output text)

echo "Target Group: $RDS_PROXY_TARGET_GROUP"

echo "=== Configurar pooling ==="

aws rds modify-db-proxy-target-group \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --target-group-name "$RDS_PROXY_TARGET_GROUP" \
  --connection-pool-config '{
    "MaxConnectionsPercent": 80,
    "MaxIdleConnectionsPercent": 40,
    "ConnectionBorrowTimeout": 120,
    "SessionPinningFilters": []
  }' \
  --region "$AWS_REGION" \
  2>&1 | tee "$LAB_DIR/results/proxy_pooling_config.json"

echo "=== Registrar Aurora como target ==="

aws rds register-db-proxy-targets \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --db-cluster-identifiers "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  2>&1 | tee "$LAB_DIR/results/proxy_register_target.json" || true

echo "=== Esperar y validar target ==="

sleep 30

aws rds describe-db-proxy-targets \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_REGION" \
  --query "Targets[*].{Endpoint:Endpoint,Tipo:Type,Estado:TargetHealth.State,Descripcion:TargetHealth.Description}" \
  --output table \
  | tee "$LAB_DIR/results/proxy_targets.txt"

echo "=== Ver configuración final del target group ==="

aws rds describe-db-proxy-target-groups \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_REGION" \
  --query "TargetGroups[0].ConnectionPoolConfig" \
  --output table \
  | tee "$LAB_DIR/results/proxy_target_group_config.txt"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
aws rds describe-db-proxy-targets \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_REGION" \
  --query "Targets[*].TargetHealth.State" \
  --output text
```

---

## 📌 Resultado esperado

Debes ver al menos un target con estado:

```text
AVAILABLE
```

- Si aparece temporalmente como `REGISTERING`, espera 30 segundos y repite la validación.
- Si aparece UNAVAILABLE espera 5 minutos y repite la validación
---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20registrar%20un%20cl%C3%BAster%20Aurora%20PostgreSQL%20como%20target%20de%20RDS%20Proxy%20y%20configurar%20MaxConnectionsPercent%2C%20MaxIdleConnectionsPercent%20y%20ConnectionBorrowTimeout.)

---

# 🧩 Reto 5. Validar conexión vía proxy

## ⏱️ Tiempo estimado

**4 minutos**

---

## 🎯 Objetivo del reto

Confirmar que puedes conectarte a Aurora PostgreSQL usando el endpoint de RDS Proxy.

---

## 🧠 Escenario

Una vez que el proxy está disponible y tiene target saludable, debes validar que acepta conexiones TLS y enruta correctamente hacia Aurora.

---

## 🛠️ Tu reto

Valida:

- Conexión vía proxy.
- Usuario actual.
- Base actual.
- Rol writer.
- Actividad visible desde `pg_stat_activity`.

---

## 💡 Pistas

- Usa el mismo usuario de la base.
- Usa el endpoint del proxy, no el endpoint del clúster.
- Usa `sslmode=require`.
- Si falla autenticación, revisa que el secreto contenga credenciales correctas.
- Usa CloudShell VPC Environment

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Validar conexión vía RDS Proxy ==="

psql "host=$RDS_PROXY_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT 'Conectado vía RDS Proxy' AS estado;" \
  -c "SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;" \
  2>&1 | tee "$LAB_DIR/results/proxy_connection_check.txt"

echo "=== Ver actividad desde conexión directa ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
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
  | tee "$LAB_DIR/results/pg_stat_activity_proxy_check.txt"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
grep "Conectado vía RDS Proxy" "$LAB_DIR/results/proxy_connection_check.txt"
```

---

## 📌 Resultado esperado

Debes ver:

```text
Conectado vía RDS Proxy
```

Y `pg_is_in_recovery()` debe devolver normalmente:

```text
f
```

porque el proxy apunta al writer para operaciones de escritura.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20validar%20una%20conexi%C3%B3n%20a%20Aurora%20PostgreSQL%20a%20trav%C3%A9s%20de%20RDS%20Proxy%20usando%20psql%20y%20sslmode%3Drequire.)

---

# 🧩 Reto 6. Comparar conexión directa vs proxy con carga ligera

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Ejecutar una comparación ligera entre conexión directa y conexión vía RDS Proxy usando `pgbench`.

---

## 🧠 Escenario

RDS Proxy no debe evaluarse únicamente por TPS. En cargas pequeñas puede incluso agregar una latencia marginal. El indicador clave es cómo administra las conexiones y cuántas conexiones reales mantiene hacia Aurora respecto a las conexiones cliente.

---

## 🛠️ Tu reto

Ejecuta pruebas cortas con:

- conexión directa con 10 clientes,
- conexión vía proxy con 10 clientes,
- conexión directa con 50 clientes,
- conexión vía proxy con 50 clientes.

---

## 💡 Pistas

- Mantén pruebas cortas de 20 segundos.
- Usa la misma base, mismos clientes y mismos hilos por escenario.
- Si `pgbench` no está inicializado en la base, inicialízalo rápido con escala 3.
- No interpretes “más TPS” como el único resultado valioso.
- Observa después métricas de conexiones en CloudWatch.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Este reto debe ejecutarse desde CloudShell VPC Environment ==="
set -euo pipefail

if [ -f ./lab6_aurora_env.sh ]; then
  source ./lab6_aurora_env.sh
fi

echo "=== Validar variables requeridas ==="

: "${AWS_REGION:?Falta AWS_REGION}"
: "${AURORA_ENDPOINT:?Falta AURORA_ENDPOINT}"
: "${AURORA_PORT:?Falta AURORA_PORT}"
: "${AURORA_DBNAME:?Falta AURORA_DBNAME}"
: "${AURORA_MASTER_USER:?Falta AURORA_MASTER_USER}"
: "${AURORA_MASTER_PASSWORD:?Falta AURORA_MASTER_PASSWORD}"
: "${RDS_PROXY_NAME:?Falta RDS_PROXY_NAME}"

echo "Endpoint DIRECTO Aurora: $AURORA_ENDPOINT"
echo "Endpoint RDS Proxy:      $RDS_PROXY_ENDPOINT"

echo "=== Validar conectividad TCP hacia Aurora directo ==="

timeout 10 bash -c "cat < /dev/null > /dev/tcp/$AURORA_ENDPOINT/$AURORA_PORT" \
  && echo "Conectividad directa OK" \
  || { echo "ERROR: No hay conectividad directa hacia Aurora."; exit 1; }

echo "=== Validar conectividad TCP hacia RDS Proxy ==="

timeout 10 bash -c "cat < /dev/null > /dev/tcp/$RDS_PROXY_ENDPOINT/$AURORA_PORT" \
  && echo "Conectividad vía proxy OK" \
  || { echo "ERROR: No hay conectividad hacia RDS Proxy."; exit 1; }

echo "=== Preparar tabla ligera de prueba usando conexión DIRECTA al writer ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require connect_timeout=10" <<'SQL' \
  | tee "$LAB_DIR/results/psql_only_setup.txt"

CREATE SCHEMA IF NOT EXISTS lab6_proxy_test;

CREATE TABLE IF NOT EXISTS lab6_proxy_test.accounts (
    id         INTEGER PRIMARY KEY,
    balance    INTEGER NOT NULL DEFAULT 1000,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO lab6_proxy_test.accounts (id, balance)
SELECT generate_series(1, 1000), 1000
ON CONFLICT (id) DO NOTHING;

ANALYZE lab6_proxy_test.accounts;

SELECT count(*) AS total_accounts
FROM lab6_proxy_test.accounts;

SQL

echo "=== Crear script de comparación usando solo psql ==="

cat > "$LAB_DIR/scripts/run_psql_proxy_comparison.sh" <<'SCRIPT'
#!/bin/bash
set -euo pipefail

ENDPOINT="$1"
LABEL="$2"
CLIENTS="$3"
DURATION="${4:-20}"
CONNECTION_TYPE="$5"
OUTDIR="$6"

mkdir -p "$OUTDIR"

echo "============================================================"
echo "Tipo de conexión: $CONNECTION_TYPE"
echo "Etiqueta:         $LABEL"
echo "Endpoint:         $ENDPOINT"
echo "Clientes:         $CLIENTS"
echo "Duración:         ${DURATION}s"
echo "Herramienta:      psql only"
echo "============================================================"

rm -f "$OUTDIR/${LABEL}_worker_"*.metrics 2>/dev/null || true

for WORKER in $(seq 1 "$CLIENTS"); do
  (
    OPS=0
    FAILS=0
    TOTAL_MS=0
    END_TIME=$((SECONDS + DURATION))

    while [ "$SECONDS" -lt "$END_TIME" ]; do
      START_MS=$(date +%s%3N)

      if psql "host=$ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require connect_timeout=5" \
        -v ON_ERROR_STOP=1 \
        -q \
        -X \
        -c "BEGIN;
            UPDATE lab6_proxy_test.accounts
            SET balance = balance + 1,
                updated_at = now()
            WHERE id = (($WORKER % 1000) + 1);
            SELECT count(*) FROM lab6_proxy_test.accounts WHERE id BETWEEN 1 AND 100;
            COMMIT;" >/dev/null 2>&1; then

        END_MS=$(date +%s%3N)
        ELAPSED_MS=$((END_MS - START_MS))
        TOTAL_MS=$((TOTAL_MS + ELAPSED_MS))
        OPS=$((OPS + 1))
      else
        FAILS=$((FAILS + 1))
      fi
    done

    echo "$OPS $FAILS $TOTAL_MS" > "$OUTDIR/${LABEL}_worker_${WORKER}.metrics"
  ) &
done

wait

awk -v label="$LABEL" \
    -v ctype="$CONNECTION_TYPE" \
    -v endpoint="$ENDPOINT" \
    -v clients="$CLIENTS" \
    -v duration="$DURATION" '
BEGIN {
  total_ops=0;
  total_fails=0;
  total_ms=0;
}
{
  total_ops += $1;
  total_fails += $2;
  total_ms += $3;
}
END {
  ops_sec = duration > 0 ? total_ops / duration : 0;
  avg_ms = total_ops > 0 ? total_ms / total_ops : 0;

  print "";
  print "==================== RESULTADO ====================";
  print "Tipo de conexión:        " ctype;
  print "Etiqueta:                " label;
  print "Endpoint:                " endpoint;
  print "Clientes simulados:      " clients;
  print "Duración segundos:       " duration;
  print "Operaciones exitosas:    " total_ops;
  print "Operaciones fallidas:    " total_fails;
  printf "Operaciones/seg aprox:   %.2f\n", ops_sec;
  printf "Latencia promedio aprox: %.2f ms\n", avg_ms;
  print "===================================================";
  print "";
}
' "$OUTDIR/${LABEL}_worker_"*.metrics

echo ""
SCRIPT

chmod +x "$LAB_DIR/scripts/run_psql_proxy_comparison.sh"

echo "=== Ejecutar comparación ligera con 10 clientes ==="

"$LAB_DIR/scripts/run_psql_proxy_comparison.sh" \
  "$AURORA_ENDPOINT" \
  "DIRECTA_C10" \
  10 \
  20 \
  "DIRECTA_AURORA_WRITER" \
  "$LAB_DIR/results" \
  2>&1 | tee "$LAB_DIR/results/direct_c10.txt"

"$LAB_DIR/scripts/run_psql_proxy_comparison.sh" \
  "$RDS_PROXY_ENDPOINT" \
  "PROXY_C10" \
  10 \
  20 \
  "RDS_PROXY" \
  "$LAB_DIR/results" \
  2>&1 | tee "$LAB_DIR/results/proxy_c10.txt"

echo "=== Ejecutar comparación ligera con 50 clientes ==="

"$LAB_DIR/scripts/run_psql_proxy_comparison.sh" \
  "$AURORA_ENDPOINT" \
  "DIRECTA_C50" \
  50 \
  20 \
  "DIRECTA_AURORA_WRITER" \
  "$LAB_DIR/results" \
  2>&1 | tee "$LAB_DIR/results/direct_c50.txt"

"$LAB_DIR/scripts/run_psql_proxy_comparison.sh" \
  "$RDS_PROXY_ENDPOINT" \
  "PROXY_C50" \
  50 \
  20 \
  "RDS_PROXY" \
  "$LAB_DIR/results" \
  2>&1 | tee "$LAB_DIR/results/proxy_c50.txt"

echo "=== Resumen de resultados DIRECTA vs PROXY ==="

cat > "$LAB_DIR/results/resumen_directa_vs_proxy.txt" <<EOF
# Resumen DIRECTA vs RDS Proxy

Ambiente de ejecución:
CloudShell VPC Environment

Nota:
Esta prueba usa psql porque CloudShell VPC Environment no tiene salida a internet
y pgbench no está disponible.

Endpoint directo Aurora:
$AURORA_ENDPOINT

Endpoint RDS Proxy:
$RDS_PROXY_ENDPOINT

EOF

for FILE in direct_c10 proxy_c10 direct_c50 proxy_c50; do
  echo "--- $FILE ---" | tee -a "$LAB_DIR/results/resumen_directa_vs_proxy.txt"

  case "$FILE" in
    direct_*)
      echo "Tipo de conexión: DIRECTA_AURORA_WRITER" | tee -a "$LAB_DIR/results/resumen_directa_vs_proxy.txt"
      ;;
    proxy_*)
      echo "Tipo de conexión: RDS_PROXY" | tee -a "$LAB_DIR/results/resumen_directa_vs_proxy.txt"
      ;;
  esac

  grep -E "Operaciones exitosas|Operaciones fallidas|Operaciones/seg aprox|Latencia promedio aprox" \
    "$LAB_DIR/results/${FILE}.txt" \
    | tee -a "$LAB_DIR/results/resumen_directa_vs_proxy.txt" || true

  echo "" | tee -a "$LAB_DIR/results/resumen_directa_vs_proxy.txt"
done

echo "=== Validar archivos generados ==="

ls -lh \
  "$LAB_DIR/results/direct_c10.txt" \
  "$LAB_DIR/results/proxy_c10.txt" \
  "$LAB_DIR/results/direct_c50.txt" \
  "$LAB_DIR/results/proxy_c50.txt" \
  "$LAB_DIR/results/resumen_directa_vs_proxy.txt"

echo "Revisa el resumen en:"
echo "$LAB_DIR/results/resumen_directa_vs_proxy.txt"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
ls -lh "$LAB_DIR/results/"*c10.txt "$LAB_DIR/results/"*c50.txt

for FILE in direct_c10 proxy_c10 direct_c50 proxy_c50; do
  echo "--- $FILE ---"
  grep -E "latency average|tps =" "$LAB_DIR/results/${FILE}.txt" || true
done
```

---

## 📌 Resultado esperado

Debes tener cuatro archivos:

```text
direct_c10.txt
proxy_c10.txt
direct_c50.txt
proxy_c50.txt
```

Y cada uno debe incluir:

```text
latency average = ...
tps = ...
```

> ⚠️ **Interpretación correcta:** El proxy no siempre tendrá mayor TPS. El beneficio principal se observa al comparar conexiones cliente contra conexiones reales a la base y al proteger el motor ante picos de conexión.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20comparar%20una%20conexi%C3%B3n%20directa%20a%20Aurora%20PostgreSQL%20contra%20una%20conexi%C3%B3n%20por%20RDS%20Proxy%20usando%20pgbench%20sin%20interpretar%20TPS%20como%20%C3%BAnico%20indicador.)

---

# 🧩 Reto 7. Consultar métricas CloudWatch del proxy

## ⏱️ Tiempo estimado

**3 minutos**

---

## 🎯 Objetivo del reto

Consultar métricas de CloudWatch para observar el comportamiento de RDS Proxy.

---

## 🧠 Escenario

La evidencia más importante del proxy no es únicamente TPS, sino la diferencia entre conexiones cliente y conexiones reales hacia Aurora. Para eso revisarás métricas como `ClientConnections` y `DatabaseConnections`.

---

## 🛠️ Tu reto

Consulta métricas de los últimos 30 minutos:

- `ClientConnections`
- `DatabaseConnections`
- `QueryRequests`
- `DatabaseConnectionsBorrowLatency`
- `MaxDatabaseConnectionsAllowed`

---

## 💡 Pistas

- CloudWatch puede tardar algunos minutos en reflejar datos.
- Si no aparecen métricas, espera y repite.
- Usa `ProxyName` como dimensión.
- En escenarios con bajo volumen, algunas métricas pueden aparecer vacías.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Este reto debe ejecutarse desde CloudShell normal, no desde VPC Environment ==="
echo "=== Crear script de consulta de métricas ==="

cat > "$LAB_DIR/scripts/query_proxy_metrics.sh" <<'SCRIPT'
#!/bin/bash
set -euo pipefail

END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_TIME=$(date -u -d "30 minutes ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "=== Métricas RDS Proxy: $RDS_PROXY_NAME ==="
echo "Ventana: $START_TIME -> $END_TIME"
echo ""

for METRIC in \
  "ClientConnections" \
  "DatabaseConnections" \
  "QueryRequests" \
  "DatabaseConnectionsBorrowLatency" \
  "MaxDatabaseConnectionsAllowed"
do
  echo "── $METRIC ──"
  aws cloudwatch get-metric-statistics \
    --namespace "AWS/RDS" \
    --metric-name "$METRIC" \
    --dimensions Name=ProxyName,Value="$RDS_PROXY_NAME" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 60 \
    --statistics Average Maximum \
    --region "$AWS_REGION" \
    --query "sort_by(Datapoints, &Timestamp)[*].{Tiempo:Timestamp,Promedio:Average,Maximo:Maximum}" \
    --output table || true
  echo ""
done
SCRIPT

chmod +x "$LAB_DIR/scripts/query_proxy_metrics.sh"

echo "=== Consultar métricas ==="

"$LAB_DIR/scripts/query_proxy_metrics.sh" \
  2>&1 | tee "$LAB_DIR/results/proxy_metrics.txt"

echo "=== Listar métricas disponibles para el proxy ==="

aws cloudwatch list-metrics \
  --namespace "AWS/RDS" \
  --dimensions Name=ProxyName,Value="$RDS_PROXY_NAME" \
  --region "$AWS_REGION" \
  --query "Metrics[*].MetricName" \
  --output table \
  | tee "$LAB_DIR/results/proxy_metric_names.txt"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
cat "$LAB_DIR/results/proxy_metrics.txt"
```

---

## 📌 Resultado esperado

Debes observar métricas o, al menos, confirmar que la consulta se ejecutó correctamente. Idealmente verás datos para:

```text
ClientConnections
DatabaseConnections
QueryRequests
```

La señal más importante es:

```text
ClientConnections >= DatabaseConnections
```

Esto indica que el proxy está gestionando conexiones cliente y conexiones reales hacia Aurora.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20interpretar%20las%20m%C3%A9tricas%20de%20CloudWatch%20de%20RDS%20Proxy%2C%20especialmente%20ClientConnections%2C%20DatabaseConnections%20y%20QueryRequests.)

---

# 🧩 Reto 8. Validar estado final previo a limpieza

## ⏱️ Tiempo estimado

**2 minutos**

---

## 🎯 Objetivo del reto

Confirmar que el proxy, sus targets, la conexión vía proxy y los archivos de evidencia existen antes de limpiar recursos.

---

## 🧠 Escenario

Antes de eliminar o conservar el proxy, necesitas confirmar que el laboratorio produjo evidencia suficiente y que el proxy quedó en un estado claro. Esto evita limpiar recursos sin haber validado el aprendizaje principal.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor esperado |
|---|---|
| RDS Proxy | `available` |
| Target Health | `AVAILABLE` |
| Endpoint proxy | `$RDS_PROXY_ENDPOINT` definido |
| Conexión vía proxy | Correcta |
| Evidencia | Archivos `06_*` creados |
| Métricas | `06_proxy_metrics.txt` creado |

---

## 🛠️ Tu reto

Realiza:

- Validación de estado del proxy.
- Validación de targets.
- Validación de endpoint.
- Validación de conexión vía proxy.
- Validación de archivos de evidencia.
- Confirmación de que estás listo para limpiar o conservar el proxy.

---

## 💡 Pistas

- El proxy puede conservarse si será usado en prácticas posteriores.
- Si el target aparece `REGISTERING`, espera 30 segundos.
- Si no hay métricas, CloudWatch puede tardar unos minutos.
- No elimines todavía el proxy; la eliminación se realiza en el Reto 9.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Validar estado del proxy ==="

aws rds describe-db-proxies \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_REGION" \
  --query "DBProxies[0].{Nombre:DBProxyName,Estado:Status,Endpoint:Endpoint}" \
  --output table

echo "=== Validar targets del proxy ==="

aws rds describe-db-proxy-targets \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_REGION" \
  --query "Targets[*].{Endpoint:Endpoint,Tipo:Type,Estado:TargetHealth.State,Descripcion:TargetHealth.Description}" \
  --output table

echo "=== Validar conexión vía proxy ==="

psql "host=$RDS_PROXY_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;"

echo "=== Crear resumen técnico ==="

cat > 06_resumen_rds_proxy.md <<EOF
# Resumen — Laboratorio 6 Gestión de conexiones con RDS Proxy

| Elemento | Valor |
|---|---|
| Fecha UTC | $(date -u +"%Y-%m-%dT%H:%M:%SZ") |
| Cluster Aurora | $AURORA_CLUSTER_ID |
| Endpoint Aurora | $AURORA_ENDPOINT |
| RDS Proxy | $RDS_PROXY_NAME |
| Endpoint Proxy | $RDS_PROXY_ENDPOINT |
| Target Group | ${RDS_PROXY_TARGET_GROUP:-default} |
| MaxConnectionsPercent | 80 |
| MaxIdleConnectionsPercent | 40 |
| ConnectionBorrowTimeout | 120 |
| IdleClientTimeout | 1800 |

## Interpretación clave

RDS Proxy no debe evaluarse solo por TPS. La evidencia principal se obtiene al comparar conexiones cliente contra conexiones reales a Aurora mediante CloudWatch:

- ClientConnections
- DatabaseConnections
- QueryRequests
- DatabaseConnectionsBorrowLatency
- MaxDatabaseConnectionsAllowed
EOF

echo "=== Validar evidencia local ==="

ls -lh 06_* 2>/dev/null || echo "No hay archivos 06_* todavía."

echo "=== Empaquetar evidencia ==="

tar -czf "06_rds_proxy_evidencia_$(date +%Y%m%d-%H%M%S).tar.gz" 06_* 2>/dev/null || true

ls -lh 06_* 2>/dev/null || true
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
aws rds describe-db-proxies \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_REGION" \
  --query "DBProxies[0].Status" \
  --output text

ls -lh 06_resumen_rds_proxy.md 06_proxy_metrics.txt
```

---

## 📌 Resultado esperado

Debes ver:

```text
available
06_resumen_rds_proxy.md
06_proxy_metrics.txt
```

También debes tener evidencia adicional:

```text
06_direct_connection_check.txt
06_proxy_status.txt
06_proxy_targets.txt
06_proxy_connection_check.txt
06_direct_c10.txt
06_proxy_c10.txt
06_direct_c50.txt
06_proxy_c50.txt
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20validar%20el%20estado%20final%20de%20un%20laboratorio%20de%20RDS%20Proxy%20antes%20de%20limpiar%20recursos%2C%20incluyendo%20proxy%2C%20targets%2C%20conexi%C3%B3n%20y%20m%C3%A9tricas.)

---

# 🧩 Reto 9. Eliminar recursos del laboratorio

## ⏱️ Tiempo estimado

**1 minuto**

---

## 🎯 Objetivo del reto

Eliminar el RDS Proxy y los recursos temporales del laboratorio si el instructor solicita cerrar el ambiente.

---

## 🧠 Escenario

El proxy puede servir para prácticas posteriores. Por eso no debe eliminarse si será reutilizado. Sin embargo, si el entorno es temporal, debes eliminar el proxy y los recursos asociados para evitar costos innecesarios.

---

## 🧱 Valores estandarizados del reto

| Recurso | Valor estándar | Acción |
|---|---|---|
| RDS Proxy | `$RDS_PROXY_NAME` | Eliminar con script |
| Target Aurora | `$AURORA_CLUSTER_ID` | Desregistrar antes de eliminar el proxy |
| Secreto | `$RDS_PROXY_SECRET_ARN` | Eliminar si fue creado para el laboratorio |
| IAM Role | `$RDS_PROXY_ROLE_ARN` | Eliminar si fue creado para el laboratorio |
| Archivos de evidencia | `06_*` | Conservar o eliminar según indique el instructor |
| Script de eliminación | `00_eliminar_laboratorio_6_aurora.sh` | Script de limpieza controlada |

---

## 🛠️ Tu reto

Realiza:

- Ejecución del script `00_eliminar_laboratorio_6_aurora.sh`.
- Validación de que el proxy ya no existe.
- Validación de que el target fue desregistrado.
- Confirmación final del cierre del laboratorio.

---

## 💡 Pistas

- El script de eliminación carga automáticamente `./lab6_aurora_env.sh` si existe.
- Primero se desregistran los targets del proxy.
- Después se elimina el proxy.
- Si el proxy está en transición, espera unos minutos y repite la validación.
- Conserva evidencia si necesitas entregar resultados.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Ejecutar script de eliminación del Laboratorio 6 ==="

chmod +x 00_eliminar_laboratorio_6_aurora.sh
./00_eliminar_laboratorio_6_aurora.sh
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
aws rds describe-db-proxies \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_REGION" \
  --query "DBProxies[0].Status" \
  --output text
```

Si el proxy fue eliminado correctamente, AWS CLI debe devolver un error similar a:

```text
DBProxyNotFoundFault
```

---

## 📌 Resultado esperado

Debes confirmar:

```text
RDS Proxy eliminado o no existente
Targets desregistrados
Recursos temporales del proxy eliminados si fueron creados para el laboratorio
Evidencia conservada o eliminada según indique el instructor
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20eliminar%20ordenadamente%20un%20Amazon%20RDS%20Proxy%20para%20Aurora%20PostgreSQL%20desregistrando%20targets%20y%20limpiando%20recursos%20temporales.)

---

# ✅ Validación final del laboratorio

Al finalizar la práctica, debes haber completado lo siguiente:

| Elemento | Estado esperado |
|---|---|
| CloudShell validado | Correcto |
| Variables `AURORA_*` | Definidas |
| Variables `RDS_PROXY_*` | Definidas |
| Secreto Secrets Manager | Validado |
| IAM Role del proxy | Validado |
| Subnets | Validadas |
| Security Group | Validado |
| Conexión directa a Aurora | Correcta |
| RDS Proxy | Disponible |
| Endpoint del proxy | Capturado |
| Target Aurora | Registrado |
| Target Health | `AVAILABLE` |
| Pooling | Configurado |
| Conexión vía proxy | Correcta |
| Pruebas directas vs proxy | Ejecutadas |
| Métricas CloudWatch | Consultadas |
| Evidencia | Guardada |
| Estado final previo a limpieza | Validado |
| Limpieza del proxy | Ejecutada solo si el instructor la solicitó |

---

# 🧠 Resultado esperado de aprendizaje

Después de completar este laboratorio, debes poder explicar y ejecutar el flujo básico de gestión de conexiones con RDS Proxy:

1. Validar prerrequisitos de IAM, Secrets Manager y red.
2. Validar conexión directa contra Aurora.
3. Crear o reutilizar un RDS Proxy.
4. Registrar Aurora PostgreSQL como target.
5. Configurar parámetros de connection pooling.
6. Conectarte mediante el endpoint del proxy.
7. Comparar conexión directa contra conexión vía proxy.
8. Revisar métricas de CloudWatch.
9. Interpretar `ClientConnections` contra `DatabaseConnections`.
10. Validar el estado final previo a limpieza.
11. Decidir si conservar o eliminar el proxy.
12. Ejecutar limpieza controlada si el instructor lo solicita.

---

# 📌 Resumen del laboratorio

En este laboratorio configuraste y validaste Amazon RDS Proxy como capa de gestión de conexiones para Aurora PostgreSQL. Primero verificaste prerrequisitos de red, IAM y Secrets Manager. Después creaste o reutilizaste un proxy, registraste el clúster Aurora como target, configuraste parámetros básicos de pooling y validaste la conexión mediante el endpoint del proxy. Luego ejecutaste una comparación ligera entre conexión directa y conexión vía proxy con `pgbench`, consultaste métricas de CloudWatch y guardaste evidencia técnica. Finalmente, validaste el estado del proxy y sus targets antes de ejecutar una limpieza controlada si el instructor lo solicitó. La idea principal reforzada es que RDS Proxy no debe evaluarse solo por TPS, sino por su capacidad para administrar conexiones cliente y reducir la presión de conexiones reales sobre Aurora.
