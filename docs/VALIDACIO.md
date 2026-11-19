# Validació abans de posar el panell en servei

## Estat d'aquesta entrega

L'adreça de la instància de Home Assistant es manté privada en aquesta còpia pública. **No s'ha accedit a Core, no s'ha executat cap ordre domòtica i l'usuari ha provat l'iPad físic i confirma que 1.0.2 carrega les habitacions; la resta de proves de la taula continuen pendents.** «Última versió» és una dada comunicada, no una versió llegida.

Consulta [el registre de proves locals](PROVES_LOCALS.md). Aquestes proves a l'ordinador no substitueixen la taula següent.

## Primera connexió: només lectura

1. Completa la instal·lació, deixa `verified_actions: []` i connecta l'app per a iPad.
2. A **Ajustos → Informe de verificació**, comprova `connected`, `version` i que només apareguin les entitats declarades a la configuració. No exportis informació privada fora de casa sense revisar-la.
3. Compara estat, disponibilitat i atributs amb **Eines de desenvolupador → Estats** de Home Assistant. `unknown`, `unavailable` i una entitat absent han de quedar diferenciats.
4. Revisa les accions i els camps reals a **Eines de desenvolupador → Accions**. Un servei del domini no garanteix que una entitat concreta el pugui executar.
5. Prova cada acció a Home Assistant, observa físicament el resultat i confirma el nou estat. Avisa les persones que hi hagi a casa abans d'armar l'alarma. No provis `script.toggle_alarma` sense revisar-lo.
6. Registra la prova i afegeix només la parella verificada a `verified_actions`, a les opcions privades de Glass Rooms. Desa i reinicia l'app. Repeteix la prova des del panell. Si falla, retira aquesta entrada i reinicia.

Exemple **sense secrets**, només després d'haver comprovat aquestes dues accions:

```yaml
verified_actions:
  - light.example_lamp:turn_on
  - light.example_lamp:turn_off
```

La prova d'encesa no autoritza brillantor o temperatura de color. L'app es nega a arrencar si hi ha IDs o accions fora del catàleg.

## Què verificar per categoria

| Categoria | Comprovacions abans d'activar | Accions admeses |
|---|---|---|
| Llums individuals i grups | Encesa/apagada real; `supported_color_modes`; camps del servei; límits Kelvin; ubicació i membres ZHA per separat. Els controls de «Tots els llums» fan servir les mateixes entrades `brightness` i `color_temp_kelvin` de cada llum | `turn_on`, `turn_off`, `brightness`, `color_temp_kelvin` |
| Adaptive Lighting | Efecte de cada switch i llums afectades; automatitzacions vinculades a `input_boolean.mode_circadia_llums` | `turn_on`, `turn_off` |
| Dues escenes | Revisar els efectes de `scene.mode_cozy` i `scene.on_llum_sofa`, provar-les i confirmar resultat | `turn_on` |
| Alarmo | Modes habilitats, bits suportats, serveis, requisits de codi per armar i desarmar, sensors inclosos | `alarm_arm_home`, `alarm_arm_away`, `alarm_arm_night`, `alarm_arm_vacation`, `alarm_disarm` |
| Escalfador | `current_temperature`, `temperature`, `min_temp` i `max_temp`; `supported_features`; `operation_list`; mode absència; que la temperatura objectiu enviada arriba a l'aparell | `set_operation_mode`, `set_temperature`, `turn_on`, `turn_off`, `set_away_mode` |
| Ventiladors | Encesa/apagada suportades; `percentage_step` o `fan_speeds`; que cada botó de velocitat (1 a 6 als CREATE) posa el ventilador a aquella velocitat | `turn_on`, `turn_off`, `set_percentage` |
| Comandaments | Que cada ordre de `remote_buttons` fa el que diu l'etiqueta (tele, llum de sostre) | `send_command` |
| Reproductors | Fabricant real; bits de funcions; reproducció, pausa i volum; encesa/apagada només si publicades i provades | `media_play`, `media_pause`, `volume_set`, `turn_on`, `turn_off` |

