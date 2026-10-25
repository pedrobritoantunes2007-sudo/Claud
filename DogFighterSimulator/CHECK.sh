#!/bin/bash
# Verificações do projeto: tipos (API Roblox), propriedades, build.
cd /home/user/DogFighterSimulator
/tmp/rojo/rojo sourcemap default.project.json -o /tmp/sourcemap_check_$$.json >/dev/null
echo "== luau-lsp =="
/tmp/lsp/luau-lsp analyze --definitions=/tmp/lsp/globalTypes.d.luau --sourcemap=/tmp/sourcemap_check_$$.json --flag:LuauSolverV2=false src 2>&1 | grep -v "^\[" | sed 's#/home/user/DogFighterSimulator/##; s#\[game/[^]]*\]##' | sort -u
echo "== propriedades =="
P=/home/user/DogFighterSimulator/tools/propcheck.py; [ -f "$P" ] && python3 "$P" src || echo "(propcheck ausente)"
echo "== build =="
/tmp/rojo/rojo build default.project.json -o /tmp/check_build_$$.rbxlx 2>&1 | tail -1
