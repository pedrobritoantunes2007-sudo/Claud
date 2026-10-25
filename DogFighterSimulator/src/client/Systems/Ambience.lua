-- Vida no ambiente (só no cliente): pássaros em bandos, gaivotas no mar, borboletas nas flores e casinhas,
-- peixes pulando, nuvens fofinhas, folhas caindo, vagalumes à noite, brilhos perto da Arena,
-- faíscas/cinzas na Boss Tower e um ciclo de dia/noite suave (só Lighting.ClockTime).
-- Tudo fica em workspace.Ambiente, com LOD por distância da câmera e limite de parts ativas.
-- Para desligar o ciclo de dia/noite: Lighting:SetAttribute("CicloDiaNoite", false).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)

local Ambience = {}

---------------------------------------------------------------- configuração
local MAX_PARTS = 140 -- limite total de parts criadas por este sistema
local DAY_SECONDS = 8 * 60 -- 06h → 18h
local NIGHT_SECONDS = 2 * 60 -- 18h → 06h
local HIDDEN = CFrame.new(0, -600, 0)

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local PASTEL = {
	Color3.fromRGB(255, 190, 210), -- rosa
	Color3.fromRGB(190, 220, 255), -- azul
	Color3.fromRGB(255, 235, 160), -- amarelo
	Color3.fromRGB(200, 190, 255), -- lilás
	Color3.fromRGB(190, 245, 210), -- menta
	Color3.fromRGB(255, 210, 170), -- pêssego
}

local rng = Random.new()
local folder: Folder
local partCount = 0

-- buffers do BulkMoveTo (uma chamada por frame)
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

