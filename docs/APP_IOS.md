# App nativa per a iPad (iOS 9)

`ios/` conté **Glass Rooms per a iPad**, una aplicació UIKit escrita en Objective-C per a l'iPad mini 1 amb iOS 9.3.5. No és un navegador incrustat: rellotge, llistes, gràfiques, calaix lateral, controls i preferències són vistes natives.

Des de 1.2.0 l'app és l'**única** manera d'accedir a Glass Rooms: el servidor ja no té panell web.

## Disseny

Està pensat per a un iPad fix a la paret i llegit a distància.

- **Estils (des de 1.2.0):** a Ajustos → Aparença es tria l'estil i el tema.
  - *Nit càlida*: de nit, negre pur amb text ambre; de dia, paper càlid amb ambre torrat.
  - *Jarvis*: una pantalla de dades a l'estil d'Iron Man. De nit, blau gairebé negre amb cian brillant, una graella de fons, anells al voltant del rellotge, cantonades marcades a les targetes i resplendor als elements actius; de dia, vidre clar amb cian fosc. Tipografia Avenir Next Condensed.
  - El tema (automàtic, dia o nit) s'aplica a tots dos estils; en automàtic és de dia de 7 a 20 h.
- **Columna del rellotge** (pàgines Estances i Resum):
  - l'hora en gran i la data, seguida de la temperatura exterior (per exemple «Barcelona 16,4° · mig ennuvolat») si hi ha una entitat `weather.*`;
  - la temperatura i la humitat interiors, amb la mitjana dels sensors disponibles;
  - l'estat de l'alarma o, si no n'hi ha cap, els llums encesos;
  - la corba de temperatura i la d'humitat del període triat a Clima, amb el valor actual al final i línies discontínues amb el màxim i el mínim del període (des de 1.2.0).
- **Navegació inferior:** Estances, Clima, Escalfador, Ventiladors, Comandaments, Preu de la llum, Seguretat, Resum i Ajustos (des de 1.2.1, Escalfador, Ventiladors i Comandaments són tres pàgines; a la 1.2.0 eren una sola, Aparells). Des de 1.2.0 no es canvia de pàgina lliscant el dit.
- **Estances:** una fila per estança, amb un punt si té llums encesos, la temperatura i un interruptor de llums. Tocar el nom obre el calaix de l'estança. Sota la llista hi ha «Encén tot» i «Apaga tot», la secció **Tots els llums** i la tira d'escenes.
- **Tots els llums (des de 1.2.0):** un control lliscant de brillantor i un d'escalfor (de càlida a freda, en kelvin) per a tots els llums que en publiquen, com els Philips Hue. Canvien els llums encesos; si no n'hi ha cap d'encès, s'encenen tots amb aquell valor. Cada llum rep la temperatura de color més propera que admet. El valor s'envia en deixar anar el dit, en una sola petició. El calaix d'una estança amb més d'un llum té els mateixos controls per als llums de l'estança.
- **Clima:** ocupa tota la pantalla. A dalt, la temperatura exterior i els períodes (1, 3, 6, 12, 24 i 48 h; 7, 14 i 30 dies des de 1.2.0); a sota, una fitxa per sensor, la lectura en gran amb el mínim, el màxim i la mitjana, i la gràfica, que es pot tocar o arrossegar. Home Assistant guarda 10 dies d'historial per defecte; per als períodes més llargs cal augmentar `purge_keep_days` del recorder.
- **Escalfador, Ventiladors i Comandaments (pàgines des de 1.2.1; a la 1.2.0, juntes a Aparells):**
  - **Escalfador** (`water_heater.*`): a la primera targeta, temperatura actual en gran, temperatura objectiu, estat i interruptor d'encesa. La temperatura objectiu es canvia amb − i + i s'envia 1,5 s després de l'últim toc. Els modes es trien amb un toc. Mode absència amb interruptor. A la segona targeta, **tota la informació** que publica l'escalfador (temperatures, límits, modes i qualsevol altre atribut simple, com potència o dutxes) i els sensors del mateix aparell: les entitats de `entity_ids` amb el mateix nom de base (per exemple `sensor.termo_energia` per a `water_heater.termo`).
  - **Ventiladors** (`fan.*`): una targeta per ventilador, amb l'estança, l'interruptor i un botó per a cada velocitat, i el llum que té el mateix nom (per exemple `light.ventilador_despatx` amb `fan.ventilador_despatx`). Si el ventilador publica `percentage_step` (16,67 % per a 6 velocitats, com els CREATE), l'app en dedueix el nombre; si no, es configura amb `fan_speeds`. La velocitat *n* de *N* s'envia com a `floor(n × 100 / N)` %, la mateixa conversió que fa Home Assistant.
  - **Comandaments** (`remote.*`): una targeta per cada dispositiu de `remote_buttons`, amb tots els seus botons. Si la tele i la llum de sostre s'han après al mateix emissor amb dispositius diferents (`tele`, `llum_sostre`), surten en dues targetes.
