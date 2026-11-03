"""Local deterministic tests. Fixtures are synthetic and never contact HA/devices."""

import copy
import http.client
import io
import json
import secrets
import shutil
import socket
import ssl
import subprocess
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

from glass_rooms.catalog import BY_ID, CATALOG, ROOM_IDS
from glass_rooms.server import (
    App, HAClient, PublicError, Server, Settings, action_payload,
    entities_for, filtered_attributes, service_field,
)

LIGHT = "light.test_cuina"
ALARM = "alarm_control_panel.test_alarm"
WATER = "water_heater.test_water"
FAN = "fan.test_fan"
PLAYER = "media_player.test_player"
SHOWERS = "sensor.test_showers"


def config(**extra):
    options = {"panel_pin": "12345678",
               "allowed_hosts": ["127.0.0.1:8099"],
               "allowed_networks": ["127.0.0.0/8"],
               "light_entity_ids": [LIGHT],
               "entity_ids": [ALARM, WATER, FAN, PLAYER, SHOWERS]}
    options.update(extra)
    return options


def services(domain, **actions):
    return {domain: {action: {"fields": {field: {} for field in fields}} for action, fields in actions.items()}}


def raw(entity_id, state="on", **attrs):
    return {entity_id: {"entity_id": entity_id, "state": state, "attributes": attrs}}


def entity(entity_id, settings, states, available):
    return next(item for item in entities_for(states, available, settings, True) if item["entity_id"] == entity_id)


class FakeHA:
    def __init__(self, states=None, available=None):
        self.states = states or raw(LIGHT, supported_color_modes=["onoff"])
        self.available = available or services("light", turn_on=[], turn_off=[])
        self.calls = []
        self.reads = 0
        self.failure = None

    def snapshot(self, by_id=None):
        self.reads += 1
        if self.failure:
            raise self.failure
        return copy.deepcopy(self.states), copy.deepcopy(self.available), "test-fixture-version"

    def call(self, domain, service, payload):
        self.calls.append((domain, service, copy.deepcopy(payload)))


class ConfigurationTests(unittest.TestCase):
    def test_defaults_refuse_to_start(self):
        for options in [{}, config(panel_pin=""), config(allowed_hosts=[]), config(allowed_networks=[])]:
            with self.subTest(options=list(options)):
                with self.assertRaises(ValueError):
                    Settings(options)

    def test_networks_must_be_explicit_private_cidrs(self):
        for network in ["0.0.0.0/0", "::/0", "8.8.8.0/24", "192.168.1.3/24", "169.254.0.0/16"]:
            with self.subTest(network=network), self.assertRaises(ValueError):
                Settings(config(allowed_networks=[network]))
        settings = Settings(config(allowed_networks=["10.42.0.0/24"]))
        self.assertTrue(settings.allows_client("10.42.0.36"))
        self.assertFalse(settings.allows_client("10.42.1.36"))
        self.assertFalse(settings.allows_client("8.8.8.8"))

    def test_invalid_hosts_and_options_fail_closed(self):
        for host in ["http://10.42.0.36:8099", "*", "good.local@evil.local", "localhost:abc", "localhost:8099/path"]:
            with self.subTest(host=host), self.assertRaises(ValueError):
                Settings(config(allowed_hosts=[host]))
        with self.assertRaises(ValueError):
            Settings(config(alarm_arm_code=[]))
        with self.assertRaises(ValueError):
            Settings(config(unknown_option=True))

    def test_explicit_catalog_only_actions_and_rooms(self):
        for verification in ["light.new_light:turn_on", "script.unknown:turn_on",
                             LIGHT + ":bad-action", LIGHT + ":", LIGHT]:
            with self.subTest(verification=verification), self.assertRaises(ValueError):
                Settings(config(verified_actions=[verification]))
        with self.assertRaises(ValueError):
            Settings(config(room_assignments=[LIGHT + ":kitchen"]))
        with self.assertRaises(ValueError):
            Settings(config(room_assignments=[LIGHT + ":cuina", LIGHT + ":menjador"]))
        settings = Settings(config(room_assignments=[LIGHT + ":cuina"]))
        self.assertEqual(settings.room_assignments, {LIGHT: "cuina"})

    def test_tls_paths_require_pair_and_ssl_basename(self):
        for values in [{"tls_certfile": "cert.pem"}, {"tls_certfile": "../cert.pem", "tls_keyfile": "key.pem"},
                       {"tls_certfile": "/ssl/cert.pem", "tls_keyfile": "key.pem"}]:
            with self.subTest(values=values), self.assertRaises(ValueError):
                Settings(config(**values))
        settings = Settings(config(tls_certfile="cert.pem", tls_keyfile="key.pem"))
        self.assertEqual(settings.scheme, "https")
        self.assertEqual(settings.tls_key, "/ssl/key.pem")

    def test_pin_is_hashed_not_retained(self):
        options = config()
        settings = Settings(options)
        self.assertTrue(settings.check_pin(options["panel_pin"]))
        self.assertFalse(settings.check_pin("87654321"))
        self.assertNotIn(options["panel_pin"], repr(settings.__dict__))
        for invalid in ("12345", "123456789", "12a456", "１２３４５６", 123456):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                Settings(config(panel_pin=invalid))
        with self.assertRaises(ValueError):
            Settings(config(panel_password="old-secret-value"))


class CapabilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.settings = Settings(config())

    def test_catalog_is_exact_and_unassigned(self):
        self.assertEqual(len(CATALOG), 1)
        self.assertEqual(len(BY_ID), len(CATALOG))
        self.assertEqual(len(ROOM_IDS), 8)
        self.assertEqual(len(self.settings.catalog), 6)
        snapshot = App(Settings({}, preview=True)).state()
        self.assertFalse(snapshot["connected"])
        self.assertTrue(snapshot["preview"])
        for item in snapshot["entities"]:
            self.assertIsNone(item["room"])
            self.assertIsNone(item["state"])
            self.assertEqual(item["controls"], [])
            self.assertEqual(item["status"], "pending")

    def test_three_way_gate_requires_live_capability_service_and_verification(self):
        states = raw(LIGHT, supported_color_modes=["brightness"], brightness=100)
        available = services("light", turn_on=["brightness"], turn_off=[])
        item = entity(LIGHT, self.settings, states, available)
        controls = {c["action"]: c for c in item["controls"]}
        self.assertIn("brightness", controls)
        self.assertTrue(all(not c["enabled"] for c in controls.values()))
        reviewed = Settings(config(verified_actions=[LIGHT + ":brightness"]))
        item = entity(LIGHT, reviewed, states, available)
        self.assertTrue(next(c for c in item["controls"] if c["action"] == "brightness")["enabled"])
        no_service = entity(LIGHT, reviewed, states, {})
        self.assertEqual(no_service["controls"], [])
        no_feature = entity(LIGHT, reviewed, raw(LIGHT, supported_color_modes=["onoff"]), available)
        self.assertNotIn("brightness", [c["action"] for c in no_feature["controls"]])

    def test_service_field_supports_nested_current_ha_descriptions(self):
        available = {"light": {"turn_on": {"fields": {"additional_fields": {"fields": {"brightness": {}}}}}}}
        self.assertTrue(service_field(available, "light", "turn_on", "brightness"))
        self.assertFalse(service_field(available, "light", "turn_on", "color_temp_kelvin"))

    def test_color_temperature_needs_actual_mode_bounds_and_service_field(self):
        available = services("light", turn_on=["color_temp_kelvin"])
        good = raw(LIGHT, supported_color_modes=["color_temp"], min_color_temp_kelvin=2000, max_color_temp_kelvin=6000)
        self.assertIn("color_temp_kelvin", [c["action"] for c in entity(LIGHT, self.settings, good, available)["controls"]])
        for attrs in [dict(supported_color_modes=["rgb"], min_color_temp_kelvin=2000, max_color_temp_kelvin=6000),
                      dict(supported_color_modes=["color_temp"]),
                      dict(supported_color_modes=["color_temp"], min_color_temp_kelvin=6000, max_color_temp_kelvin=2000)]:
            item = entity(LIGHT, self.settings, raw(LIGHT, **attrs), available)
            self.assertNotIn("color_temp_kelvin", [c["action"] for c in item["controls"]])

    def test_unavailable_unknown_missing_have_no_controls(self):
        available = services("light", turn_on=[], turn_off=[])
        for state in ["unavailable", "unknown"]:
            item = entity(LIGHT, self.settings, raw(LIGHT, state), available)
            self.assertEqual(item["status"], state)
            self.assertEqual(item["controls"], [])
        self.assertEqual(entity(LIGHT, self.settings, {}, available)["status"], "missing")

    def test_only_safe_typed_attributes_leave_server(self):
        filtered = filtered_attributes("light", {
            "supported_color_modes": ["color_temp"], "brightness": 80,
            "access_token": "fixture-secret", "entity_picture": "https://remote/secret",
            "password": "fixture-secret", "code": "fixture-secret", "min_color_temp_kelvin": float("nan"),
            "max_color_temp_kelvin": "wrong-type"})
        self.assertEqual(filtered, {"supported_color_modes": ["color_temp"], "brightness": 80})
        adaptive = filtered_attributes("switch", {"lights": [LIGHT, "https://remote/secret", "switch.unknown"]})
        self.assertEqual(adaptive, {"lights": [LIGHT]})

    def test_configured_generic_sensor_preserves_short_states(self):
        for state in ["0", "2.5", "not-a-reading"]:
            item = entity(SHOWERS, self.settings, raw(SHOWERS, state), {})
            self.assertEqual(item["state"], state)
            self.assertEqual(item["status"], "ok")
        for state in ["unavailable", "unknown"]:
            self.assertEqual(entity(SHOWERS, self.settings, raw(SHOWERS, state), {})["status"], state)

    def test_temperature_and_humidity_sensors_become_climate_readings(self):
        temperature = "sensor.menjador_temperature"
        humidity = "sensor.menjador_humidity"
        settings = Settings(config(entity_ids=[temperature, humidity, SHOWERS], room_assignments=[
            temperature + ":menjador", humidity + ":menjador"]))
        states = {
            **raw(temperature, "21.4", device_class="temperature", unit_of_measurement="°C"),
            **raw(humidity, "48", device_class="humidity", unit_of_measurement="%"),
            **raw(SHOWERS, "3", device_class="water"),
        }
        items = {item["entity_id"]: item for item in entities_for(states, {}, settings, True)}
        self.assertEqual(items[temperature]["category"], "climate")
        self.assertEqual(items[temperature]["room"], "menjador")
        self.assertEqual(items[temperature]["state"], "21.4")
        self.assertEqual(items[temperature]["attributes"]["unit_of_measurement"], "°C")
        self.assertEqual(items[humidity]["category"], "climate")
        self.assertEqual(items[humidity]["state"], "48")
        self.assertEqual(items[SHOWERS]["category"], "other")
        self.assertEqual(items[temperature]["controls"], [])
        unavailable = entity(temperature, settings, raw(temperature, "unavailable", device_class="temperature"), {})
        self.assertEqual(unavailable["category"], "climate")
        self.assertEqual(unavailable["status"], "unavailable")

    def test_water_only_published_operation_modes(self):
        available = services("water_heater", set_operation_mode=["operation_mode"], set_temperature=["temperature"])
        item = entity(WATER, self.settings, raw(WATER, "eco", supported_features=3,
                      operation_list=["eco", "electric"], operation_mode="eco", current_temperature=52), available)
        self.assertEqual([c["action"] for c in item["controls"]], ["set_operation_mode"])
        self.assertEqual(item["controls"][0]["options"], ["eco", "electric"])

    def test_fan_feature_flags_and_media_features_are_independent(self):
        fan_services = services("fan", turn_on=[], turn_off=[], set_percentage=["percentage"])
        item = entity(FAN, self.settings, raw(FAN, supported_features=1, percentage=50), fan_services)
        self.assertEqual([c["action"] for c in item["controls"]], ["set_percentage"])
        item = entity(FAN, self.settings, raw(FAN, supported_features=48), fan_services)
        self.assertEqual({c["action"] for c in item["controls"]}, {"turn_on", "turn_off"})
        media_services = services("media_player", media_play=[], media_pause=[], volume_set=["volume_level"], turn_on=[])
        item = entity(PLAYER, self.settings, raw(PLAYER, "playing", supported_features=5, volume_level=.2), media_services)
        self.assertEqual({c["action"] for c in item["controls"]}, {"media_pause", "volume_set"})
        self.assertNotIn("Sonos", item["name"])

    def test_alarm_modes_and_code_policy_are_not_inferred_from_bits(self):
        states = raw(ALARM, "disarmed", supported_features=63, code_format="number", code_arm_required=True)
        available = services("alarm_control_panel", alarm_arm_home=["code"], alarm_arm_away=["code"],
                             alarm_disarm=["code"], alarm_trigger=[], alarm_arm_custom_bypass=[])
        verified = [ALARM + ":alarm_arm_home", ALARM + ":alarm_disarm"]
        unknown = Settings(config(verified_actions=verified))
        controls = entity(ALARM, unknown, states, available)["controls"]
        self.assertTrue(controls)
        self.assertTrue(all(not c["enabled"] for c in controls))
        self.assertNotIn("alarm_trigger", [c["action"] for c in controls])
        ready = Settings(config(verified_actions=verified, alarm_modes=["alarm_arm_home"],
                                alarm_arm_code="required", alarm_disarm_code="required"))
        controls = {c["action"]: c for c in entity(ALARM, ready, states, available)["controls"]}
        self.assertTrue(controls["alarm_arm_home"]["enabled"])
        self.assertTrue(controls["alarm_disarm"]["requires_code"])
        self.assertFalse(controls["alarm_arm_away"]["enabled"])

    def test_conflicting_alarm_code_policy_blocks_control(self):
        available = services("alarm_control_panel", alarm_arm_home=["code"], alarm_disarm=["code"])
        settings = Settings(config(verified_actions=[ALARM + ":alarm_arm_home", ALARM + ":alarm_disarm"],
                                   alarm_modes=["alarm_arm_home"], alarm_arm_code="none", alarm_disarm_code="none"))
        item = entity(ALARM, settings, raw(ALARM, "disarmed", supported_features=1,
                       code_arm_required=True, code_format="number"), available)
        self.assertTrue(all(not c["enabled"] for c in item["controls"]))


