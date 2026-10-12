-- =====================================================================================
-- 02_load.sql: carga los CSV limpios a staging.
-- Ejecutar con psql DESDE LA RAÍZ DEL REPOSITORIO (\copy usa rutas relativas al cliente):
--   psql -d mercado_legal -f sql/02_load.sql
-- ENCODING UTF8 es necesario en Windows, donde psql suele usar WIN1252 por defecto.
-- =====================================================================================
\copy staging.dim_pais                          FROM 'data/reference/dim_pais.csv'                     WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy staging.pais_alias                        FROM 'data/reference/pais_alias.csv'                   WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy staging.ict_llegadas_anuales              FROM 'data/clean/ict_llegadas_anuales.csv'             WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy staging.ict_llegadas_historicas_totales   FROM 'data/clean/ict_llegadas_historicas_totales.csv'  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy staging.ict_llegadas_mensuales            FROM 'data/clean/ict_llegadas_mensuales.csv'           WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy staging.ict_encuesta_no_residentes_lir    FROM 'data/clean/ict_encuesta_no_residentes_lir.csv'   WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy staging.ict_perfil_turista_vacaciones_sjo FROM 'data/clean/ict_perfil_turista_vacaciones_sjo.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy staging.dgme_tramites_permanencia         FROM 'data/clean/dgme_tramites_permanencia.csv'        WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy staging.dgme_residentes_acumulados        FROM 'data/clean/dgme_residentes_acumulados.csv'       WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy staging.dgme_movimiento_migratorio        FROM 'data/clean/dgme_movimiento_migratorio.csv'       WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
