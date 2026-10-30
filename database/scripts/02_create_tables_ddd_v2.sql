-- =============================================================================
-- DDL CONSOLIDADO DE BASE DE DATOS — DDD v2.0 (FORJAS BOLÍVAR)
-- Plataforma Centralizada de Conocimiento Técnico y Cálculos Parametrizados
-- Motor: PostgreSQL 16+ con pgvector
-- Convenciones (DDD §4):
--   * snake_case, tablas en singular, claves foráneas con sufijo _id
--   * PK BIGINT GENERATED ALWAYS AS IDENTITY para maestros; UUID para ejecuciones/consultas
--   * Fechas TIMESTAMPTZ en UTC; DATE para vigencias sin hora
--   * Magnitudes técnicas NUMERIC(24,12) o NUMERIC(30,15); prohibido FLOAT
-- =============================================================================

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET TIME ZONE 'UTC';

-- =============================================================================
-- 1. ESQUEMA: auth (Seguridad, Usuarios, RBAC y Estructura Organizacional - DDD §5)
-- =============================================================================

CREATE TABLE IF NOT EXISTS auth.rol (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    nivel_jerarquia SMALLINT NOT NULL DEFAULT 10,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_rol_codigo UNIQUE (codigo)
);

CREATE TABLE IF NOT EXISTS auth.permiso (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(100) NOT NULL,
    recurso VARCHAR(80) NOT NULL,
    accion VARCHAR(40) NOT NULL,
    descripcion TEXT,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_permiso_codigo UNIQUE (codigo)
);