---------------------------------------------------------------- utilidades
local function make(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function canAfford(n)
	return partCount + n <= MAX_PARTS
end

local function newPart(name, size, color, extra)
	partCount += 1
	local p = make("Part", {
		Name = name,
		Size = size,
		Color = color,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.SmoothPlastic,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		CFrame = HIDDEN,
	}, folder)
	if extra then
		for k, v in pairs(extra) do
			(p :: any)[k] = v
		end
	end
	return p
end

-- part invisível que só hospeda emissores (Shape = Box usa o tamanho dela)
local function hostPart(name, size, cf)
	local p = newPart(name, size, Color3.new(1, 1, 1), { Transparency = 1 })
	p.CFrame = cf
	return p
end

local function emitter(parent, props)
	local e = make("ParticleEmitter", {
		Enabled = false,
		LightInfluence = 0,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	}, parent)
	for k, v in pairs(props) do
		(e :: any)[k] = v
	end
	return e
end

local function push(part, cf)
	local n = #moveParts + 1
	moveParts[n] = part
	moveCFrames[n] = cf
end

local function flat(v: Vector3)
	return Vector3.new(v.X, 0, v.Z)
end

local function numSeq(a, b)
	return NumberSequence.new(a, b)
end

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

---------------------------------------------------------------- pontos do mapa (árvores, flores, casinhas)
local treeTops: { Vector3 } = {}
local flowerSpots: { Vector3 } = {}

local function scanMap()
	local map = workspace:FindFirstChild("Map")
	if not map then
		return
	end
	table.clear(treeTops)
	table.clear(flowerSpots)
	for _, inst in ipairs(map:GetDescendants()) do
		if inst:IsA("Model") and inst.Name == "Arvore" then
			local best
			for _, child in ipairs(inst:GetChildren()) do
				if child:IsA("BasePart") and child.Name == "Copa" and (not best or child.Position.Y > best.Position.Y) then
					best = child
				end
			end
			if best then
				table.insert(treeTops, best.Position)
			end
		elseif inst:IsA("BasePart") and inst.Name == "Flor" then
			-- flores vêm em grupinhos: guarda só um ponto por grupo
			local p = inst.Position
			local near = false
			for _, s in ipairs(flowerSpots) do
				if (s - p).Magnitude < 6 then
					near = true
					break
				end
			end
			if not near then
				table.insert(flowerSpots, p)
			end
		end
	end
	-- frente das casinhas também atrai borboletas
	for i = 1, Layout.PLOT_COUNT do
		local cf = Layout.PlotCFrame(i) * Layout.PLOT.House * CFrame.new(0, 0, -9)
		table.insert(flowerSpots, cf.Position + Vector3.new(0, 0.5, 0))
	end
end

---------------------------------------------------------------- pássaros e gaivotas
type Bird = { body: BasePart, left: BasePart, right: BasePart, phase: number, offset: Vector3, flapSpeed: number }

local function newBird(bodyColor, wingColor, scale)
	local body = newPart("Passaro", Vector3.new(0.9, 0.8, 1.8) * scale, bodyColor)
	local left = newPart("Asa", Vector3.new(2, 0.15, 1) * scale, wingColor)
	local right = newPart("Asa", Vector3.new(2, 0.15, 1) * scale, wingColor)
	return body, left, right
end

local function placeBird(bird: Bird, cf: CFrame, flap: number, scale: number)
	push(bird.body, cf)
	push(bird.left, cf * CFrame.new(-0.4 * scale, 0.15 * scale, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-1 * scale, 0, 0))
	push(bird.right, cf * CFrame.new(0.4 * scale, 0.15 * scale, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(1 * scale, 0, 0))
end

local flocks = {}

local function makeFlock(center: Vector3, radius: number, speed: number, count: number)
	if not canAfford(count * 3) then
		return
	end
	local flock = { center = center, radius = radius, speed = speed, angle = rng:NextNumber(0, math.pi * 2), birds = {} }
	local color = pick(PASTEL)
	for i = 1, count do
		-- formação em V (para trás = +Z local)
		local side = (i % 2 == 0) and 1 or -1
		local rank = math.floor(i / 2)
		local body, left, right = newBird(Color3.new(1, 0.97, 0.94), color, 1)
		table.insert(flock.birds, {
			body = body,
			left = left,
			right = right,
			phase = rng:NextNumber(0, math.pi * 2),
			offset = Vector3.new(side * rank * 3, rng:NextNumber(-0.6, 0.6), rank * 3),
			flapSpeed = rng:NextNumber(9, 11),
		})
	end
	table.insert(flocks, flock)
end

local function flockPosition(flock, angle)
	local c = flock.center
	return c + Vector3.new(math.cos(angle) * flock.radius, math.sin(angle * 2) * 5, math.sin(angle) * flock.radius * 0.75)
end

local function updateFlock(flock, dt, t)
	flock.angle += flock.speed * dt
	local p = flockPosition(flock, flock.angle)
	local ahead = flockPosition(flock, flock.angle + 0.02 * math.sign(flock.speed))
	local bank = -math.sign(flock.speed) * 0.25
	local base = CFrame.lookAt(p, ahead) * CFrame.Angles(0, 0, bank)
	for _, bird in ipairs(flock.birds) do
		local bob = math.sin(t * 1.5 + bird.phase) * 0.4
		local cf = base * CFrame.new(bird.offset + Vector3.new(0, bob, 0))
		placeBird(bird, cf, math.sin(t * bird.flapSpeed + bird.phase) * 0.7, 1)
	end
end

local gulls = {}

local function makeGull()
	if not canAfford(3) then
		return
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(Layout.ISLAND_RADIUS + 40, Layout.ISLAND_RADIUS + 120)
	local body, left, right = newBird(Color3.fromRGB(250, 250, 255), Color3.fromRGB(200, 210, 225), 1.3)
	table.insert(gulls, {
		body = body,
		left = left,
		right = right,
		phase = rng:NextNumber(0, math.pi * 2),
		offset = Vector3.zero,
		flapSpeed = 6,
		center = Vector3.new(math.cos(a) * r, rng:NextNumber(20, 34), math.sin(a) * r),
		radius = rng:NextNumber(18, 36),
		speed = rng:NextNumber(0.25, 0.4) * (rng:NextNumber() < 0.5 and -1 or 1),
		angle = rng:NextNumber(0, math.pi * 2),
	})
end

local function gullPos(g, angle)
	return g.center + Vector3.new(math.cos(angle) * g.radius, math.sin(angle * 3) * 2, math.sin(angle) * g.radius)
end

local function updateGull(g, dt, t)
	g.angle += g.speed * dt
	local p = gullPos(g, g.angle)
	local ahead = gullPos(g, g.angle + 0.02 * math.sign(g.speed))
	local cf = CFrame.lookAt(p, ahead) * CFrame.Angles(0, 0, -math.sign(g.speed) * 0.35)
	-- gaivota plana a maior parte do tempo e bate as asas de vez em quando
	local burst = math.max(0, math.sin(t * 0.7 + g.phase))
	local flap = 0.12 + math.sin(t * g.flapSpeed + g.phase) * 0.55 * burst
	placeBird(g, cf, flap, 1.3)
end

---------------------------------------------------------------- borboletas
local butterflies = {}
local BUTTERFLY_RANGE = 140

local function makeButterfly()
	if not canAfford(2) then
		return
	end
	local color = pick(PASTEL)
	local wing = Vector3.new(0.8, 0.05, 0.7)
	table.insert(butterflies, {
		left = newPart("Borboleta", wing, color, { Material = Enum.Material.Neon, Transparency = 0.1 }),
		right = newPart("Borboleta", wing, color, { Material = Enum.Material.Neon, Transparency = 0.1 }),
		home = nil :: Vector3?,
		phase = rng:NextNumber(0, 100),
		speed = rng:NextNumber(0.5, 0.9),
		hidden = false,
	})
end

local function reassignButterflies(camPos: Vector3)
	local nearby = {}
	for _, s in ipairs(flowerSpots) do
		if (flat(s) - flat(camPos)).Magnitude < BUTTERFLY_RANGE and math.abs(s.Y - camPos.Y) < 80 then
			table.insert(nearby, s)
		end
	end
	for _, b in ipairs(butterflies) do
		if not b.home or (flat(b.home) - flat(camPos)).Magnitude > BUTTERFLY_RANGE or math.abs(b.home.Y - camPos.Y) > 80 then
			b.home = (#nearby > 0) and pick(nearby) or nil
		end
	end
end

local function butterflyPos(b, t)
	local s = t * b.speed + b.phase
	local home = b.home :: Vector3
	return home + Vector3.new(math.sin(s) * 3.5 + math.sin(s * 2.3) * 1.2, 2 + math.sin(s * 1.7) * 1 + math.sin(s * 5) * 0.3, math.cos(s * 0.8) * 3.5)
end

local function updateButterfly(b, t)
	if not b.home then
		if not b.hidden then
			push(b.left, HIDDEN)
			push(b.right, HIDDEN)
			b.hidden = true
		end
		return
	end
	b.hidden = false
	local p = butterflyPos(b, t)
	local ahead = butterflyPos(b, t + 0.05)
	local dir = ahead - p
	local cf = if dir.Magnitude > 1e-3 then CFrame.lookAt(p, p + Vector3.new(dir.X, 0, dir.Z) + Vector3.new(0, 0, 1e-3)) else CFrame.new(p)
	local flap = 0.2 + math.abs(math.sin(t * 18 + b.phase)) * 1.1
	push(b.left, cf * CFrame.Angles(0, 0, flap) * CFrame.new(-0.4, 0, 0))
	push(b.right, cf * CFrame.Angles(0, 0, -flap) * CFrame.new(0.4, 0, 0))
end

---------------------------------------------------------------- folhas caindo
local leaves = {}
local LEAF_RANGE = 110
local LEAF_COLORS = {
	Color3.fromRGB(150, 215, 120),
	Color3.fromRGB(190, 225, 110),
	Color3.fromRGB(255, 200, 120),
	Color3.fromRGB(240, 170, 130),
}

local function makeLeaf()
	if not canAfford(1) then
		return
	end
	table.insert(leaves, {
		part = newPart("Folha", Vector3.new(0.6, 0.06, 0.9), pick(LEAF_COLORS)),
		pos = nil :: Vector3?,
		wait = rng:NextNumber(0, 4),
		spin = rng:NextNumber(0, math.pi * 2),
		phase = rng:NextNumber(0, 10),
		hidden = false,
	})
end

local function respawnLeaf(leaf, camPos)
	local options = {}
	for _, top in ipairs(treeTops) do
		if (flat(top) - flat(camPos)).Magnitude < LEAF_RANGE then
			table.insert(options, top)
		end
	end
	if #options == 0 then
		leaf.pos = nil
		return
	end
	local top = pick(options)
	leaf.pos = top + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-3, -1), rng:NextNumber(-3, 3))
	leaf.spin = rng:NextNumber(0, math.pi * 2)
end

local function updateLeaf(leaf, dt, t, camPos)
	if not leaf.pos then
		leaf.wait -= dt
		if leaf.wait <= 0 then
			leaf.wait = rng:NextNumber(1, 4)
			respawnLeaf(leaf, camPos)
		end
		if not leaf.pos then
			if not leaf.hidden then
				push(leaf.part, HIDDEN)
				leaf.hidden = true
			end
			return
		end
	end
	leaf.hidden = false
	local pos = leaf.pos :: Vector3
	if pos.Y <= Layout.GROUND_Y + 0.1 then
		-- descansa no chão um pouquinho e some
		leaf.wait -= dt
		if leaf.wait <= -3 then
			leaf.pos = nil
			leaf.wait = rng:NextNumber(0.5, 3)
		end
		return
	end
	local sway = math.sin(t * 2 + leaf.phase)
	pos += Vector3.new(sway * 1.6 * dt + 0.4 * dt, -2.2 * dt, math.cos(t * 1.3 + leaf.phase) * 0.8 * dt)
	if pos.Y < Layout.GROUND_Y + 0.1 then
		pos = Vector3.new(pos.X, Layout.GROUND_Y + 0.08, pos.Z)
		leaf.wait = 0
		push(leaf.part, CFrame.new(pos) * CFrame.Angles(0, leaf.spin, 0))
	else
		leaf.spin += dt * 1.5
		push(leaf.part, CFrame.new(pos) * CFrame.Angles(sway * 0.6, leaf.spin, math.cos(t * 2 + leaf.phase) * 0.5))
	end
	leaf.pos = pos
end

---------------------------------------------------------------- peixes pulando
local fishes = {}
local splashHost: BasePart
local splashEmitter: ParticleEmitter
local FISH_COLORS = { Color3.fromRGB(255, 180, 130), Color3.fromRGB(150, 210, 255), Color3.fromRGB(255, 170, 200) }

local function makeFish()
	if not canAfford(1) then
		return
	end
	table.insert(fishes, {
		part = newPart("Peixe", Vector3.new(0.5, 0.8, 1.6), pick(FISH_COLORS)),
		t = 0,
		duration = 1,
		from = Vector3.zero,
		to = Vector3.zero,
		wait = rng:NextNumber(1, 6),
		height = 4,
		jumping = false,
	})
end

local function waterSpotNear(camPos: Vector3): Vector3?
	local camAngle = math.atan2(camPos.Z, camPos.X)
	for _ = 1, 8 do
		local a = camAngle + rng:NextNumber(-0.7, 0.7)
		local r = rng:NextNumber(Layout.ISLAND_RADIUS + 28, Layout.ISLAND_RADIUS + 110)
		local p = Vector3.new(math.cos(a) * r, Layout.WATER_LEVEL, math.sin(a) * r)
		local ok = (flat(p) - flat(camPos)).Magnitude < 220
		for _, isletAngle in ipairs(Layout.ISLET_ANGLES) do
			if (Layout.IsletCenter(isletAngle) - flat(p)).Magnitude < Layout.ISLET_RADIUS + 12 then
				ok = false
			end
		end
		local boss = flat(Layout.BOSS_CENTER)
		if (boss - flat(p)).Magnitude < 55 or (math.abs(p.X) < 14 and p.Z < 0 and p.Z > boss.Z) then
			ok = false -- longe da torre e da ponte
		end
		if ok then
			return p
		end
	end
	return nil
end

local function splash(pos: Vector3)
	splashHost.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0))
	splashEmitter:Emit(10)