class ActionTests(unittest.TestCase):
    def setUp(self):
        self.settings = Settings(config(verified_actions=[LIGHT + ":turn_on", LIGHT + ":brightness"]))
        self.fake = FakeHA(raw(LIGHT, supported_color_modes=["brightness"], brightness=60),
                           services("light", turn_on=["brightness"], turn_off=[]))
        self.app = App(self.settings, self.fake)

    def test_action_rereads_live_state_before_sending(self):
        self.app.state()
        self.fake.states[LIGHT]["state"] = "unavailable"
        with self.assertRaises(PublicError):
            self.app.action({"entity_id": LIGHT, "action": "turn_on"})
        self.assertEqual(self.fake.reads, 2)
        self.assertEqual(self.fake.calls, [])

    def test_valid_action_maps_to_fixed_service_and_entity_only(self):
        result = self.app.action({"entity_id": LIGHT, "action": "brightness", "value": 160})
        self.assertTrue(result["ok"])
        self.assertIn("pendent", result["message"])
        self.assertEqual(self.fake.calls, [("light", "turn_on", {"entity_id": LIGHT, "brightness": 160})])

    def test_lights_action_batches_after_checking_every_light(self):
        other = "light.test_other"
        settings = Settings(config(light_entity_ids=[LIGHT, other],
                                   verified_actions=[LIGHT + ":turn_off", other + ":turn_off"]))
        fake = FakeHA({**raw(LIGHT), **raw(other)}, services("light", turn_on=[], turn_off=[]))
        app = App(settings, fake)
        result = app.lights_action({"entity_ids": [LIGHT, other], "action": "turn_off"})
        self.assertEqual(result, {"ok": True, "succeeded": 2, "failed": 0, "error": None})
        self.assertEqual(fake.reads, 1)
        self.assertEqual([call[2]["entity_id"] for call in fake.calls], [LIGHT, other])
        fake.calls.clear()
        fake.states[other]["state"] = "unavailable"
        with self.assertRaises(PublicError):
            app.lights_action({"entity_ids": [LIGHT, other], "action": "turn_off"})
        self.assertEqual(fake.calls, [])
        class FailingHA(FakeHA):
            def call(self, domain, service, payload):
                if payload["entity_id"] == other:
                    raise PublicError("La segona llum ha rebutjat l'ordre.", 503)
                super().call(domain, service, payload)
        failing = FailingHA({**raw(LIGHT), **raw(other)}, services("light", turn_off=[]))
        partial = App(settings, failing).lights_action({"entity_ids": [LIGHT, other], "action": "turn_off"})
        self.assertEqual(partial["succeeded"], 1)
        self.assertEqual(partial["failed"], 1)
        self.assertFalse(partial["ok"])
        self.assertIn("segona llum", partial["error"])

    def test_lights_action_rejects_invalid_batches(self):
        for body in ({"entity_ids": [], "action": "turn_on"},
                     {"entity_ids": [LIGHT, LIGHT], "action": "turn_on"},
                     {"entity_ids": [ALARM], "action": "turn_on"},
                     {"entity_ids": [LIGHT], "action": "toggle"},
                     {"entity_ids": [LIGHT], "action": []},
                     {"entity_ids": [LIGHT], "action": "turn_on", "code": "123456"}):
            with self.subTest(body=body), self.assertRaises(PublicError):
                self.app.lights_action(body)
        self.assertEqual(self.fake.calls, [])

    def test_bad_payloads_do_not_reach_ha(self):
        for value in [False, "100", 0, 256, 12.5, float("nan"), float("inf"), [], {}]:
            with self.subTest(value=repr(value)), self.assertRaises(PublicError):
                self.app.action({"entity_id": LIGHT, "action": "brightness", "value": value})
        for body in [{"entity_id": LIGHT, "action": "turn_on", "service": "toggle"},
                     {"entity_id": LIGHT, "action": "turn_on", "code": "fixture"},
                     {"entity_id": LIGHT, "action": "turn_on", "value": 1},
                     {"entity_id": "script.toggle_alarma", "action": "turn_on"},
                     {"entity_id": "light.unlisted", "action": "turn_on"},
                     {"entity_id": LIGHT, "action": "turn_off"}]:
            with self.subTest(body=body), self.assertRaises(PublicError):
                self.app.action(body)
        self.assertEqual(self.fake.calls, [])

    def test_operation_option_must_still_be_published(self):
        settings = Settings(config(verified_actions=[WATER + ":set_operation_mode"]))
        fake = FakeHA(raw(WATER, "eco", supported_features=2, operation_list=["eco"]),
                      services("water_heater", set_operation_mode=["operation_mode"]))
        with self.assertRaises(PublicError):
            App(settings, fake).action({"entity_id": WATER, "action": "set_operation_mode", "value": "boost"})
        self.assertEqual(fake.calls, [])

    def test_alarm_requires_code_and_does_not_retain_it(self):
        settings = Settings(config(verified_actions=[ALARM + ":alarm_disarm"], alarm_disarm_code="required"))
        fake = FakeHA(raw(ALARM, "armed_away", code_format="number"),
                      services("alarm_control_panel", alarm_disarm=["code"]))
        app = App(settings, fake)
        for body in [{"entity_id": ALARM, "action": "alarm_disarm"},
                     {"entity_id": ALARM, "action": "alarm_disarm", "code": "letters"}]:
            with self.assertRaises(PublicError):
                app.action(body)
        synthetic_code = str(secrets.randbelow(1000000)).zfill(6)
        body = {"entity_id": ALARM, "action": "alarm_disarm", "code": synthetic_code}
        app.action(body)
        self.assertEqual(fake.calls[-1][2]["code"], synthetic_code)
        self.assertNotIn("code", body)
        self.assertNotIn(synthetic_code, json.dumps(app.state(audit=True)))

    def test_disconnection_does_not_return_previous_states(self):
        self.assertTrue(self.app.state()["connected"])
        self.fake.failure = PublicError("No hi ha connexió amb Home Assistant.", 502)
        result = self.app.state()
        self.assertFalse(result["connected"])
        self.assertIsNone(result["fetched_at"])
        self.assertTrue(all(item["state"] is None and item["controls"] == [] for item in result["entities"]))

    def test_preview_rejects_actions_without_client(self):
        with self.assertRaises(PublicError):
            App(Settings({}, preview=True)).action({"entity_id": LIGHT, "action": "turn_on"})


