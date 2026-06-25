<h1 align="center">🏁 Laboratorio 9. Arquitectura Aurora: optimización, observabilidad y DR</h1>

---

## 1. 🧾 Información general de la práctica

## 📘 Descripción general

En este laboratorio final vas a validar y documentar una arquitectura avanzada de **AWS Aurora PostgreSQL** para un escenario empresarial de alta concurrencia. Revisarás la configuración base del clúster, validarás optimizaciones aplicadas en prácticas anteriores, ejecutarás una medición corta de rendimiento, revisarás el estado de **RDS Proxy**, consultarás métricas de **Performance Insights** y **CloudWatch**, evaluarás la preparación para **Disaster Recovery multi-región** y generarás un documento técnico final de arquitectura.

Este laboratorio integra validación, medición, observabilidad y creación controlada de un ejemplo simple de recuperación ante desastre multi-región:

> **Validar → Medir → Observar → Crear → Replicar → Documentar → Cerrar**

La práctica está diseñada para completarse en **45 minutos de trabajo guiado**, aunque la creación real de recursos de **Aurora Global Database** puede requerir esperas adicionales de AWS. En esta versión, el reto de Aurora Global Database no será únicamente demostrativo: crearás o reutilizarás un Global Database simple, agregarás una región secundaria y validarás replicación básica con una tabla de prueba.

La práctica está diseñada como una serie de **retos guiados**. En cada reto primero intentarás resolver el objetivo con pistas. Si te bloqueas, podrás abrir la **solución sugerida**. La solución está oculta para fomentar el razonamiento, pero es completa y funcional para no extender el tiempo del laboratorio.

> ⚠️ **Importante:** Esta práctica crea recursos multi-región si ejecutas el Reto 6. No ejecutes switchover/failover real como paso obligatorio. Esos procedimientos solo deben ejecutarse con autorización del instructor y en un entorno preparado para pruebas de DR.

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
- Crear un ejemplo simple real de Aurora Global Database.
- Validar replicación básica hacia una región secundaria y diferenciar switchover/failover.
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
- Permisos para crear Aurora Global Database y recursos mínimos en la región secundaria si se ejecuta el Reto 6.
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
| DBLoad waits | `09_pi_dbload.json / 09_pi_top_waits.json / 09_pi_top_sql.json` | PI API por waits |
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
| Reto 6 | Creación de Aurora Global Database | 7 min + espera AWS |
| Reto 7 | Generar documento técnico de arquitectura | 6 min |
| Reto 8 | Validar estado final previo al cierre | 2 min |
| Reto 9 | Empaquetar evidencia y limpiar si aplica | 1 min |
| **Total** |  | **45 min + espera AWS** |

> 💡 **Nota operativa:** Este laboratorio es integrador. RDS Proxy puede validarse si existe o documentarse como recomendación. Aurora Global Database se trabaja con un ejemplo real simple en el Reto 6; su creación puede tardar más que el tiempo pedagógico estimado.

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
  relname AS tablename,
  indexrelname AS indexname,
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
| DBLoad por waits | `09_pi_dbload.json / 09_pi_top_waits.json / 09_pi_top_sql.json` |
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

export AURORA_DBI_RESOURCE_ID=$(aws rds describe-db-instances \
  --db-instance-identifier "$AURORA_WRITER_INSTANCE" \
  --region "$AWS_PRIMARY_REGION" \
  --query "DBInstances[0].DbiResourceId" \
  --output text)

echo "DbiResourceId usado por Performance Insights API: $AURORA_DBI_RESOURCE_ID"

aws pi get-resource-metrics \
  --service-type RDS \
  --identifier "$AURORA_DBI_RESOURCE_ID" \
  --metric-queries '[{"Metric":"db.load.avg"}]' \
  --start-time "$PI_START_TIME" \
  --end-time "$PI_END_TIME" \
  --period-in-seconds 60 \
  --region "$AWS_PRIMARY_REGION" \
  --output json \
  | tee 09_pi_dbload.json >/dev/null || true

echo "=== Consultar Top wait events con PI API ==="

