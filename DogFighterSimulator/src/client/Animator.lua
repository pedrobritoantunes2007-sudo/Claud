-- ANIMAÇÃO PROCEDURAL DE TODOS OS CACHORROS (jogadores, NPCs, chefões e modelos nas telas 3D).
-- Cada cliente anima localmente (nada replica). Lê a velocidade do HumanoidRootPart, o chão, a água, a vida
-- e o atributo "Action" (servidor) e move os Motor6D: Body, Neck1..3, Jaw1..3, LegFL/FR/BL/BR,
-- KneeFL/FR/BL/BR (joelhos), Tail, WingL/WingR + WingL2/WingR2 (cotovelo da asa) e as orelhas (Welds "Orelha").
--
-- COMO ESTÁ ORGANIZADO
--   1. Ajustes (TUNE)        todos os números num lugar só
--   2. Rig                   coleta das juntas (repetível, por causa do streaming)
--   3. Sentidos              velocidade, aceleração, giro, chão, água, vida (levar dano)
--   4. Estado                pesos de andar/ar/nado, andadura, fase do passo, olhar, relógio de parado
--                            OLHAR: o cachorro do jogador olha para a SETINHA do mouse (Animator.SetLookAt, chamado
--                            pelo DogControl); os outros jogadores veem pelo atributo "LookAt" (servidor). Cabeça na
--                            frente, o corpo torce junto (patas ficam plantadas) e o rabo abana mais se a setinha
--                            passa rápido perto (igual cachorro vendo laser). NPCs olham o cachorro mais perto.
--   5. Poses                 parado (comportamentos, sentar, deitar, dormir), passo/trote/galope com joelho,
--                            curvas, freada, pulo, queda, pouso, nado, flutuar, fúria
--   6. Ações                 uma função por Action do servidor (tabela ACTIONS) + uma genérica para poderes novos
--                            VOO = AVIÃO: asas abertas planando, patas recolhidas, rabo de leme, cabeça nivelada nas
--                            curvas, mergulho com asas para trás; devagar fica em pé batendo as asas
--   7. Camadas por cima      mordida (3 variações), levar dano, esquiva, mancar com vida baixa
--   8. Movimento secundário  orelhas e rabo com mola (balançam e atrasam como de verdade)
--   9. Aplicar               suavização por junta; Motor6D.Transform ou C0 (telas 3D / plano B)
--  10. Laço                  PreSimulation com LOD (chefões contam pelo tamanho, não somem de longe)
--
-- CONVENÇÕES (conferidas no modelo, o cachorro olha para -Z)
--   Perna/joelho: A(+x) leva a pata para a FRENTE. Joelho da frente ("punho") dobra com x NEGATIVO,
--   jarrete de trás dobra com x POSITIVO (tabela FLEX).
--   Pescoço: A(+x) levanta o nariz · Mandíbula: A(-x) abre a boca · Rabo: A(+x) abaixa o rabo.
--   Asas: "para baixo" = A(0, 0, -lado) e "para trás" = A(0, -lado, 0) (lado: esquerda -1, direita +1).
--
-- ROBUSTEZ (bugs antigos — não remover)
--   • StreamingEnabled: o Model chega antes dos filhos → o rig é recoletado a cada DescendantAdded/Removing.
--   • Motor6D.Transform escrito em PreSimulation (depois do Animator do Roblox, antes da física). Se as peças
--     não seguirem o Transform por alguns segundos, o cachorro passa para o modo C0 (base * pose), que relê a
--     base quando o servidor muda o C0 (ScaleTo do Titan).
--   • Erros nunca somem em silêncio: aviso com limite de spam, recoleta e continua animando.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Animator = {}

local tracked = {} -- [model] = estado

---------------------------------------------------------------- 1. AJUSTES
local TUNE = {
	-- velocidade em "comprimentos de perna por segundo": vale igual para filhote e chefão gigante
	MoveAt = 0.35, -- abaixo disso está parado
	TrotAt = 1.7,
	GallopAt = 4.2,
	Duty = { Walk = 0.64, Trot = 0.5, Gallop = 0.4 }, -- parte do ciclo com a pata no chão
	Swing = { Walk = 0.36, Trot = 0.48, Gallop = 0.66 }, -- abertura da perna (rad)
	-- ciclos por segundo. (2026-10-24, o dono: "tem alguns cachorros que estão deslizando") o teto do ritmo depende do
	-- tamanho: Hz / √perna (perna curta bate mais rápido, como cachorro de verdade), entre Max e Top. Antes o teto era
	-- 3,4/s para todos e, depois que os cachorros diminuíram, 77 das 80 raças "patinavam" correndo
	Cycle = { Min = 0.55, Max = 3.4, Turn = 1.8, Hz = 6.2, Top = 11 },
	-- passou do teto: o passo ESTICA até Stretch vezes (a perna abre mais e fica mais tempo no ar: galope voador)
	Stretch = 2.2,
	IdleEvery = { 5, 11 }, -- segundos entre comportamentos quando parado
	SitAfter = 18,
	LieAfter = 38,
	SleepAfter = 70,
	LowHealth = 0.3, -- abaixo disso manca, rabo e orelhas caem
	BigStep = 2.5, -- escala a partir da qual cada pata levanta poeira (chefões)
	Smooth = { Body = 14, Neck = 16, Jaw = 22, Leg = 24, Knee = 26, Tail = 30, Wing = 20, Fast = 40 },
	-- olhar (rad): Yaw = quanto vira no total, Neck = só o pescoço, Twist = o corpo torce junto;
	-- Stiff/Damp = mola da cabeça (rápida, com um tiquinho de passada, como cachorro de verdade)
	Look = { Yaw = 2.2, Neck = 1.2, Twist = 0.42, Up = 0.85, Down = 0.7, Stiff = 150, Damp = 18 },
	FlyMult = 4, -- igual ao DogControl: velocidade de cruzeiro do voo = BaseSpeed × FlyMult
}
-- LOD pela distância da câmera ÷ tamanho do cachorro, conforme a qualidade escolhida (atributo do LocalPlayer)
-- Far: além disso não anima · Mid: além disso anima a cada 3 quadros
local LOD = {
	Alto = { Far = 250, Mid = 110 },
	["Médio"] = { Far = 200, Mid = 80 },
	Baixo = { Far = 140, Mid = 50 },
}

local LEGS = { "LegFL", "LegFR", "LegBL", "LegBR" }
local KNEE_OF = { LegFL = "KneeFL", LegFR = "KneeFR", LegBL = "KneeBL", LegBR = "KneeBR" }
local FRONT = { LegFL = true, LegFR = true }
local SIDE = { LegFL = -1, LegBL = -1, LegFR = 1, LegBR = 1 }
local FLEX = { LegFL = -1, LegFR = -1, LegBL = 1, LegBR = 1 }
-- ordem das patas em cada andadura (fração do ciclo)
local PHASE = {
	Walk = { LegBL = 0, LegFL = 0.25, LegBR = 0.5, LegFR = 0.75 }, -- passo: 4 tempos
	Trot = { LegFL = 0, LegBR = 0, LegFR = 0.5, LegBL = 0.5 }, -- trote: diagonais juntas
	Gallop = { LegBL = 0, LegBR = 0.1, LegFR = 0.42, LegFL = 0.54 }, -- galope rotativo
}
local GALLOP_ACTIONS = { Dash = true, Charge = true, Zoom = true }
-- (2026-10) + poses das habilidades novas: no ar quem manda é a pose (o servidor leva o cachorro em arco)
local NO_AIR_ACTIONS = {
	Fly = true,
	Float = true,
	Dive = true,
	Rear = true,
	Spin = true,
	KO = true,
	Vanish = true,
	Leap = true,
	Flip = true,
	Roll = true,
	Curl = true,
	Drill = true,
	Bounce = true,
	Belly = true,
	Slide = true,
	Focus = true,
	Summon = true,
	Victory = true,
}
local STILL_ACTIONS = {
	KO = true,
	Sit = true,
	Eat = true,
	Howl = true,
	Aim = true,
	Open = true,
	Bark = true,
	Sniff = true,
	Bow = true,
	Throw = true,
	Flex = true,
	Focus = true,
	Guard = true,
	Inhale = true,
	Snore = true,
	Victory = true,
	Wiggle = true,
	Shake = true,
	Dig = true,
	Stomp = true,
	Summon = true,
	Spit = true,
	Kick = true,
	Uppercut = true,
	Curl = true,
}

-- suavização de cada junta
local RATE = { Body = TUNE.Smooth.Body, Tail = TUNE.Smooth.Tail }
local LEG_JOINT = {} -- pernas e joelhos (andando, a suavização acompanha o ritmo do passo: s.LegRate)
for _, leg in ipairs(LEGS) do
	RATE[leg] = TUNE.Smooth.Leg
	RATE[KNEE_OF[leg]] = TUNE.Smooth.Knee
	LEG_JOINT[leg], LEG_JOINT[KNEE_OF[leg]] = true, true
end
for i = 1, 3 do
	RATE["Neck" .. i] = TUNE.Smooth.Neck
	RATE["Jaw" .. i] = TUNE.Smooth.Jaw
end
for _, w in ipairs({ "WingL", "WingR", "WingL2", "WingR2" }) do
	RATE[w] = TUNE.Smooth.Wing
end

---------------------------------------------------------------- utilidades
local IDENT = CFrame.identity
local TAU = math.pi * 2

local function A(x, y, z)
	return CFrame.Angles(x or 0, y or 0, z or 0)
end

local function T(x, y, z)
	return CFrame.new(x or 0, y or 0, z or 0)
end

-- cabeça: vira para o lado, DEPOIS levanta o nariz e inclina (ordem natural do pescoço). Com A() o giro de lado
-- acontecia já com o nariz levantado e a cabeça entortava ao olhar para cima e para o lado ao mesmo tempo.
local function HEAD(pitch, yaw, tilt)
	return CFrame.fromEulerAnglesYXZ(pitch or 0, yaw or 0, tilt or 0)
end

local function damp(dt, k)
	return 1 - math.exp(-k * dt)
end

local function smooth01(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- entra em `inT`, segura e sai nos últimos `outT` segundos de uma pose com duração `dur`
local function envelope(t, dur, inT, outT)
	return smooth01(t / inT) * smooth01((dur - t) / outT)
end

-- 0 → 1 → 0 (meia senoide) durante `dur`
local function pulse(t, dur)
	if t < 0 or t > dur then
		return 0
	end
	return math.sin(t / dur * math.pi)
end

local function near(a: CFrame, b: CFrame)
	return (a.Position - b.Position).Magnitude < 1e-3 and a.XVector:Dot(b.XVector) > 0.99999 and a.YVector:Dot(b.YVector) > 0.99999
end

-- pose = tabela { nomeDaJunta = CFrame, TailX = número, TailY = número }
local function mul(P, name, cf)
	P[name] = (P[name] or IDENT) * cf
end

-- multiplica ANTES: gira a junta inteira no espaço do pai (usado para manter as patas plantadas)
local function pre(P, name, cf)
	P[name] = cf * (P[name] or IDENT)
end

-- mola amortecida em passos pequenos (estável mesmo com dt grande do LOD)
local function spring(x, v, goal, k, d, dt)
	local n = math.max(1, math.ceil(dt / 0.016))
	local h = dt / n
	for _ = 1, n do
		v += ((goal - x) * k - v * d) * h
		x += v * h
	end
	return x, v
end

-- mistura a pose Q por cima de P com peso w (0..1)
local function blend(P, Q, w)
	if w <= 0.001 then
		return
	end
	w = math.min(w, 1)
	for name, v in pairs(Q) do
		if type(v) == "number" then
			local cur = P[name] or 0
			P[name] = cur + (v - cur) * w
		else
			P[name] = (P[name] or IDENT):Lerp(v, w)
		end
	end
end

-- poeira (pouso, pegadas de chefão, pancada no chão) — só visual, no cliente
local function dust(pos: Vector3, power: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(pos)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(215, 200, 170))
	e.Transparency = NumberSequence.new(0.35, 1)
	e.Size = NumberSequence.new(1.2 * power, 3 * power)
	e.Lifetime = NumberRange.new(0.4, 0.7)
	e.Speed = NumberRange.new(6 * math.sqrt(power), 10 * math.sqrt(power))
	e.SpreadAngle = Vector2.new(80, 5)
	e.EmissionDirection = Enum.NormalId.Top
	e.Enabled = false
	e.Parent = p
	p.Parent = workspace
	e:Emit(math.clamp(math.floor(10 * power), 3, 30))
	Debris:AddItem(p, 1.2)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false -- o raio para na superfície da água: é assim que sabemos que está nadando

---------------------------------------------------------------- 2. RIG
local function refresh(s)
	s.Dirty = false
	local motors, ears, humanoid = {}, {}, nil
	for _, d in ipairs(s.Model:GetDescendants()) do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		elseif d:IsA("Weld") then
			local p0, p1 = d.Part0, d.Part1
			if p0 and p1 and (p1.Name == "Orelha" or p1.Name == "OrelhaDentro") then
				local head = tonumber(string.match(p0.Name, "^Head(%d)$"))
				if head then
					table.insert(ears, { Weld = d, Part = p1, Head = head, Main = p1.Name == "Orelha" })
				end
			end
		elseif d:IsA("Humanoid") then
			humanoid = d
		end
	end
	-- motores que sumiram: esquece o estado deles
	for name, m in pairs(s.Motors) do
		if motors[name] ~= m then
			s.Current[name] = nil
		end
	end
	-- orelha principal antes da parte de dentro (a de dentro usa a dobradiça da principal)
	table.sort(ears, function(a, b)
		return a.Main and not b.Main
	end)
	s.Motors, s.Ears, s.Humanoid = motors, ears, humanoid
	-- eixo do abanar do rabo (DogBuilder: perpendicular à direção do rabo e ao lado)
	local tailMotor = motors.Tail
	local wag = tailMotor and tailMotor.Part1 and tailMotor.Part1:GetAttribute("WagAxis")
	s.WagAxis = typeof(wag) == "Vector3" and wag.Magnitude > 0.1 and wag.Unit or nil
	s.Parts, s.Fade = nil, -1
	s.Root = s.Model.PrimaryPart or s.Model:FindFirstChild("HumanoidRootPart")
	s.Count = 0
	for _ in pairs(motors) do
		s.Count += 1
	end
	-- medidas do esqueleto (C0 original): ombros (patas plantadas quando o corpo torce), pescoço (de onde
	-- o olhar sai) e o ângulo que a asa sobe parada (para abrir RETA como asa de avião)
	local function c0(m)
		return s.Base[m] or m.C0
	end
	s.LegZ = {}
	for _, leg in ipairs(LEGS) do
		if motors[leg] then
			s.LegZ[leg] = c0(motors[leg]).Position.Z
		end
	end
	s.NeckPos = motors.Neck1 and c0(motors.Neck1).Position or nil
	-- 🐾 alavanca da perna (2026-10-24): do ombro/quadril até a sola, em pé — é o raio que a pata percorre no passo.
	-- O LegLen (atributo) é só a perna desenhada e fica 1,3 a 2x menor: com ele a pata corria mais que o corpo.
	-- Guardada como proporção do LegLen (o sense multiplica pelo tamanho atual — o Titan cresce)
	s.LeverRatio = nil
	local body, root = motors.Body, s.Root
	-- (cachorro com asa anda com o GroundHip; o HipHeight dele é o do voo)
	local hipH = s.Model:GetAttribute("GroundHip") or s.Model:GetAttribute("HipHeight")
	local legAttr = s.Model:GetAttribute("LegLen") or hipH
	if body and root and type(hipH) == "number" and type(legAttr) == "number" and legAttr > 0 then
		local okScale, scale = pcall(s.Model.GetScale, s.Model)
		scale = (okScale and type(scale) == "number" and scale > 0) and scale or 1
		local sum, n = 0, 0
		for _, leg in ipairs(LEGS) do
			local m = motors[leg]
			if m and m.Part0 and m.Part0 == body.Part1 then
				local pivot = (c0(body) * body.C1:Inverse() * c0(m)).Position
				local r = (pivot.Y + root.Size.Y / 2) / scale + hipH
				if r > 0.1 then
					sum += r
					n += 1
				end
			end
		end
		if n > 0 then
			s.LeverRatio = math.clamp(sum / n / legAttr, 1, 3)
		end
	end
	s.WingFlat = nil
	local wing, elbow = motors.WingR, motors.WingR2
	if wing and elbow then
		local d = c0(wing).Rotation * c0(elbow).Position
		s.WingFlat = math.clamp(math.atan2(d.Y, math.abs(d.X)), 0, 1.4)
	end
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop(0)
			end
		end
	end
end

-- C0 base da junta; relê se alguém (ScaleTo do servidor) mudou o C0 desde a nossa escrita
local function baseC0(s, joint)
	local c0 = joint.C0
	local base = s.Base[joint]
	local written = s.Written[joint]
	if not base or (written and not near(c0, written)) or (not written and not near(c0, base)) then
		base = c0
		s.Base[joint] = base
	end
	return base
end

local function writeC0(s, joint, cf)
	joint.C0 = cf
	s.Written[joint] = joint.C0
end

local function restore(s)
	for _, motor in pairs(s.Motors) do
		if s.UseC0 or s.Mode == "C0" then
			local base = s.Base[motor]
			if base then
				motor.C0 = base
			end
		else
			motor.Transform = IDENT
		end
	end
	for _, ear in ipairs(s.Ears) do
		local base = s.Base[ear.Weld]
		if base then
			ear.Weld.C0 = base
		end
	end
end

local function setFade(s, value)
	if s.Fade == value then
		return
	end
	s.Fade = value
	if not s.Parts then
		s.Parts = {}
		for _, d in ipairs(s.Model:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				table.insert(s.Parts, d)
			end
		end
	end
	for _, p in ipairs(s.Parts) do
		p.LocalTransparencyModifier = value
	end
	local info = s.Model:FindFirstChild("Info")
	if info and info:IsA("BillboardGui") then
		info.Enabled = value < 0.9
	end
end

---------------------------------------------------------------- 3. SENTIDOS
local function sense(s, dt, now)
	local model, root = s.Model, s.Root
	local scaleNow = 1
	local ok, sc = pcall(model.GetScale, model)
	if ok and type(sc) == "number" then
		scaleNow = sc
	end
	s.S = (model:GetAttribute("BaseScale") or 1) * scaleNow
	s.LegLen = math.max(0.5, (model:GetAttribute("LegLen") or model:GetAttribute("GroundHip") or model:GetAttribute("HipHeight") or 2) * scaleNow)
	s.Lever = (model:GetAttribute("LegLen") or model:GetAttribute("GroundHip") or model:GetAttribute("HipHeight") or 2) * scaleNow * (s.LeverRatio or 1)

	local speed, vy, yawRate, side, back = 0, 0, 0, 0, false
	if s.FakeSpeed then
		speed = s.FakeSpeed() or 0
	else
		local cf = root.CFrame
		local v = root.AssemblyLinearVelocity
		local flat = Vector3.new(v.X, 0, v.Z)
		vy = v.Y
		if s.LastPos and dt > 0 then
			-- velocidade replicada OU deslocamento real, o que for maior (NPC movido por CFrame não tem velocidade)
			local d = (cf.Position - s.LastPos) / dt
			if d.Magnitude < 250 then -- ignora teleporte (PivotTo)
				local dflat = Vector3.new(d.X, 0, d.Z)
				if dflat.Magnitude > flat.Magnitude then
					flat = dflat
				end
				if math.abs(d.Y) > math.abs(vy) then
					vy = d.Y
				end
			end
			local look, last = cf.LookVector, s.LastLook
			local ang = math.atan2(look.X, look.Z) - math.atan2(last.X, last.Z)
			yawRate = ((ang + math.pi) % TAU - math.pi) / dt
		end
		s.LastPos, s.LastLook = cf.Position, cf.LookVector
		speed = flat.Magnitude
		if speed > 0.5 then
			local localV = cf:VectorToObjectSpace(flat)
			side = localV.X / speed
			back = localV.Z > speed * 0.4 -- andando de ré
		end
	end
	local lastSpeed = s.Speed
	s.Speed += (speed - s.Speed) * damp(dt, 10)
	s.Accel += ((s.Speed - lastSpeed) / math.max(dt, 1e-3) - s.Accel) * damp(dt, 6)
	s.VelY += (vy - s.VelY) * damp(dt, 12)
	s.Yaw += (math.clamp(yawRate, -8, 8) - s.Yaw) * damp(dt, 6)
	s.Side += (side - s.Side) * damp(dt, 6)
	s.Back = back
	s.Rel = s.Speed / s.LegLen

	-- vida: levar dano (tranco) e vida baixa (manca)
	local hum = s.Humanoid
	if hum and hum.Parent then
		local hp, max = hum.Health, math.max(1, hum.MaxHealth)
		if s.LastHealth and hp < s.LastHealth - 0.5 and hp > 0 then
			s.HitAt = now
			s.HitPower = math.clamp((s.LastHealth - hp) / max * 6, 0.35, 1)
			s.HitSide = math.random() < 0.5 and -1 or 1
			s.EarKick += 5 * s.HitPower
		end
		s.LastHealth = hp
		s.Health = hp / max
	end
end

-- chão e água embaixo (raio leve, 10x por segundo)
local function groundCheck(s, now)
	if now < s.NextRay then
		return
	end
	s.NextRay = now + 0.1
	local root = s.Root
	local reach = root.Size.Y / 2 + s.LegLen + 1.6 * s.S
	rayParams.FilterDescendantsInstances = { s.Model }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), rayParams)
	s.Grounded = hit ~= nil
	s.InWater = hit ~= nil and hit.Material == Enum.Material.Water
