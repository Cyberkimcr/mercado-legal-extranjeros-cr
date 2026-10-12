-- =====================================================================================
-- 06_analysis.sql: preguntas de negocio para un despacho que atiende a extranjeros
-- (residencias, sociedades, propiedad) con foco en Guanacaste.
-- psql -d mercado_legal -f sql/06_analysis.sql
-- =====================================================================================

-- P1. ¿De qué países viene la demanda de residencia temporal (pensionados, rentistas,
--     inversionistas...)? Ranking 2025 con participación y acumulado (funciones de ventana).
SELECT RANK() OVER (ORDER BY solicitudes DESC)                                AS puesto,
       pais,
       solicitudes,
       ROUND(100.0 * solicitudes / SUM(solicitudes) OVER (), 1)               AS pct_del_total,
       ROUND(100.0 * SUM(solicitudes) OVER (ORDER BY solicitudes DESC
             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
             / SUM(solicitudes) OVER (), 1)                                   AS pct_acumulado
FROM (SELECT pais, SUM(cantidad) AS solicitudes
      FROM analytics.v_tramites
      WHERE anio = 2025 AND tipo = 'solicitud' AND categoria = 'Residente temporal' AND desagregacion = 'sexo'
      GROUP BY pais) t
ORDER BY puesto
LIMIT 10;

-- P2. ¿Hay rezago en la DGME? Solicitudes vs aprobaciones de residencia temporal por año,
--     con variación interanual (LAG). Nota: no hay informe 2023.
WITH anual AS (
    SELECT anio,
           SUM(cantidad) FILTER (WHERE tipo = 'solicitud') AS solicitudes,
           SUM(cantidad) FILTER (WHERE tipo = 'aprobada')  AS aprobaciones
    FROM core.fact_tramite_permanencia
    WHERE categoria_id = 2 AND desagregacion = 'sexo'
    GROUP BY anio)
SELECT anio, solicitudes, aprobaciones,
       aprobaciones - solicitudes                                                      AS brecha,
       ROUND(100.0 * (solicitudes  / LAG(solicitudes)  OVER w::numeric - 1), 1)        AS var_pct_solicitudes,
       ROUND(100.0 * (aprobaciones / LAG(aprobaciones) OVER w::numeric - 1), 1)        AS var_pct_aprobaciones
FROM anual
WINDOW w AS (ORDER BY anio)
ORDER BY anio;

-- P3. Embudo 2024 para los mercados objetivo: turistas -> entradas por Liberia ->
--     solicitudes de residencia temporal -> residentes temporales vigentes.
SELECT pais, turistas, ingresos_liberia,
       ROUND(100.0 * ingresos_liberia / NULLIF(turistas, 0), 1) AS liberia_vs_turistas_pct,
       solicitudes_temporal,
       solicitudes_temporal_por_10k_turistas,
       residentes_temporales, residentes_permanentes
FROM analytics.v_embudo_pais_anio
WHERE anio = 2024 AND pais_iso3 IN ('USA', 'CAN', 'DEU', 'FRA', 'GBR', 'CHE', 'NLD')
ORDER BY turistas DESC;
-- Ojo: ingresos_liberia (DGME) cuenta TODAS las entradas de esa nacionalidad, incluidas las de
-- residentes y las repetidas en el año; turistas (ICT) solo cuenta turistas. No son el mismo universo.

-- P4. ¿Qué mercados crecen más por Liberia? Enero-agosto 2026 vs enero-agosto 2025.
WITH lir AS (
    SELECT pais, anio, SUM(llegadas) AS llegadas
    FROM analytics.v_llegadas_mensuales
    WHERE puerto = 'Aeropuerto Daniel Oduber (LIR)' AND mes <= 8 AND NOT es_agrupacion
    GROUP BY pais, anio)
SELECT pais,
       SUM(llegadas) FILTER (WHERE anio = 2025) AS ene_ago_2025,
       SUM(llegadas) FILTER (WHERE anio = 2026) AS ene_ago_2026,
       ROUND(100.0 * (SUM(llegadas) FILTER (WHERE anio = 2026)::numeric
                     / NULLIF(SUM(llegadas) FILTER (WHERE anio = 2025), 0) - 1), 1) AS var_pct
FROM lir
GROUP BY pais
HAVING SUM(llegadas) FILTER (WHERE anio = 2025) >= 1000
ORDER BY ene_ago_2026 DESC;

-- P5. ¿Cuándo hacer marketing? Mes pico de llegadas por Liberia para EE. UU. y Canadá (2025).
SELECT pais, mes, llegadas,
       ROUND(100.0 * llegadas / SUM(llegadas) OVER (PARTITION BY pais), 1) AS pct_del_anio,
       RANK() OVER (PARTITION BY pais ORDER BY llegadas DESC)               AS rango
FROM analytics.v_llegadas_mensuales
WHERE puerto = 'Aeropuerto Daniel Oduber (LIR)' AND anio = 2025 AND pais_iso3 IN ('USA', 'CAN')
ORDER BY pais, mes;

-- P6. Mercado de residentes vigentes (renovaciones, sociedades, impuestos):
--     crecimiento 2021 -> 2024 por país, top 10 por residentes temporales.
WITH r AS (
    SELECT p.nombre_es AS pais, f.anio_corte, f.categoria_id, f.residentes
    FROM core.fact_residentes_acumulados f JOIN core.dim_pais p USING (pais_iso3)
    WHERE NOT p.es_agrupacion)
SELECT pais,
       SUM(residentes) FILTER (WHERE anio_corte = 2021 AND categoria_id = 2) AS temporales_2021,
       SUM(residentes) FILTER (WHERE anio_corte = 2024 AND categoria_id = 2) AS temporales_2024,
       ROUND(100.0 * (SUM(residentes) FILTER (WHERE anio_corte = 2024 AND categoria_id = 2)::numeric
             / NULLIF(SUM(residentes) FILTER (WHERE anio_corte = 2021 AND categoria_id = 2), 0) - 1), 1) AS crec_pct_temporales,
       SUM(residentes) FILTER (WHERE anio_corte = 2024 AND categoria_id = 3) AS permanentes_2024
FROM r
GROUP BY pais
ORDER BY temporales_2024 DESC NULLS LAST
LIMIT 10;

-- P7. ¿Cuántas solicitudes se deniegan? Tasa de denegación 2021 por categoría
--     (único año en que la DGME publica denegatorias de permanencia).
SELECT c.categoria,
       SUM(cantidad) FILTER (WHERE tipo = 'aprobada') AS aprobadas,
       SUM(cantidad) FILTER (WHERE tipo = 'denegada') AS denegadas,
       ROUND(100.0 * SUM(cantidad) FILTER (WHERE tipo = 'denegada')
             / NULLIF(SUM(cantidad) FILTER (WHERE tipo IN ('aprobada', 'denegada')), 0), 1) AS pct_denegadas
FROM core.fact_tramite_permanencia t
JOIN core.dim_categoria_migratoria c USING (categoria_id)
WHERE anio = 2021 AND desagregacion = 'sexo'
GROUP BY c.categoria_id, c.categoria
ORDER BY c.categoria_id;

-- P8. ¿Familias o personas solas? Peso de menores de edad en las aprobaciones de residencia
--     temporal 2025 (los menores suelen ser dependientes de un titular).
SELECT pais,
       SUM(cantidad)                                                    AS aprobadas_temporal,
       ROUND(100.0 * SUM(cantidad) FILTER (WHERE grupo = 'Menor de edad') / SUM(cantidad), 1) AS pct_menores
FROM analytics.v_tramites
WHERE anio = 2025 AND tipo = 'aprobada' AND categoria = 'Residente temporal' AND desagregacion = 'edad'
GROUP BY pais
HAVING SUM(cantidad) >= 50
ORDER BY aprobadas_temporal DESC;

-- P9. El perfil del turista de Liberia: ¿quiénes ya tienen casa en Costa Rica? (encuesta ICT 2025)
SELECT region_residencia, categoria, valor AS pct
FROM core.fact_encuesta_lir
WHERE tema = 'hospedaje' AND categoria ILIKE 'Casa/condominio%'
ORDER BY categoria, region_residencia;

-- P10. Ficha de mercados 2025: ¿qué mercado combina repetición, estadía larga y demanda de residencia?
SELECT mercado, pct_revisita, estadia_noches, gasto_diario_usd, pct_55_o_mas,
       solicitudes_temporal, solicitudes_temporal_por_10k_turistas,
       RANK() OVER (ORDER BY solicitudes_temporal DESC NULLS LAST) AS rango_demanda
FROM analytics.v_ficha_mercado_2025
ORDER BY rango_demanda;
