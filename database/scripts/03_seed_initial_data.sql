-- =============================================================================
-- DATOS SEMILLA INICIALES (SEEDS) — DDD v2.0 (FORJAS BOLÍVAR)
-- Idempotente (ON CONFLICT DO NOTHING)
-- =============================================================================

SET client_encoding = 'UTF8';
SET TIME ZONE 'UTC';

-- =============================================================================
-- 1. ROLES RBAC ORGANIZACIONALES (DDD §5.1)
-- =============================================================================
INSERT INTO auth.rol (codigo, nombre, descripcion, nivel_jerarquia, activo) VALUES
    ('ADMIN_SISTEMA',        'Administrador del Sistema',      'TI/Desarrollo · Usuarios, roles, permisos, configuración, despliegues, monitoreo y backups.', 100, TRUE),
    ('LIDER_TECNICO',        'Líder Técnico TI',               'TI/Desarrollo · Aprueba pull requests, autoriza promoción técnica y coordina releases.', 85, TRUE),
    ('VALIDADOR_INGENIERIA', 'Validador de Ingeniería Senior', 'Ingeniería · Revisa casos patrón; aprueba o rechaza normas, materiales, catálogos y calculadoras.', 85, TRUE),
    ('PRODUCT_OWNER',        'Product Owner / PMO',            'Gerencia/PMO · Consulta tableros, adopción, entregas, feedback y cobertura documental.', 80, TRUE),
    ('AUDITOR',              'Auditor de Calidad / Control',   'Calidad/Gerencia · Lectura de historial, aprobaciones, reportes, cobertura y auditoría.', 75, TRUE),
    ('ANALISTA_CALIDAD',     'Analista de Calidad',            'Calidad · Ejecuta y registra pruebas, revisa trazabilidad, evidencias y no conformidades.', 70, TRUE),
    ('GESTOR_DOCUMENTAL',    'Gestor Documental',              'Calidad/Ingeniería · Carga documentos, gestiona metadatos, ediciones, vigencia y OCR.', 65, TRUE),
    ('DESARROLLADOR',        'Desarrollador de Plataforma',    'TI/Desarrollo · Crea versiones de calculadoras y fórmulas desde código; administra migraciones.', 60, TRUE),
    ('INGENIERO',            'Ingeniero / Proyectista',        'Ingeniería · Consulta normas/catálogos aprobados, ejecuta calculadoras, genera memorias y crea borradores de materiales.', 50, TRUE),
    ('CONSULTA',             'Usuario de Consulta',            'Cualquier área autorizada · Consulta documentos y calculadoras publicadas; ejecuta conversiones.', 10, TRUE)
ON CONFLICT (codigo) DO NOTHING;

