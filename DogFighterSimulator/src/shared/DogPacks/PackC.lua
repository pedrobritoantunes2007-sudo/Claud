-- Pacote C: 13 cachorros MÍTICOS absurdos, reconhecíveis só pela silhueta.
-- Hidra de 5 cabeças, dragão-esqueleto, kraken, relógio, buraco negro minúsculo, serafim de 6 asas,
-- golem de cristal gigante, fênix de gelo, colosso do trovão, unicórnio arco-íris, samurai oni,
-- mecha gigante e cachorro planeta com anéis e lua.
--
-- Geometria extra vem de Look.build(b, ctx) (ver DogBuilder). Peças que giram/balançam são presas a
-- pivôs com atributos lidos pelo cliente (EffectsPacks/PackC):
--   CSpin  = Vector3 (rad/s em X, Y, Z) giro contínuo do Weld do pivô
--   CWave  = Vector3 (amplitude em rad nos eixos X, Y, Z) balanço senoidal; CFreq = rad/s; CPhase = fase
-- O modelo recebe o atributo "CAnim" para o cliente saber que precisa animar.
local C = Color3.fromRGB
local PI = math.pi
local ANG = CFrame.Angles

local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local METAL = Enum.Material.Metal
local SMOOTH = Enum.Material.SmoothPlastic

local WHITE = C(250, 250, 250)
local BONE = C(236, 228, 204)
local GOLD = C(245, 195, 70)
local DARK = C(24, 20, 22)
local STEEL = C(170, 176, 188)

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

-- pivô invisível que gira (CSpin) ou balança (CWave) no cliente
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

-- anel segmentado no plano XZ local de cf
local function ring(b, parent, name, cf, radius, segs, thick, height, color, mat)
	local arc = 2 * PI * radius / segs * 1.12
	local list = {}
	for i = 1, segs do
		local a = i / segs * PI * 2
		local p = b:K(parent, name, V(thick, height, arc), color, cf * ANG(0, a, 0) * CF(radius, 0, 0), mat)
		table.insert(list, p)
	end
	return list
end

-- engrenagem: disco + dentes, no plano XZ local de cf
local function gear(b, parent, name, cf, radius, teeth, thick, color)
	b:E(parent, name, V(radius * 2, thick, radius * 2), color, cf, METAL)
	b:E(parent, name .. "Eixo", V(radius * 0.5, thick * 1.6, radius * 0.5), DARK, cf, METAL)
	for i = 1, teeth do
		local a = i / teeth * PI * 2
		b:K(parent, name .. "Dente", V(radius * 0.32, thick * 0.9, radius * 0.24), color, cf * ANG(0, a, 0) * CF(radius * 1.02, 0, 0), METAL)
	end
end

-- tentáculo: começa em (0,0,0) do pivô e cresce para +X local, curvando para -Y e enrolando na ponta
local function tentacle(b, pivot, name, len, r0, color, sucker, curl, n)
	n = n or 6
	local pts = { V(0, 0, 0) }
	local dir = V(1, 0.25, 0).Unit
	local step = len / n
	local p = V(0, 0, 0)
	for k = 1, n do
		local a = -(curl or 0.45) * (k / n) ^ 1.4 * 1.6
		local c, s = math.cos(a), math.sin(a)
		local d = V(dir.X * c - dir.Y * s, dir.X * s + dir.Y * c, 0)
		p = p + d * step * (1.12 - k / n * 0.4)
		table.insert(pts, p)
	end
	local radii = {}
	for k = 1, n do
		radii[k] = r0 * (1 - (k - 1) / n * 0.8)
	end
	b:Chain(pivot, name, pts, radii, color)
	if sucker then
		for k = 2, n - 1 do
			local m = (pts[k] + pts[k + 1]) / 2
			local r = radii[k]
			b:E(pivot, name .. "Ventosa", V(r * 0.9, r * 0.5, r * 0.9), sucker, CF(m.X, m.Y - r * 0.82, m.Z), SMOOTH)
		end
	end
	return pts
end

-- asa de penas (cópia própria, para asas extras); P(x,y,z) no espaço do pivô
local function featherWing(b, pivot, side, ws, cols, eyeColor)
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
		b:Seg(pivot, "Pena", root, root + dir * len, 0.22 * ws, 0.05 * ws, cols[2 + (i % 2)], nil, normal)
		if eyeColor and i % 2 == 1 then
			-- olhos nas penas (serafim)
			local at = root + dir * len * 0.55 + normal * 0.07 * ws * side
			local cf = CFrame.lookAt(at, at + normal * side)
			b:E(pivot, "OlhoAsa", V(0.24, 0.16, 0.06) * ws, WHITE, cf, SMOOTH)
			glow(b:E(pivot, "OlhoAsaIris", V(0.1, 0.1, 0.04) * ws, eyeColor, cf * CF(0, 0, -0.025 * ws)))
		end
	end
end

-- Copia uma cabeça inteira (cabeça + mandíbula + tudo soldado nelas) para outra posição.
-- Usado pela hidra (5 cabeças). Motores copiados são renomeados (o Animator só anima Neck/Jaw 1..3).
local function cloneHead(ctx, src, name, cf)
	local model, torso = ctx.Model, ctx.Torso
	local joints = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Weld") or d:IsA("Motor6D") then
			table.insert(joints, d)
		end
	end
	local set, list = { [src] = true }, { src }
	local grew = true
	while grew do
		grew = false
		for _, j in ipairs(joints) do
			local p0, p1 = j.Part0, j.Part1
			if p0 and p1 and set[p0] and not set[p1] then
				set[p1] = true
				table.insert(list, p1)
				grew = true
			end
		end
	end
	local T = cf * src.CFrame:Inverse()
	local map = {}
	for _, p in ipairs(list) do
		map[p] = p:Clone()
	end
	for p, c in pairs(map) do
		c.CFrame = T * p.CFrame
		for _, j in ipairs(c:GetChildren()) do
			if j:IsA("Weld") or j:IsA("Motor6D") then
				local p0, p1 = j.Part0, j.Part1
				if p0 and map[p0] then
					j.Part0 = map[p0]
				end
				if p1 and map[p1] then
					j.Part1 = map[p1]
				end
				if j:IsA("Motor6D") then
					j.Name = "C" .. j.Name
				end
			end
		end
	end
	for _, c in pairs(map) do
		c.Parent = model
	end
	local head = map[src]
	head.Name = name
	local w = Instance.new("Weld")
	w.Part0 = torso
	w.Part1 = head
	w.C0 = torso.CFrame:Inverse() * head.CFrame
	w.Parent = head
	return head
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

-- ponto na superfície do tronco (elipsoide aproximado): a = ângulo em volta de Z (0 = topo), fz -0.5..0.5
local function bodyPoint(B, a, fz, push)
	if B.Surf then -- Blocky2: tronco de blocos (o DogBuilder empresta a função dele)
		return B.Surf(B, a, fz, push)
	end
	local rx, ry = B.w * 0.5, B.h * 0.5
	local k = math.sqrt(math.max(0.05, 1 - (2 * fz) ^ 2))
	local p = V(math.sin(a) * rx * k, math.cos(a) * ry * k + B.h * 0.04, fz * B.len)
	local n = V(p.X / (rx * rx), (p.Y - B.h * 0.04) / (ry * ry), p.Z / (B.len * B.len * 0.25)).Unit
	p = p + n * (push or 0)
	return CFrame.lookAt(p, p + n)
end

local function neckTop(look, B, x)
	local H = look.head
	return V(x or 0, B.h * 0.3 + (H.lift or 0), -B.len * 0.45 - (H.forward or 0))
end

local RAINBOW = { C(255, 70, 80), C(255, 160, 50), C(255, 230, 70), C(90, 220, 110), C(80, 170, 255), C(170, 100, 255) }

local Species = {}

