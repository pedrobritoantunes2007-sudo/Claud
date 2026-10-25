-- 🎩 ACESSÓRIOS (2026-10-25, pedido do dono: "chapéu, coleira, óculos e capa. Todo mundo vê, e cada um dá um bônus
-- pequeno (Cash, XP, captura ou velocidade). Dá para comprar com Cash e alguns especiais com Robux.")
-- 4 lugares (Slot): Hat, Collar, Glasses, Cape — 1 de cada no cachorro que está em campo (o mesmo visual vale para
-- qualquer cachorro que você equipar). Todo mundo vê: o servidor monta as peças no cachorro (Accessories.Attach).
-- Preço: Price = Cash · Robux = chave do produto na loja de Robux (Shared/Monetization: "Acc_<id>") · Season = só
-- no 🎟️ Passe de Temporada. Bonus = { Cash | XP | Catch | Speed = fração } (0.04 = +4%); somam entre os 4 lugares
-- (até MAX_BONUS de cada tipo). Quem aplica: MonetizationService (Cash/XP/velocidade) e CatchService (captura).
-- Perfil: data.Acc = { Owned = { [id] = true }, On = { [slot] = id } } (Services/AccessoryService).
local Accessories = {}

local C = Color3.fromRGB
local SM = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

Accessories.SLOTS = { "Hat", "Collar", "Glasses", "Cape" }
Accessories.SLOT_NAME = { Hat = "HATS", Collar = "COLLARS", Glasses = "GLASSES", Cape = "CAPES" }
Accessories.SLOT_ICON = { Hat = "hat", Collar = "paw", Glasses = "star", Cape = "wing" }
Accessories.MAX_BONUS = 0.3
Accessories.BONUS_TEXT = { Cash = "Cash", XP = "XP", Catch = "catch chance", Speed = "speed" }
Accessories.BONUS_ICON = { Cash = "coins", XP = "xp", Catch = "leash", Speed = "wind" }

-- Ordem = ordem na loja. Id nunca muda depois de lançar (fica salvo no perfil).
Accessories.List = {
	---------------------------------------------------------------- 🎩 chapéus
	{ Id = "cap", Slot = "Hat", Name = "Red Cap", Price = 2500, Bonus = { Speed = 0.03 }, Color = C(225, 50, 55) },
	{ Id = "cowboy", Slot = "Hat", Name = "Cowboy Hat", Price = 8000, Bonus = { Cash = 0.04 }, Color = C(160, 105, 60) },
	{ Id = "party", Slot = "Hat", Name = "Party Hat", Price = 20000, Bonus = { XP = 0.05 }, Color = C(80, 170, 255) },
	{ Id = "wizard", Slot = "Hat", Name = "Wizard Hat", Price = 60000, Bonus = { Catch = 0.05 }, Color = C(110, 60, 200) },
	{ Id = "crown", Slot = "Hat", Name = "Royal Crown", Robux = "Acc_crown", Bonus = { Cash = 0.1 }, Color = C(255, 205, 60) },
	{ Id = "season_cap", Slot = "Hat", Name = "Season 1 Cap", Season = true, Bonus = { XP = 0.06 }, Color = C(70, 210, 200) },
	---------------------------------------------------------------- 🐾 coleiras
	{ Id = "bandana", Slot = "Collar", Name = "Red Bandana", Price = 1500, Bonus = { Speed = 0.02 }, Color = C(220, 45, 50) },
	{ Id = "spiked", Slot = "Collar", Name = "Spiked Collar", Price = 6000, Bonus = { XP = 0.03 }, Color = C(40, 36, 44) },
	{ Id = "bell", Slot = "Collar", Name = "Golden Bell", Price = 25000, Bonus = { Catch = 0.04 }, Color = C(230, 60, 70) },
	{ Id = "bowtie", Slot = "Collar", Name = "Fancy Bow Tie", Price = 50000, Bonus = { Cash = 0.05 }, Color = C(40, 40, 60) },
	{ Id = "diamond", Slot = "Collar", Name = "Diamond Collar", Robux = "Acc_diamond", Bonus = { Catch = 0.08 }, Color = C(200, 230, 255) },
	---------------------------------------------------------------- 🕶️ óculos
	{ Id = "shades", Slot = "Glasses", Name = "Cool Shades", Price = 3000, Bonus = { Speed = 0.03 }, Color = C(30, 30, 40) },
	{ Id = "nerd", Slot = "Glasses", Name = "Nerd Glasses", Price = 10000, Bonus = { XP = 0.04 }, Color = C(30, 30, 40) },
	{ Id = "hearts", Slot = "Glasses", Name = "Heart Glasses", Price = 30000, Bonus = { Cash = 0.04 }, Color = C(255, 90, 160) },
	{ Id = "visor", Slot = "Glasses", Name = "Star Visor", Robux = "Acc_visor", Bonus = { XP = 0.1 }, Color = C(90, 240, 255) },
	---------------------------------------------------------------- 🦸 capas
	{ Id = "hero", Slot = "Cape", Name = "Hero Cape", Price = 12000, Bonus = { Speed = 0.04 }, Color = C(225, 40, 50) },
	{ Id = "batwings", Slot = "Cape", Name = "Bat Wings", Price = 40000, Bonus = { XP = 0.05 }, Color = C(50, 40, 60) },
	{ Id = "royal", Slot = "Cape", Name = "Royal Cape", Price = 80000, Bonus = { Cash = 0.06 }, Color = C(120, 50, 180) },
	{ Id = "galaxy", Slot = "Cape", Name = "Galaxy Cape", Robux = "Acc_galaxy", Bonus = { Speed = 0.08 }, Color = C(40, 40, 120) },
	{ Id = "season_cape", Slot = "Cape", Name = "Season 1 Cape", Season = true, Bonus = { Catch = 0.06 }, Color = C(70, 210, 200) },
}

Accessories.ById = {}
for i, a in ipairs(Accessories.List) do
	a.Order = i
	Accessories.ById[a.Id] = a
end

function Accessories.Get(id)
	return type(id) == "string" and Accessories.ById[id] or nil
end

-- texto do bônus: "+4% Cash"
function Accessories.BonusText(item)
	local parts = {}
	for kind, v in pairs(item and item.Bonus or {}) do
		table.insert(parts, string.format("+%d%% %s", math.floor(v * 100 + 0.5), Accessories.BONUS_TEXT[kind] or kind))
	end
	table.sort(parts)
	return table.concat(parts, " · ")
end

-- bônus somado do que está equipado: on = { [slot] = id } → { Cash, XP, Catch, Speed }
function Accessories.Bonus(on)
	local total = { Cash = 0, XP = 0, Catch = 0, Speed = 0 }
	if type(on) ~= "table" then
		return total
	end
	for _, slot in ipairs(Accessories.SLOTS) do
		local item = Accessories.Get(on[slot])
		if item and item.Slot == slot then
			for kind, v in pairs(item.Bonus or {}) do
				if total[kind] then
					total[kind] = math.min(Accessories.MAX_BONUS, total[kind] + v)
				end
			end
		end
	end
	return total
end

---------------------------------------------------------------- 🎨 peças no cachorro
-- Cada peça é soldada na cabeça (Head1, ou a do meio nos de 3 cabeças) ou no tronco (Torso): acompanha as animações.
-- Medidas pelo tamanho de verdade das peças (o cachorro grande ganha chapéu grande). O cachorro olha para −Z.
local function headOf(model)
	local heads = model:GetAttribute("Heads")
	return (heads == 3 and model:FindFirstChild("Head2")) or model:FindFirstChild("Head1")
end

local function adder(model, folder)
	return function(anchor, name, size, color, cf, material, alpha)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(math.max(0.05, size.X), math.max(0.05, size.Y), math.max(0.05, size.Z))
		p.Color = color
		p.Material = material or SM
		p.Transparency = alpha or 0
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.Anchored = false
		p.CFrame = anchor.CFrame * cf
		p:SetAttribute("Acessorio", true)
		local w = Instance.new("WeldConstraint")
		w.Part0 = anchor
		w.Part1 = p
		w.Parent = p
		p.Parent = folder
		return p
	end
end

local function V(x, y, z)
	return Vector3.new(x, y, z)
end
local CF = CFrame.new
local ANG = CFrame.Angles

local GOLD, GOLD_D = C(255, 205, 60), C(205, 150, 40)
local WHITE, BLACK = C(250, 250, 250), C(25, 22, 30)

-- desenho de cada acessório: build(add, head, torso, item) — h/t = { part, x, y, z } (meias medidas)
local BUILD = {}

------------------------------------------------ chapéus (em cima da cabeça: y = +hy)
function BUILD.cap(add, h, _t, item)
	local x, y, z = h.x, h.y, h.z
	add(h.p, "Bone", V(x * 1.7, y * 0.6, z * 1.6), item.Color, CF(0, y + y * 0.28, z * 0.05))
	add(h.p, "Aba", V(x * 1.5, y * 0.1, z * 0.9), item.Color:Lerp(BLACK, 0.2), CF(0, y + y * 0.05, -z * 1.05))
	add(h.p, "Botao", V(x * 0.3, y * 0.12, z * 0.3), WHITE, CF(0, y + y * 0.64, z * 0.05))
end
function BUILD.cowboy(add, h, _t, item)
	local x, y, z = h.x, h.y, h.z
	add(h.p, "Aba", V(x * 2.8, y * 0.1, z * 2.5), item.Color, CF(0, y + y * 0.06, 0))
	add(h.p, "Copa", V(x * 1.3, y * 0.7, z * 1.2), item.Color:Lerp(BLACK, 0.1), CF(0, y + y * 0.45, 0))
	add(h.p, "Fita", V(x * 1.34, y * 0.14, z * 1.24), C(60, 40, 30), CF(0, y + y * 0.2, 0))
end
function BUILD.party(add, h, _t, item)
	local x, y = h.x, h.y
	local cols = { item.Color, C(255, 220, 70), C(255, 110, 170) }
	for i = 0, 3 do
		local k = 1 - i / 4
		add(h.p, "Cone", V(x * 1.1 * k + x * 0.15, y * 0.3, x * 1.1 * k + x * 0.15), cols[i % 3 + 1], CF(0, y + y * (0.15 + i * 0.28), 0) * ANG(0, 0, -0.12))
	end
	add(h.p, "Pompom", V(x * 0.35, x * 0.35, x * 0.35), WHITE, CF(-y * 0.12, y + y * 1.32, 0))
end
function BUILD.wizard(add, h, _t, item)
	local x, y, z = h.x, h.y, h.z
	add(h.p, "Aba", V(x * 2.4, y * 0.08, z * 2.2), item.Color:Lerp(BLACK, 0.25), CF(0, y + y * 0.05, 0))
	for i = 0, 4 do
		local k = 1 - i / 5
		add(h.p, "Cone", V(x * 1.3 * k + x * 0.1, y * 0.36, x * 1.3 * k + x * 0.1), item.Color, CF(i * x * 0.05, y + y * (0.25 + i * 0.32), 0) * ANG(0, 0, -0.1 * i))
	end
	add(h.p, "Estrela", V(x * 0.3, x * 0.3, x * 0.06), C(255, 225, 80), CF(0, y + y * 0.55, -x * 0.62) * ANG(0, 0, math.pi / 4), NEON)
end
function BUILD.crown(add, h, _t, item)
	local x, y, z = h.x, h.y, h.z
	local w, d, hh = x * 1.4, z * 1.4, y * 0.42
	add(h.p, "Aro", V(w, hh, z * 0.12), item.Color, CF(0, y + hh / 2, -d / 2))
	add(h.p, "Aro", V(w, hh, z * 0.12), item.Color, CF(0, y + hh / 2, d / 2))
	add(h.p, "Aro", V(x * 0.12, hh, d), item.Color, CF(-w / 2, y + hh / 2, 0))
	add(h.p, "Aro", V(x * 0.12, hh, d), item.Color, CF(w / 2, y + hh / 2, 0))
	for _, sx in ipairs({ -1, 0, 1 }) do
		add(h.p, "Ponta", V(x * 0.22, y * 0.3, x * 0.22), GOLD_D, CF(sx * w * 0.38, y + hh + y * 0.12, -d / 2) * ANG(0, math.pi / 4, 0))
	end
	add(h.p, "Joia", V(x * 0.26, x * 0.26, x * 0.1), C(255, 50, 90), CF(0, y + hh * 0.5, -d / 2 - z * 0.07) * ANG(0, 0, math.pi / 4), NEON)
	add(h.p, "Joia", V(x * 0.18, x * 0.18, x * 0.1), C(60, 160, 255), CF(-w * 0.32, y + hh * 0.5, -d / 2 - z * 0.07) * ANG(0, 0, math.pi / 4), NEON)
	add(h.p, "Joia", V(x * 0.18, x * 0.18, x * 0.1), C(60, 220, 120), CF(w * 0.32, y + hh * 0.5, -d / 2 - z * 0.07) * ANG(0, 0, math.pi / 4), NEON)
end
function BUILD.season_cap(add, h, t, item)
	BUILD.cap(add, h, t, item)
	add(h.p, "Estrela", V(h.x * 0.4, h.x * 0.4, h.x * 0.06), C(255, 225, 80), CF(0, h.y + h.y * 0.3, -h.z * 0.82) * ANG(0, 0, math.pi / 4), NEON)
end

------------------------------------------------ coleiras (no pescoço: frente de cima do tronco)
local function ring(add, t, color, thick)
	local x, y, z = t.x, t.y, t.z
	local cx, cy, cz = 0, y * 0.5, -z * 0.72
	local w, d = x * 1.55, z * 0.42
	thick = thick or y * 0.28
	add(t.p, "Coleira", V(w, thick, x * 0.16), color, CF(cx, cy, cz - d / 2))
	add(t.p, "Coleira", V(w, thick, x * 0.16), color, CF(cx, cy, cz + d / 2))
	add(t.p, "Coleira", V(x * 0.16, thick, d), color, CF(cx - w / 2, cy, cz))
	add(t.p, "Coleira", V(x * 0.16, thick, d), color, CF(cx + w / 2, cy, cz))
	return CF(cx, cy, cz - d / 2 - x * 0.1)
end
function BUILD.bandana(add, _h, t, item)
	local front = ring(add, t, item.Color, t.y * 0.22)
	add(t.p, "Lenco", V(t.x * 0.9, t.x * 0.9, t.x * 0.1), item.Color, front * CF(0, -t.y * 0.3, 0) * ANG(0, 0, math.pi / 4))
	add(t.p, "Bolinha", V(t.x * 0.14, t.x * 0.14, t.x * 0.04), WHITE, front * CF(-t.x * 0.15, -t.y * 0.25, -t.x * 0.06))
	add(t.p, "Bolinha", V(t.x * 0.14, t.x * 0.14, t.x * 0.04), WHITE, front * CF(t.x * 0.18, -t.y * 0.42, -t.x * 0.06))
end
function BUILD.spiked(add, _h, t, item)
	ring(add, t, item.Color)
	local x, y, z = t.x, t.y, t.z
	for i = -2, 2 do
		add(t.p, "Espinho", V(x * 0.14, x * 0.14, x * 0.14), C(220, 225, 235), CF(i * x * 0.3, y * 0.5, -z * 0.72 - z * 0.21 - x * 0.12) * ANG(math.pi / 4, 0, math.pi / 4))
	end
end
function BUILD.bell(add, _h, t, item)
	local front = ring(add, t, item.Color)
	add(t.p, "Sino", V(t.x * 0.42, t.x * 0.42, t.x * 0.42), GOLD, front * CF(0, -t.y * 0.32, -t.x * 0.08))
	add(t.p, "SinoBoca", V(t.x * 0.3, t.x * 0.06, t.x * 0.3), GOLD_D, front * CF(0, -t.y * 0.52, -t.x * 0.08))
end
function BUILD.bowtie(add, _h, t, item)
	local front = ring(add, t, item.Color, t.y * 0.16)
	add(t.p, "Laco", V(t.x * 0.55, t.x * 0.42, t.x * 0.14), C(220, 40, 60), front * CF(-t.x * 0.3, 0, -t.x * 0.04) * ANG(0, 0, 0.25))
	add(t.p, "Laco", V(t.x * 0.55, t.x * 0.42, t.x * 0.14), C(220, 40, 60), front * CF(t.x * 0.3, 0, -t.x * 0.04) * ANG(0, 0, -0.25))
	add(t.p, "No", V(t.x * 0.2, t.x * 0.24, t.x * 0.18), C(180, 25, 45), front * CF(0, 0, -t.x * 0.06))
end
function BUILD.diamond(add, _h, t, item)
	local front = ring(add, t, C(210, 215, 230))
	add(t.p, "Diamante", V(t.x * 0.42, t.x * 0.42, t.x * 0.42), item.Color, front * CF(0, -t.y * 0.34, -t.x * 0.1) * ANG(math.pi / 4, 0, math.pi / 4), NEON)
end

------------------------------------------------ óculos (na frente da cabeça: z = −hz)
local function lensPos(h)
	return h.x * 0.42, h.y * 0.18, -h.z - h.z * 0.04
end
function BUILD.shades(add, h, _t, item)
	local lx, ly, lz = lensPos(h)
	for _, s in ipairs({ -1, 1 }) do
		add(h.p, "Lente", V(h.x * 0.62, h.y * 0.38, h.z * 0.08), item.Color, CF(s * lx, ly, lz))
		add(h.p, "Haste", V(h.x * 0.08, h.y * 0.08, h.z * 0.9), item.Color, CF(s * h.x * 0.98, ly + h.y * 0.08, -h.z * 0.5))
		add(h.p, "Brilho", V(h.x * 0.14, h.y * 0.1, h.z * 0.02), WHITE, CF(s * lx - h.x * 0.14, ly + h.y * 0.08, lz - h.z * 0.05), SM, 0.3)
	end
	add(h.p, "Ponte", V(h.x * 0.3, h.y * 0.08, h.z * 0.08), item.Color, CF(0, ly + h.y * 0.1, lz))
end
function BUILD.nerd(add, h, _t, item)
	local lx, ly, lz = lensPos(h)
	for _, s in ipairs({ -1, 1 }) do
		local cx = s * lx
		add(h.p, "Aro", V(h.x * 0.6, h.y * 0.08, h.z * 0.08), item.Color, CF(cx, ly + h.y * 0.2, lz))
		add(h.p, "Aro", V(h.x * 0.6, h.y * 0.08, h.z * 0.08), item.Color, CF(cx, ly - h.y * 0.2, lz))
		add(h.p, "Aro", V(h.x * 0.08, h.y * 0.48, h.z * 0.08), item.Color, CF(cx - h.x * 0.27, ly, lz))
		add(h.p, "Aro", V(h.x * 0.08, h.y * 0.48, h.z * 0.08), item.Color, CF(cx + h.x * 0.27, ly, lz))
		add(h.p, "Lente", V(h.x * 0.48, h.y * 0.36, h.z * 0.03), C(200, 235, 255), CF(cx, ly, lz + h.z * 0.01), SM, 0.55)
		add(h.p, "Haste", V(h.x * 0.08, h.y * 0.08, h.z * 0.9), item.Color, CF(s * h.x * 0.98, ly + h.y * 0.12, -h.z * 0.5))
	end
	add(h.p, "Ponte", V(h.x * 0.24, h.y * 0.08, h.z * 0.08), item.Color, CF(0, ly + h.y * 0.1, lz))
end
function BUILD.hearts(add, h, _t, item)
	local lx, ly, lz = lensPos(h)
	for _, s in ipairs({ -1, 1 }) do
		local cx = s * lx
		add(h.p, "Coracao", V(h.x * 0.34, h.x * 0.34, h.z * 0.08), item.Color, CF(cx - h.x * 0.1, ly + h.y * 0.06, lz) * ANG(0, 0, math.pi / 4))
		add(h.p, "Coracao", V(h.x * 0.34, h.x * 0.34, h.z * 0.08), item.Color, CF(cx + h.x * 0.1, ly + h.y * 0.06, lz) * ANG(0, 0, math.pi / 4))
		add(h.p, "Coracao", V(h.x * 0.36, h.x * 0.36, h.z * 0.08), item.Color, CF(cx, ly - h.y * 0.08, lz) * ANG(0, 0, math.pi / 4))
		add(h.p, "Haste", V(h.x * 0.08, h.y * 0.08, h.z * 0.9), item.Color:Lerp(BLACK, 0.3), CF(s * h.x * 0.98, ly + h.y * 0.1, -h.z * 0.5))
	end
end
function BUILD.visor(add, h, _t, item)
	local _, ly, lz = lensPos(h)
	add(h.p, "Visor", V(h.x * 1.95, h.y * 0.34, h.z * 0.1), item.Color, CF(0, ly, lz), NEON, 0.15)
	add(h.p, "Moldura", V(h.x * 2.05, h.y * 0.08, h.z * 0.12), C(230, 235, 245), CF(0, ly + h.y * 0.2, lz))
	for _, s in ipairs({ -1, 1 }) do
		add(h.p, "Haste", V(h.x * 0.1, h.y * 0.12, h.z * 0.9), C(230, 235, 245), CF(s * h.x * 1.0, ly, -h.z * 0.5))
	end
end

------------------------------------------------ capas (nas costas: em cima do tronco)
local function cape(add, t, color, trim)
	local x, y, z = t.x, t.y, t.z
	add(t.p, "Capa", V(x * 1.9, y * 0.1, z * 1.55), color, CF(0, y + y * 0.04, z * 0.12))
	for _, s in ipairs({ -1, 1 }) do
		add(t.p, "CapaLado", V(x * 0.1, y * 1.0, z * 1.45), color:Lerp(BLACK, 0.12), CF(s * (x + x * 0.04), y * 0.5, z * 0.15))
	end
	add(t.p, "Fecho", V(x * 0.36, x * 0.36, x * 0.12), trim or GOLD, CF(0, y * 0.75, -z * 0.78))
	if trim then
		add(t.p, "Barra", V(x * 1.94, y * 0.14, z * 0.12), trim, CF(0, y + y * 0.04, z * 0.9))
	end
end
function BUILD.hero(add, _h, t, item)
	cape(add, t, item.Color, GOLD)
	add(t.p, "Emblema", V(t.x * 0.6, t.y * 0.04, t.x * 0.6), GOLD, CF(0, t.y + t.y * 0.1, t.z * 0.2) * ANG(0, math.pi / 4, 0))
end
function BUILD.royal(add, _h, t, item)
	cape(add, t, item.Color, WHITE)
	for i = -1, 1 do
		add(t.p, "Pinta", V(t.x * 0.12, t.y * 0.04, t.x * 0.2), BLACK, CF(i * t.x * 0.6, t.y + t.y * 0.1, t.z * 0.9))
	end
end
function BUILD.batwings(add, _h, t, item)
	local x, y = t.x, t.y
	for _, s in ipairs({ -1, 1 }) do
		add(t.p, "Asa", V(x * 1.6, y * 0.08, x * 1.1), item.Color, CF(s * x * 1.5, y + y * 0.3, 0) * ANG(0, 0, s * 0.35))
		add(t.p, "Asa", V(x * 1.1, y * 0.08, x * 0.8), item.Color:Lerp(C(150, 30, 60), 0.3), CF(s * x * 2.3, y + y * 0.6, x * 0.3) * ANG(0, 0, s * 0.55))
		add(t.p, "AsaOsso", V(x * 2.2, y * 0.12, x * 0.12), C(30, 25, 35), CF(s * x * 1.75, y + y * 0.42, -x * 0.5) * ANG(0, 0, s * 0.42))
	end
end
function BUILD.galaxy(add, _h, t, item)
	cape(add, t, item.Color, C(160, 120, 255))
	local rng = Random.new(7)
	for _ = 1, 7 do
		add(t.p, "Estrela", V(t.x * 0.14, t.y * 0.04, t.x * 0.14), WHITE, CF(rng:NextNumber(-0.8, 0.8) * t.x, t.y + t.y * 0.1, rng:NextNumber(-0.5, 0.8) * t.z), NEON)
	end
end
function BUILD.season_cape(add, _h, t, item)
	cape(add, t, item.Color, C(255, 225, 80))
	add(t.p, "Numero", V(t.x * 0.5, t.y * 0.04, t.x * 0.5), C(255, 225, 80), CF(0, t.y + t.y * 0.1, t.z * 0.3) * ANG(0, math.pi / 4, 0), NEON)
end

local function measure(part)
	return { p = part, x = part.Size.X / 2, y = part.Size.Y / 2, z = part.Size.Z / 2 }
end

-- Monta os acessórios equipados no modelo (troca os antigos). on = { [slot] = id }.
function Accessories.Attach(model, on)
	if not model then
		return
	end
	local old = model:FindFirstChild("Acessorios")
	if old then
		old:Destroy()
	end
	if type(on) ~= "table" or next(on) == nil then
		return
	end
	local head, torso = headOf(model), model:FindFirstChild("Torso")
	if not (head and torso) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Acessorios"
	local add = adder(model, folder)
	local h, t = measure(head), measure(torso)
	for _, slot in ipairs(Accessories.SLOTS) do
		local item = Accessories.Get(on[slot])
		local build = item and item.Slot == slot and BUILD[item.Id]
		if build then
			local ok, err = pcall(build, add, h, t, item)
			if not ok then
				warn("[Accessories] " .. item.Id .. ": " .. tostring(err))
			end
		end
	end
	folder.Parent = model
end

-- todo acessório tem desenho? (teste)
function Accessories.HasBuild(id)
	return BUILD[id] ~= nil
end

return Accessories
