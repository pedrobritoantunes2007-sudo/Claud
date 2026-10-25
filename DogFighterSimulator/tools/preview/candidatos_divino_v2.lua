-- PRÉVIA v2 (não está no jogo): 5 versões do candidato A (Eternal Frost Phoenix) bem DIFERENTES —
-- muda a anatomia/silhueta (asas, cabeças, cauda, coroa), não só a cor. Gelo + ouro continuam (DNA do A).
-- Designer de Cachorros (forma) + Artista de Efeitos (cristal, luz, neon).
local C = Color3.fromRGB
local PI = math.pi
local ANG = CFrame.Angles
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local ICE = Enum.Material.Ice
local FOIL = Enum.Material.Foil
local GOLD = C(255, 205, 80)
local ICEC = C(175, 230, 255)
local WHITE = C(250, 252, 255)

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
local function ring(b, parent, name, cf, radius, segs, thick, height, color, mat)
	local arc = 2 * PI * radius / segs * 1.12
	for i = 1, segs do
		local a = i / segs * PI * 2
		b:K(parent, name, V(thick, height, arc), color, cf * ANG(0, a, 0) * CF(radius, 0, 0), mat)
	end
end
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
local function diamond(b, parent, name, size, color, cf, mat)
	local p = b:K(parent, name, V(size, size * 1.7, size), color, cf * ANG(PI / 4, 0, PI / 4), mat or ICE)
	p.Transparency = 0.05
	return p
end
local function neckY(look, B)
	return B.h * 0.3 + (look.head.lift or 0)
end

-- coroa de gelo/ouro em cada cabeça; plumas na cauda; floco no peito (DNA da Ice Phoenix)
local function crowns(b, ctx, list)
	local model, look = ctx.Model, ctx.Look
	local hs = look.head.size
	for hi, o in ipairs(list) do
		local head = model:FindFirstChild("Head" .. hi)
		if head then
			local n = o.count or 3
			for i = -n, n do
				local h = ((o.height or 0.7) - math.abs(i) * 0.1) * hs
				local sp = b:W(head, "Coroa", V(0.06, h, 0.2), o.color, CF(i * 0.12 * hs, 0.4 * hs + h * 0.5, 0.05 * hs) * ANG(0, PI / 2, i * 0.22), o.mat or FOIL)
				if o.mat == GLASS or o.mat == ICE then
					sp.Transparency = 0.1
				end
			end
			if o.gem then
				glow(b:K(head, "CoroaGema", V(0.18, 0.18, 0.08) * hs, o.gem, CF(0, 0.43 * hs, -0.12 * hs) * ANG(0, 0, PI / 4)))
			end
		end
	end
