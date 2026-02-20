# MOTEL 13 – Roblox Horror MVP

This repository contains a complete MVP architecture for **MOTEL 13** (1–6 co-op horror) using Luau and server-authoritative gameplay.

## A) Implementation Plan

### Phase 1: Setup (Foundation)
1. Build Explorer folder structure (`Remotes`, `Shared`, `GameServer`, `GameClient`).
2. Add map tags with `CollectionService`: `KeySpawn`, `FuseSpawn`, `EnemyWaypoint`, `LightFlicker`, `PlayerSpawn`, `LobbySpawn`, `ExitGate`, `PowerBox`.
3. Create one `Enemy` model in `Workspace` (must include `Humanoid` + `HumanoidRootPart`).
4. Drop scripts from this repo into matching Explorer paths.

### Phase 2: MVP Gameplay Loop
1. Round state machine (`Lobby -> Intermission -> InRound -> EndRound`).
2. Objective spawning + progression (6 keys, 3 fuses, restore power, unlock gate).
3. Player state authority (stamina sprint, flashlight battery, downed, spectate).
4. Enemy AI (patrol, detect LOS/running, chase, attack/down).
5. HUD UI and input bindings.

### Phase 3: Polish Pass
1. Add better map dressing + optimized waypoints.
2. Replace placeholder sounds/music with final assets.
3. Tune balance (enemy ranges/speeds, stamina economy, objective timing).
4. Add revive feature, improved jump-scare camera shake, and end-round result cards.

---

## B) Explorer Tree Layout

```text
ReplicatedStorage
├── Remotes (Folder, auto-created by Bootstrap.server.lua)
│   ├── RoundStateChanged (RemoteEvent)
│   ├── ObjectiveUpdated (RemoteEvent)
│   ├── PlayerStateUpdated (RemoteEvent)
│   ├── SpectateUpdated (RemoteEvent)
│   ├── Jumpscare (RemoteEvent)
│   ├── RequestSprint (RemoteEvent)
│   ├── ToggleFlashlight (RemoteEvent)
│   └── RequestSpectateTarget (RemoteEvent)
└── Shared
    └── Config (ModuleScript)

ServerScriptService
└── GameServer
    ├── Bootstrap.server.lua
    └── Modules
        ├── RoundManager.lua
        ├── ObjectiveManager.lua
        ├── PlayerStateService.lua
        ├── EnemyController.lua
        └── AtmosphereService.lua

StarterPlayer
└── StarterPlayerScripts
    └── GameClient
        ├── ClientBootstrap.client.lua
        ├── InputController.client.lua
        └── UIController.lua
```

---

## D) Studio Setup Checklist

### 1) Required Workspace Objects
- `Workspace.Enemy` (Model)
  - `Humanoid` (required)
  - `HumanoidRootPart` (required)
- At least 6 parts tagged `KeySpawn`.
- At least 3 parts tagged `FuseSpawn`.
- At least 3 parts tagged `EnemyWaypoint`, each with `PatrolIndex` number attribute for route ordering.
- At least 1 part tagged `PowerBox`.
- At least 1 part tagged `ExitGate`.
- At least 4 parts tagged `PlayerSpawn`.
- At least 1 part tagged `LobbySpawn`.
- Lights or emissive parts tagged `LightFlicker`.

### 2) How to Add Tags and Attributes
1. Open **View > Tag Editor** in Roblox Studio.
2. Select a part, add tag from the required list above.
3. Open **Properties > Attributes**:
   - For enemy waypoint parts: add `PatrolIndex` (Number), e.g. 1,2,3...
   - Optional on gate: `Unlocked` auto-updated by script.

### 3) Required Script Placement (exact)
- `ReplicatedStorage/Shared/Config.lua`
- `ServerScriptService/GameServer/Bootstrap.server.lua`
- `ServerScriptService/GameServer/Modules/ObjectiveManager.lua`
- `ServerScriptService/GameServer/Modules/PlayerStateService.lua`
- `ServerScriptService/GameServer/Modules/RoundManager.lua`
- `ServerScriptService/GameServer/Modules/EnemyController.lua`
- `ServerScriptService/GameServer/Modules/AtmosphereService.lua`
- `StarterPlayer/StarterPlayerScripts/GameClient/UIController.lua`
- `StarterPlayer/StarterPlayerScripts/GameClient/InputController.client.lua`
- `StarterPlayer/StarterPlayerScripts/GameClient/ClientBootstrap.client.lua`

---

## C) Scripts Included

All scripts are fully implemented in this repo at the exact paths listed above.

---

## E) Testing Steps + Debugging Tips

### Round Flow
1. Play Solo.
2. Confirm UI shows round state moving through Lobby/Intermission/InRound/EndRound.
3. Verify teleport to `LobbySpawn` then `PlayerSpawn` at round start.

### Objectives
1. Walk to key/fuse pickups and press prompt.
2. Confirm objective HUD updates key/fuse counts.
3. After 3 fuses, activate `PowerBox` prompt.
4. After 6 keys + power, confirm `ExitGate` unlocks and prompt ends round.

### Enemy
1. Ensure enemy patrols between `EnemyWaypoint` points.
2. Sprint near enemy and confirm chase trigger.
3. Break line-of-sight and confirm enemy loses target after timeout.
4. Stand close and confirm server-side downing.

### Player State
1. Hold Shift to sprint; watch stamina drain and refill.
2. Press F to toggle flashlight; battery drains then recharges.
3. On downed state, verify spectate prompt and cycle with Q/E.

### Debug Tips
- If nothing spawns: verify tags exist exactly and are case-sensitive.
- If enemy does not move: ensure `Workspace.Enemy` has `Humanoid` + `HumanoidRootPart` and waypoints are tagged.
- If UI missing: ensure client scripts are in `StarterPlayerScripts/GameClient`.

---

## F) Prioritized Polish Backlog

1. **High Priority**
   - Add revive mechanic (time-limited teammate interaction).
   - Replace placeholder SFX/music IDs and add mixer/volume settings.
   - Add proper exit gate animation and lock-state indicator mesh.
2. **Medium Priority**
   - Add crouch + visibility impact on enemy detection.
   - Add randomized room events (door slam, whisper, breaker trip).
   - Add round-end scoreboard (escaped/downed/time/objective completion).
3. **Low Priority**
   - Cosmetic flashlight skins (gamepass hook, no stat changes).
   - VHS post-process toggle menu for quality levels.
