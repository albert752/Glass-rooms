#!/usr/bin/env python3
"""Glass Rooms: config-driven inventory, fail-closed controls and a private HA API bridge.

Runtime dependencies are Python's standard library and the pinned websockets client. Never log requests, headers, bodies,
upstream responses, exception text or credentials. The Supervisor token stays
inside this process. No action is retried automatically.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
import datetime
import hashlib
import hmac
import http.cookies
import ipaddress
import json
import math
import os
from pathlib import Path
import re
import secrets
import socket
import ssl
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib import error, parse, request
try:
    from websockets.sync.client import connect as websocket_connect
except ImportError:
    websocket_connect = None

try:
    from .catalog import BY_ID, CATALOG, ROOMS, ROOM_IDS, catalog_for
except ImportError:
    from catalog import BY_ID, CATALOG, ROOMS, ROOM_IDS, catalog_for

ROOT = Path(__file__).resolve().parent / "www"
UPSTREAM = "http://supervisor/core/api"
SESSION_SECONDS = 12 * 60 * 60
COOKIE_NAME = "glass_rooms_session"
APP_TOKEN_PATTERN = r"[A-Za-z0-9_-]{32,128}"
MAX_BODY = 4096
ARM_FEATURES = {
    "alarm_arm_home": (1, "Armar a casa"),
    "alarm_arm_away": (2, "Armar fora"),
    "alarm_arm_night": (4, "Armar de nit"),
    "alarm_arm_vacation": (32, "Armar vacances"),
}
ACTION_NAMES = {
    "light": {"turn_on", "turn_off", "brightness", "color_temp_kelvin"},
    "switch": {"turn_on", "turn_off"},
    "input_boolean": {"turn_on", "turn_off"},
    "scene": {"turn_on"},
    "alarm_control_panel": set(ARM_FEATURES) | {"alarm_disarm"},
    "water_heater": {"set_operation_mode"},
    "fan": {"turn_on", "turn_off", "set_percentage"},
    "media_player": {"turn_on", "turn_off", "media_play", "media_pause", "volume_set"},
}
ATTRS = {
    "light": {"supported_features", "supported_color_modes", "brightness", "color_mode", "friendly_name",
              "color_temp_kelvin", "min_color_temp_kelvin", "max_color_temp_kelvin"},
    "switch": {"lights", "friendly_name"},
    "input_boolean": {"friendly_name"},
    "scene": {"friendly_name"},
    "alarm_control_panel": {"supported_features", "code_format", "code_arm_required", "friendly_name"},
    "sensor": {"unit_of_measurement", "device_class", "friendly_name"},
    "binary_sensor": {"device_class", "friendly_name"},
    "script": {"friendly_name"},
    "water_heater": {"supported_features", "current_temperature", "temperature_unit", "friendly_name",
                     "operation_mode", "operation_list"},
    "fan": {"supported_features", "percentage", "percentage_step", "friendly_name"},
    "media_player": {"supported_features", "volume_level", "is_volume_muted", "media_title", "media_artist", "friendly_name"},
}
PRIVATE_NETS = [ipaddress.ip_network(value) for value in (
    "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "127.0.0.0/8", "fc00::/7", "::1/128")]


class PublicError(Exception):
    """Only fixed, non-secret messages may be passed into this exception."""

    def __init__(self, message, status=400):
        self.message = message
        self.status = status
        super().__init__(message)


def number(value):
    return isinstance(value, (float, int)) and not isinstance(value, bool) and math.isfinite(value)


def short_string(value, limit=160):
    return isinstance(value, str) and len(value) <= limit and not any(ord(c) < 32 for c in value)


def authority(value):
    """Validate an exact Host value; never trust forwarded headers or suffixes."""
    if not short_string(value, 253) or not value or re.search(r"[\s/@\\?#,]", value):
        raise ValueError("Host invàlid")
    try:
        url = parse.urlsplit("//" + value)
        port = url.port
        hostname = url.hostname
    except ValueError:
        raise ValueError("Host invàlid") from None
    if not hostname or url.username or url.password or url.path or value.endswith(":"):
        raise ValueError("Host invàlid")
    if port is not None and not 1 <= port <= 65535:
        raise ValueError("Host invàlid")
    try:
        ipaddress.ip_address(hostname)
    except ValueError:
        if not re.fullmatch(r"[a-zA-Z0-9](?:[a-zA-Z0-9.-]{0,251}[a-zA-Z0-9])?", hostname):
            raise ValueError("Host invàlid") from None
        if ".." in hostname:
            raise ValueError("Host invàlid")
    return value.lower()


def list_option(options, name):
    value = options.get(name, [])
    if not isinstance(value, list) or len(value) > 256 or any(not isinstance(v, str) for v in value):
        raise ValueError("L'opció " + name + " ha de ser una llista de text.")
    return value


def action_allowed(entity_id, action, by_id=None):
    item = (by_id if by_id is not None else BY_ID).get(entity_id)
    return bool(item and isinstance(action, str) and re.fullmatch(r"[a-z][a-z0-9_]*", action))


class Settings:
    def __init__(self, options, preview=False, port=8099, lan_preview=False, lan_address=None, demo_lights=False):
        self.preview = preview
        self.demo_lights = demo_lights
        self.verified = set()
        self.room_assignments = {}
        self.alarm_modes = set()
        self.arm_code = "unknown"
        self.disarm_code = "unknown"
        self.tls_cert = self.tls_key = None
        self.pin_salt = secrets.token_bytes(32)
        self.pin_hash = b""
        self.app_token_hash = b""
        self.pin_bearer_hash = b""
        self.catalog = CATALOG
        self.by_id = {item["entity_id"]: item for item in self.catalog}
        if preview:
            if demo_lights:
                self.catalog = catalog_for(["light.demo_" + room["id"] for room in ROOMS])
                self.by_id = {item["entity_id"]: item for item in self.catalog}
                self.room_assignments = {"light.demo_" + room["id"]: room["id"] for room in ROOMS}
            self.allowed_hosts = {"127.0.0.1:" + str(port), "localhost:" + str(port)}
            self.allowed_networks = [ipaddress.ip_network("127.0.0.0/8")]
            if lan_preview:
                if not lan_address:
                    raise ValueError("No s'ha pogut determinar la interfície LAN.")
                self.allowed_hosts.add(authority(lan_address + ":" + str(port)))
                self.allowed_networks.append(ipaddress.ip_network(lan_address + "/24", strict=False))
            return
        if not isinstance(options, dict):
            raise ValueError("Les opcions han de ser un objecte JSON.")
        known = {"panel_pin", "app_token", "allowed_hosts", "allowed_networks", "verified_actions", "room_assignments",
                 "light_entity_ids", "entity_ids",
                 "alarm_modes", "alarm_arm_code", "alarm_disarm_code", "tls_certfile", "tls_keyfile"}
        if set(options) - known:
            raise ValueError("Hi ha opcions desconegudes; reviseu la configuració.")
        pin = options.get("panel_pin", "")
        if not isinstance(pin, str) or not re.fullmatch(r"[0-9]{6,8}", pin):
            raise ValueError("Configureu panel_pin privat, de 6 a 8 dígits.")
        self.pin_hash = self.pin_digest(pin)
        # The native app sends the panel PIN on every request; a keyed SHA-256 avoids running
        # PBKDF2 for each poll while failed attempts stay rate limited like the PIN pad.
        self.pin_bearer_hash = hmac.new(self.pin_salt, pin.encode("ascii"), hashlib.sha256).digest()
        app_token = options.get("app_token", "")
        if not isinstance(app_token, str) or (app_token and not re.fullmatch(APP_TOKEN_PATTERN, app_token)):
            raise ValueError("app_token ha de quedar buit o tenir de 32 a 128 caràcters A-Z, a-z, 0-9, _ o -.")
        self.app_token_hash = hashlib.sha256(app_token.encode("ascii")).digest() if app_token else b""
        self.allowed_hosts = {authority(v) for v in list_option(options, "allowed_hosts")}
        if not self.allowed_hosts:
            raise ValueError("Configureu allowed_hosts amb l'adreça exacta i el port del panell.")
        self.allowed_networks = []
        for value in list_option(options, "allowed_networks"):
            try:
                network = ipaddress.ip_network(value, strict=True)
            except ValueError:
                raise ValueError("allowed_networks conté un CIDR invàlid.") from None
            if not any(network.version == allowed.version and network.subnet_of(allowed) for allowed in PRIVATE_NETS):
                raise ValueError("allowed_networks només admet subxarxes privades explícites o loopback.")
            self.allowed_networks.append(network)
        if not self.allowed_networks:
            raise ValueError("Configureu allowed_networks amb el CIDR real de la LAN.")
        light_ids = list_option(options, "light_entity_ids")
        entity_ids = list_option(options, "entity_ids")
        if len(light_ids) + len(entity_ids) > 256:
            raise ValueError("La configuració pot incloure com a màxim 256 entitats.")
        if any(not re.fullmatch(r"light\.[a-z0-9_]+", value) for value in light_ids):
            raise ValueError("light_entity_ids només admet IDs del domini light.")
        if any(not re.fullmatch(r"[a-z_]+\.[a-z0-9_]+", value) or value.split(".", 1)[0] == "light"
               for value in entity_ids):
            raise ValueError("entity_ids admet dominis vàlids excepte light; posa els llums a light_entity_ids.")
        all_ids = light_ids + entity_ids
        if len(set(all_ids)) != len(all_ids):
            raise ValueError("Els IDs configurats han de ser únics.")
        self.light_entity_ids = light_ids
        self.entity_ids = entity_ids
        self.catalog = catalog_for(light_ids, entity_ids)
        self.by_id = {item["entity_id"]: item for item in self.catalog}
        for item in list_option(options, "verified_actions"):
            entity_id, separator, action = item.partition(":")
            if not separator or not action_allowed(entity_id, action, self.by_id):
                raise ValueError("verified_actions conté una entitat o acció no admesa.")
            self.verified.add(item)
        for item in list_option(options, "room_assignments"):
            entity_id, separator, room = item.partition(":")
            if not separator or entity_id not in self.by_id or room not in ROOM_IDS or entity_id in self.room_assignments:
                raise ValueError("room_assignments conté una assignació no admesa o duplicada.")
            self.room_assignments[entity_id] = room
        self.alarm_modes = set(list_option(options, "alarm_modes"))
        if not self.alarm_modes <= set(ARM_FEATURES):
            raise ValueError("alarm_modes conté un mode no admès.")
        self.arm_code = options.get("alarm_arm_code", "unknown")
        self.disarm_code = options.get("alarm_disarm_code", "unknown")
        if not isinstance(self.arm_code, str) or not isinstance(self.disarm_code, str) or self.arm_code not in {"required", "none", "unknown"} or self.disarm_code not in {"required", "none", "unknown"}:
            raise ValueError("La política del codi d'alarma és invàlida.")
        cert, key = options.get("tls_certfile", ""), options.get("tls_keyfile", "")
        if not isinstance(cert, str) or not isinstance(key, str) or bool(cert) != bool(key):
            raise ValueError("TLS requereix el certificat i la clau, o tots dos camps buits.")
        if cert:
            for filename in (cert, key):
                if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_.-]{0,127}", filename):
                    raise ValueError("Els fitxers TLS han de ser noms simples dins de /ssl.")
                if (Path("/ssl") / filename).resolve().parent != Path("/ssl").resolve():
                    raise ValueError("Els fitxers TLS han de romandre dins de /ssl.")
            self.tls_cert, self.tls_key = str(Path("/ssl") / cert), str(Path("/ssl") / key)

    @property
    def scheme(self):
        return "https" if self.tls_cert else "http"

    def pin_digest(self, pin):
        return hashlib.pbkdf2_hmac("sha256", pin.encode("ascii"), self.pin_salt, 200000)

    def check_pin(self, pin):
        return isinstance(pin, str) and bool(re.fullmatch(r"[0-9]{6,8}", pin)) and hmac.compare_digest(
            self.pin_hash, self.pin_digest(pin))

    def check_app_token(self, token):
        """The native app authenticates with the panel PIN (or the optional app_token) as a bearer token."""
        if not isinstance(token, str):
            return False
        if re.fullmatch(r"[0-9]{6,8}", token):
            return bool(self.pin_bearer_hash) and hmac.compare_digest(
                self.pin_bearer_hash, hmac.new(self.pin_salt, token.encode("ascii"), hashlib.sha256).digest())
        return (bool(self.app_token_hash) and bool(re.fullmatch(APP_TOKEN_PATTERN, token))
                and hmac.compare_digest(self.app_token_hash, hashlib.sha256(token.encode("ascii")).digest()))

    def allows_client(self, address):
        try:
            client = ipaddress.ip_address(address)
            return any(client.version == network.version and client in network for network in self.allowed_networks)
        except ValueError:
            return False


class NoRedirect(request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class HAClient:
    def __init__(self, token):
        if not isinstance(token, str) or not token:
            raise ValueError("Falta SUPERVISOR_TOKEN. Executeu el servei com a app de Home Assistant OS.")
        self._token = token
        self._opener = request.build_opener(request.ProxyHandler({}), NoRedirect())

    def _request(self, path, payload=None):
        data = None if payload is None else json.dumps(payload, allow_nan=False).encode("utf-8")
        req = request.Request(UPSTREAM + path, data=data, headers={
            "Authorization": "Bearer " + self._token,
            "Content-Type": "application/json", "Accept": "application/json"})
        try:
            with self._opener.open(req, timeout=4) as response:
                raw = response.read(4 * 1024 * 1024 + 1)
                if len(raw) > 4 * 1024 * 1024:
                    raise PublicError("La resposta de Home Assistant supera el límit admès.", 502)
                return json.loads(raw.decode("utf-8"))
        except error.HTTPError as exc:
            status = exc.code
            exc.close()
            if status in (401, 403):
                raise PublicError("Home Assistant ha denegat l'accés. Reviseu el permís de l'app.", 502) from None
            if payload is not None:
                raise PublicError("Home Assistant ha rebutjat l'ordre. Comproveu l'estat abans de repetir-la.", 502) from None
            raise PublicError("No s'ha pogut llegir Home Assistant.", 502) from None
        except (error.URLError, TimeoutError, OSError, ValueError, UnicodeError):
            message = ("No es pot confirmar l'ordre. Comproveu l'estat a Home Assistant abans de repetir-la."
                       if payload is not None else "No hi ha connexió amb Home Assistant.")
            raise PublicError(message, 502) from None

    def snapshot(self, by_id=None):
        # Independent reads run together so a failing upstream does not incur
        # three consecutive network timeouts on an old browser.
        with ThreadPoolExecutor(max_workers=3) as pool:
            futures = [pool.submit(self._request, path) for path in ("/states", "/services", "/config")]
            states, services, config = [future.result() for future in futures]
        if not isinstance(states, list) or not isinstance(services, list) or not isinstance(config, dict):
            raise PublicError("La resposta de Home Assistant no té el format esperat.", 502)
        entity_map = by_id if by_id is not None else BY_ID
        indexed = {item["entity_id"]: item for item in states if isinstance(item, dict)
                   and isinstance(item.get("entity_id"), str) and item["entity_id"] in entity_map}
        available = {}
        for group in services:
            if isinstance(group, dict) and isinstance(group.get("domain"), str) and isinstance(group.get("services"), dict):
                available[group["domain"]] = group["services"]
        version = config.get("version")
        return indexed, available, version if short_string(version, 60) else None

    def call(self, domain, service, payload):
        self._request("/services/" + domain + "/" + service, payload)

    def history(self, entity_ids, hours):
        end = datetime.datetime.now(datetime.timezone.utc)
        start = end - datetime.timedelta(hours=hours)
        query = parse.urlencode({"filter_entity_id": ",".join(entity_ids), "end_time": end.isoformat(),
                                 "minimal_response": "", "no_attributes": ""})
        return self._request("/history/period/" + parse.quote(start.isoformat()) + "?" + query)

    def watch_states(self, entity_ids, on_state_change, on_connection, stop_event):
        retry = 2
        while not stop_event.is_set():
            connected = False
            try:
                with websocket_connect("ws://supervisor/core/websocket", open_timeout=8,
                                       ping_interval=20, ping_timeout=20, close_timeout=2,
                                       max_size=4 * 1024 * 1024, compression=None,
                                       proxy=False) as websocket:
                    greeting = json.loads(websocket.recv(timeout=8))
                    if not isinstance(greeting, dict) or greeting.get("type") != "auth_required":
                        raise ValueError("Invalid WebSocket greeting")
                    websocket.send(json.dumps({"type": "auth", "access_token": self._token}))
                    auth = json.loads(websocket.recv(timeout=8))
                    if not isinstance(auth, dict) or auth.get("type") != "auth_ok":
                        raise ValueError("Home Assistant WebSocket authentication failed")
                    websocket.send(json.dumps({"id": 2, "type": "subscribe_entities",
                                               "entity_ids": sorted(entity_ids)}))
                    subscription = json.loads(websocket.recv(timeout=8))
                    if not isinstance(subscription, dict) or subscription.get("id") != 2 or subscription.get("success") is not True:
                        raise ValueError("Home Assistant state subscription failed")
                    connected = True
                    retry = 2
                    on_connection(True)
                    while not stop_event.is_set():
                        try:
                            message = json.loads(websocket.recv(timeout=1))
                        except TimeoutError:
                            continue
                        if isinstance(message, dict) and message.get("type") == "event" and message.get("id") == 2:
                            on_state_change(None)
            except Exception:
                # Reconnect quietly; never include upstream messages or credentials in logs.
                pass
            finally:
                if connected:
                    on_connection(False)
            if not stop_event.is_set():
                stop_event.wait(retry)
                retry = min(retry * 2, 30)


def filtered_attributes(domain, raw):
    """Never pass arbitrary HA attributes (tokens, pictures, URLs, codes) through."""
    result = {}
    if not isinstance(raw, dict):
        return result
    for key in ATTRS.get(domain, set()) | {"friendly_name"}:
        value = raw.get(key)
        if key not in raw:
            continue
        numeric = {"supported_features", "brightness", "color_temp_kelvin", "min_color_temp_kelvin",
                   "max_color_temp_kelvin", "current_temperature", "percentage", "percentage_step", "volume_level"}
        boolean = {"code_arm_required", "is_volume_muted"}
        lists = {"supported_color_modes", "operation_list", "lights"}
        if value is None:
            result[key] = value
        elif key in numeric and number(value):
            result[key] = value
        elif key in boolean and isinstance(value, bool):
            result[key] = value
        elif key not in numeric | boolean | lists and short_string(value, 256):
            result[key] = value
        elif key in lists and isinstance(value, list) and len(value) <= 128 and all(short_string(v, 160) for v in value):
            if key == "lights":
                result[key] = [v for v in value if re.fullmatch(r"light\.[a-z0-9_]+", v)]
            else:
                result[key] = value[:]
    return result


def service_exists(services, domain, service):
    return isinstance(services.get(domain), dict) and isinstance(services[domain].get(service), dict)


def service_field(services, domain, service, field):
    """Services may expose additional_fields nested groups in recent HA versions."""
    if not service_exists(services, domain, service):
        return False

    def search(fields, depth=0):
        if not isinstance(fields, dict) or depth > 5:
            return False
        if field in fields:
            return True
        return any(isinstance(value, dict) and search(value.get("fields"), depth + 1) for value in fields.values())

    return search(services[domain][service].get("fields"))


def service_has_extra_fields(services, domain, service):
    """Generic service buttons are safe only when entity_id is the sole input."""
    if not service_exists(services, domain, service):
        return True

    def inspect(fields, depth=0):
        if not isinstance(fields, dict) or depth > 5:
            return True
        for key, value in fields.items():
            if key == "entity_id":
                continue
            if key != "fields" or not isinstance(value, dict) or inspect(value, depth + 1):
                return True
        return False

    return inspect(services[domain][service].get("fields", {}))


def controls_for(item, state, attrs, services, settings):
    controls = []
    domain, entity_id = item["domain"], item["entity_id"]
    features = attrs.get("supported_features", 0)
    features = features if isinstance(features, int) and not isinstance(features, bool) and features >= 0 else 0

    def add(action, label, kind="button", service=None, field=None, blocker=None, **extra):
        service = service or action
        if not service_exists(services, domain, service) or (field and not service_field(services, domain, service, field)):
            return
        reason = blocker
        if not reason and entity_id + ":" + action not in settings.verified:
            reason = "Pendent de prova real i d'autorització a verified_actions."
        controls.append(dict(action=action, label=label, kind=kind, enabled=not bool(reason), reason=reason, **extra))

    if domain == "light":
        if state not in {"on", "off"}:
            return controls
        add("turn_on", "Encendre")
        add("turn_off", "Apagar")
        modes = attrs.get("supported_color_modes")
        modes = set(modes) if isinstance(modes, list) and all(isinstance(v, str) for v in modes) else set()
        if modes & {"brightness", "color_temp", "hs", "xy", "rgb", "rgbw", "rgbww"}:
            value = attrs.get("brightness")
            add("brightness", "Brillantor", "range", "turn_on", "brightness", min=1, max=255, step=1,
                value=value if number(value) and 1 <= value <= 255 else None)
        low, high = attrs.get("min_color_temp_kelvin"), attrs.get("max_color_temp_kelvin")
        if "color_temp" in modes and number(low) and number(high) and 500 <= low < high <= 40000:
            value = attrs.get("color_temp_kelvin")
            add("color_temp_kelvin", "Temperatura de color (K)", "range", "turn_on", "color_temp_kelvin",
                min=math.ceil(low), max=math.floor(high), step=1,
                value=value if number(value) and low <= value <= high else None)
    elif domain in {"switch", "input_boolean"} and state in {"on", "off"}:
        add("turn_on", "Activar")
        add("turn_off", "Desactivar")
    elif domain == "scene":
        add("turn_on", "Activar escena")
    elif domain == "alarm_control_panel":
        if state not in {"disarmed", "armed_home", "armed_away", "armed_night", "armed_vacation",
                         "armed_custom_bypass", "pending", "arming", "disarming", "triggered"}:
            return controls
        for action, (feature, label) in ARM_FEATURES.items():
            if features & feature:
                blocker = None
                if action not in settings.alarm_modes:
                    blocker = "Cal confirmar aquest mode a alarm_modes."
                elif settings.arm_code == "unknown":
                    blocker = "Cal confirmar si Alarmo exigeix codi per armar."
                elif attrs.get("code_arm_required") is True and settings.arm_code != "required":
                    blocker = "Alarmo exigeix codi: corregiu alarm_arm_code."
                elif settings.arm_code == "none" and attrs.get("code_arm_required") is not False:
                    blocker = "L'atribut code_arm_required no confirma armament sense codi."
                if settings.arm_code == "required" and not service_field(services, domain, action, "code"):
                    blocker = "El servei no publica el camp de codi."
                add(action, label, "alarm", blocker=blocker, requires_code=settings.arm_code == "required")
        blocker = None
        if settings.disarm_code == "unknown":
            blocker = "Cal confirmar si Alarmo exigeix codi per desarmar."
        elif settings.disarm_code == "none" and attrs.get("code_format") is not None:
            blocker = "Alarmo publica un format de codi: confirmeu la política abans de desarmar."
        elif settings.disarm_code == "required" and not service_field(services, domain, "alarm_disarm", "code"):
            blocker = "El servei no publica el camp de codi."
        add("alarm_disarm", "Desarmar", "alarm", blocker=blocker, requires_code=settings.disarm_code == "required")
    elif domain == "water_heater":
        modes = attrs.get("operation_list")
        if features & 2 and isinstance(modes, list) and modes and all(short_string(v, 100) and v for v in modes):
            add("set_operation_mode", "Mode d'operació", "select", field="operation_mode",
                options=list(dict.fromkeys(modes)), value=attrs.get("operation_mode"))
    elif domain == "fan" and state in {"on", "off"}:
        if features & 32:
            add("turn_on", "Encendre")
        if features & 16:
            add("turn_off", "Apagar")
        if features & 1:
            value, step = attrs.get("percentage"), attrs.get("percentage_step")
            add("set_percentage", "Velocitat (%)", "range", field="percentage", min=0, max=100,
                step=step if number(step) and 0 < step <= 100 else 1,
                value=value if number(value) and 0 <= value <= 100 else None)
    elif domain == "media_player":
        if state not in {"off", "on", "idle", "playing", "paused", "buffering", "standby"}:
            return controls
        for action, feature, label in [("turn_on", 128, "Encendre"), ("turn_off", 256, "Apagar"),
                                       ("media_play", 16384, "Reproduir"), ("media_pause", 1, "Pausa")]:
            if features & feature:
                add(action, label)
        if features & 4:
            value = attrs.get("volume_level")
            add("volume_set", "Volum", "range", field="volume_level", min=0, max=1, step=0.01,
                value=value if number(value) and 0 <= value <= 1 else None)
    standard = ACTION_NAMES.get(domain, set())
    for verified in settings.verified:
        entity_id, separator, action = verified.partition(":")
        if (separator and entity_id == item["entity_id"] and action not in standard
                and service_exists(services, domain, action)
                and not service_has_extra_fields(services, domain, action)):
            label = " ".join(part.capitalize() for part in action.split("_"))
            add(action, label)
    return controls


def entities_for(states, services, settings, connected):
    entities = []
    for item in settings.catalog:
        entity = dict(item, room=settings.room_assignments.get(item["entity_id"]), state=None,
                      status="pending", attributes={}, controls=[])
        if connected:
            raw = states.get(item["entity_id"])
            if raw is None:
                entity["status"] = "missing"
            else:
                value = raw.get("state")
                entity["state"] = value if short_string(value, 256) else None
                entity["status"] = value if value in ("unavailable", "unknown") else ("ok" if entity["state"] is not None else "unknown")
                entity["attributes"] = filtered_attributes(item["domain"], raw.get("attributes"))
                if item["domain"] == "sensor" and entity["attributes"].get("device_class") in {"temperature", "humidity"}:
                    entity["category"] = "climate"
                friendly_name = entity["attributes"].get("friendly_name")
                if short_string(friendly_name, 120) and friendly_name.strip():
                    entity["name"] = friendly_name.strip()
                if entity["status"] == "ok":
                    entity["controls"] = controls_for(item, value, entity["attributes"], services, settings)
        entities.append(entity)
    return entities


def action_payload(entity, body):
    if not isinstance(body, dict) or set(body) - {"entity_id", "action", "value", "code"}:
        raise PublicError("La petició conté camps no admesos.")
    action = body.get("action")
    control = next((c for c in entity["controls"] if c["action"] == action), None)
    if not control or not control["enabled"]:
        raise PublicError("Control no verificat o no disponible en l'estat actual.", 403)
    payload = {"entity_id": entity["entity_id"]}
    service = action
    if control["kind"] == "range":
        value = body.get("value")
        if not number(value) or not control["min"] <= value <= control["max"]:
            raise PublicError("El valor és fora dels límits publicats per l'entitat.")
        if action in {"brightness", "color_temp_kelvin", "set_percentage"} and value != int(value):
            raise PublicError("Aquest control requereix un valor enter.")
        field = {"brightness": "brightness", "color_temp_kelvin": "color_temp_kelvin",
                 "set_percentage": "percentage", "volume_set": "volume_level"}[action]
        payload[field] = value
        if entity["domain"] == "light":
            service = "turn_on"
    elif control["kind"] == "select":
        if not isinstance(body.get("value"), str) or body["value"] not in control["options"]:
            raise PublicError("El mode no figura entre les opcions actuals de l'entitat.")
        payload["operation_mode"] = body["value"]
    elif "value" in body:
        raise PublicError("Aquesta acció no admet un valor addicional.")
    if control["kind"] == "alarm":
        if control.get("requires_code"):
            code = body.get("code")
            if not short_string(code, 64) or not code:
                raise PublicError("Introduïu el codi per a aquesta ordre.")
            if entity["attributes"].get("code_format") == "number" and not re.fullmatch(r"[0-9]+", code):
                raise PublicError("El codi ha de contenir només dígits.")
            payload["code"] = code
        elif "code" in body:
            raise PublicError("Aquesta política no admet l'enviament d'un codi.")
    elif "code" in body:
        raise PublicError("Aquest control no admet un codi.")
    return service, payload


class App:
    def __init__(self, settings, client=None):
        self.settings, self.client = settings, client
        self.sessions = {}
        self.attempts = {}
        self.lock = threading.Lock()
        self.action_lock = threading.Lock()
        self.rejected_states = {}
        self.rejected_states_lock = threading.Lock()
        self.state_updates = threading.Condition()
        self.state_revision = 0
        self.live_updates = False
        self.state_listener_stop = threading.Event()
        self.state_listener_thread = None

    def signal_state_update(self):
        with self.state_updates:
            self.state_revision += 1
            self.state_updates.notify_all()

    def set_live_updates(self, connected):
        if self.live_updates != connected:
            self.live_updates = connected
            self.signal_state_update()

    def wait_for_state_update(self, revision, timeout=20):
        with self.state_updates:
            self.state_updates.wait_for(lambda: self.state_revision > revision, timeout=timeout)
            return self.state_revision

    def start_state_listener(self):
        if (self.settings.preview or not self.client or not hasattr(self.client, "watch_states")
                or websocket_connect is None or not self.settings.by_id):
            return
        self.state_listener_thread = threading.Thread(
            target=self.client.watch_states,
            args=(set(self.settings.by_id), self.signal_state_update, self.set_live_updates, self.state_listener_stop),
            name="home-assistant-state-websocket", daemon=True)
        self.state_listener_thread.start()

    def stop_state_listener(self):
        self.state_listener_stop.set()
        with self.state_updates:
            self.state_updates.notify_all()

    def apply_rejected_states(self, entities, connected):
        if not connected:
            return
        with self.rejected_states_lock:
            for entity in entities:
                entity_id = entity["entity_id"]
                rejected_state = self.rejected_states.get(entity_id)
                if rejected_state is None:
                    continue
                if entity["status"] == "ok" and entity["state"] != rejected_state:
                    del self.rejected_states[entity_id]
                    continue
                if entity["state"] == rejected_state:
                    entity["status"] = "unavailable"
                    entity["controls"] = []

    def mark_rejected_state(self, entity):
        with self.rejected_states_lock:
            self.rejected_states[entity["entity_id"]] = entity["state"]

    def rate_limit(self, address, kind, maximum, period):
        now = time.monotonic()
        key = (address, kind)
        with self.lock:
            for old_key in list(self.attempts):
                if not self.attempts[old_key] or now - self.attempts[old_key][-1] > 300:
                    del self.attempts[old_key]
            values = [v for v in self.attempts.get(key, []) if now - v < period]
            if len(values) >= maximum or (key not in self.attempts and len(self.attempts) >= 512):
                raise PublicError("Massa intents. Espereu una estona i torneu-ho a provar.", 429)
            self.attempts[key] = values + [now]

    def new_session(self, address):
        now = time.monotonic()
        token = secrets.token_urlsafe(32)
        session = {"csrf": secrets.token_urlsafe(32), "expires": now + SESSION_SECONDS, "address": address}
        with self.lock:
            self.sessions = {k: v for k, v in self.sessions.items() if v["expires"] > now}
            if len(self.sessions) >= 32:
                oldest = min(self.sessions, key=lambda k: self.sessions[k]["expires"])
                del self.sessions[oldest]
            self.sessions[token] = session
        return token, session

    def get_session(self, token, address):
        with self.lock:
            session = self.sessions.get(token)
            if session and session["expires"] <= time.monotonic():
                del self.sessions[token]
                return None
            if session and session["address"] == address:
                return dict(session)
        return None

    def state(self, audit=False):
        states, services, version = {}, {}, None
        connected = False
        failure = "Previsualització local: sense connexió amb Home Assistant." if self.settings.preview else None
        if self.settings.demo_lights:
            states = {"light.demo_" + room["id"]: {
                "state": "on" if index % 3 == 0 else "off",
                "attributes": {"friendly_name": "Llum del " + room["name"].lower()}}
                for index, room in enumerate(ROOMS)}
            failure = None
        elif not self.settings.preview:
            try:
                states, services, version = self.client.snapshot(self.settings.by_id)
                connected = True
            except PublicError as exc:
                failure = exc.message
        entities = entities_for(states, services, self.settings, connected or self.settings.demo_lights)
        self.apply_rejected_states(entities, connected)
        result = {"connected": connected, "preview": self.settings.preview, "demo": self.settings.demo_lights,
                  "live_updates": self.live_updates,
                  "fetched_at": datetime.datetime.now(datetime.timezone.utc).isoformat() if connected else None,
                  "error": failure, "version": version, "rooms": ROOMS,
                  "transport": self.settings.scheme,
                  "entities": entities}
        if audit:
            result["verification"] = {
                "rule": "Atributs actuals + servei disponible + prova real autoritzada a verified_actions.",
                "alarm_arm_code": self.settings.arm_code,
                "alarm_disarm_code": self.settings.disarm_code,
                "alarm_modes": sorted(self.settings.alarm_modes),
                "verified_actions": sorted(self.settings.verified),
                "room_assignments": dict(self.settings.room_assignments),
                "note": "Les capacitats detectades no acrediten una prova física; no es verifica cap acció automàticament."}
        return result

    def climate_history(self, hours):
        if hours not in (6, 24, 168, 720):
            raise PublicError("El període de l'historial no és vàlid.")
        if self.settings.preview:
            return {"hours": hours, "series": {}}
        states, services, _ = self.client.snapshot(self.settings.by_id)
        sensors = [item["entity_id"] for item in entities_for(states, services, self.settings, True)
                   if item["category"] == "climate"]
        series = {entity_id: [] for entity_id in sensors}
        if not sensors:
            return {"hours": hours, "series": series}
        history = self.client.history(sensors, hours)
        if not isinstance(history, list):
            raise PublicError("L'historial de Home Assistant no té el format esperat.", 502)
        for group in history:
            if not isinstance(group, list):
                continue
            entity_id = group[0].get("entity_id") if group and isinstance(group[0], dict) else None
            if entity_id not in series:
                continue
            for row in group:
                if not isinstance(row, dict) or row.get("entity_id", entity_id) != entity_id:
                    continue
                timestamp, value = row.get("last_changed"), row.get("state")
                if not isinstance(timestamp, str) or not isinstance(value, str) or not re.fullmatch(r"-?\d+(?:\.\d+)?", value):
                    continue
                try:
                    instant = datetime.datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
                    number = float(value)
                except ValueError:
                    continue
                if instant.tzinfo is None or not math.isfinite(number):
                    continue
                series[entity_id].append({"time": instant.astimezone(datetime.timezone.utc).isoformat(),
                                          "value": number})
        for entity_id, points in series.items():
            points.sort(key=lambda point: point["time"])
            if len(points) > 181:
                step = (len(points) - 1) / 180
                series[entity_id] = [points[round(index * step)] for index in range(181)]
        return {"hours": hours, "series": series}

    def action(self, body):
        if self.settings.preview:
            raise PublicError("La previsualització és només de lectura.", 403)
        if not isinstance(body, dict) or not isinstance(body.get("entity_id"), str) or not isinstance(body.get("action"), str):
            raise PublicError("Falten l'entitat i l'acció.")
        if not action_allowed(body["entity_id"], body["action"], self.settings.by_id):
            raise PublicError("Entitat o acció fora de la llista permesa.", 403)
        if set(body) - {"entity_id", "action", "value", "code"}:
            raise PublicError("La petició conté camps no admesos.")
        with self.action_lock:
            # Read immediately before the call: a browser snapshot never authorizes a write.
            states, services, _ = self.client.snapshot(self.settings.by_id)
            entities = entities_for(states, services, self.settings, True)
            self.apply_rejected_states(entities, True)
            entity = next(item for item in entities if item["entity_id"] == body["entity_id"])
            service, payload = action_payload(entity, body)
            try:
                self.client.call(entity["domain"], service, payload)
            except PublicError:
                self.mark_rejected_state(entity)
                raise
            finally:
                # Do not retain the PIN in application state, logs or a queue.
                payload.pop("code", None)
                body.pop("code", None)
        return {"ok": True, "message": "Ordre enviada; pendent de confirmar estat."}

    def lights_action(self, body):
        if self.settings.preview:
            raise PublicError("La previsualització és només de lectura.", 403)
        if not isinstance(body, dict) or set(body) != {"entity_ids", "action"}:
            raise PublicError("La petició de llums conté camps no admesos.")
        ids, action = body["entity_ids"], body["action"]
        if (not isinstance(ids, list) or not 1 <= len(ids) <= 256
                or any(not isinstance(entity_id, str) for entity_id in ids)
                or len(set(ids)) != len(ids) or not isinstance(action, str)
                or action not in {"turn_on", "turn_off"}):
            raise PublicError("La llista de llums o l'acció és invàlida.")
        if any(self.settings.by_id.get(entity_id, {}).get("domain") != "light" for entity_id in ids):
            raise PublicError("Només es poden controlar llums configurats.", 403)
        with self.action_lock:
            states, services, _ = self.client.snapshot(self.settings.by_id)
            entities = {item["entity_id"]: item for item in entities_for(states, services, self.settings, True)}
            self.apply_rejected_states(entities.values(), True)
            calls = []
            failed, first_error = 0, None
            for entity_id in ids:
                entity = entities[entity_id]
                try:
                    service, payload = action_payload(entity, {"entity_id": entity_id, "action": action})
                    calls.append((entity, service, payload))
                except PublicError as exc:
                    failed += 1
                    if first_error is None:
                        first_error = exc.message
            succeeded = 0
            for entity, service, payload in calls:
                try:
                    self.client.call(entity["domain"], service, payload)
                    succeeded += 1
                except PublicError as exc:
                    failed += 1
                    self.mark_rejected_state(entity)
                    if first_error is None:
                        first_error = exc.message
        return {"ok": failed == 0, "succeeded": succeeded, "failed": failed,
                "error": first_error}


class Server(ThreadingHTTPServer):
    daemon_threads = True
    request_queue_size = 16
    allow_reuse_address = True

    def __init__(self, address, app):
        self.app = app
        self.tls_context = None
        self.slots = threading.BoundedSemaphore(24)
        super().__init__(address, Handler)

    def process_request(self, request_socket, client_address):
        if not self.slots.acquire(blocking=False):
            self.shutdown_request(request_socket)
            return
        try:
            super().process_request(request_socket, client_address)
        except Exception:
            self.slots.release()
            raise

    def process_request_thread(self, request_socket, client_address):
        try:
            if self.tls_context:
                # TLS handshakes are bounded and occur in a worker, never on the
                # accept loop (a stalled client cannot block every connection).
                request_socket.settimeout(8)
                request_socket = self.tls_context.wrap_socket(request_socket, server_side=True)
            super().process_request_thread(request_socket, client_address)
        except OSError:
            self.shutdown_request(request_socket)
        finally:
            self.slots.release()

    def handle_error(self, request_socket, client_address):
        # The default implementation prints tracebacks, potentially including input.
        pass


class Handler(BaseHTTPRequestHandler):
    server_version = "GlassRooms"
    sys_version = ""
    protocol_version = "HTTP/1.0"

    def setup(self):
        super().setup()
        self.connection.settimeout(10)

    def log_message(self, format_string, *args):
        pass

    def send_error(self, code, message=None, explain=None):
        self.reply({"error": "Petició HTTP no admesa."}, code)

    @property
    def app(self):
        return self.server.app

    def reply(self, data, status=200, content_type="application/json; charset=utf-8", cookie=None, cache_control="no-store"):
        payload = data if isinstance(data, bytes) else json.dumps(data, ensure_ascii=False, allow_nan=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", cache_control)
        if cache_control == "no-store":
            self.send_header("Pragma", "no-cache")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Referrer-Policy", "same-origin")
        self.send_header("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'")
        self.send_header("Connection", "close")
        if cookie:
            self.send_header("Set-Cookie", cookie)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(payload)
        self.close_connection = True

    def bearer(self):
        """Return the native-app token when the request uses one; browsers never send it."""
        values = self.headers.get_all("Authorization", [])
        if not values:
            return None
        scheme, _, token = values[0].partition(" ")
        if len(values) != 1 or scheme != "Bearer" or not token:
            raise PublicError("Capçalera d'autorització no admesa.", 401)
        return token

    def guard(self, writing=False):
        if not self.app.settings.allows_client(self.client_address[0]):
            raise PublicError("Accés restringit a la xarxa local configurada.", 403)
        hosts = self.headers.get_all("Host", [])
        try:
            valid_host = len(hosts) == 1 and authority(hosts[0]) in self.app.settings.allowed_hosts
        except ValueError:
            valid_host = False
        if not valid_host:
            raise PublicError("Host no autoritzat. Reviseu l'adreça i allowed_hosts.", 403)
        if writing and self.bearer() is None:
            # Browser writes need the same origin; bearer requests carry no ambient credential.
            origins = self.headers.get_all("Origin", [])
            refers = self.headers.get_all("Referer", [])
            expected = self.app.settings.scheme + "://" + hosts[0].lower()
            if origins:
                valid_origin = len(origins) == 1 and origins[0].lower() == expected
            else:
                valid_origin = False
                if len(refers) == 1:
                    try:
                        ref = parse.urlsplit(refers[0])
                        valid_origin = not ref.username and not ref.password and ref.scheme + "://" + ref.netloc.lower() == expected
                    except ValueError:
                        pass
            if not valid_origin:
                raise PublicError("Origen no autoritzat. Obriu el panell des de la seva adreça local.", 403)
        if parse.urlsplit(self.path).scheme or not self.path.startswith("/") or self.path.startswith("//"):
            raise PublicError("Ruta no admesa.", 400)

    def session(self, required=True):
        token = self.bearer()
        if token is not None:
            if not self.app.settings.check_app_token(token):
                self.app.rate_limit(self.client_address[0], "login", 5, 60)
                raise PublicError("PIN o token de l'app incorrecte.", 401)
            return "", {"csrf": "", "app": True}
        cookies = http.cookies.SimpleCookie()
        try:
            cookies.load(self.headers.get("Cookie", ""))
        except http.cookies.CookieError:
            cookies = http.cookies.SimpleCookie()
        token = cookies[COOKIE_NAME].value if COOKIE_NAME in cookies else ""
        session = self.app.get_session(token, self.client_address[0])
        if required and not session:
            raise PublicError("Cal iniciar sessió al panell.", 401)
        return token, session

    def cookie(self, token, expire=False):
        value = COOKIE_NAME + "=" + token + "; Path=/api; HttpOnly; SameSite=Strict; Max-Age=" + ("0" if expire else str(SESSION_SECONDS))
        if self.app.settings.tls_cert:
            value += "; Secure"
        return value

    def read_json(self):
        if self.headers.get_content_type() != "application/json":
            raise PublicError("La petició ha de ser JSON.", 415)
        lengths = self.headers.get_all("Content-Length", [])
        if len(lengths) != 1 or self.headers.get("Transfer-Encoding"):
            raise PublicError("Longitud de petició no admesa.", 400)
        try:
            size = int(lengths[0])
        except ValueError:
            raise PublicError("Longitud de petició no admesa.", 400) from None
        if size < 2 or size > MAX_BODY:
            raise PublicError("La petició supera el límit admès.", 413)
        try:
            raw = self.rfile.read(size)
            if len(raw) != size:
                raise ValueError()
            body = json.loads(raw.decode("utf-8"), parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
        except (ValueError, UnicodeError):
            raise PublicError("El JSON no és vàlid.", 400) from None
        if not isinstance(body, dict):
            raise PublicError("El JSON ha de ser un objecte.", 400)
        return body

    def dispatch_get(self):
        self.guard()
        parsed_path = parse.urlsplit(self.path)
        path = parsed_path.path
        if path == "/api/session":
            _, session = self.session(False)
            result = {"authenticated": bool(session), "preview": self.app.settings.preview}
            if session:
                result["csrf"] = session["csrf"]
            self.reply(result)
            return
        if path in {"/api/state", "/api/audit"}:
            if not self.app.settings.preview:
                self.session()
            self.app.rate_limit(self.client_address[0], "read", 90, 60)
            self.reply(self.app.state(audit=path == "/api/audit"))
            return
        if path == "/api/climate-history":
            if not self.app.settings.preview:
                self.session()
            query = parse.parse_qs(parsed_path.query, keep_blank_values=True)
            if set(query) != {"hours"} or len(query["hours"]) != 1 or query["hours"][0] not in {"6", "24", "168", "720"}:
                raise PublicError("El període de l'historial no és vàlid.")
            self.app.rate_limit(self.client_address[0], "history", 12, 60)
            self.reply(self.app.climate_history(int(query["hours"][0])))
            return
        if path == "/api/updates":
            if not self.app.settings.preview:
                self.session()
            query = parse.parse_qs(parsed_path.query, keep_blank_values=True)
            values = query.get("since", [])
            if set(query) != {"since"} or len(values) != 1 or not re.fullmatch(r"[0-9]{1,18}", values[0]):
                raise PublicError("La revisió d'actualització no és vàlida.")
            self.connection.settimeout(30)
            revision = self.app.wait_for_state_update(int(values[0]), timeout=20)
            self.reply({"revision": revision, "live_updates": self.app.live_updates})
            return
        files = {"/": ("index.html", "text/html; charset=utf-8"),
                 "/index.html": ("index.html", "text/html; charset=utf-8"),
                 "/app.js": ("app.js", "application/javascript; charset=utf-8"),
                 "/style.css": ("style.css", "text/css; charset=utf-8"),
                 "/boot.js": ("boot.js", "application/javascript; charset=utf-8"),
                 "/diagnostics.html": ("diagnostics.html", "text/html; charset=utf-8"),
                 "/diagnostics.js": ("diagnostics.js", "application/javascript; charset=utf-8")}
        files.update({"/assets/" + room + ".svg": ("assets/" + room + ".svg", "image/svg+xml") for room in ROOM_IDS})
        if path not in files:
            raise PublicError("Recurs no trobat.", 404)
        filename, kind = files[path]
        target = ROOT / filename
        # Whitelist plus resolution check prevents a symlink from exposing /data or /ssl.
        if not target.resolve().is_relative_to(ROOT.resolve()) or not target.is_file():
            raise PublicError("Recurs no trobat.", 404)
        self.reply(target.read_bytes(), content_type=kind,
                   cache_control="public, max-age=86400" if kind == "image/svg+xml" else "no-store")

    def dispatch_post(self):
        self.guard(writing=True)
        if self.app.settings.preview:
            raise PublicError("La previsualització és només de lectura.", 403)
        path = parse.urlsplit(self.path).path
        if path not in {"/api/login", "/api/logout", "/api/action", "/api/lights"}:
            raise PublicError("Recurs no trobat.", 404)
        if path in {"/api/login", "/api/logout"} and self.bearer() is not None:
            raise PublicError("L'app nativa no utilitza sessions de navegador.", 400)
        if path == "/api/login":
            self.app.rate_limit(self.client_address[0], "login", 5, 60)
            body = self.read_json()
            if set(body) != {"pin"} or not self.app.settings.check_pin(body.get("pin")):
                raise PublicError("PIN incorrecte.", 401)
            previous, _ = self.session(False)
            with self.app.lock:
                self.app.sessions.pop(previous, None)
            token, session = self.app.new_session(self.client_address[0])
            self.reply({"authenticated": True, "csrf": session["csrf"]}, cookie=self.cookie(token))
            return
        token, session = self.session()
        csrf = self.headers.get_all("X-CSRF-Token", [])
        if not session.get("app") and (len(csrf) != 1 or not hmac.compare_digest(csrf[0], session["csrf"])):
            raise PublicError("La sessió ha canviat. Torneu a carregar el panell.", 403)
        body = self.read_json()
        if path == "/api/logout":
            if body:
                raise PublicError("La sortida de sessió no admet camps.")
            with self.app.lock:
                self.app.sessions.pop(token, None)
            self.reply({"authenticated": False}, cookie=self.cookie("", expire=True))
            return
        item = self.app.settings.by_id.get(body.get("entity_id")) if isinstance(body, dict) and isinstance(body.get("entity_id"), str) else None
        action = body.get("action") if isinstance(body, dict) else None
        light_toggle = path == "/api/lights" or (item and item["domain"] == "light" and isinstance(action, str) and action in {"turn_on", "turn_off"})
        self.app.rate_limit(self.client_address[0], "light_action" if light_toggle else "action", 120 if light_toggle else 30, 60)
        self.reply(self.app.lights_action(body) if path == "/api/lights" else self.app.action(body))

    def do_GET(self):
        self.execute(self.dispatch_get)

    def do_HEAD(self):
        self.execute(self.dispatch_get)

    def do_POST(self):
        self.execute(self.dispatch_post)

    def execute(self, operation):
        try:
            operation()
        except PublicError as exc:
            self.reply({"error": exc.message}, exc.status)
        except (BrokenPipeError, ConnectionResetError, socket.timeout):
            self.close_connection = True
        except Exception:
            # Generic message deliberately excludes exception/input/upstream details.
            self.reply({"error": "Error intern; cap resultat no es pot confirmar. Reviseu l'estat abans de repetir."}, 500)


def main():
    parser = argparse.ArgumentParser(description="Glass Rooms · panell local de Home Assistant")
    parser.add_argument("--preview", action="store_true", help="Només loopback, sense dades ni accions reals")
    parser.add_argument("--lan-preview", action="store_true", help="Previsualització només lectura accessible des de la LAN privada")
    parser.add_argument("--lan-address", help="Adreça IPv4 LAN del servidor per a --lan-preview")
    parser.add_argument("--demo-lights", action="store_true", help="Llums ficticis configurats a les vuit estances; només amb --preview")
    parser.add_argument("--port", type=int, default=8099)
    args = parser.parse_args()
    if args.lan_preview:
        args.preview = True
    if args.demo_lights and not args.preview:
        parser.error("--demo-lights requereix --preview o --lan-preview.")
    if not 1 <= args.port <= 65535:
        parser.error("El port ha d'estar entre 1 i 65535.")
    try:
        if args.preview:
            lan_address = args.lan_address
            if args.lan_preview:
                # Select the IPv4 address used for the default route on macOS/Linux.
                if not lan_address:
                    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    try:
                        probe.connect(("192.0.2.1", 80))
                        lan_address = probe.getsockname()[0]
                    finally:
                        probe.close()
            settings = Settings({}, preview=True, port=args.port, lan_preview=args.lan_preview,
                                lan_address=lan_address, demo_lights=args.demo_lights)
            client = None
        else:
            with open("/data/options.json", "r", encoding="utf-8") as stream:
                raw = stream.read(128 * 1024 + 1)
                if len(raw) > 128 * 1024:
                    raise ValueError("La configuració supera el límit admès.")
                options = json.loads(raw)
            settings = Settings(options)
            options.clear()
            raw = ""
            client = HAClient(os.environ.get("SUPERVISOR_TOKEN"))
        app = App(settings, client)
        app.start_state_listener()
        server = Server(("0.0.0.0" if args.lan_preview or not args.preview else "127.0.0.1", args.port), app)
        if settings.tls_cert:
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.minimum_version = ssl.TLSVersion.TLSv1_2
            context.load_cert_chain(settings.tls_cert, settings.tls_key)
            server.tls_context = context
    except (OSError, ValueError, ssl.SSLError) as exc:
        # Configuration errors from our code contain only fixed diagnostics; JSON and
        # SSL/parser exceptions can include paths/content, so keep them generic.
        message = str(exc) if type(exc) is ValueError and not isinstance(exc, json.JSONDecodeError) else "No s'ha pogut carregar la configuració, obrir el port o iniciar TLS."
        print("Glass Rooms: " + message, flush=True)
        return 1
    print("Glass Rooms iniciat: " + ("previsualització LAN, només lectura." if args.lan_preview else
                                      "previsualització local, només lectura." if args.preview else
                                      "accés restringit a la LAN configurada."), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.app.stop_state_listener()
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
