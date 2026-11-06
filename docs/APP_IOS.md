# App nativa per a iPad (iOS 9)

`ios/` conté **Glass Rooms per a iPad**, una aplicació UIKit escrita en Objective-C per a l'iPad mini 1 amb iOS 9.3.5. No és un navegador incrustat: rellotge, llistes, gràfiques, calaix lateral, controls i preferències són vistes natives. Les icones són les del panell web, convertides a PNG.

## Disseny «Nit càlida» (1.1.6)

Està pensat per a un iPad fix a la paret i llegit a distància.

- **Columna del rellotge:**
  - l'hora en gran i la data;
  - la temperatura i la humitat interiors, amb la mitjana dels sensors disponibles;
  - l'estat de l'alarma o, si no n'hi ha cap, els llums encesos;
  - la corba de temperatura i, a sota, la d'humitat (des de 1.1.11), del primer sensor de cada tipus amb historial, amb el període triat a Clima (24 h per defecte).
- **Navegació inferior:** Estances, Clima, Seguretat, Resum i Ajustos. Des de 1.1.11, lliscar el dit cap a l'esquerra o cap a la dreta passa a la pàgina següent o a l'anterior, en aquest ordre. No es llisca de pàgina si el dit comença sobre un control lliscant, un interruptor, la gràfica de clima o una tira de fitxes, ni amb un calaix obert. El tema (automàtic, dia o nit) només es tria a Ajustos (des de 1.1.9).
- **Estances:** una fila per estança, amb un punt ambre si té llums encesos, la temperatura i un interruptor de llums. Tocar el nom obre el calaix de l'estança. Sota la llista hi ha «Encén tot» i «Apaga tot» i, des de 1.1.13, una tira amb les escenes (`scene.*` d'`entity_ids` amb `:turn_on` a `verified_actions`).
- **Avisos:** les ordres de llums no mostren cap missatge en enviar-se ni quan funcionen; l'interruptor i l'estat actualitzat ja ho indiquen. Només apareix un avís si l'ordre falla o si s'ometen llums (des de 1.1.7).
- **Clima (des de 1.1.8):** ocupa tota la pantalla i la columna del rellotge s'amaga. A dalt hi ha el període (6 h, 24 h, 7 dies, 1 mes) i una fitxa per sensor amb l'estança i la lectura actual. Sota hi ha el valor del punt triat en gran, amb el mínim, el màxim i la mitjana del període. La gràfica té eixos de valor i d'hora, i tocar-la o arrossegar-hi el dit mostra cada registre.
- **Llums que no responen (des de 1.1.9):**
  - Un llum que Home Assistant marca com a no disponible queda bloquejat a la següent actualització en directe, normalment en un o dos segons.
  - Home Assistant pot trigar minuts a adonar-se que un llum s'ha desconnectat, i aquest retard depèn de la integració. Mentrestant, si el llum no arriba a l'estat demanat 10 segons després d'una ordre, l'app el marca com a «No respon a les ordres» i n'atura els controls.
  - El bloqueig s'aixeca quan Home Assistant informa un estat nou, o al cap de 2 minuts.
  - Si es perden les actualitzacions en directe, l'estat es torna a llegir cada 8 segons.
- **Bloqueig de la pantalla (des de 1.1.13):** a Ajustos es tria «Com iOS», 5, 15 o 30 minuts, 1 hora o «Mai». Una app no pot bloquejar l'iPad: manté la pantalla encesa mentre s'ha tocat dins del temps triat i després deixa fer al bloqueig automàtic d'iOS, que s'hi suma. Posa'l a 2 minuts a Configuració → Pantalla i brillantor. Qui tenia activat «Mantén la pantalla encesa» passa a «Mai».
- **Emissors d'infrarojos i ràdio (des de 1.1.13):** un `remote.*` assignat a una estança mostra al calaix un botó per a cada línia de `remote_buttons` (vegeu [la instal·lació](INSTALLACIO.md)).
- **Calaix lateral:** surt per la dreta. Cada dispositiu amb ordres d'encendre i apagar té un interruptor. La brillantor, la velocitat i el volum s'envien en deixar anar el control lliscant, sense botó «Aplica».
- **Temes:** de nit, negre pur amb text ambre; de dia, paper càlid amb ambre torrat. El mode automàtic canvia a les 7 i a les 20 h.
- **Orientació:** en horitzontal, el rellotge queda a l'esquerra i el contingut a la dreta. En vertical, el rellotge va a dalt i la llista a sota.

Les il·lustracions de les estances i l'opció «contrast suau» de les versions anteriors s'han retirat de l'app. El panell web les conserva.

L'app parla només amb el servidor de Glass Rooms (port `8099` per defecte), mai directament amb Home Assistant. El servidor aplica les mateixes regles que amb el navegador: xarxes i hosts permesos, nova lectura abans de cada ordre, `verified_actions` i límits de peticions.

