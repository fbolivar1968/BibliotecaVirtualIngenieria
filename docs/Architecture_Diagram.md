# Diagrama de Arquitectura del Proyecto — Biblioteca Virtual de Ingeniería (Forjas Bolívar)

Este documento visualiza la arquitectura lógica, de contenedores, de dominios (monolito modular) y de flujos de ejecución definida en el **Software Architecture Document (SAD v1.0)** y el **Database Design Document (DDD v2.0)**.

---

## 1. Vista General de Arquitectura y Contenedores (C4 Nivel 2 + Módulos)

```mermaid
flowchart TB
    subgraph Actors["Actores Organizacionales (Forjas Bolivar)"]
        ENG["Ingeniero / Proyectista / Dibujante"]
        VAL["Validador de Ingenieria Senior"]
        DOC["Gestor Documental / Analista Calidad"]
        ADM["Admin Sistema / Lider Tecnico / PO"]
    end

    subgraph ClientLayer["Capa de Presentacion (Navegador Web)"]
        SPA["Web SPA (React 18 + TypeScript + Material UI)"]
    end

    subgraph AppLayer["Capa de Aplicacion — Monolito Modular (FastAPI Python 3.12)"]
        GW["API REST (/api/v1) + Middleware JWT / RBAC / Correlation-ID"]

        subgraph DomainModules["Modulos de Dominio (backend/app/modules/)"]
            M_AUTH["auth: Identidad, RBAC y Unidades Org."]
            M_LIB["library: Gestion Documental y Versiones"]
            M_STD["standards: Normas, Tablas e Intervalos"]
            M_MAT["materials: Materiales y Propiedades"]
            M_CAT["catalog: Catalogos Estructurados y PDF"]
            M_CALC["calc: Orquestador de Calculos y Reportes"]
            M_CONV["conversion: Motor Universal de Unidades"]
            M_WF["workflow: Aprobaciones y Segregacion"]
            M_RAG["rag: Busqueda Hibrida, Citas y Feedback"]
            M_OPS["ops: Auditoria, Versionado y Outbox"]
        end
    end

    subgraph DeterministicCore["Nucleo Normativo Deterministico (calculators/)"]
        CALC_ENG["Motor Puro en Python (Decimal / Sin Float)"]
        CALC_MODS["17 Modulos Normativos (DIN 6885, ISO 286, ASME, Roscas, Cadenas, Resortes)"]
        GOLDEN["Suite de Casos Patron (Golden Tests)"]
    end

    subgraph AsyncLayer["Procesamiento Asincrono y Servicios IA Locales"]
        REDIS["Cola de Mensajes (Redis 7)"]
        WORKER["Worker Asincrono (Celery)"]
        DOCLING["Motor OCR y Extraccion Tabular (Docling)"]
        EMBED["Servicio de Embeddings Multilingues (1024-dim)"]
        LLM["Inferencia Local LLM (DeepSeek Cuantizado)"]
    end

    subgraph PersistenceLayer["Capa de Persistencia y Almacenamiento"]
        PG[("PostgreSQL 16 + pgvector (10 Esquemas DDD + Indices HNSW/GIN)")]
        FS[("Repositorio de Archivos (PDFs Originales y Memorias PDF/XLSX con Checksum SHA-256)")]
    end

    ENG --> SPA
    VAL --> SPA
    DOC --> SPA
    ADM --> SPA

    SPA -->|"HTTPS JSON (/api/v1)"| GW
    GW --> DomainModules

    M_CALC -->|"Invocacion sincrona deterministica"| CALC_ENG
    CALC_ENG --> CALC_MODS
    CALC_MODS -.->|"Verificado por"| GOLDEN

    M_LIB -->|"Encola ingesta / OCR"| REDIS
    M_CALC -->|"Encola reportes pesados"| REDIS
    REDIS --> WORKER

    WORKER --> DOCLING
    WORKER --> EMBED
    M_RAG --> EMBED
    M_RAG -->|"Generacion explicativa con citas"| LLM

    DomainModules -->|"SQLAlchemy 2.0 Async (NUMERIC / JSONB / VECTOR)"| PG
    WORKER -->|"Guarda fragmentos, tablas y vectores"| PG
    M_LIB -->|"URI + SHA-256"| FS
    M_CALC -->|"Memorias PDF/XLSX"| FS
    WORKER -->|"Lee PDF / Escribe Reportes"| FS
```

