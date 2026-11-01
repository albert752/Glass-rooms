# Inventari i preguntes pendents

Glass Rooms no incorpora cap inventari d’instància ni pressuposa que els dispositius siguin coneguts. Les opcions de l’aplicació a Home Assistant defineixen els IDs que es consulten. Es poden afegir o treure sense canviar el codi.

«Menjador» apareix una sola vegada, tot i la repetició original. Les vuit estances són de navegació; cap dispositiu té ubicació física assignada per defecte.

## Preguntes per completar a casa

1. Quines versions exactes de Core, Supervisor i OS hi ha, i quin accés local tens: Samba, Terminal/SSH o només web?
2. Quina és la subxarxa real de casa i quines IPs han de poder obrir el panell? La IP de Home Assistant no determina la màscara.
3. Bany i dutxa són la mateixa zona? Què inclou «costelles»? On van passadís i lavabo? A quina habitació física correspon cada entitat individual?
4. Quins membres té cadascun dels vuit grups ZHA? Què signifiquen les xifres comunicades? No les tractem com a recompte de bombetes.
5. Quines llums afecta Adaptive Lighting? Quines automatitzacions depenen de l’indicador de mode circadià?
6. Quins modes té habilitats l’alarma, quan exigeix codi i quins sensors inclou? Què fa exactament l’script d’alarma? El panell no l’executa.
7. Quins modes publica l’escalfador? Exposa la temperatura actual? Què representa la lectura addicional de temperatura de procés?
8. Quin reproductor correspon al dispositiu de sala? Quins controls publica cada reproductor?
9. Quina URL i certificat funcionen a Safari de l’iPad? Quina versió exacta d’iOS té? S’han completat les proves físiques?

## Configuració d’entitats

`light_entity_ids` és una llista de llums. `entity_ids` és una llista opcional per a qualsevol altre domini. Assigna les entitats a una estança amb `room_assignments` i autoritza només els serveis que hagis provat a `verified_actions`.

```yaml
light_entity_ids:
  - light.exemple_llum_nova
entity_ids:
  - sensor.exemple_sensor
room_assignments:
  - light.exemple_llum_nova:cuina
verified_actions:
  - light.exemple_llum_nova:turn_on
  - light.exemple_llum_nova:turn_off
```

Els noms del bloc són exemples ficticis. Per a una entitat nova, afegeix l’ID exacte a la llista corresponent i configura’n l’estança i les accions provades. Els controls especials de cada domini només apareixen quan el servei, els atributs i els camps necessaris estan disponibles; les accions genèriques configurades només s’ofereixen si el servei no demana cap altre camp a part de l’entitat.

Les habitacions són una estructura de navegació, no un mapa de dispositius confirmat. Fins que es verifiqui la correspondència física, les entitats es consulten al resum general. No s’infereixen membres dels grups ZHA.
