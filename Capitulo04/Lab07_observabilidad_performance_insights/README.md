<h1 align="center">📈 Laboratorio 7. Observabilidad avanzada con Performance Insights</h1>

---

## 1. 🧾 Información general de la práctica

## 📘 Descripción general

En este laboratorio vas a utilizar **Amazon RDS Performance Insights** para analizar carga real generada de forma controlada en **AWS Aurora PostgreSQL**. Prepararás datos ligeros, ejecutarás carga OLTP y consultas problemáticas, observarás el gráfico de **Average Active Sessions (AAS)**, identificarás **wait events** dominantes, correlacionarás la carga con **Top SQL**, confirmarás hallazgos con `pg_stat_statements` y exportarás evidencia mediante la **Performance Insights API**.

El objetivo no es optimizar todavía las consultas. Eso se realizará en la siguiente práctica. En este laboratorio el aprendizaje se centra en observar, diagnosticar y documentar señales de rendimiento antes de modificar índices, consultas o parámetros.

La práctica está diseñada como una serie de **retos guiados**. En cada reto primero intentarás resolver el objetivo con pistas. Si te bloqueas, podrás abrir la **solución sugerida**. La solución está oculta para fomentar el razonamiento, pero es completa y funcional para no extender el tiempo del laboratorio.

El enfoque principal es el ciclo de observabilidad avanzada:

> **Preparar → Validar PI → Validar pg_stat_statements → Generar carga → Observar AAS → Identificar waits → Correlacionar Top SQL → Exportar evidencia → Validar → Limpiar**

Esta práctica evita Terraform, cambios persistentes de parameter groups y cargas demasiado grandes para que pueda completarse en **45 minutos**.

---

## 🎯 Objetivos de aprendizaje

Al finalizar este laboratorio, podrás:

- Usar AWS CloudShell para conectarte a un clúster Aurora PostgreSQL.
- Identificar la instancia writer de un clúster Aurora PostgreSQL.
- Validar que Performance Insights está habilitado en la instancia writer.
- Obtener el ARN y `DbiResourceId` de la instancia writer.
- Validar que `pg_stat_statements` está disponible para analizar SQL normalizado.
- Generar carga controlada con `pgbench`.
- Crear consultas problemáticas observables sin afectar permanentemente el clúster.
- Interpretar el gráfico de AAS frente a la línea de vCPU.
- Identificar wait events dominantes en Performance Insights.
- Correlacionar waits con Top SQL.
- Confirmar consultas costosas con `pg_stat_statements`.
- Exportar evidencia básica con la Performance Insights API.
- Guardar un resumen técnico del diagnóstico.
- Validar el estado final previo a limpieza.
- Eliminar objetos temporales del laboratorio de forma controlada.

---

## ✅ Prerrequisitos

Antes de iniciar, debes contar con:

- Ejecutar antes de comenzar el script `00_preparar_laboratorio_7_aurora.sh` desde **AWS CloudShell** o contar con un clúster Aurora PostgreSQL equivalente ya disponible.
- Acceso a una cuenta AWS.
- Acceso a AWS CloudShell.
- Clúster Aurora PostgreSQL con instancia writer disponible.
- Performance Insights habilitado en la instancia writer.
- Permisos IAM para:
  - `rds:DescribeDBClusters`
  - `rds:DescribeDBInstances`
  - `rds:ModifyDBInstance`
  - `pi:GetResourceMetrics`
  - `pi:DescribeDimensionKeys`
  - `pi:GetDimensionKeyDetails`
  - `sts:GetCallerIdentity`
- Cliente `psql` disponible en AWS CloudShell.
- Cliente `pgbench` disponible en AWS CloudShell.
- Python 3 disponible en AWS CloudShell.
- `jq` disponible para procesar JSON.
- Navegador web con acceso a la consola AWS.
- Conocimiento básico de SQL, wait events, `pg_stat_activity`, `pg_stat_statements`, Performance Insights y Average Active Sessions.

> ⚠️ **Importante:** Este laboratorio asume que Performance Insights está habilitado. Si no está habilitado, el script de preparación puede intentar habilitarlo en la instancia writer. Ese cambio puede tardar algunos minutos en reflejarse y requiere permisos adecuados.

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
| AWS CLI | Validación de RDS y consulta de PI API |
| psql | Conexión y validación SQL |
| pgbench | Generación de carga OLTP |
| Python 3 | Extracción y resumen de evidencia |
| jq | Procesamiento de salida JSON |
| Performance Insights | Análisis visual de AAS, waits y SQL |
| Aurora PostgreSQL | Motor de base de datos |

---

## 🧱 Valores estandarizados del laboratorio

Usa estos valores durante toda la práctica para mantener consistencia entre los retos, las validaciones y la limpieza final.

