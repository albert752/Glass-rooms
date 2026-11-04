#!/usr/bin/env python3
"""Run the real Glass Rooms server on loopback with a synthetic Home Assistant for native-client tests.

Prints one JSON line with the port and token, then serves until stdin closes. Never contacts HA.
"""

import copy
import json
import secrets
import sys
import threading
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from glass_rooms.server import App, Server, Settings  # noqa: E402

KITCHEN = "light.test_cuina"
DINING = "light.test_menjador"
TEMPERATURE = "sensor.test_temperatura"


class FakeHA:
    def __init__(self):
        self.states = {
            KITCHEN: {"entity_id": KITCHEN, "state": "off", "attributes": {"friendly_name": "Llum cuina",
                                                                           "supported_color_modes": ["brightness"],
                                                                           "brightness": None}},
            DINING: {"entity_id": DINING, "state": "on", "attributes": {"friendly_name": "Llum menjador",
                                                                        "supported_color_modes": ["onoff"]}},
            TEMPERATURE: {"entity_id": TEMPERATURE, "state": "21.4",
                          "attributes": {"friendly_name": "Temperatura menjador", "device_class": "temperature",
                                         "unit_of_measurement": "°C"}},
        }
        self.available = {"light": {"turn_on": {"fields": {"brightness": {}}}, "turn_off": {"fields": {}}}}
        self.calls = []

    def snapshot(self, by_id=None):
        return copy.deepcopy(self.states), copy.deepcopy(self.available), "test-fixture"

    def call(self, domain, service, payload):
        self.calls.append((domain, service, payload))
        if service in ("turn_on", "turn_off") and payload["entity_id"] in self.states:
            self.states[payload["entity_id"]]["state"] = "on" if service == "turn_on" else "off"

    def history(self, entity_ids, hours):
        return [[{"entity_id": TEMPERATURE, "state": "20.5", "last_changed": "2026-11-04T08:00:00+00:00"},
                 {"entity_id": TEMPERATURE, "state": "21.4", "last_changed": "2026-11-04T09:30:00.250000+00:00"}]]


def main():
    token = secrets.token_urlsafe(32)
    options = {"panel_pin": "12345678", "app_token": token, "allowed_hosts": ["127.0.0.1:1"],
               "allowed_networks": ["127.0.0.0/8"], "light_entity_ids": [KITCHEN, DINING],
               "entity_ids": [TEMPERATURE],
               "verified_actions": [KITCHEN + ":turn_on", KITCHEN + ":turn_off", KITCHEN + ":brightness",
                                    DINING + ":turn_on", DINING + ":turn_off"],
               "room_assignments": [KITCHEN + ":cuina", DINING + ":menjador", TEMPERATURE + ":menjador"]}
    fake = FakeHA()
    app = App(Settings(options), fake)
    server = Server(("127.0.0.1", 0), app)
    port = server.server_address[1]
    app.settings.allowed_hosts = {"127.0.0.1:" + str(port)}
    threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.05}, daemon=True).start()
    print(json.dumps({"port": port, "token": token}), flush=True)
    sys.stdin.read()
    print(json.dumps({"calls": fake.calls}), flush=True)
    server.shutdown()


if __name__ == "__main__":
    main()
