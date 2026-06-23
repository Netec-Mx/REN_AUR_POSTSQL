<h1 align="center">📈 Laboratorio 3. Carga controlada y métricas operativas</h1>

---

## 1. 🧾 Información general de la práctica

## 📘 Descripción general

En este laboratorio vas a generar una carga controlada sobre **AWS Aurora PostgreSQL** desde **AWS CloudShell** para observar el comportamiento operativo de la base de datos durante actividad concurrente. Prepararás un esquema dedicado, crearás tablas de prueba, ejecutarás scripts de carga con Python, medirás tiempos de respuesta, observarás sesiones activas, revisarás estadísticas internas de PostgreSQL y guardarás resultados en archivos locales del laboratorio.

La práctica está diseñada como una serie de **retos guiados**. En cada reto primero intentarás resolver el objetivo con pistas. Si te bloqueas, podrás abrir la **solución sugerida**. La solución está oculta para fomentar el razonamiento, pero es completa y funcional para no extender el tiempo del laboratorio.

El enfoque principal es el ciclo básico de observabilidad operativa:

> **Preparar → Generar carga → Observar → Medir → Comparar → Registrar → Validar → Limpiar**

---

## 🎯 Objetivos de aprendizaje

Al finalizar este laboratorio, podrás:

- Usar AWS CloudShell para conectarte a un clúster Aurora PostgreSQL.
- Preparar un esquema dedicado para pruebas de carga controlada.
- Crear datos sintéticos para simular actividad transaccional.
- Ejecutar scripts Python con `psycopg2` contra Aurora PostgreSQL.
- Medir latencia promedio, mínima y máxima de operaciones SQL.
- Consultar sesiones activas con `pg_stat_activity`.
- Consultar métricas internas con `pg_stat_database`.
- Revisar actividad de tablas con `pg_stat_user_tables`.
- Identificar consultas activas y estados de sesión durante carga.
- Guardar resultados del laboratorio en archivos `.csv` y `.log`.
- Validar que no queden sesiones problemáticas ni bloqueos pendientes.
- Limpiar objetos temporales y recursos del laboratorio cuando corresponda.

---

## ✅ Prerrequisitos

Antes de iniciar, debes contar con:

- Ejecutar antes de comenzar el script `00_preparar_laboratorio_3_aurora.sh` desde **AWS CloudShell** o contar con un clúster Aurora PostgreSQL equivalente ya disponible.
- Acceso a una cuenta AWS.
- Permisos para usar AWS CloudShell.
- Permisos IAM para administrar o validar recursos de Amazon RDS/Aurora, EC2 Security Groups, VPC/Subnets, DB Subnet Groups y STS.
- Conectividad desde CloudShell hacia el endpoint writer de Aurora PostgreSQL.
- Cliente `psql` disponible en AWS CloudShell. El script previo lo instala si no existe.
- Python 3 disponible en AWS CloudShell.
- Paquete Python `psycopg2-binary` disponible. El script previo lo instala si no existe.
- Conocimientos básicos de SQL.
- Conocimientos básicos de Bash.
- Conocimiento conceptual de métricas, latencia, carga concurrente y sesiones activas.

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
| AWS CLI | Consulta de información del clúster |
| psql | Conexión y consultas contra Aurora PostgreSQL |
| jq | Procesamiento opcional de salidas JSON |
| Python 3 | Ejecución de scripts de carga |
| psycopg2-binary | Driver PostgreSQL para Python |
| Aurora PostgreSQL | Motor de base de datos del laboratorio |

---

## 🧱 Valores estandarizados del laboratorio

Usa estos valores durante toda la práctica para mantener consistencia entre los retos, las validaciones y la limpieza final.

| Tipo | Nombre / valor estándar | Uso |
|---|---|---|
| Región | `$AWS_REGION` | Región activa de AWS CLI o `us-west-2` como valor por defecto del script previo |
| Endpoint writer | `$AURORA_ENDPOINT` | Endpoint writer del clúster Aurora PostgreSQL |
| Puerto | `5432` | Puerto estándar PostgreSQL |
| Base de datos | `lab_performance` | Base creada o utilizada desde laboratorios anteriores |
| Usuario administrador | `labadmin` | Usuario master del laboratorio |
| Contraseña temporal | `AuroraLab_2026_Temporal!` | Contraseña de laboratorio, cámbiala si tu instructor lo solicita |
| Cluster ID | `aurora-performance-lab-cluster` | Identificador esperado si vienes de laboratorios anteriores |
| Directorio de trabajo | `$HOME/lab-02-00-02` | Carpeta base del laboratorio |
| Carpeta de scripts | `$HOME/lab-02-00-02/scripts` | Scripts SQL y Python |
| Carpeta de logs | `$HOME/lab-02-00-02/logs` | Archivos de salida del laboratorio |
| Carpeta de resultados | `$HOME/lab-02-00-02/results` | Resultados `.csv` |
| Esquema de laboratorio | `lab_load` | Esquema dedicado para carga controlada |
| Tabla de clientes | `lab_load.clientes` | Catálogo sintético de clientes |
| Tabla de eventos | `lab_load.eventos` | Tabla de escrituras durante carga |
| Tabla de resultados | `lab_load.resultados_carga` | Registro de métricas del laboratorio |
| Script SQL inicial | `03_setup_load.sql` | Crea esquema, tablas y datos base |
| Script Python de carga | `03_generar_carga.py` | Ejecuta operaciones concurrentes contra Aurora |
| Script de reporte | `03_reporte_metricas.sql` | Consulta métricas internas y resultados |

