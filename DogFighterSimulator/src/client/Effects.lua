-- Efeitos visuais de combate e poderes (rodam só no cliente). O servidor manda Remotes.Effect(nome, params).
--
-- Linguagem visual única para todos os poderes:
--   AVISO   → círculo que enche no chão, brilho/carga no corpo, rugido (o jogador entende o que vem)
--   IMPACTO → flash, anel de choque segmentado, faíscas, luz, tremor proporcional ao tamanho
--   RESÍDUO → marca no chão, brasas, gelo, fumaça, que somem devagar
-- Só texturas nativas (rbxasset://textures/particles/...). Nada de IDs externos.
--
-- Desempenho: tudo vai para workspace.FX (ou para attachments no Terrain) com Debris; peças, luzes,
-- textos e destaques têm limite; a quantidade de partículas segue a qualidade gráfica do jogador
-- (atributo "GraphicsQuality" do LocalPlayer: Alto / Médio / Baixo). Uma única conexão de quadro anima
-- tudo (lista `anims`), em vez de um loop por efeito.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Animator = require(script.Parent.Animator)

local Effects = {}

local TEX = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Spark = "rbxasset://textures/particles/fire_sparks_main.dds",
	Glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	Swirl = "rbxasset://textures/particles/forcefield_vortex_main.dds",
}

local C = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)

local player = Players.LocalPlayer
local folder = Instance.new("Folder")
folder.Name = "FX"
folder.Parent = workspace

---------------------------------------------------------------- qualidade e limites
local QUALITY = { Alto = 1, ["Médio"] = 0.6, Baixo = 0.3 }
local function quality(): number
	return QUALITY[player:GetAttribute("GraphicsQuality")] or 1
end
-- quantidade escalada pela qualidade (nunca zero)
local function q(n: number): number
	return math.max(1, math.floor(n * quality() + 0.5))
end

local MAX_PARTS = 550
local partCount = 0
folder.ChildAdded:Connect(function()
	partCount += 1
end)
folder.ChildRemoved:Connect(function()
	partCount -= 1
end)
-- true quando já há peças demais: efeitos decorativos (resíduos, detritos) são pulados
local function crowded(extra: number?): boolean
	return partCount + (extra or 0) > MAX_PARTS * (0.35 + 0.65 * quality())
end

local lightCount = 0
local highlightCount = 0
local textCount = 0

---------------------------------------------------------------- utilidades
local function NS(...)
	local a = { ... }
	local kps = {}
	for i = 1, #a, 2 do
		table.insert(kps, NumberSequenceKeypoint.new(a[i], a[i + 1]))
	end
	return NumberSequence.new(kps)
end

local function CS(...)
	local a = { ... }
	local kps = {}
	for i = 1, #a, 2 do
		table.insert(kps, ColorSequenceKeypoint.new(a[i], a[i + 1]))
	end
	return ColorSequence.new(kps)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rnd(a: number, b: number): number
	return a + math.random() * (b - a)
end

local function outCubic(k: number): number
	return 1 - (1 - k) ^ 3
end

local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = folder
	return p
end

local function tween(inst, time, goal, style, direction)
	local tw = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

-- Animação central: fn(k, t) recebe o progresso 0..1 e o tempo; retornar true encerra antes.
local anims = {}
local function animate(duration: number, fn, done)
	table.insert(anims, { Start = os.clock(), Dur = math.max(duration, 0.001), Fn = fn, Done = done })
end
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for i = #anims, 1, -1 do
		local a = anims[i]
		local k = math.clamp((now - a.Start) / a.Dur, 0, 1)
		local ok, stop = pcall(a.Fn, k, now - a.Start)
		if not ok then
			warn("[Effects] anim", stop)
		end
		if k >= 1 or stop == true or not ok then
			anims[i] = anims[#anims]
			anims[#anims] = nil
			if a.Done then
				local okDone, err = pcall(a.Done)
				if not okDone then
					warn("[Effects] anim fim", err)
				end
			end
		end
	end
end)

-- Ponto fixo no mundo (attachment no Terrain: não conta como peça)
local function anchor(position: Vector3, life: number)
	local a = Instance.new("Attachment")
	a.Position = position
	a.Parent = workspace.Terrain
	Debris:AddItem(a, life)
	return a
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX.Sparkle
	e.LightEmission = 0.8
	e.Enabled = false
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = parent
	return e
end

-- Rajada de partículas num ponto. extra = propriedades extras do ParticleEmitter.
local function burst(position: Vector3, color: any, count: number, size: number, speed: number, texture: string?, extra: { [string]: any }?)
	local a = anchor(position, 3)
	local sequence: any = color
	if typeof(color) == "Color3" then
		sequence = ColorSequence.new(color :: Color3)
	end
	local props = {
		Texture = texture or TEX.Sparkle,
		Color = sequence,
		Size = NS(0, size, 1, 0),
		Transparency = NS(0, 0, 0.7, 0.3, 1, 1),
		Lifetime = NumberRange.new(0.35, 0.8),
		Speed = NumberRange.new(speed * 0.4, speed),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-120, 120),
	}
	if extra then
		for k, v in pairs(extra) do
			props[k] = v
		end
	end
	local e = emitter(a, props)
	e:Emit(q(count))
	return e
end

-- Poeira/fumaça que se espalha rente ao chão
local function dust(position: Vector3, color: Color3, count: number, size: number, speed: number)
	burst(position + Vector3.new(0, 0.4, 0), color, count, size, speed, TEX.Smoke, {
		Size = NS(0, size * 0.5, 1, size * 1.6),
		Transparency = NS(0, 0.35, 1, 1),
		Lifetime = NumberRange.new(0.7, 1.3),
		SpreadAngle = Vector2.new(10, 180),
		EmissionDirection = Enum.NormalId.Right,
		Drag = 3,
		LightEmission = 0,
		Acceleration = Vector3.new(0, 2, 0),
	})
end

local function light(position: Vector3, color: Color3, range: number, duration: number, brightness: number?)
	if lightCount >= math.floor(4 + 8 * quality()) then
		return
	end
	lightCount += 1
	local a = anchor(position, duration + 0.1)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = math.min(range, 60)
	l.Brightness = brightness or 4
	l.Shadows = false
	l.Parent = a
	tween(l, duration, { Brightness = 0 })
	task.delay(duration, function()
		lightCount -= 1
	end)
end

local function disc(position: Vector3, radius: number, color: Color3, transparency: number?, material: Enum.Material?)
	return fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, radius * 2, radius * 2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = transparency or 0.3,
		Material = material or Enum.Material.Neon,
	})
end

local function setDiscRadius(part: BasePart, radius: number, thickness: number?)
	part.Size = Vector3.new(thickness or part.Size.X, radius * 2, radius * 2)
end

-- Bola de luz que cresce e some (o "flash" do impacto)
local function flashBall(position: Vector3, radius: number, color: Color3, duration: number?)
	local d = duration or 0.25
	local ball = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * radius * 0.4, CFrame = CFrame.new(position), Color = color, Transparency = 0 })
	animate(d, function(k)
		local e = outCubic(k)
		ball.Size = Vector3.one * radius * (0.4 + 1.6 * e)
		ball.Transparency = k ^ 0.6
	end, function()
		ball:Destroy()
	end)
	return ball
end

-- Anel segmentado (parece um anel de verdade, não um disco). cf: plano XZ do anel; eixo = cf.UpVector.
local function ringParts(n: number, color: Color3, material: Enum.Material?)
	local list = {}
	for _ = 1, n do
		table.insert(list, fxPart({ Size = Vector3.new(0.3, 0.3, 1), Color = color, Material = material or Enum.Material.Neon }))
	end
	return list
end

local function placeRing(list, cf: CFrame, radius: number, thick: number, height: number, spin: number, transparency: number)
	local n = #list
	local arc = 2 * math.pi * radius / n * 1.12
	for i, p in ipairs(list) do
		local a = i / n * math.pi * 2 + spin
		p.Size = Vector3.new(thick, height, math.max(0.05, arc))
		p.CFrame = cf * CFrame.Angles(0, a, 0) * CFrame.new(radius, height / 2, 0)
		p.Transparency = transparency
	end
end

-- Onda de choque: anel que expande e afina
local function ringWave(cf: CFrame, r0: number, r1: number, color: Color3, duration: number, opts: { [string]: any }?)
	local o = opts or {}
	local n = math.max(10, math.floor((o.Segs or (r1 > 14 and 26 or 18)) * (0.5 + 0.5 * quality())))
	local list = ringParts(n, color, o.Material)
	local thick = o.Thick or math.max(0.5, r1 * 0.08)
	local height = o.Height or 0.35
	local base = o.Transparency or 0.05
	local rise = o.Rise or 0
	animate(duration, function(k)
		local e = outCubic(k)
		placeRing(list, cf * CFrame.new(0, rise * e, 0), r0 + (r1 - r0) * e, thick * (1 - 0.75 * k), height * (1 - 0.5 * k), 0, base + (1 - base) * k ^ 1.3)
	end, function()
		for _, p in ipairs(list) do
			p:Destroy()
		end
	end)
end

local function groundRing(position: Vector3, r0: number, r1: number, color: Color3, duration: number, opts: { [string]: any }?)
	ringWave(CFrame.new(position + Vector3.new(0, 0.1, 0)), r0, r1, color, duration, opts)
end

-- Raio quebrado (miolo branco + brilho colorido)
local function bolt(from: Vector3, to: Vector3, color: Color3, duration: number, width: number, jag: number?)
	local segments = math.max(3, math.floor(7 * (0.5 + 0.5 * quality())))
	local last = from
	local length = (to - from).Magnitude
	for i = 1, segments do
		local k = i / segments
		local point = from:Lerp(to, k)
		if i < segments then
			point += Vector3.new(rnd(-0.5, 0.5), rnd(-0.5, 0.5), rnd(-0.5, 0.5)) * length * (jag or 0.13)
		end
		local len = (point - last).Magnitude
		local cf = CFrame.lookAt(last, point) * CFrame.new(0, 0, -len / 2)
		local glow = fxPart({ Size = Vector3.new(width, width, len + width * 0.5), CFrame = cf, Color = color, Transparency = 0.35 })
		local core = fxPart({ Size = Vector3.new(width * 0.35, width * 0.35, len + width * 0.2), CFrame = cf, Color = WHITE, Transparency = 0 })
		animate(duration, function(kk)
			glow.Transparency = 0.35 + 0.65 * kk
			core.Transparency = kk ^ 0.7
		end, function()
			glow:Destroy()
			core:Destroy()
		end)
		last = point
	end
end
Effects.Bolt = bolt

-- Lasca/cristal pontudo que brota do chão
local function spike(position: Vector3, width: number, height: number, color: Color3, material: Enum.Material, transparency: number, lean: number?)
	local cf = CFrame.new(position)
		* CFrame.Angles(0, math.random() * math.pi * 2, 0)
		* CFrame.Angles(rnd(-1, 1) * (lean or 0.25), 0, rnd(-1, 1) * (lean or 0.25))
	local p = fxPart({
		Shape = Enum.PartType.CornerWedge,
		Size = Vector3.new(width, 0.2, width),
		CFrame = cf,
		Color = color,
		Material = material,
		Transparency = transparency,
	})
	animate(0.16, function(k)
		local e = 1 - (1 - k) ^ 2 * (1 - 2.2 * k) -- passa um pouco do ponto (back)
		local h = math.max(0.2, height * math.min(e, 1.12))
		p.Size = Vector3.new(width, h, width)
		p.CFrame = cf * CFrame.new(0, h / 2 - 0.3, 0)
	end)
	return p
end

-- Fragmentos voando em arco (sem física: trajetória calculada)
local function shards(position: Vector3, color: Color3, count: number, speed: number, size: number, material: Enum.Material?)
	if crowded(count) then
		return
	end
	for _ = 1, q(count) do
		local s = size * rnd(0.6, 1.2)
		local p = fxPart({
			Size = Vector3.new(s, s * rnd(0.6, 1.4), s),
			Color = color,
			Material = material or Enum.Material.Slate,
			CFrame = CFrame.new(position),
		})
		local v = Vector3.new(rnd(-1, 1), rnd(0.8, 1.6), rnd(-1, 1)).Unit * speed * rnd(0.6, 1)
		local spin = Vector3.new(rnd(-8, 8), rnd(-8, 8), rnd(-8, 8))
		local floorY = position.Y - 0.5
		animate(rnd(0.7, 1.0), function(k, t)
			local pos = position + v * t + Vector3.new(0, -45 * t * t, 0)
			if pos.Y < floorY then
				pos = Vector3.new(pos.X, floorY, pos.Z)
			end
			p.CFrame = CFrame.new(pos) * CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t)
			if k > 0.6 then
				p.Transparency = (k - 0.6) / 0.4
			end
		end, function()
			p:Destroy()
		end)
	end
end

-- Rachaduras saindo de um ponto (resíduo)
local function cracks(position: Vector3, radius: number, color: Color3, count: number, duration: number, glow: boolean?)
	if crowded(count) then
		return
	end
	for _ = 1, q(count) do
		local a = math.random() * math.pi * 2
		local len = radius * rnd(0.5, 1)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local start = position + dir * radius * 0.15 + Vector3.new(0, 0.06, 0)
		local p = fxPart({
			Size = Vector3.new(rnd(0.25, 0.5), 0.08, 0.1),
			Color = color,
			Material = glow and Enum.Material.Neon or Enum.Material.Slate,
			Transparency = 0.1,
			CFrame = CFrame.lookAt(start, start + dir),
		})
		animate(0.18, function(k)
			local l = len * outCubic(k)
			p.Size = Vector3.new(p.Size.X, 0.08, math.max(0.1, l))
			p.CFrame = CFrame.lookAt(start, start + dir) * CFrame.new(0, 0, -l / 2)
		end)
		task.delay(duration, function()
			if p.Parent then
				tween(p, 0.8, { Transparency = 1 })
			end
		end)
		Debris:AddItem(p, duration + 0.9)
	end
end

-- Marca escura no chão que some devagar (resíduo)
local function scorch(position: Vector3, radius: number, color: Color3?, duration: number?)
	if crowded(1) then
		return
	end
	local d = disc(position + Vector3.new(0, 0.02, 0), radius, color or C(25, 20, 20), 0.35, Enum.Material.SmoothPlastic)
	task.delay(duration or 2.5, function()
		if d.Parent then
			tween(d, 1, { Transparency = 1 })
		end
	end)
	Debris:AddItem(d, (duration or 2.5) + 1.1)
	return d
end

-- Fogo contínuo num ponto (attachment ou parte)
local function fireEmitter(parent: Instance, rate: number, size: number, colorTop: Color3?)
	return emitter(parent, {
		Texture = TEX.Fire,
		Enabled = true,
		Rate = rate * quality(),
		LightEmission = 1,
		Color = CS(0, C(255, 245, 180), 0.35, colorTop or C(255, 140, 40), 1, C(120, 30, 10)),
		Size = NS(0, size, 0.5, size * 0.8, 1, size * 0.15),
		Transparency = NS(0, 0.3, 0.2, 0.05, 1, 1),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(3, 7),
		Acceleration = Vector3.new(0, 7, 0),
		SpreadAngle = Vector2.new(18, 18),
		EmissionDirection = Enum.NormalId.Top,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
	})
