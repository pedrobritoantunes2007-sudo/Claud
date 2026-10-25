-- ✨ SHINY, 🥇 GOLD e 🌈 RAINBOW (2026-10-25, pedidos do dono):
--   "Cachorro Shiny: 1 em cada 500 selvagens nasce brilhando, com aviso para o servidor inteiro. Se você capturar,
--    ele continua shiny."
--   "Evoluir: 3 cachorros iguais viram 1 versão Gold, mais forte. 3 Gold viram 1 Rainbow, ainda mais forte. Assim os
--    repetidos que você captura servem para alguma coisa."
-- Um cachorro do perfil pode ter Shiny = true e/ou Tier = 1 (GOLD) ou 2 (RAINBOW). Sem nada = normal.
-- Dados COMPARTILHADOS (servidor e cliente):
--   Variants.Mult(dog)   → multiplicador de vida/ataque (Config.Stats usa)
--   Variants.Value(dog)  → valor do cachorro nas trocas (TRADE mostra)
--   Variants.Label(dog)  → "✨ SHINY GOLD" (plaquinha, menus, avisos) · Variants.Color(dog) → cor de destaque
--   Variants.Paint(model, dog) → pinta o modelo 3D (servidor: o cachorro em campo; cliente: os retratos dos menus)
--   Variants.CanEvolve / Variants.EvolvePick → regra do EVOLUIR (servidor: Services/EvolveService)
local Variants = {}

local C = Color3.fromRGB

Variants.SHINY_CHANCE = 1 / 500 -- selvagem que nasce shiny
Variants.SHINY_MULT = 1.15 -- ✨ shiny bate e aguenta um pouquinho mais (+15%) e vale MUITO mais
Variants.SHINY_VALUE = 6
Variants.SHINY_COLOR = C(140, 240, 255)
Variants.EVOLVE_COUNT = 3 -- quantos iguais viram 1 do nível de cima
Variants.TIERS = {
	[1] = { Id = "Gold", Label = "GOLD", Mult = 1.6, Value = 3.5, Color = C(255, 205, 60) },
	[2] = { Id = "Rainbow", Label = "RAINBOW", Mult = 2.5, Value = 12, Color = C(255, 110, 220) },
}
Variants.MAX_TIER = #Variants.TIERS

-- valor base de cada raridade nas trocas (o nível e as versões multiplicam)
Variants.RARITY_VALUE = {
	Common = 10,
	Uncommon = 30,
	Rare = 90,
	Epic = 300,
	Legendary = 900,
	Mythic = 3000,
	Halloween = 5000,
	Divine = 10000,
}

function Variants.TierOf(dog)
	local t = type(dog) == "table" and tonumber(dog.Tier) or 0
	if not t or t ~= t then
		return 0
	end
	return math.clamp(math.floor(t), 0, Variants.MAX_TIER)
end

function Variants.IsShiny(dog)
	return type(dog) == "table" and dog.Shiny == true
end

-- multiplicador de vida e ataque (1 = normal)
function Variants.Mult(dog)
	local m = 1
	local tier = Variants.TIERS[Variants.TierOf(dog)]
	if tier then
		m *= tier.Mult
	end
	if Variants.IsShiny(dog) then
		m *= Variants.SHINY_MULT
	end
	return m
end

-- 💎 valor nas trocas: raridade × nível × versões (Gold/Rainbow/Shiny)
function Variants.Value(dog, rarity)
	if type(dog) ~= "table" then
		return 0
	end
	local base = Variants.RARITY_VALUE[rarity or ""] or 10
	local level = math.max(1, tonumber(dog.Level) or 1)
	local v = base * (1 + (level - 1) * 0.03)
	local tier = Variants.TIERS[Variants.TierOf(dog)]
	if tier then
		v *= tier.Value
	end
	if Variants.IsShiny(dog) then
		v *= Variants.SHINY_VALUE
	end
	return math.max(1, math.floor(v + 0.5))
end

-- quanto as versões multiplicam o valor (soltar o cachorro paga isso a mais)
function Variants.ValueMult(dog)
	local m = 1
	local tier = Variants.TIERS[Variants.TierOf(dog)]
	if tier then
		m *= tier.Value
	end
	if Variants.IsShiny(dog) then
		m *= Variants.SHINY_VALUE
	end
	return m
end

-- "✨ SHINY GOLD" / "RAINBOW" / "" (com emoji: as telas trocam por desenho)
function Variants.Label(dog, noEmoji)
	local parts = {}
	if Variants.IsShiny(dog) then
		table.insert(parts, noEmoji and "SHINY" or "✨ SHINY")
	end
	local tier = Variants.TIERS[Variants.TierOf(dog)]
	if tier then
		table.insert(parts, tier.Label)
	end
	return table.concat(parts, " ")
end

-- cor de destaque (borda dos cartões, texto) — nil = normal
function Variants.Color(dog)
	local tier = Variants.TIERS[Variants.TierOf(dog)]
	if tier then
		return tier.Color
	end
	if Variants.IsShiny(dog) then
		return Variants.SHINY_COLOR
	end
	return nil
end

-- é especial (shiny ou evoluído)?
function Variants.IsSpecial(dog)
	return Variants.IsShiny(dog) or Variants.TierOf(dog) > 0
end

