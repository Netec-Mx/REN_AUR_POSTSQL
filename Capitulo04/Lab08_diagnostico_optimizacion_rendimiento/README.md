<h1 align="center">🧠 Laboratorio 8. Diagnóstico y optimización de consultas</h1>

---

## 1. 🧾 Información general de la práctica

## 📘 Descripción general

En este laboratorio vas a diagnosticar y optimizar consultas problemáticas en **AWS Aurora PostgreSQL** usando un flujo profesional de rendimiento:

> **Identificar → Diagnosticar → Optimizar → Validar → Documentar**

Crearás un esquema de laboratorio con datos controlados, ejecutarás consultas intencionalmente problemáticas, capturarás métricas con `pg_stat_statements`, analizarás planes reales con `EXPLAIN (ANALYZE, BUFFERS)`, aplicarás optimizaciones focalizadas mediante índices, estadísticas y `work_mem` de sesión, y finalmente validarás mejoras **before/after** con evidencia cuantitativa.

Performance Insights puede utilizarse como apoyo visual, pero la validación principal de esta práctica se hará desde PostgreSQL con:

- `pg_stat_statements`
- `EXPLAIN (ANALYZE, BUFFERS)`
- `pg_stat_user_indexes`
- `pg_stat_user_tables`
- reporte técnico de optimización

La práctica está diseñada como una serie de **retos guiados**. En cada reto primero intentarás resolver el objetivo con pistas. Si te bloqueas, podrás abrir la **solución sugerida**. La solución está oculta para fomentar el razonamiento, pero es completa y funcional para no extender el tiempo del laboratorio.

Esta versión no depende de Terraform, no usa repositorios externos, no crea tablas de millones de filas y no modifica parameter groups persistentes.

---

## 🎯 Objetivos de aprendizaje

Al finalizar este laboratorio, podrás:

- Usar AWS CloudShell para conectarte a un clúster Aurora PostgreSQL.
- Validar conexión al writer endpoint con `pg_is_in_recovery()`.
- Validar que `pg_stat_statements` está disponible.
- Crear un escenario controlado de diagnóstico con tablas y datos moderados.
- Identificar consultas de alto impacto con `pg_stat_statements`.
- Distinguir entre consultas costosas por tiempo total y consultas costosas por latencia promedio.
- Analizar planes reales con `EXPLAIN (ANALYZE, BUFFERS)`.
- Detectar `Seq Scan` costoso, lecturas elevadas y operaciones con temporales.
- Crear índices adecuados para consultas filtradas y joins frecuentes.
- Actualizar estadísticas con `ANALYZE` y `ALTER COLUMN ... SET STATISTICS`.
- Ajustar `work_mem` a nivel sesión para reducir spills a disco.
- Validar mejoras before/after con métricas cuantitativas.
- Generar un reporte técnico de optimización.
- Validar estado final previo a limpieza.
- Limpiar recursos temporales sin afectar el clúster Aurora.
- Ejecutar limpieza completa de infraestructura si el instructor lo solicita.

---

## ✅ Prerrequisitos

Antes de iniciar, debes contar con:

- Ejecutar antes de comenzar el script `00_preparar_laboratorio_8_aurora.sh` desde **AWS CloudShell** o contar con un clúster Aurora PostgreSQL equivalente ya disponible.
- Haber completado la práctica anterior de observabilidad con Performance Insights o contar con un entorno Aurora PostgreSQL preparado.
- Acceso a una cuenta AWS.
- Acceso a AWS CloudShell.
- Clúster Aurora PostgreSQL activo con instancia writer disponible.
- Conectividad desde CloudShell hacia el writer endpoint.
- Cliente `psql` disponible.
- Python 3 disponible.
- Extensión `pg_stat_statements` disponible.
- Permisos de base de datos para:
  - crear esquemas,
  - crear tablas,
  - insertar datos,
  - crear índices,
  - ejecutar `ANALYZE`,
  - consultar vistas estadísticas.
- Permisos IAM para validar recursos RDS si se usa el script de preparación.
- Conocimientos básicos de:
  - SQL,
  - índices,
  - planes de ejecución,
  - `EXPLAIN ANALYZE`,
  - métricas de buffers,
  - `pg_stat_statements`.

> ⚠️ **Importante:** Esta práctica aplica optimizaciones dentro de un esquema temporal llamado `lab_diagnostics`. No modifica parameter groups ni cambia configuración global de la instancia.

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
| AWS CLI | Validación de entorno |
| psql | Ejecución SQL y análisis |
| PostgreSQL / Aurora PostgreSQL | Motor de base de datos |
| pg_stat_statements | Métricas acumuladas por consulta |
| EXPLAIN ANALYZE BUFFERS | Diagnóstico de planes reales |
| Python 3 | Cálculo simple de comparativas |
| jq | Opcional para salidas JSON |

---

## 🧱 Valores estandarizados del laboratorio

Usa estos valores durante toda la práctica para mantener consistencia entre los retos, las validaciones y la limpieza final.

| Tipo | Nombre / valor estándar | Uso |
|---|---|---|
| Región | `$AWS_REGION` | Región activa de AWS CLI o `us-west-2` como valor por defecto del script previo |
| Cluster ID | `aurora-performance-lab-cluster` | Identificador esperado del clúster Aurora |
| Endpoint writer | `$AURORA_ENDPOINT` | Endpoint writer del clúster Aurora PostgreSQL |
| Puerto | `5432` | Puerto estándar PostgreSQL |
| Base de datos | `lab_performance` | Base usada para el laboratorio |
| Usuario administrador | `labadmin` | Usuario master del laboratorio |
| Contraseña temporal | `AuroraLab_2026_Temporal!` | Contraseña de laboratorio, cámbiala si tu instructor lo solicita |
| Archivo de variables | `./lab8_aurora_env.sh` | Variables exportadas para el laboratorio |
| Esquema temporal | `lab_diagnostics` | Esquema de diagnóstico y optimización |
| Tabla clientes | `lab_diagnostics.customers_diag` | Clientes de prueba |
| Tabla órdenes | `lab_diagnostics.orders_diag` | Órdenes con filtros problemáticos |
| Tabla partidas | `lab_diagnostics.order_items_diag` | Detalles usados para agregaciones |
| Validación entorno | `08_entorno_validacion.txt` | Evidencia de conexión y extensión |
| Setup esquema | `08_setup_diagnostics_schema.txt` | Evidencia de carga de datos |
| Baseline runs | `08_baseline_run_*.txt` | Ejecuciones problemáticas antes de optimizar |
| Baseline pg_stat | `08_baseline_pg_stat_statements.txt` | Métricas baseline |
| Diagnóstico pg_stat | `08_diagnostico_pg_stat_statements.txt` | Diagnóstico por total, media, buffers y temporales |
| Planes before | `08_planes_before.txt` | Planes antes de optimizar |
| Optimizaciones | `08_optimizaciones_aplicadas.txt` | Índices, estadísticas y ANALYZE |
| Planes after | `08_planes_after.txt` | Planes después de optimizar |
| After pg_stat | `08_after_pg_stat_statements.txt` | Métricas posteriores |
| Reporte final | `08_reporte_optimizacion.md` | Reporte técnico before/after |
| Evidencia comprimida | `08_diagnostico_optimizacion_evidencia_*.tar.gz` | Paquete final de evidencias |