end
local function plumes(b, ctx, count, len, colors, tipGlow, spread)
	local tail = ctx.Model:FindFirstChild("TailBase")
	if not tail then
		return
	end
	for k = 1, count do
		local i = (k - (count + 1) / 2) / math.max(1, (count - 1) / 2)
		local piv = wavePivot(b, tail, "PlumaPivo", CF(i * 0.22, 0.1, 0.3) * ANG(0, PI / 2 + i * (spread or 0.45), 0.55), V(0, 0.12, 0.2), 2.5, k)
		local pts = { V(0, 0, 0), V(1.0 * len, -0.3, 0), V(2.0 * len, -0.35, 0), V(2.9 * len, -0.1, 0) }
		b:Chain(piv, "Pluma", pts, { 0.13, 0.1, 0.08 }, colors[(k - 1) % #colors + 1])
		glow(b:E(piv, "PlumaPonta", V(0.7, 0.18, 0.4), WHITE, CF(3.15 * len, -0.05, 0), GLASS), tipGlow)
	end
end
local function chestFlake(b, ctx, color)
	local B = ctx.Body
	local cf = CF(0, -B.h * 0.05, -B.len * 0.47)
	for k = 0, 2 do
		glow(b:K(ctx.Torso, "Floco", V(0.07, 0.75, 0.05), color, cf * ANG(0, 0, k * PI / 3)))
	end
end

local function baseLook(o)
	local look = {
		scale = o.scale or 1.9,
		main = o.main or WHITE,
		second = o.second or C(90, 175, 255),
		belly = o.belly or C(255, 255, 255),
		eye = o.eye or C(255, 230, 140),
		body = o.body or { len = 3.0, w = 1.3, h = 1.3 },
		legs = o.legs or { len = 1.05, thick = 0.3, claws = GOLD, paw = GOLD },
		head = o.head or { size = 1.35, snout = 1.25, snoutW = 0.55, lift = 0.65, muzzle = WHITE, nose = C(50, 110, 200) },
		mood = "fierce",
		ears = o.ears or "swept",
		earColor = o.earColor or C(90, 175, 255),
		earInner = WHITE,
		tail = o.tail or "fan",
		heads = o.heads,
		wingSize = o.wingSize or 1.6,
		wingColors = o.wingColors or { WHITE, ICEC, GOLD },
		wingBone = o.wingBone,
		wingColor = o.wingColor,
		spikeColor = o.spikeColor,
		extras = o.extras,
		build = o.build,
	}
	return look
end

local Species = {}

------------------------------------------------------------------ 1) CRYSTAL SOVEREIGN — asas de CRISTAL + mandala de ouro atrás da cabeça
Species.div2_crystal = {
	Name = "Crystal Sovereign",
	Rarity = "Mythic",
	Role = "Divine",
	Special = "C_GlacialRebirth",
	Stats = { HP = 1.6, Atk = 1.6, Speed = 20 },
	Look = baseLook({
		scale = 1.9,
		extras = { crest = true, float = 2.4, gem = C(120, 220, 255), stars = true, eyeGlow = true, aura = C(200, 240, 255) },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			crowns(b, ctx, { { color = GOLD, count = 3, height = 0.8, gem = C(120, 220, 255) } })
			chestFlake(b, ctx, C(220, 250, 255))
			plumes(b, ctx, 5, 1.3, { ICEC, GOLD, WHITE }, GOLD)
			-- asas feitas de LÂMINAS DE CRISTAL (vidro com miolo neon), em leque
			for _, side in ipairs({ -1, 1 }) do
				local piv = wavePivot(b, torso, "AsaCristalPivo", CF(side * B.w * 0.35, B.h * 0.42, -B.len * 0.08) * ANG(0, 0, side * 0.2), V(0, 0, 0.1), 1.6, side)
				b:E(piv, "OmbroOuro", V(0.7, 0.55, 0.8), GOLD, CF(), FOIL)
				for i = 0, 6 do
					local a = 0.1 + i * 0.24
					local d = V(side * math.cos(a), math.sin(a) * 0.95, 0.3 + i * 0.05).Unit
					local L = 1.5 + math.sin(i / 6 * PI) * 1.4 + i * 0.12
					local base = d * 0.2
					local blade = b:Seg(piv, "AsaCristal", base, base + d * L, 0.24, 0.06, i % 2 == 0 and ICEC or C(215, 245, 255), GLASS, V(0, 0, 1))
					blade.Transparency = 0.2
					glow(b:Seg(piv, "AsaCristalMiolo", base + d * 0.2, base + d * (L - 0.25), 0.05, 0.03, i % 2 == 0 and C(150, 230, 255) or GOLD, nil, V(0, 0, 1)))
				end
			end
			-- mandala de ouro e gelo atrás da cabeça, girando devagar
			local mandala = spinPivot(b, torso, "Mandala", CF(0, neckY(look, B) + 0.85, -B.len * 0.28) * ANG(PI / 2, 0, 0), V(0, 0.5, 0))
			ring(b, mandala, "MandalaAro", CFrame.new(), 1.25, 22, 0.1, 0.12, GOLD, FOIL)
			for i = 1, 12 do
				local a = i / 12 * PI * 2
				local r0, len = 1.33, i % 2 == 0 and 0.6 or 0.35
				local spike = b:Seg(mandala, "MandalaRaio", V(math.cos(a) * r0, 0, math.sin(a) * r0), V(math.cos(a) * (r0 + len), 0, math.sin(a) * (r0 + len)), 0.07, 0.05, i % 2 == 0 and ICEC or GOLD, i % 2 == 0 and GLASS or FOIL)
				spike.Transparency = i % 2 == 0 and 0.1 or 0
			end
		end,
	}),
}

------------------------------------------------------------------ 2) TWIN CROWN — DUAS cabeças + leque de pavão real atrás
Species.div2_twin = {
	Name = "Twin Crown Phoenix",
	Rarity = "Mythic",
	Role = "Divine",
	Special = "C_GlacialRebirth",
	Stats = { HP = 1.6, Atk = 1.6, Speed = 20 },
	Look = baseLook({
		scale = 1.85,
		heads = 2,
		head = { size = 1.2, snout = 1.2, snoutW = 0.5, lift = 0.75, muzzle = WHITE, nose = C(50, 110, 200) },
		wingSize = 1.75,
		extras = { wings = "feather", crest = true, float = 2.2, eyeGlow = true, aura = C(200, 240, 255) },
		build = function(b, ctx)
			local model, torso, B = ctx.Model, ctx.Torso, ctx.Body
			model:SetAttribute("CAnim", true)
			eachPart(model, named({ "Pena" }), function(p)
				p.Material = GLASS
				p.Transparency = 0.1
			end)
			crowns(b, ctx, { { color = GOLD, count = 3, height = 0.75, gem = C(120, 220, 255) }, { color = ICEC, mat = GLASS, count = 3, height = 0.75, gem = GOLD } })
			chestFlake(b, ctx, C(220, 250, 255))
			-- LEQUE DE PAVÃO em pé atrás: 11 penas longas com "olho" de ouro e gema de gelo
			local fan = wavePivot(b, torso, "Leque", CF(0, B.h * 0.4, B.len * 0.4) * ANG(-0.35, 0, 0), V(0.05, 0, 0.04), 1.2, 0)
			for i = 1, 11 do
				local a = (i - 6) / 5 * 1.25
				local L = 3.2 - math.abs(i - 6) * 0.18
				local tip = V(math.sin(a) * L, math.cos(a) * L, 0)
				b:Seg(fan, "LequePena", V(0, 0, 0), tip, 0.16, 0.06, i % 2 == 0 and ICEC or WHITE, nil, V(0, 0, 1))
				for k = 1, 3 do
					local side = tip * (0.45 + k * 0.15)
					local perp = V(math.cos(a), -math.sin(a), 0) * 0.36
					b:Seg(fan, "LequeBarba", side - perp, side + perp, 0.07, 0.03, i % 2 == 0 and C(205, 240, 255) or C(240, 250, 255), GLASS, V(0, 0, 1)).Transparency = 0.15
				end
				local cf = CF(tip.X, tip.Y, tip.Z) * ANG(0, 0, -a)
				b:E(fan, "LequeOlho", V(0.62, 0.72, 0.1), GOLD, cf, FOIL)
				glow(b:E(fan, "LequeGema", V(0.34, 0.42, 0.14), C(40, 110, 255), cf))
			end
		end,
	}),
}

