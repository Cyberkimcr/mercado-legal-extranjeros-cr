"""Extrae y valida los informes anuales de la Dirección General de Migración y Extranjería (DGME).

Fuentes (data/raw/dgme): INFORME-ANUAL-2021.xls, -2022.xlsx, -2024.xls, -2025.xls
(la DGME no publica el informe 2023).

Produce:
  - dgme_tramites_permanencia.csv ....... solicitudes, aprobaciones y denegatorias (2021) por país,
                                          categoría migratoria, sexo y edad
  - dgme_residentes_acumulados.csv ...... residentes vigentes por país al cierre de 2021, 2022 y 2024
  - dgme_movimiento_migratorio.csv ...... ingresos y egresos por nacionalidad y puesto migratorio

Las hojas de la DGME contienen errores (columnas temporal/permanente invertidas, títulos con el año
equivocado, sumas que no cuadran). Cada corrección está documentada en SPEC y en la columna `nota`.
"""
import csv, re
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW, OUT = ROOT / "data/raw/dgme", ROOT / "data/clean"
CATS = ['Categoría especial', 'Residente temporal', 'Residente permanente']
GRUPO = {'HOMBRE': 'Hombre', 'MUJER': 'Mujer', 'MAYOR': 'Mayor de edad', 'MENOR': 'Menor de edad'}


def check(cond, msg):
    if not cond:
        raise SystemExit(f'VALIDACIÓN FALLIDA: {msg}')


def write(name, header, rows):
    with open(OUT / name, 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f); w.writerow(header); w.writerows(rows)
    print(f'  -> {name}: {len(rows)} filas')


def clean_name(p):
    return re.sub(r'\s+', ' ', str(p)).strip().title()


# swap: False = sin cambio; True = la hoja entera (incluida la fila TOTAL) trae temporal/permanente invertidos;
#       'rows' = solo las filas por país vienen invertidas (la fila TOTAL está bien)
SPEC = [
 ('INFORME-ANUAL-2021.xls', 'SOLIC. SEXO ', 2021, 'solicitud', 'sexo', False, ''),
 ('INFORME-ANUAL-2021.xls', 'SOLIC. EDAD', 2021, 'solicitud', 'edad', False, 'Hoja titulada "SOLICITUDES APROBADAS" en la fuente; sus totales coinciden con las solicitudes (76.040)'),
 ('INFORME-ANUAL-2021.xls', 'APROB. SEX', 2021, 'aprobada', 'sexo', True, 'Temporal/permanente invertidos en la fuente respecto a la hoja por edad; corregido'),
 ('INFORME-ANUAL-2021.xls', 'APROB. EDAD', 2021, 'aprobada', 'edad', False, ''),
 ('INFORME-ANUAL-2021.xls', 'DENEG. SEXO', 2021, 'denegada', 'sexo', False, ''),
 ('INFORME-ANUAL-2021.xls', 'DENEG. EDAD', 2021, 'denegada', 'edad', False, ''),
 ('INFORME-ANUAL-2022.xlsx', 'SOLIC.SEXO', 2022, 'solicitud', 'sexo', True, 'Temporal/permanente invertidos en la fuente; corregido según el patrón 2021, 2024 y 2025 (no hay hoja por edad para contrastar)'),
 ('INFORME-ANUAL-2022.xlsx', 'APROB. SEXO', 2022, 'aprobada', 'sexo', False, ''),
 ('INFORME-ANUAL-2022.xlsx', 'APROB. EDAD', 2022, 'aprobada', 'edad', True, 'Temporal/permanente invertidos en la fuente respecto a la hoja por sexo; corregido'),
 ('INFORME-ANUAL-2024.xls', 'SOLIC. CATEG. SEXO', 2024, 'solicitud', 'sexo', 'rows', 'Filas por país con temporal/permanente invertidos (la fila TOTAL está bien); corregido'),
 ('INFORME-ANUAL-2024.xls', 'SOLIC. CATEG. EDAD', 2024, 'solicitud', 'edad', False, ''),
 ('INFORME-ANUAL-2024.xls', 'APROB. CATEG SEXO', 2024, 'aprobada', 'sexo', False, 'Hoja titulada "AÑO 2023" en la fuente; sus totales coinciden con 2024'),
 ('INFORME-ANUAL-2024.xls', 'APROB . CATEG. EDAD.', 2024, 'aprobada', 'edad', False, ''),
 ('INFORME-ANUAL-2025.xls', 'SOLIC. SEXO', 2025, 'solicitud', 'sexo', False, ''),
 ('INFORME-ANUAL-2025.xls', 'SOLIC.', 2025, 'solicitud', 'edad', False, 'Hoja titulada "AÑO 2024" en la fuente; sus totales coinciden con 2025'),
 ('INFORME-ANUAL-2025.xls', 'APROB. SEXO', 2025, 'aprobada', 'sexo', False, ''),
 ('INFORME-ANUAL-2025.xls', 'APROB. EDAD', 2025, 'aprobada', 'edad', False, ''),
]


