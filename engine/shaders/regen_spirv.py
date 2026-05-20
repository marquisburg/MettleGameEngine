#!/usr/bin/env python3
"""Regenerate engine/engine_vk_shaders.mettle from the GLSL in this directory.

No SPIR-V compiler ships on the build machine and the Windows SDK dxc.exe has
SPIR-V codegen disabled, so this fetches the official Khronos prebuilt
glslangValidator on demand, compiles tri.vert / tri.frag to SPIR-V, then emits
the words as Mettle uint32-fill functions.

Usage (from repo root):  python engine/shaders/regen_spirv.py
Requires network on first run (caches glslang under engine/shaders/.glslang).
"""
import os
import struct
import subprocess
import sys
import urllib.request
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
GLSLANG_DIR = os.path.join(HERE, ".glslang")
GLSLANG_EXE = os.path.join(GLSLANG_DIR, "bin", "glslangValidator.exe")
GLSLANG_URL = ("https://github.com/KhronosGroup/glslang/releases/download/"
               "main-tot/glslang-master-windows-Release.zip")
OUT = os.path.join(REPO, "engine", "engine_vk_shaders.mettle")
SPIRV_MAGIC = 0x07230203


def ensure_glslang():
    if os.path.isfile(GLSLANG_EXE):
        return
    os.makedirs(GLSLANG_DIR, exist_ok=True)
    zpath = os.path.join(GLSLANG_DIR, "glslang.zip")
    print("downloading glslang (one-time)...")
    urllib.request.urlretrieve(GLSLANG_URL, zpath)
    with zipfile.ZipFile(zpath) as z:
        z.extractall(GLSLANG_DIR)
    os.remove(zpath)
    if not os.path.isfile(GLSLANG_EXE):
        sys.exit("glslangValidator.exe not found after extract")


def compile_spv(src, dst):
    subprocess.run([GLSLANG_EXE, "-V", src, "-o", dst], check=True)


def words(path):
    data = open(path, "rb").read()
    assert len(data) % 4 == 0, (path, len(data))
    ws = [struct.unpack("<I", data[i:i + 4])[0] for i in range(0, len(data), 4)]
    assert ws and ws[0] == SPIRV_MAGIC, f"bad SPIR-V magic in {path}"
    return ws


def emit(name, ws):
    out = [
        f"// {name}: {len(ws)} SPIR-V words ({len(ws) * 4} bytes). Compiled from",
        f"// engine/shaders/{name.split('_')[-1]}.* by glslangValidator (Khronos main-tot).",
        f"// Regenerate via engine/shaders/regen_spirv.py; never hand-edit.",
        f"export function {name}_word_count() -> int32 {{ return {len(ws)}; }}",
        f"export function {name}_fill(dst: uint32*) {{",
    ]
    out += [f"  dst[{i}] = (uint32){w};" for i, w in enumerate(ws)]
    out.append("}")
    return "\n".join(out)


def main():
    ensure_glslang()
    vsrc = os.path.join(HERE, "scene.vert")
    fsrc = os.path.join(HERE, "scene.frag")
    vspv = os.path.join(GLSLANG_DIR, "scene.vert.spv")
    fspv = os.path.join(GLSLANG_DIR, "scene.frag.spv")
    compile_spv(vsrc, vspv)
    compile_spv(fsrc, fspv)
    v, f = words(vspv), words(fspv)
    body = "\n".join([
        "// AUTO-GENERATED from engine/shaders/scene.{vert,frag}. Do not edit.",
        "// Regenerate: python engine/shaders/regen_spirv.py",
        "// SPIR-V is little-endian uint32 words fed straight into",
        "// VkShaderModuleCreateInfo.pCode. Scene shaders: MVP push constant,",
        "// per-vertex position + color.",
        "",
        emit("vk_spv_scene_vert", v),
        "",
        emit("vk_spv_scene_frag", f),
        "",
    ])
    open(OUT, "w", newline="\n").write(body)
    print(f"wrote {OUT}: vert {len(v)} words, frag {len(f)} words")


if __name__ == "__main__":
    main()