---------------------------------------------------------------- 🧬 EVOLUIR
-- Pode evoluir este cachorro? Precisa de EVOLVE_COUNT do MESMO tipo e da MESMA versão (Gold só com Gold).
function Variants.CanEvolve(dog)
	return type(dog) == "table" and Variants.TierOf(dog) < Variants.MAX_TIER
end

-- Escolhe os cachorros que entram na evolução: o escolhido + os outros iguais (mesma espécie e versão), sem
-- favoritos ⭐ (a não ser o escolhido) e sem os bloqueados (ex.: oferecidos numa troca). Prefere os de level mais
-- alto (o resultado fica com o MAIOR level). Devolve a lista de uids ou nil, quantos iguais tem.
function Variants.EvolvePick(dogs, uid, blocked)
	local main = dogs and dogs[uid]
	if not Variants.CanEvolve(main) then
		return nil, 0
	end
	local tier = Variants.TierOf(main)
	local others = {}
	for id, dog in pairs(dogs) do
		if id ~= uid and dog.Species == main.Species and Variants.TierOf(dog) == tier and not dog.Fav and not (blocked and blocked[id]) then
			table.insert(others, dog)
		end
	end
	table.sort(others, function(a, b)
		if (a.Level or 1) ~= (b.Level or 1) then
			return (a.Level or 1) > (b.Level or 1)
		end
		return (tonumber(a.Id) or 0) < (tonumber(b.Id) or 0)
	end)
	local have = 1 + #others
	if have < Variants.EVOLVE_COUNT then
		return nil, have
	end
	local list = { uid }
	for i = 1, Variants.EVOLVE_COUNT - 1 do
		table.insert(list, others[i].Id)
	end
	return list, have
end

---------------------------------------------------------------- 🎨 visual
local function nearBlack(c)
	return c.R + c.G + c.B < 0.32
end

-- gira a cor (shiny = outra paleta, como nos jogos de monstrinho): cinzas/pretos/brancos ficam
local function hueShift(c, amount)
	local h, s, v = c:ToHSV()
	if s < 0.12 then
		return c
	end
	return Color3.fromHSV((h + amount) % 1, math.min(1, s * 1.1), v)
end

local function sparkles(part, color, rate, rainbow)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "VarianteBrilho"
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(0.6, 1.2)
	pe.Speed = NumberRange.new(0.5, 2)
	pe.SpreadAngle = Vector2.new(180, 180)
	local s = math.clamp(part.Size.Magnitude * 0.12, 0.25, 1.2)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	if rainbow then
		pe.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C(255, 80, 80)),
			ColorSequenceKeypoint.new(0.25, C(255, 220, 60)),
			ColorSequenceKeypoint.new(0.5, C(80, 230, 120)),
			ColorSequenceKeypoint.new(0.75, C(80, 160, 255)),
			ColorSequenceKeypoint.new(1, C(220, 90, 255)),
		})
	else
		pe.Color = ColorSequence.new(color)
	end
	pe.Parent = part
	return pe
end

-- Pinta o modelo do cachorro. dog = { Shiny, Tier } (o cachorro do perfil serve). Faz nada se for normal.
-- Shiny: outra paleta (cor girada) + brilhinhos brancos/azuis e uma luz. Gold: tudo puxado para o dourado com
-- brilho. Rainbow: faixas de arco-íris do focinho ao rabo + brilhinhos coloridos. (Só pinta 1 vez por modelo.)
function Variants.Paint(model, dog)
	if not (model and Variants.IsSpecial(dog)) or model:GetAttribute("Variante") then
		return
	end
	local shiny = Variants.IsShiny(dog)
	local tier = Variants.TierOf(dog)
	model:SetAttribute("Variante", Variants.Label(dog, true))
	model:SetAttribute("Shiny", shiny or nil)
	model:SetAttribute("Tier", tier > 0 and tier or nil)
	local root = model.PrimaryPart
	local parts = {}
	local minZ, maxZ = math.huge, -math.huge
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root and p.Transparency < 1 and not p:GetAttribute("Acessorio") then
			table.insert(parts, p)
			local z = root and root.CFrame:PointToObjectSpace(p.Position).Z or p.Position.Z
			minZ, maxZ = math.min(minZ, z), math.max(maxZ, z)
		end
	end
	local span = math.max(0.01, maxZ - minZ)
	for _, p in ipairs(parts) do
		local c = p.Color
		if not nearBlack(c) then
			if shiny then
				c = hueShift(c, 0.45)
			end
			if tier == 1 then
				c = c:Lerp(C(255, 200, 60), 0.55)
				p.Reflectance = math.max(p.Reflectance, 0.12)
			elseif tier == 2 then
				local z = root and root.CFrame:PointToObjectSpace(p.Position).Z or p.Position.Z
				local t = (z - minZ) / span
				c = c:Lerp(Color3.fromHSV(t * 0.85, 0.7, 1), 0.6)
			end
			p.Color = c
		end
	end
	local torso = model:FindFirstChild("Torso") or root
	if torso then
		if tier > 0 then
			local info = Variants.TIERS[tier]
			sparkles(torso, info.Color, tier == 2 and 10 or 7, tier == 2)
		end
		if shiny then
			sparkles(torso, C(230, 250, 255), 8)
			local light = Instance.new("PointLight")
			light.Name = "VarianteLuz"
			light.Color = Variants.SHINY_COLOR
			light.Brightness = 1.2
			light.Range = 10
			light.Parent = torso
		end
	end
end

return Variants