---

## 🚦 Preparación previa obligatoria antes de comenzar

Antes de iniciar el **Reto 1**, ejecuta el script de preparación desde **AWS CloudShell**. Este script crea o reutiliza los recursos mínimos requeridos para la práctica: VPC default, subnets, Security Group temporal, DB Subnet Group, clúster Aurora PostgreSQL, instancia writer, base `lab_performance`, cliente `psql`, validación de `pg_stat_statements`, y archivo de variables `lab8_aurora_env.sh`.

> ⚠️ **Costo y seguridad:** El script puede crear recursos que generan cargos. Para facilitar el laboratorio desde CloudShell, el ambiente puede usar conectividad pública temporal y acceso TCP/5432 desde `0.0.0.0/0`. Usa esta configuración solo en laboratorio y elimina o restringe los recursos al terminar.

### Comandos de ejecución previa

```bash
chmod +x 00_preparar_laboratorio_8_aurora.sh
./00_preparar_laboratorio_8_aurora.sh
source ./lab8_aurora_env.sh
```

### Validación previa rápida

```bash
echo "$AURORA_ENDPOINT"
echo "$AURORA_DBNAME"

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
| Nivel Bloom | Aplicar / Analizar |
| Modalidad | Retos guiados con solución oculta |
| Motor | Amazon Aurora PostgreSQL |
| Enfoque | Diagnóstico y optimización before/after |
| Entorno | AWS CloudShell |
| Costo | Puede generar cargos si el clúster fue creado para el laboratorio |
| Cambios persistentes | No modifica parameter groups |

---

## 🗓️ Distribución de tiempo por reto

| Reto | Actividad | Tiempo |
|---|---|---:|
| Reto 1 | Preparar CloudShell, variables y validar extensiones | 5 min |
| Reto 2 | Crear esquema con problemas controlados | 7 min |
| Reto 3 | Capturar baseline con consultas problemáticas | 6 min |
| Reto 4 | Diagnosticar con `pg_stat_statements` | 5 min |
| Reto 5 | Analizar planes con `EXPLAIN ANALYZE BUFFERS` | 7 min |
| Reto 6 | Aplicar optimizaciones focalizadas | 7 min |
| Reto 7 | Validar before/after y generar reporte | 5 min |
| Reto 8 | Validar estado final previo a limpieza | 2 min |
| Reto 9 | Eliminar recursos del laboratorio | 1 min |
| **Total** |  | **45 min** |

> 💡 **Nota operativa:** Los tiempos dependen del tamaño de instancia y estado del clúster. El laboratorio usa volúmenes moderados para que sea ejecutable dentro de la ventana de 45 minutos.

---

# 2. 🧪 Desarrollo de la práctica

---

# 🧩 Reto 1. Preparar CloudShell, variables y validar extensiones

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Preparar el entorno, definir variables estándar y validar que `pg_stat_statements` está disponible para capturar métricas de las consultas problemáticas.

---

## 🧠 Escenario

Antes de diagnosticar rendimiento, necesitas garantizar que estás conectado al writer endpoint y que las herramientas de observabilidad SQL están listas. `pg_stat_statements` será la fuente principal para identificar impacto acumulado por consulta.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor esperado |
|---|---|
| Archivo variables | `./lab8_aurora_env.sh` |
| Endpoint | `$AURORA_ENDPOINT` |
| Base | `$AURORA_DBNAME` |
| Extensión | `pg_stat_statements` |
| Archivo evidencia | `08_entorno_validacion.txt` |
| Rol esperado | Writer, `pg_is_in_recovery() = false` |

---

## 🛠️ Tu reto

Valida:

- Identidad AWS.
- Región.
- Endpoint writer.
- Conexión a Aurora.
- `pg_stat_statements`.
- Variables estándar.
- Herramientas locales.

---

## 💡 Pistas

- Usa `source ./lab8_aurora_env.sh`.
- `pg_is_in_recovery() = false` indica writer.
- Si `pg_stat_statements` no está cargado en `shared_preload_libraries`, el laboratorio necesita preparación previa del parameter group.
- No avances si estás conectado a un reader.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Cargar variables del Laboratorio 8 ==="

if [ -f ./lab8_aurora_env.sh ]; then
  source ./lab8_aurora_env.sh
else
  echo "ERROR: No existe ./lab8_aurora_env.sh"
  echo "Ejecuta primero 00_preparar_laboratorio_8_aurora.sh"
  exit 1
fi

echo "=== Validar identidad AWS ==="
aws sts get-caller-identity --output table

echo "=== Validar herramientas ==="
aws --version
psql --version
python3 --version

echo "=== Variables Aurora ==="
echo "Región:   $AWS_REGION"
echo "Cluster:  $AURORA_CLUSTER_ID"
echo "Endpoint: $AURORA_ENDPOINT"
echo "Base:     $AURORA_DBNAME"
echo "Usuario:  $AURORA_MASTER_USER"

echo "=== Validar conexión y extensión ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 08_entorno_validacion.txt

SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

SELECT
  extname,
  extversion
FROM pg_extension
WHERE extname = 'pg_stat_statements';

SELECT
  name,
  setting,
  source,
  context
FROM pg_settings
WHERE name IN (
  'shared_preload_libraries',
  'track_io_timing',
  'work_mem',
  'pg_stat_statements.track',
  'pg_stat_statements.max'
)
ORDER BY name;

SELECT pg_stat_statements_reset();

SQL
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT extname FROM pg_extension WHERE extname = 'pg_stat_statements';"
```

