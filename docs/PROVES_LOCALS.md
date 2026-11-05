# Registre de proves locals

Data: **1 de novembre de 2026**. Entorn: ordinador de desenvolupament macOS, Python 3.11.3 i navegador integrat de Codex. Aquest registre no acredita una prova a Home Assistant OS ni a Safari d'iOS 9.

| Comprovació executada | Resultat |
|---|---|
| Suite `tests/test_backend.py` | **37 de 37 proves superades** |
| HTTP local: sessió, caducitat, cookie, logout, CSRF, Host, origen i Referer | Superat amb clients locals de prova |
| HTTPS directe | Superat amb certificat efímer de prova; cookie Secure i client TLS lent aïllat |
| Autorització de controls | Superat: atributs + servei + verificació explícita; nova lectura abans de cada acció |
| Validació de payloads i límits | Superat: IDs, accions, tipus, rangs, modes i codi d'alarma |
| Dades i privacitat | Superat: atributs filtrats, cap secret als logs de prova, cap estat fictici en mode normal |
| Sintaxi `app.js` | Analitzada com a ES5 amb Acorn; sense fetch, Promise ni requisits moderns llistats pel comprovador |
| Portada al navegador actual | Vuit estances, un sol menjador, il·lustracions carregades |
| Mides 1024×768 i 768×1024 | Quatre i dues columnes respectivament; cap desbordament horitzontal |
| Estança → dispositius → resum | Navegació comprovada amb inventari de previsualització; zero ordres habilitades en preview |
| Preferències | Tema nocturn, retorn a automàtic i activació/desactivació del vidre comprovats |
| Informe de verificació | Carrega el catàleg i indica `preview: true`, `connected: false` |
| Consola del navegador durant les comprovacions | Sense errors registrats |

La suite utilitza objectes de Home Assistant simulats **només dins dels tests**. Aquests valors no formen part de la previsualització ni del panell lliurat al navegador. La prova TLS d'escriptori no comprova la cadena de confiança ni els xifrats disponibles a l'iPad.

## Reproducció

Des de l'arrel del projecte:

```sh
python3 -m unittest discover -s tests -v
node scripts/check-es5.cjs
python3 glass_rooms/server.py --preview --port 8099
```

La suite HTTP/TLS necessita obrir ports efímers només a loopback. La prova TLS necessita `openssl`; si no està disponible, el test ho indica com a omès. El comprovador ES5 utilitza Acorn instal·lat o el parser inclòs en Node quan és accessible; cap d'aquestes eines es lliura com a dependència al navegador.

## No comprovat en aquesta entrega

- Construcció i instal·lació del contenidor a l'amfitrió HA OS de l'usuari.
- URL de casa, versions reals, atributs, serveis, estats i efectes físics.
- Identitat Sonos, membres ZHA, ubicacions i configuració d'Alarmo.
- Safari d'iOS 9: TLS, login real, gest tàctil, memòria, rendiment i ús sostingut.

Completa [VALIDACIO.md](VALIDACIO.md) a casa abans d'habilitar controls.

## Revisió 1.0.1

La prova física posterior de l’usuari ha fallat a Safari 9.3.5 (sense estils, imatges ni resposta dels botons). La revisió incorpora quatre proves de compatibilitat de recursos i estructura, totes superades, i conserva ES5. S’han verificat les vuit imatges, les icones SVG i els botons al navegador actual. La causa exacta i la correcció a l’iPad real encara requereixen [la nova prova](SAFARI_9.md).

## Revisió 1.0.2 — confirmació física parcial

L’1 de novembre de 2026, l’usuari ha obert la versió 1.0.2 a l’iPad amb Safari iOS 9.3.5 i ha confirmat: **«Ara carrega les habitacions»**. És una prova comunicada per l’usuari, no una sessió remota de l’agent. Queden pendents les accions reals, els gestos, TLS al dispositiu i l’ús prolongat.

Corregides dues declaracions de funció dins d’un bloc en mode estricte. El comprovador millorat falla amb el codi anterior i passa amb la correcció. Resultats: 41 proves Python, 4 casos de regressió sintàctica i 5 escenaris del bootstrap superats. Els tres scripts passen ES5 amb la restricció addicional de Safari 9. La pàgina de diagnòstic retorna D1–D7 correctes al navegador d’escriptori.

## Revisió 1.1.4 — app nativa per a iPad

4 de novembre de 2026, macOS 26 amb Command Line Tools (sense Xcode) i `iPhoneOS9.3.sdk`.

