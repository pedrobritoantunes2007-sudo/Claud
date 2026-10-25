"""🎨 Galeria dos OBJETOS dos poderes (client/SkillArt.lua) sem Roblox (2026-10).

Monta cada motivo (osso, frisbee, abelha, navio...) sozinho e salva as peças no formato do render.html.
Uso:  python tools/preview/motifs_dump.py saida.json [Nome1 Nome2 ...]   (sem nomes = todos)
Foto: servir tools/preview e abrir render.html: window.buildSheet(json, { cols: 6, view: { yaw: 30, pitch: 20 } }).
"""
import json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import skills_test as T  # noqa: E402


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    out = sys.argv[1]
    names = sys.argv[2:]
    src = T.SRC
    parts = ['local MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
             'local MODULES = {}\n',
             T.module('SkillArt', os.path.join(src, 'client', 'SkillArt.lua'))]
    parts.append('''
game = { GetService = function() return { AddItem = function() end } end }
workspace = Instance.new("Folder")
workspace.BulkMoveTo = function(_, ps, cfs)
	for i, p in ipairs(ps) do
		p.CFrame = cfs[i]
	end
end
local m = Instance.new("ModuleScript")
m.Name = "SkillArt"
local SkillArt = MODULES.SkillArt(m)
local wanted = %s
local list = #wanted > 0 and wanted or SkillArt.Names()
local function f(n)
	return string.format("%%.4f", n)
end
for _, name in ipairs(list) do
	local folder = Instance.new("Folder")
	local rig = SkillArt.Build(name, 1, Color3.fromRGB(255, 120, 60), nil, folder)
	if rig then
		SkillArt.Place(rig, CFrame.new())
		print("DOG|" .. name)
		for _, p in ipairs(rig.Parts) do
			local mesh = p:FindFirstChildOfClass("SpecialMesh")
			local x, y, z, a, b, c, d, e, g, h, i, j = p.CFrame:GetComponents()
			print(table.concat({ "P", p.ClassName, p.Shape and p.Shape.Name or "Block", mesh and "Sphere" or "",
				f(p.Size.X), f(p.Size.Y), f(p.Size.Z), f(x), f(y), f(z), f(a), f(b), f(c), f(d), f(e), f(g), f(h), f(i), f(j),
				f(p.Color.R), f(p.Color.G), f(p.Color.B), p.Material.Name, f(p.Transparency), p.Name }, "|"))
		end
	end
end
''' % T.lua_list(names))
    bundle = os.path.join(tempfile.gettempdir(), 'motifs_bundle.luau')
    open(bundle, 'w', encoding='utf-8').write(''.join(parts))
    res = subprocess.run([T.LUAU, bundle], capture_output=True, text=True, encoding='utf-8', errors='replace')
    if res.returncode != 0:
        sys.stderr.write(res.stdout[-2000:] + res.stderr[-2000:])
        sys.exit('luau falhou')
    cards, cur = [], None
    for line in res.stdout.splitlines():
        f = line.split('|')
        if f[0] == 'DOG':
            cur = {'id': f[1], 'name': '', 'label': f[1], 'rarity': '', 'rarityLabel': '', 'rarityColor': [1, 1, 1],
                   'hip': 0, 'rootY': 0, 'parts': []}
            cards.append(cur)
        elif f[0] == 'P' and cur is not None:
            cur['parts'].append({'cls': f[1], 'shape': f[2], 'mesh': f[3], 'size': [float(v) for v in f[4:7]],
                                 'cf': [float(v) for v in f[7:19]], 'color': [float(v) for v in f[19:22]],
                                 'mat': f[22], 'tr': float(f[23]), 'name': f[24]})
    json.dump(cards, open(out, 'w'))
    print('ok:', len(cards), 'objetos')


if __name__ == '__main__':
    main()
