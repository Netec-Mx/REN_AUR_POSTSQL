<h1 align="center">⚙️ Laboratorio 5. Ajuste de parámetros y benchmark controlado</h1>

---

## 1. 🧾 Información general de la práctica

## 📘 Descripción general

En este laboratorio vas a ejecutar un benchmark controlado con `pgbench` sobre **AWS Aurora PostgreSQL** para comparar una línea base contra una ejecución con ajustes seguros a nivel sesión. Revisarás parámetros relevantes como `work_mem`, `effective_cache_size`, `statement_timeout` y `default_statistics_target`, ejecutarás pruebas comparativas y documentarás los resultados en una matriz técnica.

La práctica no busca aplicar “valores mágicos” ni modificar permanentemente la configuración del clúster. El objetivo es que practiques un flujo profesional de optimización basado en evidencia.

La práctica está diseñada como una serie de **retos guiados**. En cada reto primero intentarás resolver el objetivo con pistas. Si te bloqueas, podrás abrir la **solución sugerida**. La solución está oculta para fomentar el razonamiento, pero es completa y funcional para no extender el tiempo del laboratorio.

El enfoque principal es el ciclo básico de benchmark y ajuste controlado:

> **Preparar → Medir → Revisar parámetros → Ajustar → Comparar → Documentar → Validar → Limpiar**

Esta versión evita cambios persistentes en **DB parameter groups** durante el flujo principal para que el laboratorio se pueda completar en **35 minutos** sin reinicios, sin esperas largas de sincronización y sin afectar prácticas posteriores.

---

## 🎯 Objetivos de aprendizaje

Al finalizar este laboratorio, podrás:

- Usar AWS CloudShell para conectarte a un clúster Aurora PostgreSQL.
- Validar que estás conectado al writer endpoint antes de ejecutar pruebas de escritura.
- Validar disponibilidad de `psql` y `pgbench`.
- Crear una base de prueba dedicada para benchmark.
- Preparar una base de prueba con `pgbench`.
- Ejecutar una línea base reproducible de rendimiento.
- Consultar parámetros relevantes con `pg_settings`.
- Aplicar ajustes seguros a nivel sesión usando `PGOPTIONS`.
- Ejecutar una prueba comparativa con las mismas condiciones del baseline.
- Comparar TPS y latencia antes y después de los ajustes.
- Interpretar resultados sin asumir que todo incremento de TPS es una optimización universal.
- Documentar una matriz de parámetros con baseline, valor ajustado, justificación e impacto observado.
- Validar estado final previo a limpieza.
- Limpiar la base de prueba sin modificar recursos permanentes del clúster.
- Ejecutar una eliminación controlada de infraestructura si el instructor lo solicita.

---

## ✅ Prerrequisitos

Antes de iniciar, debes contar con:

- Ejecutar antes de comenzar el script `00_preparar_laboratorio_5_aurora.sh` desde **AWS CloudShell** o contar con un clúster Aurora PostgreSQL equivalente ya disponible.
- Acceso a una cuenta AWS.
- Permisos para usar AWS CloudShell.
- Permisos IAM para administrar o validar recursos de Amazon RDS/Aurora, EC2 Security Groups, VPC/Subnets, DB Subnet Groups y STS.
- Conectividad desde CloudShell hacia el endpoint writer de Aurora PostgreSQL.
- Cliente `psql` disponible en AWS CloudShell. El script previo lo instala si no existe.
- Cliente `pgbench` disponible en AWS CloudShell. El script previo lo instala si no existe.
- Python 3 disponible en AWS CloudShell.
- Conocimientos básicos de SQL.
- Conocimientos básicos de ejecución de comandos Bash.
- Comprensión general de parámetros PostgreSQL:
  - memoria por operación,
  - planeación,
  - timeouts,
  - estadísticas,
  - ejecución de benchmarks controlados.

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
| AWS CLI | Validación de identidad, región y clúster |
| psql | Conexión y validación SQL |
| pgbench | Benchmark OLTP controlado |
| Python 3 | Extracción simple de métricas |
| jq | Procesamiento opcional de salidas JSON |
| Aurora PostgreSQL | Motor de base de datos del laboratorio |

---

## 🧱 Valores estandarizados del laboratorio

Usa estos valores durante toda la práctica para mantener consistencia entre los retos, las validaciones y la limpieza final.

