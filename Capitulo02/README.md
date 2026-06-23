<h1 align="center">🔒 Laboratorio 2. Análisis de sesiones y bloqueos</h1>

---

## 1. 🧾 Información general de la práctica

## 📘 Descripción general

En este laboratorio vas a diagnosticar escenarios controlados de bloqueo en **AWS Aurora PostgreSQL** usando varias sesiones `psql` desde **AWS CloudShell**. Crearás tablas de prueba, simularás bloqueos de fila, identificarás sesiones bloqueadas con `pg_stat_activity`, `pg_locks` y `pg_blocking_pids()`, probarás patrones seguros como `NOWAIT` y `SKIP LOCKED`, y configurarás timeouts de sesión para evitar esperas indefinidas.

La práctica está diseñada como una serie de **retos guiados**. En cada reto primero intentarás resolver el objetivo con pistas. Si te bloqueas, podrás abrir la **solución sugerida**. La solución está oculta para fomentar el razonamiento, pero es completa y funcional para no extender el tiempo del laboratorio.

El enfoque principal es el ciclo básico de diagnóstico de bloqueos:

> **Observar → Bloquear → Diagnosticar → Resolver → Prevenir → Validar → Limpiar**

---

## 🎯 Objetivos de aprendizaje

Al finalizar este laboratorio, podrás:

- Usar AWS CloudShell para conectarte a un clúster Aurora PostgreSQL.
- Consultar sesiones activas con `pg_stat_activity`.
- Identificar bloqueos con `pg_locks`.
- Detectar procesos bloqueadores con `pg_blocking_pids()`.
- Simular una transacción bloqueante con dos sesiones `psql`.
- Resolver bloqueos usando `COMMIT` y `ROLLBACK`.
- Usar `FOR UPDATE NOWAIT` para fallar rápido ante una fila bloqueada.
- Usar `FOR UPDATE SKIP LOCKED` para procesar colas sin colisiones.
- Configurar `lock_timeout`, `statement_timeout` e `idle_in_transaction_session_timeout` a nivel sesión.
- Detectar sesiones `idle in transaction`.
- Limpiar objetos y validar que el ambiente quedó estable.

---

## ✅ Prerrequisitos

Antes de iniciar, debes contar con:

- Ejecutar antes de comenzar el script `00_preparar_laboratorio_2_aurora.sh` desde **AWS CloudShell** o contar con un clúster Aurora PostgreSQL equivalente ya disponible.
- Acceso a una cuenta AWS.
- Permisos para usar AWS CloudShell.
- Permisos IAM para administrar o validar recursos de Amazon RDS/Aurora, EC2 Security Groups, VPC/Subnets, DB Subnet Groups y STS.
- Conectividad desde CloudShell hacia el endpoint writer de Aurora PostgreSQL.
- Cliente `psql` disponible en AWS CloudShell. El script previo lo instala si no existe.
- Conocimientos básicos de SQL.
- Conocimientos básicos de transacciones:
  - `BEGIN`
  - `COMMIT`
  - `ROLLBACK`
- Conocimiento conceptual de bloqueos, concurrencia y MVCC.

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
| psql | Sesiones concurrentes contra Aurora PostgreSQL |
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
| Base de datos | `lab_performance` | Base creada o utilizada desde el Laboratorio 1 |
| Usuario administrador | `labadmin` | Usuario master del laboratorio |
| Contraseña temporal | `AuroraLab_2026_Temporal!` | Contraseña de laboratorio, cámbiala si tu instructor lo solicita |
| Cluster ID | `aurora-performance-lab-cluster` | Identificador esperado si vienes del Laboratorio 1 |
| Esquema de laboratorio | `lab_locking` | Esquema dedicado para sesiones y bloqueos |
| Tabla de bloqueo de fila | `lab_locking.pedidos` | Tabla para simular bloqueos con `UPDATE` |
| Tabla de cola de trabajo | `lab_locking.trabajos` | Tabla para probar `SKIP LOCKED` |
| Índice pedidos | `idx_pedidos_estado` | Índice de apoyo para consultas por estado |
| Índice trabajos | `idx_trabajos_estado_id` | Índice de apoyo para cola de trabajos |
| Fila bloqueada principal | `pedidos.id = 1` | Escenario base de bloqueo controlado |
| Fila para `NOWAIT` | `pedidos.id = 5` | Escenario de falla rápida |
| Fila para timeout | `pedidos.id = 10` | Escenario de `lock_timeout` |

---

## 🚦 Preparación previa obligatoria antes de comenzar