------------------------------------------------------------------ 3) STARLIGHT — asas de CONSTELAÇÃO (estrelas ligadas por luz) + lua de gelo
local STAR_WING = { V(0, 0, 0), V(0.9, 0.75, 0.1), V(1.8, 1.55, 0.3), V(2.7, 2.0, 0.5), V(3.3, 1.3, 0.7), V(3.0, 0.35, 0.9), V(2.3, -0.3, 1.0), V(1.4, -0.45, 0.8), V(0.5, -0.25, 0.4) }
Species.div2_star = {
	Name = "Starlight Phoenix",
	Rarity = "Mythic",
	Role = "Divine",
	Special = "C_GlacialRebirth",
	Stats = { HP = 1.6, Atk = 1.6, Speed = 20 },
	Look = baseLook({
		scale = 1.9,
		main = C(235, 245, 255),
		second = C(120, 150, 255),
		eye = C(180, 230, 255),
		extras = { crest = true, float = 2.6, stars = true, gem = GOLD, eyeGlow = true, aura = C(170, 200, 255) },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			crowns(b, ctx, { { color = C(255, 235, 150), mat = NEON, count = 2, height = 0.85 } })
			chestFlake(b, ctx, C(255, 240, 170))
			plumes(b, ctx, 3, 1.6, { C(150, 180, 255), C(230, 240, 255) }, C(255, 240, 170))
			for pair = 1, 2 do
				for _, side in ipairs({ -1, 1 }) do
					local s = pair == 1 and 1.05 or 0.7
					local cf = pair == 1 and CF(side * B.w * 0.3, B.h * 0.45, -B.len * 0.12) * ANG(0, 0, side * 0.25)
						or CF(side * B.w * 0.35, B.h * 0.2, B.len * 0.2) * ANG(0.3, 0, side * -0.35)
					local piv = wavePivot(b, torso, "AsaEstrelaPivo", cf, V(0, 0, 0.12), 1.5, side + pair)
					local pts = {}
					for i, p in ipairs(STAR_WING) do
						pts[i] = V(side * p.X, p.Y, p.Z) * s
					end
					-- membrana de luz bem transparente
					for i = 2, #pts - 1 do
						local m = b:Triangle(piv, "AsaLuz", pts[1], pts[i], pts[i + 1], 0.03, C(160, 200, 255), GLASS)
						m.Transparency = 0.55
					end
					-- linhas da constelação
					for i = 2, #pts do
						glow(b:Seg(piv, "AsaLinha", pts[i - 1], pts[i], 0.035, 0.035, C(170, 210, 255)))
					end
					glow(b:Seg(piv, "AsaLinha", pts[1], pts[4], 0.03, 0.03, C(170, 210, 255)))
					glow(b:Seg(piv, "AsaLinha", pts[1], pts[6], 0.03, 0.03, C(170, 210, 255)))
					-- estrelas nos pontos
					for i = 2, #pts do
						glow(diamond(b, piv, "AsaEstrela", i % 3 == 0 and 0.26 or 0.18, i % 3 == 0 and GOLD or WHITE, CF(pts[i].X, pts[i].Y, pts[i].Z), NEON))
					end
				end
			end
			-- lua crescente de gelo flutuando acima das costas
			local moon = wavePivot(b, torso, "Lua", CF(0, neckY(look, B) + 1.75, B.len * 0.2) * ANG(0, 0, 0.5), V(0, 0, 0.08), 0.8, 0)
			for i = 0, 10 do
				local a = -1.9 + i / 10 * 3.8
				local r = 0.95
				local w = 0.32 * math.cos(a / 2.2)
				local blk = b:K(moon, "LuaPedaco", V(w + 0.06, 0.26, 0.2), C(225, 240, 255), CF(math.cos(a) * r, math.sin(a) * r, 0) * ANG(0, 0, a), ICE)
				blk.Transparency = 0.05
			end
		end,
	}),
}

