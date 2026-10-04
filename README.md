# arca_admin

Admin menu for the Arca framework. `/admin` (or F10) opens it.

## Tabs

- **Dashboard**: player count, uptime, weather and time, plus quick actions.
- **Players**: a searchable list of everyone online. Pick a player to:
  - go to, bring or send back, spectate, freeze
  - heal, revive, kill
  - set job or gang, give or remove money, give items, open or clear their inventory, spawn a vehicle for them
  - message, kick, ban
- **Vehicles**: spawn by model or from the quick list. Repair, clean, refuel, flip, max-upgrade or delete the vehicle you're in or nearest to. Clear empty vehicles within 50m or across the whole map.
- **World**: weather, time, freeze time, blackout. Synced to every client through GlobalState.
- **Self & Dev**: noclip, god mode, invisible, player names, map-wide player blips, teleport to waypoint or coords, heal or revive yourself, the **coords editor** (from arca_core), copy vector3 / vector4.
- **Server**: announcements, revive all, active bans with unban, and a resource manager (start, stop, restart).

## Permissions

Permissions come from arca_core's aces (`arca.god` > `arca.admin` > `arca.mod`). The menu opens for `mod` and up. Every action has its own minimum permission in `shared/config.lua` → `AdminConfig.Permissions`. Buttons an admin can't use are hidden, and the server refuses them too.

```cfg
add_ace group.admin arca.admin allow
add_principal identifier.license:xxxx group.admin
```

The resource manager uses `StartResource` / `StopResource`. If your server refuses those, give the resource the command ace:

```cfg
add_ace resource.arca_admin command allow
```

## Notes

- **Bans** are stored in `arca_bans`, which is created automatically. A ban matches on license, Discord, FiveM ID or IP.
- **Weather and time:** turn off `AdminConfig.World.Enabled` if you use another weather script. Exports: `SetWeather(name)`, `SetTime(h, m)`, `GetWorld()`.
- **Noclip** can also be bound to a key: GTA Settings › Key Bindings › FiveM › *Admin: toggle noclip*.
- **Opening another player's inventory** needs arca_inventory with the `OpenPlayerInventory` export.
