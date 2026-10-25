"""Gera o HABILIDADES.md a partir do catálogo de verdade (src/shared/Skills.lua + DogData + Config) — 2026-10.

Uso:  python tools/preview/skills_doc.py            (escreve HABILIDADES.md na pasta do jogo)
"""
import json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))

DUMP = r'''
local Skills = require(Shared.Skills)
local order = {}
for _, id in ipairs(DogData.Order) do table.insert(order, id) end
local out = { dogs = {}, tiers = {} }
for _, r in ipairs(Config.RARITIES) do
	local t = Config.SKILL_TIER[r]
	table.insert(out.tiers, { r, t.Budget[1], t.Budget[2], t.Budget[3] or 0, t.Cooldown[1], t.Cooldown[2], t.Area, t.Status, t.Charge or 0, Config.RARITY[r].Stat })
end
local function esc(s)
	return (tostring(s or ""):gsub("|", "/"):gsub("\n", " "))
end
for _, id in ipairs(order) do
	local sp = DogData.Species[id]
	local list = Skills.BySpecies[id]
	if list then
		local shotName, shot = DogData.ShotFor(id)
		local row = { id, sp.Name, sp.Rarity, DogData.ElementLabel(id), shot and ("🎯 " .. shot.Name) or "🐾 Combo + 🦷" }
		for i = 1, 3 do
			local s = list[i]
			if s then
				local info = DogData.Specials[s.Id]
				table.insert(row, esc(info and info.Name or s.Id) .. "§" .. esc(s.Pt))
			else
				table.insert(row, "")
			end
		end
		print("ROW|" .. table.concat(row, "|"))
	end
end
for _, t in ipairs(out.tiers) do
	print("TIER|" .. table.concat(t, "|"))
end
'''

HEADER = """# ⚔️ Habilidades de todos os cachorros (versão 2026-10)

Pedido do dono: **refazer as habilidades de todos**, mais diferentes, **com mais animação** e **efeitos especiais únicos**;
**comum = poderes simples e fracos**, cada raridade um pouco melhor, para equilibrar o jogo; e a **4ª habilidade (Supremo)
aparece a partir do Épico**.

## Como funciona
- **1** = ataque (combo pata direita → pata esquerda → mordida, ou o tiro pela boca dos atiradores 🎯). Não mudou.
- **2** e **3** = habilidades próprias de cada cachorro (todas diferentes). Saem onde a setinha está, mesmo sem inimigo.
- **4** = 👑 **SUPREMO**, agora a partir do **Épico** (antes só Mítico e Divino). Enche batendo; quanto mais raro, mais rápido enche.
- Os Míticos e o Divino **guardaram o golpe próprio** na tecla 2 (já era único, ex.: Time Stop, Kraken Grab) e ganharam 3 e 4 novos.
- Cada habilidade é uma sequência com **poses novas** do cachorro (pulo, mortal, rolar, cavar, latir, farejar, coice, cabeçada,
  pisotear, invocar, flexionar, dançar, sacudir...) e **objetos 3D** feitos de peças (graveto, osso, frisbee, cachorro-quente,
  abelha, âncora, shuriken, haltere, espada gigante, OVNI, navio pirata, vulcão, tubarão gigante, sarcófago, máscara de Oni...).
- O Supremo muda o céu/tela de quem está perto (vermelho, dourado, noite, gelo, espaço...).

## ⚖️ Força por raridade (Config.SKILL_TIER)
Cada habilidade gasta um **orçamento** de dano medido em "ataques" do próprio cachorro (o Atk já cresce com a raridade).
O teste sem Roblox (`tools/preview/skills_test.py`) confere que cada habilidade usa ~100% do orçamento no alvo.

| Raridade | Atk (Stat) | Tecla 2 | Tecla 3 | 👑 Supremo | Recarga 2 / 3 | Área | Atordoar/queimar | Supremo enche |
|---|---|---|---|---|---|---|---|---|
"""

