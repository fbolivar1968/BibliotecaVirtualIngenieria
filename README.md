# Biblioteca Virtual de Ingeniería con Calculadoras Normativas e IA — Forjas Bolívar

Plataforma web modular centralizada para transformar normas técnicas (DIN, ISO, ASME/ANSI, ASTM, SAE), catálogos de ingeniería y modelos matemáticos en **calculadoras determinísticas trazables**, **biblioteca documental controlada** y **asistente explicativo RAG con citas**.

---

## 1. Principios Arquitectónicos Obligatorios (SAD v1.0 & DDD v2.0)

1. **Calculator First:** Todo resultado numérico crítico se resuelve mediante el motor determinístico en Python (`calculators/`) usando `Decimal`/`NUMERIC(24,12)`. Prohibido usar punto flotante (`float`) o generación libre de LLM para decisiones de tolerancia o diseño.
2. **Inmutabilidad y Trazabilidad:** Las versiones publicadas de normas, materiales, catálogos y calculadoras son inmutables. Cada ejecución conserva un snapshot completo de entradas, salidas, advertencias y dependencias (`dependency_snapshot`).
3. **Fail Closed:** Entradas fuera de rango normativo o módulos no validados bloquean el cálculo y explican la restricción.
4. **Segregación de Funciones (RBAC):** Quien crea un borrador de norma, material, catálogo o calculadora no puede autoaprobarlo (`created_by != approved_by`).
5. **Persistencia Central:** PostgreSQL 16 + `pgvector` estructurado en 10 esquemas lógicos (`auth`, `library`, `standards`, `materials`, `catalog`, `calc`, `conversion`, `workflow`, `rag`, `ops`).

---

## 2. Organización del Repositorio (`Development/app/`)

```text
Development/app/
├── frontend/       # SPA en React 18 + TypeScript + Material UI + Vite
├── backend/        # API REST (/api/v1) en Python 3.12 + FastAPI + SQLAlchemy 2.0 + Celery
├── calculators/    # Motor normativo determinístico independiente (Python puro / Decimal) y Golden Tests
├── database/       # Inicialización PostgreSQL + pgvector, migraciones Alembic y datos semilla
├── docs/           # ADRs, contratos OpenAPI, evidencias de casos patrón y runbooks operativos
└── infra/          # Dockerfiles, Nginx reverse proxy, plantillas de entorno y scripts de backup
```

---

## 3. Inicio Rápido (Entorno Local con Docker)

1. Copiar variables de entorno:
   ```bash
   cp .env.example .env
   ```
2. Levantar los servicios base (PostgreSQL + `pgvector`, Redis, Backend API, Worker, Frontend):
   ```bash
   docker compose up -d --build
   ```
3. Verificar salud de la API:
   - Live check: `http://localhost:8000/api/v1/health/live`
   - Ready check: `http://localhost:8000/api/v1/health/ready`
   - Documentación OpenAPI: `http://localhost:8000/docs`
   - Aplicación Web (SPA): `http://localhost:5173`