end

---------------------------------------------------------------- 4. ESTADO
local function context(s, dt, now, snap)
	local model = s.Model
	local action = model:GetAttribute("Action")
	-- voando (cachorro do jogador): pose de voo quando não há outra ação (a esquiva no ar marca "Dash" no
	-- servidor, mas no ar ela é o parafuso do avião: continua na pose de voo)
	local flying = model:GetAttribute("Flying") == true
	if (not action or action == "Dash") and flying then
		action = "Fly"
	end
	if action ~= s.LastAction then
		s.LastAction = action
		s.ActionStart = now
		s.ActionFx = nil
	end
	return {
		now = now,
		dt = dt,
		t = now + s.Seed,
		S = s.S,
		action = action,
		-- (habilidade do jogador: a pose anda mais rápido — atributo ActionSpeed, Fighters.SetAction)
		at = (now - (s.ActionStart or now)) * (model:GetAttribute("ActionSpeed") or 1),
		raging = model:GetAttribute("Raging") == true,
		-- 🪽 habilidade usada VOANDO: a pose da habilidade vai em cima da pose de voo (buildPose)
		airAction = flying and action ~= nil and action ~= "Fly" and action ~= "Float",
		floater = model:GetAttribute("Float") == true,
		heads = model:GetAttribute("Heads") or 1,
		big = s.S >= TUNE.BigStep,
		boss = model:GetAttribute("Kind") == "boss" or s.S >= 4,
		snap = snap, -- sem suavização (prévia)
		fast = {}, -- juntas que precisam responder rápido neste quadro
		ear = nil, -- "back" | "up" | "droop"
		wind = 0, -- 0..1.5: vento do voo (orelhas tremulando)
		fade = 0,
	}
end

local function updateAir(s, c)
	local air = false
	if not s.FakeSpeed and not c.floater and not NO_AIR_ACTIONS[c.action] then
		groundCheck(s, c.now)
		air = not s.Grounded or s.VelY > 12 * math.sqrt(s.S)
	else
		s.InWater = false
	end
	if air ~= s.Air then
		if air then
			s.AirSince = c.now
			if s.VelY > 2 then
				s.TakeoffAt = c.now
			end
		elseif c.now - s.AirSince > 0.22 then
			s.LandAt = c.now
			s.LandPower = math.clamp((c.now - s.AirSince) / 0.8, 0.35, 1)
			s.EarKick += 7 * s.LandPower
			if s.LandPower > 0.5 then
				dust(s.Root.Position - Vector3.new(0, s.LegLen + s.Root.Size.Y / 2, 0), s.LandPower * math.sqrt(s.S))
			end
		end
		s.Air = air
	end
	s.AirW += (((air and c.now - s.AirSince > 0.08) and 1 or 0) - s.AirW) * damp(c.dt, 10)
	s.SwimW += (((s.InWater and not air) and 1 or 0) - s.SwimW) * damp(c.dt, 4)
end

-- andadura: UMA de cada vez, escolhida pela velocidade com uma folga (histerese) para não ficar trocando. (2026-10-24)
-- Antes as andaduras se misturavam numa faixa de velocidade e, misturadas (passos em tempos diferentes), a perna
-- abria menos e a pata patinava; agora só misturam no instante da troca (os pesos mudam devagar logo abaixo).
local GAIT_SLACK = 0.15 -- comprimentos de perna/s
local function gaitWeights(s, c, instant)
	local rel, cur = s.Rel, s.GaitNow or "Walk"
	local want
	if GALLOP_ACTIONS[c.action] or rel > TUNE.GallopAt + (cur == "Gallop" and -GAIT_SLACK or GAIT_SLACK) then
		want = "Gallop"
	elseif rel > TUNE.TrotAt + (cur ~= "Walk" and -GAIT_SLACK or GAIT_SLACK) then
		want = "Trot"
	else
		want = "Walk"
	end
	s.GaitNow = want
	local g = s.Gait
	local k = instant and 1 or damp(c.dt, 5)
	g.Walk += ((want == "Walk" and 1 or 0) - g.Walk) * k
	g.Trot += ((want == "Trot" and 1 or 0) - g.Trot) * k
	g.Gallop += ((want == "Gallop" and 1 or 0) - g.Gallop) * k
end

-- 🐾 SEM PATINAR (2026-10-24, o dono: "tem alguns cachorros que estão deslizando"): abertura (rad) e apoio (parte do
-- ciclo com a pata no chão) de cada andadura. stretch > 1 = passo esticado: a perna abre mais e o apoio fica mais curto
-- (mais tempo no ar). O passo (distância por ciclo) sai daqui mesmo: 2 · perna · sen(abertura) / apoio — é o que a pata
-- anda para trás no chão enquanto apoia, então o corpo e a pata andam juntos
local function gaitShape(s, gait, stretch)
	local amp = TUNE.Swing[gait]
	if gait ~= "Gallop" then
		amp *= math.clamp(0.55 + s.Rel * 0.2, 0.55, 1.15)
	end
	local k = stretch - 1
	return math.min(1.2, amp * (1 + 0.32 * k)), TUNE.Duty[gait] / (1 + 0.45 * k)
end
local function strideOf(s, stretch)
	local total = 0
	for gait, w in pairs(s.Gait) do
		if w > 0.001 then
			local amp, duty = gaitShape(s, gait, stretch)
			total += w * 2 * math.sin(amp) / duty
		end
	end
	return math.max(0.05, total * (s.Lever or s.LegLen))
end

local function advancePhase(s, c)
	-- ritmo = velocidade ÷ passo, até o teto do tamanho do cachorro; mais rápido que isso, o passo estica
	local cap = math.clamp(TUNE.Cycle.Hz / math.sqrt(math.max(0.2, s.Lever or s.LegLen)), TUNE.Cycle.Max, TUNE.Cycle.Top)
	local want = math.clamp(s.Speed / (strideOf(s, 1) * cap), 1, TUNE.Stretch)
	s.Stretch += (want - s.Stretch) * damp(c.dt, 6)
	local freq = math.clamp(s.Speed / strideOf(s, s.Stretch), TUNE.Cycle.Min, cap)
	if s.TurnW > s.MoveW then
		freq = TUNE.Cycle.Turn
	end
	if c.raging then
		freq *= 0.8 -- fúria: passadas pesadas
	end
	local w = math.max(s.MoveW, s.TurnW)
	s.Phase = (s.Phase + c.dt * freq * w * (s.Back and -1 or 1)) % 1
	-- pernas rápidas não podem ser "amaciadas" demais: a suavização comia a passada (a perna abria metade)
	s.LegRate = TUNE.Smooth.Leg + freq * 14 * w
end

-- ponto para onde olhar: a setinha do mouse deste jogador (SetLookAt) ou o atributo "LookAt" que o
-- servidor põe no cachorro de cada jogador (assim todo mundo vê para onde o outro está olhando)
local function lookPoint(s, now)
	if s.LookPoint and now - s.LookPointAt < 0.5 then
		return s.LookPoint
	end
	local attr = s.Model:GetAttribute("LookAt")
	if typeof(attr) == "Vector3" then
		return attr
	end
	return nil
end

-- olhar. Prioridade: (1) a setinha do mouse; (2) o cachorro mais perto na frente (luta, encontro);
-- (3) olhar em volta. A cabeça vai numa mola rápida (como cachorro de verdade, que vira a cabeça de uma vez);
-- o corpo torce uma parte mais devagar (s.Twist) quando o alvo está muito para o lado.
local function updateLook(s, c)
	local now, dt, L = c.now, c.dt, TUNE.Look
	local point = not s.UseC0 and lookPoint(s, now) or nil
	local goal = Vector3.zero -- (cima/baixo, lados, cabeça inclinada)
	if point then
		local root = s.Root
		local neck = root.CFrame * (s.NeckPos or Vector3.new(0, 0, -root.Size.Z * 0.45))
		local d = point - neck
		local dist = d.Magnitude
		local rel = root.CFrame:VectorToObjectSpace(d)
		local yaw = math.atan2(-rel.X, -rel.Z)
		local pitch = math.atan2(rel.Y, math.max(0.01, math.sqrt(rel.X * rel.X + rel.Z * rel.Z)))
		-- setinha passando RÁPIDO perto do cachorro = animado (rabo abanando forte, orelha em pé, pulinhos)
		if dist > 0.01 then
			local dir = d / dist
			if s.LastLookDir and dt > 0 then
				local turnSpeed = math.acos(math.clamp(dir:Dot(s.LastLookDir), -1, 1)) / dt
				local near = 1 - smooth01((dist - 10 * s.S) / (30 * s.S))
				s.Excite = math.clamp(s.Excite + (math.max(0, turnSpeed - 1.2) * 0.4 * near - 0.2) * dt, 0, 1)
			end
			s.LastLookDir = dir
		end
		-- setinha parada perto: inclina a cabeça de lado, curioso
		if s.LastPoint and (point - s.LastPoint).Magnitude < 1.5 * s.S then
			s.StillFor += dt
		else
			s.StillFor = 0
			s.LastPoint = point
		end
		local tilt = 0
		if s.StillFor > 1.3 and dist < 22 * s.S and math.abs(yaw) < 1.3 then
			if s.StillFor - dt <= 1.3 then
				s.TiltSide = math.random() < 0.5 and -1 or 1
			end
			tilt = s.TiltSide * 0.32 * smooth01((s.StillFor - 1.3) / 0.4)
		end
		goal = Vector3.new(math.clamp(pitch, -L.Down, L.Up), math.clamp(yaw, -L.Yaw, L.Yaw), tilt)
	else
		s.Excite = math.max(0, s.Excite - dt * 0.3)
		s.LastLookDir = nil
		if not s.UseC0 and now > s.NextTarget then
			s.NextTarget = now + 0.45
			s.Target = nil
			local root = s.Root
			local best = 26 * math.max(1, math.sqrt(s.S))
			for other, o in pairs(tracked) do
				if other ~= s.Model and not o.UseC0 and o.Root and o.Root.Parent then
					local d = o.Root.Position - root.Position
					local dist = d.Magnitude
					if dist > 0.1 and dist < best and root.CFrame.LookVector:Dot(d / dist) > -0.1 then
						best, s.Target = dist, o.Root
					end
				end
			end
		end
		if s.Target and s.Target.Parent then
			local rel = s.Root.CFrame:PointToObjectSpace(s.Target.Position)
			local yaw = math.atan2(-rel.X, -rel.Z)
			local pitch = math.atan2(rel.Y, Vector3.new(rel.X, 0, rel.Z).Magnitude)
			goal = Vector3.new(math.clamp(pitch, -0.45, 0.45), math.clamp(yaw, -1.4, 1.4), 0)
		else
			if now > s.NextLook then
				s.NextLook = now + 1.6 + math.random() * 2.8
				if math.random() < 0.3 then
					s.LookGoal = Vector3.zero
				else
					s.LookGoal = Vector3.new(
						(math.random() - 0.5) * 0.35, -- para cima/baixo
						(math.random() - 0.5) * 1.5, -- para os lados
						math.random() < 0.25 and (math.random() - 0.5) * 0.6 or 0 -- cabeça inclinada, curioso
					)
				end
			end
			goal = s.LookGoal
		end
	end
	-- o corpo torce uma parte (devagar), o pescoço faz o resto (rápido)
	local twistGoal = math.clamp(goal.Y * 0.32, -L.Twist, L.Twist)
	local neckGoal = math.clamp(goal.Y - twistGoal, -L.Neck, L.Neck)
	s.LookYaw, s.LookYawV = spring(s.LookYaw, s.LookYawV, neckGoal, L.Stiff, L.Damp, dt)
	s.LookPitch, s.LookPitchV = spring(s.LookPitch, s.LookPitchV, goal.X, L.Stiff, L.Damp, dt)
	s.LookTilt += (goal.Z - s.LookTilt) * damp(dt, 5)
	s.Twist += (twistGoal - s.Twist) * damp(dt, 4)
end

-- comportamentos de quando está parado (segundos de duração)
local BEHAVIORS = { sniff = 2.8, scratch = 2.4, shake = 1.1, yawn = 2.1, bow = 2.3, lookback = 1.8, paw = 1.6, hop = 1.1, chase = 2.4 }
local BEHAVIOR_LIST = { "sniff", "scratch", "shake", "yawn", "bow", "lookback", "paw", "chase" }
local SHOWCASE_LIST = { "hop", "bow", "paw", "lookback", "shake", "yawn", "chase" } -- telas 3D: só os fofos

