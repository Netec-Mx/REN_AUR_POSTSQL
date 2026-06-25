<h1 align="center">🏁 Laboratorio 9. Arquitectura Aurora: optimización, observabilidad y DR</h1>

---

## 1. 🧾 Información general de la práctica

## 📘 Descripción general

En este laboratorio final vas a validar y documentar una arquitectura avanzada de **AWS Aurora PostgreSQL** para un escenario empresarial de alta concurrencia. Revisarás la configuración base del clúster, validarás optimizaciones aplicadas en prácticas anteriores, ejecutarás una medición corta de rendimiento, revisarás el estado de **RDS Proxy**, consultarás métricas de **Performance Insights** y **CloudWatch**, evaluarás la preparación para **Disaster Recovery multi-región** y generarás un documento técnico final de arquitectura.

Este laboratorio no busca crear toda la arquitectura desde cero. Su objetivo es de cierre y síntesis:

> **Validar → Medir → Evaluar → Documentar → Recomendar → Cerrar**

La práctica está diseñada para completarse en **45 minutos**. Por eso, **Aurora Global Database, RDS Proxy y recursos multi-región se validan si ya existen**. Si no existen, el estudiante documentará la arquitectura objetivo, los comandos de referencia y los riesgos de implementación.

La práctica está diseñada como una serie de **retos guiados**. En cada reto primero intentarás resolver el objetivo con pistas. Si te bloqueas, podrás abrir la **solución sugerida**. La solución está oculta para fomentar el razonamiento, pero es completa y funcional para no extender el tiempo del laboratorio.

> ⚠️ **Importante:** Esta práctica no ejecuta switchover/failover real como paso obligatorio. Esos procedimientos solo deben ejecutarse con autorización del instructor y en un entorno preparado para pruebas de DR.

---

## 🎯 Objetivos de aprendizaje

Al finalizar este laboratorio, podrás:

- Validar una arquitectura Aurora PostgreSQL optimizada.
- Identificar endpoint writer, reader endpoint, instancia writer, ARN y `DbiResourceId`.
- Revisar parámetros, extensiones, índices y estadísticas relevantes.
- Ejecutar un benchmark corto de validación con `pgbench`.
- Validar RDS Proxy como capa de gestión de conexiones si está disponible.
- Documentar RDS Proxy como recomendación si no existe.
- Revisar métricas de Performance Insights y CloudWatch.
- Evaluar preparación para DR multi-región con Aurora Global Database.
- Diferenciar switchover y failover en un escenario de DR.
- Definir objetivos RPO/RTO.
- Generar un documento técnico final de arquitectura.
- Empaquetar evidencia del laboratorio integrador.
- Validar estado final antes del cierre.
- Ejecutar limpieza controlada de recursos si el instructor lo solicita.

---

## ✅ Prerrequisitos

Antes de iniciar, debes contar con:

- Ejecutar antes de comenzar el script `00_preparar_laboratorio_9_aurora.sh` desde **AWS CloudShell** o contar con un clúster Aurora PostgreSQL equivalente ya disponible.
- Haber completado los laboratorios anteriores del curso o contar con recursos equivalentes.
- Acceso a una cuenta AWS.
- Acceso a AWS CloudShell.
- Clúster Aurora PostgreSQL activo.
- Instancia writer disponible.
- Cliente `psql` disponible.
- Cliente `pgbench` disponible.
- AWS CLI configurado.
- Python 3 disponible.
- `jq` disponible.
- Performance Insights habilitado en la instancia writer para validación completa.
- `pg_stat_statements` disponible en la base de datos objetivo.
- RDS Proxy creado previamente si se desea validarlo en vivo.
- Aurora Global Database creado previamente si se desea validar DR real.
- Permisos IAM para consultar RDS, RDS Proxy, Performance Insights, CloudWatch, Aurora Global Database y STS.
- Conocimientos básicos de arquitectura Aurora, endpoints, RDS Proxy, Performance Insights, CloudWatch, RPO/RTO y documentación técnica.

---

## 🖥️ Hardware

| Recurso | Recomendación |
|---|---|
| Equipo local | Navegador web moderno |
| CPU local | No aplica, se usa AWS CloudShell |
| RAM local | No aplica |
| Almacenamiento local | No aplica |
| Red | Acceso estable a consola AWS |
| Ambiente de ejecución | AWS CloudShell |

---

## 🧰 Software

| Software | Uso |
|---|---|
| AWS CloudShell | Ambiente principal |
| Bash | Ejecución de comandos |
| AWS CLI | Validación de arquitectura |
| psql | Validación SQL |
| pgbench | Benchmark corto |
| Python 3 | Generación de documento técnico |
| jq | Procesamiento de JSON |
| Performance Insights | Observabilidad de DBLoad/AAS |
| CloudWatch | Métricas, dashboard y evidencia |
| Aurora PostgreSQL | Motor de base de datos |
| RDS Proxy | Gestión de conexiones, si existe |
| Aurora Global Database | DR multi-región, si existe |

---

## 🧱 Valores estandarizados del laboratorio

Usa estos valores durante toda la práctica para mantener consistencia entre los retos, las validaciones y la limpieza final.

| Tipo | Nombre / valor estándar | Uso |
|---|---|---|
| Región primaria | `$AWS_PRIMARY_REGION` | Región principal del clúster Aurora |
| Región secundaria | `$AWS_SECONDARY_REGION` | Región objetivo para DR |
| Región AWS CLI | `$AWS_REGION` | Región activa de AWS CLI |
| Cluster ID | `aurora-performance-lab-cluster` | Identificador esperado del clúster Aurora |
| Endpoint writer | `$AURORA_ENDPOINT` | Endpoint de escritura |
| Endpoint reader | `$AURORA_READER_ENDPOINT` | Endpoint de lectura |
| Instancia writer | `$AURORA_WRITER_INSTANCE` | Instancia actual con rol writer |
| Instance ARN | `$AURORA_INSTANCE_ARN` | ARN para Performance Insights |
| DbiResourceId | `$AURORA_DBI_RESOURCE_ID` | ID interno para observabilidad |
| Puerto | `5432` | Puerto estándar PostgreSQL |
| Base de datos | `lab_performance` | Base usada para validaciones |
| Usuario administrador | `labadmin` | Usuario master del laboratorio |
| Contraseña temporal | `AuroraLab_2026_Temporal!` | Contraseña de laboratorio, cámbiala si tu instructor lo solicita |
| RDS Proxy esperado | `aurora-pg-proxy-lab` | Proxy validado si existe |
| Global DB esperado | `aurora-lab-global` | Global Database validado si existe |
| Cluster secundario esperado | `aurora-lab-cluster-secondary` | Cluster secundario para DR si existe |
| Archivo de variables | `./lab9_aurora_env.sh` | Variables exportadas para el laboratorio |
| Evidencia cluster | `09_arquitectura_base_cluster.json` | Estado base del clúster |
| Evidencia instancias | `09_arquitectura_base_instancias.txt` | Estado de instancias |
| Revisión parámetros | `09_revision_parametros.txt` | Configuración PostgreSQL |
| Revisión extensiones | `09_revision_extensiones.txt` | Extensiones instaladas |
| Revisión índices | `09_revision_indices.txt` | Índices y uso |
| Revisión estadísticas | `09_revision_estadisticas.txt` | Estadísticas de tablas |
| Benchmark directo | `09_benchmark_directo.txt` | Medición corta directa |
| Benchmark proxy | `09_benchmark_proxy.txt` | Medición corta vía proxy si existe |
| Estado PI | `09_performance_insights_estado.txt` | Estado Performance Insights |
| DBLoad waits | `09_pi_dbload_waits.json` | PI API por waits |
| Métricas CloudWatch | `09_cloudwatch_metricas.txt` | Métricas básicas |
| Dashboard mínimo | `09_cloudwatch_dashboard_minimo.json` | Plantilla de dashboard |
| Diseño DR | `09_diseno_dr_multi_region.md` | Diseño si Global DB no existe |
| Documento final | `09_arquitectura_aurora_final.md` | Entregable técnico |
| Evidencia comprimida | `09_evidencia_integrador_*.tar.gz` | Paquete final |

