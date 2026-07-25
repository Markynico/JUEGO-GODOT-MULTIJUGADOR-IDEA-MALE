# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Godot 4.7 multiplayer 3D game prototype (GDScript, GL Compatibility renderer, Jolt physics). Everything — code, comments, node names, identifiers — is written in **Spanish**; keep new code in Spanish to match.

The Godot project root is the subdirectory `PROYECTO JUEGO MALE/` (note the spaces — quote paths). The repo root only holds git metadata.

## Running

There are no tests, no build scripts, and no lint config. Development happens in the Godot editor.

```bash
godot --path "PROYECTO JUEGO MALE"
```

Main scene: `escena_prototipos/main_prototipos.tscn` (`uid://db3c4gewtolrb`).

To test multiplayer on a single machine, run two instances (Godot's *Debug > Run Multiple Instances*) and set `MULTIJUGADOR_TIPO` to `ENET` on the `HostearYUnirseEjemplo` node — see the transport note below.

## Multiplayer architecture

`escenas/hostear_y_unirse_ejemplo.gd` is the de-facto SteamManager. It supports **two interchangeable transports** via the exported enum `MULTIJUGADOR_TIPO`:

- `STEAM` — GodotSteam (`addons/godotsteam`, GDExtension) with `SteamMultiplayerPeer` and Steam lobbies. `STEAM_APP_ID` is still `480` (Spacewar placeholder). Requires Steam running.
- `ENET` — `ENetMultiplayerPeer` on `127.0.0.1:1027`, for local testing.

Any code calling `Steam.*` (e.g. `Player.get_nombre_steam()` → `Steam.getPersonaName()`) will fail or return `""` under ENET. This is known and tolerated.

The manager owns no game logic — it emits `agregar_jugador` / `quitar_jugador`, wired in `main_prototipos.tscn` to `SpawnerJugadores.spawnear_jugador` and `EquiposManager`. **Signal wiring lives in the scene file, not in code** — when tracing flow, read the `[connection]` section at the bottom of `.tscn` files.

### Authority model

- `SpawnerJugadores` names each player node with its multiplayer peer id; `Player._enter_tree()` calls `set_multiplayer_authority(name.to_int())`.
- Every per-player manager (`MovimientoManager`, `CamarasManager`, `NitroManager`, `hud_player`) early-returns from `_ready`/`_process`/`_input` with `if not body.is_multiplayer_authority(): return`. Preserve this guard in any new player-attached node.
- Shared state is server-authoritative and passed through the `Global` autoload (`Global.gd`): `diccionario_equipos` (replicated) and `instancia_jugadores` (local-only, never sent over RPC).

### RPC convention

The team-selection flow in `escenas/equipos_manager.gd` is the canonical pattern and is documented in-file at length: client sends a *request* with `rpc_id(SERVER_ID, ...)` (`@rpc("any_peer", "reliable", "call_local")`, guarded by `if !multiplayer.is_server(): return`), the server mutates `Global.diccionario_equipos`, then broadcasts the whole updated dictionary with an `@rpc("authority", "reliable", "call_local")` sync function. Follow this request → mutate → broadcast-full-state shape for new shared state.

Note the `call_local` quirk handled there: when the host itself invokes the RPC, `get_remote_sender_id()` returns `0`, so the code substitutes `multiplayer.get_unique_id()`.

## Player composition

`escenas/personaje_de_prueba.gd` (`class_name Player`, `CharacterBody3D`) is a thin shell; behavior is split into sibling manager nodes that each take an `@export var body : Player` reference:

| Script | Role |
| --- | --- |
| `movimiento_manager.gd` | WASD + gravity + jump + slide, state machine `ESTADOS {IDLE, CAMINAR, SALTANDO, DESLIZANDOSE, ESPECTANDO}` |
| `nitro_manager.gd` | Shift-held nitro meter, emits `nitro_activado` / `valor_nitro_cambio` |
| `camaras_manager.gd` | Switches between `CAMARAS {JUGADOR, ESPECTADOR}`, drives FOV from nitro signals |
| `spring_arm_camara_principal.gd` | `CamaraPrincipalPlayer`, third-person SpringArm3D + scroll zoom |
| `camera_espectando.gd` | `CamaraLibre`, free-fly spectator camera; also fires test projectiles via RPC |
| `hud_player.gd` | Nitro progress bar |

Managers communicate through signals rather than direct calls; `Player` exposes `cambiar_a_modo_espectador` / `cambiar_a_modo_corredor`, which `CorredoresManager` emits to rotate who is racing.

## Race prototypes

`escena_prototipos/` holds track generation, all `@tool` scripts that regenerate geometry from property setters (so they run live in the editor):

- `pista_procedural.gd` — seeded procedural track (CIRCUITO/SPRINT), emits `pista_generada`.
- `sistema_checkpoints.gd` (`SistemaCheckpoints`) — regenerates checkpoint arcs along the parent's `Path3D`; auto-connects to the parent's `pista_generada` signal if present. Guards editor-only work with `Engine.is_editor_hint()`.
- `pista_1.gd`, `pista_2.tscn`, `pista_3.tscn` — hand-built CSG tracks.
- `corredores_manager.gd` — round timer (`tiempo_x_ronda`) that rotates one racer per team out of `lista_corredores_rojo` / `lista_corredores_azul`.

When editing a `@tool` script, remember the setters call `generar()`/`_actualizar()` on every property write and must be safe before the node is in the tree (`is_inside_tree()` checks).

## Input actions

Input map uses literal key names as action names: `w`, `a`, `s`, `d`, `espacio`, `shift`, `control`, `tab`, `escape`, `f`, `click_izq`, `mouse_rueda_arriba`, `mouse_rueda_abajo`. Use those exact strings with `Input.is_action_pressed`.

## Conventions

- `.gd` files carry a sibling `.gd.uid` — commit both.
- Resources are referenced by `uid://` rather than `res://` paths in scenes; don't rewrite them by hand.
- Code is heavily commented in informal Spanish, often explaining *why* multiplayer requires a given shape. This is intentional teaching-style documentation — keep it when refactoring.
- Physics layers: 1 = `Mundo`, 2 = `Personaje`.
