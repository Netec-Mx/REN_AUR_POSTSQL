<p align="center">
  <img src="images/neteclogo (2).png" alt="Netec logo" width="300"/>
</p>

<h1 align="center">Rendimiento con Aurora PostgreSQL</h1>

<p align="center">
  <strong>Plataforma de laboratorios prácticos guiados</strong><br/>
  Optimización, concurrencia, alta disponibilidad, observabilidad y operación avanzada en Amazon Aurora PostgreSQL.
</p>

<p align="center">
  <a href="#-ruta-de-aprendizaje"><strong>Ruta de aprendizaje</strong></a> ·
  <a href="#-menú-de-laboratorios"><strong>Menú de laboratorios</strong></a> ·
  <a href="#-resumen-ejecutivo"><strong>Resumen ejecutivo</strong></a> ·
  <a href="#-contacto-y-más-información"><strong>Contacto</strong></a>
</p>

---

## Bienvenida

Te damos la bienvenida a la **plataforma de laboratorios** del curso **Rendimiento con Aurora PostgreSQL**. En este espacio trabajarás con prácticas guiadas para analizar, optimizar y operar entornos de **Amazon Aurora PostgreSQL** usando **AWS CloudShell**, **AWS CLI**, **psql**, métricas, logs, pruebas controladas y escenarios reales de administración.

Este curso está diseñado para participantes que necesitan comprender cómo mejorar el rendimiento, estabilidad y disponibilidad de bases de datos Aurora PostgreSQL. A lo largo de los laboratorios crearás entornos de prueba, ejecutarás consultas, analizarás planes de ejecución, reproducirás bloqueos y deadlocks, validarás failover, ajustarás parámetros, administrarás conexiones con RDS Proxy y usarás herramientas de observabilidad para diagnosticar problemas de rendimiento.

> **Objetivo de la plataforma:** que puedas avanzar laboratorio por laboratorio con instrucciones claras, comandos listos para ejecutar, validaciones por tarea y limpieza controlada de recursos para evitar costos innecesarios.

---

## Ruta de aprendizaje

La ruta está organizada de forma progresiva. Cada laboratorio refuerza una capacidad práctica y prepara el terreno para el siguiente.

| Bloque | Capítulos | Enfoque | Resultado esperado |
|---|---:|---|---|
| **Fundamentos de rendimiento** | 1 | Logs, tuning inicial, índices y planes de ejecución | Línea base de rendimiento y optimización inicial con evidencia |
| **Concurrencia y disponibilidad** | 2 | Sesiones, bloqueos, deadlocks, mitigación y failover | Diagnóstico de contención y validación de alta disponibilidad |
| **Optimización operativa** | 3 | Parámetros del motor, conexión eficiente y RDS Proxy | Entorno ajustado para cargas concurrentes y gestión estable de conexiones |
| **Observabilidad y diagnóstico avanzado** | 4 | Performance Insights, diagnóstico profundo y escenarios avanzados Aurora | Análisis integral, troubleshooting y operación avanzada de Aurora PostgreSQL |

---

## Recomendaciones antes de comenzar

- Trabaja los laboratorios en orden, especialmente los relacionados con concurrencia, parámetros y observabilidad.
- Usa **AWS CloudShell** como entorno principal de ejecución.
- Mantén estandarizadas las variables del laboratorio: `AWS_REGION`, `AURORA_CLUSTER_ID`, `AURORA_ENDPOINT`, `AURORA_DBNAME`, `AURORA_MASTER_USER` y `AURORA_MASTER_PASSWORD`.
- Ejecuta los scripts de preparación cuando el laboratorio lo indique.
- Valida cada reto antes de continuar con el siguiente.
- Ejecuta siempre la sección de limpieza cuando el laboratorio cree recursos temporales.
- No uses credenciales productivas ni datos reales en los laboratorios.

---

## Menú de laboratorios

### Capítulo 1 — Fundamentos de rendimiento, logs y tuning

| Campo | Detalle |
|---|---|
| **Laboratorio** | [Análisis de rendimiento con logs y tuning](Capitulo01/README.md) |
| **Descripción** | Crearás un entorno temporal de Aurora PostgreSQL, activarás slow query logging, cargarás datos OLTP de prueba, ejecutarás consultas sin índices y aplicarás índices para comparar planes de ejecución con `EXPLAIN (ANALYZE, BUFFERS)`. |
| **Resultado** | Entorno Aurora temporal, línea base de rendimiento, índices aplicados, comparación de planes y validación de slow queries. |
| **Duración estimada** | 45 min |

---

### Capítulo 2 — Concurrencia, bloqueos, deadlocks y alta disponibilidad

| Campo | Detalle |
|---|---|
| **Laboratorio** | [Análisis de sesiones y bloqueos](Capitulo02/Lab02_analisis_de_sesiones_y_bloqueos/README.md) |
| **Descripción** | Diagnosticarás sesiones activas, bloqueos de fila, sesiones `idle in transaction`, procesos bloqueadores y patrones seguros como `NOWAIT`, `SKIP LOCKED` y timeouts de sesión. |
| **Resultado** | Diagnóstico de bloqueos con `pg_stat_activity`, `pg_locks` y `pg_blocking_pids()`, además de limpieza controlada del esquema de laboratorio. |
| **Duración estimada** | 40 min |