end

local function embers(parent: Instance, rate: number, color: Color3?)
	return emitter(parent, {
		Texture = TEX.Spark,
		Enabled = true,
		Rate = rate * quality(),
		LightEmission = 1,
		Color = ColorSequence.new(color or C(255, 170, 60)),
		Size = NS(0, 0.35, 1, 0),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(2, 6),
		Acceleration = Vector3.new(0, 4, 0),
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Top,
	})
end

local function headOf(model, index)
	return model and (model:FindFirstChild("Head" .. (index or 1)) or model:FindFirstChild("Head1"))
end

local function rootOf(model)
	return model and model.Parent and model.PrimaryPart
end

local function feetOf(model): Vector3?
	local root = rootOf(model)
	if not root then
		return nil
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local hip = hum and hum.HipHeight or (model:GetAttribute("HipHeight") or 2)
	return root.Position - Vector3.new(0, root.Size.Y / 2 + hip, 0)
end

-- Boca da cabeça (frente do focinho)
local function mouthOf(head: BasePart): CFrame
	return head.CFrame * CFrame.new(0, -head.Size.Y * 0.15, -head.Size.Z * 0.75)
end

local function partsNamed(model, test)
	local list = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and test(d.Name) then
			table.insert(list, d)
		end
	end
	return list
end

---------------------------------------------------------------- câmera (tremor por "trauma")
local trauma = 0
function Effects.Shake(amount: number, _duration: number?)
	trauma = math.min(1.1, trauma + amount)
end
local lastShake = os.clock()
RunService:BindToRenderStep("DogShake", Enum.RenderPriority.Camera.Value + 1, function()
	local now = os.clock()
	local dt = now - lastShake
	lastShake = now
	if trauma > 0.002 then
		local cam = workspace.CurrentCamera
		local s = trauma * trauma
		local t = now * 24
		local rx = math.noise(t, 1.7) * s * 2.2
		local ry = math.noise(t, 9.3) * s * 2.2
		local rz = math.noise(t, 17.1) * s * 1.4
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
		trauma = math.max(0, trauma - dt * 1.5)
	end
end)

-- tremor com queda pela distância da câmera
local function shakeAt(position: Vector3, intensity: number, radius: number, duration: number?)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local dist = (cam.CFrame.Position - position).Magnitude
	local reach = radius * 1.5
	if dist < reach then
		local falloff = math.clamp(1 - dist / reach, 0.15, 1)
		Effects.Shake(intensity * falloff * math.clamp(0.45 + (duration or 0.3) * 0.6, 0.5, 1.15))
	end
end

---------------------------------------------------------------- handlers
local H = {}

-- Mordida comum: o Animator abre a boca + um "chomp" branco rápido na frente do focinho
-- dentes fechando na frente da boca (mordida)
local function biteFlash(p)
	local head = headOf(p.Model, p.Head)
	if not head or crowded(2) then
		return
	end
	task.delay(0.08, function()
		if not head.Parent then
			return
		end
		local m = mouthOf(head) * CFrame.new(0, 0, -head.Size.Z * 0.5)
		local w = head.Size.X * 1.1
		local color = p.Color or C(255, 255, 255)
		local top = fxPart({ Size = Vector3.new(w, 0.12, 0.25), Color = color, Transparency = 0.1 })
		local bottom = fxPart({ Size = Vector3.new(w, 0.12, 0.25), Color = color, Transparency = 0.1 })
		local gap = head.Size.Y * 0.7
		animate(0.16, function(k)
			local g = gap * (1 - outCubic(k))
			top.CFrame = m * CFrame.new(0, g, 0) * CFrame.Angles(0.5 * (1 - k), 0, 0)
			bottom.CFrame = m * CFrame.new(0, -g, 0) * CFrame.Angles(-0.5 * (1 - k), 0, 0)
			top.Transparency = 0.1 + 0.9 * k ^ 2
			bottom.Transparency = top.Transparency
		end, function()
			top:Destroy()
			bottom:Destroy()
		end)
	end)
end

function H.Bite(p)
	Animator.PlayBite(p.Model, p.Head)
	biteFlash(p)
end

-- 🐾 patada: três riscos brancos de unha cruzando na frente do cachorro, do lado da pata (side 1 = direita)
local function clawSlash(model, side)
	local root = rootOf(model)
	if not root or crowded(3) then
		return
	end
	task.delay(0.1, function()
		if not root.Parent then
			return
		end
		local size = root.Size
		local cf = root.CFrame * CFrame.new(side * size.X * 0.15, size.Y * 0.1, -size.Z * 0.75)
		local len = math.max(size.X, size.Y) * 1.1
		local parts = {}
		for i = -1, 1 do
			table.insert(parts, { fxPart({ Size = Vector3.new(0.12, len, 0.12), Color = C(255, 255, 255), Transparency = 0.15 }), i })
		end
		animate(0.22, function(k)
			for _, e in ipairs(parts) do
				local part, i = e[1], e[2]
				-- risco na diagonal (de cima-fora para baixo-dentro) que corre junto com a pata
				part.CFrame = cf * CFrame.Angles(0, 0, side * 0.7) * CFrame.new(i * len * 0.18, (0.5 - k) * len * 0.4, 0)
				part.Size = Vector3.new(0.12 * (1 - k * 0.5), len * (0.6 + 0.4 * outCubic(k)), 0.12)
				part.Transparency = 0.15 + 0.85 * k ^ 2
			end
		end, function()
			for _, e in ipairs(parts) do
				e[1]:Destroy()
			end
		end)
	end)
end

-- 🐾 golpe de perto do combo: 1 = pata direita, 2 = pata esquerda, 3 = mordida forte. O servidor manda para
-- todos (H.Melee); o próprio jogador já toca na hora do clique (Abilities, isLocal) e o aviso dele é ignorado.
function Effects.Melee(model, step, head, isLocal)
	if not (model and Animator.PlayMelee(model, step, isLocal)) then
		return
	end
	if step == 3 then
		biteFlash({ Model = model, Head = head })
	else
		clawSlash(model, step == 1 and 1 or -1)
	end
end

function H.Melee(p)
	Effects.Melee(p.Model, p.Step, p.Head, false)
end

---------------------------------------------------------------- 🎯 tiro pela boca (atiradores)
-- O servidor manda o estilo (DogData.SHOT_STYLES), o alvo e o tempo de voo. O tiro sai da boca, persegue
-- o alvo (chega junto com o dano do servidor) e explode no estilo dele. Rajadas (Count) e arco (Arc).
local RAINBOW_SHOT = { C(255, 70, 80), C(255, 160, 50), C(255, 230, 70), C(90, 220, 110), C(80, 170, 255), C(170, 100, 255) }

local function shotTrail(part: BasePart, style, size: number)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, size * 0.3, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -size * 0.3, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = CS(0, style.Color2 or WHITE, 1, style.Color)
	trail.Transparency = NS(0, 0.15, 1, 1)
	trail.Lifetime = 0.18
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = part
	local kind = style.Trail
	if kind == "Fire" then
		fireEmitter(a0, 40, size * 1.2, style.Color)
	elseif kind == "Smoke" then
		emitter(a0, {
			Texture = TEX.Smoke,
			Enabled = true,
			Rate = 30 * quality(),
			LightEmission = 0.2,
			Color = ColorSequence.new(style.Color),
			Size = NS(0, size * 0.6, 1, size * 1.4),
			Transparency = NS(0, 0.4, 1, 1),
			Lifetime = NumberRange.new(0.3, 0.6),
			Speed = NumberRange.new(0.5, 2),
			SpreadAngle = Vector2.new(180, 180),
		})
	elseif kind == "Sparkle" then
		emitter(a0, {
			Enabled = true,
			Rate = 40 * quality(),
			Color = ColorSequence.new(style.Color2 or WHITE),
			Size = NS(0, size * 0.5, 1, 0),
			Lifetime = NumberRange.new(0.25, 0.5),
			Speed = NumberRange.new(1, 4),
			SpreadAngle = Vector2.new(180, 180),
		})
	elseif kind == "Swirl" then
		emitter(a0, {
			Texture = TEX.Swirl,
			Enabled = true,
			Rate = 18 * quality(),
			Color = ColorSequence.new(style.Color2 or style.Color),
			Size = NS(0, size * 1.2, 1, size * 0.2),
			Transparency = NS(0, 0.3, 1, 1),
			Lifetime = NumberRange.new(0.3, 0.5),
			Speed = NumberRange.new(0, 1),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-300, 300),
		})
	end
end

-- peças do projétil: lista de { peça, deslocamento } (a 1ª leva o rastro)
local function shotBody(style, size: number)
	local parts = {}
	if style.Shape == "Shard" then
		local p = fxPart({ Size = Vector3.new(size * 0.45, size * 0.45, size * 1.6), Color = style.Color, Transparency = 0.3 })
		table.insert(parts, { p, CFrame.Angles(0, 0, math.rad(45)) })
		local core = fxPart({ Size = Vector3.new(size * 0.2, size * 0.2, size * 1.2), Color = style.Color2 or WHITE })
		table.insert(parts, { core, CFrame.Angles(0, 0, math.rad(45)) })
	elseif style.Shape == "Bone" then
		local plastic = Enum.Material.SmoothPlastic
		table.insert(parts, { fxPart({ Size = Vector3.new(size * 0.35, size * 0.35, size * 1.4), Color = style.Color, Material = plastic }), CFrame.new() })
		for _, z in ipairs({ -0.7, 0.7 }) do
			for _, x in ipairs({ -0.18, 0.18 }) do
				local knob = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.45, Color = style.Color, Material = plastic })
				table.insert(parts, { knob, CFrame.new(x * size, 0, z * size) })
			end
		end
	else
		local bubble = style.Bubble == true
		local outer = fxPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			Color = style.Color,
			Material = bubble and Enum.Material.Glass or Enum.Material.Neon,
			Transparency = bubble and 0.4 or 0.3,
		})
		table.insert(parts, { outer, CFrame.new() })
		local core = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.55, Color = style.Color2 or WHITE, Transparency = bubble and 0.5 or 0 })
		table.insert(parts, { core, CFrame.new() })
	end
	return parts
end