------------------------------------------------------------------ 4) FROST DRAGON PHOENIX — asas de dragão de gelo, chifres de ouro, cristais nas costas
Species.div2_dragon = {
	Name = "Frost Dragon Phoenix",
	Rarity = "Mythic",
	Role = "Divine",
	Special = "C_GlacialRebirth",
	Stats = { HP = 1.6, Atk = 1.6, Speed = 20 },
	Look = baseLook({
		scale = 2.0,
		main = C(225, 240, 255),
		second = C(70, 140, 230),
		head = { size = 1.35, snout = 1.35, snoutW = 0.6, lift = 0.5, muzzle = C(235, 245, 255), nose = C(40, 80, 160), forward = 0.2 },
		legs = { len = 1.1, thick = 0.38, claws = GOLD, paw = C(180, 220, 255) },
		tail = "dragon",
		wingSize = 1.55,
		wingBone = GOLD,
		wingColor = C(170, 225, 255),
		spikeColor = ICEC,
		extras = { wings = "dragon", horns = "dragon", crystals = ICEC, crystalSize = 1.2, float = 1.6, eyeGlow = true, aura = C(170, 230, 255) },
		build = function(b, ctx)
			local model = ctx.Model
			model:SetAttribute("CAnim", true)
			eachPart(model, named({ "AsaMembrana" }), function(p)
				p.Material = GLASS
				p.Transparency = 0.25
			end)
			eachPart(model, named({ "Chifre", "Chifre1", "Chifre2", "Chifre3" }), function(p)
				p.Color = GOLD
				p.Material = FOIL
			end)
			crowns(b, ctx, { { color = ICEC, mat = GLASS, count = 2, height = 0.6, gem = GOLD } })
			chestFlake(b, ctx, C(200, 240, 255))
		end,
	}),
}

------------------------------------------------------------------ 5) CELESTIAL GYRO — 3 anéis de ouro girando em volta (giroscópio) + asas de vidro
Species.div2_gyro = {
	Name = "Celestial Gyro Phoenix",
	Rarity = "Mythic",
	Role = "Divine",
	Special = "C_GlacialRebirth",
	Stats = { HP = 1.6, Atk = 1.6, Speed = 20 },
	Look = baseLook({
		scale = 1.8,
		wingSize = 1.6,
		extras = { wings = "feather", crest = true, float = 2.8, gem = C(120, 220, 255), eyeGlow = true, aura = C(200, 240, 255) },
		build = function(b, ctx)
			local model, torso = ctx.Model, ctx.Torso
			model:SetAttribute("CAnim", true)
			eachPart(model, named({ "Pena" }), function(p)
				p.Material = GLASS
				p.Transparency = 0.1
			end)
			crowns(b, ctx, { { color = GOLD, count = 3, height = 0.75, gem = C(120, 220, 255) } })
			chestFlake(b, ctx, C(220, 250, 255))
			plumes(b, ctx, 5, 1.2, { ICEC, GOLD, WHITE }, GOLD)
			local rings = {
				{ ANG(0.45, 0, 0.25), 2.7, V(0, 0.7, 0) },
				{ ANG(-0.55, 0, -0.35), 3.0, V(0, -0.5, 0) },
				{ ANG(PI / 2, 0.3, 0), 3.3, V(0, 0.35, 0) },
			}
			for i, r in ipairs(rings) do
				local piv = spinPivot(b, torso, "Giro", CF(0, 0.2, 0) * r[1], r[3])
				ring(b, piv, "GiroAro", CFrame.new(), r[2], 30, 0.13, 0.1, GOLD, FOIL)
				for k = 1, 4 do
					local a = k / 4 * PI * 2 + i
					glow(diamond(b, piv, "GiroCristal", 0.26, ICEC, ANG(0, a, 0) * CF(r[2], 0, 0), ICE), nil).Material = ICE
				end
			end
		end,
	}),
}

return {
	Species = Species,
	Order = { "div2_crystal", "div2_twin", "div2_star", "div2_dragon", "div2_gyro" },
	Specials = {},
}
