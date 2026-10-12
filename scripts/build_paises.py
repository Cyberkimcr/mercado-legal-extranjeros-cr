"""Une los nombres de país de todas las fuentes en un solo código ISO 3166-1 alfa-3.

Agrega la columna `pais_iso3` a cada CSV limpio y genera:
  - data/reference/dim_pais.csv ... un registro por país (nombre en español e inglés, zona ICT, continente DGME)
  - data/reference/pais_alias.csv . cada forma escrita en las fuentes y el código al que se asignó
Se detiene si algún nombre queda sin código.
"""
import csv, collections, sys
from pathlib import Path
from babel import Locale
import pycountry
sys.path.insert(0, str(Path(__file__).parent))
from paises import iso

ROOT = Path(__file__).resolve().parents[1]
CLEAN, REF = ROOT / 'data/clean', ROOT / 'data/reference'
REF.mkdir(exist_ok=True)
# archivo -> (columna con el país, condición para que la fila sea un país)
FUENTES = {
    'ict_llegadas_anuales.csv': ('pais_o_zona', lambda r: r['nivel'] == 'pais'),
    'ict_llegadas_mensuales.csv': ('pais_o_zona', lambda r: r['nivel'] == 'pais'),
    'ict_perfil_turista_vacaciones_sjo.csv': ('mercado', lambda r: True),
    'ict_encuesta_no_residentes_lir.csv': ('region_residencia', lambda r: r['region_residencia'] in ('Estados Unidos', 'Canadá')),
    'dgme_tramites_permanencia.csv': ('pais_origen', lambda r: True),
    'dgme_residentes_acumulados.csv': ('pais_origen', lambda r: True),
    'dgme_movimiento_migratorio.csv': ('pais_nacionalidad', lambda r: True),
}
ESPECIALES = {'XXA': ('Apátrida', 'Stateless'), 'UNK': ('No indica', 'Not stated'), 'YUG': ('Yugoslavia (histórico)', 'Yugoslavia (historical)'),
              'ANT': ('Antillas Neerlandesas (histórico)', 'Netherlands Antilles (historical)'), 'XKX': ('Kosovo', 'Kosovo'),
              'OT-ASP': ('Otros Asia y el Pacífico (ICT)', 'Other Asia & Pacific (ICT)'), 'OT-CAR': ('Otros Caribe (ICT)', 'Other Caribbean (ICT)'),
              'OT-EUR': ('Otros Europa (ICT)', 'Other Europe (ICT)'), 'OT-OME': ('Otros Oriente Medio (ICT)', 'Other Middle East (ICT)'),
              'OT-AFR': ('Otros África (ICT)', 'Other Africa (ICT)'),
              'OT-ZON': ('Otras zonas: Asia, África y Oriente Medio (ICT anual)', 'Other regions: Asia, Africa & Middle East (ICT annual)')}
es_names, en_names = Locale('es').territories, Locale('en').territories

alias = collections.defaultdict(set)
zona_ict, cont_dgme = {}, {}
missing = set()
for fname, (col, es_pais) in FUENTES.items():
    path = CLEAN / fname
    rows = list(csv.DictReader(open(path, encoding='utf-8')))
    for r in rows:
        code = iso(r[col]) if es_pais(r) else None
        if es_pais(r) and not code:
            missing.add(r[col])
        r['pais_iso3'] = code or ''
        if code:
            alias[(r[col], code)].add(fname.split('_')[0].upper())
            if fname == 'ict_llegadas_anuales.csv' and r['zona']:
                zona_ict[code] = r['zona']
            if fname == 'dgme_residentes_acumulados.csv':
                cont_dgme[code] = r['continente']
    with open(path, 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
if missing:
    raise SystemExit(f'Nombres sin código: {sorted(missing)}')

dim = []
for code in sorted({c for _, c in alias}):
    if code in ESPECIALES:
        es, en = ESPECIALES[code]; a2 = ''
    else:
        c = pycountry.countries.get(alpha_3=code)
        a2 = c.alpha_2
        es, en = es_names.get(a2, c.name), en_names.get(a2, c.name)
    dim.append([code, a2, es, en, zona_ict.get(code, ''), cont_dgme.get(code, ''), code.startswith('OT-') or code in ('XXA', 'UNK')])
with open(REF / 'dim_pais.csv', 'w', newline='', encoding='utf-8') as f:
    w = csv.writer(f); w.writerow(['pais_iso3', 'iso2', 'nombre_es', 'nombre_en', 'zona_ict', 'continente_dgme', 'es_agrupacion']); w.writerows(dim)
with open(REF / 'pais_alias.csv', 'w', newline='', encoding='utf-8') as f:
    w = csv.writer(f); w.writerow(['nombre_en_fuente', 'pais_iso3', 'fuentes'])
    w.writerows(sorted([a, c, ';'.join(sorted(s))] for (a, c), s in alias.items()))
print(f'Países: {len(dim)} códigos, {len(alias)} formas de escritura distintas')
