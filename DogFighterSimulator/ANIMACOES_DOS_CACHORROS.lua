-- ANIMAÇÕES DOS CACHORROS (Dog Fighter Simulator) — tudo que anima os cachorros, junto (atualizado 2026-10).
-- Partes: client/Animator.lua (andar, correr, pular, pousar, voar de avião, olhar para a setinha, patadas, poses de luta), client/Systems/DogControl.lua (setinha do mouse, virar o corpo, voo de avião, câmera de voo), client/Systems/Abilities.lua (combo de patas e mordida, tiro na setinha, poderes na setinha, parafuso no ar)

--[[ ================================================================
     ARQUIVO: src/client/Animator.lua
================================================================ ]]
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
	Stride = { Walk = 1.25, Trot = 2.1, Gallop = 3.3 }, -- distância de um ciclo, em comprimentos de perna
	Duty = { Walk = 0.64, Trot = 0.5, Gallop = 0.4 }, -- parte do ciclo com a pata no chão
	Swing = { Walk = 0.36, Trot = 0.48, Gallop = 0.66 }, -- abertura da perna (rad)
	Cycle = { Min = 0.55, Max = 3.4, Turn = 1.8 }, -- ciclos por segundo
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
local NO_AIR_ACTIONS = { Fly = true, Float = true, Dive = true, Rear = true, Spin = true, KO = true, Vanish = true }
local STILL_ACTIONS = { KO = true, Sit = true, Eat = true, Howl = true, Aim = true, Open = true }

-- suavização de cada junta
local RATE = { Body = TUNE.Smooth.Body, Tail = TUNE.Smooth.Tail }
for _, leg in ipairs(LEGS) do
	RATE[leg] = TUNE.Smooth.Leg
	RATE[KNEE_OF[leg]] = TUNE.Smooth.Knee
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
	s.LegLen = math.max(0.5, (model:GetAttribute("GroundHip") or model:GetAttribute("HipHeight") or 2) * scaleNow)

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
	if (not action or action == "Dash") and model:GetAttribute("Flying") then
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
		at = now - (s.ActionStart or now),
		raging = model:GetAttribute("Raging") == true,
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

local function gaitWeights(s, c, instant)
	local rel = s.Rel
	local gallop = GALLOP_ACTIONS[c.action] and 1 or smooth01((rel - TUNE.GallopAt + 0.6) / 1.2)
	local trot = (1 - gallop) * smooth01((rel - TUNE.TrotAt + 0.4) / 0.8)
	local walk = 1 - gallop - trot
	local g = s.Gait
	local k = instant and 1 or damp(c.dt, 5)
	g.Walk += (walk - g.Walk) * k
	g.Trot += (trot - g.Trot) * k
	g.Gallop += (gallop - g.Gallop) * k
end

local function advancePhase(s, c)
	local g = s.Gait
	local stride = (TUNE.Stride.Walk * g.Walk + TUNE.Stride.Trot * g.Trot + TUNE.Stride.Gallop * g.Gallop) * s.LegLen
	local freq = math.clamp(s.Speed / math.max(0.1, stride), TUNE.Cycle.Min, TUNE.Cycle.Max)
	if s.TurnW > s.MoveW then
		freq = TUNE.Cycle.Turn
	end
	if c.raging then
		freq *= 0.8 -- fúria: passadas pesadas
	end
	local w = math.max(s.MoveW, s.TurnW)
	s.Phase = (s.Phase + c.dt * freq * w * (s.Back and -1 or 1)) % 1
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

-- escreve uma perna: com joelho dobra o joelho; sem joelho (robô, modelo antigo) sobe a perna inteira
local function setLeg(s, P, leg, ang, flex, S)
	local knee = KNEE_OF[leg]
	if s.Motors[knee] then
		local front = FRONT[leg]
		P[leg] = A(ang + 0.18 * flex)
		P[knee] = A(FLEX[leg] * flex * (front and 1.15 or 0.85) + (front and 0 or 0.06))
	else
		P[leg] = T(0, flex * 0.14 * S, 0) * A(ang)
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
	local scale = math.clamp(0.55 + s.Rel * 0.2, 0.55, 1.15)
	local hurt = s.Health < TUNE.LowHealth
	for _, leg in ipairs(LEGS) do
		local ang, flex = 0, 0
		for gait, w in pairs(g) do
			if w > 0.001 then
				local amp = TUNE.Swing[gait] * (gait == "Gallop" and 1 or scale)
				local a, f = legCycle(u + PHASE[gait][leg], TUNE.Duty[gait], amp)
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
		setLeg(s, P, leg, ang, flex, S)
	end
	-- corpo: sobe e desce com as patadas; o quadril e os ombros balançam de lado no passo; no trote quica;
	-- no galope a coluna "dobra e estica" (frente sobe quando as traseiras empurram)
	local W, Tr, G = g.Walk, g.Trot, g.Gallop
	local a1 = u * TAU
	local bob = (math.cos(a1 * 2) * (0.03 * W + 0.06 * Tr) + math.sin(a1) * 0.17 * G) * S
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
function ACTIONS.Dash(s, P, c)
	P.Body *= T(0, -0.06 * c.S, 0) * A(-0.1)
	for i = 1, 3 do
		mul(P, "Neck" .. i, A(-0.18))
	end
	P.TailX, P.TailY = -0.35, math.sin(c.t * 8) * 0.12
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
		c.fade = (ACTIONS[c.action] or genericAction)(s, P, c) or 0
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
	P.Tail = A(s.TailX, s.TailY, 0)
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
function Animator.PlayDodge(model, worldDir: Vector3)
	local s = tracked[model]
	if not (s and s.Root) then
		return
	end
	local d = s.Root.CFrame:VectorToObjectSpace(worldDir)
	d = Vector3.new(d.X, 0, d.Z)
	s.DodgeDir = d.Magnitude > 0.01 and d.Unit or Vector3.new(0, 0, 1)
	s.DodgeAt = os.clock()
end

