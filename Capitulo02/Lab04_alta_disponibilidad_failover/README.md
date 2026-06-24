<h1 align="center">🛡️ Laboratorio 4. Alta disponibilidad, endpoints y failover</h1>

---

## 1. 🧾 Información general de la práctica

## 📘 Descripción general

En este laboratorio vas a validar la alta disponibilidad de **AWS Aurora PostgreSQL** mediante un failover manual controlado. Trabajarás desde **AWS CloudShell** para revisar la topología writer/reader del clúster, crear una réplica reader si no existe, monitorear la conectividad al cluster endpoint, ejecutar un failover manual, medir el tiempo de recuperación observado (**RTO**) y validar el comportamiento de los endpoints después del cambio de rol.

La práctica está diseñada como una serie de **retos guiados**. En cada reto primero intentarás resolver el objetivo con pistas. Si te bloqueas, podrás abrir la **solución sugerida**. La solución está oculta para fomentar el razonamiento, pero es completa y funcional para no extender el tiempo del laboratorio.

El enfoque principal es el ciclo operativo de alta disponibilidad:

> **Preparar → Validar topología → Monitorear → Ejecutar failover → Medir RTO → Confirmar endpoints → Registrar evidencia → Limpiar**

---

## 🎯 Objetivos de aprendizaje

Al finalizar este laboratorio, podrás:

- Usar AWS CloudShell para conectarte a un clúster Aurora PostgreSQL.
- Validar la topología writer/reader de un clúster Aurora PostgreSQL.
- Identificar el cluster endpoint y el reader endpoint.
- Confirmar desde PostgreSQL si una instancia actúa como writer o reader usando `pg_is_in_recovery()`.
- Crear una réplica reader si el clúster solo tiene una instancia writer.
- Crear un monitor de conectividad para medir el RTO observado durante un failover.
- Ejecutar un failover manual con AWS CLI.
- Validar que el cluster endpoint apunta al nuevo writer después del failover.
- Validar el comportamiento del reader endpoint después del failover.
- Revisar eventos RDS relacionados con el failover.
- Guardar evidencia técnica del laboratorio.
- Limpiar artefactos locales o eliminar infraestructura si el instructor lo solicita.

---

## ✅ Prerrequisitos

Antes de iniciar, debes contar con:

- Ejecutar antes de comenzar el script `00_preparar_laboratorio_4_aurora.sh` desde **AWS CloudShell** o contar con un clúster Aurora PostgreSQL equivalente ya disponible.
- Acceso a una cuenta AWS.
- Permisos para usar AWS CloudShell.
- Permisos IAM para administrar o validar recursos de Amazon RDS/Aurora, EC2 Security Groups, VPC/Subnets, DB Subnet Groups y STS.
- Permisos IAM específicos para:
  - `rds:DescribeDBClusters`
  - `rds:DescribeDBInstances`
  - `rds:CreateDBInstance`
  - `rds:FailoverDBCluster`
  - `rds:DescribeEvents`
  - `rds:DeleteDBInstance`
  - `rds:DeleteDBCluster`
  - `sts:GetCallerIdentity`
- Conectividad desde CloudShell hacia el endpoint writer de Aurora PostgreSQL.
- Cliente `psql` disponible en AWS CloudShell. El script previo lo instala si no existe.
- Python 3 disponible en AWS CloudShell.
- Paquete Python `psycopg2-binary` disponible. El script previo lo instala si no existe.
- Conocimiento básico de Aurora endpoints:
  - Cluster endpoint.
  - Reader endpoint.
  - Instance endpoint.
- Conocimiento básico de alta disponibilidad, failover y RTO.

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
| AWS CLI | Administración y validación del clúster Aurora |
| psql | Validación SQL de endpoints |
| Python 3 | Monitor de conectividad y medición de RTO |
| psycopg2-binary | Driver PostgreSQL para Python |
| jq | Procesamiento opcional de salidas JSON |
| Aurora PostgreSQL | Motor de base de datos del laboratorio |

---

## 🧱 Valores estandarizados del laboratorio

Usa estos valores durante toda la práctica para mantener consistencia entre los retos, las validaciones y la limpieza final.

| Tipo | Nombre / valor estándar | Uso |
|---|---|---|
| Región | `$AWS_REGION` | Región activa de AWS CLI o `us-west-2` como valor por defecto del script previo |
| Endpoint writer | `$AURORA_ENDPOINT` | Cluster endpoint del clúster Aurora PostgreSQL |
| Endpoint reader | `$AURORA_READER_ENDPOINT` | Reader endpoint del clúster Aurora PostgreSQL |
| Puerto | `5432` | Puerto estándar PostgreSQL |
| Base de datos | `lab_performance` | Base creada o utilizada desde laboratorios anteriores |
| Usuario administrador | `labadmin` | Usuario master del laboratorio |
| Contraseña temporal | `AuroraLab_2026_Temporal!` | Contraseña de laboratorio, cámbiala si tu instructor lo solicita |
| Cluster ID | `aurora-performance-lab-cluster` | Identificador esperado del clúster |
| Instancia writer | `$AURORA_WRITER_INSTANCE` | Instancia con rol writer antes del failover |
| Instancia reader | `$AURORA_READER_INSTANCE` | Instancia reader objetivo para failover |
| Instancia reader estándar | `aurora-performance-lab-cluster-reader-1` | Reader temporal creada si no existe |
| Archivo de variables | `./lab4_aurora_env.sh` | Variables exportadas para el laboratorio |
| Monitor Python | `./04_monitor_failover.py` | Script para medir conectividad y RTO |
| Log de failover | `./04_failover_log.csv` | CSV generado por el monitor |
| Resumen de failover | `./04_resumen_failover.txt` | Evidencia final del laboratorio |
| Topología final | `./04_topologia_final.txt` | Evidencia de miembros writer/reader |
| Paquete evidencia | `./04_evidencia_failover_*.tar.gz` | Evidencia comprimida del laboratorio |