---

## 🚦 Preparación previa obligatoria antes de comenzar

Antes de iniciar el **Reto 1**, ejecuta el script de preparación desde **AWS CloudShell**. Este script crea o reutiliza los recursos mínimos requeridos para la práctica: VPC default, subnets, Security Group temporal, DB Subnet Group, clúster Aurora PostgreSQL, instancia writer, base `lab_performance`, dependencias Python y archivo de variables `lab3_aurora_env.sh`.

> ⚠️ **Costo y seguridad:** El script crea recursos que pueden generar cargos. Para facilitar el laboratorio desde CloudShell, el clúster se prepara con conectividad pública temporal y acceso TCP/5432 desde `0.0.0.0/0`. Usa esta configuración solo en laboratorio y elimina o restringe los recursos al terminar.

### Comandos de ejecución previa

```bash
chmod +x 00_preparar_laboratorio_3_aurora.sh
./00_preparar_laboratorio_3_aurora.sh
source ./lab3_aurora_env.sh
```

### Validación previa rápida

```bash
echo "$AURORA_ENDPOINT"
echo "$AURORA_DBNAME"
echo "$LAB_WORKDIR"

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;"
```

Resultado esperado:

```text
current_database = lab_performance
es_replica = f
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

---

## 🗓️ Distribución de tiempo por reto

| Reto | Actividad | Tiempo |
|---|---|---:|
| Reto 1 | Preparar CloudShell, variables y conexión | 3 min |
| Reto 2 | Crear esquema y datos base de carga | 5 min |
| Reto 3 | Capturar línea base de métricas internas | 4 min |
| Reto 4 | Crear script Python de carga controlada | 5 min |
| Reto 5 | Ejecutar carga y registrar resultados | 5 min |
| Reto 6 | Observar sesiones activas durante carga | 4 min |
| Reto 7 | Comparar métricas antes y después | 4 min |
| Reto 8 | Validar estado final previo a limpieza | 2 min |
| Reto 9 | Eliminar recursos del laboratorio | 3 min |
| **Total** |  | **35 min** |

> 💡 **Nota operativa:** Este laboratorio ejecuta carga controlada de baja intensidad. No aumentes la concurrencia ni el número de operaciones sin autorización del instructor, porque puedes generar costo, latencia o saturación innecesaria.

---

# 2. 🧪 Desarrollo de la práctica

---

# 🧩 Reto 1. Preparar CloudShell, variables y conexión

## ⏱️ Tiempo estimado

**3 minutos**

---

## 🎯 Objetivo del reto

Validar que AWS CloudShell esté listo, que las variables del laboratorio estén cargadas y que puedes conectarte al endpoint writer de Aurora PostgreSQL.

---

## 🧠 Escenario

Vas a ejecutar scripts SQL y Python contra Aurora PostgreSQL. Antes de generar carga, necesitas confirmar que estás conectado al writer endpoint, que el directorio de trabajo existe y que las herramientas requeridas están disponibles.

---

## 🧱 Valores estandarizados del reto

| Variable | Valor estándar |
|---|---|
| `AWS_REGION` | Región activa de AWS CLI o `us-west-2` como valor por defecto |
| `AURORA_ENDPOINT` | Endpoint writer de Aurora PostgreSQL |
| `AURORA_PORT` | `5432` |
| `AURORA_DBNAME` | `lab_performance` |
| `AURORA_MASTER_USER` | `labadmin` |
| `AURORA_MASTER_PASSWORD` | `AuroraLab_2026_Temporal!` |
| `AURORA_CLUSTER_ID` | `aurora-performance-lab-cluster` |
| `LAB_WORKDIR` | `$HOME/lab-02-00-02` |

---

## 🛠️ Tu reto

Desde AWS CloudShell, valida:

- Identidad AWS.
- Región activa.
- Disponibilidad de `psql`.
- Disponibilidad de Python 3.
- Disponibilidad de `psycopg2`.
- Variables de conexión.
- Conexión al writer endpoint.
- Directorios `scripts`, `logs` y `results`.

---

## 💡 Pistas

- Si ejecutaste el script previo, carga `lab3_aurora_env.sh`.
- El endpoint writer normalmente contiene `.cluster-`.
- `pg_is_in_recovery()` debe devolver `false` en el writer.
- Los scripts del laboratorio deben guardarse dentro de `$LAB_WORKDIR/scripts`.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Validar identidad AWS ==="
aws sts get-caller-identity --output table

echo "=== Cargar variables del laboratorio ==="
if [ -f "$HOME/lab-02-00-02/lab3_aurora_env.sh" ]; then
  source "$HOME/lab-02-00-02/lab3_aurora_env.sh"
else
  echo "ERROR: No se encontró $HOME/lab-02-00-02/lab3_aurora_env.sh"
  echo "Ejecuta primero 00_preparar_laboratorio_3_aurora.sh"
  exit 1
fi

echo "=== Validar herramientas ==="
psql --version
python3 --version

python3 - <<'PY'
import psycopg2
print("psycopg2 disponible")
PY

echo "=== Validar directorios ==="
mkdir -p "$LAB_WORKDIR/scripts" "$LAB_WORKDIR/logs" "$LAB_WORKDIR/results"
ls -ld "$LAB_WORKDIR" "$LAB_WORKDIR/scripts" "$LAB_WORKDIR/logs" "$LAB_WORKDIR/results"

echo "=== Variables requeridas ==="
echo "Endpoint: $AURORA_ENDPOINT"
echo "Puerto:   $AURORA_PORT"
echo "DB:       $AURORA_DBNAME"
echo "Usuario:  $AURORA_MASTER_USER"
echo "Workdir:  $LAB_WORKDIR"

echo "=== Probar conexión al writer ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
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

`f` significa que estás conectado a la instancia writer.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20preparar%20AWS%20CloudShell%20para%20ejecutar%20scripts%20Python%20y%20psql%20contra%20Aurora%20PostgreSQL%20validando%20variables%2C%20conexi%C3%B3n%20y%20pg_is_in_recovery.)

---

# 🧩 Reto 2. Crear esquema y datos base de carga

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Crear un esquema dedicado y tablas sintéticas para ejecutar carga controlada sin afectar otros objetos de la base de datos.

---

## 🧠 Escenario

Necesitas un conjunto pequeño de tablas para generar lecturas y escrituras controladas. El esquema `lab_load` permitirá aislar los objetos de este laboratorio y facilitar la limpieza final.

---

## 🧱 Valores estandarizados del reto

| Recurso | Valor estándar |
|---|---|
| Script SQL | `$LAB_WORKDIR/scripts/03_setup_load.sql` |
| Esquema | `lab_load` |
| Tabla de clientes | `lab_load.clientes` |
| Tabla de eventos | `lab_load.eventos` |
| Tabla de resultados | `lab_load.resultados_carga` |
| Índice clientes | `idx_clientes_email` |
| Índice eventos cliente | `idx_eventos_cliente_creado` |
| Registros en clientes | `5000` |
| Registros iniciales en eventos | `0` |

---

## 🛠️ Tu reto

Crea:

- Esquema `lab_load`.
- Tabla `lab_load.clientes`.
- Tabla `lab_load.eventos`.
- Tabla `lab_load.resultados_carga`.
- Índices de apoyo.
- Datos sintéticos de clientes.
- Estadísticas con `ANALYZE`.

---

## 💡 Pistas

- Usa `generate_series` para crear clientes.
- La tabla `eventos` recibirá escrituras durante la carga.
- La tabla `resultados_carga` guardará métricas resumidas de cada ejecución.
- Evita usar el esquema `public`.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
cat > "$LAB_WORKDIR/scripts/03_setup_load.sql" <<'SQL'
CREATE SCHEMA IF NOT EXISTS lab_load;

DROP TABLE IF EXISTS lab_load.eventos;
DROP TABLE IF EXISTS lab_load.resultados_carga;
DROP TABLE IF EXISTS lab_load.clientes;

CREATE TABLE lab_load.clientes (
    id          integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    email       text NOT NULL UNIQUE,
    nombre      text NOT NULL,
    segmento    text NOT NULL,
    creado_en   timestamptz DEFAULT now()
);

CREATE TABLE lab_load.eventos (
    id          bigserial PRIMARY KEY,
    cliente_id  integer NOT NULL REFERENCES lab_load.clientes(id),
    tipo_evento text NOT NULL,
    monto       numeric(10,2),
    creado_en   timestamptz DEFAULT now()
);

CREATE TABLE lab_load.resultados_carga (
    id                  bigserial PRIMARY KEY,
    escenario           text NOT NULL,
    operaciones         integer NOT NULL,
    concurrencia        integer NOT NULL,
    duracion_segundos   numeric(12,3) NOT NULL,
    latencia_prom_ms    numeric(12,3) NOT NULL,
    latencia_min_ms     numeric(12,3) NOT NULL,
    latencia_max_ms     numeric(12,3) NOT NULL,
    registrado_en       timestamptz DEFAULT now()
);

CREATE INDEX idx_clientes_email
ON lab_load.clientes (email);

CREATE INDEX idx_eventos_cliente_creado
ON lab_load.eventos (cliente_id, creado_en DESC);

INSERT INTO lab_load.clientes (email, nombre, segmento)
SELECT
    'cliente_' || gs || '@example.com',
    'Cliente ' || gs,
    (ARRAY['retail','pyme','enterprise'])[1 + (random()*2)::int]
FROM generate_series(1, 5000) AS gs;

ANALYZE lab_load.clientes;
ANALYZE lab_load.eventos;
ANALYZE lab_load.resultados_carga;

SELECT 'clientes' AS tabla, count(*) AS total FROM lab_load.clientes
UNION ALL
SELECT 'eventos' AS tabla, count(*) AS total FROM lab_load.eventos
UNION ALL
SELECT 'resultados_carga' AS tabla, count(*) AS total FROM lab_load.resultados_carga;
SQL

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -f "$LAB_WORKDIR/scripts/03_setup_load.sql"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT schemaname, relname AS tabla, n_live_tup AS filas_estimadas
      FROM pg_stat_user_tables
      WHERE schemaname = 'lab_load'
      ORDER BY relname;"
```