-- PRÉVIA/TESTE: monta uma pose exata, sem física nem relógio (catálogo de poses e telas 3D).
-- opts: Speed (comprimentos de perna/s) · Phase (0..1) · Action + ActionT · VelY + AirT (no ar) · LandT ·
--       Behavior + BehaviorT · Posture ("Sit" | "Lie" | "Sleep") · Bite + BiteVariant · Hit · Dodge ·
--       Swim · Health (0..1) · Pant · Time · Look (Vector3: cima/baixo, lados, inclinar) · Excite (0..1) ·
--       voo (Action = "Fly"): FlySpeed (studs/s), FlyVelY, Yaw (giro, rad/s, > 0 = esquerda), Accel ·
--       patada: Swipe (s desde o golpe) + SwipeSide (1 = direita, -1 = esquerda) · BigBite (mordida final do combo)
function Animator.PoseAt(model, opts)
	local s = Animator.Track(model, { UseC0 = true })
	refresh(s)
	local now = 1000 + (opts.Time or 0)
	s.Seed = 0
	s.S = model:GetAttribute("BaseScale") or 1
	s.LegLen = model:GetAttribute("GroundHip") or 2
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

--[[ ================================================================
     ARQUIVO: src/client/Systems/DogControl.lua
================================================================ ]]
-- 🐶 O jogador é o cachorro. Quando o servidor assume (atributo AutoControl: indo para a Arena,
-- lutando sozinho, torre do boss), os controles de andar/pular ficam desligados.
--
-- 👀 SEM CÂMERA TRAVADA (pedido do dono, 2026-10): o mouse fica solto e o cachorro OLHA PARA A SETINHA —
-- a cabeça vai primeiro e o corpo torce junto (Animator.SetLookAt); parado, se a setinha vai muito para o
-- lado, ele vira o corpo inteiro até ela. Setinha em cima do próprio cachorro (parado) = ele olha para você.
-- Os outros jogadores veem para onde ele olha (remote LookAt → atributo "LookAt" do modelo).
-- Golpes (clique, 1, 2, 3, 4) viram o cachorro para a setinha e vão para lá (Abilities + servidor).
-- Celular/controle: não tem setinha; ele olha para onde a câmera aponta.
--
-- ✈️ VOO = AVIÃO (F ou botão FLY): vai sempre para a frente. PC: a setinha é o manche (para o lado = curva
-- inclinando o corpo, para cima/baixo = sobe/mergulha, no meio da tela = reto); A/D também fazem curva,
-- espaço sobe, C/Ctrl desce, W acelera, S freia, Shift = turbo, Q = parafuso. Celular/controle: o analógico
-- aponta para onde ir (o avião faz a curva até lá), pular sobe, câmera olhando para baixo desce, RUN = turbo.
-- Mergulhar ganha velocidade e subir perde (como avião); perto do chão ele empina sozinho para não bater.
-- Enquanto voa, a câmera vem para trás do cachorro sozinha (menos quando o jogador está girando a câmera).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))
local TouchPad = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("TouchPad"))
local Animator = require(script.Parent.Parent:WaitForChild("Animator"))

local DogControl = {}

local player = Players.LocalPlayer
local TAU = math.pi * 2

-- ✈️ voo: velocidade de cruzeiro = BaseSpeed × FLY_MULT (voo rápido, pedido do dono) e o jeito de avião
local FLY_MULT = 4
local FLY = {
	Slow = 0.22, -- S: devagar, quase parado no ar batendo as asas
	Cruise = 0.8, -- sem tecla
	Fast = 1.0, -- W (ou analógico empurrado)
	Boost = 1.45, -- Shift / RUN: turbo
	Accel = 1.5, -- quão rápido chega na velocidade pedida (por segundo)
	Turn = 2.1, -- curva máxima (rad/s); devagar a curva fica mais fechada
	PitchMax = 1.05, -- subida/mergulho mais forte (rad, ~60°)
	Bank = 0.42, -- inclinação do corpo por rad/s de curva
	BankMax = 1.15, -- inclinação máxima (~66°)
	Gravity = 0.45, -- mergulhar ganha velocidade, subir perde (fração do cruzeiro)
	Dead = 0.07, -- zona morta da setinha no meio da tela
	Roll = 0.55, -- duração do parafuso (s)
}

-- 🎯 a setinha: Point = para onde o cachorro olha; Hit = para onde os golpes vão (nil = a frente do cachorro,
-- por exemplo com a setinha em cima do próprio cachorro); Mouse = PC com mouse (senão celular/controle)
local aim = { Point = nil :: Vector3?, Hit = nil :: Vector3?, Mouse = false }
local faceUntil = 0 -- golpe: vira o corpo para a setinha até esta hora
local flyParts: any = nil -- voo ligado: LinearVelocity + AlignOrientation e o estado do avião

local function damp(dt, k)
	return 1 - math.exp(-k * dt)
end

local function wrap(a)
	return (a + math.pi) % TAU - math.pi
end

-- ângulo de giro (em volta do eixo vertical) de uma direção; igual ao CFrame.Angles(0, yaw, 0)
local function yawOf(v: Vector3)
	return math.atan2(-v.X, -v.Z)
end