local function shotImpact(position: Vector3, style, size: number, big: boolean, targetModel)
	local color = style.Color
	local color2 = style.Color2 or WHITE
	flashBall(position, 2 * size, color, 0.2)
	light(position, color, big and 20 or 12, 0.3)
	burst(position, color, big and 20 or 10, 0.9 * size, 16)
	local kind = style.Impact
	if kind == "Explode" then
		burst(position, CS(0, C(255, 240, 180), 0.4, color2, 1, color), big and 18 or 10, 1.4 * size, 14, TEX.Fire, { LightEmission = 1 })
		dust(position, C(90, 80, 70), big and 8 or 4, 2, 10)
		ringWave(CFrame.new(position), 0.5, (big and 7 or 4) * size, color2, 0.35)
		shakeAt(position, big and 0.35 or 0.15, 25, 0.15)
	elseif kind == "Shatter" then
		shards(position, color, big and 7 or 4, 16, 0.35 * size, style.Shape == "Bone" and Enum.Material.SmoothPlastic or Enum.Material.Ice)
	elseif kind == "Splash" then
		burst(position, color, big and 14 or 8, 1.2 * size, 10, TEX.Smoke, { LightEmission = 0.3 })
		local feet = feetOf(targetModel)
		if feet and not crowded(2) then
			local puddle = disc(feet, (big and 3.5 or 2.2) * size, color, 0.25)
			animate(1.6, function(k)
				puddle.Transparency = 0.25 + 0.75 * k ^ 2
			end, function()
				puddle:Destroy()
			end)
		end
	elseif kind == "Pop" then
		local seq = {}
		for i, c in ipairs(RAINBOW_SHOT) do
			table.insert(seq, ColorSequenceKeypoint.new((i - 1) / (#RAINBOW_SHOT - 1), c))
		end
		burst(position, ColorSequence.new(seq), big and 26 or 16, 0.6, 22, nil, { Shape = Enum.ParticleEmitterShape.Sphere })
		ringWave(CFrame.new(position), 0.3, 3 * size, WHITE, 0.25)
	end
end

function H.MouthShot(p)
	local style = DogData.SHOT_STYLES[p.Style]
	if not style or not p.Model then
		return
	end
	Animator.PlayBite(p.Model, p.Head)
	local head = headOf(p.Model, p.Head)
	local root = rootOf(p.Model)
	local from = (head and head.Parent and mouthOf(head).Position) or (root and root.Position)
	if not from then
		return
	end
	local targetRoot = rootOf(p.Target)
	local lastGoal: Vector3 = p.To or from
	local function goal(): Vector3
		if targetRoot and targetRoot.Parent then
			lastGoal = targetRoot.Position
		end
		return lastGoal
	end
	local big = p.Big == true
	local size = (style.Size or 1) * (big and 1.7 or 1)
	local travel = math.max(0.05, p.Time or 0.2)
	-- brilho na boca ao soltar
	flashBall(from, 1.1 * size, style.Color, 0.15)

	-- instantâneos: laser reto e raio
	if style.Shape == "Beam" or style.Shape == "Bolt" then
		local to = goal()
		if style.Shape == "Bolt" then
			bolt(from, to, style.Color, 0.25, 0.45 * size)
		else
			local len = (to - from).Magnitude
			local cf = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2)
			local w = 0.6 * size
			local glow = fxPart({ Size = Vector3.new(w, w, len), CFrame = cf, Color = style.Color, Transparency = 0.3 })
			local core = fxPart({ Size = Vector3.new(w * 0.35, w * 0.35, len), CFrame = cf, Color = style.Color2 or WHITE, Transparency = 0 })
			animate(0.25, function(k, t)
				if style.Rainbow then
					glow.Color = RAINBOW_SHOT[math.floor(t * 30) % #RAINBOW_SHOT + 1]
				end
				local thin = 1 - 0.7 * k
				glow.Size = Vector3.new(w * thin, w * thin, len)
				glow.Transparency = 0.3 + 0.7 * k
				core.Transparency = k ^ 0.7
			end, function()
				glow:Destroy()
				core:Destroy()
			end)
		end
		shotImpact(to, style, size, big, p.Target)
		return
	end

	local count = style.Count or 1
	for i = 1, count do
		task.delay((i - 1) * 0.07, function()
			local start = from
			local spread = count > 1 and rnd(-1.6, 1.6) or 0
			if crowded(6) then
				-- peças demais na tela: só a explosão no fim
				task.delay(travel, function()
					shotImpact(goal(), style, size, big, p.Target)
				end)
				return
			end
			local parts
			if style.Shape == "Wave" then
				parts = {}
				for _, part in ipairs(ringParts(12, style.Color)) do
					table.insert(parts, { part, CFrame.new() })
				end
			else
				parts = shotBody(style, size)
				shotTrail(parts[1][1], style, size)
			end
			local dir = (goal() - start).Unit
			animate(travel, function(k, t)
				local g = goal()
				local side = Vector3.new(-dir.Z, 0, dir.X)
				local pos = start:Lerp(g, k) + Vector3.new(0, (style.Arc or 0) * 4 * k * (1 - k), 0) + side * spread * math.sin(k * math.pi)
				local delta = g - pos
				if delta.Magnitude > 0.2 then
					dir = delta.Unit
				end
				local base = CFrame.lookAt(pos, pos + dir)
				if style.Shape == "Wave" then
					-- onda de som: anel que cresce enquanto voa
					local list = {}
					for _, entry in ipairs(parts) do
						table.insert(list, entry[1])
					end
					placeRing(list, base * CFrame.Angles(math.rad(90), 0, 0), (0.6 + 1.6 * k) * size, 0.25, 0.3, t * 4, 0.1 + 0.5 * k)
					return
				end
				local spin = style.Shape == "Bone" and CFrame.Angles(t * 14, 0, 0) or CFrame.Angles(0, 0, t * 10)
				for _, entry in ipairs(parts) do
					entry[1].CFrame = base * spin * entry[2]
				end
			end, function()
				for _, entry in ipairs(parts) do
					entry[1]:Destroy()
				end
				if i == 1 then
					shotImpact(goal(), style, size, big, p.Target)
				else
					burst(goal(), style.Color, 6, 0.7 * size, 12)
				end
			end)
		end)
	end
end

-- Flash branco no corpo de quem apanhou + faísca
function H.Hit(p)
	local model = p.Model
	local root = rootOf(model)
	if not root then
		return
	end
	if highlightCount < 6 then
		highlightCount += 1
		local hl = Instance.new("Highlight")
		hl.Name = "HitFlash"
		hl.FillColor = WHITE
		hl.FillTransparency = 0.15
		hl.OutlineColor = WHITE
		hl.OutlineTransparency = 0.4
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = model
		tween(hl, 0.2, { FillTransparency = 1, OutlineTransparency = 1 })
		task.delay(0.22, function()
			highlightCount -= 1
			hl:Destroy()
		end)
	end
	burst(root.Position + Vector3.new(0, root.Size.Y * 0.3, 0), C(255, 250, 220), 6, 0.6, 22, TEX.Spark, { Lifetime = NumberRange.new(0.12, 0.3), Drag = 6 })
	-- tremor leve quando o cachorro é meu
	if model:GetAttribute("Owner") == player.UserId then
		Effects.Shake(0.12)
	end
end

local function floatingLabel(position: Vector3, life: number, size: Vector2)
	local a = anchor(position, life + 0.1)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size.X, size.Y)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Parent = a
	return a, gui
end

local function styledText(parent: Instance, text: string, color: Color3, strokeColor: Color3, font: Enum.Font?)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = WHITE
	label.TextScaled = true
	label.Font = font or Enum.Font.LuckiestGuy
	label.Parent = parent
	local gradient = Instance.new("UIGradient")
	gradient.Color = CS(0, WHITE:Lerp(color, 0.25), 0.55, color, 1, color:Lerp(Color3.new(0, 0, 0), 0.25))
	gradient.Rotation = 90
	gradient.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor
	stroke.Thickness = 2.5
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = label
	return label, stroke, scale
end

local function floatingText(position: Vector3, text: string, color: Color3, size: number, rise: number?, font: Enum.Font?)
	if textCount > 30 then
		return
	end
	textCount += 1
	local life = 1.1
	local start = position + Vector3.new(rnd(-1, 1), 0, rnd(-1, 1))
	local a, gui = floatingLabel(start, life, Vector2.new(size * 5, size))
	local label, stroke, scale = styledText(gui, text, color, Color3.fromRGB(30, 20, 30), font)
	animate(life, function(k)
		a.Position = start + Vector3.new(0, (rise or 4) * outCubic(k), 0)
		scale.Scale = k < 0.15 and 0.2 + (k / 0.15) * 1 or 1.2 - math.min(1, (k - 0.15) / 0.15) * 0.2
		local fade = math.clamp((k - 0.6) / 0.4, 0, 1)
		label.TextTransparency = fade
		stroke.Transparency = fade
	end, function()
		textCount -= 1
	end)
end

-- Número de dano: pula, sai em arco para o lado, gradiente + contorno; crítico grande e tremendo
function H.Damage(p)
	if textCount > 30 then
		return
	end
	textCount += 1
	local crit = p.Crit == true
	local text = type(p.Amount) == "string" and p.Amount or nil -- ex.: "MISS" (esquiva)
	local amount = type(p.Amount) == "number" and p.Amount or 0
	local color = p.Color or (crit and C(255, 190, 40) or WHITE)
	local size = crit and 64 or math.clamp(28 + math.log10(amount + 1) * 5, 28, 48)
	local life = crit and 1.3 or 0.95
	local side = (math.random() < 0.5 and -1 or 1) * rnd(1.2, 2.6)
	local cam = workspace.CurrentCamera
	local right = cam and cam.CFrame.RightVector or Vector3.new(1, 0, 0)
	local start = p.Position + Vector3.new(0, 0.5, 0)
	local a, gui = floatingLabel(start, life, Vector2.new(size * 4, size * (crit and 1.6 or 1)))
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, crit and 0.62 or 1)
	holder.Position = UDim2.fromScale(0, crit and 0.38 or 0)
	holder.Parent = gui
	local label, stroke, scale = styledText(holder, text or Config.Format(amount), color, crit and C(90, 20, 10) or Color3.fromRGB(25, 20, 30), Enum.Font.LuckiestGuy)
	label.Rotation = rnd(-8, 8)
	local tag, tagStroke, tagScale
	if crit then
		local tagHolder = Instance.new("Frame")
		tagHolder.BackgroundTransparency = 1
		tagHolder.Size = UDim2.fromScale(1, 0.4)
		tagHolder.Parent = gui
		tag, tagStroke, tagScale = styledText(tagHolder, "CRITICAL!", C(255, 90, 60), C(60, 10, 10), Enum.Font.LuckiestGuy)
		burst(start, C(255, 210, 80), 14, 1.1, 26, TEX.Sparkle)
		flashBall(start, 1.5, C(255, 230, 120), 0.18)
	end
	animate(life, function(k)
		local e = outCubic(k)
		a.Position = start + right * side * e + Vector3.new(0, 3.2 * math.sin(math.min(1, k * 1.6) * math.pi * 0.5) - k * k * 1.2, 0)
		-- pop: 0.2 → 1.35 → 1
		local s
		if k < 0.1 then
			s = 0.2 + (k / 0.1) * 1.15
		elseif k < 0.22 then
			s = 1.35 - ((k - 0.1) / 0.12) * 0.35
		else
			s = 1
		end
		scale.Scale = s
		if crit then
			label.Rotation = math.sin(k * 60) * 6 * (1 - k)
		end
		local fade = math.clamp((k - 0.62) / 0.38, 0, 1)
		label.TextTransparency = fade
		stroke.Transparency = fade
		if tag then
			tag.TextTransparency = fade
			tagStroke.Transparency = fade
			tagScale.Scale = s * 0.9
		end
	end, function()
		textCount -= 1
	end)
end

function H.XP(p)
	floatingText(p.Position, "+" .. p.Amount .. " XP", Color3.fromRGB(120, 230, 255), 30, 5)
end

function H.Cash(p)
	if p.Player == player.UserId then
		floatingText(p.Position, "+$" .. Config.Format(p.Amount), Color3.fromRGB(120, 255, 120), 40, 6)
		burst(p.Position, Color3.fromRGB(120, 255, 120), 15, 0.8, 12)
	end
end

function H.LevelUp(p)
	local root = rootOf(p.Model)
	if not root then
		return
	end
	floatingText(root.Position + Vector3.new(0, root.Size.Y + 3, 0), "LEVEL UP!", Color3.fromRGB(255, 220, 60), 46, 6)
	burst(root.Position, Color3.fromRGB(255, 230, 100), 40, 1.2, 20)
	local feet = feetOf(p.Model) or root.Position
	groundRing(feet, 1, 9, C(255, 220, 80), 0.6)
	light(root.Position, C(255, 220, 80), 16, 0.6)
end

-- Nome do poder + aviso no corpo (anel claro nos pés)
function H.SpecialName(p)
	local root = rootOf(p.Model)
	local info = DogData.Specials[p.Name]
	if not (root and info) then
		return
	end
	floatingText(root.Position + Vector3.new(0, root.Size.Y + 4, 0), "✦ " .. info.Name .. " ✦", Color3.fromRGB(255, 200, 255), 34, 3, Enum.Font.FredokaOne)
	local feet = feetOf(p.Model)
	if feet then
		groundRing(feet, root.Size.Z * 0.6, root.Size.Z * 1.6 + 3, C(255, 230, 255), 0.45, { Thick = 0.35, Height = 0.15 })
	end
end

function H.Shake(p)
	shakeAt(p.Position, p.Intensity or 0.5, p.Radius or 50, p.Duration)
end

-- Onda de choque no chão. Thick = rochas e rachaduras (golpe pesado)
function H.Shockwave(p)
	local pos = p.Position
	local r = p.Radius or 8
	local color = p.Color or C(235, 220, 190)
	groundRing(pos, 1, r, color, 0.45, { Thick = math.max(0.5, r * 0.09), Height = p.Thick and 1.6 or 0.5 })
	local flashDisc = disc(pos, r * 0.45, color, 0.3)
	animate(0.3, function(k)
		setDiscRadius(flashDisc, r * (0.45 + 0.4 * k))
		flashDisc.Transparency = 0.3 + 0.7 * k
	end, function()
		flashDisc:Destroy()
	end)
	dust(pos, color:Lerp(C(150, 130, 110), 0.5), math.floor(10 + r), 2 + r * 0.12, 10 + r)
	if p.Thick then
		shards(pos + Vector3.new(0, 0.5, 0), C(120, 100, 80), 8, 30, 0.7)
		cracks(pos, r * 0.7, C(60, 45, 35), 7, 2)
	end
end

-- Rugido/uivo: anéis saindo da boca (para frente ou para cima no uivo) + bafo
function H.Roar(p)
	local head = headOf(p.Model)
	if not head then
		return
	end
	local color = p.Color or WHITE
	for i = 0, 3 do
		task.delay(i * 0.13, function()
			if not head.Parent then
				return
			end
			local m = mouthOf(head)
			local cf
			if p.Howl then
				cf = CFrame.new(m.Position + Vector3.new(0, 0.6, 0))
			else
				cf = m * CFrame.Angles(math.rad(-90), 0, 0)
			end
			ringWave(cf, 0.8, 6 + i * 1.5, color, 0.55, { Thick = 0.35, Height = 0.35, Rise = 6, Segs = 14 })
		end)
	end
	local m = mouthOf(head)
	burst(m.Position, color, 12, 0.9, 16, TEX.Smoke, {
		EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(25, 25),
		Size = NS(0, 0.6, 1, 2.5),
		Transparency = NS(0, 0.5, 1, 1),
		LightEmission = 0.4,
	})
	shakeAt(head.Position, 0.18, 30, 0.4)
end

-- AVISO: círculo no chão que enche até o momento do golpe
function H.Telegraph(p)
	local pos = p.Position
	local r = p.Radius or 8
	local dur = p.Duration or 0.8
	local color = p.Color or C(255, 80, 60)
	local base = disc(pos, r, color, 0.82)
	local fill = disc(pos + Vector3.new(0, 0.02, 0), 0.1, color, 0.55)
	local n = math.max(12, math.floor(r * 2))
	local edge = ringParts(math.floor(n * (0.5 + 0.5 * quality())), color)
	local edgeCF = CFrame.new(pos + Vector3.new(0, 0.1, 0))
	animate(dur, function(k, t)
		setDiscRadius(fill, math.max(0.1, r * k))
		placeRing(edge, edgeCF, r, 0.3, 0.2 + 0.15 * math.sin(t * 18), t * 0.6, 0.2)
	end, function()
		base:Destroy()
		fill:Destroy()
		for _, e in ipairs(edge) do
			e:Destroy()
		end
	end)
end

-- IMPACTO genérico (aterrissagem, investida)
function H.Impact(p)
	local pos = p.Position
	local r = p.Radius or 6
	local color = p.Color or C(240, 225, 200)
	flashBall(pos + Vector3.new(0, 1, 0), r * 0.6, WHITE:Lerp(color, 0.4), 0.22)
	groundRing(pos, 1, r * 1.2, color, 0.4, { Thick = 0.6, Height = 0.6 })
	burst(pos + Vector3.new(0, 1, 0), color, 16, 0.8, 30, TEX.Spark, { Lifetime = NumberRange.new(0.2, 0.45), Drag = 5 })
	dust(pos, C(170, 150, 120), 10 + r, 2.5, 14)
	light(pos + Vector3.new(0, 2, 0), color, r * 3, 0.35)
	if p.Heavy then
		shards(pos, C(120, 100, 80), 6, 26, 0.6)
		cracks(pos, r, C(60, 45, 35), 6, 1.8)
	end
	shakeAt(pos, math.clamp(r / 18, 0.15, 0.7), 40 + r * 2, 0.3)
end

-- Rastro preso ao corpo (Trail) enquanto ele se move
function H.Streak(p)
	local root = rootOf(p.Model)
	if not root then
		return
	end
	local w = (p.Width or 1.5) * math.max(1, root.Size.Y * 0.4)
	local life = p.Lifetime or 0.3
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, w / 2, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -w / 2, 0)
	a1.Parent = root
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Color = CS(0, WHITE, 0.3, p.Color, 1, p.Color)
	tr.Transparency = NS(0, p.Neon and 0.05 or 0.35, 1, 1)
	tr.WidthScale = NS(0, 1, 1, 0.2)
	tr.Lifetime = life
	tr.LightEmission = p.Neon and 1 or 0.3
	tr.FaceCamera = true
	tr.MinLength = 0.05
	tr.Parent = root
	local dur = p.Duration or 0.5
	task.delay(dur, function()
		tr.Enabled = false
	end)
	Debris:AddItem(tr, dur + life + 0.1)
	Debris:AddItem(a0, dur + life + 0.1)
	Debris:AddItem(a1, dur + life + 0.1)
	if p.Sparks then
		local e = emitter(a1, {
			Texture = TEX.Spark,
			Enabled = true,
			Rate = 40 * quality(),
			Color = ColorSequence.new(p.Color),
			LightEmission = 1,
			Size = NS(0, 0.5, 1, 0),
			Lifetime = NumberRange.new(0.2, 0.4),
			Speed = NumberRange.new(2, 6),
			SpreadAngle = Vector2.new(180, 180),
		})
		task.delay(dur, function()
			e.Enabled = false
		end)
	end
end