| Tipo | Nombre / valor estándar | Uso |
|---|---|---|
| Región | `$AWS_REGION` | Región activa de AWS CLI o `us-west-2` como valor por defecto del script previo |
| Cluster ID | `aurora-performance-lab-cluster` | Identificador esperado del clúster Aurora |
| Instancia writer | `$AURORA_WRITER_INSTANCE` | Instancia observada en Performance Insights |
| ARN de instancia | `$AURORA_INSTANCE_ARN` | Identificador usado por Performance Insights API |
| DbiResourceId | `$AURORA_DBI_RESOURCE_ID` | Identificador interno de la instancia |
| Endpoint writer | `$AURORA_ENDPOINT` | Endpoint writer del clúster Aurora PostgreSQL |
| Puerto | `5432` | Puerto estándar PostgreSQL |
| Base de datos | `lab_performance` | Base usada para el laboratorio |
| Usuario administrador | `labadmin` | Usuario master del laboratorio |
| Contraseña temporal | `AuroraLab_2026_Temporal!` | Contraseña de laboratorio, cámbiala si tu instructor lo solicita |
| Archivo de variables | `./lab7_aurora_env.sh` | Variables exportadas para el laboratorio |
| Esquema temporal | `lab_observability` | Esquema de datos para observabilidad |
| Tabla de órdenes | `lab_observability.orders_obs` | Tabla para generar full scans |
| Tabla de inventario | `lab_observability.inventory_hot` | Tabla para generar lock waits |
| Archivo PI status | `07_pi_status.txt` | Validación de Performance Insights |
| Validación pg_stat | `07_pg_stat_statements_check.txt` | Validación de `pg_stat_statements` |
| Datos observabilidad | `07_setup_observability_data.txt` | Evidencia de preparación de datos |
| Carga pgbench | `07_pgbench_load.txt` | Evidencia de carga OLTP |
| Observaciones PI | `07_observaciones_performance_insights.md` | Evidencia visual documentada |
| Top SQL | `07_pg_stat_statements_top_sql.txt` | Consultas por tiempo total |
| Top latencia | `07_pg_stat_statements_mean_latency.txt` | Consultas por latencia media |
| Waits API | `07_pi_waits.json` | Evidencia de PI API por waits |
| Top SQL API | `07_pi_top_sql.json` | Evidencia de PI API por SQL |
| Resumen final | `07_resumen_observabilidad.md` | Resumen técnico del laboratorio |

---

## 🚦 Preparación previa obligatoria antes de comenzar

Antes de iniciar el **Reto 1**, ejecuta el script de preparación desde **AWS CloudShell**. Este script crea o reutiliza los recursos mínimos requeridos para la práctica: VPC default, subnets, Security Group temporal, DB Subnet Group, clúster Aurora PostgreSQL, instancia writer, base `lab_performance`, clientes `psql` y `pgbench`, validación de Performance Insights, y archivo de variables `lab7_aurora_env.sh`.

> ⚠️ **Costo y seguridad:** El script puede crear recursos que generan cargos. Para facilitar el laboratorio desde CloudShell, el ambiente puede usar conectividad pública temporal y acceso TCP/5432 desde `0.0.0.0/0`. Usa esta configuración solo en laboratorio y elimina o restringe los recursos al terminar.

### Comandos de ejecución previa

```bash
chmod +x 00_preparar_laboratorio_7_aurora.sh
./00_preparar_laboratorio_7_aurora.sh
source ./lab7_aurora_env.sh
```

### Validación previa rápida

```bash
echo "$AURORA_ENDPOINT"
echo "$AURORA_WRITER_INSTANCE"
echo "$AURORA_INSTANCE_ARN"
echo "$AURORA_DBI_RESOURCE_ID"

aws rds describe-db-instances \
  --db-instance-identifier "$AURORA_WRITER_INSTANCE" \
  --region "$AWS_REGION" \
  --query "DBInstances[0].PerformanceInsightsEnabled" \
  --output text

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;"
```

Resultado esperado:

```text
PerformanceInsightsEnabled = True
current_database = lab_performance
es_replica = f
```

Después de esta validación, continúa con el **Reto 1**.

---

## ⏱️ Tabla de tiempo, complejidad y nivel Bloom

| Elemento | Detalle |
|---|---|
| Duración total | 45 minutos |
| Complejidad | Media |
| Nivel Bloom | Aplicar / Analizar |
| Modalidad | Retos guiados con solución oculta |
| Motor | Amazon Aurora PostgreSQL |
| Servicio central | Amazon RDS Performance Insights |
| Entorno | AWS CloudShell + Consola AWS |
| Costo | Puede generar cargos si el clúster fue creado para el laboratorio |
| Enfoque | Observabilidad, AAS, wait events, Top SQL y evidencia |

---

## 🗓️ Distribución de tiempo por reto

| Reto | Actividad | Tiempo |
|---|---|---:|
| Reto 1 | Preparar CloudShell, variables y validar Performance Insights | 5 min |
| Reto 2 | Validar `pg_stat_statements` y configuración mínima | 5 min |
| Reto 3 | Crear datos ligeros y carga observable | 7 min |
| Reto 4 | Ejecutar patrones de carga controlada | 7 min |
| Reto 5 | Analizar AAS, waits y Top SQL en la consola | 8 min |
| Reto 6 | Correlacionar con `pg_stat_statements` | 5 min |
| Reto 7 | Exportar evidencia con Performance Insights API | 5 min |
| Reto 8 | Validar estado final previo a limpieza | 2 min |
| Reto 9 | Eliminar recursos del laboratorio | 1 min |
| **Total** |  | **45 min** |

> 💡 **Nota operativa:** Performance Insights puede tardar entre 1 y 2 minutos en reflejar algunos datos. Si no ves Top SQL inmediatamente, espera un momento y actualiza el intervalo.

---

# 2. 🧪 Desarrollo de la práctica

---

# 🧩 Reto 1. Preparar CloudShell, variables y validar Performance Insights

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Preparar el entorno de trabajo, definir variables estándar, identificar la instancia writer y validar que Performance Insights está habilitado.

---

## 🧠 Escenario

Antes de generar carga, necesitas saber qué instancia observarás en Performance Insights. En Aurora, el clúster tiene un endpoint lógico, pero Performance Insights se revisa a nivel de instancia. Por eso vas a identificar la instancia writer, su ARN y su `DbiResourceId`.

---

## 🧱 Valores estandarizados del reto

| Variable | Valor esperado |
|---|---|
| `AWS_REGION` | Región activa o `us-west-2` |
| `AURORA_CLUSTER_ID` | `aurora-performance-lab-cluster` |
| `AURORA_ENDPOINT` | Endpoint writer del clúster |
| `AURORA_WRITER_INSTANCE` | Instancia writer |
| `AURORA_INSTANCE_ARN` | ARN de instancia writer |
| `AURORA_DBI_RESOURCE_ID` | DbiResourceId de la instancia |
| `PerformanceInsightsEnabled` | `True` |
| Archivo evidencia | `07_pi_status.txt` |