------------------------------------------------------------------------ HIDRA
Species.hydra_hound = {
	Name = "Five-Headed Hydra",
	Rarity = "Mythic",
	Role = "Regen",
	Special = "C_HydraFrenzy",
	Stats = { HP = 1.65, Atk = 1.4, Speed = 15 },
	Look = {
		scale = 2.1,
		main = C(40, 112, 78),
		second = C(190, 230, 80),
		belly = C(214, 206, 140),
		eye = C(255, 220, 40),
		body = { len = 3.6, w = 2.1, h = 1.7, chest = 1.2, haunch = 0.95 },
		legs = { len = 0.95, thick = 0.5, claws = BONE, noToes = true },
		head = { size = 1.15, snout = 1.15, snoutW = 0.8, long = 1.12, lift = 1.9, forward = 0.7, neckW = 0.62, brows = C(190, 230, 80) },
		mood = "evil",
		ears = "swept",
		earColor = C(190, 230, 80),
		earInner = C(30, 80, 55),
		tail = "dragon",
		tailSize = 1.2,
		spikeColor = C(190, 230, 80),
		heads = 3,
		extras = { scales = true, spikes = C(190, 230, 80), spikeCount = 6, horns = "small", eyeGlow = true, aura = C(150, 255, 120) },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			local S = ctx.Scale
			local hs = look.head.size
			local srcs = { model:FindFirstChild("Head1"), model:FindFirstChild("Head3") }
			for i, side in ipairs({ -1, 1 }) do
				local src = srcs[i]
				if src then
					local top = V(side * B.w * 1.05, B.h * 0.3 + look.head.lift - 0.85, -B.len * 0.28)
					local base = V(side * B.w * 0.36, B.h * 0.12, -B.len * 0.22)
					local mid = V(side * B.w * 0.95, B.h * 0.15, -B.len * 0.2)
					local r = 0.3 * hs * look.head.neckW
					b:Chain(torso, "PescocoHidra", { base, mid, top }, { r * 1.15, r }, look.main)
					b:Seg(torso, "GargantaHidra", mid + V(0, -0.15, -0.12), top + V(0, -0.25, -0.12), r * 0.75, r * 0.6, look.belly)
					local yaw = -side * 1.0
					local cf = torso.CFrame * CF(top * S) * ANG(0, yaw, 0) * CF(0, 0.12 * hs * S, -0.3 * hs * S)
					cloneHead(ctx, src, "Head" .. (3 + i), cf)
				end
			end
			-- cristas de espinhos ao longo dos pescoços do meio
			for _, x in ipairs({ -1, 0, 1 }) do
				local top = neckTop(look, B, x * B.w * 0.44 * 1.15)
				local base = V(x * B.w * 0.44 * 0.8, B.h * 0.08, -B.len * 0.3)
				for k = 1, 3 do
					local p = base:Lerp(top, k / 4) + V(0, 0.28, 0.12)
					b:W(torso, "EspinhoPescoco", V(0.06, 0.32, 0.26), look.second, CF(p) * ANG(0.5, 0, 0))
				end
			end
		end,
	},
}

------------------------------------------------------------------------ DRAGÃO-ESQUELETO
Species.bone_dragon = {
	Name = "Bone Dragon",
	Rarity = "Mythic",
	Role = "Undead",
	Special = "C_BoneCage",
	Stats = { HP = 1.35, Atk = 1.55, Speed = 18 },
	Look = {
		scale = 1.9,
		main = C(30, 70, 66),
		second = C(90, 255, 200),
		belly = C(30, 70, 66),
		eye = C(90, 255, 200),
		body = { len = 3.4, w = 1.25, h = 1.25, chest = 1.1, haunch = 0.85 },
		legs = { len = 1.25, thick = 0.24, color = BONE, claws = C(90, 255, 200), noToes = true },
		head = { size = 1.35, snout = 1.25, snoutW = 0.75, long = 1.12, lift = 0.75, forward = 0.25, cap = BONE, muzzle = BONE, skull = true, neckW = 0.6 },
		neckColor = BONE,
		mood = "evil",
		eyes = "skull",
		ears = "none",
		tail = "bone",
		tailSize = 1.3,
		tailColor = BONE,
		hornColor = BONE,
		wingSize = 1.35,
		wingBone = BONE,
		wingColor = C(40, 110, 95),
		extras = {
			ribs = BONE,
			noBelly = true,
			wings = "dragon",
			horns = "dragon",
			smoke = C(40, 160, 130),
			eyeGlow = true,
			aura = C(90, 255, 200),
		},
		build = function(b, ctx)
			local model, torso, B = ctx.Model, ctx.Torso, ctx.Body
			-- corpo vira "alma" translúcida dentro das costelas, com coração verde aceso
			eachPart(model, named({ "Torso", "Peito", "Quadril" }), function(p)
				p.Transparency = 0.55
				p.Material = GLASS
				p.CastShadow = false
			end)
			eachPart(model, named({ "AsaMembrana" }), function(p)
				p.Transparency = 0.35
			end)
			glow(b:E(torso, "Coracao", V(0.55, 0.6, 0.5), C(90, 255, 200), CF(0, 0, -B.len * 0.18)))
			glow(b:E(torso, "Alma", V(0.3, 0.3, 0.9), C(200, 255, 235), CF(0, 0.05, B.len * 0.08))).Transparency = 0.3
			-- espinha dorsal com espetos de osso
			for i = 0, 5 do
				local z = -B.len * 0.36 + i * B.len * 0.15
				local h = 0.55 - math.abs(i - 2) * 0.07
				b:W(torso, "EspetoOsso", V(0.08, h, h * 0.8), BONE, CF(0, B.h * 0.55 + h * 0.45, z) * ANG(0.3, 0, 0), SMOOTH)
			end
			-- esterno
			b:Seg(torso, "Esterno", V(0, -B.h * 0.2, -B.len * 0.36), V(0, -B.h * 0.25, -B.len * 0.02), 0.09, 0.06, BONE, SMOOTH)
		end,
	},
}

------------------------------------------------------------------------ KRAKEN
Species.kraken_hound = {
	Name = "Kraken Dog",
	Rarity = "Mythic",
	Role = "Abyssal",
	Special = "C_KrakenGrab",
	Stats = { HP = 1.55, Atk = 1.4, Speed = 15 },
	Look = {
		scale = 1.85,
		main = C(150, 45, 95),
		second = C(255, 150, 185),
		belly = C(250, 195, 210),
		eye = C(255, 215, 50),
		body = { len = 3.2, w = 1.9, h = 1.6, chest = 1.15 },
		legs = { len = 0.85, thick = 0.42, noToes = true },
		head = { size = 1.6, snout = 0.55, snoutW = 0.9, w = 1.1, tall = 1.05, lift = 0.5, forward = 0.2, eyeSize = 1.35, muzzle = C(190, 80, 125) },
		mood = "fierce",
		ears = "none",
		tail = "tentacles",
		tailSize = 1.3,
		extras = { bubbles = C(170, 230, 255), eyeGlow = true, aura = C(255, 120, 200), spots = C(205, 90, 140), spotCount = 14 },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			local head = model:FindFirstChild("Head1")
			local hs = look.head.size
			if head then
				-- manto de polvo saindo do topo da cabeça para trás
				local manto = b:E(head, "Manto", V(1.05, 1.15, 1.6) * hs, look.main, CF(0, 0.55 * hs, 0.55 * hs) * ANG(0.55, 0, 0))
				local _ = manto
				for i = 1, 5 do
					local a = i * 1.3
					b:E(
						head,
						"MantoPinta",
						V(0.22, 0.16, 0.22) * hs,
						look.second,
						CF(math.cos(a) * 0.35 * hs, 0.85 * hs + math.sin(a) * 0.12 * hs, (0.5 + i * 0.1) * hs) * ANG(0.5, 0, 0),
						SMOOTH
					)
				end
				-- barba de tentáculos embaixo do focinho (estilo Cthulhu)
				for i = -2, 2 do
					local piv = wavePivot(
						b,
						head,
						"BarbaPivo",
						CF(i * 0.14 * hs, -0.42 * hs, -0.55 * hs) * ANG(0, PI / 2 + i * 0.25, -1.25),
						V(0, 0.15, 0.25),
						2.2,
						i * 0.9
					)
					tentacle(b, piv, "Barba", (0.75 - math.abs(i) * 0.1) * hs, 0.09 * hs, look.main, look.belly, 0.7, 4)
				end
			end
			-- 6 tentáculos gigantes saindo dos lados do corpo
			for _, side in ipairs({ -1, 1 }) do
				for k = 0, 2 do
					local z = -B.len * 0.25 + k * B.len * 0.25
					local cf = CF(side * B.w * 0.42, -B.h * 0.05 + k * 0.05, z) * ANG(0, side < 0 and PI or 0, 0) * ANG(0, (k - 1) * 0.5 * side, -0.25)
					local piv = wavePivot(b, torso, "TentaculoPivo", cf, V(0.15, 0.12, 0.2), 1.6, k * 1.7 + side)
					tentacle(b, piv, "Tentaculo", 2.6 - k * 0.2, 0.3, look.main, look.belly, 0.8, 6)
				end
			end
		end,
	},
}

