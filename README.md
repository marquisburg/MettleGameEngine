# Mettle Game Engine

A Windows game engine and editor written entirely in [Mettle](https://github.com/marquisburg/Mettle),
a typed low-level language that compiles `.mettle` source files straight to
x86-64 NASM assembly and Windows COFF objects. The engine has no C++ glue
layer: every line of `engine/` is `.mettle` source linked by Mettle's own
internal PE linker against `vulkan-1.dll`, `lua55.dll`, and the Win32 system
DLLs.

Status: pre-alpha, Windows-only, single-developer. It boots, it renders, it
plays. It also has sharp edges.

## Why this exists

Most "make your own engine" projects stop at "I wrote a renderer in C++". This
one goes further down the stack on purpose:

1. The **language** is custom. Mettle is a typed systems language with
   pointers, structs, enums, function pointers, generics with monomorphization,
   modules, `defer`/`errdefer`, labeled `break`/`continue`, `match`,
   compound assignment, `async`/`await` with pool and coroutine executors
   (IOCP on Windows, `poll(2)` on POSIX), C interop via `extern` and `cstring`,
   a conservative GC for `new` and string concatenation, and symbolized crash
   tracebacks via SEH. It has its own multi-stage compiler pipeline (lex,
   parse, import resolution, monomorphization, type check, IR lowering,
   optimization, codegen) and a stable diagnostic error code system with
   carets and "did you mean?" suggestions. Apache-2.0 licensed, ~90 commits,
   five releases. See [github.com/marquisburg/Mettle](https://github.com/marquisburg/Mettle).
2. The **toolchain** is custom. `bin/mettle.exe` does the full job: source
   to executable, no NASM, no `gcc`, no `link.exe`, no MSVC needed for the
   target build. `--build --emit-obj --linker internal` invokes Mettle's
   own PE/COFF linker which resolves common Win32 DLLs directly and probes
   named DLLs by exports for anything else.
3. The **engine** is custom and lives on top of (1) and (2). Win32, Vulkan,
   Lua, and sockets are reached through `extern function ... = "Win32Symbol";`
   declarations and nothing else. There is no engine framework underneath.

The point is to see what a single-stack tower looks like when nobody else's
code is loaded into the address space except the kernel, the GPU driver, and
Lua.

## What ships in this repo

Three Mettle executables come out of one source tree under [`engine/`](engine/):

| Binary | Source | Role |
|---|---|---|
| `examples/engine_editor.exe` | [`examples/engine_editor.mettle`](examples/engine_editor.mettle) | Editor window. GDI chrome (toolbar, explorer, asset registry, inspector, output log, game tree with modal Lua code editor) plus a child Vulkan window for the 3D viewport. Spawns playtests. |
| `examples/engine_play_server.exe` | [`examples/engine_play_server.mettle`](examples/engine_play_server.mettle) | Headless authoritative server. No window, no GPU. Owns the scene, runs `ServerScriptService` and server-role entity scripts, replicates transforms over TCP. |
| `examples/engine_play_client.exe` | [`examples/engine_play_client.mettle`](examples/engine_play_client.mettle) | Render client. Connects to the server, runs `StarterPlayerScripts` locally, draws the replicated workspace through the same Vulkan path the editor uses, sends input upstream. |

When you press **Play** in the editor, it does not toggle a flag. It snapshots
the scene and the service model into `.mettleplay/`, writes
`.mettleplay/playtest.manifest` with the session id, host, port, and tick rate,
then spawns `engine_play_server.exe` and `engine_play_client.exe` as real
processes via `CreateProcess`. The two binaries talk over a localhost TCP
socket using the wire format defined in [`engine/engine_play_protocol.mettle`](engine/engine_play_protocol.mettle)
(`WELCOME`, `SCENE_BEGIN`, `ENTITY`, `SCRIPT`, `SCENE_END`, `INPUT`, `XFORM`,
`STOP`). Stop play kills both processes, restores the original scene from the
snapshot, and editing continues.

## Engine source layout

Every file below is hand-written Mettle.

```
engine/
  game_gdi_win32.mettle        Win32 window, message pump, GDI backbuffer
  engine_vulkan.mettle         Vulkan instance/device/swapchain (child HWND of editor)
  engine_vk_scene.mettle       Per-frame scene draw, MVP push constants, depth
  engine_vk_shaders.mettle     SPIR-V loader, pipeline layout
  shaders/                   GLSL sources + regen_spirv.py to rebuild .spv

  engine_scene.mettle          Entity table (id, kind, parent, transform, mesh, script)
  engine_scene_io.mettle       .mscene text format read/write
  engine_mesh.mettle           OBJ-style mesh store
  engine_materials.mettle      Per-entity material colors / tint
  engine_input.mettle          Action map (FORWARD/BACK/LEFT/RIGHT/UP/DOWN/FIRE/PLAY_TOGGLE)
  engine_runtime.mettle        Fixed-step simulation, accumulator, play snapshot

  engine_lua.mettle            Lua 5.5 host: shared lua_State, per-entity chunks,
                             role-aware VM (server vs client), engine.* API
  engine_scripts.mettle        Built-in scripts (SPIN/BOB/PLAYER), legacy path
  engine_services.mettle       ServerScriptService / StarterPlayerScripts /
                             ReplicatedStorage / Workspace service model
  engine_services_io.mettle    .msvc service snapshot format

  engine_editor_ui.mettle      GDI panels: toolbar, explorer, assets, inspector, output
  engine_explorer.mettle       Filesystem tree pane
  engine_assets.mettle         Flat asset registry (right-hand pane)
  engine_game_tree.mettle      Roblox-style game tree pane + modal Lua code editor
  engine_viewport.mettle       3D camera, gizmos, picking, viewport rect math
  engine_output_log.mettle     Output tab at the bottom of the editor

  engine_project.mettle        .mproj load/save
  engine_play_manifest.mettle  .mettleplay/playtest.manifest read/write
  engine_play_protocol.mettle  Server/client wire format
  engine_process_win32.mettle  CreateProcess wrappers for spawning playtests
  engine_fs_win32.mettle       Path joining, mkdir, file IO helpers
```

## Scripting

Scripts are Lua 5.5. The folder a script lives in determines its role, in the
same spirit as Roblox services:

```
ServerScriptService/   runs only on the playtest server (authoritative)
StarterPlayerScripts/  runs only on the playtest client (local input/UI)
ReplicatedStorage/     ModuleScripts available to both via require()
```

Per-entity scripts also exist via the `lua_script` field on each Entity and
inherit a role (server, client, or shared). Each script can define a global
`function on_tick(dt)`; the runtime invokes it every fixed step (`1/60` by
default) with a small `engine.*` API in scope.

```lua
-- ServerScriptService/main.server.lua
local t = 0
function on_tick(dt)
  t = t + dt
  local e = game:GetService("Workspace"):FindFirstChild("Cube 1")
  if e then
    e.CFrame = e.CFrame * CFrame.Angles(0, dt * 1.5, 0)
  end
end
```

```lua
-- StarterPlayerScripts/player.client.lua
function on_tick(dt)
  if engine.input_pressed(engine.IA.FIRE) ~= 0 then
    engine.log("client fired")
  end
end
```

The complete `engine.*` surface is documented at the top of
[`engine/engine_lua.mettle`](engine/engine_lua.mettle):
`engine.self_id`, `engine.dt`, `engine.time`,
`engine.get_pos` / `set_pos` / `translate`, `engine.rotate_world`,
`engine.get_scale` / `set_scale`,
`engine.input_held` / `input_pressed` / `input_released`, `engine.log`, and
the `engine.IA` action constants.

If a script does not define `on_tick`, its top-level body is re-executed every
tick instead. `on_tick` is wiped from globals after each load so scripts on
the same shared `lua_State` do not bleed into each other.

## Building

### Prerequisites

- **Windows 10 or 11**, x86-64.
- **Vulkan SDK** with `vulkan-1.dll` reachable at link time. Mettle's
  internal linker probes named DLLs by exports, so the DLL must actually be
  on `PATH`.
- **Lua 5.5** for Windows. Install to `%LOCALAPPDATA%\Programs\Lua` (the
  build script looks there first) or set `LUA_HOME` to a folder containing
  `lua55.dll`. The repo also ships `lua-5.5.0.tar.gz` and
  `lua-5.5.0_Win64_bin.zip` for convenience.
- The Mettle compiler is pre-built and checked in at
  [`bin/mettle.exe`](bin/mettle.exe). You do not need MSVC, MinGW, clang,
  NASM, `gcc`, or `link.exe` for the engine build. Mettle's `--emit-obj
  --linker internal` path goes source straight to `.exe`.

### One-shot build

From the repo root:

```powershell
.\build_engine_editor.bat
```

That script:

1. Refuses to run if `engine_editor.exe` is already running, so the file
   isn't locked under your feet.
2. Locates `lua55.dll` and prepends its directory to `PATH` so the internal
   linker can resolve `-llua55` exports.
3. Builds, in order, with `--emit-obj --linker internal`:
   - `examples\engine_editor.exe` (linked against `vulkan-1` and `lua55`)
   - `examples\engine_play_server.exe` (linked against `lua55` only, no GPU)
   - `examples\engine_play_client.exe` (linked against `vulkan-1` and `lua55`)
4. Copies `lua55.dll` next to the exes so `examples\` is self-contained.

### Manual builds

Single targets by hand:

```powershell
.\bin\mettle.exe --build --emit-obj --linker internal `
  --link-arg -lvulkan-1 --link-arg -llua55 `
  examples\engine_editor.mettle -o examples\engine_editor.exe

.\bin\mettle.exe --build --emit-obj --linker internal `
  examples\hello_game_win32.mettle -o examples\hello_game_win32.exe
```

For a smaller release binary, add `--release` (enables `-O`, strips assembly
comments, removes unreachable functions, and skips generated runtime
null/bounds traps).

For a symbolized crash traceback path, add `-s` (or `-d` to combine with
debug output). Crashes then print the native exception code (e.g.
`0xC0000005`) plus Mettle frames with file and line numbers.

### Regenerating shaders

```powershell
python engine\shaders\regen_spirv.py
```

The script downloads `glslang` on demand into `engine/shaders/.glslang/`
(gitignored) and recompiles every `.vert` and `.frag` next to it.

## Running

```powershell
cd examples
.\engine_editor.exe
```

The editor opens `project.mproj` from the repo root and loads the scene it
points at (`scene.mscene` by default). The starter scene contains a few
cubes, a box, and Artorias' sword
(`sword-of-artorias/source/sword.OBJ.obj`) hanging in space.

A typical loop:

1. Click around the **Game Tree** (left pane) to see Workspace entities and
   the three script services. Double-click a script to open the modal Lua
   code editor inline.
2. Use the **Inspector** (right pane) to edit the selected entity's
   transform, material, mesh, or attached script.
3. Drag in the **Viewport** (center) to fly the camera and pick entities;
   use the gizmo to translate / rotate / scale.
4. Press **Play**. The editor freezes its scene, writes
   `.mettleplay/playtest.manifest`, spawns `engine_play_server.exe` and
   `engine_play_client.exe`, and pipes their stdio into the **Output** panel.
   Server log goes to `.mettleplay/server.log`, client log to
   `.mettleplay/client.log`.
5. Press **Stop**. Both child processes are terminated, the scene is restored
   from the snapshot, editing resumes.

## File formats

| Extension | What it is |
|---|---|
| `.mettle` | Mettle source. |
| `.mproj` | Project file. INI-shaped: `name`, `scene`, `assets`. |
| `.mscene` | Scene file. Plain text, one `entity ... end` block per entity, fixed-point integer transforms (millimeters for position, micro-units for rotation/scale). |
| `.msvc` | Service snapshot for playtest: which Lua files belong to which service. |
| `.mettleplay/playtest.manifest` | Handshake file written by the editor and read by both server and client. Contains `session_id`, `project_root`, `scene_snapshot`, `services_snapshot`, `server_log`, `client_log`, `host`, `port`, `tick_hz`. |

A real `scene.mscene` excerpt:

```
mettlescene 3
selected 1
entity
id 1
kind 0
parent 0
script 0 0
pos_mm 0 1000 0
rot_q 0 0 0 1000000
scale_u 1000000
half_u 1000000
mesh_path
name Cube 1
end
```

Storing transforms as fixed-point integers on disk keeps scenes diff-friendly
in git and reproducible across machines without locale-dependent float
parsing.

## Repo layout

```
MettleGameEngine/
  bin/                     Pre-built mettle.exe + bundled runtime/ and stdlib/
  src/                     C source for the Mettle compiler (lexer, parser,
                           semantic, IR, codegen, linker, runtime). Mirrored
                           from the upstream Mettle repo.
  docs/                    Mettle language reference (mirrored)
  engine/                  The engine itself, in Mettle
  engine/shaders/          GLSL sources + regen_spirv.py
  examples/                engine_editor / engine_play_server / engine_play_client
                           / hello_game_win32 plus ServerScriptService,
                           StarterPlayerScripts, ReplicatedStorage sample folders
  tests/                   Mettle smoke tests (Lua linkage, project resolution,
                           protocol round-trips)
  sword-of-artorias/       Sample mesh asset for the demo scene
  lua-5.5.0*/              Vendored Lua source + Win64 prebuilt (gitignored)
  project.mproj            Default project loaded by the editor
  scene.mscene             Default scene
  build_engine_editor.bat  One-shot build of all three engine binaries
```

## Known limitations

- **Windows only.** Everything below the engine talks to Win32 directly:
  GDI for editor chrome, `CreateProcess` for playtest, IOCP for the async
  runtime, `ws2_32` for sockets. There is no abstraction layer waiting to be
  ported.
- **Vulkan only**, and the renderer is intentionally tiny: one pipeline,
  per-vertex color, MVP push constant, depth buffer. No materials beyond a
  flat tint, no lighting, no shadows.
- **Single playtest client.** The server accepts one TCP connection at a time.
- **Legacy script chain still alive.** `engine_scripts.mettle` (`SCRIPT_SPIN`,
  `SCRIPT_BOB`, `SCRIPT_PLAYER`) ticks alongside Lua. New scenes should use
  Lua exclusively; the legacy path will be removed once remaining demos are
  migrated.
- **No hot-reload of Mettle code.** Editing `engine/*.mettle` requires a
  rebuild. Lua scripts, however, reload on the next tick.
- See also [`docs/known-limitations.md`](docs/known-limitations.md) for
  language-level caveats.

## Related

- **Mettle** itself: [github.com/marquisburg/Mettle](https://github.com/marquisburg/Mettle)
  (Apache-2.0, the language and toolchain that compiles this engine).
- **Mettle language reference** lives mirrored under [`docs/`](docs/), with
  [`docs/LANGUAGE.md`](docs/LANGUAGE.md) as the entry point.

## License

No license declared yet for the engine. Treat it as all rights reserved until
that changes. The bundled Mettle compiler under [`bin/`](bin/) and its
sources mirrored under [`src/`](src/) are Apache-2.0 per the upstream
Mettle project.
