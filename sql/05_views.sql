-- =====================================================================================
-- 05_views.sql: vistas analíticas (fuente de datos para Tableau)
-- =====================================================================================

-- Embudo por país y año: turista -> entra por Liberia -> solicita residencia -> es residente
CREATE OR REPLACE VIEW analytics.v_embudo_pais_anio AS
WITH anios AS (SELECT unnest(ARRAY[2021, 2022, 2024, 2025])::smallint AS anio),
turistas AS (
    SELECT anio, pais_iso3, llegadas AS turistas
    FROM core.fact_llegadas_anual WHERE via = 'Todas las vías'),
ingresos_lir AS (
    SELECT anio, pais_iso3, personas AS ingresos_liberia
    FROM core.fact_movimiento_migratorio
    WHERE puesto = 'Daniel Oduber' AND tipo_movimiento = 'Ingreso'),
tramites AS (
    SELECT anio, pais_iso3,
           SUM(cantidad) FILTER (WHERE tipo = 'solicitud' AND categoria_id = 2) AS solicitudes_temporal,
           SUM(cantidad) FILTER (WHERE tipo = 'aprobada'  AND categoria_id = 2) AS aprobaciones_temporal,
           SUM(cantidad) FILTER (WHERE tipo = 'solicitud' AND categoria_id = 3) AS solicitudes_permanente,
           SUM(cantidad) FILTER (WHERE tipo = 'aprobada'  AND categoria_id = 3) AS aprobaciones_permanente
    FROM core.fact_tramite_permanencia
    WHERE desagregacion = 'sexo'          -- se usa una sola desagregación para no contar doble
    GROUP BY anio, pais_iso3),
residentes AS (
    SELECT anio_corte AS anio, pais_iso3,
           SUM(residentes) FILTER (WHERE categoria_id = 2) AS residentes_temporales,
           SUM(residentes) FILTER (WHERE categoria_id = 3) AS residentes_permanentes
    FROM core.fact_residentes_acumulados
    GROUP BY anio_corte, pais_iso3)
SELECT a.anio, p.pais_iso3, p.nombre_es AS pais, p.nombre_en AS pais_en, p.zona_ict, p.continente_dgme,
       t.turistas, l.ingresos_liberia,
       tr.solicitudes_temporal, tr.aprobaciones_temporal, tr.solicitudes_permanente, tr.aprobaciones_permanente,
       r.residentes_temporales, r.residentes_permanentes,
       ROUND(10000.0 * tr.solicitudes_temporal / NULLIF(t.turistas, 0), 1) AS solicitudes_temporal_por_10k_turistas
FROM anios a
CROSS JOIN core.dim_pais p
LEFT JOIN turistas     t  ON t.anio  = a.anio AND t.pais_iso3  = p.pais_iso3
LEFT JOIN ingresos_lir l  ON l.anio  = a.anio AND l.pais_iso3  = p.pais_iso3
LEFT JOIN tramites     tr ON tr.anio = a.anio AND tr.pais_iso3 = p.pais_iso3
LEFT JOIN residentes   r  ON r.anio  = a.anio AND r.pais_iso3  = p.pais_iso3
WHERE COALESCE(t.turistas, l.ingresos_liberia, tr.solicitudes_temporal, tr.aprobaciones_temporal,
               tr.solicitudes_permanente, r.residentes_temporales, r.residentes_permanentes) IS NOT NULL;

-- Llegadas mensuales con fecha, para series de tiempo y estacionalidad
CREATE OR REPLACE VIEW analytics.v_llegadas_mensuales AS
SELECT make_date(m.anio, m.mes, 1) AS fecha, m.anio, m.mes, m.puerto,
       p.pais_iso3, p.nombre_es AS pais, p.nombre_en AS pais_en, p.zona_ict, p.es_agrupacion, m.llegadas
FROM core.fact_llegadas_mensual m
JOIN core.dim_pais p USING (pais_iso3);

-- Peso de Liberia dentro de las llegadas aéreas, por país y año (2026 = ene-ago)
CREATE OR REPLACE VIEW analytics.v_participacion_liberia AS
SELECT m.anio, p.pais_iso3, p.nombre_es AS pais,
       SUM(llegadas) FILTER (WHERE puerto = 'Aeropuerto Daniel Oduber (LIR)')   AS llegadas_lir,
       SUM(llegadas) FILTER (WHERE puerto = 'Aeropuerto Juan Santamaría (SJO)') AS llegadas_sjo,
       SUM(llegadas) FILTER (WHERE puerto = 'Vía aérea')                         AS llegadas_aereas,
       ROUND(100.0 * SUM(llegadas) FILTER (WHERE puerto = 'Aeropuerto Daniel Oduber (LIR)')
             / NULLIF(SUM(llegadas) FILTER (WHERE puerto = 'Vía aérea'), 0), 1)  AS pct_liberia,
       MAX(mes) AS ultimo_mes
FROM core.fact_llegadas_mensual m
JOIN core.dim_pais p USING (pais_iso3)
GROUP BY m.anio, p.pais_iso3, p.nombre_es;

-- Trámites con nombres legibles (para filtros en Tableau)
CREATE OR REPLACE VIEW analytics.v_tramites AS
SELECT t.anio, t.tipo, p.pais_iso3, p.nombre_es AS pais, p.nombre_en AS pais_en, p.continente_dgme,
       c.categoria, t.desagregacion, t.grupo, t.cantidad, t.nota
FROM core.fact_tramite_permanencia t
JOIN core.dim_pais p USING (pais_iso3)
JOIN core.dim_categoria_migratoria c USING (categoria_id);

-- Ficha por mercado emisor 2025: perfil del turista (ICT) + demanda de residencia (DGME)
CREATE OR REPLACE VIEW analytics.v_ficha_mercado_2025 AS
WITH perfil AS (
    SELECT pais_iso3,
           MAX(valor) FILTER (WHERE tema = 'revisita')         AS pct_revisita,
           MAX(valor) FILTER (WHERE tema = 'estadia_promedio') AS estadia_noches,
           MAX(valor) FILTER (WHERE tema = 'gasto_diario')     AS gasto_diario_usd,
           MAX(valor) FILTER (WHERE tema = 'edad_promedio')    AS edad_promedio,
           SUM(valor) FILTER (WHERE tema = 'grupo_edad' AND categoria IN ('De 55 a 64', 'De 65 y más')) AS pct_55_o_mas
    FROM core.fact_perfil_turista_sjo
    WHERE periodo = '2025'
    GROUP BY pais_iso3)
SELECT p.nombre_es AS mercado, pf.*, e.turistas, e.solicitudes_temporal, e.residentes_temporales,
       e.solicitudes_temporal_por_10k_turistas
FROM perfil pf
JOIN core.dim_pais p USING (pais_iso3)
LEFT JOIN analytics.v_embudo_pais_anio e ON e.pais_iso3 = pf.pais_iso3 AND e.anio = 2025;