------------------------------------------------------------------------ RELÓGIO
Species.chrono_hound = {
	Name = "Chrono Dog",
	Rarity = "Mythic",
	Role = "Time",
	Special = "C_TimeStop",
	Stats = { HP = 1.3, Atk = 1.5, Speed = 18 },
	Look = {
		scale = 1.45,
		material = METAL,
		main = C(200, 158, 78),
		second = C(130, 86, 44),
		belly = C(246, 236, 210),
		eye = C(110, 220, 255),
		body = { len = 3.0, w = 1.55, h = 1.5 },
		legs = { len = 1.05, thick = 0.36, paw = C(130, 86, 44), noToes = true },
		head = { size = 1.4, snout = 0.85, lift = 0.5, muzzle = C(246, 236, 210), eyeSize = 1.1 },
		mood = "calm",
		ears = "none",
		tail = "stub",
		extras = { eyeGlow = true, aura = C(120, 220, 255) },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			local ivory, brass, bronze = look.belly, look.main, look.second
			-- mostradores nos dois lados do corpo com ponteiros girando
			for _, side in ipairs({ -1, 1 }) do
				local center = V(side * B.w * 0.47, B.h * 0.04, -B.len * 0.05)
				local face = CF(center) * ANG(0, 0, side * PI / 2) -- eixo Y local = normal para fora
				b:E(torso, "Mostrador", V(1.55, 0.14, 1.55), ivory, face, SMOOTH)
				ring(b, torso, "Moldura", face, 0.8, 18, 0.14, 0.2, brass, METAL)
				for h = 1, 12 do
					local a = h / 12 * PI * 2
					local big = h % 3 == 0
					b:K(torso, "Marca", V(big and 0.08 or 0.05, 0.05, big and 0.2 or 0.12), DARK, face * ANG(0, a, 0) * CF(0, 0.08, -0.62), SMOOTH)
				end
				glow(b:E(torso, "Centro", V(0.14, 0.1, 0.14), C(120, 220, 255), face * CF(0, 0.1, 0)))
				local hour = spinPivot(b, torso, "Ponteiro", face * CF(0, 0.09, 0), V(0, -0.5 * side, 0))
				b:K(hour, "PonteiroHora", V(0.09, 0.04, 0.42), DARK, CF(0, 0, -0.18), SMOOTH)
				local minute = spinPivot(b, torso, "Ponteiro", face * CF(0, 0.11, 0), V(0, -3 * side, 0))
				b:K(minute, "PonteiroMinuto", V(0.06, 0.04, 0.62), DARK, CF(0, 0, -0.28), SMOOTH)
				-- engrenagem girando no quadril
				local gcf = CF(side * B.w * 0.4, B.h * 0.18, B.len * 0.3) * ANG(0, 0, side * PI / 2)
				local g = spinPivot(b, torso, "Engrenagem", gcf, V(0, 1.2 * side, 0))
				gear(b, g, "Engrenagem", CFrame.new(), 0.42, 9, 0.12, bronze)
			end
			-- chave de corda nas costas
			local key = spinPivot(b, torso, "Chave", CF(0, B.h * 0.5, B.len * 0.08), V(0, 1.6, 0))
			b:K(key, "ChaveEixo", V(0.16, 0.7, 0.16), brass, CF(0, 0.3, 0), METAL)
			for _, side in ipairs({ -1, 1 }) do
				b:E(key, "ChaveAsa", V(0.75, 0.55, 0.14), brass, CF(side * 0.4, 0.75, 0), METAL)
				b:E(key, "ChaveFuro", V(0.32, 0.24, 0.16), bronze, CF(side * 0.42, 0.75, 0), METAL)
			end
			-- pêndulo balançando embaixo da barriga
			local pend = wavePivot(b, torso, "Pendulo", CF(0, -B.h * 0.35, 0.1), V(0, 0, 0.45), 3.2, 0)
			b:K(pend, "PenduloHaste", V(0.07, 0.75, 0.07), brass, CF(0, -0.38, 0), METAL)
			b:E(pend, "PenduloDisco", V(0.55, 0.55, 0.12), GOLD, CF(0, -0.85, 0), Enum.Material.Foil)
			-- sinos de despertador no lugar das orelhas + martelinho
			local head = model:FindFirstChild("Head1")
			if head then
				local hs = look.head.size
				for _, side in ipairs({ -1, 1 }) do
					local cfb = CF(side * 0.3 * hs, 0.5 * hs, 0.05 * hs) * ANG(0, 0, -side * 0.55)
					b:E(head, "Sino", V(0.55, 0.5, 0.55) * hs, brass, cfb * CF(0, 0.12 * hs, 0), METAL)
					b:E(head, "SinoBorda", V(0.6, 0.08, 0.6) * hs, bronze, cfb * CF(0, -0.1 * hs, 0), METAL)
					b:E(head, "SinoPe", V(0.08, 0.2, 0.08) * hs, bronze, cfb * CF(0, 0.42 * hs, 0), METAL)
				end
				local ham = wavePivot(b, head, "Martelo", CF(0, 0.55 * hs, 0.1 * hs), V(0, 0, 0.35), 14, 0)
				b:K(ham, "MarteloHaste", V(0.04, 0.32, 0.04) * hs, DARK, CF(0, 0.14 * hs, 0), METAL)
				b:E(ham, "MarteloBola", V(0.12, 0.12, 0.12) * hs, bronze, CF(0, 0.32 * hs, 0), METAL)
				-- monóculo
				local eye = CF(0.21 * hs, 0.08 * hs, -0.42 * hs)
				ring(b, head, "Monoculo", eye * ANG(PI / 2, 0, 0), 0.15 * hs, 10, 0.03 * hs, 0.03 * hs, GOLD, Enum.Material.Foil)
				b:Seg(
					head,
					"MonoculoCorrente",
					eye.Position + V(0.12, -0.1, 0) * hs,
					V(0.45, -0.35, 0.05) * hs,
					0.015 * hs,
					0.015 * hs,
					GOLD,
					Enum.Material.Foil
				)
			end
			-- ampulheta na cauda
			local tail = model:FindFirstChild("TailBase")
			if tail then
				local base = CF(0, 0.35, 0.35) * ANG(-0.5, 0, 0)
				b:E(tail, "AmpulhetaTampa", V(0.55, 0.1, 0.55), bronze, base, METAL)
				b:E(tail, "AmpulhetaTampa", V(0.55, 0.1, 0.55), bronze, base * CF(0, 0.9, 0), METAL)
				local g1 = b:E(tail, "AmpulhetaVidro", V(0.45, 0.45, 0.45), C(220, 240, 255), base * CF(0, 0.25, 0), GLASS)
				local g2 = b:E(tail, "AmpulhetaVidro", V(0.45, 0.45, 0.45), C(220, 240, 255), base * CF(0, 0.65, 0), GLASS)
				g1.Transparency = 0.45
				g2.Transparency = 0.45
				glow(b:E(tail, "Areia", V(0.3, 0.2, 0.3), C(255, 210, 110), base * CF(0, 0.15, 0)))
				glow(b:E(tail, "Areia", V(0.05, 0.4, 0.05), C(255, 210, 110), base * CF(0, 0.45, 0)))
				for _, s in ipairs({ -1, 1 }) do
					b:K(tail, "AmpulhetaHaste", V(0.04, 0.9, 0.04), bronze, base * CF(s * 0.24, 0.45, 0), METAL)
				end
			end
		end,
	},
}

