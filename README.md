# Glass Rooms

## Revisió 1.1.10

**Migració des de 1.0.x:** a les opcions privades de Glass Rooms, elimina `panel_password` i configura `panel_pin` amb un PIN nou de 6 a 8 dígits. Desa les opcions i reinicia l'aplicació. La contrasenya antiga no es converteix automàticament en PIN; si falta `panel_pin`, el servidor no arrenca. L'accés al panell es fa amb el teclat numèric de la pàgina. El PIN d'alarma, si n'hi ha, continua sent independent.

**Novetat 1.1.10:** l'app per a iPad té un panell de **Seguretat** a pantalla completa. Hi surten:

- l'alarma, amb els botons d'armar i desarmar;
- la càmera, amb una imatge nova cada 2,5 s i la detecció de moviment i de persones;
- les portes i les finestres;
- la sirena, que només es pot aturar;
- qui és a casa;
- les bateries dels sensors.

El servidor admet ara els dominis `camera`, `siren`, `person` i `device_tracker` i té la ruta `/api/camera`. La configuració és a [APP_IOS.md](docs/APP_IOS.md#panell-de-seguretat-des-de-1110).

**1.1.9:**

- **Historial de clima:** cada sèrie es tanca amb la lectura actual del sensor. Així, un sensor que no ha canviat en tot el període (sovint la humitat) dibuixa una línia en lloc de quedar buit, tant al panell web com a l'app.
- **Llums que no responen:** si un llum no arriba a l'estat demanat 10 segons després d'una ordre, l'app el bloqueja. El bloqueig dura fins que Home Assistant n'informa un estat nou o fins que passen 2 minuts.
- **Sense actualitzacions en directe:** l'app torna a llegir l'estat cada 8 segons en lloc de cada 30.
- **Tema:** l'app ja no té el botó del sol o la lluna; el tema es tria a Ajustos.

**1.1.8:** a l'app per a iPad, la pàgina de Clima ocupa tota la pantalla. Té una gràfica gran amb eixos que es pot tocar o arrossegar per veure cada punt, una fitxa per sensor, la lectura en gran i el mínim, el màxim i la mitjana del període.

**1.1.7:** l'app per a iPad ja no mostra cap avís quan envia una ordre de llums; només avisa si falla o si s'ometen llums.

**1.1.6:** redisseny complet de l'[app nativa per a iPad amb iOS 9](docs/APP_IOS.md) (`ios/`), pensada per a un iPad fix a la paret. Té un rellotge gran amb temperatura, humitat i alarma i la tendència de les últimes hores. Les estances es mostren en llista, amb un interruptor de llums a cada fila, i hi ha un calaix lateral per a cada estança. Els temes són negre i ambre de nit i paper càlid de dia. El panell web i el servidor no canvien.

**1.1.5:** l'app s'identifica amb el mateix PIN del panell (`panel_pin`), introduït una vegada a Ajustos; no té pantalla de bloqueig. `app_token` continua sent opcional.

L’inventari és dinàmic i no incorpora IDs de cap instància. Afegeix les llums a `light_entity_ids` i altres entitats a `entity_ids`, directament a les opcions de l’aplicació a Home Assistant. `room_assignments` les situa a les habitacions i `verified_actions` declara quines accions poden aparèixer quan Home Assistant publica el servei corresponent.

Un panell local en català per consultar Home Assistant i controlar les funcions que s'hagin verificat a casa. La portada mostra vuit estances il·lustrades; el resum general s'obre des de la navegació lateral. El servidor rep els canvis d’estat per WebSocket des de Home Assistant i els comunica a la pàgina sense recarregar-la; una lectura periòdica cada 30 segons serveix de recuperació si el flux cau. Els controls generals «Encén» i «Apaga» envien l’ordre explícita als llums configurats que la tenen verificada, inclosos els que no tenen estança assignada; els llums no disponibles o sense verificació s’ometen i se n’indica el nombre. El servidor comprova cada llum abans d’enviar-li l’ordre, de manera que un llum fallit no bloqueja els altres. Les ordres d'una habitació o de tota la casa s'envien al panell en una sola petició per evitar esgotar el límit amb uns quants canvis seguits. La icona de bombeta de cada targeta commuta les llums assignades quan l'ordre corresponent està verificada i torna a llegir Home Assistant per mostrar l'estat confirmat. Després d’una ordre de llum, el panell torna a consultar l’estat al cap de 2, 5, 10, 20 i 30 segons fins que Home Assistant confirma el canvi; això no accelera una integració que encara no l’hagi notificat. Si Home Assistant rebutja una ordre mentre publica un estat vàlid, l’entitat queda temporalment bloquejada fins que l’estat informat canviï. La bombeta queda farcida quan hi ha llums encesos i manté el contorn quan són apagats. Les estances amb llums encesos destaquen en to càlid, i les que tenen els llums apagats o no disponibles mostren una icona fosca. Inclou temes de dia i nit i una presentació opaca per reduir el cost dels efectes visuals. Toca la icona del sol o de la lluna al costat del rellotge per alternar els dos temes; la tria es conserva al navegador.

El mòdul **Clima** mostra la temperatura i la humitat actuals per habitació a partir dels sensors `sensor.*` configurats. Reconeix els atributs `device_class: temperature` i `device_class: humidity` publicats per Home Assistant, conserva la unitat original i mostra un guió si no hi ha lectura disponible. Cada sensor té una gràfica interactiva de l'historial de Home Assistant amb períodes de 6 hores, 24 hores, 7 dies i 1 mes (els darrers 30 dies); el selector permet consultar el valor i l'hora de cada punt, mentre la xifra gran mostra la lectura instantània. L'historial requereix que Home Assistant tingui dades enregistrades per al sensor; si no n'hi ha, el panell ho indica sense inventar valors. Pots començar amb els dos sensors del menjador i afegir-ne d'altres habitacions amb la mateixa configuració, sense canviar el codi. Els sensors sense habitació assignada apareixen en una secció separada. Cal conèixer els IDs reals abans de poder mostrar valors de casa.

**El codi està preparat per instal·lar-se, però la posada en servei real queda pendent.** L'usuari és fora de casa: no s'han comprovat la instància de Home Assistant ni els dispositius. L'usuari ha confirmat que la versió 1.0.2 carrega les habitacions a l'iPad mini 1 amb iOS 9.3.5; la resta de fluxos físics encara està pendent. La versió instal·lada és «l'última» segons l'usuari, sense número verificat. Totes les accions comencen bloquejades. El panell no substitueix les dades absents per valors inventats.

La revisió **1.0.2** corregeix [el bloqueig de sintaxi de Safari 9.3.5](docs/SAFARI_9.md). **L’usuari ha confirmat que ara carrega les habitacions a l’iPad.** Inclou un diagnòstic independent i proves de regressió.

## Com començar

1. Per mirar la interfície a l'ordinador, executa des de la carpeta del projecte:

   ```sh
   python3 glass_rooms/server.py --preview --port 8099
   ```

   Obre [la previsualització local](http://127.0.0.1:8099). Només escolta a l'ordinador, no es connecta a Home Assistant i no pot executar accions. Les entitats hi apareixen pendents.
   Per provar el disseny des d'un altre dispositiu de la mateixa xarxa, executa `python3 glass_rooms/server.py --lan-preview --lan-address ADREÇA_LAN --demo-lights --port 8100` i obre `http://ADREÇA_LAN:8100`. Aquest mode mostra vuit llums ficticis, un per estança, amb estats simulats. No consulta Home Assistant i rebutja totes les ordres.
2. Quan siguis a casa, segueix [la instal·lació a Home Assistant OS](docs/INSTALLACIO.md). Introdueix l'adreça privada de Home Assistant durant la instal·lació; el panell tindrà el seu propi port, inicialment `8099`.
3. Completa [la validació de dispositius i de l'iPad](docs/VALIDACIO.md) abans d'habilitar cada control.

## Què inclou

- Menjador, cuina, habitació, despatx, rebedor, bany, passadís i lavabo. «Menjador», repetit a la petició original, apareix una sola vegada.
- Inventari configurable de llums i d'altres entitats, sense una llista fixa al codi.
- Lectures reals i detecció de capacitats de llums, Adaptive Lighting, dues escenes, Alarmo, obertures i detecció, escalfador, ventiladors i reproductors. Les accions necessiten verificació explícita, a més dels atributs i serveis disponibles.
- Servidor Python amb biblioteca estàndard i `websockets` per al flux d'esdeveniments; client JavaScript ES5, recursos locals i cap dependència del núvol durant l'ús.
- Autenticació del panell, sessió curta al servidor, protecció de peticions i una llista tancada d'accions. El token de Supervisor no arriba al navegador.

Les habitacions són una estructura de navegació, no un mapa de dispositius confirmat. Fins que es verifiqui la correspondència física, les entitats es consulten al resum general. No s'infereixen membres dels grups ZHA. El reproductor de sala no s'etiqueta com a Sonos, el script d'alarma no s'executa i no hi ha controls de temperatura de l'escalfador.

## Fitxers i guies

| Element | Contingut |
|---|---|
| `glass_rooms/` | Aplicació local per a Home Assistant OS: configuració, imatge i servidor |
| `glass_rooms/www/` | HTML, CSS, JavaScript i il·lustracions, sense secrets |
| [Instal·lació](docs/INSTALLACIO.md) | Còpia de seguretat, accés local, autenticació i connexió |
| [Validació](docs/VALIDACIO.md) | Proves per entitat, activació de controls i proves sobre l'iPad real |
| [Inventari i preguntes pendents](docs/INVENTARI.md) | Abast exacte i decisions que falten |
| [Arquitectura](docs/ARQUITECTURA.md) | Flux de dades, permisos i límits de compatibilitat |
| [Manteniment](docs/MANTENIMENT.md) | Errors habituals, actualització, reversió i retirada |
| `ios/` · [App per a iPad](docs/APP_IOS.md) | Client natiu UIKit per a iOS 9: compilació sense Xcode, sideload i configuració |

La sintaxi ES5 i les comprovacions en un navegador actual ajuden a preparar la compatibilitat, però **no demostren que Safari d'iOS 9 funcioni al dispositiu**. La connexió HTTPS, els certificats, i el rendiment s'han de comprovar a l'iPad físic. El registre de validació diferencia aquestes proves de les comprovacions locals.
