import csv, unicodedata, re, collections
from babel import Locale
import pycountry
def key(s):
    s=unicodedata.normalize('NFKD',s).encode('ascii','ignore').decode().lower()
    s=re.sub(r'[^a-z ]',' ',s); return re.sub(r'\s+',' ',s).strip()
es=Locale('es').territories; en=Locale('en').territories
K={}
for a2,name in es.items():
    if len(a2)==2 and a2.isalpha():
        c=pycountry.countries.get(alpha_2=a2)
        if c: K[key(name)]=c.alpha_3
MAN={'canada':'CAN','paises bajos':'NLD','holanda':'NLD','rep pop de china':'CHN','china':'CHN','rep de china taiwan':'TWN','taiwan':'TWN',
 'rep de corea':'KOR','rep de corea sur':'KOR','corea del sur':'KOR','rep dem del congo':'COD','rep del congo':'COG','rep de guinea':'GIN',
 'rep dominicana':'DOM','republica dominicana':'DOM','rep checa':'CZE','republica checa':'CZE','rep helenica':'GRC','grecia':'GRC',
 'federacion rusa':'RUS','rusia':'RUS','estados unidos':'USA','reino unido':'GBR','inglaterra':'GBR','bielorrusia':'BLR','belarus':'BLR',
 'iran':'IRN','siria':'SYR','vietnam':'VNM','viet nam':'VNM','tanzania':'TZA','bolivia':'BOL','venezuela':'VEN','moldavia':'MDA',
 'macedonia':'MKD','laos':'LAO','palestina':'PSE','kazajistan':'KAZ','kirguistan':'KGZ','tayikistan':'TJK','tajistan':'TJK','azerbaiyan':'AZE',
 'botsuana':'BWA','costa de marfil':'CIV','guinea bissau':'GNB','sudan del sur':'SSD','san vicente y las granadinas':'VCT','saint kitts y nevis':'KNA',
 'san cristobal y nevis':'KNA','trinidad y tobago':'TTO','samoa':'WSM','micronesia':'FSM','emiratos arabes unidos':'ARE','guayana':'GUY','guyana':'GUY',
 'guyana francesa':'GUF','guadalupe':'GLP','bermudas':'BMU','bermuda':'BMU','butan':'BTN','benin':'BEN','niger':'NER','ruanda':'RWA','camerun':'CMR',
 'haiti':'HTI','panama':'PAN','peru':'PER','mexico':'MEX','japon':'JPN','libano':'LBN','belgica':'BEL','hungria':'HUN','rumania':'ROU','rumanía':'ROU',
 'sudafrica':'ZAF','africa del sur':'ZAF','tunez':'TUN','turquia':'TUR','espana':'ESP','alemania':'DEU','suiza':'CHE','puerto rico':'PRI',
 'antillas holandesa':'ANT','antillas holandesas':'ANT','hong kong':'HKG','granada':'GRD','apatrida':'XXA','apatria':'XXA','no indica':'UNK',
 'arabia saudita':'SAU','eslovaquia':'SVK','republica centroafricana':'CAF','malasia':'MYS','islandia':'ISL','luxemburgo':'LUX','filipinas':'PHL',
 'nueva zelanda':'NZL','jamaica':'JAM','dominica':'DMA','santa lucia':'LCA','corea del norte':'PRK','rep pop dem de corea':'PRK','ucrania':'UKR',
 'myanmar':'MMR','birmania':'MMR','surinam':'SUR','bahamas':'BHS','barbados':'BRB','belice':'BLZ','zimbabue':'ZWE','zimbabwe':'ZWE','kenia':'KEN',
 'serbia':'SRB','montenegro':'MNE','bosnia herzegovina':'BIH','bosnia y herzegovina':'BIH','vanuatu':'VUT','yemen':'YEM','zambia':'ZMB','namibia':'NAM',
 'eslovenia':'SVN','malta':'MLT','estonia':'EST','letonia':'LVA','lituania':'LTU','croacia':'HRV','albania':'ALB','armenia':'ARM','georgia':'GEO',
 'uzbekistan':'UZB','turkmenistan':'TKM','mongolia':'MNG','nepal':'NPL','sri lanka':'LKA','bangladesh':'BGD','pakistan':'PAK','afganistan':'AFG',
 'irak':'IRQ','jordania':'JOR','kuwait':'KWT','qatar':'QAT','catar':'QAT','oman':'OMN','bahrein':'BHR','israel':'ISR','egipto':'EGY','marruecos':'MAR',
 'argelia':'DZA','libia':'LBY','etiopia':'ETH','eritrea':'ERI','somalia':'SOM','sudan':'SDN','uganda':'UGA','ghana':'GHA','nigeria':'NGA','senegal':'SEN',
 'mali':'MLI','gabon':'GAB','angola':'AGO','mozambique':'MOZ','madagascar':'MDG','malawi':'MWI','burundi':'BDI','togo':'TGO','liberia':'LBR',
 'sierra leona':'SLE','gambia':'GMB','cabo verde':'CPV','guinea ecuatorial':'GNQ','chad':'TCD','burkina faso':'BFA','mauritania':'MRT','djibouti':'DJI','yibuti':'DJI',
 'tailandia':'THA','camboya':'KHM','indonesia':'IDN','singapur':'SGP','australia':'AUS','fiyi':'FJI','fiji':'FJI','papua nueva guinea':'PNG',
 'curazao':'CUW','aruba':'ABW','martinica':'MTQ','andorra':'AND','monaco':'MCO','liechtenstein':'LIE','san marino':'SMR','chipre':'CYP',
 'samoa occidental':'WSM','emiratos arebes unidos':'ARE','ganada':'GRD','tayikistan':'TJK','kosovo':'XKX','saint lucia':'LCA','islas caiman':'CYM',
 'islas virgenes':'VGB','gran bretana':'GBR','nicaragua':'NIC'}

