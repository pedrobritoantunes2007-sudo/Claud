-- 🏟️ Cenário de cada chefe no topo da Boss Tower (pedido do dono: "lugares diferentes para os bosses").
-- Quando a luta começa, BossArenas.Build(bossId) cobre o topo com o chão do tema + enfeites em volta
-- (espinhos de gelo, pedras de lava, cristais, pilares...) e partículas no ar; Clear() tira tudo no fim.
-- Só peças decorativas (sem colisão, sem sombra): não atrapalham a luta.
-- 🧱 2026-10: estilo "bloquinhos" (pedido do dono): tudo bloco, SmoothPlastic (Neon só no que brilha), chão em
-- fileiras de blocos de 2 tons e camadas bem separadas (antes eram discos redondos a 0,06 stud — piscavam).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)

local BossArenas = {}

local C = Color3.fromRGB
local M = Enum.Material

-- Floor = chão; Prop = tipo de enfeite; PropColor/PropMat; Air = cor das partículas; Ring = cor do anel
local THEMES = {
	Storm = { Floor = C(60, 62, 80), FloorMat = M.Slate, Prop = "crystal", PropColor = C(255, 230, 80), PropMat = M.Neon, Air = C(255, 240, 120), Ring = C(255, 220, 60) },
	Ice = { Floor = C(235, 245, 255), FloorMat = M.Snow, Prop = "spike", PropColor = C(150, 220, 255), PropMat = M.Ice, Air = C(255, 255, 255), Ring = C(140, 210, 255) },
	Moon = { Floor = C(45, 50, 45), FloorMat = M.Grass, Prop = "pillar", PropColor = C(90, 90, 110), PropMat = M.Cobblestone, Air = C(200, 200, 255), Ring = C(180, 180, 255) },
	Lava = { Floor = C(50, 30, 25), FloorMat = M.Basalt, Prop = "rock", PropColor = C(255, 100, 30), PropMat = M.CrackedLava, Air = C(255, 140, 40), Ring = C(255, 80, 20) },
	Ocean = { Floor = C(40, 110, 170), FloorMat = M.Glass, Prop = "coral", PropColor = C(255, 120, 160), PropMat = M.SmoothPlastic, Air = C(170, 230, 255), Ring = C(60, 180, 255) },
	Void = { Floor = C(20, 10, 35), FloorMat = M.Slate, Prop = "crystal", PropColor = C(170, 60, 255), PropMat = M.Neon, Air = C(160, 80, 255), Ring = C(140, 40, 255) },
	Arcane = { Floor = C(235, 230, 250), FloorMat = M.Marble, Prop = "pillar", PropColor = C(255, 215, 90), PropMat = M.Marble, Air = C(255, 245, 190), Ring = C(255, 215, 90) },
	Hell = { Floor = C(30, 15, 20), FloorMat = M.Basalt, Prop = "spike", PropColor = C(120, 20, 40), PropMat = M.Rock, Air = C(255, 60, 60), Ring = C(200, 20, 40) },
	Cosmos = { Floor = C(10, 10, 30), FloorMat = M.Glass, Prop = "crystal", PropColor = C(120, 200, 255), PropMat = M.Neon, Air = C(255, 255, 255), Ring = C(255, 255, 255) },
}
local BY_BOSS = {
	thunder_king = "Storm",
	frost_titan = "Ice",
	werewolf_alpha = "Moon",
	volcanic_cerberus = "Lava",
	kraken_lord = "Ocean",
	yeti_king = "Ice",
	dragon_emperor = "Lava",
	void_titan = "Void",
	archmage = "Arcane",
	shadow_cerberus = "Hell",
	phoenix_god = "Lava",
	cosmic_overlord = "Cosmos",
}

local folder = nil

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	-- sem textura: só Neon (o que brilha) fica; o resto vira plástico liso
	if p.Material ~= M.Neon then
		p.Material = M.SmoothPlastic
	end
	p.Parent = folder
	return p
end

local function shade(c: Color3, k: number)
	return c:Lerp(k < 0 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1), math.abs(k))
end