| Tipo | Nombre / valor estándar | Uso |
|---|---|---|
| Región | `$AWS_REGION` | Región activa de AWS CLI o `us-west-2` como valor por defecto del script previo |
| Endpoint writer | `$AURORA_ENDPOINT` | Endpoint writer del clúster Aurora PostgreSQL |
| Puerto | `5432` | Puerto estándar PostgreSQL |
| Base administrativa | `postgres` | Base usada para crear o eliminar `pgbench_lab` |
| Base de benchmark | `pgbench_lab` | Base dedicada para pruebas con `pgbench` |
| Usuario administrador | `labadmin` | Usuario master del laboratorio |
| Contraseña temporal | `AuroraLab_2026_Temporal!` | Contraseña de laboratorio, cámbiala si tu instructor lo solicita |
| Cluster ID | `aurora-performance-lab-cluster` | Identificador esperado del clúster |
| Archivo de variables | `./lab5_aurora_env.sh` | Variables exportadas para el laboratorio |
| Archivo init | `05_pgbench_init.txt` | Evidencia de inicialización de pgbench |
| Baseline | `05_pgbench_baseline.txt` | Resultado de prueba base |
| Parámetros baseline | `05_parametros_baseline.txt` | Parámetros consultados antes del ajuste |
| ANALYZE ajustado | `05_analyze_ajustado.txt` | Evidencia de actualización de estadísticas |
| Prueba ajustada | `05_pgbench_ajustado.txt` | Resultado de prueba con `PGOPTIONS` |
| Matriz técnica | `05_matriz_parametros.md` | Matriz de parámetros y resultados |
| Escala pgbench | `5` | Escala de datos para laboratorio |
| Clientes pgbench | `5` | Concurrencia del benchmark |
| Hilos pgbench | `2` | Hilos de ejecución |
| Duración prueba | `30 segundos` | Duración de baseline y prueba ajustada |
| Ajustes de sesión | `$PGBENCH_TUNED_OPTIONS` | Parámetros aplicados mediante `PGOPTIONS` |

---

## 🚦 Preparación previa obligatoria antes de comenzar

Antes de iniciar el **Reto 1**, ejecuta el script de preparación desde **AWS CloudShell**. Este script crea o reutiliza los recursos mínimos requeridos para la práctica: VPC default, subnets, Security Group temporal, DB Subnet Group, clúster Aurora PostgreSQL, instancia writer, base administrativa disponible, clientes `psql` y `pgbench`, y archivo de variables `lab5_aurora_env.sh`.

> ⚠️ **Costo y seguridad:** El script puede crear recursos que generan cargos. Para facilitar el laboratorio desde CloudShell, el clúster se prepara con conectividad pública temporal y acceso TCP/5432 desde `0.0.0.0/0`. Usa esta configuración solo en laboratorio y elimina o restringe los recursos al terminar.

### Comandos de ejecución previa

```bash
chmod +x 00_preparar_laboratorio_5_aurora.sh
./00_preparar_laboratorio_5_aurora.sh
source ./lab5_aurora_env.sh
```

### Validación previa rápida

```bash
echo "$AURORA_ENDPOINT"
echo "$AURORA_DBNAME"

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;"

pgbench --version
```

Resultado esperado:

```text
current_database = postgres
es_replica = f
pgbench disponible
```

Después de esta validación, continúa con el **Reto 1**.

---

## ⏱️ Tabla de tiempo, complejidad y nivel Bloom

| Elemento | Detalle |
|---|---|
| Duración total | 35 minutos |
| Complejidad | Media |
| Nivel Bloom | Aplicar / Analizar |
| Modalidad | Retos guiados con solución oculta |
| Motor | Amazon Aurora PostgreSQL |
| Versión recomendada | Aurora PostgreSQL 15.x o 16.x |
| Entorno | AWS CloudShell |
| Costo | Usa el clúster Aurora existente, el creado en laboratorios anteriores o el creado por el script previo |
| Enfoque | Benchmark controlado y ajustes seguros de sesión |

---

## 🗓️ Distribución de tiempo por reto

| Reto | Actividad | Tiempo |
|---|---|---:|
| Reto 1 | Preparar CloudShell, variables y herramientas | 4 min |
| Reto 2 | Crear base `pgbench_lab` e inicializar datos | 5 min |
| Reto 3 | Capturar baseline con `pgbench` | 5 min |
| Reto 4 | Revisar parámetros actuales y contexto | 4 min |
| Reto 5 | Aplicar ajustes seguros a nivel sesión | 4 min |
| Reto 6 | Ejecutar prueba comparativa ajustada | 5 min |
| Reto 7 | Documentar matriz de parámetros y resultados | 4 min |
| Reto 8 | Validar estado final previo a limpieza | 2 min |
| Reto 9 | Eliminar recursos del laboratorio | 2 min |
| **Total** |  | **35 min** |

> 💡 **Nota operativa:** En este laboratorio no modificarás DB parameter groups de forma persistente. Los ajustes se aplican a las sesiones usadas por `pgbench` mediante `PGOPTIONS`.

---

# 2. 🧪 Desarrollo de la práctica

---

# 🧩 Reto 1. Preparar CloudShell, variables y herramientas

## ⏱️ Tiempo estimado

**4 minutos**

---

## 🎯 Objetivo del reto

Validar el entorno de trabajo, definir variables estándar del laboratorio y confirmar que tienes las herramientas necesarias para ejecutar `psql` y `pgbench`.

---

## 🧠 Escenario

Antes de medir rendimiento, debes asegurar que estás conectado al writer endpoint de Aurora PostgreSQL y que CloudShell tiene las herramientas requeridas. Si usas un endpoint reader, las pruebas de escritura de `pgbench` fallarán o no representarán el comportamiento real del writer.

---

## 🧱 Valores estandarizados del reto

