# Mercado legal para extranjeros en Costa Rica: base de datos en PostgreSQL

**ES** · [EN below](#english)

Antes de abrir mi despacho (Moncada Maroto), quise responder con datos públicos una pregunta de negocio: **¿de dónde viene, cuánto crece y cuándo llega la demanda de servicios legales migratorios y corporativos de extranjeros, sobre todo en Guanacaste?**

Este repositorio une dos fuentes oficiales que normalmente se analizan por separado, el **Instituto Costarricense de Turismo (ICT)** y la **Dirección General de Migración y Extranjería (DGME)**, para seguir el recorrido completo:

```
turista que llega  →  turista que repite  →  solicita residencia  →  es residente
   (ICT)                (ICT, encuestas)        (DGME, trámites)       (DGME, acumulados)
```

> **No usa datos de clientes.** Todo proviene de publicaciones oficiales de acceso público.

---

## Qué demuestra este proyecto

| Habilidad | Dónde |
|---|---|
| **Extracción de datos difíciles** (Excel con encabezados combinados, tablas en PDF con miles separados por espacio, un tablero Power BI sin descarga) | `scripts/extract_ict.py`, `scripts/extract_dgme.py` |
| **Control de calidad y corrección de datos oficiales** | Ver [Hallazgos de calidad](#hallazgos-de-calidad-en-las-fuentes) |
| **Modelado dimensional** (staging → estrella → vistas) con llaves, restricciones e índices | `sql/01_schema.sql`, `sql/03_transform.sql` |
| **SQL analítico**: CTE, funciones de ventana (`RANK`, `LAG`, acumulados), `FILTER`, pivotes | `sql/05_views.sql`, `sql/06_analysis.sql` |
| **Integración de fuentes** con códigos ISO-3166 (335 formas de escribir un país → 225 códigos) | `scripts/build_paises.py`, `data/reference/` |
| **Criterio jurídico**: lectura de categorías migratorias y sus límites | Notas del modelo y de los resultados |

---

## Fuentes

| Fuente | Archivo | Contenido | Período |
|---|---|---|---|
| ICT, *Series del sitio web* | `Series_sitio_web_ICT_2025.xlsx` | Llegadas de turistas por país, todas las vías y vía aérea | 2017–2025 (totales desde 1951) |
| ICT, *Llegadas internacionales* | `2025-12_…pdf`, `2026-08_…pdf` | Llegadas mensuales por país y puerto (incluido el aeropuerto de Liberia) | 2025 y ene–ago 2026 |
| ICT, *Encuesta aérea de no residentes* | `NR_Daniel_Oduber_2025.pdf` | Perfil del turista que sale por Liberia (n = 3.300) | 2025 |
| ICT, tablero Power BI *Turistas por vacaciones* | `powerbi_perfil_…json` | Perfil del turista de vacaciones por mercado (13 países), aeropuerto Juan Santamaría | 2011–2025 |
| DGME, *Informes anuales* | `INFORME-ANUAL-2021/22/24/25` | Solicitudes, aprobaciones y denegatorias de permanencia; residentes acumulados; movimiento migratorio por puesto | 2021, 2022, 2024, 2025 |

La DGME no publica el informe 2023; la serie tiene ese vacío. El tablero Power BI del ICT no permite descargar datos, así que se extrajeron con un script del navegador; el JSON queda en `data/raw` y la extracción se verificó contra el tablero (3.436 valores, misma suma).

---

## Hallazgos de calidad en las fuentes

Cuadrar cada tabla contra sus totales oficiales reveló errores que, sin corregir, darían conclusiones falsas. Todas las correcciones quedan en la columna `nota` y en `SPEC` (`scripts/extract_dgme.py`).

| Fuente | Problema | Tratamiento |
|---|---|---|
| DGME 2024, solicitudes por sexo | Las filas por país traen **temporal y permanente invertidos** (la fila TOTAL está bien) | Corregido: tras invertirlas, las sumas cuadran exactamente con el TOTAL |
| DGME 2021 y 2022, aprobaciones | Temporal y permanente **invertidos** entre la hoja por sexo y la hoja por edad | Corregido con el patrón consistente de 2024–2025 (EE. UU. → temporal; Nicaragua → permanente) |
| DGME 2022, solicitudes | Mismo patrón invertido; no hay hoja por edad para contrastar | Corregido por el mismo criterio. **Es un juicio, no una verificación**: queda marcado |
| DGME 2024 y 2025 | Hojas con **el año equivocado en el título** ("AÑO 2023" en un informe de 2024) | Se usó el año que confirman los totales |
| DGME 2021, 2024, 2025 | Sumas internas que no cuadran (p. ej. Cuba 2025: 35 + 38 ≠ 63) | Se conserva el valor publicado y se marca; el control 7 lo reporta |
| DGME, todos los años | 335 formas distintas de escribir países ("Filiphinas", "Rep. De Cores", "Venzuela"…) | Tabla de alias → ISO-3166 (`data/reference/pais_alias.csv`) |
| ICT, tablero Power BI | Valor de 730 % (Suiza, solteros, 2025) y columna 2023 duplicada (Colombia, actividades) | Se conserva el valor publicado y se marca; columnas unidas |

Los controles 1 a 6 de `sql/04_quality_checks.sql` dan **OK**, incluido uno que compara el Excel anual del ICT con la suma de los 12 meses del PDF (coinciden país por país). El control 7 documenta las 3 inconsistencias propias de la fuente (Alemania 2021, Francia 2024 y Cuba 2025).

---

## Modelo de datos

```
staging.*  (copia fiel de los CSV)  ──►  core.*  (estrella)  ──►  analytics.*  (vistas para Tableau)

core.dim_pais ─┬─ fact_llegadas_anual          (ICT)  anio · via · país
               ├─ fact_llegadas_mensual        (ICT)  anio · mes · puerto · país
               ├─ fact_perfil_turista_sjo      (ICT)  país · tema · categoría · período
               ├─ fact_encuesta_lir            (ICT)  región · tema · categoría
               ├─ fact_tramite_permanencia     (DGME) anio · tipo · país · categoría · sexo/edad
               ├─ fact_residentes_acumulados   (DGME) año de corte · país · categoría
               └─ fact_movimiento_migratorio   (DGME) anio · país · puesto · ingreso/egreso
core.dim_categoria_migratoria ── (trámites y residentes)
```

**Límite jurídico importante:** la DGME publica tres categorías (especial, residente temporal y residente permanente). *Residente temporal* agrupa pensionados, rentistas e inversionistas, pero también ejecutivos, profesionales, religiosos y reunificación familiar. Es la mejor aproximación pública al mercado de un despacho de inmigración, no una medida exacta. El desglose por subcategoría requeriría una solicitud formal de información a la DGME.

---

## Cómo ejecutarlo

Requisitos: Python 3.10+ y PostgreSQL 14+.

**Windows (PowerShell):**

```powershell
pip install -r requirements.txt
powershell -ExecutionPolicy Bypass -File .\run_all.ps1      # pide la contraseña de PostgreSQL una vez
psql -U postgres -d mercado_legal -f sql/06_analysis.sql    # preguntas de negocio
```

**macOS / Linux:**

```bash
pip install -r requirements.txt
./run_all.sh
psql -d mercado_legal -f sql/06_analysis.sql
```

Ambos scripts extraen los datos de las fuentes originales, los validan, crean la base `mercado_legal` y corren los controles de calidad.

Los CSV limpios ya están en `data/clean/`, así que también puede cargarlos directamente: `sql/01` → `02` → `03` → `04` → `05`.

---

## Resultados principales

1. **Estados Unidos concentra el 40 % de las solicitudes de residencia temporal (2025)**: 1.891 de 4.706. Los 4 primeros países suman el 57 %. *(P1)*
2. **Señal de rezago en la DGME:** en 2025 las solicitudes de residencia temporal suben 31 % y las aprobaciones bajan 34 %. *(P2)*
3. **Canadá es el mercado de Liberia:** las entradas de canadienses por Liberia equivalen al 65 % de sus llegadas como turistas en 2024 (son universos distintos, ver limitaciones); sus llegadas por ese aeropuerto crecen 31 % en ene–ago 2026, y sus residentes temporales vigentes crecieron 62 % entre 2021 y 2024. *(P3, P4, P6)*
4. **Ventana de marketing:** de diciembre a marzo llega el 61 % de los canadienses que entran por Liberia (2025). *(P5)*
5. **Ya hay propietarios:** el 4,7 % de los canadienses y el 3,0 % de los estadounidenses que salen por Liberia se hospedaron en una vivienda propia en Costa Rica. Son clientes directos de servicios societarios, tributarios y migratorios. *(P9)*
6. **Las residencias temporales casi no se deniegan:** 4,1 % en 2021, contra 9,7 % en categorías especiales. *(P7)*

Las consultas que producen cada cifra están en `sql/06_analysis.sql`.

### Limitaciones
- Las llegadas del ICT cuentan **turistas**; los movimientos de la DGME cuentan **todas las entradas** de una nacionalidad (residentes y entradas repetidas incluidas). Se comparan como orden de magnitud, no como el mismo universo.
- Las aprobaciones de un año incluyen solicitudes de años anteriores: **aprobaciones ÷ solicitudes del mismo año no es una tasa de aprobación.**
- Liberia es un **piso** del mercado de Guanacaste: muchos turistas llegan por Juan Santamaría y viajan por tierra.
- El perfil por mercado (Power BI) corresponde solo a turistas de **vacaciones** que salen por **Juan Santamaría**.

---

<a id="english"></a>
## English summary

**Legal market for foreigners in Costa Rica: a PostgreSQL analytics database built from official open data.**

Before opening my law practice, I used public data to answer a business question: *where does demand for immigration and corporate legal services from foreigners come from, how fast is it growing, and when does it arrive (with a focus on Guanacaste)?* The project joins two official sources that are normally analyzed separately, the Costa Rican Tourism Board (ICT) and the Immigration Authority (DGME), to follow the funnel **tourist → repeat visitor → residency applicant → resident**.

- **Hard extraction:** multi-header Excel files, PDF tables with space-separated thousands, and a Power BI dashboard with no export option.
- **Data quality:** reconciling every table against official totals uncovered **swapped temporary/permanent columns** in the immigration reports for 2021, 2022 and 2024, mislabeled sheet years, and internal sums that don't add up. Every correction is documented; all integrity checks pass, and a final check lists the 3 inconsistencies that come from the source itself.
- **Modeling:** staging → star schema (8 fact tables, country and category dimensions, PKs, FKs, CHECK constraints) → analytics views for Tableau.
- **Country harmonization:** 335 spellings mapped to 225 ISO-3166 codes.
- **Key findings:** the US accounts for 40% of temporary-residency applications (2025); applications rose 31% while approvals fell 34% (a backlog signal); Canada is Liberia's market (+31% arrivals in Jan–Aug 2026, +62% temporary residents 2021–2024); and 3–5% of North American visitors leaving through Liberia stayed in a home they own.

No client data is used; every source is public.

---

**Autora / Author:** Kimberleen Moncada Maroto, abogada y Legal Data Analyst · [GitHub: Cyberkimcr](https://github.com/Cyberkimcr)
