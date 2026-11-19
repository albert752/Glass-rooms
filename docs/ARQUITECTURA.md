# Arquitectura

```text
App nativa per a iPad, iOS 9 (ios/)
  │ Authorization: Bearer PIN del panell (o app_token)
  │ HTTP o HTTPS directe, port 8099
  ▼
Glass Rooms (app local de Home Assistant OS) — només API JSON, sense pàgines web
  ├─ comprovació de xarxa, Host i credencial Bearer a cada petició
  ├─ inventari dinàmic llegit de `light_entity_ids` i `entity_ids` + verificació explícita per acció
  └─ SUPERVISOR_TOKEN només al procés servidor
       ├─ REST: http://supervisor/core/api
       └─ WebSocket: ws://supervisor/core/websocket
       ▼
Home Assistant Core → integracions → dispositius
```

## Límits d'accés

Des de 1.2.0 no hi ha panell web: el servidor no serveix HTML, CSS, JavaScript ni imatges, i no té sessions de navegador, cookies ni CSRF. Totes les rutes `/api/*` excepte `/api/session` exigeixen `Authorization: Bearer` amb el PIN del panell o, si s'ha configurat, `app_token`. Qualsevol altra ruta respon 404.

L'app no parla directament amb l'API de Core. El servidor consulta estats, serveis i la versió, i manté una subscripció WebSocket limitada als IDs configurats. Els canvis desperten una consulta de llarga espera de l'app (`/api/updates`); si la subscripció cau, l'app torna a llegir l'estat cada 8 segons. Després d'una ordre de llum, l'app fa lectures addicionals als 2, 5, 10, 20 i 30 segons fins a rebre confirmació. El servidor retorna només el catàleg i els atributs seleccionats i torna a llegir les capacitats abans d'enviar cada ordre. Les ordres de diversos llums (encendre, apagar, brillantor o temperatura de color) arriben en una sola petició `/api/lights`; el servidor verifica cada llum i envia les ordres autoritzades, encara que una altra falli. Amb la temperatura de color, cada llum rep el valor més proper que admet. No es modifica l'estat de manera optimista ni es reintenten les ordres automàticament.

Una acció necessita tres comprovacions: capacitat actual publicada, servei disponible i entrada exacta a `verified_actions` després d'una prova real. La presència d'una entitat a l'inventari no habilita res. `room_assignments` només configura la navegació; no crea grups ni canvia Home Assistant.

Atributs que surten del servidor: una llista tancada per domini. Hi ha dues excepcions amb filtre propi: l'escalfador (`water_heater`) envia també la resta dels seus atributs simples (números, sí/no o text curt) excepte els que tenen al nom paraules com token, password, key, code, url, ip, mac o serial; i el sensor del PVPC envia els preus de cada hora (`price_00h`…`price_23h`, `price_next_day_…`) i el resum de la integració.

El token de Supervisor té accés ampli a Core. La restricció per entitat és una responsabilitat del servidor, no un permís individual concedit per Home Assistant. L'app de Home Assistant no sol·licita l'API de Supervisor, Docker, xarxa de l'amfitrió, dispositius, ni desactivació de protecció. No és un proxy d'accions arbitràries.

Per al PIN, el servidor en guarda un HMAC-SHA256 amb una sal aleatòria de l'arrencada; per a `app_token`, l'SHA-256. Es comparen en temps constant i els intents erronis tenen un límit de 5 per minut i IP. Les peticions de l'app no porten cap credencial ambiental (cookie), de manera que una pàgina web d'un altre lloc no les pot reutilitzar. Continuen sotmeses a `allowed_networks`, `allowed_hosts` i als límits d'ordres. El servidor no accepta capçaleres de proxy com a prova de xarxa o transport.

Els logs no inclouen cossos, PINs, capçaleres ni respostes de Core. El PIN d'alarma s'escriu en un teclat de l'app, s'envia només amb l'ordre i s'esborra immediatament. Sobre HTTP, el PIN viatja sense xifrar dins la LAN: si pots, configura HTTPS.

El servidor és Python amb biblioteca estàndard i `websockets==15.0.1` per mantenir la subscripció del Core. Està pensat per a pocs clients dins d'una LAN de confiança, no per exposar-lo a Internet. La imatge declarada és Python 3.13 Alpine per a amfitrions amd64/aarch64.

Referències: [API REST de Home Assistant](https://developers.home-assistant.io/docs/api/rest/), [comunicació amb Supervisor](https://contributors.home-assistant.io/apps/guides/communication/).