------------------------------------------------------------------------ BURACO NEGRO (minúsculo)
Species.singularity_pup = {
	Name = "Singularity Pup",
	Rarity = "Mythic",
	Role = "Gravity",
	Special = "C_EventHorizon",
	Stats = { HP = 1.2, Atk = 1.65, Speed = 21 },
	Look = {
		scale = 0.5,
		main = C(10, 8, 18),
		second = C(255, 150, 50),
		belly = C(18, 14, 30),
		eye = C(255, 255, 255),
		body = { len = 1.7, w = 1.5, h = 1.5 },
		legs = { len = 0.6, thick = 0.34, noToes = true, paw = C(255, 150, 50) },
		head = { size = 1.45, snout = 0.45, snoutW = 0.9, lift = 0.25, eyeSize = 1.5, muzzle = C(26, 20, 40) },
		mood = "calm",
		eyes = "glow",
		ears = "big",
		earInner = C(255, 150, 50),
		tail = "wisp",
		extras = { float = 2.2, stars = true, eyeGlow = true, aura = C(255, 160, 70) },
		build = function(b, ctx)
			local model, torso = ctx.Model, ctx.Torso
			model:SetAttribute("CAnim", true)
			-- disco de acreção inclinado girando (laranja → amarelo → branco)
			local tilt = CF(0, 0.05, 0) * ANG(0.35, 0, 0.25)
			local disk = spinPivot(b, torso, "Acrecao", tilt, V(0, 2.4, 0))
			ring(b, disk, "Disco", CFrame.new(), 2.5, 26, 0.5, 0.06, C(255, 120, 40), NEON)
			ring(b, disk, "Disco", CFrame.new(), 2.0, 22, 0.45, 0.07, C(255, 200, 80), NEON)
			ring(b, disk, "Disco", CFrame.new(), 1.55, 18, 0.3, 0.08, C(255, 250, 230), NEON)
			-- destroços presos na órbita
			for i = 1, 5 do
				local a = i / 5 * PI * 2 + 0.4
				b:K(
					disk,
					"Destroco",
					V(0.32, 0.26, 0.3) * (0.6 + (i % 3) * 0.25),
					C(110, 100, 120),
					CF(math.cos(a) * 2.95, 0.1, math.sin(a) * 2.95) * ANG(i, i * 2, 0),
					Enum.Material.Slate
				)
			end
			-- anel de fótons (vertical, sempre "de frente")
			ring(b, torso, "AnelFoton", CF(0, 0.05, 0) * ANG(PI / 2, 0, 0), 1.25, 20, 0.08, 0.06, C(255, 240, 210), NEON)
			-- jatos polares
			local up = tilt.Rotation * V(0, 1, 0)
			for _, s in ipairs({ 1, -1 }) do
				local a = up * 0.7 * s
				local t = up * 2.6 * s
				local jet = glow(b:Seg(torso, "Jato", a, t, 0.12, 0.12, C(190, 160, 255)))
				jet.Transparency = 0.2
				glow(b:Seg(torso, "JatoBrilho", a, a:Lerp(t, 0.6), 0.22, 0.22, C(120, 80, 255))).Transparency = 0.55
			end
		end,
	},
}

------------------------------------------------------------------------ SERAFIM (6 asas)
Species.seraph_hound = {
	Name = "Six-Winged Seraph",
	Rarity = "Mythic",
	Role = "Holy",
	Special = "C_Judgement",
	Stats = { HP = 1.45, Atk = 1.4, Speed = 17 },
	Look = {
		scale = 1.55,
		main = C(252, 250, 244),
		second = C(255, 212, 95),
		belly = C(255, 255, 252),
		eye = C(255, 236, 150),
		body = { len = 3.0, w = 1.4, h = 1.4 },
		legs = { len = 1.0, thick = 0.36, paw = C(255, 212, 95) },
		head = { size = 1.4, snout = 0.8, lift = 0.55, eyeSize = 1.05 },
		mood = "calm",
		ears = "floppy",
		earSize = 1.15,
		earTip = C(255, 212, 95),
		tail = "plume",
		wingSize = 1.35,
		wingColors = { C(255, 255, 252), C(255, 246, 220), C(255, 220, 130) },
		extras = { wings = "feather", halo = C(255, 225, 110), float = 2.4, stars = true, gem = C(120, 200, 255), eyeGlow = true, aura = C(255, 230, 140) },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			local cols = look.wingColors
			for _, side in ipairs({ -1, 1 }) do
				-- par de cima: sobe e cobre por cima da cabeça
				local up =
					wavePivot(b, torso, "AsaCima", CF(side * B.w * 0.22, B.h * 0.48, -B.len * 0.28) * ANG(-0.55, 0, side * 0.75), V(0, 0, 0.12), 2.2, side)
				featherWing(b, up, side, 0.95, cols, C(90, 170, 255))
				-- par de baixo: desce cobrindo as patas
				local low =
					wavePivot(b, torso, "AsaBaixo", CF(side * B.w * 0.42, -B.h * 0.05, B.len * 0.12) * ANG(0.35, 0, side * -1.75), V(0, 0, 0.1), 1.8, side + 1)
				featherWing(b, low, side, 0.9, cols, C(90, 170, 255))
			end
			-- roda sagrada de olhos girando em volta do corpo (ofanim)
			local wheel = spinPivot(b, torso, "Roda", CF(0, 0.1, 0) * ANG(0, 0, PI / 2), V(0, 0.9, 0))
			ring(b, wheel, "RodaAro", CFrame.new(), 2.3, 24, 0.14, 0.16, GOLD, Enum.Material.Foil)
			for i = 1, 6 do
				local a = i / 6 * PI * 2
				local cf = ANG(0, a, 0) * CF(2.3, 0, 0) * ANG(0, PI / 2, 0)
				b:E(wheel, "RodaOlho", V(0.42, 0.28, 0.12), WHITE, cf, SMOOTH)
				glow(b:E(wheel, "RodaIris", V(0.18, 0.18, 0.08), C(90, 170, 255), cf * CF(0, 0, 0.04)))
				glow(b:E(wheel, "RodaIris", V(0.18, 0.18, 0.08), C(90, 170, 255), cf * CF(0, 0, -0.04)))
			end
		end,
	},
}

