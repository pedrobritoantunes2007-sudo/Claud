"""Monta as casinhas (5 níveis), os estandes e as tigelas do HouseBuilder de verdade no mini-Roblox, confere os
nomes que outros sistemas procuram e salva no formato do islands_render.js.
Uso: python3 tools/preview/houses_dump.py saida.json
"""
import glob, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.abspath(os.path.join(HERE, '..', '..', 'src'))
LUAU = os.environ.get('LUAU', '/tmp/luau/luau')
out_path = sys.argv[1]
parts = ['local MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
         'local MODULES = {}\n', open(os.path.join(HERE, 'mock_world.luau'), encoding='utf-8').read() + '\n']
tree = []
for p in sorted(glob.glob(os.path.join(SRC, 'shared', '*.lua'))):
    n = os.path.basename(p)[:-4]
    parts.append(f'MODULES[{json.dumps("Shared/" + n)}] = function(script)\n{open(p, encoding="utf-8").read()}\nend\n')
    tree.append(['Shared/' + n, ['ReplicatedStorage', 'Shared'], n])
for p in sorted(glob.glob(os.path.join(SRC, 'shared', 'DogPacks', '*.lua'))):
    n = os.path.basename(p)[:-4]
    parts.append(f'MODULES[{json.dumps("Shared/DogPacks/" + n)}] = function(script)\n{open(p, encoding="utf-8").read()}\nend\n')
    tree.append(['Shared/DogPacks/' + n, ['ReplicatedStorage', 'Shared', 'DogPacks'], n])
