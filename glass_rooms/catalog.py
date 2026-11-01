"""Generic Home Assistant inventory built only from user-supplied entity IDs."""

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
ROOM_IDS = {item["id"] for item in ROOMS}

CATEGORY_BY_DOMAIN = {
    "light": "lights",
    "alarm_control_panel": "security",
    "binary_sensor": "security",
    "water_heater": "water",
    "fan": "fans",
    "media_player": "media",
    "scene": "scenes",
    "switch": "switches",
    "input_boolean": "switches",
}


def humanize(entity_id):
    """Readable fallback when Home Assistant has no friendly_name attribute."""
    value = entity_id.split(".", 1)[1]
    return " ".join(part.capitalize() for part in value.split("_"))


def catalog_for(light_entity_ids, entity_ids=None, preview=False):
    """Build an inventory from lists saved in Home Assistant app options."""
    result = []
    ids = list(light_entity_ids or []) + list(entity_ids or [])
    if preview and not ids:
        ids = ["light.preview_light"]
    seen = set()
    for entity_id in ids:
        if entity_id in seen:
            continue
        seen.add(entity_id)
        domain = entity_id.split(".", 1)[0]
        category = CATEGORY_BY_DOMAIN.get(domain, "other")
        result.append({
            "entity_id": entity_id,
            "name": humanize(entity_id),
            "domain": domain,
            "category": category,
            "inventory_area": None,
            "is_group": False,
            "note": "",
        })
    return result


CATALOG = catalog_for([], preview=True)
BY_ID = {item["entity_id"]: item for item in CATALOG}
