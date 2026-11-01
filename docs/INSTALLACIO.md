# Instal·lació a Home Assistant OS

Fes aquests passos quan tornis a la xarxa de casa. No cal exposar Home Assistant ni el panell a Internet. Utilitza la teva adreça privada de Home Assistant, representada aquí per `ADREÇA_HA`. No substitueixis el port de Home Assistant pel del panell.

## 1. Anota la instal·lació i guarda una còpia

Des d'un ordinador actual, obre la URL de Home Assistant i inicia sessió com a administrador. A **Configuració → Sistema → Reparacions → menú → Informació del sistema**, anota la versió exacta de Core, Supervisor i OS i l'arquitectura de l'amfitrió. «Última versió» no identifica aquestes quatre dades. Aquesta aplicació declara suport de servidor per a `aarch64` i `amd64`; l'arquitectura de l'iPad no intervé en la construcció del servidor.

A **Configuració → Sistema → Còpies de seguretat**, crea una còpia manual abans d'instal·lar. Inclou la configuració de Home Assistant i les aplicacions que utilitzes. Descarrega la còpia i desa el kit d'emergència de xifrat fora del dispositiu de Home Assistant, en una ubicació privada. Comprova que la còpia ha acabat sense errors. Les còpies poden contenir credencials; no les posis dins d'aquest projecte ni en una carpeta pública. [Guia oficial de còpies de seguretat](https://www.home-assistant.io/common-tasks/general/backups/).

Conserva també una còpia de la carpeta font `glass_rooms` al teu ordinador. No pressuposis que una còpia de l'aplicació inclou el seu directori de desenvolupament local.

## 2. Copia el projecte al directori correcte

