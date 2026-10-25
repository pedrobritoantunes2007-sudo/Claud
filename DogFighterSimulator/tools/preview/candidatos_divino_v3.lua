-- PRÉVIA v3 (não está no jogo): o dono escolheu a FORMA do nº 4 (Frost Dragon Phoenix).
-- Agora só as CORES: 6 paletas especiais (Designer de Cachorros + Artista de Efeitos).
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
					glow(b:K(ctx.Torso, "Floco", V(0.07, 0.75, 0.05), pal.flake, cf * ANG(0, 0, k * PI / 3)))
				end
			end,
		},
	}
end

local GOLD = C(255, 205, 80)
local Species = {}

-- 0) a original (para comparar)
Species.div3_original = dragon("Frost Dragon Phoenix", {
	main = C(225, 240, 255), second = C(70, 140, 230), belly = C(250, 252, 255), eye = C(255, 230, 140), nose = C(40, 80, 160),
	paw = C(180, 220, 255), bone = GOLD, membranes = { C(170, 225, 255) }, crystals = C(175, 230, 255), horns = GOLD,
	crownColor = C(175, 230, 255), gem = GOLD, flake = C(200, 240, 255), aura = C(170, 230, 255),
})

-- 1) AURORA — pele das asas em degradê de aurora boreal, ossos de prata, linhas verde-água no corpo
Species.div3_aurora = dragon("Aurora Dragon Phoenix", {
	main = C(225, 250, 245), second = C(60, 190, 170), belly = C(245, 255, 252), eye = C(150, 255, 220), nose = C(30, 90, 90),
	paw = C(170, 240, 225), bone = C(225, 235, 245), boneMat = METAL,
	membranes = { C(90, 255, 190), C(70, 210, 255), C(150, 110, 255), C(255, 110, 220) }, memTr = 0.2,
	crystals = C(140, 255, 220), horns = C(225, 235, 245), hornMat = METAL,
	crownColor = C(190, 150, 255), gem = C(255, 120, 220), lines = C(110, 255, 210), flake = C(150, 255, 220), aura = C(120, 255, 210),
})

-- 2) ROYAL SAPPHIRE — corpo azul safira, ossos e chifres de ouro, asas azul-gelo brilhando
Species.div3_sapphire = dragon("Sapphire Dragon Phoenix", {
	main = C(40, 75, 170), second = C(255, 205, 80), belly = C(150, 195, 255), eye = C(255, 235, 150), nose = C(15, 25, 70),
	muzzle = C(120, 170, 245), paw = GOLD, bone = GOLD,
	membranes = { C(120, 200, 255), C(170, 225, 255), C(120, 200, 255), C(80, 160, 255) }, memTr = 0.2,
	crystals = C(200, 240, 255), horns = GOLD, crownColor = GOLD, crownMat = FOIL, gem = C(120, 220, 255),
	lines = GOLD, flake = C(255, 235, 150), aura = C(120, 190, 255),
})

-- 3) VOID DIAMOND — preto-galáxia com linhas roxas neon, asas violeta e cristais rosa
Species.div3_void = dragon("Void Diamond Dragon", {
	main = C(28, 24, 48), second = C(170, 80, 255), belly = C(55, 45, 90), eye = C(255, 90, 230), nose = C(10, 8, 20),
	paw = C(170, 80, 255), bone = C(190, 110, 255), boneMat = NEON,
	membranes = { C(110, 50, 200), C(150, 70, 230), C(200, 90, 240), C(255, 110, 220) }, memTr = 0.3,
	crystals = C(255, 120, 230), horns = C(240, 230, 255), hornMat = METAL,
	crownColor = C(255, 120, 230), gem = C(170, 80, 255), lines = C(190, 100, 255), flake = C(255, 140, 240), aura = C(170, 80, 255),
})

-- 4) RAINBOW OPAL — branco perolado, pele das asas arco-íris, ossos de ouro (o "Divino" mais colorido)
Species.div3_opal = dragon("Opal Dragon Phoenix", {
	main = C(250, 248, 255), second = C(255, 190, 230), belly = C(255, 255, 255), eye = C(140, 220, 255), nose = C(90, 70, 140),
	paw = C(255, 225, 245), bone = GOLD,
	membranes = { C(255, 120, 140), C(255, 200, 100), C(140, 240, 150), C(120, 190, 255) }, memTr = 0.15,
	crystals = C(230, 210, 255), horns = GOLD, crownColor = C(230, 210, 255), gem = C(255, 120, 200),
	lines = C(255, 170, 230), flake = C(255, 220, 250), aura = C(255, 200, 240),
})

-- 5) BLACK & GOLD EMPEROR — preto fosco, tudo de ouro, olhos e cristais azul-gelo neon
Species.div3_emperor = dragon("Emperor Dragon Phoenix", {
	main = C(30, 30, 36), second = C(255, 200, 70), belly = C(55, 55, 62), eye = C(120, 230, 255), nose = C(10, 10, 12),
	muzzle = C(45, 45, 52), paw = GOLD, bone = GOLD,
	membranes = { C(255, 205, 80), C(255, 225, 130), C(255, 205, 80), C(240, 170, 50) }, memMat = FOIL, memTr = 0,
	crystals = C(120, 230, 255), horns = GOLD, crownColor = GOLD, crownMat = FOIL, gem = C(120, 230, 255),
	lines = C(120, 230, 255), flake = C(120, 230, 255), aura = C(255, 210, 90),
})

-- 6) SUNRISE FROST — creme e ouro rosé, asas pêssego→dourado (o nascer do sol no gelo)
Species.div3_sunrise = dragon("Sunrise Dragon Phoenix", {
	main = C(255, 245, 235), second = C(255, 160, 140), belly = C(255, 252, 248), eye = C(255, 200, 120), nose = C(140, 70, 70),
	paw = C(255, 200, 180), bone = C(240, 170, 140), boneMat = FOIL,
	membranes = { C(255, 150, 160), C(255, 180, 140), C(255, 210, 120), C(255, 235, 150) }, memTr = 0.2,
	crystals = C(255, 210, 190), horns = C(240, 170, 140), crownColor = C(255, 220, 150), crownMat = FOIL, gem = C(255, 120, 140),
	lines = C(255, 190, 150), flake = C(255, 220, 170), aura = C(255, 190, 150),
})

return {
	Species = Species,
	Order = { "div3_original", "div3_aurora", "div3_sapphire", "div3_void", "div3_opal", "div3_emperor", "div3_sunrise" },
	Specials = {},
}
