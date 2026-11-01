# Compatibilitat amb Safari iOS 9.3.5

## Correcció 1.0.2: bloqueig abans d'executar app.js

S'han trobat dues declaracions de funció dins d'un `if` en mode estricte (`updateLabel` i `changeRange`). Safari 9 pot rebutjar el fitxer complet amb `SyntaxError: Strict mode does not allow function declarations in a lexically nested statement`. Això impedeix arribar al `try/catch` d'arrencada del mateix fitxer i encaixa amb l'avís immutable «carregant la interfície». Hi ha un [informe directe del projecte noVNC sobre iOS 9.3.5](https://github.com/novnc/noVNC/issues/815) amb aquest mateix error.

Les dues funcions ara són expressions assignades a `var`. La comprovació anterior amb Acorn en mode ES5 acceptava aquesta extensió: el nou comprovador recorre l'arbre sintàctic i rebutja explícitament declaracions fora del cos immediat d'una funció o del programa. S'ha observat que el nou comprovador falla amb el codi anterior a la línia 211 i passa després de la correcció. **L’usuari ha confirmat «Ara carrega les habitacions» a l’iPad amb la versió 1.0.2.** Aquesta validació d’arrencada no acredita les accions domòtiques ni el rendiment sostingut.

`boot.js` és independent d'`app.js` i s'executa abans: pot mostrar un error de parseig d'`app.js`, que el seu propi `try/catch` no podia capturar. No imprimeix dades, missatges d'aplicació, PINs ni tokens. La pàgina `diagnostics.html` també és independent, no inicia sessió ni envia ordres, i no depèn de la inicialització principal.

Per provar la previsualització, obre la URL del PC amb `/?v=1.0.2`; si falla, obre `/diagnostics.html`. Si és el complement instal·lat, actualitza **tota** la carpeta i reconstrueix la imatge a 1.0.2: ara també calen `boot.js`, `diagnostics.js` i `diagnostics.html`.

| Codi | Significat |
|---|---|
| Avís inicial sense G1 | Ni tan sols s'ha executat boot.js; comprova versió, càrrega, JavaScript o bloqueig de recursos |
| G1 | Bootstrap executat, app.js encara no interpretat |
| G2 | app.js interpretat |
| G3 / G4 | Inicialització de navegació/icones o habitacions |
| B1 | Script no descarregat o bloquejat |
| B2 | Error JavaScript amb categoria i línia |
| B3 | L'arrencada no ha acabat en 10 segons |
| B4 | El CSS no s'ha aplicat |
| D0 / D1 | Diagnòstic independent pendent / executat |
| D2–D4 | CSS, APIs bàsiques i SVG |
| D5–D7 | Estat HTTP i MIME del JS, CSS i servidor; descarregar JS no prova que s'executi |

Reproducció local: `node scripts/check-es5.cjs`, `node tests/test_js_compat.cjs`, `node tests/test_boot.cjs` i `python3 -m unittest discover -s tests -v`.

## Històric: revisió 1.0.1

La prova física de l'usuari de la versió inicial va fallar: pàgina sense estils, sense imatges ni icones, i botons sense resposta. L'usuari indica que la URL no té subcarpeta. Per tant, **no s'ha confirmat la causa concreta** i no s'atribueix el problema a les rutes absolutes.

## Canvis aplicats

- CSS i JavaScript amb rutes relatives i revisió `?v=1.0.1`; imatges i API relatives al panell. També es pot visualitzar la UI dins d'una subcarpeta, però les accions continuen necessitant el servidor propi.
- Script carregat després de tot el contingut HTML, sense dependre de `defer`.
- Normalització de l'aparença nativa dels botons amb `-webkit-appearance: none`, mides i tipografia explícites.
- Graella basada en floats i neteja de files; controls sense flexbox. Eliminats object-fit, calc, unitats vh, focus-visible i desenfocament. Superfícies opaques i mode dia/nit conservats.
- Icones SVG amb namespace XML explícit, dimensions i atributs propis, sense inserir SVG amb innerHTML.
- Avís d'arrencada present al mateix HTML, amb enllaços directes al CSS, JS i una il·lustració. El client comprova que el CSS s'ha aplicat abans d'amagar-lo. Una fallada d'inicialització deixa un missatge llegible.

## Tornar a provar a l'iPad

1. Si utilitzes la previsualització del PC, recarrega la mateixa URL del PC amb `/?v=1.0.1`. No introdueixis `127.0.0.1` a l'iPad: apuntaria al mateix iPad.
2. Si has instal·lat el complement a HA OS, actualitza la carpeta completa `glass_rooms`, refresca la botiga i actualitza/reconstrueix la imatge a **1.0.1**. Reiniciar una imatge antiga no copia els fitxers nous.
3. Tanca la pestanya antiga de Safari i torna a obrir la URL. A Ajustos ha d'aparèixer **Glass Rooms 1.0.1**. Prova primer a Safari normal, després l'accés de pantalla d'inici.
4. Si l'avís d'arrencada queda visible, obre els enllaços **CSS**, **JavaScript** i **imatge** que inclou. Anota quin falla i el missatge HTTP que mostra, sense enviar credencials. Si falta el fitxer, cal corregir el desplegament o l'accés abans de revisar el disseny.
5. Si els fitxers es carreguen però no s'inicia, comprova **Configuració d'iOS → Safari → Avançat → JavaScript**. Anota el text de l'avís, la URL completa i si es tracta de Safari o de l'accés de pantalla d'inici.
6. Comprova vuit targetes en horitzontal i vertical, obertura/tancament d'una estança, botó del resum, Ajustos i mode nocturn. Els controls domòtics continuen bloquejats fins a la seva verificació real.

No cal modificar permisos, tokens, cookies ni la política de seguretat del servidor per carregar els recursos. No es desactiva CSP com a solució provisional.

## Evidència disponible

Quatre proves noves protegeixen les rutes relatives, l'ordre de càrrega, l'avís d'arrencada, la base CSS i el namespace SVG. La sintaxi continua passant l'anàlisi ES5. Al navegador actual s'han comprovat recursos i botons a l'arrel i en una subcarpeta; això **no emula Safari 9.3.5**. La nova prova física de l'iPad encara queda pendent.

Referències: [configuració del viewport d'Apple](https://developer.apple.com/library/archive/documentation/AppleApplications/Reference/SafariWebContent/UsingtheViewport/UsingtheViewport.html), [error històric de layout flexbox a WebKit](https://bugs.webkit.org/show_bug.cgi?id=136041). Aquests documents justifiquen decisions conservadores, però no demostren la causa de la fallada observada.