---

## 🚦 Preparación previa obligatoria antes de comenzar

Antes de iniciar el **Reto 1**, ejecuta el script de preparación desde **AWS CloudShell**. Este script crea o reutiliza los recursos mínimos requeridos para la práctica: VPC default, subnets, Security Group temporal, DB Subnet Group, clúster Aurora PostgreSQL, instancia writer, base `lab_performance`, clientes `psql` y `pgbench`, validación de Performance Insights, validación de `pg_stat_statements`, variables base y archivo `lab9_aurora_env.sh`.

> ⚠️ **Costo y seguridad:** El script puede crear recursos que generan cargos. Para facilitar el laboratorio desde CloudShell, el ambiente puede usar conectividad pública temporal y acceso TCP/5432 desde `0.0.0.0/0`. Usa esta configuración solo en laboratorio y elimina o restringe los recursos al terminar.

### Comandos de ejecución previa

```bash
chmod +x 00_preparar_laboratorio_9_aurora.sh
./00_preparar_laboratorio_9_aurora.sh
source ./lab9_aurora_env.sh
```

### Validación previa rápida

```bash
echo "$AWS_PRIMARY_REGION"
echo "$AWS_SECONDARY_REGION"
echo "$AURORA_ENDPOINT"
echo "$AURORA_READER_ENDPOINT"
echo "$AURORA_WRITER_INSTANCE"
echo "$AURORA_INSTANCE_ARN"

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;" \
  -c "SELECT extname FROM pg_extension WHERE extname = 'pg_stat_statements';"
```

Resultado esperado:

```text
current_database = lab_performance
es_replica = f
pg_stat_statements
```

Después de esta validación, continúa con el **Reto 1**.

---

## ⏱️ Tabla de tiempo, complejidad y nivel Bloom

| Elemento | Detalle |
|---|---|
| Duración total | 45 minutos |
| Complejidad | Alta |
| Nivel Bloom | Crear / Evaluar |
| Modalidad | Reto integrador guiado |
| Motor | Amazon Aurora PostgreSQL |
| Servicios relacionados | RDS Proxy, Performance Insights, CloudWatch, Aurora Global Database |
| Entorno | AWS CloudShell |
| Enfoque | Validación, arquitectura, observabilidad y DR |
| Limpieza | Conserva evidencia y elimina infraestructura solo si el instructor lo solicita |

---

## 🗓️ Distribución de tiempo por reto

| Reto | Actividad | Tiempo |
|---|---|---:|
| Reto 1 | Preparar variables y validar arquitectura base | 5 min |
| Reto 2 | Revisar optimizaciones aplicadas | 6 min |
| Reto 3 | Ejecutar benchmark corto de validación | 6 min |
| Reto 4 | Validar RDS Proxy y conexiones | 5 min |
| Reto 5 | Revisar observabilidad: Performance Insights y CloudWatch | 7 min |
| Reto 6 | Evaluar DR multi-región / Aurora Global Database | 7 min |
| Reto 7 | Generar documento técnico de arquitectura | 6 min |
| Reto 8 | Validar estado final previo al cierre | 2 min |
| Reto 9 | Empaquetar evidencia y limpiar si aplica | 1 min |
| **Total** |  | **45 min** |

> 💡 **Nota operativa:** Este laboratorio es integrador. Funciona aunque RDS Proxy o Aurora Global Database no existan; en ese caso, se documentan como componentes recomendados y se genera evidencia de diseño.

---

# 2. 🧪 Desarrollo de la práctica

---

# 🧩 Reto 1. Preparar variables y validar arquitectura base

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Definir variables estándar, identificar endpoints del clúster, detectar la instancia writer y guardar una primera evidencia de la arquitectura base.

---

## 🧠 Escenario

Como arquitecto de base de datos, primero debes saber qué arquitectura existe realmente: clúster, writer, reader endpoint, instancias asociadas, clase de instancia, estado y capacidades de observabilidad.

---

## 🧱 Valores estandarizados del reto

| Variable | Valor esperado |
|---|---|
| `AWS_PRIMARY_REGION` | Región primaria |
| `AWS_SECONDARY_REGION` | Región secundaria para DR |
| `AURORA_CLUSTER_ID` | `aurora-performance-lab-cluster` |
| `AURORA_ENDPOINT` | Writer endpoint |
| `AURORA_READER_ENDPOINT` | Reader endpoint |
| `AURORA_WRITER_INSTANCE` | Instancia writer |
| `AURORA_INSTANCE_ARN` | ARN de instancia writer |
| `AURORA_DBI_RESOURCE_ID` | DbiResourceId |
| Evidencia | `09_arquitectura_base_cluster.json`, `09_arquitectura_base_instancias.txt` |

---

## 🛠️ Tu reto

Valida identidad AWS, regiones, clúster Aurora, endpoint writer, endpoint reader, instancia writer, ARN de instancia, `DbiResourceId`, estado general del clúster y archivos de evidencia.

---

## 💡 Pistas

- Usa `source ./lab9_aurora_env.sh`.
- El endpoint del clúster se usa para escrituras.
- El reader endpoint distribuye lecturas entre réplicas disponibles.
- Performance Insights se revisa a nivel de instancia.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Cargar variables del Laboratorio 9 ==="

if [ -f ./lab9_aurora_env.sh ]; then
  source ./lab9_aurora_env.sh
else
  echo "ERROR: No existe ./lab9_aurora_env.sh"
  echo "Ejecuta primero 00_preparar_laboratorio_9_aurora.sh"
  exit 1
fi

echo "=== Validar identidad AWS ==="
aws sts get-caller-identity --output table

echo "=== Regiones ==="
echo "Región primaria:   $AWS_PRIMARY_REGION"
echo "Región secundaria: $AWS_SECONDARY_REGION"

echo "=== Variables Aurora ==="
echo "Cluster:         $AURORA_CLUSTER_ID"
echo "Writer endpoint: $AURORA_ENDPOINT"
echo "Reader endpoint: $AURORA_READER_ENDPOINT"
echo "Writer instance: $AURORA_WRITER_INSTANCE"
echo "Instance ARN:    $AURORA_INSTANCE_ARN"
echo "DbiResourceId:   $AURORA_DBI_RESOURCE_ID"