- **Preu de la llum (des de 1.2.0):** a partir del sensor de la integració *Spain electricity hourly pricing (PVPC)*.
  - El preu actual en cèntims d'euro per kWh i si l'hora és **vall**, **normal** o **alta**: vall són les 8 hores més barates del dia, alta les 8 més cares i normal la resta.
  - El mínim i el màxim del dia (amb l'hora) i la mitjana.
  - Una gràfica de barres de les 24 hores, de color segons el nivell, amb l'hora actual destacada i línies discontínues al màxim i al mínim. Tocar o arrossegar sobre la gràfica mostra el preu de cada hora.
  - «Avui» i «Demà» quan Home Assistant ja té els preus de l'endemà (normalment a partir de les 20.30).
  - El període tarifari (punta P1, pla P2, vall P3), el següent, la propera hora més barata i les tres hores més barates que queden avui.
- **Avisos:** les ordres no mostren cap missatge en enviar-se ni quan funcionen; només si fallen o s'ometen llums.
- **Llums que no responen (des de 1.1.9):** si un llum no arriba a l'estat demanat 10 segons després d'una ordre, l'app el marca com a «No respon a les ordres» i n'atura els controls fins que Home Assistant informa un estat nou o passen 2 minuts. Si es perden les actualitzacions en directe, l'estat es torna a llegir cada 8 segons.
- **Ajustos (pàgina des de 1.2.0):** Aparença (estil i tema), Pantalla i Connexió (adreça, PIN, comprovació i informe de verificació).
- **Pantalla (des de 1.2.0):** el temps sense tocar-la abans d'apagar-se es tria entre «Com iOS», 15 s, 30 s, 1 min, 5 min, 15 min, 1 h i «Mai», o s'escriu en segons (de 5 a 86 400). Una app no pot bloquejar l'iPad: quan passa el temps, l'app posa la pantalla negra i amb la brillantor al mínim, i deixa fer al bloqueig automàtic d'iOS (Configuració → Pantalla i brillantor), que la bloqueja després. El primer toc sobre la pantalla negra només l'encén i restaura la brillantor; no arriba a cap botó. L'opció «Apaga-la del tot» es pot desactivar; aleshores, en passar el temps, només es deixa fer a iOS.
- **Alarma (teclat des de 1.2.0):** quan una ordre necessita el PIN de l'alarma, el calaix mostra un teclat numèric de botons grans (1–9, 0, esborra l'últim dígit i esborra-ho tot) i uns punts amb els dígits escrits. No s'obre el teclat d'iOS.
- **Calaix lateral:** surt per la dreta. Cada dispositiu amb ordres d'encendre i apagar té un interruptor. La brillantor, la temperatura de color i el volum s'envien en deixar anar el control lliscant.
- **Orientació:** en horitzontal, el rellotge queda a l'esquerra i el contingut a la dreta. En vertical, el rellotge va a dalt i la llista a sota. Totes les pàgines excepte Estances i Resum ocupen tota la pantalla; en horitzontal, les targetes van en dues columnes.

