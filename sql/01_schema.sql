-- =====================================================================================
-- Mercado legal para extranjeros en Costa Rica: base de datos analítica
-- 01_schema.sql: esquemas, tablas de staging y modelo dimensional (core)
-- PostgreSQL 14+
-- =====================================================================================
DROP SCHEMA IF EXISTS analytics CASCADE;
DROP SCHEMA IF EXISTS core CASCADE;
DROP SCHEMA IF EXISTS staging CASCADE;
CREATE SCHEMA staging;   -- copia fiel de los CSV limpios (data/clean, data/reference)
CREATE SCHEMA core;      -- modelo estrella: dimensiones + hechos, con llaves y restricciones
CREATE SCHEMA analytics; -- vistas listas para Tableau y para las preguntas de negocio

-- -------------------------------------------------------------------------------------
-- STAGING: una tabla por archivo; las columnas siguen exactamente el orden del CSV
-- -------------------------------------------------------------------------------------
CREATE TABLE staging.dim_pais (
    pais_iso3 text, iso2 text, nombre_es text, nombre_en text,
    zona_ict text, continente_dgme text, es_agrupacion boolean);

CREATE TABLE staging.pais_alias (nombre_en_fuente text, pais_iso3 text, fuentes text);

CREATE TABLE staging.ict_llegadas_anuales (
    anio int, via text, nivel text, zona text, pais_o_zona text, llegadas int, pais_iso3 text);

CREATE TABLE staging.ict_llegadas_historicas_totales (anio int, via text, llegadas int);

CREATE TABLE staging.ict_llegadas_mensuales (
    anio int, mes int, puerto text, nivel text, zona text, pais_o_zona text, llegadas int, pais_iso3 text);

CREATE TABLE staging.ict_encuesta_no_residentes_lir (
    aeropuerto text, anio int, region_residencia text, tema text, categoria text, nivel text,
    valor numeric, unidad text, respuesta_multiple boolean, pais_iso3 text);

CREATE TABLE staging.ict_perfil_turista_vacaciones_sjo (
    mercado text, tema text, categoria text, periodo text, valor numeric, unidad text, nota text, pais_iso3 text);

CREATE TABLE staging.dgme_tramites_permanencia (
    anio int, tipo text, pais_origen text, categoria_migratoria text, desagregacion text,
    grupo text, cantidad int, fuente text, nota text, pais_iso3 text);

CREATE TABLE staging.dgme_residentes_acumulados (
    anio_corte int, continente text, pais_origen text, categoria_migratoria text, residentes int, pais_iso3 text);

CREATE TABLE staging.dgme_movimiento_migratorio (
    anio int, pais_nacionalidad text, puesto_migratorio text, tipo_movimiento text, personas int, pais_iso3 text);

-- -------------------------------------------------------------------------------------
-- CORE: dimensiones
-- -------------------------------------------------------------------------------------
CREATE TABLE core.dim_pais (
    pais_iso3        varchar(6)  PRIMARY KEY,        -- ISO 3166-1 alfa-3 (+ códigos propios: XXA, UNK, OT-*)
    iso2             char(2),
    nombre_es        text        NOT NULL,
    nombre_en        text        NOT NULL,          -- nombre que Tableau reconoce para mapas
    zona_ict         text,                          -- zona turística según el ICT
    continente_dgme  text,                          -- continente según la DGME
    es_agrupacion    boolean     NOT NULL DEFAULT false  -- "Otros Europa", "Apátrida", etc.
);

CREATE TABLE core.dim_categoria_migratoria (
    categoria_id   smallint PRIMARY KEY,
    categoria      text NOT NULL UNIQUE,
    descripcion    text NOT NULL
);

-- -------------------------------------------------------------------------------------
-- CORE: hechos del ICT (turismo)
-- -------------------------------------------------------------------------------------
CREATE TABLE core.fact_llegadas_anual (
    anio        smallint   NOT NULL,
    via         text       NOT NULL CHECK (via IN ('Todas las vías', 'Vía aérea')),
    pais_iso3   varchar(6) NOT NULL REFERENCES core.dim_pais,
    llegadas    integer    NOT NULL CHECK (llegadas >= 0),
    PRIMARY KEY (anio, via, pais_iso3)
);

