-- ✨ EFEITOS DAS HABILIDADES NOVAS (2026-10, pedido do dono: "habilidades mais diferentes, com mais animação e
-- efeitos especiais únicos"). O servidor (server/Services/SkillKit.lua) manda efeitos genéricos "S_*" com o
-- NOME DE UM OBJETO (client/SkillArt.lua: osso, frisbee, nota musical, abelha, âncora, OVNI, navio...) e o
-- jeito de mexer; cada habilidade combina objetos, cores, caminhos e tempos diferentes → todas ficam únicas.
--
--   S_Shot   tiros com objeto (arco, giro, rastro, persegue, bumerangue)     S_Rain   chuva de objetos do céu
--   S_Ring   anel de objetos que se abre                                      S_Orbit  objetos girando no cachorro
--   S_Prop   objeto grande com caminho (cai, sobe do chão, voa, paira, gira, bate)
--   S_Line   linha no chão (cheiro, corrida, rachadura, corte, fogo, gelo, raio, patinhas)
--   S_Zone   área no chão por um tempo (poça, mel, lava, gelo, veneno, areia, flores, pista de dança...)
--   S_Mark   marca de estado no alvo (tonto, dormindo, preso, teia, bolha, vinhas, gaiola, faixas, choque...)
--   S_Aura   aura no próprio cachorro (escudo, fúria, pressa, cura, pedra, sagrado, sirene...)
--   S_Burst  rajada de objetos (confete, terra, folhas, ossos, notas, corações, moedas...)
--   S_Beam   raio/jato da boca          S_Cone  sopro em cone          S_Wave  onda andando pelo chão
--   S_Pillar coluna (fogo, gelo, luz...) S_Summon criaturas (abelhas, lobos, fantasmas, esqueletos, touros...)
--   S_Sky    céu/tela muda no Supremo   S_Charge carga de energia no corpo   S_Pop  texto de quadrinho (BONK!)
--
-- Regras do Artista de Efeitos (equipe/efeitos-especiais.md): aviso → impacto → resíduo; tudo some sozinho;
-- quantidade segue a qualidade gráfica (q); limite de peças (full); uma só conexão de quadro anima tudo.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SkillArt = require(script.Parent.Parent:WaitForChild("SkillArt"))

local C = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local BLACK = C(25, 20, 30)
local TAU = math.pi * 2
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local UP = Vector3.new(0, 1, 0)

local TEX = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Spark = "rbxasset://textures/particles/fire_sparks_main.dds",
	Glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	Swirl = "rbxasset://textures/particles/forcefield_vortex_main.dds",
}

local RAINBOW = { C(255, 70, 80), C(255, 160, 50), C(255, 230, 70), C(90, 220, 110), C(80, 170, 255), C(170, 100, 255) }
local CONFETTI = { C(255, 80, 90), C(255, 200, 60), C(90, 220, 120), C(80, 170, 255), C(200, 110, 255), C(255, 140, 200) }