end

local function updateFish(fish, dt, camPos)
	if not fish.jumping then
		fish.wait -= dt
		if fish.wait > 0 then
			return
		end
		local spot = waterSpotNear(camPos)
		if not spot then
			fish.wait = 3
			return
		end
		local dir = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.xAxis
		fish.from = spot
		fish.to = spot + dir * rng:NextNumber(5, 8)
		fish.t = 0
		fish.duration = rng:NextNumber(0.9, 1.3)
		fish.height = rng:NextNumber(3.5, 6)
		fish.jumping = true
		splash(fish.from)
	end
	fish.t += dt
	local a = math.clamp(fish.t / fish.duration, 0, 1)
	local function at(x)
		return fish.from:Lerp(fish.to, x) + Vector3.new(0, math.sin(x * math.pi) * fish.height, 0)
	end
	if a >= 1 then
		splash(fish.to)
		fish.jumping = false
		fish.wait = rng:NextNumber(2, 7)
		push(fish.part, HIDDEN)
		return
	end
	local p = at(a)
	local ahead = at(math.min(a + 0.03, 1))
	if (ahead - p).Magnitude < 1e-3 then
		ahead = p + (fish.to - fish.from)
	end
	push(fish.part, CFrame.lookAt(p, ahead) * CFrame.Angles(0, 0, math.sin(fish.t * 20) * 0.3))
