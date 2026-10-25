-- PRÉVIA v4 (não está no jogo): FORMA do nº 4 (dragão-fênix) e SEM GELO (pedido do dono): o que era gelo
-- (pele das asas, cristais, coroa, emblema do peito) agora é DOURADO. Cada paleta = ouro + uma cor especial.
-- Cada paleta: corpo, ossos das asas, pele das asas (uma cor por pedaço = degradê), cristais, chifres,
-- coroa, linhas brilhando no corpo e aura.
local C = Color3.fromRGB
local PI = math.pi
local ANG = CFrame.Angles
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local FOIL = Enum.Material.Foil
local METAL = Enum.Material.Metal

local function V(x, y, z)
	return Vector3.new(x, y, z)
end
local function CF(x, y, z)
	return CFrame.new(x, y, z)
end
local function glow(p, color)
	p.Material = NEON
	if color then
		p.Color = color
	end
	p.CastShadow = false
	return p
end
local function eachPart(model, test, fn)
	local i = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and test(d.Name) then
			i += 1
			fn(d, i)
		end
	end
end
local function named(list)
	local set = {}
	for _, n in ipairs(list) do
		set[n] = true
	end
	return function(n)
		return set[n] == true
	end
end

local function crown(b, ctx, color, mat, gem)
	local head = ctx.Model:FindFirstChild("Head1")
	if not head then
		return
	end
	local hs = ctx.Look.head.size
	for i = -2, 2 do
		local h = (0.6 - math.abs(i) * 0.1) * hs
		local sp = b:W(head, "Coroa", V(0.06, h, 0.2), color, CF(i * 0.12 * hs, 0.4 * hs + h * 0.5, 0.05 * hs) * ANG(0, PI / 2, i * 0.22), mat)
		if mat == GLASS then
			sp.Transparency = 0.1
		end
	end
	if gem then
		glow(b:K(head, "CoroaGema", V(0.18, 0.18, 0.08) * hs, gem, CF(0, 0.43 * hs, -0.12 * hs) * ANG(0, 0, PI / 4)))
	end
end

-- pal = { main, second, belly, eye, nose, paw, bone, boneMat, membranes = {..}, memMat, memTr, crystals, horns, hornMat,
--         crownColor, crownMat, gem, lines, flake, aura }
local function dragon(name, pal)
	return {
		Name = name,
		Rarity = "Mythic",
		Role = "Divine",
		Special = "C_GlacialRebirth",
		Stats = { HP = 1.6, Atk = 1.6, Speed = 20 },
		Look = {
			scale = 2.0,
			main = pal.main,
			second = pal.second,
			belly = pal.belly,
			eye = pal.eye,
			body = { len = 3.0, w = 1.3, h = 1.3 },
			legs = { len = 1.1, thick = 0.38, claws = pal.claws or pal.bone, paw = pal.paw },
			head = { size = 1.35, snout = 1.35, snoutW = 0.6, lift = 0.5, muzzle = pal.muzzle or pal.belly, nose = pal.nose, forward = 0.2 },
			mood = "fierce",
			ears = "swept",
			earColor = pal.second,
			earInner = pal.belly,
			tail = "dragon",
			wingSize = 1.55,
			wingBone = pal.bone,
			wingColor = pal.membranes[1],
			spikeColor = pal.crystals,
			extras = { wings = "dragon", horns = "dragon", crystals = pal.crystals, crystalSize = 1.2, float = 1.6, eyeGlow = true, lines = pal.lines, aura = pal.aura },
			build = function(b, ctx)
				local model = ctx.Model
				model:SetAttribute("CAnim", true)
				-- pele das asas: cada pedaço com uma cor da lista (degradê), vidro ou neon
				local list = pal.membranes
				local perWing = 8 -- 4 triângulos × 2 cunhas
				eachPart(model, named({ "AsaMembrana" }), function(p, i)
					local k = math.floor(((i - 1) % perWing) / 2) + 1
					p.Color = list[(k - 1) % #list + 1]
					p.Material = pal.memMat or GLASS
					p.Transparency = pal.memTr or 0.25
				end)
				eachPart(model, named({ "AsaOsso", "AsaDedo", "AsaGarra" }), function(p)
					p.Color = pal.bone
					p.Material = pal.boneMat or FOIL
				end)
				eachPart(model, named({ "Chifre", "Chifre1", "Chifre2", "Chifre3" }), function(p)
					p.Color = pal.horns
					p.Material = pal.hornMat or FOIL
				end)
				crown(b, ctx, pal.crownColor, pal.crownMat or GLASS, pal.gem)
				local B = ctx.Body
				local cf = CF(0, -B.h * 0.05, -B.len * 0.47)
				for k = 0, 2 do
					glow(b:K(ctx.Torso, "Emblema", V(0.07, 0.75, 0.05), pal.flake, cf * ANG(0, 0, k * PI / 3)))
				end
			end,
		},
	}
end

local GOLD = C(255, 205, 80)
local GOLD_L = C(255, 228, 140)
local GOLD_D = C(225, 160, 40)
local Species = {}

-- 1) DIVINE GOLD — branco perolado e tudo de ouro (asas em degradê de ouro claro → ouro forte)
Species.div4_gold = dragon("Divine Gold Dragon", {
	main = C(252, 248, 238), second = GOLD, belly = C(255, 255, 250), eye = C(255, 240, 170), nose = C(120, 80, 30),
	paw = GOLD, bone = GOLD, membranes = { GOLD_L, GOLD, GOLD_L, GOLD_D }, memTr = 0.15,
	crystals = GOLD, horns = GOLD, crownColor = GOLD, crownMat = FOIL, gem = C(255, 255, 230),
	lines = GOLD_L, flake = GOLD_L, aura = C(255, 225, 120),
})

