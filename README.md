# Glass Rooms

## Revisió 1.2.0

**Migració des de 1.1.x:** el panell web ja no existeix. Glass Rooms és ara un servidor d'API per a l'[app nativa per a iPad](docs/APP_IOS.md), que és l'única manera d'accedir-hi. Les opcions no canvien: l'app s'identifica amb el mateix `panel_pin` (o `app_token`). Si obries el panell amb Safari, instal·la l'app i introdueix-hi l'adreça del panell i el PIN. Les rutes `/api/login` i `/api/logout`, la cookie de sessió i els fitxers HTML, CSS, JavaScript i SVG s'han retirat; qualsevol petició a l'API sense `Authorization: Bearer` es rebutja.

**Migració des de 1.0.x:** a les opcions privades de Glass Rooms, elimina `panel_password` i configura `panel_pin` amb un PIN nou de 6 a 8 dígits. Desa les opcions i reinicia l'aplicació. Si falta `panel_pin`, el servidor no arrenca. El PIN d'alarma, si n'hi ha, continua sent independent.

**Novetats 1.2.0 (app per a iPad):**

- **Estil Jarvis:** a Ajustos es tria entre «Nit càlida» (negre i ambre) i «Jarvis» (pantalla de dades blau cian, amb graella, anells i resplendor). Tots dos tenen versió de dia i de nit, i totes les pàgines funcionen amb tots dos.
- **Ajustos és una pàgina** sencera, amb Aparença, Pantalla i Connexió.
- **Pantalla:** el temps sense tocar-la abans d'apagar-se es pot escriure en segons (de 5 a 86 400) o triar d'una llista. En passar el temps, l'app deixa la pantalla negra i amb la brillantor al mínim, i el bloqueig automàtic d'iOS la bloqueja després. Tocar-la només l'encén.
- **Brillantor i escalfor de tots els llums** (els Philips Hue i qualsevol llum que publiqui brillantor o temperatura de color) amb dos controls lliscants a la pàgina d'estances, i els mateixos per a tots els llums d'una estança al seu calaix. Canvien els llums encesos; si no n'hi ha cap d'encès, s'encenen tots amb aquell valor.
- **Pàgina Aparells:**
  - l'**escalfador**, amb la temperatura actual, la temperatura objectiu (botons − i +), l'encesa, el mode, el mode absència i tots els atributs que publica, més els sensors del mateix aparell;
  - els **ventiladors** (per exemple CREATE), amb interruptor i un botó per a cada velocitat, de l'1 al 6;
  - els **comandaments** d'infrarojos o ràdio (la tele, la llum de sostre…), amb tots els botons configurats a `remote_buttons` (ara fins a 48 per comandament).
- **Preu de la llum (PVPC):** preu actual en cèntims per kWh, gràfica de les 24 hores amb línies de màxim i mínim, mínim, màxim i mitjana del dia, i l'hora marcada com a **vall**, **normal** o **alta** (les 8 hores més barates, les 8 més cares i la resta). També els preus de l'endemà quan Red Eléctrica els publica.
- **Temperatura de Barcelona** (o de qualsevol entitat `weather.*`) al costat de la data i a la pàgina de Clima.
- **Clima:** períodes d'1, 3, 6, 12, 24 i 48 hores i de 7, 14 i 30 dies.
- **Gràfiques de la portada** amb el valor actual i línies discontínues amb el màxim i el mínim del període.
- **Alarma:** el PIN es marca amb un teclat numèric de botons grans a la mateixa pantalla, sense el teclat d'iOS.
- S'ha retirat el canvi de pàgina lliscant el dit.

Les versions anteriors es descriuen a l'[historial de l'app](docs/APP_IOS.md#historial).

## Què és

Un servidor local per a Home Assistant OS i una app nativa per a l'iPad mini 1 amb iOS 9.3.5, pensada per tenir-la fixa a la paret. L'app parla només amb el servidor de Glass Rooms, i el servidor parla amb Home Assistant per l'API interna de Supervisor. El token de Supervisor no surt mai del servidor.

L'inventari és dinàmic i no incorpora IDs de cap instància. Afegeix les llums a `light_entity_ids` i altres entitats a `entity_ids`, directament a les opcions de l'aplicació a Home Assistant. `room_assignments` les situa a les habitacions i `verified_actions` declara quines accions poden aparèixer quan Home Assistant publica el servei corresponent. Totes les accions comencen bloquejades i el panell no substitueix les dades absents per valors inventats.

El servidor rep els canvis d'estat per WebSocket des de Home Assistant i els comunica a l'app; una lectura periòdica fa de recuperació si el flux cau. Abans de cada ordre torna a llegir l'estat i els serveis de Home Assistant.

## Com començar

1. Quan siguis a casa, segueix [la instal·lació a Home Assistant OS](docs/INSTALLACIO.md). El servidor té el seu propi port, inicialment `8099`.
2. Compila i instal·la [l'app per a iPad](docs/APP_IOS.md) i introdueix-hi l'adreça del panell i el PIN.
3. Completa [la validació de dispositius i de l'iPad](docs/VALIDACIO.md) abans d'habilitar cada control.

Per provar l'app a l'ordinador sense Home Assistant: `python3 glass_rooms/server.py --preview --port 8099` obre una API de només lectura a `127.0.0.1:8099` (amb `--lan-preview --demo-lights`, accessible des de la LAN i amb vuit llums ficticis). No consulta Home Assistant i rebutja totes les ordres.

## Fitxers i guies

| Element | Contingut |
|---|---|
| `glass_rooms/` | Aplicació local per a Home Assistant OS: configuració, imatge i servidor d'API |
| `ios/` · [App per a iPad](docs/APP_IOS.md) | Client natiu UIKit per a iOS 9: compilació sense Xcode, sideload i configuració |
| [Instal·lació](docs/INSTALLACIO.md) | Còpia de seguretat, accés local, autenticació i connexió |
| [Validació](docs/VALIDACIO.md) | Proves per entitat, activació de controls i proves sobre l'iPad real |
| [Inventari i preguntes pendents](docs/INVENTARI.md) | Abast exacte i decisions que falten |
| [Arquitectura](docs/ARQUITECTURA.md) | Flux de dades, permisos i límits |
| [Manteniment](docs/MANTENIMENT.md) | Errors habituals, actualització, reversió i retirada |
| [Proves locals](docs/PROVES_LOCALS.md) | Què s'ha comprovat a l'ordinador i què no |

Les habitacions són una estructura de navegació, no un mapa de dispositius confirmat. No s'infereixen membres dels grups ZHA, el reproductor de sala no s'etiqueta com a Sonos i el script d'alarma no s'executa.
