# Glass Rooms

## Revisió 1.0.11

L’inventari és dinàmic i no incorpora IDs de cap instància. Afegeix les llums a `light_entity_ids` i altres entitats a `entity_ids`, directament a les opcions de l’aplicació a Home Assistant. `room_assignments` les situa a les habitacions i `verified_actions` declara quines accions poden aparèixer quan Home Assistant publica el servei corresponent.

Un panell local en català per consultar Home Assistant i controlar les funcions que s'hagin verificat a casa. La portada mostra vuit estances il·lustrades; el resum general s'obre lliscant cap avall o des de la navegació lateral. El servidor rep els canvis d’estat per WebSocket des de Home Assistant i els comunica a la pàgina sense recarregar-la; una lectura periòdica cada 30 segons serveix de recuperació si el flux cau. El botó general encén o apaga tots els llums configurats, inclosos els que no tenen estança assignada, només quan tots els controls necessaris estan verificats. La icona de bombeta de cada targeta commuta les llums assignades quan l'ordre corresponent està verificada i torna a llegir Home Assistant per mostrar l'estat confirmat. Les llums que Home Assistant marca com a no disponibles es mostren a la targeta i bloquegen la commutació de l’habitació. Si Home Assistant rebutja una ordre mentre publica un estat vàlid, l’entitat queda temporalment bloquejada fins que l’estat informat canviï. La bombeta queda farcida quan hi ha llums encesos i manté el contorn quan són apagats. Les estances amb llums encesos destaquen en to càlid, i les que tenen els llums apagats o no disponibles mostren una icona fosca. Inclou temes de dia i nit i una presentació opaca per reduir el cost dels efectes visuals.

El mòdul **Clima** mostra la temperatura i la humitat per habitació a partir dels sensors `sensor.*` configurats. Reconeix els atributs `device_class: temperature` i `device_class: humidity` publicats per Home Assistant, conserva la unitat original i mostra un guió si no hi ha lectura disponible. Pots començar amb els dos sensors del menjador i afegir-ne d'altres habitacions amb la mateixa configuració, sense canviar el codi. Els sensors sense habitació assignada apareixen en una secció separada. Cal conèixer els IDs reals abans de poder mostrar valors de casa.

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

La sintaxi ES5 i les comprovacions en un navegador actual ajuden a preparar la compatibilitat, però **no demostren que Safari d'iOS 9 funcioni al dispositiu**. La connexió HTTPS, els certificats, els gestos i el rendiment s'han de comprovar a l'iPad físic. El registre de validació diferencia aquestes proves de les comprovacions locals.