---

## 🚦 Preparación previa obligatoria antes de comenzar

Antes de iniciar el **Reto 1**, ejecuta el script de preparación desde **AWS CloudShell**. Este script crea o reutiliza los recursos mínimos requeridos para la práctica: VPC default, subnets, Security Group temporal, DB Subnet Group, clúster Aurora PostgreSQL, instancia writer, instancia reader, base `lab_performance`, dependencias Python y archivo de variables `lab4_aurora_env.sh`.

> ⚠️ **Costo y seguridad:** El script crea recursos que pueden generar cargos. Para facilitar el laboratorio desde CloudShell, el clúster se prepara con conectividad pública temporal y acceso TCP/5432 desde `0.0.0.0/0`. Usa esta configuración solo en laboratorio y elimina o restringe los recursos al terminar.

### Comandos de ejecución previa

```bash
chmod +x 00_preparar_laboratorio_4_aurora.sh
./00_preparar_laboratorio_4_aurora.sh
source ./lab4_aurora_env.sh
```

### Validación previa rápida

```bash
echo "$AURORA_ENDPOINT"
echo "$AURORA_READER_ENDPOINT"
echo "$AURORA_WRITER_INSTANCE"
echo "$AURORA_READER_INSTANCE"

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
| Duración total | 45 minutos |
| Complejidad | Difícil |
| Nivel Bloom | Aplicar / Analizar |
| Modalidad | Retos guiados con solución oculta |
| Motor | Amazon Aurora PostgreSQL |
| Versión recomendada | Aurora PostgreSQL 15.x o 16.x |
| Entorno | AWS CloudShell |
| Costo | Puede generar cargos si se crea una réplica reader adicional |

---

## 🗓️ Distribución de tiempo por reto

| Reto | Actividad | Tiempo |
|---|---|---:|
| Reto 1 | Preparar CloudShell y variables del laboratorio | 5 min |
| Reto 2 | Validar topología Aurora | 6 min |
| Reto 3 | Confirmar o crear réplica reader | 6 min |
| Reto 4 | Crear monitor de conectividad para medir RTO | 7 min |
| Reto 5 | Ejecutar failover manual | 7 min |
| Reto 6 | Validar endpoints después del failover | 5 min |
| Reto 7 | Revisar eventos RDS del failover | 4 min |
| Reto 8 | Validar estado final previo a limpieza | 2 min |
| Reto 9 | Eliminar recursos del laboratorio | 3 min |
| **Total** |  | **45 min** |

> 💡 **Nota operativa:** Este laboratorio necesita que el clúster Aurora tenga al menos una instancia reader para ejecutar failover manual. Si no existe una réplica reader, el script de preparación o el Reto 3 pueden crearla.

---

# 2. 🧪 Desarrollo de la práctica

---

# 🧩 Reto 1. Preparar CloudShell y variables del laboratorio

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Validar AWS CloudShell, preparar variables estándar del laboratorio y confirmar que tienes conectividad básica con Aurora PostgreSQL.

---

## 🧠 Escenario

Vas a ejecutar un failover manual en un clúster Aurora PostgreSQL. Antes de modificar la topología, necesitas validar tu identidad, región, herramientas y variables de conexión.

---

## 🧱 Valores estandarizados del reto

| Variable | Valor estándar |
|---|---|
| `AWS_REGION` | Región activa de AWS CLI o `us-west-2` |
| `AURORA_CLUSTER_ID` | `aurora-performance-lab-cluster` |
| `AURORA_ENDPOINT` | Cluster endpoint |
| `AURORA_READER_ENDPOINT` | Reader endpoint |
| `AURORA_PORT` | `5432` |
| `AURORA_DBNAME` | `lab_performance` |
| `AURORA_MASTER_USER` | `labadmin` |
| `AURORA_MASTER_PASSWORD` | `AuroraLab_2026_Temporal!` |

---

## 🛠️ Tu reto

Desde AWS CloudShell, valida:

- Identidad AWS.
- Región activa.
- Disponibilidad de `aws`, `psql` y `python3`.
- Variables `AURORA_*`.
- Conectividad básica al clúster.
- Que el cluster endpoint apunta al writer.

---

## 💡 Pistas

- Usa `source ./lab4_aurora_env.sh`.
- El cluster endpoint debe usarse para conexiones de escritura.
- El reader endpoint se usa para conexiones de solo lectura.
- `pg_is_in_recovery() = false` confirma conexión al writer.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Cargar variables del Laboratorio 4 ==="

if [ -f ./lab4_aurora_env.sh ]; then
  source ./lab4_aurora_env.sh
else
  echo "ERROR: No existe ./lab4_aurora_env.sh"
  echo "Ejecuta primero 00_preparar_laboratorio_4_aurora.sh"
  exit 1
fi

echo "=== Validar identidad AWS ==="
aws sts get-caller-identity --output table

echo "=== Validar región y herramientas ==="
echo "Región: $AWS_REGION"
aws --version
python3 --version
psql --version

echo "=== Variables base ==="
echo "Cluster:          $AURORA_CLUSTER_ID"
echo "Cluster endpoint: $AURORA_ENDPOINT"
echo "Reader endpoint:  $AURORA_READER_ENDPOINT"
echo "DB:               $AURORA_DBNAME"
echo "Usuario:          $AURORA_MASTER_USER"

echo "=== Probar conexión al cluster endpoint ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT current_database(), current_user, pg_is_in_recovery() AS es_replica;"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
echo "$AURORA_ENDPOINT"
echo "$AURORA_READER_ENDPOINT"

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT pg_is_in_recovery() AS es_replica;"
```