local function idleClock(s, c)
	local calm = s.MoveW < 0.05 and s.AirW < 0.05 and s.SwimW < 0.05 and not c.action and not c.raging
	if calm then
		s.IdleTime += c.dt
	else
		s.IdleTime = 0
		s.Behavior = nil
	end
	-- animado com a setinha: não senta nem dorme (e acorda se estava dormindo)
	if s.Excite > 0.3 then
		s.IdleTime = math.min(s.IdleTime, TUNE.SitAfter * 0.5)
	end
	-- descanso: senta, depois deita, depois dorme (só fora das telas 3D e fora de chefões)
	local posture = 0
	if calm and not s.UseC0 and not c.boss then
		if s.IdleTime > TUNE.SleepAfter then
			posture = 3
		elseif s.IdleTime > TUNE.LieAfter then
			posture = 2
		elseif s.IdleTime > TUNE.SitAfter then
			posture = 1
		end
	end
	local k = damp(c.dt, 2.5)
	s.SitW += ((posture == 1 and 1 or 0) - s.SitW) * k
	s.LieW += ((posture >= 2 and 1 or 0) - s.LieW) * k
	s.SleepW += ((posture == 3 and 1 or 0) - s.SleepW) * damp(c.dt, 1.2)
	-- de vez em quando, um comportamento curto (em pé)
	if s.Behavior and c.now - s.BehaviorAt > BEHAVIORS[s.Behavior] then
		s.Behavior = nil
	end
	-- muito animado: reverência de brincadeira ("vem brincar!")
	if calm and posture == 0 and not s.Behavior and s.Excite > 0.7 and c.now > (s.NextPlay or 0) then
		s.Behavior, s.LastBehavior, s.BehaviorAt = "bow", "bow", c.now
		s.BehaviorSide = math.random() < 0.5 and -1 or 1
		s.NextPlay = c.now + 6
		s.NextBehavior = c.now + BEHAVIORS.bow + 3
	end
	if calm and posture == 0 and not s.Behavior and s.IdleTime > 1.5 and c.now > s.NextBehavior then
		local list = s.UseC0 and SHOWCASE_LIST or BEHAVIOR_LIST
		local pick = list[math.random(1, #list)]
		if pick == s.LastBehavior then
			pick = list[(table.find(list, pick) :: number) % #list + 1]
		end
		s.Behavior, s.LastBehavior, s.BehaviorAt = pick, pick, c.now
		s.BehaviorSide = math.random() < 0.5 and -1 or 1
		local gap = TUNE.IdleEvery[1] + math.random() * (TUNE.IdleEvery[2] - TUNE.IdleEvery[1])
		s.NextBehavior = c.now + BEHAVIORS[pick] + gap
	elseif not calm then
		s.NextBehavior = math.max(s.NextBehavior, c.now + 2)
	end
end

local function update(s, c)
	updateAir(s, c)
	local moving = s.Rel > TUNE.MoveAt and not STILL_ACTIONS[c.action]
	s.MoveW += ((moving and 1 or 0) - s.MoveW) * damp(c.dt, 6)
	local turning = not moving and math.abs(s.Yaw) > 1.1 and s.AirW < 0.5
	s.TurnW += ((turning and 1 or 0) - s.TurnW) * damp(c.dt, 6)
	local running = s.MoveW > 0.5 and s.Gait.Walk < 0.5
	s.Pant = math.clamp(s.Pant + (running and c.dt * 0.2 or -c.dt * 0.07), 0, 1)
	gaitWeights(s, c, false)
	advancePhase(s, c)
	updateLook(s, c)
	idleClock(s, c)
end

---------------------------------------------------------------- 5. POSES
-- uma perna num ciclo: u (0..1) → ângulo (A(+x) = frente) e dobra do joelho (0..1)
local function legCycle(u, duty, amp)
	u %= 1
	if u < duty then
		-- apoio: a pata fica no chão e o corpo passa por cima (perna vai da frente para trás)
		return amp * (1 - 2 * u / duty), 0
	end
	-- voo da pata: volta para a frente com aceleração suave e o joelho dobrado
	local k = (u - duty) / (1 - duty)
	return -amp + 2 * amp * smooth01(k), math.sin(k * math.pi)
end

-- escreve uma perna: com joelho dobra o joelho; sem joelho (robô, modelo antigo) sobe a perna inteira.
-- side (−1..1, opcional): andando de LADO (trava do Ctrl) a perna balança para o lado em vez de para a frente — o passo
-- vai junto com o corpo e a pata não escorrega de lado (2026-10-24)
local function setLeg(s, P, leg, ang, flex, S, side)
	local knee = KNEE_OF[leg]
	local sn = side or 0
	local cs = math.sqrt(math.max(0, 1 - sn * sn))
	if s.Motors[knee] then
		local front = FRONT[leg]
		P[leg] = A((ang + 0.18 * flex) * cs, 0, ang * sn)
		P[knee] = A(FLEX[leg] * flex * (front and 1.15 or 0.85) + (front and 0 or 0.06))
	else
		P[leg] = T(0, flex * 0.14 * S, 0) * A(ang * cs, 0, ang * sn)
	end
end

-- asas: open 0 = dobradas nas costas, 1 = abertas
local function foldWings(P, open)
	for _, side in ipairs({ -1, 1 }) do
		local name = side < 0 and "WingL" or "WingR"
		local closed = 1 - open
		P[name] = A(0, -side * 0.95 * closed, 0) * A(0, 0, -side * 0.3 * closed)
		P[name .. "2"] = A(0, -side * 1.25 * closed, 0) * A(0, 0, -side * 0.25 * closed)
	end
end

-- batida: stroke > 0 = para baixo; a parte de fora atrasa (chicote) e dobra na subida
local function flapWings(P, stroke, outer, fold, sweep)
	for _, side in ipairs({ -1, 1 }) do
		local name = side < 0 and "WingL" or "WingR"
		P[name] = A(0, -side * sweep, 0) * A(0, 0, -side * stroke)
		P[name .. "2"] = A(0, -side * fold, 0) * A(0, 0, -side * outer)
	end
end

-- gira o corpo inteiro (olhar, inclinar) com as PATAS PLANTADAS: cada perna desfaz a inclinação do corpo e
-- se inclina para o lado contrário do giro (quando o corpo torce, o ombro anda e a pata fica onde estava).
-- plant: 0 = as pernas giram junto, 1 = patas plantadas
local function bodyTurn(s, P, pitch, yaw, roll, plant)
	if math.abs(pitch) + math.abs(yaw) + math.abs(roll) < 1e-4 then
		return
	end
	P.Body = (P.Body or IDENT) * A(pitch, yaw, roll)
	if plant <= 0.001 then
		return
	end
	local L = math.max(0.5, s.LegLen)
	for _, leg in ipairs(LEGS) do
		local z = s.LegZ and s.LegZ[leg] or (FRONT[leg] and -0.6 or 0.6) * s.S
		local slide = math.clamp(-z * yaw / L, -0.6, 0.6)
		pre(P, leg, A(-pitch * plant, -yaw * 0.5 * plant, (slide - roll) * plant))
	end
end

local function sitPose(s, c)
	local L = s.LegLen
	local Q = {
		Body = T(0, -0.3 * L, 0.2 * L) * A(0.55),
		LegBL = A(-1.2),
		LegBR = A(-1.2),
		KneeBL = A(1.5),
		KneeBR = A(1.5),
		LegFL = A(-0.55),
		LegFR = A(-0.55),
		TailX = 0.9, -- rabo no chão, varrendo
		TailY = math.sin(c.t * (5 + 5 * s.Excite)) * (0.4 + 0.25 * s.Excite),
	}
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(-0.45 + s.LookPitch, s.LookYaw, s.LookTilt)
	end
	-- sentado também acompanha a setinha com o peito
	bodyTurn(s, Q, 0, s.Twist * 0.7, -s.Twist * 0.1, 0.5)
	return Q
end

local function liePose(s, c)
	local L, sleep = s.LegLen, s.SleepW
	local br = math.sin(c.t * (2 - sleep))
	local awake = 1 - sleep
	local Q = {
		Body = T(0, -0.8 * L + br * 0.015 * c.S, 0) * A(br * 0.01),
		LegFL = A(1.45),
		LegFR = A(1.45),
		KneeFL = IDENT,
		KneeFR = IDENT,
		LegBL = A(1.25, 0, -0.35),
		LegBR = A(1.25, 0, 0.35),
		KneeBL = A(1.5),
		KneeBR = A(1.5),
		TailX = 0.6, -- enrolado em volta do corpo
		TailY = 0.9 + br * 0.03,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(0.05 - 0.5 * sleep + s.LookPitch * awake, s.LookYaw * awake, s.LookTilt * awake)
		Q["Jaw" .. i] = IDENT
	end
	return Q
end

local function behaviorPose(s, P, c)
	local b = s.Behavior
	if not b then
		return
	end
	local bt = c.now - s.BehaviorAt
	local dur = BEHAVIORS[b]
	local t, S, side = c.t, c.S, s.BehaviorSide or 1
	local Q = {}
	if b == "sniff" then -- fareja o chão
		local nose = math.sin(t * 15) * 0.035
		Q.Body = T(0, -0.06 * S, -0.05 * S) * A(-0.1)
		for i = 1, 3 do
			Q["Neck" .. i] = A(-0.7 + nose, math.sin(bt * 1.7 + i) * 0.35, 0)
			Q["Jaw" .. i] = IDENT
		end
		Q.LegFL, Q.LegFR = A(0.05), A(0.05)
		Q.KneeFL, Q.KneeFR = A(-0.15), A(-0.15)
		Q.TailX, Q.TailY = -0.1, math.sin(t * 4) * 0.25
	elseif b == "scratch" then -- senta e coça a orelha com a pata de trás
		local leg = side < 0 and "LegBL" or "LegBR"
		local other = side < 0 and "LegBR" or "LegBL"
		local fast = math.sin(t * 22)
		Q.Body = T(0, -0.22 * s.LegLen, 0.12 * s.LegLen) * A(0.35, 0, side * 0.12)
		Q[leg] = A(1.0 + fast * 0.28, 0, side * 0.15)
		Q[KNEE_OF[leg]] = A(0.9 + fast * 0.2)
		Q[other] = A(-0.85)
		Q[KNEE_OF[other]] = A(1.1)
		Q.LegFL, Q.LegFR = A(-0.35), A(-0.35)
		for i = 1, 3 do
			Q["Neck" .. i] = A(-0.1, side * 0.35, side * 0.45 + fast * 0.03)
			Q["Jaw" .. i] = A(-0.08)
		end
		Q.TailX, Q.TailY = 0.3, 0
		c.ear = "droop"
	elseif b == "shake" then -- chacoalha o corpo inteiro
		local decay = math.max(0, 1 - bt / dur)
		local w = math.sin(t * 30) * decay
		Q.Body = T(0, -0.03 * S, 0) * A(0, w * 0.12, w * 0.32)
		for i = 1, 3 do
			Q["Neck" .. i] = A(0.05, -w * 0.5, -w * 0.4)
			Q["Jaw" .. i] = A(-0.15 * decay)
		end
		Q.TailX, Q.TailY = 0, -w * 0.8
		s.EarKick += math.abs(w) * 0.6
	elseif b == "yawn" then -- boceja
		local open = smooth01(bt / 0.8) * smooth01((dur - bt) / 0.6)
		Q.Body = A(0.06 * open)
		for i = 1, 3 do
			Q["Neck" .. i] = A(0.45 * open, 0, 0.12 * open * (i % 2 == 0 and -1 or 1))
			Q["Jaw" .. i] = A(-1.0 * open)
		end
		Q.LegFL, Q.LegFR = A(0.1 * open), A(0.1 * open)
		c.ear = "back"
	elseif b == "bow" then -- reverência de brincadeira: frente no chão, bumbum para cima, rabo abanando
		Q.Body = T(0, -0.12 * S, -0.05 * S) * A(-0.38)
		Q.LegFL, Q.LegFR = A(1.1), A(1.1)
		Q.KneeFL, Q.KneeFR = A(-0.1), A(-0.1)
		Q.LegBL, Q.LegBR = A(0.38), A(0.38)
		for i = 1, 3 do
			Q["Neck" .. i] = A(0.55, 0, math.sin(t * 2) * 0.1)
			Q["Jaw" .. i] = A(-0.25)
		end
		Q.TailX, Q.TailY = -0.5, math.sin(t * 9) * 0.5
	elseif b == "lookback" then -- olha para trás por cima do ombro
		local k = smooth01(bt / 0.4)
		Q.Body = A(0, side * 0.12 * k, side * 0.05 * k)
		for i = 1, 3 do
			Q["Neck" .. i] = A(0.05, side * 1.25 * k, side * 0.15 * k)
		end
		Q.TailX, Q.TailY = 0.05, side * 0.4 + math.sin(t * 6) * 0.2
	elseif b == "paw" then -- levanta uma pata da frente, curioso, cabeça de lado
		local leg = side < 0 and "LegFL" or "LegFR"
		Q[leg] = A(0.55)
		Q[KNEE_OF[leg]] = A(-1.1)
		Q.Body = A(0.03, 0, -SIDE[leg] * 0.04)
		for i = 1, 3 do
			Q["Neck" .. i] = A(0.08, 0, -SIDE[leg] * 0.35)
		end
	elseif b == "hop" then -- pulinhos de alegria (telas 3D)
		local h = math.abs(math.sin(bt * 6))
		Q.Body = T(0, h * 0.35 * S, 0) * A(0.1 * h)
		Q.LegFL, Q.LegFR = A(0.4 * h), A(0.4 * h)
		Q.KneeFL, Q.KneeFR = A(-0.7 * h), A(-0.7 * h)
		Q.LegBL, Q.LegBR = A(-0.3 * h), A(-0.3 * h)
		Q.KneeBL, Q.KneeBR = A(0.6 * h), A(0.6 * h)
		Q.TailY = math.sin(t * 14) * 0.6
	elseif b == "chase" then -- corre atrás do próprio rabo: uma volta inteira no lugar, olhando para trás
		for _, leg in ipairs(LEGS) do
			local a, f = legCycle(bt * 2.8 + PHASE.Trot[leg], 0.5, 0.3)
			setLeg(s, Q, leg, a, f, S)
		end
		Q.Body = T(0, -0.04 * S, 0) * A(-0.05, 0, side * 0.12)
		for i = 1, 3 do
			Q["Neck" .. i] = A(-0.12, side * 1.15, side * 0.2)
			Q["Jaw" .. i] = A(-0.4)
		end
		Q.TailX, Q.TailY = 0.05, side * 0.9 -- o rabo "foge"
		c.ear = "up"
	end
	blend(P, Q, envelope(bt, dur, 0.3, 0.35))
	if b == "chase" then
		-- o giro vai por cima (multiplicado, não misturado: misturar 360° daria zero) e sem suavizar o corpo
		P.Body *= A(0, side * TAU * smooth01((bt - 0.25) / (dur - 0.55)), 0)
		c.fast.Body = true
	end
end

local function idlePose(s, P, c)
	local t, S = c.t, c.S
	local sleep, hurt = s.SleepW, s.Health < TUNE.LowHealth
	local ex = s.Excite -- 0..1: a setinha passando rápido perto (cachorro vendo laser)
	local rate = 2.1 + 3.5 * math.max(s.Pant, ex * 0.6) - 1.2 * sleep
	local br = math.sin(t * rate)
	-- animado: pulinhos no lugar e o bumbum rebola junto com o rabo
	local hop = math.abs(math.sin(t * 8)) * math.max(0, ex - 0.3) * 0.12 * S
	local wiggle = math.sin(t * (6.5 + 7 * ex)) * 0.05 * ex
	P.Body = T(0, br * (0.02 + 0.015 * s.Pant) * S + hop, 0) * A(br * 0.012, wiggle, math.sin(t * 0.55) * 0.012)
	-- troca o peso de uma pata para outra (o corpo vai junto para o lado)
	local shift = math.sin(t * 0.45) * 0.045
	P.Body *= A(0, 0, shift)
	P.LegFL, P.LegFR = A(shift * 0.5, 0, -shift), A(-shift * 0.5, 0, -shift)
	P.LegBL, P.LegBR = A(-shift * 0.4, 0, -shift), A(shift * 0.4, 0, -shift)
	P.KneeBL, P.KneeBR = A(0.06), A(0.06)
	for i = 1, 3 do
		-- com várias cabeças, cada uma tem vontade própria
		local own = c.heads > 1 and (math.sin(t * 0.37 + i * 2.1) * 0.25 + (i - 2) * 0.18) or 0
		P["Neck" .. i] = HEAD(s.LookPitch + br * 0.02 - (hurt and 0.12 or 0), s.LookYaw + own, s.LookTilt)
		-- ofegante depois de correr (ou feliz/animado): língua para fora
		P["Jaw" .. i] = A(-(0.08 + 0.14 * math.abs(math.sin(t * 9 + i))) * math.max(s.Pant, ex * 0.8))
	end
	-- rabo: abana feliz (animado: rápido e alto); cansado/ferido abana devagar e baixo; dormindo fica parado
	P.TailX = 0.05 + (hurt and 0.45 or 0) - 0.3 * ex
	P.TailY = math.sin(t * (hurt and 2.5 or (6.5 + 7 * ex))) * (hurt and 0.15 or (0.38 + 0.3 * ex)) * (1 - sleep)
	foldWings(P, 0)
	-- olhar: o peito torce para o lado da setinha, inclina um tiquinho para lá e empina ao olhar para cima
	local awake = 1 - sleep
	bodyTurn(s, P, math.clamp(s.LookPitch * 0.12, -0.08, 0.1) * awake, s.Twist * awake, -s.Twist * 0.12 * awake, 1)
	if ex > 0.4 then
		c.ear = "up" -- animado: orelhas em pé
	end
	-- virando no lugar: passinhos
	if s.TurnW > 0.01 then
		local Q = {}
		for _, leg in ipairs(LEGS) do
			local a, f = legCycle(s.Phase + PHASE.Trot[leg], 0.5, 0.12)
			setLeg(s, Q, leg, a, f * 0.7, S)
		end
		blend(P, Q, s.TurnW)
	end
	behaviorPose(s, P, c)
	if s.SitW > 0.01 then
		blend(P, sitPose(s, c), s.SitW)
	end
	if s.LieW > 0.01 then
		blend(P, liePose(s, c), s.LieW)
	end
end

local function footsteps(s, c)
	if s.UseC0 or c.snap or not s.Root then
		return
	end
	local g = s.Gait
	local gait = (g.Gallop > g.Trot and g.Gallop > g.Walk) and "Gallop" or (g.Trot > g.Walk and "Trot" or "Walk")
	for _, leg in ipairs(LEGS) do
		local u = (s.Phase + PHASE[gait][leg]) % 1
		local last = s.LastStep[leg]
		if last and u < last and not s.Back and s.MoveW > 0.6 then -- voltou ao começo do ciclo = a pata encostou
			local m = s.Motors[leg]
			local foot = m and m.Part1 and m.Part1.Position or s.Root.Position
			local y = s.Root.Position.Y - s.LegLen - s.Root.Size.Y / 2
			dust(Vector3.new(foot.X, y, foot.Z), 0.18 * math.sqrt(c.S))
		end
		s.LastStep[leg] = u
	end
end

local function movePose(s, P, c)
	local g, S, t = s.Gait, c.S, c.t
	local u = s.Phase
	local hurt = s.Health < TUNE.LowHealth
	for _, leg in ipairs(LEGS) do
		local ang, flex = 0, 0
		for gait, w in pairs(g) do
			if w > 0.001 then
				local amp, duty = gaitShape(s, gait, s.Stretch)
				local a, f = legCycle(u + PHASE[gait][leg], duty, amp)
				if gait == "Gallop" then
					a += FRONT[leg] and 0.1 or -0.08 -- dianteiras esticam à frente, traseiras empurram atrás
				end
				ang += a * w
				flex += f * w
			end
		end
		-- mancando: a pata machucada mal encosta e sobe mais
		if hurt and leg == s.LimpLeg then
			ang *= 0.55
			flex = math.min(1, flex * 1.3 + 0.15)
		end
		-- (de ré o ciclo anda ao contrário: o lado também inverte)
		setLeg(s, P, leg, ang, flex, S, math.clamp(s.Side, -1, 1) * (s.Back and -1 or 1))
	end
	-- corpo: sobe e desce com as patadas; o quadril e os ombros balançam de lado no passo; no trote quica;
	-- no galope a coluna "dobra e estica" (frente sobe quando as traseiras empurram)
	local W, Tr, G = g.Walk, g.Trot, g.Gallop
	local a1 = u * TAU
	local bob = (math.cos(a1 * 2) * (0.03 * W + 0.06 * Tr) + math.sin(a1) * 0.17 * G * (1 + 0.5 * (s.Stretch - 1))) * S
	local pitch = -0.03 - 0.02 * G + math.sin(a1 + 0.8) * 0.14 * G + math.cos(a1 * 2) * 0.02 * Tr
	local roll = math.sin(a1) * (0.05 * W + 0.025 * Tr)
	local sway = math.sin(a1) * 0.05 * W + math.sin(a1 * 2) * 0.012 * Tr
	if hurt then -- mancando: o corpo afunda quando a pata machucada deveria apoiar
		local lu = (u + PHASE.Trot[s.LimpLeg]) % 1
		bob -= (lu < 0.5 and math.sin(lu / 0.5 * math.pi) or 0) * 0.06 * S
	end
	if c.big then -- chefão: passos pesados, o corpo balança mais
		bob *= 1.35
		roll *= 1.3
	end
	-- curva: inclina para dentro, a cabeça vai na frente, o rabo vai para fora
	local turn = math.clamp(-s.Yaw * 0.085 * math.min(1, s.Rel / 2), -0.32, 0.32)
	P.Body = T(0, bob, 0) * A(pitch, sway, roll + turn + s.Side * 0.1)
	-- a cabeça fica firme (balança menos que o corpo) e acompanha a setinha
	local nod = math.cos(a1 * 2 + 0.5) * 0.06 * W + math.cos(a1 * 2) * 0.025 * Tr - (pitch + 0.04) * 0.8 * G
	local lead = math.clamp(s.Yaw * 0.14, -0.5, 0.5)
	for i = 1, 3 do
		P["Neck" .. i] = HEAD(-0.08 + nod + s.LookPitch * 0.6 - (hurt and 0.12 or 0), lead + s.LookYaw * 0.8 - sway * 0.6, -(roll + turn) * 0.6)
		P["Jaw" .. i] = A(-(0.05 + 0.12 * G) - 0.1 * s.Pant)
	end
	P.TailX = 0.05 - 0.4 * G + math.sin(a1) * 0.12 * G + (hurt and 0.4 or 0)
	P.TailY = math.sin(a1) * 0.3 * W + math.sin(t * 9) * 0.18 * Tr - s.Yaw * 0.08 - sway * 1.5
	foldWings(P, 0.15 * G) -- no galope as asas abrem um pouco (equilíbrio)
	-- olhando para o lado enquanto anda: o peito vira um pouco junto
	bodyTurn(s, P, 0, s.Twist * 0.5, 0, 0.6)
	if c.big then
		footsteps(s, c)
	end
end

-- freada (patas da frente travam, corpo vai para trás) e arrancada (abaixa a frente e empurra)
local function brakePose(s, P, c)
	if s.Speed < 0.3 * s.LegLen then
		return
	end
	local acc = s.Accel / math.max(1, s.LegLen)
	if acc < -2 then
		local k = math.clamp((-acc - 2) / 8, 0, 1)
		P.Body *= T(0, -0.08 * c.S * k, 0) * A(0.12 * k)
		mul(P, "LegFL", A(0.35 * k))
		mul(P, "LegFR", A(0.35 * k))
		mul(P, "LegBL", A(0.25 * k))
		mul(P, "LegBR", A(0.25 * k))
	elseif acc > 2 then
		local k = math.clamp((acc - 2) / 8, 0, 1)
		P.Body *= A(-0.1 * k)
		for i = 1, 3 do
			mul(P, "Neck" .. i, A(-0.1 * k))
		end
	end
end

-- nado: corpo baixo, nariz para fora d'água, patas remando em círculo, rabo de leme
local function swimPose(s, P, c)
	local t, S = c.t, c.S
	local w = t * 7
	P.Body = T(0, -0.25 * S, 0) * A(0.12, 0, math.sin(w * 0.5) * 0.04)
	for _, leg in ipairs(LEGS) do
		local off = (SIDE[leg] > 0 and math.pi or 0) + (FRONT[leg] and 0 or math.pi * 0.5)
		if FRONT[leg] then
			setLeg(s, P, leg, 0.25 + math.sin(w + off) * 0.55, math.max(0, math.cos(w + off)) * 0.9, S)
		else
			setLeg(s, P, leg, -0.2 + math.sin(w + off) * 0.3, math.max(0, math.cos(w + off)) * 0.6, S)
		end
	end
	for i = 1, 3 do
		P["Neck" .. i] = HEAD(0.35 + math.sin(w) * 0.04 + s.LookPitch * 0.3, s.LookYaw * 0.6, 0)
		P["Jaw" .. i] = A(-0.06)
	end
	P.TailX, P.TailY = 0, math.sin(t * 3) * 0.35 - s.Yaw * 0.15 -- rabo de leme
	c.ear = "back"
end

-- no ar: subindo estica (salto), caindo busca o chão com as patas da frente
local function airPose(s, P, c)
	local t, S = c.t, c.S
	local rise = math.clamp(s.VelY / (14 * math.sqrt(S)), -1, 1)
	local k = (rise + 1) / 2 -- 1 subindo, 0 caindo
	P.Body = A(math.clamp(s.VelY * 0.015 / math.sqrt(S), -0.3, 0.3))
	local flail = (c.now - s.AirSince > 0.9) and math.sin(t * 14) * 0.15 or 0 -- queda longa: patas agitadas
	for _, leg in ipairs(LEGS) do
		local f = SIDE[leg] * flail
		if FRONT[leg] then
			setLeg(s, P, leg, 0.35 + 0.55 * k + f, 0.2 + 0.7 * k, S)
		else
			setLeg(s, P, leg, 0.3 - 1.05 * k - f, 0.55 - 0.35 * k, S)
		end
	end
	for i = 1, 3 do
		P["Neck" .. i] = A(0.18 * k - 0.08)
		P["Jaw" .. i] = A(-0.15)
	end
	P.TailX, P.TailY = 0.1 - 0.4 * k, math.sin(t * 10) * 0.2
	foldWings(P, 0.35) -- asas abrem um pouco para equilibrar
end

-- impulso do pulo: as traseiras empurram
local function takeoffPose(s, P, c)
	local k = pulse(c.now - s.TakeoffAt, 0.22)
	if k <= 0 then
		return
	end
	P.Body *= A(0.2 * k)
	mul(P, "LegBL", A(-0.6 * k))
	mul(P, "LegBR", A(-0.6 * k))
	mul(P, "LegFL", A(0.4 * k))
	mul(P, "LegFR", A(0.4 * k))
end

-- pouso: amortece nos joelhos e volta com um quique (mola amortecida)
local function landPose(s, P, c)
	local lt = c.now - s.LandAt
	if lt > 0.7 then
		return
	end
	local comp = s.LandPower * math.exp(-lt * 7) * math.cos(lt * 11)
	local down = math.max(comp, -0.3)
	P.Body = T(0, -0.42 * c.S * down, 0) * A(-0.12 * down) * P.Body
	mul(P, "LegFL", A(-0.15 * down))
	mul(P, "LegFR", A(-0.15 * down))
	mul(P, "LegBL", A(0.3 * down))
	mul(P, "LegBR", A(0.3 * down))
	mul(P, "KneeFL", A(-0.5 * down))
	mul(P, "KneeFR", A(-0.5 * down))
	mul(P, "KneeBL", A(0.6 * down))
	mul(P, "KneeBR", A(0.6 * down))
	for i = 1, 3 do
		mul(P, "Neck" .. i, A(-0.25 * down))
	end
end

-- cachorro que sempre flutua (fantasma): balança no ar com as patas soltas
local function floaterPose(s, P, c)
	local t, S = c.t, c.S
	P.Body = P.Body * T(0, (0.15 + math.sin(t * 1.6) * 0.25) * S, 0)
	local Q = {}
	for i, leg in ipairs(LEGS) do
		setLeg(s, Q, leg, (FRONT[leg] and -0.25 or 0.25) + math.sin(t * 1.6 + i) * 0.08, 0.3, S)
	end
	blend(P, Q, 1 - s.MoveW * 0.6)
	flapWings(P, math.sin(t * 2.8) * 0.3, math.sin(t * 2.8 - 0.7) * 0.25, 0.2, 0.2)
end

-- fúria (Titan): tremendo, cabeça baixa, rosnando, rabo duro para cima
local function ragePose(s, P, c)
	local t = c.t
	local tremble = math.sin(t * 37) * 0.012
	P.Body *= A(tremble - 0.05, 0, tremble)
	for i = 1, 3 do
		mul(P, "Neck" .. i, A(-0.22 + math.sin(t * 3) * 0.04, math.sin(t * 23 + i) * 0.03, 0))
		P["Jaw" .. i] = A(-0.38 + math.sin(t * 7 + i) * 0.1)
	end
	P.TailX, P.TailY = -0.55, math.sin(t * 4) * 0.1
	c.ear = "back"
end

---------------------------------------------------------------- 6. AÇÕES (atributo "Action" do servidor)
-- Cada função recebe a pose já pronta (locomoção) e mistura a pose da ação por cima.
-- Pode devolver um valor de transparência (0 = normal, 1 = invisível).
local ACTIONS = {}

-- agachado, rebolando o quadril antes do bote (Pounce)
function ACTIONS.Crouch(s, P, c)
	local t, S = c.t, c.S
	local tr = math.sin(t * 30) * 0.008
	local wiggle = math.sin(t * 9) * 0.06
	local Q = {
		Body = T(0, -0.42 * s.LegLen, 0.05 * S) * A(-0.12 + tr, wiggle * 0.3, 0),
		LegFL = A(0.35),
		LegFR = A(0.35),
		KneeFL = A(-0.55),
		KneeFR = A(-0.55),
		LegBL = A(-0.15 + wiggle),
		LegBR = A(-0.15 - wiggle),
		KneeBL = A(1.0),
		KneeBR = A(1.0),
		TailX = -0.05,
		TailY = math.sin(t * 14) * 0.18,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(-0.15 + s.LookPitch * 0.3, s.LookYaw * 0.4, 0)
		Q["Jaw" .. i] = A(-0.12)
	end
	blend(P, Q, smooth01(c.at / 0.25))
	c.ear = "back"
end

-- uivo: senta nas patas de trás e uiva em frases (abre, segura com vibrato, respira)
function ACTIONS.Howl(s, P, c)
	local t, L = c.t, s.LegLen
	local phrase = c.at % 2.4
	local open = smooth01(phrase / 0.35) * smooth01((2.1 - phrase) / 0.3)
	local Q = {
		Body = T(0, -0.22 * L, 0.15 * L) * A(0.38),
		LegBL = A(-0.95),
		LegBR = A(-0.95),
		KneeBL = A(1.25),
		KneeBR = A(1.25),
		LegFL = A(-0.38),
		LegFR = A(-0.38),
		TailX = 0.5,
		TailY = math.sin(t * 2) * 0.1,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = A(0.85 + 0.15 * open + math.sin(t * 1.3 + i) * 0.04, (i - 2) * 0.25 * (c.heads > 1 and 1 or 0), 0)
		Q["Jaw" .. i] = A(-(0.12 + 0.5 * open) - math.sin(t * 18 + i) * 0.04 * open)
	end
	blend(P, Q, smooth01(c.at / 0.45))
	c.ear = "back"
end

-- rugido: puxa a cabeça para trás e solta tudo para a frente, tremendo
function ACTIONS.Roar(s, P, c)
	local at, t, S = c.at, c.t, c.S
	local wind = smooth01(at / 0.18)
	local blast = smooth01((at - 0.18) / 0.12)
	local shake = math.sin(t * 42) * 0.03 * blast
	local Q = {
		Body = T(0, -0.12 * S, (0.12 * wind - 0.32 * blast) * S) * A(0.06 * wind - 0.12 * blast + shake, 0, shake),
		LegFL = A(0.35 * blast),
		LegFR = A(0.35 * blast),
		KneeFL = A(-0.1),
		KneeFR = A(-0.1),
		LegBL = A(-0.3 * blast),
		LegBR = A(-0.3 * blast),
		KneeBL = A(0.3),
		KneeBR = A(0.3),
		TailX = -0.55 * blast,
		TailY = shake * 3,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = A(0.3 * wind - 0.45 * blast + shake, math.sin(t * 31 + i) * 0.07 * blast, 0)
		Q["Jaw" .. i] = A(-0.25 * wind - 0.65 * blast - math.sin(t * 20) * 0.08 * blast)
	end
	blend(P, Q, 1)
	c.ear = "back"
end

-- empina nas patas de trás e dá socos no ar com as da frente
function ACTIONS.Rear(s, P, c)
	local t, L = c.t, s.LegLen
	local k = smooth01(c.at / 0.4)
	local theta = 1.0 * k
	local box = math.sin(t * 12)
	local Q = {
		Body = T(0, L * 0.9 * math.sin(theta), 0.5 * L * k) * A(theta),
		LegBL = A(-theta + 0.1),
		LegBR = A(-theta + 0.1),
		KneeBL = A(0.35),
		KneeBR = A(0.35),
		LegFL = A(-0.2 + box * 0.45),
		LegFR = A(-0.2 - box * 0.45),
		KneeFL = A(-0.9 - math.max(0, box) * 0.4),
		KneeFR = A(-0.9 - math.max(0, -box) * 0.4),
		TailX = 0.25,
		TailY = math.sin(t * 7) * 0.3,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(-0.55 * k, s.LookYaw * 0.3, 0)
		Q["Jaw" .. i] = A(-0.35 - math.max(0, box) * 0.2)
	end
	blend(P, Q, 1)
	c.ear = "up"
end

-- pancada: levanta a frente e bate as patas no chão (poeira + tremor)
function ACTIONS.Slam(s, P, c)
	local at, t, S = c.at, c.t, c.S
	local up = smooth01(at / 0.16) * (1 - smooth01((at - 0.16) / 0.08))
	local hit = smooth01((at - 0.18) / 0.06)
	local ring = math.exp(-math.max(0, at - 0.24) * 9) * hit
	local shake = math.sin(t * 50) * 0.05 * ring
	local Q = {
		Body = T(0, (0.35 * up - 0.3 * hit) * S, -0.15 * S * hit) * A(0.45 * up - 0.3 * hit + shake, 0, shake),
		LegFL = A(-0.4 * up + 0.75 * hit),
		LegFR = A(-0.4 * up + 0.75 * hit),
		KneeFL = A(-1.0 * up),
		KneeFR = A(-1.0 * up),
		LegBL = A(-0.4 * up + 0.2 * hit),
		LegBR = A(-0.4 * up + 0.2 * hit),
		KneeBL = A(0.5 * up + 0.4 * hit),
		KneeBR = A(0.5 * up + 0.4 * hit),
		TailX = -0.4,
		TailY = shake * 4,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = A(0.25 * up - 0.3 * hit)
		Q["Jaw" .. i] = A(-0.3 * up - 0.55 * hit)
	end
	blend(P, Q, 1)
	if at > 0.2 and not s.ActionFx and not c.snap and s.Root then
		s.ActionFx = true
		dust(s.Root.Position + s.Root.CFrame.LookVector * s.LegLen - Vector3.new(0, s.LegLen, 0), 0.8 * math.sqrt(S))
	end
end

-- boca escancarada (sopro/raio): patas firmes, cabeça varrendo devagar
function ACTIONS.Open(s, P, c)
	local t, S = c.t, c.S
	local Q = {
		Body = T(0, -0.05 * S, 0) * A(-0.06),
		LegFL = A(0.2),
		LegFR = A(0.2),
		LegBL = A(-0.15),
		LegBR = A(-0.15),
		TailX = -0.2,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = A(0.1 + math.sin(t * 2 + i) * 0.04, math.sin(t * 1.5 + i) * 0.1, 0)
		Q["Jaw" .. i] = A(-0.9 + math.sin(t * 14) * 0.05)
	end
	blend(P, Q, smooth01(c.at / 0.2))
end

-- comendo: cabeça na tigela mastigando; de vez em quando levanta mastigando e abana o rabo
function ACTIONS.Eat(s, P, c)
	local t, L = c.t, s.LegLen
	local cycle = c.at % 3.2
	local lift = smooth01((cycle - 2.3) / 0.25) * smooth01((3.2 - cycle) / 0.25)
	local chew = math.abs(math.sin(t * 10))
	local Q = {
		Body = T(0, -0.1 * L, 0) * A(-0.14),
		LegFL = A(0.12, 0, 0.06),
		LegFR = A(0.12, 0, -0.06),
		KneeFL = A(-0.12),
		KneeFR = A(-0.12),
		LegBL = A(-0.05),
		LegBR = A(-0.05),
		TailX = 0,
		TailY = math.sin(t * 12) * 0.5,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = A(-0.85 + lift * 0.75 + chew * 0.04, math.sin(t * 1.1 + i) * 0.08, 0)
		Q["Jaw" .. i] = A(-0.3 * chew)
	end
	blend(P, Q, smooth01(c.at / 0.3))
end

-- VOO = AVIÃO. Quem voa de verdade é o DogControl (vai sempre para a frente, inclina o corpo INTEIRO nas
-- curvas, sobe e mergulha). Aqui só a pose por cima disso:
--   rápido   = asas abertas RETAS planando (uma batida de vez em quando para parecer vivo), patas recolhidas
--              como trem de pouso, rabo reto de leme, orelhas para trás e boca aberta no vento;
--   devagar  = quase em pé no ar, batendo as asas forte, patas penduradas remando;
--   subindo, acelerando ou decolando = batidas fortes; mergulho rápido = asas fechadas para trás (falcão).
-- A cabeça fica NIVELADA quando o corpo inclina na curva (como pássaro) e olha para a setinha.
function ACTIONS.Fly(s, P, c)
	local t, S = c.t, c.S
	local root = s.Root
	local cruise = math.max(8, (s.Model:GetAttribute("BaseSpeed") or 16) * TUNE.FlyMult)
	local v = math.sqrt(s.Speed * s.Speed + s.VelY * s.VelY) / cruise -- 1 = velocidade de cruzeiro
	local glide = smooth01((v - 0.4) / 0.45)
	local hover = 1 - smooth01(v / 0.4)
	local climb = math.clamp(s.VelY / (cruise * 0.5), -1, 1)
	local dive = smooth01((-climb - 0.35) / 0.5) * glide
	local boost = 1 - smooth01(c.at / 0.8) -- decolagem
	local push = math.clamp(s.Accel / cruise * 1.5, 0, 1) -- acelerando
	-- planando: de vez em quando uma batida
	if not c.snap and c.now > (s.NextFlap or 0) then
		s.NextFlap = c.now + 1.8 + math.random() * 1.8
		s.FlapAt = c.now
	end
	local burst = c.snap and 0 or pulse(c.now - (s.FlapAt or -10), 1.1)
	local beat = math.clamp(math.max(hover, boost, climb * 0.85, push * 0.8, burst * 0.7) * (1 - dive), 0, 1)
	local rate = (7 + 8 * beat) / math.max(1, S ^ 0.35)
	if c.snap then
		s.FlapPhase = c.at * rate
	else
		s.FlapPhase = (s.FlapPhase or 0) + c.dt * rate
	end
	local w = s.FlapPhase
	local amp = 0.12 + 0.78 * beat
	local stroke = (math.sin(w) + 0.25 * math.sin(2 * w)) * amp -- > 0 = asa descendo (rápida para baixo)
	local flat = s.WingFlat or 0.9
	local bank = root and math.asin(math.clamp(root.CFrame.RightVector.Y, -1, 1)) or 0 -- inclinação da curva
	local turn = math.clamp(s.Yaw, -3, 3) -- > 0 = virando para a esquerda
	local Q = {
		-- o corpo sobe quando a asa desce; devagar fica mais em pé; nas curvas o quadril vira para dentro
		Body = T(0, stroke * 0.08 * S, 0) * A(0.55 * hover + 0.12 * boost - 0.05 * glide - 0.04 * stroke, turn * 0.05, 0),
		TailX = 0.45 * glide + 0.1 * hover, -- reto para trás (leme)
		TailY = -turn * 0.22 + math.sin(t * 3.1) * 0.08 * (1 - glide * 0.6),
	}
	local paddle = math.sin(t * 4) * 0.12 * hover
	for _, leg in ipairs(LEGS) do
		local side = SIDE[leg]
		if FRONT[leg] then
			-- dianteiras dobradas para trás embaixo do peito (rápido) ou penduradas (devagar)
			setLeg(s, Q, leg, (-0.85 - 0.2 * dive) * glide + (0.15 + paddle * side) * (1 - glide), 0.95 * glide + 0.45 * (1 - glide), S)
		else
			-- traseiras esticadas para trás como avião a jato
			setLeg(s, Q, leg, (-1.25 - 0.15 * dive) * glide + (-0.25 - paddle * side) * (1 - glide), 0.12 * glide + 0.5 * (1 - glide), S)
		end
	end
	-- asas: abrem RETAS (WingFlat = quanto descer para ficar na horizontal, medido no modelo) + a batida.
	-- A ponta atrasa (chicote) e dobra na subida; rápido vão um pouco para trás; no mergulho fecham para trás.
	-- Na curva a asa de dentro sobe um pouco e a de fora desce.
	local sweep = 0.06 + 0.22 * glide * math.min(v, 1.4) + 0.85 * dive
	local fold = math.max(0, -math.cos(w)) * 0.55 * beat + 0.6 * dive
	for _, side in ipairs({ -1, 1 }) do
		local name = side < 0 and "WingL" or "WingR"
		local down = flat - 0.08 + stroke + side * turn * 0.05
		Q[name] = A(0, -side * sweep, 0) * A(0, 0, -side * down)
		Q[name .. "2"] = A(0, -side * fold, 0) * A(0, 0, -side * (0.04 - 0.12 * glide + math.sin(w - 0.8) * 0.4 * beat))
	end
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(0.08 * glide - 0.5 * hover + s.LookPitch * 0.6 - 0.03 * stroke, s.LookYaw * 0.8 + turn * 0.08, -bank * 0.55)
		Q["Jaw" .. i] = A(-0.08 - 0.22 * glide * math.min(v, 1.3)) -- boca aberta no vento
	end
	blend(P, Q, smooth01(c.at / 0.25))
	c.ear = "back"
	c.wind = glide * math.min(v, 1.5)
end

-- levitando (magia): sobe e desce devagar, patas soltas balançando, asas tremulando
function ACTIONS.Float(s, P, c)
	local t, S = c.t, c.S
	local Q = {
		Body = T(0, (0.6 + math.sin(t * 2.4) * 0.18) * S, 0) * A(0.08 + math.sin(t * 1.2) * 0.04, math.sin(t * 0.7) * 0.08, math.sin(t * 1.3) * 0.05),
		TailX = 0.25,
		TailY = math.sin(t * 1.6) * 0.4,
	}
	for i, leg in ipairs(LEGS) do
		setLeg(s, Q, leg, (FRONT[leg] and -0.25 or 0.25) + math.sin(t * 1.8 + i) * 0.12, 0.35 + math.sin(t * 1.8 + i) * 0.1, S)
	end
	flapWings(Q, math.sin(t * 5) * 0.4, math.sin(t * 5 - 0.7) * 0.35, 0.15, 0.1)
	for i = 1, 3 do
		Q["Neck" .. i] = A(0.3 + math.sin(t * 2.4) * 0.05)
		Q["Jaw" .. i] = A(-0.15)
	end
	blend(P, Q, smooth01(c.at / 0.4))
	c.ear = "up"
end

-- arrancada: corpo baixo e esticado, orelhas coladas (as patas já galopam pela velocidade)
-- 💨 bote da DASH (2026-10, pedido do dono: a dash vai para o analógico, mais rápida): o corpo estica para a frente —
-- patas da frente esticadas à frente, traseiras empurrando para trás, cabeça baixa à frente, orelhas coladas e rabo
-- reto. k = força (0..1)
local function pounce(P, k, S)
	if k <= 0 then
		return
	end
	P.Body = (P.Body or IDENT) * T(0, -0.12 * S * k, -0.12 * S * k) * A(-0.1 * k)
	-- mesmo sentido do Leap: frente + = estica à frente, trás − = estica para trás; joelho = FLEX (dobra de leve)
	mul(P, "LegFL", A(1.05 * k))
	mul(P, "LegFR", A(0.85 * k))
	mul(P, "KneeFL", A(-0.12 * k))
	mul(P, "KneeFR", A(-0.2 * k))
	mul(P, "LegBL", A(-0.95 * k))
	mul(P, "LegBR", A(-0.8 * k))
	mul(P, "KneeBL", A(0.12 * k))
	mul(P, "KneeBR", A(0.2 * k))
	for i = 1, 3 do
		mul(P, "Neck" .. i, A(0.06 * k))
	end
	P.TailX = (P.TailX or 0) + 0.45 * k
end

function ACTIONS.Dash(s, P, c)
	P.Body *= T(0, -0.06 * c.S, 0) * A(-0.1)
	for i = 1, 3 do
		mul(P, "Neck" .. i, A(-0.18))
	end
	P.TailX, P.TailY = -0.35, math.sin(c.t * 8) * 0.12
	-- o bote (quem é dono do cachorro já fez o dele na hora do clique: Animator.PlayDodge(..., true))
	if not (s.DodgeForward and c.now - s.DodgeAt < 0.6) then
		pounce(P, pulse(c.at, 0.4), c.S)
	end
	c.ear = "back"
end

-- investida de cabeça baixa (chifres na frente)
function ACTIONS.Charge(s, P, c)
	P.Body *= T(0, -0.1 * c.S, 0) * A(-0.16)
	for i = 1, 3 do
		mul(P, "Neck" .. i, A(-0.5))
		P["Jaw" .. i] = A(-0.05)
	end
	P.TailX = -0.5
	c.ear = "back"
end

-- correria maluca: língua para fora, cabeça balançando, rabo girando em círculo
function ACTIONS.Zoom(s, P, c)
	local t = c.t
	P.Body *= A(-0.08, 0, math.sin(t * 7) * 0.08)
	for i = 1, 3 do
		mul(P, "Neck" .. i, A(math.sin(t * 11) * 0.12, math.sin(t * 6 + i) * 0.25, math.sin(t * 8) * 0.2))
		P["Jaw" .. i] = A(-0.45 + math.sin(t * 20) * 0.08)
	end
	P.TailX, P.TailY = -0.2 + math.sin(t * 15) * 0.3, math.cos(t * 15) * 0.6
end

-- giro de ataque: gira no próprio eixo com as patas encolhidas
function ACTIONS.Spin(s, P, c)
	local turns = c.at / 0.45
	local S = c.S
	local Q = {
		Body = T(0, 0.25 * S * math.sin(math.min(1, turns) * math.pi), 0) * A(-0.05, -turns * TAU, 0),
		TailX = -0.4,
		TailY = 0.6,
	}
	for _, leg in ipairs(LEGS) do
		setLeg(s, Q, leg, FRONT[leg] and 0.5 or -0.4, 0.9, S)
	end
	for i = 1, 3 do
		Q["Neck" .. i] = A(-0.1)
	end
	blend(P, Q, 1)
	c.fast.Body = true -- o giro não pode ser suavizado (a suavização "desgiraria" pelo caminho curto)
end

-- sombra: semi-invisível, rastejando baixo e devagar
function ACTIONS.Shadow(s, P, c)
	P.Body *= T(0, -0.18 * s.LegLen, 0) * A(-0.06)
	mul(P, "KneeFL", A(-0.35))
	mul(P, "KneeFR", A(-0.35))
	mul(P, "KneeBL", A(0.45))
	mul(P, "KneeBR", A(0.45))
	for i = 1, 3 do
		mul(P, "Neck" .. i, A(-0.2))
	end
	P.TailX, P.TailY = 0.3, math.sin(c.t * 2) * 0.2
	c.ear = "back"
	return 0.65
end

-- some (agacha rápido e desaparece)
function ACTIONS.Vanish(s, P, c)
	P.Body *= T(0, -0.2 * s.LegLen * smooth01(c.at / 0.15), 0)
	return 1
end

-- mergulho: cava o chão rápido com as patas da frente e entra de cabeça
function ACTIONS.Dive(s, P, c)
	local at, t, S = c.at, c.t, c.S
	local dig = 1 - smooth01((at - 0.45) / 0.15)
	local sink = smooth01((at - 0.35) / 0.4)
	local d1, d2 = math.sin(t * 24), math.sin(t * 24 + math.pi)
	local Q = {
		Body = T(0, -(s.LegLen * 1.8 + 1.5 * S) * sink, -0.3 * S * sink) * A(-0.25 - 0.5 * sink),
		LegBL = A(-0.3 - 0.4 * sink),
		LegBR = A(-0.3 - 0.4 * sink),
		KneeBL = A(0.5),
		KneeBR = A(0.5),
		TailX = -0.4,
		TailY = math.sin(t * 12) * 0.4 * dig,
	}
	setLeg(s, Q, "LegFL", 0.4 + d1 * 0.6 * dig, 0.7 + math.max(0, d1) * 0.5 * dig, S)
	setLeg(s, Q, "LegFR", 0.4 + d2 * 0.6 * dig, 0.7 + math.max(0, d2) * 0.5 * dig, S)
	for i = 1, 3 do
		Q["Neck" .. i] = A(-0.5)
		Q["Jaw" .. i] = A(-0.1)
	end
	blend(P, Q, smooth01(at / 0.1))
	c.ear = "back"
end

-- mirando: pose de cão "pointer" (pata da frente levantada, rabo reto, cabeça firme)
function ACTIONS.Aim(s, P, c)
	local tr = math.sin(c.t * 25) * 0.005
	local Q = {
		Body = T(0, -0.06 * c.S, 0) * A(-0.04 + tr),
		LegFL = A(0.4),
		KneeFL = A(-1.25),
		LegFR = A(0.05),
		LegBL = A(-0.15),
		LegBR = A(-0.1),
		KneeBL = A(0.2),
		TailX = -0.25,
		TailY = 0,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(0.02 + tr, s.LookYaw * 0.2, 0)
		Q["Jaw" .. i] = IDENT
	end
	blend(P, Q, smooth01(c.at / 0.25))
	c.ear = "up"
end

-- sentar (comando do servidor)
function ACTIONS.Sit(s, P, c)
	blend(P, sitPose(s, c), smooth01(c.at / 0.4))
end

-- nocaute: cambaleia e cai de lado, respirando fraco
function ACTIONS.KO(s, P, c)
	local at, t, L = c.at, c.t, s.LegLen
	local wob = smooth01(at / 0.25) * (1 - smooth01((at - 0.25) / 0.2))
	local fall = smooth01((at - 0.3) / 0.35)
	local slow = math.sin(t * 1.1) * 0.012
	local Q = {
		Body = T(0, -L * 0.8 * fall + slow * c.S, 0) * A(-0.1 * wob + slow, 0, math.sin(at * 18) * 0.12 * wob + 1.45 * fall),
		TailX = 0.7,
		TailY = 0,
	}
	for i, leg in ipairs(LEGS) do
		setLeg(s, Q, leg, (FRONT[leg] and 0.25 or 0.05) * fall + 0.2 * wob + math.sin(t * 0.6 + i) * 0.02, 0.35 * fall, c.S)
	end
	for i = 1, 3 do
		Q["Neck" .. i] = A(-0.3 * wob - 0.15 * fall + slow)
		Q["Jaw" .. i] = A(-0.28 * fall)
	end
	flapWings(Q, -0.25, 0.3, 0.2, 0.3) -- asas largadas
	blend(P, Q, 1)
	c.ear = "droop"
end

---------------------------------------------------------------- 6b. POSES DAS HABILIDADES NOVAS (2026-10)
-- Pedido do dono: "habilidades mais diferentes e com MAIS ANIMAÇÃO". Cada habilidade (server/SkillKit.lua)
-- encadeia estas poses: prepara → golpe → volta. Conferir sem Roblox: tools/preview/poses.py.

-- SALTO em arco (o servidor leva o cachorro): subindo = nariz para cima e patas da frente esticadas;
-- caindo = nariz para baixo, patas da frente para pegar, boca aberta
function ACTIONS.Leap(s, P, c)
	local at, t, S = c.at, c.t, c.S
	local up = math.clamp(s.VelY / (12 * math.sqrt(S)), -1, 1)
	local down = math.max(0, -up)
	local Q = {
		Body = T(0, 0.1 * S, 0) * A(0.32 * up - 0.04, 0, 0),
		TailX = -0.3 - 0.25 * math.max(0, up),
		TailY = math.sin(t * 9) * 0.15,
	}
	setLeg(s, Q, "LegFL", 0.95 - 0.35 * down, 0.15 + 0.2 * down, S)
	setLeg(s, Q, "LegFR", 0.8 - 0.35 * down, 0.25 + 0.2 * down, S)
	setLeg(s, Q, "LegBL", -1.0 + 0.3 * down, 0.15, S)
	setLeg(s, Q, "LegBR", -0.9 + 0.3 * down, 0.25, S)
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(0.05 - 0.2 * up, s.LookYaw * 0.3, 0)
		Q["Jaw" .. i] = A(-0.25 - 0.35 * down)
	end
	flapWings(Q, 0.35, 0.2, 0.1, 0.25)
	blend(P, Q, smooth01(at / 0.1))
	c.ear = "back"
end

-- MORTAL para trás (uma volta inteira, patas encolhidas)
function ACTIONS.Flip(s, P, c)
	local u = math.clamp(c.at / 0.55, 0, 1)
	local S = c.S
	local Q = {
		Body = T(0, 0.9 * S * math.sin(u * math.pi), 0) * A(smooth01(u) * TAU, 0, 0),
		TailX = -0.4,
		TailY = 0,
	}
	for _, leg in ipairs(LEGS) do
		setLeg(s, Q, leg, FRONT[leg] and 0.6 or -0.5, 1.0, S)
	end
	for i = 1, 3 do
		Q["Neck" .. i] = A(-0.2)
		Q["Jaw" .. i] = A(-0.1)
	end
	foldWings(Q, 0.2)
	blend(P, Q, 1)
	c.fast.Body = true
	c.ear = "back"
end

-- BOLA: encolhe as patas, esconde a cabeça (tatu, rolo); Roll = rola para a frente
local function curlPose(s, c, spin)
	local S, L = c.S, s.LegLen
	local k = smooth01(c.at / 0.15)
	local Q = {
		Body = T(0, (-0.35 * L + 0.35 * S) * k, 0) * A(-spin, 0, 0) * A(-0.3 * k, 0, 0),
		TailX = 0.6 * k,
		TailY = 0,
	}
	for _, leg in ipairs(LEGS) do
		setLeg(s, Q, leg, (FRONT[leg] and -0.6 or 0.7) * k, 1.4 * k, S)
	end
	for i = 1, 3 do
		Q["Neck" .. i] = A(-0.9 * k)
		Q["Jaw" .. i] = IDENT
	end
	foldWings(Q, 0)
	return Q
end
function ACTIONS.Curl(s, P, c)
	blend(P, curlPose(s, c, 0), 1)
	c.ear = "droop"
end
function ACTIONS.Roll(s, P, c)
	blend(P, curlPose(s, c, c.at * 12), 1)
	c.fast.Body = true
	c.ear = "droop"
end

-- BROCA: gira no próprio comprimento (parafuso), patas esticadas
function ACTIONS.Drill(s, P, c)
	local S = c.S
	local Q = {
		Body = T(0, 0.1 * S, 0) * A(-0.1, 0, c.at * 18),
		TailX = -0.5,
		TailY = 0,
	}
	for _, leg in ipairs(LEGS) do
		setLeg(s, Q, leg, FRONT[leg] and 1.0 or -1.0, 0.2, S)
	end
	for i = 1, 3 do
		Q["Neck" .. i] = A(-0.2)
		Q["Jaw" .. i] = A(-0.2)
	end
	foldWings(Q, 0)
	blend(P, Q, 1)
	c.fast.Body = true
	c.ear = "back"
end

-- COICE: abaixa a frente e chuta para trás com as duas patas de trás
function ACTIONS.Kick(s, P, c)
	local at, S = c.at, c.S
	local load = smooth01(at / 0.15) * (1 - smooth01((at - 0.15) / 0.06))
	local kick = smooth01((at - 0.17) / 0.07) * (1 - smooth01((at - 0.45) / 0.2))
	local Q = {
		Body = T(0, (0.15 * kick - 0.08 * load) * S, -0.1 * kick * S) * A(-0.35 * kick + 0.1 * load, 0, 0),
		LegFL = A(0.25 * kick),
		LegFR = A(0.25 * kick),
		KneeFL = A(-0.2),
		KneeFR = A(-0.2),
		TailX = -0.6 * kick,
		TailY = 0,
	}
	setLeg(s, Q, "LegBL", 0.4 * load - 1.5 * kick, 0.9 * load + 0.1, S)
	setLeg(s, Q, "LegBR", 0.4 * load - 1.4 * kick, 0.9 * load + 0.1, S)
	for i = 1, 3 do
		Q["Neck" .. i] = A(-0.3 * kick + 0.1 * load)
		Q["Jaw" .. i] = A(-0.25 * kick)
	end
	blend(P, Q, 1)
	c.ear = "back"
end

-- CAVAR: patas da frente se alternando bem rápido, cabeça baixa, bumbum para cima, terra voando
function ACTIONS.Dig(s, P, c)
	local t, S = c.t, c.S
	local d1, d2 = math.sin(t * 22), math.sin(t * 22 + math.pi)
	local Q = {
		Body = T(0, -0.05 * S, 0) * A(-0.28, 0, math.sin(t * 11) * 0.03),
		LegBL = A(-0.2),
		LegBR = A(-0.2),
		KneeBL = A(0.4),
		KneeBR = A(0.4),
		TailX = -0.5,
		TailY = math.sin(t * 14) * 0.4,
	}
	setLeg(s, Q, "LegFL", 0.35 + d1 * 0.55, 0.6 + math.max(0, d1) * 0.6, S)
	setLeg(s, Q, "LegFR", 0.35 + d2 * 0.55, 0.6 + math.max(0, d2) * 0.6, S)
	for i = 1, 3 do
		Q["Neck" .. i] = A(-0.6 + math.sin(t * 5) * 0.05)
		Q["Jaw" .. i] = A(-0.1)
	end
	blend(P, Q, smooth01(c.at / 0.12))
	c.ear = "droop"
	if not c.snap and s.Root and c.now > (s.NextDig or 0) then
		s.NextDig = c.now + 0.16
		dust(s.Root.Position + s.Root.CFrame.LookVector * s.LegLen * 0.8 - Vector3.new(0, s.LegLen, 0), 0.4 * math.sqrt(S))
	end
end

-- LATIDO: cada 0,32 s um latido curto (cabeça vai para a frente, boca abre, corpo dá um tranquinho)
function ACTIONS.Bark(s, P, c)
	local at, t, S = c.at, c.t, c.S
	local ph = (at % 0.32) / 0.32
	local snap = math.sin(math.min(1, ph / 0.35) * math.pi)
	local Q = {
		Body = T(0, 0.04 * S * snap, -0.12 * S * snap) * A(0.06 * snap, 0, 0),
		LegFL = A(0.25 * snap),
		LegFR = A(0.25 * snap),
		KneeFL = A(-0.15 * snap),
		KneeFR = A(-0.15 * snap),
		LegBL = A(-0.1),
		LegBR = A(-0.1),
		TailX = -0.4,
		TailY = math.sin(t * 16) * 0.3,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(0.15 + 0.25 * snap, s.LookYaw * 0.4, 0) * T(0, 0, -0.15 * S * snap)
		Q["Jaw" .. i] = A(-0.75 * snap)
	end
	blend(P, Q, smooth01(at / 0.08))
	c.ear = snap > 0.3 and "back" or "up"
end

-- CUSPIR / SOLTAR TIRO: puxa a cabeça e solta para a frente com a boca aberta (repete a cada 0,35 s)
function ACTIONS.Spit(s, P, c)
	local at, S = c.at, c.S
	local ph = at % 0.35
	local back = smooth01(ph / 0.1) * (1 - smooth01((ph - 0.1) / 0.05))
	local out = smooth01((ph - 0.11) / 0.06) * (1 - smooth01((ph - 0.24) / 0.1))
	local Q = {
		Body = T(0, 0, (0.1 * back - 0.12 * out) * S) * A(0.06 * back - 0.04 * out),
		TailX = -0.3,
		TailY = 0,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(0.25 * back - 0.1 * out, s.LookYaw * 0.4, 0) * T(0, 0, (0.1 * back - 0.2 * out) * S)
		Q["Jaw" .. i] = A(-0.15 * back - 0.75 * out)
	end
	blend(P, Q, smooth01(at / 0.06))
	c.ear = "back"
end

-- FAREJAR: focinho no chão varrendo de um lado para o outro, rabo abanando
function ACTIONS.Sniff(s, P, c)
	local t, S = c.t, c.S
	local sweep = math.sin(t * 2.2) * 0.35
	local sniff = math.sin(t * 28) * 0.03
	local Q = {
		Body = T(0, -0.08 * S, 0) * A(-0.12, sweep * 0.3, 0),
		LegFL = A(0.12),
		LegFR = A(0.12),
		KneeFL = A(-0.25),
		KneeFR = A(-0.25),
		TailX = -0.3,
		TailY = math.sin(t * 13) * 0.5,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(-0.75 + sniff, sweep, 0)
		Q["Jaw" .. i] = A(-0.05)
	end
	blend(P, Q, smooth01(c.at / 0.2))
	c.ear = "droop"
end

-- CONVITE PARA BRINCAR: frente no chão, bumbum para cima, rabo abanando forte
function ACTIONS.Bow(s, P, c)
	local t, L = c.t, s.LegLen
	local Q = {
		Body = T(0, -0.25 * L, 0) * A(-0.35, 0, 0),
		LegFL = A(0.9),
		LegFR = A(0.9),
		KneeFL = A(-0.1),
		KneeFR = A(-0.1),
		LegBL = A(-0.1),
		LegBR = A(-0.1),
		TailX = -0.7,
		TailY = math.sin(t * 18) * 0.6,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(0.45, math.sin(t * 3) * 0.1, math.sin(t * 2) * 0.15)
		Q["Jaw" .. i] = A(-0.3)
	end
	blend(P, Q, smooth01(c.at / 0.2))
	c.ear = "up"
end

-- ARREMESSO com a boca: abaixa e vira a cabeça, depois joga para cima e para a frente
function ACTIONS.Throw(s, P, c)
	local at, S = c.at, c.S
	local wind = smooth01(at / 0.18) * (1 - smooth01((at - 0.2) / 0.08))
	local fling = smooth01((at - 0.2) / 0.1) * (1 - smooth01((at - 0.55) / 0.25))
	local Q = {
		Body = T(0, 0, (0.1 * wind - 0.15 * fling) * S) * A(-0.1 * wind + 0.18 * fling, 0.25 * wind - 0.15 * fling, 0),
		LegFL = A(-0.15 * wind + 0.3 * fling),
		LegFR = A(0.1 * fling),
		TailX = -0.3,
		TailY = 0.3 * wind,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(-0.55 * wind + 0.7 * fling, 0.6 * wind - 0.2 * fling, 0)
		Q["Jaw" .. i] = A(-0.15 * wind - 0.5 * fling)
	end
	blend(P, Q, 1)
	c.ear = "back"
end

-- GANCHO: agacha e sobe nas patas de trás dando um soco para cima com a pata direita
function ACTIONS.Uppercut(s, P, c)
	local at, t, S, L = c.at, c.t, c.S, s.LegLen
	local crouch = smooth01(at / 0.12) * (1 - smooth01((at - 0.12) / 0.06))
	local rise = smooth01((at - 0.14) / 0.12) * (1 - smooth01((at - 0.6) / 0.2))
	local theta = 0.9 * rise
	local Q = {
		Body = T(0, L * 0.85 * math.sin(theta) - 0.15 * L * crouch, 0.4 * L * rise) * A(theta - 0.1 * crouch),
		LegBL = A(-theta + 0.1),
		LegBR = A(-theta + 0.1),
		KneeBL = A(0.35 + 0.4 * crouch),
		KneeBR = A(0.35 + 0.4 * crouch),
		TailX = 0.2,
		TailY = math.sin(t * 7) * 0.2,
	}
	setLeg(s, Q, "LegFR", -0.4 * crouch + 1.6 * rise, 0.9 * crouch + 0.1, S)
	setLeg(s, Q, "LegFL", -0.2, 0.9, S)
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(-0.4 * rise + 0.2, s.LookYaw * 0.3, 0)
		Q["Jaw" .. i] = A(-0.3 * rise)
	end
	blend(P, Q, 1)
	c.ear = "up"
end

-- CABEÇADA: abaixa a cabeça carregando e dá o tranco para a frente
function ACTIONS.Headbutt(s, P, c)
	local at, S = c.at, c.S
	local load = smooth01(at / 0.2) * (1 - smooth01((at - 0.22) / 0.06))
	local ram = smooth01((at - 0.22) / 0.08) * (1 - smooth01((at - 0.5) / 0.2))
	local Q = {
		Body = T(0, -0.12 * S * load, (0.18 * load - 0.45 * ram) * S) * A(-0.12 * load - 0.08 * ram),
		LegFL = A(-0.2 * load + 0.4 * ram),
		LegFR = A(-0.2 * load + 0.4 * ram),
		KneeFL = A(-0.4 * load),
		KneeFR = A(-0.4 * load),
		LegBL = A(0.25 * load - 0.5 * ram),
		LegBR = A(0.25 * load - 0.5 * ram),
		KneeBL = A(0.6 * load),
		KneeBR = A(0.6 * load),
		TailX = -0.5,
		TailY = 0,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = A(-0.55 * load - 0.35 * ram) * T(0, 0, -0.2 * S * ram)
		Q["Jaw" .. i] = A(-0.05)
	end
	blend(P, Q, 1)
	c.ear = "back"
end

-- PISOTEAR: patas da frente batem no chão alternando, forte (poeira a cada batida)
function ACTIONS.Stomp(s, P, c)
	local at, S = c.at, c.S
	local n = math.floor(at / 0.36)
	local cyc = (at % 0.36) / 0.36
	local side = n % 2 == 0 and 1 or -1
	local lift = math.sin(math.min(1, cyc / 0.6) * math.pi)
	local Q = {
		Body = T(0, 0.08 * S * lift, 0) * A(0.12 * lift, 0, 0.06 * side * lift),
		TailX = -0.3,
		TailY = 0,
	}
	setLeg(s, Q, side > 0 and "LegFR" or "LegFL", 0.2 - 0.3 * lift, 1.2 * lift, S)
	setLeg(s, Q, side > 0 and "LegFL" or "LegFR", 0.1, 0.1, S)
	for i = 1, 3 do
		Q["Neck" .. i] = A(0.1 * lift - 0.15)
		Q["Jaw" .. i] = A(-0.3)
	end
	blend(P, Q, smooth01(at / 0.1))
	if cyc > 0.6 and not c.snap and s.Root and s.LastStomp ~= n then
		s.LastStomp = n
		dust(s.Root.Position + s.Root.CFrame.LookVector * s.LegLen * 0.6 - Vector3.new(0, s.LegLen, 0), 0.5 * math.sqrt(S))
	end
	c.ear = "back"
end

-- INVOCAR: em pé nas patas de trás, patas da frente erguidas, cabeça para cima, asas abertas
function ACTIONS.Summon(s, P, c)
	local at, t, S, L = c.at, c.t, c.S, s.LegLen
	local k = smooth01(at / 0.35)
	local theta = 0.75 * k
	local Q = {
		Body = T(0, L * 0.75 * math.sin(theta), 0.35 * L * k) * A(theta + math.sin(t * 3) * 0.02),
		LegBL = A(-theta + 0.1),
		LegBR = A(-theta + 0.1),
		KneeBL = A(0.3),
		KneeBR = A(0.3),
		TailX = 0.1,
		TailY = math.sin(t * 3) * 0.3,
	}
	setLeg(s, Q, "LegFL", 0.9 * k + math.sin(t * 4) * 0.08, 0.3, S)
	setLeg(s, Q, "LegFR", 0.9 * k + math.sin(t * 4 + 1) * 0.08, 0.3, S)
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(0.25 * k, (i - 2) * 0.25 * (c.heads > 1 and 1 or 0), 0)
		Q["Jaw" .. i] = A(-0.35 * k)
	end
	flapWings(Q, -0.35 * k + math.sin(t * 4) * 0.1, 0.1, 0, 0.1)
	blend(P, Q, 1)
	c.ear = "up"
end

-- CONCENTRAR: abaixa, treme e flutua um tiquinho (carregando o Supremo)
function ACTIONS.Focus(s, P, c)
	local t, S, L = c.t, c.S, s.LegLen
	local k = smooth01(c.at / 0.3)
	local tr = math.sin(t * 38) * 0.012 * k
	local Q = {
		Body = T(0, (-0.25 * L + 0.08 * S * math.sin(t * 2.5)) * k, 0) * A(-0.08 * k + tr, 0, tr),
		TailX = 0.4,
		TailY = math.sin(t * 2) * 0.1,
	}
	for _, leg in ipairs(LEGS) do
		setLeg(s, Q, leg, FRONT[leg] and 0.25 or -0.25, 0.8 * k, S)
	end
	for i = 1, 3 do
		Q["Neck" .. i] = A(-0.45 * k)
		Q["Jaw" .. i] = IDENT
	end
	flapWings(Q, -0.3 * k, -0.2 * k, 0, 0)
	blend(P, Q, 1)
	c.ear = "back"
end

-- MÚSCULO: senta nas patas de trás, peito para fora e "flexiona" as patas da frente
function ACTIONS.Flex(s, P, c)
	local at, t, S, L = c.at, c.t, c.S, s.LegLen
	local k = smooth01(at / 0.25)
	local pump = math.sin(t * 6) * 0.5 + 0.5
	local theta = 0.55 * k
	local Q = {
		Body = T(0, L * 0.45 * math.sin(theta), 0.2 * L * k) * A(theta),
		LegBL = A(-theta - 0.2),
		LegBR = A(-theta - 0.2),
		KneeBL = A(0.5),
		KneeBR = A(0.5),
		TailX = 0,
		TailY = math.sin(t * 10) * 0.4,
	}
	setLeg(s, Q, "LegFL", 0.6 * k + 0.2 * pump, 1.3 * k, S)
	setLeg(s, Q, "LegFR", 0.6 * k + 0.2 * (1 - pump), 1.3 * k, S)
	Q.LegFL = Q.LegFL * A(0, 0, -0.35 * k)
	Q.LegFR = Q.LegFR * A(0, 0, 0.35 * k)
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(0.2 * k - 0.35 * k, math.sin(t * 2) * 0.2, 0)
		Q["Jaw" .. i] = A(-0.2 * k)
	end
	blend(P, Q, 1)
	c.ear = "up"
end

-- ESCORREGAR de barriga: corpo no chão, patas esticadas para frente e para trás
function ACTIONS.Slide(s, P, c)
	local t, S, L = c.t, c.S, s.LegLen
	local k = smooth01(c.at / 0.15)
	local Q = {
		Body = T(0, -0.75 * L * k, 0) * A(0.05 * k, 0, math.sin(t * 6) * 0.03),
		TailX = -0.2,
		TailY = math.sin(t * 8) * 0.3,
	}
	setLeg(s, Q, "LegFL", 1.2 * k, 0.1, S)
	setLeg(s, Q, "LegFR", 1.2 * k, 0.1, S)
	setLeg(s, Q, "LegBL", -1.3 * k, 0.1, S)
	setLeg(s, Q, "LegBR", -1.3 * k, 0.1, S)
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(0.35 * k, 0, 0)
		Q["Jaw" .. i] = A(-0.4 * k)
	end
	foldWings(Q, 0.3)
	blend(P, Q, 1)
	c.ear = "back"
end

-- PULINHOS no lugar (mola, bumbum, balão): sobe e desce amassando no chão
function ACTIONS.Bounce(s, P, c)
	local at, t, S, L = c.at, c.t, c.S, s.LegLen
	local ph = (at % 0.42) / 0.42
	local h = math.sin(ph * math.pi)
	local squash = (1 - smooth01(ph / 0.15)) + smooth01((ph - 0.85) / 0.15)
	local Q = {
		Body = T(0, L * (0.9 * h - 0.15 * squash), 0) * A(0.1 * h - 0.05 * squash, 0, math.sin(t * 5) * 0.06),
		TailX = -0.3 * h,
		TailY = math.sin(t * 15) * 0.5,
	}
	for _, leg in ipairs(LEGS) do
		setLeg(s, Q, leg, (FRONT[leg] and 0.3 or -0.3) * h, 0.6 * squash + 0.3 * h, S)
	end
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(0.2 * h, 0, math.sin(t * 5) * 0.1)
		Q["Jaw" .. i] = A(-0.35 * h)
	end
	flapWings(Q, math.sin(t * 20) * 0.4 * h, 0.2, 0.1, 0.1)
	blend(P, Q, 1)
	c.ear = h > 0.5 and "up" or "droop"
end

-- PIRUETA: em pé nas patas de trás, girando sem parar (bailarina)
function ACTIONS.Twirl(s, P, c)
	local at, S, L = c.at, c.S, s.LegLen
	local k = smooth01(at / 0.2)
	local theta = 0.6 * k
	local Q = {
		Body = T(0, L * 0.5 * math.sin(theta), 0.2 * L * k) * A(0, -at * 13, 0) * A(theta, 0, 0),
		LegBL = A(-theta),
		LegBR = A(-theta),
		TailX = -0.3,
		TailY = 0.6,
	}
	setLeg(s, Q, "LegFL", 0.5 * k, 0.8, S)
	setLeg(s, Q, "LegFR", 0.5 * k, 0.8, S)
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(0.3 - 0.4 * k, 0, 0.2)
		Q["Jaw" .. i] = A(-0.2)
	end
	blend(P, Q, 1)
	c.fast.Body = true
	c.ear = "back"
end

-- GUARDA: base larga e baixa, cabeça baixa, firme (escudo)
function ACTIONS.Guard(s, P, c)
	local t, S, L = c.t, c.S, s.LegLen
	local k = smooth01(c.at / 0.2)
	local br = math.sin(t * 3) * 0.02
	local Q = {
		Body = T(0, -0.2 * L * k, 0.08 * S * k) * A(-0.08 * k + br, 0, 0),
		LegFL = A(0.3 * k, 0, -0.25 * k),
		LegFR = A(0.3 * k, 0, 0.25 * k),
		KneeFL = A(-0.35 * k),
		KneeFR = A(-0.35 * k),
		LegBL = A(-0.25 * k, 0, -0.2 * k),
		LegBR = A(-0.25 * k, 0, 0.2 * k),
		KneeBL = A(0.5 * k),
		KneeBR = A(0.5 * k),
		TailX = 0.1,
		TailY = 0,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(-0.3 * k, s.LookYaw * 0.5, 0)
		Q["Jaw" .. i] = A(-0.12 * k)
	end
	foldWings(Q, 0.6)
	blend(P, Q, 1)
	c.ear = "back"
end

-- CORTE de espada: torce o corpo para um lado e corta varrendo a cabeça para o outro
function ACTIONS.Slash(s, P, c)
	local at, S = c.at, c.S
	local wind = smooth01(at / 0.15) * (1 - smooth01((at - 0.16) / 0.05))
	local cut = smooth01((at - 0.16) / 0.09)
	local back = 1 - smooth01((at - 0.45) / 0.25)
	local yaw = 0.7 * wind - 0.9 * cut * back
	local Q = {
		Body = T(0, -0.06 * S, -0.15 * S * cut * back) * A(-0.05, yaw * 0.6, -0.08 * cut * back),
		LegFL = A(0.35 * cut * back),
		LegBR = A(-0.35 * cut * back),
		TailX = -0.3,
		TailY = -yaw * 0.8,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(0.05, yaw, -yaw * 0.3)
		Q["Jaw" .. i] = A(-0.06)
	end
	blend(P, Q, 1)
	c.ear = "back"
end

-- PUXAR O AR antes do sopro: peito para cima, cabeça para trás, asas sobem
function ACTIONS.Inhale(s, P, c)
	local t, S = c.t, c.S
	local k = smooth01(c.at / 0.4)
	local Q = {
		Body = T(0, 0.05 * S * k, 0.12 * S * k) * A(0.15 * k, 0, 0),
		LegFL = A(-0.1 * k),
		LegFR = A(-0.1 * k),
		TailX = -0.2,
		TailY = math.sin(t * 5) * 0.1,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(0.55 * k, 0, 0)
		Q["Jaw" .. i] = A(-0.15 * k)
	end
	flapWings(Q, -0.4 * k, -0.2 * k, 0, 0.1)
	blend(P, Q, 1)
	c.ear = "back"
end

-- BARRIGADA: patas abertas para os lados (esquilo voador) e cai de barriga
function ACTIONS.Belly(s, P, c)
	local S, L = c.S, s.LegLen
	local k = smooth01(c.at / 0.15)
	local fall = s.VelY < -2 and 1 or 0
	local Q = {
		Body = T(0, -0.5 * L * k * fall, 0) * A(-0.05 * k, 0, 0),
		TailX = -0.4,
		TailY = 0,
	}
	setLeg(s, Q, "LegFL", 1.0 * k, 0.1, S)
	setLeg(s, Q, "LegFR", 1.0 * k, 0.1, S)
	setLeg(s, Q, "LegBL", -1.0 * k, 0.1, S)
	setLeg(s, Q, "LegBR", -1.0 * k, 0.1, S)
	Q.LegFL = Q.LegFL * A(0, 0, -0.6 * k)
	Q.LegFR = Q.LegFR * A(0, 0, 0.6 * k)
	Q.LegBL = Q.LegBL * A(0, 0, -0.6 * k)
	Q.LegBR = Q.LegBR * A(0, 0, 0.6 * k)
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(0.3 * k, 0, 0)
		Q["Jaw" .. i] = A(-0.5 * k)
	end
	flapWings(Q, 0, 0, 0, 0)
	blend(P, Q, 1)
	c.ear = "back"
end

-- RONCO: deitado, cabeça nas patas, respirando fundo
function ACTIONS.Snore(s, P, c)
	blend(P, liePose(s, c), smooth01(c.at / 0.3))
	local breath = math.sin(c.t * 3)
	P.Body = (P.Body or IDENT) * T(0, 0.05 * c.S * breath, 0)
	for i = 1, 3 do
		mul(P, "Neck" .. i, A(-0.15 + 0.06 * breath))
		P["Jaw" .. i] = A(-0.08 - 0.12 * math.max(0, breath))
	end
	c.ear = "droop"
end

-- COMEMORAR: em pé nas patas de trás, abanando o rabo e as patinhas
function ACTIONS.Victory(s, P, c)
	local at, t, S, L = c.at, c.t, c.S, s.LegLen
	local k = smooth01(at / 0.3)
	local theta = 1.05 * k
	local Q = {
		Body = T(0, L * 0.95 * math.sin(theta), 0.5 * L * k) * A(theta, 0, math.sin(t * 5) * 0.08),
		LegBL = A(-theta + 0.1),
		LegBR = A(-theta + 0.1),
		KneeBL = A(0.3),
		KneeBR = A(0.3),
		TailX = 0,
		TailY = math.sin(t * 16) * 0.7,
	}
	setLeg(s, Q, "LegFL", 0.4 + math.sin(t * 10) * 0.5, 0.4, S)
	setLeg(s, Q, "LegFR", 0.4 + math.sin(t * 10 + math.pi) * 0.5, 0.4, S)
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(-0.3 * k + math.sin(t * 5) * 0.1, math.sin(t * 2.5) * 0.3, 0)
		Q["Jaw" .. i] = A(-0.45 * k)
	end
	flapWings(Q, math.sin(t * 9) * 0.5, math.sin(t * 9 - 0.6) * 0.4, 0.1, 0.1)
	blend(P, Q, 1)
	c.ear = "up"
end

-- DANCINHA: rebola o bumbum e balança a cabeça no ritmo
function ACTIONS.Wiggle(s, P, c)
	local t, S = c.t, c.S
	local beat = math.sin(t * 9)
	local Q = {
		Body = T(0, math.abs(beat) * 0.08 * S, 0) * A(0, beat * 0.25, beat * 0.12),
		LegBL = A(-0.1 + beat * 0.15),
		LegBR = A(-0.1 - beat * 0.15),
		TailX = -0.5,
		TailY = beat * 0.9,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(0.15 + math.abs(beat) * 0.15, -beat * 0.2, beat * 0.25)
		Q["Jaw" .. i] = A(-0.25 - math.abs(beat) * 0.2)
	end
	flapWings(Q, beat * 0.3, 0.1, 0, 0.1)
	blend(P, Q, smooth01(c.at / 0.15))
	c.ear = "up"
end

-- SACUDIR como cachorro molhado: o corpo gira rápido de um lado para o outro
function ACTIONS.Shake(s, P, c)
	local at, t = c.at, c.t
	local env = smooth01(at / 0.1) * (1 - smooth01((at - 0.6) / 0.25))
	local w = math.sin(t * 34)
	local Q = {
		Body = A(0, w * 0.15 * env, w * 0.4 * env),
		LegFL = A(0.1, 0, -0.15),
		LegFR = A(0.1, 0, 0.15),
		LegBL = A(-0.1, 0, -0.15),
		LegBR = A(-0.1, 0, 0.15),
		TailX = -0.2,
		TailY = -w * 0.8 * env,
	}
	for i = 1, 3 do
		Q["Neck" .. i] = HEAD(0.05, -w * 0.5 * env, -w * 0.4 * env)
		Q["Jaw" .. i] = A(-0.1)
	end
	blend(P, Q, 1)
	c.fast.Body = true
	c.ear = "up"
	s.EarKick = (s.EarKick or 0) + 0.6 * env
end

-- PODERES NOVOS (qualquer Action sem função própria): o nome escolhe um de 4 jeitos,
-- então cada poder tem seu movimento e o mesmo poder sempre anima igual
local GENERIC = { "push", "stomp", "channel", "lunge" }
local function genericAction(s, P, c)
	local name = c.action
	local h = 0
	for i = 1, #name do
		h = (h * 31 + string.byte(name, i)) % 997
	end
	local kind = GENERIC[h % #GENERIC + 1]
	local at, t, S = c.at, c.t, c.S
	local wind = smooth01(at / 0.2)
	local go = smooth01((at - 0.2) / 0.12)
	local Q = {}
	if kind == "push" then -- prepara e empurra o poder com as patas da frente
		Q.Body = T(0, -0.08 * S, (0.08 * wind - 0.2 * go) * S) * A(0.08 * wind - 0.08 * go)
		setLeg(s, Q, "LegFL", -0.3 * wind + 0.8 * go, 0.8 * wind * (1 - go), S)
		setLeg(s, Q, "LegFR", -0.3 * wind + 0.8 * go, 0.8 * wind * (1 - go), S)
		Q.LegBL, Q.LegBR = A(-0.35 * go), A(-0.35 * go)
		for i = 1, 3 do
			Q["Neck" .. i] = A(0.15 * wind + 0.2 * go)
			Q["Jaw" .. i] = A(-0.6 * go)
		end
		Q.TailX = -0.4 * go
	elseif kind == "stomp" then -- empina um pouco e pisa forte, várias vezes
		local lift = math.sin(((at % 0.7) / 0.7) * math.pi)
		Q.Body = T(0, 0.15 * S * lift, 0) * A(0.25 * lift)
		setLeg(s, Q, "LegFL", -0.3 * lift, 0.9 * lift, S)
		setLeg(s, Q, "LegFR", -0.3 * lift, 0.9 * lift, S)
		for i = 1, 3 do
			Q["Neck" .. i] = A(0.2 * lift - 0.1)
			Q["Jaw" .. i] = A(-0.4)
		end
		Q.TailX = -0.3
	elseif kind == "channel" then -- concentra (treme, cabeça baixa) e explode olhando para cima
		local tr = math.sin(t * 40) * 0.02 * (1 - go)
		Q.Body = T(0, (-0.15 * (1 - go) + 0.05 * go) * S, 0) * A(-0.1 * (1 - go) + 0.15 * go + tr, 0, tr)
		for _, leg in ipairs(LEGS) do
			setLeg(s, Q, leg, 0, 0.45 * (1 - go), S)
		end
		for i = 1, 3 do
			Q["Neck" .. i] = A(-0.45 * (1 - go) + 0.65 * go)
			Q["Jaw" .. i] = A(-0.75 * go)
		end
		Q.TailX = -0.5 * go
		flapWings(Q, -0.3 * go, 0, 0, 0)
	else -- lunge: bote curto para a frente com a boca aberta
		Q.Body = T(0, -0.1 * S * wind, (0.1 * wind - 0.45 * go) * S) * A(-0.15 * go)
		Q.LegFL, Q.LegFR = A(0.6 * go), A(0.6 * go)
		Q.LegBL, Q.LegBR = A(-0.5 * go), A(-0.5 * go)
		for i = 1, 3 do
			Q["Neck" .. i] = A(-0.1)
			Q["Jaw" .. i] = A(-0.8 * go * (1 - smooth01((at - 0.45) / 0.1)))
		end
		Q.TailX = -0.35
	end
	blend(P, Q, smooth01(at / 0.1))
	c.ear = "back"
end

---------------------------------------------------------------- 7. CAMADAS POR CIMA
-- mordida em 3 tempos (prepara, ataca e fecha a boca, sacode e volta); 3 variações em sequência:
-- 1 reta, 2 de lado, 3 de baixo para cima
local BITE_TIME = 0.38
local function bitePose(s, P, c)
	local bodyDone = false
	for head, b in pairs(s.Bites) do
		local bt = c.now - b.At
		if bt > BITE_TIME then
			s.Bites[head] = nil
		else
			local S = c.S
			local wind = smooth01(bt / 0.07) * (1 - smooth01((bt - 0.07) / 0.05))
			local strike = smooth01((bt - 0.07) / 0.08) * (1 - smooth01((bt - 0.2) / 0.14))
			local open = bt < 0.15 and smooth01(bt / 0.1) or (1 - smooth01((bt - 0.15) / 0.04))
			local shakeK = smooth01((bt - 0.18) / 0.04) * (1 - smooth01((bt - 0.3) / 0.08))
			local yaw, pitch = 0, 0
			if b.Variant == 2 then
				yaw = (0.4 - 0.8 * smooth01((bt - 0.07) / 0.1)) * b.Side
			elseif b.Variant == 3 then
				pitch = -0.35 + 0.6 * smooth01((bt - 0.07) / 0.1)
			end
			local neck, jaw = "Neck" .. head, "Jaw" .. head
			local big = b.Big and 1.5 or 1 -- mordida final do combo: bote maior
			mul(P, neck, T(0, 0, (0.18 * wind - 0.6 * strike * big) * S) * A(0.15 * wind - 0.1 * strike + pitch * strike, yaw * strike + math.sin(c.t * 45) * 0.12 * shakeK, 0))
			P[jaw] = A(-0.95 * open)
			c.fast[neck], c.fast[jaw] = true, true
			if not bodyDone then -- o corpo acompanha o bote (uma vez, mesmo com várias cabeças)
				bodyDone = true
				-- prepara (recua e sobe um tico) e dá o bote com o corpo todo: dianteiras esticam, traseiras empurram
				P.Body *= T(0, (0.03 * wind - 0.06 * strike) * S, (0.1 * wind - 0.3 * strike * big) * S) * A(0.07 * wind - 0.1 * strike * big)
				mul(P, "LegFL", A(0.3 * strike - 0.1 * wind))
				mul(P, "LegFR", A(0.3 * strike - 0.1 * wind))
				mul(P, "LegBL", A(-0.25 * strike))
				mul(P, "LegBR", A(-0.25 * strike))
				P.TailX = (P.TailX or 0) - 0.3 * strike
			end
			c.ear = "back"
		end
	end
end

-- 🐾 PATADA do combo (pata direita → pata esquerda → mordida): a pata da frente SOBE e abre para fora (arma),
-- DESCE cruzando na frente do corpo (unhas), e volta. O corpo sobe um tico, avança no golpe, torce para dentro e
-- inclina para o outro lado (o peso vai para a outra pata); a cabeça acompanha e o cachorro rosna.
local SWIPE_TIME = 0.42
local function swipePose(s, P, c)
	for side, sw in pairs(s.Swipes) do
		local t = c.now - sw.At
		if t > SWIPE_TIME then
			s.Swipes[side] = nil
		else
			local S = c.S
			local leg = side > 0 and "LegFR" or "LegFL"
			local knee = KNEE_OF[leg]
			local up = smooth01(t / 0.09)
			local strike = smooth01((t - 0.09) / 0.08)
			local back = smooth01((t - 0.22) / 0.2)
			local k = up * (1 - back)
			local hit = strike * (1 - back)
			-- perna: armada = alta na frente e para fora, pulso dobrado; golpe = desce cruzando para dentro, esticada
			P[leg] = (P[leg] or IDENT):Lerp(A(1.55 - 1.1 * strike, 0, side * (0.3 - 0.7 * strike)), k)
			P[knee] = (P[knee] or IDENT):Lerp(A(FLEX[leg] * (0.95 - 0.8 * strike) * 1.15), k)
			-- a outra dianteira apoia mais aberta
			mul(P, side > 0 and "LegFL" or "LegFR", A(0.1 * k, 0, -side * 0.08 * k))
			P.Body *= T(0, 0.05 * S * k, -0.12 * S * hit) * A(0.1 * up * (1 - strike) - 0.06 * hit, side * 0.12 * hit, side * 0.1 * k)
			for i = 1, 3 do
				mul(P, "Neck" .. i, HEAD(-0.08 * k, side * 0.15 * hit, -side * 0.1 * k))
				mul(P, "Jaw" .. i, A(-0.25 * k)) -- rosna
			end
			c.fast[leg], c.fast[knee] = true, true
			c.ear = "back"
		end
	end
end

-- levou dano: tranco para trás e para o lado, cabeça desvia, rabo encolhe
local function hitPose(s, P, c)
	local k = pulse(c.now - s.HitAt, 0.4) * s.HitPower
	if k <= 0 then
		return
	end
	local side = s.HitSide
	P.Body *= T(0, -0.05 * c.S * k, 0.22 * c.S * k) * A(0.12 * k, side * 0.15 * k, side * 0.18 * k)
	for i = 1, 3 do
		mul(P, "Neck" .. i, A(0.3 * k, -side * 0.35 * k, side * 0.2 * k))
		mul(P, "Jaw" .. i, A(-0.3 * k))
	end
	mul(P, "LegFL", A(0.3 * k))
	mul(P, "LegFR", A(0.2 * k))
	mul(P, "KneeBL", A(0.4 * k))
	mul(P, "KneeBR", A(0.4 * k))
	P.TailX = (P.TailX or 0) + 0.5 * k
	c.ear = "back"
end

-- esquiva: pulinho de lado (ou para trás) com as patas encolhidas e o corpo torcendo para o lado do pulo.
-- Voando: o DogControl gira o corpo inteiro num parafuso (como avião); aqui as asas e as patas se fecham.
local function dodgePose(s, P, c)
	if c.action == "Fly" then
		local kk = pulse(c.now - s.DodgeAt, 0.55)
		if kk > 0 then
			for _, side in ipairs({ -1, 1 }) do
				mul(P, side < 0 and "WingL" or "WingR", A(0, -side * 0.6 * kk, 0))
			end
			mul(P, "KneeFL", A(-0.5 * kk))
			mul(P, "KneeFR", A(-0.5 * kk))
			mul(P, "LegBL", A(-0.3 * kk))
			mul(P, "LegBR", A(-0.3 * kk))
			c.ear = "back"
		end
		return
	end
	-- 💨 dash para a frente (o novo Q): bote esticado em vez do pulinho de lado
	if s.DodgeForward then
		pounce(P, pulse(c.now - s.DodgeAt, 0.4), c.S)
		if c.now - s.DodgeAt < 0.4 then
			c.ear = "back"
		end
		return
	end
	local k = pulse(c.now - s.DodgeAt, 0.35)
	if k <= 0 then
		return
	end
	local d = s.DodgeDir
	P.Body *= T(0, 0.35 * c.S * k, 0) * A(d.Z * 0.3 * k, -d.X * 0.25 * k, -d.X * 0.55 * k)
	mul(P, "LegFL", A(0.4 * k))
	mul(P, "LegFR", A(0.4 * k))
	mul(P, "LegBL", A(-0.4 * k))
	mul(P, "LegBR", A(-0.4 * k))
	mul(P, "KneeFL", A(-0.9 * k))
	mul(P, "KneeFR", A(-0.9 * k))
	mul(P, "KneeBL", A(0.8 * k))
	mul(P, "KneeBR", A(0.8 * k))
	P.TailX = (P.TailX or 0) - 0.3 * k
	c.ear = "back"
end

-- vida baixa e parado: segura a pata machucada levantada
local function limpPose(s, P, c)
	if s.Health >= TUNE.LowHealth or s.MoveW > 0.5 or c.action then
		return
	end
	local k = 1 - s.MoveW * 2
	local leg = s.LimpLeg
	mul(P, leg, A(0.15 * k))
	mul(P, KNEE_OF[leg], A(FLEX[leg] * 0.5 * k))
	if not c.ear then
		c.ear = "droop"
	end
end

local function buildPose(s, c)
	local P = {}
	idlePose(s, P, c)
	if s.MoveW > 0.001 then
		local Q = {}
		movePose(s, Q, c)
		blend(P, Q, s.MoveW)
	end
	brakePose(s, P, c)
	if s.SwimW > 0.001 then
		local Q = {}
		swimPose(s, Q, c)
		blend(P, Q, s.SwimW)
	end
	if c.floater then
		floaterPose(s, P, c)
	end
	if s.AirW > 0.001 then
		local Q = {}
		airPose(s, Q, c)
		blend(P, Q, s.AirW)
	end
	takeoffPose(s, P, c)
	landPose(s, P, c)
	if c.raging then
		ragePose(s, P, c)
	end
	if c.action then
		if c.airAction then
			-- 🪽 HABILIDADE NO AR (2026-10, pedido do dono: "usar as habilidades no ar, com animações um pouco diferentes,
			-- parecidas, mas ajustadas porque ele está no ar"): por baixo a pose de voo (pairando, asas batendo); por cima
			-- a da habilidade. As asas continuam batendo e as patas só fazem metade do gesto (não "pisam" no ar)
			local fc = table.clone(c)
			fc.at = 10 -- voo já firme (sem a batida da decolagem)
			ACTIONS.Fly(s, P, fc)
			local F = table.clone(P)
			c.fade = (ACTIONS[c.action] or genericAction)(s, P, c) or 0
			for _, name in ipairs({ "WingL", "WingR", "WingL2", "WingR2" }) do
				if F[name] then
					P[name] = F[name]
				end
			end
			for _, leg in ipairs(LEGS) do
				for _, name in ipairs({ leg, KNEE_OF[leg] }) do
					if F[name] and P[name] then
						P[name] = P[name]:Lerp(F[name], 0.55)
					end
				end
			end
			c.ear = c.ear or "back"
		else
			c.fade = (ACTIONS[c.action] or genericAction)(s, P, c) or 0
		end
	end
	limpPose(s, P, c)
	bitePose(s, P, c)
	swipePose(s, P, c)
	hitPose(s, P, c)
	dodgePose(s, P, c)
	return P
end

---------------------------------------------------------------- 8. MOVIMENTO SECUNDÁRIO (molas)
-- rabo: segue a pose com atraso e balanço
local function tailFinish(s, P, c)
	local gx, gy = P.TailX or 0, P.TailY or 0
	if c.snap then
		s.TailX, s.TailY, s.TailVX, s.TailVY = gx, gy, 0, 0
	else
		s.TailX, s.TailVX = spring(s.TailX, s.TailVX, gx, 90, 11, c.dt)
		s.TailY, s.TailVY = spring(s.TailY, s.TailVY, gy, 120, 9, c.dt)
	end
	-- abanar de LADO: em volta do eixo do rabo (um rabo em pé não fica mais torcendo em volta dele mesmo)
	P.Tail = s.WagAxis and (A(s.TailX, 0, 0) * CFrame.fromAxisAngle(s.WagAxis, s.TailY)) or A(s.TailX, s.TailY, 0)
	P.TailX, P.TailY = nil, nil
end

-- orelhas: dobradiça na base; mola que balança com passos, pulos, pancadas e chacoalhadas
local function earsFinish(s, c)
	if #s.Ears == 0 then
		return
	end
	local now, dt = c.now, c.dt
	local M, G = s.MoveW, s.Gait.Gallop
	local goal = 0.22 * M + 0.18 * G + 0.25 * s.AirW + math.sin(s.Phase * TAU * 2) * 0.12 * M
	local flare = math.sin(c.t * 1.7) * 0.03
	if c.ear == "back" then
		goal, flare = 0.65, -0.1
	elseif c.ear == "droop" then
		goal, flare = 0.2, 0.45
	elseif c.ear == "up" then
		goal, flare = -0.15, 0
	elseif s.SleepW > 0.5 then
		goal, flare = 0.3, 0.3
	end
	-- voando rápido: orelhas coladas para trás, tremulando no vento
	local wind = math.min(c.wind or 0, 1.5)
	if wind > 0.05 then
		goal += 0.25 * math.min(wind, 1)
	end
	if now > s.NextTwitch then
		s.NextTwitch = now + 1.5 + math.random() * 4
		s.EarV[math.random() < 0.5 and -1 or 1] += 9 -- orelhinha mexe sozinha
	end
	for _, side in ipairs({ -1, 1 }) do
		s.EarV[side] += s.EarKick
		if wind > 0.05 then
			s.EarV[side] += math.sin(c.t * 29 + side * 1.9) * 420 * wind * dt
		end
		if c.snap then
			s.EarX[side], s.EarV[side] = goal, 0
		else
			s.EarX[side], s.EarV[side] = spring(s.EarX[side], s.EarV[side], goal, 160, 13, dt)
		end
	end
	s.EarKick = 0
	local hinges = {}
	local ek = c.snap and 1 or damp(dt, 30)
	for _, ear in ipairs(s.Ears) do
		local weld, part = ear.Weld, ear.Part
		if weld.Parent and weld.Part0 then
			local base = baseC0(s, weld)
			local side = base.Position.X >= 0 and 1 or -1
			local key = ear.Head * 2 + (side > 0 and 1 or 0)
			local up = base.Position.Y > weld.Part0.Size.Y * 0.2
			local u = up and 1 or -1
			local hinge = hinges[key]
			if ear.Main or not hinge then
				hinge = CFrame.new(base * Vector3.new(0, (up and -0.45 or 0.45) * part.Size.Y, 0))
				hinges[key] = hinge
			end
			local target = A(s.EarX[side] * u, 0, -side * u * flare)
			local cur = (s.EarCur[weld] or IDENT):Lerp(target, ek)
			s.EarCur[weld] = cur
			writeC0(s, weld, hinge * cur * hinge:Inverse() * base)
		end
	end
end

---------------------------------------------------------------- 9. APLICAR
local function apply(s, c, P)
	local useC0 = s.UseC0 or s.Mode == "C0"
	for name, motor in pairs(s.Motors) do
		local goal = P[name] or IDENT
		local rate
		if c.snap then
			rate = 1
		elseif c.fast[name] then
			rate = name == "Body" and 1 or damp(c.dt, TUNE.Smooth.Fast)
		elseif LEG_JOINT[name] and s.LegRate then
			rate = damp(c.dt, math.max(RATE[name], s.LegRate))
		else
			rate = damp(c.dt, RATE[name] or 14)
		end
		local cur = (s.Current[name] or IDENT):Lerp(goal, rate)
		s.Current[name] = cur
		if useC0 then
			writeC0(s, motor, baseC0(s, motor) * cur)
		else
			motor.Transform = cur
		end
	end
	setFade(s, c.fade)
end

-- confere se o Transform faz efeito; se não, passa para o modo C0
local function verify(s, now)
	if s.UseC0 or s.Mode == "C0" or now < s.NextVerify then
		return
	end
	s.NextVerify = now + 0.5
	local leg = s.Motors.LegFL or s.Motors.Neck1
	local last = leg and s.Current[leg.Name] -- o que foi escrito no quadro anterior
	if not (leg and leg.Part0 and leg.Part1 and last) then
		return
	end
	local actual = leg.Part0.CFrame:ToObjectSpace(leg.Part1.CFrame).Position
	local rest = (leg.C0 * leg.C1:Inverse()).Position
	local expected = (leg.C0 * last * leg.C1:Inverse()).Position
	if (expected - rest).Magnitude > 0.05 * s.S then
		if (actual - rest).Magnitude < (actual - expected).Magnitude * 0.35 then
			s.Mismatch += 1
		else
			s.Mismatch = 0
		end
		if s.Mismatch >= 8 then
			warn("[Animator] Transform sem efeito em", s.Model:GetFullName(), "- usando C0")
			s.Mode = "C0"
			for _, m in pairs(s.Motors) do
				m.Transform = IDENT
			end
		end
	end
end

local function step(s, dt, now)
	if s.Dirty then
		refresh(s)
	end
	if not s.Root or not s.Root.Parent then
		s.Dirty = true
		return
	end
	if s.Count == 0 then
		return -- ainda chegando (streaming); DescendantAdded marca para recoletar
	end
	sense(s, dt, now)
	local c = context(s, dt, now, false)
	update(s, c)
	local P = buildPose(s, c)
	tailFinish(s, P, c)
	verify(s, now)
	apply(s, c, P)
	earsFinish(s, c)
end

---------------------------------------------------------------- API pública
-- opts.UseC0 = true para modelos em ViewportFrame; opts.Speed = function() -> velocidade fake (studs/s)
function Animator.Track(model, opts)
	if tracked[model] then
		return tracked[model]
	end
	opts = opts or {}
	local now = os.clock()
	local s: any = {
		Model = model,
		Root = nil,
		Motors = {},
		Ears = {},
		Count = 0,
		Humanoid = nil,
		Base = setmetatable({}, { __mode = "k" }),
		Written = setmetatable({}, { __mode = "k" }),
		Current = {},
		EarCur = {},
		UseC0 = opts.UseC0,
		FakeSpeed = opts.Speed,
		Seed = math.random() * 100,
		Phase = math.random(),
		Dirty = true,
		Errors = 0,
		Acc = 0,
		Frame = math.random(0, 2),
		Mismatch = 0,
		NextVerify = now + 1,
		-- sentidos
		S = 1,
		LegLen = 2,
		Speed = 0,
		Rel = 0,
		Accel = 0,
		VelY = 0,
		Yaw = 0,
		Side = 0,
		Back = false,
		Health = 1,
		Grounded = true,
		InWater = false,
		NextRay = 0,
		-- pesos e andadura
		MoveW = 0,
		AirW = 0,
		SwimW = 0,
		TurnW = 0,
		Gait = { Walk = 1, Trot = 0, Gallop = 0 },
		Stretch = 1, -- passo esticado (galope voador) quando a perna não alcança a velocidade
		LegRate = nil,
		Pant = 0,
		Air = false,
		AirSince = 0,
		TakeoffAt = -10,
		LandAt = -10,
		LandPower = 0,
		LastStep = {},
		-- olhar
		LookYaw = 0,
		LookPitch = 0,
		LookTilt = 0,
		LookYawV = 0,
		LookPitchV = 0,
		Twist = 0, -- quanto o corpo torce junto com o olhar
		LookGoal = Vector3.zero,
		NextLook = 0,
		NextTarget = 0,
		Target = nil,
		LookPoint = nil, -- setinha do mouse (SetLookAt)
		LookPointAt = -10,
		LastLookDir = nil,
		LastPoint = nil,
		StillFor = 0,
		TiltSide = 1,
		Excite = 0, -- 0..1: setinha passando rápido perto
		LegZ = {},
		-- parado
		IdleTime = 0,
		Behavior = nil,
		BehaviorAt = 0,
		BehaviorSide = 1,
		NextBehavior = now + 3 + math.random() * 4,
		SitW = 0,
		LieW = 0,
		SleepW = 0,
		-- golpes
		Bites = {},
		BiteVariant = 0,
		Swipes = {}, -- [lado] = { At } (1 = pata direita, -1 = esquerda)
		LocalMeleeAt = -10,
		HitAt = -10,
		HitPower = 0,
		HitSide = 1,
		DodgeAt = -10,
		DodgeDir = Vector3.new(1, 0, 0),
		LimpLeg = LEGS[math.random(1, 4)],
		-- molas
		TailX = 0,
		TailY = 0,
		TailVX = 0,
		TailVY = 0,
		EarX = { [-1] = 0, [1] = 0 },
		EarV = { [-1] = 0, [1] = 0 },
		EarKick = 0,
		NextTwitch = now + math.random() * 4,
		Conns = {},
	}
	tracked[model] = s
	local function dirty()
		s.Dirty = true
	end
	table.insert(
		s.Conns,
		model.DescendantAdded:Connect(function(d)
			if d:IsA("JointInstance") or d:IsA("BasePart") or d:IsA("Animator") or d:IsA("Humanoid") then
				dirty()
			end
		end)
	)
	table.insert(
		s.Conns,
		model.DescendantRemoving:Connect(function(d)
			if d:IsA("JointInstance") or d:IsA("BasePart") then
				dirty()
			end
		end)
	)
	table.insert(
		s.Conns,
		model.AncestryChanged:Connect(function(_, parent)
			if not parent then
				Animator.Untrack(model)
			end
		end)
	)
	return s
end

function Animator.Untrack(model)
	local s = tracked[model]
	if not s then
		return
	end
	tracked[model] = nil
	for _, c in ipairs(s.Conns) do
		c:Disconnect()
	end
	if model.Parent then
		pcall(restore, s)
	end
end

-- mordida (o servidor manda para todos; o cliente do jogador também chama na hora do clique).
-- Repetida em menos de 0.2 s na mesma cabeça é a mesma mordida (não reinicia).
function Animator.PlayBite(model, head)
	local s = tracked[model]
	if not s then
		return
	end
	head = head or 1
	local now = os.clock()
	local last = s.Bites[head]
	if last and now - last.At < 0.2 then
		return
	end
	s.BiteVariant = s.BiteVariant % 3 + 1
	s.Bites[head] = { At = now, Variant = s.BiteVariant, Side = math.random() < 0.5 and -1 or 1 }
end

-- 🐾 golpe de perto do combo: step 1 = pata DIREITA, 2 = pata ESQUERDA, 3 = MORDIDA forte (bote maior).
-- isLocal = o próprio jogador clicou (toca na hora); o aviso do servidor para o mesmo cachorro logo depois é
-- ignorado (não toca duas vezes). Devolve true se tocou.
function Animator.PlayMelee(model, step, isLocal): boolean
	local s = tracked[model]
	if not s then
		return false
	end
	local now = os.clock()
	if isLocal then
		s.LocalMeleeAt = now
	elseif now - s.LocalMeleeAt < 0.45 then
		return false
	end
	if step == 3 then
		s.Bites[1] = { At = now, Variant = 1, Side = math.random() < 0.5 and -1 or 1, Big = true }
	else
		s.Swipes[step == 1 and 1 or -1] = { At = now }
	end
	return true
end

-- olhar (cliente do jogador, a cada quadro): ponto no mundo para onde a setinha do mouse aponta.
-- nil = volta ao olhar automático. Sem chamadas por meio segundo, também volta.
function Animator.SetLookAt(model, point: Vector3?)
	local s = tracked[model]
	if s then
		s.LookPoint = point
		s.LookPointAt = os.clock()
	end
end

-- esquiva (cliente do jogador): direção no mundo
-- forward = dash para a frente (o corpo vira para a direção dela): bote esticado em vez do pulinho de esquiva
function Animator.PlayDodge(model, worldDir: Vector3, forward: boolean?)
	local s = tracked[model]
	if not (s and s.Root) then
		return
	end
	local d = s.Root.CFrame:VectorToObjectSpace(worldDir)
	d = Vector3.new(d.X, 0, d.Z)
	s.DodgeDir = d.Magnitude > 0.01 and d.Unit or Vector3.new(0, 0, 1)
	s.DodgeForward = forward == true
	s.DodgeAt = os.clock()
end

-- PRÉVIA/TESTE: monta uma pose exata, sem física nem relógio (catálogo de poses e telas 3D).
-- opts: Speed (comprimentos de perna/s) · Phase (0..1) · Action + ActionT · VelY + AirT (no ar) · LandT ·
--       Behavior + BehaviorT · Posture ("Sit" | "Lie" | "Sleep") · Bite + BiteVariant · Hit · Dodge ·
--       Swim · Health (0..1) · Pant · Time · Look (Vector3: cima/baixo, lados, inclinar) · Excite (0..1) ·
--       voo (Action = "Fly"): FlySpeed (studs/s), FlyVelY, Yaw (giro, rad/s, > 0 = esquerda), Accel ·
--       patada: Swipe (s desde o golpe) + SwipeSide (1 = direita, -1 = esquerda) · BigBite (mordida final do combo) ·
--       DodgeForward (a esquiva vira o bote da dash) · Flying (poder usado parado no ar)
function Animator.PoseAt(model, opts)
	local s = Animator.Track(model, { UseC0 = true })
	refresh(s)
	local now = 1000 + (opts.Time or 0)
	s.Seed = 0
	s.S = model:GetAttribute("BaseScale") or 1
	s.LegLen = model:GetAttribute("LegLen") or model:GetAttribute("GroundHip") or 2
	s.Rel = opts.Speed or 0
	s.Speed = s.Rel * s.LegLen
	s.Accel, s.Yaw, s.Side, s.Back = opts.Accel or 0, opts.Yaw or 0, 0, false
	if opts.FlySpeed then
		s.Speed = opts.FlySpeed
	end
	s.Phase = opts.Phase or 0
	s.Health = opts.Health or 1
	s.Pant = opts.Pant or 0
	local look = opts.Look or Vector3.zero
	s.Twist = math.clamp(look.Y * 0.32, -TUNE.Look.Twist, TUNE.Look.Twist)
	s.LookPitch, s.LookYaw, s.LookTilt = look.X, math.clamp(look.Y - s.Twist, -TUNE.Look.Neck, TUNE.Look.Neck), look.Z
	s.Excite = opts.Excite or 0
	s.MoveW = s.Rel > TUNE.MoveAt and 1 or 0
	s.TurnW = 0
	s.Air = opts.VelY ~= nil
	s.VelY = opts.VelY or opts.FlyVelY or 0
	s.AirW = s.Air and 1 or 0
	s.AirSince = now - (opts.AirT or 0.3)
	s.TakeoffAt = -10
	s.LandAt = opts.LandT and now - opts.LandT or -10
	s.LandPower = 1
	s.SwimW = opts.Swim and 1 or 0
	s.Behavior = opts.Behavior
	s.BehaviorAt = now - (opts.BehaviorT or 0)
	s.BehaviorSide = 1
	s.SitW = opts.Posture == "Sit" and 1 or 0
	s.LieW = (opts.Posture == "Lie" or opts.Posture == "Sleep") and 1 or 0
	s.SleepW = opts.Posture == "Sleep" and 1 or 0
	s.Bites = {}
	if opts.Bite then
		s.Bites[1] = { At = now - opts.Bite, Variant = opts.BiteVariant or 1, Side = 1, Big = opts.BigBite }
	end
	s.Swipes = {}
	if opts.Swipe then
		s.Swipes[opts.SwipeSide or 1] = { At = now - opts.Swipe }
	end
	s.HitAt = opts.Hit and now - opts.Hit or -10
	s.HitPower, s.HitSide = 1, 1
	s.DodgeAt = opts.Dodge and now - opts.Dodge or -10
	s.DodgeDir = Vector3.new(1, 0, 0)
	s.DodgeForward = opts.DodgeForward == true
	model:SetAttribute("Flying", opts.Flying == true)
	model:SetAttribute("Action", opts.Action)
	s.LastAction = opts.Action
	s.ActionStart = now - (opts.ActionT or 0)
	local c = context(s, 1 / 60, now, true)
	gaitWeights(s, c, true)
	local P = buildPose(s, c)
	tailFinish(s, P, c)
	apply(s, c, P)
	earsFinish(s, c)
end

-- (testes: tools/preview/slide_test.py confere a pata plantada no apoio com estas contas)
Animator.Gait = { Shape = gaitShape, Phase = PHASE }

---------------------------------------------------------------- 10. LAÇO
function Animator.Start()
	CollectionService:GetInstanceAddedSignal("Dog"):Connect(function(model)
		Animator.Track(model)
	end)
	for _, model in ipairs(CollectionService:GetTagged("Dog")) do
		Animator.Track(model)
	end
	-- PreSimulation roda DEPOIS do passo de animação do Roblox (Animator do Humanoid) e antes da
	-- física: é o lugar documentado para escrever Motor6D.Transform.
	RunService.PreSimulation:Connect(function(dt)
		local now = os.clock()
		local player = Players.LocalPlayer
		local lod = LOD[player and player:GetAttribute("GraphicsQuality") or "Alto"] or LOD.Alto
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position
		for model, s in pairs(tracked) do
			if model.Parent and now >= (s.PausedUntil or 0) then
				local stepDt = dt
				if not s.UseC0 and camPos and s.Root and s.Root.Parent then
					-- distância ÷ tamanho: um chefão gigante continua animando de longe
					local dist = (s.Root.Position - camPos).Magnitude / math.max(1, s.S ^ 0.8)
					if dist > lod.Far then
						s.Acc = 0
						s.LastPos = nil
						stepDt = nil
					elseif dist > lod.Mid then
						s.Acc += dt
						s.Frame = (s.Frame + 1) % 3
						if s.Frame ~= 0 then
							stepDt = nil
						else
							stepDt = math.min(s.Acc, 0.2)
							s.Acc = 0
						end
					else
						s.Acc = 0
					end
				end
				if stepDt then
					local ok, err = pcall(step, s, stepDt, now)
					if not ok then
						s.Errors += 1
						if s.Errors == 1 or s.Errors % 100 == 0 then
							warn("[Animator] erro em", model:GetFullName(), "(" .. s.Errors .. "x):", err)
						end
						s.Dirty = true -- recoleta e tenta de novo no próximo quadro
						if s.Errors % 30 == 0 then
							s.PausedUntil = now + 1 -- erro persistente: respira 1 s e tenta de novo
						end
					else
						s.Errors = 0
					end
				end
			end
		end
	end)
end

return Animator
