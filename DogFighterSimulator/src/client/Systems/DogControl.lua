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
-- espaço sobe, C desce, W acelera, S freia, Shift = turbo, Q = parafuso. Celular/controle: o analógico
-- aponta para onde ir (o avião faz a curva até lá), pular sobe, câmera olhando para baixo desce, RUN = turbo.
-- Mergulhar ganha velocidade e subir perde (como avião); perto do chão ele empina sozinho para não bater.
-- Enquanto voa, a câmera vem para trás do cachorro sozinha (menos quando o jogador está girando a câmera).
--
-- 🔒 TRAVA DA CÂMERA (2026-10, pedido do dono; desde 2026-10-23 no CTRL — "a trava no Ctrl e correr no Shift"):
-- Ctrl liga/desliga (só PC com mouse). A setinha vira uma MIRA no meio da
-- tela, a câmera fica por cima do ombro e gira com o mouse, e o cachorro vira junto com a câmera (anda de lado e de
-- costas como no Roblox). Golpes e poderes vão para a mira. Voando: o avião vai para onde a câmera olha. Menu aberto
-- solta o mouse. (Correr = Shift, no Sprint; voando, Shift = turbo e C desce.)
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))
local TouchPad = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("TouchPad"))
local Animator = require(script.Parent.Parent:WaitForChild("Animator"))

local DogControl = {}

local player = Players.LocalPlayer
local TAU = math.pi * 2

