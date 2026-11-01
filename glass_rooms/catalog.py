"""Inventory slots; Home Assistant entity IDs are supplied in app options."""

ROOMS = [
    {"id": "menjador", "name": "Menjador"},
    {"id": "cuina", "name": "Cuina"},
    {"id": "habitacio", "name": "Habitació"},
    {"id": "despatx", "name": "Despatx"},
    {"id": "rebedor", "name": "Rebedor"},
    {"id": "bany", "name": "Bany"},
    {"id": "passadis", "name": "Passadís"},
    {"id": "lavabo", "name": "Lavabo"},
]


def entry(slot, domain, name, category, area=None, group=False, note=""):
    return {"slot": slot, "entity_id": None, "name": name, "domain": domain,
            "category": category, "inventory_area": area, "is_group": group, "note": note}


TEMPLATES = []
for slot, name, group, note in [
    ("light_zha_costelles", "Llums costelles", True, "Grup ZHA; membres i ubicació pendents de confirmar."),
    ("light_zha_cuina", "Llums cuina", True, "Grup ZHA; membres i ubicació pendents de confirmar."),
    ("light_zha_dutxa", "Llums dutxa", True, "Grup ZHA; membres i ubicació pendents de confirmar."),
    ("light_zha_lavabo", "Llums lavabo", True, "Grup ZHA; membres i ubicació pendents de confirmar."),
    ("light_zha_menjador", "Llums menjador", True, "Grup ZHA; membres i ubicació pendents de confirmar."),
    ("light_zha_passadis", "Llums passadís", True, "Grup ZHA; membres i ubicació pendents de confirmar."),
    ("light_zha_rebedor", "Llums rebedor", True, "Grup ZHA; membres i ubicació pendents de confirmar."),
    ("light_zha_totes", "Totes les llums", True, "Grup ZHA; membres i ubicació pendents de confirmar."),
]:
    TEMPLATES.append(entry(slot, "light", name, "lights", group=group, note=note))

TEMPLATES.extend([
    entry("light_fan_bedroom", "light", "Llum del ventilador · Bedroom", "lights", "Bedroom"),
    entry("light_fan_office", "light", "Llum del ventilador · Office", "lights", "Office"),
])
for area, numbers in [
    ("Hall", ["00", "01", "03"]),
    ("Living Room", ["04", "05"]),
    ("Kitchen", ["02", "06", "11", "13", "14"]),
    ("Bathroom", ["07", "08", "09", "10", "12"]),
]:
    for number in numbers:
        TEMPLATES.append(entry("light_hue_" + number, "light", "Hue " + number + " · " + area, "lights", area))
for number in ["20", "21", "22"]:
    TEMPLATES.append(entry("light_phwa_" + number, "light", "PHWA " + number + " · Kitchen", "lights", "Kitchen"))

TEMPLATES.extend([
    entry("adaptive_main", "switch", "Adaptive Lighting", "adaptive", note="Llums afectades pendents de verificar."),
    entry("adaptive_brightness", "switch", "Adaptar brillantor", "adaptive"),
    entry("adaptive_color", "switch", "Adaptar color", "adaptive"),
    entry("adaptive_sleep", "switch", "Mode de descans", "adaptive"),
    entry("circadian_indicator", "input_boolean", "Mode circadià · indicador independent", "adaptive",
          note="No es vincula a Adaptive Lighting: cal revisar quina automatització governa."),
    entry("scene_cozy", "scene", "Mode cozy", "scenes"),
    entry("scene_sofa", "scene", "Llum del sofà", "scenes"),
    entry("alarm_panel", "alarm_control_panel", "Alarma principal", "security",
          note="Modes, requisits de codi i sensors pendents de comprovació."),
    entry("alarm_status", "sensor", "Estat auxiliar de l'alarma", "security"),
    entry("alarm_toggle_script", "script", "Script toggle_alarma · només lectura", "security",
          note="No s'executa: cal revisar-ne el contingut."),
    entry("door_living_room", "binary_sensor", "Porta · sensor de sala", "security"),
    entry("window_office", "binary_sensor", "Finestra · despatx", "security"),
    entry("window_living_room", "binary_sensor", "Finestra · menjador", "security"),
    entry("door_hall", "binary_sensor", "Porta · rebedor", "security"),
    entry("camera_motion", "binary_sensor", "Càmera · detecció de moviment", "security"),
    entry("camera_motion_alarm", "binary_sensor", "Càmera · alarma de moviment", "security"),
    entry("camera_person", "binary_sensor", "Càmera · detecció de persones", "security"),
    entry("water_heater", "water_heater", "Escalfador Ariston", "water"),
    entry("water_showers", "sensor", "Dutxes disponibles · estimació", "water"),
    entry("water_process_temperature", "sensor", "Lectura proc_req_temp", "water",
          note="Significat pendent: no es presenta com a temperatura actual."),
    entry("water_heating", "binary_sensor", "Escalfant", "water"),
    entry("water_night_mode", "switch", "Escalfador · mode nocturn", "water",
          note="Només lectura. No es modifiquen paràmetres de seguretat."),
    entry("water_permanent_boost", "switch", "Escalfador · boost permanent", "water",
          note="Només lectura. No es modifiquen paràmetres de seguretat."),
    entry("water_power", "switch", "Escalfador · alimentació", "water", note="Només lectura."),
    entry("fan_bedroom", "fan", "Ventilador · Bedroom", "fans"),
    entry("fan_office", "fan", "Ventilador · despatx", "fans"),
    entry("media_room", "media_player", "Reproductor de sala", "media",
          note="Fabricant pendent de confirmar."),
    entry("media_tv", "media_player", "Televisor", "media"),
])

SLOT_BY_ID = {item["slot"]: item for item in TEMPLATES}
SLOTS_BY_CATEGORY = {}
for _item in TEMPLATES:
    SLOTS_BY_CATEGORY.setdefault(_item["category"], []).append(_item["slot"])
ROOM_IDS = {item["id"] for item in ROOMS}


def catalog_for(entity_ids, preview=False):
    """Build the live inventory from entity_ids saved in Home Assistant options."""
    result = []
    for original in TEMPLATES:
        item = dict(original)
        entity_id = entity_ids.get(item["slot"]) if isinstance(entity_ids, dict) else None
        if not entity_id and preview:
            entity_id = item["domain"] + ".preview_" + item["slot"]
        item["entity_id"] = entity_id
        result.append(item)
    return result


# Generic IDs keep local preview behavior deterministic; these are not instance IDs.
CATALOG = catalog_for({}, preview=True)
BY_ID = {item["entity_id"]: item for item in CATALOG}