L'app parla només amb el servidor de Glass Rooms (port `8099` per defecte), mai directament amb Home Assistant. El servidor aplica xarxes i hosts permesos, nova lectura abans de cada ordre, `verified_actions` i límits de peticions.

**Estat:** compilada i enllaçada contra l'SDK d'iOS 9.3 (armv7 i arm64), provada a l'ordinador i instal·lada a l'iPad mini 1 (jailbreak i AppSync Unified). La connexió amb el Home Assistant real la confirma l'usuari. Vegeu [què s'ha comprovat](#què-sha-comprovat).

## Configuració de les novetats de 1.2.0

Opcions de Glass Rooms (en YAML). Totes les entitats han de ser a `light_entity_ids` o `entity_ids`, i cada acció a `verified_actions` després de provar-la:

```yaml
entity_ids:
  - water_heater.termo
  - sensor.termo_energia          # sensors del mateix aparell, opcionals
  - fan.ventilador_menjador
  - remote.tele
  - remote.llum_sostre
  - sensor.esios_pvpc             # integració «Spain electricity hourly pricing (PVPC)»
  - weather.barcelona             # Met.no o AEMET; el nom de l'entitat és el que es mostra
fan_speeds:
  - fan.ventilador_menjador:6     # només si el ventilador no publica percentage_step
remote_buttons:
  - remote.tele:tele:power:Engega
  - remote.tele:tele:volume_up:Volum +
  - remote.llum_sostre:sostre:on:Encén
verified_actions:
  - light.sostre_menjador:brightness          # per a cada llum Hue
  - light.sostre_menjador:color_temp_kelvin
  - water_heater.termo:turn_on
  - water_heater.termo:turn_off
  - water_heater.termo:set_temperature
  - water_heater.termo:set_operation_mode
  - water_heater.termo:set_away_mode          # activa i desactiva el mode absència
  - fan.ventilador_menjador:turn_on
  - fan.ventilador_menjador:turn_off
  - fan.ventilador_menjador:set_percentage
  - remote.tele:send_command
  - remote.llum_sostre:send_command
```

- L'escalfador només mostra els controls que publica (`supported_features`: 1 temperatura objectiu, 2 modes, 4 mode absència, 8 encesa) i amb els límits `min_temp` i `max_temp`.
- Els comandaments no poden descobrir les ordres apreses: cal escriure-les a `remote_buttons` amb el dispositiu i l'ordre que vas fer servir en aprendre-les. Fins a 48 botons per comandament.
- El PVPC i el temps són només de lectura.

## Panell de seguretat (des de 1.1.10)

El botó de l'escut obre una pàgina a pantalla completa:

- **Alarma:** l'estat en gran i des de quan. Si està desarmada, hi ha els botons d'armar; si està armada, el de desarmar. Cada ordre passa pel calaix de confirmació i, si la política ho exigeix, demana el PIN de l'alarma.
- **Càmera:**
  - El servidor demana una captura a Home Assistant (`/api/camera`), reduïda a 1280 px d'amplada i amb 15 s d'espera (des de 1.1.12), i l'app la refresca cada 2,5 s, només mentre la pàgina és visible.
  - Si no arriba cap imatge, el motiu surt sobre el requadre (per exemple, l'estat HTTP que ha retornat Home Assistant).
  - Tocar la imatge l'amplia a pantalla completa. Si n'hi ha més d'una, uns botons permeten triar-la.
  - A sota hi ha el moviment i la detecció de persones, amb l'hora de l'últim canvi.
  - Les adreces internes i els tokens de la càmera mai arriben a l'app.
- **Portes i finestres:** a sota de l'alarma (des de 1.1.12), obertes en vermell, i des de quan.
- Des de 1.1.12 la pàgina ja no mostra la sirena ni qui és a casa, encara que siguin a `entity_ids`.
- **Bateries:** dels sensors, de la més baixa a la més alta, amb avís per sota del 20 %.

La pàgina mostra les entitats que hi ha a `entity_ids` i les classifica pel domini i per `device_class`. Les entitats `*_tamper` no hi surten. Exemple amb les entitats d'aquesta casa (opcions de Glass Rooms, en YAML):

```yaml
entity_ids:
  - alarm_control_panel.alarmo
  - camera.living_room_cam_pt2_mainstream
  - binary_sensor.cam_pt2_cell_motion_detection
  - binary_sensor.cam_pt2_person_detection
  - binary_sensor.sensor_porta_00
  - binary_sensor.living_room_sensor_porta_01
  - binary_sensor.sensor_finestra_despatx
  - binary_sensor.sensor_finestra_menjador
  - siren.sonoff_snzb_09p
  - switch.living_room_sirena_alarma_siren_on
  - binary_sensor.living_room_sirena_alarma_external_power
  - person.albert_azemar_i_rovira
  - person.xazemar
  - device_tracker.iphone_de_albert_2
  - sensor.sensor_porta_00_battery
  - sensor.living_room_sensor_porta_01_battery
  - sensor.sensor_finestra_despatx_battery
  - sensor.sensor_finestra_menjador_battery
  - sensor.sonoff_snzb_09p_battery
verified_actions:
  - alarm_control_panel.alarmo:alarm_arm_home
  - alarm_control_panel.alarmo:alarm_arm_away
  - alarm_control_panel.alarmo:alarm_disarm
  - siren.sonoff_snzb_09p:turn_off
  - switch.living_room_sirena_alarma_siren_on:turn_off
alarm_modes:
  - alarm_arm_home
  - alarm_arm_away
alarm_arm_code: none        # o required, segons Alarmo
alarm_disarm_code: required # o none, segons Alarmo
```

Conserva els llums i els sensors que ja tenies a `entity_ids`. Les ordres de l'alarma i de la sirena només s'activen després de provar-les a casa i afegir-les a `verified_actions`.

## Accés i seguretat

- **Credencial:** el PIN del panell (`panel_pin`) s'introdueix una sola vegada a Ajustos, queda al clauer de l'iPad i l'app l'envia com a `Authorization: Bearer` amb cada petició. No hi ha cookie ni sessió: per revocar l'accés, canvia `panel_pin`.
- **Certificat:** si iOS no reconeix el certificat HTTPS, l'app permet fixar-lo per empremta SHA-256.

## 1. Prepara el servidor

1. Actualitza Glass Rooms a **1.2.0** o posterior perquè coincideixi amb l'app. L'app s'identifica amb el PIN del panell (`panel_pin`).
2. `app_token` (de 1.1.4) continua sent opcional: si el configures, l'app també accepta aquell token llarg en lloc del PIN.
3. Comprova que `allowed_hosts` conté l'adreça exacta que escriuràs a l'app (per exemple `192.168.1.10:8099`) i que l'IP de l'iPad és dins d'`allowed_networks`.

L'app envia el PIN amb cada petició. Els intents erronis tenen un límit de 5 per minut i IP. Sobre HTTP, el PIN viatja sense xifrar dins la LAN: si pots, configura HTTPS.

## 2. Compila l'IPA (Mac sense Xcode)

Calen les Command Line Tools d'Apple (`xcode-select --install`), Python 3 i accés a GitHub per a la primera baixada.

```sh
ios/scripts/build.sh
```

La primera vegada, `ios/scripts/fetch-sdk.sh` baixa només `iPhoneOS9.3.sdk` (capçaleres i stubs `.tbd`, sense executables) del repositori comunitari [theos/sdks](https://github.com/theos/sdks), fixat a un commit concret, dins `ios/.sdk/` (ignorat pel git). Enllaçar contra aquest SDK garanteix que el binari no usa cap API posterior a iOS 9.3.

El resultat és `ios/build/GlassRooms.ipa`, amb signatura ad hoc. Per canviar l'identificador: `BUNDLE_ID=cat.exemple.glassrooms ios/scripts/build.sh`. La versió es llegeix de `glass_rooms/config.yaml`.

## 3. Instal·la-la a l'iPad

Apple només permet instal·lar apps signades amb un certificat vàlid per al dispositiu. Opcions habituals:

- **Eina de sideload amb un Apple ID** (per exemple Sideloadly): torna a signar l'IPA per al teu iPad. Comprova abans que la versió de l'eina encara admet iOS 9. Amb un Apple ID gratuït la signatura **caduca al cap de 7 dies** i cal reinstal·lar; amb un compte de desenvolupador de pagament, un any.
- **iPad amb jailbreak i AppSync Unified** (el camí que ha funcionat a l'iPad mini 1 amb iOS 9.3.5, on la verificació en línia d'Apple falla): instal·la AppSync Unified des de Cydia (`https://cydia.akemi.ai/`) i, amb l'iPad connectat per USB, `ideviceinstaller install ios/build/GlassRooms.ipa` (`brew install ideviceinstaller`). Després de reiniciar l'iPad cal reactivar el jailbreak abans d'obrir l'app.

Les preferències i el PIN es conserven mentre no esborris l'app. Per actualitzar-la, torna a instal·lar l'IPA nova de la mateixa manera.

## 4. Primera obertura

L'app obre Ajustos automàticament:

1. **Adreça del panell**: `http://192.168.1.10:8099` o `https://nom-local:8099` (sense ruta).
2. **PIN del panell**: el mateix PIN de 6 a 8 dígits que `panel_pin`.
3. Toca **Desa i connecta**. La portada mostra «Actualitzat a les …» quan el servidor respon.

Si diu «PIN o token de l'app incorrecte», revisa `panel_pin`. Si diu que el servidor no accepta el PIN, actualitza Glass Rooms a 1.1.5 o posterior.

### HTTPS amb certificat propi

Si iOS 9 confia en el certificat (cadena vàlida i nom correcte), no cal fer res. Si no hi confia, Ajustos mostra l'**empremta SHA-256** del certificat rebut. Compara-la amb la del certificat de `/ssl` (`openssl x509 -in CERT.pem -noout -fingerprint -sha256`) i, només si coincideix, toca **Confia en aquest certificat**. L'app acceptarà exactament aquell certificat; si el renoves, caldrà tornar-hi a confiar. Canviar l'adreça esborra la fixació.

## Codi i proves

| Fitxer | Paper |
|---|---|
| `ios/GlassRooms/GRLogic.m` | Regles de presentació (estats, recomptes, clima, temps, velocitats de ventilador, nivells del PVPC) |
| `ios/GlassRooms/GRPanelModel.m` | Estat, sondeig, actualitzacions en directe, ordres i historial |
| `ios/GlassRooms/GRAPIClient.m` | `NSURLSession`, credencial Bearer, errors en català i fixació de certificat |
| `ios/GlassRooms/GRMainViewController.m` | Tota la interfície, amb disposició manual per a 1024×768 i 768×1024 |
| `ios/GlassRooms/GRTheme.m` | Estils «Nit càlida» i «Jarvis», cadascun de dia i de nit, i les tipografies |
| `ios/GlassRooms/GRScreenLock.m` | Apagat de la pantalla després dels segons triats |
| `ios/GlassRooms/Resources/` | Icones (de `ios/scripts/icons.json`), icona de l'app i pantalles d'inici generades per `ios/scripts/render-assets.py` |
| `ios/scripts/test.sh` | Proves de la lògica i del client contra el servidor real amb un Home Assistant simulat |
| `ios/scripts/preview-mac.sh` | Només desenvolupament: la mateixa interfície com a app Mac Catalyst per veure-la a l'ordinador |

`python3 -m unittest discover -s tests` executa també `ios/scripts/test.sh` quan hi ha `clang` de macOS.

## Què s'ha comprovat

- **1.2.0:** compilació amb `-Werror` contra `iPhoneOS9.3.sdk`; proves de la lògica (velocitats de ventilador, nivells i preus del PVPC, línia del temps) i del client contra el servidor nou, només API; captures de la compilació Mac Catalyst a 1024×768 en els dos estils, de dia i de nit, contra el servidor real amb un Home Assistant simulat (llums Hue, ventiladors de 6 velocitats, escalfador, dos comandaments, PVPC, temps de Barcelona i alarma): estances, clima, aparells, preu de la llum, ajustos, calaix d'estança i teclat de l'alarma. No s'ha comprovat a l'iPad l'apagat de la pantalla (brillantor i primer toc), la tipografia Avenir Next Condensed d'iOS 9 ni el rendiment de les ombres de l'estil Jarvis a l'A5.
- Compilació amb `-Werror` i enllaç contra `iPhoneOS9.3.sdk` per a armv7 i arm64; el binari porta `LC_VERSION_MIN_IPHONEOS 9.0` i només enllaça frameworks del sistema.
- Proves del client nadiu contra `glass_rooms/server.py` amb un Home Assistant simulat: PIN i token acceptats, credencial incorrecta rebutjada, estat, ordre de llums per lots, brillantor, error de validació del servidor, historial i informe sense el token.
- Captures del disseny 1.1.6 en una compilació Mac Catalyst a 1024×768 i 768×1024, de dia i de nit, contra el servidor real amb un Home Assistant simulat (llums, sensors i alarma). Inclouen estances, resum, clima, calaix d'estança, llums i ajustos, i un interruptor d'estança que arriba al servidor i torna l'estança encesa.
- Instal·lació a l'iPad mini 1 amb iOS 9.3.5 (jailbreak i AppSync Unified) amb `ideviceinstaller`.

**No comprovat:** l'aspecte exacte a iOS 9 (al Mac Catalyst, els interruptors no prenen el color del botó), rendiment de l'A5, TLS d'iOS 9 amb el teu certificat, clauer amb la signatura de l'eina de sideload, rotació i teclat al dispositiu. El Mac Catalyst usa UIKit modern i no reprodueix iOS 9.

## Historial

**1.1.13:** a l'app per a iPad, la pàgina Estances té una tira d'**escenes** sota «Encén tot» i «Apaga tot». Un emissor d'infrarojos o de ràdio (`remote.*`, per exemple de LocalTuya) pot tenir botons propis amb la nova opció `remote_buttons`, i surten a la seva estança. A Ajustos es tria el temps sense tocar la pantalla abans que l'iPad s'apagui. Les escenes que encara no s'han activat mai (estat `unknown`) ja es poden activar.

**1.1.12:** a la pàgina de **Seguretat** de l'app per a iPad, la llista de portes i finestres és a sota de l'alarma i la càmera al costat. Ja no hi surten la sirena ni qui és a casa. El servidor demana a Home Assistant la imatge de la càmera reduïda a 1280 px d'amplada i l'espera fins a 15 s; si no arriba, l'app mostra el motiu sobre la imatge.

**1.1.11:** a l'app per a iPad, la portada mostra la corba de la temperatura i, a sota, la de la humitat. L'ordre de les pàgines és Estances, Clima, Seguretat i Resum, i es pot passar d'una a l'altra lliscant el dit cap a l'esquerra o cap a la dreta.

**1.1.10:** l'app per a iPad té un panell de **Seguretat** a pantalla completa. Hi surten:

- l'alarma, amb els botons d'armar i desarmar;
- la càmera, amb una imatge nova cada 2,5 s i la detecció de moviment i de persones;
- les portes i les finestres;
- la sirena, que només es pot aturar;
- qui és a casa;
- les bateries dels sensors.

El servidor admet ara els dominis `camera`, `siren`, `person` i `device_tracker` i té la ruta `/api/camera`. La configuració és a [APP_IOS.md](#panell-de-seguretat-des-de-1110).

**1.1.9:**

- **Historial de clima:** cada sèrie es tanca amb la lectura actual del sensor. Així, un sensor que no ha canviat en tot el període (sovint la humitat) dibuixa una línia en lloc de quedar buit, tant al panell web com a l'app.
- **Llums que no responen:** si un llum no arriba a l'estat demanat 10 segons després d'una ordre, l'app el bloqueja. El bloqueig dura fins que Home Assistant n'informa un estat nou o fins que passen 2 minuts.
- **Sense actualitzacions en directe:** l'app torna a llegir l'estat cada 8 segons en lloc de cada 30.
- **Tema:** l'app ja no té el botó del sol o la lluna; el tema es tria a Ajustos.