aws pi describe-dimension-keys \
  --service-type RDS \
  --identifier "$AURORA_DBI_RESOURCE_ID" \
  --start-time "$PI_START_TIME" \
  --end-time "$PI_END_TIME" \
  --metric "db.load.avg" \
  --group-by '{"Group":"db.wait_event","Limit":10}' \
  --period-in-seconds 300 \
  --region "$AWS_PRIMARY_REGION" \
  --output json \
  | tee 09_pi_top_waits.json >/dev/null || true

echo "=== Consultar Top SQL con PI API ==="

aws pi describe-dimension-keys \
  --service-type RDS \
  --identifier "$AURORA_DBI_RESOURCE_ID" \
  --start-time "$PI_START_TIME" \
  --end-time "$PI_END_TIME" \
  --metric "db.load.avg" \
  --group-by '{"Group":"db.sql_tokenized","Limit":10}' \
  --period-in-seconds 300 \
  --region "$AWS_PRIMARY_REGION" \
  --output json \
  | tee 09_pi_top_sql.json >/dev/null || true

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
       09_pi_dbload.json / 09_pi_top_waits.json / 09_pi_top_sql.json \
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

# 🧩 Reto 6. Creación de Aurora Global Database

## ⏱️ Tiempo estimado

**7 minutos + espera AWS**

---

## 🎯 Objetivo del reto

Crear un ejemplo simple real de **Aurora Global Database** usando el clúster Aurora existente como primario y una región secundaria como destino de lectura/DR.

---

## 🧠 Escenario

El equipo necesita validar que la arquitectura puede extenderse a una estrategia multi-región. En este reto no harás failover ni switchover; crearás una Global Database básica, agregarás una región secundaria, crearás una instancia reader secundaria y validarás replicación con una tabla simple.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor |
|---|---|
| Global DB | `$AURORA_GLOBAL_CLUSTER_ID` o `aurora-lab-global` |
| Cluster primario | `$AURORA_CLUSTER_ID` |
| Cluster secundario | `$AURORA_SECONDARY_CLUSTER_ID` |
| Instancia secundaria | `$AURORA_SECONDARY_INSTANCE_ID` |
| Región primaria | `$AWS_PRIMARY_REGION` |
| Región secundaria | `$AWS_SECONDARY_REGION` |
| Security Group secundario | `$GLOBAL_SECONDARY_SG_ID` |
| DB Subnet Group secundario | `$GLOBAL_SECONDARY_DB_SUBNET_GROUP` |
| Evidencia Global DB | `09_global_database_descripcion.json` |
| Evidencia secundaria | `09_global_database_secondary_cluster.json` |
| Validación SQL secundaria | `09_globaldb_secondary_validation.txt` |
| Runbook DR | `09_diseno_dr_multi_region.md` |
| Variables ejemplo | `09_globaldb_example_env.sh` |

---

## 🛠️ Tu reto

Crea o reutiliza:

- Aurora Global Database.
- Red mínima en región secundaria.
- Security Group temporal en región secundaria.
- DB Subnet Group secundario.
- Clúster secundario ligado al Global Database.
- Instancia secundaria reader.
- Tabla de prueba en región primaria.
- Validación de replicación en región secundaria.
- Documento de diseño/runbook DR.

---

## 💡 Pistas

- No ejecutes failover.
- No ejecutes switchover.
- El clúster secundario es de lectura.
- El clúster primario conserva escrituras.
- Usa la misma versión de motor que el clúster primario.
- La creación real puede tardar varios minutos.
- Si el clúster ya pertenece a un Global Database, reutiliza el existente.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Reto 6: Crear ejemplo simple real de Aurora Global Database ==="

set -euo pipefail

if [ -f ./lab9_aurora_env.sh ]; then
  source ./lab9_aurora_env.sh
else
  echo "ERROR: No existe ./lab9_aurora_env.sh"
  echo "Ejecuta primero el script de preparación del Laboratorio 9."
  exit 1
fi

export AWS_PRIMARY_REGION="${AWS_PRIMARY_REGION:-${AWS_REGION:-us-west-2}}"
export AWS_SECONDARY_REGION="${AWS_SECONDARY_REGION:-us-east-1}"

