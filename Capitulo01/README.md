<h1 align="center">🚀 Laboratorio 1. Análisis de rendimiento con logs y tuning</h1>

---

## 1. 🧾 Información general de la práctica

## 📘 Descripción general

En este laboratorio vas a trabajar desde **AWS CloudShell** para crear un entorno temporal de **Amazon Aurora PostgreSQL**, activar el registro de consultas lentas, crear una base de datos OLTP de prueba, ejecutar consultas sin índices para obtener una línea base y después aplicar índices para comparar la mejora.

La práctica está diseñada como una serie de **retos guiados**. En cada reto primero intentarás resolver el objetivo con pistas. Si te bloqueas, podrás abrir la **solución sugerida**. La solución está oculta para fomentar el razonamiento, pero es completa y funcional para no extender el tiempo del laboratorio.

El enfoque principal es el ciclo básico de optimización:

> **Medir → Diagnosticar → Optimizar → Comparar → Validar → Limpiar**

---

## 🎯 Objetivos de aprendizaje

Al finalizar este laboratorio, podrás:

- Usar AWS CloudShell como entorno de ejecución para administrar Aurora PostgreSQL.
- Preparar variables de entorno para automatizar comandos AWS CLI.
- Crear un clúster Aurora PostgreSQL temporal para laboratorio.
- Configurar slow query logging con `log_min_duration_statement`.
- Crear una base de datos OLTP de prueba.
- Ejecutar consultas con `EXPLAIN (ANALYZE, BUFFERS)`.
- Identificar `Seq Scan`, `Index Scan`, `Bitmap Index Scan`, filtros y buffers.
- Crear índices B-tree simples, compuestos, parciales y de cobertura.
- Comparar planes antes y después de optimizar.
- Validar slow queries en logs de Aurora.
- Eliminar recursos para evitar costos.

---

## ✅ Prerrequisitos

Antes de iniciar, debes contar con:

- Acceso a una cuenta AWS.
- Permisos para usar AWS CloudShell.
- Permisos IAM para administrar:
  - Amazon RDS/Aurora.
  - Amazon EC2 Security Groups.
  - Amazon VPC/Subnets.
  - CloudWatch Logs.
  - STS.
- Una VPC disponible con al menos dos subnets.
- Acceso a **AWS CloudShell VPC Environment** o conectividad de red desde CloudShell hacia el clúster Aurora.
- Conocimientos básicos de SQL.
- Conocimientos básicos de PostgreSQL.
- Conocimientos básicos de AWS CLI.

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
| AWS CLI | Creación y administración de recursos AWS |
| psql | Conexión y ejecución SQL en Aurora PostgreSQL |
| jq | Procesamiento de salidas JSON |
| CloudWatch Logs | Consulta centralizada de logs |

---

## ⏱️ Tabla de tiempo, complejidad y nivel Bloom

| Elemento | Detalle |
|---|---|
| Duración total | 45 minutos |
| Complejidad | Media |
| Nivel Bloom | Aplicar / Analizar |
| Modalidad | Retos guiados con solución oculta |
| Motor | Amazon Aurora PostgreSQL |
| Versión recomendada | Aurora PostgreSQL 16.x |
| Instancia sugerida | `db.r6g.large` |
| Entorno | AWS CloudShell |
| Costo | Genera cargos mientras los recursos existan |

---

## 🗓️ Distribución de tiempo por reto

| Reto | Actividad | Tiempo |
|---|---|---:|
| Reto 1 | Preparar AWS CloudShell | 4 min |
| Reto 2 | Configurar variables y red mínima | 5 min |
| Reto 3 | Crear Aurora PostgreSQL | 7 min |
| Reto 4 | Conectar y activar slow query logging | 5 min |
| Reto 5 | Crear esquema OLTP y cargar datos | 6 min |
| Reto 6 | Obtener línea base sin índices | 5 min |
| Reto 7 | Crear índices y comparar planes | 5 min |
| Reto 8 | Validar slow queries en logs | 3 min |
| Reto 9 | Eliminar recursos del laboratorio | 5 min |
| **Total** |  | **45 min** |

> 💡 **Nota operativa:** La creación de Aurora puede tardar más dependiendo de la región y la cuenta.

---

# 2. 🧪 Desarrollo de la práctica

---

# 🧩 Reto 1. Preparar AWS CloudShell

## ⏱️ Tiempo estimado

**4 minutos**

---

## 🎯 Objetivo del reto

Validar que AWS CloudShell esté listo para ejecutar comandos de AWS CLI, Bash, `jq` y `psql`.

---

## 🧠 Escenario

Vas a trabajar directamente dentro de la cuenta AWS. Antes de crear Aurora PostgreSQL, necesitas validar tu identidad, región y herramientas disponibles en CloudShell.

---

## 🛠️ Tu reto

Desde AWS CloudShell, valida:

- Tu identidad AWS.
- La región activa.
- La versión de AWS CLI.
- La existencia de `jq`.
- La existencia de `psql`.

---

## 🧾 Valores estandarizados que debes crear o usar

| Elemento | Nombre o valor estándar | Observación |
|---|---|---|
| Región AWS | `AWS_REGION` | Se obtiene desde la configuración actual de AWS CLI. Si está vacía, usa `us-west-2`. |
| Cuenta AWS | Cuenta activa de CloudShell | Debe validarse con STS antes de crear recursos. |
| Shell | `bash` | Todos los comandos del laboratorio se ejecutan en Bash. |
| Cliente PostgreSQL | `psql` | Debe quedar disponible antes de crear o validar Aurora. |

---

## 💡 Pistas