| Variable | Valor estándar |
|---|---|
| `AWS_REGION` | Región activa de AWS CLI o `us-west-2` |
| `AURORA_CLUSTER_ID` | `aurora-performance-lab-cluster` |
| `AURORA_ENDPOINT` | Endpoint writer de Aurora PostgreSQL |
| `AURORA_PORT` | `5432` |
| `AURORA_DBNAME` | `postgres` |
| `AURORA_MASTER_USER` | `labadmin` |
| `AURORA_MASTER_PASSWORD` | `AuroraLab_2026_Temporal!` |
| `PGBENCH_DBNAME` | `pgbench_lab` |

---

## 🛠️ Tu reto

Desde AWS CloudShell, valida:

- Identidad AWS.
- Región activa.
- Cliente `psql`.
- Cliente `pgbench`.
- Cliente `python3`.
- Variables de conexión.
- Conexión al writer endpoint.
- Que no estás conectado a una réplica.

---

## 💡 Pistas

- Usa `source ./lab5_aurora_env.sh`.
- El endpoint writer normalmente contiene `.cluster-`.
- `pg_is_in_recovery()` debe devolver `false` cuando usas el writer endpoint.
- `pgbench` se instala como parte de los paquetes cliente o contrib de PostgreSQL.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Cargar variables del Laboratorio 5 ==="

if [ -f ./lab5_aurora_env.sh ]; then
  source ./lab5_aurora_env.sh
else
  echo "ERROR: No existe ./lab5_aurora_env.sh"
  echo "Ejecuta primero 00_preparar_laboratorio_5_aurora.sh"
  exit 1
fi

echo "=== Validar identidad AWS ==="
aws sts get-caller-identity --output table

echo "=== Validar región y herramientas ==="
echo "Región: $AWS_REGION"
aws --version
psql --version
pgbench --version
python3 --version

echo "=== Variables requeridas ==="
echo "Cluster:  $AURORA_CLUSTER_ID"
echo "Endpoint: $AURORA_ENDPOINT"
echo "Puerto:   $AURORA_PORT"
echo "DB base:  $AURORA_DBNAME"
echo "Usuario:  $AURORA_MASTER_USER"

echo "=== Validar conexión al writer ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT pg_is_in_recovery() AS es_replica;"
```

---

## 📌 Resultado esperado

Debes ver:

```text
 es_replica
------------
 f
```

`f` indica que estás conectado al writer endpoint.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20preparar%20AWS%20CloudShell%20para%20ejecutar%20pgbench%20contra%20Aurora%20PostgreSQL%20validando%20psql%2C%20pgbench%2C%20variables%20AURORA%20y%20writer%20endpoint.)

---

# 🧩 Reto 2. Crear base `pgbench_lab` e inicializar datos

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Crear una base dedicada para la prueba y cargar datos con `pgbench` usando una escala pequeña y controlada.

---

## 🧠 Escenario

Necesitas una base de prueba aislada para ejecutar benchmarks sin afectar tablas de otros laboratorios. Usarás `pgbench_lab` y una escala moderada para que la inicialización sea rápida.

---

## 🧱 Valores estandarizados del reto

| Recurso | Valor estándar |
|---|---|
| Base de benchmark | `pgbench_lab` |
| Escala | `5` |
| Archivo init | `05_pgbench_init.txt` |
| Tablas esperadas | `pgbench_accounts`, `pgbench_branches`, `pgbench_history`, `pgbench_tellers` |

---

## 🛠️ Tu reto

Crea:

- Base `pgbench_lab`.
- Esquema de `pgbench`.
- Datos de prueba con escala 5.
- Validación de tablas creadas.

---

## 💡 Pistas

- `pgbench -i` inicializa las tablas de benchmark.
- `-s 5` crea un volumen suficiente para una prueba corta.
- Si la base ya existe, puedes eliminarla o reutilizarla.
- No uses la base `postgres` para cargar las tablas de `pgbench`.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Crear base pgbench_lab si no existe ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -tc "SELECT 1 FROM pg_database WHERE datname = 'pgbench_lab';" | grep -q 1 \
  || psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
       -c "CREATE DATABASE pgbench_lab;"

echo "=== Inicializar pgbench con escala 5 ==="

PGPASSWORD="$AURORA_MASTER_PASSWORD" \
pgbench \
  -h "$AURORA_ENDPOINT" \
  -p "$AURORA_PORT" \
  -U "$AURORA_MASTER_USER" \
  -d pgbench_lab \
  -i \
  -s 5 \
  2>&1 | tee 05_pgbench_init.txt

echo "=== Validar tablas pgbench ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=pgbench_lab user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "\dt pgbench_*"

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=pgbench_lab user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT
        relname AS tabla,
        n_live_tup AS filas_estimadas
      FROM pg_stat_user_tables
      WHERE relname LIKE 'pgbench%'
      ORDER BY relname;"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=pgbench_lab user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS tablas_pgbench
      FROM pg_tables
      WHERE tablename LIKE 'pgbench%';"
```

---

## 📌 Resultado esperado

Debes ver al menos cuatro tablas:

```text
pgbench_accounts
pgbench_branches
pgbench_history
pgbench_tellers
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20crear%20una%20base%20pgbench_lab%20e%20inicializar%20datos%20de%20prueba%20con%20pgbench%20en%20PostgreSQL.)

---

# 🧩 Reto 3. Capturar baseline con `pgbench`

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Ejecutar una prueba baseline con configuración estándar para obtener valores iniciales de TPS y latencia promedio.

---

## 🧠 Escenario

No puedes optimizar lo que no has medido. El baseline sirve como referencia para comparar el efecto de cualquier ajuste posterior. Esta prueba usa una concurrencia moderada para que sea reproducible en un ambiente de laboratorio.

---

## 🧱 Valores estandarizados del reto

| Parámetro | Valor |
|---|---|
| Base | `pgbench_lab` |
| Clientes | `5` |
| Hilos | `2` |
| Duración | `30 segundos` |
| Progreso | Cada `10 segundos` |
| Archivo | `05_pgbench_baseline.txt` |

---

## 🛠️ Tu reto

Ejecuta una prueba de 30 segundos con:

- 5 clientes.
- 2 hilos.
- Reporte de progreso cada 10 segundos.
- Salida guardada en `05_pgbench_baseline.txt`.

---

## 💡 Pistas

- Usa `-T 30` para mantener la práctica dentro de tiempo.
- Usa `tee` para guardar evidencia.
- El TPS y la latencia pueden variar por región, instancia, estado del clúster y carga concurrente.
- No interpretes un resultado aislado como recomendación universal.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Ejecutar baseline con pgbench ==="

PGPASSWORD="$AURORA_MASTER_PASSWORD" \
pgbench \
  -h "$AURORA_ENDPOINT" \
  -p "$AURORA_PORT" \
  -U "$AURORA_MASTER_USER" \
  -d pgbench_lab \
  -c 5 \
  -j 2 \
  -T 30 \
  -P 10 \
  2>&1 | tee 05_pgbench_baseline.txt

echo "=== Extraer métricas principales del baseline ==="

grep -E "latency average|tps =" 05_pgbench_baseline.txt || true
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
test -f 05_pgbench_baseline.txt && echo "Archivo baseline creado"

grep -E "latency average|tps =" 05_pgbench_baseline.txt
```

---

## 📌 Resultado esperado

Debes obtener líneas similares a:

```text
latency average = XX.XXX ms
tps = XXX.XXXXXX (without initial connection time)
```

Los valores exactos dependen del entorno.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20ejecutar%20un%20baseline%20con%20pgbench%20en%20PostgreSQL%20y%20c%C3%B3mo%20interpretar%20TPS%20y%20latencia%20promedio.)

---

# 🧩 Reto 4. Revisar parámetros actuales y contexto

## ⏱️ Tiempo estimado

**4 minutos**

---

## 🎯 Objetivo del reto

Consultar parámetros relevantes de PostgreSQL y entender su contexto antes de aplicar ajustes.

---

## 🧠 Escenario

Antes de modificar parámetros, debes saber sus valores actuales, fuente y contexto. Esto evita ajustes ciegos y permite documentar el baseline.

---

## 🧱 Valores estandarizados del reto

| Parámetro | Motivo de revisión |
|---|---|
| `work_mem` | Memoria por operación de sort/hash |
| `effective_cache_size` | Estimación de caché disponible para el optimizador |
| `default_statistics_target` | Nivel de detalle de estadísticas |
| `statement_timeout` | Protección ante sentencias largas |
| `track_io_timing` | Medición de tiempos de I/O |
| `max_connections` | Límite de conexiones |
| `shared_buffers` | Memoria compartida del motor |

---

## 🛠️ Tu reto

Consulta los parámetros:

- `work_mem`
- `effective_cache_size`
- `default_statistics_target`
- `statement_timeout`
- `track_io_timing`
- `max_connections`
- `shared_buffers`

---

## 💡 Pistas