Les accions de brillantor i Kelvin es tradueixen internament a `light.turn_on` amb l'únic paràmetre autoritzat. Els percentatges del ventilador s'envien com a enters; la velocitat *n* de *N* és `floor(n × 100 / N)` %. El volum és de 0 a 1. No s'afegeixen serveis Sonos especials. Els switches propis de l'escalfador (night mode, permanent boost, power) es poden afegir a `entity_ids` com qualsevol interruptor; no s'assumeix que siguin equivalents als modes de l'entitat principal.

### Alarmo

Mantén les dues polítiques en `unknown` fins a revisar Alarmo. Per a cada mode d'armament verificat, afegeix el nom del servei a `alarm_modes` i la parella `alarm_control_panel.alarmo:nom_del_servei` a `verified_actions`. Configura `alarm_arm_code` i `alarm_disarm_code` com a `required` o `none` segons la configuració real. **No escriguis el PIN en aquests camps.** Els atributs incompatibles amb una política sense codi mantenen el control bloquejat.

Quan el codi és obligatori, l'app el demana amb el seu teclat numèric per a cada ordre. Prova codi correcte i incorrecte sense copiar-los al registre. Un codi erroni mai no ha de fer aparèixer una desactivació confirmada. No s'implementen armament forçat, bypass, sirena ni el mode custom bypass. Si la configuració real necessita un d'aquests modes, deixa'l fora d'abast.

### Ubicacions

Després de confirmar una ubicació, afegeix a `room_assignments` una cadena amb `entity_id:room_id`. IDs vàlids d'estança: `menjador`, `cuina`, `habitacio`, `despatx`, `rebedor`, `bany`, `passadis`, `lavabo`. Aquesta operació no reassigna àrees a Home Assistant ni modifica membres d'un grup. Un grup que abasta diverses estances pot quedar al resum sense ubicació.

## Prova física a l'iPad mini 1

Anota model, versió exacta d'iOS, adreça del panell, versió de l'app i data.

| Prova | Criteri d'acceptació | Resultat |
|---|---|---|
| Connexió | L'app connecta amb el PIN del panell; un PIN erroni mostra l'error | Pendent |
| Portada | 8 estances, llegibles, sense desbordament a 1024×768 i 768×1024 | Pendent |
| Estils | Nit càlida i Jarvis, de dia i de nit; 20 minuts d'ús sense alentiments ni tancaments | Pendent |
| Pantalla | Amb un temps curt (per exemple 15 s), la pantalla queda negra i fosca; el primer toc l'encén sense prémer res; després, iOS la bloqueja | Pendent |
| Tots els llums | Brillantor i escalfor canvien els llums Hue encesos | Pendent |
| Aparells | Escalfador (objectiu, mode, encesa), velocitats 1–6 dels ventiladors i botons dels comandaments | Pendent |
| Preu de la llum | Preu actual i nivell coherents amb Home Assistant | Pendent |
| Recuperació | Desconnectar/reconnectar Wi-Fi i tornar després de bloquejar la pantalla actualitza l'estat | Pendent |
| Dades absents | Pèrdua de connexió no mostra valors antics com a actuals; cap ordre disponible | Pendent |
| Accions | Cada ordre verificada produeix resultat físic i nova lectura coherent | Pendent |
| PIN de l'alarma | Teclat numèric usable; esborra els dígits; tancar no envia res | Pendent |
| Xarxa de convidats | No accedeix al panell; cap exposició WAN o túnel | Pendent |

Si TLS no funciona, segueix les alternatives documentades a la instal·lació; no donis el panell per validat saltant errors de certificat.

## Registre per acció

Copia aquesta taula tantes vegades com calgui, sense PINs ni tokens:

| Entitat | Acció / valor no secret | Atributs i servei revisats | Resultat físic | Estat posterior | Data / provador | Entrada habilitada |
|---|---|---|---|---|---|---|
| Pendent | Pendent | Pendent | Pendent | Pendent | Pendent | No |