---

## 📌 Resultado esperado

Debes ver aproximadamente:

```text
clientes            5000
eventos             0
resultados_carga    0
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20preparar%20tablas%20de%20laboratorio%20para%20generar%20carga%20controlada%20en%20Aurora%20PostgreSQL%20usando%20un%20esquema%20dedicado%2C%20datos%20sint%C3%A9ticos%20e%20%C3%ADndices.)

---

# 🧩 Reto 3. Capturar línea base de métricas internas

## ⏱️ Tiempo estimado

**4 minutos**

---

## 🎯 Objetivo del reto

Capturar una línea base de métricas internas antes de ejecutar la carga controlada.

---

## 🧠 Escenario

Antes de generar actividad, necesitas guardar una referencia del estado actual de la base de datos. Esta línea base permitirá comparar transacciones, lecturas, filas insertadas y actividad de tablas después de la prueba.

---

## 🛠️ Tu reto

Consulta y guarda:

- Estadísticas de base de datos con `pg_stat_database`.
- Estadísticas de tablas del esquema `lab_load`.
- Sesiones activas antes de la carga.
- Bloqueos pendientes antes de la carga.

---

## 💡 Pistas

- `pg_stat_database` muestra contadores acumulados por base de datos.
- `pg_stat_user_tables` muestra actividad acumulada por tabla.
- Los contadores son acumulativos, por eso debes comparar antes y después.
- Guarda salidas en `$LAB_WORKDIR/results`.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Línea base pg_stat_database ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT
          datname,
          xact_commit,
          xact_rollback,
          blks_read,
          blks_hit,
          tup_returned,
          tup_fetched,
          tup_inserted,
          tup_updated,
          tup_deleted,
          deadlocks,
          temp_files,
          temp_bytes
      FROM pg_stat_database
      WHERE datname = current_database();" \
  | tee "$LAB_WORKDIR/results/03_linea_base_pg_stat_database.txt"

echo "=== Línea base pg_stat_user_tables ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT
          schemaname,
          relname,
          seq_scan,
          idx_scan,
          n_tup_ins,
          n_tup_upd,
          n_tup_del,
          n_live_tup,
          n_dead_tup
      FROM pg_stat_user_tables
      WHERE schemaname = 'lab_load'
      ORDER BY relname;" \
  | tee "$LAB_WORKDIR/results/03_linea_base_pg_stat_user_tables.txt"

echo "=== Sesiones activas antes de carga ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT
          pid,
          usename,
          application_name,
          state,
          wait_event_type,
          wait_event,
          left(query, 80) AS query_truncada
      FROM pg_stat_activity
      WHERE datname = current_database()
        AND pid <> pg_backend_pid()
      ORDER BY state, pid;" \
  | tee "$LAB_WORKDIR/results/03_linea_base_sesiones.txt"

echo "=== Bloqueos pendientes antes de carga ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS bloqueos_pendientes
      FROM pg_locks
      WHERE NOT granted;"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
ls -lh "$LAB_WORKDIR/results"/03_linea_base_*.txt
```