-- Linha reta (rastro de dash/teleporte) com brilho
function H.Trail(p)
	local diff = p.To - p.From
	local len = diff.Magnitude
	if len < 0.5 then
		return
	end
	local w = p.Width or 1
	local cf = CFrame.lookAt(p.From, p.To) * CFrame.new(0, 0, -len / 2)
	local streak = fxPart({ Size = Vector3.new(w, w * 0.5, len), CFrame = cf, Color = p.Color, Transparency = p.Neon and 0.15 or 0.5 })
	local core = fxPart({ Size = Vector3.new(w * 0.3, w * 0.15, len), CFrame = cf, Color = WHITE, Transparency = 0.1 })
	local dur = p.Duration or 0.4
	animate(dur, function(k)
		streak.Size = Vector3.new(w * (1 - k * 0.9), w * 0.5 * (1 - k * 0.9), len)
		streak.Transparency = (p.Neon and 0.15 or 0.5) + 0.85 * k
		core.Transparency = 0.1 + 0.9 * k
	end, function()
		streak:Destroy()
		core:Destroy()
	end)
end

---------------------------------------------------------------- elétricos
-- Carga elétrica nas patas: faíscas, arcos pulando, brilho no chão crescendo, olhos acesos
function H.ThunderCharge(p)
	local model = p.Model
	local root = rootOf(model)
	if not root then
		return
	end
	local color = p.Color or C(130, 220, 255)
	local dur = p.Duration or 1
	local paws = partsNamed(model, function(n)
		return n == "Pata"
	end)
	if #paws == 0 then
		paws = partsNamed(model, function(n)
			return n:match("^Leg") ~= nil
		end)
	end
	local emitters = {}
	for _, part in ipairs(paws) do
		table.insert(
			emitters,
			emitter(part, {
				Texture = TEX.Spark,
				Color = CS(0, WHITE, 1, color),
				Rate = 30 * quality(),
				Enabled = true,
				LightEmission = 1,
				Size = NS(0, 0.5, 1, 0),
				Lifetime = NumberRange.new(0.12, 0.28),
				Speed = NumberRange.new(5, 12),
				SpreadAngle = Vector2.new(180, 180),
			})
		)
	end
	local feet = feetOf(model) or root.Position
	local glow = disc(feet, 0.5, color, 0.5)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = 10
	l.Brightness = 0
	l.Shadows = false
	l.Parent = root
	local nextArc = 0
	animate(dur, function(k, t)
		if not root.Parent then
			return true
		end
		local f = feetOf(model) or feet
		glow.CFrame = CFrame.new(f + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
		setDiscRadius(glow, 1 + root.Size.Z * 0.9 * k)
		glow.Transparency = 0.75 - 0.35 * k + math.sin(t * 40) * 0.08
		l.Brightness = 1 + 4 * k
		if t >= nextArc and #paws > 0 then
			nextArc = t + 0.05 / quality()
			local part = paws[math.random(1, #paws)]
			local a = part.Position
			bolt(a, a + Vector3.new(rnd(-1, 1), rnd(0.3, 1.4), rnd(-1, 1)) * (2 + 2 * k), color, 0.08, 0.15 + 0.1 * k, 0.3)
		end
		return nil
	end, function()
		for _, e in ipairs(emitters) do
			e:Destroy()
		end
		glow:Destroy()
		l:Destroy()
	end)
end
H.Sparks = H.ThunderCharge

-- Dash relâmpago: risco elétrico no chão entre os pontos + arcos ao longo + marca queimada
function H.ThunderDash(p)
	local from, to = p.From, p.To
	local color = p.Color or C(150, 230, 255)
	bolt(from + Vector3.new(0, 1.2, 0), to + Vector3.new(0, 1.2, 0), color, 0.35, 0.9, 0.04)
	bolt(from + Vector3.new(0, 1.6, 0), to + Vector3.new(0, 1.0, 0), WHITE, 0.2, 0.3, 0.07)
	H.Trail({ From = from + Vector3.new(0, 1, 0), To = to + Vector3.new(0, 1, 0), Color = color, Width = 2.2, Duration = 0.5, Neon = true })
	local dir = flat(to - from)
	local len = dir.Magnitude
	if len > 1 and not crowded(4) then
		local mark = fxPart({
			Size = Vector3.new(1.4, 0.06, len),
			CFrame = CFrame.lookAt(from, from + dir) * CFrame.new(0, -0.9, -len / 2),
			Color = C(30, 40, 60),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.4,
		})
		task.delay(1.2, function()
			if mark.Parent then
				tween(mark, 0.8, { Transparency = 1 })
			end
		end)
		Debris:AddItem(mark, 2.1)
	end
	for k = 1, q(5) do
		burst(from:Lerp(to, k / 5) + Vector3.new(0, 1, 0), color, 4, 0.6, 14, TEX.Spark)
	end
	light(to + Vector3.new(0, 2, 0), color, 20, 0.3)
end

-- Raio caindo do céu: pré-flash fino, raio grosso + ramificações, anel, luz forte, chão queimado
function H.Lightning(p)
	local ground = p.Position
	local color = p.Color or C(160, 230, 255)
	local big = p.Big ~= false
	local sky = ground + Vector3.new(rnd(-5, 5), 70, rnd(-5, 5))
	bolt(sky, ground, color, 0.4, big and 1.6 or 1, 0.12)
	bolt(sky + Vector3.new(rnd(-3, 3), 0, rnd(-3, 3)), ground + Vector3.new(rnd(-2, 2), 0, rnd(-2, 2)), WHITE, 0.25, 0.45, 0.15)
	-- ramificações
	for _ = 1, q(3) do
		local mid = sky:Lerp(ground, rnd(0.3, 0.7))
		bolt(mid, mid + Vector3.new(rnd(-10, 10), rnd(-14, -6), rnd(-10, 10)), color, 0.25, 0.35, 0.2)
	end
	-- coluna de luz
	local col = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(60, 5, 5),
		CFrame = CFrame.new(ground + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.5,
	})
	animate(0.3, function(k)
		col.Size = Vector3.new(60, 5 * (1 - k) + 0.2, 5 * (1 - k) + 0.2)
		col.Transparency = 0.5 + 0.5 * k
	end, function()
		col:Destroy()
	end)
	flashBall(ground + Vector3.new(0, 1, 0), 4, WHITE, 0.2)
	light(ground + Vector3.new(0, 5, 0), color, 50, 0.6, 8)
	burst(ground + Vector3.new(0, 1, 0), color, 30, 1, 40, TEX.Spark, { Lifetime = NumberRange.new(0.25, 0.6), Acceleration = Vector3.new(0, -30, 0) })
	groundRing(ground, 1, big and 16 or 10, color, 0.45, { Thick = 0.8, Height = 0.4 })
	scorch(ground, big and 4 or 2.5, C(20, 25, 35), 2)
	cracks(ground, big and 7 or 4, color, big and 6 or 4, 1.2, true)
	shakeAt(ground, big and 0.55 or 0.35, 60, 0.3)
end

-- Carga/brilho nos olhos (ou no corpo todo com Body=true): aviso de que um golpe vem
function H.EyeGlow(p)
	local model = p.Model
	local root = rootOf(model)
	if not root then
		return
	end
	local color = p.Color or WHITE
	local dur = p.Duration or 0.5
	local hosts = {}
	if p.Body then
		table.insert(hosts, model:FindFirstChild("Torso") or root)
	else
		local heads = p.All and (model:GetAttribute("Heads") or 1) or 1
		for i = 1, heads do
			local h = headOf(model, i)
			if h then
				table.insert(hosts, h)
			end
		end
	end
	local list = {}
	for _, host in ipairs(hosts) do
		local att = Instance.new("Attachment")
		att.Position = p.Body and Vector3.zero or Vector3.new(0, host.Size.Y * 0.12, -host.Size.Z * 0.45)
		att.Parent = host
		local e = emitter(att, {
			Texture = TEX.Glow,
			Enabled = true,
			Rate = 18 * quality(),
			LightEmission = 1,
			Color = ColorSequence.new(color),
			Size = NS(0, p.Body and 3 or 1.2, 1, 0),
			Transparency = NS(0, 0.3, 1, 1),
			Lifetime = NumberRange.new(0.15, 0.3),
			Speed = NumberRange.new(0, 0.5),
			LockedToPart = true,
		})
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = p.Body and 16 or 8
		l.Brightness = 0
		l.Shadows = false
		l.Parent = att
		table.insert(list, { att, e, l })
	end
	burst(hosts[1] and hosts[1].Position or root.Position, color, 6, 0.7, 6, TEX.Sparkle)
	animate(dur, function(k, t)
		for _, entry in ipairs(list) do
			entry[3].Brightness = (2 + 3 * k) * (0.85 + 0.15 * math.sin(t * 30))
		end
	end, function()
		for _, entry in ipairs(list) do
			entry[2].Enabled = false
			entry[3].Enabled = false
			Debris:AddItem(entry[1], 0.4)
		end
	end)
end

-- Laser dos olhos: feixe (brilho + miolo) varre os pontos; faíscas e marcas de queimado no chão
function H.Laser(p)
	local head = headOf(p.Model)
	local points = p.Points
	if not head or not points or #points == 0 then
		return
	end
	local color = p.Color or C(255, 50, 50)
	local dur = p.Duration or 1.2
	local w = p.Width or 0.8
	local glow = fxPart({ Size = Vector3.new(w, w, 1), Color = color, Transparency = 0.35 })
	local core = fxPart({ Size = Vector3.new(w * 0.35, w * 0.35, 1), Color = WHITE, Transparency = 0 })
	local tip = anchor(points[1], dur + 1)
	local sparks = emitter(tip, {
		Texture = TEX.Spark,
		Enabled = true,
		Rate = 70 * quality(),
		Color = CS(0, WHITE, 1, color),
		LightEmission = 1,
		Size = NS(0, 0.6, 1, 0),
		Lifetime = NumberRange.new(0.2, 0.45),
		Speed = NumberRange.new(8, 18),
		SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -25, 0),
	})
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = 14
	l.Brightness = 5
	l.Parent = tip
	local nextMark = 0
	animate(dur, function(k, t)
		if not head.Parent then
			return true
		end
		local seg = k * (#points - 1)
		local i = math.clamp(math.floor(seg) + 1, 1, #points)
		local j = math.min(i + 1, #points)
		local target = points[i]:Lerp(points[j], seg - (i - 1))
		local from = head.CFrame * CFrame.new(0, head.Size.Y * 0.12, -head.Size.Z * 0.45)
		local origin = from.Position
		local len = (target - origin).Magnitude
		local cf = CFrame.lookAt(origin, target) * CFrame.new(0, 0, -len / 2)
		local pulse = 1 + math.sin(t * 50) * 0.15
		glow.Size = Vector3.new(w * pulse, w * pulse, len)
		glow.CFrame = cf
		core.Size = Vector3.new(w * 0.35, w * 0.35, len)
		core.CFrame = cf
		tip.Position = target
		if t >= nextMark then
			nextMark = t + 0.06
			scorch(target, 0.9, C(40, 15, 15), 1.2)
		end
		return nil
	end, function()
		glow:Destroy()
		core:Destroy()
		sparks.Enabled = false
		l.Enabled = false
	end)
	-- olhos acesos antes do disparo
	burst(head.Position, color, 10, 0.8, 4, TEX.Glow)
end

---------------------------------------------------------------- gelo
-- Campo de gelo: o chão congela do centro para fora, cristais nascem em ondas, névoa fria
function H.IceField(p)
	local pos = p.Position
	local r = p.Radius or 14
	local dur = p.Duration or 3
	local grow = p.Grow or 0.6
	local floor = disc(pos, 0.5, C(200, 240, 255), 0.25, Enum.Material.Ice)
	local rim = disc(pos + Vector3.new(0, 0.03, 0), 0.5, C(230, 250, 255), 0.4)
	animate(grow, function(k)
		local e = outCubic(k)
		setDiscRadius(floor, r * e)
		setDiscRadius(rim, r * e + 0.4)
		rim.Transparency = 0.4 + 0.5 * k
	end)
	local crystals = {}
	local n = q(18)
	if not crowded(n) then
		for i = 1, n do
			local a = math.random() * math.pi * 2
			local rr = math.sqrt(math.random()) * r * 0.95
			task.delay(grow * rr / r, function()
				local c = spike(
					pos + Vector3.new(math.cos(a) * rr, 0, math.sin(a) * rr),
					rnd(0.6, 1.2),
					rnd(1.5, 4),
					C(185, 230, 255),
					Enum.Material.Glass,
					0.15,
					0.35
				)
				table.insert(crystals, c)
			end)
			if i % 3 == 0 then
				task.delay(grow * rr / r, function()
					burst(pos + Vector3.new(math.cos(a) * rr, 0.5, math.sin(a) * rr), C(220, 245, 255), 3, 0.5, 6)
				end)
			end
		end
	end
	local mist = anchor(pos + Vector3.new(0, 0.5, 0), dur + 3)
	local fog = emitter(mist, {
		Texture = TEX.Smoke,
		Enabled = true,
		Rate = 10 * quality(),
		Color = ColorSequence.new(C(220, 245, 255)),
		LightEmission = 0.2,
		Size = NS(0, 2, 1, 5),
		Transparency = NS(0, 0.75, 1, 1),
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(r * 0.3, r * 0.6),
		SpreadAngle = Vector2.new(5, 180),
		EmissionDirection = Enum.NormalId.Right,
		Drag = 1,
	})
	task.delay(dur, function()
		fog.Enabled = false
		tween(floor, 0.6, { Transparency = 1 })
		tween(rim, 0.6, { Transparency = 1 })
		for _, c in ipairs(crystals) do
			if c.Parent then
				burst(c.Position, C(210, 240, 255), 2, 0.5, 8)
				tween(c, 0.4, { Transparency = 1, Size = c.Size * Vector3.new(0.3, 0.2, 0.3) })
			end
		end
	end)
	Debris:AddItem(floor, dur + 0.7)
	Debris:AddItem(rim, dur + 0.7)
	task.delay(dur + 0.6, function()
		for _, c in ipairs(crystals) do
			c:Destroy()
		end
	end)
end

-- Onda de gelo atravessando: frente de cristais pontudos inclinados para frente, deixa trilha que estilhaça
function H.IceWave(p)
	local from, dir = p.From, flat(p.Direction).Unit
	local length, width, dur = p.Length or 50, p.Width or 16, p.Duration or 0.8
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local color = p.Color or C(180, 230, 255)
	local rows = math.max(6, math.floor(length / 4 * (0.5 + 0.5 * quality())))
	local placed = 0
	local trail = {}
	local front = anchor(from + Vector3.new(0, 1, 0), dur + 2)
	local fog = emitter(front, {
		Texture = TEX.Smoke,
		Enabled = true,
		Rate = 30 * quality(),
		Color = ColorSequence.new(C(230, 250, 255)),
		LightEmission = 0.3,
		Size = NS(0, 2, 1, 6),
		Transparency = NS(0, 0.5, 1, 1),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(4, 10),
		SpreadAngle = Vector2.new(70, 30),
		EmissionDirection = Enum.NormalId.Top,
	})
	local wall = fxPart({ Size = Vector3.new(width, 0.4, 1.2), Color = WHITE, Transparency = 0.3 })
	animate(dur, function(k)
		local along = length * k
		local center = from + dir * along
		front.Position = center + Vector3.new(0, 1, 0)
		local wallH = 2.5 + math.sin(k * math.pi) * 2
		wall.Size = Vector3.new(width * (0.7 + 0.3 * k), wallH, 1.2)
		wall.CFrame = CFrame.lookAt(center + Vector3.new(0, wallH / 2, 0), center + Vector3.new(0, wallH / 2, 0) + dir)
		wall.Transparency = 0.35 + 0.4 * k
		local want = math.floor(k * rows)
		while placed < want do
			placed += 1
			local at = from + dir * (length * placed / rows)
			for s = -1, 1 do
				local pos = at + right * (s * width * 0.3 + rnd(-1, 1))
				local c = spike(pos, rnd(1.2, 2), rnd(2.5, 4.5) * (s == 0 and 1.3 or 1), color, Enum.Material.Glass, 0.1, 0.45)
				table.insert(trail, c)
			end
			burst(at + Vector3.new(0, 1, 0), C(225, 245, 255), 4, 0.8, 10)
		end
		return nil
	end, function()
		wall:Destroy()
		fog.Enabled = false
	end)
	-- resíduo: a trilha fica um instante e estilhaça
	task.delay(dur + 0.9, function()
		for i, c in ipairs(trail) do
			if c.Parent then
				if i % 3 == 0 then
					burst(c.Position, C(215, 240, 255), 3, 0.6, 12)
				end
				tween(c, 0.35, { Transparency = 1, Size = c.Size * Vector3.new(0.4, 0.2, 0.4) })
				Debris:AddItem(c, 0.4)
			end
		end
	end)
end
-- compatibilidade com a versão anterior
H.Wave = H.IceWave

-- Congelado: bloco de gelo com cristais em volta, ou bandagens em espiral (Múmia). Estilhaça no fim.
function H.Freeze(p)
	local model = p.Model
	local root = rootOf(model)
	if not root then
		return
	end
	local dur = p.Duration or 2
	local size = model:GetExtentsSize()
	if p.Kind == "vines" then
		return -- 🌿 Natureza: as raízes já aparecem pelo efeito B_Vines (sem bloco de gelo)
	end
	if p.Kind == "bandage" then
		-- bandagem em espiral (hélice elíptica) que vai enrolando o corpo de baixo para cima
		local strips = {}
		local n = math.max(12, math.floor(30 * (0.5 + 0.5 * quality())))
		local turns = 4
		for i = 1, n do
			table.insert(
				strips,
				fxPart({
					Size = Vector3.new(0.12, 0.55, 1),
					Color = i % 2 == 0 and C(235, 222, 185) or C(215, 200, 160),
					Material = Enum.Material.Fabric,
					Transparency = 1,
				})
			)
		end
		local rx, rz = size.X * 0.55, size.Z * 0.45
		local function helix(u, spread)
			local a = u * turns * math.pi * 2
			return Vector3.new(math.cos(a) * rx * spread, (u - 0.5) * size.Y * 0.85, math.sin(a) * rz * spread)
		end
		animate(dur, function(k, t)
			if not root.Parent then
				return true
			end
			local pivot = model:GetPivot()
			local wrap = math.min(1, t / 0.4)
			local spread = 1.5 - 0.5 * outCubic(wrap)
			for i, s in ipairs(strips) do
				local u0, u1 = (i - 1) / n, i / n
				local p0 = pivot * helix(u0, spread)
				local p1 = pivot * helix(u1, spread)
				local len = (p1 - p0).Magnitude
				s.Size = Vector3.new(0.12, 0.55, len + 0.15)
				s.CFrame = CFrame.lookAt(p0, p1) * CFrame.new(0, 0, -len / 2)
				local shown = u1 <= wrap + 0.001
				s.Transparency = shown and (k > 0.85 and (k - 0.85) / 0.15 or 0) or 1
			end
			return nil
		end, function()
			for _, s in ipairs(strips) do
				s:Destroy()
			end
			burst(root.Position, C(235, 220, 180), 14, 0.7, 12, TEX.Smoke, { LightEmission = 0 })
		end)
		return
	end
	-- gelo
	local block = fxPart({
		Size = size * 1.12,
		CFrame = model:GetPivot(),
		Color = C(170, 225, 255),
		Material = Enum.Material.Ice,
		Transparency = 0.45,
	})
	local crystals = {}
	local feet = feetOf(model) or root.Position
	if not crowded(6) then
		for _ = 1, q(6) do
			local a = math.random() * math.pi * 2
			local c = spike(
				feet + Vector3.new(math.cos(a), 0, math.sin(a)) * (math.max(size.X, size.Z) * 0.55),
				rnd(0.6, 1.1),
				rnd(1.5, size.Y * 0.9),
				C(200, 240, 255),
				Enum.Material.Glass,
				0.1,
				0.5
			)
			table.insert(crystals, c)
		end
	end
	burst(root.Position, C(220, 245, 255), 14, 0.9, 10)
	animate(dur, function()
		if not root.Parent then
			return true
		end
		block.CFrame = model:GetPivot()
		return nil
	end, function()
		shards(block.Position, C(190, 235, 255), 8, 22, 0.5, Enum.Material.Glass)
		burst(block.Position, C(220, 245, 255), 18, 1, 14)
		block:Destroy()
		for _, c in ipairs(crystals) do
			c:Destroy()
		end
	end)
end

---------------------------------------------------------------- sombras
-- Clones de sombra: silhuetas escuras com olhos roxos acesos; avançam juntos e viram fumaça
function H.Clones(p)
	local source = p.Model
	if not (source and source.Parent) then
		return
	end
	local dur = p.Duration or 1.2
	local pivot = source:GetPivot()
	local minSize = quality() < 1 and 0.25 or 0
	local center = p.Center
	for i, cf in ipairs(p.CFrames) do
		task.delay((i - 1) * 0.1, function()
			if not source.Parent then
				return
			end
			local clone = Instance.new("Model")
			local list = {}
			for _, d in ipairs(source:GetDescendants()) do
				if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Size.Magnitude > minSize then
					local eye = d.Name == "Olho" or d.Name == "Pupila" or d.Name == "Visor"
					local c = fxPart({
						Size = d.Size,
						Color = eye and C(220, 120, 255) or C(25, 12, 40),
						Material = Enum.Material.Neon,
						Transparency = 1,
						CFrame = cf * pivot:ToObjectSpace(d.CFrame),
					})
					local mesh = d:FindFirstChildOfClass("SpecialMesh")
					if mesh then
						mesh:Clone().Parent = c
					end
					c.Parent = clone
					table.insert(list, { c, eye })
				end
			end
			clone.WorldPivot = cf
			clone.Parent = folder
			burst(cf.Position, C(90, 40, 160), 14, 2.2, 8, TEX.Smoke, { LightEmission = 0.2, Size = NS(0, 1.5, 1, 4) })
			local life = dur - (i - 1) * 0.1
			local lungeFrom = cf
			local lungeTo = cf
			if center then
				local toward = flat(center - cf.Position)
				if toward.Magnitude > 0.1 then
					lungeTo = cf + toward.Unit * math.min(3, toward.Magnitude * 0.5)
				end
			end
			animate(life, function(k, t)
				local appear = math.min(1, t / 0.18)
				local vanish = k > 0.8 and (k - 0.8) / 0.2 or 0
				for _, entry in ipairs(list) do
					local base = entry[2] and 0 or 0.3
					entry[1].Transparency = 1 - (1 - base) * appear * (1 - vanish)
				end
				if k > 0.6 then
					local e = outCubic(math.min(1, (k - 0.6) / 0.2))
					clone:PivotTo(lungeFrom:Lerp(lungeTo, e) * CFrame.new(0, math.sin(t * 30) * 0.05, 0))
				end
				return nil
			end, function()
				burst(clone:GetPivot().Position, C(60, 25, 100), 10, 2, 6, TEX.Smoke, { LightEmission = 0.1, Size = NS(0, 1.5, 1, 3.5) })
				clone:Destroy()
			end)
		end)
	end
end

-- O verdadeiro aparece: flash roxo, X cortando, pétalas de sombra
function H.ShadowStrike(p)
	local pos = p.Position
	local color = p.Color or C(190, 100, 255)
	flashBall(pos, 3, color, 0.2)
	light(pos, color, 22, 0.5, 6)
	burst(pos, C(40, 10, 70), 16, 2.5, 14, TEX.Smoke, { LightEmission = 0, Size = NS(0, 1, 1, 3.5) })
	burst(pos, color, 18, 0.9, 26, TEX.Sparkle)
	local d = p.Direction or Vector3.new(0, 0, -1)
	H.Slash({ Position = pos, Direction = d, Color = color, Size = 8, Tilt = 0.8 })
	H.Slash({ Position = pos, Direction = d, Color = WHITE, Size = 8, Tilt = -0.8 })
	shakeAt(pos, 0.35, 40)
end

function H.Smoke(p)
	burst(p.Position, p.Color, 22, p.Size or 4, 8, TEX.Smoke, {
		LightEmission = 0.1,
		Size = NS(0, (p.Size or 4) * 0.4, 1, p.Size or 4),
		Transparency = NS(0, 0.2, 1, 1),
		Lifetime = NumberRange.new(0.6, 1.1),
		Drag = 3,
	})
end

-- Corte em meia-lua que "varre" (o arco vai aparecendo) e some
function H.Slash(p)
	local d = flat(p.Direction or Vector3.new(0, 0, -1))
	d = d.Magnitude > 0.01 and d.Unit or Vector3.new(0, 0, -1)
	local color = p.Color or WHITE
	local size = p.Size or 7
	local tilt = p.Tilt or rnd(-0.6, 0.6)
	local center = p.Position + Vector3.new(0, 1, 0)
	local n = math.max(5, math.floor(9 * (0.5 + 0.5 * quality())))
	local base = CFrame.lookAt(center, center + d) * CFrame.Angles(0, 0, tilt)
	local segs = {}
	local radius = size * 0.5
	local arc = math.pi * 0.9
	for i = 1, n do
		local mid = math.abs(i - (n + 1) / 2) / ((n + 1) / 2)
		table.insert(segs, { fxPart({ Size = Vector3.new(0.1, 0.1, 0.1), Color = i % 2 == 0 and WHITE or color, Transparency = 1 }), 1 - mid })
	end
	animate(0.28, function(k)
		local reveal = math.min(1, k / 0.45)
		for i, entry in ipairs(segs) do
			local part, thickK = entry[1], entry[2]
			local a0 = -arc / 2 + (i - 1) / n * arc
			local a1 = -arc / 2 + i / n * arc
			local shown = (i / n) <= reveal + 0.001
			local p0 = base * Vector3.new(math.sin(a0) * radius, 0, -math.cos(a0) * radius * 0.4)
			local p1 = base * Vector3.new(math.sin(a1) * radius, 0, -math.cos(a1) * radius * 0.4)
			local len = (p1 - p0).Magnitude
			local th = (0.15 + 0.55 * thickK) * (1 - k * 0.6)
			part.Size = Vector3.new(th, th * 0.5, len + th)
			part.CFrame = CFrame.lookAt(p0, p1) * CFrame.new(0, 0, -len / 2)
			part.Transparency = shown and (0.05 + 0.95 * math.max(0, (k - 0.4) / 0.6)) or 1
		end
	end, function()
		for _, entry in ipairs(segs) do
			entry[1]:Destroy()
		end
	end)
	burst(center, color, 5, 0.6, 14, TEX.Spark)
end

-- Marca de mordida grande (dentes de cima e de baixo fechando) — usado por cabeças alternadas
function H.BiteMark(p)
	local pos = p.Position
	local d = flat(p.Direction or Vector3.new(0, 0, -1))
	d = d.Magnitude > 0.01 and d.Unit or Vector3.new(0, 0, -1)
	local color = p.Color or WHITE
	local scale = p.Big and 1.8 or 1
	local base = CFrame.lookAt(pos, pos + d) * CFrame.new(0, 0, 0.5)
	local teeth = {}
	local n = p.Big and 5 or 4
	for jaw = -1, 1, 2 do
		for i = 1, n do
			local t =
				fxPart({ Shape = Enum.PartType.Wedge, Size = Vector3.new(0.35, 0.8, 0.5) * scale, Color = i % 2 == 0 and WHITE or color, Transparency = 0 })
			table.insert(teeth, { t, jaw, (i - (n + 1) / 2) * 0.55 * scale })
		end
	end
	local gap = 2.2 * scale
	animate(0.3, function(k)
		local close = k < 0.4 and outCubic(k / 0.4) or 1
		local g = gap * (1 - close)
		for _, e in ipairs(teeth) do
			local part, jaw, x = e[1], e[2], e[3]
			local cf = base * CFrame.new(x, jaw * (g + 0.35 * scale), 0)
			part.CFrame = jaw > 0 and cf * CFrame.Angles(math.pi, 0, 0) or cf
			part.Transparency = k > 0.5 and (k - 0.5) / 0.5 or 0
		end
	end, function()
		for _, e in ipairs(teeth) do
			e[1]:Destroy()
		end
	end)
	task.delay(0.12, function()
		burst(pos, color, p.Big and 18 or 8, 0.8, 18, TEX.Spark)
		if p.Big then
			flashBall(pos, 2.5, color, 0.2)
			light(pos, color, 16, 0.3)
		end
	end)
end

---------------------------------------------------------------- terra / cristal
-- Espinhos/cristais em linha (ou sombras em anel). Ficam um pouco e estilhaçam.
function H.Spikes(p)
	local interval = p.Interval or 0.05
	local shadow = p.Kind == "shadow"
	local color = p.Color or C(200, 150, 255)
	local h = p.Height or 6
	for i, pos in ipairs(p.Positions) do
		task.delay(i * interval, function()
			local list = {}
			local main = spike(pos, shadow and 1.4 or 1.6, h, color, shadow and Enum.Material.Neon or Enum.Material.Glass, shadow and 0.05 or 0.1, 0.3)
			table.insert(list, main)
			if not shadow and not crowded(2) then
				for _ = 1, 2 do
					local off = Vector3.new(rnd(-1.2, 1.2), 0, rnd(-1.2, 1.2))
					table.insert(list, spike(pos + off, rnd(0.6, 1), h * rnd(0.35, 0.6), color:Lerp(WHITE, 0.3), Enum.Material.Glass, 0.15, 0.6))
				end
			end
			if shadow then
				burst(pos, C(30, 0, 20), 6, 2, 6, TEX.Smoke, { LightEmission = 0, Size = NS(0, 1, 1, 3) })
			else
				burst(pos + Vector3.new(0, 1, 0), color, 5, 0.7, 10)
				dust(pos, C(150, 130, 120), 3, 1.5, 6)
			end
			task.delay(0.9, function()
				for _, s in ipairs(list) do
					if s.Parent then
						if not shadow then
							burst(s.Position, color, 2, 0.5, 10)
						end
						tween(s, 0.3, { Transparency = 1, Size = s.Size * Vector3.new(0.3, 0.6, 0.3) })
					end
				end
			end)
			for _, s in ipairs(list) do
				Debris:AddItem(s, 1.3)
			end
		end)
	end
end

-- Ground Slam: rochas sobem num anel que expande, poeira grossa, rachaduras, luz de terra
function H.GroundSlam(p)
	local pos = p.Position
	local r = p.Radius or 20
	local color = p.Color or C(200, 170, 130)
	flashBall(pos + Vector3.new(0, 1, 0), 3, C(255, 240, 210), 0.2)
	groundRing(pos, 1, r, color, 0.55, { Thick = 1.4, Height = 1.8, Material = Enum.Material.SmoothPlastic, Transparency = 0.2 })
	groundRing(pos, 1, r * 0.8, WHITE, 0.35, { Thick = 0.5, Height = 0.3 })
	-- rochas brotando ao longo da onda
	local rings = 3
	for ring = 1, rings do
		local rr = r * ring / (rings + 0.5)
		local count = q(6 + ring * 3)
		task.delay(0.55 * ring / (rings + 0.5), function()
			if crowded(count) then
				return
			end
			for i = 1, count do
				local a = i / count * math.pi * 2 + rnd(-0.2, 0.2)
				local rp = pos + Vector3.new(math.cos(a), 0, math.sin(a)) * rr
				local rock = spike(rp, rnd(1.2, 2.2), rnd(1.5, 3.2) * (1.2 - ring * 0.15), C(130, 110, 90), Enum.Material.Slate, 0, 0.5)
				task.delay(0.7, function()
					if rock.Parent then
						tween(rock, 0.35, { Transparency = 1, CFrame = rock.CFrame - Vector3.new(0, 1.5, 0) })
					end
				end)
				Debris:AddItem(rock, 1.1)
			end
		end)
	end
	dust(pos, C(170, 150, 120), 30, 4, 28)
	shards(pos + Vector3.new(0, 0.5, 0), C(120, 100, 80), 10, 34, 0.8)
	cracks(pos, r * 0.6, C(50, 40, 30), 9, 2.5)
	light(pos + Vector3.new(0, 3, 0), C(255, 220, 160), 30, 0.4)
	shakeAt(pos, 0.75, 70, 0.5)
end

---------------------------------------------------------------- veneno
function H.Glob(p)
	local from, to, dur = p.From, p.To, p.Duration or 0.45
	local color = p.Color or C(130, 230, 60)
	local ball = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, Color = color, Transparency = 0.1, CFrame = CFrame.new(from) })
	local a0 = Instance.new("Attachment")
	a0.Parent = ball
	local drip = emitter(a0, {
		Texture = TEX.Smoke,
		Enabled = true,
		Rate = 40 * quality(),
		Color = ColorSequence.new(color),
		LightEmission = 0.4,
		Size = NS(0, 0.8, 1, 0.2),
		Transparency = NS(0, 0.3, 1, 1),
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(0, 1),
	})
	local height = math.max(4, (to - from).Magnitude * 0.3)
	animate(dur, function(k)
		ball.CFrame = CFrame.new(from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * height, 0))
	end, function()
		drip.Enabled = false
		Debris:AddItem(ball, 0.6)
		ball.Transparency = 1
		burst(to + Vector3.new(0, 0.5, 0), color, 20, 1.2, 18, TEX.Sparkle)
		groundRing(to, 0.5, 5, color, 0.35, { Thick = 0.5 })
	end)
end

-- Nuvem tóxica: névoa verde, bolhas subindo, disco borbulhante (resíduo)
function H.Cloud(p)
	local pos, r, dur = p.Position, p.Radius or 12, p.Duration or 5
	local color = p.Color or C(130, 230, 60)
	local anchorPart = fxPart({ Size = Vector3.new(r * 2, 3, r * 2), CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)), Transparency = 1 })
	local fog = emitter(anchorPart, {
		Texture = TEX.Smoke,
		Enabled = true,
		Rate = 25 * quality(),
		LightEmission = 0.35,
		Color = CS(0, color, 1, color:Lerp(C(60, 90, 20), 0.5)),
		Size = NS(0, 3, 1, 7),
		Transparency = NS(0, 0.55, 0.5, 0.6, 1, 1),
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(0.5, 2),
		Shape = Enum.ParticleEmitterShape.Box,
		RotSpeed = NumberRange.new(-20, 20),
		Rotation = NumberRange.new(0, 360),
	})
	local bubbles = emitter(anchorPart, {
		Texture = TEX.Glow,
		Enabled = true,
		Rate = 14 * quality(),
		LightEmission = 0.8,
		Color = ColorSequence.new(color:Lerp(WHITE, 0.3)),
		Size = NS(0, 0.2, 0.8, 0.7, 1, 0),
		Transparency = NS(0, 0.2, 1, 0.6),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(2, 4),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
	})
	local floor = disc(pos, 0.5, color:Lerp(C(40, 60, 10), 0.4), 0.55)
	animate(0.5, function(k)
		setDiscRadius(floor, r * outCubic(k))
	end)
	task.delay(dur, function()
		fog.Enabled = false
		bubbles.Enabled = false
		tween(floor, 0.8, { Transparency = 1 })
	end)
	Debris:AddItem(anchorPart, dur + 3)
	Debris:AddItem(floor, dur + 0.9)
