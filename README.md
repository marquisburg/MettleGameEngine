# Mettle Game Engine

A Windows game engine and editor written in [Mettle](https://github.com/marquisburg/Mettle). No C++, no MSVC, no NASM. Source compiles to `.exe` via Mettle's internal PE linker against `vulkan-1.dll`, `lua55.dll`, and Win32.

Pre-alpha.

## What's in the box

Three executables built from [engine/](engine/):

- **engine_editor.exe**: GDI editor (explorer, inspector, game tree, output log) with a child Vulkan viewport.
- **engine_play_server.exe**: headless authoritative server. Runs `ServerScripts` and replicates over TCP.
- **engine_play_client.exe**: render client. Connects to the server, runs `ClientScripts`, draws via Vulkan.

Press **Play** in the editor: it snapshots the scene, writes `.mettleplay/playtest.manifest`, and spawns the two play binaries as real processes. They talk via the wire format in [engine/engine_play_protocol.mettle](engine/engine_play_protocol.mettle). **Stop** kills them and restores the scene.

## Scripting

Lua 5.5. Folder determines role.

```
ServerScripts/   authoritative, server only
ClientScripts/   client only
SharedScripts/   shared via require()
```

Define `function on_tick(dt)` and the runtime calls it each fixed step (1/60s) with `engine.*` in scope (`get_pos`/`set_pos`, `translate`, `rotate_world`, `input_held`/`pressed`/`released`, `log`, `IA.*`). Full surface is at the top of [engine/engine_lua.mettle](engine/engine_lua.mettle).

## Building

Requirements: Windows 10/11 x64, Vulkan SDK (`vulkan-1.dll` on PATH), Lua 5.5 (`%LOCALAPPDATA%\Programs\Lua` or `LUA_HOME`). The Mettle compiler is checked in at [bin/mettle.exe](bin/mettle.exe).

```powershell
.\build_engine_editor.bat
```

Builds all three binaries and copies `lua55.dll` next to them. Add `--release` for optimized builds, `-s` for symbolized crash tracebacks. Regenerate shaders with `python engine\shaders\regen_spirv.py`.

## Running

```powershell
cd examples
.\engine_editor.exe
```

Opens [project.mproj](project.mproj) and loads [scene.mscene](scene.mscene). Edit in the viewport, double-click scripts to open the inline Lua editor, hit Play.

## Layout

```
engine/      Engine source (all .mettle)
  shaders/   GLSL + regen_spirv.py
examples/    Editor, play server, play client, sample script folders
bin/         Pre-built mettle.exe, runtime, stdlib
src/         Mettle compiler C source (mirrored)
docs/        Mettle language reference (mirrored)
tests/       Smoke tests
```

## Known limitations

- Windows only, Vulkan only. No abstraction layer.
- Renderer is one pipeline, per-vertex color, MVP push constant, depth.
- Single playtest client (server accepts one TCP connection).
- Legacy `SCRIPT_SPIN`/`BOB`/`PLAYER` path still ticks alongside Lua. New scenes should be Lua-only.
- No hot-reload for `.mettle` code. Lua reloads on the next tick.
- See [docs/known-limitations.md](docs/known-limitations.md) for language-level caveats.

## License

No license declared for the engine. All rights reserved until that changes. Bundled Mettle compiler under [bin/](bin/) and [src/](src/) is Apache-2.0 per the [upstream project](https://github.com/marquisburg/Mettle).
