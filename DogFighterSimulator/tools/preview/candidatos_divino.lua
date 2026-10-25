-- PRÉVIA (não está no jogo): 4 candidatos para o cachorro DIVINO, todos inspirados na Ice Phoenix.
-- Designer de Cachorros (anatomia/silhueta) + Artista de Efeitos (brilhos, gelo, aura).
-- Mesmo formato de src/shared/DogPacks; o dono escolhe 1 e ele vira o pack de verdade.
local C = Color3.fromRGB
local PI = math.pi
local ANG = CFrame.Angles
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local ICE = Enum.Material.Ice
local FOIL = Enum.Material.Foil
local GOLD = C(255, 205, 80)

local function V(x, y, z)
	return Vector3.new(x, y, z)
end
local function CF(x, y, z)
	if type(x) ~= "number" then
		return CFrame.new(x)
	end
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
local function spinPivot(b, parent, name, cf, w)
	local p = b:Pivot(name)
	b:Attach(parent, p, cf)
	p:SetAttribute("CSpin", w)
	return p
end
local function wavePivot(b, parent, name, cf, amp, freq, phase)
	local p = b:Pivot(name)
	b:Attach(parent, p, cf)
	p:SetAttribute("CWave", amp)
	p:SetAttribute("CFreq", freq)
	p:SetAttribute("CPhase", phase or 0)
	return p
end
local function eachPart(model, test, fn)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and test(d.Name) then
			fn(d)
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
-- asa de penas extra (igual à do PackC)
local function featherWing(b, pivot, side, ws, cols, mat)
	local function P(x, y, z)
		return V(side * x * ws, y * ws, z * ws)
	end
	local elbow, tip = P(0.95, 0.75, 0.15), P(1.75, 1.55, 0.35)
	b:Seg(pivot, "AsaBraco", P(0, 0, 0), elbow, 0.26 * ws, 0.16 * ws, cols[1])
	b:Seg(pivot, "AsaBraco", elbow, tip, 0.2 * ws, 0.13 * ws, cols[1])
	for i = 0, 5 do
		local f = i / 5
		local root = P(0.2, 0.15, 0.1):Lerp(tip, f)
		local len = (0.85 + f * 1.0) * ws
		local dir = V(side * (0.1 + f * 0.55), -0.55 + f * 0.25, 1).Unit
		local normal = (tip - P(0, 0, 0)).Unit:Cross(dir)
		local feather = b:Seg(pivot, "Pena", root, root + dir * len, 0.22 * ws, 0.05 * ws, cols[2 + (i % 2)], mat, normal)
		if mat == GLASS then
			feather.Transparency = 0.12
		end
	end
end