end

---------------------------------------------------------------- fogo
-- Labareda no chão (rastro de fogo) por alguns segundos
function H.FireSpot(p)
	local pos, dur, size = p.Position, p.Duration or 2.5, p.Size or 1.8
	local a = anchor(pos + Vector3.new(0, 0.2, 0), dur + 1.2)
	local f = fireEmitter(a, 22, size)
	local glow = disc(pos, size * 0.9, C(255, 120, 30), 0.45)
	if math.random() < 0.4 then
		light(pos + Vector3.new(0, 2, 0), C(255, 140, 50), 12, dur, 2)
	end
	task.delay(dur, function()
		f.Enabled = false
		tween(glow, 0.5, { Transparency = 1, Color = C(40, 30, 25) })
	end)
	Debris:AddItem(glow, dur + 0.6)
end

-- Anel fechado: as chamas sobem juntas em volta do inimigo
function H.FireRing(p)
	local pos, r, dur = p.Position, p.Radius or 8, p.Duration or 2
	local n = math.max(8, math.floor(r * 2.2 * (0.45 + 0.55 * quality())))
	local list = {}
	for i = 1, n do
		local a = i / n * math.pi * 2
		local at = anchor(pos + Vector3.new(math.cos(a) * r, 0.3, math.sin(a) * r), dur + 1.2)
		local e = fireEmitter(at, 18, 2.6, C(255, 110, 30))
		e.Speed = NumberRange.new(6, 12)
		table.insert(list, e)
	end
	groundRing(pos, r, r, C(255, 120, 30), dur, { Thick = 1.2, Height = 0.2, Transparency = 0.3 })
	local glow = disc(pos, r + 1, C(255, 90, 20), 0.75)
	light(pos + Vector3.new(0, 3, 0), C(255, 120, 40), r * 2.5, dur, 3)
	task.delay(dur, function()
		for _, e in ipairs(list) do
			e.Enabled = false
		end
		tween(glow, 0.5, { Transparency = 1 })
	end)
	Debris:AddItem(glow, dur + 0.6)