- Usa `aws sts get-caller-identity`.
- Usa `aws configure get region`.
- Si `psql` no existe, instala el cliente PostgreSQL.
- Todo debe ejecutarse desde Bash.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Identidad AWS ==="
aws sts get-caller-identity --output table

echo "=== Región actual ==="
export AWS_REGION="$(aws configure get region)"

if [ -z "$AWS_REGION" ]; then
  export AWS_REGION="us-east-1"
fi

echo "Región configurada: $AWS_REGION"

echo "=== Versiones de herramientas ==="
aws --version
bash --version | head -1
jq --version || echo "jq no encontrado"

echo "=== Validar psql ==="
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
else
  echo "psql ya está instalado."
fi

psql --version
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
aws sts get-caller-identity --query "Account" --output text
echo "$AWS_REGION"
command -v psql
psql --version
```

---

## 📌 Resultado esperado

Debes obtener:

```text
Una cuenta AWS válida
Una región configurada
Ruta del ejecutable psql
Versión de psql
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20preparar%20AWS%20CloudShell%20para%20una%20pr%C3%A1ctica%20de%20Aurora%20PostgreSQL%2C%20validando%20AWS%20CLI%2C%20regi%C3%B3n%2C%20jq%20y%20psql.)

---

# 🧩 Reto 2. Configurar variables y red mínima

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Definir variables reutilizables y preparar los recursos mínimos de red para crear Aurora PostgreSQL.

---

## 🧠 Escenario

Para acelerar el laboratorio, usarás la VPC default de la región. Crearás un Security Group para Aurora y un DB Subnet Group con dos subnets.

---

## 🛠️ Tu reto

Configura:

- Variables del laboratorio.
- VPC default.
- Dos subnets.
- Security Group para Aurora.
- Regla inbound TCP/5432.
- DB Subnet Group para RDS.

---

## 🧾 Valores estandarizados que debes crear

| Elemento | Nombre o valor estándar | Variable asociada |
|---|---|---|
| Prefijo del laboratorio | `aurora-performance-lab` | `LAB_PREFIX` |
| Security Group | `aurora-performance-lab-aurora-sg` | `AURORA_SG_ID` |
| DB Subnet Group | `aurora-performance-lab-db-subnet-group` | `DB_SUBNET_GROUP_NAME` |
| Puerto PostgreSQL | `5432` | `AURORA_PORT` |
| VPC | VPC default de la región | `VPC_ID` |
| Subnets Publicas | Primeras dos subnets disponibles de la VPC | `SUBNET_IDS` |
| Usuario maestro | `labadmin` | `AURORA_MASTER_USER` |
| Contraseña temporal | `AuroraLab_2026_Temporal!` | `AURORA_MASTER_PASSWORD` |

---

## 💡 Pistas

- Aurora requiere un DB Subnet Group.
- El puerto de PostgreSQL es `5432`.
- Para laboratorio se permitirá tráfico desde el CIDR de la VPC.
- En producción se debe restringir el acceso al Security Group de la aplicación o del entorno CloudShell VPC.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Variables base del laboratorio ==="

export LAB_PREFIX="aurora-performance-lab"
export AURORA_CLUSTER_ID="${LAB_PREFIX}-cluster"
export AURORA_INSTANCE_ID="${LAB_PREFIX}-instance-1"
export AURORA_PARAM_GROUP="${LAB_PREFIX}-cluster-pg"
export DB_SUBNET_GROUP_NAME="${LAB_PREFIX}-db-subnet-group"

export AURORA_DBNAME="postgres"
export AURORA_PORT="5432"
export AURORA_MASTER_USER="labadmin"

# Cambia esta contraseña antes de continuar si tu instructor lo solicita.
export AURORA_MASTER_PASSWORD="AuroraLab_2026_Temporal!"

echo "Cluster: $AURORA_CLUSTER_ID"
echo "Instance: $AURORA_INSTANCE_ID"
echo "Parameter Group: $AURORA_PARAM_GROUP"

echo "=== Obtener VPC default ==="

export VPC_ID=$(aws ec2 describe-vpcs \
  --region "$AWS_REGION" \
  --filters "Name=isDefault,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "No se encontró VPC default. Solicita al instructor una VPC_ID y ejecútala así:"
  echo 'export VPC_ID="vpc-xxxxxxxx"'
  exit 1
fi

echo "VPC seleccionada: $VPC_ID"

echo "=== Obtener dos subnets ==="

export SUBNET_IDS=$(aws ec2 describe-subnets \
  --region "$AWS_REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[0:2].SubnetId" \
  --output text)

if [ "$(echo "$SUBNET_IDS" | wc -w)" -lt 2 ]; then
  echo "Se requieren al menos dos subnets para el DB Subnet Group."
  exit 1
fi

echo "Subnets seleccionadas: $SUBNET_IDS"

echo "=== Crear Security Group para Aurora ==="

export AURORA_SG_ID=$(aws ec2 create-security-group \
  --group-name "${LAB_PREFIX}-aurora-sg" \
  --description "Security Group para laboratorio Aurora PostgreSQL Performance" \
  --vpc-id "$VPC_ID" \
  --region "$AWS_REGION" \
  --query "GroupId" \
  --output text)

echo "Security Group creado: $AURORA_SG_ID"

echo "=== Autorizar PostgreSQL desde Internet ==="

aws ec2 authorize-security-group-ingress \
  --group-id "$AURORA_SG_ID" \
  --protocol tcp \
  --port "$AURORA_PORT" \
  --cidr "0.0.0.0/0" \
  --region "$AWS_REGION" || true

echo "Regla creada para TCP/$AURORA_PORT desde 0.0.0.0/0"

echo "=== Crear DB Subnet Group ==="

aws rds create-db-subnet-group \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --db-subnet-group-description "DB Subnet Group para Aurora Performance Lab" \
  --subnet-ids $SUBNET_IDS \
  --region "$AWS_REGION"

echo "DB Subnet Group creado: $DB_SUBNET_GROUP_NAME"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
aws ec2 describe-security-groups \
  --group-ids "$AURORA_SG_ID" \
  --region "$AWS_REGION" \
  --query "SecurityGroups[0].{GroupId:GroupId,GroupName:GroupName,VpcId:VpcId}" \
  --output table

aws rds describe-db-subnet-groups \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --region "$AWS_REGION" \
  --query "DBSubnetGroups[0].{Name:DBSubnetGroupName,VpcId:VpcId,Status:SubnetGroupStatus}" \
  --output table
```

---

## 📌 Resultado esperado

Debes ver:

```text
Security Group creado
DB Subnet Group en estado Complete
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20preparar%20la%20red%20para%20crear%20Aurora%20PostgreSQL%20desde%20AWS%20CloudShell%3A%20VPC%2C%20subnets%2C%20Security%20Group%20y%20DB%20Subnet%20Group.)