- `setting` muestra el valor interno.
- `unit` indica la unidad.
- `source` indica si viene de default, configuración, usuario o sesión.
- `context` ayuda a identificar si un cambio requiere reinicio o puede aplicarse en sesión.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Revisar parámetros actuales ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=pgbench_lab user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT
        name,
        setting,
        unit,
        source,
        context
      FROM pg_settings
      WHERE name IN (
        'work_mem',
        'effective_cache_size',
        'default_statistics_target',
        'statement_timeout',
        'track_io_timing',
        'max_connections',
        'shared_buffers'
      )
      ORDER BY name;" \
  | tee 05_parametros_baseline.txt
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
cat 05_parametros_baseline.txt
```

---

## 📌 Resultado esperado

Debes ver los parámetros consultados con columnas similares a:

```text
name | setting | unit | source | context
```

En muchos entornos, varios valores aparecerán con `source = default`.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20interpretar%20pg_settings%20en%20PostgreSQL%20incluyendo%20setting%2C%20unit%2C%20source%20y%20context%20para%20par%C3%A1metros%20como%20work_mem%20y%20effective_cache_size.)

---

# 🧩 Reto 5. Aplicar ajustes seguros a nivel sesión

## ⏱️ Tiempo estimado

**4 minutos**

---

## 🎯 Objetivo del reto

Aplicar ajustes seguros a nivel sesión sin modificar DB parameter groups ni reiniciar instancias.

---

## 🧠 Escenario

En un laboratorio corto no conviene aplicar cambios persistentes que puedan requerir reinicio o impactar otros ejercicios. Usarás `PGOPTIONS` para que cada conexión creada por `pgbench` reciba parámetros de sesión.

---

## 🧱 Valores estandarizados del reto

| Parámetro | Valor ajustado | Alcance |
|---|---:|---|
| `work_mem` | `16MB` | Sesión |
| `effective_cache_size` | `3GB` | Sesión |
| `statement_timeout` | `30s` | Sesión |
| `default_statistics_target` | `200` | Sesión |

---

## 🛠️ Tu reto

Define un conjunto de parámetros de sesión para la prueba ajustada:

- `work_mem=16MB`
- `effective_cache_size=3GB`
- `statement_timeout=30s`
- `default_statistics_target=200`

Además, ejecuta `ANALYZE` para actualizar estadísticas con el nuevo objetivo.

---

## 💡 Pistas

- `PGOPTIONS` permite pasar `-c parametro=valor` al servidor al abrir conexión.
- Los cambios aplican solo a las sesiones nuevas.
- No todos los parámetros pueden cambiarse a nivel sesión; por eso este reto evita parámetros estáticos.
- El objetivo no es garantizar más TPS, sino practicar una comparación controlada.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Definir PGOPTIONS para prueba ajustada ==="

export PGBENCH_TUNED_OPTIONS="-c work_mem=16MB -c effective_cache_size=3GB -c statement_timeout=30s -c default_statistics_target=200"

echo "$PGBENCH_TUNED_OPTIONS"

echo "=== Validar parámetros en una sesión nueva ==="

PGOPTIONS="$PGBENCH_TUNED_OPTIONS" \
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=pgbench_lab user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SHOW work_mem;" \
  -c "SHOW effective_cache_size;" \
  -c "SHOW statement_timeout;" \
  -c "SHOW default_statistics_target;"

echo "=== Ejecutar ANALYZE con default_statistics_target ajustado ==="

PGOPTIONS="$PGBENCH_TUNED_OPTIONS" \
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=pgbench_lab user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "ANALYZE;" \
  -c "SELECT
        relname,
        last_analyze,
        last_autoanalyze,
        n_mod_since_analyze
      FROM pg_stat_user_tables
      WHERE relname LIKE 'pgbench%'
      ORDER BY relname;" \
  | tee 05_analyze_ajustado.txt
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
PGOPTIONS="$PGBENCH_TUNED_OPTIONS" \
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=pgbench_lab user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT name, setting, unit, source
      FROM pg_settings
      WHERE name IN ('work_mem','effective_cache_size','statement_timeout','default_statistics_target')
      ORDER BY name;"
```

---

## 📌 Resultado esperado

Debes ver valores como:

```text
work_mem = 16MB
effective_cache_size = 3GB
statement_timeout = 30s
default_statistics_target = 200
```

La fuente puede aparecer como sesión o cliente, dependiendo del parámetro y versión.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20usar%20PGOPTIONS%20para%20aplicar%20par%C3%A1metros%20de%20sesi%C3%B3n%20en%20PostgreSQL%20sin%20modificar%20parameter%20groups.)

---

# 🧩 Reto 6. Ejecutar prueba comparativa ajustada

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Ejecutar una segunda prueba `pgbench` usando los ajustes de sesión y comparar contra el baseline.

---

## 🧠 Escenario

Ahora que tienes un baseline y un conjunto de parámetros de sesión, necesitas repetir una prueba equivalente. La comparación solo es válida si mantienes la misma concurrencia, duración y base de datos.

---

## 🧱 Valores estandarizados del reto

| Parámetro | Valor |
|---|---|
| Base | `pgbench_lab` |
| Clientes | `5` |
| Hilos | `2` |
| Duración | `30 segundos` |
| Archivo | `05_pgbench_ajustado.txt` |
| Ajustes | `$PGBENCH_TUNED_OPTIONS` |

---

## 🛠️ Tu reto

Ejecuta una prueba ajustada con:

- mismos clientes,
- mismos hilos,
- misma duración,
- `PGOPTIONS` activo,
- salida guardada.

---

## 💡 Pistas

- No cambies `-c`, `-j` ni `-T` respecto al baseline.
- Si cambias la carga, la comparación deja de ser directa.
- Una mejora de TPS no siempre implica optimización global.
- Si el resultado empeora, también es aprendizaje: no todo ajuste ayuda.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Ejecutar prueba ajustada con PGOPTIONS ==="

PGPASSWORD="$AURORA_MASTER_PASSWORD" \
PGOPTIONS="$PGBENCH_TUNED_OPTIONS" \
pgbench \
  -h "$AURORA_ENDPOINT" \
  -p "$AURORA_PORT" \
  -U "$AURORA_MASTER_USER" \
  -d pgbench_lab \
  -c 5 \
  -j 2 \
  -T 30 \
  -P 10 \
  2>&1 | tee 05_pgbench_ajustado.txt