------------------------------------------------------------------------ GOLEM DE CRISTAL (gigante)
Species.crystal_golem = {
	Name = "Crystal Golem",
	Rarity = "Mythic",
	Role = "Colossus",
	Special = "C_CrystalPrison",
	Stats = { HP = 1.85, Atk = 1.25, Speed = 13 },
	Look = {
		scale = 2.75,
		material = Enum.Material.Slate,
		main = C(72, 76, 96),
		second = C(80, 245, 225),
		belly = C(98, 102, 124),
		eye = C(110, 255, 240),
		body = { len = 3.1, w = 2.4, h = 2.0, chest = 1.45, haunch = 0.8 },
		legs = { len = 1.15, thick = 0.6, front = 1.45, hind = 0.85, noToes = true, claws = C(80, 245, 225) },
		head = { size = 1.2, snout = 0.55, snoutW = 1.25, w = 1.2, flat = true, lift = 0.15, forward = 0.3, brows = C(80, 245, 225), muzzle = C(98, 102, 124) },
		mood = "fierce",
		ears = "none",
		tail = "rock",
		extras = {
			rocks = true,
			cracks = C(80, 245, 225),
			cracksHead = C(80, 245, 225),
			eyeGlow = true,
			aura = C(80, 245, 225),
			muscles = true,
			tag = false,
		},
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			local cry = look.second
			-- espigões gigantes de cristal nas costas
			local list = {
				{ 0, 0.5, -0.12, 0, 2.4 },
				{ 0.36, 0.42, -0.25, -0.5, 1.7 },
				{ -0.36, 0.42, -0.2, 0.5, 1.8 },
				{ 0.22, 0.45, 0.18, -0.3, 1.4 },
				{ -0.2, 0.45, 0.22, 0.35, 1.25 },
				{ 0.05, 0.42, 0.38, 0.1, 0.9 },
			}
			for i, c in ipairs(list) do
				local h = c[5]
				local base = CF(c[1] * B.w, c[2] * B.h, c[3] * B.len) * ANG(0.15, i * 0.8, c[4])
				local body = b:K(torso, "CristalGigante", V(0.5 * h * 0.45, h * 0.7, 0.5 * h * 0.45), cry, base * CF(0, h * 0.35, 0), GLASS)
				body.Transparency = 0.15
				for k = 0, 3 do
					local tip = b:W(
						torso,
						"CristalPonta",
						V(0.5 * h * 0.45 * 0.5, h * 0.35, 0.5 * h * 0.45 * 0.5),
						cry,
						base * CF(0, h * 0.7, 0) * ANG(0, k * PI / 2, 0) * CF(0, h * 0.175, 0.5 * h * 0.45 * 0.25) * ANG(0, PI, 0),
						GLASS
					)
					tip.Transparency = 0.15
				end
				if i % 2 == 1 then
					glow(b:K(torso, "CristalNucleo", V(0.1, h * 0.6, 0.1) * 1.4, C(220, 255, 255), base * CF(0, h * 0.4, 0)))
				end
			end
			-- núcleo no peito
			glow(b:E(torso, "Nucleo", V(0.7, 0.7, 0.3), cry, CF(0, -B.h * 0.02, -B.len * 0.5)))
			b:E(torso, "NucleoMoldura", V(1.0, 1.0, 0.25), C(50, 52, 66), CF(0, -B.h * 0.02, -B.len * 0.47))
			-- pedregulhos nos ombros
			for _, side in ipairs({ -1, 1 }) do
				b:K(torso, "Pedregulho", V(1.1, 0.9, 1.0), C(60, 62, 80), CF(side * B.w * 0.55, B.h * 0.4, -B.len * 0.28) * ANG(0.3, side * 0.5, side * 0.4))
				local sc = b:K(torso, "CristalOmbro", V(0.3, 1.0, 0.3), cry, CF(side * B.w * 0.62, B.h * 0.75, -B.len * 0.28) * ANG(0, 0, -side * 0.55), GLASS)
				sc.Transparency = 0.15
			end
			-- punhos de pedra nas patas da frente
			for _, name in ipairs({ "LegFL", "LegFR" }) do
				local leg = model:FindFirstChild(name)
				if leg then
					local sy = leg.Size.Y / ctx.Scale
					b:K(leg, "Punho", V(0.95, 0.75, 1.0), C(60, 62, 80), CF(0, -sy * 0.62, -0.05) * ANG(0.1, 0.3, 0))
					glow(b:K(leg, "PunhoCristal", V(0.18, 0.5, 0.18), cry, CF(0, -sy * 0.3, -0.38) * ANG(-0.5, 0, 0)))
				end
			end
		end,
	},
}

------------------------------------------------------------------------ FÊNIX DE GELO
Species.frost_phoenix = {
	Name = "Ice Phoenix",
	Rarity = "Mythic",
	Role = "Rebirth",
	Special = "C_GlacialRebirth",
	Stats = { HP = 1.4, Atk = 1.45, Speed = 19 },
	Look = {
		scale = 1.55,
		main = C(205, 238, 255),
		second = C(80, 165, 255),
		belly = C(250, 254, 255),
		eye = C(170, 240, 255),
		body = { len = 3.0, w = 1.3, h = 1.3 },
		legs = { len = 1.05, thick = 0.3, claws = C(80, 165, 255), paw = C(140, 200, 255) },
		head = { size = 1.35, snout = 1.25, snoutW = 0.55, lift = 0.65, muzzle = C(150, 210, 255), nose = C(50, 110, 200) },
		mood = "fierce",
		ears = "swept",
		earColor = C(80, 165, 255),
		earInner = C(220, 245, 255),
		tail = "fan",
		wingSize = 1.4,
		wingColors = { C(240, 250, 255), C(150, 215, 255), C(80, 160, 255) },
		extras = {
			wings = "feather",
			crest = true,
			float = 1.8,
			icicleBack = C(190, 235, 255),
			icicles = C(200, 240, 255),
			eyeGlow = true,
			aura = C(150, 220, 255),
		},
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			-- penas viram vidro de gelo
			eachPart(model, named({ "Pena", "Crista" }), function(p)
				p.Material = GLASS
				p.Transparency = 0.12
			end)
			-- coroa de gelo
			local head = model:FindFirstChild("Head1")
			if head then
				local hs = look.head.size
				for i = -2, 2 do
					local h = (0.55 - math.abs(i) * 0.1) * hs
					local sp = b:W(
						head,
						"CoroaGelo",
						V(0.06, h, 0.2) * 1,
						C(200, 245, 255),
						CF(i * 0.13 * hs, 0.4 * hs + h * 0.5, 0.05 * hs) * ANG(0, PI / 2, i * 0.25),
						Enum.Material.Ice
					)
					sp.Transparency = 0.1
				end
			end
			-- floco de neve no peito
			local cf = CF(0, -B.h * 0.05, -B.len * 0.47)
			for k = 0, 2 do
				glow(b:K(torso, "Floco", V(0.07, 0.75, 0.05), C(220, 250, 255), cf * ANG(0, 0, k * PI / 3)))
			end
			-- três plumas longas de gelo na cauda balançando
			local tail = model:FindFirstChild("TailBase")
			if tail then
				for i = -1, 1 do
					local piv = wavePivot(b, tail, "PlumaPivo", CF(i * 0.18, 0.1, 0.3) * ANG(0, PI / 2 + i * 0.35, 0.55), V(0, 0.12, 0.2), 2.5, i)
					local pts = { V(0, 0, 0), V(1.0, -0.3, 0), V(2.0, -0.35, 0), V(2.9, -0.1, 0) }
					b:Chain(piv, "Pluma", pts, { 0.13, 0.1, 0.08 }, i == 0 and look.second or C(150, 215, 255))
					local tip = b:E(piv, "PlumaPonta", V(0.7, 0.18, 0.4), C(230, 250, 255), CF(3.15, -0.05, 0), GLASS)
					glow(tip, C(200, 245, 255))
				end
			end
		end,
	},
}