---

# 🧩 Reto 3. Crear Aurora PostgreSQL

## ⏱️ Tiempo estimado

**7 minutos**

---

## 🎯 Objetivo del reto

Crear un clúster Aurora PostgreSQL temporal con un Parameter Group personalizado y una instancia writer.

---

## 🧠 Escenario

Necesitas un clúster Aurora PostgreSQL para ejecutar pruebas de rendimiento. Como se usará AWS CLI, primero crearás el clúster y después la instancia writer.

---

## 🛠️ Tu reto

Crea:

- DB Cluster Parameter Group.
- Clúster Aurora PostgreSQL.
- Instancia writer.
- Endpoint writer en una variable.

---

## 🧾 Valores estandarizados que debes crear

| Elemento | Nombre o valor estándar | Variable asociada |
|---|---|---|
| DB Cluster Parameter Group | `aurora-performance-lab-cluster-pg` | `AURORA_PARAM_GROUP` |
| Familia del Parameter Group | `aurora-postgresql16` | No aplica |
| DB Cluster | `aurora-performance-lab-cluster` | `AURORA_CLUSTER_ID` |
| DB Instance writer | `aurora-performance-lab-instance-1` | `AURORA_INSTANCE_ID` |
| Motor | `aurora-postgresql` | No aplica |
| Versión de motor | `16` | No aplica |
| Clase de instancia | `db.r6g.large` | No aplica |
| Endpoint writer | Valor devuelto por RDS | `AURORA_ENDPOINT` |

---

## 💡 Pistas

- El Parameter Group debe usar familia `aurora-postgresql16`.
- El motor es `aurora-postgresql`.
- El clúster queda incompleto hasta crear la instancia writer.
- Usa `aws rds wait` para esperar disponibilidad.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Crear DB Cluster Parameter Group ==="

aws rds create-db-cluster-parameter-group \
  --db-cluster-parameter-group-name "$AURORA_PARAM_GROUP" \
  --db-parameter-group-family "aurora-postgresql16" \
  --description "Parameter group para laboratorio de rendimiento Aurora PostgreSQL" \
  --region "$AWS_REGION"

echo "=== Crear clúster Aurora PostgreSQL ==="

aws rds create-db-cluster \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --engine aurora-postgresql \
  --engine-version 16 \
  --master-username "$AURORA_MASTER_USER" \
  --master-user-password "$AURORA_MASTER_PASSWORD" \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --vpc-security-group-ids "$AURORA_SG_ID" \
  --db-cluster-parameter-group-name "$AURORA_PARAM_GROUP" \
  --backup-retention-period 1 \
  --port "$AURORA_PORT" \
  --region "$AWS_REGION"

echo "=== Crear instancia writer ==="

aws rds create-db-instance \
  --db-instance-identifier "$AURORA_INSTANCE_ID" \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --engine aurora-postgresql \
  --db-instance-class db.r6g.large \
  --publicly-accessible \
  --region "$AWS_REGION"

echo "=== Esperar disponibilidad de la instancia ==="

aws rds wait db-instance-available \
  --db-instance-identifier "$AURORA_INSTANCE_ID" \
  --region "$AWS_REGION"

aws rds wait db-cluster-available \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION"

echo "=== Obtener endpoint writer ==="

export AURORA_ENDPOINT=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].Endpoint" \
  --output text)

echo "Endpoint writer: $AURORA_ENDPOINT"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].{Cluster:DBClusterIdentifier,Engine:Engine,EngineVersion:EngineVersion,Status:Status,Endpoint:Endpoint}" \
  --output table

aws rds describe-db-instances \
  --db-instance-identifier "$AURORA_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query "DBInstances[0].{Instance:DBInstanceIdentifier,Class:DBInstanceClass,Status:DBInstanceStatus}" \
  --output table
```

---

## 📌 Resultado esperado

Debes ver:

```text
Cluster status: available
Instance status: available
Endpoint writer disponible
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20crear%20un%20cl%C3%BAster%20Aurora%20PostgreSQL%20desde%20AWS%20CLI%2C%20incluyendo%20Parameter%20Group%2C%20DB%20Cluster%2C%20DB%20Instance%20writer%20y%20endpoint.)

---

# 🧩 Reto 4. Conectar y activar slow query logging

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Validar la conexión a Aurora PostgreSQL y activar el registro de consultas lentas.