export AURORA_GLOBAL_CLUSTER_ID="${AURORA_GLOBAL_CLUSTER_ID:-aurora-lab-global}"
export AURORA_SECONDARY_CLUSTER_ID="${AURORA_SECONDARY_CLUSTER_ID:-aurora-lab-cluster-secondary}"
export AURORA_SECONDARY_INSTANCE_ID="${AURORA_SECONDARY_INSTANCE_ID:-aurora-lab-secondary-instance-1}"

export GLOBAL_SECONDARY_DB_SUBNET_GROUP="${GLOBAL_SECONDARY_DB_SUBNET_GROUP:-aurora-lab-global-secondary-subnet-group}"
export GLOBAL_SECONDARY_SG_NAME="${GLOBAL_SECONDARY_SG_NAME:-aurora-lab-global-secondary-sg}"

export AURORA_PORT="${AURORA_PORT:-5432}"
export AURORA_INSTANCE_CLASS="${AURORA_INSTANCE_CLASS:-db.r6g.large}"

echo "Región primaria:    $AWS_PRIMARY_REGION"
echo "Región secundaria:  $AWS_SECONDARY_REGION"
echo "Global DB:          $AURORA_GLOBAL_CLUSTER_ID"
echo "Cluster primario:   $AURORA_CLUSTER_ID"
echo "Cluster secundario: $AURORA_SECONDARY_CLUSTER_ID"
echo "Instancia secundaria: $AURORA_SECONDARY_INSTANCE_ID"

echo "=== Validar variables requeridas ==="

: "${AURORA_CLUSTER_ID:?Falta AURORA_CLUSTER_ID}"
: "${AURORA_ENDPOINT:?Falta AURORA_ENDPOINT}"
: "${AURORA_DBNAME:?Falta AURORA_DBNAME}"
: "${AURORA_MASTER_USER:?Falta AURORA_MASTER_USER}"
: "${AURORA_MASTER_PASSWORD:?Falta AURORA_MASTER_PASSWORD}"

echo "=== Obtener datos del clúster primario ==="

export PRIMARY_CLUSTER_ARN=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_PRIMARY_REGION" \
  --query "DBClusters[0].DBClusterArn" \
  --output text)

export AURORA_ENGINE=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_PRIMARY_REGION" \
  --query "DBClusters[0].Engine" \
  --output text)

export AURORA_ENGINE_VERSION=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_PRIMARY_REGION" \
  --query "DBClusters[0].EngineVersion" \
  --output text)

export PRIMARY_GLOBAL_CLUSTER=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_PRIMARY_REGION" \
  --query "DBClusters[0].GlobalClusterIdentifier" \
  --output text 2>/dev/null || echo "None")

echo "Primary ARN:        $PRIMARY_CLUSTER_ARN"
echo "Engine:             $AURORA_ENGINE"
echo "Engine version:     $AURORA_ENGINE_VERSION"
echo "Global actual:      $PRIMARY_GLOBAL_CLUSTER"

echo "=== Crear o reutilizar Aurora Global Database ==="

if [ "$PRIMARY_GLOBAL_CLUSTER" != "None" ] && [ -n "$PRIMARY_GLOBAL_CLUSTER" ]; then
  echo "El clúster primario ya pertenece a Global Database: $PRIMARY_GLOBAL_CLUSTER"
  export AURORA_GLOBAL_CLUSTER_ID="$PRIMARY_GLOBAL_CLUSTER"
else
  if aws rds describe-global-clusters \
    --global-cluster-identifier "$AURORA_GLOBAL_CLUSTER_ID" \
    --region "$AWS_PRIMARY_REGION" >/dev/null 2>&1; then

    echo "Global Database ya existe: $AURORA_GLOBAL_CLUSTER_ID"

  else

    echo "Creando Global Database a partir del clúster primario existente..."

    aws rds create-global-cluster \
      --global-cluster-identifier "$AURORA_GLOBAL_CLUSTER_ID" \
      --source-db-cluster-identifier "$PRIMARY_CLUSTER_ARN" \
      --region "$AWS_PRIMARY_REGION" \
      --output json \
      | tee 09_global_database_create.json >/dev/null

    echo "Global Database creado."
  fi