------------------------------------------------------------------------ COLOSSO DO TROVÃO (gigante)
Species.thunder_colossus = {
	Name = "Thunder Colossus",
	Rarity = "Mythic",
	Role = "Colossus",
	Special = "C_ThunderWall",
	Stats = { HP = 1.75, Atk = 1.35, Speed = 14 },
	Look = {
		scale = 3.0,
		main = C(46, 52, 82),
		second = C(255, 225, 60),
		belly = C(88, 98, 142),
		eye = C(255, 250, 170),
		body = { len = 3.4, w = 2.4, h = 2.0, chest = 1.45, haunch = 0.85 },
		legs = { len = 1.3, thick = 0.6, front = 1.2, claws = C(255, 225, 60), noToes = true },
		head = { size = 1.45, snout = 0.9, snoutW = 1.2, w = 1.1, forward = 0.4, lift = 0.6, jowls = true, brows = C(255, 225, 60), neckW = 1.1 },
		mood = "fierce",
		ears = "cropped",
		earInner = C(255, 225, 60),
		tail = "bolt",
		tailSize = 1.2,
		extras = { muscles = true, bolts = C(255, 225, 60), mane = C(120, 128, 160), spiky = true, eyeGlow = true, aura = C(255, 230, 90) },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			local yellow = look.second
			-- nuvem de tempestade flutuando sobre as costas (gira devagar)
			local cloud = spinPivot(b, torso, "Nuvem", CF(0, B.h * 0.5 + 1.7, B.len * 0.05), V(0, 0.35, 0))
			local puffs = {
				{ 0, 0, 0, 1.6 },
				{ 0.9, -0.1, 0.4, 1.2 },
				{ -0.9, -0.05, 0.3, 1.25 },
				{ 0.4, 0.35, -0.6, 1.1 },
				{ -0.5, 0.3, -0.5, 1.0 },
				{ 0.2, 0.1, 1.0, 1.05 },
				{ -0.3, -0.25, -1.0, 0.95 },
			}
			for i, p in ipairs(puffs) do
				b:E(cloud, "NuvemBolo", V(p[4] * 1.3, p[4], p[4] * 1.2), i % 2 == 0 and C(150, 155, 175) or C(105, 110, 132), CF(p[1], p[2], p[3]), SMOOTH)
			end
			-- raios saindo da nuvem até as costas
			for _, x in ipairs({ -0.7, 0.6 }) do
				local pts = { V(x, -0.5, 0.1), V(x + 0.35, -0.95, 0.3), V(x - 0.1, -1.3, -0.1), V(x + 0.2, -1.75, 0.15) }
				for k = 1, #pts - 1 do
					glow(b:Seg(cloud, "RaioNuvem", pts[k], pts[k + 1], 0.07, 0.07, yellow))
				end
			end
			-- chifres para-raios
			local head = model:FindFirstChild("Head1")
			if head then
				local hs = look.head.size
				for _, side in ipairs({ -1, 1 }) do
					local a = V(side * 0.25 * hs, 0.35 * hs, 0.05 * hs)
					local t = V(side * 0.45 * hs, 1.25 * hs, 0.2 * hs)
					b:Seg(head, "ParaRaio", a, t, 0.06 * hs, 0.06 * hs, STEEL, METAL)
					for k = 1, 3 do
						local p = a:Lerp(t, k / 4)
						b:E(head, "ParaRaioAnel", V(0.16, 0.05, 0.16) * hs, C(90, 92, 105), CF(p), METAL)
					end
					glow(b:E(head, "ParaRaioPonta", V(0.2, 0.2, 0.2) * hs, yellow, CF(t)))
				end
			end
			-- braceletes de ferro com runa acesa nas patas da frente
			for _, name in ipairs({ "LegFL", "LegFR" }) do
				local leg = model:FindFirstChild(name)
				if leg then
					local s = leg.Size / ctx.Scale
					b:E(leg, "Bracelete", V(s.X * 1.15, 0.35, s.Z * 1.15), C(80, 84, 98), CF(0, -s.Y * 0.2, 0), METAL)
					glow(b:E(leg, "BraceleteRuna", V(s.X * 1.18, 0.08, s.Z * 1.18), yellow, CF(0, -s.Y * 0.2, 0)))
				end
			end
		end,
	},
}