---

## 🧠 Escenario

Ya tienes el clúster Aurora creado. Ahora necesitas confirmar que puedes conectarte y configurar el parámetro `log_min_duration_statement` para capturar consultas que tarden más de 100 ms.

---

## 🛠️ Tu reto

Realiza lo siguiente:

- Conéctate al clúster con `psql`.
- Crea la base `lab_performance`.
- Activa slow query logging.
- Exporta logs de PostgreSQL a CloudWatch Logs.
- Valida los parámetros desde PostgreSQL.

---

## 🧾 Valores estandarizados que debes crear o configurar

| Elemento | Nombre o valor estándar | Observación |
|---|---|---|
| Base de laboratorio | `lab_performance` | Se crea desde la base inicial `postgres`. |
| Modo SSL | `sslmode=require` | Obligatorio para conexión segura en el laboratorio. |
| Parámetro slow query | `log_min_duration_statement=100` | Registra consultas que superen 100 ms. |
| Registro de sentencias | `log_statement=none` | Evita registrar todas las sentencias. |
| Prefijo de logs | `%m:%r:%u@%d:[%p]:%l:%e:%s:%v:%x:%c:%q%a:` | Facilita trazabilidad en logs. |
| Tipo de log exportado | `postgresql` | Se habilita en CloudWatch Logs. |

---

## 💡 Pistas

- Usa `sslmode=require`.
- Usa `log_min_duration_statement = 100`.
- Usa `log_statement = none`.
- Exporta logs tipo `postgresql`.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Probar conexión con psql ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT version(), current_database(), current_user;"

echo "=== Crear base de laboratorio ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "CREATE DATABASE lab_performance;"

echo "=== Configurar slow query logging ==="

aws rds modify-db-cluster-parameter-group \
  --db-cluster-parameter-group-name "$AURORA_PARAM_GROUP" \
  --region "$AWS_REGION" \
  --parameters \
    "ParameterName=log_min_duration_statement,ParameterValue=100,ApplyMethod=immediate" \
    "ParameterName=log_statement,ParameterValue=none,ApplyMethod=immediate" \
    "ParameterName=log_line_prefix,ParameterValue='%m:%r:%u@%d:[%p]:%l:%e:%s:%v:%x:%c:%q%a:',ApplyMethod=immediate"

echo "=== Habilitar exportación de logs a CloudWatch ==="

aws rds modify-db-cluster \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --cloudwatch-logs-export-configuration '{"EnableLogTypes":["postgresql"]}' \
  --region "$AWS_REGION"

echo "=== Validar parámetros desde PostgreSQL ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SHOW log_min_duration_statement; SHOW log_statement; SHOW log_line_prefix;"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT current_database(), current_user; SHOW log_min_duration_statement;"

aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].EnabledCloudwatchLogsExports" \
  --output table
```

---

## 📌 Resultado esperado

Debes ver:

```text
current_database: lab_performance
log_min_duration_statement: 100ms
CloudWatch Logs export: postgresql
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20activar%20slow%20query%20logging%20en%20Aurora%20PostgreSQL%20con%20log_min_duration_statement%2C%20log_statement%2C%20log_line_prefix%20y%20CloudWatch%20Logs.)

---

# 🧩 Reto 5. Crear esquema OLTP y cargar datos

## ⏱️ Tiempo estimado

**6 minutos**

---

## 🎯 Objetivo del reto

Crear tablas representativas de una carga OLTP y cargar datos suficientes para observar diferencias en planes de ejecución.

---

## 🧠 Escenario

Necesitas una base de prueba con clientes, productos, órdenes y detalle de órdenes. La carga debe ser suficiente para que los escaneos secuenciales sean visibles, pero no tan grande como para exceder el tiempo del laboratorio.

---

## 🛠️ Tu reto

Crea un script SQL que:

- Cree el esquema `app`.
- Cree las tablas `customers`, `products`, `orders` y `order_items`.
- Inserte datos de prueba.
- Ejecute `ANALYZE`.

---

## 🧾 Valores estandarizados que debes crear

| Elemento | Nombre o valor estándar | Volumen esperado |
|---|---|---:|
| Archivo SQL | `01_setup_lab.sql` | No aplica |
| Esquema | `app` | No aplica |
| Tabla de clientes | `app.customers` | 15,000 filas |
| Tabla de productos | `app.products` | 500 filas |
| Tabla de órdenes | `app.orders` | 50,000 filas |
| Tabla de detalle | `app.order_items` | 100,000 filas |
| Estadísticas | `ANALYZE` | Todas las tablas del esquema `app` |

---

## 💡 Pistas

- Usa `generate_series`.
- No agregues índice único en `email`, porque necesitas observar una línea base sin índice.
- Carga menos datos que en un ambiente real para mantener el laboratorio en 45 minutos.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
cat > 01_setup_lab.sql <<'SQL'
CREATE SCHEMA IF NOT EXISTS app;

DROP TABLE IF EXISTS app.order_items;
DROP TABLE IF EXISTS app.orders;
DROP TABLE IF EXISTS app.products;
DROP TABLE IF EXISTS app.customers;

CREATE TABLE app.customers (
    customer_id  bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    email        text NOT NULL,
    full_name    text NOT NULL,
    country_code char(2) NOT NULL DEFAULT 'US',
    created_at   timestamptz NOT NULL DEFAULT now(),
    is_active    boolean NOT NULL DEFAULT true
);