-- 2) SUNFIRE — creme com asas de ouro → laranja → vermelho (um sol), linhas vermelhas
Species.div4_sun = dragon("Sunfire Dragon", {
	main = C(255, 244, 225), second = C(255, 140, 50), belly = C(255, 252, 240), eye = C(255, 210, 90), nose = C(130, 50, 30),
	paw = GOLD, bone = GOLD, membranes = { C(255, 225, 110), C(255, 175, 60), C(255, 120, 50), C(235, 70, 60) }, memTr = 0.15,
	crystals = GOLD, horns = GOLD, crownColor = GOLD, crownMat = FOIL, gem = C(255, 80, 60),
	lines = C(255, 110, 60), flake = C(255, 200, 80), aura = C(255, 150, 60),
})

-- 3) ROYAL AMETHYST — branco e roxo real com ouro (asas ouro → roxo)
Species.div4_royal = dragon("Royal Gold Dragon", {
	main = C(248, 244, 255), second = C(140, 70, 220), belly = C(255, 255, 255), eye = C(200, 150, 255), nose = C(60, 30, 100),
	paw = GOLD, bone = GOLD, membranes = { GOLD_L, GOLD, C(190, 120, 240), C(140, 70, 220) }, memTr = 0.15,
	crystals = GOLD, horns = GOLD, crownColor = GOLD, crownMat = FOIL, gem = C(160, 80, 255),
	lines = C(170, 100, 255), flake = GOLD_L, aura = C(190, 130, 255),
})

-- 4) BLACK & GOLD EMPEROR — preto fosco, asas de ouro maciço, olhos e linhas de ouro brilhando
Species.div4_emperor = dragon("Emperor Gold Dragon", {
	main = C(30, 30, 36), second = GOLD, belly = C(55, 55, 62), eye = C(255, 210, 80), nose = C(10, 10, 12),
	muzzle = C(45, 45, 52), paw = GOLD, bone = GOLD,
	membranes = { GOLD, GOLD_L, GOLD, GOLD_D }, memMat = FOIL, memTr = 0,
	crystals = GOLD, horns = GOLD, crownColor = GOLD, crownMat = FOIL, gem = C(255, 60, 60),
	lines = C(255, 210, 80), flake = C(255, 210, 80), aura = C(255, 210, 90),
})

-- 5) EMERALD CROWN — branco e verde-esmeralda com ouro (asas ouro → esmeralda)
Species.div4_emerald = dragon("Emerald Gold Dragon", {
	main = C(245, 252, 245), second = C(40, 190, 110), belly = C(255, 255, 252), eye = C(120, 255, 170), nose = C(20, 80, 50),
	paw = GOLD, bone = GOLD, membranes = { GOLD_L, GOLD, C(90, 220, 140), C(30, 170, 100) }, memTr = 0.15,
	crystals = GOLD, horns = GOLD, crownColor = GOLD, crownMat = FOIL, gem = C(40, 220, 120),
	lines = C(70, 230, 140), flake = GOLD_L, aura = C(120, 240, 170),
})

-- 6) ROSE GOLD — rosado com ouro rosé (asas rosa → ouro), delicado e brilhante
Species.div4_rose = dragon("Rose Gold Dragon", {
	main = C(255, 236, 238), second = C(240, 150, 160), belly = C(255, 250, 250), eye = C(255, 170, 190), nose = C(130, 60, 70),
	paw = C(240, 180, 150), bone = C(235, 170, 140), membranes = { C(255, 180, 190), C(250, 170, 150), C(245, 195, 130), GOLD }, memTr = 0.15,
	crystals = C(240, 185, 140), horns = C(235, 170, 140), crownColor = C(240, 185, 140), crownMat = FOIL, gem = C(255, 100, 140),
	lines = C(255, 170, 190), flake = C(250, 200, 160), aura = C(255, 180, 200),
})

return {
	Species = Species,
	Order = { "div4_gold", "div4_sun", "div4_royal", "div4_emperor", "div4_emerald", "div4_rose" },
	Specials = {},
}
