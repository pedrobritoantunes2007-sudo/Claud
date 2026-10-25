# Foto do HUD de verdade — sem abrir o Roblox

Roda o **HUD do jogo de verdade** (`src/client/UI/HUD.lua`, `Kit`, `Icons3D`, `TouchPad`, `Systems/Abilities`, `Systems/Music`)
num mini-Roblox de telas (`mock_gui.luau` em cima do `tools/preview/mock.luau`) e desenha a tela no Chromium.

1. Luau CLI em `/tmp/luau/luau` (github.com/luau-lang/luau/releases → luau-ubuntu.zip).
2. Árvore de telas: `python3 tools/hud_preview/hud_dump.py <tela> /tmp/h.json [estados]`
   - tela: `pc` (1920x1080), `phone` (844x390, toque) ou `LxA` / `LxAt` (t = toque), ex.: `1366x768`, `667x375t`, `1024x768t`.
   - estados (vírgula): `ko, awake, colosseum, home, pvp, mythic, longname, allclaimed, reserve, streak, noteam`.
3. Foto: `node tools/hud_preview/hud_render.js /tmp/h.json foto.png` (Playwright + Chromium; three.js está nesta pasta).
- `fonts_metrics.json` = largura das letras (Luckiest Guy e Fredoka One), medida no Chromium por `measure_fonts.js`.
- `hud_mock.html` + `render_hud.js` = a PRÉVIA desenhada à mão que o dono aprovou (estilos escuro/claro/colorido).

Limites: não anima (tweens pulam para o fim), luz 3D aproximada, fundo fixo (Puppy Meadows). Não substitui o print do dono.