Antes de iniciar el **Reto 1**, ejecuta el script de preparación desde **AWS CloudShell**. Este script crea o reutiliza los recursos mínimos requeridos para la práctica: VPC default, subnets, Security Group temporal, DB Subnet Group, clúster Aurora PostgreSQL, instancia writer, base `lab_performance` y archivo de variables `lab2_aurora_env.sh`.

> ⚠️ **Costo y seguridad:** El script crea recursos que pueden generar cargos. Para facilitar el laboratorio desde CloudShell, el clúster se prepara con conectividad pública temporal y acceso TCP/5432 desde `0.0.0.0/0`. Usa esta configuración solo en laboratorio y elimina o restringe los recursos al terminar.

### Comandos de ejecución previa

```bash
chmod +x 00_preparar_laboratorio_2_aurora.sh
./00_preparar_laboratorio_2_aurora.sh
source ./lab2_aurora_env.sh
```

### Validación previa rápida

```bash
echo "$AURORA_ENDPOINT"
echo "$AURORA_DBNAME"

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
| Duración total | 40 minutos |
| Complejidad | Media |
| Nivel Bloom | Aplicar / Analizar |
| Modalidad | Retos guiados con solución oculta |
| Motor | Amazon Aurora PostgreSQL |
| Versión recomendada | Aurora PostgreSQL 15.x o 16.x |
| Entorno | AWS CloudShell |
| Costo | Usa el clúster Aurora existente, el creado en el laboratorio anterior o el creado por el script previo |

---

## 🗓️ Distribución de tiempo por reto

| Reto | Actividad | Tiempo |
|---|---|---:|
| Reto 1 | Preparar CloudShell y conexión a Aurora | 4 min |
| Reto 2 | Crear esquema y datos de bloqueo | 5 min |
| Reto 3 | Observar línea base de sesiones y locks | 4 min |
| Reto 4 | Crear bloqueo controlado entre dos sesiones | 6 min |
| Reto 5 | Diagnosticar y resolver el bloqueo | 6 min |
| Reto 6 | Probar `NOWAIT` y `SKIP LOCKED` | 6 min |
| Reto 7 | Configurar timeouts de sesión | 4 min |
| Reto 8 | Validar estado final previo a limpieza | 2 min |
| Reto 9 | Eliminar recursos del laboratorio | 3 min |
| **Total** |  | **40 min** |

> 💡 **Nota operativa:** Este laboratorio requiere al menos **dos sesiones `psql` simultáneas**. Puedes abrir dos pestañas de AWS CloudShell o dos conexiones `psql` dentro del mismo entorno si usas terminales divididas. Para el diagnóstico, se recomienda una tercera sesión temporal.

---

# 2. 🧪 Desarrollo de la práctica

---

# 🧩 Reto 1. Preparar CloudShell y conexión a Aurora

## ⏱️ Tiempo estimado

**4 minutos**

---

## 🎯 Objetivo del reto

Validar que AWS CloudShell esté listo y que puedes conectarte al endpoint writer de Aurora PostgreSQL.

---

## 🧠 Escenario

Vas a diagnosticar bloqueos en una base Aurora PostgreSQL real. Antes de generar contención, necesitas confirmar que estás conectado al writer endpoint y que las variables del laboratorio están definidas correctamente.

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

---

## 🛠️ Tu reto

Desde AWS CloudShell, valida:

- Identidad AWS.
- Región activa.
- Disponibilidad de `psql`.
- Variables de conexión.
- Conexión al writer endpoint.
- Que no estás conectado a una réplica.

---

## 💡 Pistas

- Usa las mismas variables del Laboratorio 1.
- El endpoint writer normalmente contiene `.cluster-`.
- El reader endpoint suele contener `.cluster-ro-`.
- `pg_is_in_recovery()` debe devolver `false` en el writer.

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
fi

psql --version

echo "=== Variables requeridas ==="

# Si ejecutaste el script previo, carga las variables generadas.
if [ -f ./lab2_aurora_env.sh ]; then
  source ./lab2_aurora_env.sh
fi

# Ajusta estos valores solo si usarás un clúster diferente al preparado por el script previo.
export AURORA_ENDPOINT="${AURORA_ENDPOINT:-<endpoint-writer-aurora>}"
export AURORA_PORT="${AURORA_PORT:-5432}"
export AURORA_DBNAME="${AURORA_DBNAME:-lab_performance}"
export AURORA_MASTER_USER="${AURORA_MASTER_USER:-labadmin}"
export AURORA_MASTER_PASSWORD="${AURORA_MASTER_PASSWORD:-AuroraLab_2026_Temporal!}"
export AURORA_CLUSTER_ID="${AURORA_CLUSTER_ID:-aurora-performance-lab-cluster}"

echo "Endpoint: $AURORA_ENDPOINT"
echo "Puerto:   $AURORA_PORT"
echo "DB:       $AURORA_DBNAME"
echo "Usuario:  $AURORA_MASTER_USER"

if [ "$AURORA_ENDPOINT" = "<endpoint-writer-aurora>" ]; then
  echo "ERROR: Define AURORA_ENDPOINT antes de continuar."
  echo 'Ejemplo: export AURORA_ENDPOINT="mi-cluster.cluster-xxxx.us-west-2.rds.amazonaws.com"'
  exit 1
fi

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

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20preparar%20AWS%20CloudShell%20para%20diagnosticar%20bloqueos%20en%20Aurora%20PostgreSQL%20validando%20psql%2C%20variables%20de%20conexi%C3%B3n%20y%20pg_is_in_recovery.)

---

# 🧩 Reto 2. Crear esquema y datos de bloqueo

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Crear un esquema dedicado y tablas de prueba para simular escenarios de bloqueo y procesamiento concurrente.

---

## 🧠 Escenario

Necesitas tablas pequeñas, controladas y rápidas de cargar para reproducir bloqueos sin afectar otros objetos del clúster. Usarás un esquema dedicado llamado `lab_locking`.

---

## 🧱 Valores estandarizados del reto

| Recurso | Valor estándar |
|---|---|
| Script SQL | `02_setup_locking.sql` |
| Esquema | `lab_locking` |
| Tabla de pedidos | `lab_locking.pedidos` |
| Tabla de trabajos | `lab_locking.trabajos` |
| Índice de pedidos | `idx_pedidos_estado` |
| Índice de trabajos | `idx_trabajos_estado_id` |
| Registros en pedidos | `1000` |
| Registros en trabajos | `100` |

---

## 🛠️ Tu reto

Crea:

- Esquema `lab_locking`.
- Tabla `lab_locking.pedidos`.
- Tabla `lab_locking.trabajos`.
- Índices de apoyo.
- Datos de prueba.

---

## 💡 Pistas

- `pedidos` se usará para bloqueos de fila.
- `trabajos` se usará para demostrar `SKIP LOCKED`.
- Evita usar el esquema `public` para no mezclar objetos de otros laboratorios.
- Usa `generate_series` para cargar datos rápido.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
cat > 02_setup_locking.sql <<'SQL'
CREATE SCHEMA IF NOT EXISTS lab_locking;

DROP TABLE IF EXISTS lab_locking.trabajos;
DROP TABLE IF EXISTS lab_locking.pedidos;

CREATE TABLE lab_locking.pedidos (
    id          integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    cliente_id  integer NOT NULL,
    estado      varchar(30) NOT NULL DEFAULT 'NUEVO',
    monto       numeric(10,2),
    creado_en   timestamptz DEFAULT now()
);

CREATE TABLE lab_locking.trabajos (
    id          integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    estado      varchar(30) NOT NULL DEFAULT 'PENDIENTE',
    payload     text,
    creado_en   timestamptz DEFAULT now()
);

CREATE INDEX idx_pedidos_estado
ON lab_locking.pedidos (estado);

CREATE INDEX idx_trabajos_estado_id
ON lab_locking.trabajos (estado, id);

INSERT INTO lab_locking.pedidos (cliente_id, estado, monto)
SELECT
    (random() * 500 + 1)::int,
    (ARRAY['NUEVO','EN_PROCESO','COMPLETADO'])[1 + (random()*2)::int],
    round((random() * 1000 + 10)::numeric, 2)
FROM generate_series(1, 1000);

INSERT INTO lab_locking.trabajos (estado, payload)
SELECT
    'PENDIENTE',
    'payload_' || gs
FROM generate_series(1, 100) AS gs;

ANALYZE lab_locking.pedidos;
ANALYZE lab_locking.trabajos;

SELECT 'pedidos' AS tabla, count(*) AS total FROM lab_locking.pedidos
UNION ALL
SELECT 'trabajos' AS tabla, count(*) AS total FROM lab_locking.trabajos;
SQL

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -f 02_setup_locking.sql
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT schemaname, relname AS tabla, n_live_tup AS filas_estimadas
      FROM pg_stat_user_tables
      WHERE schemaname = 'lab_locking'
      ORDER BY relname;"
```