---

## 📌 Resultado esperado

Debes ver:

```text
pg_stat_statements
```

Y la conexión debe mostrar:

```text
es_replica = f
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20preparar%20Aurora%20PostgreSQL%20para%20diagnosticar%20consultas%20con%20pg_stat_statements%20y%20EXPLAIN%20ANALYZE%20BUFFERS.)

---

# 🧩 Reto 2. Crear esquema con problemas controlados

## ⏱️ Tiempo estimado

**7 minutos**

---

## 🎯 Objetivo del reto

Crear un esquema de laboratorio con datos suficientes para provocar problemas controlados de rendimiento: filtro sin índice, agregación costosa y estadísticas que requieren actualización.

---

## 🧠 Escenario

Vas a crear un mini escenario de e-commerce con clientes, órdenes y partidas. Al inicio, dejarás intencionalmente algunas columnas sin índices para observar planes ineficientes. Después corregirás esos problemas en los retos finales.

---

## 🧱 Valores estandarizados del reto

| Recurso | Valor |
|---|---|
| Esquema | `lab_diagnostics` |
| Clientes | `customers_diag` |
| Órdenes | `orders_diag` |
| Partidas | `order_items_diag` |
| Filas clientes | `50000` |
| Filas órdenes | `300000` |
| Filas partidas | `450000` |
| Archivo evidencia | `08_setup_diagnostics_schema.txt` |

---

## 🛠️ Tu reto

Crea:

- Esquema `lab_diagnostics`.
- Tabla `customers_diag`.
- Tabla `orders_diag`.
- Tabla `order_items_diag`.
- Datos moderados para pruebas.
- Estadísticas iniciales.

---

## 💡 Pistas

- No crees índices en `orders_diag.status` ni `orders_diag.created_at` al inicio.
- No crees índice sobre `order_items_diag.product_id` al inicio.
- Las llaves primarias básicas sí son válidas.
- Usa `ANALYZE` al final para tener estadísticas iniciales.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Crear esquema con problemas controlados ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 08_setup_diagnostics_schema.txt

DROP SCHEMA IF EXISTS lab_diagnostics CASCADE;
CREATE SCHEMA lab_diagnostics;

CREATE TABLE lab_diagnostics.customers_diag (
    customer_id   INTEGER PRIMARY KEY,
    customer_name TEXT NOT NULL,
    email         TEXT NOT NULL,
    city          TEXT NOT NULL,
    segment       TEXT NOT NULL
);

CREATE TABLE lab_diagnostics.orders_diag (
    order_id     BIGSERIAL PRIMARY KEY,
    customer_id  INTEGER NOT NULL REFERENCES lab_diagnostics.customers_diag(customer_id),
    status       TEXT NOT NULL,
    amount       NUMERIC(12,2) NOT NULL,
    created_at   TIMESTAMP NOT NULL,
    notes        TEXT
);

CREATE TABLE lab_diagnostics.order_items_diag (
    item_id    BIGSERIAL PRIMARY KEY,
    order_id   BIGINT NOT NULL REFERENCES lab_diagnostics.orders_diag(order_id),
    product_id INTEGER NOT NULL,
    quantity   INTEGER NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL
);

INSERT INTO lab_diagnostics.customers_diag (
    customer_id,
    customer_name,
    email,
    city,
    segment
)
SELECT
    id,
    'Cliente ' || id,
    'cliente' || id || '@example.com',
    CASE (id % 5)
      WHEN 0 THEN 'CDMX'
      WHEN 1 THEN 'Guadalajara'
      WHEN 2 THEN 'Monterrey'
      WHEN 3 THEN 'Puebla'
      ELSE 'Querétaro'
    END,
    CASE (id % 4)
      WHEN 0 THEN 'enterprise'
      WHEN 1 THEN 'midmarket'
      WHEN 2 THEN 'smb'
      ELSE 'consumer'
    END
FROM generate_series(1, 50000) AS id;

INSERT INTO lab_diagnostics.orders_diag (
    customer_id,
    status,
    amount,
    created_at,
    notes
)
SELECT
    (random() * 49999)::INTEGER + 1,
    CASE
      WHEN random() < 0.08 THEN 'pending'
      WHEN random() < 0.35 THEN 'processing'
      WHEN random() < 0.70 THEN 'shipped'
      ELSE 'delivered'
    END,
    (random() * 10000)::NUMERIC(12,2),
    now() - ((random() * 180)::INTEGER || ' days')::INTERVAL,
    repeat('orden de diagnóstico ', 4)
FROM generate_series(1, 300000);

INSERT INTO lab_diagnostics.order_items_diag (
    order_id,
    product_id,
    quantity,
    unit_price
)
SELECT
    (random() * 299999)::BIGINT + 1,
    (random() * 5000)::INTEGER + 1,
    (random() * 5)::INTEGER + 1,
    (random() * 1000)::NUMERIC(12,2)
FROM generate_series(1, 450000);

ANALYZE lab_diagnostics.customers_diag;
ANALYZE lab_diagnostics.orders_diag;
ANALYZE lab_diagnostics.order_items_diag;

SELECT
  schemaname,
  relname,
  n_live_tup
FROM pg_stat_user_tables
WHERE schemaname = 'lab_diagnostics'
ORDER BY relname;

SQL
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT
        (SELECT count(*) FROM lab_diagnostics.customers_diag) AS customers,
        (SELECT count(*) FROM lab_diagnostics.orders_diag) AS orders,
        (SELECT count(*) FROM lab_diagnostics.order_items_diag) AS items;"
```

---

## 📌 Resultado esperado

Debes ver cantidades similares a:

```text
customers = 50000
orders    = 300000
items     = 450000
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20crear%20un%20esquema%20de%20diagn%C3%B3stico%20en%20PostgreSQL%20con%20consultas%20lentas%20controladas%20para%20probar%20%C3%ADndices%2C%20ANALYZE%20y%20work_mem.)

---

# 🧩 Reto 3. Capturar baseline con consultas problemáticas

## ⏱️ Tiempo estimado

**6 minutos**

---

## 🎯 Objetivo del reto

Ejecutar consultas problemáticas antes de cualquier optimización para capturar una línea base de rendimiento.

---

## 🧠 Escenario

Necesitas medir antes de corregir. Ejecutarás tres consultas con problemas intencionales:

1. Consulta filtrada sin índice eficiente.
2. Agregación y ordenamiento costoso.
3. Consulta de join con volumen de datos considerable.

---

## 🧱 Valores estandarizados del reto

| Archivo | Uso |
|---|---|
| `08_run_baseline_queries.sql` | Script con consultas baseline |
| `08_baseline_run_1.txt` | Primera ejecución |
| `08_baseline_run_2.txt` | Segunda ejecución |
| `08_baseline_run_3.txt` | Tercera ejecución |
| `08_baseline_pg_stat_statements.txt` | Métricas acumuladas baseline |

---

## 🛠️ Tu reto

Ejecuta las consultas baseline varias veces para que aparezcan en `pg_stat_statements` y guarda resultados.

---

## 💡 Pistas

- Usa `\timing on` para capturar duración.
- Repite varias veces para que `pg_stat_statements` acumule datos.
- No crees índices todavía.
- No cambies `work_mem` todavía.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Resetear pg_stat_statements para baseline limpio ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT pg_stat_statements_reset();"

echo "=== Crear script baseline ==="

cat > 08_run_baseline_queries.sql <<'SQL'
\timing on

\echo 'Consulta 1: filtro sin índice eficiente'
SELECT
  order_id,
  customer_id,
  amount,
  created_at
FROM lab_diagnostics.orders_diag
WHERE status = 'pending'
  AND created_at >= now() - interval '30 days'
ORDER BY created_at DESC
LIMIT 100;

\echo 'Consulta 2: agregación y ordenamiento costoso'
SET work_mem = '1MB';

SELECT
  product_id,
  sum(quantity * unit_price) AS total_sales,
  count(*) AS total_items
FROM lab_diagnostics.order_items_diag
GROUP BY product_id
ORDER BY total_sales DESC
LIMIT 50;

RESET work_mem;

\echo 'Consulta 3: join con filtro de segmento'
SELECT
  c.segment,
  count(*) AS total_orders,
  sum(o.amount) AS total_amount
FROM lab_diagnostics.orders_diag o
JOIN lab_diagnostics.customers_diag c
  ON o.customer_id = c.customer_id
WHERE o.created_at >= now() - interval '60 days'
GROUP BY c.segment
ORDER BY total_amount DESC;
SQL

echo "=== Ejecutar baseline 3 veces ==="

for i in 1 2 3; do
  echo "Ejecución baseline $i"
  psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
    -f 08_run_baseline_queries.sql \
    2>&1 | tee "08_baseline_run_${i}.txt"
done

echo "=== Capturar pg_stat_statements baseline ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 08_baseline_pg_stat_statements.txt

SELECT
  left(query, 120) AS query_preview,
  calls,
  round(total_exec_time::numeric, 2) AS total_ms,
  round(mean_exec_time::numeric, 2) AS mean_ms,
  rows,
  shared_blks_read,
  shared_blks_hit,
  temp_blks_written
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
  AND query NOT LIKE '%pg_stat_statements_reset%'
ORDER BY total_exec_time DESC
LIMIT 10;

SQL

echo "=== Generar carga visible para Database Insights ==="
echo "=== Esta carga debe ejecutarse ANTES de crear índices ==="

cat > 08_database_insights_bad_query.sql <<'SQL'
\set ON_ERROR_STOP on

SELECT
  order_id,
  customer_id,
  amount,
  created_at
FROM lab_diagnostics.orders_diag
WHERE status = 'pending'
  AND created_at >= now() - interval '30 days'
ORDER BY created_at DESC
LIMIT 100;
SQL

echo "=== Ejecutar consulta problemática durante varios minutos ==="

for i in $(seq 1 120); do
  echo "Ejecución problemática $i/120"

  psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require connect_timeout=10" \
    -f 08_database_insights_bad_query.sql >/dev/null 2>&1 || true

  sleep 1
done

echo "=== Capturar plan problemático para correlacionar con Database Insights ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 08_database_insights_bad_query_plan_before.txt

EXPLAIN (ANALYZE, BUFFERS)
SELECT
  order_id,
  customer_id,
  amount,
  created_at
FROM lab_diagnostics.orders_diag
WHERE status = 'pending'
  AND created_at >= now() - interval '30 days'
ORDER BY created_at DESC
LIMIT 100;

SQL

echo "=== Espera sugerida ==="
echo "Espera de 3 a 10 minutos y revisa CloudWatch Database Insights."
echo "Ruta sugerida:"
echo "CloudWatch -> Database Insights -> Database instance -> Top SQL / SQL statements / DB Load"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
ls -lh 08_baseline_run_*.txt
cat 08_baseline_pg_stat_statements.txt
```

---

## 📌 Resultado esperado

Debes tener:

```text
08_baseline_run_1.txt
08_baseline_run_2.txt
08_baseline_run_3.txt
08_baseline_pg_stat_statements.txt
```

Y las consultas deben aparecer con valores de:

```text
total_ms
mean_ms
shared_blks_read
temp_blks_written
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20por%20qu%C3%A9%20debo%20capturar%20un%20baseline%20antes%20de%20optimizar%20consultas%20en%20PostgreSQL%20usando%20pg_stat_statements.)

---

# 🧩 Reto 4. Diagnosticar con `pg_stat_statements`

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Identificar qué consultas tienen mayor impacto acumulado, mayor latencia promedio y señales de lectura o uso de temporales.

---

## 🧠 Escenario

Una consulta puede ser problemática por diferentes razones. Puede ser lenta individualmente, ejecutarse demasiadas veces o provocar muchas lecturas y temporales. `pg_stat_statements` te permite distinguir esos casos.

---

## 🧱 Valores estandarizados del reto

| Diagnóstico | Archivo |
|---|---|
| Top por tiempo total | `08_diagnostico_pg_stat_statements.txt` |
| Top por latencia media | `08_diagnostico_pg_stat_statements.txt` |
| Lecturas y temporales | `08_diagnostico_pg_stat_statements.txt` |
| Actividad por tablas | `08_diagnostico_pg_stat_statements.txt` |

---

## 🛠️ Tu reto

Genera diagnósticos por:

- Tiempo total.
- Latencia promedio.
- Bloques leídos.
- Bloques temporales escritos.
- Uso de tablas del laboratorio.

---

## 💡 Pistas

- `total_exec_time` prioriza impacto acumulado.
- `mean_exec_time` prioriza latencia individual.
- `shared_blks_read` ayuda a detectar lectura física.
- `temp_blks_written` sugiere spills a disco.
- `calls` alto puede indicar hot path.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Diagnóstico pg_stat_statements ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 08_diagnostico_pg_stat_statements.txt

\echo '--- Top por tiempo total ---'
SELECT
  left(query, 120) AS query_preview,
  calls,
  round(total_exec_time::numeric, 2) AS total_ms,
  round(mean_exec_time::numeric, 2) AS mean_ms,
  round(stddev_exec_time::numeric, 2) AS stddev_ms,
  rows
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY total_exec_time DESC
LIMIT 8;

\echo '--- Top por latencia media ---'
SELECT
  left(query, 120) AS query_preview,
  calls,
  round(mean_exec_time::numeric, 2) AS mean_ms,
  round(max_exec_time::numeric, 2) AS max_ms,
  rows
FROM pg_stat_statements
WHERE calls > 0
  AND query NOT LIKE '%pg_stat_statements%'
ORDER BY mean_exec_time DESC
LIMIT 8;

\echo '--- Lecturas y temporales ---'
SELECT
  left(query, 120) AS query_preview,
  calls,
  shared_blks_read,
  shared_blks_hit,
  temp_blks_read,
  temp_blks_written,
  round(mean_exec_time::numeric, 2) AS mean_ms
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY temp_blks_written DESC, shared_blks_read DESC
LIMIT 8;

\echo '--- Actividad por tablas ---'
SELECT
  schemaname,
  relname,
  seq_scan,
  seq_tup_read,
  idx_scan,
  n_live_tup,
  last_analyze
FROM pg_stat_user_tables
WHERE schemaname = 'lab_diagnostics'
ORDER BY seq_tup_read DESC;

SQL
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
grep -E "orders_diag|order_items_diag|customers_diag" 08_diagnostico_pg_stat_statements.txt || true
```

---

## 📌 Resultado esperado

Debes identificar al menos dos señales:

```text
Consulta con alto total_exec_time
Consulta con alto mean_exec_time
Consulta con shared_blks_read significativo
Consulta con temp_blks_written mayor a 0
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20priorizar%20consultas%20con%20pg_stat_statements%20usando%20total_exec_time%2C%20mean_exec_time%2C%20shared_blks_read%20y%20temp_blks_written.)

---

# 🧩 Reto 5. Analizar planes con `EXPLAIN ANALYZE BUFFERS`

## ⏱️ Tiempo estimado

**7 minutos**

---

## 🎯 Objetivo del reto

Confirmar la causa raíz de las consultas problemáticas usando planes reales de ejecución.

---

## 🧠 Escenario

`pg_stat_statements` te dice qué consultas importan. `EXPLAIN (ANALYZE, BUFFERS)` te dice por qué son costosas. En este reto analizarás el plan antes de optimizar para justificar cada corrección.

---

## 🧱 Valores estandarizados del reto

| Plan | Archivo |
|---|---|
| Filtro sin índice | `08_planes_before.txt` |
| Agregación con sort | `08_planes_before.txt` |
| Join por segmento | `08_planes_before.txt` |

---

## 🛠️ Tu reto

Analiza:

- Consulta filtrada sin índice.
- Agregación con ordenamiento.
- Join por segmento.
- Evidencia de buffers, temporales y tiempos.

---

## 💡 Pistas

En los planes busca:

- `Seq Scan`
- `Rows Removed by Filter`
- `Buffers: shared hit/read`
- `Sort Method`
- `Disk`
- `temp read/write`
- `Execution Time`

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Guardar planes BEFORE ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 08_planes_before.txt

\echo '--- Plan BEFORE 1: filtro sin índice ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT
  order_id,
  customer_id,
  amount,
  created_at
FROM lab_diagnostics.orders_diag
WHERE status = 'pending'
  AND created_at >= now() - interval '30 days'
ORDER BY created_at DESC
LIMIT 100;

\echo '--- Plan BEFORE 2: agregación y sort con work_mem bajo ---'
SET work_mem = '1MB';

EXPLAIN (ANALYZE, BUFFERS)
SELECT
  product_id,
  sum(quantity * unit_price) AS total_sales,
  count(*) AS total_items
FROM lab_diagnostics.order_items_diag
GROUP BY product_id
ORDER BY total_sales DESC
LIMIT 50;

RESET work_mem;

\echo '--- Plan BEFORE 3: join por segmento ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT
  c.segment,
  count(*) AS total_orders,
  sum(o.amount) AS total_amount
FROM lab_diagnostics.orders_diag o
JOIN lab_diagnostics.customers_diag c
  ON o.customer_id = c.customer_id
WHERE o.created_at >= now() - interval '60 days'
GROUP BY c.segment
ORDER BY total_amount DESC;

SQL
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
grep -E "Seq Scan|Sort Method|Disk|Buffers|Execution Time" 08_planes_before.txt
```

---

## 📌 Resultado esperado

Debes encontrar evidencia de problemas como:

```text
Seq Scan on orders_diag
Rows Removed by Filter
Buffers: shared hit/read
Sort Method
Execution Time
```

Si aparece `Disk` o `temp`, es evidencia de spill a disco.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20leer%20EXPLAIN%20ANALYZE%20BUFFERS%20en%20PostgreSQL%20para%20identificar%20Seq%20Scan%2C%20lecturas%20de%20buffers%2C%20sort%20externo%20y%20tiempo%20de%20ejecuci%C3%B3n.)