------------------------------------------------------------------------ UNICÓRNIO ARCO-ÍRIS
Species.rainbow_unicorn = {
	Name = "Rainbow Unicorn",
	Rarity = "Mythic",
	Role = "Prism",
	Special = "C_RainbowBridge",
	Stats = { HP = 1.3, Atk = 1.5, Speed = 20 },
	Look = {
		scale = 1.5,
		main = C(255, 252, 255),
		second = C(255, 160, 220),
		belly = C(255, 246, 252),
		eye = C(110, 70, 190),
		body = { len = 3.0, w = 1.25, h = 1.35 },
		legs = { len = 1.4, thick = 0.3, paw = C(255, 205, 90), sockH = 0.3 },
		head = { size = 1.35, snout = 1.05, snoutW = 0.78, lift = 0.95, long = 1.1, eyeSize = 1.25, muzzle = C(255, 225, 240) },
		mood = "happy",
		eyes = "cute",
		ears = "pointy",
		earSize = 0.85,
		earInner = C(255, 160, 220),
		tail = "stub",
		extras = { stars = true, aura = C(255, 170, 240), trail = C(255, 200, 250) },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			local head = model:FindFirstChild("Head1")
			local hs = look.head.size
			if head then
				-- chifre espiral dourado
				local base = V(0, 0.36 * hs, -0.22 * hs)
				local tip = V(0, 1.35 * hs, -0.62 * hs)
				local n = 5
				for k = 0, n - 1 do
					local a, c = base:Lerp(tip, k / n), base:Lerp(tip, (k + 1) / n)
					local r = 0.13 * hs * (1 - k / n * 0.8)
					b:Seg(head, "Chifre", a, c, r, r, k % 2 == 0 and C(255, 225, 120) or C(255, 250, 235), Enum.Material.Foil)
				end
				glow(b:E(head, "ChifreBrilho", V(0.1, 0.1, 0.1) * hs, WHITE, CF(tip)))
			end
			-- crina arco-íris descendo pelo pescoço
			local top = neckTop(look, B, 0)
			local nb = V(0, B.h * 0.2, -B.len * 0.28)
			for i, col in ipairs(RAINBOW) do
				local u = (i - 1) / (#RAINBOW - 1)
				local root = top:Lerp(nb, u) + V(0, 0.42, 0.28)
				local piv = wavePivot(b, torso, "CrinaPivo", CF(root) * ANG(0, PI / 2, -0.4 - u * 0.5), V(0.1, 0.08, 0.1), 3.5, i * 0.6)
				b:Chain(piv, "Crina", { V(0, 0, 0), V(0.45, 0.15, 0.25), V(0.9, -0.2, 0.15) }, { 0.2, 0.14 }, col)
			end
			-- topete arco-íris na testa
			if head then
				for i = 1, 3 do
					b:Seg(
						head,
						"Topete",
						V((i - 2) * 0.12 * hs, 0.38 * hs, 0.05 * hs),
						V((i - 2) * 0.3 * hs, 0.15 * hs, -0.35 * hs),
						0.1 * hs,
						0.08 * hs,
						RAINBOW[i * 2 - 1]
					)
				end
			end
			-- cauda de 6 mechas coloridas
			local tail = model:FindFirstChild("TailBase")
			if tail then
				for i, col in ipairs(RAINBOW) do
					local x = (i - 3.5) * 0.09
					local piv = wavePivot(b, tail, "CaudaPivo", CF(x, 0.05, 0.1) * ANG(0, PI / 2, 0.2 + (i - 3.5) * 0.06), V(0, 0.2, 0.15), 3, i * 0.4)
					b:Chain(piv, "CaudaMecha", { V(0, 0, 0), V(0.7, 0.25, 0), V(1.4, -0.3, 0), V(1.9, -0.9, 0) }, { 0.13, 0.11, 0.07 }, col)
				end
			end
		end,
	},
}

------------------------------------------------------------------------ SAMURAI ONI
Species.demon_samurai = {
	Name = "Oni Samurai",
	Rarity = "Mythic",
	Role = "Blades",
	Special = "C_FlyingBlades",
	Stats = { HP = 1.35, Atk = 1.6, Speed = 18 },
	Look = {
		scale = 1.7,
		main = C(52, 22, 30),
		second = C(220, 35, 45),
		belly = C(36, 28, 36),
		eye = C(255, 225, 60),
		body = { len = 3.2, w = 1.6, h = 1.5, chest = 1.2 },
		legs = { len = 1.1, thick = 0.4, claws = GOLD, noToes = true },
		head = {
			size = 1.45,
			snout = 0.75,
			snoutW = 1.15,
			lift = 0.6,
			muzzle = C(205, 30, 40),
			jowls = true,
			fangs = true,
			brows = GOLD,
			toothColor = C(255, 245, 220),
		},
		mood = "evil",
		ears = "pointy",
		earColor = C(40, 18, 25),
		earInner = C(220, 35, 45),
		tail = "whip",
		spikeColor = C(220, 35, 45),
		extras = { helmet = C(28, 24, 30), samurai = C(30, 26, 34), smoke = C(120, 10, 20), eyeGlow = true, aura = C(255, 40, 50) },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			local red = look.second
			-- chifres de oni saindo do elmo + lua crescente dourada (maedate)
			local head = model:FindFirstChild("Head1")
			if head then
				local hs = look.head.size
				for _, side in ipairs({ -1, 1 }) do
					b:Chain(
						head,
						"ChifreOni",
						{ V(side * 0.25, 0.4, 0.0) * hs, V(side * 0.42, 0.75, 0.1) * hs, V(side * 0.38, 1.05, 0.3) * hs },
						{ 0.1 * hs, 0.06 * hs },
						C(255, 240, 210)
					)
				end
				for k = -3, 3 do
					local a = k * 0.32
					local p = V(math.sin(a) * 0.55, 0.62 + math.cos(a) * 0.45, -0.38) * hs
					b:K(head, "Maedate", V(0.2, 0.12, 0.05) * hs, GOLD, CF(p) * ANG(0, 0, -a), Enum.Material.Foil)
				end
			end
			-- quatro braços demoníacos nas costas, cada um com uma katana
			local arms = {
				{ -1, 0.35, -0.2, 0.9, -0.3 },
				{ 1, 0.35, -0.2, 0.9, -0.3 },
				{ -1, 0.15, 0.2, 0.55, 0.4 },
				{ 1, 0.15, 0.2, 0.55, 0.4 },
			}
			for i, a in ipairs(arms) do
				local side = a[1]
				local cf = CF(side * B.w * 0.35, B.h * a[2], B.len * a[3]) * ANG(a[5], 0, 0)
				local piv = wavePivot(b, torso, "BracoOniPivo", cf, V(0.1, 0.08, 0.1), 1.4, i * 1.3)
				piv:SetAttribute("CBlade", i)
				local sh, el, hand = V(0, 0, 0), V(side * 0.9, a[4], 0.1), V(side * 1.5, a[4] + 0.6, -0.4)
				b:Seg(piv, "BracoOni", sh, el, 0.17, 0.15, C(140, 20, 30))
				b:Seg(piv, "BracoOni", el, hand, 0.14, 0.12, C(140, 20, 30))
				glow(b:Seg(piv, "BracoOniVeia", sh + V(0, 0.08, 0), el + V(0, 0.08, 0), 0.04, 0.04, red))
				b:E(piv, "MaoOni", V(0.32, 0.3, 0.32), C(110, 15, 25), CF(hand))
				-- katana: cabo, tsuba e lâmina apontando para cima/para fora
				local dir = V(side * 0.35, 1, -0.45).Unit
				local hilt = CFrame.lookAt(hand, hand + dir)
				b:K(piv, "KatanaCabo", V(0.1, 0.1, 0.55), C(30, 20, 25), hilt * CF(0, 0, 0.12), Enum.Material.Fabric)
				b:K(piv, "KatanaTsuba", V(0.3, 0.3, 0.05), GOLD, hilt * CF(0, 0, -0.18), Enum.Material.Foil)
				b:K(piv, "KatanaLamina", V(0.05, 0.16, 2.0), C(220, 225, 235), hilt * CF(0, 0, -1.18), METAL)
				glow(b:K(piv, "KatanaFio", V(0.03, 0.04, 1.95), C(255, 60, 60), hilt * CF(0, -0.09, -1.18)))
			end
		end,
	},
}

------------------------------------------------------------------------ MECHA (gigante)
Species.mecha_hound = {
	Name = "Omega Mecha Dog",
	Rarity = "Mythic",
	Role = "Artillery",
	Special = "C_MissileBarrage",
	Stats = { HP = 1.7, Atk = 1.4, Speed = 14 },
	Look = {
		scale = 2.6,
		material = METAL,
		main = C(205, 210, 220),
		second = C(58, 62, 78),
		belly = C(255, 140, 30),
		eye = C(80, 230, 255),
		body = { len = 3.4, w = 2.1, h = 1.75, chest = 1.25 },
		legs = { len = 1.35, thick = 0.52, front = 1.1 },
		head = { size = 1.35, snout = 0.95, lift = 0.5, forward = 0.25 },
		mood = "fierce",
		ears = "cropped",
		earColor = C(58, 62, 78),
		earInner = C(255, 140, 30),
		tail = "antenna",
		extras = { robot = C(80, 230, 255), eyeGlow = true, aura = C(80, 230, 255), tag = false },
		build = function(b, ctx)
			local model, torso, B, look = ctx.Model, ctx.Torso, ctx.Body, ctx.Look
			model:SetAttribute("CAnim", true)
			local dark, orange, cyan = look.second, look.belly, C(80, 230, 255)
			-- casulos de mísseis nos ombros
			for _, side in ipairs({ -1, 1 }) do
				local pod = CF(side * B.w * 0.55, B.h * 0.55, -B.len * 0.2) * ANG(-0.25, 0, 0)
				b:K(torso, "CasuloMissil", V(0.9, 0.7, 1.3), dark, pod, METAL)
				b:K(torso, "CasuloFaixa", V(0.92, 0.12, 1.32), orange, pod * CF(0, 0.2, 0), SMOOTH)
				for r = 0, 1 do
					for c = -1, 1 do
						local m = pod * CF(c * 0.26, -0.1 + r * 0.28, -0.66)
						b:K(torso, "MissilTubo", V(0.22, 0.22, 0.08), C(30, 32, 40), m, METAL)
						b:E(torso, "MissilPonta", V(0.15, 0.15, 0.22), C(230, 50, 40), m * CF(0, 0, -0.06), SMOOTH)
					end
				end
			end
			-- canhão nas costas
			local can = CF(0, B.h * 0.62, B.len * 0.12)
			b:K(torso, "CanhaoBase", V(0.8, 0.45, 0.9), dark, can, METAL)
			b:K(torso, "CanhaoCano", V(0.32, 0.32, 2.4), C(150, 155, 168), can * CF(0, 0.3, -0.9), METAL)
			glow(b:K(torso, "CanhaoBoca", V(0.36, 0.36, 0.1), cyan, can * CF(0, 0.3, -2.1)))
			for k = 0, 2 do
				b:K(torso, "CanhaoAnel", V(0.42, 0.42, 0.12), dark, can * CF(0, 0.3, -0.4 - k * 0.5), METAL)
			end
			-- propulsores atrás
			for _, side in ipairs({ -1, 1 }) do
				local j = CF(side * B.w * 0.3, B.h * 0.15, B.len * 0.48)
				b:K(torso, "Propulsor", V(0.5, 0.5, 0.6), dark, j, METAL)
				glow(b:E(torso, "PropulsorFogo", V(0.36, 0.36, 0.8), cyan, j * CF(0, 0, 0.55))).Transparency = 0.2
			end
			-- reator no peito e faixas de alerta
			glow(b:E(torso, "Reator", V(0.6, 0.6, 0.2), cyan, CF(0, -B.h * 0.02, -B.len * 0.5)))
			b:K(torso, "ReatorMoldura", V(0.85, 0.85, 0.15), dark, CF(0, -B.h * 0.02, -B.len * 0.47), METAL)
			for _, side in ipairs({ -1, 1 }) do
				for k = 0, 3 do
					b:K(
						torso,
						"Alerta",
						V(0.06, 0.2, 0.32),
						k % 2 == 0 and orange or DARK,
						CF(side * B.w * 0.53, -B.h * 0.25, -B.len * 0.15 + k * 0.32) * ANG(0.6, 0, 0),
						SMOOTH
					)
				end
			end
			-- crista em V dourada na cabeça
			local head = model:FindFirstChild("Head1")
			if head then
				local hs = look.head.size
				for _, side in ipairs({ -1, 1 }) do
					b:K(
						head,
						"CristaV",
						V(0.08, 0.7, 0.06) * hs,
						GOLD,
						CF(side * 0.18 * hs, 0.55 * hs, -0.42 * hs) * ANG(0, 0, -side * 0.75),
						Enum.Material.Foil
					)
				end
				b:K(head, "CristaVBase", V(0.16, 0.16, 0.08) * hs, C(230, 50, 40), CF(0, 0.35 * hs, -0.44 * hs), SMOOTH)
			end
		end,
	},
}

------------------------------------------------------------------------ PLANETA
Species.planet_hound = {
	Name = "Planet Dog",
	Rarity = "Mythic",
	Role = "Cosmic",
	Special = "C_MoonFall",
	Stats = { HP = 1.55, Atk = 1.4, Speed = 16 },
	Look = {
		scale = 1.7,
		main = C(55, 125, 215),
		second = C(85, 180, 90),
		belly = C(55, 125, 215),
		eye = C(30, 30, 40),
		body = { len = 2.6, w = 2.6, h = 2.6 },
		legs = { len = 0.55, thick = 0.36, color = C(85, 180, 90), noToes = true },
		head = { size = 1.3, snout = 0.75, lift = -0.35, forward = 0.1, eyeSize = 1.2, cap = C(85, 180, 90), muzzle = C(235, 225, 190) },
		mood = "happy",
		eyes = "cute",
		ears = "floppy",
		earColor = C(60, 140, 70),
		tail = "curl",
		tailColor = C(85, 180, 90),
		extras = { float = 1.3, noBelly = true, stars = true, aura = C(150, 200, 255), tag = false },
		build = function(b, ctx)
			local model, torso, B = ctx.Model, ctx.Torso, ctx.Body
			model:SetAttribute("CAnim", true)
			-- continentes, desertos e calotas polares
			local land = {
				{ 0.8, -0.1, 0.9, C(85, 180, 90) },
				{ -0.9, 0.15, 1.0, C(85, 180, 90) },
				{ 1.9, 0.2, 0.8, C(200, 175, 110) },
				{ -2.0, -0.15, 0.75, C(70, 160, 80) },
				{ 2.6, -0.3, 0.6, C(85, 180, 90) },
				{ -2.7, 0.3, 0.55, C(200, 175, 110) },
				{ 0.3, 0.32, 0.6, C(70, 160, 80) },
			}
			for _, l in ipairs(land) do
				local cf = bodyPoint(B, l[1], l[2], -0.08)
				b:E(torso, "Continente", V(l[3] * 1.3, l[3], 0.3), l[4], cf, SMOOTH)
			end
			b:E(torso, "Calota", V(1.3, 0.35, 1.3), WHITE, CF(0, B.h * 0.47, 0.1), SMOOTH)
			b:E(torso, "Calota", V(1.1, 0.3, 1.1), WHITE, CF(0, -B.h * 0.47, 0.1), SMOOTH)
			for i = 1, 3 do
				local cf = bodyPoint(B, i * 1.9 - 3, -0.2 + i * 0.12, 0.05)
				b:E(torso, "Nuvem", V(1.2, 0.35, 0.15), WHITE, cf, SMOOTH).Transparency = 0.25
			end
			-- anéis de Saturno (giram devagar)
			local rings = spinPivot(b, torso, "Aneis", CF(0, 0, 0) * ANG(0.3, 0, 0.28), V(0, 0.4, 0))
			ring(b, rings, "Anel", CFrame.new(), 2.45, 26, 0.55, 0.06, C(235, 210, 160), SMOOTH)
			ring(b, rings, "Anel", CFrame.new(), 3.05, 30, 0.45, 0.05, C(205, 170, 120), SMOOTH)
			ring(b, rings, "Anel", CFrame.new(), 3.5, 32, 0.25, 0.04, C(250, 235, 200), SMOOTH)
			-- lua em órbita com crateras
			local orbit = spinPivot(b, torso, "Orbita", CF(0, 0.6, 0) * ANG(-0.2, 0, 0.15), V(0, 0.9, 0))
			local moon = CF(4.3, 0, 0)
			b:E(orbit, "Lua", V(0.95, 0.95, 0.95), C(200, 200, 210), moon, Enum.Material.Slate)
			for k = 1, 4 do
				local a = k * 1.6
				local n = V(math.cos(a), math.sin(a * 1.3) * 0.6, math.sin(a)).Unit
				b:E(orbit, "Cratera", V(0.24, 0.24, 0.08), C(150, 150, 160), moon * CFrame.lookAt(n * 0.45, n * 2), SMOOTH)
			end
			-- satélite do lado oposto
			local sat = CF(-3.9, 0.3, 0)
			b:K(orbit, "Satelite", V(0.25, 0.25, 0.35), STEEL, sat, METAL)
			b:K(orbit, "SatelitePainel", V(0.9, 0.04, 0.25), C(40, 70, 160), sat, SMOOTH)
		end,
	},
}

local Order = {
	"hydra_hound",
	"bone_dragon",
	"kraken_hound",
	"chrono_hound",
	"singularity_pup",
	"seraph_hound",
	"crystal_golem",
	"frost_phoenix",
	"thunder_colossus",
	"rainbow_unicorn",
	"demon_samurai",
	"mecha_hound",
	"planet_hound",
}

local Specials = {
	C_HydraFrenzy = {
		Name = "Hydra Frenzy",
		Desc = "All five heads stretch like snakes and bite from five sides. Every bite that lands restores HP.",
	},
	C_BoneCage = {
		Name = "Bone Cage",
		Desc = "Falls apart into a pile of bones, rebuilds under the target and a giant rib cage bursts from the ground and snaps shut on it.",
	},
	C_KrakenGrab = {
		Name = "Kraken Grab",
		Desc = "Giant tentacles burst from the ground, grab the target, lift it up and smash it down. Ends with a blast of ink.",
	},
	C_TimeStop = {
		Name = "Time Stop",
		Desc = "A giant clock appears in the sky and time stops. It strikes the frozen target from every side and everything explodes when time resumes.",
	},
	C_EventHorizon = {
		Name = "Event Horizon",
		Desc = "The pup becomes a black hole: it sucks in the target, grinds it in orbit and spits it far away through a white hole.",
	},
	C_Judgement = {
		Name = "Divine Judgement",
		Desc = "Spreads its six wings, six pillars of light surround the target, sweep to the center and become a holy column. Heals a little.",
	},
	C_CrystalPrison = {
		Name = "Crystal Prison",
		Desc = "Punches the ground and a giant crystal traps the target; the golem leaps and shatters the prison with its body.",
	},
	C_GlacialRebirth = {
		Name = "Glacial Rebirth",
		Desc = "Turns into an invulnerable ice egg and heals; the egg cracks and bursts into a freezing storm of ice feathers.",
	},
	C_ThunderWall = {
		Name = "Thunder Wall",
		Desc = "The cloud on its back zaps it; with every stomp a wall of lightning marches across the ground to the target.",
	},
	C_RainbowBridge = {
		Name = "Rainbow Bridge",
		Desc = "A rainbow forms in the sky, it gallops across it and lands horn-first on the target in a burst of color.",
	},
	C_FlyingBlades = {
		Name = "Oni Blades",
		Desc = "The four katanas fly from its demon arms, spin around the target slicing, then return for a final X slash.",
	},
	C_MissileBarrage = {
		Name = "Missile Barrage",
		Desc = "Opens its pods and fires 12 homing missiles that rise and rain down on the target; ends with a cannon blast.",
	},
	C_MoonFall = {
		Name = "Moonfall",
		Desc = "The moon leaves orbit, grows in the sky and crashes onto the target, leaving a crater; its rings become a shockwave.",
	},
}

return { Species = Species, Order = Order, Specials = Specials }
