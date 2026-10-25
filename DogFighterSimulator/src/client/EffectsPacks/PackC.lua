-- Efeitos do Pacote C (míticos). Retorna function(H, Effects) que adiciona handlers H.C_*.
-- Também anima as peças extras dos míticos (pivôs com atributos CSpin/CWave definidos no
-- DogPacks/PackC): anéis, ponteiros de relógio, tentáculos, crinas, lua em órbita...
--
-- Só texturas nativas (rbxasset://). Tudo vai para workspace.FX com limite próprio de peças; a
-- quantidade segue a qualidade gráfica (atributo "GraphicsQuality" do LocalPlayer).
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local C = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local TAU = math.pi * 2
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass

local TEX = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Spark = "rbxasset://textures/particles/fire_sparks_main.dds",
	Swirl = "rbxasset://textures/particles/forcefield_vortex_main.dds",
}

local RAINBOW = { C(255, 70, 80), C(255, 160, 50), C(255, 230, 70), C(90, 220, 110), C(80, 170, 255), C(170, 100, 255) }

return function(H, Effects)
	local player = Players.LocalPlayer

	------------------------------------------------------------ qualidade / limites
	local QUALITY = { Alto = 1, ["Médio"] = 0.6, Baixo = 0.3 }
	local function quality(): number
		return QUALITY[player:GetAttribute("GraphicsQuality")] or 1
	end
	local function q(n: number): number
		return math.max(1, math.floor(n * quality() + 0.5))
	end

	local folder = workspace:FindFirstChild("FX")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "FX"
		folder.Parent = workspace
	end

	local MAX_PARTS = 260
	local myParts = 0
	local function full(extra: number?): boolean
		return myParts + (extra or 0) > MAX_PARTS * (0.4 + 0.6 * quality())
	end

	local function fxPart(props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = NEON
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in pairs(props) do
			p[k] = v
		end
		myParts += 1
		p.Destroying:Connect(function()
			myParts -= 1
		end)
		p.Parent = folder
		Debris:AddItem(p, 12) -- segurança: nada fica para sempre
		return p
	end

	local function kill(list)
		for _, p in ipairs(list) do
			if p.Parent then
				p:Destroy()
			end
		end
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
			if not ok then
				warn("[EffectsPackC]", stop)
			end
			if k >= 1 or stop == true or not ok then
				anims[i] = anims[#anims]
				anims[#anims] = nil
				if a.Done then
					local okDone, err = pcall(a.Done)
					if not okDone then
						warn("[EffectsPackC] fim", err)
					end
				end
			end
		end
	end)

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

	local function outCubic(k: number): number
		return 1 - (1 - k) ^ 3
	end

	local function anchor(position: Vector3, life: number)
		local a = Instance.new("Attachment")
		a.Position = position
		a.Parent = workspace.Terrain
		Debris:AddItem(a, life)
		return a
	end

	local function burst(position: Vector3, color: Color3, count: number, size: number, speed: number, texture: string?, extra: { [string]: any }?)
		local a = anchor(position, 3)
		local e = Instance.new("ParticleEmitter")
		e.Enabled = false
		e.Texture = texture or TEX.Sparkle
		e.LightEmission = 0.8
		e.Color = ColorSequence.new(color)
		e.Size = NS(0, size, 1, 0)
		e.Transparency = NS(0, 0, 0.7, 0.3, 1, 1)
		e.Lifetime = NumberRange.new(0.4, 0.9)
		e.Speed = NumberRange.new(speed * 0.4, speed)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 3
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-120, 120)
		if extra then
			for k, v in pairs(extra) do
				(e :: any)[k] = v
			end
		end
		e.Parent = a
		e:Emit(q(count))
		return e
	end

	local lights = 0
	local function light(position: Vector3, color: Color3, range: number, duration: number)
		if lights >= math.floor(3 + 5 * quality()) then
			return
		end
		lights += 1
		local a = anchor(position, duration + 0.1)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = math.min(range, 60)
		l.Brightness = 4
		l.Shadows = false
		l.Parent = a
		animate(duration, function(k)
			l.Brightness = 4 * (1 - k)
		end, function()
			lights -= 1
		end)
	end

	local function shake(position: Vector3, amount: number, radius: number)
		local cam = workspace.CurrentCamera
		if cam and Effects.Shake then
			local dist = (cam.CFrame.Position - position).Magnitude
			if dist < radius * 1.5 then
				Effects.Shake(amount * math.clamp(1 - dist / (radius * 1.5), 0.15, 1))
			end
		end
	end

	local function flash(position: Vector3, radius: number, color: Color3, duration: number?)
		local ball = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * radius * 0.4, CFrame = CFrame.new(position), Color = color })
		animate(duration or 0.3, function(k)
			ball.Size = Vector3.one * radius * (0.4 + 1.6 * outCubic(k))
			ball.Transparency = k ^ 0.6
		end, function()
			ball:Destroy()
		end)
	end

	-- segmento entre dois pontos (peça já existente)
	local function stretch(p: BasePart, a: Vector3, b: Vector3, w: number, h: number?)
		local len = (b - a).Magnitude
		if len < 0.01 then
			p.CFrame = CFrame.new(a)
			return
		end
		p.Size = Vector3.new(w, h or w, len + w * 0.3)
		p.CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2)
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

	-- esconde (localmente) as peças com certos nomes durante um tempo
	local function hideParts(model, names, seconds)
		local list = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and names[d.Name] then
				table.insert(list, { d, d.LocalTransparencyModifier })
				d.LocalTransparencyModifier = 1
			end
		end
		task.delay(seconds, function()
			for _, e in ipairs(list) do
				if e[1].Parent then
					e[1].LocalTransparencyModifier = e[2]
				end
			end
		end)
		return list
	end

	local function groundRing(position: Vector3, r0: number, r1: number, color: Color3, duration: number, thick: number?)
		if H.Shockwave and r0 < 2 then
			H.Shockwave({ Position = position, Radius = r1, Color = color })
			return
		end
		local n = q(20)
		local list = {}
		for _ = 1, n do
			table.insert(list, fxPart({ Size = Vector3.new(0.4, 0.4, 1), Color = color }))
		end
		animate(duration, function(k)
			local r = r0 + (r1 - r0) * outCubic(k)
			local arc = TAU * r / n * 1.15
			for i, p in ipairs(list) do
				local a = i / n * TAU
				p.Size = Vector3.new(thick or 0.6, 0.5, arc)
				p.CFrame = CFrame.new(position) * CFrame.Angles(0, a, 0) * CFrame.new(r, 0.25, 0)
				p.Transparency = k ^ 1.4
			end
		end, function()
			kill(list)
		end)
	end

	------------------------------------------------------------ animação ociosa das peças extras
	local tracked = {} -- [model] = { {Weld, Base, Last, Spin, Wave, Freq, Phase} }
	local function collect(model)
		local list = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Weld") and d.Part1 then
				local spin = d.Part1:GetAttribute("CSpin")
				local wave = d.Part1:GetAttribute("CWave")
				if typeof(spin) == "Vector3" or typeof(wave) == "Vector3" then
					table.insert(list, {
						Weld = d,
						Base = d.C0,
						Last = d.C0,
						Spin = typeof(spin) == "Vector3" and spin or nil,
						Wave = typeof(wave) == "Vector3" and wave or nil,
						Freq = d.Part1:GetAttribute("CFreq") or 2,
						Phase = d.Part1:GetAttribute("CPhase") or 0,
					})
				end
			end
		end
		return list
	end
	local function track(model)
		if not model:IsA("Model") then
			return
		end
		local function try()
			if model:GetAttribute("CAnim") and model.Parent then
				tracked[model] = collect(model)
			end
		end
		try()
		model.DescendantAdded:Connect(function()
			task.defer(try)
		end)
		model.AncestryChanged:Connect(function()
			if not model.Parent then
				tracked[model] = nil
			end
		end)
	end
	CollectionService:GetInstanceAddedSignal("Dog"):Connect(track)
	for _, m in ipairs(CollectionService:GetTagged("Dog")) do
		track(m)
	end
	local frame = 0
	RunService.PreSimulation:Connect(function()
		frame += 1
		local t = os.clock()
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position
		local far = 90 + 110 * quality()
		for model, list in pairs(tracked) do
			local root = model.PrimaryPart
			if root and model.Parent then
				local dist = camPos and (root.Position - camPos).Magnitude or 0
				if dist < far and (dist < far * 0.5 or frame % 3 == 0) then
					for _, e in ipairs(list) do
						local w = e.Weld
						if w.Parent then
							if w.C0 ~= e.Last then
								e.Base = w.C0 -- alguém (ScaleTo) mudou o C0: relê a base
							end
							local rot = CFrame.identity
							if e.Spin then
								local s = e.Spin
								rot = CFrame.Angles(s.X * t % TAU, s.Y * t % TAU, s.Z * t % TAU)
							end
							if e.Wave then
								local v = math.sin(t * e.Freq + e.Phase)
								local v2 = math.sin(t * e.Freq * 0.73 + e.Phase * 1.7)
								rot = rot * CFrame.Angles(e.Wave.X * v2, e.Wave.Y * v, e.Wave.Z * v)
							end
							local c0 = e.Base * rot
							w.C0 = c0
							e.Last = c0
						end
					end
				end
			end
		end
	end)

	------------------------------------------------------------ HIDRA: pescoço-serpente que estica até o alvo
	function H.C_HydraNeck(p)
		local model = p.Model
		local head = model and model:FindFirstChild("Head" .. (p.Head or 1))
		if not (head and p.To) or full(10) then
			return
		end
		local color = p.Color or C(150, 255, 120)
		local n = q(9) + 2
		local segs, dur = {}, p.Duration or 0.5
		for i = 1, n do
			table.insert(
				segs,
				fxPart({ Shape = Enum.PartType.Ball, Color = i % 2 == 0 and C(40, 112, 78) or C(60, 140, 95), Material = Enum.Material.SmoothPlastic })
			)
		end
		local skull = fxPart({ Size = Vector3.new(1.6, 1.2, 2.2), Color = C(40, 112, 78), Material = Enum.Material.SmoothPlastic })
		local jaw = fxPart({ Size = Vector3.new(1.2, 0.4, 1.8), Color = C(214, 206, 140), Material = Enum.Material.SmoothPlastic })
		local eye = fxPart({ Size = Vector3.new(1.7, 0.3, 0.4), Color = C(255, 220, 40) })
		local side = (p.Head or 1) % 2 == 0 and 1 or -1
		animate(dur, function(k)
			if not head.Parent then
				return true
			end
			local a = head.Position
			local b = p.To
			local reach = math.sin(math.min(k / 0.55, 1) * math.pi * 0.5)
			if k > 0.7 then
				reach = 1 - (k - 0.7) / 0.3
			end
			local tip = a:Lerp(b, reach)
			local dir = (b - a)
			local right = dir.Magnitude > 0.1 and dir.Unit:Cross(Vector3.yAxis) or Vector3.xAxis
			for i, s in ipairs(segs) do
				local u = i / (n + 1)
				local pos = a:Lerp(tip, u)
					+ right * math.sin(u * math.pi * 2 + k * 10) * 1.4 * side * reach
					+ Vector3.new(0, math.sin(u * math.pi) * 2.5 * reach, 0)
				local r = 1.3 - u * 0.4
				s.Size = Vector3.one * r
				s.CFrame = CFrame.new(pos)
			end
			local look = CFrame.lookAt(tip, tip + (dir.Magnitude > 0.1 and dir.Unit or Vector3.zAxis))
			local bite = k > 0.45 and k < 0.6 and 0 or 0.5
			skull.CFrame = look * CFrame.new(0, 0.25, 0)
			jaw.CFrame = look * CFrame.new(0, -0.45, 0.2) * CFrame.Angles(bite, 0, 0)
			eye.CFrame = look * CFrame.new(0, 0.45, 0.2)
			return nil
		end, function()
			kill(segs)
			skull:Destroy()
			jaw:Destroy()
			eye:Destroy()
		end)
		task.delay(dur * 0.5, function()
			burst(p.To, color, 12, 0.8, 18, TEX.Spark)
		end)
	end

	-- cura: espirais subindo em volta do corpo
	function H.C_Heal(p)
		local root = rootOf(p.Model)
		if not root then
			return
		end
		local color = p.Color or C(130, 255, 140)
		local base = feetOf(p.Model) or root.Position
		local r = math.max(2, root.Size.X * 0.8)
		local list = {}
		for i = 1, q(8) do
			table.insert(list, { fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, Color = color }), i })
		end
		animate(0.9, function(k)
			if not root.Parent then
				return true
			end
			for _, e in ipairs(list) do
				local a = e[2] / #list * TAU + k * 7
				e[1].CFrame = CFrame.new(base + Vector3.new(math.cos(a) * r, k * root.Size.Y * 2.2, math.sin(a) * r))
				e[1].Transparency = k ^ 2
			end
			return nil
		end, function()
			for _, e in ipairs(list) do
				e[1]:Destroy()
			end
		end)
		burst(root.Position, color, 16, 0.7, 6, TEX.Sparkle, { Acceleration = Vector3.new(0, 8, 0) })
	end

	------------------------------------------------------------ DRAGÃO-ESQUELETO
	-- ossos desmontam (Mode "fall") ou remontam voando para o centro (Mode "rise")
	function H.C_BonePile(p)
		local pos = p.Position
		if not pos or full(10) then
			return
		end
		local color = p.Color or C(90, 255, 200)
		local list = {}
		for _ = 1, q(10) do
			local bone = fxPart({ Size = Vector3.new(0.4, 0.4, rnd(1.2, 2.2)), Color = C(236, 228, 204), Material = Enum.Material.SmoothPlastic })
			local away = Vector3.new(rnd(-1, 1), 0, rnd(-1, 1)).Unit * rnd(2, 5)
			table.insert(list, { bone, away, Vector3.new(rnd(-6, 6), rnd(-6, 6), rnd(-6, 6)) })
		end
		local rise = p.Mode == "rise"
		animate(0.55, function(k)
			for _, e in ipairs(list) do
				local u = rise and (1 - k) or k
				local at = pos + e[2] * u + Vector3.new(0, 0.3 + math.sin(u * math.pi) * 2 + (rise and k * 2 or (1 - k) * 2), 0)
				e[1].CFrame = CFrame.new(at) * CFrame.Angles(e[3].X * u, e[3].Y * u, e[3].Z * u)
			end
		end, function()
			for _, e in ipairs(list) do
				e[1]:Destroy()
			end
		end)
		burst(pos + Vector3.new(0, 1, 0), color, 20, 1.2, 10, TEX.Smoke, { LightEmission = 0.6 })
	end

	-- caixa torácica gigante: costelas curvas brotam em volta e se fecham sobre o centro
	function H.C_RibCage(p)
		local pos, r, dur = p.Position, p.Radius or 6, p.Duration or 1.6
		if not pos or full(30) then
			return
		end
		local ribs = {}
		local n = 8
		local per = 4
		for i = 1, n do
			local segs = {}
			for _ = 1, per do
				table.insert(segs, fxPart({ Shape = Enum.PartType.Ball, Color = C(236, 228, 204), Material = Enum.Material.SmoothPlastic }))
			end
			table.insert(ribs, { segs, (i - 0.5) / n * TAU })
		end
		local spine = fxPart({ Size = Vector3.new(1, 1, r * 2), Color = C(220, 212, 188), Material = Enum.Material.SmoothPlastic, Transparency = 1 })
		local glowCore = fxPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2,
			Color = C(90, 255, 200),
			Transparency = 0.6,
			CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)),
		})
		local function rib(a, close, s)
			-- arco: sai do chão no raio r e curva para o topo em cima do centro
			local pts = {}
			for j = 0, per do
				local u = j / per
				local ang = u * math.pi * 0.5 * close
				local rr = r * math.cos(ang)
				local h = r * 1.4 * math.sin(ang) * s
				table.insert(pts, pos + Vector3.new(math.cos(a) * rr, h, math.sin(a) * rr))
			end
			return pts
		end
		animate(dur, function(k, t)
			local grow = outCubic(math.min(1, t / 0.35))
			local close = 0.4 + 0.6 * outCubic(math.clamp((t - 0.25) / 0.5, 0, 1))
			for _, e in ipairs(ribs) do
				local pts = rib(e[2], close, grow)
				for j, s in ipairs(e[1]) do
					local w = 0.75 - j * 0.1
					stretch(s, pts[j], pts[j + 1], w)
				end
			end
			spine.Transparency = close > 0.95 and 0 or 1
			spine.CFrame = CFrame.new(pos + Vector3.new(0, r * 1.4 * grow, 0))
			glowCore.Transparency = 0.5 + 0.3 * math.sin(t * 20)
			if k > 0.85 then
				local f = (k - 0.85) / 0.15
				for _, e in ipairs(ribs) do
					for _, s in ipairs(e[1]) do
						s.Transparency = f
					end
				end
			end
		end, function()
			for _, e in ipairs(ribs) do
				kill(e[1])
			end
			spine:Destroy()
			glowCore:Destroy()
			burst(pos + Vector3.new(0, 2, 0), C(236, 228, 204), 24, 0.8, 26, TEX.Sparkle, { LightEmission = 0.2 })
			burst(pos + Vector3.new(0, 1, 0), C(90, 255, 200), 18, 2.5, 12, TEX.Smoke, { LightEmission = 0.7 })
		end)
		burst(pos, C(150, 140, 120), 18, 2.5, 12, TEX.Smoke, { LightEmission = 0 })
		shake(pos, 0.35, 50)
	end

	------------------------------------------------------------ KRAKEN
	function H.C_Tentacles(p)
		local pos, r, dur = p.Position, p.Radius or 7, p.Duration or 2.2
		if not pos or full(40) then
			return
		end
		local count = math.min(p.Count or 6, q(6) + 1)
		local per = 6
		local list = {}
		for i = 1, count do
			local segs, suck = {}, {}
			for j = 1, per do
				table.insert(
					segs,
					fxPart({ Shape = Enum.PartType.Ball, Color = j % 2 == 0 and C(150, 45, 95) or C(165, 55, 105), Material = Enum.Material.SmoothPlastic })
				)
				if j % 2 == 1 then
					table.insert(
						suck,
						fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, Color = C(250, 195, 210), Material = Enum.Material.SmoothPlastic })
					)
				end
			end
			table.insert(list, { segs, suck, (i - 1) / count * TAU + rnd(-0.2, 0.2), rnd(0, 6) })
		end
		local holeList = {}
		for _, e in ipairs(list) do
			local a = e[3]
			local hole = fxPart({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.15, 3, 3),
				CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * r, 0.08, math.sin(a) * r)) * CFrame.Angles(0, 0, math.pi / 2),
				Color = C(25, 15, 25),
				Material = Enum.Material.SmoothPlastic,
			})
			table.insert(holeList, hole)
		end
		animate(dur, function(k, t)
			local up = outCubic(math.min(1, t / 0.4))
			local grab = math.clamp((t - 0.45) / 0.35, 0, 1) -- curvam para o centro
			local down = k > 0.82 and (1 - (k - 0.82) / 0.18) or 1
			for _, e in ipairs(list) do
				local a = e[3]
				local base = pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				local inward = (pos - base).Unit
				local pts = { base }
				local height = 9 * up * down
				for j = 1, per do
					local u = j / per
					local bend = u * u * (0.3 + grab * 1.3)
					local sway = math.sin(t * 5 + e[4] + u * 4) * 0.8 * (1 - grab * 0.7)
					local pt = base + Vector3.new(0, height * u * (1 - grab * u * 0.45), 0) + inward * r * bend * 0.85 + inward:Cross(Vector3.yAxis) * sway
					table.insert(pts, pt)
				end
				for j, s in ipairs(e[1]) do
					local w = (1.6 - j * 0.2) * math.max(0.2, up)
					stretch(s, pts[j], pts[j + 1], w)
				end
				for m, s in ipairs(e[2]) do
					local j = m * 2 - 1
					local mid = (pts[j] + pts[j + 1]) / 2
					s.CFrame = CFrame.new(mid + inward * (0.8 - j * 0.1))
					s.Transparency = up < 0.3 and 1 or 0
				end
			end
		end, function()
			for _, e in ipairs(list) do
				kill(e[1])
				kill(e[2])
			end
			kill(holeList)
		end)
		burst(pos, C(120, 200, 230), 20, 1.5, 14, TEX.Smoke, { LightEmission = 0.2 })
		shake(pos, 0.3, 50)
	end

	function H.C_Ink(p)
		local pos = p.Position
		if not pos then
			return
		end
		local r = p.Radius or 8
		burst(
			pos + Vector3.new(0, 1.5, 0),
			C(15, 10, 25),
			30,
			6,
			16,
			TEX.Smoke,
			{ LightEmission = 0, Size = NS(0, 3, 1, 9), Lifetime = NumberRange.new(1, 1.8) }
		)
		if not full(1) then
			local d = fxPart({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.12, r * 2, r * 2),
				CFrame = CFrame.new(pos + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				Color = C(20, 12, 30),
				Material = Enum.Material.SmoothPlastic,
				Transparency = 0.2,
			})
			animate(3, function(k)
				d.Transparency = 0.2 + 0.8 * k ^ 2
			end, function()
				d:Destroy()
			end)
		end
	end

	------------------------------------------------------------ CRONOS: o tempo para
	local grayToken = 0
	function H.C_TimeStop(p)
		local pos, r, dur = p.Position, p.Radius or 30, p.Duration or 2.4
		if not pos then
			return
		end
		-- mundo cinza só para quem está perto
		local cam = workspace.CurrentCamera
		if cam and (cam.CFrame.Position - pos).Magnitude < r * 2.5 then
			grayToken += 1
			local token = grayToken
			local cc = Instance.new("ColorCorrectionEffect")
			cc.Name = "C_TimeStop"
			cc.Parent = Lighting
			animate(dur, function(k)
				local inK = math.min(1, k / 0.12)
				local outK = k > 0.9 and (k - 0.9) / 0.1 or 0
				cc.Saturation = -1 * inK * (1 - outK)
				cc.Contrast = 0.2 * inK * (1 - outK)
				cc.TintColor = WHITE:Lerp(C(200, 225, 255), inK * (1 - outK))
			end, function()
				cc:Destroy()
				if token == grayToken then
					Effects.Shake(0.4)
				end
			end)
		end
		if full(40) then
			return
		end
		-- relógio gigante no céu
		local center = pos + Vector3.new(0, 16, 0)
		local faceR = 9
		local look = cam and CFrame.lookAt(center, Vector3.new(cam.CFrame.Position.X, center.Y, cam.CFrame.Position.Z)) or CFrame.new(center)
		local face = fxPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, faceR * 2, faceR * 2),
			CFrame = look * CFrame.Angles(0, math.pi / 2, 0),
			Color = C(246, 236, 210),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 1,
		})
		local rim = {}
		for i = 1, 24 do
			local a = i / 24 * TAU
			table.insert(
				rim,
				fxPart({
					Size = Vector3.new(0.8, 2.6, 0.9),
					Color = C(220, 175, 80),
					CFrame = look * CFrame.Angles(0, 0, a) * CFrame.new(0, faceR, -0.3),
					Transparency = 1,
				})
			)
		end
		for h = 1, 12 do
			local a = h / 12 * TAU
			table.insert(
				rim,
				fxPart({
					Size = Vector3.new(0.5, h % 3 == 0 and 2 or 1.1, 0.3),
					Color = C(40, 30, 30),
					Material = Enum.Material.SmoothPlastic,
					CFrame = look * CFrame.Angles(0, 0, a) * CFrame.new(0, faceR - 1.6, -0.35),
					Transparency = 1,
				})
			)
		end
		local hourH = fxPart({ Size = Vector3.new(0.7, 5, 0.3), Color = C(30, 25, 30), Material = Enum.Material.SmoothPlastic, Transparency = 1 })
		local minH = fxPart({ Size = Vector3.new(0.45, 7.5, 0.3), Color = C(30, 25, 30), Material = Enum.Material.SmoothPlastic, Transparency = 1 })
		local all = { face, hourH, minH }
		for _, x in ipairs(rim) do
			table.insert(all, x)
		end
		animate(dur, function(k, t)
			local vis = math.min(1, t / 0.25)
			if k > 0.85 then
				vis = 1 - (k - 0.85) / 0.15
			end
			for _, x in ipairs(all) do
				x.Transparency = 1 - vis * (x == face and 0.75 or 1)
			end
			-- ponteiros giram PARA TRÁS e param
			local spin = -t * (k < 0.15 and 12 or 0.6)
			hourH.CFrame = look * CFrame.Angles(0, 0, spin * 0.25) * CFrame.new(0, 2.3, -0.5)
			minH.CFrame = look * CFrame.Angles(0, 0, spin) * CFrame.new(0, 3.6, -0.55)
		end, function()
			kill(all)
			flash(center, 8, C(200, 230, 255), 0.35)
		end)
		groundRing(pos, 2, r, C(170, 220, 255), 0.6, 0.5)
		light(pos + Vector3.new(0, 6, 0), C(150, 210, 255), 40, dur)
	end

	-- imagem residual do cachorro parado no tempo (fantasma azulado no lugar do golpe)
	function H.C_AfterImage(p)
		local model = p.Model
		local root = rootOf(model)
		if not root or full(1) then
			return
		end
		local size = model:GetExtentsSize()
		local ghost =
			fxPart({ Shape = Enum.PartType.Ball, Size = size * Vector3.new(0.7, 0.8, 0.9), CFrame = root.CFrame, Color = C(150, 210, 255), Transparency = 0.5 })
		animate(p.Duration or 1.2, function(k)
			ghost.Transparency = 0.5 + 0.5 * k
		end, function()
			ghost:Destroy()
		end)
		burst(root.Position, C(200, 235, 255), 8, 0.6, 8)
	end

	------------------------------------------------------------ SINGULARIDADE
	function H.C_Singularity(p)
		local model = p.Model
		local root = rootOf(model)
		if not root or full(30) then
			return
		end
		local dur, r = p.Duration or 2.2, p.Radius or 14
		local hole = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, Color = C(0, 0, 0), Material = Enum.Material.SmoothPlastic })
		local halo = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, Color = C(255, 160, 70), Transparency = 0.7 })
		local n = q(22)
		local disk = {}
		for i = 1, n do
			table.insert(disk, {
				fxPart({ Size = Vector3.new(0.6, 0.15, 1), Color = i % 3 == 0 and C(255, 245, 220) or (i % 3 == 1 and C(255, 140, 50) or C(255, 200, 90)) }),
				i,
			})
		end
		local a = Instance.new("Attachment")
		a.Parent = hole
		local e = Instance.new("ParticleEmitter")
		e.Texture = TEX.Swirl
		e.Color = ColorSequence.new(C(255, 170, 90))
		e.LightEmission = 1
		e.Size = NS(0, r * 0.9, 1, 0.5)
		e.Transparency = NS(0, 0.6, 1, 1)
		e.Lifetime = NumberRange.new(0.6, 0.8)
		e.Speed = NumberRange.new(0, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(300, 400)
		e.Rate = 8 * quality()
		e.Parent = a
		local s = Instance.new("ParticleEmitter")
		s.Texture = TEX.Sparkle
		s.Color = ColorSequence.new(C(255, 220, 160))
		s.LightEmission = 1
		s.Size = NS(0, 0.6, 1, 0)
		s.Lifetime = NumberRange.new(0.5, 0.7)
		s.Speed = NumberRange.new(-r * 2, -r * 1.6) -- partículas caem para dentro
		s.SpreadAngle = Vector2.new(180, 180)
		s.Rate = 60 * quality()
		s.Parent = a
		animate(dur, function(k, t)
			if not root.Parent then
				return true
			end
			local grow = outCubic(math.min(1, t / 0.4))
			if k > 0.88 then
				grow = 1 - (k - 0.88) / 0.12
			end
			local c = root.Position
			local hr = 2 + 4 * grow
			hole.CFrame = CFrame.new(c)
			hole.Size = Vector3.one * hr
			halo.CFrame = CFrame.new(c)
			halo.Size = Vector3.one * hr * 1.35
			local tilt = CFrame.new(c) * CFrame.Angles(0.35, 0, 0.2)
			local rr = hr * 1.5
			local arc = TAU * rr / n * 1.1
			for _, d in ipairs(disk) do
				local ang = d[2] / n * TAU + t * 6
				d[1].Size = Vector3.new(1.1 * grow + 0.1, 0.15, arc)
				d[1].CFrame = tilt * CFrame.Angles(0, ang, 0) * CFrame.new(rr, 0, 0)
			end
			return nil
		end, function()
			hole:Destroy()
			halo:Destroy()
			for _, d in ipairs(disk) do
				d[1]:Destroy()
			end
		end)
		light(root.Position, C(255, 160, 70), 30, dur)
		shake(root.Position, 0.25, 40)
	end

	function H.C_WhiteHole(p)
		local pos = p.Position
		if not pos then
			return
		end
		local r = p.Radius or 10
		flash(pos, r, WHITE, 0.4)
		groundRing(pos - Vector3.new(0, 1, 0), 2, r * 1.6, C(255, 245, 230), 0.5, 0.8)
		if not full(10) then
			local rays = {}
			for i = 1, q(10) do
				local d = Vector3.new(rnd(-1, 1), rnd(-0.3, 0.9), rnd(-1, 1)).Unit
				table.insert(rays, { fxPart({ Size = Vector3.new(0.5, 0.5, 1), Color = i % 2 == 0 and WHITE or C(200, 220, 255) }), d })
			end
			animate(0.45, function(k)
				for _, e in ipairs(rays) do
					stretch(e[1], pos + e[2] * r * 0.2, pos + e[2] * r * (0.3 + 1.6 * outCubic(k)), 0.6 * (1 - k) + 0.05)
					e[1].Transparency = k
				end
			end, function()
				for _, e in ipairs(rays) do
					e[1]:Destroy()
				end
			end)
		end
		burst(pos, WHITE, 30, 1.2, 45)
		light(pos, WHITE, r * 3, 0.5)
		shake(pos, 0.6, 60)
	end

	------------------------------------------------------------ SERAFIM: hexagrama de pilares de luz
	function H.C_Judgement(p)
		local pos, r, dur = p.Position, p.Radius or 12, p.Duration or 1.6
		if not pos or full(30) then
			return
		end
		local gold = C(255, 225, 120)
		local pts = {}
		for i = 1, 6 do
			local a = i / 6 * TAU
			table.insert(pts, pos + Vector3.new(math.cos(a) * r, 0.1, math.sin(a) * r))
		end
		-- hexagrama no chão (dois triângulos)
		local lines = {}
		for i = 1, 6 do
			local a, b = pts[i], pts[(i + 1) % 6 + 1]
			local l = fxPart({ Color = gold, Transparency = 0.2 })
			stretch(l, a, b, 0.35, 0.1)
			table.insert(lines, l)
		end
		local pillars = {}
		for i = 1, 6 do
			table.insert(pillars, fxPart({ Shape = Enum.PartType.Cylinder, Color = i % 2 == 0 and WHITE or gold, Transparency = 0.3 }))
		end
		animate(dur, function(k, t)
			local u = math.clamp((t - 0.35) / (dur - 0.55), 0, 1) -- varrem até o centro
			local w = 2.2 * math.min(1, t / 0.25)
			for i, pl in ipairs(pillars) do
				local a = i / 6 * TAU + u * 1.4
				local rr = r * (1 - outCubic(u))
				local at = pos + Vector3.new(math.cos(a) * rr, 30, math.sin(a) * rr)
				pl.Size = Vector3.new(60, w, w)
				pl.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
				pl.Transparency = 0.25 + 0.15 * math.sin(t * 30 + i)
			end
			for _, l in ipairs(lines) do
				l.Transparency = 0.2 + 0.8 * k
			end
		end, function()
			kill(pillars)
			kill(lines)
			-- coluna sagrada final
			local col = fxPart({ Shape = Enum.PartType.Cylinder, Color = WHITE, Transparency = 0 })
			animate(0.6, function(k)
				local w = 10 * outCubic(math.min(1, k * 3)) * (1 - k * 0.6)
				col.Size = Vector3.new(80, w, w)
				col.CFrame = CFrame.new(pos + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.pi / 2)
				col.Transparency = k ^ 1.5
			end, function()
				col:Destroy()
			end)
			flash(pos + Vector3.new(0, 2, 0), 9, C(255, 245, 200), 0.35)
			groundRing(pos, 2, r * 1.4, gold, 0.6, 0.9)
			burst(pos + Vector3.new(0, 2, 0), gold, 40, 1.3, 35)
			light(pos + Vector3.new(0, 4, 0), gold, 50, 0.8)
			shake(pos, 0.6, 70)
		end)
		burst(pos + Vector3.new(0, 1, 0), gold, 20, 0.8, 6, TEX.Sparkle, { Acceleration = Vector3.new(0, 6, 0) })
	end

	------------------------------------------------------------ GOLEM: prisão de cristal
	function H.C_CrystalPrison(p)
		local model = p.Model
		local root = rootOf(model)
		if not root or full(14) then
			return
		end
		local dur = p.Duration or 1.6
		local size = model:GetExtentsSize()
		local base = feetOf(model) or root.Position
		local rr = math.max(size.X, size.Z) * 0.55 + 0.8
		local hh = size.Y * 1.3 + 2
		local cry = C(80, 245, 225)
		local walls, tops = {}, {}
		for i = 1, 6 do
			table.insert(walls, fxPart({ Size = Vector3.new(0.6, 0.2, rr * 1.2), Color = cry, Material = GLASS, Transparency = 0.35 }))
			table.insert(
				tops,
				fxPart({ Shape = Enum.PartType.Wedge, Size = Vector3.new(0.5, 0.2, rr), Color = C(200, 255, 250), Material = GLASS, Transparency = 0.3 })
			)
		end
		local core = fxPart({ Size = Vector3.new(rr * 1.5, 0.2, rr * 1.5), Color = cry, Transparency = 0.75 })
		animate(dur, function(_, t)
			local g = outCubic(math.min(1, t / 0.25))
			local h = hh * g
			for i, w in ipairs(walls) do
				local a = i / 6 * TAU
				w.Size = Vector3.new(0.6, math.max(0.2, h), rr * 1.18)
				w.CFrame = CFrame.new(base) * CFrame.Angles(0, a, 0) * CFrame.new(rr, h / 2, 0)
				local tp = tops[i]
				tp.Size = Vector3.new(0.5, math.max(0.2, h * 0.35), rr * 1.0)
				tp.CFrame = CFrame.new(base) * CFrame.Angles(0, a, 0) * CFrame.new(rr * 0.5, h + h * 0.175, 0) * CFrame.Angles(0, -math.pi / 2, 0)
			end
			core.Size = Vector3.new(rr * 1.6, math.max(0.2, h), rr * 1.6)
			core.CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, math.pi / 6, 0)
		end, function()
			kill(walls)
			kill(tops)
			core:Destroy()
		end)
		burst(base + Vector3.new(0, 1, 0), cry, 24, 0.9, 20)
		light(base + Vector3.new(0, 3, 0), cry, 22, dur)
	end

	function H.C_CrystalShatter(p)
		local pos = p.Position
		if not pos then
			return
		end
		local cry = C(80, 245, 225)
		flash(pos + Vector3.new(0, 2, 0), 7, C(210, 255, 250), 0.3)
		if not full(14) then
			for _ = 1, q(14) do
				local s = rnd(0.6, 1.6)
				local shard =
					fxPart({ Size = Vector3.new(s * 0.5, s * 1.6, s * 0.5), Color = cry, Material = GLASS, Transparency = 0.2, CFrame = CFrame.new(pos) })
				local v = Vector3.new(rnd(-1, 1), rnd(0.6, 1.5), rnd(-1, 1)).Unit * rnd(25, 45)
				local spin = Vector3.new(rnd(-9, 9), rnd(-9, 9), rnd(-9, 9))
				animate(rnd(0.8, 1.1), function(k, t)
					local at = pos + v * t + Vector3.new(0, -50 * t * t, 0)
					if at.Y < pos.Y - 0.5 then
						at = Vector3.new(at.X, pos.Y - 0.5, at.Z)
					end
					shard.CFrame = CFrame.new(at) * CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t)
					shard.Transparency = 0.2 + 0.8 * math.max(0, k - 0.6) / 0.4
				end, function()
					shard:Destroy()
				end)
			end
		end
		groundRing(pos, 2, 14, cry, 0.5, 0.8)
		burst(pos + Vector3.new(0, 1, 0), C(220, 255, 255), 40, 1.1, 40)
		light(pos, cry, 30, 0.6)
		shake(pos, 0.8, 70)
	end

	------------------------------------------------------------ FÊNIX DE GELO
	function H.C_IceEgg(p)
		local model = p.Model
		local root = rootOf(model)
		if not root or full(8) then
			return
		end
		local dur = p.Duration or 1.4
		local size = model:GetExtentsSize()
		local egg = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, Color = C(190, 235, 255), Material = Enum.Material.Ice, Transparency = 0.25 })
		local cracks = {}
		for _ = 1, 5 do
			table.insert(
				cracks,
				{ fxPart({ Size = Vector3.new(0.15, 0.15, 1), Color = WHITE, Transparency = 1 }), Vector3.new(rnd(-1, 1), rnd(-0.6, 1), rnd(-1, 1)).Unit }
			)
		end
		local eggSize = Vector3.new(size.X * 0.9 + 1.5, size.Y * 1.25 + 1.5, size.Z * 0.7 + 1.5)
		animate(dur, function(k, t)
			if not root.Parent then
				return true
			end
			local g = outCubic(math.min(1, t / 0.25))
			egg.Size = eggSize * g
			egg.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, t * 0.5, 0)
			for i, c in ipairs(cracks) do
				local show = k > 0.45 + i * 0.08
				local at = root.Position + c[2] * eggSize.Y * 0.48
				c[1].CFrame = CFrame.lookAt(at, at + c[2]:Cross(Vector3.yAxis)) * CFrame.Angles(0, 0, i)
				c[1].Size = Vector3.new(0.15, 0.15, show and eggSize.X * 0.5 or 0.1)
				c[1].Transparency = show and 0 or 1
			end
			return nil
		end, function()
			egg:Destroy()
			for _, c in ipairs(cracks) do
				c[1]:Destroy()
			end
		end)
		burst(root.Position, C(220, 245, 255), 16, 0.8, 8)
	end

	function H.C_FeatherStorm(p)
		local pos = p.Position
		if not pos then
			return
		end
		local r = p.Radius or 16
		local n = math.min(p.Count or 14, q(14) + 2)
		flash(pos, 6, C(220, 245, 255), 0.3)
		if full(n * 2) then
			return
		end
		local cols = { C(240, 250, 255), C(150, 215, 255), C(80, 160, 255) }
		for i = 1, n do
			local a = i / n * TAU
			local feather = fxPart({ Size = Vector3.new(0.25, 0.8, 2.6), Color = cols[i % 3 + 1], Material = GLASS, Transparency = 0.1 })
			local tip = fxPart({ Size = Vector3.new(0.3, 0.3, 1.2), Color = WHITE })
			local land = pos + Vector3.new(math.cos(a + 0.6) * r * rnd(0.6, 1), -1, math.sin(a + 0.6) * r * rnd(0.6, 1))
			local from = pos + Vector3.new(0, 1, 0)
			animate(0.45 + i * 0.015, function(k)
				-- espiral para fora e cravando no chão
				local u = outCubic(k)
				local sp = a + u * 0.6
				local at = from:Lerp(land, u)
					+ Vector3.new(math.cos(sp), 0, math.sin(sp)) * math.sin(u * math.pi) * 3
					+ Vector3.new(0, math.sin(u * math.pi) * 4, 0)
				local nextAt = at + (land - from).Unit
				feather.CFrame = CFrame.lookAt(at, nextAt)
				tip.CFrame = feather.CFrame * CFrame.new(0, 0, -1.4)
			end, function()
				tip:Destroy()
				feather.CFrame = CFrame.new(land + Vector3.new(0, 1, 0)) * CFrame.Angles(math.rad(-70), a, 0)
				animate(1.6, function(k)
					feather.Transparency = 0.1 + 0.9 * math.max(0, k - 0.6) / 0.4
				end, function()
					feather:Destroy()
				end)
				burst(land + Vector3.new(0, 0.5, 0), C(200, 240, 255), 5, 0.6, 8)
			end)
		end
		groundRing(pos - Vector3.new(0, 1, 0), 2, r, C(170, 225, 255), 0.6, 0.8)
		burst(pos, C(230, 250, 255), 40, 1, 40)
		light(pos, C(170, 225, 255), 40, 0.7)
		shake(pos, 0.5, 60)
	end

	------------------------------------------------------------ COLOSSO DO TROVÃO
	local bolt = Effects.Bolt
	function H.C_RodStrike(p)
		local model = p.Model
		local root = rootOf(model)
		if not root then
			return
		end
		local cloud = model:FindFirstChild("NuvemBolo")
		local top = (cloud and cloud.Position or root.Position + Vector3.new(0, root.Size.Y * 2, 0))
		local sky = top + Vector3.new(rnd(-3, 3), 45, rnd(-3, 3))
		local yellow = C(255, 230, 80)
		if bolt then
			bolt(sky, top, yellow, 0.35, 1.6)
			task.delay(0.12, function()
				if root.Parent then
					bolt(top, root.Position, yellow, 0.3, 1)
				end
			end)
		end
		flash(top, 6, C(255, 250, 200), 0.3)
		burst(root.Position, yellow, 30, 1, 30, TEX.Spark)
		light(root.Position, yellow, 40, 0.6)
		shake(root.Position, 0.5, 70)
	end

	-- muralha de raios: linha de raios verticais que avança pelo chão até o fim
	function H.C_ThunderWall(p)
		local from, dir = p.From, p.Direction
		if not (from and dir) then
			return
		end
		local len, width, dur = p.Length or 30, p.Width or 10, p.Duration or 0.6
		local right = dir:Cross(Vector3.yAxis).Unit
		local rows = math.max(3, math.floor(len / 4))
		local per = math.max(2, q(4))
		local yellow = C(255, 230, 80)
		for i = 1, rows do
			task.delay(dur * (i - 1) / rows, function()
				local c = from + dir * (i * len / rows)
				for j = 1, per do
					local x = (j - (per + 1) / 2) / per * width
					local bottom = c + right * (x + rnd(-0.8, 0.8))
					if bolt and not full(per * 2) then
						bolt(bottom + Vector3.new(rnd(-1, 1), rnd(10, 16), rnd(-1, 1)), bottom, j % 2 == 0 and yellow or C(170, 220, 255), 0.25, 0.7)
					end
				end
				burst(c + Vector3.new(0, 0.5, 0), yellow, 10, 0.8, 18, TEX.Spark)
				if i % 2 == 0 then
					light(c, yellow, 20, 0.25)
				end
			end)
		end
		shake(from, 0.5, 70)
	end

	------------------------------------------------------------ UNICÓRNIO: arco-íris
	function H.C_Rainbow(p)
		local from, to = p.From, p.To
		if not (from and to) or full(60) then
			return
		end
		local height, dur = p.Height or 14, p.Duration or 1.6
		local n = q(14) + 4
		local bands = {}
		local span = to - from
		local right = Vector3.new(-span.Z, 0, span.X)
		right = right.Magnitude > 0.01 and right.Unit or Vector3.xAxis
		for b, col in ipairs(RAINBOW) do
			local segs = {}
			for _ = 1, n do
				table.insert(segs, fxPart({ Color = col, Transparency = 0.15 }))
			end
			table.insert(bands, { segs, b })
		end
		local function arc(u, b)
			local y = math.sin(u * math.pi) * (height + (3.5 - b) * 0.9)
			return from:Lerp(to, u) + Vector3.new(0, y + 0.5, 0)
		end
		animate(dur, function(k, t)
			local reveal = math.min(1, t / 0.4)
			for _, e in ipairs(bands) do
				for i, s in ipairs(e[1]) do
					local u0, u1 = (i - 1) / n, i / n
					if u1 <= reveal then
						stretch(s, arc(u0, e[2]), arc(u1, e[2]), 0.9, 0.4)
						s.Transparency = 0.15 + 0.85 * math.max(0, k - 0.75) / 0.25
					else
						s.Transparency = 1
					end
				end
			end
		end, function()
			for _, e in ipairs(bands) do
				kill(e[1])
			end
		end)
		burst(from + Vector3.new(0, 1, 0), C(255, 220, 250), 20, 1, 14)
	end

	function H.C_Prism(p)
		local pos = p.Position
		if not pos then
			return
		end
		local r = p.Radius or 10
		flash(pos + Vector3.new(0, 1.5, 0), r * 0.7, WHITE, 0.3)
		for i, col in ipairs(RAINBOW) do
			task.delay(i * 0.05, function()
				groundRing(pos, 2, r * (0.6 + i * 0.12), col, 0.55, 0.7)
			end)
			burst(pos + Vector3.new(0, 1.5, 0), col, 8, 1, 35)
		end
		light(pos, C(255, 200, 255), 35, 0.6)
		shake(pos, 0.6, 60)
	end

	------------------------------------------------------------ SAMURAI ONI: katanas voadoras
	local BLADE_PARTS = { KatanaLamina = true, KatanaFio = true, KatanaCabo = true, KatanaTsuba = true }
	function H.C_Blades(p)
		local owner, target = p.Model, p.Target
		local oRoot, tRoot = rootOf(owner), rootOf(target)
		if not (oRoot and tRoot) or full(16) then
			return
		end
		local dur = p.Duration or 2.2
		local count = p.Count or 4
		hideParts(owner, BLADE_PARTS, dur)
		local blades = {}
		for i = 1, count do
			local blade = fxPart({ Size = Vector3.new(0.15, 0.5, 4.2), Color = C(225, 230, 240), Material = Enum.Material.Metal })
			local edge = fxPart({ Size = Vector3.new(0.1, 0.12, 4.1), Color = C(255, 50, 50) })
			local hilt = fxPart({ Size = Vector3.new(0.25, 0.25, 1.1), Color = C(30, 20, 25), Material = Enum.Material.Fabric })
			table.insert(blades, { blade, edge, hilt, (i - 1) / count * TAU })
		end
		local trailT = 0
		animate(dur, function(k, t)
			if not (oRoot.Parent and tRoot.Parent) then
				return true
			end
			local out = math.min(1, t / 0.3)
			local back = k > 0.85 and (k - 0.85) / 0.15 or 0
			local orbitR = math.max(3.5, tRoot.Size.Z * 0.9 + 2)
			for i, e in ipairs(blades) do
				local a = e[4] + t * 9
				local tilt = math.sin(t * 4 + i) * 0.6
				local orbit = tRoot.Position + Vector3.new(math.cos(a) * orbitR, math.sin(a * 2 + i) * 1.2 + 0.5, math.sin(a) * orbitR)
				local home = oRoot.Position + Vector3.new(0, oRoot.Size.Y, 0)
				local at = home:Lerp(orbit, out):Lerp(home, back)
				local cf = CFrame.new(at) * CFrame.Angles(tilt, -a, 0) * CFrame.Angles(0, 0, t * 20)
				e[1].CFrame = cf
				e[2].CFrame = cf * CFrame.new(0, -0.28, 0)
				e[3].CFrame = cf * CFrame.new(0, 0, 2.6)
			end
			if t - trailT > 0.12 then
				trailT = t
				burst(tRoot.Position, C(255, 60, 60), 4, 0.8, 20, TEX.Spark)
			end
			return nil
		end, function()
			for _, e in ipairs(blades) do
				e[1]:Destroy()
				e[2]:Destroy()
				e[3]:Destroy()
			end
		end)
	end

	------------------------------------------------------------ MECHA: mísseis teleguiados e canhão
	function H.C_Missiles(p)
		local owner, target = p.Model, p.Target
		local oRoot = rootOf(owner)
		if not oRoot then
			return
		end
		local count = math.min(p.Count or 12, 6 + q(6))
		local flight, interval = p.Flight or 1.1, p.Interval or 0.08
		local tips = {}
		for _, d in ipairs(owner:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "MissilPonta" then
				table.insert(tips, d)
			end
		end
		local lastPos = p.Position or oRoot.Position
		for i = 1, count do
			task.delay((i - 1) * interval, function()
				if not oRoot.Parent or full(3) then
					return
				end
				local src = tips[(i - 1) % math.max(1, #tips) + 1]
				local start = src and src.Parent and src.Position or oRoot.Position + Vector3.new(0, oRoot.Size.Y, 0)
				local up = start + Vector3.new(rnd(-6, 6), rnd(14, 22), rnd(-6, 6))
				local body = fxPart({ Size = Vector3.new(0.45, 0.45, 1.6), Color = C(235, 235, 240), Material = Enum.Material.Metal })
				local nose = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, Color = C(230, 50, 40), Material = Enum.Material.SmoothPlastic })
				local att = Instance.new("Attachment")
				att.Parent = body
				att.Position = Vector3.new(0, 0, 0.8)
				local smoke = Instance.new("ParticleEmitter")
				smoke.Texture = TEX.Smoke
				smoke.Color = ColorSequence.new(C(220, 220, 225))
				smoke.LightEmission = 0
				smoke.Size = NS(0, 0.5, 1, 1.8)
				smoke.Transparency = NS(0, 0.3, 1, 1)
				smoke.Lifetime = NumberRange.new(0.5, 0.8)
				smoke.Speed = NumberRange.new(0, 1)
				smoke.Rate = 30 * quality()
				smoke.Parent = att
				local fire = Instance.new("ParticleEmitter")
				fire.Texture = TEX.Fire
				fire.Color = ColorSequence.new(C(255, 180, 60))
				fire.LightEmission = 1
				fire.Size = NS(0, 0.6, 1, 0)
				fire.Lifetime = NumberRange.new(0.1, 0.2)
				fire.Speed = NumberRange.new(0, 0)
				fire.Rate = 40 * quality()
				fire.Parent = att
				local last = start
				animate(flight, function(k)
					local tRoot = rootOf(target)
					if tRoot then
						lastPos = tRoot.Position
					end
					local goal = lastPos + Vector3.new(math.sin(i * 2.3) * 2.5, -0.5, math.cos(i * 1.7) * 2.5)
					-- curva de Bézier: sobe e cai teleguiado
					local a = start:Lerp(up, k)
					local b = up:Lerp(goal, k)
					local at = a:Lerp(b, k)
					if (at - last).Magnitude > 0.01 then
						body.CFrame = CFrame.lookAt(at, at + (at - last))
					end
					nose.CFrame = body.CFrame * CFrame.new(0, 0, -0.85)
					last = at
				end, function()
					local hit = body.Position
					body:Destroy()
					nose:Destroy()
					flash(hit, 3, C(255, 200, 100), 0.2)
					burst(hit, C(255, 150, 50), 10, 1.8, 18, TEX.Fire, { LightEmission = 1 })
					burst(hit, C(90, 85, 85), 6, 2.5, 8, TEX.Smoke, { LightEmission = 0 })
					if i % 3 == 0 then
						light(hit, C(255, 160, 60), 18, 0.25)
						shake(hit, 0.2, 50)
					end
				end)
			end)
		end
	end

	function H.C_Cannon(p)
		local owner = p.Model
		local oRoot = rootOf(owner)
		if not (oRoot and p.To) then
			return
		end
		local mouth = owner:FindFirstChild("CanhaoBoca")
		local from = mouth and mouth.Position or oRoot.Position
		local cyan = C(80, 230, 255)
		local beam = fxPart({ Color = cyan, Transparency = 0.1 })
		local core = fxPart({ Color = WHITE })
		animate(0.5, function(k)
			local w = 2.6 * math.sin(math.min(1, k * 2) * math.pi * 0.5) * (1 - k * 0.7)
			stretch(beam, from, p.To, w + 0.1)
			stretch(core, from, p.To, w * 0.4 + 0.05)
			beam.Transparency = 0.1 + 0.9 * k ^ 2
			core.Transparency = k ^ 2
		end, function()
			beam:Destroy()
			core:Destroy()
		end)
		flash(from, 3, cyan, 0.2)
		flash(p.To, 6, cyan, 0.35)
		burst(p.To, cyan, 30, 1.2, 35, TEX.Spark)
		light(p.To, cyan, 30, 0.5)
		shake(p.To, 0.5, 60)
	end

	------------------------------------------------------------ PLANETA: a lua cai
	local MOON_PARTS = { Lua = true, Cratera = true }
	function H.C_MoonFall(p)
		local owner = p.Model
		local oRoot = rootOf(owner)
		local pos = p.Position
		if not (oRoot and pos) or full(10) then
			return
		end
		local delay = p.Delay or 1.4
		local r = p.Radius or 11
		local moonPart = owner:FindFirstChild("Lua")
		local start = moonPart and moonPart.Position or oRoot.Position + Vector3.new(4, 2, 0)
		hideParts(owner, MOON_PARTS, delay + 1.5)
		local moon = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Color = C(205, 205, 215), Material = Enum.Material.Slate })
		local craters = {}
		for i = 1, 5 do
			table.insert(craters, {
				fxPart({ Shape = Enum.PartType.Ball, Color = C(150, 150, 162), Material = Enum.Material.Slate }),
				Vector3.new(math.cos(i * 1.3), math.sin(i * 2.1) * 0.6, math.sin(i * 1.3)).Unit,
			})
		end
		local a = Instance.new("Attachment")
		a.Parent = moon
		local fire = Instance.new("ParticleEmitter")
		fire.Texture = TEX.Fire
		fire.Color = ColorSequence.new(C(255, 220, 160), C(255, 120, 60))
		fire.LightEmission = 1
		fire.Size = NS(0, 4, 1, 1)
		fire.Transparency = NS(0, 0.3, 1, 1)
		fire.Lifetime = NumberRange.new(0.3, 0.5)
		fire.Speed = NumberRange.new(2, 4)
		fire.SpreadAngle = Vector2.new(30, 30)
		fire.Rate = 0
		fire.Parent = a
		local sky = pos + Vector3.new(r * 0.6, 55, r * 0.4)
		animate(delay, function(k)
			local size
			local at
			if k < 0.45 then
				local u = outCubic(k / 0.45)
				at = start:Lerp(sky, u)
				size = 2 + 14 * u
			else
				local u = ((k - 0.45) / 0.55) ^ 2
				at = sky:Lerp(pos + Vector3.new(0, 4, 0), u)
				size = 16 - 4 * u
				fire.Rate = 60 * quality()
			end
			moon.Size = Vector3.one * size
			moon.CFrame = CFrame.new(at) * CFrame.Angles(k * 3, k * 2, 0)
			for _, c in ipairs(craters) do
				c[1].Size = Vector3.new(size * 0.3, size * 0.3, size * 0.1)
				c[1].CFrame = CFrame.lookAt(at + moon.CFrame.Rotation * c[2] * size * 0.46, at + moon.CFrame.Rotation * c[2] * size)
			end
		end, function()
			moon:Destroy()
			for _, c in ipairs(craters) do
				c[1]:Destroy()
			end
			if H.Explosion then
				H.Explosion({ Position = pos + Vector3.new(0, 1, 0), Radius = r, Color = C(230, 220, 200), Kind = "void" })
			end
			-- cratera com borda de rochas
			if not full(12) then
				local rocks = {}
				for i = 1, q(12) do
					local ang = i / 12 * TAU
					local s = rnd(1.5, 3)
					table.insert(
						rocks,
						fxPart({
							Size = Vector3.new(s, s * 0.8, s),
							Color = C(120, 115, 120),
							Material = Enum.Material.Slate,
							CFrame = CFrame.new(pos + Vector3.new(math.cos(ang) * r * 0.75, 0.3, math.sin(ang) * r * 0.75))
								* CFrame.Angles(rnd(0, 3), rnd(0, 3), 0),
						})
					)
				end
				task.delay(2.5, function()
					kill(rocks)
				end)
			end
			groundRing(pos, 2, r * 1.8, C(235, 210, 160), 0.7, 1.2)
			task.delay(0.15, function()
				groundRing(pos, 2, r * 2.2, C(205, 170, 120), 0.8, 0.9)
			end)
			burst(pos + Vector3.new(0, 2, 0), C(170, 160, 150), 30, 5, 20, TEX.Smoke, { LightEmission = 0, Size = NS(0, 3, 1, 8) })
			shake(pos, 1, 90)
		end)
	end
end