---

## 📌 Resultado esperado

Debes ver archivos similares a:

```text
03_linea_base_pg_stat_database.txt
03_linea_base_pg_stat_user_tables.txt
03_linea_base_sesiones.txt
```

También se espera:

```text
bloqueos_pendientes = 0
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20capturar%20una%20l%C3%ADnea%20base%20de%20m%C3%A9tricas%20internas%20en%20PostgreSQL%20usando%20pg_stat_database%2C%20pg_stat_user_tables%20y%20pg_stat_activity.)

---

# 🧩 Reto 4. Crear script Python de carga controlada

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Crear un script Python que ejecute operaciones controladas de lectura y escritura contra Aurora PostgreSQL y calcule métricas básicas de latencia.

---

## 🧠 Escenario

Para analizar comportamiento operativo necesitas una carga repetible. El script realizará búsquedas por cliente e inserciones de eventos, medirá cada operación y guardará un resumen dentro de la tabla `lab_load.resultados_carga`.

---

## 🛠️ Tu reto

Crea un script que:

- Use variables de ambiente para conectarse.
- Ejecute operaciones con concurrencia controlada.
- Mida latencia por operación.
- Inserte eventos en `lab_load.eventos`.
- Consulte clientes por email.
- Registre resumen en `lab_load.resultados_carga`.
- Genere un archivo CSV local con latencias.

---

## 💡 Pistas

- Usa `os.environ` para leer variables.
- Usa `ThreadPoolExecutor` para concurrencia simple.
- Mantén la carga baja.
- Usa `time.perf_counter()` para medir duración.
- Cierra conexiones correctamente.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
cat > "$LAB_WORKDIR/scripts/03_generar_carga.py" <<'PY'
import csv
import os
import random
import statistics
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

import psycopg2

HOST = os.environ["AURORA_ENDPOINT"]
PORT = os.environ.get("AURORA_PORT", "5432")
DBNAME = os.environ.get("AURORA_DBNAME", "lab_performance")
USER = os.environ["AURORA_MASTER_USER"]
PASSWORD = os.environ["AURORA_MASTER_PASSWORD"]
LAB_WORKDIR = os.environ.get("LAB_WORKDIR", os.path.expanduser("~/lab-02-00-02"))

OPERACIONES = int(os.environ.get("LAB3_OPERACIONES", "80"))
CONCURRENCIA = int(os.environ.get("LAB3_CONCURRENCIA", "4"))
ESCENARIO = os.environ.get("LAB3_ESCENARIO", "carga_controlada_baja")

CSV_PATH = os.path.join(LAB_WORKDIR, "results", "03_latencias_carga.csv")

def conectar():
    return psycopg2.connect(
        host=HOST,
        port=PORT,
        dbname=DBNAME,
        user=USER,
        password=PASSWORD,
        sslmode="require",
        application_name="lab3_carga_controlada",
    )

def ejecutar_operacion(i: int):
    inicio = time.perf_counter()
    cliente_id = random.randint(1, 5000)
    tipo_evento = random.choice(["consulta", "compra", "navegacion", "soporte"])
    monto = round(random.uniform(10, 500), 2)

    conn = conectar()
    try:
        with conn:
            with conn.cursor() as cur:
                if i % 2 == 0:
                    email = f"cliente_{cliente_id}@example.com"
                    cur.execute(
                        """
                        SELECT id, email, segmento
                        FROM lab_load.clientes
                        WHERE email = %s
                        """,
                        (email,),
                    )
                    cur.fetchone()
                    operacion = "select_cliente"
                else:
                    cur.execute(
                        """
                        INSERT INTO lab_load.eventos (cliente_id, tipo_evento, monto)
                        VALUES (%s, %s, %s)
                        """,
                        (cliente_id, tipo_evento, monto),
                    )
                    operacion = "insert_evento"
    finally:
        conn.close()

    fin = time.perf_counter()
    latencia_ms = (fin - inicio) * 1000
    return {
        "operacion_id": i,
        "tipo_operacion": operacion,
        "latencia_ms": round(latencia_ms, 3),
    }

def main():
    os.makedirs(os.path.dirname(CSV_PATH), exist_ok=True)

    resultados = []
    inicio_total = time.perf_counter()

    with ThreadPoolExecutor(max_workers=CONCURRENCIA) as executor:
        futures = [executor.submit(ejecutar_operacion, i) for i in range(1, OPERACIONES + 1)]

        for future in as_completed(futures):
            resultados.append(future.result())

    fin_total = time.perf_counter()
    duracion = fin_total - inicio_total

    latencias = [r["latencia_ms"] for r in resultados]
    lat_prom = statistics.mean(latencias)
    lat_min = min(latencias)
    lat_max = max(latencias)

    resultados.sort(key=lambda r: r["operacion_id"])

    with open(CSV_PATH, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["operacion_id", "tipo_operacion", "latencia_ms"])
        writer.writeheader()
        writer.writerows(resultados)

    conn = conectar()
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO lab_load.resultados_carga
                    (escenario, operaciones, concurrencia, duracion_segundos,
                     latencia_prom_ms, latencia_min_ms, latencia_max_ms)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        ESCENARIO,
                        OPERACIONES,
                        CONCURRENCIA,
                        round(duracion, 3),
                        round(lat_prom, 3),
                        round(lat_min, 3),
                        round(lat_max, 3),
                    ),
                )
    finally:
        conn.close()

    print("=== Resultado de carga controlada ===")
    print(f"Escenario:          {ESCENARIO}")
    print(f"Operaciones:        {OPERACIONES}")
    print(f"Concurrencia:       {CONCURRENCIA}")
    print(f"Duración segundos:  {duracion:.3f}")
    print(f"Latencia prom ms:   {lat_prom:.3f}")
    print(f"Latencia min ms:    {lat_min:.3f}")
    print(f"Latencia max ms:    {lat_max:.3f}")
    print(f"CSV generado:       {CSV_PATH}")

if __name__ == "__main__":
    main()
PY

python3 -m py_compile "$LAB_WORKDIR/scripts/03_generar_carga.py"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
python3 -m py_compile "$LAB_WORKDIR/scripts/03_generar_carga.py"
ls -lh "$LAB_WORKDIR/scripts/03_generar_carga.py"
```