MAN.update({'anguilla':'AIA','bhutan':'BTN','bosnia y hercegovina':'BIH','botswana':'BWA','bukina faso':'BFA','comoros':'COM','isla christmas':'CXR',
'islas marshal':'MHL','islas turks y caicos':'TCA','islas turcas y caicas':'TCA','islas turcos y caicos':'TCA','turcos y caicos':'TCA','kyrgystan':'KGZ','kirgistan':'KGZ',
'moldova':'MDA','palau':'PLW','principado de monaco':'MCO','rep centroafricana':'CAF','rep guinea':'GIN','republica de guinea':'GIN','suazilandia':'SWZ','swazilandia':'SWZ',
'sudan del norte':'SDN','tajikistan':'TJK','arabia sudita':'SAU','argel':'DZA','barabados':'BRB','burindi':'BDI','costa de mafil':'CIV','cripre':'CYP',
'el salavador':'SLV','estiopia':'ETH','gutemala':'GTM','islas fiji':'FJI','kazaguistan':'KAZ','ltuania':'LTU','naru':'NRU','niu':'NIU','pakistasn':'PAK',
'puero rico':'PRI','re checa':'CZE','rep corea':'KOR','rep de china':'TWN','rep de taiwan':'TWN','republica de china taiwan':'TWN','rep dominicaa':'DOM','rwanda':'RWA',
'suadfrica':'ZAF','sudan sur':'SSD','surinan':'SUR','tunes':'TUN','uzbequistan':'UZB','vanatu':'VUT','venzuela':'VEN','viet nan':'VNM','vietnan':'VNM',
'iraq':'IRQ','islas pitcarin':'PCN','lesotho':'LSO','mayanmar':'MMR','reino tonga':'TON','republica de corea':'KOR','republica del congo':'COG',
'republica dem del congo':'COD','republica helenica':'GRC','republica pop de china':'CHN','republica pop dem de corea':'PRK','santa sede del vaticano':'VAT',
'timor oriental':'TLS','yugoeslavia':'YUG','otros asia y el pacifico':'OT-ASP','otros caribe':'OT-CAR','otros europa':'OT-EUR','otros oriente medio':'OT-OME','otros africa':'OT-AFR'})
MAN.update({'otras zonas asia africa y oriente medio':'OT-ZON'})
MAN.update({'filiphinas':'PHL','kazagistan':'KAZ','mynmar':'MMR','rep de cores':'KOR','zinbabwe':'ZWE'})
MAN.update({'islas virgenes e e u u':'VIR','islas virgenes eeuu':'VIR','islas virgenes estadounidenses':'VIR'})
def iso(name):
    full=key(name); k=key(re.sub(r'\(.*?\)','',name))
    return MAN.get(full) or K.get(full) or MAN.get(k) or K.get(k)