---

## 📌 Resultado esperado

Debes ver aproximadamente:

```text
pedidos    1000
trabajos   100
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20preparar%20tablas%20de%20laboratorio%20para%20simular%20bloqueos%20en%20PostgreSQL%20usando%20un%20esquema%20dedicado%2C%20pedidos%2C%20trabajos%20e%20%C3%ADndices.)

---

# 🧩 Reto 3. Observar línea base de sesiones y locks

## ⏱️ Tiempo estimado

**4 minutos**

---

## 🎯 Objetivo del reto

Observar el estado base de sesiones, transacciones y bloqueos antes de generar contención.

---

## 🧠 Escenario

Antes de provocar bloqueos, necesitas conocer cómo se ve el sistema en un estado estable. Esto te permitirá diferenciar una sesión normal de una sesión bloqueada o una transacción abierta.

---

## 🛠️ Tu reto

Consulta:

- Sesiones activas en la base actual.
- Bloqueos existentes sobre objetos del esquema `lab_locking`.
- Sesiones `idle in transaction`.
- Bloqueos pendientes.

---

## 💡 Pistas

- `pg_stat_activity` muestra sesiones y estado.
- `pg_locks` muestra bloqueos concedidos o pendientes.
- `granted = false` indica un lock solicitado pero no concedido.
- `idle in transaction` indica una transacción abierta sin actividad.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Sesiones activas en la base actual ==="

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
      ORDER BY state, pid;"

echo "=== Locks sobre objetos del esquema lab_locking ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT
          l.locktype,
          l.relation::regclass AS objeto,
          l.mode,
          l.granted,
          l.pid
      FROM pg_locks l
      JOIN pg_class c ON l.relation = c.oid
      JOIN pg_namespace n ON c.relnamespace = n.oid
      WHERE n.nspname = 'lab_locking'
      ORDER BY l.granted, objeto, l.mode;"

echo "=== Sesiones idle in transaction ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT
          pid,
          usename,
          state,
          now() - xact_start AS duracion_tx,
          left(query, 80) AS ultima_query
      FROM pg_stat_activity
      WHERE state = 'idle in transaction'
      ORDER BY duracion_tx DESC;"

echo "=== Bloqueos pendientes ==="

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
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS bloqueos_pendientes
      FROM pg_locks
      WHERE NOT granted;"
```