---

## 📌 Resultado esperado

Debes ver que el script compila sin errores y que el archivo existe:

```text
03_generar_carga.py
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20crear%20un%20script%20Python%20con%20psycopg2%20para%20generar%20carga%20controlada%20en%20Aurora%20PostgreSQL%20midiendo%20latencia%20por%20operaci%C3%B3n.)

---

# 🧩 Reto 5. Ejecutar carga y registrar resultados

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Ejecutar la carga controlada y registrar resultados tanto en la base de datos como en archivos locales.

---

## 🧠 Escenario

Ya tienes las tablas y el script de carga. Ahora ejecutarás un escenario de baja concurrencia para generar actividad observable sin saturar el clúster.

---

## 🛠️ Tu reto

Ejecuta:

- Carga con 80 operaciones.
- Concurrencia de 4 hilos.
- Registro de latencias en CSV.
- Inserción de resumen en `lab_load.resultados_carga`.
- Validación de filas insertadas en `lab_load.eventos`.

---

## 💡 Pistas

- No aumentes la concurrencia sin indicación del instructor.
- Usa variables `LAB3_OPERACIONES` y `LAB3_CONCURRENCIA`.
- Guarda la salida del script en `$LAB_WORKDIR/logs`.
- Revisa la tabla `resultados_carga`.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Ejecutar carga controlada ==="

export LAB3_OPERACIONES=80
export LAB3_CONCURRENCIA=4
export LAB3_ESCENARIO="carga_controlada_baja"

python3 "$LAB_WORKDIR/scripts/03_generar_carga.py" \
  | tee "$LAB_WORKDIR/logs/03_ejecucion_carga.log"

echo "=== Validar resultados registrados ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT
          id,
          escenario,
          operaciones,
          concurrencia,
          duracion_segundos,
          latencia_prom_ms,
          latencia_min_ms,
          latencia_max_ms,
          registrado_en
      FROM lab_load.resultados_carga
      ORDER BY id DESC
      LIMIT 5;"

echo "=== Validar eventos insertados ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS eventos_generados
      FROM lab_load.eventos;"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
ls -lh "$LAB_WORKDIR/results/03_latencias_carga.csv" "$LAB_WORKDIR/logs/03_ejecucion_carga.log"

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS resultados_registrados
      FROM lab_load.resultados_carga;"
```

