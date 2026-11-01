# Glass Rooms Home Assistant app

Generic Home Assistant app repository for the Glass Rooms panel. The repository contains no instance-specific entity IDs; configure those in Home Assistant.

```yaml
light_entity_ids:
  - light.example_new_lamp
entity_ids: []
room_assignments:
  - light.example_new_lamp:cuina
verified_actions:
  - light.example_new_lamp:turn_on
  - light.example_new_lamp:turn_off
```

The example ID is fictitious. Add other domains to `entity_ids`. A configured service is shown only when Home Assistant exposes it and it can be called with the entity ID alone. App options are stored by Home Assistant.