**Estat:** compilada i enllaçada contra l'SDK d'iOS 9.3 (armv7 i arm64), provada a l'ordinador i instal·lada a l'iPad mini 1 (jailbreak i AppSync Unified). La connexió amb el Home Assistant real la confirma l'usuari. Vegeu [què s'ha comprovat](#què-sha-comprovat).

## Què fa igual que el panell web

- Les vuit estances, amb els llums encesos o apagats, els llums sense connexió i la commutació dels llums de cada estança.
- «Encén» i «Apaga» per a tots els llums amb l'ordre verificada, en una sola petició `/api/lights`.
- Resum per categories, «Veure tots els dispositius», calaixos de Llums, Alarma i Ambient.
- Clima amb lectura actual i historial de 6 h, 24 h, 7 dies i 1 mes; tocar la gràfica mostra l'hora i el valor de cada punt.
- Controls de botó, interval (brillantor, temperatura de color, velocitat, volum) i mode, amb els motius de bloqueig del servidor.
- Alarma amb confirmació i PIN d'alarma quan la política ho exigeix. El PIN s'esborra del camp abans d'enviar-lo.
- Temes de dia i nit (automàtic de 7 a 20 h), triats a Ajustos.
- Actualitzacions en directe (`/api/updates`), lectura de seguretat cada 30 segons i relectures als 2, 5, 10, 20 i 30 segons després d'una ordre de llum. L'historial de clima es demana com a màxim cada 2 minuts, perquè la columna del rellotge en mostra la tendència a totes les vistes.
- Informe de verificació (`/api/audit`).

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

## Diferències deliberades

| Web | App |
|---|---|
| Teclat numèric amb `panel_pin` i sessió de 12 hores | **Sense bloqueig amb codi.** El PIN del panell (`panel_pin`) s'introdueix una sola vegada a Ajustos, queda al clauer de l'iPad i l'app l'envia com a credencial. |
| Cookie, CSRF i comprovació d'origen | Capçalera `Authorization: Bearer`; no hi ha credencial ambiental que un altre web pugui reutilitzar. |
| Seguretat al calaix de categoria | Pàgina completa amb alarma, càmera, obertures, sirena, persones i bateries. |
| `<select>` per als modes | Full d'opcions natiu. |
| Botó «Aplica» als controls lliscants | El valor s'envia en deixar anar el control. |
| Targetes il·lustrades | Llista d'estances amb interruptor; sense il·lustracions. |
| Tancar la sessió | No n'hi ha: per revocar l'accés, canvia `panel_pin`. |
| — | Temps de bloqueig de la pantalla (des de 1.1.13; abans, «Mantén la pantalla encesa»). |
| — | Fixació del certificat HTTPS per empremta SHA-256 si iOS no el reconeix. |

## 1. Prepara el servidor

1. Actualitza Glass Rooms a **1.1.5** o posterior. Des d'aquesta versió l'app accepta el mateix PIN que el panell web (`panel_pin`); no cal cap opció nova.
2. `app_token` (de 1.1.4) continua sent opcional: si el configures, l'app també accepta aquell token llarg en lloc del PIN.
3. Comprova que `allowed_hosts` conté l'adreça exacta que escriuràs a l'app (per exemple `192.168.1.10:8099`) i que l'IP de l'iPad és dins d'`allowed_networks`.

L'app envia el PIN amb cada petició. Els intents erronis comparteixen el límit del teclat web (5 per minut i IP). Sobre HTTP, el PIN viatja sense xifrar dins la LAN, igual que al panell web: si pots, configura HTTPS.

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

Les preferències i el PIN es conserven mentre no esborris l'app.

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
| `ios/GlassRooms/GRLogic.m` | Regles de presentació portades d'`app.js` (estats, recomptes, clima) |
| `ios/GlassRooms/GRPanelModel.m` | Estat, sondeig, actualitzacions en directe, ordres i historial |
| `ios/GlassRooms/GRAPIClient.m` | `NSURLSession`, credencial Bearer, errors en català i fixació de certificat |
| `ios/GlassRooms/GRMainViewController.m` | Tota la interfície, amb disposició manual per a 1024×768 i 768×1024 |
| `ios/GlassRooms/GRTheme.m` | Paletes «Nit càlida» de dia i de nit |
| `ios/GlassRooms/Resources/` | Icones, icona de l'app i pantalles d'inici generades per `ios/scripts/render-assets.py` |
| `ios/scripts/test.sh` | Proves de la lògica i del client contra el servidor real amb un Home Assistant simulat |
| `ios/scripts/preview-mac.sh` | Només desenvolupament: la mateixa interfície com a app Mac Catalyst per veure-la a l'ordinador |

`python3 -m unittest discover -s tests` executa també `ios/scripts/test.sh` quan hi ha `clang` de macOS.

## Què s'ha comprovat

- Compilació amb `-Werror` i enllaç contra `iPhoneOS9.3.sdk` per a armv7 i arm64; el binari porta `LC_VERSION_MIN_IPHONEOS 9.0` i només enllaça frameworks del sistema.
- Proves del client nadiu contra `glass_rooms/server.py` amb un Home Assistant simulat: PIN i token acceptats, credencial incorrecta rebutjada, estat, ordre de llums per lots, brillantor, error de validació del servidor, historial i informe sense el token.
- Captures del disseny 1.1.6 en una compilació Mac Catalyst a 1024×768 i 768×1024, de dia i de nit, contra el servidor real amb un Home Assistant simulat (llums, sensors i alarma). Inclouen estances, resum, clima, calaix d'estança, llums i ajustos, i un interruptor d'estança que arriba al servidor i torna l'estança encesa.
- Instal·lació a l'iPad mini 1 amb iOS 9.3.5 (jailbreak i AppSync Unified) amb `ideviceinstaller`.

**No comprovat:** l'aspecte exacte a iOS 9 (al Mac Catalyst, els interruptors no prenen el color del botó), rendiment de l'A5, TLS d'iOS 9 amb el teu certificat, clauer amb la signatura de l'eina de sideload, rotació i teclat al dispositiu. El Mac Catalyst usa UIKit modern i no reprodueix iOS 9.