---

## 📌 Resultado esperado

Debes observar:

```text
03_latencias_carga.csv
03_ejecucion_carga.log
resultados_registrados >= 1
eventos_generados > 0
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20ejecutar%20una%20carga%20controlada%20contra%20Aurora%20PostgreSQL%20con%20Python%2C%20registrar%20latencias%20en%20CSV%20y%20guardar%20un%20resumen%20en%20una%20tabla.)

---

# 🧩 Reto 6. Observar sesiones activas durante carga

## ⏱️ Tiempo estimado

**4 minutos**

---

## 🎯 Objetivo del reto

Observar sesiones activas de Aurora PostgreSQL mientras se ejecuta una carga controlada.

---

## 🧠 Escenario

Durante una prueba de carga, necesitas identificar conexiones activas, estado de sesiones, eventos de espera y consultas en ejecución. Esto ayuda a diferenciar actividad normal de esperas anómalas.

---

## 🛠️ Tu reto

Ejecuta una carga más lenta y, en paralelo, observa:

- Sesiones con `application_name = 'lab3_carga_controlada'`.
- Estado de cada sesión.
- Eventos de espera.
- Consultas truncadas.
- Cantidad de conexiones activas.

---

## 💡 Pistas

- Abre dos pestañas de CloudShell.
- En la primera pestaña ejecuta carga.
- En la segunda pestaña observa `pg_stat_activity`.
- El script usa `application_name='lab3_carga_controlada'`.

---

<details>
<summary>✅ Ver solución sugerida</summary>

### Terminal 1 — Ejecutar carga

```bash
export LAB3_OPERACIONES=1500
export LAB3_CONCURRENCIA=4
export LAB3_ESCENARIO="observacion_sesiones"

python3 "$LAB_WORKDIR/scripts/03_generar_carga.py" \
  | tee "$LAB_WORKDIR/logs/03_observacion_sesiones.log"
```

### Terminal 2 — Observar sesiones

Ejecuta varias veces mientras corre la carga:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT
          pid,
          application_name,
          state,
          wait_event_type,
          wait_event,
          now() - query_start AS duracion_query,
          left(query, 100) AS query
      FROM pg_stat_activity
      WHERE datname = current_database()
        AND application_name = 'lab3_carga_controlada'
      ORDER BY pid;"
```

Consulta resumida:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT
          application_name,
          state,
          count(*) AS sesiones
      FROM pg_stat_activity
      WHERE datname = current_database()
        AND application_name = 'lab3_carga_controlada'
      GROUP BY application_name, state
      ORDER BY application_name, state;"
```

</details>

---

## 🔍 Validación

Ejecuta durante la carga:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS sesiones_lab3
      FROM pg_stat_activity
      WHERE datname = current_database()
        AND application_name = 'lab3_carga_controlada';"
```

---

## 📌 Resultado esperado

Durante la ejecución, puedes observar sesiones asociadas a la aplicación:

```text
application_name = lab3_carga_controlada
```

Al finalizar la carga, el conteo de sesiones puede regresar a `0`.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20observar%20sesiones%20activas%20en%20PostgreSQL%20durante%20una%20carga%20controlada%20usando%20pg_stat_activity%20y%20application_name.)

---

# 🧩 Reto 7. Comparar métricas antes y después

## ⏱️ Tiempo estimado

**4 minutos**

---

## 🎯 Objetivo del reto

Comparar métricas internas después de la carga y generar un reporte operativo básico.

---

## 🧠 Escenario

Después de ejecutar carga, debes verificar que las métricas internas reflejan actividad: commits, tuplas insertadas, consultas con índice, lecturas y cambios en tablas del esquema `lab_load`.

---

## 🛠️ Tu reto

Crea un reporte que muestre:

- Estadísticas actuales de la base de datos.
- Estadísticas actuales de tablas `lab_load`.
- Resultados de carga registrados.
- Conteo de eventos generados.
- Últimas latencias registradas en CSV.

---

## 💡 Pistas

- Compara manualmente contra los archivos de línea base del Reto 3.
- `n_tup_ins` debe aumentar para la tabla `eventos`.
- `resultados_carga` debe contener al menos un registro.
- `idx_scan` puede aumentar por búsquedas de email.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
cat > "$LAB_WORKDIR/scripts/03_reporte_metricas.sql" <<'SQL'
\echo '=== Métricas actuales pg_stat_database ==='
SELECT
    datname,
    xact_commit,
    xact_rollback,
    blks_read,
    blks_hit,
    tup_returned,
    tup_fetched,
    tup_inserted,
    tup_updated,
    tup_deleted,
    deadlocks,
    temp_files,
    temp_bytes
FROM pg_stat_database
WHERE datname = current_database();