CREATE TABLE app.products (
    product_id   bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    sku          text NOT NULL,
    category     text NOT NULL,
    price        numeric(10,2) NOT NULL,
    stock        int NOT NULL DEFAULT 0,
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.orders (
    order_id     bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    customer_id  bigint NOT NULL REFERENCES app.customers(customer_id),
    status       text NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','processing','shipped','delivered','cancelled')),
    total_amount numeric(12,2) NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.order_items (
    item_id      bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    order_id     bigint NOT NULL REFERENCES app.orders(order_id),
    product_id   bigint NOT NULL REFERENCES app.products(product_id),
    quantity     int NOT NULL CHECK (quantity > 0),
    unit_price   numeric(10,2) NOT NULL
);

INSERT INTO app.customers (email, full_name, country_code, is_active)
SELECT
    'user_' || i || '@example.com',
    'Customer ' || i,
    (ARRAY['US','MX','BR','AR','CO'])[1 + (i % 5)],
    (i % 10 != 0)
FROM generate_series(1, 15000) AS s(i);

INSERT INTO app.products (sku, category, price, stock)
SELECT
    'SKU-' || LPAD(i::text, 6, '0'),
    (ARRAY['Electronics','Clothing','Books','Food','Sports'])[1 + (i % 5)],
    (random() * 500 + 5)::numeric(10,2),
    (random() * 1000)::int
FROM generate_series(1, 500) AS s(i);

INSERT INTO app.orders (customer_id, status, total_amount, created_at, updated_at)
SELECT
    1 + (random() * 14999)::int,
    (ARRAY['pending','processing','shipped','delivered','cancelled'])[1 + (random()*4)::int],
    (random() * 2000 + 10)::numeric(12,2),
    now() - ((random() * 120)::int || ' days')::interval,
    now()
FROM generate_series(1, 50000) AS s(i);

INSERT INTO app.order_items (order_id, product_id, quantity, unit_price)
SELECT
    o.order_id,
    1 + (random() * 499)::int,
    1 + (random() * 5)::int,
    (random() * 500 + 5)::numeric(10,2)
FROM app.orders o,
     generate_series(1, 2) AS s(i);

ANALYZE app.customers;
ANALYZE app.products;
ANALYZE app.orders;
ANALYZE app.order_items;
SQL

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -f 01_setup_lab.sql
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT schemaname, relname AS tabla, n_live_tup AS filas_estimadas
      FROM pg_stat_user_tables
      WHERE schemaname = 'app'
      ORDER BY relname;"
```

---

## 📌 Resultado esperado

Debes ver aproximadamente:

```text
customers     15000
order_items   100000
orders        50000
products      500
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20crear%20un%20dataset%20OLTP%20en%20PostgreSQL%20con%20customers%2C%20products%2C%20orders%20y%20order_items%2C%20usando%20generate_series%20y%20ANALYZE.)

---

# 🧩 Reto 6. Obtener línea base sin índices

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Ejecutar consultas sin índices adicionales para identificar planes ineficientes.

---

## 🧠 Escenario

Antes de optimizar, necesitas una línea base. Ejecutarás tres consultas y observarás si PostgreSQL usa `Seq Scan`, cuántas filas descarta y cuánto tiempo tarda.

---

## 🛠️ Tu reto

Ejecuta planes para estas consultas:

- Búsqueda puntual por email.
- Órdenes por estado y fecha.
- Últimas órdenes de un cliente.

---

## 🧾 Valores estandarizados que debes crear o registrar

| Elemento | Nombre o valor estándar | Observación |
|---|---|---|
| Tabla de resultados | `public.lab_resultados` | Guarda hallazgos conceptuales antes y después de optimizar. |
| Escenario inicial | `Antes de indices` | Mantén este texto igual para que las validaciones funcionen. |
| Consulta 1 | `Busqueda por email` | Evalúa `app.customers.email`. |
| Consulta 2 | `Ordenes por status y fecha` | Evalúa `app.orders.status` + `created_at`. |
| Consulta 3 | `Ultimas ordenes por cliente` | Evalúa `customer_id`, `status` y ordenamiento por fecha. |
| Email de prueba | `user_12345@example.com` | Debe existir en `app.customers`. |
| Cliente de prueba | `1000` | Se usa para buscar últimas órdenes. |

---

## 💡 Pistas

Busca en la salida:

- `Seq Scan`.
- `Rows Removed by Filter`.
- `Sort`.
- `Buffers`.
- `Execution Time`.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Crear tabla de resultados ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "CREATE TABLE IF NOT EXISTS public.lab_resultados (
        id bigserial PRIMARY KEY,
        consulta text NOT NULL,
        escenario text NOT NULL,
        tipo_scan text,
        observaciones text,
        registrado_en timestamptz DEFAULT now()
      );"

echo "=== Limpiar registros previos de línea base ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "DELETE FROM public.lab_resultados
      WHERE escenario = 'Antes de indices';"

echo "=== Consulta 1: búsqueda por email sin índice ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
      SELECT customer_id, email, full_name
      FROM app.customers
      WHERE email = 'user_12345@example.com';"

echo "=== Consulta 2: órdenes por estado y fecha sin índice ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
      SELECT order_id, customer_id, status, total_amount, created_at
      FROM app.orders
      WHERE status = 'pending'
        AND created_at >= now() - interval '30 days';"

echo "=== Consulta 3: últimas órdenes por cliente sin índice ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
      SELECT order_id, customer_id, status, total_amount, created_at
      FROM app.orders
      WHERE customer_id = 1000
        AND status != 'cancelled'
      ORDER BY created_at DESC
      LIMIT 10;"