fi

echo "=== Preparar red mínima pública en región secundaria ==="

export SECONDARY_VPC_ID=$(aws ec2 describe-vpcs \
  --region "$AWS_SECONDARY_REGION" \
  --filters "Name=is-default,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text 2>/dev/null || echo "None")

if [ -z "$SECONDARY_VPC_ID" ] || [ "$SECONDARY_VPC_ID" = "None" ]; then
  echo "No existe VPC default en región secundaria. Creando VPC default..."
  export SECONDARY_VPC_ID=$(aws ec2 create-default-vpc \
    --region "$AWS_SECONDARY_REGION" \
    --query "Vpc.VpcId" \
    --output text)
fi

echo "VPC secundaria: $SECONDARY_VPC_ID"

echo "=== Validar Internet Gateway en VPC secundaria ==="

export SECONDARY_IGW_ID=$(aws ec2 describe-internet-gateways \
  --region "$AWS_SECONDARY_REGION" \
  --filters "Name=attachment.vpc-id,Values=$SECONDARY_VPC_ID" \
  --query "InternetGateways[0].InternetGatewayId" \
  --output text 2>/dev/null || echo "None")

if [ -z "$SECONDARY_IGW_ID" ] || [ "$SECONDARY_IGW_ID" = "None" ]; then
  echo "No existe Internet Gateway asociado. Creando Internet Gateway..."

  export SECONDARY_IGW_ID=$(aws ec2 create-internet-gateway \
    --region "$AWS_SECONDARY_REGION" \
    --query "InternetGateway.InternetGatewayId" \
    --output text)

  aws ec2 create-tags \
    --region "$AWS_SECONDARY_REGION" \
    --resources "$SECONDARY_IGW_ID" \
    --tags Key=Lab,Value=09 Key=Name,Value=aurora-lab-global-secondary-igw >/dev/null

  aws ec2 attach-internet-gateway \
    --region "$AWS_SECONDARY_REGION" \
    --internet-gateway-id "$SECONDARY_IGW_ID" \
    --vpc-id "$SECONDARY_VPC_ID" || true
fi

echo "Internet Gateway secundario: $SECONDARY_IGW_ID"

echo "=== Validar o crear subnets default en al menos dos AZs ==="

for AZ in $(aws ec2 describe-availability-zones \
  --region "$AWS_SECONDARY_REGION" \
  --query "AvailabilityZones[?State=='available'].ZoneName" \
  --output text | awk '{print $1, $2}'); do

  EXISTING_SUBNET=$(aws ec2 describe-subnets \
    --region "$AWS_SECONDARY_REGION" \
    --filters "Name=vpc-id,Values=$SECONDARY_VPC_ID" "Name=availability-zone,Values=$AZ" \
    --query "Subnets[0].SubnetId" \
    --output text 2>/dev/null || echo "None")

  if [ -z "$EXISTING_SUBNET" ] || [ "$EXISTING_SUBNET" = "None" ]; then
    echo "Creando subnet default en $AZ..."
    aws ec2 create-default-subnet \
      --availability-zone "$AZ" \
      --region "$AWS_SECONDARY_REGION" >/dev/null || true
  fi
done

export SECONDARY_SUBNET_IDS=$(aws ec2 describe-subnets \
  --region "$AWS_SECONDARY_REGION" \
  --filters "Name=vpc-id,Values=$SECONDARY_VPC_ID" \
  --query "Subnets[0:2].SubnetId" \
  --output text)

if [ "$(echo "$SECONDARY_SUBNET_IDS" | wc -w)" -lt 2 ]; then
  echo "ERROR: Se requieren al menos dos subnets en región secundaria."
  exit 1
fi

echo "Subnets secundarias: $SECONDARY_SUBNET_IDS"

echo "=== Habilitar auto-assign public IPv4 en subnets secundarias ==="

for SUBNET_ID in $SECONDARY_SUBNET_IDS; do
  aws ec2 modify-subnet-attribute \
    --region "$AWS_SECONDARY_REGION" \
    --subnet-id "$SUBNET_ID" \
    --map-public-ip-on-launch

  echo "Subnet pública validada: $SUBNET_ID"
done

echo "=== Validar ruta pública 0.0.0.0/0 hacia Internet Gateway ==="

export SECONDARY_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
  --region "$AWS_SECONDARY_REGION" \
  --filters "Name=vpc-id,Values=$SECONDARY_VPC_ID" "Name=association.main,Values=true" \
  --query "RouteTables[0].RouteTableId" \
  --output text 2>/dev/null || echo "None")