CREATE TABLE IF NOT EXISTS auth.rol_permiso (
    rol_id BIGINT NOT NULL,
    permiso_id BIGINT NOT NULL,
    concedido BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_rol_permiso PRIMARY KEY (rol_id, permiso_id),
    CONSTRAINT fk_rol_permiso_rol_id_rol FOREIGN KEY (rol_id)
        REFERENCES auth.rol (id) ON DELETE RESTRICT,
    CONSTRAINT fk_rol_permiso_permiso_id_permiso FOREIGN KEY (permiso_id)
        REFERENCES auth.permiso (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS auth.usuario (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR(80) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    correo VARCHAR(200) NOT NULL,
    rol_id BIGINT,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    intentos_fallidos INTEGER NOT NULL DEFAULT 0,
    bloqueado_hasta TIMESTAMPTZ,
    password_changed_at TIMESTAMPTZ,
    ultimo_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_usuario_username UNIQUE (username),
    CONSTRAINT uq_usuario_correo UNIQUE (correo),
    CONSTRAINT ck_usuario_intentos_no_negativos CHECK (intentos_fallidos >= 0),
    CONSTRAINT fk_usuario_rol_id_rol FOREIGN KEY (rol_id)
        REFERENCES auth.rol (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS auth.unidad_organizacional (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    tipo VARCHAR(30) NOT NULL,
    parent_id BIGINT,
    lider_usuario_id BIGINT,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_unidad_organizacional_codigo UNIQUE (codigo),
    CONSTRAINT ck_unidad_organizacional_tipo CHECK (tipo IN ('CORPORATIVO', 'AREA', 'EQUIPO')),
    CONSTRAINT fk_unidad_organizacional_parent_id FOREIGN KEY (parent_id)
        REFERENCES auth.unidad_organizacional (id) ON DELETE RESTRICT,
    CONSTRAINT fk_unidad_organizacional_lider_usuario_id FOREIGN KEY (lider_usuario_id)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS auth.usuario_rol (
    usuario_id BIGINT NOT NULL,
    rol_id BIGINT NOT NULL,
    unidad_organizacional_id BIGINT,
    alcance VARCHAR(20) NOT NULL DEFAULT 'UNIDAD',
    vigente_desde DATE NOT NULL DEFAULT CURRENT_DATE,
    vigente_hasta DATE,
    asignado_por BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_usuario_rol PRIMARY KEY (usuario_id, rol_id, vigente_desde),
    CONSTRAINT ck_usuario_rol_alcance CHECK (alcance IN ('GLOBAL', 'UNIDAD', 'PROPIO')),
    CONSTRAINT ck_usuario_rol_vigencia CHECK (vigente_hasta IS NULL OR vigente_desde <= vigente_hasta),
    CONSTRAINT fk_usuario_rol_usuario_id FOREIGN KEY (usuario_id)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT,
    CONSTRAINT fk_usuario_rol_rol_id FOREIGN KEY (rol_id)
        REFERENCES auth.rol (id) ON DELETE RESTRICT,
    CONSTRAINT fk_usuario_rol_unidad_id FOREIGN KEY (unidad_organizacional_id)
        REFERENCES auth.unidad_organizacional (id) ON DELETE RESTRICT,
    CONSTRAINT fk_usuario_rol_asignado_por FOREIGN KEY (asignado_por)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS auth.usuario_unidad (
    usuario_id BIGINT NOT NULL,
    unidad_id BIGINT NOT NULL,
    cargo VARCHAR(100) NOT NULL,
    es_lider BOOLEAN NOT NULL DEFAULT FALSE,
    vigente_desde DATE NOT NULL DEFAULT CURRENT_DATE,
    vigente_hasta DATE,
    CONSTRAINT pk_usuario_unidad PRIMARY KEY (usuario_id, unidad_id, vigente_desde),
    CONSTRAINT ck_usuario_unidad_vigencia CHECK (vigente_hasta IS NULL OR vigente_desde <= vigente_hasta),
    CONSTRAINT fk_usuario_unidad_usuario_id FOREIGN KEY (usuario_id)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT,
    CONSTRAINT fk_usuario_unidad_unidad_id FOREIGN KEY (unidad_id)
        REFERENCES auth.unidad_organizacional (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS auth.refresh_token (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id BIGINT NOT NULL,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    replaced_by_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_refresh_token_hash UNIQUE (token_hash),
    CONSTRAINT fk_refresh_token_usuario_id FOREIGN KEY (usuario_id)
        REFERENCES auth.usuario (id) ON DELETE CASCADE,
    CONSTRAINT fk_refresh_token_replaced_by_id FOREIGN KEY (replaced_by_id)
        REFERENCES auth.refresh_token (id) ON DELETE SET NULL
);


-- =============================================================================
-- 2. ESQUEMA: library (Biblioteca Documental, Versiones, OCR y Fragmentos - DDD §6)
-- =============================================================================

CREATE TABLE IF NOT EXISTS library.documento (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(150) NOT NULL,
    titulo VARCHAR(300) NOT NULL,
    categoria VARCHAR(100) NOT NULL,
    propietario VARCHAR(200) NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'BORRADOR',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_documento_codigo UNIQUE (codigo),
    CONSTRAINT ck_documento_estado CHECK (estado IN ('BORRADOR', 'EN_REVISION', 'PUBLICADO', 'OBSOLETO', 'RETIRADO'))
);

CREATE TABLE IF NOT EXISTS library.documento_version (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    documento_id BIGINT NOT NULL,
    version VARCHAR(50) NOT NULL,
    archivo_uri TEXT NOT NULL,
    checksum_sha256 CHAR(64) NOT NULL,
    mime_type VARCHAR(100) NOT NULL DEFAULT 'application/pdf',
    size_bytes BIGINT NOT NULL,
    idioma VARCHAR(20) NOT NULL DEFAULT 'es',
    estado VARCHAR(30) NOT NULL DEFAULT 'BORRADOR',
    created_by BIGINT NOT NULL,
    approved_by BIGINT,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_documento_version UNIQUE (documento_id, version),
    CONSTRAINT ck_documento_version_size CHECK (size_bytes > 0),
    CONSTRAINT ck_documento_version_estado CHECK (estado IN ('BORRADOR', 'EN_VALIDACION', 'VALIDADO', 'PUBLICADO', 'OBSOLETO', 'RETIRADO')),
    CONSTRAINT ck_documento_version_segregacion CHECK (approved_by IS NULL OR created_by <> approved_by),
    CONSTRAINT fk_documento_version_documento_id FOREIGN KEY (documento_id)
        REFERENCES library.documento (id) ON DELETE RESTRICT,
    CONSTRAINT fk_documento_version_created_by FOREIGN KEY (created_by)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT,
    CONSTRAINT fk_documento_version_approved_by FOREIGN KEY (approved_by)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS library.documento_extraccion (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    documento_version_id BIGINT NOT NULL,
    motor VARCHAR(100) NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    confianza_ocr NUMERIC(5,4),
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    error TEXT,
    CONSTRAINT ck_documento_extraccion_estado CHECK (estado IN ('PENDIENTE', 'PROCESANDO', 'COMPLETADO', 'FALLIDO')),
    CONSTRAINT ck_documento_extraccion_confianza CHECK (confianza_ocr IS NULL OR (confianza_ocr >= 0 AND confianza_ocr <= 1)),
    CONSTRAINT fk_documento_extraccion_doc_version_id FOREIGN KEY (documento_version_id)
        REFERENCES library.documento_version (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS library.documento_fragmento (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    documento_version_id BIGINT NOT NULL,
    pagina_inicio INTEGER NOT NULL,
    pagina_fin INTEGER NOT NULL,
    seccion VARCHAR(300),
    texto TEXT NOT NULL,
    token_count INTEGER NOT NULL DEFAULT 0,
    embedding VECTOR(1024),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_documento_fragmento_paginas CHECK (pagina_inicio >= 1 AND pagina_inicio <= pagina_fin),
    CONSTRAINT ck_documento_fragmento_tokens CHECK (token_count >= 0),
    CONSTRAINT fk_documento_fragmento_doc_version_id FOREIGN KEY (documento_version_id)
        REFERENCES library.documento_version (id) ON DELETE RESTRICT
);


-- =============================================================================
-- 3. ESQUEMA: conversion (Categorías y Unidades Base - DDD §10)
-- Nota: Se crea categoria_conversion y unidad antes de standards/materials/catalog
-- para satisfacer las referencias FK de unidad_id.
-- =============================================================================

CREATE TABLE IF NOT EXISTS conversion.categoria_conversion (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    dimension_si VARCHAR(80) NOT NULL,
    tipo_transformacion VARCHAR(20) NOT NULL DEFAULT 'LINEAL',
    descripcion TEXT,
    CONSTRAINT uq_categoria_conversion_codigo UNIQUE (codigo),
    CONSTRAINT ck_categoria_conversion_tipo CHECK (tipo_transformacion IN ('LINEAL', 'AFIN', 'TABULAR', 'FORMULA'))
);

CREATE TABLE IF NOT EXISTS conversion.unidad (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    categoria_id BIGINT NOT NULL,
    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    simbolo VARCHAR(30) NOT NULL,
    sistema VARCHAR(20) NOT NULL DEFAULT 'SI',
    factor_base NUMERIC(30,15) NOT NULL DEFAULT 1,
    offset_base NUMERIC(30,15) NOT NULL DEFAULT 0,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_unidad_categoria_codigo UNIQUE (categoria_id, codigo),
    CONSTRAINT ck_unidad_sistema CHECK (sistema IN ('SI', 'IMPERIAL', 'DIN', 'ISO', 'ASTM', 'SAE', 'AGMA', 'OTRO')),
    CONSTRAINT ck_unidad_factor_no_cero CHECK (factor_base <> 0),
    CONSTRAINT fk_unidad_categoria_id FOREIGN KEY (categoria_id)
        REFERENCES conversion.categoria_conversion (id) ON DELETE RESTRICT
);


-- =============================================================================
-- 4. ESQUEMA: standards (Normas, Versiones, Fuentes, Tablas y Reglas - DDD §6)
-- =============================================================================

CREATE TABLE IF NOT EXISTS standards.norma (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organismo VARCHAR(50) NOT NULL,
    codigo VARCHAR(100) NOT NULL,
    nombre VARCHAR(300) NOT NULL,
    familia VARCHAR(100) NOT NULL,
    descripcion TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_norma_organismo_codigo UNIQUE (organismo, codigo)
);

CREATE TABLE IF NOT EXISTS standards.norma_version (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    norma_id BIGINT NOT NULL,
    edicion VARCHAR(100) NOT NULL,
    vigente_desde DATE NOT NULL,
    vigente_hasta DATE,
    estado VARCHAR(30) NOT NULL DEFAULT 'BORRADOR',
    documento_version_id BIGINT,
    created_by BIGINT NOT NULL,
    approved_by BIGINT,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_norma_version_edicion UNIQUE (norma_id, edicion),
    CONSTRAINT ck_norma_version_vigencia CHECK (vigente_hasta IS NULL OR vigente_desde <= vigente_hasta),
    CONSTRAINT ck_norma_version_estado CHECK (estado IN ('BORRADOR', 'EN_VALIDACION', 'APROBADA', 'PUBLICADO', 'OBSOLETO', 'RETIRADO')),
    CONSTRAINT ck_norma_version_segregacion CHECK (approved_by IS NULL OR created_by <> approved_by),
    CONSTRAINT fk_norma_version_norma_id FOREIGN KEY (norma_id)
        REFERENCES standards.norma (id) ON DELETE RESTRICT,
    CONSTRAINT fk_norma_version_documento_version_id FOREIGN KEY (documento_version_id)
        REFERENCES library.documento_version (id) ON DELETE RESTRICT,
    CONSTRAINT fk_norma_version_created_by FOREIGN KEY (created_by)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT,
    CONSTRAINT fk_norma_version_approved_by FOREIGN KEY (approved_by)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS standards.fuente_normativa (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    norma_version_id BIGINT NOT NULL,
    pagina INTEGER NOT NULL,
    tabla VARCHAR(100),
    seccion VARCHAR(200),
    nota TEXT,
    CONSTRAINT ck_fuente_normativa_pagina CHECK (pagina >= 1),
    CONSTRAINT fk_fuente_normativa_norma_version_id FOREIGN KEY (norma_version_id)
        REFERENCES standards.norma_version (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS standards.tabla_normativa (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    norma_version_id BIGINT NOT NULL,
    codigo VARCHAR(100) NOT NULL,
    nombre VARCHAR(200) NOT NULL,
    unidad_base_id BIGINT,
    esquema_columnas JSONB NOT NULL DEFAULT '[]'::jsonb,
    CONSTRAINT uq_tabla_normativa_version_codigo UNIQUE (norma_version_id, codigo),
    CONSTRAINT fk_tabla_normativa_norma_version_id FOREIGN KEY (norma_version_id)
        REFERENCES standards.norma_version (id) ON DELETE RESTRICT,
    CONSTRAINT fk_tabla_normativa_unidad_base_id FOREIGN KEY (unidad_base_id)
        REFERENCES conversion.unidad (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS standards.detalle_tabla_normativa (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tabla_normativa_id BIGINT NOT NULL,
    limite_inferior NUMERIC(24,12),
    limite_superior NUMERIC(24,12),
    inclusivo_inferior BOOLEAN NOT NULL DEFAULT TRUE,
    inclusivo_superior BOOLEAN NOT NULL DEFAULT TRUE,
    valores JSONB NOT NULL DEFAULT '{}'::jsonb,
    fuente_id BIGINT,
    CONSTRAINT ck_detalle_tabla_normativa_limites CHECK (
        limite_inferior IS NULL OR limite_superior IS NULL OR limite_inferior <= limite_superior
    ),
    CONSTRAINT fk_detalle_tabla_normativa_tabla_id FOREIGN KEY (tabla_normativa_id)
        REFERENCES standards.tabla_normativa (id) ON DELETE RESTRICT,
    CONSTRAINT fk_detalle_tabla_normativa_fuente_id FOREIGN KEY (fuente_id)
        REFERENCES standards.fuente_normativa (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS standards.regla_normativa (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    norma_version_id BIGINT NOT NULL,
    codigo VARCHAR(100) NOT NULL,
    descripcion TEXT,
    expresion TEXT,
    variables JSONB NOT NULL DEFAULT '{}'::jsonb,
    unidad_salida_id BIGINT,
    redondeo JSONB NOT NULL DEFAULT '{}'::jsonb,
    fuente_id BIGINT,
    CONSTRAINT uq_regla_normativa_version_codigo UNIQUE (norma_version_id, codigo),
    CONSTRAINT fk_regla_normativa_norma_version_id FOREIGN KEY (norma_version_id)
        REFERENCES standards.norma_version (id) ON DELETE RESTRICT,
    CONSTRAINT fk_regla_normativa_unidad_salida_id FOREIGN KEY (unidad_salida_id)
        REFERENCES conversion.unidad (id) ON DELETE RESTRICT,
    CONSTRAINT fk_regla_normativa_fuente_id FOREIGN KEY (fuente_id)
        REFERENCES standards.fuente_normativa (id) ON DELETE RESTRICT
);


-- =============================================================================
-- 5. ESQUEMA: conversion (Tablas dependientes de fuente_normativa y norma_version)
-- =============================================================================

CREATE TABLE IF NOT EXISTS conversion.conversion_no_lineal (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    categoria_id BIGINT NOT NULL,
    unidad_origen_id BIGINT NOT NULL,
    unidad_destino_id BIGINT NOT NULL,
    version VARCHAR(50) NOT NULL,
    metodo VARCHAR(30) NOT NULL,
    parametros JSONB NOT NULL DEFAULT '{}'::jsonb,
    fuente_id BIGINT,
    estado VARCHAR(30) NOT NULL DEFAULT 'PUBLICADO',
    CONSTRAINT uq_conversion_no_lineal UNIQUE (unidad_origen_id, unidad_destino_id, version),
    CONSTRAINT ck_conversion_no_lineal_estado CHECK (estado IN ('BORRADOR', 'PUBLICADO', 'OBSOLETO')),
    CONSTRAINT fk_conversion_no_lineal_categoria_id FOREIGN KEY (categoria_id)
        REFERENCES conversion.categoria_conversion (id) ON DELETE RESTRICT,
    CONSTRAINT fk_conversion_no_lineal_origen_id FOREIGN KEY (unidad_origen_id)
        REFERENCES conversion.unidad (id) ON DELETE RESTRICT,
    CONSTRAINT fk_conversion_no_lineal_destino_id FOREIGN KEY (unidad_destino_id)
        REFERENCES conversion.unidad (id) ON DELETE RESTRICT,
    CONSTRAINT fk_conversion_no_lineal_fuente_id FOREIGN KEY (fuente_id)
        REFERENCES standards.fuente_normativa (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS conversion.escala_dureza (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(20) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    metodo VARCHAR(100) NOT NULL,
    rango_min NUMERIC(12,4),
    rango_max NUMERIC(12,4),
    norma_version_id BIGINT,
    CONSTRAINT uq_escala_dureza_codigo UNIQUE (codigo),
    CONSTRAINT ck_escala_dureza_rango CHECK (rango_min IS NULL OR rango_max IS NULL OR rango_min <= rango_max),
    CONSTRAINT fk_escala_dureza_norma_version_id FOREIGN KEY (norma_version_id)
        REFERENCES standards.norma_version (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS conversion.conversion_dureza (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    escala_origen_id BIGINT NOT NULL,
    escala_destino_id BIGINT NOT NULL,
    material_family VARCHAR(100) NOT NULL DEFAULT 'CARBON_ALLOY_STEEL',
    valor_origen NUMERIC(12,4) NOT NULL,
    valor_destino NUMERIC(12,4) NOT NULL,
    tolerancia NUMERIC(12,4),
    fuente_id BIGINT NOT NULL,
    version VARCHAR(50) NOT NULL DEFAULT '1.0',
    CONSTRAINT fk_conversion_dureza_origen_id FOREIGN KEY (escala_origen_id)
        REFERENCES conversion.escala_dureza (id) ON DELETE RESTRICT,
    CONSTRAINT fk_conversion_dureza_destino_id FOREIGN KEY (escala_destino_id)
        REFERENCES conversion.escala_dureza (id) ON DELETE RESTRICT,
    CONSTRAINT fk_conversion_dureza_fuente_id FOREIGN KEY (fuente_id)
        REFERENCES standards.fuente_normativa (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS conversion.ejecucion_conversion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id BIGINT,
    categoria_id BIGINT NOT NULL,
    unidad_origen_id BIGINT NOT NULL,
    unidad_destino_id BIGINT NOT NULL,
    valor_origen NUMERIC(30,15) NOT NULL,
    valor_resultado NUMERIC(30,15) NOT NULL,
    conversion_version VARCHAR(50) NOT NULL DEFAULT '1.0',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_ejecucion_conversion_usuario_id FOREIGN KEY (usuario_id)
        REFERENCES auth.usuario (id) ON DELETE SET NULL,
    CONSTRAINT fk_ejecucion_conversion_categoria_id FOREIGN KEY (categoria_id)
        REFERENCES conversion.categoria_conversion (id) ON DELETE RESTRICT,
    CONSTRAINT fk_ejecucion_conversion_origen_id FOREIGN KEY (unidad_origen_id)
        REFERENCES conversion.unidad (id) ON DELETE RESTRICT,
    CONSTRAINT fk_ejecucion_conversion_destino_id FOREIGN KEY (unidad_destino_id)
        REFERENCES conversion.unidad (id) ON DELETE RESTRICT
);


-- =============================================================================
-- 6. ESQUEMA: materials (Materiales, Propiedades Mecánicas/Físicas y Equivalencias - DDD §7)
-- =============================================================================

CREATE TABLE IF NOT EXISTS materials.material (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(200) NOT NULL,
    familia VARCHAR(100) NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'ACTIVO',
    created_by BIGINT NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_material_codigo UNIQUE (codigo),
    CONSTRAINT fk_material_created_by FOREIGN KEY (created_by)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS materials.material_version (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    material_id BIGINT NOT NULL,
    version VARCHAR(50) NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'BORRADOR',
    aprobada BOOLEAN NOT NULL DEFAULT FALSE,
    especificacion VARCHAR(150),
    fabricante VARCHAR(150),
    observaciones TEXT,
    created_by BIGINT NOT NULL,
    approved_by BIGINT,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_material_version UNIQUE (material_id, version),
    CONSTRAINT ck_material_version_estado CHECK (estado IN ('BORRADOR', 'EN_VALIDACION', 'APROBADA', 'PUBLICADO', 'OBSOLETO', 'RECHAZADO')),
    CONSTRAINT ck_material_version_segregacion CHECK (approved_by IS NULL OR created_by <> approved_by),
    CONSTRAINT fk_material_version_material_id FOREIGN KEY (material_id)
        REFERENCES materials.material (id) ON DELETE RESTRICT,
    CONSTRAINT fk_material_version_created_by FOREIGN KEY (created_by)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT,
    CONSTRAINT fk_material_version_approved_by FOREIGN KEY (approved_by)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS materials.tipo_propiedad (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    grupo VARCHAR(30) NOT NULL,
    unidad_base_id BIGINT NOT NULL,
    tipo_dato VARCHAR(20) NOT NULL DEFAULT 'NUMERIC',
    CONSTRAINT uq_tipo_propiedad_codigo UNIQUE (codigo),
    CONSTRAINT ck_tipo_propiedad_grupo CHECK (grupo IN ('MECANICA', 'FISICA', 'QUIMICA', 'TERMICA')),
    CONSTRAINT fk_tipo_propiedad_unidad_base_id FOREIGN KEY (unidad_base_id)
        REFERENCES conversion.unidad (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS materials.propiedad_material (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    material_version_id BIGINT NOT NULL,
    tipo_propiedad_id BIGINT NOT NULL,
    valor_min NUMERIC(24,12),
    valor_nominal NUMERIC(24,12),
    valor_max NUMERIC(24,12),
    unidad_id BIGINT NOT NULL,
    temperatura_referencia NUMERIC(12,4) NOT NULL DEFAULT 20.0000,
    fuente_id BIGINT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT uq_propiedad_material_unica UNIQUE (
        material_version_id, tipo_propiedad_id, temperatura_referencia, unidad_id
    ),
    CONSTRAINT ck_propiedad_material_rango CHECK (
        valor_min IS NULL OR valor_max IS NULL OR valor_min <= valor_max
    ),
    CONSTRAINT fk_propiedad_material_version_id FOREIGN KEY (material_version_id)
        REFERENCES materials.material_version (id) ON DELETE RESTRICT,
    CONSTRAINT fk_propiedad_material_tipo_id FOREIGN KEY (tipo_propiedad_id)
        REFERENCES materials.tipo_propiedad (id) ON DELETE RESTRICT,
    CONSTRAINT fk_propiedad_material_unidad_id FOREIGN KEY (unidad_id)
        REFERENCES conversion.unidad (id) ON DELETE RESTRICT,
    CONSTRAINT fk_propiedad_material_fuente_id FOREIGN KEY (fuente_id)
        REFERENCES standards.fuente_normativa (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS materials.aprobacion_material (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    material_version_id BIGINT NOT NULL,
    approved_by BIGINT NOT NULL,
    estado VARCHAR(30) NOT NULL,
    comentario TEXT,
    approved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_aprobacion_material_estado CHECK (estado IN ('APROBADO', 'RECHAZADO', 'DEVUELTO')),
    CONSTRAINT fk_aprobacion_material_version_id FOREIGN KEY (material_version_id)
        REFERENCES materials.material_version (id) ON DELETE RESTRICT,
    CONSTRAINT fk_aprobacion_material_approved_by FOREIGN KEY (approved_by)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS materials.equivalencia_material (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    material_version_origen_id BIGINT NOT NULL,
    material_version_destino_id BIGINT NOT NULL,
    norma_version_id BIGINT,
    nivel_equivalencia VARCHAR(30) NOT NULL,
    nota TEXT,
    CONSTRAINT ck_equivalencia_material_distintos CHECK (material_version_origen_id <> material_version_destino_id),
    CONSTRAINT ck_equivalencia_material_nivel CHECK (nivel_equivalencia IN ('DIRECTA', 'APROXIMADA', 'CONDICIONAL')),
    CONSTRAINT fk_equivalencia_material_origen_id FOREIGN KEY (material_version_origen_id)
        REFERENCES materials.material_version (id) ON DELETE RESTRICT,
    CONSTRAINT fk_equivalencia_material_destino_id FOREIGN KEY (material_version_destino_id)
        REFERENCES materials.material_version (id) ON DELETE RESTRICT,
    CONSTRAINT fk_equivalencia_material_norma_version_id FOREIGN KEY (norma_version_id)
        REFERENCES standards.norma_version (id) ON DELETE RESTRICT
);


-- =============================================================================
-- 7. ESQUEMA: catalog (Catálogos Estructurados y Catálogos PDF para RAG - DDD §7.1)
-- =============================================================================

CREATE TABLE IF NOT EXISTS catalog.catalogo_ingenieria (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(100) NOT NULL,
    nombre VARCHAR(200) NOT NULL,
    tipo VARCHAR(60) NOT NULL,
    descripcion TEXT,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_catalogo_ingenieria_codigo UNIQUE (codigo)
);

CREATE TABLE IF NOT EXISTS catalog.catalogo_version (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    catalogo_id BIGINT NOT NULL,
    version VARCHAR(50) NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'BORRADOR',
    norma_version_id BIGINT,
    esquema_atributos JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_by BIGINT NOT NULL,
    approved_by BIGINT,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_catalogo_version UNIQUE (catalogo_id, version),
    CONSTRAINT ck_catalogo_version_estado CHECK (estado IN ('BORRADOR', 'EN_VALIDACION', 'APROBADA', 'PUBLICADO', 'OBSOLETO', 'RETIRADO')),
    CONSTRAINT ck_catalogo_version_segregacion CHECK (approved_by IS NULL OR created_by <> approved_by),
    CONSTRAINT fk_catalogo_version_catalogo_id FOREIGN KEY (catalogo_id)
        REFERENCES catalog.catalogo_ingenieria (id) ON DELETE RESTRICT,
    CONSTRAINT fk_catalogo_version_norma_version_id FOREIGN KEY (norma_version_id)
        REFERENCES standards.norma_version (id) ON DELETE RESTRICT,
    CONSTRAINT fk_catalogo_version_created_by FOREIGN KEY (created_by)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT,
    CONSTRAINT fk_catalogo_version_approved_by FOREIGN KEY (approved_by)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS catalog.item_catalogo (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    catalogo_version_id BIGINT NOT NULL,
    item_code VARCHAR(100) NOT NULL,
    nombre VARCHAR(200) NOT NULL,
    atributos JSONB NOT NULL DEFAULT '{}'::jsonb,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fuente_id BIGINT,
    CONSTRAINT uq_item_catalogo_version_code UNIQUE (catalogo_version_id, item_code),
    CONSTRAINT fk_item_catalogo_version_id FOREIGN KEY (catalogo_version_id)
        REFERENCES catalog.catalogo_version (id) ON DELETE RESTRICT,
    CONSTRAINT fk_item_catalogo_fuente_id FOREIGN KEY (fuente_id)
        REFERENCES standards.fuente_normativa (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS catalog.catalogo_item_atributo (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    item_catalogo_id BIGINT NOT NULL,
    atributo_codigo VARCHAR(100) NOT NULL,
    atributo_nombre VARCHAR(200) NOT NULL,
    tipo_dato VARCHAR(30) NOT NULL,
    valor_numerico NUMERIC(24,12),
    valor_texto TEXT,
    valor_booleano BOOLEAN,
    unidad_id BIGINT,
    valor_min NUMERIC(24,12),
    valor_max NUMERIC(24,12),
    fuente_id BIGINT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    orden SMALLINT NOT NULL DEFAULT 0,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_catalogo_item_atributo UNIQUE (item_catalogo_id, atributo_codigo),
    CONSTRAINT ck_catalogo_item_atributo_tipo CHECK (tipo_dato IN ('NUMERIC', 'TEXT', 'BOOLEAN', 'RANGE')),
    CONSTRAINT ck_catalogo_item_atributo_rango CHECK (
        valor_min IS NULL OR valor_max IS NULL OR valor_min <= valor_max
    ),
    CONSTRAINT ck_catalogo_item_atributo_valor_unico CHECK (
        (CASE WHEN valor_numerico IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN valor_texto IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN valor_booleano IS NOT NULL THEN 1 ELSE 0 END) = 1
        OR (tipo_dato = 'RANGE' AND valor_min IS NOT NULL AND valor_max IS NOT NULL)
    ),
    CONSTRAINT fk_catalogo_item_atributo_item_id FOREIGN KEY (item_catalogo_id)
        REFERENCES catalog.item_catalogo (id) ON DELETE RESTRICT,
    CONSTRAINT fk_catalogo_item_atributo_unidad_id FOREIGN KEY (unidad_id)
        REFERENCES conversion.unidad (id) ON DELETE RESTRICT,
    CONSTRAINT fk_catalogo_item_atributo_fuente_id FOREIGN KEY (fuente_id)
        REFERENCES standards.fuente_normativa (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS catalog.catalogo_pdf (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    catalogo_version_id BIGINT NOT NULL,
    documento_version_id BIGINT NOT NULL,
    fabricante VARCHAR(200) NOT NULL,
    categoria VARCHAR(100) NOT NULL,
    idioma VARCHAR(20) NOT NULL DEFAULT 'es',
    titulo_comercial VARCHAR(300) NOT NULL,
    anio_publicacion INTEGER,
    estado VARCHAR(30) NOT NULL DEFAULT 'BORRADOR',
    procesado_rag BOOLEAN NOT NULL DEFAULT FALSE,
    created_by BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_catalogo_pdf_version_doc UNIQUE (catalogo_version_id, documento_version_id),
    CONSTRAINT ck_catalogo_pdf_estado CHECK (estado IN ('BORRADOR', 'EN_VALIDACION', 'PUBLICADO', 'OBSOLETO')),
    CONSTRAINT fk_catalogo_pdf_catalogo_version_id FOREIGN KEY (catalogo_version_id)
        REFERENCES catalog.catalogo_version (id) ON DELETE RESTRICT,
    CONSTRAINT fk_catalogo_pdf_documento_version_id FOREIGN KEY (documento_version_id)
        REFERENCES library.documento_version (id) ON DELETE RESTRICT,
    CONSTRAINT fk_catalogo_pdf_created_by FOREIGN KEY (created_by)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS catalog.catalogo_pdf_seccion (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    catalogo_pdf_id BIGINT NOT NULL,
    parent_id BIGINT,
    codigo VARCHAR(100),
    titulo VARCHAR(500) NOT NULL,
    nivel SMALLINT NOT NULL DEFAULT 1,
    pagina_inicio INTEGER NOT NULL,
    pagina_fin INTEGER NOT NULL,
    orden INTEGER NOT NULL DEFAULT 0,
    texto_resumen TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT ck_catalogo_pdf_seccion_paginas CHECK (pagina_inicio >= 1 AND pagina_inicio <= pagina_fin),
    CONSTRAINT fk_catalogo_pdf_seccion_pdf_id FOREIGN KEY (catalogo_pdf_id)
        REFERENCES catalog.catalogo_pdf (id) ON DELETE RESTRICT,
    CONSTRAINT fk_catalogo_pdf_seccion_parent_id FOREIGN KEY (parent_id)
        REFERENCES catalog.catalogo_pdf_seccion (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS catalog.catalogo_pdf_tabla (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    catalogo_pdf_id BIGINT NOT NULL,
    seccion_id BIGINT,
    codigo VARCHAR(100),
    nombre VARCHAR(300) NOT NULL,
    pagina INTEGER NOT NULL,
    pagina_fin INTEGER,
    encabezados JSONB NOT NULL DEFAULT '[]'::jsonb,
    contenido_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    texto_indexable TEXT NOT NULL,
    confianza_extraccion NUMERIC(5,4) NOT NULL DEFAULT 1.0000,
    estado_validacion VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    fuente_fragmento_id BIGINT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT ck_catalogo_pdf_tabla_confianza CHECK (confianza_extraccion >= 0 AND confianza_extraccion <= 1),
    CONSTRAINT ck_catalogo_pdf_tabla_estado CHECK (estado_validacion IN ('PENDIENTE', 'EN_REVISION', 'VALIDADA', 'DESCARTADA')),
    CONSTRAINT fk_catalogo_pdf_tabla_pdf_id FOREIGN KEY (catalogo_pdf_id)
        REFERENCES catalog.catalogo_pdf (id) ON DELETE RESTRICT,
    CONSTRAINT fk_catalogo_pdf_tabla_seccion_id FOREIGN KEY (seccion_id)
        REFERENCES catalog.catalogo_pdf_seccion (id) ON DELETE RESTRICT,
    CONSTRAINT fk_catalogo_pdf_tabla_fragmento_id FOREIGN KEY (fuente_fragmento_id)
        REFERENCES library.documento_fragmento (id) ON DELETE SET NULL
);


-- =============================================================================
-- 8. ESQUEMA: calc (Calculadoras, Fórmulas, Casos Patrón, Ejecuciones y Reportes - DDD §8)
-- =============================================================================

CREATE TABLE IF NOT EXISTS calc.calculadora (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(100) NOT NULL,
    nombre VARCHAR(250) NOT NULL,
    dominio VARCHAR(60) NOT NULL,
    descripcion TEXT,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_calculadora_codigo UNIQUE (codigo)
);

CREATE TABLE IF NOT EXISTS calc.calculadora_version (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    calculadora_id BIGINT NOT NULL,
    version VARCHAR(50) NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'BORRADOR',
    algoritmo_version VARCHAR(50) NOT NULL DEFAULT '1.0.0',
    input_schema JSONB NOT NULL DEFAULT '{}'::jsonb,
    output_schema JSONB NOT NULL DEFAULT '{}'::jsonb,
    released_at TIMESTAMPTZ,
    created_by BIGINT NOT NULL,
    approved_by BIGINT,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_calculadora_version UNIQUE (calculadora_id, version),
    CONSTRAINT ck_calculadora_version_estado CHECK (
        estado IN ('BORRADOR', 'EN_VALIDACION', 'APROBADA', 'PUBLICADO', 'RETIRADA')
    ),
    CONSTRAINT ck_calculadora_version_segregacion CHECK (approved_by IS NULL OR created_by <> approved_by),
    CONSTRAINT fk_calculadora_version_calculadora_id FOREIGN KEY (calculadora_id)
        REFERENCES calc.calculadora (id) ON DELETE RESTRICT,
    CONSTRAINT fk_calculadora_version_created_by FOREIGN KEY (created_by)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT,
    CONSTRAINT fk_calculadora_version_approved_by FOREIGN KEY (approved_by)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS calc.formula_version (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    calculadora_version_id BIGINT NOT NULL,
    formula_code VARCHAR(100) NOT NULL,
    version VARCHAR(50) NOT NULL,
    descripcion TEXT,
    source_code_hash CHAR(64) NOT NULL,
    build_id VARCHAR(100),
    publicada BOOLEAN NOT NULL DEFAULT FALSE,
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_formula_version UNIQUE (calculadora_version_id, formula_code, version),
    CONSTRAINT fk_formula_version_calc_version_id FOREIGN KEY (calculadora_version_id)
        REFERENCES calc.calculadora_version (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS calc.dependencia_calculadora (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    calculadora_version_id BIGINT NOT NULL,
    tipo_dependencia VARCHAR(30) NOT NULL,
    dependencia_id BIGINT NOT NULL,
    obligatoria BOOLEAN NOT NULL DEFAULT TRUE,
    alias VARCHAR(100) NOT NULL,
    prioridad SMALLINT NOT NULL DEFAULT 1,
    condicion JSONB NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT ck_dependencia_calculadora_tipo CHECK (
        tipo_dependencia IN (
            'NORMA_VERSION', 'TABLA_NORMATIVA', 'CATALOGO_VERSION',
            'MATERIAL_VERSION', 'UNIDAD', 'FORMULA_VERSION', 'PARAMETRO_SISTEMA'
        )
    ),
    CONSTRAINT fk_dependencia_calculadora_calc_version_id FOREIGN KEY (calculadora_version_id)
        REFERENCES calc.calculadora_version (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS calc.parametro_calculadora (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    calculadora_version_id BIGINT NOT NULL,
    codigo VARCHAR(100) NOT NULL,
    etiqueta VARCHAR(200) NOT NULL,
    tipo_dato VARCHAR(30) NOT NULL,
    unidad_categoria_id BIGINT,
    requerido BOOLEAN NOT NULL DEFAULT TRUE,
    valor_min NUMERIC(24,12),
    valor_max NUMERIC(24,12),
    opciones JSONB NOT NULL DEFAULT '[]'::jsonb,
    orden SMALLINT NOT NULL DEFAULT 0,
    CONSTRAINT uq_parametro_calculadora UNIQUE (calculadora_version_id, codigo),
    CONSTRAINT ck_parametro_calculadora_limites CHECK (
        valor_min IS NULL OR valor_max IS NULL OR valor_min <= valor_max
    ),
    CONSTRAINT fk_parametro_calculadora_calc_version_id FOREIGN KEY (calculadora_version_id)
        REFERENCES calc.calculadora_version (id) ON DELETE RESTRICT,
    CONSTRAINT fk_parametro_calculadora_unidad_cat_id FOREIGN KEY (unidad_categoria_id)
        REFERENCES conversion.categoria_conversion (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS calc.caso_prueba (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    calculadora_version_id BIGINT NOT NULL,
    codigo VARCHAR(100) NOT NULL,
    descripcion TEXT,
    input_data JSONB NOT NULL,
    expected_output JSONB NOT NULL,
    tolerancia JSONB NOT NULL DEFAULT '{}'::jsonb,
    fuente_id BIGINT,
    obligatorio BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_caso_prueba_version_codigo UNIQUE (calculadora_version_id, codigo),
    CONSTRAINT fk_caso_prueba_calc_version_id FOREIGN KEY (calculadora_version_id)
        REFERENCES calc.calculadora_version (id) ON DELETE RESTRICT,
    CONSTRAINT fk_caso_prueba_fuente_id FOREIGN KEY (fuente_id)
        REFERENCES standards.fuente_normativa (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS calc.validacion_tecnica (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    calculadora_version_id BIGINT NOT NULL,
    caso_prueba_id BIGINT NOT NULL,
    ejecutado_por BIGINT NOT NULL,
    resultado VARCHAR(20) NOT NULL,
    actual_output JSONB NOT NULL DEFAULT '{}'::jsonb,
    evidencia_uri TEXT,
    executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_validacion_tecnica_resultado CHECK (resultado IN ('APROBADO', 'FALLIDO', 'BLOQUEADO')),
    CONSTRAINT fk_validacion_tecnica_calc_version_id FOREIGN KEY (calculadora_version_id)
        REFERENCES calc.calculadora_version (id) ON DELETE RESTRICT,
    CONSTRAINT fk_validacion_tecnica_caso_id FOREIGN KEY (caso_prueba_id)
        REFERENCES calc.caso_prueba (id) ON DELETE RESTRICT,
    CONSTRAINT fk_validacion_tecnica_ejecutado_por FOREIGN KEY (ejecutado_por)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS calc.ejecucion_calculo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id BIGINT NOT NULL,
    calculadora_version_id BIGINT NOT NULL,
    formula_version_id BIGINT NOT NULL,
    input_snapshot JSONB NOT NULL,
    dependency_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
    output_snapshot JSONB NOT NULL,
    warnings JSONB NOT NULL DEFAULT '[]'::jsonb,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_ejecucion_calculo_duration CHECK (duration_ms >= 0),
    CONSTRAINT fk_ejecucion_calculo_usuario_id FOREIGN KEY (usuario_id)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT,
    CONSTRAINT fk_ejecucion_calculo_calc_version_id FOREIGN KEY (calculadora_version_id)
        REFERENCES calc.calculadora_version (id) ON DELETE RESTRICT,
    CONSTRAINT fk_ejecucion_calculo_formula_version_id FOREIGN KEY (formula_version_id)
        REFERENCES calc.formula_version (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS calc.plantilla_reporte (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(100) NOT NULL,
    formato VARCHAR(10) NOT NULL,
    version VARCHAR(50) NOT NULL,
    archivo_uri TEXT NOT NULL,
    checksum CHAR(64) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_plantilla_reporte UNIQUE (codigo, formato, version),
    CONSTRAINT ck_plantilla_reporte_formato CHECK (formato IN ('PDF', 'XLSX'))
);

CREATE TABLE IF NOT EXISTS calc.reporte_generado (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ejecucion_id UUID NOT NULL,
    plantilla_id BIGINT NOT NULL,
    formato VARCHAR(10) NOT NULL,
    archivo_uri TEXT NOT NULL,
    checksum CHAR(64) NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'GENERADO',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_reporte_generado_formato CHECK (formato IN ('PDF', 'XLSX')),
    CONSTRAINT ck_reporte_generado_estado CHECK (estado IN ('PENDIENTE', 'GENERADO', 'FALLIDO')),
    CONSTRAINT fk_reporte_generado_ejecucion_id FOREIGN KEY (ejecucion_id)
        REFERENCES calc.ejecucion_calculo (id) ON DELETE RESTRICT,
    CONSTRAINT fk_reporte_generado_plantilla_id FOREIGN KEY (plantilla_id)
        REFERENCES calc.plantilla_reporte (id) ON DELETE RESTRICT
);


-- =============================================================================
-- 9. ESQUEMA: workflow (Flujos, Pasos, Solicitudes e Historial de Aprobación - DDD §11)
-- =============================================================================

CREATE TABLE IF NOT EXISTS workflow.flujo_aprobacion (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(100) NOT NULL,
    nombre VARCHAR(200) NOT NULL,
    tipo_entidad VARCHAR(60) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_flujo_aprobacion_codigo UNIQUE (codigo)
);

CREATE TABLE IF NOT EXISTS workflow.paso_aprobacion (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    flujo_id BIGINT NOT NULL,
    orden SMALLINT NOT NULL,
    rol_id BIGINT NOT NULL,
    unidad_tipo VARCHAR(30) NOT NULL DEFAULT 'AREA',
    obligatorio BOOLEAN NOT NULL DEFAULT TRUE,
    requiere_segregacion BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_paso_aprobacion_flujo_orden UNIQUE (flujo_id, orden),
    CONSTRAINT fk_paso_aprobacion_flujo_id FOREIGN KEY (flujo_id)
        REFERENCES workflow.flujo_aprobacion (id) ON DELETE RESTRICT,
    CONSTRAINT fk_paso_aprobacion_rol_id FOREIGN KEY (rol_id)
        REFERENCES auth.rol (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS workflow.solicitud_aprobacion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flujo_id BIGINT NOT NULL,
    entity_type VARCHAR(60) NOT NULL,
    entity_id VARCHAR(80) NOT NULL,
    solicitante_id BIGINT NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    current_step SMALLINT NOT NULL DEFAULT 1,
    motivo TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_solicitud_aprobacion_estado CHECK (
        estado IN ('PENDIENTE', 'EN_PROCESO', 'APROBADA', 'RECHAZADA', 'DEVUELTA', 'CANCELADA')
    ),
    CONSTRAINT fk_solicitud_aprobacion_flujo_id FOREIGN KEY (flujo_id)
        REFERENCES workflow.flujo_aprobacion (id) ON DELETE RESTRICT,
    CONSTRAINT fk_solicitud_aprobacion_solicitante_id FOREIGN KEY (solicitante_id)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS workflow.historial_aprobacion (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    solicitud_id UUID NOT NULL,
    paso_id BIGINT NOT NULL,
    usuario_id BIGINT NOT NULL,
    accion VARCHAR(30) NOT NULL,
    comentario TEXT,
    evidencia_uri TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_historial_aprobacion_accion CHECK (
        accion IN ('SOLICITAR', 'APROBAR', 'RECHAZAR', 'DEVOLVER', 'CANCELAR')
    ),
    CONSTRAINT fk_historial_aprobacion_solicitud_id FOREIGN KEY (solicitud_id)
        REFERENCES workflow.solicitud_aprobacion (id) ON DELETE RESTRICT,
    CONSTRAINT fk_historial_aprobacion_paso_id FOREIGN KEY (paso_id)
        REFERENCES workflow.paso_aprobacion (id) ON DELETE RESTRICT,
    CONSTRAINT fk_historial_aprobacion_usuario_id FOREIGN KEY (usuario_id)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT
);


-- =============================================================================
-- 10. ESQUEMA: rag (Modelos, Prompts, Consultas con Citas y Feedback - DDD §12)
-- =============================================================================

CREATE TABLE IF NOT EXISTS rag.modelo_embedding (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    version VARCHAR(50) NOT NULL,
    dimension INTEGER NOT NULL DEFAULT 1024,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_modelo_embedding UNIQUE (nombre, version),
    CONSTRAINT ck_modelo_embedding_dimension CHECK (dimension > 0)
);

CREATE TABLE IF NOT EXISTS rag.prompt_version (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(100) NOT NULL,
    version VARCHAR(50) NOT NULL,
    contenido_hash CHAR(64) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_prompt_version UNIQUE (codigo, version)
);

CREATE TABLE IF NOT EXISTS rag.consulta_rag (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id BIGINT NOT NULL,
    pregunta TEXT NOT NULL,
    respuesta TEXT,
    modelo VARCHAR(150) NOT NULL,
    prompt_version_id BIGINT,
    estado VARCHAR(30) NOT NULL DEFAULT 'COMPLETADA',
    duration_ms INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_consulta_rag_estado CHECK (estado IN ('COMPLETADA', 'DERIVADA_CALCULADORA', 'ABSTENCION_EVIDENCIA', 'ERROR')),
    CONSTRAINT fk_consulta_rag_usuario_id FOREIGN KEY (usuario_id)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT,
    CONSTRAINT fk_consulta_rag_prompt_version_id FOREIGN KEY (prompt_version_id)
        REFERENCES rag.prompt_version (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS rag.consulta_rag_fuente (
    consulta_id UUID NOT NULL,
    fragmento_id BIGINT NOT NULL,
    rank INTEGER NOT NULL,
    score NUMERIC(12,8) NOT NULL,
    usado_en_respuesta BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_consulta_rag_fuente PRIMARY KEY (consulta_id, fragmento_id),
    CONSTRAINT fk_consulta_rag_fuente_consulta_id FOREIGN KEY (consulta_id)
        REFERENCES rag.consulta_rag (id) ON DELETE CASCADE,
    CONSTRAINT fk_consulta_rag_fuente_fragmento_id FOREIGN KEY (fragmento_id)
        REFERENCES library.documento_fragmento (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS rag.feedback (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id BIGINT NOT NULL,
    object_type VARCHAR(40) NOT NULL,
    object_id VARCHAR(100) NOT NULL,
    calificacion SMALLINT NOT NULL,
    comentario TEXT,
    estado VARCHAR(30) NOT NULL DEFAULT 'REGISTRADO',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_feedback_calificacion CHECK (calificacion BETWEEN 1 AND 5),
    CONSTRAINT ck_feedback_object_type CHECK (object_type IN ('CALCULO', 'DOCUMENTO', 'NORMA', 'CONSULTA_RAG', 'SISTEMA')),
    CONSTRAINT fk_feedback_usuario_id FOREIGN KEY (usuario_id)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT
);


-- =============================================================================
-- 11. ESQUEMA: ops (Auditoría, Versionado Transversal, Trabajos Async y Outbox - DDD §11-12)
-- =============================================================================

CREATE TABLE IF NOT EXISTS ops.version_entidad (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_type VARCHAR(60) NOT NULL,
    entity_id VARCHAR(80) NOT NULL,
    version VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL,
    payload_hash CHAR(64) NOT NULL,
    created_by BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_version_entidad UNIQUE (entity_type, entity_id, version),
    CONSTRAINT fk_version_entidad_created_by FOREIGN KEY (created_by)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS ops.cambio_entidad (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    version_entidad_id BIGINT NOT NULL,
    before_data JSONB,
    after_data JSONB NOT NULL,
    changed_by BIGINT NOT NULL,
    motivo TEXT,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_cambio_entidad_version_id FOREIGN KEY (version_entidad_id)
        REFERENCES ops.version_entidad (id) ON DELETE RESTRICT,
    CONSTRAINT fk_cambio_entidad_changed_by FOREIGN KEY (changed_by)
        REFERENCES auth.usuario (id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS ops.auditoria (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id BIGINT,
    accion VARCHAR(100) NOT NULL,
    entidad VARCHAR(80) NOT NULL,
    entidad_id VARCHAR(100),
    resultado VARCHAR(20) NOT NULL DEFAULT 'EXITO',
    ip_origen INET,
    correlation_id UUID,
    detalle JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_auditoria_usuario_id FOREIGN KEY (usuario_id)
        REFERENCES auth.usuario (id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS ops.trabajo_async (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo VARCHAR(50) NOT NULL,
    recurso_tipo VARCHAR(50) NOT NULL,
    recurso_id VARCHAR(100) NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    progreso NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    intentos INTEGER NOT NULL DEFAULT 0,
    error TEXT,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_trabajo_async_progreso CHECK (progreso >= 0 AND progreso <= 100),
    CONSTRAINT ck_trabajo_async_estado CHECK (estado IN ('PENDIENTE', 'EN_PROGRESO', 'COMPLETADO', 'FALLIDO', 'CANCELADO'))
);

CREATE TABLE IF NOT EXISTS ops.outbox_event (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type VARCHAR(50) NOT NULL,
    aggregate_id VARCHAR(100) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ
);


-- =============================================================================
-- 12. REGLAS DE INMUTABILIDAD Y SEGREGACIÓN MEDIANTE TRIGGERS (DDD §1.1 y §13)
-- =============================================================================

CREATE OR REPLACE FUNCTION ops.fn_prevent_immutable_modification()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' AND OLD.estado IN ('PUBLICADO', 'APROBADA') THEN
        RAISE EXCEPTION 'Operación prohibida (DDD §13): No se permite eliminar una versión en estado % (% id=%).',
            OLD.estado, TG_TABLE_NAME, OLD.id;
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.estado = 'PUBLICADO' THEN
        -- Solo se permite transicionar de PUBLICADO a OBSOLETO o RETIRADO/RETIRADA
        IF NEW.estado NOT IN ('OBSOLETO', 'RETIRADO', 'RETIRADA') THEN
            RAISE EXCEPTION 'Inmutabilidad técnica (DDD §1.1): Una versión PUBLICADA no admite modificaciones directas (% id=%). Cree una nueva versión.',
                TG_TABLE_NAME, OLD.id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_immutable_norma_version ON standards.norma_version;
CREATE TRIGGER trg_immutable_norma_version
    BEFORE UPDATE OR DELETE ON standards.norma_version
    FOR EACH ROW EXECUTE FUNCTION ops.fn_prevent_immutable_modification();

DROP TRIGGER IF EXISTS trg_immutable_material_version ON materials.material_version;
CREATE TRIGGER trg_immutable_material_version
    BEFORE UPDATE OR DELETE ON materials.material_version
    FOR EACH ROW EXECUTE FUNCTION ops.fn_prevent_immutable_modification();

DROP TRIGGER IF EXISTS trg_immutable_catalogo_version ON catalog.catalogo_version;
CREATE TRIGGER trg_immutable_catalogo_version
    BEFORE UPDATE OR DELETE ON catalog.catalogo_version
    FOR EACH ROW EXECUTE FUNCTION ops.fn_prevent_immutable_modification();

DROP TRIGGER IF EXISTS trg_immutable_calculadora_version ON calc.calculadora_version;
CREATE TRIGGER trg_immutable_calculadora_version
    BEFORE UPDATE OR DELETE ON calc.calculadora_version
    FOR EACH ROW EXECUTE FUNCTION ops.fn_prevent_immutable_modification();


-- Trigger append-only para ejecuciones de cálculo, historial de aprobaciones y auditoría
CREATE OR REPLACE FUNCTION ops.fn_append_only_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Tabla append-only (DDD §8/§11): No se permite % sobre %.%',
        TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME;
END;
$$;

DROP TRIGGER IF EXISTS trg_append_only_ejecucion_calculo ON calc.ejecucion_calculo;
CREATE TRIGGER trg_append_only_ejecucion_calculo
    BEFORE UPDATE OR DELETE ON calc.ejecucion_calculo
    FOR EACH ROW EXECUTE FUNCTION ops.fn_append_only_guard();

DROP TRIGGER IF EXISTS trg_append_only_historial_aprobacion ON workflow.historial_aprobacion;
CREATE TRIGGER trg_append_only_historial_aprobacion
    BEFORE UPDATE OR DELETE ON workflow.historial_aprobacion
    FOR EACH ROW EXECUTE FUNCTION ops.fn_append_only_guard();

DROP TRIGGER IF EXISTS trg_append_only_auditoria ON ops.auditoria;
CREATE TRIGGER trg_append_only_auditoria
    BEFORE UPDATE OR DELETE ON ops.auditoria
    FOR EACH ROW EXECUTE FUNCTION ops.fn_append_only_guard();


-- =============================================================================
-- 13. ÍNDICES DE RENDIMIENTO Y BÚSQUEDA (DDD §7.1.2 y §14)
-- =============================================================================

-- Auth
CREATE UNIQUE INDEX IF NOT EXISTS ix_usuario_username_lower ON auth.usuario (LOWER(username));
CREATE INDEX IF NOT EXISTS ix_usuario_activo_bloqueado ON auth.usuario (activo, bloqueado_hasta);
CREATE INDEX IF NOT EXISTS ix_usuario_rol_lookup ON auth.usuario_rol (usuario_id, rol_id, unidad_organizacional_id, vigente_desde, vigente_hasta);

-- Library & Vector HNSW (pgvector)
CREATE INDEX IF NOT EXISTS ix_documento_cat_estado ON library.documento (categoria, estado);
CREATE INDEX IF NOT EXISTS ix_documento_fragmento_doc_version ON library.documento_fragmento (documento_version_id, pagina_inicio);
CREATE INDEX IF NOT EXISTS ix_documento_fragmento_embedding_hnsw
    ON library.documento_fragmento USING hnsw (embedding vector_cosine_ops);

-- Standards
CREATE INDEX IF NOT EXISTS ix_detalle_tabla_normativa_rangos
    ON standards.detalle_tabla_normativa (tabla_normativa_id, limite_inferior, limite_superior);
CREATE INDEX IF NOT EXISTS ix_detalle_tabla_normativa_valores_gin
    ON standards.detalle_tabla_normativa USING gin (valores);

-- Materials & Catalog (DDD §7.1.2)
CREATE INDEX IF NOT EXISTS ix_item_catalogo_atributos_gin
    ON catalog.item_catalogo USING gin (atributos);
CREATE INDEX IF NOT EXISTS ix_catalogo_item_atributo_lookup
    ON catalog.catalogo_item_atributo (item_catalogo_id, atributo_codigo);
CREATE INDEX IF NOT EXISTS ix_catalogo_item_atributo_num
    ON catalog.catalogo_item_atributo (atributo_codigo, valor_numerico)
    WHERE valor_numerico IS NOT NULL AND activo = TRUE;
CREATE INDEX IF NOT EXISTS ix_catalogo_pdf_lookup
    ON catalog.catalogo_pdf (catalogo_version_id, estado, procesado_rag);
CREATE INDEX IF NOT EXISTS ix_catalogo_pdf_seccion_paginas
    ON catalog.catalogo_pdf_seccion (catalogo_pdf_id, pagina_inicio, pagina_fin);
CREATE INDEX IF NOT EXISTS ix_catalogo_pdf_tabla_fts
    ON catalog.catalogo_pdf_tabla USING gin (to_tsvector('spanish', texto_indexable));

-- Calculators & Executions
CREATE INDEX IF NOT EXISTS ix_ejecucion_calculo_usuario_fecha
    ON calc.ejecucion_calculo (usuario_id, created_at DESC);
CREATE INDEX IF NOT EXISTS ix_ejecucion_calculo_version_fecha
    ON calc.ejecucion_calculo (calculadora_version_id, created_at DESC);

-- Audit & Ops
CREATE INDEX IF NOT EXISTS ix_auditoria_fecha ON ops.auditoria (created_at DESC);
CREATE INDEX IF NOT EXISTS ix_auditoria_usuario_entidad ON ops.auditoria (usuario_id, entidad, entidad_id);
CREATE INDEX IF NOT EXISTS ix_auditoria_correlation_id ON ops.auditoria (correlation_id);
CREATE INDEX IF NOT EXISTS ix_outbox_unprocessed ON ops.outbox_event (occurred_at) WHERE processed_at IS NULL;