---

# 🧩 Reto 6. Aplicar optimizaciones focalizadas

## ⏱️ Tiempo estimado

**7 minutos**

---

## 🎯 Objetivo del reto

Aplicar optimizaciones justificadas por la evidencia: índice para filtro frecuente, índice auxiliar para joins, estadísticas más precisas y ajuste de `work_mem` a nivel sesión.

---

## 🧠 Escenario

Ya identificaste las causas raíz. Ahora aplicarás correcciones específicas. No cambiarás parámetros globales ni crearás soluciones genéricas. Cada cambio debe responder a una evidencia observada.

---

## 🧱 Valores estandarizados del reto

| Optimización | Valor |
|---|---|
| Índice filtro | `idx_orders_diag_status_created` |
| Índice join | `idx_orders_diag_customer_created` |
| Índice agregación | `idx_order_items_diag_product` |
| Statistics target | `500` |
| ANALYZE | Ejecutado después de crear índices |
| Archivo evidencia | `08_optimizaciones_aplicadas.txt` |

---

## 🛠️ Tu reto

Aplica:

- Índice para búsqueda por `status` y `created_at`.
- Índice auxiliar para join por `customer_id`.
- Índice para agregación por `product_id`.
- Estadísticas más detalladas para columnas relevantes.
- `ANALYZE` posterior.
- `work_mem` solo a nivel sesión para la consulta de agregación.

---

## 💡 Pistas

- En producción podrías usar `CREATE INDEX CONCURRENTLY`.
- En el laboratorio usaremos `CREATE INDEX` normal para ahorrar tiempo.
- No uses `CREATE INDEX CONCURRENTLY` dentro de una transacción.
- No cambies `work_mem` globalmente.
- `ANALYZE` debe ejecutarse después de crear índices y ajustar estadísticas.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Aplicar optimizaciones focalizadas ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 08_optimizaciones_aplicadas.txt

\echo '--- Crear índice para filtro frecuente ---'
CREATE INDEX idx_orders_diag_status_created
ON lab_diagnostics.orders_diag (status, created_at DESC)
INCLUDE (customer_id, amount);

\echo '--- Crear índice auxiliar para joins por customer_id y fecha ---'
CREATE INDEX idx_orders_diag_customer_created
ON lab_diagnostics.orders_diag (customer_id, created_at DESC)
INCLUDE (status, amount);

\echo '--- Crear índice para agregación por producto ---'
CREATE INDEX idx_order_items_diag_product
ON lab_diagnostics.order_items_diag (product_id)
INCLUDE (quantity, unit_price);

\echo '--- Mejorar estadísticas en columnas relevantes ---'
ALTER TABLE lab_diagnostics.orders_diag
ALTER COLUMN status SET STATISTICS 500;

ALTER TABLE lab_diagnostics.orders_diag
ALTER COLUMN created_at SET STATISTICS 500;

ALTER TABLE lab_diagnostics.order_items_diag
ALTER COLUMN product_id SET STATISTICS 500;

\echo '--- Ejecutar ANALYZE después de cambios ---'
ANALYZE lab_diagnostics.orders_diag;
ANALYZE lab_diagnostics.order_items_diag;
ANALYZE lab_diagnostics.customers_diag;

\echo '--- Validar índices creados correctamente ---'

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 08_indices_validados.txt

SELECT
  schemaname,
  relname AS tablename,
  indexrelname AS indexname,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'lab_diagnostics'
ORDER BY relname, indexrelname;

SQL
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT indexname
      FROM pg_indexes
      WHERE schemaname = 'lab_diagnostics'
      ORDER BY indexname;"
```

---

## 📌 Resultado esperado

Debes ver índices como:

```text
idx_order_items_diag_product
idx_orders_diag_customer_created
idx_orders_diag_status_created
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20aplicar%20optimizaciones%20focalizadas%20en%20PostgreSQL%20usando%20%C3%ADndices%2C%20ANALYZE%2C%20statistics_target%20y%20work_mem%20de%20sesi%C3%B3n.)

---

# 🧩 Reto 7. Validar before/after y generar reporte

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Reejecutar las consultas optimizadas, comparar métricas before/after y generar un reporte técnico.

---

## 🧠 Escenario

Una optimización no está terminada hasta que se valida. Repetirás los planes, revisarás si los índices se usan, comprobarás reducción de temporales y documentarás resultados reales.

---

## 🧱 Valores estandarizados del reto

| Evidencia | Archivo |
|---|---|
| Planes after | `08_planes_after.txt` |
| Métricas after | `08_after_pg_stat_statements.txt` |
| Reporte | `08_reporte_optimizacion.md` |
| Uso de índices | Incluido en `08_after_pg_stat_statements.txt` |

---

## 🛠️ Tu reto

Genera:

- Planes después de optimizar.
- Métricas actualizadas de `pg_stat_statements`.
- Uso de índices.
- Reporte Markdown con before/after.

---

## 💡 Pistas

- No necesitas que todos los tiempos bajen al mismo nivel; busca evidencia de mejora.
- Si el plan sigue usando Seq Scan, revisa selectividad y estadísticas.
- Para el sort, valida si bajan los temporales al aumentar `work_mem` en sesión.
- Documenta los resultados reales, no inventes mejoras.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Resetear pg_stat_statements para medición AFTER ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT pg_stat_statements_reset();"

echo "=== Guardar planes AFTER ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 08_planes_after.txt

\echo '--- Plan AFTER 1: filtro con índice ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT
  order_id,
  customer_id,
  amount,
  created_at
FROM lab_diagnostics.orders_diag
WHERE status = 'pending'
  AND created_at >= now() - interval '30 days'
ORDER BY created_at DESC
LIMIT 100;

\echo '--- Plan AFTER 2: agregación con work_mem de sesión ---'
SET work_mem = '64MB';

EXPLAIN (ANALYZE, BUFFERS)
SELECT
  product_id,
  sum(quantity * unit_price) AS total_sales,
  count(*) AS total_items
FROM lab_diagnostics.order_items_diag
GROUP BY product_id
ORDER BY total_sales DESC
LIMIT 50;

RESET work_mem;