---

## 📌 Resultado esperado

En un ambiente limpio, debes ver:

```text
 bloqueos_pendientes
---------------------
 0
```

También se espera que no existan sesiones `idle in transaction` problemáticas antes de iniciar los escenarios.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20usar%20pg_stat_activity%20y%20pg_locks%20para%20observar%20una%20l%C3%ADnea%20base%20de%20sesiones%20y%20bloqueos%20en%20PostgreSQL.)

---

# 🧩 Reto 4. Crear bloqueo controlado entre dos sesiones

## ⏱️ Tiempo estimado

**6 minutos**

---

## 🎯 Objetivo del reto

Simular una situación real donde una transacción retiene un bloqueo de fila y otra sesión queda esperando.

---

## 🧠 Escenario

Una aplicación inicia una transacción, actualiza una fila y no hace `COMMIT` ni `ROLLBACK`. Otra sesión intenta actualizar la misma fila y queda bloqueada. Este patrón es común cuando una aplicación deja transacciones abiertas más tiempo del necesario.

---

## 🛠️ Tu reto

Usa dos sesiones `psql`:

- **Sesión A:** inicia una transacción y actualiza el pedido `id = 1`.
- **Sesión B:** intenta actualizar el mismo pedido.
- Mantén la Sesión B bloqueada para diagnosticarla en el siguiente reto.

---

## 💡 Pistas

- En CloudShell puedes abrir dos pestañas.
- La Sesión A debe dejar la transacción abierta.
- La Sesión B no devolverá el prompt mientras esté esperando el lock.
- No ejecutes `COMMIT` todavía en la Sesión A.

---

<details>
<summary>✅ Ver solución sugerida</summary>

### Abrir Sesión A

Ejecuta en una primera terminal de CloudShell:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require"
```

Dentro de `psql`, ejecuta:

```sql
\set PROMPT1 'SESION_A=> '

BEGIN;

UPDATE lab_locking.pedidos
SET estado = 'EN_PROCESO'
WHERE id = 1;

SELECT id, estado
FROM lab_locking.pedidos
WHERE id = 1;

-- IMPORTANTE:
-- No ejecutes COMMIT ni ROLLBACK todavía.
-- Deja esta transacción abierta.
```

### Abrir Sesión B

Ejecuta en una segunda terminal de CloudShell:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require"
```