-- disco "de blocos": fileiras de `step` studs cortadas no círculo (r0 = buraco no meio), topo em `top`
local function voxelDisc(center: Vector3, r: number, r0: number, top: number, thick: number, color: Color3, mat, step: number, twoTone: boolean)
	local n = math.floor(r / step)
	for k = -n, n - 1 do
		local z = (k + 0.5) * step
		local hw = math.floor(math.sqrt(math.max(0, r * r - z * z)) / step) * step
		if hw > 0 then
			local col = twoTone and (k % 2 == 0 and color or shade(color, 0.12)) or color
			local inner = r0 > math.abs(z) and math.floor(math.sqrt(r0 * r0 - z * z) / step) * step or 0
			if inner <= 0 then
				part({ Size = Vector3.new(hw * 2, thick, step), CFrame = CFrame.new(center + Vector3.new(0, top - thick / 2, z)), Color = col, Material = mat })
			elseif hw > inner then
				for _, sx in ipairs({ -1, 1 }) do
					local w = hw - inner
					part({ Size = Vector3.new(w, thick, step), CFrame = CFrame.new(center + Vector3.new(sx * (inner + w / 2), top - thick / 2, z)), Color = col, Material = mat })
				end
			end
		end
	end
end

-- altura real do chão do topo da torre
local function floorY()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace:FindFirstChild("Map") or workspace }
	local hit = workspace:Raycast(Layout.BOSS_CENTER + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	return hit and hit.Position.Y or Layout.BOSS_CENTER.Y
end

local function prop(kind, pos, t, rng)
	local s = rng:NextNumber(0.8, 1.5)
	if kind == "spike" then
		local h = 9 * s
		part({ Size = Vector3.new(2.4 * s, h, 2.4 * s), CFrame = CFrame.new(pos + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 6), rng:NextNumber(-0.25, 0.25)), Color = t.PropColor, Material = t.PropMat, Transparency = t.PropMat == M.Ice and 0.15 or 0 })
		part({ Size = Vector3.new(1.4 * s, h * 0.6, 1.4 * s), CFrame = CFrame.new(pos + Vector3.new(1.6 * s, h * 0.3 - 0.5, 0.8)) * CFrame.Angles(0.3, 0, -0.35), Color = t.PropColor, Material = t.PropMat })
	elseif kind == "crystal" then
		local h = 7 * s
		local c = part({ Size = Vector3.new(2 * s, h, 2 * s), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0.2) * CFrame.Angles(0, 0.78, 0), Color = t.PropColor, Material = t.PropMat, Transparency = 0.1 })
		local light = Instance.new("PointLight")
		light.Color = t.PropColor
		light.Range = 14
		light.Brightness = 1
		light.Parent = c
	elseif kind == "pillar" then
		local h = 16 * s
		-- coluna quadrada: base em degrau, fuste, faixas mais escuras, capitel e cubo que brilha
		part({ Size = Vector3.new(4.4, 1, 4.4), CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)), Color = shade(t.PropColor, -0.25), Material = t.PropMat })
		part({ Size = Vector3.new(3, h, 3), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)), Color = t.PropColor, Material = t.PropMat })
		for _, fy in ipairs({ h * 0.3, h * 0.65 }) do
			part({ Size = Vector3.new(3.3, 0.6, 3.3), CFrame = CFrame.new(pos + Vector3.new(0, fy, 0)), Color = shade(t.PropColor, -0.18), Material = t.PropMat })
		end
		part({ Size = Vector3.new(4.2, 1, 4.2), CFrame = CFrame.new(pos + Vector3.new(0, h + 0.5, 0)), Color = shade(t.PropColor, 0.15), Material = t.PropMat })
		part({ Size = Vector3.one * 2, CFrame = CFrame.new(pos + Vector3.new(0, h + 2, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = t.Ring, Material = M.Neon })
	elseif kind == "rock" then
		-- pedra de blocos empilhados (escura embaixo, mais clara em cima) + rachadura de lava e poça de lava
		local r = part({ Size = Vector3.new(6, 2.6, 5) * s, CFrame = CFrame.new(pos + Vector3.new(0, 1.3 * s, 0)), Color = C(45, 35, 35), Material = M.SmoothPlastic })
		part({ Size = Vector3.new(4.2, 1.8, 3.6) * s, CFrame = CFrame.new(pos + Vector3.new(0.4 * s, 3.4 * s, -0.2 * s)), Color = C(62, 50, 50), Material = M.SmoothPlastic })
		part({ Size = Vector3.new(2.2, 1.2, 2) * s, CFrame = CFrame.new(pos + Vector3.new(-0.3 * s, 4.8 * s, 0.3 * s)), Color = C(80, 66, 64), Material = M.SmoothPlastic })
		part({ Size = Vector3.new(0.4, 2, 2.6) * s, CFrame = CFrame.new(pos + Vector3.new(3.05 * s, 1.4 * s, 0)), Color = t.PropColor, Material = M.Neon })
		part({ Size = Vector3.new(4.5 * s, 0.3, 4.5 * s), CFrame = CFrame.new(pos + Vector3.new(4.5 * s, 0.55, 2)), Color = t.PropColor, Material = M.Neon })
		local fire = Instance.new("Fire")
		fire.Heat = 6
		fire.Size = 5
		fire.Color = t.PropColor
		fire.Parent = r
	elseif kind == "coral" then
		-- coral de galhos quadrados em escadinha (cada galho sobe, vira para o lado e sobe de novo)
		for i = 1, 3 do
			local h = rng:NextNumber(3, 5) * s
			local x, z = i - 2, rng:NextNumber(-1, 1)
			local dir = rng:NextNumber() < 0.5 and 1 or -1
			local col = i == 2 and shade(t.PropColor, 0.15) or t.PropColor
			part({ Size = Vector3.new(1, h, 1), CFrame = CFrame.new(pos + Vector3.new(x, h / 2, z)), Color = col, Material = t.PropMat })
			part({ Size = Vector3.new(2, 1, 1), CFrame = CFrame.new(pos + Vector3.new(x + dir * 0.5, h - 0.5, z)), Color = col, Material = t.PropMat })
			part({ Size = Vector3.new(1, h * 0.6, 1), CFrame = CFrame.new(pos + Vector3.new(x + dir, h + h * 0.3 - 1, z)), Color = col, Material = t.PropMat })
			part({ Size = Vector3.new(1.3, 1.3, 1.3), CFrame = CFrame.new(pos + Vector3.new(x + dir, h + h * 0.6 - 0.6, z)), Color = shade(col, 0.25), Material = t.PropMat })
		end
	end
end

function BossArenas.Clear()
	if folder then
		folder:Destroy()
		folder = nil
	end
end

function BossArenas.Build(bossId)
	BossArenas.Clear()
	local t = THEMES[BY_BOSS[bossId] or "Void"]
	folder = Instance.new("Folder")
	folder.Name = "BossArena"
	folder.Parent = workspace
	local y = floorY()
	local R = Layout.BOSS_RADIUS
	local center = Vector3.new(Layout.BOSS_CENTER.X, y, Layout.BOSS_CENTER.Z)
	-- chão do tema em fileiras de blocos (2 tons) — topo 0,4 acima do chão da torre: nada de piscar
	voxelDisc(center, R - 2, 0, 0.4, 0.5, t.Floor, t.FloorMat, 4, true)
	-- anel que brilha (blocos em volta de um círculo) e o miolo de outro tom, os dois 0,25 acima do chão
	voxelDisc(center, R * 0.6, R * 0.52, 0.65, 0.3, t.Ring, M.Neon, 2, false)
	voxelDisc(center, R * 0.52, 0, 0.65, 0.3, shade(t.Floor, 0.1), t.FloorMat, 4, true)
	-- enfeites em dois anéis
	local rng = Random.new(#bossId * 97)
	for ring = 1, 2 do
		local count = ring == 1 and 14 or 10
		local rad = ring == 1 and R - 8 or R * 0.6
		for i = 1, count do
			local a = (i + ring * 0.5) / count * math.pi * 2
			prop(t.Prop, center + Vector3.new(math.cos(a), 0, math.sin(a)) * (rad + rng:NextNumber(-3, 3)), t, rng)
		end
	end
	-- partículas no ar (neve, brasas, faíscas, estrelas)
	local sky = part({ Size = Vector3.new(R * 2, 1, R * 2), CFrame = CFrame.new(center + Vector3.new(0, 40, 0)), Transparency = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = 60
	e.Lifetime = NumberRange.new(4, 6)
	e.Speed = NumberRange.new(4, 8)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(20, 20)
	e.LightEmission = 0.8
	e.Color = ColorSequence.new(t.Air)
	e.Size = NumberSequence.new(0.6, 0.2)
	e.Parent = sky
end

return BossArenas