if [ -z "$SECONDARY_ROUTE_TABLE_ID" ] || [ "$SECONDARY_ROUTE_TABLE_ID" = "None" ]; then
  export SECONDARY_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
    --region "$AWS_SECONDARY_REGION" \
    --filters "Name=vpc-id,Values=$SECONDARY_VPC_ID" \
    --query "RouteTables[0].RouteTableId" \
    --output text)
fi

echo "Route table secundaria: $SECONDARY_ROUTE_TABLE_ID"

aws ec2 create-route \
  --region "$AWS_SECONDARY_REGION" \
  --route-table-id "$SECONDARY_ROUTE_TABLE_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$SECONDARY_IGW_ID" >/dev/null 2>&1 \
  || echo "La ruta pública ya existe o no requiere cambios."

echo "=== Crear o reutilizar Security Group secundario ==="

export GLOBAL_SECONDARY_SG_ID=$(aws ec2 describe-security-groups \
  --region "$AWS_SECONDARY_REGION" \
  --filters "Name=vpc-id,Values=$SECONDARY_VPC_ID" "Name=group-name,Values=$GLOBAL_SECONDARY_SG_NAME" \
  --query "SecurityGroups[0].GroupId" \
  --output text 2>/dev/null || echo "None")

if [ -z "$GLOBAL_SECONDARY_SG_ID" ] || [ "$GLOBAL_SECONDARY_SG_ID" = "None" ]; then
  export GLOBAL_SECONDARY_SG_ID=$(aws ec2 create-security-group \
    --region "$AWS_SECONDARY_REGION" \
    --group-name "$GLOBAL_SECONDARY_SG_NAME" \
    --description "Temporal SG Aurora Global DB Lab 9 secondary region" \
    --vpc-id "$SECONDARY_VPC_ID" \
    --query "GroupId" \
    --output text)

  aws ec2 create-tags \
    --region "$AWS_SECONDARY_REGION" \
    --resources "$GLOBAL_SECONDARY_SG_ID" \
    --tags Key=Lab,Value=09 Key=Name,Value="$GLOBAL_SECONDARY_SG_NAME" >/dev/null
fi

aws ec2 authorize-security-group-ingress \
  --region "$AWS_SECONDARY_REGION" \
  --group-id "$GLOBAL_SECONDARY_SG_ID" \
  --protocol tcp \
  --port "$AURORA_PORT" \
  --cidr 0.0.0.0/0 >/dev/null 2>&1 \
  || echo "Regla TCP/$AURORA_PORT ya existe en Security Group secundario."

echo "Security Group secundario: $GLOBAL_SECONDARY_SG_ID"

echo "=== Crear o reutilizar DB Subnet Group secundario ==="

if aws rds describe-db-subnet-groups \
  --db-subnet-group-name "$GLOBAL_SECONDARY_DB_SUBNET_GROUP" \
  --region "$AWS_SECONDARY_REGION" >/dev/null 2>&1; then

  echo "DB Subnet Group secundario existente: $GLOBAL_SECONDARY_DB_SUBNET_GROUP"

else

  aws rds create-db-subnet-group \
    --db-subnet-group-name "$GLOBAL_SECONDARY_DB_SUBNET_GROUP" \
    --db-subnet-group-description "Subnet group for Aurora Global DB Lab 9 secondary cluster" \
    --subnet-ids $SECONDARY_SUBNET_IDS \
    --region "$AWS_SECONDARY_REGION" \
    --tags Key=Lab,Value=09 Key=Component,Value=AuroraGlobalDB >/dev/null

  echo "DB Subnet Group secundario creado: $GLOBAL_SECONDARY_DB_SUBNET_GROUP"
fi

