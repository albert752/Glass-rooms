# Glass Rooms — internal implementation contract

Local-only HA OS add-on in `glass_rooms/`: a Python standard-library JSON API (plus pinned websockets) for the native iPad app in `ios/`. Since 1.2.0 there is no web panel, ## Ownership
- Backend: `glass_rooms/server.py`, `glass_rooms/catalog.py`, Dockerfile, config.yaml, backend tests.
- iPad app: `ios/` (UIKit, Objective-C, iOS 9 SDK), native tests and preview.
- Documentation: root README.md and docs/*.

## API (iPad app only)
Every /api route except GET /api/session requires Authorization: Bearer <panel_pin or app_token>. panel_pin is checked as HMAC-SHA256 with the startup salt; app_token optional (32–128 [A-Za-z0-9_-]), stored as SHA-256; invalid bearer → 401 and 5 per minute per IP. No cookies, CSRF, Origin checks, /api/login or /api/logout (404). Any non-API path → 404. Network and Host guards on every request.
GET /api/session -> {authenticated: bool (valid bearer), preview: bool}.
GET /api/state -> {connected, preview, demo, live_updates, fetched_at, error, version, entities:[Entity], rooms:[{id,name}], transport}. No synthetic values in preview. Unavailable entity: status unavailable; missing: missing; unknown: unknown.
Entity: {entity_id,name,domain,category,room,inventory_area,is_group,state,status,attributes:{filtered},controls:[Control],note,changed?}. Categories: lights, security, water, fans, media, scenes, switches, climate (temperature/humidity sensors), energy (sensor with price_00h, PVPC), weather (weather.*), other.
Control: {action,label,kind:'button'|'range'|'select'|'alarm',enabled,reason,min?,max?,step?,value?,options?,requires_code?,speeds?}. Present only for detected capabilities and services; enabled only if entity_id:action (or the shared verify action) is in verified_actions.
Water heater: turn_on/turn_off (feature 8), set_temperature range min_temp..max_temp (feature 1, field temperature), set_operation_mode select (feature 2), away_mode_on/away_mode_off buttons → set_away_mode {away_mode: bool} verified by set_away_mode (feature 4). Water heater attributes also pass any other plain attribute (number, bool, string ≤64 without "://") whose name has no secret word (token, password, key, code, url, ip, mac, serial, id…), up to 48.
Fan: set_percentage carries speeds N from fan_speeds or from percentage_step when 100/step is a whole number 2–10.
PVPC sensor attributes: price_HHh, price_next_day_HHh and the integration summary (period, next_period, min/max price…).
POST /api/action {entity_id,action,value?,code?} -> {ok:true,message}. Server re-reads state/services before validating. No arbitrary service proxy. Never optimistic UI.
POST /api/lights {entity_ids,action:'turn_on'|'turn_off'|'brightness'|'color_temp_kelvin',value?} -> {ok,succeeded,failed,error}. brightness integer 1–255, color_temp_kelvin integer 500–40000 clamped to each light's own range. Every light validated against fresh state and verified controls before any call; individual failures do not stop the others. 120 light requests per IP per minute; other actions 30.
GET /api/climate-history?hours=1|3|6|12|24|48|168|336|720, GET /api/camera?entity_id=, GET /api/updates?since=, GET /api/audit: as before, bearer required.
Siren controls are turn_off only. Remote buttons: remote_buttons remote.x:device:command:Label (≤48 per remote), command_N controls verified by remote.x:send_command.

 with pending entities, never misleading stale live state.

## Options and deployment contract
panel_pin (empty default refuses startup; user sets privately, 6–8 ASCII digits), allowed_hosts list (empty refuses production startup; explicit IP/hostname with optional port), allowed_networks list (empty refuses startup; user enters actual LAN CIDR), verified_actions list of entity_id:action, room_assignments list of entity_id:room_id, remote_buttons list of remote.entity:device:command:Label (up to 48 per remote; a free send_command is never accepted), fan_speeds list of fan.entity:N (2–10), alarm_modes list of service names, alarm_arm_code policy required/none/unknown, alarm_disarm_code required/none/unknown. All default unknown/empty. tls_certfile/tls_keyfile optional private /ssl basenames with read-only ssl mapping. TLS optional but explicitly describe HTTP PIN exposure and recommend TLS, no Internet exposure. Use forwarded headers never (direct TLS support). Supervisor token only env, fixed upstream http://supervisor/core/api. App homeassistant_api:true, no hassio_api/docker_api/privileged. Default port 8099. FROM python:3.13-alpine; architectures amd64,aarch64 (document supported HA OS hosts); fixed named app files no static traversal. Python 3.9+ local compatibility desirable.
python3 glass_rooms/server.py --preview --port 8099 binds loopback with a read-only API, no real backend or actions. Production normal invocation loads /data/options.json. All configuration fail closed. Preview visual state explicitly labeled disconnected, no fake data. Room IDs menjador,cuina,habitacio,despatx,rebedor,bany,passadis,lavabo.

## Verification
Unit tests: backend authorization, capabilities, code policy, payload constraints, bearer-only API, preview read-only; native logic and client against the real server with a fake HA (ios/scripts/test.sh). Actual HA instance and iPad hardware are pending external validation. docs must distinguish performed checks from remaining checks.
