#!/bin/bash
# Verificações do projeto no PC do dono (Windows, Git Bash): tipos (API Roblox) e build.
# Igual ao CHECK.sh, mas com as ferramentas de Documents/Dog Fighter/ferramentas
# (rojo.exe, luau-lsp.exe + globalTypes.d.luau da mesma época). Uso: bash CHECK_PC.sh
cd "$(dirname "$0")"
T="../../ferramentas"
MAP="${TEMP:-/tmp}/df_sourcemap_check.json"
"$T/rojo.exe" sourcemap default.project.json -o "$MAP" >/dev/null
echo "== luau-lsp =="
"$T/luau-lsp.exe" analyze --definitions="$T/globalTypes.d.luau" --sourcemap="$MAP" --flag:LuauSolverV2=false src 2>&1 | tr -d '\r' | grep -v '^\[INFO\]\|didChangeWatchedFiles' | sort -u
echo "== build =="
"$T/rojo.exe" build default.project.json -o "${TEMP:-/tmp}/df_check_build.rbxlx" 2>&1 | tail -1