end

-- Chão pegando fogo embaixo do cachorro (rosnado do Inferno)
function H.Ignite(p)
	local pos, r, dur = p.Position, p.Radius or 4, p.Duration or 1.2
	local glow = disc(pos, 0.3, C(255, 110, 30), 0.35)
	animate(0.35, function(k)
		setDiscRadius(glow, r * outCubic(k))
	end)
	local n = q(6)
	for i = 1, n do
		local a = i / n * math.pi * 2
		local at = anchor(pos + Vector3.new(math.cos(a) * r * 0.6, 0.2, math.sin(a) * r * 0.6), dur + 1)
		local e = fireEmitter(at, 14, 1.6)
		task.delay(dur, function()
			e.Enabled = false
		end)
	end
	local sparks = embers(anchor(pos, dur + 1.5), 20)
	task.delay(dur, function()
		sparks.Enabled = false
	end)
	light(pos + Vector3.new(0, 2, 0), C(255, 120, 40), 14, dur, 3)
	task.delay(dur, function()
		tween(glow, 0.4, { Transparency = 1 })
	end)
	Debris:AddItem(glow, dur + 0.5)
	cracks(pos, r, C(255, 120, 40), 5, dur, true)
end

-- Fogo preso ao corpo (queimando)
function H.Burn(p)
	local root = rootOf(p.Model)
	if not root then
		return
	end
	local dur = p.Duration or 1.5
	local torso = p.Model:FindFirstChild("Torso") or root
	local f = fireEmitter(torso, 25, math.max(1.2, torso.Size.X * 0.7))
	f.Shape = Enum.ParticleEmitterShape.Box
	local e = embers(torso, 12)
	task.delay(dur, function()
		f.Enabled = false
		e.Enabled = false
	end)
	Debris:AddItem(f, dur + 1)
	Debris:AddItem(e, dur + 1.3)
end

-- Bafo de fogo em cone (Dragon Breath / Fire Bite) + chão chamuscado no caminho
function H.Cone(p)
	local head = headOf(p.Model, p.Head)
	if not head then
		return
	end
	local fire = p.Kind == "fire"
	local color = p.Color or C(255, 120, 30)
	local att = Instance.new("Attachment")
	att.Parent = head
	att.CFrame = CFrame.new(0, -head.Size.Y * 0.15, -head.Size.Z * 0.6)
	local len = p.Length or 20
	local main = emitter(att, {
		Texture = fire and TEX.Fire or TEX.Sparkle,
		Color = CS(0, C(255, 250, 200), 0.25, color:Lerp(WHITE, 0.2), 0.7, color, 1, C(90, 20, 10)),
		LightEmission = 1,
		Size = NS(0, 0.8, 0.4, 3.5, 1, 6),
		Transparency = NS(0, 0.15, 0.7, 0.3, 1, 1),
		Lifetime = NumberRange.new(len / 48, len / 36),
		Speed = NumberRange.new(36, 48),
		SpreadAngle = Vector2.new((p.Angle or 25) * 0.6, (p.Angle or 25) * 0.6),
		EmissionDirection = Enum.NormalId.Front,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-180, 180),
		Rate = 110 * quality(),
		Enabled = true,
		Drag = 1,
	})
	local sparks = emitter(att, {
		Texture = TEX.Spark,
		Color = ColorSequence.new(C(255, 220, 120)),
		LightEmission = 1,
		Size = NS(0, 0.4, 1, 0),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(30, 45),
		SpreadAngle = Vector2.new(p.Angle or 25, p.Angle or 25),
		EmissionDirection = Enum.NormalId.Front,
		Acceleration = Vector3.new(0, -10, 0),
		Rate = 40 * quality(),
		Enabled = true,
	})
	local smoke = emitter(att, {
		Texture = TEX.Smoke,
		Color = ColorSequence.new(C(60, 50, 50)),
		LightEmission = 0,
		Size = NS(0, 2, 1, 7),
		Transparency = NS(0, 0.8, 0.4, 0.65, 1, 1),
		Lifetime = NumberRange.new(0.8, 1.2),
		Speed = NumberRange.new(20, 26),
		SpreadAngle = Vector2.new(20, 20),
		EmissionDirection = Enum.NormalId.Front,
		Acceleration = Vector3.new(0, 6, 0),
		Rate = 14 * quality(),
		Enabled = true,
	})
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = 22
	l.Brightness = 4
	l.Shadows = false
	l.Parent = att
	local dur = p.Duration or 1
	local nextMark = 0
	animate(dur, function(_, t)
		if not head.Parent then
			return true
		end
		l.Brightness = 3.5 + math.sin(t * 30) * 1
		if t >= nextMark and fire then
			nextMark = t + 0.18
			local look = flat(head.CFrame.LookVector)
			if look.Magnitude > 0.1 then
				local feet = feetOf(p.Model)
				if feet then
					local at = feet + look.Unit * rnd(len * 0.35, len * 0.8) + Vector3.new(rnd(-2, 2), 0, rnd(-2, 2))
					scorch(at, rnd(1.2, 2.2), C(35, 22, 18), 1.5)
					if math.random() < 0.5 then
						H.FireSpot({ Position = at, Duration = 0.9, Size = 1.2 })
					end
				end
			end
		end
		return nil
	end, function()
		main.Enabled = false
		sparks.Enabled = false
		smoke.Enabled = false
		l.Enabled = false
	end)
	Debris:AddItem(att, dur + 1.5)
end

-- Golpe de cauda: arco laranja varrendo 360° em volta do corpo + poeira
function H.TailSwipe(p)
	local root = rootOf(p.Model)
	if not root then
		return
	end
	local feet = feetOf(p.Model) or root.Position
	local r = p.Radius or 10
	local color = p.Color or C(255, 140, 60)
	local n = math.max(8, math.floor(16 * (0.5 + 0.5 * quality())))
	local segs = ringParts(n, color)
	local cf0 = CFrame.new(feet + Vector3.new(0, root.Size.Y * 0.5 + 0.5, 0))
	animate(0.4, function(k)
		local sweep = math.min(1, k / 0.6) * math.pi * 2
		local arc = 2 * math.pi * r * 0.8 / n * 1.15
		for i, s in ipairs(segs) do
			local a = i / n * math.pi * 2
			local shown = a <= sweep
			s.Size = Vector3.new(0.6, 1.2 * (1 - k * 0.5), arc)
			s.CFrame = cf0 * CFrame.Angles(0, -a + math.pi, 0) * CFrame.new(r * 0.8, 0, 0)
			local age = (sweep - a) / (math.pi * 2)
			s.Transparency = shown and math.clamp(0.1 + age * 1.6 + math.max(0, k - 0.6) * 2, 0, 1) or 1
		end
	end, function()
		for _, s in ipairs(segs) do
			s:Destroy()
		end
	end)
	dust(feet, C(170, 150, 120), 14, 2.5, 18)
	groundRing(feet, 1, r, color, 0.4, { Thick = 0.6 })
end