echo "=== Guardar evidencia de arquitectura base ==="

aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_PRIMARY_REGION" \
  --query "DBClusters[0].{Cluster:DBClusterIdentifier,Estado:Status,Engine:Engine,Version:EngineVersion,Endpoint:Endpoint,ReaderEndpoint:ReaderEndpoint,Members:DBClusterMembers}" \
  --output json \
  | tee 09_arquitectura_base_cluster.json >/dev/null

aws rds describe-db-instances \
  --region "$AWS_PRIMARY_REGION" \
  --filters "Name=db-cluster-id,Values=$AURORA_CLUSTER_ID" \
  --query "DBInstances[*].{Instance:DBInstanceIdentifier,Clase:DBInstanceClass,Estado:DBInstanceStatus,PI:PerformanceInsightsEnabled,MonitoringInterval:MonitoringInterval}" \
  --output table \
  | tee 09_arquitectura_base_instancias.txt

echo "=== Validar conexión al writer ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;" \
  | tee 09_conexion_writer.txt
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
echo "$AURORA_ENDPOINT"
echo "$AURORA_READER_ENDPOINT"
echo "$AURORA_WRITER_INSTANCE"
echo "$AURORA_INSTANCE_ARN"

ls -lh 09_arquitectura_base_cluster.json 09_arquitectura_base_instancias.txt
```

---

## 📌 Resultado esperado

Debes tener definidas las variables principales de Aurora y archivos de evidencia generados.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20validar%20la%20arquitectura%20base%20de%20un%20cl%C3%BAster%20Aurora%20PostgreSQL%20identificando%20writer%2C%20reader%20endpoint%2C%20instancias%20y%20Performance%20Insights.)

---

# 🧩 Reto 2. Revisar optimizaciones aplicadas

## ⏱️ Tiempo estimado

**6 minutos**

---

## 🎯 Objetivo del reto

Revisar el estado actual de optimización del clúster sin aplicar cambios globales.

---

## 🧠 Escenario

Como práctica de cierre, no debes modificar parameter groups sin ventana de mantenimiento. En su lugar, validarás configuración, extensiones, índices, estadísticas y actividad acumulada. Esto te permitirá documentar el estado de la arquitectura y proponer mejoras justificadas.

---

## 🧱 Valores estandarizados del reto

| Evidencia | Archivo |
|---|---|
| Parámetros clave | `09_revision_parametros.txt` |
| Extensiones | `09_revision_extensiones.txt` |
| Índices | `09_revision_indices.txt` |
| Estadísticas | `09_revision_estadisticas.txt` |
| Top SQL | `09_revision_top_sql.txt` |

---

## 🛠️ Tu reto

Consulta y guarda evidencia de parámetros clave, extensiones, `pg_stat_statements`, índices existentes, estadísticas de tablas y top queries acumuladas.

---

## 💡 Pistas

- No modifiques parameter groups en este reto.
- Si las tablas de prácticas anteriores ya fueron limpiadas, el resultado puede ser limitado; eso es aceptable.
- Lo importante es documentar lo que existe y lo que falta.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Revisar parámetros clave ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 09_revision_parametros.txt

SELECT
  name,
  setting,
  unit,
  source,
  context
FROM pg_settings
WHERE name IN (
  'shared_buffers',
  'work_mem',
  'maintenance_work_mem',
  'effective_cache_size',
  'random_page_cost',
  'effective_io_concurrency',
  'checkpoint_completion_target',
  'track_io_timing',
  'shared_preload_libraries',
  'max_connections'
)
ORDER BY name;

SQL

echo "=== Revisar extensiones ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT extname, extversion FROM pg_extension ORDER BY extname;" \
  | tee 09_revision_extensiones.txt

echo "=== Revisar índices principales ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 09_revision_indices.txt

SELECT
  schemaname,
  tablename,
  indexname,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC, pg_relation_size(indexrelid) DESC
LIMIT 20;

SQL

echo "=== Revisar estadísticas de tablas ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 09_revision_estadisticas.txt

SELECT
  schemaname,
  relname,
  n_live_tup,
  n_dead_tup,
  seq_scan,
  idx_scan,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC
LIMIT 20;

SQL

echo "=== Revisar Top SQL si pg_stat_statements existe ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 09_revision_top_sql.txt

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

SELECT
  left(query, 120) AS query_preview,
  calls,
  round(total_exec_time::numeric, 2) AS total_ms,
  round(mean_exec_time::numeric, 2) AS mean_ms,
  shared_blks_read,
  shared_blks_hit,
  temp_blks_written
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY total_exec_time DESC
LIMIT 10;

SQL
```

</details>

---

## 🔍 Validación

```bash
ls -lh 09_revision_parametros.txt \
       09_revision_indices.txt \
       09_revision_estadisticas.txt \
       09_revision_top_sql.txt
```

---

## 📌 Resultado esperado

Debes conservar evidencia de parámetros, extensiones, índices, estadísticas y top SQL.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20revisar%20el%20estado%20de%20optimizaci%C3%B3n%20de%20Aurora%20PostgreSQL%20sin%20modificar%20parameter%20groups%2C%20usando%20pg_settings%2C%20pg_stat_user_indexes%20y%20pg_stat_user_tables.)

---

# 🧩 Reto 3. Ejecutar benchmark corto de validación

## ⏱️ Tiempo estimado

**6 minutos**

---

## 🎯 Objetivo del reto

Ejecutar una medición corta con `pgbench` para validar el estado actual de rendimiento del clúster.

---

## 🧠 Escenario

Este no es un benchmark formal de producción. Es una medición rápida de laboratorio para generar evidencia y alimentar el documento técnico final.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor |
|---|---|
| Escala pgbench | `5` |
| Clientes | `10` |
| Hilos | `2` |
| Duración | `45 segundos` |
| Archivo benchmark | `09_benchmark_directo.txt` |
| Resumen | `09_benchmark_directo_resumen.txt` |

---

## 🛠️ Tu reto

Realiza preparación de tablas `pgbench` si no existen, benchmark corto directo al writer, extracción de TPS y latencia, y evidencia en archivo.

---

## 💡 Pistas

- Usa 45 segundos para mantener el laboratorio dentro de tiempo.
- Usa 10 clientes y 2 hilos para evitar saturar CloudShell.
- No interpretes TPS como única métrica de arquitectura.
- Usa `PGPASSWORD` para evitar prompts interactivos.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Inicializar pgbench si no existen tablas ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -tc "SELECT count(*) FROM pg_tables WHERE tablename LIKE 'pgbench%';" | grep -q '[1-9]' \
  || PGPASSWORD="$AURORA_MASTER_PASSWORD" \
     pgbench \
      -h "$AURORA_ENDPOINT" \
      -p "$AURORA_PORT" \
      -U "$AURORA_MASTER_USER" \
      -d "$AURORA_DBNAME" \
      -i \
      -s 5 \
      2>&1 | tee 09_pgbench_init.txt

