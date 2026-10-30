-- =============================================================================
-- INICIALIZACIÓN DE EXTENSIONES Y ESQUEMAS LÓGICOS (DDD v2.0 - Sección 2)
-- Motor: PostgreSQL 16+ con pgvector
-- =============================================================================

-- 1. Extensiones requeridas
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- 2. Esquemas lógicos por dominio (DDD §2)
CREATE SCHEMA IF NOT EXISTS auth;       -- Usuarios, roles, permisos, unidades organizacionales y sesiones
CREATE SCHEMA IF NOT EXISTS library;    -- Documentos, versiones, extracción OCR y fragmentos vectoriales
CREATE SCHEMA IF NOT EXISTS standards;  -- Normas, versiones, fuentes, tablas, rangos y reglas
CREATE SCHEMA IF NOT EXISTS materials;  -- Materiales, versiones, propiedades mecánicas/físicas y equivalencias
CREATE SCHEMA IF NOT EXISTS catalog;    -- Catálogos técnicos estructurados y catálogos PDF para RAG
CREATE SCHEMA IF NOT EXISTS calc;       -- Calculadoras, fórmulas, dependencias, casos patrón, ejecuciones y reportes
CREATE SCHEMA IF NOT EXISTS conversion; -- Magnitudes, unidades, conversiones lineales/no lineales y dureza
CREATE SCHEMA IF NOT EXISTS workflow;   -- Flujos, pasos, solicitudes e historial de aprobación (segregación)
CREATE SCHEMA IF NOT EXISTS rag;        -- Modelos de embedding, prompts, consultas RAG, citas y feedback
CREATE SCHEMA IF NOT EXISTS ops;        -- Auditoría, versionado transversal, trabajos asíncronos y outbox

-- 3. Configuración de search_path por defecto para la base de datos
ALTER DATABASE fobol_engineering_kb SET search_path TO
    public, auth, library, standards, materials, catalog, calc, conversion, workflow, rag, ops;