-- Explosão: núcleo, bola de fogo, fumaça, brasas, anel, luz, cratera (resíduo), tremor por raio
function H.Explosion(p)
	local pos = p.Position
	local color = p.Color or C(255, 120, 30)
	local r = p.Radius or 10
	local water = p.Kind == "water"
	local void = p.Kind == "void"
	flashBall(pos, r * 0.5, WHITE, 0.15)
	local ball = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = CFrame.new(pos), Color = color, Transparency = 0.1 })
	animate(0.4, function(k)
		local e = outCubic(k)
		ball.Size = Vector3.one * (2 + (r * 2 - 2) * e)
		ball.Transparency = 0.1 + 0.9 * k ^ 0.8
	end, function()
		ball:Destroy()
	end)
	if water then
		burst(pos, C(200, 235, 255), 40, 1.2, 40, TEX.Sparkle, { Acceleration = Vector3.new(0, -50, 0), Drag = 1 })
		burst(pos, C(230, 245, 255), 18, 3, 16, TEX.Smoke, { LightEmission = 0.3, Size = NS(0, 2, 1, 5) })
	elseif void then
		burst(pos, color, 40, 1.4, 45, TEX.Sparkle)
		burst(pos, C(30, 0, 60), 20, 5, 18, TEX.Smoke, { LightEmission = 0, Size = NS(0, 3, 1, 7) })
	else
		burst(pos, CS(0, C(255, 250, 200), 0.4, color, 1, C(120, 30, 10)), 30, 3.5, 30, TEX.Fire, {
			Size = NS(0, 2.5, 1, 5),
			Lifetime = NumberRange.new(0.4, 0.8),
			LightEmission = 1,
		})
		burst(pos, C(70, 60, 60), 18, 5, 14, TEX.Smoke, {
			LightEmission = 0,
			Size = NS(0, 3, 1, 8),
			Transparency = NS(0, 0.3, 1, 1),
			Lifetime = NumberRange.new(1, 1.8),
			Acceleration = Vector3.new(0, 4, 0),
		})
		burst(pos, C(255, 190, 80), 24, 0.5, 45, TEX.Spark, { Acceleration = Vector3.new(0, -40, 0), Drag = 1, Lifetime = NumberRange.new(0.6, 1.2) })
	end
	light(pos, color, r * 3, 0.7, 7)
	groundRing(pos - Vector3.new(0, 0.9, 0), 1, r * 1.35, color, 0.5, { Thick = math.max(0.6, r * 0.08), Height = 0.8 })
	if not water then
		scorch(pos - Vector3.new(0, 0.9, 0), r * 0.55, void and C(30, 10, 50) or C(30, 22, 20), 2.5)
		cracks(pos - Vector3.new(0, 0.9, 0), r * 0.8, void and color or C(255, 120, 40), 6, 1.5, true)
	end
	shakeAt(pos, math.clamp(r / 16, 0.25, 0.9), 40 + r * 3, 0.4)
end

-- Lava: poça que cresce com borda escura, bolhas estourando, brilho; vira crosta (resíduo)
function H.Lava(p)
	local pos, r, dur = p.Position, p.Radius or 8, p.Duration or 4
	local crust = disc(pos, 0.5, C(60, 25, 15), 0.05, Enum.Material.Basalt)
	local pool = disc(pos + Vector3.new(0, 0.03, 0), 0.4, C(255, 110, 20), 0.05)
	animate(0.6, function(k)
		local e = outCubic(k)
		setDiscRadius(crust, r * e + 0.6)
		setDiscRadius(pool, r * e)
	end)
	local glowPart = fxPart({ Size = Vector3.new(r * 1.6, 0.5, r * 1.6), CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)), Transparency = 1 })
	local f = emitter(glowPart, {
		Texture = TEX.Fire,
		Enabled = true,
		Rate = r * 2.5 * quality(),
		Color = CS(0, C(255, 220, 100), 1, C(255, 70, 20)),
		LightEmission = 1,
		Size = NS(0, 1.4, 1, 0),
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(15, 15),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
	})
	local pops = emitter(glowPart, {
		Texture = TEX.Spark,
		Enabled = true,
		Rate = r * 1.2 * quality(),
		Color = ColorSequence.new(C(255, 180, 60)),
		LightEmission = 1,
		Size = NS(0, 0.5, 1, 0),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -30, 0),
		Shape = Enum.ParticleEmitterShape.Box,
	})
	light(pos + Vector3.new(0, 3, 0), C(255, 110, 30), r * 2.5, dur, 3)
	animate(dur, function(_, t)
		pool.Color = C(255, 110, 20):Lerp(C(255, 170, 50), (math.sin(t * 4) + 1) * 0.5)
	end, function()
		f.Enabled = false
		pops.Enabled = false
		tween(pool, 0.8, { Transparency = 1, Color = C(80, 30, 20) })
		tween(crust, 1.6, { Transparency = 1 })
	end)
	Debris:AddItem(pool, dur + 0.9)
	Debris:AddItem(crust, dur + 1.7)
	Debris:AddItem(glowPart, dur + 1.2)
end

-- Rachaduras de lava ligando o boss às poças (aviso do Lava Floor)
function H.LavaCracks(p)
	local from = p.From
	for _, to in ipairs(p.Tos or {}) do
		local dir = flat(to - from)
		local len = dir.Magnitude
		if len > 1 then
			local steps = math.clamp(math.floor(len / 5), 2, 10)
			local last = from
			for i = 1, steps do
				local k = i / steps
				local point = from + dir * k + (i < steps and Vector3.new(rnd(-1.5, 1.5), 0, rnd(-1.5, 1.5)) or Vector3.zero)
				local a, b = last, point
				task.delay(k * 0.5, function()
					local l = (b - a).Magnitude
					local seg = fxPart({
						Size = Vector3.new(0.5, 0.1, l),
						CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0.08, -l / 2),
						Color = C(255, 120, 30),
						Transparency = 0.05,
					})
					burst(b + Vector3.new(0, 0.3, 0), C(255, 150, 50), 2, 0.5, 6, TEX.Spark)
					task.delay(p.Duration or 2, function()
						if seg.Parent then
							tween(seg, 0.6, { Transparency = 1, Color = C(60, 30, 20) })
						end
					end)
					Debris:AddItem(seg, (p.Duration or 2) + 0.7)
				end)
				last = point
			end
		end
	end
end

-- Meteoro/estrela: aviso que enche, pedra com rastro de fogo, explosão e cratera
function H.Meteor(p)
	local star = p.Kind == "star"
	local delay = p.Delay or 1
	local color = star and C(255, 240, 150) or C(255, 100, 30)
	H.Telegraph({ Position = p.Position, Radius = p.Radius, Duration = delay, Color = color })
	local size = star and 2 or 4.5
	local start = p.Position + Vector3.new(rnd(10, 20), 75, rnd(5, 15))
	local rock = fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		Color = star and C(255, 250, 200) or C(90, 40, 25),
		Material = star and Enum.Material.Neon or Enum.Material.Basalt,
		CFrame = CFrame.new(start),
	})
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, size * 0.4, 0)
	a0.Parent = rock
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -size * 0.4, 0)
	a1.Parent = rock
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Color = star and CS(0, WHITE, 1, color) or CS(0, C(255, 230, 150), 0.4, C(255, 120, 30), 1, C(80, 30, 20))
	tr.Transparency = NS(0, 0, 1, 1)
	tr.Lifetime = 0.35
	tr.LightEmission = 1
	tr.FaceCamera = true
	tr.WidthScale = NS(0, 1.4, 1, 0)
	tr.Parent = rock
	if star then
		emitter(rock, {
			Enabled = true,
			Rate = 30 * quality(),
			Color = ColorSequence.new(color),
			Size = NS(0, 0.8, 1, 0),
			Lifetime = NumberRange.new(0.3, 0.6),
			Speed = NumberRange.new(1, 3),
		})
	else
		fireEmitter(rock, 50, 3.5).SpreadAngle = Vector2.new(180, 180)
	end
	animate(delay, function(k)
		local e = k * k
		rock.CFrame = CFrame.new(start:Lerp(p.Position, e)) * CFrame.Angles(k * 8, k * 5, 0)
	end, function()
		rock:Destroy()
		H.Explosion({ Position = p.Position + Vector3.new(0, 1, 0), Radius = p.Radius, Color = color, Kind = star and "water" or nil })
		if star then
			burst(p.Position + Vector3.new(0, 1, 0), color, 20, 1, 20, TEX.Sparkle)
		else
			shards(p.Position + Vector3.new(0, 0.5, 0), C(70, 40, 30), 6, 28, 0.8, Enum.Material.Basalt)
			H.FireSpot({ Position = p.Position, Duration = 1.8, Size = 2 })
		end
	end)
end

---------------------------------------------------------------- água / mergulho
function H.Fin(p)
	local root = rootOf(p.Model)
	if not root then
		return
	end
	local feet = feetOf(p.Model) or root.Position
	local size = math.max(1, root.Size.Y * 0.6)
	local fin = fxPart({
		Shape = Enum.PartType.Wedge,
		Size = Vector3.new(0.35, 2.6 * size, 2.4 * size),
		Color = C(80, 120, 160),
		Material = Enum.Material.SmoothPlastic,
	})
	local dur = p.Duration or 0.25
	animate(dur, function(k)
		if not root.Parent then
			return true
		end
		local f = feetOf(p.Model) or feet
		fin.CFrame = CFrame.new(f + Vector3.new(0, 1.3 * size, 0)) * root.CFrame.Rotation * CFrame.Angles(0, math.pi, 0)
		fin.Transparency = k > 0.8 and (k - 0.8) / 0.2 or 0
		return nil
	end, function()
		fin:Destroy()
	end)
	burst(feet + Vector3.new(0, 0.5, 0), C(200, 230, 255), 6, 0.8, 10, TEX.Sparkle, { Acceleration = Vector3.new(0, -30, 0) })
	dust(feet, C(150, 125, 95), 3, 1.5, 5)
	if not crowded(4) then
		groundRing(feet, 0.5, 2.5 * size, C(170, 210, 240), 0.5, { Thick = 0.25, Height = 0.1, Segs = 10 })
	end
end

-- Gêiser de água (Shark Dive explode embaixo do alvo)
function H.Geyser(p)
	local pos, r = p.Position, p.Radius or 8
	H.Explosion({ Position = pos + Vector3.new(0, 1, 0), Radius = r, Color = C(90, 180, 255), Kind = "water" })
	local col = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, r * 0.9, r * 0.9),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C(150, 210, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.25,
	})
	animate(0.7, function(k)
		local h = 18 * math.sin(math.min(1, k * 1.4) * math.pi * 0.5) * (1 - math.max(0, k - 0.7) / 0.3 * 0.5)
		col.Size = Vector3.new(math.max(0.5, h), r * 0.9 * (1 - k * 0.5), r * 0.9 * (1 - k * 0.5))
		col.CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		col.Transparency = 0.25 + 0.75 * math.max(0, (k - 0.5) / 0.5)
	end, function()
		col:Destroy()
	end)
	burst(
		pos + Vector3.new(0, 14, 0),
		C(210, 240, 255),
		30,
		1.2,
		25,
		TEX.Sparkle,
		{ Acceleration = Vector3.new(0, -60, 0), Drag = 0.5, Lifetime = NumberRange.new(0.8, 1.3) }
	)
	local puddle = disc(pos, r * 0.7, C(120, 180, 230), 0.5, Enum.Material.Glass)
	task.delay(1.5, function()
		tween(puddle, 1, { Transparency = 1 })
	end)
	Debris:AddItem(puddle, 2.6)
end

---------------------------------------------------------------- ossos / bandagens / raio trator
function H.Projectile(p)
	local proj = Instance.new("Model")
	local parts = {}
	local color = C(245, 240, 225)
	if p.Kind == "bone" then
		local mid = fxPart({ Size = Vector3.new(1.8, 0.4, 0.4), Color = color, Material = Enum.Material.SmoothPlastic, Shape = Enum.PartType.Cylinder })
		table.insert(parts, { mid, CFrame.new() })
		for _, x in ipairs({ -0.9, 0.9 }) do
			for _, z in ipairs({ -0.2, 0.2 }) do
				local knob = fxPart({ Size = Vector3.one * 0.55, Shape = Enum.PartType.Ball, Color = color, Material = Enum.Material.SmoothPlastic })
				table.insert(parts, { knob, CFrame.new(x, 0, z) })
			end
		end
	else
		color = C(235, 220, 180)
		local strip = fxPart({ Size = Vector3.new(0.7, 0.1, 3.2), Color = color, Material = Enum.Material.Fabric })
		table.insert(parts, { strip, CFrame.new() })
	end
	for _, entry in ipairs(parts) do
		entry[1].Parent = proj
	end
	proj.Parent = folder
	local main = parts[1][1]
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0.9, 0, 0)
	a0.Parent = main
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(-0.9, 0, 0)
	a1.Parent = main
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Color = ColorSequence.new(color)
	tr.Transparency = NS(0, 0.4, 1, 1)
	tr.Lifetime = 0.2
	tr.Parent = main
	local dur = p.Duration or 0.35
	local from, to = p.From, p.To
	local side = flat(to - from)
	side = side.Magnitude > 0.1 and Vector3.new(-side.Z, 0, side.X).Unit or Vector3.new(1, 0, 0)
	local curve = p.Curve or 0
	local total = p.Return and dur * 2 or dur
	animate(total, function(_, t)
		local pos
		if t <= dur then
			local k = t / dur
			pos = from:Lerp(to, k) + side * math.sin(k * math.pi) * curve + Vector3.new(0, math.sin(k * math.pi) * 2, 0)
		else
			local k = (t - dur) / dur
			pos = to:Lerp(from, k) - side * math.sin(k * math.pi) * curve + Vector3.new(0, math.sin(k * math.pi) * 1.5, 0)
		end
		local cf = CFrame.new(pos) * CFrame.Angles(0, t * 25, p.Kind == "bone" and 0 or t * 6)
		for _, entry in ipairs(parts) do
			entry[1].CFrame = cf * entry[2]
		end
	end, function()
		proj:Destroy()
	end)
	if p.Kind == "bone" then
		task.delay(dur, function()
			burst(to, WHITE, 6, 0.7, 14, TEX.Spark)
		end)
	end
end

-- Raio trator: cone de luz verde, anéis subindo em volta do alvo, partículas sendo puxadas
function H.Tractor(p)
	local a, b = rootOf(p.From), rootOf(p.To)
	if not (a and b) then
		return
	end
	local color = p.Color or C(120, 255, 160)
	local dur = p.Duration or 1.2
	local beam = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 3, 3), Color = color, Transparency = 0.55 })
	local core = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 0.8, 0.8), Color = WHITE, Transparency = 0.2 })
	local ringsList = {}
	for i = 1, 3 do
		ringsList[i] = ringParts(12, color)
	end
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 14
	glow.Brightness = 3
	glow.Parent = b
	local pull = emitter(b, {
		Enabled = true,
		Rate = 30 * quality(),
		Color = ColorSequence.new(color),
		Size = NS(0, 0.5, 1, 0),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(4, 8),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, 15, 0),
		SpreadAngle = Vector2.new(40, 40),
	})
	animate(dur, function(_, t)
		if not (a.Parent and b.Parent) then
			return true
		end
		local head = headOf(p.From) or a
		local from = head.Position
		local len = (b.Position - from).Magnitude
		local w = 3 + math.sin(t * 20) * 0.3
		local cf = CFrame.lookAt(from, b.Position) * CFrame.new(0, 0, -len / 2) * CFrame.Angles(0, math.rad(90), 0)
		beam.Size = Vector3.new(len, w, w)
		beam.CFrame = cf
		core.Size = Vector3.new(len, 0.6, 0.6)
		core.CFrame = cf
		local r = math.max(b.Size.X, b.Size.Z) * 0.9 + 1
		for i, list in ipairs(ringsList) do
			local phase = (t * 0.8 + i / 3) % 1
			placeRing(
				list,
				CFrame.new(b.Position - Vector3.new(0, b.Size.Y, 0)) * CFrame.new(0, phase * b.Size.Y * 3, 0),
				r * (1 - phase * 0.3),
				0.25,
				0.2,
				t * 3,
				phase
			)
		end
		return nil
	end, function()
		beam:Destroy()
		core:Destroy()
		for _, list in ipairs(ringsList) do
			for _, s in ipairs(list) do
				s:Destroy()
			end
		end
		glow:Destroy()
		pull:Destroy()
	end)