| Comprovació executada | Resultat |
|---|---|
| Suite `tests/test_backend.py` amb les proves noves d'`app_token` | Superada: validació de l'opció, lectura i ordre amb Bearer sense cookie ni origen, rebuig de tokens erronis, Host i xarxa, límit d'intents |
| `ios/scripts/test.sh` (lògica i client natius compilats per a macOS contra el servidor real i un Home Assistant simulat) | 46 comprovacions superades |
| `ios/scripts/build.sh` | IPA armv7 + arm64, `-Werror`, enllaçat contra l'SDK 9.3, `LC_VERSION_MIN_IPHONEOS 9.0`, signatura ad hoc SHA-1 i SHA-256 |
| Previsualització Mac Catalyst a 1024×768 i 768×1024 | Portada, resum, clima amb gràfica, calaix d'estança amb controls, llums, ajustos, tema de nit i primera configuració |

No s'ha instal·lat l'app a l'iPad. La compilació Mac Catalyst no emula iOS 9 ni l'A5. Vegeu [APP_IOS.md](APP_IOS.md#què-sha-comprovat).

## Revisió 1.1.5 — PIN com a credencial de l'app

5 de novembre de 2026. L'app nativa accepta el `panel_pin` com a credencial Bearer.

| Comprovació executada | Resultat |
|---|---|
| `tests/test_backend.py` | Superada, amb PIN Bearer correcte i PINs erronis o mal formats rebutjats |
| `ios/scripts/test.sh` | 47 comprovacions superades, inclosa la connexió amb el PIN |
| Instal·lació a l'iPad mini 1 (iOS 9.3.5, jailbreak + AppSync Unified) amb `ideviceinstaller` | Instal·lació completada; l'execució i la connexió a Home Assistant les confirma l'usuari |

## Revisió 1.1.6 — redisseny «Nit càlida» de l'app per a iPad

5 de novembre de 2026. Només canvia l'app nativa; el servidor i el panell web només canvien de número de versió.

| Comprovació executada | Resultat |
|---|---|
| `python3 -m unittest discover -s tests` (inclou `ios/scripts/test.sh`) | 53 proves superades; 47 comprovacions natives sense errors |
| `ios/scripts/build.sh` | IPA armv7 + arm64 contra l'SDK 9.3 amb `-Werror` i `-Werror=unguarded-availability` |
| Previsualització Mac Catalyst a 1024×768 i 768×1024 contra el servidor real amb un Home Assistant simulat | Estances, resum, clima amb historial, calaix d'estança, llums i ajustos, de dia i de nit; l'interruptor de la cuina encén el llum al servidor |
| Instal·lació a l'iPad mini 1 amb `ideviceinstaller` | Instal·lació completada (`cat.glassrooms.panel` 1.1.6). L'aspecte i la connexió al dispositiu els confirma l'usuari: sense la imatge de disc de desenvolupador no es poden fer captures de l'iPad. |

## Revisió 1.1.8 — Clima a pantalla completa a l'app per a iPad

5 de novembre de 2026. Només canvia l'app nativa (i l'avís d'ordre retirat a 1.1.7).

| Comprovació executada | Resultat |
|---|---|
| `python3 -m unittest discover -s tests` (inclou `ios/scripts/test.sh`) | 53 proves superades; 47 comprovacions natives sense errors |
| `ios/scripts/build.sh` i instal·lació a l'iPad mini 1 amb `ideviceinstaller` | IPA 1.1.8 compilada contra l'SDK 9.3 i instal·lada |
| Previsualització Mac Catalyst a 1024×768 i 768×1024, de dia i de nit, amb un Home Assistant simulat | Clima a pantalla completa amb fitxes de sensor, lectura, mínim/màxim/mitjana i gràfica amb eixos; la resta de vistes conserven la columna del rellotge |

## Revisió 1.1.9 — llums que no responen i historial d'humitat

5 de novembre de 2026.

| Comprovació executada | Resultat |
|---|---|
| `tests/test_backend.py` | Superada. Cada sèrie de clima es tanca amb la lectura actual; un sensor amb un sol registre retorna dos punts |
| Previsualització Mac Catalyst amb un llum que ignora les ordres | 12 segons després de l'ordre, l'interruptor queda desactivat, la fila indica «1 llum sense connexió» i surt l'avís «no respon» |
| Previsualització Mac Catalyst amb un sensor d'humitat sense canvis | La gràfica dibuixa una línia plana de 24 h |
| `python3 -m unittest discover -s tests` i `ios/scripts/test.sh` | 53 proves i 47 comprovacions natives superades (l'historial del client compta el punt actual afegit) |
| Instal·lació a l'iPad mini 1 amb `ideviceinstaller` | IPA 1.1.9 instal·lada; el botó de tema ja no hi és i el tema es tria a Ajustos |

No comprovat: el comportament amb el llum i el sensor d'humitat reals de Home Assistant.