-- =============================================================================
-- 2. PERMISOS ATÓMICOS (DDD §5)
-- =============================================================================
INSERT INTO auth.permiso (codigo, recurso, accion, descripcion) VALUES
    ('USUARIO_ADMINISTRAR',  'USUARIO',     'ADMINISTRAR', 'Gestionar usuarios, roles, bloqueos y asignaciones organizacionales'),
    ('DOCUMENTO_LEER',       'DOCUMENTO',   'LEER',        'Consultar documentos y fragmentos publicados en la biblioteca técnica'),
    ('DOCUMENTO_CARGAR',     'DOCUMENTO',   'CARGAR',      'Cargar documentos PDF, registrar metadatos y disparar OCR/indexación'),
    ('DOCUMENTO_APROBAR',    'DOCUMENTO',   'APROBAR',     'Aprobar técnicamente versiones documentales para publicación'),
    ('NORMA_LEER',           'NORMA',       'LEER',        'Consultar normas, tablas e intervalos publicados'),
    ('NORMA_ESTRUCTURAR',    'NORMA',       'ESTRUCTURAR', 'Crear o editar borradores de tablas y reglas normativas'),
    ('NORMA_APROBAR',        'NORMA',       'APROBAR',     'Aprobar o retirar versiones de normas estructuradas'),
    ('MATERIAL_LEER',        'MATERIAL',    'LEER',        'Consultar materiales y propiedades mecánicas/físicas aprobadas'),
    ('MATERIAL_CREAR',       'MATERIAL',    'CREAR',       'Crear borradores de materiales y propiedades para revisión'),
    ('MATERIAL_APROBAR',     'MATERIAL',    'APROBAR',     'Aprobar o rechazar versiones de materiales (con segregación de funciones)'),
    ('CATALOGO_LEER',        'CATALOGO',    'LEER',        'Consultar catálogos técnicos estructurados y catálogos PDF'),
    ('CATALOGO_EDITAR',      'CATALOGO',    'EDITAR',      'Crear borradores de catálogos e ítems técnicos'),
    ('CATALOGO_APROBAR',     'CATALOGO',    'APROBAR',     'Aprobar versiones de catálogos e ítems validados'),
    ('CALCULO_EJECUTAR',     'CALCULADORA', 'EJECUTAR',    'Ejecutar calculadoras normativas publicadas y conversiones'),
    ('CALCULADORA_CREAR',    'CALCULADORA', 'CREAR',       'Registrar versiones de calculadoras, fórmulas y casos patrón desde código'),
    ('CALCULADORA_VALIDAR',  'CALCULADORA', 'VALIDAR',     'Ejecutar casos patrón y registrar evidencias de validación técnica'),
    ('CALCULADORA_APROBAR',  'CALCULADORA', 'APROBAR',     'Aprobar técnicamente versiones de calculadoras (Ingeniería Senior)'),
    ('CALCULADORA_PUBLICAR', 'CALCULADORA', 'PUBLICAR',    'Autorizar despliegue productivo de calculadoras aprobadas (Líder Técnico)'),
    ('REPORTE_EXPORTAR',     'REPORTE',     'EXPORTAR',    'Generar y descargar memorias de cálculo en PDF y XLSX'),
    ('RAG_CONSULTAR',        'RAG',         'CONSULTAR',   'Realizar consultas al asistente inteligente con citas documentales'),
    ('AUDITORIA_LEER',       'AUDITORIA',   'LEER',        'Consultar bitácora de auditoría, historial de cambios y telemetría')
ON CONFLICT (codigo) DO NOTHING;

-- =============================================================================
-- 3. UNIDADES ORGANIZACIONALES DE FORJAS BOLÍVAR (DDD §5)
-- =============================================================================
INSERT INTO auth.unidad_organizacional (codigo, nombre, tipo, parent_id, activo) VALUES
    ('FOBOL_CORP', 'Forjas Bolívar S.A.S.', 'CORPORATIVO', NULL, TRUE)
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO auth.unidad_organizacional (codigo, nombre, tipo, parent_id, activo)
SELECT v.codigo, v.nombre, v.tipo, p.id, TRUE
FROM (VALUES
    ('AREA_INGENIERIA',  'Ingeniería, Diseño y Proyectos', 'AREA'),
    ('AREA_OPERACIONES', 'Operaciones y Planta (OP)',      'AREA'),
    ('AREA_CALIDAD',     'Gestión de Calidad',             'AREA'),
    ('AREA_TI_TD',       'TI / Transformación Digital',    'AREA'),
    ('AREA_GERENCIA',    'Gerencia / PMO / LSS',           'AREA')
) AS v(codigo, nombre, tipo)
CROSS JOIN auth.unidad_organizacional p
WHERE p.codigo = 'FOBOL_CORP'
ON CONFLICT (codigo) DO NOTHING;