\echo '--- Plan AFTER 3: join por segmento con índices y estadísticas ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT
  c.segment,
  count(*) AS total_orders,
  sum(o.amount) AS total_amount
FROM lab_diagnostics.orders_diag o
JOIN lab_diagnostics.customers_diag c
  ON o.customer_id = c.customer_id
WHERE o.created_at >= now() - interval '60 days'
GROUP BY c.segment
ORDER BY total_amount DESC;

SQL

echo "=== Reejecutar consultas AFTER para pg_stat_statements ==="

for i in 1 2; do
  psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
    -f 08_run_baseline_queries.sql >/dev/null 2>&1
done

echo "=== Capturar pg_stat_statements AFTER ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" <<'SQL' \
  | tee 08_after_pg_stat_statements.txt

SELECT
  left(query, 120) AS query_preview,
  calls,
  round(total_exec_time::numeric, 2) AS total_ms,
  round(mean_exec_time::numeric, 2) AS mean_ms,
  rows,
  shared_blks_read,
  shared_blks_hit,
  temp_blks_written
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
  AND query NOT LIKE '%pg_stat_statements_reset%'
ORDER BY total_exec_time DESC
LIMIT 10;

\echo '--- Uso de índices nuevos ---'
SELECT
  schemaname,
  relname AS table_name,
  indexrelname AS index_name,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'lab_diagnostics'
ORDER BY idx_scan DESC, indexrelname;

SQL

echo "=== Crear reporte de optimización ==="

cat > 08_reporte_optimizacion.md <<EOF_REPORT
# Reporte de optimización — Laboratorio 8

| Elemento | Valor |
|---|---|
| Fecha UTC | $(date -u +"%Y-%m-%dT%H:%M:%SZ") |
| Cluster | $AURORA_CLUSTER_ID |
| Endpoint | $AURORA_ENDPOINT |
| Base | $AURORA_DBNAME |
| Esquema | lab_diagnostics |

---

## Problemas diagnosticados

| Consulta | Problema observado | Evidencia before | Optimización aplicada | Evidencia after esperada |
|---|---|---|---|---|
| Filtro por status y fecha | Seq Scan / buffers altos | 08_planes_before.txt | Índice en status + created_at | Index Scan o menor Execution Time |
| Agregación por producto | Sort/aggregate costoso, posible temporal | 08_planes_before.txt | Índice en product_id + work_mem sesión | Menos temporales o menor tiempo |
| Join por segmento | Lectura elevada y agregación | 08_planes_before.txt | Índice auxiliar + ANALYZE | Menor costo / mejor plan |

---

## Archivos de evidencia

- 08_baseline_pg_stat_statements.txt
- 08_diagnostico_pg_stat_statements.txt
- 08_planes_before.txt
- 08_optimizaciones_aplicadas.txt
- 08_planes_after.txt
- 08_after_pg_stat_statements.txt

---

## Interpretación

La optimización debe evaluarse con evidencia real. En esta práctica se consideran señales positivas:

- reducción de Execution Time;
- menor número de buffers leídos;
- uso de índices nuevos;
- reducción de temp_blks_written;
- planes más selectivos;
- estadísticas actualizadas.

EOF_REPORT

cat 08_reporte_optimizacion.md
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
ls -lh 08_planes_after.txt 08_reporte_optimizacion.md

grep -E "Index Scan|Bitmap Index Scan|Execution Time|Sort Method|Disk|Buffers" 08_planes_after.txt || true
```

---

## 📌 Resultado esperado

Debes observar señales como:

```text
Index Scan
Bitmap Index Scan
menor Execution Time
menos buffers leídos
menos temp_blks_written
```

No prometas un porcentaje fijo. Lo importante es documentar la mejora real observada.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20validar%20una%20optimizaci%C3%B3n%20before%20after%20en%20PostgreSQL%20usando%20EXPLAIN%20ANALYZE%20BUFFERS%2C%20pg_stat_statements%20e%20%C3%ADndices.)

---

# 🧩 Reto 8. Validar estado final previo a limpieza

## ⏱️ Tiempo estimado

**2 minutos**

---

## 🎯 Objetivo del reto

Confirmar que el diagnóstico, los planes before/after, el reporte y el esquema temporal existen antes de ejecutar la limpieza.

---

## 🧠 Escenario

Antes de borrar el esquema `lab_diagnostics`, debes validar que el laboratorio produjo evidencia suficiente. Esto evita perder información relevante antes de documentar el análisis.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor esperado |
|---|---|
| Esquema temporal | `lab_diagnostics` |
| Planes before | `08_planes_before.txt` |
| Planes after | `08_planes_after.txt` |
| Reporte | `08_reporte_optimizacion.md` |
| Métricas baseline | `08_baseline_pg_stat_statements.txt` |
| Métricas after | `08_after_pg_stat_statements.txt` |

---

## 🛠️ Tu reto

Realiza:

- Validación de esquema temporal.
- Validación de archivos de evidencia.
- Validación de índices creados.
- Validación de reporte final.
- Confirmación de que estás listo para limpiar.

---

## 💡 Pistas

- No elimines todavía el esquema; la limpieza se realiza en el Reto 9.
- Si falta el reporte, vuelve al Reto 7.
- Si faltan planes before/after, vuelve a los retos 5 y 7.
- Conserva archivos `08_*` como evidencia.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Validar esquema temporal ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT schema_name
      FROM information_schema.schemata
      WHERE schema_name = 'lab_diagnostics';"

echo "=== Validar índices creados ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT indexname
      FROM pg_indexes
      WHERE schemaname = 'lab_diagnostics'
      ORDER BY indexname;"

echo "=== Validar evidencia local ==="

ls -lh \
  08_entorno_validacion.txt \
  08_setup_diagnostics_schema.txt \
  08_baseline_pg_stat_statements.txt \
  08_diagnostico_pg_stat_statements.txt \
  08_planes_before.txt \
  08_optimizaciones_aplicadas.txt \
  08_planes_after.txt \
  08_after_pg_stat_statements.txt \
  08_reporte_optimizacion.md

echo "=== Vista rápida del reporte ==="

head -40 08_reporte_optimizacion.md
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
ls -lh 08_planes_before.txt 08_planes_after.txt 08_reporte_optimizacion.md

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT schema_name
      FROM information_schema.schemata
      WHERE schema_name = 'lab_diagnostics';"
```