end

---------------------------------------------------------------- nuvens
local clouds = {}
local CLOUD_SPAN = 650

local function cloudZ()
	-- evita a faixa da Boss Tower para não cobrir a arena do boss
	local z
	repeat
		z = rng:NextNumber(-560, 520)
	until z > Layout.BOSS_CENTER.Z + 110 or z < Layout.BOSS_CENTER.Z - 110
	return z
end

local function makeCloud()
	if not canAfford(3) then
		return
	end
	local cloud = {
		parts = {},
		offsets = {},
		pos = Vector3.new(rng:NextNumber(-CLOUD_SPAN, CLOUD_SPAN), rng:NextNumber(105, 140), cloudZ()),
		speed = rng:NextNumber(2, 4.5),
	}
	local base = rng:NextNumber(18, 28)
	local tint = rng:NextNumber() < 0.3 and Color3.fromRGB(255, 240, 248) or Color3.fromRGB(255, 255, 255)
	for i = 1, 3 do
		local d = base * (i == 2 and 1.25 or rng:NextNumber(0.7, 0.9))
		table.insert(cloud.parts, newPart("Nuvem", Vector3.new(d, d * 0.75, d), tint, { Shape = Enum.PartType.Ball, Transparency = 0.12 }))
		table.insert(cloud.offsets, Vector3.new((i - 2) * base * 0.7, (i == 2) and base * 0.18 or 0, rng:NextNumber(-3, 3)))
	end
	table.insert(clouds, cloud)