-- detalhes de gelo da Ice Phoenix (coroa, floco no peito, plumas na cauda), com opções
local function iceDetails(b, ctx, o)
	local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
	model:SetAttribute("CAnim", true)
	eachPart(model, named({ "Pena", "Crista" }), function(p)
		if o.glassFeathers then
			p.Material = GLASS
			p.Transparency = 0.12
		end
	end)
	local head = model:FindFirstChild("Head1")
	if head then
		local hs = look.head.size
		local n = o.crownCount or 2
		for i = -n, n do
			local h = ((o.crownHeight or 0.55) - math.abs(i) * 0.1) * hs
			local sp = b:W(head, "CoroaGelo", V(0.06, h, 0.2), o.crownColor or C(200, 245, 255),
				CF(i * 0.13 * hs, 0.4 * hs + h * 0.5, 0.05 * hs) * ANG(0, PI / 2, i * 0.25), o.crownMat or ICE)
			sp.Transparency = o.crownMat == NEON and 0 or 0.1
		end
	end
	local cf = CF(0, -B.h * 0.05, -B.len * 0.47)
	for k = 0, 2 do
		glow(b:K(torso, "Floco", V(0.07, 0.75, 0.05), o.flakeColor or C(220, 250, 255), cf * ANG(0, 0, k * PI / 3)))
	end
	local tail = model:FindFirstChild("TailBase")
	if tail then
		local count = o.plumes or 3
		for k = 1, count do
			local i = (k - (count + 1) / 2) / math.max(1, (count - 1) / 2)
			local piv = wavePivot(b, tail, "PlumaPivo", CF(i * 0.22, 0.1, 0.3) * ANG(0, PI / 2 + i * 0.45, 0.55), V(0, 0.12, 0.2), 2.5, k)
			local L = o.plumeLen or 1
			local pts = { V(0, 0, 0), V(1.0 * L, -0.3, 0), V(2.0 * L, -0.35, 0), V(2.9 * L, -0.1, 0) }
			local col = o.plumeColors and o.plumeColors[(k - 1) % #o.plumeColors + 1] or C(150, 215, 255)
			b:Chain(piv, "Pluma", pts, { 0.13, 0.1, 0.08 }, col)
			local tip = b:E(piv, "PlumaPonta", V(0.7, 0.18, 0.4), C(230, 250, 255), CF(3.15 * L, -0.05, 0), GLASS)
			glow(tip, o.tipGlow or C(200, 245, 255))
		end
	end
end

-- anel de cristais de gelo girando em volta do corpo
local function crystalOrbit(b, torso, B, radius, count, color, h)
	local orbit = spinPivot(b, torso, "OrbitaCristal", CF(0, h or B.h * 0.2, 0), V(0, 0.8, 0))
	for i = 1, count do
		local a = i / count * PI * 2
		local cf = ANG(0, a, 0) * CF(radius, 0, 0)
		local c = b:K(orbit, "CristalOrbita", V(0.32, 0.6, 0.32), color, cf * ANG(PI / 4, 0, PI / 4), ICE)
		c.Transparency = 0.05
		glow(b:K(orbit, "CristalBrilho", V(0.12, 0.3, 0.12), C(240, 255, 255), cf * ANG(PI / 4, 0, PI / 4)))
	end
end

local function phoenixLook(o)
	return {
		scale = o.scale or 1.8,
		main = o.main,
		second = o.second,
		belly = o.belly,
		eye = o.eye,
		body = { len = 3.0, w = 1.3, h = 1.3 },
		legs = { len = 1.05, thick = 0.3, claws = o.second, paw = o.paw or o.second },
		head = { size = 1.35, snout = 1.25, snoutW = 0.55, lift = 0.65, muzzle = o.muzzle or o.belly, nose = o.nose or C(50, 110, 200) },
		mood = "fierce",
		ears = "swept",
		earColor = o.second,
		earInner = o.belly,
		tail = "fan",
		wingSize = o.wingSize or 1.6,
		wingColors = o.wings,
		extras = o.extras,
		build = o.build,
	}
end

local Species = {}

------------------------------------------------------------------ A) ETERNAL FROST PHOENIX — a Ice Phoenix "evoluída"
Species.div_eternal = {
	Name = "Eternal Frost Phoenix",
	Rarity = "Mythic",
	Role = "Divine",
	Special = "C_GlacialRebirth",
	Stats = { HP = 1.6, Atk = 1.6, Speed = 20 },
	Look = phoenixLook({
		scale = 1.85,
		main = C(235, 248, 255),
		second = C(90, 175, 255),
		belly = C(255, 255, 255),
		eye = C(255, 230, 140),
		paw = GOLD,
		wings = { C(255, 255, 255), C(170, 225, 255), GOLD },
		extras = { wings = "feather", crest = true, float = 2.2, halo = GOLD, gem = C(120, 220, 255), stars = true, icicleBack = C(200, 240, 255), icicles = C(210, 245, 255), eyeGlow = true, aura = C(200, 240, 255) },
		build = function(b, ctx)
			local torso, B, look = ctx.Torso, ctx.Body, ctx.Look
			iceDetails(b, ctx, { glassFeathers = true, crownCount = 3, crownHeight = 0.7, crownColor = GOLD, crownMat = FOIL, plumes = 5, plumeLen = 1.25, plumeColors = { C(150, 215, 255), GOLD, C(230, 250, 255) }, tipGlow = GOLD })
			-- 2º par de asas (4 asas), menor, por cima
			for _, side in ipairs({ -1, 1 }) do
				local up = wavePivot(b, torso, "AsaCima", CF(side * B.w * 0.22, B.h * 0.5, -B.len * 0.05) * ANG(-0.35, 0, side * 0.95), V(0, 0, 0.12), 2.2, side)
				featherWing(b, up, side, 1.05, { C(255, 255, 255), GOLD, C(170, 225, 255) }, GLASS)
			end
			crystalOrbit(b, torso, B, 2.6, 8, C(180, 235, 255))
		end,
	}),
}

------------------------------------------------------------------ B) AURORA PHOENIX — cores da aurora boreal
local AURORA = { C(90, 255, 200), C(80, 200, 255), C(170, 110, 255), C(255, 120, 220) }
Species.div_aurora = {
	Name = "Aurora Phoenix",
	Rarity = "Mythic",
	Role = "Divine",
	Special = "C_GlacialRebirth",
	Stats = { HP = 1.6, Atk = 1.6, Speed = 20 },
	Look = phoenixLook({
		scale = 1.8,
		main = C(225, 250, 248),
		second = C(110, 90, 220),
		belly = C(245, 255, 255),
		eye = C(140, 255, 220),
		nose = C(70, 50, 150),
		wings = { C(230, 255, 250), C(90, 240, 200), C(150, 110, 255) },
		extras = { wings = "feather", crest = true, float = 2.0, stars = true, gem = C(255, 120, 220), eyeGlow = true, aura = C(120, 255, 210) },
		build = function(b, ctx)
			local torso, B = ctx.Torso, ctx.Body
			iceDetails(b, ctx, { crownCount = 2, crownHeight = 0.75, crownColor = C(190, 150, 255), crownMat = GLASS, plumes = 4, plumeLen = 1.5, plumeColors = AURORA, tipGlow = C(255, 160, 240), flakeColor = C(150, 255, 220) })
			-- fitas de aurora flutuando acima das costas (neon, balançando)
			for i = 1, 4 do
				local piv = wavePivot(b, torso, "AuroraPivo", CF((i - 2.5) * 0.35, B.h * 0.95 + i * 0.12, B.len * (0.25 - i * 0.12)) * ANG(0, PI / 2, 0.3), V(0.15, 0, 0.18), 1.6, i)
				local pts = { V(-1.4, 0, 0), V(-0.5, 0.25, 0), V(0.5, -0.15, 0), V(1.5, 0.2, 0) }
				local list = b:Chain(piv, "Aurora", pts, { 0.07, 0.07, 0.07 }, AURORA[i])
				for _, p in ipairs(list) do
					glow(p)
					p.Transparency = 0.25
				end
			end
		end,
	}),
}