Dentro de `psql`, ejecuta:

```sql
\set PROMPT1 'SESION_B=> '

BEGIN;

UPDATE lab_locking.pedidos
SET estado = 'EN_COLA'
WHERE id = 1;

-- Esta sesión quedará esperando.
-- No cierres la terminal.
```

</details>

---

## 🔍 Validación

La **Sesión B** debe quedar sin devolver el prompt después del `UPDATE`.

En la Sesión A puedes confirmar que la transacción sigue abierta porque todavía ves el prompt y no has ejecutado `COMMIT` ni `ROLLBACK`.

---

## 📌 Resultado esperado

Comportamiento esperado:

```text
Sesión A mantiene el lock sobre la fila id = 1.
Sesión B queda esperando para actualizar la misma fila.
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20por%20qu%C3%A9%20una%20transacci%C3%B3n%20UPDATE%20sin%20COMMIT%20puede%20bloquear%20otra%20transacci%C3%B3n%20en%20PostgreSQL%20y%20c%C3%B3mo%20diagnosticarlo.)

---

# 🧩 Reto 5. Diagnosticar y resolver el bloqueo

## ⏱️ Tiempo estimado

**6 minutos**

---

## 🎯 Objetivo del reto

Identificar qué sesión está bloqueada, qué sesión la bloquea y liberar la espera de forma controlada.

---

## 🧠 Escenario

La Sesión B está esperando porque la Sesión A mantiene un bloqueo sobre la misma fila. Necesitas diagnosticar la relación bloqueado/bloqueador sin depender de suposiciones sobre el tipo exacto de lock.

---

## 🛠️ Tu reto

Desde una tercera sesión o una terminal nueva:

- Identifica la sesión bloqueada.
- Identifica el PID bloqueador.
- Revisa el evento de espera.
- Resuelve el bloqueo.
- Valida que no quedan bloqueos pendientes.

---

## 💡 Pistas

- `pg_blocking_pids(pid)` es la forma más directa de identificar bloqueadores.
- `wait_event_type = 'Lock'` indica espera por lock.
- Para liberar la Sesión B, primero debes cerrar la transacción de la Sesión A.
- En este laboratorio usaremos `COMMIT` en A y `ROLLBACK` en B para dejar limpio el escenario.

---

<details>
<summary>✅ Ver solución sugerida</summary>

### Abrir Sesión de Diagnóstico

Ejecuta en una tercera terminal de CloudShell:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require"
```

Dentro de `psql`, ejecuta:

```sql
\set PROMPT1 'DIAGNOSTICO=> '

SELECT
    pid,
    pg_blocking_pids(pid) AS bloqueado_por,
    wait_event_type,
    wait_event,
    state,
    now() - xact_start AS duracion_tx,
    left(query, 100) AS query
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;
```

Consulta complementaria para ver bloqueos:

```sql
SELECT
    a.pid,
    a.state,
    a.wait_event_type,
    a.wait_event,
    l.locktype,
    l.relation::regclass AS objeto,
    l.mode,
    l.granted,
    left(a.query, 100) AS query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE a.datname = current_database()
ORDER BY l.granted, a.pid, l.locktype;
```

### Resolver el bloqueo

En la **Sesión A**, ejecuta:

```sql
COMMIT;
```

La **Sesión B** terminará su `UPDATE`. Después, en la **Sesión B**, ejecuta:

```sql
ROLLBACK;
```

### Validar que el bloqueo desapareció

En la sesión de diagnóstico, ejecuta:

```sql
SELECT count(*) AS bloqueos_pendientes
FROM pg_locks
WHERE NOT granted;

SELECT
    pid,
    pg_blocking_pids(pid) AS bloqueado_por,
    wait_event_type,
    wait_event,
    state
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;
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
```

---

## 📌 Resultado esperado

Debes ver:

```text
 bloqueos_pendientes
---------------------
 0
```

Y no debe haber filas en:

```sql
SELECT *
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20diagnosticar%20sesiones%20bloqueadas%20en%20PostgreSQL%20usando%20pg_stat_activity%2C%20pg_locks%20y%20pg_blocking_pids.)

---

# 🧩 Reto 6. Probar NOWAIT y SKIP LOCKED

## ⏱️ Tiempo estimado

**6 minutos**

---

## 🎯 Objetivo del reto

Probar dos patrones para evitar esperas indefinidas ante bloqueos: `NOWAIT` y `SKIP LOCKED`.

---

## 🧠 Escenario

No todas las aplicaciones deben esperar indefinidamente cuando una fila está bloqueada. Algunas deben fallar rápido y reintentar después; otras deben saltarse filas bloqueadas y seguir procesando trabajo disponible.

---

## 🛠️ Tu reto

Demuestra:

- `FOR UPDATE NOWAIT`: falla inmediatamente si la fila está bloqueada.
- `FOR UPDATE SKIP LOCKED`: omite filas bloqueadas y devuelve otras disponibles.

---

## 💡 Pistas

- `NOWAIT` se usa con `SELECT ... FOR UPDATE NOWAIT`.
- `SKIP LOCKED` se usa con `SELECT ... FOR UPDATE SKIP LOCKED`.
- Este reto requiere dos sesiones.
- Siempre limpia con `ROLLBACK`.

---

<details>
<summary>✅ Ver solución sugerida</summary>

## Parte A — Probar NOWAIT

### En Sesión A

```sql
BEGIN;

UPDATE lab_locking.pedidos
SET estado = 'EN_PROCESO'
WHERE id = 5;

-- No hagas COMMIT todavía.
```

### En Sesión B

```sql
BEGIN;

SELECT id, estado
FROM lab_locking.pedidos
WHERE id = 5
FOR UPDATE NOWAIT;
```

Resultado esperado en Sesión B:

```text
ERROR:  could not obtain lock on row in relation "pedidos"
```

Después limpia ambas sesiones:

### En Sesión B

```sql
ROLLBACK;
```

### En Sesión A

```sql
ROLLBACK;
```

---

## Parte B — Probar SKIP LOCKED

### En Sesión A

```sql
BEGIN;

SELECT id, payload
FROM lab_locking.trabajos
WHERE estado = 'PENDIENTE'
ORDER BY id
FOR UPDATE SKIP LOCKED
LIMIT 5;

-- No hagas COMMIT todavía.
-- Esta sesión mantiene bloqueados esos 5 trabajos.
```

### En Sesión B

```sql
BEGIN;

SELECT id, payload
FROM lab_locking.trabajos
WHERE estado = 'PENDIENTE'
ORDER BY id
FOR UPDATE SKIP LOCKED
LIMIT 5;
```

La Sesión B debe obtener otros 5 IDs distintos.

Después limpia ambas sesiones:

### En Sesión B

```sql
ROLLBACK;
```

### En Sesión A

```sql
ROLLBACK;
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
```

---

## 📌 Resultado esperado

Debes observar:

```text
NOWAIT falla inmediatamente cuando la fila está bloqueada.
SKIP LOCKED devuelve filas diferentes sin esperar.
No quedan bloqueos pendientes al finalizar.
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20la%20diferencia%20entre%20FOR%20UPDATE%20NOWAIT%20y%20FOR%20UPDATE%20SKIP%20LOCKED%20en%20PostgreSQL%2C%20con%20ejemplos%20de%20bloqueos%20y%20colas%20de%20trabajo.)

---

# 🧩 Reto 7. Configurar timeouts de sesión

## ⏱️ Tiempo estimado

**4 minutos**

---

## 🎯 Objetivo del reto

Configurar límites de espera para evitar que una sesión quede bloqueada indefinidamente.

---

## 🧠 Escenario

En producción, una sesión que espera indefinidamente por un lock puede afectar la experiencia del usuario y consumir recursos. Para reducir ese riesgo, PostgreSQL permite configurar timeouts de sesión.

---

## 🛠️ Tu reto

Configura en una sesión:

- `lock_timeout = '5s'`
- `statement_timeout = '30s'`
- `idle_in_transaction_session_timeout = '60s'`

Luego genera un bloqueo y confirma que la sesión bloqueada se cancela automáticamente después de 5 segundos.

---

## 💡 Pistas

- `lock_timeout` cancela una sentencia si no puede obtener un lock en el tiempo definido.
- `statement_timeout` limita la duración total de una sentencia.
- `idle_in_transaction_session_timeout` cierra sesiones que quedan inactivas dentro de una transacción.
- Para este laboratorio se configuran a nivel sesión con `SET`.

---

<details>
<summary>✅ Ver solución sugerida</summary>

## Configurar timeouts en Sesión B

En la **Sesión B**, ejecuta:

```sql
SET lock_timeout = '5s';
SET statement_timeout = '30s';
SET idle_in_transaction_session_timeout = '60s';

SHOW lock_timeout;
SHOW statement_timeout;
SHOW idle_in_transaction_session_timeout;
```

## Crear bloqueo en Sesión A

En la **Sesión A**, ejecuta:

```sql
BEGIN;

UPDATE lab_locking.pedidos
SET estado = 'EN_PROCESO'
WHERE id = 10;

-- Mantén abierta la transacción durante más de 5 segundos.
```

## Probar timeout en Sesión B

En la **Sesión B**, ejecuta:

```sql
BEGIN;

UPDATE lab_locking.pedidos
SET estado = 'EN_COLA'
WHERE id = 10;
```

Después de aproximadamente 5 segundos, debe aparecer:

```text
ERROR:  canceling statement due to lock timeout
```

## Limpiar sesiones

En la **Sesión B**, ejecuta:

```sql
ROLLBACK;
```

En la **Sesión A**, ejecuta:

```sql
ROLLBACK;
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT name, setting, unit
      FROM pg_settings
      WHERE name IN ('lock_timeout', 'statement_timeout', 'idle_in_transaction_session_timeout')
      ORDER BY name;"
```

---

## 📌 Resultado esperado

Durante la prueba, la Sesión B debe recibir:

```text
ERROR:  canceling statement due to lock timeout
```

Después de limpiar, no deben quedar bloqueos pendientes.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20funcionan%20lock_timeout%2C%20statement_timeout%20e%20idle_in_transaction_session_timeout%20en%20PostgreSQL%20y%20c%C3%B3mo%20ayudan%20a%20evitar%20esperas%20indefinidas%20por%20bloqueos.)

---

# 🧩 Reto 8. Validar estado final previo a limpieza

## ⏱️ Tiempo estimado

**2 minutos**

---

## 🎯 Objetivo del reto

Confirmar que no quedan bloqueos pendientes ni sesiones problemáticas antes de eliminar los objetos del laboratorio.

---

## 🧠 Escenario

Después de trabajar con sesiones concurrentes, es importante validar que todas las transacciones quedaron cerradas y que el clúster no mantiene sesiones `idle in transaction` que puedan afectar pruebas posteriores.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor estándar |
|---|---|
| Base de datos | `$AURORA_DBNAME` |
| Esquema validado | `lab_locking` |
| Estado esperado de bloqueos pendientes | `0` |
| Estado esperado de sesiones `idle in transaction` | `0` |

---

## 🛠️ Tu reto

Realiza:

- `ROLLBACK` en cualquier sesión `psql` que haya quedado abierta.
- Validación de bloqueos pendientes.
- Validación de sesiones `idle in transaction`.
- Confirmación de que el esquema `lab_locking` todavía existe antes de limpiarlo en el siguiente reto.

---

## 💡 Pistas

- Si una sesión queda dentro de una transacción, ejecuta `ROLLBACK`.
- `pg_locks` permite confirmar locks pendientes con `granted = false`.
- `pg_stat_activity` permite detectar sesiones `idle in transaction`.
- No elimines todavía el esquema; la eliminación se realiza en el Reto 9.

---

<details>
<summary>✅ Ver solución sugerida</summary>

## Cerrar transacciones abiertas

En cada sesión `psql` que hayas usado, ejecuta:

```sql
ROLLBACK;
```

Si aparece:

```text
WARNING: there is no transaction in progress
```

no es un problema. Significa que la sesión no tenía transacción abierta.

## Validar estado final antes de eliminar objetos

Ejecuta desde Bash:

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

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT schema_name
      FROM information_schema.schemata
      WHERE schema_name = 'lab_locking';"
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

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20validar%20que%20no%20quedan%20bloqueos%20pendientes%20ni%20sesiones%20idle%20in%20transaction%20en%20PostgreSQL%20antes%20de%20limpiar%20un%20laboratorio.)

---

# 🧩 Reto 9. Eliminar recursos del laboratorio

## ⏱️ Tiempo estimado

**3 minutos**

---

## 🎯 Objetivo del reto

Eliminar los objetos creados exclusivamente para este laboratorio y confirmar que el ambiente quedó limpio.

---

## 🧠 Escenario

Este laboratorio reutiliza un clúster Aurora PostgreSQL existente. Por eso, la limpieza debe enfocarse únicamente en el esquema `lab_locking` y sus objetos asociados, sin eliminar la base `lab_performance` ni los recursos de infraestructura del Laboratorio 1.

---

## 🧱 Valores estandarizados del reto

| Recurso | Valor estándar | Acción |
|---|---|---|
| Esquema | `lab_locking` | Eliminar con `DROP SCHEMA ... CASCADE` |
| Tabla | `lab_locking.pedidos` | Se elimina junto con el esquema |
| Tabla | `lab_locking.trabajos` | Se elimina junto con el esquema |
| Índice | `idx_pedidos_estado` | Se elimina junto con la tabla `pedidos` |
| Índice | `idx_trabajos_estado_id` | Se elimina junto con la tabla `trabajos` |
| Base de datos | `lab_performance` | No eliminar |
| Clúster Aurora | `$AURORA_CLUSTER_ID` | No eliminar en este laboratorio |

