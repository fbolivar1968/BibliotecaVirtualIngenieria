# Diagrama de Despliegue e Infraestructura — Biblioteca Virtual de Ingeniería (Forjas Bolívar)

Este documento presenta la topología de despliegue **On-Premises** dentro de la red corporativa de **Forjas Bolívar**, alineada con la sección **10. Despliegue e infraestructura** del **Software Architecture Document (SAD v1.0)**.

---

## 1. Topología de Despliegue en Producción (Servidor Interno Corporativo)

```mermaid
flowchart TB
    subgraph CorpNet["Red Interna Corporativa Forjas Bolivar (LAN / VPN)"]
        USERS["Estaciones de Trabajo (20-30 Usuarios: Diseno, Proyectos, OP, Calidad)"]
        DNS["DNS Interno (bibliotecatecnica.forjasbolivar.local)"]
    end

    subgraph ProdHost["Servidor On-Premises de Produccion (16 Cores / 32 Threads, 128 GB RAM, 2 TB NVMe)"]
        subgraph DockerNet["Red de Contenedores Docker (fobol-engineering-net)"]
            NGINX["Reverse Proxy Nginx (TLS / HTTPS :443, Max Body 50MB)"]
            FE["Contenedor Frontend (React + Vite / Static Build)"]
            BE["Contenedor Backend API (Uvicorn + FastAPI + Motor Calculators :8000)"]
            WK["Contenedor Worker Asincrono (Celery: OCR Docling, Indexacion RAG, PDF/XLSX)"]
            RD["Contenedor Redis 7 (Broker de Colas y Rate Limiting :6379)"]
            PG_CONT["Contenedor PostgreSQL 16 + pgvector (:5432)"]
        end

        subgraph LocalAIService["Servicio de Inferencia IA Local (Aislado por Recursos / GPU 16-24 GB VRAM)"]
            LLM_SRV["Servidor Modelo Local (DeepSeek Cuantizado + Modelo Embeddings Multilingue)"]
        end

        subgraph PersistentStorage["Volumenes Persistentes en Disco NVMe Local (2 TB)"]
            VOL_PG[("Volumen postgres_data (10 Esquemas DDD + Indices HNSW)")]
            VOL_DOC[("Volumen storage_data/documents (300-500 PDFs Normativos Controlados)")]
            VOL_REP[("Volumen storage_data/reports (Memorias de Calculo PDF/XLSX)")]
            VOL_RD[("Volumen redis_data (Persistencia AOF de Colas)")]
        end
    end

    subgraph BackupNode["Almacenamiento Secundario / Servidor de Respaldo Corporativo"]
        BKP_STORAGE[("Repositorio de Backups Coordinados (pg_dump + Snapshots Archivos SHA-256)")]
    end

    USERS -->|"Resolucion de nombre"| DNS
    USERS -->|"HTTPS (:443)"| NGINX

    NGINX -->|"Rutas UI (/)"| FE
    NGINX -->|"Rutas API (/api/v1/*)"| BE

    BE -->|"Conexion Pool Async (psycopg3)"| PG_CONT
    BE -->|"Encola tareas y sesiones"| RD
    BE -->|"Consulta inferencia y embeddings"| LLM_SRV

    RD -->|"Consume colas documents_ocr_rag y reports"| WK
    WK -->|"Persiste fragmentos, vectores y estados"| PG_CONT
    WK -->|"Genera embeddings de PDFs"| LLM_SRV

    PG_CONT --> VOL_PG
    BE --> VOL_DOC
    BE --> VOL_REP
    WK --> VOL_DOC
    WK --> VOL_REP
    RD --> VOL_RD

    VOL_PG -.->|"Backup coordinado diario (RPO 24h / RTO 8h)"| BKP_STORAGE
    VOL_DOC -.->|"Sincronizacion verificada por SHA-256"| BKP_STORAGE
    VOL_REP -.->|"Sincronizacion verificada por SHA-256"| BKP_STORAGE
```

---

## 2. Flujo de Promoción entre Ambientes (Desarrollo → QA → Producción)

```mermaid
flowchart LR
    subgraph DevEnv["1. Ambiente de Desarrollo"]
        DEV_CODE["Codigo Fuente (frontend, backend, calculators, database)"]
        DEV_TEST["Pruebas Unitarias + Linter (Ruff/Mypy) + Golden Tests"]
    end

    subgraph QAEnv["2. Ambiente de QA / Piloto"]
        QA_MIG["Migraciones Alembic (Prueba Upgrade / Rollback)"]
        QA_UAT["Validacion de Casos Patron y Sesion Guiada con Usuarios"]
        QA_SEC["Pruebas de Seguridad RBAC, Segregacion y Rendimiento (p95 < 2s)"]
    end

    subgraph Gates["Compuertas de Aprobacion Dual (DDD §5.2 y §5.3)"]
        GATE_ENG["Aprobacion Tecnica: VALIDADOR_INGENIERIA"]
        GATE_IT["Autorizacion Despliegue: LIDER_TECNICO + PRODUCT_OWNER"]
    end

    subgraph ProdEnv["3. Ambiente de Produccion (On-Premises)"]
        PROD_DEPLOY["Despliegue de Imagenes Versionadas + Feature Flags"]
        PROD_MON["Observabilidad: Logs JSON, Telemetria LSS, CSAT y Alertas"]
    end

    DEV_CODE --> DEV_TEST
    DEV_TEST -->|"Build de Imagenes Docker"| QA_MIG
    QA_MIG --> QA_UAT
    QA_UAT --> QA_SEC
    QA_SEC --> GATE_ENG
    GATE_ENG --> GATE_IT
    GATE_IT -->|"Promocion controlada con Rollback listo"| PROD_DEPLOY
    PROD_DEPLOY --> PROD_MON
```

---

## 3. Especificaciones de Dimensionamiento (SAD §10.1)

| Recurso | Configuración Base (Piloto / Sin GPU) | Configuración Productiva Recomendada (Con RAG Local) |
| :--- | :--- | :--- |
| **CPU** | 12 núcleos | 16 núcleos / 32 hilos |
| **Memoria RAM** | 64 GB | 128 GB (aplicación, PostgreSQL, OCR e inferencia local) |
| **GPU** | No requerida para calculadoras normativas | 16–24 GB VRAM (para modelo DeepSeek cuantizado local) |
| **Almacenamiento** | 1 TB NVMe | 2 TB NVMe + nodo externo para backups coordinados |
| **Red** | 1 GbE corporativa | 1 GbE (o 10 GbE hacia almacenamiento de respaldos) |
| **RPO / RTO** | RPO 24 horas / RTO 8 horas | Respaldo coordinado de PostgreSQL + archivos (`SHA-256`) |