---

## 📌 Resultado esperado

Debes ver:

```text
es_replica = f
```

Esto confirma que el cluster endpoint apunta al writer actual.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20preparar%20AWS%20CloudShell%20para%20validar%20endpoints%20de%20Aurora%20PostgreSQL%20y%20conectarme%20al%20cluster%20endpoint%20writer.)

---

# 🧩 Reto 2. Validar topología Aurora

## ⏱️ Tiempo estimado

**6 minutos**

---

## 🎯 Objetivo del reto

Identificar la instancia writer actual, la réplica reader disponible y los endpoints del clúster.

---

## 🧠 Escenario

Aurora separa el endpoint lógico del rol físico de las instancias. Durante un failover, una réplica puede ser promovida a writer. Por eso necesitas conocer la topología antes de iniciar el evento.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor estándar |
|---|---|
| Cluster ID | `$AURORA_CLUSTER_ID` |
| Writer actual | `$AURORA_WRITER_INSTANCE` |
| Reader actual | `$AURORA_READER_INSTANCE` |
| Conteo de readers | `$AURORA_READER_COUNT` |
| Cluster endpoint | `$AURORA_ENDPOINT` |
| Reader endpoint | `$AURORA_READER_ENDPOINT` |

---

## 🛠️ Tu reto

Obtén:

- Estado del clúster.
- Lista de miembros del clúster.
- Instancia writer actual.
- Primera instancia reader disponible.
- Número de readers.

---

## 💡 Pistas

- `IsClusterWriter = true` identifica el writer.
- `IsClusterWriter = false` identifica readers.
- Si no hay reader, el siguiente reto confirma o crea una.
- No asumas nombres como `instance-1` o `reader-1`; deriva siempre los valores desde AWS CLI.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Estado general del clúster ==="

aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].{Cluster:DBClusterIdentifier,Status:Status,Engine:Engine,EngineVersion:EngineVersion,Endpoint:Endpoint,ReaderEndpoint:ReaderEndpoint}" \
  --output table

echo "=== Miembros del clúster ==="

aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].DBClusterMembers[*].{Instancia:DBInstanceIdentifier,Writer:IsClusterWriter,ParameterStatus:DBClusterParameterGroupStatus}" \
  --output table

echo "=== Derivar writer y reader actuales ==="

export AURORA_WRITER_INSTANCE=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].DBClusterMembers[?IsClusterWriter==\`true\`].DBInstanceIdentifier | [0]" \
  --output text)

export AURORA_READER_INSTANCE=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].DBClusterMembers[?IsClusterWriter==\`false\`].DBInstanceIdentifier | [0]" \
  --output text)

export AURORA_READER_COUNT=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "length(DBClusters[0].DBClusterMembers[?IsClusterWriter==\`false\`])" \
  --output text)

echo "Writer actual: $AURORA_WRITER_INSTANCE"
echo "Reader actual: $AURORA_READER_INSTANCE"
echo "Readers:       $AURORA_READER_COUNT"

echo "=== Validar rol desde SQL usando cluster endpoint ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT inet_server_addr() AS ip_servidor, pg_is_in_recovery() AS es_replica;"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
echo "Writer: $AURORA_WRITER_INSTANCE"
echo "Reader: $AURORA_READER_INSTANCE"
echo "Readers disponibles: $AURORA_READER_COUNT"
```

---

## 📌 Resultado esperado

Debes tener:

```text
Writer identificado.
Reader identificado.
Reader count >= 1.
```

Si `AURORA_READER_COUNT = 0`, continúa con el Reto 3 para crear una réplica reader.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20identificar%20writer%20y%20reader%20en%20un%20cl%C3%BAster%20Aurora%20PostgreSQL%20usando%20AWS%20CLI%20y%20pg_is_in_recovery.)

---

# 🧩 Reto 3. Confirmar o crear réplica reader

## ⏱️ Tiempo estimado

**7 minutos**

---

## 🎯 Objetivo del reto

Asegurar que el clúster tenga al menos una réplica reader para poder ejecutar failover manual.

---

## 🧠 Escenario

Un clúster Aurora con una sola instancia writer no puede promover una réplica durante un failover. Si el clúster del laboratorio viene de una práctica anterior y solo tiene writer, crearás una reader temporal.

---

## 🧱 Valores estandarizados del reto

| Recurso | Valor estándar |
|---|---|
| Reader temporal | `${AURORA_CLUSTER_ID}-reader-1` |
| Clase de instancia | `db.r6g.large` |
| Engine | `aurora-postgresql` |
| Estado esperado | `available` |

---

## 🛠️ Tu reto

Realiza lo siguiente:

- Verifica si existe una reader.
- Si no existe, crea una instancia reader.
- Espera hasta que esté disponible.
- Actualiza la variable `AURORA_READER_INSTANCE`.
- Confirma que el clúster tiene al menos dos miembros.

---

## 💡 Pistas

- Usa el mismo engine del clúster.
- Usa una clase de instancia compatible con Aurora PostgreSQL.
- Para laboratorio puedes usar `db.r6g.large`, si está disponible en tu región.
- No destruyas el writer.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Verificar si ya existe una reader ==="

if [ "$AURORA_READER_COUNT" -ge 1 ] && [ "$AURORA_READER_INSTANCE" != "None" ]; then
  echo "Ya existe una reader: $AURORA_READER_INSTANCE"