-- =============================================================================
-- 4. CATEGORÍAS Y UNIDADES DE CONVERSIÓN (DDD §10.1 - 19 Categorías)
-- =============================================================================
INSERT INTO conversion.categoria_conversion (codigo, nombre, dimension_si, tipo_transformacion, descripcion) VALUES
    ('DUREZA',             'Dureza de Materiales',       'ADIMENSIONAL', 'TABULAR', 'Conversión tabular/interpolada entre escalas Brinell, Vickers, Rockwell y Knoop'),
    ('DISTANCIA',          'Longitud / Distancia',       'L',            'LINEAL',  'Conversión lineal hacia metro (m)'),
    ('PESO_MASA',          'Masa / Peso',                'M',            'LINEAL',  'Conversión lineal hacia kilogramo (kg)'),
    ('DENSIDAD',           'Densidad',                   'M·L^-3',       'LINEAL',  'Conversión lineal hacia kg/m³'),
    ('VOLUMEN',            'Volumen',                    'L^3',          'LINEAL',  'Conversión lineal hacia m³'),
    ('ACELERACION',        'Aceleración',                'L·T^-2',       'LINEAL',  'Conversión lineal hacia m/s²'),
    ('CAUDAL_VOLUMETRICO', 'Caudal Volumétrico',         'L^3·T^-1',     'LINEAL',  'Conversión lineal hacia m³/s'),
    ('CAUDAL_MASICO',      'Caudal Másico',              'M·T^-1',       'LINEAL',  'Conversión lineal hacia kg/s'),
    ('FUERZA',             'Fuerza',                     'M·L·T^-2',     'LINEAL',  'Conversión lineal hacia newton (N)'),
    ('ESFUERZO_PRESION',   'Esfuerzo / Presión',         'M·L^-1·T^-2',  'LINEAL',  'Conversión lineal hacia pascal (Pa)'),
    ('TEMPERATURA',        'Temperatura',                'Θ',            'AFIN',    'Conversión afín (factor y offset) hacia kelvin (K)'),
    ('POTENCIA',           'Potencia',                   'M·L^2·T^-3',   'LINEAL',  'Conversión lineal hacia watt (W)'),
    ('TORQUE',             'Torque / Momento Torsor',    'M·L^2·T^-2',   'LINEAL',  'Conversión lineal hacia N·m'),
    ('AREA',               'Área / Superficie',          'L^2',          'LINEAL',  'Conversión lineal hacia m²'),
    ('VELOCIDAD_LINEAL',   'Velocidad Lineal',           'L·T^-1',       'LINEAL',  'Conversión lineal hacia m/s'),
    ('VELOCIDAD_ANGULAR',  'Velocidad Angular',          'T^-1',         'LINEAL',  'Conversión lineal hacia rad/s'),
    ('ENERGIA',            'Energía / Trabajo',          'M·L^2·T^-2',   'LINEAL',  'Conversión lineal hacia joule (J)'),
    ('TIEMPO',             'Tiempo',                     'T',            'LINEAL',  'Conversión lineal hacia segundo (s)'),
    ('ANGULO',             'Ángulo Plano',               'ADIMENSIONAL', 'LINEAL',  'Conversión lineal hacia radián (rad)')
ON CONFLICT (codigo) DO NOTHING;