end

---------------------------------------------------------------- velocidade
-- Estrondo sônico: anel vertical + flash
function H.SonicBoom(p)
	local pos = p.Position
	local color = p.Color or C(255, 230, 100)
	local d = flat(p.Direction or Vector3.new(0, 0, -1))
	d = d.Magnitude > 0.01 and d.Unit or Vector3.new(0, 0, -1)
	ringWave(CFrame.lookAt(pos, pos + d) * CFrame.Angles(math.rad(-90), 0, 0), 0.5, p.Radius or 6, WHITE, 0.3, { Thick = 0.3, Height = 0.3, Segs = 14 })
	ringWave(
		CFrame.lookAt(pos, pos + d) * CFrame.Angles(math.rad(-90), 0, 0),
		0.5,
		(p.Radius or 6) * 0.7,
		color,
		0.35,
		{ Thick = 0.4, Height = 0.6, Segs = 14, Rise = 2 }
	)
	flashBall(pos, 1.6, WHITE, 0.12)
	burst(pos, color, 8, 0.6, 26, TEX.Spark)
end

---------------------------------------------------------------- inferno / portal
-- Hell Gate: pentagrama giratório (dois anéis contrários + raios), poço escuro, fumaça vermelha subindo
function H.Circle(p)
	local pos, r, dur = p.Position, p.Radius or 12, p.Duration or 2
	local color = p.Color or C(200, 20, 60)
	if p.Kind ~= "hell" then
		H.Telegraph({ Position = pos, Radius = r, Duration = dur, Color = color })
		return
	end
	local pit = disc(pos, 0.5, C(10, 0, 5), 0.1, Enum.Material.SmoothPlastic)
	local glow = disc(pos + Vector3.new(0, 0.02, 0), 0.5, color, 0.6)
	local outer = ringParts(math.max(14, math.floor(28 * (0.5 + 0.5 * quality()))), color)
	local inner = ringParts(math.max(10, math.floor(20 * (0.5 + 0.5 * quality()))), C(255, 80, 60))
	local spokes = {}
	for i = 1, 5 do
		spokes[i] = fxPart({ Size = Vector3.new(0.3, 0.1, 1), Color = color, Transparency = 0.1 })
	end
	local smoke = anchor(pos + Vector3.new(0, 0.5, 0), dur + 3)
	local e = emitter(smoke, {
		Texture = TEX.Smoke,
		Enabled = true,
		Rate = 25 * quality(),
		LightEmission = 0.3,
		Color = CS(0, C(160, 0, 40), 1, C(30, 0, 10)),
		Size = NS(0, 2, 1, 6),
		Transparency = NS(0, 0.4, 1, 1),
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(4, 9),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top,
	})
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = r * 2
	l.Brightness = 0
	l.Parent = smoke
	animate(dur, function(k, t)
		local open = outCubic(math.min(1, t / 0.5))
		local close = k > 0.85 and (k - 0.85) / 0.15 or 0
		local cf = CFrame.new(pos + Vector3.new(0, 0.12, 0))
		setDiscRadius(pit, r * 0.8 * open)
		setDiscRadius(glow, r * open)
		pit.Transparency = 0.1 + 0.9 * close
		glow.Transparency = 0.6 + 0.4 * close + math.sin(t * 8) * 0.05
		placeRing(outer, cf, r * open, 0.5, 0.25, t * 0.8, 0.05 + 0.95 * close)
		placeRing(inner, cf, r * 0.62 * open, 0.35, 0.25, -t * 1.4, 0.05 + 0.95 * close)
		-- pentagrama (5 linhas ligando pontas alternadas)
		for i, s in ipairs(spokes) do
			local a0 = (i / 5) * math.pi * 2 + t * 0.8
			local a1 = ((i + 2) / 5) * math.pi * 2 + t * 0.8
			local p0 = pos + Vector3.new(math.cos(a0), 0, math.sin(a0)) * r * 0.95 * open + Vector3.new(0, 0.14, 0)
			local p1 = pos + Vector3.new(math.cos(a1), 0, math.sin(a1)) * r * 0.95 * open + Vector3.new(0, 0.14, 0)
			local len = (p1 - p0).Magnitude
			s.Size = Vector3.new(0.3, 0.1, math.max(0.1, len))
			s.CFrame = CFrame.lookAt(p0, p1 + Vector3.new(0, 0.001, 0)) * CFrame.new(0, 0, -len / 2)
			s.Transparency = 0.1 + 0.9 * close
		end
		l.Brightness = 3 * open * (1 - close)
	end, function()
		pit:Destroy()
		glow:Destroy()
		for _, s in ipairs(outer) do
			s:Destroy()
		end
		for _, s in ipairs(inner) do
			s:Destroy()
		end
		for _, s in ipairs(spokes) do
			s:Destroy()
		end
		e.Enabled = false
	end)
end

-- Cabeça espectral saindo do portal e mordendo o alvo (Hell Gate)
function H.SpectralBite(p)
	local from, to = p.From, p.To
	local color = p.Color or C(255, 50, 90)
	local skull = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.2, 3), Color = C(40, 0, 15), Transparency = 0.2 })
	local eyeL = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, Color = color })
	local eyeR = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, Color = color })
	local att = Instance.new("Attachment")
	att.Parent = skull
	local trail = emitter(att, {
		Texture = TEX.Smoke,
		Enabled = true,
		Rate = 40 * quality(),
		LightEmission = 0.4,
		Color = CS(0, color, 1, C(20, 0, 10)),
		Size = NS(0, 1.6, 1, 0.3),
		Transparency = NS(0, 0.3, 1, 1),
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(0, 1),
	})
	local dur = 0.35
	animate(dur, function(k)
		local pos = from:Lerp(to, outCubic(k)) + Vector3.new(0, math.sin(k * math.pi) * 3, 0)
		local cf = CFrame.lookAt(pos, to + Vector3.new(0, 0.001, 0))
		skull.CFrame = cf
		eyeL.CFrame = cf * CFrame.new(-0.6, 0.4, -1.2)
		eyeR.CFrame = cf * CFrame.new(0.6, 0.4, -1.2)
	end, function()
		trail.Enabled = false
		Debris:AddItem(skull, 0.5)
		skull.Transparency = 1
		eyeL:Destroy()
		eyeR:Destroy()
		H.BiteMark({ Position = to, Direction = to - from, Color = color, Big = p.Big })
		burst(to, C(40, 0, 20), 10, 2, 8, TEX.Smoke, { LightEmission = 0 })
	end)
end

---------------------------------------------------------------- titã
-- Ao crescer: poeira em anel nos pés, brilho dourado no corpo
function H.TitanGrow(p)
	local model = p.Model
	local root = rootOf(model)
	if not root then
		return
	end
	local feet = feetOf(model) or root.Position
	local size = model:GetExtentsSize()
	dust(feet, C(180, 160, 130), 18, 2 + size.X * 0.2, 16 + size.X)
	groundRing(feet, size.X * 0.4, size.X * 0.9 + 6, C(255, 210, 120), 0.45, { Thick = 0.8, Height = 0.8 })
	burst(root.Position, C(255, 220, 140), 14, 1.2, 14, TEX.Glow)
	if highlightCount < 6 then
		highlightCount += 1
		local hl = Instance.new("Highlight")
		hl.FillColor = C(255, 200, 90)
		hl.FillTransparency = 0.45
		hl.OutlineColor = C(255, 230, 160)
		hl.OutlineTransparency = 0.2
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = model
		tween(hl, 0.35, { FillTransparency = 1, OutlineTransparency = 1 })
		task.delay(0.36, function()
			highlightCount -= 1
			hl:Destroy()
		end)
	end
end

-- Enquanto furioso: vapor/brasas saindo do corpo, cada passada levanta poeira e treme o chão
function H.TitanAura(p)
	local model = p.Model
	local root = rootOf(model)
	if not root then
		return
	end
	local torso = model:FindFirstChild("Torso") or root
	local dur = p.Duration or 8
	local heat = emitter(torso, {
		Texture = TEX.Smoke,
		Enabled = true,
		Rate = 14 * quality(),
		LightEmission = 0.5,
		Color = CS(0, C(255, 190, 90), 1, C(120, 60, 30)),
		Size = NS(0, 1.5, 1, 5),
		Transparency = NS(0, 0.65, 1, 1),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(3, 6),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
		Acceleration = Vector3.new(0, 4, 0),
	})
	local sparks = embers(torso, 18, C(255, 200, 90))
	sparks.Shape = Enum.ParticleEmitterShape.Box
	local nextStep = 0
	animate(dur + 1, function(_, t)
		if not (root.Parent and model.Parent) then
			return true
		end
		if t > 0.5 and model:GetAttribute("Raging") ~= true then
			return true
		end
		local v = flat(root.AssemblyLinearVelocity).Magnitude
		if v > 3 and t >= nextStep then
			nextStep = t + 0.42
			local feet = feetOf(model)
			if feet then
				dust(feet, C(170, 150, 120), 6, 2.5, 10)
				if not crowded(3) then
					groundRing(feet, 1, root.Size.X * 1.4 + 3, C(220, 190, 140), 0.3, { Thick = 0.4, Height = 0.2, Segs = 10 })
				end
				shakeAt(feet, 0.12, 40, 0.15)
			end
		end
		return nil
	end, function()
		heat.Enabled = false
		sparks.Enabled = false
		Debris:AddItem(heat, 1.5)
		Debris:AddItem(sparks, 1.5)
	end)
end

---------------------------------------------------------------- fênix / vazio
-- Asas de fogo + rastro enquanto sobe
function H.PhoenixRise(p)
	local model = p.Model
	local root = rootOf(model)
	if not root then
		return
	end
	local dur = p.Duration or 1.2
	local list = {}
	local wings = partsNamed(model, function(n)
		return n == "AsaMembrana"
	end)
	local hosts = #wings > 0 and wings or { model:FindFirstChild("Torso") or root }
	for _, w in ipairs(hosts) do
		local f = fireEmitter(w, 40, 2.4)
		f.Shape = Enum.ParticleEmitterShape.Box
		f.SpreadAngle = Vector2.new(60, 60)
		table.insert(list, f)
	end
	table.insert(list, embers(root, 30))
	H.Streak({ Model = model, Color = C(255, 140, 30), Duration = dur, Width = 2.5, Neon = true, Lifetime = 0.45 })
	local feet = feetOf(model) or root.Position
	H.Ignite({ Position = feet, Radius = 5, Duration = 1 })
	light(root.Position, C(255, 150, 50), 24, dur, 4)
	task.delay(dur, function()
		for _, e in ipairs(list) do
			e.Enabled = false
			Debris:AddItem(e, 1.2)
		end
	end)
end

-- Fenda do vazio: disco escuro com braços espirais girando, partículas sugadas, núcleo pulsando
function H.Vortex(p)
	local pos, r, dur = p.Position, p.Radius or 18, p.Duration or 2
	local color = C(170, 90, 255)
	local base = disc(pos, 0.5, C(15, 0, 30), 0.15, Enum.Material.SmoothPlastic)
	local core = fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one,
		CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)),
		Color = C(10, 0, 20),
		Material = Enum.Material.SmoothPlastic,
	})
	local halo = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)), Color = color, Transparency = 0.6 })
	local arms = {}
	local nArms, perArm = 4, math.max(4, math.floor(9 * (0.5 + 0.5 * quality())))
	for a = 1, nArms do
		for i = 1, perArm do
			table.insert(arms, { fxPart({ Size = Vector3.new(0.4, 0.15, 1.5), Color = i % 2 == 0 and color or C(220, 170, 255), Transparency = 0.2 }), a, i })
		end
	end
	local sucker = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, r * 2, r * 2),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Transparency = 1,
	})
	local e = emitter(sucker, {
		Enabled = true,
		Rate = 70 * quality(),
		Color = CS(0, C(230, 200, 255), 1, color),
		Size = NS(0, 0.9, 1, 0),
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(-26, -18),
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
	})
	local swirl = anchor(pos + Vector3.new(0, 2, 0), dur + 2)
	local sw = emitter(swirl, {
		Texture = TEX.Swirl,
		Enabled = true,
		Rate = 6 * quality(),
		LightEmission = 1,
		Color = ColorSequence.new(color),
		Size = NS(0, r * 0.9, 1, 1),
		Transparency = NS(0, 0.6, 1, 1),
		Lifetime = NumberRange.new(0.8, 1),
		Speed = NumberRange.new(0, 0),
		RotSpeed = NumberRange.new(200, 300),
		Rotation = NumberRange.new(0, 360),
	})
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = r * 1.5
	l.Brightness = 3
	l.Parent = swirl
	animate(dur, function(k, t)
		local open = outCubic(math.min(1, t / 0.4))
		setDiscRadius(base, r * open)
		local cs = 3 + 2.5 * k + math.sin(t * 12) * 0.3
		core.Size = Vector3.one * cs
		halo.Size = Vector3.one * (cs * 1.5)
		for _, entry in ipairs(arms) do
			local part, a, i = entry[1], entry[2], entry[3]
			local u = i / perArm
			local rr = r * open * (1 - u * 0.85)
			local ang = a / nArms * math.pi * 2 + u * 2.6 + t * (3 + 2 * k)
			local at = pos + Vector3.new(math.cos(ang) * rr, 0.2 + u * 0.8, math.sin(ang) * rr)
			local tangent = Vector3.new(-math.sin(ang), 0, math.cos(ang))
			part.CFrame = CFrame.lookAt(at, at + tangent)
			part.Size = Vector3.new(0.5 * (1 - u * 0.5), 0.15, 2.2 * (1 - u * 0.5) * open + 0.1)
		end
	end, function()
		e.Enabled = false
		sw.Enabled = false
		l.Enabled = false
		tween(base, 0.3, { Transparency = 1 })
		Debris:AddItem(base, 0.35)
		core:Destroy()
		halo:Destroy()
		sucker:Destroy()
		for _, entry in ipairs(arms) do
			entry[1]:Destroy()
		end
	end)
end

function Effects.Start()
	-- Pacotes extras: cada ModuleScript em Client/EffectsPacks retorna function(H, Effects)
	-- que adiciona handlers novos (H.MeuEfeito = function(params) ... end).
	local packs = script.Parent:FindFirstChild("EffectsPacks")
	if packs then
		for _, module in ipairs(packs:GetChildren()) do
			if module:IsA("ModuleScript") then
				local ok, err = pcall(function()
					require(module)(H, Effects)
				end)
				if not ok then
					warn("[Effects] pacote falhou", module.Name, err)
				end
			end
		end
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes.Effect.OnClientEvent:Connect(function(name, params)
		local handler = H[name]
		if handler and type(params) == "table" then
			local ok, err = pcall(handler, params)
			if not ok then
				warn("[Effects]", name, err)
			end
		end
	end)
end

return Effects