---

## 🛠️ Tu reto

Valida identidad AWS, región, herramientas locales, endpoint writer, instancia writer, ARN, `DbiResourceId` y estado de Performance Insights.

---

## 💡 Pistas

- Usa `source ./lab7_aurora_env.sh`.
- `IsClusterWriter=true` identifica la instancia writer dentro del clúster.
- Performance Insights se consulta con identificadores de la instancia.
- `PerformanceInsightsEnabled=True` es obligatorio para continuar.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
source ./lab7_aurora_env.sh

aws sts get-caller-identity --output table
aws --version
psql --version
pgbench --help >/dev/null && echo "pgbench OK"
python3 --version
jq --version

echo "Cluster:         $AURORA_CLUSTER_ID"
echo "Endpoint:        $AURORA_ENDPOINT"
echo "Writer:          $AURORA_WRITER_INSTANCE"
echo "Instance ARN:    $AURORA_INSTANCE_ARN"
echo "DbiResourceId:   $AURORA_DBI_RESOURCE_ID"

aws rds describe-db-instances \
  --db-instance-identifier "$AURORA_WRITER_INSTANCE" \
  --region "$AWS_REGION" \
  --query "DBInstances[0].{Instance:DBInstanceIdentifier,Clase:DBInstanceClass,Estado:DBInstanceStatus,PI_Enabled:PerformanceInsightsEnabled,PI_Retention:PerformanceInsightsRetentionPeriod,DbiResourceId:DbiResourceId}" \
  --output table \
  | tee 07_pi_status.txt
```

</details>

---

## 🔍 Validación

```bash
aws rds describe-db-instances \
  --db-instance-identifier "$AURORA_WRITER_INSTANCE" \
  --region "$AWS_REGION" \
  --query "DBInstances[0].PerformanceInsightsEnabled" \
  --output text
```

---

## 📌 Resultado esperado

```text
True
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20identificar%20la%20instancia%20writer%20de%20Aurora%20PostgreSQL%20y%20validar%20si%20Performance%20Insights%20est%C3%A1%20habilitado%20usando%20AWS%20CLI.)

---

# 🧩 Reto 2. Validar `pg_stat_statements` y configuración mínima

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Validar que `pg_stat_statements` está disponible para correlacionar las consultas observadas en Performance Insights con métricas SQL acumuladas.

---

## 🧠 Escenario

Performance Insights permite ver carga por SQL, pero `pg_stat_statements` ayuda a confirmar estadísticas acumuladas como llamadas, tiempo total, latencia media, bloques leídos y temporales. Si la extensión no existe, la crearás en la base de laboratorio.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor esperado |
|---|---|
| Base | `$AURORA_DBNAME` |
| Extensión | `pg_stat_statements` |
| Archivo evidencia | `07_pg_stat_statements_check.txt` |
| Reset de estadísticas | Ejecutado con `pg_stat_statements_reset()` |
| Rol esperado | Writer, `pg_is_in_recovery() = false` |

---

## 🛠️ Tu reto

Valida conexión al writer, extensión `pg_stat_statements`, parámetros relacionados y reinicia estadísticas para iniciar el análisis limpio.

---

## 💡 Pistas

- `CREATE EXTENSION IF NOT EXISTS` no falla si la extensión ya existe.
- Si `pg_stat_statements` no está en `shared_preload_libraries`, requerirá ajuste de parameter group y reinicio.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 07_pg_stat_statements_check.txt
SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
SELECT name, setting, unit, source, context
FROM pg_settings
WHERE name IN ('shared_preload_libraries','track_io_timing','pg_stat_statements.track','pg_stat_statements.max','track_activity_query_size')
ORDER BY name;
SELECT pg_stat_statements_reset();
SQL
```

</details>

---

## 🔍 Validación

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT extname FROM pg_extension WHERE extname = 'pg_stat_statements';"
```

---

## 📌 Resultado esperado

```text
pg_stat_statements
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20validar%20pg_stat_statements%20en%20Aurora%20PostgreSQL%20y%20por%20qu%C3%A9%20es%20%C3%BAtil%20para%20correlacionar%20con%20Performance%20Insights.)

---

# 🧩 Reto 3. Crear datos ligeros y carga observable

## ⏱️ Tiempo estimado

**7 minutos**

---

## 🎯 Objetivo del reto

Crear un esquema de laboratorio con datos suficientes para generar carga observable en Performance Insights sin usar tablas demasiado grandes.

---

## 🧠 Escenario

Usarás un esquema `lab_observability` con una tabla de órdenes y una tabla de inventario. La tabla de órdenes se usará para provocar lecturas costosas y la tabla de inventario para provocar espera por locks.

---

## 🧱 Valores estandarizados del reto

| Recurso | Valor |
|---|---|
| Esquema | `lab_observability` |
| Tabla lectura | `orders_obs` |
| Filas aproximadas | `250000` |
| Tabla lock | `inventory_hot` |
| Filas inventario | `100` |
| Archivo evidencia | `07_setup_observability_data.txt` |

---

## 🛠️ Tu reto

Crea el esquema temporal, tablas de apoyo, datos ligeros y estadísticas actualizadas.

---

## 💡 Pistas

- No crees índices en columnas de filtro de `orders_obs`; eso permite provocar full scans.
- Usa `ANALYZE` al final.
- El objetivo es observabilidad, no optimización.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 07_setup_observability_data.txt
DROP SCHEMA IF EXISTS lab_observability CASCADE;
CREATE SCHEMA lab_observability;
CREATE TABLE lab_observability.orders_obs (
    order_id BIGSERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    product_code TEXT NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    status TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    description TEXT
);
INSERT INTO lab_observability.orders_obs (customer_id, product_code, amount, status, created_at, description)
SELECT
    (random() * 50000)::INTEGER + 1,
    'PROD-' || ((random() * 1000)::INTEGER + 1)::TEXT,
    (random() * 10000)::NUMERIC(12,2),
    CASE (random() * 4)::INTEGER WHEN 0 THEN 'pending' WHEN 1 THEN 'processing' WHEN 2 THEN 'shipped' ELSE 'delivered' END,
    now() - ((random() * 90)::INTEGER || ' days')::INTERVAL,
    repeat('orden de laboratorio para observabilidad ', 3)
FROM generate_series(1, 250000);
CREATE TABLE lab_observability.inventory_hot (
    product_id INTEGER PRIMARY KEY,
    stock INTEGER NOT NULL DEFAULT 1000,
    reserved INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);
INSERT INTO lab_observability.inventory_hot (product_id, stock)
SELECT generate_series(1, 100), 1000;
ANALYZE lab_observability.orders_obs;
ANALYZE lab_observability.inventory_hot;
SELECT schemaname, relname, n_live_tup
FROM pg_stat_user_tables
WHERE schemaname = 'lab_observability'
ORDER BY relname;
SQL
```