p = os.path.join(SRC, 'server', 'Services', 'HouseBuilder.lua')
parts.append(f'MODULES["Services/HouseBuilder"] = function(script)\n{open(p, encoding="utf-8").read()}\nend\n')
tree.append(['Services/HouseBuilder', ['ServerScriptService', 'Server', 'Services'], 'HouseBuilder'])
parts.append('MOCK_TREE = ' + json.dumps(tree).replace('[', '{').replace(']', '}') + '\n')
parts.append(r'''
mockTree(MOCK_TREE)
local HB = require(game:GetService("ServerScriptService").Server.Services.HouseBuilder)
local root = Instance.new("Folder")
root.Parent = workspace
local problems = {}
local out = {}
local function export(m, label)
	local n, round = 0, 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
			if d.Shape and d.Shape ~= Enum.PartType.Block then
				round += 1
			end
			local c = { d.CFrame:GetComponents() }
			local col = d.Color
			table.insert(out, { d.ClassName == "WedgePart" and "Wedge" or d.ClassName == "CornerWedgePart" and "Corner" or "Block", d.Size.X, d.Size.Y, d.Size.Z, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12], math.floor(col.R * 255 + 0.5), math.floor(col.G * 255 + 0.5), math.floor(col.B * 255 + 0.5), d.Material and d.Material.Name or "SmoothPlastic", d.Transparency or 0 })
		end
	end
	print(string.format("%s: %d peças%s", label, n, round > 0 and (" (" .. round .. " REDONDAS!)") or ""))
end
for lv = 1, 5 do
	local ok, err = pcall(function()
		local cf = CFrame.new((lv - 3) * 60, 0, 0)
		local m = HB.House(lv, cf, "Buddy")
		m.Parent = root
		if m.Name ~= "Casa" then table.insert(problems, "casa " .. lv .. ": nome " .. m.Name) end
		if not m.PrimaryPart or m.PrimaryPart.Name ~= "Paredes" then table.insert(problems, "casa " .. lv .. ": PrimaryPart não é Paredes") end
		if m:GetAttribute("Nivel") ~= lv then table.insert(problems, "casa " .. lv .. ": atributo Nivel") end
		export(m, "Casa nível " .. lv)
		local st, body = HB.Stand(lv, cf * CFrame.new(15.5, 0, 2))
		st.Parent = root
		if not body then table.insert(problems, "estande " .. lv .. ": não devolveu o Corpo") end
		export(st, "Estande nível " .. lv)
		local bw = HB.Bowl(lv, cf * CFrame.new(0, 0, -15))
		bw.Parent = root
		if not bw:FindFirstChild("Racao", true) then table.insert(problems, "tigela " .. lv .. ": sem Racao") end
	end)
	if not ok then
		table.insert(problems, "nível " .. lv .. " deu ERRO: " .. tostring(err))
	end
end
-- 2ª casa de cada nível vem do MOLDE (cache): tem que ser igual à 1ª, só que em outro lugar, girada e com outro nome
for lv = 1, 5 do
	local ok, err = pcall(function()
		local cfA = CFrame.new((lv - 3) * 60, 0, 0)
		local cfB = CFrame.new((lv - 3) * 60 + 7, 0, 300) * CFrame.Angles(0, 1.1, 0)
		local a = HB.House(lv, cfA, "Buddy")
		local b = HB.House(lv, cfB, "Rex")
		local pa, pb = {}, {}
		for _, d in ipairs(a:GetDescendants()) do
			if d:IsA("BasePart") then table.insert(pa, d) end
		end
		for _, d in ipairs(b:GetDescendants()) do
			if d:IsA("BasePart") then table.insert(pb, d) end
		end
		if #pa ~= #pb then
			table.insert(problems, "casa " .. lv .. " do molde: " .. #pb .. " peças (devia " .. #pa .. ")")
			return
		end
		local worst = 0
		for i = 1, #pa do
			local ra = cfA:ToObjectSpace(pa[i].CFrame)
			local rb = cfB:ToObjectSpace(pb[i].CFrame)
			worst = math.max(worst, (ra.Position - rb.Position).Magnitude, (pa[i].Size - pb[i].Size).Magnitude)
		end
		if worst > 1e-3 then
			table.insert(problems, string.format("casa %d do molde: peça fora do lugar (%.3f)", lv, worst))
		end
		if not b.PrimaryPart or b.PrimaryPart.Name ~= "Paredes" or b:GetAttribute("Nivel") ~= lv then
			table.insert(problems, "casa " .. lv .. " do molde: PrimaryPart/Nivel errado")
		end
		-- placas: o que era "Buddy" na casa montada do zero vira "Rex" na cópia; o resto (ex.: CHAMPION) fica igual
		local la, lb = {}, {}
		for _, d in ipairs(a:GetDescendants()) do
			if d.ClassName == "TextLabel" then table.insert(la, d.Text) end
		end
		for _, d in ipairs(b:GetDescendants()) do
			if d.ClassName == "TextLabel" then table.insert(lb, d.Text) end
		end
		local names = 0
		for i, t in ipairs(la) do
			local want = (t == "Buddy") and "Rex" or t
			if lb[i] ~= want then
				table.insert(problems, "casa " .. lv .. " do molde: placa '" .. tostring(lb[i]) .. "' (devia '" .. want .. "')")
			elseif want == "Rex" then
				names += 1
			end
		end
		local cells = 0
		for _, d in ipairs(b:GetDescendants()) do
			if d:GetAttribute("Cell") ~= nil then
				cells += 1
				if (d:GetAttribute("Cell") - cfB.Position).Magnitude > 1e-3 then
					table.insert(problems, "casa " .. lv .. " do molde: célula de detalhe com centro errado")
				end
			end
		end
		print(string.format("Casa nível %d copiada do molde: %d peças iguais, %d placa(s) com 'Rex', %d célula(s) no lugar", lv, #pb, names, cells))
	end)
	if not ok then
		table.insert(problems, "molde nível " .. lv .. " deu ERRO: " .. tostring(err))
	end
end
print(#problems == 0 and "OK: nomes e peças que os outros sistemas procuram estão certos" or ("PROBLEMAS:\n  " .. table.concat(problems, "\n  ")))
print("@@JSON@@" .. toJSON({ islands = { casas = { parts = out, terrain = {}, center = { 0, 0, 0 }, yaw = 0 } }, palette = {} }))
''')
bundle = f'/tmp/houses_dump_bundle_{os.getpid()}.luau'
open(bundle, 'w', encoding='utf-8').write(''.join(parts))
res = subprocess.run([LUAU, bundle], capture_output=True, text=True)
data = None
for l in res.stdout.splitlines():
    if l.startswith('@@JSON@@'):
        data = l[8:]
    else:
        print(l)
if res.returncode != 0:
    sys.stderr.write(res.stderr[-4000:])
    sys.exit(1)
open(out_path, 'w').write(data)
print('ok:', out_path)