\echo '=== Métricas actuales pg_stat_user_tables ==='
SELECT
    schemaname,
    relname,
    seq_scan,
    idx_scan,
    n_tup_ins,
    n_tup_upd,
    n_tup_del,
    n_live_tup,
    n_dead_tup
FROM pg_stat_user_tables
WHERE schemaname = 'lab_load'
ORDER BY relname;

\echo '=== Resultados de carga registrados ==='
SELECT
    id,
    escenario,
    operaciones,
    concurrencia,
    duracion_segundos,
    latencia_prom_ms,
    latencia_min_ms,
    latencia_max_ms,
    registrado_en
FROM lab_load.resultados_carga
ORDER BY id DESC
LIMIT 10;

\echo '=== Eventos generados ==='
SELECT count(*) AS eventos_generados
FROM lab_load.eventos;

\echo '=== Distribución de tipos de evento ==='
SELECT tipo_evento, count(*) AS total
FROM lab_load.eventos
GROUP BY tipo_evento
ORDER BY total DESC;
SQL

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -f "$LAB_WORKDIR/scripts/03_reporte_metricas.sql" \
  | tee "$LAB_WORKDIR/results/03_reporte_metricas_final.txt"

echo "=== Primeras latencias registradas ==="
head -n 10 "$LAB_WORKDIR/results/03_latencias_carga.csv"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
ls -lh "$LAB_WORKDIR/results/03_reporte_metricas_final.txt"

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS resultados_registrados
      FROM lab_load.resultados_carga;"
```

---

## 📌 Resultado esperado

Debes observar:

```text
resultados_registrados >= 1
eventos_generados > 0
03_reporte_metricas_final.txt
```

El reporte debe mostrar que hubo actividad transaccional después de la carga.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20comparar%20m%C3%A9tricas%20antes%20y%20despu%C3%A9s%20de%20una%20carga%20controlada%20en%20PostgreSQL%20usando%20pg_stat_database%2C%20pg_stat_user_tables%20y%20resultados%20de%20latencia.)

---

# 🧩 Reto 8. Validar estado final previo a limpieza

## ⏱️ Tiempo estimado

**2 minutos**

---

## 🎯 Objetivo del reto

Confirmar que no quedan bloqueos pendientes ni sesiones activas problemáticas antes de eliminar los objetos del laboratorio.

---

## 🧠 Escenario

Después de ejecutar carga con múltiples conexiones, es importante validar que las conexiones se cerraron correctamente, que no quedan sesiones `idle in transaction` y que no hay bloqueos pendientes.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor estándar |
|---|---|
| Base de datos | `$AURORA_DBNAME` |
| Esquema validado | `lab_load` |
| Estado esperado de bloqueos pendientes | `0` |
| Estado esperado de sesiones `idle in transaction` | `0` |
| Aplicación del laboratorio | `lab3_carga_controlada` |

---

## 🛠️ Tu reto

Realiza:

- Validación de bloqueos pendientes.
- Validación de sesiones `idle in transaction`.
- Validación de sesiones activas del script de carga.
- Confirmación de que el esquema `lab_load` todavía existe antes de limpiarlo en el siguiente reto.

---

## 💡 Pistas

- Si alguna sesión quedó abierta, espera unos segundos y vuelve a validar.
- `pg_locks` permite confirmar locks pendientes con `granted = false`.
- `pg_stat_activity` permite detectar sesiones `idle in transaction`.
- No elimines todavía el esquema; la eliminación se realiza en el Reto 9.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Validar bloqueos pendientes ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS bloqueos_pendientes
      FROM pg_locks
      WHERE NOT granted;"

echo "=== Validar sesiones idle in transaction ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS idle_in_tx
      FROM pg_stat_activity
      WHERE state = 'idle in transaction'
        AND datname = current_database();"

echo "=== Validar sesiones activas del laboratorio ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS sesiones_lab3
      FROM pg_stat_activity
      WHERE datname = current_database()
        AND application_name = 'lab3_carga_controlada';"

echo "=== Validar esquema lab_load ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT schema_name
      FROM information_schema.schemata
      WHERE schema_name = 'lab_load';"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS bloqueos_pendientes
      FROM pg_locks
      WHERE NOT granted;"

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS idle_in_tx
      FROM pg_stat_activity
      WHERE state = 'idle in transaction'
        AND datname = current_database();"
```

---

## 📌 Resultado esperado

Debes ver:

```text
bloqueos_pendientes = 0
idle_in_tx = 0
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20validar%20que%20no%20quedan%20bloqueos%20pendientes%20ni%20sesiones%20idle%20in%20transaction%20despu%C3%A9s%20de%20una%20prueba%20de%20carga%20en%20PostgreSQL.)

---

# 🧩 Reto 9. Eliminar recursos del laboratorio

## ⏱️ Tiempo estimado

**3 minutos**

---

## 🎯 Objetivo del reto

Eliminar los objetos creados exclusivamente para este laboratorio y confirmar que el ambiente quedó limpio.

---

## 🧠 Escenario

Este laboratorio utiliza un clúster Aurora PostgreSQL creado o reutilizado por el script previo. La limpieza principal debe enfocarse en el esquema `lab_load`, los archivos locales del laboratorio y, si el instructor lo solicita, la infraestructura AWS creada para la práctica.

---

## 🧱 Valores estandarizados del reto

| Recurso | Valor estándar | Acción |
|---|---|---|
| Esquema | `lab_load` | Eliminar con `DROP SCHEMA ... CASCADE` |
| Tabla | `lab_load.clientes` | Se elimina junto con el esquema |
| Tabla | `lab_load.eventos` | Se elimina junto con el esquema |
| Tabla | `lab_load.resultados_carga` | Se elimina junto con el esquema |
| Índice | `idx_clientes_email` | Se elimina junto con la tabla `clientes` |
| Índice | `idx_eventos_cliente_creado` | Se elimina junto con la tabla `eventos` |
| Base de datos | `lab_performance` | No eliminar en la limpieza lógica |
| Clúster Aurora | `$AURORA_CLUSTER_ID` | Eliminar solo con script de infraestructura si el instructor lo solicita |

---

## 🛠️ Tu reto

Realiza:

- Eliminación del esquema `lab_load`.
- Validación de que el esquema ya no existe.
- Validación final de bloqueos pendientes.
- Confirmación de que la base `lab_performance` sigue disponible.
- Ejecución opcional del script de eliminación de infraestructura si el instructor lo solicita.

---

## 💡 Pistas

- `DROP SCHEMA IF EXISTS lab_load CASCADE` elimina tablas, índices y dependencias dentro del esquema.
- Primero limpia objetos de base de datos.
- No elimines infraestructura AWS si el instructor quiere reutilizar el clúster en otro laboratorio.
- Si vas a eliminar infraestructura, usa el script Bash entregado para esta práctica.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Eliminar esquema del laboratorio 3 ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "DROP SCHEMA IF EXISTS lab_load CASCADE;"

echo "=== Validar que el esquema fue eliminado ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT schema_name
      FROM information_schema.schemata
      WHERE schema_name = 'lab_load';"

echo "=== Validar que no quedan bloqueos pendientes ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS bloqueos_pendientes
      FROM pg_locks
      WHERE NOT granted;"

echo "=== Confirmar base activa ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT current_database(), current_user, now() AS validado_en;"
```

### Ejecutar script de eliminación de infraestructura

Si el instructor solicita eliminar también el clúster Aurora y los recursos AWS creados para esta práctica, ejecuta el script de eliminación desde AWS CloudShell:

```bash
chmod +x 00_eliminar_laboratorio_3_aurora.sh
./00_eliminar_laboratorio_3_aurora.sh
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT schema_name
      FROM information_schema.schemata
      WHERE schema_name = 'lab_load';"
```

---

## 📌 Resultado esperado

La consulta del esquema no debe devolver filas:

```text
(0 rows)
```

También debes confirmar:

```text
bloqueos_pendientes = 0
Base lab_performance disponible
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20eliminar%20objetos%20temporales%20de%20un%20laboratorio%20PostgreSQL%20con%20DROP%20SCHEMA%20CASCADE%20y%20cu%C3%A1ndo%20conviene%20eliminar%20tambi%C3%A9n%20la%20infraestructura%20Aurora%20con%20un%20script%20Bash.)

---

# ✅ Validación final del laboratorio

Al finalizar la práctica, debes haber completado lo siguiente:

| Elemento | Estado esperado |
|---|---|
| CloudShell validado | Correcto |
| Conexión al writer endpoint | Correcta |
| Python 3 validado | Correcto |
| `psycopg2` validado | Correcto |
| Esquema `lab_load` | Creado y eliminado |
| Tabla `clientes` | Creada para datos sintéticos |
| Tabla `eventos` | Creada para escrituras de carga |
| Tabla `resultados_carga` | Creada para métricas resumidas |
| Línea base de métricas internas | Capturada |
| Script Python de carga | Creado y validado |
| Carga controlada | Ejecutada |
| Latencias CSV | Generadas |
| Sesiones activas | Observadas con `pg_stat_activity` |
| Métricas antes/después | Comparadas |
| Bloqueos pendientes | 0 |
| Sesiones `idle in transaction` | 0 |
| Limpieza de objetos del laboratorio | Completada |

---

# 🧠 Resultado esperado de aprendizaje

Después de completar este laboratorio, debes poder explicar y ejecutar el flujo básico de generación de carga controlada y observación operativa en Aurora PostgreSQL:

1. Validar conexión al writer.
2. Preparar tablas de prueba.
3. Capturar una línea base de métricas internas.
4. Crear un script Python con `psycopg2`.
5. Ejecutar operaciones concurrentes controladas.
6. Medir latencia por operación.
7. Guardar resultados en CSV.
8. Registrar métricas resumidas en una tabla.
9. Observar sesiones activas con `pg_stat_activity`.
10. Comparar métricas antes y después.
11. Validar estado final sin bloqueos ni sesiones problemáticas.
12. Eliminar objetos temporales del esquema `lab_load`.

---

# 📌 Resumen del laboratorio

En este laboratorio trabajaste con AWS CloudShell y Aurora PostgreSQL para generar una carga controlada y observar métricas operativas de la base de datos. Preparaste un esquema dedicado, cargaste clientes sintéticos, creaste un script Python con `psycopg2`, ejecutaste operaciones concurrentes de lectura y escritura, mediste latencias, registraste resultados en una tabla y generaste reportes locales. Finalmente, comparaste métricas internas antes y después de la carga, validaste que no quedaran bloqueos pendientes ni sesiones `idle in transaction`, y eliminaste los objetos temporales del esquema `lab_load`.