</details>

---

## 🔍 Validación

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS total_orders FROM lab_observability.orders_obs;"
```

---

## 📌 Resultado esperado

```text
total_orders
------------
250000
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20crear%20datos%20ligeros%20en%20PostgreSQL%20para%20generar%20carga%20observable%20en%20Performance%20Insights%20sin%20usar%20tablas%20demasiado%20grandes.)

---

# 🧩 Reto 4. Ejecutar patrones de carga controlada

## ⏱️ Tiempo estimado

**7 minutos**

---

## 🎯 Objetivo del reto

Generar carga controlada que sea visible en Performance Insights mediante tres patrones: carga OLTP, full scans y espera por locks.

---

## 🧠 Escenario

Performance Insights necesita actividad suficiente para mostrar AAS, waits y Top SQL. Ejecutarás scripts de carga en segundo plano para producir patrones observables durante los siguientes minutos.

---

## 🧱 Valores estandarizados del reto

| Patrón | Duración | Archivo evidencia |
|---|---:|---|
| `pgbench` OLTP | 90s | `07_pgbench_load.txt` |
| Full scan | 90s | `07_full_scan_load.txt` |
| Lock wait | ~40s | `07_lock_wait_load.txt` |

---

## 🛠️ Tu reto

Ejecuta carga OLTP ligera con `pgbench`, full scans repetidos sobre `orders_obs` y lock controlado sobre `inventory_hot`.

---

## 💡 Pistas

- La carga debe durar entre 60 y 90 segundos.
- Abre una segunda pestaña de CloudShell si quieres observar procesos mientras corren.
- Usa `PGPASSWORD` para evitar prompt interactivo.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
cat > 07_run_full_scan.sh <<'SCRIPT'
#!/bin/bash
set -euo pipefail
END_TIME=$((SECONDS + 90))
while [ $SECONDS -lt $END_TIME ]; do
  psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
    -c "SELECT status, count(*) AS total, sum(amount) AS amount_total FROM lab_observability.orders_obs WHERE status = 'pending' AND customer_id > 25000 GROUP BY status;" >/dev/null 2>&1 || true
done
SCRIPT
chmod +x 07_run_full_scan.sh

cat > 07_run_lock_wait.sh <<'SCRIPT'
#!/bin/bash
set -euo pipefail
for i in $(seq 1 20); do
  psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' >/dev/null 2>&1 &
BEGIN;
UPDATE lab_observability.inventory_hot SET stock = stock - 1, reserved = reserved + 1, updated_at = now() WHERE product_id = 1;
SELECT pg_sleep(2);
COMMIT;
SQL
  sleep 0.2
  psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
    -c "UPDATE lab_observability.inventory_hot SET stock = stock - 1, reserved = reserved + 1, updated_at = now() WHERE product_id = 1;" >/dev/null 2>&1 &
  sleep 2
done
SCRIPT
chmod +x 07_run_lock_wait.sh

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -tc "SELECT count(*) FROM pg_tables WHERE tablename LIKE 'pgbench%';" | grep -q '[1-9]' \
  || PGPASSWORD="$AURORA_MASTER_PASSWORD" pgbench -h "$AURORA_ENDPOINT" -p "$AURORA_PORT" -U "$AURORA_MASTER_USER" -d "$AURORA_DBNAME" -i -s 5 2>&1 | tee 07_pgbench_init.txt

PGPASSWORD="$AURORA_MASTER_PASSWORD" pgbench -h "$AURORA_ENDPOINT" -p "$AURORA_PORT" -U "$AURORA_MASTER_USER" -d "$AURORA_DBNAME" -c 10 -j 2 -T 90 -P 10 2>&1 | tee 07_pgbench_load.txt &
export PGBENCH_PID=$!
./07_run_full_scan.sh > 07_full_scan_load.txt 2>&1 &
export FULLSCAN_PID=$!
./07_run_lock_wait.sh > 07_lock_wait_load.txt 2>&1 &
export LOCKWAIT_PID=$!
sleep 60

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT state, wait_event_type, wait_event, count(*) AS sesiones FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid() GROUP BY state, wait_event_type, wait_event ORDER BY sesiones DESC;"
```

</details>

---

## 🔍 Validación

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS consultas_observadas FROM pg_stat_statements WHERE calls > 0;"
```

---

## 📌 Resultado esperado

Debes ver consultas registradas en `pg_stat_statements` y sesiones relacionadas con `pgbench`, `orders_obs` e `inventory_hot`.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20generar%20carga%20controlada%20en%20Aurora%20PostgreSQL%20para%20observar%20AAS%2C%20wait%20events%20y%20Top%20SQL%20en%20Performance%20Insights.)