echo "=== Ejecutar benchmark directo corto ==="

PGPASSWORD="$AURORA_MASTER_PASSWORD" \
pgbench \
  -h "$AURORA_ENDPOINT" \
  -p "$AURORA_PORT" \
  -U "$AURORA_MASTER_USER" \
  -d "$AURORA_DBNAME" \
  -c 10 \
  -j 2 \
  -T 45 \
  -P 15 \
  2>&1 | tee 09_benchmark_directo.txt

echo "=== Resumen benchmark directo ==="

grep -E "latency average|tps =" 09_benchmark_directo.txt \
  | tee 09_benchmark_directo_resumen.txt
```

</details>

---

## 🔍 Validación

```bash
cat 09_benchmark_directo_resumen.txt
```

---

## 📌 Resultado esperado

Debes ver líneas similares a:

```text
latency average = ...
tps = ...
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20ejecutar%20un%20benchmark%20corto%20con%20pgbench%20en%20Aurora%20PostgreSQL%20y%20por%20qu%C3%A9%20no%20debo%20usar%20TPS%20como%20%C3%BAnica%20m%C3%A9trica%20de%20arquitectura.)

---

# 🧩 Reto 4. Validar RDS Proxy y conexiones

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Validar si existe RDS Proxy, revisar su estado, targets y configuración de connection pooling. Si está disponible, ejecutar una prueba corta vía proxy.

---

## 🧠 Escenario

RDS Proxy ayuda a administrar conexiones, reducir churn y proteger Aurora ante picos de clientes. No debe interpretarse como una garantía de mayor TPS, sino como una capa de gestión de conexiones.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor |
|---|---|
| Proxy esperado | `$RDS_PROXY_NAME` o `aurora-pg-proxy-lab` |
| Estado proxy | `09_rds_proxy_estado.txt` |
| Targets | `09_rds_proxy_targets.txt` |
| Pooling | `09_rds_proxy_pooling.json` |
| Conexión proxy | `09_rds_proxy_conexion.txt` |
| Benchmark proxy | `09_benchmark_proxy.txt` |
| Recomendación si no existe | `09_rds_proxy_recomendacion.md` |

---

## 🛠️ Tu reto

Valida existencia de proxy, endpoint, target health, target group config, benchmark corto vía proxy si existe y documentación si no existe.

---

## 💡 Pistas

- `RDS_PROXY_NAME` puede venir de la práctica 6.
- Si no existe proxy, no bloquees el laboratorio.
- Si hay proxy, compara conexiones directas vs proxy con cautela.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Definir proxy esperado ==="

export RDS_PROXY_NAME="${RDS_PROXY_NAME:-aurora-pg-proxy-lab}"

echo "Proxy esperado: $RDS_PROXY_NAME"

echo "=== Validar si RDS Proxy existe ==="

if aws rds describe-db-proxies \
  --db-proxy-name "$RDS_PROXY_NAME" \
  --region "$AWS_PRIMARY_REGION" >/dev/null 2>&1; then

  echo "RDS Proxy encontrado: $RDS_PROXY_NAME" | tee 09_rds_proxy_estado.txt

  export RDS_PROXY_ENDPOINT=$(aws rds describe-db-proxies \
    --db-proxy-name "$RDS_PROXY_NAME" \
    --region "$AWS_PRIMARY_REGION" \
    --query "DBProxies[0].Endpoint" \
    --output text)

  aws rds describe-db-proxies \
    --db-proxy-name "$RDS_PROXY_NAME" \
    --region "$AWS_PRIMARY_REGION" \
    --query "DBProxies[0].{Nombre:DBProxyName,Estado:Status,Endpoint:Endpoint,TLS:RequireTLS,IdleTimeout:IdleClientTimeout}" \
    --output table \
    | tee -a 09_rds_proxy_estado.txt

  aws rds describe-db-proxy-targets \
    --db-proxy-name "$RDS_PROXY_NAME" \
    --region "$AWS_PRIMARY_REGION" \
    --query "Targets[*].{Tipo:Type,Endpoint:Endpoint,Estado:TargetHealth.State,Descripcion:TargetHealth.Description}" \
    --output table \
    | tee 09_rds_proxy_targets.txt

  aws rds describe-db-proxy-target-groups \
    --db-proxy-name "$RDS_PROXY_NAME" \
    --region "$AWS_PRIMARY_REGION" \
    --query "TargetGroups[0].ConnectionPoolConfig" \
    --output json \
    | tee 09_rds_proxy_pooling.json >/dev/null

  echo "=== Validar conexión vía proxy ==="

  psql "host=$RDS_PROXY_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
    -c "SELECT 'Conexión vía RDS Proxy OK' AS estado, current_database(), current_user;" \
    | tee 09_rds_proxy_conexion.txt

  echo "=== Benchmark corto vía proxy ==="

  PGPASSWORD="$AURORA_MASTER_PASSWORD" \
  pgbench \
    -h "$RDS_PROXY_ENDPOINT" \
    -p "$AURORA_PORT" \
    -U "$AURORA_MASTER_USER" \
    -d "$AURORA_DBNAME" \
    -c 10 \
    -j 2 \
    -T 45 \
    -P 15 \
    2>&1 | tee 09_benchmark_proxy.txt

  grep -E "latency average|tps =" 09_benchmark_proxy.txt \
    | tee 09_benchmark_proxy_resumen.txt

else

  echo "RDS Proxy no existe en este entorno. Se documenta como componente recomendado." \
    | tee 09_rds_proxy_no_disponible.txt

  cat > 09_rds_proxy_recomendacion.md <<DOC
# RDS Proxy — Recomendación de arquitectura

RDS Proxy no está disponible en este entorno de laboratorio.

## Recomendación

Incluir RDS Proxy cuando la aplicación tenga:

- muchas conexiones cortas;
- picos impredecibles de conexión;
- múltiples servicios conectando a Aurora;
- necesidad de proteger el motor contra sobresuscripción de conexiones;
- rotación de secretos con Secrets Manager;
- failover donde la aplicación debe reconectar con menor impacto.

## Validación recomendada

Cuando el proxy exista, revisar:

- ClientConnections;
- DatabaseConnections;
- QueryRequests;
- DatabaseConnectionsBorrowLatency;
- MaxDatabaseConnectionsAllowed.
DOC