-- Unidades principales por categoría (DDD §10.1)
INSERT INTO conversion.unidad (categoria_id, codigo, nombre, simbolo, sistema, factor_base, offset_base)
SELECT c.id, u.codigo, u.nombre, u.simbolo, u.sistema, u.factor_base, u.offset_base
FROM (VALUES
    -- DISTANCIA (base: m)
    ('DISTANCIA', 'UM',  'Micrómetro',          'µm',      'SI',       0.000001000000000, 0),
    ('DISTANCIA', 'MM',  'Milímetro',           'mm',      'SI',       0.001000000000000, 0),
    ('DISTANCIA', 'CM',  'Centímetro',          'cm',      'SI',       0.010000000000000, 0),
    ('DISTANCIA', 'M',   'Metro',               'm',       'SI',       1.000000000000000, 0),
    ('DISTANCIA', 'IN',  'Pulgada',             'in',      'IMPERIAL', 0.025400000000000, 0),
    ('DISTANCIA', 'FT',  'Pie',                 'ft',      'IMPERIAL', 0.304800000000000, 0),
    -- PESO_MASA (base: kg)
    ('PESO_MASA', 'G',   'Gramo',               'g',       'SI',       0.001000000000000, 0),
    ('PESO_MASA', 'KG',  'Kilogramo',           'kg',      'SI',       1.000000000000000, 0),
    ('PESO_MASA', 'T',   'Tonelada métrica',    't',       'SI',       1000.000000000000, 0),
    ('PESO_MASA', 'LB',  'Libra masa',          'lb',      'IMPERIAL', 0.453592370000000, 0),
    -- FUERZA (base: N)
    ('FUERZA',    'N',   'Newton',              'N',       'SI',       1.000000000000000, 0),
    ('FUERZA',    'KN',  'Kilonewton',          'kN',      'SI',       1000.000000000000, 0),
    ('FUERZA',    'KGF', 'Kilogramo-fuerza',    'kgf',     'OTRO',     9.806650000000000, 0),
    ('FUERZA',    'TF',  'Tonelada-fuerza',     'tf',      'OTRO',     9806.650000000000, 0),
    ('FUERZA',    'LBF', 'Libra-fuerza',        'lbf',     'IMPERIAL', 4.448221615260500, 0),
    ('FUERZA',    'KIP', 'Kilolibra-fuerza',    'kip',     'IMPERIAL', 4448.221615260500, 0),
    -- ESFUERZO_PRESION (base: Pa)
    ('ESFUERZO_PRESION', 'PA',     'Pascal',            'Pa',      'SI',       1.000000000000000, 0),
    ('ESFUERZO_PRESION', 'KPA',    'Kilopascal',        'kPa',     'SI',       1000.000000000000, 0),
    ('ESFUERZO_PRESION', 'MPA',    'Megapascal',        'MPa',     'SI',       1000000.000000000, 0),
    ('ESFUERZO_PRESION', 'GPA',    'Gigapascal',        'GPa',     'SI',       1000000000.000000, 0),
    ('ESFUERZO_PRESION', 'BAR',    'Bar',               'bar',     'OTRO',     100000.0000000000, 0),
    ('ESFUERZO_PRESION', 'PSI',    'Libra/pulgada²',    'psi',     'IMPERIAL', 6894.757293168360, 0),
    ('ESFUERZO_PRESION', 'KSI',    'Kilolibra/pulgada²','ksi',     'IMPERIAL', 6894757.293168360, 0),
    ('ESFUERZO_PRESION', 'KGF_CM2','kgf/cm²',           'kgf/cm²', 'OTRO',     98066.50000000000, 0),
    -- TORQUE (base: N·m)
    ('TORQUE',    'NM',    'Newton-metro',      'N·m',     'SI',       1.000000000000000, 0),
    ('TORQUE',    'KNM',   'Kilonewton-metro',  'kN·m',    'SI',       1000.000000000000, 0),
    ('TORQUE',    'NMM',   'Newton-milímetro',  'N·mm',    'SI',       0.001000000000000, 0),
    ('TORQUE',    'KGFM',  'kgf-metro',         'kgf·m',   'OTRO',     9.806650000000000, 0),
    ('TORQUE',    'LBFFT', 'lbf-pie',           'lbf·ft',  'IMPERIAL', 1.355817948331400, 0),
    ('TORQUE',    'LBFIN', 'lbf-pulgada',       'lbf·in',  'IMPERIAL', 0.112984829027617, 0),
    -- POTENCIA (base: W)
    ('POTENCIA',  'W',     'Watt',              'W',       'SI',       1.000000000000000, 0),
    ('POTENCIA',  'KW',    'Kilowatt',          'kW',      'SI',       1000.000000000000, 0),
    ('POTENCIA',  'HP',    'Horsepower mecánico','hp',     'IMPERIAL', 745.6998715822700, 0),
    ('POTENCIA',  'CV',    'Caballo de vapor',  'CV',      'OTRO',     735.4987500000000, 0),
    -- VELOCIDAD_LINEAL (base: m/s)
    ('VELOCIDAD_LINEAL', 'MM_S',  'Milímetro/segundo', 'mm/s',   'SI',       0.001000000000000, 0),
    ('VELOCIDAD_LINEAL', 'M_S',   'Metro/segundo',     'm/s',    'SI',       1.000000000000000, 0),
    ('VELOCIDAD_LINEAL', 'FT_MIN','Pie/minuto',        'ft/min', 'IMPERIAL', 0.005080000000000, 0),
    -- VELOCIDAD_ANGULAR (base: rad/s)
    ('VELOCIDAD_ANGULAR', 'RAD_S', 'Radián/segundo',   'rad/s',  'SI',       1.000000000000000, 0),
    ('VELOCIDAD_ANGULAR', 'RPM',   'Revoluciones/min', 'rpm',    'OTRO',     0.104719755119660, 0),
    -- TEMPERATURA (base: K)
    ('TEMPERATURA', 'K',   'Kelvin',            'K',       'SI',       1.000000000000000, 0),
    ('TEMPERATURA', 'C',   'Grado Celsius',     '°C',      'SI',       1.000000000000000, 273.150000000000),
    ('TEMPERATURA', 'F',   'Grado Fahrenheit',  '°F',      'IMPERIAL', 0.555555555555556, 255.372222222222),
    -- DENSIDAD (base: kg/m³)
    ('DENSIDAD',  'KG_M3', 'kg/m³',             'kg/m³',   'SI',       1.000000000000000, 0),
    ('DENSIDAD',  'G_CM3', 'g/cm³',             'g/cm³',   'SI',       1000.000000000000, 0),
    -- AREA (base: m²)
    ('AREA',      'MM2',   'Milímetro cuadrado','mm²',     'SI',       0.000001000000000, 0),
    ('AREA',      'CM2',   'Centímetro cuadrado','cm²',    'SI',       0.000100000000000, 0),
    ('AREA',      'M2',    'Metro cuadrado',    'm²',      'SI',       1.000000000000000, 0),
    ('AREA',      'IN2',   'Pulgada cuadrada',  'in²',     'IMPERIAL', 0.000645160000000, 0),
    -- ANGULO (base: rad)
    ('ANGULO',    'RAD',   'Radián',            'rad',     'SI',       1.000000000000000, 0),
    ('ANGULO',    'DEG',   'Grado sexagesimal', '°',       'OTRO',     0.017453292519943, 0),
    -- TIEMPO (base: s)
    ('TIEMPO',    'S',     'Segundo',           's',       'SI',       1.000000000000000, 0),
    ('TIEMPO',    'MIN',   'Minuto',            'min',     'SI',       60.00000000000000, 0),
    ('TIEMPO',    'H',     'Hora',              'h',       'SI',       3600.000000000000, 0),
    -- DUREZA (adimensional)
    ('DUREZA',    'HB',    'Brinell Hardness',  'HB',      'ASTM',     1.000000000000000, 0),
    ('DUREZA',    'HRC',   'Rockwell C',        'HRC',     'ASTM',     1.000000000000000, 0),
    ('DUREZA',    'HV',    'Vickers Hardness',  'HV',      'ISO',      1.000000000000000, 0)
) AS u(cat_codigo, codigo, nombre, simbolo, sistema, factor_base, offset_base)
JOIN conversion.categoria_conversion c ON c.codigo = u.cat_codigo
ON CONFLICT (categoria_id, codigo) DO NOTHING;