---

# 🧩 Reto 5. Analizar AAS, waits y Top SQL en la consola

## ⏱️ Tiempo estimado

**8 minutos**

---

## 🎯 Objetivo del reto

Usar la consola de Performance Insights para interpretar AAS, identificar wait events dominantes y correlacionarlos con consultas SQL.

---

## 🧠 Escenario

Ya generaste carga controlada. Ahora debes observarla en Performance Insights. Este reto es principalmente visual y analítico.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor esperado |
|---|---|
| Consola | RDS → Databases → Instancia writer |
| Vista | Performance Insights |
| Intervalo | Last 15 minutes |
| Dimensiones | Waits y SQL |
| Archivo observaciones | `07_observaciones_performance_insights.md` |

---

## 🛠️ Tu reto

En la consola AWS, clic en el menu lateral derecho Performance Insights, selecciona el nodo de aurora, selecciona los últimos 15 minutos, revisa AAS, cambia dimensiones a **Waits** y **SQL**, identifica consultas de `orders_obs`, `inventory_hot` y `pgbench`, y documenta observaciones.

---

## 💡 Pistas

- AAS significa sesiones activas promedio.
- Si AAS supera la línea de vCPU de forma sostenida, hay presión en recursos.
- La dimensión **Waits** muestra el tipo de cuello de botella.
- La dimensión **SQL** muestra qué consulta contribuye más a la carga.

---

<details>
<summary>✅ Ver guía de análisis sugerida</summary>

```bash
cat > 07_observaciones_performance_insights.md <<EOF
# Observaciones Performance Insights — Laboratorio 7

| Campo | Observación |
|---|---|
| Instancia writer | $AURORA_WRITER_INSTANCE |
| Intervalo revisado | Last 15 minutes |
| AAS máximo observado | Pendiente de completar |
| Línea de vCPU | Pendiente de completar |
| ¿AAS superó vCPU? | Sí / No |
| Wait dominante | CPU / IO / Lock / LWLock / Otro |
| SQL principal observado | Pendiente de completar |
| Consulta de orders_obs visible | Sí / No |
| Consulta de inventory_hot visible | Sí / No |
| Interpretación inicial | Pendiente de completar |

## Notas

- Si domina IO, revisar consultas con full scan.
- Si domina Lock, revisar sesiones bloqueadas y transacciones largas.
- Si domina CPU, revisar consultas con agregaciones, joins o alto volumen.
EOF
cat 07_observaciones_performance_insights.md
```

</details>

---

## 🔍 Validación

```bash
ls -lh 07_observaciones_performance_insights.md
```

---

## 📌 Resultado esperado

Debes completar un archivo con AAS máximo observado, wait dominante, SQL principal e interpretación inicial.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20leer%20el%20gr%C3%A1fico%20AAS%20de%20Performance%20Insights%20en%20Aurora%20PostgreSQL%20y%20c%C3%B3mo%20correlacionar%20waits%20con%20Top%20SQL.)

---

# 🧩 Reto 6. Correlacionar con `pg_stat_statements`

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Confirmar desde SQL qué consultas consumieron más tiempo total, tuvieron mayor latencia media o generaron más lectura de bloques.

---

## 🧠 Escenario

Performance Insights te da una vista temporal y visual de la carga. `pg_stat_statements` te permite consultar métricas acumuladas por consulta normalizada. En este reto unirás ambas perspectivas.

---

## 🧱 Valores estandarizados del reto

| Consulta | Archivo evidencia |
|---|---|
| Top SQL por tiempo total | `07_pg_stat_statements_top_sql.txt` |
| Top SQL por latencia media | `07_pg_stat_statements_mean_latency.txt` |
| Actividad por tablas | `07_table_activity_summary.txt` |

---

## 🛠️ Tu reto

Consulta Top SQL por `total_exec_time`, Top SQL por `mean_exec_time`, bloques compartidos y actividad en tablas del esquema `lab_observability`.

---

## 💡 Pistas

- `total_exec_time` identifica impacto acumulado.
- `mean_exec_time` identifica consultas individualmente costosas.
- `shared_blks_read` alto puede sugerir lectura desde disco o working set mayor a caché.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 07_pg_stat_statements_top_sql.txt
SELECT left(query, 120) AS query_preview, calls, round(total_exec_time::numeric, 2) AS total_ms,
       round(mean_exec_time::numeric, 2) AS mean_ms, rows, shared_blks_read, shared_blks_hit, temp_blks_written
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY total_exec_time DESC
LIMIT 10;
SQL

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 07_pg_stat_statements_mean_latency.txt
SELECT left(query, 120) AS query_preview, calls, round(total_exec_time::numeric, 2) AS total_ms,
       round(mean_exec_time::numeric, 2) AS mean_ms, round(max_exec_time::numeric, 2) AS max_ms,
       rows, shared_blks_read, shared_blks_hit