echo "=== Comparar baseline vs ajustado ==="

echo "--- BASELINE ---"
grep -E "latency average|tps =" 05_pgbench_baseline.txt || true

echo ""
echo "--- AJUSTADO ---"
grep -E "latency average|tps =" 05_pgbench_ajustado.txt || true
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
test -f 05_pgbench_ajustado.txt && echo "Archivo ajustado creado"

grep -E "latency average|tps =" 05_pgbench_ajustado.txt
```

---

## 📌 Resultado esperado

Debes tener dos archivos comparables:

```text
05_pgbench_baseline.txt
05_pgbench_ajustado.txt
```

Y ambos deben mostrar:

```text
latency average = ...
tps = ...
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20comparar%20dos%20ejecuciones%20de%20pgbench%20manteniendo%20misma%20concurrencia%2C%20duraci%C3%B3n%20y%20base%20para%20evaluar%20un%20ajuste%20de%20par%C3%A1metros.)

---

# 🧩 Reto 7. Documentar matriz de parámetros y resultados

## ⏱️ Tiempo estimado

**4 minutos**

---

## 🎯 Objetivo del reto

Crear una matriz técnica que documente los parámetros revisados, valores aplicados y resultados medidos.

---

## 🧠 Escenario

Una optimización profesional no termina con ejecutar comandos. Debes dejar evidencia clara de qué cambiaste, por qué lo hiciste y qué impacto mediste. Esta matriz será el entregable técnico del laboratorio.

---

## 🧱 Valores estandarizados del reto

| Archivo | Uso |
|---|---|
| `05_matriz_parametros.md` | Matriz de parámetros y resultados |
| `05_pgbench_baseline.txt` | Métricas baseline |
| `05_pgbench_ajustado.txt` | Métricas ajustadas |
| `05_parametros_baseline.txt` | Valores de parámetros iniciales |

---

## 🛠️ Tu reto

Genera un archivo `05_matriz_parametros.md` que incluya:

- Parámetros baseline.
- Parámetros ajustados.
- Resultados de `pgbench`.
- Observaciones técnicas.
- Advertencia de que son resultados de laboratorio.

---

## 💡 Pistas

- Extrae TPS y latencia con `grep`.
- Usa Python para calcular mejora porcentual si quieres automatizar.
- Documenta observaciones, incluso si el ajuste no mejora.
- No afirmes que el valor ajustado es “mejor” para todos los casos.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Extraer métricas de baseline y ajustado ==="

BASELINE_TPS=$(grep "tps = " 05_pgbench_baseline.txt | tail -1 | awk '{print $3}')
AJUSTADO_TPS=$(grep "tps = " 05_pgbench_ajustado.txt | tail -1 | awk '{print $3}')

BASELINE_LAT=$(grep "latency average" 05_pgbench_baseline.txt | tail -1 | awk '{print $4}')
AJUSTADO_LAT=$(grep "latency average" 05_pgbench_ajustado.txt | tail -1 | awk '{print $4}')

MEJORA_TPS=$(python3 - <<PY
try:
    b=float("$BASELINE_TPS")
    a=float("$AJUSTADO_TPS")
    print(f"{((a-b)/b)*100:.2f}%")
except Exception:
    print("N/A")
PY
)

MEJORA_LAT=$(python3 - <<PY
try:
    b=float("$BASELINE_LAT")
    a=float("$AJUSTADO_LAT")
    print(f"{((b-a)/b)*100:.2f}%")
except Exception:
    print("N/A")
PY
)

echo "Baseline TPS: $BASELINE_TPS"
echo "Ajustado TPS: $AJUSTADO_TPS"
echo "Mejora TPS: $MEJORA_TPS"

echo "=== Crear matriz en Markdown ==="

cat > 05_matriz_parametros.md <<EOF
# Matriz de parámetros — Laboratorio 5

## Contexto

| Elemento | Valor |
|---|---|
| Fecha UTC | $(date -u +"%Y-%m-%dT%H:%M:%SZ") |
| Cluster | $AURORA_CLUSTER_ID |
| Endpoint | $AURORA_ENDPOINT |
| Base de prueba | pgbench_lab |
| Duración por prueba | 30 segundos |
| Clientes | 5 |
| Hilos | 2 |
| Escala pgbench | 5 |

---

## Parámetros evaluados

| Parámetro | Baseline | Ajustado | Alcance | Justificación |
|---|---:|---:|---|---|
| work_mem | Valor por defecto | 16MB | Sesión | Aumenta memoria disponible por operación de sort/hash. |
| effective_cache_size | Valor por defecto | 3GB | Sesión | Orienta al optimizador sobre caché efectiva estimada. |
| statement_timeout | Valor por defecto | 30s | Sesión | Protege la prueba contra sentencias colgadas. |
| default_statistics_target | Valor por defecto | 200 | Sesión | Permite estadísticas más detalladas antes del ANALYZE. |

---

## Resultados pgbench