-- Direção do cachorro até a setinha (PC). nil no celular/controle: o servidor usa a frente do cachorro.
function DogControl.AimDirection(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (aim.Mouse and aim.Hit and root and root:IsA("BasePart")) then
		return nil
	end
	local d = aim.Hit - root.Position
	if d.Magnitude < 0.5 then
		return nil
	end
	return d.Unit
end

-- Ponto da setinha no mundo (PC) — os poderes saem ali. nil no celular/controle (o poder sai na frente).
function DogControl.AimPoint(): Vector3?
	return aim.Mouse and aim.Hit or nil
end

-- Golpe: o cachorro vira para a setinha rapidinho (no chão; voando quem manda é o avião)
function DogControl.FaceAim()
	if aim.Mouse and aim.Hit then
		faceUntil = os.clock() + 0.3
	end
end

-- Esquiva no ar = parafuso de avião para o lado (side: -1 esquerda, 1 direita). false = não está voando.
function DogControl.BarrelRoll(side: number): boolean
	if not flyParts then
		return false
	end
	if not flyParts.RollAt or os.clock() - flyParts.RollAt > FLY.Roll then
		flyParts.RollAt = os.clock()
		flyParts.RollSide = side >= 0 and 1 or -1
	end
	return true
end

function DogControl.Start(HUD)
	local controls = nil
	local ok = pcall(function()
		local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
		if module then
			controls = (require(module :: any) :: any):GetControls()
		end
	end)
	if not ok or not controls then
		warn("[DogControl] PlayerModule não encontrado")
		return
	end
	local function apply()
		if player:GetAttribute("AutoControl") == true then
			controls:Disable()
		else
			controls:Enable()
		end
	end
	player:GetAttributeChangedSignal("AutoControl"):Connect(apply)
	player.CharacterAdded:Connect(function()
		task.defer(apply)
	end)
	apply()

	-- 🎥 câmera sempre no personagem (o cachorro), igual à de um jogador normal. O servidor troca o
	-- personagem (novo cachorro, renascer, torre) e a câmera ficava presa no modelo antigo.
	RunService:BindToRenderStep("DogCamera", Enum.RenderPriority.Camera.Value - 2, function()
		local camera = workspace.CurrentCamera
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not (camera and hum) or camera.CameraType ~= Enum.CameraType.Custom then
			return
		end
		local subject = camera.CameraSubject
		if subject == hum or (subject and subject.Name == "Visuals_FightFocus" and subject.Parent) then
			return
		end
		camera.CameraSubject = hum
	end)

	local playerGui = player:WaitForChild("PlayerGui")
	-- menu ou tela grande aberta: o cachorro só acompanha a setinha com a cabeça (não vira o corpo)
	local function modalOpen()
		if HUD.IsOpen() then
			return true
		end
		for _, name in ipairs({ "Hatch", "FirstTime" }) do
			local g = playerGui:FindFirstChild(name)
			if g and g:IsA("ScreenGui") and g.Enabled then
				return true
			end
		end
		return false
	end

	-- quem o jogador usou por último: mouse/teclado (a setinha manda) ou toque/controle (a câmera manda)
	local function mouseInput(t: Enum.UserInputType): boolean?
		if t == Enum.UserInputType.Touch or t.Name:sub(1, 7) == "Gamepad" then
			return false
		elseif
			t == Enum.UserInputType.MouseMovement
			or t == Enum.UserInputType.MouseButton1
			or t == Enum.UserInputType.MouseButton2
			or t == Enum.UserInputType.MouseWheel
			or t == Enum.UserInputType.Keyboard
		then
			return UserInputService.MouseEnabled
		end
		return nil
	end
	local first = mouseInput(UserInputService:GetLastInputType())
	if first == nil then
		first = UserInputService.MouseEnabled and not Kit.IsTouch()
	end
	aim.Mouse = first == true
	UserInputService.LastInputTypeChanged:Connect(function(t)
		local m = mouseInput(t)
		if m ~= nil then
			aim.Mouse = m
		end
	end)

	-- o jogador está girando a câmera? (botão direito do mouse, dedo arrastando a tela, analógico direito)
	-- Enquanto gira, a câmera de avião não puxa a câmera para trás do cachorro.
	local lastManualCam = 0
	local panTouches = {}
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch and not processed then
			panTouches[input] = true
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			lastManualCam = os.clock()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		panTouches[input] = nil
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			(input.UserInputType == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2))
			or panTouches[input]
			or (input.KeyCode == Enum.KeyCode.Thumbstick2 and input.Position.Magnitude > 0.25)
		then
			lastManualCam = os.clock()
		end
	end)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local function ignoreList(character)
		local list = { character }
		local fx = workspace:FindFirstChild("DogFX")
		if fx then
			table.insert(list, fx)
		end
		return list
	end

	-- 👀 manda para o servidor para onde o cachorro olha (todo mundo vê): até ~7x por segundo, só se mudou
	local lookRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("LookAt")
	local lastSent, lastSentPoint = 0, nil
	local function sendLook(root: BasePart, point: Vector3)
		local now = os.clock()
		if not lookRemote or now - lastSent < 0.15 then
			return
		end
		if lastSentPoint then
			local a, b = lastSentPoint - root.Position, point - root.Position
			if a.Magnitude > 0.5 and b.Magnitude > 0.5 and a.Unit:Dot(b.Unit) > 0.9985 then
				return -- mudou menos de 3°
			end
		end
		lastSent, lastSentPoint = now, point
		lookRemote:FireServer(point)
	end

	-- gira o HumanoidRootPart em volta do eixo vertical, no máximo `maxStep` rad; devolve o que faltou
	local function turnToward(root: BasePart, goalYaw: number, maxStep: number): number
		local cur = yawOf(root.CFrame.LookVector)
		local err = wrap(goalYaw - cur)
		local step = math.clamp(err, -maxStep, maxStep)
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, cur + step, 0)
		return err - step
	end

	local turning = false
	local autoRotateOff = false
	local function restoreAutoRotate(hum)
		if autoRotateOff then
			autoRotateOff = false
			if hum and hum.Parent then
				hum.AutoRotate = true
			end
		end
	end
	-- depois da câmera do Roblox (Camera + 1): a câmera já está no lugar deste quadro
	RunService:BindToRenderStep("DogLook", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		local now = os.clock()
		-- ✈️ câmera de avião: vem para trás do cachorro sozinha (se o jogador não está girando a câmera)
		if
			flyParts
			and camera
			and hum
			and camera.CameraType == Enum.CameraType.Custom
			and camera.CameraSubject == hum
			and now - lastManualCam > 1.2
		then
			local cf = camera.CFrame
			local focus = camera.Focus.Position
			local step = wrap(flyParts.Yaw - yawOf(cf.LookVector)) * damp(dt, 2.2)
			camera.CFrame = CFrame.new(focus) * CFrame.Angles(0, step, 0) * CFrame.new(-focus) * cf
		end
		if
			not (hum and root and root:IsA("BasePart") and camera and character:GetAttribute("Kind") == "player" and hum.Health > 0)
			or player:GetAttribute("AutoControl")
		then
			aim.Point, aim.Hit = nil, nil
			turning = false
			restoreAutoRotate(hum)
			return
		end
		-- 👀 o ponto: debaixo da setinha (PC) ou no meio da câmera (celular/controle)
		local origin, dir
		if aim.Mouse then
			local m = UserInputService:GetMouseLocation()
			local ray = camera:ViewportPointToRay(m.X, m.Y)
			origin, dir = ray.Origin, ray.Direction
		else
			origin, dir = camera.CFrame.Position, camera.CFrame.LookVector
		end
		rayParams.FilterDescendantsInstances = ignoreList(character)
		local hit = workspace:Raycast(origin, dir * 700, rayParams)
		local point = hit and hit.Position or (origin + dir * 350)
		local idle = hum.MoveDirection.Magnitude < 0.1 and not flyParts
		-- setinha em cima do próprio cachorro (parado): ele olha para você
		local lookAtYou = false
		if aim.Mouse and idle then
			local toDog = root.Position - origin
			local along = toDog:Dot(dir)
			local miss = (toDog - dir * along).Magnitude
			local size = math.max(root.Size.X, root.Size.Y, root.Size.Z)
			-- (câmera bem perto/dentro do cachorro, em primeira pessoa, não conta)
			if along > size * 1.5 and miss < size * 0.7 and (not hit or (hit.Position - origin).Magnitude > along * 0.9) then
				point = camera.CFrame.Position
				lookAtYou = true
			end
		end
		aim.Point = point
		aim.Hit = not lookAtYou and point or nil
		Animator.SetLookAt(character, point)
		sendLook(root, point)
		-- 🐕 o corpo vira para a setinha: golpe = rápido; parado = quando a setinha vai muito para o lado
		local flat = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
		if flyParts or flat.Magnitude < 1 then
			turning = false
			restoreAutoRotate(hum)
			return
		end
		local goal = yawOf(flat)
		if now < faceUntil and not lookAtYou then
			if not autoRotateOff then
				autoRotateOff = true
				hum.AutoRotate = false
			end
			turnToward(root, goal, 16 * dt)
			return
		end
		restoreAutoRotate(hum)
		if not (aim.Mouse and idle) or lookAtYou or modalOpen() then
			turning = false
			return
		end
		local err = math.abs(wrap(goal - yawOf(root.CFrame.LookVector)))
		if not turning and err > 1.2 then
			turning = true
		end
		if turning then
			-- vira com passinhos (o Animator vê o giro e mexe as patas), mais devagar no fim
			local left = turnToward(root, goal, (1.2 + 4.3 * math.clamp(err / 1.2, 0, 1)) * dt)
			if math.abs(left) < 0.12 then
				turning = false
			end
		end
	end)

	-- ✈️ VOO DE AVIÃO (atributo Flying, ligado pelo servidor com F). LinearVelocity leva para a frente e o
	-- AlignOrientation inclina o corpo inteiro (curva, subida, mergulho, parafuso); Humanoid em PlatformStand.
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	groundParams.IgnoreWater = false -- voando baixo no mar: a água conta como chão
	local function stopFlying()
		if flyParts then
			local root, yaw = flyParts.Root, flyParts.Yaw
			for _, inst in ipairs(flyParts.List) do
				inst:Destroy()
			end
			if flyParts.Hum.Parent then
				flyParts.Hum.PlatformStand = false
			end
			-- desce de pé (sem a inclinação da curva), virado para onde voava
			if root.Parent then
				root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
			end
			flyParts = nil
		end
	end

	-- setinha em cima de um botão: não pilota (o jogador vai clicar nele)
	local buttonCheckAt, buttonHover = 0, false
	local function overButton(m: Vector2): boolean
		local now = os.clock()
		if now - buttonCheckAt < 0.1 then
			return buttonHover
		end
		buttonCheckAt = now
		buttonHover = false
		local inset = GuiService:GetGuiInset()
		local okList, list = pcall(playerGui.GetGuiObjectsAtPosition, playerGui, m.X - inset.X, m.Y - inset.Y)
		if okList then
			for _, g in ipairs(list) do
				if g:IsA("GuiButton") and g.Visible then
					buttonHover = true
					break
				end
			end
		end
		return buttonHover
	end
	-- a setinha como manche: distância do meio da tela → (-1..1 lado, -1..1 cima)
	local function mouseStick(camera: Camera): (number, number)
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			return 0, 0 -- girando a câmera
		end
		local m = UserInputService:GetMouseLocation()
		if overButton(m) then
			return 0, 0
		end
		local vs = camera.ViewportSize
		local function shape(v)
			local a = math.abs(v)
			if a < FLY.Dead then
				return 0
			end
			return math.sign(v) * math.min(1, (a - FLY.Dead) / (1 - FLY.Dead))
		end
		return shape((m.X - vs.X / 2) / (vs.X * 0.32)), shape((vs.Y / 2 - m.Y) / (vs.Y * 0.32))
	end

	RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local flying = player:GetAttribute("Flying") == true
			and hum ~= nil
			and root ~= nil
			and root:IsA("BasePart")
			and character:GetAttribute("Kind") == "player"
			and not player:GetAttribute("AutoControl")
			and hum.Health > 0
		if not flying then
			stopFlying()
			return
		end
		if flyParts and flyParts.Root ~= root then
			stopFlying()
		end
		local now = os.clock()
		local base = character:GetAttribute("BaseSpeed") or 16
		local cruise = base * FLY_MULT
		if not flyParts then
			-- decolagem: sai para onde estava virado, de nariz para cima
			local att = Instance.new("Attachment")
			att.Name = "FlyAtt"
			att.Parent = root
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Fly"
			lv.Attachment0 = att
			lv.RelativeTo = Enum.ActuatorRelativeTo.World
			lv.MaxForce = 1e7
			lv.VectorVelocity = Vector3.new(0, 38, 0)
			lv.Parent = root
			local ao = Instance.new("AlignOrientation")
			ao.Name = "FlyTilt"
			ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
			ao.Attachment0 = att
			ao.MaxTorque = 1e7
			ao.Responsiveness = 25
			ao.CFrame = root.CFrame.Rotation
			ao.Parent = root
			hum.PlatformStand = true
			local v = root.AssemblyLinearVelocity
			flyParts = {
				Root = root,
				Hum = hum,
				Lv = lv,
				Ao = ao,
				List = { lv, ao, att },
				Yaw = yawOf(root.CFrame.LookVector),
				Pitch = 0.6,
				Bank = 0,
				YawRate = 0,
				Speed = math.max(cruise * 0.5, Vector3.new(v.X, 0, v.Z).Magnitude),
				Start = now,
			}
		end
		local F = flyParts
		local camera = workspace.CurrentCamera
		local mv = controls:GetMoveVector() -- relativo à câmera (X lado, Z frente negativa)
		local typing = UserInputService:GetFocusedTextBox() ~= nil
		local function key(k)
			return not typing and UserInputService:IsKeyDown(k)
		end
		-- comandos: turn (> 0 = direita), pitch (-1 desce .. 1 sobe), forward (W/S ou analógico)
		local turn, pitch, forward = 0, 0, -mv.Z
		if aim.Mouse and camera then
			local sx, sy = mouseStick(camera)
			turn, pitch = sx + mv.X, sy
		elseif camera then
			-- analógico: aponta para onde ir (relativo à câmera) e o avião faz a curva até lá
			if mv.Magnitude > 0.15 then
				local want = camera.CFrame:VectorToWorldSpace(Vector3.new(mv.X, 0, mv.Z))
				want = Vector3.new(want.X, 0, want.Z)
				if want.Magnitude > 0.01 then
					turn = -wrap(yawOf(want) - F.Yaw) * 1.3
				end
			end
			forward = mv.Magnitude
			-- câmera olhando um pouco para baixo (o normal) = reto; mais para baixo = mergulha; para cima = sobe
			pitch = (camera.CFrame.LookVector.Y + 0.35) * 2.2
			if math.abs(pitch) < 0.12 then
				pitch = 0
			end
		end
		if key(Enum.KeyCode.Space) or hum.Jump then
			pitch += 1
		end
		if key(Enum.KeyCode.C) or key(Enum.KeyCode.LeftControl) then
			pitch -= 1
		end
		turn = math.clamp(turn, -1, 1)
		pitch = math.clamp(pitch, -1, 1)
		-- velocidade pedida: W acelera, S freia, Shift/RUN = turbo (o Sprint deixa o WalkSpeed maior)
		local boost = hum.WalkSpeed > base * 1.2
		local throttle = forward < -0.3 and FLY.Slow or ((boost and FLY.Boost) or (forward > 0.3 and FLY.Fast) or FLY.Cruise)
		local v = F.Speed / cruise
		-- curva (devagar fica mais fechada, quase um helicóptero)
		local yawRateGoal = -turn * FLY.Turn * (1 + 0.8 * math.max(0, 1 - v))
		F.YawRate += (yawRateGoal - F.YawRate) * damp(dt, 6)
		F.Yaw = wrap(F.Yaw + F.YawRate * dt)
		-- subida/mergulho
		local pitchGoal = pitch * FLY.PitchMax
		local t = now - F.Start
		if t < 0.7 then
			pitchGoal = math.max(pitchGoal, 0.6 * (1 - t / 0.7)) -- decolagem
		end
		-- perto do chão (ou da água) não deixa bater: empina sozinho
		groundParams.FilterDescendantsInstances = ignoreList(character)
		local clearance = (character:GetAttribute("GroundHip") or 2) + root.Size.Y / 2
		local pitchRate = 3
		local below = workspace:Raycast(root.Position, Vector3.new(0, -(clearance + 8), 0), groundParams)
		if below then
			local h = root.Position.Y - below.Position.Y - clearance
			pitchGoal = math.max(pitchGoal, -0.15 + 0.45 * math.clamp(1 - h / 6, 0, 1))
		end
		local going = F.Lv.VectorVelocity
		if going.Magnitude > 1 then
			local ahead = workspace:Raycast(root.Position, going * 0.7, groundParams)
			if ahead and ahead.Normal.Y > 0.4 then
				pitchGoal = math.max(pitchGoal, 0.35) -- vai bater no chão: puxa o nariz para cima
				pitchRate = 7
			end
		end
		F.Pitch += (pitchGoal - F.Pitch) * damp(dt, pitchRate)
		-- velocidade: mergulho acelera, subida freia
		local speedGoal = cruise * (throttle - FLY.Gravity * math.sin(F.Pitch))
		F.Speed += (speedGoal - F.Speed) * damp(dt, FLY.Accel)
		F.Speed = math.max(F.Speed, cruise * 0.15)
		-- inclinação de curva (mais rápido = inclina mais)
		local bankGoal = math.clamp(F.YawRate * FLY.Bank * (0.6 + 0.6 * math.min(v, 1.4)), -FLY.BankMax, FLY.BankMax)
		F.Bank += (bankGoal - F.Bank) * damp(dt, 5)
		-- parafuso (Q no ar): uma volta inteira de lado + um empurrão para o lado
		local orient = CFrame.Angles(0, F.Yaw, 0) * CFrame.Angles(F.Pitch, 0, 0)
		local roll, slide = 0, Vector3.zero
		if F.RollAt then
			local rt = (now - F.RollAt) / FLY.Roll
			if rt >= 1 then
				F.RollAt = nil
			else
				roll = -F.RollSide * TAU * rt * rt * (3 - 2 * rt)
				slide = orient.RightVector * F.RollSide * cruise * 0.7 * math.sin(rt * math.pi)
			end
		end
		F.Ao.Responsiveness = F.RollAt and 120 or 25
		F.Ao.CFrame = orient * CFrame.Angles(0, 0, F.Bank + roll)
		local vel = orient.LookVector * F.Speed + slide
		if t < 0.6 then
			vel += Vector3.new(0, 30 * (1 - t / 0.6), 0) -- decolagem: pulo para cima
		end
		F.Lv.VectorVelocity = vel
	end)
	player:GetAttributeChangedSignal("Flying"):Connect(function()
		if not player:GetAttribute("Flying") then
			stopFlying()
		end
	end)

	-- 🧍 Z (ou botão no celular): pessoa ⇄ cachorro
	local function toggleHuman()
		ReplicatedStorage.Remotes.ToggleHuman:FireServer()
	end
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Z and not UserInputService:GetFocusedTextBox() then
			toggleHuman()
		end
	end)
	-- celular: botão redondo no TouchPad (em volta do pulo)
	local humanButton = TouchPad.Add("Human", { Icon = "🧍", Icon3D = "person", Label = "HUMAN", Color = Kit.C.Blue, Order = 2 }, toggleHuman)
	local function refreshHuman()
		local human = player:GetAttribute("HumanMode") == true
		humanButton.Set({ Icon = human and "🐶" or "🧍", Icon3D = human and "dog" or "person", Label = human and "DOG" or "HUMAN" })
	end
	player:GetAttributeChangedSignal("HumanMode"):Connect(refreshHuman)
	refreshHuman()

	-- 🪽 F (ou botão FLY no celular): cachorro com asas voa / pousa (pedido do dono; antes era espaço 2x,
	-- que brigava com o espaço de subir voando)
	local function canFly()
		local character = player.Character
		return character ~= nil and character:GetAttribute("Wings") == true and character:GetAttribute("Kind") == "player"
	end
	local function toggleFly()
		if canFly() and not player:GetAttribute("AutoControl") then
			ReplicatedStorage.Remotes.ToggleFly:FireServer()
		end
	end
	UserInputService.InputBegan:Connect(function(input)
		if (input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR1) and not UserInputService:GetFocusedTextBox() then
			toggleFly()
		end
	end)
	local flyButton = TouchPad.Add("Fly", { Icon = "🦅", Icon3D = "wing", Label = "FLY", Color = Kit.C.Purple, Order = 4 }, toggleFly)
	flyButton.SetVisible(false)
	if Kit.IsTouch() then
		RunService.Heartbeat:Connect(function()
			local flying = player:GetAttribute("Flying") == true
			flyButton.SetVisible(canFly())
			flyButton.Set({ Label = flying and "LAND" or "FLY", Active = flying })
		end)
	end