---

## 📌 Resultado esperado

Debes ver:

```text
08_planes_before.txt
08_planes_after.txt
08_reporte_optimizacion.md
lab_diagnostics
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20validar%20que%20un%20laboratorio%20de%20optimizaci%C3%B3n%20PostgreSQL%20tiene%20evidencia%20before%20after%20suficiente%20antes%20de%20limpiar%20recursos.)

---

# 🧩 Reto 9. Eliminar recursos del laboratorio

## ⏱️ Tiempo estimado

**1 minuto**

---

## 🎯 Objetivo del reto

Eliminar el esquema temporal del laboratorio, conservar la evidencia y ejecutar limpieza de infraestructura solo si el instructor lo solicita.

---

## 🧠 Escenario

El laboratorio creó tablas, índices y datos temporales. Debes limpiar la base para no afectar prácticas posteriores, pero conservar la evidencia en CloudShell.

---

## 🧱 Valores estandarizados del reto

| Recurso | Valor estándar | Acción |
|---|---|---|
| Esquema temporal | `lab_diagnostics` | Eliminar con `DROP SCHEMA` |
| Evidencia | `08_*` | Conservar |
| Paquete evidencia | `08_diagnostico_optimizacion_evidencia_*.tar.gz` | Crear |
| Script de eliminación | `00_eliminar_laboratorio_8_aurora.sh` | Usar si se eliminará infraestructura |

---

## 🛠️ Tu reto

Realiza:

- Compresión de resultados.
- Eliminación del esquema `lab_diagnostics`.
- Validación de limpieza.
- Conservación de reporte.
- Ejecución opcional del script de eliminación de infraestructura.

---

## 💡 Pistas

- No destruyas el clúster si será usado por laboratorios posteriores.
- No modifiques parameter groups.
- No elimines `pg_stat_statements`.
- Conserva archivos `08_*`.
- Ejecuta el script de eliminación solo si el instructor quiere cerrar el ambiente completo.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Empaquetar evidencia ==="

tar -czf "08_diagnostico_optimizacion_evidencia_$(date +%Y%m%d-%H%M%S).tar.gz" 08_* 2>/dev/null || true

echo "=== Eliminar esquema temporal ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "DROP SCHEMA IF EXISTS lab_diagnostics CASCADE;"

echo "=== Validar limpieza ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT schema_name
      FROM information_schema.schemata
      WHERE schema_name = 'lab_diagnostics';"

echo "=== Evidencia conservada ==="

ls -lh 08_*
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT schema_name
      FROM information_schema.schemata
      WHERE schema_name = 'lab_diagnostics';"
```

---

## 📌 Resultado esperado

Debe devolver:

```text
(0 rows)
```

Y debes conservar:

```text
08_reporte_optimizacion.md
08_diagnostico_optimizacion_evidencia_*.tar.gz
```

### Ejecutar script de eliminación de infraestructura

Si el instructor solicita eliminar también el clúster Aurora y los recursos AWS creados para esta práctica, ejecuta el script de eliminación desde AWS CloudShell:

```bash
chmod +x 00_eliminar_laboratorio_8_aurora.sh
./00_eliminar_laboratorio_8_aurora.sh
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20limpiar%20un%20esquema%20temporal%20de%20diagn%C3%B3stico%20en%20PostgreSQL%20y%20conservar%20evidencia%20de%20optimizaci%C3%B3n.)

---

# ✅ Validación final del laboratorio

Al finalizar la práctica, debes haber completado lo siguiente:

| Elemento | Estado esperado |
|---|---|
| CloudShell validado | Correcto |
| Variables `AURORA_*` | Definidas |
| Conexión al writer | `pg_is_in_recovery() = false` |
| `pg_stat_statements` | Disponible |
| Esquema `lab_diagnostics` | Creado |
| Datos de prueba | Cargados |
| Baseline | Capturado |
| Diagnóstico con `pg_stat_statements` | Ejecutado |
| Planes before | Guardados |
| Índices | Creados |
| Estadísticas | Actualizadas |
| `work_mem` de sesión | Usado en prueba |
| Planes after | Guardados |
| Reporte técnico | Generado |
| Estado final previo a limpieza | Validado |
| Evidencia | Empaquetada |
| Esquema temporal | Eliminado |
| Infraestructura | Eliminada solo si el instructor lo solicitó |

---

# 🧠 Resultado esperado de aprendizaje

Después de completar este laboratorio, debes poder explicar y ejecutar un ciclo completo de optimización de consultas en Aurora PostgreSQL:

1. Crear un escenario controlado de rendimiento.
2. Ejecutar consultas problemáticas.
3. Capturar una línea base.
4. Priorizar consultas con `pg_stat_statements`.
5. Analizar planes reales con `EXPLAIN (ANALYZE, BUFFERS)`.
6. Identificar `Seq Scan`, buffers altos y temporales.
7. Aplicar índices y estadísticas.
8. Usar `work_mem` de sesión para pruebas controladas.
9. Validar before/after con métricas reales.
10. Documentar hallazgos y decisiones técnicas.
11. Limpiar objetos temporales sin afectar el clúster.

---

# 📌 Resumen del laboratorio

En este laboratorio ejecutaste un flujo completo de diagnóstico y optimización de consultas en Aurora PostgreSQL. Primero preparaste el entorno y validaste `pg_stat_statements`. Después creaste un esquema controlado con clientes, órdenes y partidas, ejecutaste consultas problemáticas para capturar un baseline y priorizaste las consultas con mayor impacto. Luego analizaste planes reales con `EXPLAIN (ANALYZE, BUFFERS)`, identificaste problemas como scans costosos, lecturas elevadas y posibles temporales, y aplicaste optimizaciones mediante índices, estadísticas y `work_mem` de sesión. Finalmente validaste los cambios con planes after, revisaste uso de índices, generaste un reporte técnico, validaste el estado final previo a la limpieza y eliminaste los recursos temporales. Esta práctica consolida el ciclo profesional de optimización: medir, diagnosticar, corregir y validar.