end

local function updateCloud(cloud, dt)
	cloud.pos += Vector3.new(cloud.speed * dt, 0, 0)
	if cloud.pos.X > CLOUD_SPAN then
		cloud.pos = Vector3.new(-CLOUD_SPAN, rng:NextNumber(105, 140), cloudZ())
	end
	for i, p in ipairs(cloud.parts) do
		push(p, CFrame.new(cloud.pos + cloud.offsets[i]))
	end
end

---------------------------------------------------------------- emissores fixos (Arena, Boss Tower, vagalumes)
local zones = {}

local function makeZone(name, size, cf, range, emitters)
	if not canAfford(1) then
		return nil
	end
	local host = hostPart(name, size, cf)
	local list = {}
	for _, props in ipairs(emitters) do
		table.insert(list, emitter(host, props))
	end
	local zone = { host = host, emitters = list, range = range, on = false }
	table.insert(zones, zone)
	return zone
end

local function setZone(zone, on)
	if zone.on ~= on then
		zone.on = on
		for _, e in ipairs(zone.emitters) do
			e.Enabled = on
		end
	end
end

---------------------------------------------------------------- dia e noite
local clock = 14
local lastSet = -1

local function isNight(c)
	return c >= 18.6 or c < 5.4
end

local function updateClock(dt)
	if Lighting:GetAttribute("CicloDiaNoite") == false then
		lastSet = -1
		return
	end
	-- se alguém (servidor) mudou o horário, segue dali
	if lastSet >= 0 and math.abs(Lighting.ClockTime - lastSet) > 0.05 then
		clock = Lighting.ClockTime
	end
	local day = clock >= 6 and clock < 18
	local rate = 12 / (day and DAY_SECONDS or NIGHT_SECONDS)
	clock = (clock + rate * dt) % 24
	lastSet = clock
	Lighting.ClockTime = clock
end