return function(H, Effects)
	local player = Players.LocalPlayer

	------------------------------------------------------------ qualidade / limites
	local QUALITY = { Alto = 1, ["Médio"] = 0.6, Baixo = 0.3 }
	local function quality(): number
		return QUALITY[player and player:GetAttribute("GraphicsQuality") or "Alto"] or 1
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

	local MAX_PARTS = 380
	local myParts = 0
	local function full(extra: number?): boolean
		return myParts + (extra or 0) > MAX_PARTS * (0.4 + 0.6 * quality())
	end
	local function track(p: BasePart)
		myParts += 1
		p.Destroying:Connect(function()
			myParts -= 1
		end)
		Debris:AddItem(p, 16) -- segurança: nada fica para sempre
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
		track(p)
		p.Parent = folder
		return p
	end

	-- objeto do SkillArt (nil se a tela já tem peças demais)
	local function build(motif: string?, size: number?, c1: Color3?, c2: Color3?, force: boolean?)
		if not motif or not SkillArt.Has(motif) then
			return nil
		end
		if not force and full(6) then
			return nil
		end
		local rig = SkillArt.Build(motif, size or 1, c1, c2, folder)
		if rig then
			for _, p in ipairs(rig.Parts) do
				track(p)
			end
		end
		return rig
	end

	------------------------------------------------------------ utilidades
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
	local function smooth(k: number): number
		k = math.clamp(k, 0, 1)
		return k * k * (3 - 2 * k)
	end
	local function pick(list)
		return list[math.random(1, #list)]
	end
	local function unitRandom(up: number?)
		local v = Vector3.new(rnd(-1, 1), rnd(-1, 1) + (up or 0), rnd(-1, 1))
		return v.Magnitude > 0.01 and v.Unit or UP
	end

	-- animação central: fn(k, t, dt); devolver true encerra antes
	local anims = {}
	local function animate(duration: number, fn, done)
		table.insert(anims, { Start = os.clock(), Last = os.clock(), Dur = math.max(duration, 0.001), Fn = fn, Done = done })
	end
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for i = #anims, 1, -1 do
			local a = anims[i]
			local k = math.clamp((now - a.Start) / a.Dur, 0, 1)
			local dt = now - a.Last
			a.Last = now
			local ok, stop = pcall(a.Fn, k, now - a.Start, dt)
			if not ok then
				warn("[Skills] anim", stop)
			end
			if k >= 1 or stop == true or not ok then
				anims[i] = anims[#anims]
				anims[#anims] = nil
				if a.Done then
					local okDone, err = pcall(a.Done)
					if not okDone then
						warn("[Skills] fim", err)
					end
				end
			end
		end
	end)

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

	-- rajada de partículas num ponto
	local function puff(position: Vector3, color: any, count: number, size: number, speed: number, texture: string?, extra)
		local a = anchor(position, 3)
		local seq = color
		if typeof(color) == "Color3" then
			seq = ColorSequence.new(color)
		end
		local props = {
			Texture = texture or TEX.Sparkle,
			Color = seq,
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

	local function smoke(position: Vector3, color: Color3, count: number, size: number, speed: number)
		puff(position, color, count, size, speed, TEX.Smoke, {
			Size = NS(0, size * 0.5, 1, size * 1.6),
			Transparency = NS(0, 0.35, 1, 1),
			Lifetime = NumberRange.new(0.6, 1.2),
			LightEmission = 0,
			Drag = 3,
			Acceleration = Vector3.new(0, 3, 0),
		})
	end

	local lights = 0
	local function light(position: Vector3, color: Color3, range: number, duration: number, brightness: number?)
		if lights >= math.floor(3 + 6 * quality()) then
			return
		end
		lights += 1
		local a = anchor(position, duration + 0.1)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = math.min(range, 60)
		l.Brightness = brightness or 4
		l.Shadows = false
		l.Parent = a
		TweenService:Create(l, TweenInfo.new(duration), { Brightness = 0 }):Play()
		task.delay(duration, function()
			lights -= 1
		end)
	end

	local function disc(position: Vector3, radius: number, color: Color3, transparency: number?, material: Enum.Material?)
		return fxPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, radius * 2, radius * 2),
			CFrame = CFrame.new(position + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
			Transparency = transparency or 0.3,
			Material = material or NEON,
		})
	end
	local function setDisc(part: BasePart, radius: number)
		part.Size = Vector3.new(part.Size.X, math.max(0.1, radius * 2), math.max(0.1, radius * 2))
	end

	local function flash(position: Vector3, radius: number, color: Color3, duration: number?)
		local d = duration or 0.25
		local ball = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * radius * 0.4, CFrame = CFrame.new(position), Color = color })
		animate(d, function(k)
			ball.Size = Vector3.one * radius * (0.4 + 1.6 * outCubic(k))
			ball.Transparency = k ^ 0.6
		end, function()
			ball:Destroy()
		end)
	end

	-- anel que abre no chão (segmentos)
	local function groundRing(position: Vector3, r0: number, r1: number, color: Color3, duration: number, thick: number?)
		local n = math.max(10, math.floor(18 * (0.5 + 0.5 * quality())))
		local list = {}
		for _ = 1, n do
			table.insert(list, fxPart({ Size = Vector3.new(0.3, 0.3, 1), Color = color }))
		end
		local th = thick or math.max(0.4, r1 * 0.07)
		local cf = CFrame.new(position + Vector3.new(0, 0.12, 0))
		animate(duration, function(k)
			local e = outCubic(k)
			local r = r0 + (r1 - r0) * e
			local arc = TAU * r / n * 1.12
			for i, p in ipairs(list) do
				local a = i / n * TAU
				p.Size = Vector3.new(th * (1 - 0.7 * k), 0.3 * (1 - 0.5 * k), math.max(0.05, arc))
				p.CFrame = cf * CFrame.Angles(0, a, 0) * CFrame.new(r, 0.15, 0)
				p.Transparency = k ^ 1.3
			end
		end, function()
			for _, p in ipairs(list) do
				p:Destroy()
			end
		end)
	end

	local function rootOf(model)
		return model and model.Parent and model.PrimaryPart
	end
	local function headOf(model, index)
		return model and (model:FindFirstChild("Head" .. (index or 1)) or model:FindFirstChild("Head1"))
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
	local function mouthCF(model): CFrame?
		local head = headOf(model)
		if head then
			return head.CFrame * CFrame.new(0, -head.Size.Y * 0.15, -head.Size.Z * 0.75)
		end
		local root = rootOf(model)
		return root and root.CFrame * CFrame.new(0, root.Size.Y * 0.3, -root.Size.Z * 0.6) or nil
	end
	local function sizeOf(model): number
		local root = rootOf(model)
		return root and math.clamp(root.Size.Z / 4, 0.6, 5) or 1
	end

	local function shakeAt(position: Vector3, intensity: number, radius: number)
		if H.Shake then
			H.Shake({ Position = position, Intensity = intensity, Radius = radius })
		end
	end

	-- texto curto (BillboardGui) que sobe e some
	local function floatText(position: Vector3, text: string, color: Color3, size: number, life: number, rise: number, rot: number?)
		local a = anchor(position, life + 0.1)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(size * 4, size * 1.3)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.MaxDistance = 170
		gui.Parent = a
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = color
		label.TextScaled = true
		label.Font = Enum.Font.LuckiestGuy
		label.Rotation = rot or 0
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Color = BLACK
		stroke.Thickness = 3
		stroke.Parent = label
		local scale = Instance.new("UIScale")
		scale.Scale = 0.2
		scale.Parent = label
		animate(life, function(k)
			a.Position = position + Vector3.new(0, rise * outCubic(k), 0)
			local s
			if k < 0.12 then
				s = 0.2 + (k / 0.12) * 1.3
			elseif k < 0.25 then
				s = 1.5 - ((k - 0.12) / 0.13) * 0.5
			else
				s = 1
			end
			scale.Scale = s
			local fade = math.clamp((k - 0.7) / 0.3, 0, 1)
			label.TextTransparency = fade
			stroke.Transparency = fade
		end)
		return label
	end

	------------------------------------------------------------ objetos voando com física simples
	-- n peças de um motivo jogadas de um ponto (gravidade, giro, quicam no chão e somem)
	local function toss(motif: string, pos: Vector3, n: number, speed: number, size: number, colorFn, opts)
		opts = opts or {}
		n = q(n)
		local pieces = {}
		for i = 1, n do
			local col = colorFn and colorFn(i) or nil
			local rig = build(motif, size * rnd(0.7, 1.25), col, nil)
			if not rig then
				break
			end
			local dir = unitRandom(opts.up or 0.9)
			if opts.dir then
				dir = (opts.dir + unitRandom(0.6) * (opts.cone or 0.6)).Unit
			end
			table.insert(pieces, {
				rig = rig,
				p = pos + Vector3.new(rnd(-0.3, 0.3), rnd(0, 0.4), rnd(-0.3, 0.3)),
				v = dir * speed * rnd(0.5, 1),
				r = CFrame.Angles(rnd(0, TAU), rnd(0, TAU), rnd(0, TAU)),
				w = Vector3.new(rnd(-8, 8), rnd(-8, 8), rnd(-8, 8)),
			})
		end
		if #pieces == 0 then
			return
		end
		local floor = pos.Y - (opts.below or 0.4)
		local g = opts.gravity or 70
		local life = opts.life or 1.2
		animate(life, function(k, _t, dt)
			dt = math.min(dt, 1 / 20)
			for _, pc in ipairs(pieces) do
				pc.v -= Vector3.new(0, g * dt, 0)
				if opts.drag then
					pc.v *= (1 - opts.drag * dt)
				end
				pc.p += pc.v * dt
				if pc.p.Y < floor then
					pc.p = Vector3.new(pc.p.X, floor, pc.p.Z)
					pc.v = Vector3.new(pc.v.X * 0.5, math.abs(pc.v.Y) * 0.3, pc.v.Z * 0.5)
					pc.w *= 0.5
				end
				pc.r *= CFrame.Angles(pc.w.X * dt, pc.w.Y * dt, pc.w.Z * dt)
				SkillArt.Place(pc.rig, CFrame.new(pc.p) * pc.r)
				if k > 0.65 then
					SkillArt.Fade(pc.rig, (k - 0.65) / 0.35)
				end
			end
		end, function()
			for _, pc in ipairs(pieces) do
				SkillArt.Destroy(pc.rig)
			end
		end)
	end

	-- objetos que sobem flutuando (notas, corações, bolhas, Zzz)
	local function floatUp(motif: string, pos: Vector3, n: number, size: number, color: Color3?, life: number, spread: number)
		local list = {}
		for _ = 1, q(n) do
			local rig = build(motif, size * rnd(0.7, 1.2), color, nil)
			if not rig then
				break
			end
			table.insert(list, { rig = rig, o = Vector3.new(rnd(-spread, spread), rnd(0, 1), rnd(-spread, spread)), s = rnd(2, 5), ph = rnd(0, TAU), d = rnd(0, 0.4) })
		end
		animate(life, function(k, t)
			for _, it in ipairs(list) do
				local kk = math.clamp((t - it.d) / (life - it.d), 0, 1)
				local p = pos + it.o + Vector3.new(math.sin(t * 3 + it.ph) * 0.5, it.s * kk, 0)
				local cam = workspace.CurrentCamera
				local look = cam and flat(cam.CFrame.Position - p) or Vector3.new(0, 0, 1)
				if look.Magnitude < 0.01 then
					look = Vector3.new(0, 0, 1)
				end
				SkillArt.Place(it.rig, CFrame.lookAt(p, p - look) * CFrame.Angles(0, 0, math.sin(t * 4 + it.ph) * 0.3))
				SkillArt.Fade(it.rig, kk < 0.15 and 1 - kk / 0.15 or math.clamp((kk - 0.6) / 0.4, 0, 1))
			end
		end, function()
			for _, it in ipairs(list) do
				SkillArt.Destroy(it.rig)
			end
		end)
	end

	------------------------------------------------------------ impactos (fim de tiro, queda, criatura)
	local IMPACT_OF = {
		Bone = "Bones", Stick = "Pop", Ball = "Pop", Frisbee = "Burst", HotDog = "Pop", Bubble = "Splash", Drop = "Splash",
		Note = "Notes", Star = "Stars", Leaf = "Leaves", Fireball = "Fire", Lava = "Fire", Acid = "Poison", Ink = "Ink",
		Honey = "Honey", Shard = "Shatter", Icicle = "Shatter", Snowball = "Snow", Crystal = "Crystal", Rock = "Rock",
		Boulder = "Rock", Missile = "Explode", Rocket = "Explode", Shell = "Explode", Cannonball = "Explode", Bomb = "Explode",
		Skull = "Bones", GhostSkull = "Void", Ghost = "Void", Orb = "Burst", Plasma = "Shock", Bolt = "Shock",
		Shuriken = "Burst", Kunai = "Burst", Feather = "Feathers", Spore = "Poison", Mushroom = "Poison", Bee = "Poison",
		Balloon = "Splash", Heart = "Hearts", Pom = "Pop", Coin = "Coins", Comet = "Stars", Meteor = "Explode",
		ArcaneOrb = "Burst", Petal = "Petals", Flower = "Petals", Sand = "Sand", Needle = "Burst", Moon = "Holy",
		Planet = "Explode", Barrel = "Snow", Anchor = "Rock", Blade = "Burst", Lance = "Holy", Sword = "Holy",
		Fist = "Shock", Confetti = "Confetti", Egg = "Fire", Tornado = "Dust", Cloud = "Dust",
	}

	local function impact(kind: string?, pos: Vector3, radius: number?, color: Color3?, color2: Color3?)
		local r = radius or 3
		local col = color or WHITE
		kind = kind or "Burst"
		local up = pos + Vector3.new(0, 0.8, 0)
		if kind == "Pop" then
			smoke(up, C(245, 245, 240), 8, 1.6, 8)
			flash(up, r * 0.6, WHITE, 0.15)
			groundRing(pos, 0.5, r, col, 0.3, 0.35)
		elseif kind == "Splash" then
			puff(up, C(200, 235, 255), 26, 0.6, 26, TEX.Sparkle, { Acceleration = Vector3.new(0, -60, 0), Drag = 1, SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Top })
			groundRing(pos, 0.5, r * 1.2, col:Lerp(C(120, 190, 255), 0.5), 0.35)
			toss("Drop", up, 6, 18, 0.5, function()
				return col:Lerp(C(120, 200, 255), 0.6)
			end, { life = 0.8 })
		elseif kind == "Explode" then
			if H.Explosion then
				H.Explosion({ Position = up, Radius = r, Color = color or C(255, 130, 40) })
			end
		elseif kind == "Shatter" then
			flash(up, r * 0.5, C(220, 245, 255), 0.18)
			toss("Shard", up, 7, 26, 0.45, function()
				return col
			end, { life = 0.9 })
			puff(up, C(230, 250, 255), 14, 0.7, 20)
		elseif kind == "Dirt" or kind == "Rock" then
			smoke(pos, C(150, 125, 95), 12, 2.4, 12)
			toss("Rock", up, kind == "Rock" and 7 or 5, 26, kind == "Rock" and 0.6 or 0.4, nil, { life = 1 })
			groundRing(pos, 0.5, r * 1.1, C(170, 140, 100), 0.35)
		elseif kind == "Confetti" then
			toss("Confetti", up, 22, 30, 1, function(i)
				return CONFETTI[(i % #CONFETTI) + 1]
			end, { gravity = 25, drag = 1.5, life = 1.6 })
			flash(up, r * 0.6, WHITE, 0.15)
		elseif kind == "Smoke" or kind == "Dust" then
			smoke(up, color or C(200, 200, 200), 14, 2.5, 10)
		elseif kind == "Bones" then
			toss("Bone", up, 5, 22, 0.45, nil, { life = 1 })
			smoke(up, C(235, 225, 200), 6, 1.4, 8)
		elseif kind == "Leaves" or kind == "Petals" then
			toss(kind == "Leaves" and "Leaf" or "Petal", up, 10, 18, 0.7, function()
				return kind == "Leaves" and C(90, 190, 70):Lerp(C(160, 220, 80), math.random()) or (color or C(255, 170, 200))
			end, { gravity = 12, drag = 2, life = 1.5 })
		elseif kind == "Notes" then
			floatUp("Note", up, 5, 0.9, color or C(255, 120, 220), 1.1, 1.5)
			groundRing(pos, 0.5, r, col, 0.35)
		elseif kind == "Hearts" then
			floatUp("Heart", up, 5, 0.8, color or C(255, 90, 150), 1.1, 1.5)
		elseif kind == "Stars" then
			toss("Star", up, 6, 20, 0.6, function()
				return color or C(255, 230, 90)
			end, { gravity = 30, life = 0.9 })
			flash(up, r * 0.6, color or C(255, 240, 160), 0.2)
		elseif kind == "Coins" then
			toss("Coin", up, 8, 24, 0.7, nil, { life = 1.1 })
		elseif kind == "Honey" then
			local d = disc(pos, r * 0.8, C(255, 175, 30), 0.25, GLASS)
			animate(1.5, function(k)
				d.Transparency = 0.25 + 0.75 * math.clamp((k - 0.6) / 0.4, 0, 1)
			end, function()
				d:Destroy()
			end)
			toss("Honey", up, 4, 14, 0.35, nil, { life = 0.8 })
		elseif kind == "Ink" then
			local d = disc(pos, r * 0.9, C(25, 20, 35), 0.1, GLASS)
			animate(1.8, function(k)
				d.Transparency = 0.1 + 0.9 * math.clamp((k - 0.6) / 0.4, 0, 1)
			end, function()
				d:Destroy()
			end)
			toss("Ink", up, 5, 18, 0.4, nil, { life = 0.8 })
		elseif kind == "Fire" then
			puff(up, CS(0, C(255, 240, 180), 0.5, col, 1, C(120, 30, 10)), 20, 2.2, 18, TEX.Fire, { LightEmission = 1, Lifetime = NumberRange.new(0.3, 0.6) })
			puff(up, C(255, 190, 80), 14, 0.4, 30, TEX.Spark, { Acceleration = Vector3.new(0, -30, 0), Drag = 1 })
			groundRing(pos, 0.5, r * 1.1, col, 0.35)
		elseif kind == "Holy" then
			flash(up, r * 0.8, C(255, 245, 200), 0.25)
			for i = 1, q(5) do
				local a = i / 5 * TAU
				local ray = fxPart({ Size = Vector3.new(0.3, r * 2, 0.3), CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * r * 0.4, r, math.sin(a) * r * 0.4)), Color = color or C(255, 230, 140), Transparency = 0.2 })
				animate(0.5, function(k)
					ray.Transparency = 0.2 + 0.8 * k
				end, function()
					ray:Destroy()
				end)
			end
			groundRing(pos, 0.5, r * 1.2, color or C(255, 220, 120), 0.4)
		elseif kind == "Void" then
			local ball = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * r * 2, CFrame = CFrame.new(up), Color = C(20, 0, 35), Material = Enum.Material.SmoothPlastic, Transparency = 0.2 })
			animate(0.35, function(k)
				ball.Size = Vector3.one * math.max(0.2, r * 2 * (1 - k))
			end, function()
				ball:Destroy()
				flash(up, r * 0.7, color or C(190, 120, 255), 0.2)
			end)
			puff(up, color or C(170, 90, 255), 18, 0.8, 22)
		elseif kind == "Crystal" then
			toss("Crystal", up, 6, 22, 0.45, function()
				return col
			end, { life = 1 })
			puff(up, col, 16, 0.7, 20)
		elseif kind == "Bubbles" then
			floatUp("Bubble", up, 6, 0.8, color or C(170, 220, 255), 1.2, 1.6)
		elseif kind == "Feathers" then
			toss("Feather", up, 8, 14, 0.7, function()
				return color or WHITE
			end, { gravity = 6, drag = 2.5, life = 1.6 })
		elseif kind == "Shock" then
			flash(up, r * 0.5, C(255, 250, 200), 0.15)
			if Effects.Bolt then
				for _ = 1, q(4) do
					Effects.Bolt(up, up + unitRandom(0.2) * r * 1.4, color or C(255, 230, 90), 0.2, 0.25)
				end
			end
			puff(up, color or C(255, 235, 120), 16, 0.5, 30, TEX.Spark)
		elseif kind == "Snow" then
			smoke(up, C(240, 248, 255), 12, 2, 12)
			toss("Snowflake", up, 6, 12, 0.5, function()
				return C(220, 240, 255)
			end, { gravity = 6, drag = 2, life = 1.2 })
		elseif kind == "Poison" then
			puff(up, C(150, 240, 80), 18, 0.9, 16, TEX.Smoke, { LightEmission = 0.4, Lifetime = NumberRange.new(0.6, 1.1) })
			floatUp("Bubble", up, 3, 0.5, C(150, 240, 80), 0.8, 1)
			groundRing(pos, 0.5, r, C(140, 230, 70), 0.35)
		elseif kind == "Sand" then
			smoke(pos, C(225, 195, 130), 14, 2.5, 14)
			toss("Sand", up, 8, 20, 0.6, nil, { life = 0.9 })
		else -- Burst
			flash(up, r * 0.5, WHITE:Lerp(col, 0.4), 0.18)
			puff(up, col, 18, 0.7, 26, TEX.Spark, { Lifetime = NumberRange.new(0.2, 0.45), Drag = 5 })
			groundRing(pos, 0.5, r * 1.1, col, 0.3)
		end
		light(up, color or col, r * 3, 0.3)
	end
	Effects.SkillImpact = impact

	------------------------------------------------------------ rastro preso num objeto que voa
	local function trailOn(part: BasePart, kind: string?, color: Color3, size: number)
		if not kind or not part then
			return
		end
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.25 * size, 0)
		a0.Parent = part
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.25 * size, 0)
		a1.Parent = part
		local tr = Instance.new("Trail")
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Lifetime = 0.25
		tr.MinLength = 0.05
		tr.FaceCamera = true
		tr.LightEmission = 0.7
		tr.Color = ColorSequence.new(color)
		tr.Transparency = NS(0, 0.3, 1, 1)
		tr.WidthScale = NS(0, 1, 1, 0)
		tr.Parent = part
		local tex = ({ Smoke = TEX.Smoke, Fire = TEX.Fire, Sparkle = TEX.Sparkle, Swirl = TEX.Swirl, Spark = TEX.Spark })[kind]
		if tex then
			emitter(a0, {
				Texture = tex,
				Enabled = true,
				Rate = 40 * quality(),
				Color = kind == "Smoke" and ColorSequence.new(C(220, 220, 220)) or ColorSequence.new(color),
				Size = NS(0, 0.5 * size, 1, (kind == "Smoke" and 1.4 or 0.1) * size),
				Transparency = NS(0, 0.3, 1, 1),
				Lifetime = NumberRange.new(0.25, 0.45),
				Speed = NumberRange.new(0.5, 1.5),
				LightEmission = kind == "Smoke" and 0 or 0.9,
				SpreadAngle = Vector2.new(180, 180),
			})
		end
	end

	-- quem gira e como (padrão por objeto)
	local SPIN_OF = {
		Bone = Vector3.new(14, 0, 0),
		Stick = Vector3.new(12, 0, 0),
		HotDog = Vector3.new(9, 0, 0),
		Frisbee = Vector3.new(0, 22, 0),
		Shuriken = Vector3.new(0, 30, 0),
		Coin = Vector3.new(0, 14, 0),
		Star = Vector3.new(0, 0, 8),
		Rock = Vector3.new(6, 4, 0),
		Boulder = Vector3.new(5, 0, 0),
		Snowball = Vector3.new(8, 0, 0),
		Skull = Vector3.new(0, 0, 3),
		Barrel = Vector3.new(9, 0, 0),
		Anchor = Vector3.new(0, 0, 10),
		Gear = Vector3.new(14, 0, 0),
		Crystal = Vector3.new(0, 0, 9),
		Leaf = Vector3.new(0, 6, 4),
		Feather = Vector3.new(0, 4, 0),
		Kunai = Vector3.new(0, 0, 0),
		Pom = Vector3.new(6, 6, 0),
		Planet = Vector3.new(0, 3, 0),
	}

	------------------------------------------------------------ S_Pop: texto de quadrinho
	function H.S_Pop(p)
		local size = 36 * (p.Size or 1)
		floatText(p.Position, p.Text or "POW!", p.Color or C(255, 220, 60), size, 1.1, 3, rnd(-12, 12))
	end

	------------------------------------------------------------ S_Shot: tiros com objeto
	function H.S_Shot(p)
		local points = p.Points or {}
		local times = p.Times or {}
		local delays = p.Delays or {}
		local color = p.Color or WHITE
		local size = p.Size or 1
		local spin = p.Spin and Vector3.new(0, 0, p.Spin) or SPIN_OF[p.Motif or ""] or Vector3.zero
		for i, to in ipairs(points) do
			task.delay(delays[i] or 0, function()
				local m = p.Model and mouthCF(p.Model)
				local from = m and m.Position or p.From or to
				local rig = build(p.Motif, size, color, p.Color2)
				local time = times[i] or 0.5
				local arc = p.Arc or 0
				local targetRoot = p.Target and rootOf(p.Target)
				if rig and p.Trail then
					trailOn(rig.Parts[1], p.Trail, color, size)
				end
				local last = from
				local dest = to
				animate(time, function(k, t)
					if targetRoot and targetRoot.Parent then
						dest = targetRoot.Position
					end
					local pos = from:Lerp(dest, k) + Vector3.new(0, arc * 4 * k * (1 - k), 0)
					local dir = pos - last
					if dir.Magnitude < 0.001 then
						dir = dest - from
					end
					if dir.Magnitude < 0.001 then
						dir = Vector3.new(0, 0, -1)
					end
					if rig then
						SkillArt.Place(rig, CFrame.lookAt(pos, pos + dir) * CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t))
					end
					last = pos
				end, function()
					impact(p.Impact or IMPACT_OF[p.Motif or ""] or "Burst", dest, p.Radius or 2.5 * size, color, p.Color2)
					if rig and p.Back and p.Model then
						-- bumerangue: volta para quem jogou
						local start = dest
						animate(time * 0.9, function(k, t)
							local r = rootOf(p.Model)
							local home = r and r.Position or from
							local pos = start:Lerp(home, k) + Vector3.new(0, arc * 2 * k * (1 - k), 0)
							SkillArt.Place(rig, CFrame.new(pos) * CFrame.Angles(spin.X * t + 3, spin.Y * t, spin.Z * t))
						end, function()
							SkillArt.Destroy(rig)
						end)
					elseif rig then
						SkillArt.Destroy(rig)
					end
				end)
			end)
		end
	end

	------------------------------------------------------------ S_Rain: chuva de objetos do céu
	function H.S_Rain(p)
		local color = p.Color or WHITE
		local fall = p.Fall or 0.6
		local height = p.Height or 40
		local spin = p.Spin and Vector3.new(p.Spin, 0, 0) or SPIN_OF[p.Motif or ""] or Vector3.new(0, 2, 0)
		for i, pt in ipairs(p.Points or {}) do
			task.delay((i - 1) * (p.Gap or 0.1), function()
				if p.Tele ~= false and H.Telegraph then
					H.Telegraph({ Position = pt, Radius = p.Radius or 4, Duration = fall, Color = color })
				end
				local rig = build(p.Motif, p.Size or 1, color, p.Color2)
				local start = pt + Vector3.new(rnd(-5, 5), height, rnd(-5, 5))
				local dir = (pt - start).Unit
				animate(fall, function(k, t)
					if rig then
						local pos = start:Lerp(pt, k * k)
						SkillArt.Place(rig, CFrame.lookAt(pos, pos + dir) * CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t))
					end
				end, function()
					impact(p.Impact or IMPACT_OF[p.Motif or ""] or "Burst", pt, p.Radius or 4, color, p.Color2)
					if rig then
						if p.Stay then
							SkillArt.Place(rig, CFrame.lookAt(pt + Vector3.new(0, 0.6, 0), pt + Vector3.new(0, 0.6, 0) + dir))
							animate(p.Stay, function(k)
								if k > 0.7 then
									SkillArt.Fade(rig, (k - 0.7) / 0.3)
								end
							end, function()
								SkillArt.Destroy(rig)
							end)
						else
							SkillArt.Destroy(rig)
						end
					end
				end)
			end)
		end
	end

	------------------------------------------------------------ S_Ring: anel de objetos que se abre
	function H.S_Ring(p)
		local n = q(p.Count or 8)
		local pos = p.Position
		local r0, r1 = p.R0 or 1, p.R1 or 8
		local time = p.Time or 0.6
		local h = p.Height or 1
		local list = {}
		for i = 1, n do
			local rig = build(p.Motif, p.Size or 1, p.Color, p.Color2)
			if rig then
				table.insert(list, { rig = rig, a = (i - 1) / n * TAU + (p.Turn or 0) })
			end
		end
		local spin = SPIN_OF[p.Motif or ""] or Vector3.new(0, 4, 0)
		animate(time, function(k, t)
			local e = outCubic(k)
			local r = r0 + (r1 - r0) * e
			for _, it in ipairs(list) do
				local a = it.a + (p.Swirl or 0) * k
				local at = pos + Vector3.new(math.cos(a) * r, h + (p.Rise or 0) * e, math.sin(a) * r)
				local out = Vector3.new(math.cos(a), 0, math.sin(a))
				SkillArt.Place(it.rig, CFrame.lookAt(at, at + out) * CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t))
				if k > 0.6 then
					SkillArt.Fade(it.rig, (k - 0.6) / 0.4)
				end
			end
		end, function()
			for _, it in ipairs(list) do
				SkillArt.Destroy(it.rig)
			end
		end)
	end

	------------------------------------------------------------ S_Orbit: objetos girando em volta do cachorro
	function H.S_Orbit(p)
		local root = rootOf(p.Model)
		if not root then
			return
		end
		local n = p.Count or 3
		local radius = (p.Radius or 3) * sizeOf(p.Model)
		local speed = p.Speed or 3
		local dur = p.Duration or 1.5
		local h = p.Height or 0.5
		local list = {}
		for i = 1, n do
			local rig = build(p.Motif, p.Size or 1, p.Colors and p.Colors[i] or p.Color, p.Color2)
			if rig then
				table.insert(list, { rig = rig, a = (i - 1) / n * TAU })
			end
		end
		local spin = SPIN_OF[p.Motif or ""] or Vector3.zero
		local lastPos = {}
		animate(dur, function(k, t)
			if not root.Parent then
				return true
			end
			local grow = smooth(math.min(1, t / 0.3))
			for i, it in ipairs(list) do
				local a = it.a + t * speed
				local at = root.Position + Vector3.new(math.cos(a) * radius * grow, h + math.sin(t * 3 + i) * 0.3, math.sin(a) * radius * grow)
				lastPos[i] = at
				SkillArt.Place(it.rig, CFrame.lookAt(at, at + Vector3.new(-math.sin(a), 0, math.cos(a))) * CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t))
			end
			return false
		end, function()
			local targetRoot = p.Target and rootOf(p.Target)
			for i, it in ipairs(list) do
				local from = lastPos[i]
				if not from then
					SkillArt.Destroy(it.rig)
					continue
				end
				if p.End == "Fire" and (targetRoot or p.To) then
					local dest = targetRoot and targetRoot.Position or p.To
					local d = (i - 1) * 0.08
					task.delay(d, function()
						animate(0.3, function(k)
							local pos = from:Lerp(dest, k)
							SkillArt.Place(it.rig, CFrame.lookAt(pos, dest))
						end, function()
							impact(IMPACT_OF[p.Motif or ""] or "Burst", dest, 3, p.Colors and p.Colors[i] or p.Color)
							SkillArt.Destroy(it.rig)
						end)
					end)
				elseif p.End == "Burst" then
					local out = flat(from - root.Position)
					out = out.Magnitude > 0.01 and out.Unit or UP
					animate(0.35, function(k)
						local pos = from + out * 10 * outCubic(k)
						SkillArt.Place(it.rig, CFrame.new(pos))
						SkillArt.Fade(it.rig, k)
					end, function()
						SkillArt.Destroy(it.rig)
					end)
				else
					animate(0.25, function(k)
						SkillArt.Fade(it.rig, k)
					end, function()
						SkillArt.Destroy(it.rig)
					end)
				end
			end
		end)
	end

	------------------------------------------------------------ S_Prop: objeto grande com caminho
	-- Path: Fall (cai do céu e fica), Rise (sai do chão), Fly (vai de Position até To), Hover (desce, paira e sobe),
	-- Spin (gira no lugar), Swing (bate do alto para a frente), Countdown (semáforo 3-2-1), Grow (surge e morde)
	-- Look = para onde a frente aponta · Tilt = levanta a frente (graus) · Offset = desloca · End = Fade/Sink/Up/Shatter
	function H.S_Prop(p)
		local rig = build(p.Motif, p.Size or 1, p.Color, p.Color2, true)
		if not rig then
			return
		end
		local pos = p.Position
		local path = p.Path or "Fall"
		local time = p.Time or 0.6
		local hold = p.Hold or 0.8
		local look = p.Look and flat(p.Look) or Vector3.new(0, 0, -1)
		if look.Magnitude < 0.01 then
			look = Vector3.new(0, 0, -1)
		end
		local rot = CFrame.lookAt(Vector3.zero, look.Unit)
		if p.Tilt then
			rot *= CFrame.Angles(math.rad(p.Tilt), 0, 0) -- > 0 = levanta a frente (tubarão saltando)
		end
		local offset = p.Offset or Vector3.zero
		local function place(at: Vector3, extra: CFrame?)
			SkillArt.Place(rig, CFrame.new(at + offset) * rot * (extra or CFrame.identity))
		end
		local function finish(after: number)
			task.delay(after, function()
				if p.End == "Shatter" then
					impact("Shatter", pos, 6, p.Color)
					SkillArt.Destroy(rig)
				elseif p.End == "Sink" then
					animate(0.5, function(k)
						place(pos - UP * 6 * k)
						SkillArt.Fade(rig, k)
					end, function()
						SkillArt.Destroy(rig)
					end)
				elseif p.End == "Up" then
					animate(0.6, function(k)
						place(pos + UP * 40 * k * k)
						SkillArt.Fade(rig, math.max(0, k - 0.5) * 2)
					end, function()
						SkillArt.Destroy(rig)
					end)
				else
					animate(0.4, function(k)
						SkillArt.Fade(rig, k)
					end, function()
						SkillArt.Destroy(rig)
					end)
				end
			end)
		end
		local spinRate = p.Spin or 0
		if path == "Fall" then
			local start = pos + UP * (p.Height or 45)
			animate(time, function(k, t)
				place(start:Lerp(pos, k * k), CFrame.Angles(0, spinRate * t, 0))
			end, function()
				place(pos)
				impact(p.Impact or "Holy", pos, p.Radius or 8, p.Color)
				shakeAt(pos, p.Shake or 0.6, 60)
				finish(hold)
			end)
		elseif path == "Rise" or path == "Grow" then
			local depth = p.Depth or 8
			animate(time, function(k, t)
				place(pos - UP * depth * (1 - outCubic(k)), CFrame.Angles(0, spinRate * t, 0))
			end, function()
				impact(p.Impact or "Dirt", pos, p.Radius or 5, p.Color)
				if p.Shake then
					shakeAt(pos, p.Shake, 50)
				end
				animate(hold, function(_k, t)
					place(pos + UP * math.sin(t * 2) * (p.Bob or 0), CFrame.Angles(0, spinRate * (t + time), 0))
				end)
				finish(hold)
			end)
		elseif path == "Fly" then
			local to = p.To or pos
			local dir = to - pos
			if flat(dir).Magnitude > 0.1 then
				rot = CFrame.lookAt(Vector3.zero, flat(dir).Unit)
			end
			animate(time, function(k, t)
				place(pos:Lerp(to, k) + UP * math.sin(t * 2) * (p.Bob or 0), CFrame.Angles(0, 0, math.sin(t * 1.5) * (p.Roll or 0)))
			end, function()
				pos = to
				finish(0)
			end)
		elseif path == "Hover" then
			local start = pos + UP * 20
			SkillArt.Fade(rig, 1)
			animate(time, function(k, t)
				place(start:Lerp(pos, outCubic(k)), CFrame.Angles(0, spinRate * t, 0))
				SkillArt.Fade(rig, 1 - k)
			end, function()
				animate(hold, function(_k, t)
					place(pos + UP * math.sin(t * 2.2) * 0.6, CFrame.Angles(0, spinRate * (t + time), 0))
				end, function()
					if p.End == nil then
						p.End = "Up"
					end
					finish(0)
				end)
			end)
		elseif path == "Spin" then
			animate(time + hold, function(k, t)
				place(pos + UP * math.sin(t * 3) * (p.Bob or 0), CFrame.Angles(0, (spinRate ~= 0 and spinRate or 6) * t, 0))
				if k < 0.15 then
					SkillArt.Fade(rig, 1 - k / 0.15)
				end
			end, function()
				finish(0)
			end)
		elseif path == "Swing" then
			-- base no chão; começa em pé (inclinado para trás) e bate para a frente
			animate(time * 0.6, function(k)
				place(pos, CFrame.Angles(math.rad(25) * smooth(k), 0, 0))
			end, function()
				animate(time * 0.4, function(k)
					place(pos, CFrame.Angles(math.rad(25) - math.rad(115) * k * k, 0, 0))
				end, function()
					local tip = pos + look.Unit * (p.Reach or 8)
					impact(p.Impact or "Rock", tip, p.Radius or 6, p.Color)
					shakeAt(tip, p.Shake or 0.5, 50)
					finish(hold)
				end)
			end)
		elseif path == "Countdown" then
			-- 3 luzes: vermelha, amarela, verde (largada)
			local lamps = { C(255, 60, 50), C(255, 210, 50), C(80, 255, 110) }
			place(pos)
			for i, col in ipairs(lamps) do
				task.delay((i - 1) * time / 3, function()
					floatText(pos + UP * 2, i < 3 and tostring(4 - i) or "GO!", col, 40, 0.6, 1.5)
					light(pos + UP * 2, col, 18, 0.4, 6)
				end)
			end
			finish(time + 0.2)
		else
			place(pos)
			finish(time + hold)
		end
	end

	------------------------------------------------------------ S_Line: linha no chão
	function H.S_Line(p)
		local from, to = p.From, p.To
		if not (from and to) then
			return
		end
		local kind = p.Kind or "Trail"
		local color = p.Color or WHITE
		local dur = p.Duration or 1.2
		local d = to - from
		local len = flat(d).Magnitude
		if len < 0.5 then
			return
		end
		local dir = flat(d).Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local width = p.Width or 2
		if kind == "Bolt" then
			if Effects.Bolt then
				Effects.Bolt(from + UP, to + UP, color, 0.35, width * 0.3)
			end
			puff(to + UP, color, 12, 0.5, 20, TEX.Spark)
			return
		end
		if kind == "Slash" then
			local mid = from:Lerp(to, 0.5) + UP * (p.Height or 1.5)
			local line = fxPart({ Size = Vector3.new(0.12, 0.12, len), CFrame = CFrame.lookAt(mid, mid + dir), Color = color })
			local glow = fxPart({ Size = Vector3.new(0.5, 0.5, len), CFrame = CFrame.lookAt(mid, mid + dir), Color = color, Transparency = 0.6 })
			animate(0.45, function(k)
				line.Size = Vector3.new(0.12 * (1 - k) + 0.02, 0.12 * (1 - k) + 0.02, len)
				line.Transparency = k
				glow.Transparency = 0.6 + 0.4 * k
			end, function()
				line:Destroy()
				glow:Destroy()
			end)
			puff(to + UP, color, 10, 0.4, 18, TEX.Spark)
			return
		end
		local steps = math.clamp(math.floor(len / (kind == "Paw" and 2.2 or 1.6)), 2, 40)
		local parts, rigs = {}, {}
		for i = 1, steps do
			local u = (i - 0.5) / steps
			local at = from:Lerp(to, u)
			if kind == "Scent" then
				at += side * math.sin(u * 14) * 1.2 + UP * 1.2
				table.insert(parts, fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, CFrame = CFrame.new(at), Color = color, Transparency = 1 }))
			elseif kind == "Paw" then
				local rig = build("Paw", 0.8, color, nil)
				if rig then
					SkillArt.Place(rig, CFrame.lookAt(at + UP * 0.12 + side * ((i % 2 == 0) and 0.45 or -0.45), at + UP * 0.12 + dir))
					SkillArt.Fade(rig, 1)
					table.insert(rigs, rig)
				end
			elseif kind == "Fire" then
				local rig = build("Flame", rnd(0.8, 1.3) * width * 0.5, color, nil)
				if rig then
					SkillArt.Place(rig, CFrame.new(at + UP * 0.5))
					SkillArt.Fade(rig, 1)
					table.insert(rigs, rig)
				end
			elseif kind == "Ice" or kind == "Crystal" then
				local rig = build("Crystal", rnd(0.6, 1.1) * width * 0.6, color, nil)
				if rig then
					SkillArt.Place(rig, CFrame.new(at + side * rnd(-1, 1)) * CFrame.Angles(math.rad(-90 + rnd(-20, 20)), rnd(0, TAU), 0))
					SkillArt.Fade(rig, 1)
					table.insert(rigs, rig)
				end
			elseif kind == "Crack" then
				local seg = fxPart({
					Size = Vector3.new(0.35, 0.1, len / steps * 1.3),
					CFrame = CFrame.lookAt(at + UP * 0.06 + side * rnd(-0.6, 0.6), at + UP * 0.06 + dir + side * rnd(-0.6, 0.6)),
					Color = color,
					Transparency = 1,
				})
				table.insert(parts, seg)
			elseif kind == "Race" then
				local seg = fxPart({
					Size = Vector3.new(width, 0.06, len / steps * 0.6),
					CFrame = CFrame.lookAt(at + UP * 0.05, at + UP * 0.05 + dir),
					Color = (i % 2 == 0) and WHITE or color,
					Material = Enum.Material.SmoothPlastic,
					Transparency = 1,
				})
				table.insert(parts, seg)
			elseif kind == "Wind" then
				local seg = fxPart({
					Size = Vector3.new(0.15, 0.15, 2.2),
					CFrame = CFrame.lookAt(at + UP * rnd(0.5, 2.5) + side * rnd(-width, width), at + UP + dir * 10),
					Color = WHITE,
					Transparency = 1,
				})
				table.insert(parts, seg)
			else -- Trail / Water / Poison
				local seg = fxPart({
					Size = Vector3.new(width, 0.08, len / steps * 1.05),
					CFrame = CFrame.lookAt(at + UP * 0.07, at + UP * 0.07 + dir),
					Color = color,
					Material = kind == "Water" and GLASS or NEON,
					Transparency = 1,
				})
				table.insert(parts, seg)
			end
		end
		-- aparece do começo para o fim e some devagar
		local appear = math.min(0.35, dur * 0.3)
		animate(dur, function(k, t)
			local front = math.clamp(t / appear, 0, 1)
			local fade = math.clamp((k - 0.65) / 0.35, 0, 1)
			for i, part in ipairs(parts) do
				local on = (i / #parts) <= front
				local base = (kind == "Scent" and 0.25) or (kind == "Crack" and 0.15) or (kind == "Wind" and 0.5) or 0.35
				part.Transparency = on and (base + (1 - base) * fade) or 1
				if kind == "Wind" then
					part.CFrame += dir * 0.6
				elseif kind == "Scent" then
					part.CFrame = CFrame.new(part.Position + Vector3.new(0, math.sin(t * 4 + i) * 0.01, 0))
				end
			end
			for i, rig in ipairs(rigs) do
				local on = (i / #rigs) <= front
				SkillArt.Fade(rig, on and fade or 1)
			end
		end, function()
			for _, part in ipairs(parts) do
				part:Destroy()
			end
			for _, rig in ipairs(rigs) do
				SkillArt.Destroy(rig)
			end
		end)
		if kind == "Fire" then
			light(from:Lerp(to, 0.5) + UP, color, len, dur * 0.8, 3)
		end
	end

	------------------------------------------------------------ S_Zone: área no chão por um tempo
	local ZONE_LOOK = {
		Puddle = { C(90, 170, 255), GLASS, 0.35 },
		Water = { C(70, 150, 240), GLASS, 0.3 },
		Honey = { C(255, 175, 30), GLASS, 0.25 },
		Lava = { C(255, 110, 30), NEON, 0.2 },
		Fire = { C(60, 30, 20), Enum.Material.Slate, 0.2 },
		Ice = { C(190, 235, 255), Enum.Material.Ice, 0.25 },
		Snow = { C(245, 250, 255), Enum.Material.Snow, 0.1 },
		Poison = { C(130, 220, 60), NEON, 0.55 },
		Sand = { C(225, 195, 130), Enum.Material.Sand, 0.05 },
		Mud = { C(110, 80, 50), Enum.Material.Mud, 0.05 },
		Vines = { C(70, 150, 60), Enum.Material.Grass, 0.1 },
		Flowers = { C(110, 200, 90), Enum.Material.Grass, 0.15 },
		Spores = { C(150, 110, 200), NEON, 0.7 },
		Stars = { C(40, 30, 90), NEON, 0.35 },
		Holy = { C(255, 225, 130), NEON, 0.6 },
		Shadow = { C(30, 10, 45), Enum.Material.SmoothPlastic, 0.25 },
		Ink = { C(25, 20, 35), GLASS, 0.1 },
		Web = { C(240, 240, 240), NEON, 0.92 },
		Rune = { C(255, 255, 255), NEON, 0.85 },
		Dance = { C(30, 25, 40), Enum.Material.SmoothPlastic, 0.2 },
		Storm = { C(120, 130, 160), NEON, 0.85 },
		Grave = { C(70, 90, 60), Enum.Material.Grass, 0.2 },
		Gravity = { C(120, 60, 200), NEON, 0.7 },
		Time = { C(200, 200, 210), NEON, 0.75 },
		Confetti = { C(255, 255, 255), NEON, 0.9 },
		Crack = { C(60, 45, 35), Enum.Material.Slate, 0.4 },
	}

	function H.S_Zone(p)
		local pos = p.Position
		local r = p.Radius or 8
		local dur = p.Duration or 3
		local kind = p.Kind or "Puddle"
		local look = ZONE_LOOK[kind] or ZONE_LOOK.Puddle
		local color = p.Color or look[1]
		local baseColor = (kind == "Rune" or kind == "Holy" or kind == "Stars" or kind == "Gravity" or kind == "Poison" or kind == "Spores") and color or look[1]
		local base = disc(pos, 0.1, baseColor, 1, look[2])
		local baseTr = look[3]
		local extras, rigs, emitters = {}, {}, {}
		local holder = anchor(pos + UP * 0.5, dur + 2)
		local function emit(props)
			local e = emitter(holder, props)
			e.Enabled = true
			table.insert(emitters, e)
			return e
		end
		local function deco(motif: string, n: number, size: number, col: Color3?, ring: boolean?)
			for i = 1, q(n) do
				local a = ring and (i / n * TAU) or rnd(0, TAU)
				local rr = ring and r * 0.85 or math.sqrt(math.random()) * r * 0.85
				local rig = build(motif, size * rnd(0.8, 1.2), col or color, nil)
				if rig then
					table.insert(rigs, { rig = rig, at = pos + Vector3.new(math.cos(a) * rr, 0, math.sin(a) * rr), a = a, ph = rnd(0, TAU) })
				end
			end
		end
		if kind == "Lava" or kind == "Fire" then
			emit({ Texture = TEX.Fire, Rate = 30 * quality(), Color = CS(0, C(255, 230, 150), 1, C(255, 80, 20)), Size = NS(0, 1.4, 1, 0), Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(3, 7), SpreadAngle = Vector2.new(20, 20), EmissionDirection = Enum.NormalId.Top, LightEmission = 1 })
			deco("Flame", kind == "Fire" and 7 or 3, 1.3, C(255, 140, 40))
		elseif kind == "Poison" or kind == "Spores" then
			emit({ Texture = TEX.Smoke, Rate = 14 * quality(), Color = ColorSequence.new(color), Size = NS(0, 1.5, 1, 3.5), Transparency = NS(0, 0.5, 1, 1), Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Top, LightEmission = 0.3 })
			if kind == "Spores" then
				deco("Mushroom", 6, 1.2, C(200, 80, 200), true)
			end
		elseif kind == "Ice" or kind == "Snow" then
			deco("Crystal", 6, 1.2, C(180, 230, 255), true)
			emit({ Texture = TEX.Sparkle, Rate = 12 * quality(), Color = ColorSequence.new(C(220, 245, 255)), Size = NS(0, 0.5, 1, 0), Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(1, 2), SpreadAngle = Vector2.new(80, 80), EmissionDirection = Enum.NormalId.Top })
		elseif kind == "Sand" then
			emit({ Texture = TEX.Smoke, Rate = 20 * quality(), Color = ColorSequence.new(C(225, 195, 130)), Size = NS(0, 2, 1, 4), Transparency = NS(0, 0.4, 1, 1), Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(10, 180), EmissionDirection = Enum.NormalId.Right, LightEmission = 0 })
			deco("Scarab", 3, 0.8, nil)
		elseif kind == "Vines" or kind == "Flowers" then
			deco(kind == "Flowers" and "Flower" or "Leaf", 10, 1, kind == "Flowers" and pick(CONFETTI) or C(80, 180, 70))
		elseif kind == "Stars" then
			deco("Star", 8, 0.7, C(255, 240, 150))
		elseif kind == "Holy" or kind == "Rune" then
			local rune = build("Rune", r / 1.1, color, WHITE)
			if rune then
				table.insert(rigs, { rig = rune, at = pos + UP * 0.12, a = 0, ph = 0, spinning = true })
			end
			emit({ Texture = TEX.Sparkle, Rate = 18 * quality(), Color = ColorSequence.new(color), Size = NS(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(30, 30), EmissionDirection = Enum.NormalId.Top })
		elseif kind == "Shadow" or kind == "Ink" then
			emit({ Texture = TEX.Smoke, Rate = 16 * quality(), Color = ColorSequence.new(kind == "Ink" and C(20, 15, 30) or C(60, 20, 90)), Size = NS(0, 1.5, 1, 3), Transparency = NS(0, 0.4, 1, 1), Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(50, 50), EmissionDirection = Enum.NormalId.Top, LightEmission = 0 })
		elseif kind == "Honey" then
			deco("Honey", 5, 0.6, nil)
			deco("Bee", 3, 0.7, nil)
		elseif kind == "Puddle" or kind == "Water" then
			deco("Bubble", 4, 0.6, C(190, 230, 255))
		elseif kind == "Dance" then
			-- pista de dança: ladrilhos que trocam de cor no ritmo
			local n = math.clamp(math.floor(r / 2.2), 2, 5)
			local cell = r * 2 / (n * 2 + 1)
			for x = -n, n do
				for z = -n, n do
					if x * x + z * z <= n * n and not full(4) then
						local tile = fxPart({ Size = Vector3.new(cell * 0.92, 0.1, cell * 0.92), CFrame = CFrame.new(pos + Vector3.new(x * cell, 0.12, z * cell)), Color = CONFETTI[((x + z) % #CONFETTI) + 1], Transparency = 1 })
						table.insert(extras, { part = tile, i = x + z * 3 })
					end
				end
			end
		elseif kind == "Storm" then
			local cloud = build("Cloud", r / 2.4, C(90, 95, 115), nil)
			if cloud then
				table.insert(rigs, { rig = cloud, at = pos + UP * 16, a = 0, ph = 0, sky = true })
			end
			emit({ Texture = TEX.Sparkle, Rate = 40 * quality(), Color = ColorSequence.new(C(170, 200, 255)), Size = NS(0, 0.25, 1, 0.25), Lifetime = NumberRange.new(0.5, 0.7), Speed = NumberRange.new(30, 40), SpreadAngle = Vector2.new(15, 15), EmissionDirection = Enum.NormalId.Bottom })
		elseif kind == "Grave" then
			deco("Tombstone", 5, 1.3, nil, true)
			emit({ Texture = TEX.Smoke, Rate = 10 * quality(), Color = ColorSequence.new(C(120, 255, 200)), Size = NS(0, 2, 1, 4), Transparency = NS(0, 0.6, 1, 1), Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(10, 180), EmissionDirection = Enum.NormalId.Right, LightEmission = 0.3 })
		elseif kind == "Gravity" then
			emit({ Texture = TEX.Sparkle, Rate = 30 * quality(), Color = ColorSequence.new(color), Size = NS(0, 0.4, 1, 0), Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(6, 12), SpreadAngle = Vector2.new(10, 10), EmissionDirection = Enum.NormalId.Top })
		elseif kind == "Time" then
			local clock = build("Clock", r / 1.3, nil, nil)
			if clock then
				table.insert(rigs, { rig = clock, at = pos + UP * 0.2, a = 0, ph = 0, flatDisc = true })
			end
		elseif kind == "Confetti" then
			emit({ Texture = TEX.Sparkle, Rate = 30 * quality(), Color = ColorSequence.new(pick(CONFETTI)), Size = NS(0, 0.5, 1, 0.3), Lifetime = NumberRange.new(1, 1.5), Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(50, 50), EmissionDirection = Enum.NormalId.Top })
		elseif kind == "Web" then
			for i = 1, 6 do
				local a = i / 6 * math.pi
				local strand = fxPart({ Size = Vector3.new(0.1, 0.06, r * 2), CFrame = CFrame.new(pos + UP * 0.15) * CFrame.Angles(0, a, 0), Color = WHITE, Transparency = 1 })
				table.insert(extras, { part = strand, web = true })
			end
		elseif kind == "Crack" then
			for _ = 1, q(7) do
				local a = rnd(0, TAU)
				local seg = fxPart({ Size = Vector3.new(0.4, 0.1, r * rnd(0.5, 1)), CFrame = CFrame.new(pos + UP * 0.1) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r * 0.4), Color = color, Transparency = 1 })
				table.insert(extras, { part = seg, web = true })
			end
		end
		animate(dur, function(k, t)
			local open = outCubic(math.min(1, t / 0.35))
			local fade = math.clamp((k - 0.8) / 0.2, 0, 1)
			setDisc(base, r * open)
			base.Transparency = baseTr + (1 - baseTr) * fade
			for _, it in ipairs(rigs) do
				local cf
				if it.sky then
					cf = CFrame.new(it.at + Vector3.new(math.sin(t) * 0.5, 0, 0))
				elseif it.spinning then
					cf = CFrame.new(it.at) * CFrame.Angles(0, t * 0.8, 0)
				elseif it.flatDisc then
					cf = CFrame.new(it.at) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.Angles(0, 0, -t * 2)
				else
					local bob = math.sin(t * 3 + it.ph) * 0.15
					cf = CFrame.new(it.at + UP * (0.3 + bob)) * CFrame.Angles(0, it.a + t * 0.3, 0)
				end
				SkillArt.Place(it.rig, cf)
				SkillArt.Fade(it.rig, math.max(1 - open, fade))
			end
			for _, ex in ipairs(extras) do
				if ex.web then
					ex.part.Transparency = 0.3 + 0.7 * math.max(1 - open, fade)
				else
					local beat = math.floor(t * 4)
					ex.part.Color = CONFETTI[((ex.i + beat) % #CONFETTI) + 1]
					ex.part.Transparency = 0.15 + 0.85 * math.max(1 - open, fade)
				end
			end
			if kind == "Storm" and math.random() < 0.03 * quality() and Effects.Bolt then
				local at = pos + Vector3.new(rnd(-r, r), 0, rnd(-r, r)) * 0.7
				Effects.Bolt(at + UP * 16, at, C(200, 220, 255), 0.2, 0.3)
			end
			if (kind == "Puddle" or kind == "Water") and math.random() < 0.05 then
				groundRing(pos + Vector3.new(rnd(-r, r), 0, rnd(-r, r)) * 0.6, 0.3, 1.8, C(200, 230, 255), 0.6, 0.15)
			end
		end, function()
			base:Destroy()
			for _, it in ipairs(rigs) do
				SkillArt.Destroy(it.rig)
			end
			for _, ex in ipairs(extras) do
				ex.part:Destroy()
			end
			for _, e in ipairs(emitters) do
				e.Enabled = false
			end
		end)
	end

	------------------------------------------------------------ S_Mark: estado no alvo
	function H.S_Mark(p)
		local model = p.Model
		local root = rootOf(model)
		if not root then
			return
		end
		local kind = p.Kind or "Dizzy"
		local dur = math.max(0.3, p.Duration or 1)
		local s = sizeOf(model)
		local color = p.Color
		local rigs, parts, emitters = {}, {}, {}
		local att = Instance.new("Attachment")
		att.Parent = root
		Debris:AddItem(att, dur + 1.5)
		local function emit(props)
			local e = emitter(att, props)
			e.Enabled = true
			table.insert(emitters, e)
			return e
		end
		local top = root.Size.Y * 0.5 + 1.6 * s
		local function orbiters(motif: string, n: number, size: number, col: Color3?)
			for i = 1, n do
				local rig = build(motif, size * s, col, nil, true)
				if rig then
					table.insert(rigs, { rig = rig, a = (i - 1) / n * TAU })
				end
			end
		end
		local mode = "orbit"
		if kind == "Dizzy" or kind == "Shock" then
			orbiters(kind == "Shock" and "Bolt" or "Star", 3, 0.45, kind == "Shock" and C(255, 235, 90) or C(255, 225, 80))
			if kind == "Shock" then
				emit({ Texture = TEX.Spark, Rate = 25 * quality(), Color = ColorSequence.new(C(255, 240, 120)), Size = NS(0, 0.4, 1, 0), Lifetime = NumberRange.new(0.15, 0.3), Speed = NumberRange.new(6, 12) })
			end
		elseif kind == "Sleep" then
			mode = "sleep"
		elseif kind == "Charm" or kind == "Dance" then
			mode = "float"
		elseif kind == "Fear" then
			emit({ Texture = TEX.Smoke, Rate = 10 * quality(), Color = ColorSequence.new(C(90, 40, 140)), Size = NS(0, 1.5, 1, 3), Transparency = NS(0, 0.5, 1, 1), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(1, 2), LightEmission = 0 })
			orbiters("Ghost", 2, 0.4, C(200, 160, 255))
		elseif kind == "Burn" then
			emit({ Texture = TEX.Fire, Rate = 22 * quality(), Color = CS(0, C(255, 230, 140), 1, C(255, 80, 20)), Size = NS(0, 1.2 * s, 1, 0), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top, LightEmission = 1 })
			mode = "none"
		elseif kind == "Poison" or kind == "Bleed" or kind == "Wet" or kind == "Ink" then
			local col = ({ Poison = C(150, 240, 80), Bleed = C(220, 40, 50), Wet = C(140, 200, 255), Ink = C(30, 20, 40) })[kind]
			emit({ Texture = TEX.Sparkle, Rate = 14 * quality(), Color = ColorSequence.new(col), Size = NS(0, 0.5, 1, 0.2), Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(1, 3), Acceleration = kind == "Poison" and Vector3.new(0, 4, 0) or Vector3.new(0, -14, 0), LightEmission = kind == "Ink" and 0 or 0.5 })
			mode = "none"
		elseif kind == "Curse" then
			orbiters("GhostSkull", 1, 0.55, C(180, 90, 255))
			emit({ Texture = TEX.Smoke, Rate = 8 * quality(), Color = ColorSequence.new(C(130, 60, 200)), Size = NS(0, 1, 1, 2.5), Transparency = NS(0, 0.5, 1, 1), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(1, 2), LightEmission = 0.3 })
		elseif kind == "Slow" then
			mode = "swirl"
		elseif kind == "Bubble" then
			local rig = build("Bubble", root.Size.Z * 0.9, C(170, 220, 255), nil, true)
			if rig then
				table.insert(rigs, { rig = rig, a = 0, center = true })
			end
			mode = "center"
		elseif kind == "Cage" or kind == "Web" or kind == "Vines" or kind == "Wrap" or kind == "Pin" or kind == "Stone" or kind == "Honey" or kind == "Time" or kind == "Grab" then
			mode = "bars"
			local n = kind == "Cage" and 8 or 5
			local col = color or ({ Cage = C(255, 220, 120), Web = WHITE, Vines = C(80, 180, 70), Wrap = C(240, 230, 205), Pin = C(255, 255, 255), Stone = C(140, 130, 120), Honey = C(255, 175, 30), Time = C(220, 220, 240), Grab = C(150, 80, 200) })[kind]
			local h = root.Size.Y + 2.2 * s
			local rr = root.Size.Z * 0.65 + 0.4
			for i = 1, n do
				local a = (i - 1) / n * TAU
				local bar = fxPart({
					Size = kind == "Cage" and Vector3.new(0.25, h, 0.25) or Vector3.new(0.35, 0.35, rr * 1.4),
					Color = col,
					Material = (kind == "Stone" and Enum.Material.Slate) or (kind == "Honey" and GLASS) or (kind == "Cage" and NEON) or Enum.Material.SmoothPlastic,
					Transparency = 1,
				})
				table.insert(parts, { part = bar, a = a, rr = rr, h = h })
			end
			if kind == "Time" then
				orbiters("Clock", 1, 0.9, nil)
			end
		elseif kind == "Reticle" then
			orbiters("Ring", 1, 1.6, C(255, 60, 50))
			mode = "reticle"
		elseif kind == "Lift" then
			emit({ Texture = TEX.Sparkle, Rate = 20 * quality(), Color = ColorSequence.new(color or C(180, 140, 255)), Size = NS(0, 0.4, 1, 0), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(3, 6), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20) })
			mode = "none"
		else
			orbiters("Star", 2, 0.4, color or C(255, 225, 80))
		end
		local nextZ = 0
		local nextFloat = 0
		animate(dur, function(k, t)
			if not root.Parent then
				return true
			end
			local fade = math.clamp((k - 0.85) / 0.15, 0, 1)
			local appear = math.min(1, t / 0.15)
			local headPos = root.Position + UP * top
			if mode == "orbit" or mode == "reticle" then
				for i, it in ipairs(rigs) do
					local a = it.a + t * (mode == "reticle" and 1 or 5)
					local at = mode == "reticle" and headPos + UP * 0.6 or headPos + Vector3.new(math.cos(a) * 1.1 * s, math.sin(t * 7 + i) * 0.15, math.sin(a) * 1.1 * s)
					local cf = mode == "reticle" and CFrame.new(at) * CFrame.Angles(0, t * 2, 0) or CFrame.new(at) * CFrame.Angles(0, -a, t * 3)
					SkillArt.Place(it.rig, cf)
					SkillArt.Fade(it.rig, math.max(1 - appear, fade))
				end
			elseif mode == "center" then
				for _, it in ipairs(rigs) do
					SkillArt.Place(it.rig, CFrame.new(root.Position + UP * math.sin(t * 3) * 0.3))
					SkillArt.Fade(it.rig, math.max(1 - appear, fade))
				end
			elseif mode == "bars" then
				local feet = root.Position - UP * (root.Size.Y * 0.5 + 0.5 * s)
				for i, it in ipairs(parts) do
					local cf
					if kind == "Cage" then
						cf = CFrame.new(feet + Vector3.new(math.cos(it.a) * it.rr, it.h / 2, math.sin(it.a) * it.rr))
					else
						-- faixas enroladas em volta do corpo, girando devagar
						local a = it.a + t * (kind == "Wrap" and 1.5 or 0.4)
						local y = root.Size.Y * (0.2 + 0.6 * ((i - 1) / #parts))
						cf = CFrame.new(feet + UP * (y + 0.4 * s)) * CFrame.Angles(0, a, math.rad(kind == "Vines" and 25 or 12))
					end
					it.part.CFrame = cf
					it.part.Transparency = (kind == "Honey" and 0.35 or 0.1) + 0.9 * math.max(1 - appear, fade)
				end
				for _, it in ipairs(rigs) do
					SkillArt.Place(it.rig, CFrame.new(headPos + UP * 0.8) * CFrame.Angles(0, t, 0))
					SkillArt.Fade(it.rig, math.max(1 - appear, fade))
				end
			elseif mode == "sleep" then
				if t >= nextZ then
					nextZ = t + 0.45
					floatText(headPos + Vector3.new(0.4 * s, 0, 0), "Z", C(200, 220, 255), 26, 1, 2.5, rnd(-15, 15))
				end
			elseif mode == "float" then
				if t >= nextFloat then
					nextFloat = t + 0.35
					floatUp(kind == "Charm" and "Heart" or "Note", headPos, 1, 0.6, kind == "Charm" and C(255, 100, 170) or pick(CONFETTI), 0.9, 0.8)
				end
			elseif mode == "swirl" then
				if t >= nextFloat then
					nextFloat = t + 0.3
					groundRing(root.Position - UP * (root.Size.Y * 0.5 + 0.5 * s), 0.3, 2.2 * s, color or C(140, 190, 255), 0.5, 0.2)
				end
			end
			return false
		end, function()
			for _, it in ipairs(rigs) do
				SkillArt.Destroy(it.rig)
			end
			for _, it in ipairs(parts) do
				it.part:Destroy()
			end
			for _, e in ipairs(emitters) do
				e.Enabled = false
			end
		end)
	end

	------------------------------------------------------------ S_Aura: aura no próprio cachorro
	function H.S_Aura(p)
		local model = p.Model
		local root = rootOf(model)
		if not root then
			return
		end
		local kind = p.Kind or "Shield"
		local dur = math.max(0.4, p.Duration or 2)
		local color = p.Color or C(140, 200, 255)
		local s = sizeOf(model)
		local att = Instance.new("Attachment")
		att.Parent = root
		Debris:AddItem(att, dur + 1.5)
		local emitters, rigs, parts = {}, {}, {}
		local function emit(props)
			local e = emitter(att, props)
			e.Enabled = true
			table.insert(emitters, e)
			return e
		end
		local bubble = nil
		local pl = Instance.new("PointLight")
		pl.Color = color
		pl.Range = 10 * s
		pl.Brightness = 0
		pl.Shadows = false
		pl.Parent = att
		if kind == "Shield" or kind == "Bubble" or kind == "Metal" or kind == "Holy" or kind == "Crystal" then
			bubble = fxPart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * (root.Size.Z * 1.6 + 2 * s),
				CFrame = root.CFrame,
				Color = color,
				Material = kind == "Bubble" and GLASS or Enum.Material.ForceField,
				Transparency = 1,
			})
			if kind == "Holy" then
				local halo = build("Ring", 1.2 * s, C(255, 230, 120), nil, true)
				if halo then
					table.insert(rigs, { rig = halo, halo = true })
				end
			elseif kind == "Crystal" or kind == "Metal" then
				for i = 1, 4 do
					local rig = build(kind == "Crystal" and "Crystal" or "Shield", 0.8 * s, color, nil, true)
					if rig then
						table.insert(rigs, { rig = rig, a = (i - 1) / 4 * TAU })
					end
				end
			end
		elseif kind == "Rage" or kind == "Fire" then
			emit({ Texture = TEX.Fire, Rate = 40 * quality(), Color = kind == "Rage" and CS(0, C(255, 200, 120), 1, C(220, 30, 30)) or CS(0, C(255, 230, 140), 1, C(255, 90, 20)), Size = NS(0, 2 * s, 1, 0), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(180, 180), EmissionDirection = Enum.NormalId.Top, LightEmission = 1, Acceleration = Vector3.new(0, 6, 0) })
		elseif kind == "Haste" or kind == "Wind" then
			emit({ Texture = TEX.Sparkle, Rate = 30 * quality(), Color = ColorSequence.new(WHITE), Size = NS(0, 0.3, 1, 0), Lifetime = NumberRange.new(0.2, 0.4), Speed = NumberRange.new(8, 14), SpreadAngle = Vector2.new(20, 20), EmissionDirection = Enum.NormalId.Back })
			if H.Streak then
				H.Streak({ Model = model, Color = color, Duration = dur, Width = 1, Lifetime = 0.3 })
			end
		elseif kind == "Heal" then
			emit({ Texture = TEX.Sparkle, Rate = 25 * quality(), Color = ColorSequence.new(C(120, 255, 140)), Size = NS(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(40, 40), EmissionDirection = Enum.NormalId.Top })
			for i = 1, 3 do
				task.delay((i - 1) * 0.2, function()
					floatText(root.Position + Vector3.new(rnd(-1, 1), root.Size.Y, rnd(-1, 1)) , "+", C(120, 255, 140), 30, 0.8, 3)
				end)
			end
		elseif kind == "Stone" then
			for i = 1, 5 do
				local rig = build("Rock", 1.1 * s, nil, nil, true)
				if rig then
					table.insert(rigs, { rig = rig, a = (i - 1) / 5 * TAU })
				end
			end
		elseif kind == "Shadow" then
			emit({ Texture = TEX.Smoke, Rate = 20 * quality(), Color = ColorSequence.new(C(40, 15, 60)), Size = NS(0, 2 * s, 1, 4 * s), Transparency = NS(0, 0.4, 1, 1), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(1, 3), LightEmission = 0 })
		elseif kind == "Ice" then
			emit({ Texture = TEX.Sparkle, Rate = 25 * quality(), Color = ColorSequence.new(C(200, 240, 255)), Size = NS(0, 0.5, 1, 0), Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(1, 4) })
			for i = 1, 4 do
				local rig = build("Snowflake", 0.7 * s, C(200, 240, 255), nil, true)
				if rig then
					table.insert(rigs, { rig = rig, a = (i - 1) / 4 * TAU })
				end
			end
		elseif kind == "Storm" then
			emit({ Texture = TEX.Spark, Rate = 30 * quality(), Color = ColorSequence.new(C(255, 240, 120)), Size = NS(0, 0.5, 1, 0), Lifetime = NumberRange.new(0.15, 0.3), Speed = NumberRange.new(8, 14) })
		elseif kind == "Siren" then
			for i, col in ipairs({ C(255, 40, 40), C(40, 90, 255) }) do
				local ball = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.7 * s, Color = col, Transparency = 0 })
				table.insert(parts, { part = ball, side = i == 1 and -1 or 1, col = col })
			end
		elseif kind == "Gold" or kind == "Rainbow" then
			emit({ Texture = TEX.Sparkle, Rate = 30 * quality(), Color = kind == "Rainbow" and CS(0, RAINBOW[1], 0.33, RAINBOW[3], 0.66, RAINBOW[5], 1, RAINBOW[6]) or ColorSequence.new(C(255, 220, 100)), Size = NS(0, 0.6, 1, 0), Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(2, 5) })
		end
		animate(dur, function(k, t)
			if not root.Parent then
				return true
			end
			local appear = math.min(1, t / 0.2)
			local fade = math.clamp((k - 0.85) / 0.15, 0, 1)
			local vis = math.max(1 - appear, fade)
			pl.Brightness = 2.5 * (1 - vis)
			if bubble then
				bubble.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, t, 0)
				local base = kind == "Bubble" and 0.6 or 0.15
				bubble.Transparency = base + (1 - base) * vis
				bubble.Size = Vector3.one * (root.Size.Z * 1.6 + 2 * s) * (1 + math.sin(t * 6) * 0.03)
			end
			for i, it in ipairs(rigs) do
				local cf
				if it.halo then
					cf = CFrame.new(root.Position + UP * (root.Size.Y * 0.5 + 1.8 * s)) * CFrame.Angles(math.rad(90), 0, t)
				else
					local a = it.a + t * 2.2
					local rr = root.Size.Z * 0.8 + 1.4 * s
					cf = CFrame.new(root.Position + Vector3.new(math.cos(a) * rr, math.sin(t * 3 + i) * 0.4, math.sin(a) * rr)) * CFrame.Angles(0, -a, 0)
				end
				SkillArt.Place(it.rig, cf)
				SkillArt.Fade(it.rig, vis)
			end
			for _, it in ipairs(parts) do
				local on = (math.floor(t * 6) % 2 == 0) == (it.side < 0)
				it.part.CFrame = root.CFrame * CFrame.new(it.side * 0.45 * s, root.Size.Y * 0.5 + 1.2 * s, 0)
				it.part.Transparency = on and vis or 0.7 + 0.3 * vis
				if on then
					pl.Color = it.col
				end
			end
			return false
		end, function()
			pl:Destroy()
			if bubble then
				bubble:Destroy()
			end
			for _, it in ipairs(rigs) do
				SkillArt.Destroy(it.rig)
			end
			for _, it in ipairs(parts) do
				it.part:Destroy()
			end
			for _, e in ipairs(emitters) do
				e.Enabled = false
			end
		end)
	end

	------------------------------------------------------------ S_Burst: rajada de objetos
	local BURST = {
		Confetti = { "Confetti", 0.9, 30, function(i)
			return CONFETTI[(i % #CONFETTI) + 1]
		end, { gravity = 25, drag = 1.5, life = 1.6 } },
		Dirt = { "Rock", 0.45, 22, nil, { life = 1 } },
		Rocks = { "Rock", 0.7, 26, nil, { life = 1.1 } },
		Leaves = { "Leaf", 0.7, 16, function()
			return C(90, 190, 70):Lerp(C(170, 220, 80), math.random())
		end, { gravity = 10, drag = 2, life = 1.6 } },
		Petals = { "Petal", 0.7, 16, nil, { gravity = 8, drag = 2, life = 1.8 } },
		Bones = { "Bone", 0.5, 22, nil, { life = 1.1 } },
		Hearts = { "Heart", 0.6, 14, nil, { gravity = -4, drag = 2, life = 1.3 } },
		Notes = { "Note", 0.7, 14, function()
			return CONFETTI[math.random(1, #CONFETTI)]
		end, { gravity = -4, drag = 2, life = 1.3 } },
		Stars = { "Star", 0.6, 22, nil, { gravity = 20, life = 1 } },
		Coins = { "Coin", 0.7, 24, nil, { life = 1.2 } },
		Bubbles = { "Bubble", 0.7, 10, nil, { gravity = -6, drag = 2, life = 1.4 } },
		Snow = { "Snowflake", 0.6, 14, function()
			return C(220, 240, 255)
		end, { gravity = 6, drag = 2, life = 1.4 } },
		Feathers = { "Feather", 0.8, 14, nil, { gravity = 5, drag = 2.5, life = 1.8 } },
		Crystals = { "Crystal", 0.6, 24, nil, { life = 1.1 } },
		Sand = { "Sand", 0.6, 22, nil, { life = 1 } },
		Spores = { "Spore", 0.6, 10, nil, { gravity = -3, drag = 2, life = 1.6 } },
		Crumbs = { "Crumb", 0.8, 18, nil, { life = 1 } },
		Poms = { "Pom", 0.6, 20, nil, { life = 1.1 } },
		Drops = { "Drop", 0.6, 22, nil, { life = 0.9 } },
		Embers = { "Ember", 0.6, 20, nil, { gravity = -2, drag = 1.5, life = 1.2 } },
		Feather = { "Feather", 0.8, 14, nil, { gravity = 5, drag = 2.5, life = 1.8 } },
		Skulls = { "Skull", 0.5, 20, nil, { life = 1 } },
		Shards = { "Shard", 0.5, 26, nil, { life = 0.9 } },
		Ink = { "Ink", 0.5, 20, nil, { life = 0.9 } },
	}
	function H.S_Burst(p)
		local def = BURST[p.Kind or "Confetti"] or BURST.Confetti
		local color = p.Color
		local colorFn = def[4] or function()
			return color
		end
		local speed = def[3] * ((p.Radius or 6) / 6) ^ 0.5
		local opts = table.clone(def[5])
		if p.Dir then
			opts.dir = p.Dir
			opts.cone = p.Cone or 0.5
		end
		toss(def[1], p.Position + UP * 0.6, p.Count or 12, speed, (p.Size or 1) * def[2], colorFn, opts)
		if p.Kind == "Dirt" or p.Kind == "Rocks" or p.Kind == "Sand" then
			smoke(p.Position, p.Kind == "Sand" and C(225, 195, 130) or C(150, 125, 95), 10, 2.5, 10)
		end
	end

	------------------------------------------------------------ S_Beam: raio/jato da boca
	local BEAM = {
		Laser = { C(255, 60, 60), WHITE, 0.35 },
		Water = { C(90, 170, 255), C(230, 245, 255), 1 },
		Fire = { C(255, 120, 30), C(255, 240, 170), 1 },
		Holy = { C(255, 220, 120), WHITE, 1.2 },
		Plasma = { C(120, 255, 140), WHITE, 0.9 },
		Ice = { C(150, 220, 255), WHITE, 0.9 },
		Sound = { C(255, 120, 220), WHITE, 0.8 },
		Rainbow = { C(255, 255, 255), WHITE, 1 },
		Void = { C(140, 60, 220), C(20, 0, 40), 1.1 },
		Photon = { C(120, 230, 255), WHITE, 1.6 },
		Tractor = { C(120, 255, 180), WHITE, 1 },
		Sun = { C(255, 190, 60), C(255, 250, 220), 1.5 },
	}
	function H.S_Beam(p)
		local kind = p.Kind or "Laser"
		local def = BEAM[kind] or BEAM.Laser
		local color = p.Color or def[1]
		local core = p.Color2 or def[2]
		local width = (p.Width or 3) * def[3] * 0.5
		local dur = p.Duration or 0.8
		local from0, to0 = p.From, p.To
		if not (from0 and to0) then
			return
		end
		local baseDir = to0 - from0
		local length = baseDir.Magnitude
		if length < 0.5 then
			return
		end
		baseDir = baseDir.Unit
		local glow = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, width * 2, width * 2), Color = color, Transparency = 0.45 })
		local mid = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, width, width), Color = color, Transparency = 0.15 })
		local inner = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, width * 0.4, width * 0.4), Color = core, Transparency = 0 })
		local strands = {}
		if kind == "Rainbow" then
			for i = 1, 3 do
				table.insert(strands, fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, width * 0.5, width * 0.5), Color = RAINBOW[i * 2 - 1], Transparency = 0.1 }))
			end
		end
		local endAtt = anchor(to0, dur + 1)
		local endFx = emitter(endAtt, {
			Texture = (kind == "Fire" or kind == "Sun") and TEX.Fire or TEX.Sparkle,
			Enabled = true,
			Rate = 50 * quality(),
			Color = ColorSequence.new(color),
			Size = NS(0, width * 1.2, 1, 0),
			Lifetime = NumberRange.new(0.2, 0.4),
			Speed = NumberRange.new(6, 14),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 1,
		})
		local startPos = from0
		local rings = {}
		animate(dur, function(k, t)
			local m = p.Model and mouthCF(p.Model)
			if m then
				startPos = m.Position
			end
			local d = baseDir
			if p.Sweep then
				local a = math.rad(p.Sweep * (k - 0.5) * 2)
				local c, sn = math.cos(a), math.sin(a)
				d = Vector3.new(baseDir.X * c - baseDir.Z * sn, baseDir.Y, baseDir.X * sn + baseDir.Z * c)
			end
			local endPos = startPos + d * length
			local cf = CFrame.lookAt(startPos:Lerp(endPos, 0.5), endPos) * CFrame.Angles(0, math.rad(90), 0)
			local open = math.min(1, t / 0.12)
			local close = math.clamp((k - 0.8) / 0.2, 0, 1)
			local w = width * open * (1 - close) * (1 + math.sin(t * 40) * 0.08)
			glow.CFrame = cf
			mid.CFrame = cf
			inner.CFrame = cf
			glow.Size = Vector3.new(length, w * 2 + 0.05, w * 2 + 0.05)
			mid.Size = Vector3.new(length, w + 0.05, w + 0.05)
			inner.Size = Vector3.new(length, w * 0.4 + 0.05, w * 0.4 + 0.05)
			for i, st in ipairs(strands) do
				local a = t * 8 + i * TAU / 3
				st.CFrame = cf * CFrame.new(0, math.cos(a) * w * 0.6, math.sin(a) * w * 0.6)
				st.Size = Vector3.new(length, w * 0.5 + 0.05, w * 0.5 + 0.05)
			end
			endAtt.WorldPosition = endPos
			if kind == "Sound" and math.random() < 0.3 then
				table.insert(rings, { u = 0 })
			end
		end, function()
			glow:Destroy()
			mid:Destroy()
			inner:Destroy()
			for _, st in ipairs(strands) do
				st:Destroy()
			end
			endFx.Enabled = false
		end)
		light(from0:Lerp(to0, 0.5), color, length * 0.6, dur, 4)
		if kind == "Sound" then
			for i = 1, q(5) do
				task.delay((i - 1) * dur / 5, function()
					local rig = build("Ring", width * 0.9, color, nil)
					if not rig then
						return
					end
					animate(0.4, function(k)
						local m = p.Model and mouthCF(p.Model)
						local s0 = m and m.Position or from0
						local pos = s0 + baseDir * length * k
						SkillArt.Place(rig, CFrame.lookAt(pos, pos + baseDir))
						SkillArt.Fade(rig, k)
					end, function()
						SkillArt.Destroy(rig)
					end)
				end)
			end
		end
	end

	------------------------------------------------------------ S_Cone: sopro em cone
	local CONE = {
		Fire = { TEX.Fire, CS(0, C(255, 240, 170), 0.4, C(255, 130, 40), 1, C(120, 30, 10)), 1, nil },
		Frost = { TEX.Sparkle, CS(0, WHITE, 1, C(140, 210, 255)), 0.8, "Snowflake" },
		Wind = { TEX.Swirl, ColorSequence.new(C(220, 255, 245)), 0.4, "Leaf" },
		Perfume = { TEX.Sparkle, CS(0, C(255, 200, 230), 1, C(255, 120, 200)), 0.8, "Heart" },
		Poison = { TEX.Smoke, ColorSequence.new(C(150, 230, 70)), 0.4, "Bubble" },
		Sand = { TEX.Smoke, ColorSequence.new(C(225, 195, 130)), 0, "Sand" },
		Sound = { TEX.Sparkle, ColorSequence.new(C(255, 150, 230)), 0.8, "Note" },
		Water = { TEX.Sparkle, CS(0, WHITE, 1, C(90, 170, 255)), 0.7, "Drop" },
		Spores = { TEX.Smoke, ColorSequence.new(C(190, 120, 230)), 0.5, "Spore" },
		Ink = { TEX.Smoke, ColorSequence.new(C(30, 20, 45)), 0, "Ink" },
		Ghost = { TEX.Fire, CS(0, C(220, 255, 250), 1, C(60, 220, 200)), 1, "GhostSkull" },
		Bubbles = { TEX.Sparkle, ColorSequence.new(C(190, 230, 255)), 0.6, "Bubble" },
		Shadow = { TEX.Smoke, ColorSequence.new(C(70, 30, 110)), 0.2, nil },
		Holy = { TEX.Sparkle, CS(0, WHITE, 1, C(255, 220, 120)), 1, "Feather" },
	}
	function H.S_Cone(p)
		local head = headOf(p.Model, p.Head)
		local root = rootOf(p.Model)
		if not (head or root) then
			return
		end
		local def = CONE[p.Kind or "Fire"] or CONE.Fire
		local length = p.Length or 16
		local angle = p.Angle or 30
		local dur = p.Duration or 1
		local att = Instance.new("Attachment")
		local part = head or root
		local mouth = head and head.CFrame * CFrame.new(0, -head.Size.Y * 0.15, -head.Size.Z * 0.75) or mouthCF(p.Model)
		att.CFrame = part.CFrame:ToObjectSpace(mouth or part.CFrame)
		att.Parent = part
		Debris:AddItem(att, dur + 2)
		local life = 0.5
		local e = emitter(att, {
			Texture = def[1],
			Enabled = true,
			Rate = 90 * quality(),
			Color = p.Color and ColorSequence.new(p.Color) or def[2],
			Size = NS(0, 0.6, 1, math.tan(math.rad(angle)) * length * 0.9),
			Transparency = NS(0, 0.15, 0.7, 0.5, 1, 1),
			Lifetime = NumberRange.new(life * 0.8, life),
			Speed = NumberRange.new(length / life * 0.8, length / life),
			SpreadAngle = Vector2.new(angle * 0.7, angle * 0.7),
			EmissionDirection = Enum.NormalId.Front,
			LightEmission = def[3],
			Drag = 1,
			RotSpeed = NumberRange.new(-90, 90),
			Rotation = NumberRange.new(0, 360),
		})
		local motifs = {}
		local nextMotif = 0
		animate(dur, function(_k, t)
			if def[4] and t >= nextMotif and not full(8) then
				nextMotif = t + 0.12 / quality()
				local m = mouthCF(p.Model)
				if m then
					local dir = (m.LookVector + Vector3.new(rnd(-0.4, 0.4), rnd(-0.2, 0.3), rnd(-0.4, 0.4)) * math.tan(math.rad(angle))).Unit
					local rig = build(def[4], 0.6, p.Color, nil)
					if rig then
						table.insert(motifs, { rig = rig, p = m.Position, v = dir * length / 0.6, t0 = t })
					end
				end
			end
			for i = #motifs, 1, -1 do
				local it = motifs[i]
				local age = t - it.t0
				local pos = it.p + it.v * math.min(age, 0.6)
				SkillArt.Place(it.rig, CFrame.lookAt(pos, pos + it.v) * CFrame.Angles(0, 0, age * 6))
				SkillArt.Fade(it.rig, math.clamp((age - 0.35) / 0.3, 0, 1))
				if age > 0.65 then
					SkillArt.Destroy(it.rig)
					table.remove(motifs, i)
				end
			end
		end, function()
			e.Enabled = false
			for _, it in ipairs(motifs) do
				SkillArt.Destroy(it.rig, 0.3)
			end
		end)
		if p.Kind == "Fire" or p.Kind == "Ghost" or p.Kind == "Holy" then
			light((mouthCF(p.Model) or part.CFrame).Position, p.Color or C(255, 150, 60), length, dur, 3)
		end
	end

	------------------------------------------------------------ S_Wave: onda andando pelo chão
	function H.S_Wave(p)
		local pos = p.Position
		local dir = p.Dir and flat(p.Dir) or Vector3.new(0, 0, -1)
		if dir.Magnitude < 0.01 then
			return
		end
		dir = dir.Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local kind = p.Kind or "Water"
		local length = p.Length or 30
		local width = p.Width or 8
		local speed = p.Speed or 40
		local color = p.Color or C(90, 170, 255)
		local dur = length / speed
		local wall = {}
		local n = math.max(3, math.floor(width / 1.6))
		local h = kind == "Water" and 4 or kind == "Sand" and 3 or kind == "Sound" and 3 or 2
		if kind == "Water" or kind == "Sand" or kind == "Fire" or kind == "Shadow" or kind == "Shock" or kind == "Sound" then
			for i = 1, n do
				local part = fxPart({
					Size = Vector3.new(width / n * 1.15, h, 1.2),
					Color = kind == "Sand" and C(225, 195, 130) or color,
					Material = (kind == "Water" and GLASS) or (kind == "Sand" and Enum.Material.Sand) or NEON,
					Transparency = 1,
				})
				table.insert(wall, { part = part, x = (i - 0.5) / n - 0.5 })
			end
		end
		local nextSpawn = 0
		animate(dur, function(k, t)
			local front = pos + dir * length * k
			for _, w in ipairs(wall) do
				local bulge = math.cos(w.x * math.pi) * 1.2
				local at = front + side * w.x * width + dir * bulge + UP * (h / 2 * (0.6 + 0.4 * math.sin(t * 10 + w.x * 6)))
				w.part.CFrame = CFrame.lookAt(at, at + dir) * CFrame.Angles(math.rad(-15), 0, 0)
				w.part.Transparency = (kind == "Water" and 0.3 or 0.25) + 0.75 * math.clamp((k - 0.8) / 0.2, 0, 1)
			end
			if t >= nextSpawn then
				nextSpawn = t + 0.06 / quality()
				local at = front + side * rnd(-0.5, 0.5) * width
				if kind == "Spikes" or kind == "Ice" or kind == "Crystal" then
					local rig = build(kind == "Spikes" and "Rock" or "Crystal", rnd(1, 1.8), color, nil)
					if rig then
						local cf = CFrame.new(at) * CFrame.Angles(math.rad(-90 + rnd(-25, 25)), rnd(0, TAU), 0)
						animate(1, function(kk)
							SkillArt.Place(rig, cf * CFrame.new(0, 0, (1 - outCubic(math.min(1, kk * 5))) * 2))
							SkillArt.Fade(rig, math.clamp((kk - 0.6) / 0.4, 0, 1))
						end, function()
							SkillArt.Destroy(rig)
						end)
					end
				elseif kind == "Water" then
					puff(at + UP, C(220, 240, 255), 4, 0.7, 12, TEX.Sparkle, { Acceleration = Vector3.new(0, -40, 0) })
				elseif kind == "Fire" then
					puff(at + UP, CS(0, C(255, 230, 140), 1, color), 4, 1.5, 6, TEX.Fire, { EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), LightEmission = 1 })
				elseif kind == "Sand" or kind == "Shock" then
					smoke(at, kind == "Sand" and C(225, 195, 130) or C(160, 140, 110), 3, 2, 6)
				elseif kind == "Sound" then
					local rig = build("Note", 0.8, pick(CONFETTI), nil)
					if rig then
						animate(0.6, function(kk)
							SkillArt.Place(rig, CFrame.new(at + UP * (1 + 2 * kk)))
							SkillArt.Fade(rig, kk)
						end, function()
							SkillArt.Destroy(rig)
						end)
					end
				end
			end
		end, function()
			for _, w in ipairs(wall) do
				w.part:Destroy()
			end
		end)
	end

	------------------------------------------------------------ S_Pillar: coluna vertical
	local PILLAR = {
		Fire = { C(255, 120, 30), NEON, 0.15, TEX.Fire },
		Ice = { C(170, 225, 255), GLASS, 0.2, TEX.Sparkle },
		Holy = { C(255, 225, 130), NEON, 0.25, TEX.Sparkle },
		Light = { C(255, 255, 230), NEON, 0.2, TEX.Sparkle },
		Water = { C(80, 160, 255), GLASS, 0.25, TEX.Sparkle },
		Shadow = { C(90, 35, 140), GLASS, 0.35, TEX.Smoke },
		Poison = { C(140, 230, 70), NEON, 0.35, TEX.Smoke },
		Rock = { C(130, 115, 100), Enum.Material.Slate, 0, nil },
		Wind = { C(220, 255, 245), Enum.Material.SmoothPlastic, 0.6, TEX.Swirl },
		Lava = { C(255, 100, 20), NEON, 0.1, TEX.Fire },
		Sand = { C(225, 195, 130), Enum.Material.Sand, 0.3, TEX.Smoke },
		Void = { C(40, 10, 70), GLASS, 0.3, TEX.Sparkle },
		Plasma = { C(120, 255, 160), NEON, 0.2, TEX.Spark },
		Lightning = { C(255, 240, 120), NEON, 0.3, TEX.Spark },
	}
	function H.S_Pillar(p)
		local kind = p.Kind or "Fire"
		local def = PILLAR[kind] or PILLAR.Fire
		local pos = p.Position
		local r = p.Radius or 3
		local height = p.Height or 18
		local time = p.Time or 0.25
		local hold = p.Hold or 0.6
		local color = p.Color or def[1]
		if kind == "Lightning" then
			if Effects.Bolt then
				Effects.Bolt(pos + UP * 50, pos, color, 0.3, math.max(0.5, r * 0.35), 0.1)
				Effects.Bolt(pos + UP * 50 + Vector3.new(rnd(-3, 3), 0, rnd(-3, 3)), pos, WHITE, 0.2, math.max(0.3, r * 0.2), 0.12)
			end
			flash(pos + UP, r * 1.2, WHITE, 0.2)
			groundRing(pos, 0.5, r * 2, color, 0.4)
			light(pos + UP * 3, color, r * 6, 0.4, 8)
			return
		end
		local col = fxPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, r * 2, r * 2),
			Color = color,
			Material = def[2],
			Transparency = def[3],
		})
		local core
		if kind ~= "Rock" and kind ~= "Void" then
			core = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, r * 0.8, r * 0.8), Color = WHITE:Lerp(color, 0.3), Transparency = 0.1 })
		end
		local att = anchor(pos + UP * height * 0.5, time + hold + 2)
		local e
		if def[4] then
			e = emitter(att, {
				Texture = def[4],
				Enabled = true,
				Rate = 40 * quality(),
				Color = ColorSequence.new(color),
				Size = NS(0, r * 0.8, 1, 0),
				Lifetime = NumberRange.new(0.4, 0.8),
				Speed = NumberRange.new(4, 10),
				SpreadAngle = Vector2.new(180, 180),
				LightEmission = kind == "Shadow" and 0 or 1,
			})
		end
		local spin = kind == "Wind" and 8 or 1
		animate(time + hold, function(_k, t)
			local grow = outCubic(math.min(1, t / time))
			local fade = math.clamp((t - time - hold * 0.6) / (hold * 0.4), 0, 1)
			local hh = math.max(0.1, height * grow)
			local cf = CFrame.new(pos + UP * hh / 2) * CFrame.Angles(0, t * spin, math.rad(90))
			col.CFrame = cf
			col.Size = Vector3.new(hh, r * 2 * (1 - 0.6 * fade), r * 2 * (1 - 0.6 * fade))
			col.Transparency = def[3] + (1 - def[3]) * fade
			if core then
				core.CFrame = cf
				core.Size = Vector3.new(hh, r * 0.8 * (1 - fade), r * 0.8 * (1 - fade))
				core.Transparency = 0.1 + 0.9 * fade
			end
		end, function()
			col:Destroy()
			if core then
				core:Destroy()
			end
			if e then
				e.Enabled = false
			end
		end)
		groundRing(pos, 0.5, r * 1.8, color, 0.45)
		light(pos + UP * 3, color, r * 5, time + hold, 5)
		if kind == "Rock" then
			impact("Rock", pos, r, color)
		end
	end

	------------------------------------------------------------ S_Summon: criaturas que atacam
	local CREATURE = {
		Bee = { "Bee", "Swarm", 0.8, "Poison" },
		Ghost = { "Ghost", "Fly", 1.2, "Void" },
		Wolf = { "Wolf", "Run", 1.1, "Shock" },
		Shade = { "Wolf", "Run", 1.1, "Void" },
		Bull = { "Bull", "Run", 1.4, "Dirt" },
		Skeleton = { "Skeleton", "Rise", 1.0, "Bones" },
		Bat = { "Bat", "Fly", 0.9, "Ink" },
		Bird = { "Bird", "Fly", 0.9, "Feathers" },
		Snake = { "Snake", "Rise", 1.2, "Poison" },
		Scarab = { "Scarab", "Run", 0.8, "Sand" },
		Fish = { "Fish", "Fly", 0.8, "Splash" },
		Plane = { "Plane", "Over", 1.6, "Explode" },
		Hound = { "Wolf", "Run", 1.3, "Fire" },
		Spirit = { "Wolf", "Fly", 2.2, "Holy" },
		Tentacle = { "Tentacle", "Rise", 1.2, "Splash" },
		Hand = { "BoneHand", "Rise", 1.2, "Bones" },
		Shark = { "Megalodon", "Rise", 0.35, "Splash" },
		Fist = { "Fist", "Dive", 1.4, "Shock" },
		Comet = { "Comet", "Dive", 1.2, "Stars" },
		Spear = { "Lance", "Dive", 1.3, "Holy" },
		Sword = { "Blade", "Dive", 1.3, "Burst" },
		Missile = { "Missile", "Over", 1.3, "Explode" },
	}
	function H.S_Summon(p)
		local def = CREATURE[p.Kind or "Ghost"] or CREATURE.Ghost
		local from = p.From or (rootOf(p.Model) and rootOf(p.Model).Position) or Vector3.zero
		local time = p.Time or 0.8
		local color = p.Color
		local size = (p.Size or 1) * def[3]
		local path = p.Path or def[2]
		for i, pt in ipairs(p.Points or {}) do
			task.delay((i - 1) * (p.Gap or 0.15), function()
				local swarm = path == "Swarm"
				local count = swarm and q(4) or 1
				local list = {}
				for j = 1, count do
					local rig = build(def[1], size * (swarm and rnd(0.6, 1) or 1), color, nil)
					if rig then
						table.insert(list, { rig = rig, o = swarm and unitRandom(0.3) * 1.5 or Vector3.zero, ph = j })
					end
				end
				local start = from + Vector3.new(rnd(-2, 2), 0, rnd(-2, 2))
				if path == "Rise" then
					start = pt - UP * 4
				elseif path == "Dive" then
					start = pt + UP * 40 + Vector3.new(rnd(-8, 8), 0, rnd(-8, 8))
				elseif path == "Over" then
					local d = flat(pt - from)
					d = d.Magnitude > 0.1 and d.Unit or Vector3.new(0, 0, -1)
					start = pt - d * 60 + UP * 22
				end
				local last = start
				local riseHold = path == "Rise" and 0.35 or 0
				local over = pt + UP * 22 -- avião passa por cima do ponto na hora do impacto
				if path == "Over" then
					task.delay(time, function()
						impact(def[4], pt, 3 * size, color)
					end)
					-- a bomba cai do avião e chega junto com o dano
					task.delay(time * 0.55, function()
						local bomb = build(def[1] == "Missile" and "Missile" or "Bomb", 0.9 * size, nil, nil)
						if bomb then
							local b0 = start:Lerp(over, 0.55)
							animate(time * 0.45, function(kk)
								local bp = b0:Lerp(pt, kk * kk)
								SkillArt.Place(bomb, CFrame.lookAt(bp, pt + Vector3.new(0.01, 0, 0)))
							end, function()
								SkillArt.Destroy(bomb)
							end)
						end
					end)
				end
				animate(time + riseHold + (path == "Over" and time * 0.6 or 0), function(k, t)
					local u = math.clamp(t / time, 0, 1)
					local pos
					if path == "Rise" then
						pos = start:Lerp(pt + UP * (2 * size), outCubic(u))
						if t > time then
							pos += UP * math.sin((t - time) * 20) * 0.3 -- treme antes do bote
						end
					elseif path == "Fly" or path == "Swarm" then
						pos = start:Lerp(pt, u) + UP * (3 + 4 * math.sin(u * math.pi))
					elseif path == "Dive" then
						pos = start:Lerp(pt, u * u)
					elseif path == "Over" then
						pos = start:Lerp(over, t / time) -- continua voando depois do ponto
					else -- Run
						pos = start:Lerp(pt, u) + UP * (1 * size + math.abs(math.sin(t * 14)) * 0.6)
					end
					local dir = pos - last
					if dir.Magnitude < 0.001 then
						dir = flat(pt - start)
						if dir.Magnitude < 0.001 then
							dir = Vector3.new(0, 0, -1)
						end
					end
					if path == "Rise" then
						dir = flat(pt - from)
						if dir.Magnitude < 0.01 then
							dir = Vector3.new(0, 0, -1)
						end
					end
					last = pos
					if path == "Dive" then
						dir = pt - start + Vector3.new(0.01, 0, 0)
					end
					for _, it in ipairs(list) do
						local wob = swarm and Vector3.new(math.sin(t * 9 + it.ph) * 0.8, math.cos(t * 11 + it.ph) * 0.6, math.cos(t * 7 + it.ph) * 0.8) or Vector3.zero
						local at = pos + it.o + wob
						SkillArt.Place(it.rig, CFrame.lookAt(at, at + dir))
						if k < 0.12 then
							SkillArt.Fade(it.rig, 1 - k / 0.12)
						end
					end
				end, function()
					if path ~= "Over" then
						impact(def[4], pt, 3 * size, color)
					end
					for _, it in ipairs(list) do
						local rig = it.rig
						if path == "Rise" or path == "Over" then
							animate(0.35, function(kk)
								SkillArt.Fade(rig, kk)
							end, function()
								SkillArt.Destroy(rig)
							end)
						else
							SkillArt.Destroy(rig)
						end
					end
				end)
			end)
		end
	end

	------------------------------------------------------------ S_Sky: céu/tela muda (Supremos)
	local SKY = {
		Dark = { C(150, 135, 185), -0.12, 0.15, -0.2 },
		Red = { C(255, 150, 140), -0.05, 0.2, 0.1 },
		Gold = { C(255, 235, 180), 0.06, 0.1, 0.1 },
		Ice = { C(200, 230, 255), 0.04, 0.05, -0.25 },
		Night = { C(120, 120, 190), -0.2, 0.2, -0.3 },
		Storm = { C(170, 180, 205), -0.12, 0.25, -0.3 },
		Toxic = { C(190, 255, 170), -0.04, 0.1, 0 },
		Space = { C(160, 145, 230), -0.15, 0.2, 0.1 },
		Holy = { C(255, 250, 225), 0.12, 0.05, 0 },
		Fire = { C(255, 195, 150), 0, 0.15, 0.15 },
		Time = { C(225, 225, 235), 0, 0.05, -0.95 },
		Rainbow = { C(255, 245, 250), 0.05, 0.1, 0.6 },
		Abyss = { C(110, 150, 210), -0.18, 0.2, -0.2 },
		Sand = { C(255, 225, 170), 0, 0.1, -0.1 },
		Ocean = { C(150, 200, 255), -0.05, 0.1, 0.1 },
		Spooky = { C(255, 185, 140), -0.14, 0.22, 0.1 }, -- 🎃 Halloween: laranja de abóbora e mais escuro
	}
	function H.S_Sky(p)
		local cam = workspace.CurrentCamera
		if not cam or (p.Position and (cam.CFrame.Position - p.Position).Magnitude > 260) then
			return
		end
		local def = SKY[p.Kind or "Dark"] or SKY.Dark
		local dur = math.max(0.8, p.Duration or 3)
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "SkillSky"
		cc.TintColor = WHITE
		cc.Parent = Lighting
		Debris:AddItem(cc, dur + 1)
		local function goal(k)
			return { TintColor = WHITE:Lerp(def[1], k), Brightness = def[2] * k, Contrast = def[3] * k, Saturation = def[4] * k }
		end
		TweenService:Create(cc, TweenInfo.new(0.35), goal(1)):Play()
		task.delay(dur - 0.45, function()
			if cc.Parent then
				TweenService:Create(cc, TweenInfo.new(0.45), goal(0)):Play()
			end
		end)
		-- clarão branco no começo
		local fl = Instance.new("ColorCorrectionEffect")
		fl.Brightness = 0.35
		fl.Parent = Lighting
		TweenService:Create(fl, TweenInfo.new(0.35), { Brightness = 0 }):Play()
		Debris:AddItem(fl, 0.5)
		if p.Kind == "Storm" then
			for i = 1, q(4) do
				task.delay(i * dur / 5, function()
					local f2 = Instance.new("ColorCorrectionEffect")
					f2.Brightness = 0.25
					f2.Parent = Lighting
					TweenService:Create(f2, TweenInfo.new(0.15), { Brightness = 0 }):Play()
					Debris:AddItem(f2, 0.3)
				end)
			end
		end
	end

	------------------------------------------------------------ S_Charge: carga de energia no corpo
	function H.S_Charge(p)
		local root = rootOf(p.Model)
		if not root then
			return
		end
		local dur = math.max(0.2, p.Duration or 0.6)
		local color = p.Color or WHITE
		local s = sizeOf(p.Model)
		local shell = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * (6 * s + root.Size.Z), CFrame = root.CFrame, Transparency = 1 })
		local e = emitter(shell, {
			Texture = TEX.Sparkle,
			Enabled = true,
			Rate = 70 * quality(),
			Color = ColorSequence.new(color),
			Size = NS(0, 0.5 * s, 1, 0.1),
			Lifetime = NumberRange.new(0.3, 0.45),
			Speed = NumberRange.new(9 * s, 12 * s),
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			LightEmission = 1,
		})
		local glow = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, CFrame = root.CFrame, Color = color, Transparency = 1 })
		local pl = Instance.new("PointLight")
		pl.Color = color
		pl.Range = 12 * s
		pl.Brightness = 0
		pl.Parent = glow
		animate(dur, function(k)
			if not root.Parent then
				return true
			end
			shell.CFrame = root.CFrame
			glow.CFrame = root.CFrame
			glow.Size = Vector3.one * (root.Size.Z * (0.6 + 0.9 * k))
			glow.Transparency = 0.9 - 0.45 * k
			pl.Brightness = 4 * k
			return false
		end, function()
			e.Enabled = false
			shell:Destroy()
			flash(root.Position, root.Size.Z * 1.2, color, 0.2)
			glow:Destroy()
		end)
		local feet = feetOf(p.Model)
		if feet then
			groundRing(feet, root.Size.Z * 1.6 + 3, 0.5, color, dur)
		end
	end
end
