# App nativa per a iPad (iOS 9)

`ios/` conté **Glass Rooms per a iPad**, una aplicació UIKit escrita en Objective-C per a l'iPad mini 1 amb iOS 9.3.5. No és un navegador incrustat: rail, targetes d'estança, gràfiques, calaixos, controls i preferències són vistes natives. Les il·lustracions i les icones són les mateixes del panell web, convertides a PNG.

L'app parla només amb el servidor de Glass Rooms (port `8099` per defecte), mai directament amb Home Assistant. El servidor aplica les mateixes regles que amb el navegador: xarxes i hosts permesos, nova lectura abans de cada ordre, `verified_actions` i límits de peticions.

**Estat:** compilada i enllaçada contra l'SDK d'iOS 9.3 (armv7 i arm64) i provada a l'ordinador. **Encara no s'ha instal·lat ni provat a l'iPad real.** Vegeu [què s'ha comprovat](#què-sha-comprovat).

## Què fa igual que el panell web

- Portada amb les vuit estances, llums encesos o apagats, recompte online/offline i bombeta per commutar els llums de cada estança.
- «Encén» i «Apaga» per a tots els llums amb l'ordre verificada, en una sola petició `/api/lights`.
- Resum per categories, «Veure tots els dispositius», calaixos de Llums, Alarma i Ambient.
- Clima amb lectura actual i historial de 6 h, 24 h, 7 dies i 1 mes; el control lliscant mostra l'hora i el valor de cada punt.
- Controls de botó, interval (brillantor, temperatura de color, velocitat, volum) i mode, amb els motius de bloqueig del servidor.
- Alarma amb confirmació i PIN d'alarma quan la política ho exigeix. El PIN s'esborra del camp abans d'enviar-lo.
- Temes de dia i nit (automàtic de 7 a 20 h), botó del sol o la lluna al costat del rellotge i opció de contrast suau.
- Actualitzacions en directe (`/api/updates`), lectura de seguretat cada 30 segons i relectures als 2, 5, 10, 20 i 30 segons després d'una ordre de llum.
- Informe de verificació (`/api/audit`).

## Diferències deliberades

| Web | App |
|---|---|
| Teclat numèric amb `panel_pin` i sessió de 12 hores | **Sense bloqueig amb codi.** L'app s'identifica amb un token privat (`app_token`) desat al clauer de l'iPad. |
| Cookie, CSRF i comprovació d'origen | Capçalera `Authorization: Bearer`; no hi ha credencial ambiental que un altre web pugui reutilitzar. |
| `<select>` per als modes | Full d'opcions natiu. |
| Tancar la sessió | No n'hi ha: per revocar l'accés, canvia o buida `app_token`. |
| — | Opció «Mantén la pantalla encesa» per a un iPad fix a la paret. |
| — | Fixació del certificat HTTPS per empremta SHA-256 si iOS no el reconeix. |

## 1. Prepara el servidor

1. Actualitza Glass Rooms a **1.1.4** o posterior.
2. Genera un token aleatori a l'ordinador:

   ```sh
   python3 -c "import secrets; print(secrets.token_urlsafe(32))"
   ```

3. A les opcions de Glass Rooms, enganxa'l a `app_token` (32 a 128 caràcters `A-Z a-z 0-9 _ -`), desa i reinicia. Buit vol dir que l'app nativa queda desactivada; el panell web continua igual.
4. Comprova que `allowed_hosts` conté l'adreça exacta que escriuràs a l'app (per exemple `192.168.1.10:8099`) i que l'IP de l'iPad és dins d'`allowed_networks`.

Qui tingui aquest token i accés a la xarxa permesa pot fer el mateix que el panell desbloquejat. Tracta'l com una contrasenya: no el posis al repositori ni en captures. Sobre HTTP, el token viatja sense xifrar dins la LAN, igual que el PIN del web.

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
- **iPad amb jailbreak i AppSync Unified**: es pot instal·lar l'IPA ad hoc directament. Decideix-ho tu; aquest projecte no ho requereix ni ho ha provat.

Les preferències i el token es conserven mentre no esborris l'app.

## 4. Primera obertura

L'app obre Ajustos automàticament:

1. **Adreça del panell**: `http://192.168.1.10:8099` o `https://nom-local:8099` (sense ruta).
2. **Token de l'app**: el valor d'`app_token`.
3. Toca **Desa i connecta**. La portada mostra «Actualitzat a les …» quan el servidor respon.

Si el missatge diu que el servidor no accepta el token, revisa `app_token`, que el servidor sigui 1.1.4 o posterior i que no hi hagi espais.

### HTTPS amb certificat propi

Si iOS 9 confia en el certificat (cadena vàlida i nom correcte), no cal fer res. Si no hi confia, Ajustos mostra l'**empremta SHA-256** del certificat rebut. Compara-la amb la del certificat de `/ssl` (`openssl x509 -in CERT.pem -noout -fingerprint -sha256`) i, només si coincideix, toca **Confia en aquest certificat**. L'app acceptarà exactament aquell certificat; si el renoves, caldrà tornar-hi a confiar. Canviar l'adreça esborra la fixació.

## Codi i proves

| Fitxer | Paper |
|---|---|
| `ios/GlassRooms/GRLogic.m` | Regles de presentació portades d'`app.js` (estats, recomptes, clima) |
| `ios/GlassRooms/GRPanelModel.m` | Estat, sondeig, actualitzacions en directe, ordres i historial |
| `ios/GlassRooms/GRAPIClient.m` | `NSURLSession`, token, errors en català i fixació de certificat |
| `ios/GlassRooms/GRMainViewController.m` | Tota la interfície, amb disposició manual per a 1024×768 i 768×1024 |
| `ios/GlassRooms/Resources/` | PNG generats per `ios/scripts/render-assets.py` a partir dels SVG del web |
| `ios/scripts/test.sh` | Proves de la lògica i del client contra el servidor real amb un Home Assistant simulat |
| `ios/scripts/preview-mac.sh` | Només desenvolupament: la mateixa interfície com a app Mac Catalyst per veure-la a l'ordinador |

`python3 -m unittest discover -s tests` executa també `ios/scripts/test.sh` quan hi ha `clang` de macOS.

## Què s'ha comprovat

- Compilació amb `-Werror` i enllaç contra `iPhoneOS9.3.sdk` per a armv7 i arm64; el binari porta `LC_VERSION_MIN_IPHONEOS 9.0` i només enllaça frameworks del sistema.
- Proves del client nadiu contra `glass_rooms/server.py` amb un Home Assistant simulat: token incorrecte rebutjat, estat, ordre de llums per lots, brillantor, error de validació del servidor, historial i informe sense el token.
- Captures de la interfície en una compilació Mac Catalyst a 1024×768 i 768×1024, de dia i de nit, i un toc a la bombeta d'una estança que arriba al servidor i torna l'estança encesa.

**No comprovat:** instal·lació i execució a l'iPad mini 1, rendiment de l'A5, TLS d'iOS 9 amb el teu certificat, clauer amb la signatura de l'eina de sideload, rotació i teclat al dispositiu. El Mac Catalyst usa UIKit modern i no reprodueix iOS 9.
