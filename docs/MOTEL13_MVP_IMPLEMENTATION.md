# MOTEL 13 - Roblox Horror MVP Implementation

## A) Structured implementation plan

### Phase 1 - Setup (foundation)
1. Build folders in Studio (`ReplicatedStorage/Shared`, `ReplicatedStorage/Remotes`, `ServerScriptService/GameServer`, `StarterPlayerScripts/GameClient`).
2. Add `GameConfig` for tunables (round timings, stamina, AI ranges).
3. Add bootstrap script to auto-create required remotes.
4. Tag map objects using `CollectionService` so systems are data-driven.

### Phase 2 - MVP gameplay loop
1. **RoundManager** state machine: Lobby -> Intermission -> InRound -> EndRound.
2. **ObjectiveManager**: spawn keys/fuses from tagged points, power box insertion, gate unlock and escape.
3. **PlayerStateManager**: stamina sprint, flashlight battery, downed state, spectate targets.
4. **EnemyController**: waypoint patrol, hearing + LOS detection, chase pathing, server-side downing.
5. **UI + client controls**: objective tracker, state timer, stamina/battery bars, spectate cycling, jumpscare VFX.

### Phase 3 - Polish + hardening
1. Tune AI/path settings for your map geometry.
2. Add stronger ambience pass (zone sounds, more flicker groups).
3. Add revive system and more anti-stall rules.
4. Add telemetry counters and balancing pass.

## B) Explorer tree layout

```text
ReplicatedStorage
├─ Shared
│  └─ GameConfig (ModuleScript)
└─ Remotes (Folder)
   ├─ RoundState (RemoteEvent)
   ├─ ObjectiveUpdate (RemoteEvent)
   ├─ PlayerStateUpdate (RemoteEvent)
   ├─ AtmosphereCue (RemoteEvent)
   ├─ Jumpscare (RemoteEvent)
   ├─ SpectateTargets (RemoteEvent)
   ├─ SprintState (RemoteEvent)
   ├─ FlashlightToggle (RemoteEvent)
   ├─ RequestInteract (RemoteEvent)
   └─ RequestSpectateNext (RemoteFunction)

ServerScriptService
└─ GameServer (Folder)
   ├─ Bootstrap (Script)
   ├─ Main (Script)
   └─ Modules (Folder)
      ├─ RoundManager (ModuleScript)
      ├─ ObjectiveManager (ModuleScript)
      ├─ PlayerStateManager (ModuleScript)
      ├─ EnemyController (ModuleScript)
      └─ AtmosphereController (ModuleScript)

StarterPlayer
└─ StarterPlayerScripts
   └─ GameClient (Folder)
      └─ ClientMain (LocalScript)
```

## D) Studio setup checklist (tags + attributes + objects)

### 1) Tags to create (CollectionService)
Use **Model > Tags** in Studio or `CollectionService` plugin:

- `LobbySpawn`: Spawn parts in lobby area.
- `PlayerSpawn`: Spawn parts for active round.
- `KeySpawn`: Candidate points for room keys.
- `FuseSpawn`: Candidate points for fuse pickups.
- `PowerBox`: One or more interactable power box parts.
- `ExitGate`: Exit gate interaction part.
- `EnemyWaypoint`: Ordered AI patrol points.
- `Enemy`: The enemy model.
- `LightFlicker`: Lights or fixtures that can flicker.

### 2) Required attributes
- On every `EnemyWaypoint` part: `PatrolIndex` (number) for ordered route.
- Optional tuning attributes you can add later by custom scripts:
  - `LightGroup` on flicker models,
  - `KeyId` / `FuseId` on designer-authored pickups.

### 3) Required object assumptions
- Enemy model tagged `Enemy` must include:
  - `Humanoid`
  - `HumanoidRootPart`
- Spawn tags should be on `BasePart` instances.
- `LightFlicker` tagged instances should contain `PointLight`, `SpotLight`, or `SurfaceLight` descendants.

### 4) Installation order in Studio
1. Copy scripts from `src/` into matching Explorer paths.
2. Ensure `Bootstrap` is enabled and `Main` is present.
3. Press Play; remotes auto-create under `ReplicatedStorage/Remotes`.
4. Tag your map parts/models from checklist above.
5. Run test with at least 1 player (Start Server + 1–2 clients recommended).

## C) Scripts created (full runnable Luau)

All scripts are included as complete Luau files under `src/`:

- `src/ReplicatedStorage/Shared/GameConfig.lua`
- `src/ServerScriptService/GameServer/Bootstrap.server.lua`
- `src/ServerScriptService/GameServer/Main.server.lua`
- `src/ServerScriptService/GameServer/Modules/RoundManager.lua`
- `src/ServerScriptService/GameServer/Modules/ObjectiveManager.lua`
- `src/ServerScriptService/GameServer/Modules/PlayerStateManager.lua`
- `src/ServerScriptService/GameServer/Modules/EnemyController.lua`
- `src/ServerScriptService/GameServer/Modules/AtmosphereController.lua`
- `src/StarterPlayerScripts/GameClient/ClientMain.client.lua`

Each file starts with an `Explorer Path` header comment and includes expected object dependencies.

## E) Testing steps + debugging tips

### Round flow
1. Run Studio with **Start Server** + **1 Client**.
2. Confirm HUD shows `Intermission`, then `InRound`.
3. Confirm player teleports to `PlayerSpawn` on round start and back to `LobbySpawn` on round end.

### Objectives
1. Verify 6 keys spawn at random `KeySpawn` points.
2. Verify 3 fuses spawn at random `FuseSpawn` points.
3. Pick up fuse, interact with `PowerBox`, confirm fuse count increments.
4. After 6 keys + power restored, confirm gate unlock and `ExitGate` interaction marks escape.

### Enemy AI
1. Ensure enemy has pathing room around waypoints.
2. Walk in LOS: enemy should chase.
3. Sprint near enemy without LOS: hearing should trigger chase.
4. Reach attack range: player should become downed (server-side).

### Spectate + fail conditions
1. When downed, right mouse cycles spectated player.
2. If all players downed/escaped, round should transition to `EndRound`.

### Debugging tips
- If nothing spawns, verify tags exactly match names (case-sensitive).
- If enemy does not move, check enemy model has `Humanoid` + `HumanoidRootPart` and waypoint tags.
- If UI not updating, verify remotes exist under `ReplicatedStorage/Remotes`.
- Open Output window and search for warnings (`No spawns tagged`, `No enemy model tagged`).

## F) Polish backlog (priority order)

1. **P0**: Add revive mechanic (teammate channel interaction, time-limited).
2. **P0**: Move ambience to zones (different motel wings, unique SFX).
3. **P1**: Add door lock system powered by fuse state.
4. **P1**: Better enemy search state (last known position investigation).
5. **P1**: Add objective item meshes/models and interaction animation.
6. **P2**: Cosmetic gamepass flashlight skin hook (visual only).
7. **P2**: Accessibility settings (camera shake intensity, subtitle cues).
