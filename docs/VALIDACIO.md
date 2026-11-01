# Validació abans de posar el panell en servei

## Estat d'aquesta entrega

L'adreça de la instància de Home Assistant es manté privada en aquesta còpia pública. **No s'ha accedit a Core, no s'ha executat cap ordre domòtica i l'usuari ha provat l'iPad físic i confirma que 1.0.2 carrega les habitacions; la resta de proves de la taula continuen pendents.** «Última versió» és una dada comunicada, no una versió llegida.

Consulta [el registre de proves locals](PROVES_LOCALS.md). Aquestes proves de codi i navegador actual no substitueixen la taula següent.

## Primera connexió: només lectura

1. Completa la instal·lació, deixa `verified_actions: []` i obre el panell des d'un ordinador actual de casa.
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
| Llums individuals i grups | Encesa/apagada real; `supported_color_modes`; camps del servei; límits Kelvin; ubicació i membres ZHA per separat | `turn_on`, `turn_off`, `brightness`, `color_temp_kelvin` |
| Adaptive Lighting | Efecte de cada switch i llums afectades; automatitzacions vinculades a `input_boolean.mode_circadia_llums` | `turn_on`, `turn_off` |
| Dues escenes | Revisar els efectes de `scene.mode_cozy` i `scene.on_llum_sofa`, provar-les i confirmar resultat | `turn_on` |
| Alarmo | Modes habilitats, bits suportats, serveis, requisits de codi per armar i desarmar, sensors inclosos | `alarm_arm_home`, `alarm_arm_away`, `alarm_arm_night`, `alarm_arm_vacation`, `alarm_disarm` |
| Escalfador | `current_temperature` si existeix; lectura vàlida de dutxes; `operation_list` i suport de modes; semàntica del sensor de temperatura requerida | `set_operation_mode` |
| Ventiladors | Encesa/apagada suportades i canvi de percentatge observat; pas i escala reals | `turn_on`, `turn_off`, `set_percentage` |
| Reproductors | Fabricant real; bits de funcions; reproducció, pausa i volum; encesa/apagada només si publicades i provades | `media_play`, `media_pause`, `volume_set`, `turn_on`, `turn_off` |

Les accions de brillantor i Kelvin es tradueixen internament a `light.turn_on` amb l'únic paràmetre autoritzat. Els percentatges del ventilador s'envien com a enters. El volum és de 0 a 1. No s'afegeixen serveis Sonos especials. Els switches de night mode, permanent boost i power de l'escalfador són de lectura en aquesta entrega; no s'assumeix que siguin equivalents als modes de l'entitat principal.

### Alarmo

Mantén les dues polítiques en `unknown` fins a revisar Alarmo. Per a cada mode d'armament verificat, afegeix el nom del servei a `alarm_modes` i la parella `alarm_control_panel.alarmo:nom_del_servei` a `verified_actions`. Configura `alarm_arm_code` i `alarm_disarm_code` com a `required` o `none` segons la configuració real. **No escriguis el PIN en aquests camps.** Els atributs incompatibles amb una política sense codi mantenen el control bloquejat.

Quan el codi és obligatori, la finestra ha de demanar-lo per a cada ordre. Prova codi correcte i incorrecte sense copiar-los al registre. Un codi erroni mai no ha de fer aparèixer una desactivació confirmada. No s'implementen armament forçat, bypass, sirena ni el mode custom bypass. Si la configuració real necessita un d'aquests modes, deixa'l fora d'abast.

### Ubicacions

Després de confirmar una ubicació, afegeix a `room_assignments` una cadena amb `entity_id:room_id`. IDs vàlids d'estança: `menjador`, `cuina`, `habitacio`, `despatx`, `rebedor`, `bany`, `passadis`, `lavabo`. Aquesta operació no reassigna àrees a Home Assistant ni modifica membres d'un grup. Un grup que abasta diverses estances pot quedar al resum sense ubicació.

## Prova física a l'iPad mini 1

Anota model, versió exacta d'iOS, URL final i data. Fes la prova amb Safari i després, si el vols, amb l'accés afegit a la pantalla d'inici.

| Prova | Criteri d'acceptació | Resultat |
|---|---|---|
| Obertura de la URL | Carrega sense excepció de certificat, recursos absents o pàgina en blanc | Pendent |
| Sessió | Entrada, sortida i nova entrada; contrasenya absent del camp després d'enviar | Pendent |
| Portada | 8 estances, llegibles, sense desbordament horitzontal a 1024×768 i 768×1024 | Pendent |
| Resum | S'obre amb el botó i amb lliscament avall des del capdamunt | Pendent |
| Navegació | Es poden obrir/tancar finestres, desplaçar llistes i arribar als controls amb una mà | Pendent |
| Aparença | Dia/nit i vidre desactivat; 20 minuts d'ús sense recàrregues per memòria | Pendent |
| Recuperació | Desconnectar/reconnectar Wi-Fi i tornar després de bloquejar la pantalla actualitza l'estat | Pendent |
| Dades absents | Pèrdua de connexió no mostra valors antics com a actuals; cap ordre disponible | Pendent |
| Accions | Cada ordre verificada produeix resultat físic i nova lectura coherent | Pendent |
| PIN | Teclat usable, esborra el camp, cancel·lar no envia res, no es desa en preferències | Pendent |
| Caducitat | Després de reiniciar l'app o expirar la sessió demana autenticació | Pendent |
| Xarxa de convidats | No accedeix al panell; cap exposició WAN o túnel | Pendent |

Si un gest no funciona, utilitza el botó. Si el desenfocament és lent, desactiva **Vidre suau**. Si TLS no funciona, segueix les alternatives documentades a la instal·lació; no donis el panell per validat saltant errors de certificat. No cal alterar el bloqueig de pantalla.

## Registre per acció

Copia aquesta taula tantes vegades com calgui, sense PINs, contrasenyes ni tokens:

| Entitat | Acció / valor no secret | Atributs i servei revisats | Resultat físic | Estat posterior | Data / provador | Entrada habilitada |
|---|---|---|---|---|---|---|
| Pendent | Pendent | Pendent | Pendent | Pendent | Pendent | No |