---

## 🛠️ Tu reto

Realiza:

- Eliminación del esquema `lab_locking`.
- Validación de que el esquema ya no existe.
- Validación final de bloqueos pendientes.
- Confirmación de que la base `lab_performance` sigue disponible.

---

## 💡 Pistas

- `DROP SCHEMA IF EXISTS lab_locking CASCADE` elimina tablas, índices y dependencias dentro del esquema.
- No uses comandos de eliminación de RDS en este laboratorio.
- Este reto limpia objetos de base de datos, no infraestructura AWS.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Eliminar esquema del laboratorio 2 ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "DROP SCHEMA IF EXISTS lab_locking CASCADE;"

echo "=== Validar que el esquema fue eliminado ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT schema_name
      FROM information_schema.schemata
      WHERE schema_name = 'lab_locking';"

echo "=== Validar que no quedan bloqueos pendientes ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT count(*) AS bloqueos_pendientes
      FROM pg_locks
      WHERE NOT granted;"

echo "=== Confirmar base activa ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT current_database(), current_user, now() AS validado_en;"
```
</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT schema_name
      FROM information_schema.schemata
      WHERE schema_name = 'lab_locking';"
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

### Ejecutar script de eliminación de infraestructura

Si el instructor solicita eliminar también el clúster Aurora y los recursos AWS creados para esta práctica, ejecuta el script de eliminación desde AWS CloudShell:

```bash
chmod +x 00_eliminar_laboratorio_2_aurora.sh
./00_eliminar_laboratorio_2_aurora.sh
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20eliminar%20objetos%20temporales%20de%20un%20laboratorio%20PostgreSQL%20con%20DROP%20SCHEMA%20CASCADE%20sin%20eliminar%20el%20cl%C3%BAster%20Aurora%20ni%20la%20base%20principal.)

---

# ✅ Validación final del laboratorio

Al finalizar la práctica, debes haber completado lo siguiente:

| Elemento | Estado esperado |
|---|---|
| CloudShell validado | Correcto |
| Conexión al writer endpoint | Correcta |
| Esquema `lab_locking` | Creado y eliminado |
| Tabla `pedidos` | Creada para pruebas de bloqueo |
| Tabla `trabajos` | Creada para pruebas de `SKIP LOCKED` |
| Línea base de sesiones | Revisada |
| Bloqueo controlado | Simulado |
| Sesión bloqueada | Diagnosticada |
| Bloqueador | Identificado con `pg_blocking_pids()` |
| `NOWAIT` | Probado |
| `SKIP LOCKED` | Probado |
| Timeouts de sesión | Probados |
| Bloqueos pendientes | 0 |
| Sesiones `idle in transaction` | 0 |
| Limpieza de objetos del laboratorio | Completada |

---

# 🧠 Resultado esperado de aprendizaje

Después de completar este laboratorio, debes poder explicar y ejecutar el flujo básico de diagnóstico de bloqueos en Aurora PostgreSQL:

1. Validar conexión al writer.
2. Preparar tablas de prueba.
3. Observar sesiones activas.
4. Crear un bloqueo controlado.
5. Diagnosticar el proceso bloqueado y el bloqueador.
6. Resolver la espera de forma controlada.
7. Usar `NOWAIT` para fallar rápido.
8. Usar `SKIP LOCKED` para procesar colas sin bloquearse.
9. Configurar timeouts de sesión.
10. Validar estado final sin bloqueos pendientes.
11. Eliminar objetos temporales del esquema `lab_locking`.

---

# 📌 Resumen del laboratorio

En este laboratorio trabajaste con AWS CloudShell y Aurora PostgreSQL para analizar sesiones, bloqueos y timeouts. Preparaste un esquema de prueba, generaste un bloqueo controlado entre dos sesiones, diagnosticaste la relación bloqueado/bloqueador con `pg_stat_activity`, `pg_locks` y `pg_blocking_pids()`, probaste patrones de concurrencia seguros con `NOWAIT` y `SKIP LOCKED`, y configuraste timeouts de sesión para evitar esperas indefinidas. Finalmente, validaste que no quedaran bloqueos pendientes ni sesiones `idle in transaction`, y eliminaste en una tarea separada los objetos temporales del esquema `lab_locking`.