CREATE TABLE core.fact_llegadas_mensual (
    anio        smallint   NOT NULL,
    mes         smallint   NOT NULL CHECK (mes BETWEEN 1 AND 12),
    puerto      text       NOT NULL,
    pais_iso3   varchar(6) NOT NULL REFERENCES core.dim_pais,
    llegadas    integer    NOT NULL CHECK (llegadas >= 0),
    PRIMARY KEY (anio, mes, puerto, pais_iso3)
);

CREATE TABLE core.fact_llegadas_historicas (
    anio      smallint NOT NULL,
    via       text     NOT NULL,
    llegadas  integer  NOT NULL,
    PRIMARY KEY (anio, via)
);

CREATE TABLE core.fact_perfil_turista_sjo (
    pais_iso3  varchar(6) NOT NULL REFERENCES core.dim_pais,
    tema       text       NOT NULL,
    categoria  text       NOT NULL,
    periodo    text       NOT NULL,
    valor      numeric(8,2) NOT NULL,
    unidad     text       NOT NULL,
    nota       text,
    PRIMARY KEY (pais_iso3, tema, categoria, periodo)
);

CREATE TABLE core.fact_encuesta_lir (
    anio                smallint NOT NULL,
    region_residencia   text     NOT NULL,          -- Total, Estados Unidos, Canadá, Europa
    pais_iso3           varchar(6) REFERENCES core.dim_pais,  -- solo para EE. UU. y Canadá
    tema                text     NOT NULL,
    categoria           text     NOT NULL,
    nivel               text     NOT NULL CHECK (nivel IN ('detalle', 'subtotal')),
    valor               numeric(8,2) NOT NULL,
    unidad              text     NOT NULL,
    respuesta_multiple  boolean  NOT NULL,
    PRIMARY KEY (anio, region_residencia, tema, categoria)
);

-- -------------------------------------------------------------------------------------
-- CORE: hechos de la DGME (migración)
-- -------------------------------------------------------------------------------------
CREATE TABLE core.fact_tramite_permanencia (
    anio           smallint   NOT NULL,
    tipo           text       NOT NULL CHECK (tipo IN ('solicitud', 'aprobada', 'denegada')),
    pais_iso3      varchar(6) NOT NULL REFERENCES core.dim_pais,
    categoria_id   smallint   NOT NULL REFERENCES core.dim_categoria_migratoria,
    desagregacion  text       NOT NULL CHECK (desagregacion IN ('sexo', 'edad')),
    grupo          text       NOT NULL,
    cantidad       integer    NOT NULL CHECK (cantidad >= 0),
    nota           text,
    PRIMARY KEY (anio, tipo, pais_iso3, categoria_id, desagregacion, grupo)
);

CREATE TABLE core.fact_residentes_acumulados (
    anio_corte    smallint   NOT NULL,
    pais_iso3     varchar(6) NOT NULL REFERENCES core.dim_pais,
    categoria_id  smallint   NOT NULL REFERENCES core.dim_categoria_migratoria,
    residentes    integer    NOT NULL CHECK (residentes >= 0),
    PRIMARY KEY (anio_corte, pais_iso3, categoria_id)
);

CREATE TABLE core.fact_movimiento_migratorio (
    anio             smallint   NOT NULL,
    pais_iso3        varchar(6) NOT NULL REFERENCES core.dim_pais,
    puesto           text       NOT NULL,
    tipo_movimiento  text       NOT NULL CHECK (tipo_movimiento IN ('Ingreso', 'Egreso')),
    personas         integer    NOT NULL CHECK (personas >= 0),
    PRIMARY KEY (anio, pais_iso3, puesto, tipo_movimiento)
);

CREATE INDEX ON core.fact_tramite_permanencia (pais_iso3, anio);
CREATE INDEX ON core.fact_llegadas_mensual (pais_iso3, puerto);
CREATE INDEX ON core.fact_movimiento_migratorio (puesto, anio);