end

return DogControl

--[[ ================================================================
     ARQUIVO: src/client/Systems/Abilities.lua
================================================================ ]]
-- 🐾 Barra de habilidades (embaixo, no meio): 1 = Mordida (ou tiro pela boca dos atiradores), 2 = Poder da espécie, 3 = Poder do tipo,
-- Q = Esquiva (impulso no cliente + invencibilidade curta no servidor), 4 = SUPREMO (só Míticos).
-- Visual do HUD novo (estilo A escuro): botões redondos com o ícone 3D do golpe (Icons3D: fogo, gelo, raio...),
-- recarga em "pizza" escura que vai abrindo, tecla no canto (PC) e o nome embaixo.
-- PC: clique ou teclas 1/2/3/Q. Controle: X / Y / B / L1. Celular: botões redondos.
-- Quem decide alvo, dano e recarga é o servidor (remote UseAbility; recargas nos atributos CD1/CD2).
-- A mordida e a esquiva também tocam a animação NA HORA neste cliente (Animator), sem esperar o servidor.
-- 🎯 PC: o golpe vai para onde a SETINHA aponta (o cachorro vira para ela e a direção vai junto no UseAbility).
-- 🐾 1 de quem não atira = combo pata DIREITA → pata ESQUERDA → MORDIDA (toca na hora; o servidor confere).
-- ✨ Poderes (2, 3, 4) saem no ponto da setinha, mesmo sem inimigo (o ponto vai junto no UseAbility).
-- ✈️ Voando: Q = parafuso de avião (DogControl.BarrelRoll) e a mordida não dá o bote para a frente.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Icons3D = require(UI:WaitForChild("Icons3D"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))
local Animator = require(script.Parent.Parent:WaitForChild("Animator"))
local DogControl = require(script.Parent:WaitForChild("DogControl"))
local Effects = require(script.Parent.Parent:WaitForChild("Effects"))

