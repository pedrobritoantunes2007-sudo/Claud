-- Monta cada cachorro com o DogBuilder de verdade (projeto Roblox) e imprime as peças E as juntas.
-- Roda dentro do pacote montado pelo exportar.py (mock.luau do projeto + módulos de src/shared).
-- Saída (uma linha por item, campos separados por |):
--   DOG|id|nome|raridade|HipHeight|GroundHip|LegLen|BaseScale|Heads|Wings|Float|tamanhoDaRaizY
--   P|indice|classe|sx|sy|sz|cf(12)|r|g|b|material|transparencia|nome
--   J|M ou W|nome|indicePart0|indicePart1|C0(12)|C1(12)
--   A|indice|x|y|z            (WagAxis do pivô do rabo)

local function f(n)
	return string.format("%.4f", n)
end

local function cf12(c)
	local x, y, z, a, b, cc, d, e, g, h, i, j = c:GetComponents()
	return table.concat({ f(x), f(y), f(z), f(a), f(b), f(cc), f(d), f(e), f(g), f(h), f(i), f(j) }, "|")
end

local DogData = require(SHARED.DogData)
local DogBuilder = require(SHARED.DogBuilder)

local wanted = WANTED
if wanted[1] == "ALL" then
	wanted = {}
	for _, id in ipairs(DogData.Order) do
		table.insert(wanted, id)
	end
	local extra = {}
	for id in pairs(DogData.Species) do
		if not table.find(wanted, id) then
			table.insert(extra, id)
		end
	end
	table.sort(extra)
	for _, id in ipairs(extra) do
		table.insert(wanted, id)
	end
end

for _, id in ipairs(wanted) do
	local sp = DogData.Species[id]
	if not sp then
		print("ERR|" .. id .. "|não existe")
		continue
	end
	local ok, model = pcall(DogBuilder.Build, id, {})
	if not ok then
		print("ERR|" .. id .. "|" .. tostring(model))
		continue
	end
	local root = model.PrimaryPart
	print(table.concat({
		"DOG",
		id,
		sp.Name,
		sp.Rarity,
		f(model:GetAttribute("HipHeight") or 0),
		f(model:GetAttribute("GroundHip") or 0),
		f(model:GetAttribute("LegLen") or 0),
		f(model:GetAttribute("BaseScale") or 1),
		tostring(model:GetAttribute("Heads") or 1),
		tostring(model:GetAttribute("Wings") == true),
		tostring(model:GetAttribute("Float") == true),
		f(root and root.Size.Y or 0),
		f(root and root.Size.X or 0),
		f(root and root.Size.Z or 0),
	}, "|"))
	local index = {}
	local n = 0
	local all = model:GetDescendants()
	for _, p in ipairs(all) do
		if p:IsA("BasePart") then
			n += 1
			index[p] = n
			print(table.concat({
				"P",
				tostring(n),
				p.ClassName,
				f(p.Size.X),
				f(p.Size.Y),
				f(p.Size.Z),
				cf12(p.CFrame),
				f(p.Color.R),
				f(p.Color.G),
				f(p.Color.B),
				p.Material and p.Material.Name or "Plastic",
				f(p.Transparency),
				p.Name,
			}, "|"))
			local wag = p:GetAttribute("WagAxis")
			if wag then
				print(table.concat({ "A", tostring(n), f(wag.X), f(wag.Y), f(wag.Z) }, "|"))
			end
		end
	end
	for _, j in ipairs(all) do
		if (j:IsA("Motor6D") or j.ClassName == "Weld") and j.Part0 and j.Part1 and index[j.Part0] and index[j.Part1] then
			print(table.concat({
				"J",
				j:IsA("Motor6D") and "M" or "W",
				j.Name,
				tostring(index[j.Part0]),
				tostring(index[j.Part1]),
				cf12(j.C0),
				cf12(j.C1),
			}, "|"))
		end
	end
end