-- =============================================================================
-- 5. ESCALAS DE DUREZA (DDD §10 - 13 Escalas)
-- =============================================================================
INSERT INTO conversion.escala_dureza (codigo, nombre, metodo, rango_min, rango_max) VALUES
    ('HB',    'Dureza Brinell Estándar',         'ASTM E10 / ISO 6506', 80,  650),
    ('HV',    'Dureza Vickers',                  'ASTM E92 / ISO 6507', 80,  1000),
    ('HK',    'Dureza Knoop',                    'ASTM E384',           100, 1000),
    ('HRA',   'Dureza Rockwell Escala A',        'ASTM E18 / ISO 6508', 60,  88),
    ('HRB',   'Dureza Rockwell Escala B',        'ASTM E18 / ISO 6508', 40,  100),
    ('HRC',   'Dureza Rockwell Escala C',        'ASTM E18 / ISO 6508', 20,  70),
    ('HRD',   'Dureza Rockwell Escala D',        'ASTM E18 / ISO 6508', 40,  77),
    ('HRE',   'Dureza Rockwell Escala E',        'ASTM E18 / ISO 6508', 70,  100),
    ('HRF',   'Dureza Rockwell Escala F',        'ASTM E18 / ISO 6508', 60,  100),
    ('HRG',   'Dureza Rockwell Escala G',        'ASTM E18 / ISO 6508', 30,  94),
    ('HR15N', 'Rockwell Superficial 15N',        'ASTM E18',            70,  94),
    ('HR30N', 'Rockwell Superficial 30N',        'ASTM E18',            42,  86),
    ('HR45N', 'Rockwell Superficial 45N',        'ASTM E18',            20,  77)
ON CONFLICT (codigo) DO NOTHING;

