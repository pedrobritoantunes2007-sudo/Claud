# Prévia 3D dos cachorros (foto-catálogo) — sem abrir o Roblox

Roda o **DogBuilder de verdade** (`src/shared`) num mini-Roblox (`mock.luau`) e tira fotos com three.js no Chromium.

1. Luau CLI: baixar `luau-ubuntu.zip` de github.com/luau-lang/luau/releases (latest) e descompactar em `/tmp/luau`.
2. Peças:  `python3 tools/preview/dump.py saida.json frost_phoenix caramelo` (ou `ALL`)
   - cachorros só de teste: `--extra tools/preview/candidatos_divino.lua` (mesmo formato dos DogPacks).
3. Foto:   `NODE_PATH=/opt/node22/lib/node_modules node tools/preview/render.js saida.json foto.png opcoes.json`
   - opções: `cols`, `card`, `size`, `order`, `view {yaw, pitch, zoom}`, `labels {id: {label, rarityLabel, labelColor, note, views}}`.
   - three.js está em `vendor/` (veio do npm: `npm pack three@0.160.0`; o jsdelivr é bloqueado aqui).

Limites: não mostra partículas/aura/brilho animado; Neon aparece como cor chapada; peças com CSpin/CWave ficam paradas.

## Poses das animações (2026-10)
`python tools/preview/poses.py saida.json dragon_hound [lista.json]` roda o **Animator.lua de verdade** (`Animator.PoseAt`) em
cima do DogBuilder e salva cada pose como um "cachorro" no mesmo JSON (parado, olhar, andar, galope, pulo, mordida, voo de
avião em curva/mergulho...). Luau: `LUAU=...` ou `Documents/Dog Fighter/ferramentas/luau-0.740/luau.exe`.
Foto: `python -m http.server 8765` nesta pasta, abrir `render.html` e chamar `buildSheet(json, opções)` no console
(ou o render.js com Playwright). `root: {pitch, yaw, roll}` inclina o corpo inteiro (como o voo faz no jogo).

## ⚔️ Habilidades (2026-10)
- `python tools/preview/skills_test.py` — TESTE de todas as habilidades novas (SkillKit + SpecialsPacks/Skills_*.lua) num
  mini-mundo com relógio falso, em 3 cenários (inimigo de verdade, setinha com inimigo perto, setinha sozinha). No cenário 1
  os desenhos do cliente (EffectsPacks/PackSkills.lua + SkillArt.lua) rodam quadro a quadro com os mesmos dados.
  Mostra erros, quanto tempo prende o cachorro, dano no alvo em "orçamentos" (Config.SKILL_TIER), efeitos/poses que não
  existem e parâmetros estranhos. `--all` = uma linha por habilidade · `--no-client` = mais rápido.
- `python tools/preview/skill_shots.py saida.json SK_knight_dog_4 SK_pug_2 --times 0.5,1.2` — FOTOS 3D dos efeitos (cachorros
  do DogBuilder + todas as peças dos efeitos naquele momento). Abrir no render.html (`buildSheet`).
- `python tools/preview/motifs_dump.py saida.json [Nome ...]` — galeria dos 104 objetos dos poderes (client/SkillArt.lua).
- `python tools/preview/skills_doc.py` — gera o `HABILIDADES.md` a partir do catálogo (shared/Skills.lua).
- `python tools/preview/save_server.py 8766 Previa_Habilidades` — servidorzinho que GRAVA PNG mandado pela página
  (`fetch('http://localhost:8766/save', {method:'POST', body: JSON.stringify({name, png: canvas.toDataURL()})})`): assim
  as folhas de fotos viram arquivos de verdade na pasta do jogo.

## 🐶 Folhas de fotos dos cachorros no Windows (2026-10, estilo novo "Blocky2")
- `python tools/preview/dump.py tools/preview/_cache/novo.json ALL` — monta os 80 com o estilo do jogo (`--style Blocky` = o
  estilo antigo, para comparar). No Windows o dump usa o luau de `Documents/Dog Fighter/ferramentas` e a pasta TEMP sozinho.
- Servir esta pasta (`python -m http.server 8765`, config "previa-3d" do launch.json) + `python tools/preview/save_server.py 8766
  Previa_Habilidades` (config "guardar-fotos"). Na página `render.html`:
  `const dogs = await loadDogs('novo.json')` (lê `_cache/`), depois
  `saveSheet('foto.png', [{dog, view: {yaw, pitch, zoom, target, noFloor}, label, sub, color}], {cols, size, labelH, title, folder})`
  — desenha a grade num canvas e grava o PNG; `folder` = outra pasta simples dentro do projeto (ex. `Previa_Cachorros_Novos`).
  Roda em segundo plano: espere `window.progress.saved`. Rosto de perto: `view.target` = posição da peça "Head1" e `zoom` ~2.6.
- `_cache/` é só rascunho (JSON grandes): pode apagar.

## 📜 Missões das ilhas (2026-10)
- `python tools/preview/quest_test.py` — roda o `server/Services/QuestService.lua` de verdade num mini-Roblox com DataService,
  Fighters, ZoneGeo, Monetization e Progression falsos: NPC em cada ilha, menu, aceitar longe/perto, contar selvagens (golpe final e
  ajuda >= 20%), outra ilha não conta, missão de boss, prêmio (2x Cash), Fast Missions, trocar, desistir e missão salva no perfil.