echo "=== Registrar línea base conceptual ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "INSERT INTO public.lab_resultados
      (consulta, escenario, tipo_scan, observaciones)
      VALUES
      ('Busqueda por email', 'Antes de indices', 'Seq Scan esperado', 'Sin indice en email'),
      ('Ordenes por status y fecha', 'Antes de indices', 'Seq Scan esperado', 'Sin indice compuesto'),
      ('Ultimas ordenes por cliente', 'Antes de indices', 'Seq Scan + Sort esperado', 'Sin indice parcial');"

echo "=== Validar registros de línea base ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT consulta, escenario, tipo_scan, observaciones
      FROM public.lab_resultados
      WHERE escenario = 'Antes de indices'
      ORDER BY id;"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT consulta, escenario, tipo_scan, observaciones
      FROM public.lab_resultados
      ORDER BY id;"
```

---

## 📌 Resultado esperado

Durante la ejecución de las consultas con EXPLAIN ANALYZE, debes observar planes con patrones como:

```text
Seq Scan
Rows Removed by Filter
Sort
Execution Time
Buffers
```

Además, la tabla public.lab_resultados debe contener tres registros de línea base correspondientes a las consultas evaluadas antes de crear índices.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20interpretar%20EXPLAIN%20ANALYZE%20BUFFERS%20en%20PostgreSQL%2C%20incluyendo%20Seq%20Scan%2C%20Rows%20Removed%20by%20Filter%2C%20Sort%2C%20Buffers%20y%20Execution%20Time.)

---

# 🧩 Reto 7. Crear índices y comparar planes

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Crear índices iniciales y validar que los planes de ejecución cambien.

---

## 🧠 Escenario

Ya identificaste consultas con escaneos secuenciales. Ahora aplicarás índices para reducir lectura, mejorar filtros y evitar ordenamientos innecesarios.

---

## 🛠️ Tu reto

Crea:

- Índice simple para búsqueda por email.
- Índice compuesto para `status` y `created_at`.
- Índice parcial para órdenes no canceladas por cliente.
- Índice de cobertura para consultas recientes por estado.

Después repite las consultas para comparar los planes.

---

## 🧾 Valores estandarizados que debes crear

| Elemento | Nombre estándar | Tabla | Tipo de índice |
|---|---|---|---|
| Índice por email | `idx_customers_email` | `app.customers` | B-tree simple |
| Índice por estado y fecha | `idx_orders_status_created` | `app.orders` | B-tree compuesto |
| Índice parcial por cliente | `idx_orders_active_customer_created` | `app.orders` | B-tree parcial |
| Índice de cobertura | `idx_orders_covering_status_created` | `app.orders` | B-tree con `INCLUDE` |
| Escenario optimizado | `Despues de indices` | `public.lab_resultados` | Registro conceptual |

---

## 💡 Pistas

- Para búsqueda puntual usa índice sobre la columna filtrada.
- Para igualdad + rango usa índice compuesto.
- Para subconjuntos frecuentes usa índice parcial.
- Para reducir acceso al heap puedes usar `INCLUDE`.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Crear índices ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "CREATE INDEX idx_customers_email
      ON app.customers (email);

      CREATE INDEX idx_orders_status_created
      ON app.orders (status, created_at DESC);

      CREATE INDEX idx_orders_active_customer_created
      ON app.orders (customer_id, created_at DESC)
      WHERE status != 'cancelled';

      CREATE INDEX idx_orders_covering_status_created
      ON app.orders (status, created_at DESC)
      INCLUDE (order_id, customer_id, total_amount);

      ANALYZE app.customers;
      ANALYZE app.orders;"

echo "=== Validar índices creados ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT indexname, tablename
      FROM pg_indexes
      WHERE schemaname = 'app'
        AND indexname LIKE 'idx_%'
      ORDER BY tablename, indexname;"

echo "=== Repetir consulta por email ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
      SELECT customer_id, email, full_name
      FROM app.customers
      WHERE email = 'user_12345@example.com';"

echo "=== Repetir consulta por status y fecha ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
      SELECT order_id, customer_id, status, total_amount, created_at
      FROM app.orders
      WHERE status = 'pending'
        AND created_at >= now() - interval '30 days';"

echo "=== Repetir consulta últimas órdenes por cliente ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
      SELECT order_id, customer_id, status, total_amount, created_at
      FROM app.orders
      WHERE customer_id = 1000
        AND status != 'cancelled'
      ORDER BY created_at DESC
      LIMIT 10;"

echo "=== Registrar optimización conceptual ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "INSERT INTO public.lab_resultados
      (consulta, escenario, tipo_scan, observaciones)
      VALUES
      ('Busqueda por email', 'Despues de indices', 'Index Scan esperado', 'Indice simple en email'),
      ('Ordenes por status y fecha', 'Despues de indices', 'Index Scan o Bitmap Scan esperado', 'Indice compuesto status + created_at'),
      ('Ultimas ordenes por cliente', 'Despues de indices', 'Index Scan esperado', 'Indice parcial por cliente y fecha');"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT consulta, escenario, tipo_scan, observaciones
      FROM public.lab_resultados
      ORDER BY consulta, escenario;"
```

También valida los índices:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT indexname, tablename
      FROM pg_indexes
      WHERE schemaname = 'app'
        AND indexname LIKE 'idx_%'
      ORDER BY tablename, indexname;"
```

---

## 📌 Resultado esperado

Debes observar algunos de estos patrones:

```text
Index Scan using idx_customers_email
Bitmap Index Scan
Bitmap Heap Scan
Index Scan using idx_orders_active_customer_created
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20los%20%C3%ADndices%20B-tree%20simples%2C%20compuestos%2C%20parciales%20y%20de%20cobertura%20mejoran%20consultas%20en%20PostgreSQL%20y%20c%C3%B3mo%20validarlo%20con%20EXPLAIN%20ANALYZE%20BUFFERS.)