-- =============================================================================
-- 6. NORMAS BASE DEL INVENTARIO INICIAL (DDD §9 y User Stories)
-- =============================================================================
INSERT INTO standards.norma (organismo, codigo, nombre, familia, descripcion) VALUES
    ('DIN',  'DIN 6885',      'Chavetas paralelas y chaveteros — Dimensiones y aplicación', 'CHAVETAS',    'Dimensionamiento de chavetas, chaveteros de eje/cubo y tolerancias'),
    ('ISO',  'ISO 286',       'Sistema ISO de tolerancias y ajustes (IT y desviaciones)',   'TOLERANCIAS', 'Grados de tolerancia estándar y desviaciones fundamentales para ejes y agujeros'),
    ('DIN',  'DIN 7168',      'Tolerancias generales de dimensiones lineales y angulares',  'TOLERANCIAS', 'Tolerancias generales según clase fina, media, gruesa y muy gruesa'),
    ('ISO',  'ISO 68-1',      'Roscas de tornillo de propósito general ISO — Perfil básico','ROSCAS',      'Geometría y tolerancias de roscas métricas ISO internas y externas'),
    ('ASME', 'ASME B1.1',     'Unified Inch Screw Threads (UN, UNC, UNF, UNEF)',            'ROSCAS',      'Roscas unificadas en pulgadas, series y clases de ajuste 1A/2A/3A y 1B/2B/3B'),
    ('ASME', 'ASME B1.20.1',  'Pipe Threads, General Purpose (Inch) — NPT / NPS',           'ROSCAS',      'Roscas de tubería cónicas NPT y rectas NPS'),
    ('DIN',  'DIN 7346',      'Pasadores elásticos (pines ranurados) — Serie ligera',       'PINES',       'Dimensiones, tolerancias y carga cortante admisible de pines DIN 7346'),
    ('DIN',  'DIN 1481',      'Pasadores elásticos (pines ranurados) — Serie pesada',       'PINES',       'Dimensiones, tolerancias y carga cortante admisible de pines DIN 1481'),
    ('ASME', 'ASME B29.12M',  'Cadenas de transmisión y ruedas dentadas (Sprockets)',       'TRANSMISION', 'Geometría de sprockets y cadenas estándar'),
    ('DIN',  'DIN 2092',      'Resortes de disco (Belleville) — Cálculo',                   'RESORTES',    'Ecuaciones de Almen-Laszlo para carga, deflexión, tensiones y fatiga'),
    ('DIN',  'DIN 2093',      'Resortes de disco — Dimensiones y requisitos de calidad',    'RESORTES',    'Series dimensionales A, B, C y grupos de resortes de disco'),
    ('ASTM', 'ASTM A36',      'Standard Specification for Carbon Structural Steel',         'MATERIALES',  'Acero estructural al carbono (límite elástico mín. 250 MPa / 36 ksi)'),
    ('ASTM', 'ASTM A29',      'Standard Specification for General Requirements for Steel Bars','MATERIALES','Requisitos generales y tolerancias para barras de acero al carbono y aleado'),
    ('SAE',  'SAE J429',      'Mechanical and Material Requirements for Externally Threaded Fasteners','SUJECION','Grados mecánicos (Grado 2, 5, 8) para pernos y elementos roscados')
ON CONFLICT (organismo, codigo) DO NOTHING;

-- =============================================================================
-- 7. CATÁLOGOS DE INGENIERÍA INICIALES (DDD §7 y §9)
-- =============================================================================
INSERT INTO catalog.catalogo_ingenieria (codigo, nombre, tipo, descripcion, activo) VALUES
    ('KEYWAYS',         'Catálogo de Chavetas y Chaveteros',       'CHAVETAS',   'Perfiles estándar de chavetas en mm e inch', TRUE),
    ('THREADS',         'Catálogo Maestro de Roscas y Brocas',     'ROSCAS',     'Series métricas, Unified National, NPT/NPS y brocas para roscado', TRUE),
    ('CHAINS',          'Catálogo de Cadenas de Transmisión/Arrastre','CADENAS', 'Paso, diámetro de rodillo, ancho interior, altura de placa y carga de rotura', TRUE),
    ('SPROCKETS',       'Catálogo de Factores y Geometría Sprocket','SPROCKETS', 'Tablas de factores y perfiles para ruedas dentadas', TRUE),
    ('DISC_SPRINGS',    'Catálogo de Resortes de Disco DIN 2093',  'RESORTES',   'Dimensiones De, Di, t, l0, h0 y series de resortes Belleville', TRUE),
    ('HYDRAULIC_PRESS', 'Catálogo de Prensas Hidráulicas Planta',  'PRENSAS',    'Capacidad, área de cilindro y presión de trabajo de prensas Forjas Bolívar', TRUE),
    ('PINS',            'Catálogo de Pines y Pasadores Elásticos', 'PINES',      'Dimensiones y resistencias al corte según DIN 7346 / DIN 1481', TRUE)
ON CONFLICT (codigo) DO NOTHING;

