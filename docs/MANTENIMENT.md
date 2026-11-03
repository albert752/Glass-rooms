# Manteniment, errors i retirada

## Errors habituals

| Símptoma | Comprovació i solució |
|---|---|
| L'app no apareix a la botiga | Una sola carpeta `glass_rooms` dins de `local_apps` o `addons`, amb `config.yaml` al primer nivell; comprova actualitzacions i refresca la botiga. |
| La imatge no es construeix | Revisa arquitectura amd64/aarch64, xarxa sortint cap al registre, espai lliure i el registre de Supervisor. No s'ha provat aquesta construcció a la teva instància. |
| No arrenca | Completa `panel_pin` privat de 6–8 dígits, hosts i xarxes; revisa parelles d'accions, assignacions, polítiques Alarmo i fitxers TLS. Un error d'opcions es mostra sense el contingut secret. |
| Host no autoritzat | L'adreça i el port de la URL han de coincidir amb `allowed_hosts`. La URL de Core `:8080` no és la del panell `:8099`. |
| Xarxa no autoritzada | Revisa la màscara real i la IP del client; no afegeixis una xarxa pública o totes les adreces. El servidor ignora `X-Forwarded-For`. |
| No hi ha connexió amb Core | Comprova Core i Supervisor, `homeassistant_api: true`, reinicia l'app. No afegeixis un token al navegador. |
| Login o ordre denegats | Obre el panell directament, sense iframe/proxy; comprova cookie, origen i sessió. Torna a entrar després de reiniciar o canviar de IP. |
| Massa intents | Espera que acabi el límit temporal; no automatitzis reintents de login. |
| Control absent o bloquejat | Revisa entitat disponible, atributs actuals, servei i camps, `verified_actions`; per Alarmo també modes i política de codi. No forcis la UI. |
| Ordre enviada però sense canvi | El retorn del servei no prova l'èxit físic. Comprova la integració i el dispositiu a Core abans de repetir l'ordre. |
| Entitat absent / unknown / unavailable | Compara l'ID exacte i l'estat a Core; una baixa o canvi de nom no és un estat apagat. |
| Safari no carrega | Revisa URL, xarxa, confiança del certificat, TLS i JavaScript habilitat. La validació ES5 no resol problemes de TLS. |
| Navegació lenta | Desactiva vidre suau, tanca altres pestanyes i prova una sessió llarga. Registra la limitació real a VALIDACIO.md. |
| Preferències no persisteixen | `localStorage` pot estar restringit; el panell funciona igual amb aparença predeterminada. |

## Actualització

1. Desactiva temporalment les accions posant `verified_actions: []` i reinicia l'app. Desa privadament les opcions anteriors; no les afegeixis al codi.
2. Fes una còpia de seguretat completa i una còpia separada del directori font anterior. Si hi ha TLS, conserva'n les claus privadament. Anota la versió anterior.
3. Comprova el codi nou a l'ordinador amb `python3 -m unittest discover -s tests -v`, `node scripts/check-es5.cjs` i el servidor `--preview`. Node només és una eina de comprovació, no un requisit del panell.
4. Atura Glass Rooms. Substitueix els fitxers de la seva carpeta local pel nou paquet verificat. Conserva la mateixa `slug`; incrementa la versió de `config.yaml` si publiques una revisió pròpia.
5. Actualitza la botiga local i aplica l'actualització. Si treballes amb la mateixa versió i la interfície ho ofereix, utilitza **Reconstrueix**; si no, publica una versió nova. No pressuposis que reiniciar reconstrueix la imatge.
6. Inicia, comprova lectura, torna a validar les accions afectades i habilita-les una a una. Recarrega Safari: no hi ha service worker ni cache d'aplicació que calgui esborrar.

Els tags de la imatge base poden rebre actualitzacions. Per a una instal·lació reproduïble, conserva la còpia de seguretat de l'app abans de reconstruir i registra el digest de la imatge utilitzada. Aquesta entrega no afirma haver construït el contenidor a Home Assistant OS.

## Reversió

Atura l'app si hi ha un error. Restaura la carpeta font anterior, reconstrueix la imatge anterior i recupera les opcions compatibles des de la còpia privada. Si no és possible reconstruir, utilitza la restauració de l'app des de la còpia de seguretat de Home Assistant. Comença amb accions bloquejades i confirma lectura abans de reactivar-les.

Restaurar el codi no desfà ordres ja executades als dispositius. Si una escena ha canviat llums o un mode ha canviat un aparell, revisa'n l'estat i corregeix-lo des de Home Assistant. No enviïs automàticament ordres inverses a l'alarma o l'escalfador.

## Retirada

1. Posa `verified_actions: []`, reinicia i tanca la sessió dels navegadors.
2. Atura Glass Rooms, desactiva l'inici automàtic i desinstal·la l'app des de Home Assistant. Això atura el port i elimina les sessions en memòria.
3. Retira la carpeta font local quan hagis conservat allò necessari per a una reversió. Revisa les còpies que continguin opcions privades i elimina-les segons la teva política de còpies.
4. Elimina del router o tallafoc qualsevol regla específica que haguessis afegit. No hi hauria d'haver ports WAN. Si havies instal·lat un certificat o clau exclusius d'aquest panell, retira'ls només després de comprovar que no els usa cap altre servei.
5. A l'iPad, elimina l'accés directe i les dades d'aquest origen. Si el navegador havia desat la contrasenya antiga del panell, elimina aquesta entrada.

No cal eliminar cap entitat, grup, escena o automatització de Home Assistant: Glass Rooms no en crea ni en reconfigura. No deixa tokens de llarga durada de l'usuari per revocar.

## Servidor de proves d'aquest PC

La previsualització escolta només a `127.0.0.1:8099`. Atura-la amb **Ctrl+C** al terminal on s'executa. Per tornar-la a obrir, executa `python3 glass_rooms/server.py --preview --port 8099` des del projecte. No utilitzis `--preview` com a desplegament real: no llegeix Home Assistant i rebutja totes les ordres.