-- ✈️ voo: velocidade de cruzeiro = BaseSpeed × FLY_MULT (voo rápido, pedido do dono) e o jeito de avião
local FLY_MULT = 4
local FLY = {
	Slow = 0.22, -- (antigo: S devagar; 2026-10 sem W ele fica parado no ar pairando)
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
local faceDir: Vector3?, faceDirUntil = nil, 0 -- dash: vira o corpo para esta direção até esta hora
local flyParts: any = nil -- voo ligado: LinearVelocity + AlignOrientation e o estado do avião
local shiftLock = false -- 🔒 trava da câmera pedida pelo jogador (Ctrl liga/desliga; o nome ficou do tempo do Shift)
local lockOn = false -- trava valendo AGORA (PC com mouse, controlando o cachorro, sem menu aberto)
local lockChanged: ((boolean) -> ())? = nil -- avisa a mira/HUD

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

-- Direção do golpe: do cachorro até a setinha (PC). 📱 Celular/controle (2026-10, pedido do dono: "onde estiver o
-- analógico o cachorro vai dar naquela direção"): para onde o analógico aponta; parado, para onde a câmera olha.
function DogControl.AimDirection(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	if aim.Mouse then
		if not aim.Hit then
			return nil
		end
		local d = aim.Hit - root.Position
		if d.Magnitude < 0.5 then
			return nil
		end
		return d.Unit
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	local mv = hum and hum.MoveDirection
	if mv and Vector3.new(mv.X, 0, mv.Z).Magnitude > 0.2 then
		return Vector3.new(mv.X, 0, mv.Z).Unit
	end
	local cam = workspace.CurrentCamera
	if cam then
		local l = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
		if l.Magnitude > 0.01 then
			return l.Unit
		end
	end
	return nil
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

-- 💨 dash: o corpo vira na hora para a direção do dash (no mundo) por `seconds`
function DogControl.FaceDirection(dir: Vector3, seconds: number)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude > 0.01 then
		faceDir, faceDirUntil = flat.Unit, os.clock() + seconds
	end
end

-- 🔒 trava de Shift ligada agora? (a mira no meio da tela manda nos golpes)
function DogControl.ShiftLocked(): boolean
	return lockOn
end

function DogControl.SetShiftLock(on: boolean)
	shiftLock = on == true
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
		for _, name in ipairs({ "Hatch", "StarterRoll" }) do
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
	-- ⚡ habilidade pediu para virar (o corpo é do jogador: o servidor só pede — atributo FaceAt/FaceAtN do modelo)
	local lastFaceN, serverFace, serverFaceUntil = nil, nil, 0
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
			and not lockOn
		then
			local cf = camera.CFrame
			local focus = camera.Focus.Position
			local step = wrap(flyParts.Yaw - yawOf(cf.LookVector)) * damp(dt, 2.2)
			camera.CFrame = CFrame.new(focus) * CFrame.Angles(0, step, 0) * CFrame.new(-focus) * cf
		end
		-- 🔒 trava de Shift: mouse preso no meio (a câmera gira com ele), câmera por cima do ombro, sem a setinha
		local wantLock = shiftLock
			and aim.Mouse
			and hum ~= nil
			and root ~= nil
			and root:IsA("BasePart")
			and camera ~= nil
			and camera.CameraType == Enum.CameraType.Custom
			and character:GetAttribute("Kind") == "player"
			and not player:GetAttribute("AutoControl")
			and not modalOpen()
		if wantLock then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
			-- por cima do ombro direito (voando fica no meio: o corpo inclina nas curvas)
			local k = math.clamp(root.Size.Z / 2.6, 0.7, 2)
			hum.CameraOffset = Vector3.new(flyParts and 0 or 1.7 * k, 0.6 * k, 0)
		end
		if wantLock ~= lockOn then
			lockOn = wantLock
			if not lockOn then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = true
				if hum then
					hum.CameraOffset = Vector3.zero
				end
			end
			if lockChanged then
				lockChanged(lockOn)
			end
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
		local faceN = character:GetAttribute("FaceAtN")
		if faceN ~= lastFaceN then
			lastFaceN = faceN
			local p = character:GetAttribute("FaceAt")
			if faceN and typeof(p) == "Vector3" then
				serverFace, serverFaceUntil = p, now + 0.35
			end
		end
		if faceDir and now < faceDirUntil and not flyParts then
			if not autoRotateOff then
				autoRotateOff = true
				hum.AutoRotate = false
			end
			turnToward(root, yawOf(faceDir), 40 * dt)
			return
		end
		if serverFace and now < serverFaceUntil and not flyParts then
			local sf = Vector3.new(serverFace.X - root.Position.X, 0, serverFace.Z - root.Position.Z)
			if sf.Magnitude > 1 then
				if not autoRotateOff then
					autoRotateOff = true
					hum.AutoRotate = false
				end
				turnToward(root, yawOf(sf), 18 * dt)
				return
			end
		end
		-- 🔒 trava de Shift no chão: o corpo segue a câmera (anda de lado/de costas sem virar)
		if lockOn and not flyParts then
			local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
			if look.Magnitude > 0.01 then
				if not autoRotateOff then
					autoRotateOff = true
					hum.AutoRotate = false
				end
				turnToward(root, yawOf(look), 30 * dt)
			end
			turning = false
			return
		end
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

	-- 🛡️ BARREIRA INVISÍVEL DO PvP (2026-10, pedido do dono: "quando entram em PvP não podem sair voando de lá"):
	-- quem está no chão do Coliseu com o PvP ligado (Super Boss dormindo) não sai voando — nem por cima nem pelos lados.
	-- Onde bate, a parede de energia aparece um instante. Para sair: pousar e andar pelos portões. (O servidor confere
	-- de novo: DogService.homeRoutine.)
	local inPvP = false
	local flashAt, toastAt = 0, 0
	local function barrierFlash(point: Vector3, normal: Vector3)
		local now = os.clock()
		if now - flashAt < 0.12 then
			return
		end
		flashAt = now
		local wall = Instance.new("Part")
		wall.Name = "BarreiraPvP"
		wall.Anchored = true
		wall.CanCollide = false
		wall.CanQuery = false
		wall.CanTouch = false
		wall.CastShadow = false
		wall.Material = Enum.Material.ForceField
		wall.Color = Color3.fromRGB(255, 90, 80)
		wall.Size = Vector3.new(22, 22, 0.6)
		wall.CFrame = CFrame.lookAt(point, point + normal)
		wall.Transparency = 0.05
		wall.Parent = workspace
		local ring = wall:Clone()
		ring.Material = Enum.Material.Neon
		ring.Size = Vector3.new(6, 6, 0.2)
		ring.Transparency = 0.4
		ring.Color = Color3.fromRGB(255, 220, 140)
		ring.Parent = workspace
		local tween = game:GetService("TweenService")
		local info = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		tween:Create(wall, info, { Transparency = 1, Size = Vector3.new(30, 30, 0.6) }):Play()
		tween:Create(ring, info, { Transparency = 1, Size = Vector3.new(16, 16, 0.2) }):Play()
		game:GetService("Debris"):AddItem(wall, 0.6)
		game:GetService("Debris"):AddItem(ring, 0.6)
		if now - toastAt > 4 then
			toastAt = now
			HUD.Toast("🛡️ PvP barrier! Land and walk out through a gate to leave.", "red")
		end
	end
	-- devolve a velocidade sem a parte que sai da barreira (e vira o avião para dentro)
	local function arenaBarrier(F, root: BasePart, vel: Vector3): Vector3
		local pos = root.Position
		local c = Layout.ARENA_CENTER
		local rel = Vector3.new(pos.X - c.X, 0, pos.Z - c.Z)
		local maxR = Layout.ARENA_RADIUS - 5
		if rel.Magnitude > maxR then
			local n = rel.Unit
			local out = vel:Dot(n)
			if out > 0 then
				vel -= n * out * 1.8 -- quica um pouco para dentro
				local look = Vector3.new(math.sin(-F.Yaw), 0, -math.cos(F.Yaw))
				local bounce = look - n * 2 * look:Dot(n)
				if bounce.Magnitude > 0.01 then
					F.Yaw = yawOf(bounce)
				end
			end
			if rel.Magnitude > maxR + 2 then
				vel -= n * 25
			end
			barrierFlash(c + n * (Layout.ARENA_RADIUS - 1) + Vector3.new(0, pos.Y, 0), -n)
		end
		local ceiling = Layout.ARENA_CEILING - 5
		if pos.Y > ceiling then
			if vel.Y > 0 then
				vel = Vector3.new(vel.X, -vel.Y * 0.4, vel.Z)
			end
			F.Pitch = math.min(F.Pitch, -0.25) -- nariz para baixo
			if pos.Y > ceiling + 2 then
				vel -= Vector3.new(0, 25, 0)
			end
			barrierFlash(Vector3.new(pos.X, Layout.ARENA_CEILING, pos.Z), Vector3.new(0, -1, 0))
		end
		return vel
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
		-- 🛡️ está no PvP do Coliseu? (andando para fora pelos portões deixa de estar; voando, a barreira segura)
		if not (root and root:IsA("BasePart")) or workspace:GetAttribute("SuperBossAwake") == true then
			inPvP = false
		elseif Layout.InArena(root.Position) then
			inPvP = true
		elseif not flying then
			inPvP = false
		end
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
			-- já no ar (uma habilidade segurou o corpo e devolveu): continua pairando, sem a decolagem de novo
			groundParams.FilterDescendantsInstances = ignoreList(character)
			local airborne = workspace:Raycast(root.Position, Vector3.new(0, -((character:GetAttribute("GroundHip") or 2) + root.Size.Y / 2 + 4), 0), groundParams) == nil
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			flyParts = {
				Root = root,
				Hum = hum,
				Lv = lv,
				Ao = ao,
				List = { lv, ao, att },
				Yaw = look.Magnitude > 0.01 and yawOf(look) or 0,
				Pitch = airborne and 0 or 0.6,
				Bank = 0,
				YawRate = 0,
				Speed = airborne and Vector3.new(v.X, 0, v.Z).Magnitude or math.max(cruise * 0.5, Vector3.new(v.X, 0, v.Z).Magnitude),
				Start = airborne and now - 1 or now,
				Hover = airborne and 1 or 0,
			}
			if airborne then
				lv.VectorVelocity = Vector3.zero
			end
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
		if lockOn and camera then
			-- 🔒 trava de Shift: o mouse gira a câmera e o avião vai para onde ela olha
			local look = camera.CFrame.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z)
			if flatLook.Magnitude > 0.01 then
				turn = -wrap(yawOf(flatLook) - F.Yaw) * 1.6 + mv.X
			end
			pitch = (look.Y + 0.12) * 2.4
			if math.abs(pitch) < 0.08 then
				pitch = 0
			end
		elseif aim.Mouse and camera then
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
		local lift = 0 -- (pairando: só as teclas sobem/descem — a setinha fica livre para mirar)
		if key(Enum.KeyCode.Space) or hum.Jump then
			pitch += 1
			lift += 1
		end
		if key(Enum.KeyCode.C) then -- (Shift é correr/turbo: Sprint)
			pitch -= 1
			lift -= 1
		end
		turn = math.clamp(turn, -1, 1)
		pitch = math.clamp(pitch, -1, 1)
		-- velocidade pedida: W acelera, Shift/RUN = turbo (o Sprint deixa o WalkSpeed maior)
		local boost = hum.WalkSpeed > base * 1.2
		local throttle = (boost and FLY.Boost) or (forward > 0.3 and FLY.Fast) or FLY.Cruise
		-- 🪽 PARADO NO AR (2026-10, pedido do dono: "os cachorros possam ficar parados no ar voando, com as animações da
		-- asa"): sem W (ou com o analógico solto / S) ele freia e fica pairando, batendo as asas, virado para a setinha;
		-- espaço sobe e C desce devagar. W (ou o analógico) volta a voar como avião.
		local wantHover = not boost and forward < 0.3
		F.Hover = (F.Hover or 0) + ((wantHover and 1 or 0) - (F.Hover or 0)) * damp(dt, forward < -0.3 and 4 or 2.2)
		local hov = F.Hover
		throttle *= 1 - hov
		local v = F.Speed / cruise
		-- curva (devagar fica mais fechada, quase um helicóptero); pairando: vira para a setinha
		local yawRateGoal = -turn * FLY.Turn * (1 + 0.8 * math.max(0, 1 - v))
		if hov > 0.01 then
			local face = nil
			if aim.Mouse and aim.Point then
				face = Vector3.new(aim.Point.X - root.Position.X, 0, aim.Point.Z - root.Position.Z)
			elseif mv.Magnitude > 0.15 and camera then
				face = camera.CFrame:VectorToWorldSpace(Vector3.new(mv.X, 0, mv.Z))
				face = Vector3.new(face.X, 0, face.Z)
			end
			local hoverRate = 0
			if face and face.Magnitude > 2 then
				hoverRate = math.clamp(wrap(yawOf(face) - F.Yaw) * 5, -3, 3)
			end
			yawRateGoal = yawRateGoal * (1 - hov) + hoverRate * hov
		end
		F.YawRate += (yawRateGoal - F.YawRate) * damp(dt, 6)
		F.Yaw = wrap(F.Yaw + F.YawRate * dt)
		-- subida/mergulho (pairando o corpo fica nivelado: sobe e desce reto)
		local pitchGoal = pitch * FLY.PitchMax * (1 - hov)
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
		F.Speed += (speedGoal - F.Speed) * damp(dt, FLY.Accel * (1 + hov))
		F.Speed = math.max(F.Speed, cruise * 0.15 * (1 - hov))
		-- inclinação de curva (mais rápido = inclina mais; pairando, só um pouquinho)
		local bankGoal = math.clamp(F.YawRate * FLY.Bank * (0.6 + 0.6 * math.min(v, 1.4)) * (1 - 0.7 * hov), -FLY.BankMax, FLY.BankMax)
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
		-- pairando: espaço sobe, C desce (perto do chão não desce mais: fica pairando logo acima)
		if hov > 0.01 then
			local climb = lift * cruise * 0.4
			if below and climb < 0 then
				local h = root.Position.Y - below.Position.Y - clearance
				climb *= math.clamp((h - 1.5) / 4, 0, 1)
			end
			vel += Vector3.new(0, climb * hov, 0)
		end
		if inPvP then
			vel = arenaBarrier(F, root, vel)
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
	-- 🔒 TRAVA DA CÂMERA: Ctrl liga/desliga; mira no meio da tela enquanto vale
	local crossGui = Instance.new("ScreenGui")
	crossGui.Name = "ShiftLockCrosshair"
	crossGui.IgnoreGuiInset = true
	crossGui.ResetOnSpawn = false
	crossGui.DisplayOrder = 5
	crossGui.Enabled = false
	crossGui.Parent = playerGui
	local function bar(size: UDim2, pos: UDim2)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = size
		f.Position = pos
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BorderSizePixel = 0
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.5
		stroke.Color = Color3.fromRGB(30, 20, 40)
		stroke.Parent = f
		f.Parent = crossGui
		return f
	end
	local dot = bar(UDim2.fromOffset(6, 6), UDim2.fromScale(0.5, 0.5))
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	bar(UDim2.fromOffset(12, 3), UDim2.new(0.5, -15, 0.5, 0))
	bar(UDim2.fromOffset(12, 3), UDim2.new(0.5, 15, 0.5, 0))
	bar(UDim2.fromOffset(3, 12), UDim2.new(0.5, 0, 0.5, -15))
	bar(UDim2.fromOffset(3, 12), UDim2.new(0.5, 0, 0.5, 15))
	lockChanged = function(on)
		crossGui.Enabled = on
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if (input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl) and not processed and not UserInputService:GetFocusedTextBox() then
			if not aim.Mouse then
				return
			end
			shiftLock = not shiftLock
			if HUD.Toast then
				HUD.Toast(shiftLock and "🔒 Camera Lock ON — aim with the center cross · Ctrl = unlock" or "🔓 Camera Lock OFF", shiftLock and "gold" or nil)
			end
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