-- =============================================================================
-- 8. INVENTARIO DE LAS 17 CALCULADORAS DEL ALCANCE ACTUAL (DDD §9)
-- =============================================================================
INSERT INTO calc.calculadora (codigo, nombre, dominio, descripcion, activo) VALUES
    ('KEYWAY_DIN6885',            'Calculadora de Chavetas y Chaveteros DIN 6885',         'ELEMENTOS_EJE',   'Entrada: diámetro de eje, serie/unidad. Salida: b, h, t1, t2, radio, ajustes y límites.', TRUE),
    ('FIT_ISO286',                'Calculadora de Ajustes y Tolerancias ISO 286',          'TOLERANCIAS',     'Entrada: dimensión nominal, letra y grado de eje/agujero. Salida: desviaciones, límites y tipo de ajuste.', TRUE),
    ('GENERAL_TOLERANCE_DIN7168', 'Calculadora de Tolerancias Generales DIN 7168',         'TOLERANCIAS',     'Entrada: dimensión y clase. Salida: tolerancia general aplicable.', TRUE),
    ('THREAD_METRIC',             'Calculadora de Roscas Métricas ISO',                    'ROSCAS',          'Entrada: diámetro, paso, clase, rosca interna/externa. Salida: diámetros mayor, medio, menor, tolerancias y profundidad.', TRUE),
    ('THREAD_UNIFIED',            'Calculadora de Roscas Unified National (UNC/UNF/UN)',   'ROSCAS',          'Entrada: diámetro, TPI, serie UNC/UNF/UN, clase y entradas. Salida: geometría y tolerancias.', TRUE),
    ('THREAD_NPT_NPS',            'Calculadora de Roscas de Tubería NPT / NPS',            'ROSCAS',          'Entrada: tamaño nominal, TPI, tipo y longitud. Salida: diámetros, conicidad, planos y engagement.', TRUE),
    ('TAP_DRILL',                 'Calculadora de Brocas para Roscado (Tap Drill)',        'ROSCAS',          'Entrada: designación o diámetro/paso. Salida: broca recomendada y porcentaje de rosca.', TRUE),
    ('PIN_DIN7346',               'Calculadora de Pines Elásticos Ligeros DIN 7346',       'PINES',           'Entrada: diámetro/longitud. Salida: dimensiones, tolerancias y carga cortante.', TRUE),
    ('PIN_DIN1481',               'Calculadora de Pines Elásticos Pesados DIN 1481',       'PINES',           'Entrada: diámetro/longitud. Salida: dimensiones y carga cortante.', TRUE),
    ('SPROCKET_GEOMETRY',         'Calculadora de Geometría de Sprockets ASME B29.12M',    'TRANSMISION',     'Entrada: cadena, paso, rodillo, ancho, altura y dientes. Salida: Dp, Do, Dr/Db, Rp, Rt, Wf, Wt, chaflán y ángulo.', TRUE),
    ('CHAIN_WORK_LOAD',           'Calculadora de Carga de Trabajo y Rotura de Cadenas',   'TRANSMISION',     'Entrada: geometría, material y factor de seguridad. Salida: área, carga de rotura y carga de trabajo.', TRUE),
    ('CHAIN_BEARING_PRESSURE',    'Calculadora de Presión de Apoyo en Cadenas',            'TRANSMISION',     'Entrada: velocidad, tensión, geometría y material. Salida: fuerza centrífuga y presión de apoyo.', TRUE),
    ('INTERFERENCE_FIT',          'Calculadora de Ajustes por Interferencia (Lame/Birnie)','AJUSTES_PRENSA',  'Entrada: diámetros, interferencia, longitudes y materiales. Salida: presión de contacto y deformación.', TRUE),
    ('ASSEMBLY_FORCE',            'Calculadora de Fuerza de Ensamble y Presión Hidráulica','AJUSTES_PRENSA',  'Entrada: presión/interferencia, fricción, diámetro y longitud. Salida: fuerza axial, toneladas y presión hidráulica.', TRUE),
    ('LINEAR_SPEED',              'Calculadora de Velocidad Lineal, Angular y RPM',        'CINEMATICA',      'Entrada: RPM, diámetro/radio o rad/s. Salida: velocidad lineal, angular y RPM equivalentes.', TRUE),
    ('DISC_SPRING_LOAD',          'Calculadora de Carga y Tensión en Resortes de Disco',   'RESORTES',        'Entrada: resorte, material, temperatura, deflexión, serie y paralelo. Salida: fuerza, altura y tensiones sOM/s1/s2/s3/s4.', TRUE),
    ('DISC_SPRING_FATIGUE',       'Calculadora de Fatiga y Vida en Resortes de Disco',     'RESORTES',        'Entrada: dos puntos de carga y apilamiento. Salida: tensiones superior/inferior, ciclos y vida.', TRUE)