FOOTER = """
## 🧪 Como testar sem Roblox
- `python tools/preview/skills_test.py` — roda as 188 habilidades novas num mini-mundo (com os desenhos do cliente de verdade):
  erros, quanto tempo prende o cachorro, dano no alvo em orçamentos, efeitos e poses que não existem.
- `python tools/preview/skill_shots.py saida.json SK_knight_dog_4 ...` — fotos 3D dos efeitos em alguns momentos.
- `python tools/preview/motifs_dump.py saida.json` — galeria de todos os objetos 3D dos poderes.
- `python tools/preview/poses.py saida.json caramelo lista.json` — fotos das poses (inclui as 29 poses novas).
- Arquivos: catálogo `src/shared/Skills.lua` · kit `src/server/Services/SkillKit.lua` · habilidades
  `src/server/Services/SpecialsPacks/Skills_*.lua` · efeitos `src/client/EffectsPacks/PackSkills.lua` · objetos
  `src/client/SkillArt.lua` · poses `src/client/Animator.lua` (seção 6b).
"""

LABEL = {'Common': 'Comuns', 'Uncommon': 'Incomuns', 'Rare': 'Raros', 'Epic': 'Épicos', 'Legendary': 'Lendários',
         'Mythic': 'Míticos', 'Divine': '☀️ Divino'}
NOTE = {
    'Common': 'Simples e fracos: um golpe só, efeito pequeno, fofo e engraçado.',
    'Uncommon': 'Um pouco melhores: 2 tempos e um efeito extra (lento, preso, cura, escudo).',
    'Rare': '2–3 tempos e um estado marcante (choque, veneno, maldição, sono).',
    'Epic': 'Golpes grandes com cenário e o 👑 Supremo liberado.',
    'Legendary': 'Mais tempos e mais área; Supremos maiores.',
    'Mythic': 'Golpe próprio continua (tecla 2); teclas 3 e 4 novas, de cinema.',
    'Divine': 'As maiores do jogo.',
}


def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass
    test = os.path.join(tempfile.gettempdir(), 'skills_doc_dump.luau')
    open(test, 'w', encoding='utf-8').write(DUMP)
    res = subprocess.run([sys.executable, os.path.join(HERE, 'run_shared.py'), test], capture_output=True, text=True, encoding='utf-8', errors='replace')
    if res.returncode != 0:
        sys.exit(res.stderr[-2000:])
    rows, tiers = [], []
    for line in res.stdout.splitlines():
        f = line.split('|')
        if f[0] == 'ROW':
            rows.append(f[1:])
        elif f[0] == 'TIER':
            tiers.append(f[1:])
    md = [HEADER.rstrip()]
    for t in tiers:
        r, b2, b3, b4, c2, c3, area, st, ch, stat = t
        sup = f'{float(b4):.1f}' if float(b4) > 0 else '—'
        charge = f'+{float(ch):g} por golpe' if float(ch) > 0 else '—'
        md.append(f'| {LABEL[r]} | ×{float(stat):g} | {float(b2):.2f} | {float(b3):.2f} | {sup} | {float(c2):g}s / {float(c3):g}s | ×{float(area):g} | ×{float(st):g} | {charge} |')
    md.append('')
    for rarity in ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Mythic', 'Divine']:
        group = [r for r in rows if r[2] == rarity]
        if not group:
            continue
        md.append(f'## {LABEL[rarity]}')
        md.append(NOTE[rarity])
        md.append('')
        has4 = any(r[7] for r in group)
        if has4:
            md.append('| Cachorro | Elementos | 1 | 2 | 3 | 👑 4 Supremo |')
            md.append('|---|---|---|---|---|---|')
        else:
            md.append('| Cachorro | Elementos | 1 | 2 | 3 |')
            md.append('|---|---|---|---|---|')
        for r in group:
            cells = []
            for c in r[5:8 if has4 else 7]:
                if '§' in c:
                    name, pt = c.split('§', 1)
                    cells.append(f'**{name}** — {pt}')
                else:
                    cells.append(c or '—')
            md.append(f'| {r[1]} | {r[3]} | {r[4]} | ' + ' | '.join(cells) + ' |')
        md.append('')
    md.append(FOOTER)
    out = os.path.join(ROOT, 'HABILIDADES.md')
    open(out, 'w', encoding='utf-8').write('\n'.join(md))
    print('ok:', out, len(rows), 'cachorros')


if __name__ == '__main__':
    main()
