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