echo "=== Crear o reutilizar clúster secundario ligado al Global Database ==="

if aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_SECONDARY_CLUSTER_ID" \
  --region "$AWS_SECONDARY_REGION" >/dev/null 2>&1; then

  echo "Clúster secundario ya existe: $AURORA_SECONDARY_CLUSTER_ID"

else

  set +e

  aws rds create-db-cluster \
    --db-cluster-identifier "$AURORA_SECONDARY_CLUSTER_ID" \
    --engine "$AURORA_ENGINE" \
    --engine-version "$AURORA_ENGINE_VERSION" \
    --global-cluster-identifier "$AURORA_GLOBAL_CLUSTER_ID" \
    --db-subnet-group-name "$GLOBAL_SECONDARY_DB_SUBNET_GROUP" \
    --vpc-security-group-ids "$GLOBAL_SECONDARY_SG_ID" \
    --region "$AWS_SECONDARY_REGION" \
    --tags Key=Lab,Value=09 Key=Component,Value=AuroraGlobalDBSecondary \
    --output json \
    2>&1 | tee 09_secondary_cluster_create.json

  CREATE_CLUSTER_RC=${PIPESTATUS[0]}
  set -e

  if [ "$CREATE_CLUSTER_RC" -ne 0 ]; then
    echo "ERROR: No se pudo crear el clúster secundario."
    echo "Revisa 09_secondary_cluster_create.json"
    exit "$CREATE_CLUSTER_RC"
  fi

  echo "Clúster secundario solicitado."
fi

echo "=== Esperar clúster secundario disponible antes de crear instancia ==="

aws rds wait db-cluster-available \
  --db-cluster-identifier "$AURORA_SECONDARY_CLUSTER_ID" \
  --region "$AWS_SECONDARY_REGION"

echo "=== Crear o reutilizar instancia reader secundaria ==="

if aws rds describe-db-instances \
  --db-instance-identifier "$AURORA_SECONDARY_INSTANCE_ID" \
  --region "$AWS_SECONDARY_REGION" >/dev/null 2>&1; then

  echo "Instancia secundaria ya existe: $AURORA_SECONDARY_INSTANCE_ID"

else

  set +e

  aws rds create-db-instance \
    --db-instance-identifier "$AURORA_SECONDARY_INSTANCE_ID" \
    --db-cluster-identifier "$AURORA_SECONDARY_CLUSTER_ID" \
    --engine "$AURORA_ENGINE" \
    --db-instance-class "${AURORA_INSTANCE_CLASS:-db.r6g.large}" \
    --publicly-accessible \
    --region "$AWS_SECONDARY_REGION" \
    --tags Key=Lab,Value=09 Key=Component,Value=AuroraGlobalDBSecondaryInstance \
    --output json \
    2>&1 | tee 09_secondary_instance_create.json

  CREATE_INSTANCE_RC=${PIPESTATUS[0]}
  set -e

  if [ "$CREATE_INSTANCE_RC" -ne 0 ]; then
    echo "ERROR: No se pudo crear la instancia secundaria."
    echo "Revisa 09_secondary_instance_create.json"
    exit "$CREATE_INSTANCE_RC"
  fi

  echo "Instancia secundaria solicitada."
fi

echo "=== Esperar instancia y clúster secundario disponibles ==="

aws rds wait db-instance-available \
  --db-instance-identifier "$AURORA_SECONDARY_INSTANCE_ID" \
  --region "$AWS_SECONDARY_REGION"

aws rds wait db-cluster-available \
  --db-cluster-identifier "$AURORA_SECONDARY_CLUSTER_ID" \
  --region "$AWS_SECONDARY_REGION"

echo "=== Guardar evidencia de Global Database ==="

aws rds describe-global-clusters \
  --global-cluster-identifier "$AURORA_GLOBAL_CLUSTER_ID" \
  --region "$AWS_PRIMARY_REGION" \
  --query "GlobalClusters[0].{GlobalCluster:GlobalClusterIdentifier,Estado:Status,Engine:Engine,EngineVersion:EngineVersion,Members:GlobalClusterMembers}" \
  --output json \
  | tee 09_global_database_descripcion.json >/dev/null

aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_SECONDARY_CLUSTER_ID" \
  --region "$AWS_SECONDARY_REGION" \
  --query "DBClusters[0].{Cluster:DBClusterIdentifier,Estado:Status,Endpoint:Endpoint,ReaderEndpoint:ReaderEndpoint,GlobalCluster:GlobalClusterIdentifier,Members:DBClusterMembers}" \
  --output json \
  | tee 09_global_database_secondary_cluster.json >/dev/null

export AURORA_SECONDARY_ENDPOINT=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_SECONDARY_CLUSTER_ID" \
  --region "$AWS_SECONDARY_REGION" \
  --query "DBClusters[0].Endpoint" \
  --output text)

echo "Endpoint secundario: $AURORA_SECONDARY_ENDPOINT"

echo "=== Crear dato simple en primaria para validar replicación ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require connect_timeout=10" <<'SQL' \
  | tee 09_globaldb_primary_write.txt

CREATE SCHEMA IF NOT EXISTS lab_globaldb;

CREATE TABLE IF NOT EXISTS lab_globaldb.replication_test (
    id INTEGER PRIMARY KEY,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO lab_globaldb.replication_test (id, message)
VALUES (1, 'replicacion aurora global database lab 9')
ON CONFLICT (id)
DO UPDATE SET message = EXCLUDED.message,
              created_at = now();

SELECT id, message, created_at
FROM lab_globaldb.replication_test;

SQL

echo "=== Validar lectura en región secundaria ==="

for i in $(seq 1 30); do

  if psql "host=$AURORA_SECONDARY_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require connect_timeout=10" \
    -c "SELECT pg_is_in_recovery() AS es_replica, id, message, created_at FROM lab_globaldb.replication_test WHERE id = 1;" \
    2>&1 | tee 09_globaldb_secondary_validation.txt; then

    if grep -q "replicacion aurora global database lab 9" 09_globaldb_secondary_validation.txt; then
      echo "Replicación validada en región secundaria."
      break
    fi
  fi

  echo "Intento $i/30: esperando replicación visible en región secundaria..."
  sleep 20

  if [ "$i" -eq 30 ]; then
    echo "ERROR: No se pudo validar la replicación en el tiempo esperado."
    exit 1
  fi
done

echo "=== Consultar lag de replicación CloudWatch si hay datos ==="

export CW_END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
export CW_START_TIME=$(date -u -d '30 minutes ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

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

echo "=== Persistir variables del ejemplo Global DB ==="

cat > 09_globaldb_example_env.sh <<EOF
export AURORA_GLOBAL_CLUSTER_ID='$AURORA_GLOBAL_CLUSTER_ID'
export AURORA_SECONDARY_CLUSTER_ID='$AURORA_SECONDARY_CLUSTER_ID'
export AURORA_SECONDARY_INSTANCE_ID='$AURORA_SECONDARY_INSTANCE_ID'
export AURORA_SECONDARY_ENDPOINT='$AURORA_SECONDARY_ENDPOINT'
export GLOBAL_SECONDARY_DB_SUBNET_GROUP='$GLOBAL_SECONDARY_DB_SUBNET_GROUP'
export GLOBAL_SECONDARY_SG_ID='$GLOBAL_SECONDARY_SG_ID'
export SECONDARY_VPC_ID='$SECONDARY_VPC_ID'
export SECONDARY_IGW_ID='$SECONDARY_IGW_ID'
export SECONDARY_ROUTE_TABLE_ID='$SECONDARY_ROUTE_TABLE_ID'
export SECONDARY_SUBNET_IDS='$SECONDARY_SUBNET_IDS'
export AWS_PRIMARY_REGION='$AWS_PRIMARY_REGION'
export AWS_SECONDARY_REGION='$AWS_SECONDARY_REGION'
export PRIMARY_CLUSTER_ARN='$PRIMARY_CLUSTER_ARN'
EOF

chmod 600 09_globaldb_example_env.sh

echo "=== Crear diseño y runbook DR ==="

cat > 09_diseno_dr_multi_region.md <<DOC
# Diseño DR multi-región — Aurora Global Database

## Estado

Se creó o reutilizó un ejemplo simple de Aurora Global Database para el laboratorio.

| Elemento | Valor |
|---|---|
| Global Database | $AURORA_GLOBAL_CLUSTER_ID |
| Región primaria | $AWS_PRIMARY_REGION |
| Cluster primario | $AURORA_CLUSTER_ID |
| Región secundaria | $AWS_SECONDARY_REGION |
| Cluster secundario | $AURORA_SECONDARY_CLUSTER_ID |
| Instancia secundaria | $AURORA_SECONDARY_INSTANCE_ID |
| Endpoint secundario | $AURORA_SECONDARY_ENDPOINT |

## Validación realizada

Se creó una tabla simple en la región primaria:

\`lab_globaldb.replication_test\`

y se validó su lectura desde la región secundaria.

## RPO/RTO sugeridos

| Métrica | Objetivo de laboratorio |
|---|---|
| RPO | Validar con métrica AuroraGlobalDBReplicationLag |
| RTO | Documentar procedimiento, no ejecutar failover automático |
| Prueba DR | Controlada y autorizada |
| Runbook | Requerido antes de producción |

## Switchover vs Failover

| Operación | Uso recomendado |
|---|---|
| Switchover | Cambio planeado entre regiones sanas |
| Failover | Recuperación ante desastre o pérdida de región primaria |

## Riesgos

- Propagación de DNS.
- Reconexión de aplicaciones.
- Secretos en región secundaria.
- Seguridad y rutas de red.
- Costos multi-región.
- Validación de escritura después de recuperación.
- Procedimiento de retorno a región primaria.
DOC

echo "=== Reto 6 completado ==="
ls -lh 09_global_database_descripcion.json \
       09_global_database_secondary_cluster.json \
       09_globaldb_secondary_validation.txt \
       09_diseno_dr_multi_region.md \
       09_globaldb_example_env.sh
```

</details>

---

## 🔍 Validación

```bash
ls -lh 09_global_database_descripcion.json \
       09_global_database_secondary_cluster.json \
       09_globaldb_secondary_validation.txt \
       09_diseno_dr_multi_region.md

grep -E "replicacion aurora global database lab 9|es_replica" 09_globaldb_secondary_validation.txt
```

---

## 📌 Resultado esperado

Debes ver evidencia de Global Database y validación desde el clúster secundario. En la lectura secundaria, `pg_is_in_recovery()` debe devolver normalmente:

```text
t
```

porque el clúster secundario opera como reader.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20crear%20un%20ejemplo%20simple%20de%20Aurora%20Global%20Database%20con%20un%20cluster%20primario%20existente%20y%20un%20cluster%20secundario%20en%20otra%20regi%C3%B3n.)

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

````bash
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
````

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

### Ejecutar script de eliminación de infraestructura

Si el instructor solicita eliminar también el clúster Aurora y los recursos AWS creados para esta práctica, ejecuta el script de eliminación desde AWS CloudShell:

```bash
chmod +x 00_eliminar_laboratorio_9_aurora.sh
./00_eliminar_laboratorio_9_aurora.sh
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
| Performance Insights | Validado con DbiResourceId |
| CloudWatch metrics | Consultadas |
| Dashboard mínimo | Generado como JSON |
| Aurora Global Database | Creado o reutilizado |
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

En este laboratorio integrador validaste una arquitectura Aurora PostgreSQL desde el punto de vista de rendimiento, conexión, observabilidad y recuperación ante desastre. Primero preparaste variables y documentaste el estado base del clúster. Después revisaste parámetros, extensiones, índices, estadísticas y Top SQL. Ejecutaste un benchmark corto para obtener evidencia de rendimiento, validaste RDS Proxy si estaba disponible, revisaste Performance Insights y CloudWatch, creaste o reutilizaste un ejemplo simple real de Aurora Global Database y generaste un documento técnico final de arquitectura. Finalmente validaste los entregables, empaquetaste evidencia y dejaste la limpieza de infraestructura como una acción controlada del instructor. La práctica refuerza el enfoque profesional de cierre: no basta con ejecutar comandos; debes medir, evaluar, documentar y justificar decisiones técnicas.
