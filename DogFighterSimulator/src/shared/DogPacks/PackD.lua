-- Pacote D: o ÚNICO cachorro DIVINO (raridade acima do Mítico) — SUNFIRE DRAGON.
-- Escolhido pelo dono em 3 rodadas de prévia: forma de dragão-fênix (asas de dragão, chifres, cristais nas
-- costas, coroa), sem gelo — tudo dourado — e a paleta "Sunfire": pele das asas em degradê ouro → laranja →
-- vermelho, linhas vermelhas brilhando no corpo. Elementos: Fogo + Luz + Voador. Vendido por Robux (DivineDog).
-- Habilidades: 2 = Sunfire Breath (próprio, SpecialsPacks/PackD), 3 = fusão "Sunfire Nova", 4 = "DIVINE SUNFIRE".
local C = Color3.fromRGB
local PI = math.pi
local ANG = CFrame.Angles
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local FOIL = Enum.Material.Foil

local GOLD = C(255, 205, 80)

local function V(x, y, z)
	return Vector3.new(x, y, z)
end

local function glow(p, color)
	p.Material = NEON
	if color then
		p.Color = color
	end
	p.CastShadow = false
	return p
end

local function eachPart(model, names, fn)
	local i = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and names[d.Name] then
			i += 1
			fn(d, i)
		end
	end
end

local MEMBRANES = { C(255, 225, 110), C(255, 175, 60), C(255, 120, 50), C(235, 70, 60) } -- ouro → vermelho

local Species = {}

Species.sun_dragon = {
	Name = "Sunfire Dragon",
	Rarity = "Divine",
	Role = "Divine",
	Special = "D_SunfireBreath",
	Stats = { HP = 1.6, Atk = 1.65, Speed = 21 },
	Look = {
		scale = 2.0,
		main = C(255, 244, 225),
		second = C(255, 140, 50),
		belly = C(255, 252, 240),
		eye = C(255, 210, 90),
		body = { len = 3.0, w = 1.3, h = 1.3 },
		legs = { len = 1.1, thick = 0.38, claws = GOLD, paw = GOLD },
		head = { size = 1.35, snout = 1.35, snoutW = 0.6, lift = 0.5, muzzle = C(255, 252, 240), nose = C(130, 50, 30), forward = 0.2 },
		mood = "fierce",
		ears = "swept",
		earColor = C(255, 140, 50),
		earInner = C(255, 252, 240),
		tail = "dragon",
		wingSize = 1.55,
		wingBone = GOLD,
		wingColor = MEMBRANES[1],
		spikeColor = GOLD,
		extras = {
			wings = "dragon",
			horns = "dragon",
			crystals = GOLD,
			crystalSize = 1.2,
			float = 1.6,
			eyeGlow = true,
			lines = C(255, 110, 60),
			fire = C(255, 150, 50),
			aura = C(255, 150, 60),
		},
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			-- pele das asas: um pedaço de cada cor (degradê do sol), vidro brilhante
			eachPart(model, { AsaMembrana = true }, function(p, i)
				local k = math.floor(((i - 1) % 8) / 2) + 1
				p.Color = MEMBRANES[k]
				p.Material = GLASS
				p.Transparency = 0.15
			end)
			eachPart(model, { AsaOsso = true, AsaDedo = true, AsaGarra = true, Chifre = true, Chifre1 = true, Chifre2 = true, Chifre3 = true }, function(p)
				p.Color = GOLD
				p.Material = FOIL
			end)
			-- coroa de ouro com gema de rubi
			local head = model:FindFirstChild("Head1")
			if head then
				local hs = look.head.size
				for i = -2, 2 do
					local h = (0.6 - math.abs(i) * 0.1) * hs
					b:W(head, "Coroa", V(0.06, h, 0.2), GOLD, CFrame.new(i * 0.12 * hs, 0.4 * hs + h * 0.5, 0.05 * hs) * ANG(0, PI / 2, i * 0.22), FOIL)
				end
				glow(b:K(head, "CoroaGema", V(0.18, 0.18, 0.08) * hs, C(255, 80, 60), CFrame.new(0, 0.43 * hs, -0.12 * hs) * ANG(0, 0, PI / 4)))
			end
			-- emblema do sol no peito
			local cf = CFrame.new(0, -B.h * 0.05, -B.len * 0.47)
			for k = 0, 2 do
				glow(b:K(torso, "Emblema", V(0.07, 0.75, 0.05), C(255, 200, 80), cf * ANG(0, 0, k * PI / 3)))
			end
		end,
	},
}

return {
	Species = Species,
	Order = { "sun_dragon" },
	Specials = {
		D_SunfireBreath = {
			Name = "Sunfire Breath",
			Desc = "Breathes a sweeping beam of golden sunfire that burns everything in front, then a small sun explodes on the target and heals you.",
		},
	},
}