------------------------------------------------------------------ C) GLACIER SERAPH — anjo de gelo com 6 asas e armadura
Species.div_seraph = {
	Name = "Glacier Seraph",
	Rarity = "Mythic",
	Role = "Divine",
	Special = "C_GlacialRebirth",
	Stats = { HP = 1.6, Atk = 1.6, Speed = 20 },
	Look = phoenixLook({
		scale = 1.8,
		main = C(245, 250, 255),
		second = C(120, 190, 255),
		belly = C(255, 255, 255),
		eye = C(120, 220, 255),
		paw = C(200, 235, 255),
		wingSize = 1.45,
		wings = { C(240, 250, 255), C(190, 235, 255), C(140, 205, 255) },
		extras = { wings = "feather", crest = true, float = 2.6, halo = C(170, 235, 255), eyeGlow = true, stars = true, aura = C(170, 230, 255) },
		build = function(b, ctx)
			local torso, B = ctx.Torso, ctx.Body
			iceDetails(b, ctx, { glassFeathers = true, crownCount = 3, crownHeight = 0.6, plumes = 3, plumeLen = 1.1 })
			-- +4 asas de gelo (6 no total): par de cima e par de baixo
			for _, side in ipairs({ -1, 1 }) do
				local up = wavePivot(b, torso, "AsaCima", CF(side * B.w * 0.22, B.h * 0.48, -B.len * 0.28) * ANG(-0.55, 0, side * 0.75), V(0, 0, 0.12), 2.2, side)
				featherWing(b, up, side, 1.0, { C(240, 250, 255), C(200, 240, 255), C(150, 210, 255) }, GLASS)
				local low = wavePivot(b, torso, "AsaBaixo", CF(side * B.w * 0.42, -B.h * 0.05, B.len * 0.12) * ANG(0.35, 0, side * -1.75), V(0, 0, 0.1), 1.8, side + 1)
				featherWing(b, low, side, 0.9, { C(240, 250, 255), C(200, 240, 255), C(150, 210, 255) }, GLASS)
			end
			-- armadura de gelo no peito e nas costas
			local plate = b:K(torso, "ArmaduraGelo", V(B.w * 0.9, B.h * 0.55, 0.18), C(200, 235, 255), CF(0, B.h * 0.05, -B.len * 0.44), ICE)
			plate.Transparency = 0.1
			for i = -1, 1 do
				local back = b:K(torso, "ArmaduraGelo", V(B.w * 0.75, 0.16, B.len * 0.22), C(200, 235, 255), CF(0, B.h * 0.47, i * B.len * 0.24), ICE)
				back.Transparency = 0.1
				glow(b:K(torso, "ArmaduraLinha", V(B.w * 0.78, 0.05, 0.05), C(150, 230, 255), CF(0, B.h * 0.56, i * B.len * 0.24 - B.len * 0.11)))
			end
		end,
	}),
}

------------------------------------------------------------------ D) FROSTFLAME PHOENIX — fogo azul congelante
Species.div_frostflame = {
	Name = "Frostflame Phoenix",
	Rarity = "Mythic",
	Role = "Divine",
	Special = "C_GlacialRebirth",
	Stats = { HP = 1.6, Atk = 1.6, Speed = 20 },
	Look = phoenixLook({
		scale = 1.85,
		main = C(40, 60, 130),
		second = C(60, 220, 255),
		belly = C(120, 200, 255),
		eye = C(220, 255, 255),
		muzzle = C(70, 110, 190),
		nose = C(20, 25, 60),
		wings = { C(70, 110, 200), C(60, 230, 255), C(170, 245, 255) },
		extras = { wings = "feather", crest = true, float = 2.0, fire = C(80, 220, 255), flameMane = C(90, 230, 255), legFire = C(90, 230, 255), eyeGlow = true, aura = C(80, 220, 255) },
		build = function(b, ctx)
			local torso, B = ctx.Torso, ctx.Body
			iceDetails(b, ctx, { crownCount = 3, crownHeight = 0.8, crownColor = C(120, 240, 255), crownMat = NEON, plumes = 5, plumeLen = 1.3, plumeColors = { C(60, 220, 255), C(150, 245, 255), C(60, 140, 255) }, tipGlow = C(170, 250, 255), flakeColor = C(150, 250, 255) })
			crystalOrbit(b, torso, B, 2.5, 6, C(90, 210, 255), B.h * 0.6)
		end,
	}),
}

return {
	Species = Species,
	Order = { "div_eternal", "div_aurora", "div_seraph", "div_frostflame" },
	Specials = {},
}