---

# 🧩 Reto 8. Validar slow queries en logs

## ⏱️ Tiempo estimado

**3 minutos**

---

## 🎯 Objetivo del reto

Generar una consulta lenta controlada y confirmar que aparece en los logs de Aurora PostgreSQL.

---

## 🧠 Escenario

Antes de finalizar, debes comprobar que `slow query logging` funciona correctamente. Para ello ejecutarás una consulta controlada con `pg_sleep(0.2)` y revisarás los logs disponibles de la instancia Aurora.

---

## 🛠️ Tu reto

Realiza lo siguiente:

- Ejecuta una consulta lenta controlada.
- Lista los archivos de log disponibles para la instancia writer.
- Guarda el nombre del archivo de log más reciente.
- Busca entradas `duration:` dentro del log.

---

## 🧾 Valores estandarizados que debes crear o usar

| Elemento | Nombre o valor estándar | Observación |
|---|---|---|
| Consulta lenta controlada | `SELECT pg_sleep(0.2)` | Supera el umbral de 100 ms configurado. |
| Instancia a revisar | `aurora-performance-lab-instance-1` | Se referencia con `AURORA_INSTANCE_ID`. |
| Archivo de log más reciente | `AURORA_LOG_FILE` | Variable exportada desde `describe-db-log-files`. |
| Patrón de búsqueda | `duration:` | Texto esperado en entradas de slow query. |
| Cantidad de entradas a revisar | `tail -20` | Muestra las últimas entradas relevantes. |

---

## 💡 Pistas

- Usa `pg_sleep(0.2)` para superar 100 ms.
- Los logs se consultan con `describe-db-log-files`.
- Descarga una porción del log con `download-db-log-file-portion`.
- Busca el patrón `duration:` para confirmar que el registro de consultas lentas está activo.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Generar slow query controlada ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=lab_performance user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT pg_sleep(0.2), COUNT(*) FROM app.order_items WHERE unit_price > 400;"

echo "=== Listar logs disponibles ==="

aws rds describe-db-log-files \
  --db-instance-identifier "$AURORA_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'DescribeDBLogFiles[*].{Archivo:LogFileName,Tamano:Size,UltimaEscritura:LastWritten}' \
  --output table

echo "=== Obtener archivo de log más reciente ==="