FROM pg_stat_statements
WHERE calls > 0 AND query NOT LIKE '%pg_stat_statements%'
ORDER BY mean_exec_time DESC
LIMIT 10;
SQL

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 07_table_activity_summary.txt
SELECT schemaname, relname, seq_scan, seq_tup_read, idx_scan, n_live_tup, n_dead_tup, last_analyze
FROM pg_stat_user_tables
WHERE schemaname = 'lab_observability'
ORDER BY seq_tup_read DESC;
SQL
```

</details>

---

## 🔍 Validación

```bash
grep -E "orders_obs|inventory_hot|pgbench" 07_pg_stat_statements_top_sql.txt || true
```

---

## 📌 Resultado esperado

Debes encontrar consultas relacionadas con `orders_obs`, `inventory_hot` o tablas `pgbench`.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20correlacionar%20Performance%20Insights%20con%20pg_stat_statements%20para%20identificar%20Top%20SQL%2C%20tiempo%20total%2C%20latencia%20media%20y%20lecturas%20de%20bloques.)

---

# 🧩 Reto 7. Exportar evidencia con Performance Insights API

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Exportar datos básicos de Performance Insights usando AWS CLI para conservar evidencia del análisis.

---

## 🧠 Escenario

La consola es útil para análisis visual, pero en entornos profesionales también necesitas exportar evidencia. Usarás la API de Performance Insights para obtener DB Load agrupado por wait type y Top SQL por carga.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor |
|---|---|
| Ventana | Últimos 15 minutos |
| Métrica | `db.load.avg` |
| Agrupación waits | `db.wait_event_type` |
| Agrupación SQL | `db.sql_tokenized` |
| Archivo waits | `07_pi_waits.json` |
| Archivo Top SQL | `07_pi_top_sql.json` |
| Resumen API | `07_pi_api_summary.md` |

---

## 🛠️ Tu reto

Exporta `db.load.avg` agrupado por wait event type, Top SQL por carga, archivos JSON y resumen legible en Markdown.

---

## 💡 Pistas

- Usa el ARN de la instancia como identificador de Performance Insights.
- Si no hay datos, espera 1 o 2 minutos y repite.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Corrección PI API — Laboratorio 7 ==="

set -euo pipefail

if [ -f ./lab7_aurora_env.sh ]; then
  source ./lab7_aurora_env.sh
fi

echo "=== Limpiar archivos fallidos anteriores ==="

rm -f 07_pi_waits.json 07_pi_top_sql.json 07_pi_dbload.json 07_pi_top_waits.json 07_pi_api_summary.md

echo "=== Validar variables base ==="

: "${AWS_REGION:?Falta AWS_REGION}"
: "${AURORA_WRITER_INSTANCE:?Falta AURORA_WRITER_INSTANCE}"

if [ -z "${AURORA_DBI_RESOURCE_ID:-}" ] || [ "$AURORA_DBI_RESOURCE_ID" = "None" ]; then
  export AURORA_DBI_RESOURCE_ID=$(aws rds describe-db-instances \
    --db-instance-identifier "$AURORA_WRITER_INSTANCE" \
    --region "$AWS_REGION" \
    --query "DBInstances[0].DbiResourceId" \
    --output text)
fi

if [ -z "${AURORA_INSTANCE_ARN:-}" ] || [ "$AURORA_INSTANCE_ARN" = "None" ]; then
  export AURORA_INSTANCE_ARN=$(aws rds describe-db-instances \
    --db-instance-identifier "$AURORA_WRITER_INSTANCE" \
    --region "$AWS_REGION" \
    --query "DBInstances[0].DBInstanceArn" \
    --output text)
fi

echo "AURORA_WRITER_INSTANCE=$AURORA_WRITER_INSTANCE"
echo "AURORA_INSTANCE_ARN=$AURORA_INSTANCE_ARN"
echo "AURORA_DBI_RESOURCE_ID=$AURORA_DBI_RESOURCE_ID"

if [ -z "$AURORA_DBI_RESOURCE_ID" ] || [ "$AURORA_DBI_RESOURCE_ID" = "None" ]; then
  echo "ERROR: No se pudo obtener AURORA_DBI_RESOURCE_ID."
  exit 1
fi

echo "=== Validar que Performance Insights esté habilitado ==="

aws rds describe-db-instances \
  --db-instance-identifier "$AURORA_WRITER_INSTANCE" \
  --region "$AWS_REGION" \
  --query "DBInstances[0].{
    Instance:DBInstanceIdentifier,
    PerformanceInsightsEnabled:PerformanceInsightsEnabled,
    DbiResourceId:DbiResourceId
  }" \
  --output table

PI_ENABLED=$(aws rds describe-db-instances \
  --db-instance-identifier "$AURORA_WRITER_INSTANCE" \
  --region "$AWS_REGION" \
  --query "DBInstances[0].PerformanceInsightsEnabled" \
  --output text)

if [ "$PI_ENABLED" != "True" ]; then
  echo "ERROR: Performance Insights no está habilitado para $AURORA_WRITER_INSTANCE."
  exit 1
fi

echo "=== Definir ventana de consulta PI ==="

export PI_START_TIME=$(date -u -d '15 minutes ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
export PI_END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "Inicio: $PI_START_TIME"
echo "Fin:    $PI_END_TIME"

echo "=== 1. Exportar DB Load general ==="

aws pi get-resource-metrics \
  --service-type RDS \
  --identifier "$AURORA_DBI_RESOURCE_ID" \
  --metric-queries '[{"Metric":"db.load.avg"}]' \
  --start-time "$PI_START_TIME" \
  --end-time "$PI_END_TIME" \
  --period-in-seconds 60 \
  --region "$AWS_REGION" \
  --output json \
  | tee 07_pi_dbload.json >/dev/null

echo "=== 2. Exportar Top wait events ==="

aws pi describe-dimension-keys \
  --service-type RDS \
  --identifier "$AURORA_DBI_RESOURCE_ID" \
  --start-time "$PI_START_TIME" \
  --end-time "$PI_END_TIME" \
  --metric "db.load.avg" \
  --group-by '{"Group":"db.wait_event","Limit":10}' \
  --period-in-seconds 300 \
  --region "$AWS_REGION" \
  --output json \
  | tee 07_pi_top_waits.json >/dev/null

echo "=== 3. Exportar Top SQL ==="

aws pi describe-dimension-keys \
  --service-type RDS \
  --identifier "$AURORA_DBI_RESOURCE_ID" \
  --start-time "$PI_START_TIME" \
  --end-time "$PI_END_TIME" \
  --metric "db.load.avg" \
  --group-by '{"Group":"db.sql_tokenized","Limit":10}' \
  --period-in-seconds 300 \
  --region "$AWS_REGION" \
  --output json \
  | tee 07_pi_top_sql.json >/dev/null

echo "=== Crear resumen legible ==="

cat > 07_pi_api_summary.md <<EOF
# Evidencia PI API — Laboratorio 7

| Elemento | Valor |
|---|---|
| Cluster | ${AURORA_CLUSTER_ID:-No definido} |
| Instancia writer | $AURORA_WRITER_INSTANCE |
| Instance ARN | $AURORA_INSTANCE_ARN |
| DbiResourceId usado por PI API | $AURORA_DBI_RESOURCE_ID |
| Ventana inicio | $PI_START_TIME |
| Ventana fin | $PI_END_TIME |

## Archivos generados

- 07_pi_dbload.json
- 07_pi_top_waits.json
- 07_pi_top_sql.json

## Correcciones aplicadas

- La API de Performance Insights usa DbiResourceId como identifier.
- Para waits se usa el grupo \`db.wait_event\`, no \`db.wait_event_type\`.
- Para Top SQL se usa \`period-in-seconds 300\`, no 900.
EOF

echo "=== Vista rápida de DB Load ==="

cat 07_pi_dbload.json \
  | jq '.MetricList[0].DataPoints[0:5]' 2>/dev/null || true

echo "=== Vista rápida de Top waits ==="

cat 07_pi_top_waits.json \
  | jq '.Keys[0:10] | map({total: .Total, dimensions: .Dimensions})' 2>/dev/null || true

echo "=== Vista rápida de Top SQL ==="

cat 07_pi_top_sql.json \
  | jq '.Keys[0:10] | map({total: .Total, dimensions: .Dimensions})' 2>/dev/null || true

echo "=== Validar archivos ==="

ls -lh \
  07_pi_dbload.json \
  07_pi_top_waits.json \
  07_pi_top_sql.json \
  07_pi_api_summary.md

echo "=== Validar que los JSON no estén vacíos ==="

for FILE in 07_pi_dbload.json 07_pi_top_waits.json 07_pi_top_sql.json; do
  if [ ! -s "$FILE" ]; then
    echo "ERROR: $FILE está vacío."
    exit 1
  fi
done

echo "PI API exportada correctamente."
```