class HTTPTests(unittest.TestCase):
    def setUp(self):
        self.options = config(verified_actions=[LIGHT + ":turn_on"])
        self.fake = FakeHA()
        self.app = App(Settings(self.options), self.fake)
        self.server = Server(("127.0.0.1", 0), self.app)
        self.port = self.server.server_address[1]
        self.host = "127.0.0.1:" + str(self.port)
        self.app.settings.allowed_hosts = {self.host}
        self.origin = "http://" + self.host
        self.thread = threading.Thread(target=self.server.serve_forever, kwargs={"poll_interval": 0.02}, daemon=True)
        self.thread.start()
        self.cookie = None
        self.csrf = None

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def call(self, path, method="GET", body=None, headers=None):
        request_headers = dict(headers or {})
        if method == "POST":
            request_headers.setdefault("Content-Type", "application/json")
            request_headers.setdefault("Origin", self.origin)
        if self.cookie:
            request_headers.setdefault("Cookie", self.cookie)
        if self.csrf:
            request_headers.setdefault("X-CSRF-Token", self.csrf)
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=3)
        conn.request(method, path, json.dumps(body) if body is not None else None, request_headers)
        response = conn.getresponse()
        payload = response.read()
        result = json.loads(payload) if response.getheader("Content-Type", "").startswith("application/json") else payload
        status, response_headers = response.status, dict(response.getheaders())
        conn.close()
        return status, result, response_headers

    def login(self):
        status, result, headers = self.call("/api/login", "POST", {"pin": self.options["panel_pin"]})
        self.assertEqual(status, 200)
        self.cookie = headers["Set-Cookie"].split(";", 1)[0]
        self.csrf = result["csrf"]
        return headers

    def test_state_and_audit_require_authentication(self):
        for path in ["/api/state", "/api/audit"]:
            self.assertEqual(self.call(path)[0], 401)
        self.assertEqual(self.call("/api/session")[1], {"authenticated": False, "preview": False})
        self.assertEqual(self.fake.reads, 0)

    def test_login_cookie_csrf_and_logout_lifecycle(self):
        headers = self.login()
        self.assertIn("HttpOnly", headers["Set-Cookie"])
        self.assertIn("SameSite=Strict", headers["Set-Cookie"])
        self.assertIn("Path=/api", headers["Set-Cookie"])
        self.assertEqual(self.call("/api/state")[0], 200)
        self.assertEqual(self.call("/api/session")[1]["csrf"], self.csrf)
        self.assertEqual(self.call("/api/logout", "POST", {})[0], 200)
        self.assertEqual(self.call("/api/state")[0], 401)

    def test_old_password_payload_does_not_log_in(self):
        status, result, _ = self.call("/api/login", "POST", {"password": self.options["panel_pin"]})
        self.assertEqual(status, 401)
        self.assertEqual(result["error"], "PIN incorrecte.")
        self.assertEqual(self.app.sessions, {})

    def test_host_and_network_guard_ignore_forwarded_headers(self):
        self.assertEqual(self.call("/api/session", headers={"Host": "evil.example"})[0], 403)
        self.app.settings.allowed_networks = []
        self.assertEqual(self.call("/api/session", headers={"X-Forwarded-For": "127.0.0.1"})[0], 403)

    def test_cross_origin_login_is_blocked_even_with_valid_pin(self):
        status = self.call("/api/login", "POST", {"pin": self.options["panel_pin"]},
                           {"Origin": "http://evil.example", "Referer": self.origin + "/"})[0]
        self.assertEqual(status, 403)
        self.assertEqual(self.app.sessions, {})

    def test_authenticated_writes_require_csrf_and_matching_origin(self):
        self.login()
        body = {"entity_id": LIGHT, "action": "turn_on"}
        self.assertEqual(self.call("/api/action", "POST", body, {"X-CSRF-Token": "incorrect"})[0], 403)
        self.assertEqual(self.call("/api/action", "POST", body, {"Origin": "null"})[0], 403)
        self.assertEqual(self.fake.calls, [])
        self.assertEqual(self.call("/api/action", "POST", body)[0], 200)
        self.assertEqual(len(self.fake.calls), 1)

    def test_light_batch_uses_one_rate_slot_and_requires_csrf(self):
        self.login()
        body = {"entity_ids": [LIGHT], "action": "turn_on"}
        self.assertEqual(self.call("/api/lights", "POST", body, {"X-CSRF-Token": "incorrect"})[0], 403)
        self.assertEqual(self.fake.calls, [])
        for _ in range(35):
            self.assertEqual(self.call("/api/lights", "POST", body)[0], 200)
        for _ in range(35):
            self.assertEqual(self.call("/api/action", "POST", {"entity_id": LIGHT, "action": "turn_on"})[0], 200)
        self.assertEqual(len(self.fake.calls), 70)

    def test_safari_referer_fallback_and_json_requirement(self):
        self.login()
        # Direct HTTP request deliberately omits Origin to exercise Safari 9 fallback.
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=3)
        conn.request("POST", "/api/action", json.dumps({"entity_id": LIGHT, "action": "turn_on"}), {
            "Content-Type": "application/json", "Referer": self.origin + "/", "Cookie": self.cookie,
            "X-CSRF-Token": self.csrf})
        response = conn.getresponse()
        self.assertEqual(response.status, 200)
        response.read()
        conn.close()
        self.assertEqual(self.call("/api/action", "POST", {}, {"Content-Type": "text/plain"})[0], 415)

    def test_session_expiry_is_absolute_and_ip_bound(self):
        self.login()
        token = self.cookie.split("=", 1)[1]
        self.assertIsNone(self.app.get_session(token, "192.168.1.10"))
        self.app.sessions[token]["expires"] = time.monotonic() - 1
        self.assertEqual(self.call("/api/state")[0], 401)

    def test_only_allowlisted_public_files_and_cache_policy(self):
        for path in ["/data/options.json", "/server.py", "/../catalog.py", "/assets/../../server.py", "/%2e%2e/server.py"]:
            self.assertEqual(self.call(path)[0], 404)
        status, _, headers = self.call("/api/session")
        self.assertEqual(status, 200)
        self.assertEqual(headers["Cache-Control"], "no-store")
        self.assertEqual(headers["X-Frame-Options"], "DENY")
        self.assertNotIn("Access-Control-Allow-Origin", headers)
        status, _, headers = self.call("/assets/cuina.svg?v=1.0.16")
        self.assertEqual(status, 200)
        self.assertEqual(headers["Cache-Control"], "public, max-age=86400")
        status, _, headers = self.call("/app.js?v=1.0.16")
        self.assertEqual(status, 200)
        self.assertEqual(headers["Cache-Control"], "no-store")

    def test_login_rate_limit_and_body_size_limit(self):
        for _ in range(5):
            self.assertEqual(self.call("/api/login", "POST", {"pin": "000000"})[0], 401)
        self.assertEqual(self.call("/api/login", "POST", {"pin": "000000"})[0], 429)
        self.app.attempts.clear()
        self.assertEqual(self.call("/api/login", "POST", {"pin": "0" * 5000})[0], 413)

    def test_http_does_not_print_pin_or_bodies(self):
        captured = io.StringIO()
        with patch("sys.stderr", captured), patch("sys.stdout", captured):
            self.login()
            self.call("/api/action", "POST", {"entity_id": ALARM, "action": "alarm_disarm", "code": "fixture-pin"})
        self.assertEqual(captured.getvalue(), "")

    def test_preview_http_has_no_real_data_and_rejects_login(self):
        self.app.settings.preview = True
        self.assertEqual(self.call("/api/state")[0], 200)
        self.assertEqual(self.call("/api/login", "POST", {"pin": self.options["panel_pin"]})[0], 403)
        self.assertEqual(self.fake.reads, 0)

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL CLI needed for ephemeral local TLS certificate")
    def test_direct_tls_sets_secure_cookie_and_handshake_does_not_block_accept(self):
        with tempfile.TemporaryDirectory(prefix="glass-rooms-tls-test-") as directory:
            cert, key = directory + "/cert.pem", directory + "/key.pem"
            subprocess.run([shutil.which("openssl"), "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                            "-keyout", key, "-out", cert, "-days", "1", "-subj", "/CN=127.0.0.1",
                            "-addext", "subjectAltName=IP:127.0.0.1"],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.minimum_version = ssl.TLSVersion.TLSv1_2
            context.load_cert_chain(cert, key)
            self.app.settings.tls_cert = cert
            self.server.tls_context = context
            stalled = socket.create_connection(("127.0.0.1", self.port), timeout=3)
            try:
                client_context = ssl.create_default_context(cafile=cert)
                conn = http.client.HTTPSConnection("127.0.0.1", self.port, context=client_context, timeout=3)
                conn.request("POST", "/api/login", json.dumps({"pin": self.options["panel_pin"]}),
                             {"Content-Type": "application/json", "Origin": "https://" + self.host})
                response = conn.getresponse()
                self.assertEqual(response.status, 200)
                self.assertIn("; Secure", response.getheader("Set-Cookie"))
                response.read()
                conn.close()
            finally:
                stalled.close()


class UpstreamTests(unittest.TestCase):
    def test_snapshot_calls_only_fixed_read_paths(self):
        client = HAClient(secrets.token_urlsafe(24))
        responses = {"/states": [{"entity_id": LIGHT, "state": "on", "attributes": {}},
                                  {"entity_id": "sensor.unlisted", "state": "private", "attributes": {}}],
                     "/services": [{"domain": "light", "services": {"turn_on": {}}}],
                     "/config": {"version": "fixture", "latitude": 1, "longitude": 2}}
        with patch.object(client, "_request", side_effect=lambda path: responses[path]) as requester:
            states, available, version = client.snapshot({LIGHT: {}})
        self.assertEqual(set(states), {LIGHT})
        self.assertEqual(version, "fixture")
        self.assertEqual(available, {"light": {"turn_on": {}}})
        self.assertEqual({call.args[0] for call in requester.call_args_list}, set(responses))


if __name__ == "__main__":
    unittest.main()