local Abilities = {}
local make = Kit.make
local player = Players.LocalPlayer

local INK = Color3.fromRGB(27, 20, 48)
local LUCKY = Enum.Font.LuckiestGuy

local function inkStroke(parent, thickness)
	return make("UIStroke", {
		Color = INK,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, parent)
end

-- texto com contorno escuro; maxSize > 0 = encolhe para caber (nomes de golpe compridos)
local function label(parent, text, size, props, maxSize)
	local l = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = LUCKY,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = size,
		TextScaled = maxSize ~= nil,
	}, parent)
	for k, v in pairs(props) do
		l[k] = v
	end
	if maxSize then
		make("UITextSizeConstraint", { MaxTextSize = maxSize }, l)
	end
	make("UIStroke", { Color = INK, Thickness = math.max(1.5, size * 0.17), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, l)
	return l
end

-- recarga em "pizza": duas metades com degradê de corte girando. set(f): f = parte escura (1 = tudo, 0 = livre)
local function pie(parent)
	local holder = make("Frame", { Name = "Pie", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 5 }, parent)
	local cuts = {}
	for _, sideName in ipairs({ "L", "R" }) do
		local clip = make("Frame", {
			Name = sideName,
			Position = UDim2.fromScale(sideName == "L" and 0 or 0.5, 0),
			Size = UDim2.fromScale(0.5, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = 5,
		}, holder)
		local disc = make("Frame", {
			Position = UDim2.fromScale(sideName == "L" and 0 or -1, 0),
			Size = UDim2.fromScale(2, 1),
			BackgroundColor3 = Color3.fromRGB(15, 10, 30),
			BackgroundTransparency = 0.28,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, clip)
		Kit.Corner(disc, 999)
		cuts[sideName] = make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.499, 0),
				NumberSequenceKeypoint.new(0.5, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, disc)
	end
	return function(f)
		f = math.clamp(f, 0, 1)
		holder.Visible = f > 0.002
		-- ângulo já liberado (horário, a partir das 12h): metade direita primeiro, depois a esquerda
		local a = 360 * (1 - f)
		if a <= 180 then
			cuts.R.Rotation = 180 + a
			cuts.L.Rotation = 0
		else
			cuts.R.Rotation = 0
			cuts.L.Rotation = a - 180
		end
	end
end

function Abilities.Start(HUD)
	local touch = Kit.IsTouch()
	-- medidas da prévia: PC botão 67 / nome 12; celular botão 88 / nome 17 (pixels de design)
	local SIZE = touch and 88 or 67
	local GAP = touch and 16 or 14
	local LABEL = touch and 17 or 12
	local BOTTOM = touch and 10 or 14
	local gui, root = Kit.Screen("Abilities", 7)
	local bar = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM), -- embaixo, no meio (pedido do dono)
		Size = UDim2.fromOffset(SIZE * 5 + GAP * 4, SIZE + LABEL + 8),
		BackgroundTransparency = 1,
	}, root)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, GAP),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bar)

	-- impulso de verdade: o Humanoid freia o AssemblyLinearVelocity no mesmo quadro, então usamos uma
	-- LinearVelocity por um instante (a física do personagem é deste cliente)
	local function burst(root, velocity, duration)
		local att = Instance.new("Attachment")
		att.Name = "BurstAtt"
		att.Parent = root
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Burst"
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.MaxForce = 1e7
		lv.VectorVelocity = velocity
		lv.Parent = root
		task.delay(duration, function()
			lv:Destroy()
			att:Destroy()
		end)
	end

	local busy = {}
	local rollSide = 1
	-- 🐾 combo de perto (mesma conta do servidor): 1 = pata direita, 2 = pata esquerda, 3 = mordida
	local comboStep, comboAt = 0, -10
	local function dodgeImpulse()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and hum) or player:GetAttribute("AutoControl") then
			return false
		end
		if (player:GetAttribute("CD4") or 0) > workspace:GetServerTimeNow() then
			return false
		end
		-- ✈️ voando: parafuso de avião para o lado da tecla A/D (sem tecla: alterna os lados)
		if player:GetAttribute("Flying") then
			local typing = UserInputService:GetFocusedTextBox() ~= nil
			if not typing and UserInputService:IsKeyDown(Enum.KeyCode.D) then
				rollSide = 1
			elseif not typing and UserInputService:IsKeyDown(Enum.KeyCode.A) then
				rollSide = -1
			else
				rollSide = -rollSide
			end
			if DogControl.BarrelRoll(rollSide) then
				Animator.PlayDodge(character, root.CFrame.RightVector * rollSide)
				return true
			end
		end
		local dir = hum.MoveDirection
		if dir.Magnitude < 0.1 then
			dir = -root.CFrame.LookVector -- parado: pulo para trás
		end
		dir = Vector3.new(dir.X, 0, dir.Z).Unit
		burst(root, dir * 70, 0.22)
		Animator.PlayDodge(character, dir)
		return true
	end
	local function use(slot)
		if busy[slot] then
			return
		end
		if slot == 4 and not dodgeImpulse() then
			return
		end
		-- 🎯 PC: mira na setinha (o cachorro vira para ela agora; o servidor escolhe o alvo naquela direção)
		local aimDir = nil
		if slot ~= 4 and not player:GetAttribute("AutoControl") then
			aimDir = DogControl.AimDirection()
			if aimDir then
				DogControl.FaceAim()
			end
		end
		-- mordida: pequeno bote para a frente (sensação de golpe); tiro pela boca: só abre a boca
		-- (o tiro em si vem do servidor, efeito "MouthShot"). Voando não tem bote (quem empurra é o voo).
		if slot == 1 and (player:GetAttribute("CD1") or 0) <= workspace:GetServerTimeNow() then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and not player:GetAttribute("AutoControl") then
				local look = aimDir or root.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				if DogData.ShotFor(character:GetAttribute("Species")) then
					Animator.PlayBite(character, 1) -- atirador: só abre a boca
				else
					local now = os.clock()
					comboStep = now - comboAt <= Config.MELEE_COMBO_WINDOW and comboStep % 3 + 1 or 1
					comboAt = now
					Effects.Melee(character, comboStep, 1, true)
					if flat.Magnitude > 0.01 and not player:GetAttribute("Flying") then
						burst(root, flat.Unit * (comboStep == 3 and 30 or 14), 0.12)
					end
				end
			end
		end
		busy[slot] = true
		task.spawn(function()
			local ok, message = Net.Invoke("UseAbility", slot, aimDir, slot ~= 1 and slot ~= 4 and DogControl.AimPoint() or nil)
			busy[slot] = nil
			if not ok and type(message) == "string" and message ~= "" then
				HUD.Toast(message, "red")
			end
		end)
	end

	local slots = {}
	local function paintSlot(slot, iconName)
		local c1, c2 = Icons3D.Colors(iconName)
		slot.Colors = { c1, c2 }
		slot.Gradient.Color = ColorSequence.new(c1, c2)
		Icons3D.Set(slot.Icon, iconName)
	end
	local function slotButton(i, key, iconName, name)
		local holder = make("Frame", { Name = "Slot" .. i, LayoutOrder = i, Size = UDim2.fromOffset(SIZE, SIZE + LABEL + 8), BackgroundTransparency = 1 }, bar)
		local pop = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(SIZE / 2, SIZE / 2),
			Size = UDim2.fromOffset(SIZE, SIZE),
			BackgroundTransparency = 1,
		}, holder)
		local popScale = make("UIScale", {}, pop)
		local shadow = make("Frame", {
			Position = UDim2.fromOffset(0, 4),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, pop)
		Kit.Corner(shadow, 999)
		inkStroke(shadow)
		local button = make("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 2,
		}, pop)
		Kit.Corner(button, 999)
		local stroke = inkStroke(button)
		local gradient = make("UIGradient", { Rotation = 90 }, button)
		local icon = Icons3D.Make(button, iconName, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.48),
			Size = UDim2.fromScale(0.76, 0.76),
			ZIndex = 3,
		})
		local setPie = pie(button)
		local cdText = label(button, "", math.floor(SIZE * 0.32), {
			Size = UDim2.fromScale(1, 1),
			ZIndex = 6,
		})
		if not touch then
			local keyChip = make("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, 5, 1, 3),
				Size = UDim2.fromOffset(23, 23),
				BackgroundColor3 = Color3.fromRGB(42, 34, 68),
				BorderSizePixel = 0,
				ZIndex = 7,
			}, button)
			Kit.Corner(keyChip, 7)
			inkStroke(keyChip, 2)
			label(keyChip, key, 12, { Size = UDim2.fromScale(1, 1), ZIndex = 8 })
		end
		local nameLabel = label(holder, name, LABEL, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, SIZE + 5),
			Size = UDim2.fromOffset(SIZE + GAP, LABEL + 2),
		}, LABEL)
		button.MouseButton1Down:Connect(function()
			Kit.Tween(popScale, 0.06, { Scale = 0.9 })
		end)
		button.InputEnded:Connect(function()
			Kit.Tween(popScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
		button.Activated:Connect(function()
			use(i)
		end)
		local slot = { Holder = holder, Button = button, Icon = icon, Gradient = gradient, Stroke = stroke, SetPie = setPie, CdText = cdText, Label = nameLabel }
		slots[i] = slot
		paintSlot(slot, iconName)
		return slot
	end
	slotButton(1, "1", "fang", "ATTACK")
	slotButton(2, "2", "star", "POWER")
	slotButton(3, "3", "bolt", "POWER")
	slotButton(4, "Q", "wind", "DODGE")
	slotButton(5, "4", "crown", "SUPREME") -- 👑 SUPREMO (só Míticos): enche batendo
	slots[4].Holder.LayoutOrder = 6 -- esquiva por último; o Supremo (5) fica entre o 3 e ela
	-- ✈️ dica do voo de avião (PC, só enquanto voa). Antes aqui ficava o "CTRL = free the mouse" da câmera
	-- travada, que saiu (o mouse agora é sempre livre e o cachorro olha para a setinha).
	local flyHint = nil
	if not touch then
		flyHint = label(root, "✈️ MOUSE = steer · W/S = speed · SHIFT = boost · Q = barrel roll · F = land", 11, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -(BOTTOM + SIZE + LABEL + 10)),
			Size = UDim2.fromOffset(520, 16),
			Font = Enum.Font.FredokaOne,
			TextColor3 = Color3.fromRGB(201, 193, 230),
			Visible = false,
		})
	end

	local lastSpecies = nil
	local function refreshDog()
		local character = player.Character
		local isDog = character ~= nil and character:GetAttribute("Kind") == "player"
		gui.Enabled = isDog
		local speciesId = isDog and character:GetAttribute("Species") or nil
		if speciesId == lastSpecies then
			return
		end
		lastSpecies = speciesId
		local species = speciesId and DogData.Species[speciesId]
		-- 1 = ATTACK (pata direita, pata esquerda, mordida) ou o tiro pela boca dos atiradores (vai bem longe)
		local shotName, shot = DogData.ShotFor(speciesId)
		paintSlot(slots[1], shotName and Icons3D.ForShot(shotName) or "fang")
		slots[1].Label.Text = shot and string.upper(shot.Name) or "ATTACK"
		local pw = species and DogData.PowersFor(speciesId)
		local sp = pw and DogData.Specials[pw[1]]
		paintSlot(slots[2], Icons3D.ForPower(pw and pw[1], sp))
		slots[2].Label.Text = sp and string.upper(sp.Name) or "POWER"
		slots[5].Holder.Visible = species ~= nil and Config.HasSupreme(species.Rarity)
		local third = speciesId and DogData.ThirdPower(speciesId)
		local sp3 = third and DogData.Specials[third]
		paintSlot(slots[3], Icons3D.ForPower(third, sp3))
		slots[3].Label.Text = string.upper(sp3 and sp3.Name or (third and third:gsub("(%l)(%u)", "%1 %2") or "POWER"))
	end

	RunService.Heartbeat:Connect(function()
		refreshDog()
		if not gui.Enabled then
			return
		end
		if flyHint then
			flyHint.Visible = player:GetAttribute("Flying") == true
		end
		local now = workspace:GetServerTimeNow()
		local auto = player:GetAttribute("AutoControl") == true
		-- 👑 Supremo: a pizza escura vai abrindo enquanto carrega; cheio = brilha
		do
			local s = slots[5]
			local charge = player:GetAttribute("Supreme") or 0
			s.SetPie(1 - charge / 100)
			s.CdText.Text = charge < 100 and (tostring(math.floor(charge)) .. "%") or ""
			if charge >= 100 then
				local k = (math.sin(os.clock() * 8) + 1) * 0.2
				local white = Color3.new(1, 1, 1)
				s.Gradient.Color = ColorSequence.new(s.Colors[1]:Lerp(white, k), s.Colors[2]:Lerp(white, k))
				s.Stroke.Color = INK:Lerp(white, k * 2)
			elseif s.Stroke.Color ~= INK then
				s.Gradient.Color = ColorSequence.new(s.Colors[1], s.Colors[2])
				s.Stroke.Color = INK
			end
		end
		for i = 1, 4 do
			local s = slots[i]
			local endsAt = player:GetAttribute("CD" .. i) or 0
			local left = endsAt - now
			-- duração total = o que faltava quando a recarga começou
			if s.EndsAt ~= endsAt then
				s.EndsAt = endsAt
				s.Total = math.max(0.3, left)
			end
			local total = s.Total or 1
			if left > 0 then
				s.SetPie(left / total)
				s.CdText.Text = left >= 1 and (tostring(math.ceil(left)) .. "s") or ""
			else
				s.SetPie(auto and 1 or 0)
				s.CdText.Text = ""
			end
		end
	end)

	-- a barra de itens do Roblox usa as teclas 1–9 (e marca o aperto como "processado"): o jogo não usa
	-- ferramentas, então ela fica desligada e as teclas valem mesmo "processadas" (menos digitando no chat)
	task.spawn(function()
		for _ = 1, 10 do
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
				break
			end
			task.wait(1)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not gui.Enabled or UserInputService:GetFocusedTextBox() then
			return
		end
		if processed and input.UserInputType ~= Enum.UserInputType.Keyboard and input.UserInputType ~= Enum.UserInputType.Gamepad1 then
			return
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.One or k == Enum.KeyCode.ButtonX then
			use(1)
		elseif k == Enum.KeyCode.Two or k == Enum.KeyCode.ButtonY then
			use(2)
		elseif k == Enum.KeyCode.Three or k == Enum.KeyCode.ButtonB then
			use(3)
		elseif k == Enum.KeyCode.Q or k == Enum.KeyCode.ButtonL1 then
			use(4)
		elseif k == Enum.KeyCode.Four or k == Enum.KeyCode.ButtonR2 then
			use(5)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not touch then
			use(1)
		end
	end)
end

return Abilities