fi
```

</details>

---

## 🔍 Validación

```bash
ls -lh 09_*proxy* 2>/dev/null || true
```

---

## 📌 Resultado esperado

Si existe RDS Proxy, debes tener evidencia del estado, targets, pooling y benchmark. Si no existe, debes tener la recomendación documentada.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20validar%20RDS%20Proxy%20para%20Aurora%20PostgreSQL%20y%20por%20qu%C3%A9%20su%20valor%20principal%20es%20connection%20pooling%20y%20no%20necesariamente%20mayor%20TPS.)

---

# 🧩 Reto 5. Revisar observabilidad: Performance Insights y CloudWatch

## ⏱️ Tiempo estimado

**7 minutos**

---

## 🎯 Objetivo del reto

Validar que la arquitectura cuenta con observabilidad suficiente para diagnosticar carga, CPU, waits, conexiones y latencia.

---

## 🧠 Escenario

Una arquitectura madura no solo debe rendir bien; también debe poder observarse. Revisarás Performance Insights y CloudWatch para generar evidencia de monitoreo.

---

## 🧱 Valores estandarizados del reto

| Evidencia | Archivo |
|---|---|
| Estado Performance Insights | `09_performance_insights_estado.txt` |
| DBLoad por waits | `09_pi_dbload_waits.json` |
| Métricas CloudWatch | `09_cloudwatch_metricas.txt` |
| Dashboard mínimo | `09_cloudwatch_dashboard_minimo.json` |

---

## 🛠️ Tu reto

Consulta Performance Insights habilitado, DBLoad por PI API, top wait types, métricas CloudWatch básicas y plantilla de dashboard mínimo.

---

## 💡 Pistas

- `DBLoad` representa actividad de sesiones promedio.
- `DBLoadCPU` indica sesiones activas esperando CPU.
- CloudWatch puede tardar en mostrar puntos recientes.
- Si PI no está habilitado, documenta el hallazgo.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Validar Performance Insights ==="

aws rds describe-db-instances \
  --db-instance-identifier "$AURORA_WRITER_INSTANCE" \
  --region "$AWS_PRIMARY_REGION" \
  --query "DBInstances[0].{Instance:DBInstanceIdentifier,PI_Enabled:PerformanceInsightsEnabled,PI_Retention:PerformanceInsightsRetentionPeriod,MonitoringInterval:MonitoringInterval}" \
  --output table \
  | tee 09_performance_insights_estado.txt

echo "=== Consultar DBLoad con PI API ==="

export PI_START_TIME=$(date -u -d '15 minutes ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
export PI_END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

aws pi get-resource-metrics \
  --service-type RDS \
  --identifier "$AURORA_INSTANCE_ARN" \
  --metric-queries '[{"Metric":"db.load.avg","GroupBy":{"Group":"db.wait_event_type","Dimensions":["db.wait_event_type"],"Limit":5}}]' \
  --start-time "$PI_START_TIME" \
  --end-time "$PI_END_TIME" \
  --period-in-seconds 60 \
  --region "$AWS_PRIMARY_REGION" \
  --output json \
  | tee 09_pi_dbload_waits.json >/dev/null || true

echo "=== Consultar métricas CloudWatch básicas ==="

export CW_END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
export CW_START_TIME=$(date -u -d '15 minutes ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

: > 09_cloudwatch_metricas.txt

for METRIC in CPUUtilization DatabaseConnections ReadLatency WriteLatency; do
  echo "=== $METRIC ===" | tee -a 09_cloudwatch_metricas.txt

  aws cloudwatch get-metric-statistics \
    --namespace "AWS/RDS" \
    --metric-name "$METRIC" \
    --dimensions Name=DBInstanceIdentifier,Value="$AURORA_WRITER_INSTANCE" \
    --start-time "$CW_START_TIME" \
    --end-time "$CW_END_TIME" \
    --period 60 \
    --statistics Average Maximum \
    --region "$AWS_PRIMARY_REGION" \
    --query "sort_by(Datapoints, &Timestamp)[*].{Tiempo:Timestamp,Promedio:Average,Maximo:Maximum}" \
    --output table \
    | tee -a 09_cloudwatch_metricas.txt

done

echo "=== Crear plantilla de dashboard mínimo ==="

cat > 09_cloudwatch_dashboard_minimo.json <<DOC
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "Aurora Writer — CPU y Conexiones",
        "region": "$AWS_PRIMARY_REGION",
        "metrics": [
          [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "$AURORA_WRITER_INSTANCE" ],
          [ "AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "$AURORA_WRITER_INSTANCE" ]
        ],
        "period": 60,
        "stat": "Average",
        "view": "timeSeries"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "Aurora Writer — Latencia Read/Write",
        "region": "$AWS_PRIMARY_REGION",
        "metrics": [
          [ "AWS/RDS", "ReadLatency", "DBInstanceIdentifier", "$AURORA_WRITER_INSTANCE" ],
          [ "AWS/RDS", "WriteLatency", "DBInstanceIdentifier", "$AURORA_WRITER_INSTANCE" ]
        ],
        "period": 60,
        "stat": "Average",
        "view": "timeSeries"
      }
    }
  ]
}
DOC
```

</details>

---

## 🔍 Validación

```bash
ls -lh 09_performance_insights_estado.txt \
       09_pi_dbload_waits.json \
       09_cloudwatch_metricas.txt \
       09_cloudwatch_dashboard_minimo.json
```

---

## 📌 Resultado esperado

Debes tener evidencia de Performance Insights, PI API / DBLoad, CloudWatch metrics y dashboard mínimo JSON.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20validar%20observabilidad%20en%20Aurora%20PostgreSQL%20usando%20Performance%20Insights%2C%20DBLoad%2C%20CloudWatch%20y%20m%C3%A9tricas%20b%C3%A1sicas%20de%20RDS.)

---

# 🧩 Reto 6. Evaluar DR multi-región / Aurora Global Database

## ⏱️ Tiempo estimado

**7 minutos**

---

## 🎯 Objetivo del reto

Evaluar si existe una estrategia de DR multi-región con Aurora Global Database o documentar una arquitectura objetivo si aún no existe.

---

## 🧠 Escenario

No todos los entornos de laboratorio tienen Aurora Global Database precreado. En un laboratorio de 45 minutos, no es realista crear una arquitectura multi-región completa desde cero. Por eso, este reto tiene dos caminos: validar si existe o documentar el diseño objetivo.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor |
|---|---|
| Global DB esperado | `$AURORA_GLOBAL_CLUSTER_ID` o `aurora-lab-global` |
| Cluster secundario esperado | `$AURORA_SECONDARY_CLUSTER_ID` |
| Región primaria | `$AWS_PRIMARY_REGION` |
| Región secundaria | `$AWS_SECONDARY_REGION` |
| Evidencia Global DB | `09_global_database_descripcion.json` |
| Evidencia lag | `09_global_database_replication_lag.txt` |
| Diseño si no existe | `09_diseno_dr_multi_region.md` |

---

## 🛠️ Tu reto

Evalúa si existe Global Database, clúster primario, región secundaria, estado de miembros, lag de replicación si aplica, RPO/RTO objetivo y diferencia entre switchover y failover.

---

## 💡 Pistas

- Switchover se usa para cambios planeados en entornos sanos.
- Failover se usa para recuperación ante desastre.
- No ejecutes failover sin autorización.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Definir nombre esperado de Global Database ==="

export AURORA_GLOBAL_CLUSTER_ID="${AURORA_GLOBAL_CLUSTER_ID:-aurora-lab-global}"
export AURORA_SECONDARY_CLUSTER_ID="${AURORA_SECONDARY_CLUSTER_ID:-aurora-lab-cluster-secondary}"

echo "Global cluster esperado: $AURORA_GLOBAL_CLUSTER_ID"

echo "=== Validar si existe Aurora Global Database ==="