ON CONFLICT (codigo) DO NOTHING;

-- =============================================================================
-- 9. TIPOS DE PROPIEDAD DE MATERIALES (DDD §7: MECÁNICA / FÍSICA)
-- =============================================================================
INSERT INTO materials.tipo_propiedad (codigo, nombre, grupo, unidad_base_id, tipo_dato)
SELECT v.codigo, v.nombre, v.grupo, u.id, 'NUMERIC'
FROM (VALUES
    ('YIELD_STRENGTH',       'Límite Elástico (Sy)',               'MECANICA', 'ESFUERZO_PRESION', 'MPA'),
    ('TENSILE_STRENGTH',     'Resistencia a la Tracción (Sut)',    'MECANICA', 'ESFUERZO_PRESION', 'MPA'),
    ('ELASTIC_MODULUS',      'Módulo de Elasticidad (Young E)',    'MECANICA', 'ESFUERZO_PRESION', 'GPA'),
    ('POISSON_RATIO',        'Coeficiente de Poisson (ν)',         'MECANICA', 'ANGULO',           'RAD'),
    ('HARDNESS_HB',          'Dureza Brinell (HB)',                'MECANICA', 'DUREZA',           'HB'),
    ('DENSITY',              'Densidad (ρ)',                       'FISICA',   'DENSIDAD',         'KG_M3'),
    ('OPERATING_TEMP_MIN',   'Temperatura Mínima de Operación',    'TERMICA',  'TEMPERATURA',      'C'),
    ('OPERATING_TEMP_MAX',   'Temperatura Máxima de Operación',    'TERMICA',  'TEMPERATURA',      'C')
) AS v(codigo, nombre, grupo, cat_codigo, unidad_codigo)
JOIN conversion.categoria_conversion c ON c.codigo = v.cat_codigo
JOIN conversion.unidad u ON u.categoria_id = c.id AND u.codigo = v.unidad_codigo
ON CONFLICT (codigo) DO NOTHING;

-- =============================================================================
-- 10. FLUJOS Y PASOS DE APROBACIÓN (DDD §5.3 y §11)
-- =============================================================================
INSERT INTO workflow.flujo_aprobacion (codigo, nombre, tipo_entidad, activo) VALUES
    ('WF_MATERIAL_APPROVAL',   'Flujo de Aprobación de Materiales de Ingeniería', 'MATERIAL_VERSION',    TRUE),
    ('WF_STANDARD_APPROVAL',   'Flujo de Aprobación de Normas y Documentos',      'NORMA_VERSION',       TRUE),
    ('WF_CATALOG_APPROVAL',    'Flujo de Aprobación de Catálogos Técnicos',       'CATALOGO_VERSION',    TRUE),
    ('WF_CALCULATOR_RELEASE',  'Flujo Dual de Aprobación y Publicación de Calculadora', 'CALCULADORA_VERSION', TRUE)
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO workflow.paso_aprobacion (flujo_id, orden, rol_id, unidad_tipo, obligatorio, requiere_segregacion)
SELECT f.id, p.orden, r.id, 'AREA', TRUE, TRUE
FROM (VALUES
    ('WF_MATERIAL_APPROVAL',  1, 'VALIDADOR_INGENIERIA'),
    ('WF_STANDARD_APPROVAL',  1, 'VALIDADOR_INGENIERIA'),
    ('WF_CATALOG_APPROVAL',   1, 'VALIDADOR_INGENIERIA'),
    ('WF_CALCULATOR_RELEASE', 1, 'ANALISTA_CALIDAD'),
    ('WF_CALCULATOR_RELEASE', 2, 'VALIDADOR_INGENIERIA'),
    ('WF_CALCULATOR_RELEASE', 3, 'LIDER_TECNICO')
) AS p(flujo_codigo, orden, rol_codigo)
JOIN workflow.flujo_aprobacion f ON f.codigo = p.flujo_codigo
JOIN auth.rol r ON r.codigo = p.rol_codigo
ON CONFLICT (flujo_id, orden) DO NOTHING;

