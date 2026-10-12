-- =====================================================================================
-- 03_transform.sql: de staging al modelo dimensional (core).
-- Solo pasan filas de país; las filas de TOTAL y de zona se usan en 04_quality_checks.sql
-- para comprobar que nada se perdió. Cuando una fuente escribe el mismo país de dos formas
-- (p. ej. "Sudafrica" y "Africa Del Sur"), se suman bajo un solo código ISO.
-- =====================================================================================
BEGIN;

INSERT INTO core.dim_pais
SELECT pais_iso3, NULLIF(iso2, ''), nombre_es, nombre_en, NULLIF(zona_ict, ''), NULLIF(continente_dgme, ''), es_agrupacion
FROM staging.dim_pais;

INSERT INTO core.dim_categoria_migratoria VALUES
 (1, 'Categoría especial',   'Trabajadores temporales y de ocupación específica, estudiantes, asilados, refugiados, apátridas, artistas, deportistas, entre otros (nota 1/ DGME)'),
 (2, 'Residente temporal',   'Pensionados, rentistas, inversionistas, religiosos, ejecutivos, técnicos, científicos, profesionales, reunificación familiar, entre otros (nota 2/ DGME)'),
 (3, 'Residente permanente', 'Residencia permanente, incluida la otorgada por vínculo con costarricense');

-- ICT --------------------------------------------------------------------------------
INSERT INTO core.fact_llegadas_anual (anio, via, pais_iso3, llegadas)
SELECT anio, via, pais_iso3, SUM(llegadas)
FROM staging.ict_llegadas_anuales
WHERE nivel = 'pais'
GROUP BY anio, via, pais_iso3;

INSERT INTO core.fact_llegadas_mensual (anio, mes, puerto, pais_iso3, llegadas)
SELECT anio, mes, puerto, pais_iso3, SUM(llegadas)
FROM staging.ict_llegadas_mensuales
WHERE nivel = 'pais'
GROUP BY anio, mes, puerto, pais_iso3;

INSERT INTO core.fact_llegadas_historicas
SELECT anio, via, llegadas FROM staging.ict_llegadas_historicas_totales;

INSERT INTO core.fact_perfil_turista_sjo
SELECT pais_iso3, tema, categoria, periodo, valor, unidad, NULLIF(nota, '')
FROM staging.ict_perfil_turista_vacaciones_sjo;

INSERT INTO core.fact_encuesta_lir
SELECT anio, region_residencia, NULLIF(pais_iso3, ''), tema, categoria, nivel, valor, unidad, respuesta_multiple
FROM staging.ict_encuesta_no_residentes_lir;

-- DGME -------------------------------------------------------------------------------
INSERT INTO core.fact_tramite_permanencia (anio, tipo, pais_iso3, categoria_id, desagregacion, grupo, cantidad, nota)
SELECT t.anio, t.tipo, t.pais_iso3, c.categoria_id, t.desagregacion, t.grupo,
       SUM(t.cantidad),
       NULLIF(string_agg(DISTINCT NULLIF(t.nota, ''), '; '), '')
FROM staging.dgme_tramites_permanencia t
JOIN core.dim_categoria_migratoria c ON c.categoria = t.categoria_migratoria
GROUP BY t.anio, t.tipo, t.pais_iso3, c.categoria_id, t.desagregacion, t.grupo;

INSERT INTO core.fact_residentes_acumulados
SELECT r.anio_corte, r.pais_iso3, c.categoria_id, SUM(r.residentes)
FROM staging.dgme_residentes_acumulados r
JOIN core.dim_categoria_migratoria c ON c.categoria = r.categoria_migratoria
GROUP BY r.anio_corte, r.pais_iso3, c.categoria_id;

INSERT INTO core.fact_movimiento_migratorio
SELECT anio, pais_iso3, puesto_migratorio, tipo_movimiento, SUM(personas)
FROM staging.dgme_movimiento_migratorio
GROUP BY anio, pais_iso3, puesto_migratorio, tipo_movimiento;

COMMIT;