| Campo | Detalle |
|---|---|
| **Laboratorio** | [Simulación de concurrencia, deadlocks y mitigación](Capitulo02/Lab03_simulacion_concurrencia_deadlocks/README.md) |
| **Descripción** | Reproducirás deadlocks manuales con dos sesiones `psql`, automatizarás la simulación con Python y `psycopg2`, y aplicarás mitigación mediante ordenamiento consistente de recursos. |
| **Resultado** | Deadlock reproducido, evidencia registrada, simulación automatizada, mitigación aplicada y resultados exportados en JSON. |
| **Duración estimada** | 35 min |

| Campo | Detalle |
|---|---|
| **Laboratorio** | [Alta disponibilidad y failover](Capitulo02/Lab04_alta_disponibilidad_failover/README.md) |
| **Descripción** | Implementarás y validarás escenarios de alta disponibilidad, comportamiento del endpoint writer/reader y proceso de failover en Aurora PostgreSQL. |
| **Resultado** | Validación práctica de disponibilidad, roles de instancias, endpoints y recuperación ante failover. |
| **Duración estimada** | 45 min |

---

### Capítulo 3 — Parámetros, optimización y gestión de conexiones

| Campo | Detalle |
|---|---|
| **Laboratorio** | [Ajuste de parámetros y optimización](Capitulo03/Lab05_ajuste_parametros_optimizacion/README.md) |
| **Descripción** | Revisarás parámetros críticos del motor PostgreSQL, aplicarás ajustes controlados y validarás su impacto mediante consultas y métricas. |
| **Resultado** | Parameter Group ajustado, validación de parámetros y evidencia de mejora o cambio operativo. |
| **Duración estimada** | 35 min |

| Campo | Detalle |
|---|---|
| **Laboratorio** | [Gestión de conexiones con RDS Proxy](Capitulo03/Lab06_gestion_conexiones_rds_proxy/README.md) |
| **Descripción** | Configurarás y evaluarás RDS Proxy para mejorar la administración de conexiones, reducir sobrecarga y estabilizar cargas concurrentes. |
| **Resultado** | RDS Proxy configurado, pruebas de conexión ejecutadas y comparación de comportamiento con conexiones directas. |
| **Duración estimada** | 35 min |

---

### Capítulo 4 — Observabilidad, diagnóstico y escenarios avanzados

| Campo | Detalle |
|---|---|
| **Laboratorio** | [Observabilidad avanzada con Performance Insights](Capitulo04/Lab07_observabilidad_performance_insights/README.md) |
| **Descripción** | Analizarás métricas, carga de base de datos, espera, consultas principales y patrones de consumo mediante Performance Insights y CloudWatch. |
| **Resultado** | Diagnóstico visual y técnico de carga, waits, SQL principales y oportunidades de optimización. |
| **Duración estimada** | 45 min |

| Campo | Detalle |
|---|---|
| **Laboratorio** | [Diagnóstico y optimización de rendimiento](Capitulo04/Lab08_diagnostico_optimizacion_rendimiento/README.md) |
| **Descripción** | Ejecutarás un diagnóstico integral de problemas de rendimiento y aplicarás acciones correctivas basadas en evidencia de planes, métricas y comportamiento del motor. |
| **Resultado** | Caso práctico de troubleshooting con hipótesis, validación, optimización y comparación antes/después. |
| **Duración estimada** | 45 min |

| Campo | Detalle |
|---|---|
| **Laboratorio** | [Arquitectura Aurora: optimización, observabilidad y DR](Capitulo04/Lab09_escenarios_avanzados_aurora/README.md) |
| **Descripción** | Diseñarás y ejecutarás escenarios avanzados de operación en Aurora PostgreSQL, incluyendo recuperación, validación multi-región y análisis integral. |
| **Resultado** | Flujo avanzado de operación, validación de arquitectura Aurora y limpieza completa de recursos temporales. |
| **Duración estimada** | 45 min |

---

## Resumen ejecutivo

| Capítulo | Laboratorio | Duración | Producto principal |
|---:|---|---:|---|
| 1 | Análisis de rendimiento con logs y tuning | 45 min | Línea base, slow logs e índices optimizados |
| 2 | Análisis de sesiones y bloqueos | 40 min | Diagnóstico de bloqueos y sesiones concurrentes |
| 2 | Simulación de concurrencia y deadlocks | 35 min | Deadlocks reproducidos y mitigados |
| 2 | Alta disponibilidad y failover | 45 min | Validación de failover y endpoints Aurora |
| 3 | Ajuste de parámetros y optimización | 35 min | Parámetros ajustados y validados |
| 3 | Gestión de conexiones con RDS Proxy | 35 min | Proxy configurado y pruebas de conexión |
| 4 | Observabilidad avanzada con Performance Insights | 45 min | Diagnóstico con métricas y waits |
| 4 | Diagnóstico y optimización de rendimiento | 45 min | Troubleshooting basado en evidencia |
| 4 | Arquitectura Aurora: optimización, observabilidad y DR | 45 min | Operación avanzada y validación integral |

---

## Contacto y más información

Si tienes alguna pregunta o necesitas más detalles, no dudes en [contactarnos](mailto:soporte@netec.com). También puedes encontrar más recursos en nuestra [página](https://netec.com).

---

<p align="center">
  <strong>¡Gracias por visitar nuestra plataforma!</strong><br/>
  No olvides revisar todos los laboratorios y comenzar tu viaje de aprendizaje hoy mismo.
</p>