---------------------------------------------------------------- montagem
local function build()
	folder = make("Folder", { Name = "Ambiente" }, workspace)

	-- emissores (≈ 6 parts)
	local arenaY = Layout.GROUND_Y + 9
	makeZone(
		"BrilhoArena",
		Vector3.new(Layout.ARENA_RADIUS * 2, 16, Layout.ARENA_RADIUS * 2),
		CFrame.new(Layout.ARENA_CENTER + Vector3.new(0, arenaY, 0)),
		260,
		{
			{
				Texture = SPARKLE,
				Rate = 18,
				Lifetime = NumberRange.new(3, 5),
				Speed = NumberRange.new(0.3, 1),
				SpreadAngle = Vector2.new(180, 180),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.5), NumberSequenceKeypoint.new(1, 0) }),
				Color = ColorSequence.new(Color3.fromRGB(255, 245, 200), Color3.fromRGB(255, 210, 240)),
				LightEmission = 0.8,
				Transparency = numSeq(0.2, 1),
				Acceleration = Vector3.new(0, 0.4, 0),
			},
			{
				Texture = SMOKE,
				Rate = 5,
				Lifetime = NumberRange.new(5, 8),
				Speed = NumberRange.new(0.5, 1.2),
				SpreadAngle = Vector2.new(180, 20),
				Size = numSeq(3, 6),
				Color = ColorSequence.new(Color3.fromRGB(245, 230, 205)),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.85), NumberSequenceKeypoint.new(1, 1) }),
				RotSpeed = NumberRange.new(-15, 15),
				Rotation = NumberRange.new(0, 360),
			},
		}
	)

	local C = Layout.BOSS_CENTER
	local bossBase = Vector3.new(C.X, 0, C.Z)
	local embers = {
		Texture = SPARKLE,
		Rate = 14,
		Lifetime = NumberRange.new(2.5, 4.5),
		Speed = NumberRange.new(3, 7),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(25, 25),
		Size = numSeq(0.6, 0),
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 110), Color3.fromRGB(255, 110, 70)),
		LightEmission = 1,
		Acceleration = Vector3.new(0, 2, 0),
		Drag = 0.4,
	}
	local ash = {
		Texture = SMOKE,
		Rate = 4,
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(2, 4),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(30, 30),
		Size = numSeq(2, 6),
		Color = ColorSequence.new(Color3.fromRGB(120, 105, 120)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) }),
		RotSpeed = NumberRange.new(-20, 20),
		Rotation = NumberRange.new(0, 360),
	}
	-- 🏰 (2026-10) sem a Boss Tower (Config.BOSS_TOWER = false) não tem cinza nem faísca no rochedo do norte
	if Config.BOSS_TOWER then
		makeZone("CinzasTorre", Vector3.new(56, C.Y, 56), CFrame.new(bossBase + Vector3.new(0, C.Y / 2, 0)), 420, { embers, ash })
		makeZone("FaiscasTopo", Vector3.new(Layout.BOSS_RADIUS * 2, 2, Layout.BOSS_RADIUS * 2), CFrame.new(C + Vector3.new(0, 1, 0)), 300, {
			embers,
			{
				Texture = FIRE,
				Rate = 5,
				Lifetime = NumberRange.new(1, 2),
				Speed = NumberRange.new(1, 3),
				EmissionDirection = Enum.NormalId.Top,
				Size = numSeq(1.2, 0),
				Color = ColorSequence.new(Color3.fromRGB(255, 150, 80)),
				LightEmission = 0.9,
				Transparency = numSeq(0.4, 1),
			},
		})
	end

	local fieldSize = Layout.ARENA_RADIUS * 0.87 -- (vaga-lumes sobre o chão da arena, que cresceu em 2026-10)
	local fireflies = makeZone("Vagalumes", Vector3.new(fieldSize, 7, fieldSize), CFrame.new(0, Layout.GROUND_Y + 4.5, 0), math.huge, {
		{
			Texture = SPARKLE,
			Rate = 22,
			Lifetime = NumberRange.new(4, 7),
			Speed = NumberRange.new(0.3, 1),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.2, 0.45),
				NumberSequenceKeypoint.new(0.5, 0.25),
				NumberSequenceKeypoint.new(0.8, 0.45),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Color = ColorSequence.new(Color3.fromRGB(230, 255, 140), Color3.fromRGB(180, 255, 170)),
			LightEmission = 1,
			Brightness = 2,
			Acceleration = Vector3.new(0, 0.15, 0),
			RotSpeed = NumberRange.new(-30, 30),
		},
	})

	splashHost = hostPart("Respingo", Vector3.new(1.5, 0.2, 1.5), HIDDEN)
	splashEmitter = emitter(splashHost, {
		Texture = SPARKLE,
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(5, 9),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(35, 35),
		Size = numSeq(0.8, 0.1),
		Color = ColorSequence.new(Color3.fromRGB(220, 245, 255)),
		Transparency = numSeq(0.1, 1),
		Acceleration = Vector3.new(0, -30, 0),
		LightEmission = 0.4,
	})

	-- seres animados (cada pássaro = 3 parts)
	makeFlock(Vector3.new(0, 58, 0), Layout.PLOT_RADIUS + 15, 0.07, 5)
	local k = Layout.ARENA_RADIUS / 150 -- (bandos em volta do Coliseu, que cresceu)
	makeFlock(Vector3.new(110 * k, 46, 95 * k), 85 * k, -0.12, 4)
	makeFlock(Vector3.new(-130 * k, 66, -50 * k), 105 * k, 0.1, 5)
	for _ = 1, 5 do
		makeGull()
	end
	for _ = 1, 10 do
		makeButterfly()
	end
	for _ = 1, 9 do
		makeLeaf()
	end
	for _ = 1, 4 do
		makeFish()
	end
	for _ = 1, 9 do
		makeCloud()
	end
	return fireflies