export AURORA_LOG_FILE=$(aws rds describe-db-log-files \
  --db-instance-identifier "$AURORA_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'DescribeDBLogFiles[-1].LogFileName' \
  --output text)

echo "Archivo de log seleccionado: $AURORA_LOG_FILE"

echo "=== Buscar entradas duration ==="

aws rds download-db-log-file-portion \
  --db-instance-identifier "$AURORA_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --log-file-name "$AURORA_LOG_FILE" \
  --starting-token 0 \
  --output text | grep "duration:" | tail -20
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
echo "Archivo revisado: $AURORA_LOG_FILE"

aws rds download-db-log-file-portion \
  --db-instance-identifier "$AURORA_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --log-file-name "$AURORA_LOG_FILE" \
  --starting-token 0 \
  --output text | grep "duration:" | tail -5
```

---

## 📌 Resultado esperado

Debes observar al menos una entrada con el patrón:

```text
duration:
```

Esto confirma que Aurora PostgreSQL registró una consulta que superó el umbral configurado en `log_min_duration_statement`.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20validar%20slow%20queries%20en%20Aurora%20PostgreSQL%20con%20pg_sleep%2C%20logs%20de%20RDS%20y%20el%20patr%C3%B3n%20duration.)

---

# 🧩 Reto 9. Eliminar recursos del laboratorio

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Eliminar los recursos creados durante el laboratorio para evitar costos innecesarios en AWS.

---

## 🧠 Escenario

Ya validaste el comportamiento de los planes de ejecución, los índices y los logs. Ahora debes limpiar el ambiente en el orden correcto. La eliminación debe realizarse con cuidado porque existen dependencias entre base de datos, instancia, clúster, Parameter Group, DB Subnet Group y Security Group.

---

## 🛠️ Tu reto

Realiza lo siguiente:

- Restaura los parámetros de logging usados en el laboratorio.
- Termina conexiones activas contra `lab_performance`.
- Elimina la base de datos `lab_performance`.
- Elimina la instancia writer.
- Elimina el clúster Aurora.
- Elimina el DB Cluster Parameter Group.
- Elimina el DB Subnet Group.
- Elimina el Security Group.

---

## 🧾 Valores estandarizados que debes eliminar

| Recurso | Nombre estándar | Variable asociada | Orden |
|---|---|---|---:|
| Base de datos | `lab_performance` | No aplica | 1 |
| Instancia writer | `aurora-performance-lab-instance-1` | `AURORA_INSTANCE_ID` | 2 |
| Clúster Aurora | `aurora-performance-lab-cluster` | `AURORA_CLUSTER_ID` | 3 |
| DB Cluster Parameter Group | `aurora-performance-lab-cluster-pg` | `AURORA_PARAM_GROUP` | 4 |
| DB Subnet Group | `aurora-performance-lab-db-subnet-group` | `DB_SUBNET_GROUP_NAME` | 5 |
| Security Group | `aurora-performance-lab-aurora-sg` | `AURORA_SG_ID` | 6 |

---

## 💡 Pistas

- Elimina primero la base de laboratorio para cerrar el ciclo de trabajo SQL.
- La instancia debe eliminarse antes que el clúster.
- El Parameter Group no puede eliminarse si sigue asociado a un clúster.
- El DB Subnet Group y el Security Group se eliminan al final.
- Usa `--skip-final-snapshot` porque es un entorno temporal de laboratorio.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Restaurar parámetros de logging ==="

aws rds modify-db-cluster-parameter-group \
  --db-cluster-parameter-group-name "$AURORA_PARAM_GROUP" \
  --region "$AWS_REGION" \
  --parameters \
    "ParameterName=log_min_duration_statement,ParameterValue=-1,ApplyMethod=immediate" \
    "ParameterName=log_statement,ParameterValue=none,ApplyMethod=immediate"

echo "=== Terminar conexiones activas contra lab_performance ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT pg_terminate_backend(pid)
      FROM pg_stat_activity
      WHERE datname = 'lab_performance'
        AND pid <> pg_backend_pid();"

echo "=== Eliminar base de laboratorio ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "DROP DATABASE IF EXISTS lab_performance;"

echo "=== Eliminar instancia Aurora ==="

aws rds delete-db-instance \
  --db-instance-identifier "$AURORA_INSTANCE_ID" \
  --skip-final-snapshot \
  --delete-automated-backups \
  --region "$AWS_REGION"

aws rds wait db-instance-deleted \
  --db-instance-identifier "$AURORA_INSTANCE_ID" \
  --region "$AWS_REGION"

echo "=== Eliminar clúster Aurora ==="

aws rds delete-db-cluster \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --skip-final-snapshot \
  --region "$AWS_REGION"

aws rds wait db-cluster-deleted \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION"

echo "=== Eliminar DB Cluster Parameter Group ==="

aws rds delete-db-cluster-parameter-group \
  --db-cluster-parameter-group-name "$AURORA_PARAM_GROUP" \
  --region "$AWS_REGION"

echo "=== Eliminar DB Subnet Group ==="

aws rds delete-db-subnet-group \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --region "$AWS_REGION"

echo "=== Eliminar Security Group ==="

aws ec2 delete-security-group \
  --group-id "$AURORA_SG_ID" \
  --region "$AWS_REGION"

echo "Limpieza finalizada."
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" || echo "Clúster eliminado correctamente."

aws rds describe-db-subnet-groups \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --region "$AWS_REGION" || echo "DB Subnet Group eliminado correctamente."

echo "=== Buscar Security Group del laboratorio ==="

export LAB_PREFIX="aurora-performance-lab"

export AURORA_SG_ID=$(aws ec2 describe-security-groups \
  --region "$AWS_REGION" \
  --filters "Name=group-name,Values=${LAB_PREFIX}-aurora-sg" \
  --query "SecurityGroups[0].GroupId" \
  --output text)

echo "Security Group encontrado: $AURORA_SG_ID"

aws ec2 describe-security-groups \
  --group-ids "$AURORA_SG_ID" \
  --region "$AWS_REGION" || echo "Security Group eliminado correctamente."
```

---

## 📌 Resultado esperado

Debes ver mensajes indicando que:

```text
El clúster ya no existe
La instancia ya no existe
El Security Group fue eliminado
El DB Subnet Group fue eliminado
El Parameter Group fue eliminado
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20eliminar%20recursos%20de%20un%20laboratorio%20Aurora%20PostgreSQL%20en%20AWS%20CLI%3A%20base%20de%20datos%2C%20instancia%2C%20cl%C3%BAster%2C%20Parameter%20Group%2C%20DB%20Subnet%20Group%20y%20Security%20Group.)

---

# ✅ Validación final del laboratorio

Al finalizar la práctica, debes haber completado lo siguiente:

| Elemento | Estado esperado |
|---|---|
| CloudShell validado | Correcto |
| Variables del laboratorio | Definidas |
| Security Group | Creado y eliminado |
| DB Subnet Group | Creado y eliminado |
| Aurora PostgreSQL | Creado y eliminado |
| Base `lab_performance` | Creada y eliminada |
| Slow query logging | Activado temporalmente |
| Tablas OLTP | Creadas |
| Datos de prueba | Cargados |
| Línea base | Ejecutada con `EXPLAIN` |
| Índices | Creados y validados |
| Logs | Slow query detectada |
| Restauración de logging | Completada |
| Limpieza | Completada en tarea separada |

---

# 🧠 Resultado esperado de aprendizaje

Después de completar este laboratorio, debes poder explicar y ejecutar el flujo básico de optimización en Aurora PostgreSQL:

1. Crear un entorno temporal de prueba.
2. Cargar datos representativos.
3. Ejecutar consultas sin índices.
4. Leer planes con `EXPLAIN (ANALYZE, BUFFERS)`.
5. Crear índices adecuados.
6. Comparar el comportamiento del optimizador.
7. Confirmar slow queries en logs.
8. Restaurar parámetros temporales del laboratorio.
9. Limpiar recursos cloud para evitar costos.

---

# 📌 Resumen del laboratorio

En este laboratorio trabajaste con AWS CloudShell para crear un clúster temporal de Amazon Aurora PostgreSQL, activar el registro de consultas lentas, preparar una base OLTP, ejecutar consultas de línea base con `EXPLAIN (ANALYZE, BUFFERS)` y aplicar índices B-tree simples, compuestos, parciales y de cobertura. También validaste slow queries desde los logs de Aurora y ejecutaste una tarea separada de limpieza completa de recursos. El laboratorio consolida el proceso esencial de optimización de rendimiento: **medir, diagnosticar, optimizar, comparar, validar logs y eliminar recursos temporales**.