def tramites():
    rows = []
    for f, sh, anio, tipo, des, swap, nota in SPEC:
        df = pd.read_excel(RAW / f, sheet_name=sh, header=None)
        hdr = next(i for i in range(15) if str(df.iloc[i, 3]).strip() == 'TOTAL')
        labs = [str(df.iloc[hdr, c]).strip() for c in range(1, 10)]
        if des == 'edad':  # algunas hojas por edad rotulan mal las subcolumnas (MUJER/HOMBRE)
            labs = ['MAYOR', 'MENOR', 'TOTAL'] * 3
        tot, data = None, []
        for i in range(hdr + 1, len(df)):
            p = df.iloc[i, 0]
            if not isinstance(p, str) or not p.strip():
                continue
            p = re.sub(r'\s+', ' ', p).strip()
            if re.match(r'^(Notas|Fuente|Planificaci|\d/|\*)', p):
                break
            v = df.iloc[i, 1:11].tolist()
            if any(pd.isna(x) for x in v):
                continue
            v, L = [int(x) for x in v], list(labs)
            if p == 'TOTAL':
                if swap is True:
                    v = v[:3] + v[6:9] + v[3:6] + v[9:]
                tot = v; continue
            if swap:
                v, L = v[:3] + v[6:9] + v[3:6] + v[9:], L[:3] + L[6:9] + L[3:6]
            data.append((p, v, L))
        for k in range(3):
            check(sum(d[1][3 * k + 2] for d in data) == tot[3 * k + 2], f'{f}/{sh}: {CATS[k]} no suma el TOTAL')
        for p, v, L in data:
            for k in range(3):
                a, b, t = v[3 * k:3 * k + 3]
                nn = nota
                if a + b != t:
                    nn = (nn + '; ' if nn else '') + f'Inconsistencia en la fuente: {a} + {b} no suma {t}'
                for j in range(2):
                    rows.append([anio, tipo, clean_name(p), CATS[k], des, GRUPO[L[3 * k + j]], v[3 * k + j], f'{f} / {sh.strip()}', nn])
    write('dgme_tramites_permanencia.csv', ['anio','tipo','pais_origen','categoria_migratoria','desagregacion','grupo','cantidad','fuente','nota'], rows)


def acumulados():
    cont_names = {'AFRICA', 'AMERICA', 'ASIA', 'EUROPA', 'OCEANIA', 'OTROS'}
    rows = []
    for f, sh, anio in [('INFORME-ANUAL-2021.xls', 'ACUMULADOS 2021', 2021), ('INFORME-ANUAL-2022.xlsx', 'ACUMULADOS 2022', 2022),
                        ('INFORME-ANUAL-2024.xls', 'ACUMUL AL 31-12-2024', 2024)]:
        df = pd.read_excel(RAW / f, sheet_name=sh, header=None)
        cont, tot, csum, data = None, None, {}, []
        for i in range(len(df)):
            p = df.iloc[i, 0]
            if not isinstance(p, str) or not p.strip():
                continue
            P = p.strip()
            v = df.iloc[i, 1:5].tolist()
            if any(pd.isna(x) or not str(x).isdigit() for x in v):
                continue
            v = [int(x) for x in v]
            if P == 'TOTAL':
                tot = v
            elif P in cont_names:
                cont = P.title(); csum[cont] = v
            else:
                check(sum(v[:3]) == v[3], f'{sh}: la fila {P} no suma')
                data.append((cont, P, v))
        for c, cv in csum.items():
            check([sum(d[2][k] for d in data if d[0] == c) for k in range(4)] == cv, f'{sh}: {c} no suma')
        check([sum(d[2][k] for d in data) for k in range(4)] == tot, f'{sh}: países no suman el TOTAL')
        for c, p, v in data:
            for k, cat in enumerate(CATS):
                rows.append([anio, c, clean_name(p), cat, v[k]])
    write('dgme_residentes_acumulados.csv', ['anio_corte','continente','pais_origen','categoria_migratoria','residentes'], rows)


def movimiento():
    rows = []
    for f, sh, anio in [('INFORME-ANUAL-2021.xls', 'MOV. MIG.', 2021), ('INFORME-ANUAL-2022.xlsx', 'MOV. MIG. 2022', 2022),
                        ('INFORME-ANUAL-2024.xls', 'MOV. MIG.NAC. 2024', 2024)]:
        df = pd.read_excel(RAW / f, sheet_name=sh, header=None)
        h = next(i for i in range(15) if str(df.iloc[i, 1]).strip().startswith('ING'))
        top, mid, typ = df.iloc[h - 2].tolist(), df.iloc[h - 1].tolist(), df.iloc[h].tolist()
        cols, cur = [], None
        for c in range(1, df.shape[1]):
            t = str(typ[c]).strip()
            if not t.startswith(('ING', 'EGR')):
                continue
            if t.startswith('ING'):
                cur = str(mid[c]).strip() if str(mid[c]).strip() != 'nan' else str(top[c]).strip()
            cols.append((c, re.sub(r'\s+', ' ', cur), 'Ingreso' if t.startswith('ING') else 'Egreso'))
        tot, sub = None, []
        for i in range(h + 1, len(df)):
            p = df.iloc[i, 0]
            if not isinstance(p, str) or not p.strip():
                continue
            P = re.sub(r'\s+', ' ', p).strip()
            if P.startswith(('Fuente', 'Nota', '*', 'a/', 'Planif')):
                break
            vals = [df.iloc[i, c] for c, _, _ in cols]
            if any(pd.isna(x) for x in vals):
                continue
            if P == 'TOTAL':
                tot = dict(zip([(pu, t) for _, pu, t in cols], vals)); continue
            for (c, pu, t), x in zip(cols, vals):
                if pu != 'TOTAL':
                    sub.append([anio, clean_name(P), pu.title(), t, int(x)])
        for t in ('Ingreso', 'Egreso'):
            check(sum(r[4] for r in sub if r[3] == t) == tot[('TOTAL', t)], f'{sh}: {t} no suma el TOTAL')
        rows += sub
    write('dgme_movimiento_migratorio.csv', ['anio','pais_nacionalidad','puesto_migratorio','tipo_movimiento','personas'], rows)


if __name__ == '__main__':
    print('DGME:')
    tramites(); acumulados(); movimiento()
