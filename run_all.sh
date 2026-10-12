#!/usr/bin/env bash
# Reconstruye todo desde las fuentes originales: extracción -> validación -> PostgreSQL.
# Uso:  ./run_all.sh [nombre_bd]      (por defecto: mercado_legal)
set -euo pipefail
cd "$(dirname "$0")"
DB="${1:-mercado_legal}"
python3 scripts/extract_ict.py
python3 scripts/extract_dgme.py
python3 scripts/build_paises.py
createdb "$DB" 2>/dev/null || true
for f in sql/01_schema.sql sql/02_load.sql sql/03_transform.sql sql/04_quality_checks.sql sql/05_views.sql; do
  echo "== $f"; psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$f"
done
echo "Listo. Consultas de negocio: psql -d $DB -f sql/06_analysis.sql"
