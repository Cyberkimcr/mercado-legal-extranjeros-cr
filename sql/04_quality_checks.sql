-- =====================================================================================
-- 04_quality_checks.sql: controles de calidad después de la carga.
-- Cada control devuelve una fila con su resultado: OK, o el número de casos a revisar.
-- Los controles 1-6 deben dar OK. El control 7 documenta inconsistencias PROPIAS DE LA
-- FUENTE (la DGME publica cifras por sexo y por edad que no siempre suman lo mismo).
-- =====================================================================================

WITH
-- 1. ICT anual: los países (más "Otras zonas") suman el TOTAL publicado
c1 AS (
    SELECT count(*) AS n FROM (
        SELECT s.anio, s.via
        FROM staging.ict_llegadas_anuales s
        WHERE s.nivel = 'total'
        GROUP BY s.anio, s.via, s.llegadas
        HAVING s.llegadas <> (SELECT SUM(f.llegadas) FROM core.fact_llegadas_anual f
                              WHERE f.anio = s.anio AND f.via = s.via)
    ) x),
-- 2. ICT mensual: los países suman el TOTAL de cada mes y puerto
c2 AS (
    SELECT count(*) AS n FROM staging.ict_llegadas_mensuales s
    WHERE s.nivel = 'total'
      AND s.llegadas <> (SELECT SUM(f.llegadas) FROM core.fact_llegadas_mensual f
                         WHERE f.anio = s.anio AND f.mes = s.mes AND f.puerto = s.puerto)),
-- 3. Dos fuentes del ICT coinciden: el Excel anual 2025 vs la suma de los 12 meses del PDF
c3 AS (
    SELECT count(*) AS n
    FROM core.fact_llegadas_anual a
    JOIN (SELECT pais_iso3,
                 CASE puerto WHEN 'Todas las vías' THEN 'Todas las vías' ELSE 'Vía aérea' END AS via,
                 SUM(llegadas) AS llegadas
          FROM core.fact_llegadas_mensual
          WHERE anio = 2025 AND puerto IN ('Todas las vías', 'Vía aérea')
          GROUP BY 1, 2) m USING (pais_iso3, via)
    WHERE a.anio = 2025 AND a.llegadas <> m.llegadas),
-- 4. DGME trámites: no se perdió ni duplicó nada entre staging y core
c4 AS (
    SELECT count(*) AS n FROM (
        SELECT anio, tipo, desagregacion, SUM(cantidad) AS s FROM staging.dgme_tramites_permanencia GROUP BY 1, 2, 3
        EXCEPT
        SELECT anio, tipo, desagregacion, SUM(cantidad) FROM core.fact_tramite_permanencia GROUP BY 1, 2, 3
    ) x),
-- 5. DGME residentes acumulados = totales oficiales publicados
c5 AS (
    SELECT count(*) AS n FROM (VALUES (2021, 584285), (2022, 607772), (2024, 649637)) AS oficial(anio, total)
    WHERE total <> (SELECT SUM(residentes) FROM core.fact_residentes_acumulados WHERE anio_corte = oficial.anio)),
-- 6. DGME movimiento migratorio: ingresos = totales oficiales publicados
c6 AS (
    SELECT count(*) AS n FROM (VALUES (2021, 2254862), (2022, 3775345), (2024, 5066045)) AS oficial(anio, total)
    WHERE total <> (SELECT SUM(personas) FROM core.fact_movimiento_migratorio
                    WHERE anio = oficial.anio AND tipo_movimiento = 'Ingreso')),
-- 7. Fuente DGME: el total por sexo y el total por edad deberían ser iguales
c7 AS (
    SELECT count(*) AS n FROM (
        SELECT anio, tipo, pais_iso3, categoria_id
        FROM core.fact_tramite_permanencia
        GROUP BY 1, 2, 3, 4
        HAVING SUM(cantidad) FILTER (WHERE desagregacion = 'sexo')
            <> SUM(cantidad) FILTER (WHERE desagregacion = 'edad')
    ) x)
SELECT control, CASE WHEN n = 0 THEN 'OK' ELSE n || ' caso(s) a revisar' END AS resultado
FROM (
          SELECT 1 AS orden, 'ICT anual: países suman el total publicado' AS control, n FROM c1
UNION ALL SELECT 2, 'ICT mensual: países suman el total de cada mes y puerto', n FROM c2
UNION ALL SELECT 3, 'ICT: Excel anual 2025 = suma de los meses del PDF', n FROM c3
UNION ALL SELECT 4, 'DGME trámites: staging = core (sin pérdidas)', n FROM c4
UNION ALL SELECT 5, 'DGME residentes acumulados = total oficial', n FROM c5
UNION ALL SELECT 6, 'DGME movimiento migratorio = total oficial', n FROM c6
UNION ALL SELECT 7, 'Fuente DGME: total por sexo = total por edad', n FROM c7
) r
ORDER BY orden;

-- Detalle del control 7 (inconsistencias de la fuente, documentadas en el README)
SELECT anio, tipo, pais_iso3, c.categoria,
       SUM(cantidad) FILTER (WHERE desagregacion = 'sexo') AS total_por_sexo,
       SUM(cantidad) FILTER (WHERE desagregacion = 'edad') AS total_por_edad
FROM core.fact_tramite_permanencia t
JOIN core.dim_categoria_migratoria c USING (categoria_id)
GROUP BY anio, tipo, pais_iso3, c.categoria
HAVING SUM(cantidad) FILTER (WHERE desagregacion = 'sexo') <> SUM(cantidad) FILTER (WHERE desagregacion = 'edad')
ORDER BY anio, pais_iso3;