if aws rds describe-global-clusters \
  --global-cluster-identifier "$AURORA_GLOBAL_CLUSTER_ID" \
  --region "$AWS_PRIMARY_REGION" >/dev/null 2>&1; then

  echo "Aurora Global Database encontrado: $AURORA_GLOBAL_CLUSTER_ID" \
    | tee 09_global_database_estado.txt

  aws rds describe-global-clusters \
    --global-cluster-identifier "$AURORA_GLOBAL_CLUSTER_ID" \
    --region "$AWS_PRIMARY_REGION" \
    --query "GlobalClusters[0].{GlobalCluster:GlobalClusterIdentifier,Estado:Status,Engine:Engine,EngineVersion:EngineVersion,Members:GlobalClusterMembers}" \
    --output json \
    | tee 09_global_database_descripcion.json >/dev/null

  cat 09_global_database_descripcion.json | jq '.'

  echo "=== Consultar lag de replicación si existe cluster secundario ==="

  aws cloudwatch get-metric-statistics \
    --namespace "AWS/RDS" \
    --metric-name "AuroraGlobalDBReplicationLag" \
    --dimensions Name=DBClusterIdentifier,Value="$AURORA_SECONDARY_CLUSTER_ID" \
    --start-time "$CW_START_TIME" \
    --end-time "$CW_END_TIME" \
    --period 60 \
    --statistics Average Maximum \
    --region "$AWS_SECONDARY_REGION" \
    --query "sort_by(Datapoints, &Timestamp)[*].{Tiempo:Timestamp,Promedio:Average,Maximo:Maximum}" \
    --output table \
    | tee 09_global_database_replication_lag.txt || true

else

  echo "Aurora Global Database no existe en este entorno. Se documentará arquitectura objetivo." \
    | tee 09_global_database_no_disponible.txt

  cat > 09_diseno_dr_multi_region.md <<DOC
# Diseño objetivo DR multi-región — Aurora Global Database

## Estado

Aurora Global Database no está creado en este entorno de laboratorio.

## Arquitectura objetivo

| Componente | Región primaria | Región secundaria |
|---|---|---|
| Aurora PostgreSQL Cluster | $AWS_PRIMARY_REGION | $AWS_SECONDARY_REGION |
| Rol | Writer | Reader / DR |
| Replicación | Origen | Destino |
| Objetivo | Operación principal | Recuperación ante desastre |

## Objetivos sugeridos

| Métrica | Objetivo recomendado |
|---|---|
| RPO | Menor a 5 segundos para cargas críticas, sujeto a validación real |
| RTO | Menor a 15 minutos para recuperación operativa inicial |
| Prueba DR | Trimestral o por ciclo de release mayor |
| Runbook | Requerido |
| Validación aplicación | Requerida |

## Switchover vs Failover

| Operación | Uso recomendado |
|---|---|
| Switchover | Cambio planeado entre regiones sanas, por mantenimiento o rotación regional |
| Failover | Recuperación ante evento no planeado o pérdida de región primaria |

## Riesgos a documentar

- DNS y endpoint cutover.
- Reconexión de aplicaciones.
- Secrets Manager en región secundaria.
- Seguridad y rutas de red.
- Monitoreo y alarmas.
- Validación de escrituras posterior a recuperación.
- Costos multi-región.
DOC