else
  echo "No existe reader. Se creará una réplica temporal."

  export AURORA_READER_INSTANCE="${AURORA_CLUSTER_ID}-reader-1"

  aws rds create-db-instance \
    --db-instance-identifier "$AURORA_READER_INSTANCE" \
    --db-cluster-identifier "$AURORA_CLUSTER_ID" \
    --engine aurora-postgresql \
    --db-instance-class db.r6g.large \
    --region "$AWS_REGION"

  echo "Esperando a que la reader esté available..."

  aws rds wait db-instance-available \
    --db-instance-identifier "$AURORA_READER_INSTANCE" \
    --region "$AWS_REGION"
fi

echo "=== Actualizar topología ==="

export AURORA_WRITER_INSTANCE=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].DBClusterMembers[?IsClusterWriter==\`true\`].DBInstanceIdentifier | [0]" \
  --output text)

export AURORA_READER_INSTANCE=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].DBClusterMembers[?IsClusterWriter==\`false\`].DBInstanceIdentifier | [0]" \
  --output text)

export AURORA_READER_COUNT=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "length(DBClusters[0].DBClusterMembers[?IsClusterWriter==\`false\`])" \
  --output text)

echo "Writer actual: $AURORA_WRITER_INSTANCE"
echo "Reader para failover: $AURORA_READER_INSTANCE"
echo "Readers: $AURORA_READER_COUNT"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].DBClusterMembers[*].{Instancia:DBInstanceIdentifier,Writer:IsClusterWriter}" \
  --output table
```

---

## 📌 Resultado esperado

Debes ver al menos:

```text
Una instancia con Writer = true
Una instancia con Writer = false
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20por%20qu%C3%A9%20un%20cl%C3%BAster%20Aurora%20PostgreSQL%20necesita%20una%20r%C3%A9plica%20reader%20para%20un%20failover%20manual%20y%20c%C3%B3mo%20crear%20una%20con%20AWS%20CLI.)

---

# 🧩 Reto 4. Crear monitor de conectividad para medir RTO

## ⏱️ Tiempo estimado

**7 minutos**

---

## 🎯 Objetivo del reto

Crear un monitor Python que pruebe la conexión al cluster endpoint cada segundo y registre cuándo se pierde y recupera la conexión durante el failover.

---

## 🧠 Escenario

El RTO no debe asumirse; debe medirse. Para eso crearás un script que conecte al cluster endpoint, ejecute una consulta simple y registre cada intento en un archivo CSV.

---

## 🧱 Valores estandarizados del reto

| Archivo | Uso |
|---|---|
| `04_monitor_failover.py` | Monitor de conectividad |
| `04_failover_log.csv` | Log CSV de conectividad |
| Cluster endpoint | `$AURORA_ENDPOINT` |
| Intervalo | 1 segundo |
| Timeout conexión | 3 segundos |

---

## 🛠️ Tu reto

Crea:

- Script `04_monitor_failover.py`.
- Log `04_failover_log.csv`.
- Monitor continuo contra el cluster endpoint.
- Registro de estados `UP` y `DOWN`.

---

## 💡 Pistas

- El script debe leer variables `AURORA_*`.
- Usa `psycopg2-binary`.
- El script debe conectarse al cluster endpoint, no al instance endpoint.
- El RTO observado se calcula entre el primer estado `DOWN` y el siguiente estado `UP`.
- Mantén este monitor corriendo mientras ejecutas el failover en otra terminal.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Crear monitor 04_monitor_failover.py ==="

cat > 04_monitor_failover.py <<'PY'
#!/usr/bin/env python3
import csv
import os
import sys
import time
from datetime import datetime, timezone

try:
    import psycopg2
except ImportError:
    print("ERROR: psycopg2 no está instalado. Ejecuta primero el script de preparación del laboratorio.")
    sys.exit(1)

AURORA_ENDPOINT = os.environ.get("AURORA_ENDPOINT")
AURORA_PORT = int(os.environ.get("AURORA_PORT", "5432"))
AURORA_DBNAME = os.environ.get("AURORA_DBNAME", "lab_performance")
AURORA_MASTER_USER = os.environ.get("AURORA_MASTER_USER")
AURORA_MASTER_PASSWORD = os.environ.get("AURORA_MASTER_PASSWORD")

LOG_FILE = "./04_failover_log.csv"

def utc_now():
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")

def try_connect():
    try:
        conn = psycopg2.connect(
            host=AURORA_ENDPOINT,
            port=AURORA_PORT,
            dbname=AURORA_DBNAME,
            user=AURORA_MASTER_USER,
            password=AURORA_MASTER_PASSWORD,
            sslmode="require",
            connect_timeout=3,
            options="-c statement_timeout=2000"
        )
        conn.autocommit = True
        cur = conn.cursor()
        cur.execute("SELECT inet_server_addr()::text, pg_is_in_recovery();")
        server_ip, is_replica = cur.fetchone()
        cur.close()
        conn.close()
        return True, f"server_ip={server_ip};is_replica={is_replica}"
    except Exception as exc:
        return False, str(exc).replace("\n", " ")[:300]

def main():
    required = {
        "AURORA_ENDPOINT": AURORA_ENDPOINT,
        "AURORA_MASTER_USER": AURORA_MASTER_USER,
        "AURORA_MASTER_PASSWORD": AURORA_MASTER_PASSWORD,
    }

    missing = [k for k, v in required.items() if not v]
    if missing:
        print(f"ERROR: faltan variables: {', '.join(missing)}")
        sys.exit(1)

    print(f"Monitoreando cluster endpoint: {AURORA_ENDPOINT}")
    print(f"Log CSV: {LOG_FILE}")
    print("Presiona Ctrl+C después del failover para detener el monitor.")
    print()

    last_status = None
    down_start = None
    attempt = 0

    with open(LOG_FILE, "w", newline="", encoding="utf-8") as fh:
        writer = csv.writer(fh)
        writer.writerow(["timestamp_utc", "attempt", "status", "detail"])
        fh.flush()

        while True:
            attempt += 1
            ok, detail = try_connect()
            status = "UP" if ok else "DOWN"
            writer.writerow([utc_now(), attempt, status, detail])
            fh.flush()

            if status != last_status:
                if status == "DOWN":
                    down_start = time.time()
                    print(f"\n🔴 {utc_now()} conexión perdida. Intento #{attempt}")
                    print(f"   {detail}")
                elif status == "UP" and down_start:
                    rto = time.time() - down_start
                    print(f"\n🟢 {utc_now()} conexión recuperada. RTO observado: {rto:.2f} segundos")
                    print(f"   {detail}")
                    down_start = None
                else:
                    print(f"🟢 {utc_now()} conexión inicial correcta")
                    print(f"   {detail}")

                last_status = status
            else:
                print("." if ok else "x", end="", flush=True)

            time.sleep(1)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nMonitor detenido por el usuario.")
PY

chmod +x 04_monitor_failover.py

echo "=== Ejecutar monitor ==="
python3 04_monitor_failover.py
```

> Mantén este monitor ejecutándose en una terminal de CloudShell. Abre otra terminal para ejecutar el failover en el siguiente reto.

</details>

---

## 🔍 Validación

En otra terminal, ejecuta:

```bash
ls -la ./04_failover_log.csv
head -5 ./04_failover_log.csv
```

---

## 📌 Resultado esperado

Debes ver un CSV con filas similares a:

```text
timestamp_utc,attempt,status,detail
2026-06-19T18:00:00.000+00:00,1,UP,server_ip=10.x.x.x;is_replica=False
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20crear%20un%20monitor%20Python%20para%20medir%20el%20RTO%20de%20un%20failover%20en%20Aurora%20PostgreSQL%20con%20psycopg2%20y%20un%20log%20CSV.)

---

# 🧩 Reto 5. Ejecutar failover manual

## ⏱️ Tiempo estimado

**7 minutos**

---

## 🎯 Objetivo del reto

Ejecutar un failover manual del clúster Aurora PostgreSQL y observar la pérdida y recuperación de conexión en el monitor.

---

## 🧠 Escenario

Aurora puede promover una réplica reader como nueva instancia writer. Ejecutarás un failover manual hacia la reader identificada y observarás cómo cambia el rol de las instancias.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor |
|---|---|
| Cluster ID | `$AURORA_CLUSTER_ID` |
| Reader objetivo | `$AURORA_READER_INSTANCE` |
| Writer anterior | `$AURORA_WRITER_INSTANCE` |
| Medición CLI | `$RTO_CLI_SECONDS` |
| Monitor | `04_monitor_failover.py` |

---

## 🛠️ Tu reto

Realiza lo siguiente:

- Confirma el writer actual.
- Confirma la reader objetivo.
- Ejecuta el failover manual.
- Espera a que el clúster vuelva a `available`.
- Observa el RTO en el monitor.

---

## 💡 Pistas

- El monitor debe seguir ejecutándose antes de iniciar el failover.
- Usa `--target-db-instance-identifier` para indicar la reader que quieres promover.
- El cluster endpoint debe recuperar conexión hacia el nuevo writer.
- El RTO observado puede variar.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Confirmar writer y reader antes del failover ==="

echo "Writer actual: $AURORA_WRITER_INSTANCE"
echo "Reader objetivo: $AURORA_READER_INSTANCE"

if [ -z "$AURORA_READER_INSTANCE" ] || [ "$AURORA_READER_INSTANCE" = "None" ]; then
  echo "ERROR: No hay reader disponible. Ejecuta el Reto 3 antes de continuar."
  exit 1
fi

echo "=== Registrar inicio del failover ==="

export FAILOVER_START_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
export FAILOVER_START_EPOCH=$(date +%s)

echo "Failover iniciado: $FAILOVER_START_UTC"

echo "=== Ejecutar failover manual ==="

aws rds failover-db-cluster \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --target-db-instance-identifier "$AURORA_READER_INSTANCE" \
  --region "$AWS_REGION"

echo "=== Esperar a que el clúster regrese a available ==="

aws rds wait db-cluster-available \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION"

export FAILOVER_END_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
export FAILOVER_END_EPOCH=$(date +%s)
export RTO_CLI_SECONDS=$((FAILOVER_END_EPOCH - FAILOVER_START_EPOCH))

echo "Failover finalizado: $FAILOVER_END_UTC"
echo "RTO aproximado medido por CLI: ${RTO_CLI_SECONDS} segundos"

echo "=== Ver topología posterior al failover ==="

aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].DBClusterMembers[*].{Instancia:DBInstanceIdentifier,Writer:IsClusterWriter}" \
  --output table
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].Status" \
  --output text
```

---

## 📌 Resultado esperado

Debes ver:

```text
available
```

En el monitor Python debes observar un período `DOWN` y luego recuperación `UP`, con un RTO observado.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20ejecutar%20un%20failover%20manual%20en%20Amazon%20Aurora%20PostgreSQL%20con%20AWS%20CLI%20y%20c%C3%B3mo%20medir%20el%20RTO%20observado.)