La documentació actual anomena els complements **Apps / Aplicacions** i el directori local **`local_apps`**. En instal·lacions o eines anteriors trobaràs **Add-ons / Complements** i **`addons`**. Samba exposa els dos noms per compatibilitat: utilitza un únic directori, no dues còpies de Glass Rooms. [Accés als fitxers de Home Assistant OS](https://www.home-assistant.io/common-tasks/os/).

### Opció A: Samba des del Mac

1. A **Configuració → Aplicacions → Instal·la una aplicació**, instal·la **Samba share** del repositori oficial si encara no el tens.
2. Configura-hi les credencials privadament i limita'n l'accés a la LAN. Inicia Samba.
3. A Finder, prem **Cmd+K**, introdueix `smb://ADREÇA_HA` i autentica't.
4. Obre el recurs compartit **local_apps**; si només hi apareix **addons**, utilitza aquest nom.
5. Copia-hi la carpeta **`glass_rooms`** del projecte. No copiïs la carpeta pare sencera.

### Opció B: Terminal & SSH

Utilitza l'aplicació oficial **Terminal & SSH** si ja hi tens accés. El terminal web no requereix obrir SSH a Internet. Per transferir des d'un client SSH/SFTP, configura primer la teva clau pública i el port local segons la pestanya Documentació d'aquesta aplicació. Navega a `/local_apps`; si la versió exposa `/addons`, utilitza aquest directori. Copia-hi `glass_rooms` amb el teu client de fitxers. No cal accés de depuració a l'OS amfitrió ni desactivar el mode de protecció. [Procediment oficial de fitxers i SSH](https://www.home-assistant.io/common-tasks/os/).

El resultat ha de tenir aquesta forma:

```text
/local_apps/glass_rooms/
    config.yaml
    Dockerfile
    server.py
    catalog.py
    www/
        index.html
        app.js
        style.css
        assets/
```

Amb el nom antic, la mateixa estructura és `/addons/glass_rooms/`. El codi no necessita ser a `/config/www`: els recursos de `/local/` de Home Assistant són accessibles sense autenticació i no són un lloc per a secrets. [Advertiment oficial sobre `/local/`](https://www.home-assistant.io/integrations/http/#hosting-files).

## 3. Instal·la l'aplicació local

A **Configuració → Aplicacions → Instal·la una aplicació**, obre el menú i selecciona **Comprova si hi ha actualitzacions**. Refresca la pàgina i busca **Glass Rooms** a **Aplicacions locals**. Prem **Instal·la**. Supervisor construirà la imatge; la primera construcció necessita accés sortint al registre d'imatges. L'ús quotidià del panell és local. Si no apareix, comprova `config.yaml` i el registre de Supervisor. [Instal·lació oficial d'una aplicació local](https://contributors.home-assistant.io/apps/first-app/).

No l'iniciïs encara. Primer configura el transport i l'accés.

## 4. Tria el transport abans d'introduir secrets

| Opció | Límit concret | Pas següent |
|---|---|---|
| HTTPS directe al panell, recomanat | Cal que iOS 9 accepti el certificat, el nom i la cadena de confiança i pugui negociar TLS amb aquest servidor. Encara no s'ha provat. | Instal·la un certificat adequat i prova l'obertura a l'iPad abans d'introduir contrasenyes o PINs. |
| HTTP directe només a casa | El trànsit no està xifrat: la contrasenya del panell, la sessió i qualsevol PIN poden ser interceptats dins de la xarxa. La llista de xarxes no xifra res. | Només continua si acceptes explícitament aquest límit i controles la xarxa. Mantén les accions d'alarma bloquejades mentre no hagis decidit com protegir-ne el PIN. |
| Si l'iPad no accepta HTTPS | El codi web no pot solucionar una incompatibilitat de TLS o de confiança del sistema operatiu. | Revisa la cadena del certificat i prova un nom local correcte; si segueix fallant, tria conscientment HTTP local amb les limitacions anteriors o un dispositiu més recent. |

La URL de Home Assistant facilitada també usa HTTP. La pàgina d'administració on introdueixes `panel_password` transmetrà aquesta dada segons el seu propi transport. Configura-la des d'un accés d'administració segur; si només disposes d'aquest HTTP, la decisió sobre el risc també s'aplica a aquest pas.

Per HTTPS directe, posa el certificat i la clau privada a la carpeta compartida **`ssl`** de Home Assistant, amb accés restringit. L'aplicació els llegeix a `/ssl` sense permís d'escriptura. Introdueix només els **noms de fitxer** a `tls_certfile` i `tls_keyfile`; no hi posis rutes ni el contingut de la clau. Han d'estar informats tots dos. El nom o IP de la URL ha de coincidir amb el certificat. No desactivis la validació del certificat per donar la prova per superada.

Glass Rooms usa connexió directa i no confia en capçalere​s de proxy. Un proxy invers no és una alternativa configurada i validada en aquesta entrega.

## 5. Configura l'accés privat

A la pestanya **Configuració** de Glass Rooms:

| Camp | Valor que has de decidir |
|---|---|
| `light_entity_ids` | Llista de qualsevol nombre d'IDs `light.*`, incloses llums noves. |
| `entity_ids` | Llista opcional d'altres entitats de qualsevol domini, com sensors, interruptors, escenes o ventiladors. |
| `panel_password` | Una contrasenya única de 12 caràcters com a mínim, introduïda només aquí. No és la contrasenya de Home Assistant. |
| `allowed_hosts` | L'adreça exacta amb què obriràs el panell, inclòs el port si escau: `ADREÇA_HA:8099` per a la URL inicial. Afegeix un nom local només si l'utilitzes realment. Sense `http://` ni rutes. |
| `allowed_networks` | La xarxa CIDR real de casa, o IPs concretes `/32` amb reserva DHCP. No es pot deduir la màscara només de l'adreça `ADREÇA_HA`. Consulta-la al router. |
| `verified_actions` | Mantén `[]` fins a completar les proves. Després, afegeix `entity_id:servei`; només es mostra si Home Assistant publica el servei per aquell domini. |
| `room_assignments` | Mantén `[]` fins a confirmar ubicacions. Afegeix `entity_id:habitacio` per situar una entitat a una estança. |
| `alarm_modes` | Mantén `[]` fins a revisar els modes habilitats d'Alarmo. |
| `alarm_arm_code`, `alarm_disarm_code` | Mantén `unknown` fins a confirmar la política de codi. No són camps per escriure el PIN. |
| `tls_certfile`, `tls_keyfile` | Noms de fitxer a `/ssl` per HTTPS, o buits si has triat HTTP amb els límits anteriors. |

Aquest fragment conté només camps no secrets i conserva els bloquejos. **No és una configuració completa per arrencar**: falta introduir la contrasenya privadament i configurar la xarxa real.

```yaml
allowed_hosts:
  - ADREÇA_HA:8099
allowed_networks: []
verified_actions: []
room_assignments: []
alarm_modes: []
alarm_arm_code: unknown
alarm_disarm_code: unknown
tls_certfile: ""
tls_keyfile: ""
```

Amb contrasenya absent o massa curta, hosts buits o xarxes buides, el servidor rebutja l'arrencada. No ho solucionis obrint totes les adreces: defineix només els clients de confiança. Si fas servir una xarxa IPv6, comprova també les regles IPv6 del router; no n'afegeixis cap si no la necessites.

Supervisor escriu les opcions privades a **`/data/options.json` dins del contenidor**, abans de cada arrencada. Glass Rooms crea l'inventari exclusivament a partir de `light_entity_ids` i `entity_ids`; el codi no enumera cap instància. Les opcions buides donen un inventari buit. No creïs aquest fitxer a `www`, no el publiquis ni editis el codi per afegir-hi IDs o contrasenyes. [Entorn i emmagatzematge oficials d'aplicacions](https://contributors.home-assistant.io/apps/reference/environment/).

## 6. Inicia i comprova només la lectura

1. A la configuració de xarxa de l'aplicació, conserva el port `8099/tcp` publicat com `8099`, si està lliure. Si el canvies, adapta `allowed_hosts` i la URL del navegador.
2. Desa, inicia Glass Rooms i revisa el registre. No enganxis en converses opcions privades ni registres amb dades sensibles.
3. A casa, obre `https://ADREÇA_HA:8099` si el certificat cobreix aquesta IP, o el nom local cobert pel certificat. Si has triat HTTP, obre `http://ADREÇA_HA:8099`.
4. Inicia sessió al panell. Ha d'indicar connexió amb Home Assistant i mostrar l'hora de lectura. Compara dos o tres estats amb Home Assistant. Si no es connecta, segueix [la resolució d'errors](MANTENIMENT.md).
5. Les accions continuen bloquejades. Completa [la validació](VALIDACIO.md) abans d'activar-ne cap.
6. Al router, comprova que no hi ha redireccions WAN, túnels ni regles UPnP per al port del panell. Si tens xarxa de convidats, comprova que no hi pot accedir. Les regles del servidor complementen aquesta separació; no substitueixen el tallafoc.

L'accés del servidor a Home Assistant passa internament per `http://supervisor/core/api`; no es configura un token de llarga durada ni s'introdueix la URL `:8080` al JavaScript. L'aplicació necessita `homeassistant_api: true`, que té privilegis amplis a Core: el codi només llegeix entitats declarades a les opcions i només envia serveis explícitament enumerats a `verified_actions`. [Permisos del proxy de Supervisor](https://contributors.home-assistant.io/apps/guides/communication/).