fi
```

</details>

---

## 🔍 Validación

```bash
ls -lh 09_*global* 09_diseno_dr_multi_region.md 2>/dev/null || true
```

---

## 📌 Resultado esperado

Si existe Global Database, debes tener evidencia real. Si no existe, debes tener el diseño objetivo de DR multi-región.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20evaluar%20una%20estrategia%20DR%20multi-regi%C3%B3n%20con%20Aurora%20Global%20Database%2C%20RPO%2C%20RTO%2C%20switchover%20y%20failover%20sin%20ejecutar%20un%20failover%20real.)

---

# 🧩 Reto 7. Generar documento técnico de arquitectura

## ⏱️ Tiempo estimado

**6 minutos**

---

## 🎯 Objetivo del reto

Generar el entregable final del curso: un documento técnico que integre estado actual, mediciones, observabilidad, conexión, DR, riesgos y recomendaciones.

---

## 🧠 Escenario

Una arquitectura profesional no se cierra solo con comandos. Debe documentarse con decisiones, evidencia y recomendaciones. Este documento debe poder compartirse con un equipo técnico o de operación.

---

## 🧱 Valores estandarizados del reto

| Entregable | Archivo |
|---|---|
| Script generador | `09_generate_architecture_doc.py` |
| Documento técnico | `09_arquitectura_aurora_final.md` |
| Fuente | Archivos `09_*` generados en retos anteriores |

---

## 🛠️ Tu reto

Genera el archivo `09_arquitectura_aurora_final.md` con resumen ejecutivo, arquitectura actual, optimización, rendimiento, RDS Proxy, observabilidad, DR multi-región, RPO/RTO, riesgos, recomendaciones y próximos pasos.

---

## 💡 Pistas

- Usa evidencia real si existe.
- Si algo no existe, documenta recomendación.
- No inventes métricas.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Generar documento técnico de arquitectura ==="

cat > 09_generate_architecture_doc.py <<'PY'
#!/usr/bin/env python3
from pathlib import Path
from datetime import datetime
import os

base = Path(".").resolve()

def read_text(name: str, default: str = "No disponible"):
    path = base / name
    if path.exists():
        return path.read_text(encoding="utf-8", errors="ignore")
    return default

def extract_summary_metric(text: str):
    lines = []
    for line in text.splitlines():
        if "latency average" in line or "tps =" in line:
            lines.append(line.strip())
    return "\n".join(lines) if lines else "No disponible"

benchmark_direct = extract_summary_metric(read_text("09_benchmark_directo.txt"))
benchmark_proxy = extract_summary_metric(read_text("09_benchmark_proxy.txt"))

proxy_status = "Disponible" if (base / "09_rds_proxy_estado.txt").exists() else "No disponible / recomendado"
global_status = "Disponible" if (base / "09_global_database_estado.txt").exists() else "No disponible / diseño recomendado"

cluster = os.environ.get("AURORA_CLUSTER_ID", "No definido")
endpoint = os.environ.get("AURORA_ENDPOINT", "No definido")
db = os.environ.get("AURORA_DBNAME", "No definido")
writer = os.environ.get("AURORA_WRITER_INSTANCE", "No definido")
primary = os.environ.get("AWS_PRIMARY_REGION", "No definido")
secondary = os.environ.get("AWS_SECONDARY_REGION", "No definido")

doc = f"""# Documento técnico final — Arquitectura Aurora PostgreSQL

## 1. Resumen ejecutivo

Este documento resume la validación final de una arquitectura AWS Aurora PostgreSQL orientada a cargas empresariales de alta concurrencia. La evaluación integra rendimiento, optimización, gestión de conexiones, observabilidad y preparación para recuperación ante desastre.

**Fecha UTC:** {datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")}

---

## 2. Arquitectura evaluada

| Componente | Estado |
|---|---|
| Aurora PostgreSQL Cluster | Validado |
| Cluster ID | {cluster} |
| Writer endpoint | {endpoint} |
| Writer instance | {writer} |
| Base de datos | {db} |
| Región primaria | {primary} |
| Región secundaria | {secondary} |
| Performance Insights | Revisado |
| pg_stat_statements | Revisado |
| RDS Proxy | {proxy_status} |
| Aurora Global Database | {global_status} |
| CloudWatch metrics | Revisado |

---

## 3. Evidencia de rendimiento

### Benchmark directo

```text
{benchmark_direct}
```

### Benchmark vía RDS Proxy

```text
{benchmark_proxy}
```

> Interpretación: estos resultados son una medición corta de laboratorio. No sustituyen una prueba de carga formal con volumen, concurrencia y patrón de aplicación real.

---

## 4. Optimización y configuración

La revisión incluyó parámetros clave, extensiones instaladas, índices existentes, estadísticas de tablas y consultas acumuladas en pg_stat_statements.

Archivos de evidencia:

- `09_revision_parametros.txt`
- `09_revision_extensiones.txt`
- `09_revision_indices.txt`
- `09_revision_estadisticas.txt`
- `09_revision_top_sql.txt`

### Recomendaciones

1. No modificar parameter groups sin hipótesis y medición before/after.
2. Revisar índices con baja o nula utilización.
3. Mantener `pg_stat_statements` habilitado para análisis continuo.
4. Ejecutar `ANALYZE` después de cargas masivas o cambios importantes.
5. Evaluar `work_mem` por sesión para consultas específicas antes de cambios globales.

---

## 5. Gestión de conexiones

RDS Proxy se evaluó como componente de arquitectura para reducir churn de conexiones, proteger Aurora ante picos de clientes, reutilizar conexiones, centralizar autenticación con Secrets Manager y mejorar resiliencia de conexión en ciertos escenarios.

> RDS Proxy no debe presentarse como garantía de mayor TPS. Su valor principal es la administración eficiente de conexiones.

---

## 6. Observabilidad

La arquitectura debe monitorear como mínimo:

| Área | Métrica / herramienta |
|---|---|
| Carga de base de datos | Performance Insights DBLoad / AAS |
| CPU | CPUUtilization / DBLoadCPU |
| Esperas no CPU | DBLoadNonCPU / wait events |
| Conexiones | DatabaseConnections / RDS Proxy metrics |
| Latencia | ReadLatency / WriteLatency |
| SQL costoso | Top SQL / pg_stat_statements |
| Salud operativa | CloudWatch Alarms / Dashboard |

---

## 7. Estrategia DR multi-región

Aurora Global Database: **{global_status}**

| Métrica | Objetivo sugerido |
|---|---|
| RPO | Definir según criticidad y validar con prueba real |
| RTO | Definir según SLA y validar con runbook |
| Prueba DR | Ejecutar periódicamente |
| Runbook | Obligatorio |
| Validación de aplicación | Obligatoria después de switchover/failover |

| Operación | Uso recomendado |
|---|---|
| Switchover | Procedimiento planeado entre regiones sanas |
| Failover | Recuperación ante desastre o evento no planeado |

---

## 8. Riesgos identificados

| Riesgo | Mitigación recomendada |
|---|---|
| Cambios globales sin validación | Usar pruebas before/after |
| Conexiones excesivas | RDS Proxy y pooling de aplicación |
| Falta de visibilidad | Performance Insights + CloudWatch |
| Índices no usados | Revisión periódica de pg_stat_user_indexes |
| DR no probado | Simulacros controlados |
| Dependencia de una sola región | Aurora Global Database si RTO/RPO lo justifica |
| Costos multi-región | Etiquetado, presupuestos y limpieza de laboratorios |

---

## 9. Próximos pasos

1. Ejecutar prueba de carga representativa de aplicación real.
2. Definir SLO/SLA de latencia y disponibilidad.
3. Completar runbook DR.
4. Configurar dashboard CloudWatch final.
5. Crear alarmas para DBLoad, CPU, conexiones y latencia.
6. Validar RDS Proxy con patrón real de conexiones.
7. Evaluar Aurora Global Database en entorno controlado.
8. Programar revisión periódica de índices, vacuum y estadísticas.

---

## 10. Entregables

- Evidencia técnica en archivos `09_*`.
- Dashboard mínimo en JSON.
- Documento de arquitectura final.
- Archivo comprimido de evidencia del laboratorio.
"""

output = base / "09_arquitectura_aurora_final.md"
output.write_text(doc, encoding="utf-8")
print(f"Documento generado: {output}")
PY

chmod +x 09_generate_architecture_doc.py
python3 09_generate_architecture_doc.py

ls -lh 09_arquitectura_aurora_final.md
head -40 09_arquitectura_aurora_final.md
```

</details>

---

## 🔍 Validación

```bash
test -s 09_arquitectura_aurora_final.md && echo "Documento generado correctamente"
```

---

## 📌 Resultado esperado

Debes tener `09_arquitectura_aurora_final.md` con secciones de rendimiento, RDS Proxy, observabilidad, DR, riesgos y recomendaciones.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20generar%20un%20documento%20t%C3%A9cnico%20de%20arquitectura%20Aurora%20PostgreSQL%20que%20incluya%20rendimiento%2C%20observabilidad%2C%20RDS%20Proxy%2C%20DR%20multi-regi%C3%B3n%2C%20riesgos%20y%20recomendaciones.)

---

# 🧩 Reto 8. Validar estado final previo al cierre

## ⏱️ Tiempo estimado

**2 minutos**

---

## 🎯 Objetivo del reto

Confirmar que todos los entregables críticos existen antes de empaquetar evidencia y cerrar el laboratorio.

---

## 🧠 Escenario

Antes de cerrar el laboratorio integrador, debes validar que existe evidencia de arquitectura, benchmark, observabilidad, RDS Proxy o recomendación, DR o diseño objetivo, y documento técnico final.

---

## 🧱 Valores estandarizados del reto

| Elemento | Archivo esperado |
|---|---|
| Arquitectura base | `09_arquitectura_base_cluster.json` |
| Benchmark directo | `09_benchmark_directo_resumen.txt` |
| RDS Proxy o recomendación | `09_rds_proxy_estado.txt` o `09_rds_proxy_recomendacion.md` |
| Observabilidad | `09_cloudwatch_metricas.txt` |
| DR o diseño | `09_global_database_descripcion.json` o `09_diseno_dr_multi_region.md` |
| Documento final | `09_arquitectura_aurora_final.md` |

---

## 🛠️ Tu reto

Realiza validación de archivos críticos, documento final, variables principales y confirmación de que estás listo para empaquetar evidencia.

---

## 💡 Pistas

- Si no existe RDS Proxy, debe existir la recomendación.
- Si no existe Global Database, debe existir el diseño objetivo.
- No cierres el laboratorio sin documento final.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Validar variables principales ==="

echo "Cluster:         $AURORA_CLUSTER_ID"
echo "Writer endpoint: $AURORA_ENDPOINT"
echo "Reader endpoint: $AURORA_READER_ENDPOINT"
echo "Writer instance: $AURORA_WRITER_INSTANCE"
echo "Primary region:  $AWS_PRIMARY_REGION"
echo "Secondary region:$AWS_SECONDARY_REGION"