| Métrica | Baseline | Ajustado | Cambio observado |
|---|---:|---:|---:|
| TPS | $BASELINE_TPS | $AJUSTADO_TPS | $MEJORA_TPS |
| Latencia promedio ms | $BASELINE_LAT | $AJUSTADO_LAT | $MEJORA_LAT |

---

## Observaciones

- Los resultados dependen de la región, clase de instancia, carga concurrente y estado del clúster.
- Estos ajustes fueron aplicados a nivel sesión mediante PGOPTIONS.
- No se modificaron DB parameter groups persistentes.
- Un incremento de TPS en pgbench no garantiza mejora para todas las cargas reales.
- Todo ajuste de parámetros debe validarse con métricas de aplicación y monitoreo operacional.

EOF

cat 05_matriz_parametros.md
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
ls -lh 05_matriz_parametros.md
cat 05_matriz_parametros.md
```

---

## 📌 Resultado esperado

Debes tener un archivo:

```text
05_matriz_parametros.md
```

Con una matriz de parámetros y resultados comparativos.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20documentar%20una%20matriz%20de%20par%C3%A1metros%20PostgreSQL%20con%20baseline%2C%20valor%20ajustado%2C%20justificaci%C3%B3n%20e%20impacto%20medido%20con%20pgbench.)

---

# 🧩 Reto 8. Validar estado final previo a limpieza

## ⏱️ Tiempo estimado

**2 minutos**

---

## 🎯 Objetivo del reto

Confirmar que las pruebas terminaron correctamente, que no quedan conexiones activas problemáticas a `pgbench_lab` y que los archivos de evidencia existen antes de limpiar.

---

## 🧠 Escenario

Antes de eliminar la base de benchmark, necesitas validar que terminaste las pruebas, que guardaste evidencia suficiente y que no hay sesiones activas que impidan el `DROP DATABASE`.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor esperado |
|---|---|
| Base de benchmark | `pgbench_lab` |
| Conexiones activas a `pgbench_lab` | `0` o terminables |
| Baseline | `05_pgbench_baseline.txt` |
| Prueba ajustada | `05_pgbench_ajustado.txt` |
| Matriz | `05_matriz_parametros.md` |
| Estado esperado del clúster | `available` |

---

## 🛠️ Tu reto

Realiza:

- Validación de la base `pgbench_lab`.
- Validación de conexiones activas.
- Validación de archivos de evidencia.
- Validación de estado del clúster.
- Confirmación de que estás listo para limpiar.

---

## 💡 Pistas

- `pg_stat_activity` muestra conexiones activas por base.
- No elimines todavía la base; la eliminación se realiza en el Reto 9.
- Si falta la matriz, vuelve al Reto 7 antes de limpiar.
- Si hay conexiones activas, se terminarán en el Reto 9.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Validar existencia de pgbench_lab ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT datname
      FROM pg_database
      WHERE datname = 'pgbench_lab';"

echo "=== Validar conexiones activas a pgbench_lab ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT
        pid,
        usename,
        state,
        application_name,
        now() - COALESCE(query_start, backend_start) AS duracion,
        left(query, 80) AS query
      FROM pg_stat_activity
      WHERE datname = 'pgbench_lab'
        AND pid <> pg_backend_pid()
      ORDER BY backend_start;"

echo "=== Validar evidencia local ==="

ls -lh \
  05_pgbench_init.txt \
  05_pgbench_baseline.txt \
  05_parametros_baseline.txt \
  05_analyze_ajustado.txt \
  05_pgbench_ajustado.txt \
  05_matriz_parametros.md

echo "=== Validar estado del clúster ==="

aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].Status" \
  --output text
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
ls -lh 05_pgbench_baseline.txt 05_pgbench_ajustado.txt 05_matriz_parametros.md

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS conexiones_pgbench_lab
      FROM pg_stat_activity
      WHERE datname = 'pgbench_lab'
        AND pid <> pg_backend_pid();"
```

---

## 📌 Resultado esperado

Debes ver:

```text
Archivos de evidencia creados
conexiones_pgbench_lab = 0
```

Si hay conexiones activas, el Reto 9 las terminará antes de eliminar la base.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20validar%20que%20una%20base%20de%20benchmark%20PostgreSQL%20est%C3%A1%20lista%20para%20limpieza%20revisando%20evidencias%2C%20conexiones%20activas%20y%20estado%20del%20cl%C3%BAster.)

---

# 🧩 Reto 9. Eliminar recursos del laboratorio

## ⏱️ Tiempo estimado

**2 minutos**

---

## 🎯 Objetivo del reto

Eliminar la base de prueba y confirmar que el ambiente quedó limpio.

---

## 🧠 Escenario

La práctica creó una base específica para benchmark. Al finalizar, debes eliminarla para evitar confusión con futuras prácticas, pero conservar los archivos de evidencia en CloudShell. Si el instructor solicita cerrar el ambiente completo, puedes ejecutar el script de eliminación de infraestructura.

---

## 🧱 Valores estandarizados del reto