---

# 🧩 Reto 6. Validar endpoints después del failover

## ⏱️ Tiempo estimado

**5 minutos**

---

## 🎯 Objetivo del reto

Confirmar que el cluster endpoint apunta al nuevo writer y que el reader endpoint responde como endpoint de lectura.

---

## 🧠 Escenario

Después del failover, los roles físicos de las instancias cambian. El cluster endpoint debe seguir representando al writer lógico del clúster, aunque la instancia física haya cambiado.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor esperado |
|---|---|
| Cluster endpoint | `pg_is_in_recovery() = false` |
| Reader endpoint | `pg_is_in_recovery() = true` en condiciones normales |
| Writer después | `$AURORA_WRITER_INSTANCE_AFTER` |
| Reader después | `$AURORA_READER_INSTANCE_AFTER` |

---

## 🛠️ Tu reto

Valida:

- Nuevo writer.
- Nueva reader.
- `pg_is_in_recovery()` desde cluster endpoint.
- `pg_is_in_recovery()` desde reader endpoint.
- Actualización de variables locales.

---

## 💡 Pistas

- `pg_is_in_recovery() = false` indica writer.
- `pg_is_in_recovery() = true` indica reader.
- El reader endpoint puede tardar unos segundos en estabilizarse después del failover.
- Si el reader endpoint devuelve temporalmente el writer, espera unos segundos y repite.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Actualizar variables de topología post-failover ==="