</details>

---

## 🔍 Validación

```bash
ls -lh 07_pi_waits.json 07_pi_top_sql.json
cat 07_pi_api_summary.md
```

---

## 📌 Resultado esperado

Debes tener `07_pi_waits.json`, `07_pi_top_sql.json` y `07_pi_api_summary.md`.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20usar%20la%20Performance%20Insights%20API%20para%20exportar%20DBLoad%20por%20wait%20event%20y%20Top%20SQL%20en%20Aurora%20PostgreSQL.)

---

# 🧩 Reto 8. Validar estado final previo a limpieza

## ⏱️ Tiempo estimado

**2 minutos**

---

## 🎯 Objetivo del reto

Confirmar que los procesos de carga terminaron, que la evidencia fue generada y que el esquema temporal existe antes de ejecutar la limpieza.

---

## 🧠 Escenario

Antes de limpiar, debes confirmar que el laboratorio produjo la evidencia suficiente para el diagnóstico. También debes identificar si aún quedan procesos de carga activos o sesiones relacionadas con el esquema temporal.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor esperado |
|---|---|
| Procesos de carga | Terminados o detenibles |
| Esquema temporal | `lab_observability` |
| Evidencia PI API | `07_pi_waits.json`, `07_pi_top_sql.json` |
| Evidencia SQL | `07_pg_stat_statements_top_sql.txt` |
| Observaciones | `07_observaciones_performance_insights.md` |
| Resumen | Pendiente de crear en Reto 9 |

---

## 🛠️ Tu reto

Valida procesos en background, esquema temporal, archivos de evidencia, `pg_stat_statements` y que estás listo para limpiar.

---

## 💡 Pistas

- No elimines todavía el esquema; la limpieza se realiza en el Reto 9.
- Conserva los archivos `07_*` como evidencia.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "PGBENCH_PID=${PGBENCH_PID:-no definido}"
echo "FULLSCAN_PID=${FULLSCAN_PID:-no definido}"
echo "LOCKWAIT_PID=${LOCKWAIT_PID:-no definido}"

ps -ef | grep -E "pgbench|07_run_full_scan|07_run_lock_wait" | grep -v grep || true

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'lab_observability';"