end

---------------------------------------------------------------- loop
function Ambience.Start(_HUD)
	if workspace:FindFirstChild("Ambiente") then
		return
	end
	workspace:WaitForChild("Map", 60)
	local fireflies = build()
	scanMap()

	local t = 0
	local rescanTimer = 0
	local assignTimer = 0
	local slowTimer = 0
	local clockTimer = 0

	RunService.Heartbeat:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		t += dt
		local camPos = camera.CFrame.Position
		table.clear(moveParts)
		table.clear(moveCFrames)

		-- relógio (10x por segundo é suave o bastante)
		clockTimer += dt
		if clockTimer >= 0.1 then
			updateClock(clockTimer)
			clockTimer = 0
		end
		local night = isNight(Lighting.ClockTime)

		-- reconhece o mapa de vez em quando (pode ter sido reconstruído)
		rescanTimer += dt
		if rescanTimer > 30 then
			rescanTimer = 0
			scanMap()
		end
		assignTimer -= dt
		if assignTimer <= 0 then
			assignTimer = 2
			if not isNight(Lighting.ClockTime) then
				reassignButterflies(camPos)
			end
		end

		-- pássaros: perto = todo frame; longe = congelados
		for _, flock in ipairs(flocks) do
			local p = flockPosition(flock, flock.angle)
			if (p - camPos).Magnitude < 420 then
				updateFlock(flock, dt, t)
			else
				flock.angle += flock.speed * dt
			end
		end
		for _, g in ipairs(gulls) do
			if (g.center - camPos).Magnitude < 320 then
				updateGull(g, dt, t)
			else
				g.angle += g.speed * dt
			end
		end
		-- borboletas dormem à noite
		for _, b in ipairs(butterflies) do
			if night and b.home then
				b.home = nil
			end
			updateButterfly(b, t)
		end
		local nearGround = camPos.Y < 80 and flat(camPos).Magnitude < Layout.ISLAND_RADIUS + 140
		for _, leaf in ipairs(leaves) do
			if nearGround or leaf.pos then
				updateLeaf(leaf, dt, t, camPos)
			end
		end
		for _, fish in ipairs(fishes) do
			if nearGround or fish.jumping then
				updateFish(fish, dt, camPos)
			end
		end
		-- nuvens são lentas: 10 atualizações por segundo bastam
		slowTimer += dt
		if slowTimer >= 0.1 then
			for _, cloud in ipairs(clouds) do
				updateCloud(cloud, slowTimer)
			end
			slowTimer = 0
		end

		-- zonas de partículas com LOD
		for _, zone in ipairs(zones) do
			if zone ~= fireflies then
				setZone(zone, (zone.host.Position - camPos).Magnitude < zone.range)
			end
		end
		if fireflies then
			local onIsland = flat(camPos).Magnitude < Layout.ISLAND_RADIUS + 20 and camPos.Y < 60
			setZone(fireflies, night and onIsland)
			if fireflies.on then
				local fp = fireflies.host.Position
				local target = Vector3.new(camPos.X, Layout.GROUND_Y + 4.5, camPos.Z)
				if (flat(fp) - flat(target)).Magnitude > 20 then
					push(fireflies.host, CFrame.new(target))
				end
			end
		end

		if #moveParts > 0 then
			workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return Ambience