---

## 2. Flujo de Cálculo Normativo Determinístico ("Calculator First")

```mermaid
sequenceDiagram
    autonumber
    actor Ing as Ingeniero / Proyectista
    participant SPA as Frontend React
    participant API as FastAPI (Modulo calc)
    participant DB as PostgreSQL (standards / materials / catalog)
    participant Eng as Motor Deterministico (calculators/)
    participant FS as Almacenamiento Reportes

    Ing->>SPA: Ingresa parametros (ej. Eje d=45 mm, DIN 6885)
    SPA->>API: POST /api/v1/calculators/KEYWAY_DIN6885/execute
    API->>API: Valida JWT, permiso CALCULO_EJECUTAR y esquema Pydantic
    API->>DB: Carga version PUBLICADA de calculadora, norma, tablas y unidades
    DB-->>API: Datos normativos aprobados (NUMERIC) + hashes
    API->>Eng: Ejecuta funcion pura con Decimal y unidades normalizadas
    Eng->>Eng: Evalua rangos, formulas, redondeo normativo y advertencias
    Eng-->>API: StandardCalculationEnvelope (result, tolerances, warnings, traceability)
    API->>DB: Inserta registro inmutable (append-only) en calc.ejecucion_calculo
    API-->>SPA: Retorna resultado trazable (< 2 s) + execution_id
    opt Exportar Memoria de Calculo
        Ing->>SPA: Solicita exportar PDF / XLSX
        SPA->>API: POST /api/v1/calculations/{execution_id}/report
        API->>FS: Genera PDF/XLSX desde snapshot inmutable y calcula SHA-256
        API->>DB: Registra calc.reporte_generado
        API-->>SPA: Descarga Memoria de Calculo Oficial con QR / ID
    end
```

---

## 3. Flujo Documental y Consulta Asistente IA (RAG con Citas y Guardrails)

```mermaid
sequenceDiagram
    autonumber
    actor User as Usuario / Ingeniero
    participant SPA as Frontend React
    participant API as FastAPI (Modulo rag)
    participant PG as PostgreSQL + pgvector
    participant LLM as DeepSeek Local

    User->>SPA: Consulta en lenguaje natural (ej. "Grado 8 en SAE J429" o "Calcula chaveta de 50mm")
    SPA->>API: POST /api/v1/assistant/query
    API->>API: Clasifica intencion (Guardrail "Calculator First")
    alt Pregunta solicita calculo numerico critico
        API->>PG: Registra rag.consulta_rag (estado = DERIVADA_CALCULADORA)
        API-->>SPA: Redirige directamente a la Calculadora Normativa validada
    else Consulta documental / explicativa
        API->>PG: Busqueda hibrida (Texto completo + Vector HNSW en library.documento_fragmento y catalog.catalogo_pdf_tabla)
        PG-->>API: Top-K fragmentos de documentos PUBLICADOS con score y metadatos
        alt Confianza >= Umbral minimo
            API->>LLM: Prompt controlado + fragmentos recuperados (prohibido inventar datos)
            LLM-->>API: Respuesta explicativa con referencias
            API->>PG: Guarda rag.consulta_rag y rag.consulta_rag_fuente (rank, score)
            API-->>SPA: Muestra respuesta + Citas exactas (Documento, Edicion, Tabla, Pagina)
        else Evidencia insuficiente
            API->>PG: Registra rag.consulta_rag (estado = ABSTENCION_EVIDENCIA)
            API-->>SPA: Informa abstencion segura y muestra fragmentos originales sin afirmar valores
        end
    end
```
