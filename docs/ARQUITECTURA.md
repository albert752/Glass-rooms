# Arquitectura i compatibilitat

```text
iPad / navegador de casa          App nativa iOS 9 (ios/)
  │ cookie + CSRF, mateix origen     │ Authorization: Bearer app_token
  └──────────────┬───────────────────┘
                 │ HTTP o HTTPS directe, port 8099
  ▼
Glass Rooms (app local de Home Assistant OS)
  ├─ www/: HTML, CSS, ES5 i SVG sense secrets
  ├─ sessió HttpOnly en memòria + comprovació de xarxa, Host, origen i CSRF
  ├─ inventari dinàmic llegit de `light_entity_ids` i `entity_ids` + verificació explícita per acció
  └─ SUPERVISOR_TOKEN només al procés servidor
       ├─ REST: http://supervisor/core/api
       └─ WebSocket: ws://supervisor/core/websocket
       ▼
Home Assistant Core → integracions → dispositius
```

## Límits d'accés

El navegador no parla directament amb l'API de Core. El servidor consulta estats, serveis i la versió, i manté una subscripció WebSocket limitada als IDs configurats. Els canvis desperten una consulta XHR de llarga espera del navegador; si la subscripció cau, es torna a consultar l'estat cada 30 segons. Després d’enviar una ordre de llum, el navegador fa lectures addicionals als 2, 5, 10, 20 i 30 segons fins a rebre confirmació. El servidor retorna només el catàleg i els atributs seleccionats i torna a llegir les capacitats abans d'enviar cada ordre. El control d'una habitació o de tots els llums arriba en una sola petició; el servidor verifica cada llum i envia les ordres autoritzades a Home Assistant, encara que una altra llum falli. No es modifica l'estat visual de manera optimista ni es reintenten les ordres automàticament. Les errades parcials es mostren al panell.

Els sensors `sensor.*` configurats amb `device_class` `temperature` o `humidity` formen la categoria Clima. La interfície els agrupa segons `room_assignments` i mostra totes les lectures d'una habitació, amb la unitat publicada per Home Assistant. Els sensors sense assignació apareixen separats. Aquesta categoria només consulta estats i no habilita cap ordre.

Una acció necessita tres comprovacions: capacitat actual publicada, servei disponible i entrada exacta a `verified_actions` després d'una prova real. La presència d'una entitat a l'inventari no habilita res. `room_assignments` només configura la navegació; no crea grups ni canvia Home Assistant.

El token de Supervisor té accés ampli a Core. La restricció per entitat és una responsabilitat del servidor, no un permís individual concedit per Home Assistant. L'app no sol·licita l'API de Supervisor, Docker, xarxa de l'amfitrió, dispositius, ni desactivació de protecció. No és un proxy d'accions arbitràries.

El PIN del panell queda en les opcions privades de Supervisor; en memòria es comprova amb PBKDF2. Les sessions aleatòries caduquen al cap de 12 hores i es perden en reiniciar; estan lligades a la IP del client. La cookie és HttpOnly, `SameSite=Strict` i `Secure` si hi ha TLS. El client només rep un nonce CSRF temporal. iOS 9 pot ignorar SameSite: el servidor exigeix també origen exacte o Referer del mateix origen, JSON i nonce. No accepta capçaleres de proxy com a prova de xarxa o transport.

L'[app nativa](APP_IOS.md) no usa cookie ni PIN: envia `Authorization: Bearer` amb `app_token`. El servidor en guarda només l'SHA-256 i el compara en temps constant; els intents erronis comparteixen el límit del login (5 per minut i IP). Aquestes peticions no porten credencial ambiental, de manera que no necessiten origen ni nonce CSRF, però continuen sotmeses a la llista de xarxes, a `allowed_hosts` i als mateixos límits d'ordres. Sense `app_token` configurat, qualsevol capçalera Bearer es rebutja.

Els logs no inclouen cossos, PINs, capçaleres ni respostes de Core. El PIN d'accés es buida de la interfície abans de transmetre'l i no es desa en preferències; el PIN d'alarma es buida del seu camp abans de transmetre'l. `localStorage` només conté el tema i la preferència de vidre; si no funciona, la interfície continua amb els valors predeterminats. Les API, l'HTML, el CSS i el JavaScript se serveixen amb `no-store`; les il·lustracions SVG públiques es conserven un dia i porten una versió a l'URL per renovar-les en actualitzar el panell. Els PINs encara necessiten HTTPS per protegir el transport.

## Eleccions per a Safari d'iOS 9

| Part | Implementació | Alternativa o límit |
|---|---|---|
| JavaScript | ES5 sense mòduls, classes, fletxes, async/await o transpilers | Anàlisi sintàctica amb Acorn; pendent d'execució al Safari real |
| Dades | XMLHttpRequest, peticions al mateix origen | El navegador no rep el token ni es connecta directament a Home Assistant |
| Actualització | WebSocket servidor-Core i notificació long-poll XHR del mateix origen; pausa amb la pàgina amagada | Lectura REST de recuperació cada 30 segons; en tornar, actualitza |
| Disposició | Floats, blocs i posició fixa; controls sense flexbox | Sense CSS Grid, variables CSS o gap necessaris |
| Vidre | Superfícies clares sense desenfocament per defecte | Sense desenfocament a la revisió 1.0.1; superfícies opaques |
| Il·lustracions | Vuit SVG locals petits, sense filtres costosos | No són plànols ni ubicacions de dispositius |
| Navegació | Botons grans, resum visible i finestres | El canvi de secció es fa amb els botons del menú |
| Dia/nit | Hora local del navegador: dia entre 7 i 20 h | El botó del sol o la lluna alterna el tema i desa la tria; també es pot seleccionar a Ajustos |
| Fonts | Tipografia del sistema | No hi ha descàrregues externes |

L'anàlisi ES5 no valida les API DOM ni els detalls de Safari. El navegador integrat modern i una mida de 1024 × 768 no emulen iOS 9 ni l'A5 de l'iPad mini 1. Encara s'han de provar TLS, confiança del certificat, teclat, cookies, zoom, rotació, memòria i rendiment al dispositiu. No es fa cap gestió de bloqueig o activació de pantalla.

El servidor és Python amb biblioteca estàndard i `websockets==15.0.1` per mantenir la subscripció del Core. Està pensat per a pocs clients dins d'una LAN de confiança, no per exposar-lo a Internet. La imatge declarada és Python 3.13 Alpine per a amfitrions amd64/aarch64; construir-la i provar-la al teu Home Assistant OS forma part de la posada en servei pendent.

Referències: [API REST de Home Assistant](https://developers.home-assistant.io/docs/api/rest/), [comunicació amb Supervisor](https://contributors.home-assistant.io/apps/guides/communication/), [Safari 9 segons Apple](https://developer.apple.com/library/archive/releasenotes/General/WhatsNewInSafari/Articles/Safari_9_0.html).