echo "=== Validar archivos críticos ==="

ls -lh 09_arquitectura_base_cluster.json \
       09_arquitectura_base_instancias.txt \
       09_benchmark_directo_resumen.txt \
       09_cloudwatch_metricas.txt \
       09_arquitectura_aurora_final.md

echo "=== Validar evidencia RDS Proxy o recomendación ==="

ls -lh 09_rds_proxy_estado.txt 09_rds_proxy_recomendacion.md 2>/dev/null || true

echo "=== Validar evidencia DR o diseño objetivo ==="

ls -lh 09_global_database_descripcion.json 09_diseno_dr_multi_region.md 2>/dev/null || true

echo "=== Validar documento final ==="

head -60 09_arquitectura_aurora_final.md
```

</details>

---

## 🔍 Validación

```bash
test -s 09_arquitectura_aurora_final.md && echo "Documento final OK"
ls -lh 09_*
```

---

## 📌 Resultado esperado

Debes tener al menos el documento final, resumen de benchmark, métricas CloudWatch y evidencia de arquitectura.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20validar%20los%20entregables%20finales%20de%20un%20laboratorio%20integrador%20de%20arquitectura%20Aurora%20PostgreSQL%20antes%20de%20cerrar%20la%20pr%C3%A1ctica.)

---

# 🧩 Reto 9. Empaquetar evidencia y limpiar si aplica

## ⏱️ Tiempo estimado

**1 minuto**

---

## 🎯 Objetivo del reto

Comprimir toda la evidencia generada, cerrar el laboratorio y ejecutar limpieza de infraestructura solo si el instructor lo solicita.

---

## 🧠 Escenario

Este laboratorio es integrador y puede ejecutarse sobre recursos compartidos del curso. Por eso no destruye infraestructura por defecto. El objetivo final es conservar evidencia y entregar el documento técnico.

---

## 🧱 Valores estandarizados del reto

| Recurso | Valor estándar | Acción |
|---|---|---|
| Evidencia | `09_*` | Empaquetar |
| Documento técnico | `09_arquitectura_aurora_final.md` | Conservar |
| Paquete evidencia | `09_evidencia_integrador_*.tar.gz` | Crear |
| Script eliminación | `00_eliminar_laboratorio_9_aurora.sh` | Ejecutar solo si se eliminará infraestructura |
| Clúster Aurora | `$AURORA_CLUSTER_ID` | No eliminar salvo instrucción |
| RDS Proxy | `$RDS_PROXY_NAME` | No eliminar salvo instrucción |
| Global DB | `$AURORA_GLOBAL_CLUSTER_ID` | No eliminar salvo instrucción explícita y entorno preparado |

---

## 🛠️ Tu reto

Realiza empaquetado de evidencia, listado de entregables, cierre del laboratorio y limpieza opcional si el instructor lo solicita.

---

## 💡 Pistas

- No ejecutes `terraform destroy`.
- No elimines Global Database.
- No elimines RDS Proxy.
- No elimines el clúster Aurora sin autorización.
- Conserva siempre el paquete de evidencia.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Empaquetar evidencia del laboratorio integrador ==="

tar -czf "09_evidencia_integrador_$(date +%Y%m%d-%H%M%S).tar.gz" 09_* 2>/dev/null || true

echo "=== Entregables generados ==="

find . -maxdepth 1 -type f -name "09_*" | sort | while read file; do
  ls -lh "$file" | awk '{print $5, $9}'
done

echo ""
echo "Laboratorio 9 completado."
echo "Archivo de evidencia:"
ls -lh 09_evidencia_integrador_*.tar.gz

echo ""
echo "=== Limpieza opcional de infraestructura AWS ==="
echo "Si el instructor solicita eliminar todo el ambiente, ejecuta:"
echo ""
echo "chmod +x 00_eliminar_laboratorio_9_aurora.sh"
echo "./00_eliminar_laboratorio_9_aurora.sh"
```

</details>

---

## 🔍 Validación

```bash
ls -lh 09_evidencia_integrador_*.tar.gz
ls -lh 09_arquitectura_aurora_final.md
```

---

## 📌 Resultado esperado

Debes tener:

```text
09_evidencia_integrador_*.tar.gz
09_arquitectura_aurora_final.md
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20cerrar%20un%20laboratorio%20integrador%20de%20Aurora%20PostgreSQL%20conservando%20evidencia%20sin%20destruir%20infraestructura%20compartida.)

---

# ✅ Validación final del laboratorio

Al finalizar la práctica, debes haber completado lo siguiente:

| Elemento | Estado esperado |
|---|---|
| Variables base | Definidas |
| Cluster Aurora | Validado |
| Writer endpoint | Validado |
| Reader endpoint | Validado |
| Writer instance | Identificada |
| Instance ARN | Identificado |
| DbiResourceId | Identificado |
| Parámetros clave | Revisados |
| Extensiones | Revisadas |
| Índices | Revisados |
| Estadísticas | Revisadas |
| Benchmark directo | Ejecutado |
| RDS Proxy | Validado o documentado como recomendado |
| Performance Insights | Validado |
| CloudWatch metrics | Consultadas |
| Dashboard mínimo | Generado como JSON |
| DR multi-región | Validado o documentado |
| Documento técnico | Generado |
| Estado final previo al cierre | Validado |
| Evidencia | Empaquetada |
| Limpieza de infraestructura | Ejecutada solo si el instructor la solicitó |

---

# 🧠 Resultado esperado de aprendizaje

Después de completar este laboratorio, debes poder explicar y defender una arquitectura Aurora PostgreSQL avanzada desde una perspectiva profesional:

1. Validar arquitectura base de Aurora.
2. Revisar estado de optimización sin aplicar cambios riesgosos.
3. Ejecutar una medición corta de rendimiento.
4. Interpretar RDS Proxy como capa de gestión de conexiones.
5. Revisar DBLoad/AAS y métricas CloudWatch.
6. Evaluar preparación para DR multi-región.
7. Diferenciar switchover de failover.
8. Definir RPO/RTO.
9. Documentar riesgos y recomendaciones.
10. Generar un entregable técnico de arquitectura.
11. Empaquetar evidencia y cerrar una práctica integradora.

---

# 📌 Resumen del laboratorio

En este laboratorio integrador validaste una arquitectura Aurora PostgreSQL desde el punto de vista de rendimiento, conexión, observabilidad y recuperación ante desastre. Primero preparaste variables y documentaste el estado base del clúster. Después revisaste parámetros, extensiones, índices, estadísticas y Top SQL. Ejecutaste un benchmark corto para obtener evidencia de rendimiento, validaste RDS Proxy si estaba disponible, revisaste Performance Insights y CloudWatch, evaluaste la existencia o diseño de Aurora Global Database y generaste un documento técnico final de arquitectura. Finalmente validaste los entregables, empaquetaste evidencia y dejaste la limpieza de infraestructura como una acción controlada del instructor. La práctica refuerza el enfoque profesional de cierre: no basta con ejecutar comandos; debes medir, evaluar, documentar y justificar decisiones técnicas.