export AURORA_WRITER_INSTANCE_AFTER=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].DBClusterMembers[?IsClusterWriter==\`true\`].DBInstanceIdentifier | [0]" \
  --output text)

export AURORA_READER_INSTANCE_AFTER=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].DBClusterMembers[?IsClusterWriter==\`false\`].DBInstanceIdentifier | [0]" \
  --output text)

echo "Writer antes:  $AURORA_WRITER_INSTANCE"
echo "Reader antes:  $AURORA_READER_INSTANCE"
echo "Writer ahora:  $AURORA_WRITER_INSTANCE_AFTER"
echo "Reader ahora:  $AURORA_READER_INSTANCE_AFTER"

echo "=== Validar cluster endpoint ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT inet_server_addr() AS ip_servidor, pg_is_in_recovery() AS es_replica;"

echo "=== Validar reader endpoint ==="

psql "host=$AURORA_READER_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT inet_server_addr() AS ip_servidor, pg_is_in_recovery() AS es_replica;"
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT pg_is_in_recovery() AS cluster_endpoint_es_replica;"

psql "host=$AURORA_READER_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT pg_is_in_recovery() AS reader_endpoint_es_replica;"
```

---

## 📌 Resultado esperado

Para el cluster endpoint:

```text
cluster_endpoint_es_replica = f
```

Para el reader endpoint, normalmente se espera:

```text
reader_endpoint_es_replica = t
```

> ⚠️ Si el reader endpoint tarda en reflejar el nuevo estado, espera de 10 a 20 segundos y repite la validación.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20validar%20el%20cluster%20endpoint%20y%20reader%20endpoint%20de%20Aurora%20PostgreSQL%20despu%C3%A9s%20de%20un%20failover%20usando%20pg_is_in_recovery.)

---

# 🧩 Reto 7. Revisar eventos RDS del failover

## ⏱️ Tiempo estimado

**4 minutos**

---

## 🎯 Objetivo del reto

Revisar los eventos RDS generados durante el failover para reconstruir la secuencia operacional del cambio de rol.

---

## 🧠 Escenario

Además de observar la conexión desde el cliente, debes consultar los eventos registrados por RDS para entender qué ocurrió a nivel de servicio administrado.

---

## 🛠️ Tu reto

Consulta:

- Eventos del clúster en los últimos 30 minutos.
- Eventos de la instancia writer anterior.
- Eventos de la instancia promovida.
- Mensajes relacionados con failover, promoción o disponibilidad.

---

## 💡 Pistas

- Usa `aws rds describe-events`.
- Filtra por `db-cluster`.
- También puedes consultar eventos de tipo `db-instance`.
- Los mensajes pueden variar por región y estado del clúster.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Eventos del clúster en los últimos 30 minutos ==="

aws rds describe-events \
  --source-identifier "$AURORA_CLUSTER_ID" \
  --source-type db-cluster \
  --duration 30 \
  --region "$AWS_REGION" \
  --query "Events[*].{Fecha:Date,Mensaje:Message}" \
  --output table

echo "=== Eventos de la instancia que era writer antes ==="

aws rds describe-events \
  --source-identifier "$AURORA_WRITER_INSTANCE" \
  --source-type db-instance \
  --duration 30 \
  --region "$AWS_REGION" \
  --query "Events[*].{Fecha:Date,Mensaje:Message}" \
  --output table || true

echo "=== Eventos de la instancia promovida ==="

aws rds describe-events \
  --source-identifier "$AURORA_READER_INSTANCE" \
  --source-type db-instance \
  --duration 30 \
  --region "$AWS_REGION" \
  --query "Events[*].{Fecha:Date,Mensaje:Message}" \
  --output table || true
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
aws rds describe-events \
  --source-identifier "$AURORA_CLUSTER_ID" \
  --source-type db-cluster \
  --duration 30 \
  --region "$AWS_REGION" \
  --query "length(Events)" \
  --output text