ls -lh 07_* 2>/dev/null || true

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS consultas_observadas FROM pg_stat_statements WHERE calls > 0;"
```

</details>

---

## 🔍 Validación

```bash
ls -lh 07_pi_waits.json 07_pi_top_sql.json 07_pg_stat_statements_top_sql.txt

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'lab_observability';"
```

---

## 📌 Resultado esperado

Debes ver evidencia generada y el esquema todavía existente.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20validar%20que%20un%20laboratorio%20de%20Performance%20Insights%20tiene%20evidencia%20suficiente%20antes%20de%20limpiar%20datos%20temporales.)

---

# 🧩 Reto 9. Eliminar recursos del laboratorio

## ⏱️ Tiempo estimado

**1 minuto**

---

## 🎯 Objetivo del reto

Detener procesos, limpiar objetos temporales del laboratorio y conservar la evidencia generada.

---

## 🧠 Escenario

La práctica generó tablas y carga temporal. Debes limpiar el esquema `lab_observability`, detener procesos si siguen activos y conservar los archivos de resultados. Si el instructor solicita eliminar también la infraestructura AWS creada para esta práctica, se usará el script de eliminación.

---

## 🧱 Valores estandarizados del reto

| Recurso | Valor estándar | Acción |
|---|---|---|
| Procesos pgbench | `$PGBENCH_PID` | Detener si siguen activos |
| Full scan | `$FULLSCAN_PID` | Detener si sigue activo |
| Lock wait | `$LOCKWAIT_PID` | Detener si sigue activo |
| Esquema temporal | `lab_observability` | Eliminar con `DROP SCHEMA` |
| Evidencia | `07_*` | Conservar |
| Script de eliminación | `00_eliminar_laboratorio_7_aurora.sh` | Usar si se eliminará infraestructura |

---

## 🛠️ Tu reto

Detén cargas en background, elimina el esquema temporal, crea resumen final, empaqueta evidencia y ejecuta el script de eliminación solo si el instructor lo solicita.

---

## 💡 Pistas

- No destruyas el clúster Aurora si será usado por laboratorios posteriores.
- No elimines Performance Insights.
- Conserva archivos `07_*` como evidencia.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
kill "${PGBENCH_PID:-}" 2>/dev/null || true
kill "${FULLSCAN_PID:-}" 2>/dev/null || true
kill "${LOCKWAIT_PID:-}" 2>/dev/null || true
pkill -f "07_run_full_scan.sh" 2>/dev/null || true
pkill -f "07_run_lock_wait.sh" 2>/dev/null || true

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "DROP SCHEMA IF EXISTS lab_observability CASCADE;"

cat > 07_resumen_observabilidad.md <<EOF
# Resumen — Laboratorio 7 Observabilidad avanzada con Performance Insights

| Elemento | Valor |
|---|---|
| Fecha UTC | $(date -u +"%Y-%m-%dT%H:%M:%SZ") |
| Cluster | $AURORA_CLUSTER_ID |
| Instancia writer | $AURORA_WRITER_INSTANCE |
| Endpoint | $AURORA_ENDPOINT |
| Instance ARN | $AURORA_INSTANCE_ARN |
| DbiResourceId | $AURORA_DBI_RESOURCE_ID |
| Performance Insights | Validado |
| pg_stat_statements | Validado |
| Carga OLTP | pgbench |
| Carga problemática | full scan + lock wait |
| Evidencia PI API | 07_pi_waits.json, 07_pi_top_sql.json |

## Conclusión

El laboratorio permitió generar carga controlada, observar AAS en Performance Insights, identificar waits dominantes, correlacionar Top SQL con pg_stat_statements y exportar evidencia mediante PI API.
EOF

tar -czf "07_observabilidad_evidencia_$(date +%Y%m%d-%H%M%S).tar.gz" 07_* 2>/dev/null || true
ls -lh 07_*
```

</details>

---

## 🔍 Validación

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'lab_observability';"

ls -lh 07_resumen_observabilidad.md
```

---

## 📌 Resultado esperado

El esquema debe desaparecer:

```text
(0 rows)
```

Y debes conservar:

```text
07_resumen_observabilidad.md
07_observabilidad_evidencia_*.tar.gz
```

Si el instructor solicita eliminar también el clúster Aurora y los recursos AWS creados para esta práctica, ejecuta el script de eliminación desde AWS CloudShell:

```bash
chmod +x 00_eliminar_laboratorio_7_aurora.sh
./00_eliminar_laboratorio_7_aurora.sh
```
---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20limpiar%20objetos%20temporales%20de%20un%20laboratorio%20de%20Aurora%20PostgreSQL%20y%20guardar%20evidencia%20de%20Performance%20Insights.)

---

# ✅ Validación final del laboratorio

Al finalizar la práctica, debes haber completado lo siguiente:

| Elemento | Estado esperado |
|---|---|
| AWS CloudShell validado | Correcto |
| Variables `AURORA_*` | Definidas |
| Instancia writer | Identificada |
| Performance Insights | Habilitado |
| `AURORA_INSTANCE_ARN` | Definido |
| `AURORA_DBI_RESOURCE_ID` | Definido |
| `pg_stat_statements` | Validado |
| Datos de laboratorio | Creados |
| Carga controlada | Ejecutada |
| AAS en Performance Insights | Revisado |
| Waits dominantes | Identificados |
| Top SQL | Correlacionado |
| `pg_stat_statements` | Consultado |
| PI API | Consultada |
| Evidencia | Guardada |
| Estado final previo a limpieza | Validado |
| Esquema temporal | Eliminado |
| Infraestructura | Eliminada solo si el instructor lo solicitó |

---

# 🧠 Resultado esperado de aprendizaje

Después de completar este laboratorio, debes poder explicar y ejecutar un flujo profesional de observabilidad en Aurora PostgreSQL:

1. Identificar la instancia writer.
2. Validar Performance Insights.
3. Validar `pg_stat_statements`.
4. Generar carga controlada.
5. Leer AAS en Performance Insights.
6. Comparar AAS contra vCPU.
7. Identificar wait events dominantes.
8. Correlacionar wait events con Top SQL.
9. Confirmar hallazgos con `pg_stat_statements`.
10. Exportar evidencia con PI API.
11. Validar estado final previo a limpieza.
12. Preparar el diagnóstico para una práctica posterior de optimización.

---

# 📌 Resumen del laboratorio

En este laboratorio utilizaste AWS CloudShell, Aurora PostgreSQL y Amazon RDS Performance Insights para observar carga real generada de forma controlada. Primero validaste la instancia writer y el estado de Performance Insights. Después confirmaste `pg_stat_statements`, creaste datos ligeros, ejecutaste carga OLTP y patrones problemáticos de full scan y lock wait. Luego analizaste AAS, wait events y Top SQL en la consola de Performance Insights, correlacionaste los hallazgos con consultas acumuladas en `pg_stat_statements` y exportaste evidencia mediante la Performance Insights API. Finalmente validaste el estado final, limpiaste los objetos temporales y guardaste un resumen técnico del diagnóstico. Esta práctica prepara el camino para la siguiente fase: diagnóstico y optimización de consultas.