| Recurso | Valor estándar | Acción |
|---|---|---|
| Base de benchmark | `pgbench_lab` | Eliminar con `DROP DATABASE` |
| Conexiones activas | `pg_stat_activity` | Terminar con `pg_terminate_backend` |
| Archivos de evidencia | `05_*` | Conservar como evidencia |
| Base administrativa | `postgres` | No eliminar |
| Clúster Aurora | `$AURORA_CLUSTER_ID` | No eliminar salvo instrucción del instructor |
| Script de eliminación | `00_eliminar_laboratorio_5_aurora.sh` | Usar solo si se eliminará infraestructura |

---

## 🛠️ Tu reto

Realiza:

- Cierre de conexiones activas a `pgbench_lab`.
- Eliminación de la base.
- Validación de limpieza.
- Listado de resultados generados.
- Ejecución opcional del script de eliminación de infraestructura si el instructor lo solicita.

---

## 💡 Pistas

- No puedes borrar una base si hay conexiones activas.
- Conéctate a `postgres` para borrar `pgbench_lab`.
- No elimines el clúster Aurora si será usado por laboratorios posteriores.
- No elimines los resultados del laboratorio.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Terminar conexiones activas a pgbench_lab ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT pg_terminate_backend(pid)
      FROM pg_stat_activity
      WHERE datname = 'pgbench_lab'
        AND pid <> pg_backend_pid();"

echo "=== Eliminar base pgbench_lab ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "DROP DATABASE IF EXISTS pgbench_lab;"

echo "=== Validar que la base fue eliminada ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT datname
      FROM pg_database
      WHERE datname = 'pgbench_lab';"

echo "=== Resultados conservados ==="

ls -lh 05_*
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=postgres user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT datname
      FROM pg_database
      WHERE datname = 'pgbench_lab';"
```

---

## 📌 Resultado esperado

Debe devolver:

```text
(0 rows)
```

Y los resultados deben permanecer en CloudShell:

```text
05_pgbench_init.txt
05_pgbench_baseline.txt
05_parametros_baseline.txt
05_analyze_ajustado.txt
05_pgbench_ajustado.txt
05_matriz_parametros.md
```

### Ejecutar script de eliminación de infraestructura

Si el instructor solicita eliminar también el clúster Aurora y los recursos AWS creados para esta práctica, ejecuta el script de eliminación desde AWS CloudShell:

```bash
chmod +x 00_eliminar_laboratorio_5_aurora.sh
./00_eliminar_laboratorio_5_aurora.sh
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20limpiar%20una%20base%20de%20benchmark%20pgbench%20en%20PostgreSQL%20sin%20eliminar%20la%20evidencia%20del%20laboratorio%20ni%20el%20cl%C3%BAster%20Aurora.)

---

# ✅ Validación final del laboratorio

Al finalizar la práctica, debes haber completado lo siguiente:

| Elemento | Estado esperado |
|---|---|
| CloudShell validado | Correcto |
| Variables `AURORA_*` | Definidas |
| Writer endpoint | Validado con `pg_is_in_recovery() = false` |
| Herramienta `psql` | Disponible |
| Herramienta `pgbench` | Disponible |
| Base `pgbench_lab` | Creada para pruebas |
| Datos `pgbench` | Inicializados con escala 5 |
| Baseline | Guardado |
| Parámetros actuales | Documentados |
| Ajustes de sesión | Aplicados con `PGOPTIONS` |
| Prueba ajustada | Ejecutada |
| Matriz de parámetros | Generada |
| Estado final previo a limpieza | Validado |
| Base `pgbench_lab` | Eliminada |
| Resultados | Conservados como evidencia |
| Limpieza de infraestructura | Ejecutada solo si el instructor la solicitó |

---

# 🧠 Resultado esperado de aprendizaje

Después de completar este laboratorio, debes poder explicar y ejecutar un flujo profesional de ajuste controlado de parámetros en Aurora PostgreSQL:

1. Validar conexión al writer.
2. Validar disponibilidad de `psql` y `pgbench`.
3. Preparar una base de benchmark.
4. Inicializar datos de prueba con `pgbench`.
5. Ejecutar una línea base con `pgbench`.
6. Revisar parámetros con `pg_settings`.
7. Aplicar ajustes seguros por sesión.
8. Repetir la prueba con las mismas condiciones.
9. Comparar TPS y latencia promedio.
10. Documentar los resultados en una matriz.
11. Evitar cambios permanentes sin evidencia suficiente.
12. Validar estado final previo a limpieza.
13. Limpiar recursos temporales.

---

# 📌 Resumen del laboratorio

En este laboratorio usaste AWS CloudShell y Aurora PostgreSQL para ejecutar un benchmark controlado con `pgbench`. Creaste una base de prueba, capturaste una línea base, revisaste parámetros relevantes de PostgreSQL y aplicaste ajustes seguros a nivel sesión usando `PGOPTIONS`. Después repetiste la prueba con las mismas condiciones, comparaste TPS y latencia, generaste una matriz técnica de resultados y validaste el estado final antes de limpiar. Finalmente, eliminaste la base temporal `pgbench_lab` sin aplicar cambios persistentes en DB parameter groups ni afectar el clúster para prácticas posteriores.