```

---

## 📌 Resultado esperado

Debes obtener un número de eventos mayor o igual a `1`. Los mensajes pueden incluir referencias a failover, cambio de estado o disponibilidad del clúster.

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20revisar%20eventos%20de%20RDS%20despu%C3%A9s%20de%20un%20failover%20de%20Aurora%20PostgreSQL%20usando%20AWS%20CLI.)

---

# 🧩 Reto 8. Validar estado final previo a limpieza

## ⏱️ Tiempo estimado

**2 minutos**

---

## 🎯 Objetivo del reto

Confirmar que el clúster está disponible, que los endpoints responden correctamente y que la evidencia mínima del failover existe antes de ejecutar la limpieza.

---

## 🧠 Escenario

Después de ejecutar un failover, necesitas validar que el clúster quedó estable y que la evidencia técnica fue guardada. Esto evita eliminar recursos sin confirmar el resultado operativo de la práctica.

---

## 🧱 Valores estandarizados del reto

| Elemento | Valor esperado |
|---|---|
| Estado del clúster | `available` |
| Cluster endpoint | `pg_is_in_recovery() = false` |
| Reader count | `>= 1` |
| Log de failover | `04_failover_log.csv` |
| Topología final | `04_topologia_final.txt` |
| Resumen | `04_resumen_failover.txt` |

---

## 🛠️ Tu reto

Realiza:

- Detener el monitor Python con `Ctrl+C`, si sigue activo.
- Validación del estado del clúster.
- Validación de topología actual.
- Validación del cluster endpoint.
- Validación del reader endpoint.
- Confirmación de archivos de evidencia.
- Confirmación de que estás listo para limpiar recursos.

---

## 💡 Pistas

- `aws rds wait db-cluster-available` confirma estabilidad del clúster.
- `pg_is_in_recovery() = false` en el cluster endpoint confirma writer.
- El reader endpoint puede tardar unos segundos en estabilizarse.
- No ejecutes todavía el script de eliminación si el instructor quiere reutilizar el clúster.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Esperar clúster disponible ==="

aws rds wait db-cluster-available \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION"

echo "=== Estado del clúster ==="

aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].{Cluster:DBClusterIdentifier,Status:Status,Endpoint:Endpoint,ReaderEndpoint:ReaderEndpoint}" \
  --output table

echo "=== Topología actual ==="

aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].DBClusterMembers[*].{Instancia:DBInstanceIdentifier,Writer:IsClusterWriter}" \
  --output table

echo "=== Validar cluster endpoint ==="

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT pg_is_in_recovery() AS cluster_endpoint_es_replica;"

echo "=== Validar reader endpoint ==="

psql "host=$AURORA_READER_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT pg_is_in_recovery() AS reader_endpoint_es_replica;" || true

echo "=== Guardar topología final ==="

aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].DBClusterMembers[*].{Instancia:DBInstanceIdentifier,Writer:IsClusterWriter}" \
  --output table > 04_topologia_final.txt

echo "=== Guardar resumen del laboratorio ==="

export FAILOVER_DOWN_COUNT=$(grep -c ",DOWN," 04_failover_log.csv 2>/dev/null || echo 0)
export FAILOVER_UP_COUNT=$(grep -c ",UP," 04_failover_log.csv 2>/dev/null || echo 0)

cat > 04_resumen_failover.txt <<EOF
Laboratorio 4 - Alta disponibilidad, endpoints y failover

Fecha UTC: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Cluster: $AURORA_CLUSTER_ID
Región: $AWS_REGION

Endpoint writer lógico:
$AURORA_ENDPOINT

Endpoint reader:
$AURORA_READER_ENDPOINT

Writer antes del failover:
$AURORA_WRITER_INSTANCE

Reader objetivo del failover:
$AURORA_READER_INSTANCE

Writer después del failover:
${AURORA_WRITER_INSTANCE_AFTER:-No recalculado}

Reader después del failover:
${AURORA_READER_INSTANCE_AFTER:-No recalculado}

RTO aproximado medido por AWS CLI:
${RTO_CLI_SECONDS:-No registrado} segundos

Intentos DOWN registrados por monitor:
$FAILOVER_DOWN_COUNT

Intentos UP registrados por monitor:
$FAILOVER_UP_COUNT

Notas:
- El RTO observado puede variar por región, carga, estado del clúster y comportamiento de DNS.
- No se destruyó el clúster desde el reto para permitir laboratorios posteriores.
EOF

cat 04_resumen_failover.txt

echo "=== Empaquetar evidencia ==="

tar -czf "04_evidencia_failover_$(date +%Y%m%d-%H%M%S).tar.gz" \
  04_failover_log.csv \
  04_topologia_final.txt \
  04_resumen_failover.txt

ls -lh 04_* 2>/dev/null || echo "No hay archivos 04_* para listar."
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].Status" \
  --output text

psql "host=$AURORA_ENDPOINT port=$AURORA_PORT dbname=$AURORA_DBNAME user=$AURORA_MASTER_USER password=$AURORA_MASTER_PASSWORD sslmode=require" \
  -c "SELECT pg_is_in_recovery() AS cluster_endpoint_es_replica;"
```

---

## 📌 Resultado esperado

Debes ver:

```text
available
cluster_endpoint_es_replica = f
```

También debes tener evidencia local si completaste los retos anteriores:

```text
04_failover_log.csv
04_topologia_final.txt
04_resumen_failover.txt
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20validar%20que%20un%20cl%C3%BAster%20Aurora%20PostgreSQL%20qued%C3%B3%20estable%20despu%C3%A9s%20de%20un%20failover%20antes%20de%20eliminar%20recursos.)

---

# 🧩 Reto 9. Eliminar recursos del laboratorio

## ⏱️ Tiempo estimado

**3 minutos**

---

## 🎯 Objetivo del reto

Eliminar los recursos creados para este laboratorio y confirmar que el ambiente quedó limpio.

---

## 🧠 Escenario

Este laboratorio puede crear una réplica reader y también puede reutilizar o crear infraestructura Aurora. Si el instructor indica cerrar el ambiente, debes ejecutar el script de eliminación controlada para borrar el clúster, sus instancias y los recursos asociados.

---

## 🧱 Valores estandarizados del reto

| Recurso | Valor estándar | Acción |
|---|---|---|
| Instancia writer | `$AURORA_INSTANCE_ID` | Eliminar con script |
| Instancia reader | `$AURORA_READER_INSTANCE` o `$AURORA_READER_INSTANCE_ID` | Eliminar con script |
| Clúster Aurora | `$AURORA_CLUSTER_ID` | Eliminar con script |
| DB Subnet Group | `$DB_SUBNET_GROUP_NAME` | Eliminar con script |
| Parameter Group | `$AURORA_PARAM_GROUP` | Eliminar con script |
| Security Group | `$AURORA_SG_ID` | Eliminar con script |
| Archivo de variables | `lab4_aurora_env.sh` | Eliminar con script |
| Evidencia local | `04_*` | Eliminar o conservar según indique el instructor |

---

## 🛠️ Tu reto

Realiza:

- Ejecución del script `00_eliminar_laboratorio_4_aurora.sh`.
- Validación de que las instancias ya no existen.
- Validación de que el clúster ya no existe.
- Validación de que el DB Subnet Group y Parameter Group se eliminaron.
- Confirmación final del cierre del laboratorio.

---

## 💡 Pistas

- El script de eliminación carga automáticamente `./lab4_aurora_env.sh` si existe.
- El script elimina primero las instancias y después el clúster.
- No interrumpas el script mientras espera la eliminación de las instancias.
- Si el Security Group no se elimina por dependencias, espera unos minutos y repite el script.

---

<details>
<summary>✅ Ver solución sugerida</summary>

```bash
echo "=== Ejecutar script de eliminación del Laboratorio 4 ==="

chmod +x 00_eliminar_laboratorio_4_aurora.sh
./00_eliminar_laboratorio_4_aurora.sh
```

</details>

---

## 🔍 Validación

Ejecuta:

```bash
aws rds describe-db-clusters \
  --db-cluster-identifier "$AURORA_CLUSTER_ID" \
  --region "$AWS_REGION" \
  --query "DBClusters[0].Status" \
  --output text
```

Si el clúster fue eliminado correctamente, AWS CLI debe devolver un error similar a:

```text
DBClusterNotFoundFault
```

---

## 📌 Resultado esperado

Debes confirmar:

```text
Instancias eliminadas
Clúster eliminado
DB Subnet Group eliminado
Parameter Group eliminado
Security Group eliminado o sin dependencias pendientes
```

---

## 🤖 Prompt de apoyo

[Explicar este reto en ChatGPT](https://chatgpt.com/?q=Expl%C3%ADcame%20c%C3%B3mo%20eliminar%20ordenadamente%20un%20cl%C3%BAster%20Aurora%20PostgreSQL%20con%20instancia%20writer%2C%20reader%2C%20DB%20Subnet%20Group%2C%20Parameter%20Group%20y%20Security%20Group%20usando%20AWS%20CLI.)

---

# ✅ Validación final del laboratorio

Al finalizar la práctica, debes haber completado lo siguiente:

| Elemento | Estado esperado |
|---|---|
| CloudShell validado | Correcto |
| Variables `AURORA_*` | Definidas |
| Cluster endpoint | Identificado |
| Reader endpoint | Identificado |
| Writer inicial | Identificado |
| Reader objetivo | Identificado |
| Réplica reader | Disponible |
| Monitor Python | Ejecutado |
| Failover manual | Ejecutado |
| Clúster | Estado `available` |
| Cluster endpoint post-failover | `pg_is_in_recovery() = false` |
| Reader endpoint post-failover | `pg_is_in_recovery() = true` en condiciones normales |
| Eventos RDS | Consultados |
| Evidencia | Guardada |
| Estado final previo a limpieza | Validado |
| Limpieza de recursos del laboratorio | Completada si el instructor la solicitó |

---

# 🧠 Resultado esperado de aprendizaje

Después de completar este laboratorio, debes poder explicar y ejecutar el flujo básico de alta disponibilidad en Aurora PostgreSQL:

1. Validar CloudShell y variables de conexión.
2. Identificar writer y reader.
3. Entender el rol del cluster endpoint.
4. Entender el rol del reader endpoint.
5. Crear una réplica reader si el clúster no tiene una.
6. Monitorear conectividad antes y durante un failover.
7. Ejecutar failover manual con AWS CLI.
8. Medir el RTO observado.
9. Validar los endpoints después del failover.
10. Revisar eventos RDS.
11. Guardar evidencia operativa.
12. Validar el estado final previo a limpieza.
13. Ejecutar limpieza controlada de infraestructura si el instructor lo solicita.

---

# 📌 Resumen del laboratorio

En este laboratorio trabajaste con AWS CloudShell y Amazon Aurora PostgreSQL para validar un escenario real de alta disponibilidad. Identificaste la topología writer/reader del clúster, creaste o confirmaste una réplica reader, construiste un monitor de conectividad en Python, ejecutaste un failover manual y mediste el RTO observado. Después validaste que el cluster endpoint siguiera apuntando al writer lógico del clúster, revisaste el comportamiento del reader endpoint, consultaste eventos RDS y guardaste evidencia del proceso. Finalmente, validaste que el clúster estuviera estable antes de la limpieza y ejecutaste, si el instructor lo solicitó, una eliminación controlada de los recursos de Aurora creados para la práctica.
