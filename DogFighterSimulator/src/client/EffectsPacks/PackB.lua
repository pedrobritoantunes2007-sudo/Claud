-- Efeitos do Pacote B (poderes "B_*" dos Épicos/Lendários de DogPacks/PackB).
-- Mesma linguagem visual do Effects.lua: AVISO → IMPACTO → RESÍDUO. Só texturas rbxasset:// nativas;
-- tudo vai para workspace.FX com Debris/limpeza no fim da animação; a quantidade de partículas e
-- peças segue a qualidade gráfica do jogador (atributo "GraphicsQuality": Alto / Médio / Baixo).
-- Reaproveita handlers prontos (H.Impact, H.Explosion, H.Shockwave...) quando faz sentido.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TEX = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Spark = "rbxasset://textures/particles/fire_sparks_main.dds",
	Glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
}

local C = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local PI = math.pi

return function(H, Effects)
	local player = Players.LocalPlayer
	local folder = workspace:FindFirstChild("FX")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "FX"
		folder.Parent = workspace
	end

	------------------------------------------------------------ utilidades
	local QUALITY = { Alto = 1, ["Médio"] = 0.6, Baixo = 0.3 }
	local function quality(): number
		return QUALITY[player:GetAttribute("GraphicsQuality")] or 1
	end
	local function q(n: number): number
		return math.max(1, math.floor(n * quality() + 0.5))
	end
	-- muitas peças no FX: pula os detalhes decorativos
	local function crowded(): boolean
		return #folder:GetChildren() > 450 * (0.35 + 0.65 * quality())
	end

	local function NS(...)
		local a = { ... }
		local kps = {}
		for i = 1, #a, 2 do
			table.insert(kps, NumberSequenceKeypoint.new(a[i], a[i + 1]))
		end
		return NumberSequence.new(kps)
	end

	local function rnd(a: number, b: number): number
		return a + math.random() * (b - a)
	end

	local function part(props)
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
			(p :: any)[k] = v
		end
		p.Parent = folder
		return p
	end

	local function ball(size: Vector3, color: Color3, material: Enum.Material?, transparency: number?)
		return part({ Shape = Enum.PartType.Ball, Size = size, Color = color, Material = material or Enum.Material.Neon, Transparency = transparency or 0 })
	end

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
			if k >= 1 or stop == true or not ok then
				anims[i] = anims[#anims]
				anims[#anims] = nil
				if not ok then
					warn("[EffectsB] anim", stop)
				end
				if a.Done then
					pcall(a.Done)
				end
			end
		end
	end)

	-- destrói uma lista de peças
	local function clean(list)
		return function()
			for _, p in ipairs(list) do
				p:Destroy()
			end
		end
	end

	local function anchor(position: Vector3, life: number)
		local a = Instance.new("Attachment")
		a.Position = position
		a.Parent = workspace.Terrain
		Debris:AddItem(a, life)
		return a
	end

	local function burst(position: Vector3, color: Color3, count: number, size: number, speed: number, texture: string?, extra: { [string]: any }?)
		local e = Instance.new("ParticleEmitter")
		e.Texture = texture or TEX.Sparkle
		e.Color = ColorSequence.new(color)
		e.LightEmission = 0.8
		e.Size = NS(0, size, 1, 0)
		e.Transparency = NS(0, 0, 0.7, 0.3, 1, 1)
		e.Lifetime = NumberRange.new(0.35, 0.8)
		e.Speed = NumberRange.new(speed * 0.4, speed)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 4
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-120, 120)
		e.Enabled = false
		for k, v in pairs(extra or {}) do
			(e :: any)[k] = v
		end
		e.Parent = anchor(position, 3)
		e:Emit(q(count))
	end

	local function smoke(position: Vector3, color: Color3, count: number, size: number, speed: number)
		burst(position, color, count, size, speed, TEX.Smoke, {
			Size = NS(0, size * 0.5, 1, size * 1.6),
			Transparency = NS(0, 0.35, 1, 1),
			Lifetime = NumberRange.new(0.7, 1.3),
			LightEmission = 0,
			Drag = 3,
			Acceleration = Vector3.new(0, 2, 0),
		})
	end

	local lights = 0
	local function light(position: Vector3, color: Color3, range: number, duration: number)
		if lights >= 3 + 6 * quality() then
			return
		end
		lights += 1
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = math.min(range, 60)
		l.Brightness = 4
		l.Shadows = false
		l.Parent = anchor(position, duration + 0.1)
		animate(duration, function(k)
			l.Brightness = 4 * (1 - k)
		end, function()
			lights -= 1
		end)
	end

	-- disco fino no chão
	local function disc(position: Vector3, radius: number, color: Color3, transparency: number, material: Enum.Material?)
		return part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, radius * 2, radius * 2),
			CFrame = CFrame.new(position + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, PI / 2),
			Color = color,
			Transparency = transparency,
			Material = material or Enum.Material.Neon,
		})
	end

	-- anel que expande no chão (ou em qualquer plano: cf)
	local function ring(cf: CFrame, r0: number, r1: number, color: Color3, duration: number, thick: number?)
		local n = math.max(10, math.floor(20 * (0.5 + 0.5 * quality())))
		local list = {}
		for _ = 1, n do
			table.insert(list, part({ Size = Vector3.new(0.4, 0.4, 1), Color = color }))
		end
		local th = thick or 0.6
		animate(duration, function(k)
			local e = 1 - (1 - k) ^ 3
			local r = r0 + (r1 - r0) * e
			local arc = 2 * PI * r / n * 1.12
			for i, p in ipairs(list) do
				p.Size = Vector3.new(th * (1 - 0.7 * k), th * 0.6, math.max(0.05, arc))
				p.CFrame = cf * CFrame.Angles(0, i / n * PI * 2, 0) * CFrame.new(r, 0, 0)
				p.Transparency = k ^ 1.3
			end
		end, clean(list))
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

	-- primeira peça do modelo com esse nome (ou a raiz)
	local function partOf(model, name: string)
		local p = model and model:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			return p
		end
		return rootOf(model)
	end

	-- objeto voando em arco de `from` até `to`; parts = { {peça, offset CFrame} }
	local function fly(parts, from: Vector3, to: Vector3, duration: number, height: number, spin: number?, done)
		animate(duration, function(k)
			local p = from:Lerp(to, k) + Vector3.new(0, math.sin(k * PI) * height, 0)
			local ahead = from:Lerp(to, math.min(1, k + 0.05)) + Vector3.new(0, math.sin(math.min(1, k + 0.05) * PI) * height, 0)
			local cf = (ahead - p).Magnitude > 0.01 and CFrame.lookAt(p, ahead) or CFrame.new(p)
			cf *= CFrame.Angles(0, 0, (spin or 0) * k)
			for _, e in ipairs(parts) do
				e[1].CFrame = cf * e[2]
			end
		end, function()
			for _, e in ipairs(parts) do
				e[1]:Destroy()
			end
			if done then
				done()
			end
		end)
	end

	-- rastro (Trail) preso a uma peça de efeito
	local function trail(p: BasePart, color: Color3, width: number, life: number, smokeLike: boolean?)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, width / 2, 0)
		a0.Parent = p
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -width / 2, 0)
		a1.Parent = p
		local tr = Instance.new("Trail")
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Color = ColorSequence.new(color)
		tr.Transparency = NS(0, smokeLike and 0.4 or 0.1, 1, 1)
		tr.Lifetime = life
		tr.LightEmission = smokeLike and 0 or 1
		tr.FaceCamera = true
		tr.Texture = smokeLike and TEX.Smoke or ""
		tr.Parent = p
		return tr
	end

	-- marca no chão que some devagar (resíduo)
	local function residue(position: Vector3, radius: number, color: Color3, duration: number, material: Enum.Material?, transparency: number?)
		if crowded() then
			return nil
		end
		local d = disc(position + Vector3.new(0, 0.03, 0), radius, color, transparency or 0.35, material or Enum.Material.SmoothPlastic)
		local t0 = d.Transparency
		animate(duration + 0.8, function(_, t)
			if t > duration then
				d.Transparency = t0 + (1 - t0) * ((t - duration) / 0.8)
			end
		end, function()
			d:Destroy()
		end)
		return d
	end

	-- três riscos paralelos (garrada)
	local function clawMarks(position: Vector3, direction: Vector3, color: Color3, size: number, tiltZ: number)
		local d = Vector3.new(direction.X, 0, direction.Z)
		if d.Magnitude < 0.01 then
			d = Vector3.new(0, 0, -1)
		end
		local base = CFrame.lookAt(position, position + d.Unit) * CFrame.Angles(0, 0, tiltZ)
		for i = -1, 1 do
			local p = part({ Size = Vector3.new(0.25, size, 0.25), Color = color, Transparency = 0.05 })
			local cf = base * CFrame.new(i * size * 0.18, 0, -1)
			animate(0.35, function(k)
				local e = math.min(1, k * 3)
				p.Size = Vector3.new(0.25 * (1 - 0.6 * k), size * e, 0.25)
				p.CFrame = cf * CFrame.new(0, size * (0.5 - e * 0.5), 0)
				p.Transparency = k > 0.5 and (k - 0.5) * 2 or 0.05
			end, function()
				p:Destroy()
			end)
		end
		burst(position, color, 10, 0.5, 18, TEX.Spark, { Lifetime = NumberRange.new(0.2, 0.4) })
	end

	-- emissor contínuo preso a uma peça por um tempo
	local function attachEmitter(parentPart: BasePart, duration: number, props: { [string]: any })
		local e = Instance.new("ParticleEmitter")
		e.Texture = TEX.Sparkle
		e.LightEmission = 0.6
		for k, v in pairs(props) do
			(e :: any)[k] = v
		end
		e.Rate = (props.Rate or 10) * quality()
		e.Parent = parentPart
		task.delay(duration, function()
			e.Enabled = false
		end)
		Debris:AddItem(e, duration + 2)
		return e
	end

	------------------------------------------------------------ PIRATA
	-- âncora girando acima da cabeça (aviso)
	function H.B_AnchorSpin(p)
		local root = rootOf(p.Model)
		if not root then
			return
		end
		local dur = p.Duration or 0.7
		local s = root.Size.Y
		local shank = part({ Size = Vector3.new(0.35, 0.35, 2.6) * s * 0.5, Color = C(80, 82, 92), Material = Enum.Material.Metal })
		local arms = part({ Size = Vector3.new(1.8, 0.3, 0.3) * s * 0.5, Color = C(80, 82, 92), Material = Enum.Material.Metal })
		local list = { shank, arms }
		animate(dur, function(_, t)
			if not root.Parent then
				return true
			end
			local cf = root.CFrame * CFrame.new(0, s * 1.6, 0) * CFrame.Angles(0, t * 14, 0) * CFrame.new(0, 0, -s * 0.9) * CFrame.Angles(PI / 2, 0, 0)
			shank.CFrame = cf
			arms.CFrame = cf * CFrame.new(0, 0, s * 0.6)
			return nil
		end, clean(list))
		burst(root.Position + Vector3.new(0, s * 1.6, 0), C(200, 230, 255), 10, 0.5, 8)
	end

	-- âncora voa presa a uma corrente, crava no alvo e volta puxando
	function H.B_Anchor(p)
		local root, target = rootOf(p.Model), rootOf(p.Target)
		if not root or not target then
			return
		end
		local dur, travel = p.Duration or 1.2, p.Travel or 0.3
		local s = math.max(1, root.Size.Y * 0.6)
		local metal = C(80, 82, 92)
		local head = part({ Size = Vector3.new(0.4, 0.4, 2.2) * s, Color = metal, Material = Enum.Material.Metal })
		local arms = part({ Size = Vector3.new(1.6, 0.35, 0.35) * s, Color = metal, Material = Enum.Material.Metal })
		local links = {}
		for _ = 1, q(10) do
			table.insert(links, part({ Size = Vector3.new(0.18, 0.4, 0.6) * s, Color = C(150, 150, 160), Material = Enum.Material.Metal }))
		end
		local hit = false
		animate(dur, function(_, t)
			if not root.Parent then
				return true
			end
			local from = root.Position + Vector3.new(0, root.Size.Y * 0.6, 0)
			local tp = target.Parent and target.Position or from
			local k
			if t < travel then
				k = t / travel
			elseif t < dur - 0.25 then
				k = 1
			else
				k = math.max(0, 1 - (t - (dur - 0.25)) / 0.25)
			end
			if t >= travel and not hit then
				hit = true
				burst(tp, C(200, 230, 255), 16, 0.7, 20, TEX.Spark)
				Effects.Shake(0.15)
			end
			local tip = from:Lerp(tp, k) + Vector3.new(0, math.sin(k * PI) * 3 * (t < travel and 1 or 0), 0)
			local dir = (tip - from).Magnitude > 0.1 and (tip - from).Unit or root.CFrame.LookVector
			local cf = CFrame.lookAt(tip, tip + dir)
			head.CFrame = cf
			arms.CFrame = cf * CFrame.new(0, 0, -0.9 * s)
			for i, l in ipairs(links) do
				local u = i / (#links + 1)
				local pos = from:Lerp(tip, u) - Vector3.new(0, math.sin(u * PI) * 0.6, 0)
				l.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, 0, i % 2 == 0 and PI / 2 or 0)
			end
			return nil
		end, function()
			head:Destroy()
			arms:Destroy()
			clean(links)()
		end)
	end

	-- respingo de água e poça que fica
	function H.B_Splash(p)
		local pos, r = p.Position, p.Radius or 7
		local blue = C(90, 170, 255)
		burst(pos + Vector3.new(0, 1, 0), C(200, 235, 255), 26, 0.9, 30, TEX.Sparkle, {
			Acceleration = Vector3.new(0, -40, 0),
			Lifetime = NumberRange.new(0.6, 1),
			SpreadAngle = Vector2.new(35, 35),
			EmissionDirection = Enum.NormalId.Top,
			Drag = 0,
		})
		ring(CFrame.new(pos + Vector3.new(0, 0.2, 0)), 1, r, C(160, 210, 255), 0.5)
		local puddle = residue(pos, r * 0.6, blue, p.Duration or 3, Enum.Material.Glass, 0.3)
		if puddle then
			puddle.Reflectance = 0.3
		end
	end

	------------------------------------------------------------ ESCORPIÃO
	-- ferrão desce em arco da cauda até o alvo
	function H.B_Sting(p)
		local model = p.Model
		local tip = partOf(model, "Ferrao")
		if not tip then
			return
		end
		local color = p.Color or C(255, 170, 40)
		local from = tip.Position
		local to = p.To
		local spike = part({ Size = Vector3.new(0.3, 0.3, 1.4), Color = color })
		trail(spike, color, 0.5, 0.25)
		fly({ { spike, CFrame.new() } }, from, to, 0.14, 2, nil, function()
			burst(to, color, 14, 0.6, 18, TEX.Spark)
			ring(CFrame.new(to), 0.5, 3, color, 0.3, 0.3)
		end)
	end

	-- veneno: bolhas verdes subindo do corpo + brilho
	function H.B_Poison(p)
		local root = rootOf(p.Model)
		if not root then
			return
		end
		local dur = p.Duration or 4
		attachEmitter(root, dur, {
			Color = ColorSequence.new(C(170, 255, 60)),
			Size = NS(0, 0.4, 1, 0.1),
			Transparency = NS(0, 0.1, 1, 1),
			Lifetime = NumberRange.new(0.6, 1),
			Speed = NumberRange.new(1, 3),
			Acceleration = Vector3.new(0, 5, 0),
			SpreadAngle = Vector2.new(180, 180),
			Rate = 16,
			LightEmission = 1,
		})
		local h = Instance.new("Highlight")
		h.FillColor = C(140, 255, 60)
		h.FillTransparency = 0.7
		h.OutlineTransparency = 1
		h.Adornee = p.Model
		h.Parent = folder
		Debris:AddItem(h, dur)
	end

	------------------------------------------------------------ DIONEIA
	-- vinhas brotam do chão e se enrolam em volta do alvo
	function H.B_Vines(p)
		local pos = p.Position
		local dur = p.Duration or 2
		local size = (p.Model and p.Model.Parent) and p.Model:GetExtentsSize() or Vector3.new(4, 4, 4)
		local r = math.max(size.X, size.Z) * 0.55
		local h = size.Y * 0.9
		local green = C(70, 160, 50)
		local list = {}
		local n = q(6)
		for i = 1, n do
			local a0 = i / n * PI * 2
			local segs = {}
			for j = 1, 5 do
				local seg = part({ Size = Vector3.new(0.35, 0.35, 1), Color = j % 2 == 0 and green or C(95, 190, 60), Material = Enum.Material.Grass })
				table.insert(segs, seg)
				table.insert(list, seg)
			end
			local leaf = part({ Size = Vector3.new(0.1, 0.6, 0.9), Color = C(120, 210, 80), Material = Enum.Material.Grass })
			table.insert(list, leaf)
			animate(dur, function(k, t)
				local grow = math.min(1, t / 0.35)
				local fade = k > 0.85 and (k - 0.85) / 0.15 or 0
				local last = pos + Vector3.new(math.cos(a0), 0, math.sin(a0)) * (r + 1)
				for j, seg in ipairs(segs) do
					local u = j / #segs * grow
					local a = a0 + u * PI * 1.4
					local rr = r * (1 + 0.4 * (1 - u))
					local pt = pos + Vector3.new(math.cos(a) * rr, u * h, math.sin(a) * rr)
					local len = (pt - last).Magnitude
					seg.Size = Vector3.new(0.35, 0.35, math.max(0.1, len + 0.2))
					seg.CFrame = CFrame.lookAt(last, pt) * CFrame.new(0, 0, -len / 2)
					seg.Transparency = fade
					last = pt
				end
				leaf.CFrame = CFrame.new(last) * CFrame.Angles(0, a0, 0.6)
				leaf.Transparency = fade
			end)
		end
		animate(dur, function() end, clean(list))
		smoke(pos, C(110, 90, 60), 12, 2, 10)
		ring(CFrame.new(pos + Vector3.new(0, 0.2, 0)), 1, r + 3, C(120, 220, 80), 0.45)
	end

	-- poça de ácido borbulhando (resíduo)
	function H.B_Acid(p)
		local pos, r, dur = p.Position, p.Radius or 6, p.Duration or 3
		local pool = residue(pos, r, C(150, 230, 40), dur, Enum.Material.Neon, 0.45)
		burst(pos + Vector3.new(0, 0.5, 0), C(190, 255, 70), 20, 0.6, 14)
		if pool then
			local a = anchor(pos, dur + 1)
			local e = Instance.new("ParticleEmitter")
			e.Texture = TEX.Sparkle
			e.Color = ColorSequence.new(C(190, 255, 70))
			e.Size = NS(0, 0.5, 1, 0.1)
			e.Lifetime = NumberRange.new(0.5, 0.9)
			e.Speed = NumberRange.new(1, 3)
			e.Acceleration = Vector3.new(0, 4, 0)
			e.Shape = Enum.ParticleEmitterShape.Disc
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
			e.EmissionDirection = Enum.NormalId.Top
			e.Rate = 18 * quality()
			e.LightEmission = 1
			e.Parent = a
			task.delay(dur, function()
				e.Enabled = false
			end)
		end
	end

	-- atordoado: estrelinhas girando em cima da cabeça
	function H.B_Stun(p)
		local root = rootOf(p.Model)
		if not root then
			return
		end
		local dur = p.Duration or 1.2
		local size = p.Model:GetExtentsSize()
		local stars = {}
		for i = 1, 4 do
			table.insert(stars, part({ Size = Vector3.new(0.5, 0.5, 0.15), Color = i % 2 == 0 and C(255, 230, 90) or WHITE }))
		end
		animate(dur, function(k, t)
			if not root.Parent then
				return true
			end
			local c = root.Position + Vector3.new(0, size.Y * 0.6 + 0.6, 0)
			for i, s in ipairs(stars) do
				local a = t * 6 + i / #stars * PI * 2
				s.CFrame = CFrame.new(c + Vector3.new(math.cos(a), math.sin(t * 8 + i) * 0.15, math.sin(a)) * math.max(1.2, size.X * 0.35))
					* CFrame.Angles(0, -a, PI / 4)
				s.Transparency = k > 0.85 and (k - 0.85) / 0.15 or 0
			end
			return nil
		end, clean(stars))
	end

	------------------------------------------------------------ DJ
	-- batida: anel de som neon, caixas pulsando, notas subindo
	function H.B_Beat(p)
		local pos, r, color = p.Position, p.Radius or 10, p.Color or C(0, 240, 220)
		ring(CFrame.new(pos + Vector3.new(0, 0.3, 0)), 1, r, color, 0.4, 0.9)
		ring(CFrame.new(pos + Vector3.new(0, 1.5, 0)), 0.5, r * 0.7, WHITE, 0.35, 0.4)
		light(pos + Vector3.new(0, 3, 0), color, r * 2, 0.35)
		Effects.Shake(0.08)
		local model = p.Model
		if model and model.Parent then
			for _, d in ipairs(model:GetChildren()) do
				if d:IsA("BasePart") and (d.Name == "AltoLuz" or d.Name == "FoneLuz") then
					burst(d.Position, color, 4, 0.6, 10, TEX.Sparkle)
				end
			end
		end
		-- notas musicais (bolinha + haste)
		for _ = 1, q(3) do
			local a = math.random() * PI * 2
			local start = pos + Vector3.new(math.cos(a) * 3, 2, math.sin(a) * 3)
			local head = ball(Vector3.new(0.6, 0.45, 0.45), color)
			local stem = part({ Size = Vector3.new(0.12, 1.1, 0.12), Color = color })
			animate(0.9, function(k)
				local c = start + Vector3.new(0, k * 5, 0)
				head.CFrame = CFrame.new(c)
				stem.CFrame = CFrame.new(c + Vector3.new(0.25, 0.55, 0))
				head.Transparency = k
				stem.Transparency = k
			end, clean({ head, stem }))
		end
	end

	-- DROP: onda gigante, flash e pista de dança piscando no chão
	function H.B_Drop(p)
		local pos, r, dur = p.Position, p.Radius or 16, p.Duration or 2.5
		local cols = { C(0, 240, 220), C(255, 60, 200), C(255, 230, 60), C(120, 90, 255) }
		ring(CFrame.new(pos + Vector3.new(0, 0.4, 0)), 1, r, cols[1], 0.5, 1.4)
		ring(CFrame.new(pos + Vector3.new(0, 0.6, 0)), 1, r * 0.8, cols[2], 0.6, 1)
		ring(CFrame.new(pos + Vector3.new(0, 3, 0)), 1, r * 0.6, WHITE, 0.4, 0.5)
		burst(pos + Vector3.new(0, 1, 0), cols[2], 30, 1, 40, TEX.Spark)
		light(pos + Vector3.new(0, 4, 0), cols[1], 40, 0.6)
		if crowded() then
			return
		end
		local tiles = {}
		local n = math.floor(3 + 2 * quality())
		local step = r * 1.4 / (2 * n + 1)
		for x = -n, n do
			for z = -n, n do
				if x * x + z * z <= n * n then
					table.insert(
						tiles,
						part({
							Size = Vector3.new(step * 0.9, 0.1, step * 0.9),
							CFrame = CFrame.new(pos + Vector3.new(x * step, 0.1, z * step)),
							Color = cols[(x + z) % 4 + 1],
							Transparency = 0.4,
						})
					)
				end
			end
		end
		animate(dur, function(k, t)
			local beat = math.floor(t * 6)
			for i, tile in ipairs(tiles) do
				tile.Color = cols[(i + beat) % 4 + 1]
				tile.Transparency = 0.35 + 0.65 * k ^ 2
			end
		end, clean(tiles))
	end

	------------------------------------------------------------ CAVALEIRO
	-- escudo de luz dourada na frente do corpo
	function H.B_Shield(p)
		local root = rootOf(p.Model)
		if not root then
			return
		end
		local dur = p.Duration or 1.1
		local size = p.Model:GetExtentsSize()
		local s = math.max(size.Y, size.X) * 0.75
		local wall = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, s, s), Color = C(255, 215, 90), Transparency = 0.55 })
		local rim = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, s * 1.08, s * 1.08), Color = WHITE, Transparency = 0.7 })
		animate(dur, function(k, t)
			if not root.Parent then
				return true
			end
			local cf = root.CFrame * CFrame.new(0, size.Y * 0.1, -root.Size.Z * 0.75) * CFrame.Angles(0, PI / 2, 0)
			wall.CFrame = cf
			rim.CFrame = cf * CFrame.new(-0.05, 0, 0)
			wall.Transparency = 0.5 + 0.15 * math.sin(t * 20) + (k > 0.8 and (k - 0.8) * 2.5 or 0)
			rim.Transparency = 0.6 + (k > 0.8 and (k - 0.8) * 2 or 0)
			return nil
		end, clean({ wall, rim }))
		burst(root.Position, C(255, 230, 140), 16, 0.6, 10)
	end

	-- estocada: cone de luz saindo da lança
	function H.B_Thrust(p)
		local root = rootOf(p.Model)
		if not root then
			return
		end
		local tipPart = partOf(p.Model, "LancaPonta3")
		local from = (tipPart or root).Position
		local d = p.Direction or root.CFrame.LookVector
		local len, color = p.Length or 11, p.Color or WHITE
		local beam = part({ Size = Vector3.new(0.8, 0.8, 1), Color = color, Transparency = 0.2 })
		local core = part({ Size = Vector3.new(0.3, 0.3, 1), Color = WHITE })
		animate(0.25, function(k)
			local l = len * math.min(1, k * 2.5)
			local cf = CFrame.lookAt(from, from + d) * CFrame.new(0, 0, -l / 2)
			beam.Size = Vector3.new(0.8 * (1 - k), 0.8 * (1 - k), l)
			core.Size = Vector3.new(0.3 * (1 - k), 0.3 * (1 - k), l)
			beam.CFrame = cf
			core.CFrame = cf
			beam.Transparency = 0.2 + 0.8 * k
		end, clean({ beam, core }))
		burst(from + d * len, color, 8, 0.5, 14, TEX.Spark)
	end

	------------------------------------------------------------ TATU
	-- bola de casco rolando no lugar do corpo
	function H.B_Ball(p)
		local root = rootOf(p.Model)
		if not root then
			return
		end
		local dur = p.Duration or 2.8
		local d = math.max(root.Size.Y, root.Size.X) * 1.15
		local color = p.Color or C(170, 140, 110)
		local core = ball(Vector3.one * d, color, Enum.Material.SmoothPlastic)
		local bands = {}
		for i = -2, 2 do
			local band = part({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.18, d * math.cos(i * 0.32) * 1.02, d * math.cos(i * 0.32) * 1.02),
				Color = C(120, 95, 80),
				Material = Enum.Material.SmoothPlastic,
			})
			table.insert(bands, { band, i })
		end
		local dustAt = 0
		local last = root.Position
		local roll = 0
		animate(dur, function(_, t)
			if not root.Parent then
				return true
			end
			local pos = root.Position
			local move = Vector3.new(pos.X - last.X, 0, pos.Z - last.Z)
			last = pos
			roll += move.Magnitude / (d * 0.5)
			local dir = move.Magnitude > 0.01 and move.Unit or root.CFrame.LookVector
			local cf = CFrame.lookAt(pos, pos + Vector3.new(dir.X, 0, dir.Z)) * CFrame.Angles(-roll, 0, 0)
			core.CFrame = cf
			for _, e in ipairs(bands) do
				e[1].CFrame = cf * CFrame.Angles(e[2] * 0.32 + PI / 2, 0, 0) * CFrame.Angles(0, 0, PI / 2)
			end
			if t > dustAt and move.Magnitude > 0.05 then
				dustAt = t + 0.12
				smoke(pos - Vector3.new(0, d * 0.45, 0), C(180, 160, 130), 3, 1.5, 4)
			end
			return nil
		end, function()
			core:Destroy()
			for _, e in ipairs(bands) do
				e[1]:Destroy()
			end
			burst(root.Position, C(190, 165, 135), 14, 0.8, 12, TEX.Smoke, { LightEmission = 0 })
		end)
	end

	------------------------------------------------------------ DENTE-DE-SABRE
	function H.B_ClawX(p)
		local color = p.Color or WHITE
		clawMarks(p.Position, p.Direction or Vector3.new(0, 0, -1), color, 5, 0.6)
		clawMarks(p.Position, p.Direction or Vector3.new(0, 0, -1), color, 5, -0.6)
		Effects.Shake(0.12)
	end

	-- sangramento: gotas vermelhas pingando
	function H.B_Bleed(p)
		local root = rootOf(p.Model)
		if not root then
			return
		end
		attachEmitter(root, p.Duration or 3, {
			Color = ColorSequence.new(C(220, 30, 40)),
			Size = NS(0, 0.3, 1, 0.15),
			Lifetime = NumberRange.new(0.5, 0.8),
			Speed = NumberRange.new(1, 3),
			Acceleration = Vector3.new(0, -25, 0),
			SpreadAngle = Vector2.new(60, 60),
			Rate = 12,
			LightEmission = 0.2,
		})
	end

	------------------------------------------------------------ ASTRONAUTA
	-- jato forte saindo dos bocais
	function H.B_Jet(p)
		local model = p.Model
		local dur = p.Duration or 2.4
		for _, d in ipairs(model and model:GetChildren() or {}) do
			if d:IsA("BasePart") and d.Name == "Bocal" then
				attachEmitter(d, dur, {
					Texture = TEX.Fire,
					Color = ColorSequence.new(C(255, 240, 160), C(255, 110, 30)),
					Size = NS(0, 0.9, 1, 0.1),
					Lifetime = NumberRange.new(0.2, 0.35),
					Speed = NumberRange.new(14, 20),
					EmissionDirection = Enum.NormalId.Bottom,
					SpreadAngle = Vector2.new(8, 8),
					Rate = 60,
					LightEmission = 1,
				})
			end
		end
		local feet = feetOf(model)
		if feet then
			smoke(feet, C(220, 220, 230), 18, 3, 14)
			ring(CFrame.new(feet + Vector3.new(0, 0.2, 0)), 1, 7, C(255, 200, 120), 0.4)
		end
	end

	-- foguetinho sai da mochila em curva lateral e cai no alvo
	function H.B_Rocket(p)
		local root = rootOf(p.Model)
		if not root then
			return
		end
		local from = (partOf(p.Model, "Mochila") or root).Position
		local to = p.To
		local side = (p.Side or 1) * 6
		local dur = p.Duration or 0.6
		local body = part({ Size = Vector3.new(0.45, 0.45, 1.4), Color = WHITE, Material = Enum.Material.SmoothPlastic })
		local nose = part({ Size = Vector3.new(0.48, 0.48, 0.4), Color = C(255, 70, 50), Material = Enum.Material.SmoothPlastic })
		local flame = part({ Size = Vector3.new(0.35, 0.35, 0.6), Color = C(255, 180, 60) })
		trail(body, C(230, 230, 235), 0.8, 0.5, true)
		local right = root.CFrame.RightVector
		animate(dur, function(k)
			local function at(u)
				local up = math.sin(u * PI) * 8
				return from:Lerp(to, u) + right * side * math.sin(u * PI) + Vector3.new(0, up, 0)
			end
			local pos, ahead = at(k), at(math.min(1, k + 0.04))
			local cf = (ahead - pos).Magnitude > 0.01 and CFrame.lookAt(pos, ahead) or CFrame.new(pos)
			body.CFrame = cf
			nose.CFrame = cf * CFrame.new(0, 0, -0.85)
			flame.CFrame = cf * CFrame.new(0, 0, 0.95)
		end, clean({ body, nose, flame }))
	end

	------------------------------------------------------------ YETI
	-- bola de neve crescendo acima da cabeça
	function H.B_Snowball(p)
		local root = rootOf(p.Model)
		if not root then
			return
		end
		local dur = p.Duration or 1
		local s = root.Size.Y
		local snow = ball(Vector3.one * 0.5, C(245, 250, 255), Enum.Material.Snow)
		animate(dur, function(k)
			if not root.Parent then
				return true
			end
			local d = s * (0.4 + 1.6 * k)
			snow.Size = Vector3.one * d
			snow.CFrame = root.CFrame * CFrame.new(0, s * 1.4 + d * 0.5, -root.Size.Z * 0.2)
			return nil
		end, function()
			snow:Destroy()
		end)
		attachEmitter(root, dur, {
			Color = ColorSequence.new(WHITE),
			Size = NS(0, 0.4, 1, 0),
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(3, 6),
			Acceleration = Vector3.new(0, 6, 0),
			SpreadAngle = Vector2.new(180, 180),
			Rate = 25,
		})
	end

	function H.B_SnowThrow(p)
		local root = rootOf(p.Model)
		if not root then
			return
		end
		local s = root.Size.Y
		local d = s * 2
		local from = (root.CFrame * CFrame.new(0, s * 1.4 + d * 0.5, -root.Size.Z * 0.2)).Position
		local snow = ball(Vector3.one * d, C(245, 250, 255), Enum.Material.Snow)
		trail(snow, C(230, 240, 255), d * 0.8, 0.4, true)
		fly({ { snow, CFrame.new() } }, from, p.To + Vector3.new(0, d * 0.4, 0), p.Duration or 0.55, 6, 8)
	end

	function H.B_SnowBurst(p)
		local pos, r = p.Position, p.Radius or 10
		burst(pos + Vector3.new(0, 1.5, 0), WHITE, 40, 1.4, 35, TEX.Smoke, {
			LightEmission = 0.2,
			Size = NS(0, 1.5, 1, 4),
			Transparency = NS(0, 0.1, 1, 1),
			Lifetime = NumberRange.new(0.6, 1.2),
			Drag = 3,
		})
		burst(pos + Vector3.new(0, 1, 0), C(200, 240, 255), 24, 0.6, 30, TEX.Sparkle)
		ring(CFrame.new(pos + Vector3.new(0, 0.3, 0)), 1, r, C(220, 240, 255), 0.5, 1.2)
		light(pos + Vector3.new(0, 3, 0), C(190, 235, 255), 30, 0.5)
		Effects.Shake(0.45)
		-- montes de neve que ficam
		for _ = 1, q(5) do
			local a = math.random() * PI * 2
			local pile = ball(Vector3.new(rnd(2, 3.5), rnd(0.8, 1.4), rnd(2, 3.5)), C(240, 246, 255), Enum.Material.Snow)
			pile.CFrame = CFrame.new(pos + Vector3.new(math.cos(a), 0, math.sin(a)) * rnd(1, r * 0.7))
			animate(3.6, function(_, t)
				if t > 3 then
					pile.Transparency = (t - 3) / 0.6
				end
			end, function()
				pile:Destroy()
			end)
		end
	end

	------------------------------------------------------------ LOBISOMEM
	-- lua cheia no céu, céu escurece um pouco em volta (luz azulada)
	function H.B_Moon(p)
		local pos, dur = p.Position, p.Duration or 3.5
		local moon = ball(Vector3.one * 0.5, C(255, 248, 210))
		local halo = ball(Vector3.one * 0.5, C(200, 210, 255), Enum.Material.Neon, 0.75)
		local spots = {}
		for i = 1, 3 do
			table.insert(spots, ball(Vector3.one * (1 + i * 0.4), C(220, 210, 170), Enum.Material.SmoothPlastic))
		end
		animate(dur, function(k)
			local e = math.min(1, k * 5)
			local fade = k > 0.85 and (k - 0.85) / 0.15 or 0
			moon.Size = Vector3.one * 10 * e
			moon.CFrame = CFrame.new(pos)
			moon.Transparency = fade
			halo.Size = Vector3.one * 16 * e
			halo.CFrame = CFrame.new(pos)
			halo.Transparency = 0.75 + 0.25 * fade
			for i, s in ipairs(spots) do
				s.CFrame = CFrame.new(pos + Vector3.new(math.cos(i * 2) * 2.2, math.sin(i * 2) * 2.2, 0) * e) * CFrame.new(0, 0, 3.6 * e)
				s.Transparency = e < 1 and 1 or fade
			end
		end, function()
			moon:Destroy()
			halo:Destroy()
			clean(spots)()
		end)
		light(pos - Vector3.new(0, 20, 0), C(170, 190, 255), 60, dur)
	end

	function H.B_Claw(p)
		clawMarks(p.Position, p.Direction or Vector3.new(0, 0, -1), p.Color or C(200, 210, 255), 4.5, rnd(-0.9, 0.9))
		Effects.Shake(0.1)
	end

	-- cura: partículas vermelhas indo para o corpo
	function H.B_Heal(p)
		local root = rootOf(p.Model)
		if not root then
			return
		end
		burst(root.Position, C(255, 80, 100), 10, 0.5, 6, TEX.Sparkle, { Acceleration = Vector3.new(0, 8, 0) })
	end

	------------------------------------------------------------ POLVO
	-- tinta preta grudada no alvo (cego) com respingos
	function H.B_Ink(p)
		local root = rootOf(p.Model)
		if not root then
			return
		end
		local dur = p.Duration or 3
		local h = Instance.new("Highlight")
		h.FillColor = C(20, 15, 30)
		h.FillTransparency = 0.35
		h.OutlineColor = C(60, 40, 90)
		h.OutlineTransparency = 0.4
		h.Adornee = p.Model
		h.Parent = folder
		animate(dur, function(k)
			h.FillTransparency = 0.35 + 0.65 * k ^ 2
		end, function()
			h:Destroy()
		end)
		burst(root.Position, C(25, 15, 40), 20, 1, 14, TEX.Smoke, { LightEmission = 0 })
		local feet = feetOf(p.Model)
		if feet then
			residue(feet, 3, C(20, 15, 30), dur, Enum.Material.SmoothPlastic, 0.2)
		end
		-- se for o MEU cachorro: a tela escurece um pouco (cegueira)
		if p.Model:GetAttribute("Owner") == player.UserId then
			local cc = Instance.new("ColorCorrectionEffect")
			cc.Brightness = -0.25
			cc.Saturation = -0.6
			cc.Parent = workspace.CurrentCamera
			animate(dur, function(k)
				cc.Brightness = -0.25 * (1 - k)
				cc.Saturation = -0.6 * (1 - k)
			end, function()
				cc:Destroy()
			end)
		end
	end

	-- tentáculos saindo do chão em volta do alvo e apertando
	function H.B_Tentacles(p)
		local pos = p.Position
		local dur = p.Duration or 1.9
		local size = (p.Model and p.Model.Parent) and p.Model:GetExtentsSize() or Vector3.new(4, 4, 4)
		local r = math.max(size.X, size.Z) * 0.6 + 1
		local h = size.Y * 1.1
		local list = {}
		local n = q(5)
		for i = 1, n do
			local a0 = i / n * PI * 2
			local segs = {}
			for j = 1, 6 do
				local seg = part({
					Shape = Enum.PartType.Ball,
					Size = Vector3.one,
					Color = j == 6 and C(255, 160, 210) or C(175, 70, 145),
					Material = Enum.Material.SmoothPlastic,
				})
				table.insert(segs, seg)
				table.insert(list, seg)
			end
			animate(dur, function(k, t)
				local grow = math.min(1, t / 0.3)
				local squeeze = 1 - 0.35 * math.min(1, math.max(0, t - 0.3) / 0.3) + math.sin(t * 14) * 0.05
				local sink = k > 0.8 and (k - 0.8) / 0.2 or 0
				for j, seg in ipairs(segs) do
					local u = j / #segs
					local a = a0 + u * 1.2
					local rr = r * squeeze * (1.2 - u * 0.5)
					local width = (1.3 - u * 0.9) * 1.2
					seg.Size = Vector3.one * width
					seg.CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * rr, (u * h) * grow - sink * h, math.sin(a) * rr))
				end
			end)
		end
		animate(dur, function() end, clean(list))
		smoke(pos, C(90, 60, 80), 14, 2.5, 10)
		residue(pos, r, C(40, 25, 50), dur, Enum.Material.SmoothPlastic, 0.3)
		Effects.Shake(0.2)
	end

	------------------------------------------------------------ TANQUE
	-- mira laser vermelha do canhão até o alvo, piscando cada vez mais rápido
	function H.B_LaserSight(p)
		local root, target = rootOf(p.Model), rootOf(p.Target)
		if not root or not target then
			return
		end
		local muzzle = partOf(p.Model, "CanhaoBoca") or root
		local beam = part({ Size = Vector3.new(0.15, 0.15, 1), Color = C(255, 30, 30), Transparency = 0.2 })
		local dot = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 3, 3), Color = C(255, 40, 40), Transparency = 0.3 })
		animate(p.Duration or 1, function(k, t)
			if not root.Parent or not target.Parent then
				return true
			end
			local a = muzzle.Position
			local b = target.Position
			local len = (b - a).Magnitude
			beam.Size = Vector3.new(0.15, 0.15, len)
			beam.CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2)
			local blink = math.sin(t * (10 + 40 * k)) > 0
			beam.Transparency = blink and 0.15 or 0.6
			local feet = feetOf(p.Target) or b
			dot.CFrame = CFrame.new(feet + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, PI / 2)
			dot.Size = Vector3.new(0.1, 3 + 4 * (1 - k), 3 + 4 * (1 - k))
			return nil
		end, clean({ beam, dot }))
	end

	-- disparo: clarão/fumaça na boca do canhão e o projétil voando reto
	function H.B_Shell(p)
		local root = rootOf(p.Model)
		if not root then
			return
		end
		local muzzle = partOf(p.Model, "CanhaoBoca") or root
		local from = muzzle.Position
		burst(from, C(255, 200, 100), 20, 1.4, 25, TEX.Fire, { Lifetime = NumberRange.new(0.1, 0.25) })
		smoke(from, C(120, 115, 105), 16, 3, 16)
		light(from, C(255, 180, 80), 25, 0.25)
		Effects.Shake(0.3)
		local shell = part({ Size = Vector3.new(0.8, 0.8, 2), Color = C(255, 200, 90) })
		trail(shell, C(255, 160, 60), 0.9, 0.3)
		fly({ { shell, CFrame.new() } }, from, p.To + Vector3.new(0, 0.5, 0), p.Duration or 0.3, 1.5)
	end

	-- cratera queimada com fogo nas bordas (resíduo)
	function H.B_Crater(p)
		local pos, r, dur = p.Position, p.Radius or 9, p.Duration or 3.5
		residue(pos, r * 0.7, C(30, 25, 22), dur, Enum.Material.Slate, 0.15)
		burst(pos + Vector3.new(0, 0.5, 0), C(120, 100, 80), 14, 0.8, 30, TEX.Smoke, { LightEmission = 0, Acceleration = Vector3.new(0, -30, 0) })
		if crowded() then
			return
		end
		for i = 1, q(6) do
			local a = i / 6 * PI * 2 + rnd(-0.3, 0.3)
			local at = anchor(pos + Vector3.new(math.cos(a), 0.3, math.sin(a)) * r * 0.65, dur + 1.2)
			local e = Instance.new("ParticleEmitter")
			e.Texture = TEX.Fire
			e.Color = ColorSequence.new(C(255, 220, 120), C(255, 80, 20))
			e.Size = NS(0, 1.4, 1, 0.2)
			e.Lifetime = NumberRange.new(0.4, 0.7)
			e.Speed = NumberRange.new(2, 5)
			e.Acceleration = Vector3.new(0, 6, 0)
			e.EmissionDirection = Enum.NormalId.Top
			e.SpreadAngle = Vector2.new(15, 15)
			e.LightEmission = 1
			e.Rate = 14 * quality()
			e.Parent = at
			task.delay(dur, function()
				e.Enabled = false
			end)
		end
	end

	------------------------------------------------------------ FEITICEIRO
	local orbColors = { C(120, 220, 255), C(255, 120, 230), C(160, 120, 255) }

	-- três orbes girando em volta do feiticeiro (carga)
	function H.B_Orbs(p)
		local root = rootOf(p.Model)
		if not root then
			return
		end
		local dur = p.Duration or 0.9
		local s = math.max(2, root.Size.Z * 0.8)
		local orbs = {}
		for i = 1, 3 do
			local o = ball(Vector3.one * 0.9, orbColors[i])
			trail(o, orbColors[i], 0.6, 0.3)
			table.insert(orbs, o)
		end
		animate(dur, function(k, t)
			if not root.Parent then
				return true
			end
			for i, o in ipairs(orbs) do
				local a = t * 7 + i / 3 * PI * 2
				o.CFrame = root.CFrame * CFrame.new(math.cos(a) * s, root.Size.Y * (0.6 + 0.2 * math.sin(t * 5 + i)), math.sin(a) * s)
				o.Size = Vector3.one * (0.6 + 0.6 * k)
			end
			return nil
		end, clean(orbs))
		ring(root.CFrame * CFrame.new(0, -root.Size.Y * 0.5, 0), 1, s * 1.5, orbColors[1], dur, 0.4)
	end

	-- orbe disparado do lado do feiticeiro até o alvo
	function H.B_OrbShot(p)
		local root, target = rootOf(p.Model), rootOf(p.Target)
		if not root or not target then
			return
		end
		local i = p.Index or 1
		local color = p.Color or orbColors[1]
		local a = i / 3 * PI * 2
		local s = math.max(2, root.Size.Z * 0.8)
		local from = (root.CFrame * CFrame.new(math.cos(a) * s, root.Size.Y * 0.7, math.sin(a) * s)).Position
		local o = ball(Vector3.one * 1.2, color)
		trail(o, color, 0.9, 0.35)
		local to = target.Position
		fly({ { o, CFrame.new() } }, from, to, p.Duration or 0.3, 2.5, nil, function()
			burst(to, color, 16, 0.8, 18)
			ring(CFrame.new(to), 0.5, 4, color, 0.3, 0.4)
		end)
	end

	-- selo mágico girando no chão (aviso) que acende antes de explodir
	function H.B_Seal(p)
		local pos, r, dur = p.Position, p.Radius or 8, p.Duration or 0.9
		local color = C(160, 120, 255)
		local base = disc(pos, r, color, 0.75)
		local list = { base }
		local n = q(10)
		for _ = 1, n do
			table.insert(list, part({ Size = Vector3.new(0.3, 0.12, r * 1.2), Color = orbColors[2] }))
		end
		local runes = {}
		for _ = 1, q(6) do
			local rune = part({ Size = Vector3.new(0.8, 0.12, 0.8), Color = WHITE })
			table.insert(runes, rune)
			table.insert(list, rune)
		end
		animate(dur, function(k, t)
			-- estrela de linhas cruzadas girando
			for i = 2, n + 1 do
				local a = (i - 1) / n * PI * 2 + t * 1.5
				local mid = pos + Vector3.new(math.cos(a), 0, math.sin(a)) * r * 0.45 + Vector3.new(0, 0.15, 0)
				list[i].CFrame = CFrame.new(mid) * CFrame.Angles(0, -a + PI / 2 + 0.6, 0)
				list[i].Transparency = 0.4 - 0.35 * k
			end
			for j, rune in ipairs(runes) do
				local a = j / #runes * PI * 2 - t * 2
				rune.CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * r * 0.85, 0.2 + k * 1.5, math.sin(a) * r * 0.85)) * CFrame.Angles(0, a, PI / 4)
			end
			base.Transparency = 0.75 - 0.4 * k
		end, clean(list))
		light(pos + Vector3.new(0, 2, 0), color, r * 3, dur + 0.3)
	end
end
