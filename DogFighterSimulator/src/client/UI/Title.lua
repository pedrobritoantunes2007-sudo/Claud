-- 🎬 TELA DE ENTRADA (2026-10, pedido do dono: "que apareça o nome do jogo e as ilhas de cima no início, para ser a
-- tela de entrada; daí clica PLAY, tem uma animação e daí vem o tutorial").
-- Ao entrar: a câmera voa bem alto em volta das ilhas, o nome do jogo cai do céu, dois cachorros 3D fazem pose,
-- faixa da atualização e o botão ▶ PLAY pulsando (espera o save e o cachorro aparecerem). O resto da tela (HUD,
-- menus, lista de jogadores, chat) fica escondido. PLAY: confete, o título sai e a câmera MERGULHA do céu até o
-- cachorro (ou o avatar, para quem ainda não tem cachorro); aí volta tudo e o tutorial começa (Title.Done).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Kit = require(script.Parent:WaitForChild("Kit"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local Title = {}

local C = Kit.C
local make = Kit.make
local LUCKY = Enum.Font.LuckiestGuy
local TAU = math.pi * 2

-- câmera do título: dá voltas em volta da ilha principal, bem alto (as ilhas de raridade aparecem em volta).
-- (2026-10-23) ABAIXO do ☁️ Reino das Nuvens (Islands.CLOUD_Y = 700): antes ela voava a 720, na altura das nuvens, e
-- passava por dentro da ilha do céu — parecia um mapa em cima do outro.
-- (2026-10-25, o dono: "o início, se a pessoa está com a renderização baixa, não mostra nada; faz de um jeito que
-- sempre vai aparecer") a ~1000 studs, no gráfico baixo o Roblox não desenhava nada. Agora ela voa PERTO (~300
-- studs) em volta da 🏡 Pawville — colorida, com o canil e a fonte, e é onde quem é novo começa: aparece em qualquer
-- qualidade gráfica.
local CENTER = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Village")).Center
local ORBIT_R = 275
local ORBIT_H = 135
local ORBIT_SPEED = 0.05 -- rad/s
local SWOOP_TIME = 2.6
-- ScreenGuis que continuam aparecendo durante o título (o resto some e volta depois)
local KEEP = { TitleScreen = true }

local doneEvent = Instance.new("BindableEvent")
Title.Done = doneEvent.Event
local done = false

function Title.IsDone(): boolean
	return done
end

-- espera o jogador clicar PLAY e a câmera chegar no cachorro
function Title.WaitDone()
	if not done then
		doneEvent.Event:Wait()
	end
end

local function sfx(name)
	local systems = script.Parent.Parent:FindFirstChild("Systems")
	local module = systems and systems:FindFirstChild("Sfx")
	if module then
		pcall(function()
			require(module).Play(name)
		end)
	end
end

local function controls(on: boolean)
	pcall(function()
		local module = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
		local c = module and (require(module :: any) :: any):GetControls()
		if c then
			if on and not Players.LocalPlayer:GetAttribute("AutoControl") then
				c:Enable()
			elseif not on then
				c:Disable()
			end
		end
	end)
end

local function smooth(u)
	return u * u * u * (u * (u * 6 - 15) + 10)
end

function Title.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local camera = workspace.CurrentCamera

	---------------------------------------------------------------- tela
	local gui, root = Kit.Screen("TitleScreen", 100)
	-- escurece o alto e o pé da tela (o texto fica legível em cima do céu e das ilhas)
	for _, top in ipairs({ true, false }) do
		local shade = make("Frame", {
			AnchorPoint = Vector2.new(0.5, top and 0 or 1),
			Position = UDim2.fromScale(0.5, top and 0 or 1),
			Size = UDim2.fromScale(1.2, 0.42),
			BackgroundColor3 = Color3.fromRGB(12, 8, 28),
			BorderSizePixel = 0,
			ZIndex = 1,
		}, gui)
		make("UIGradient", {
			Rotation = top and 90 or -90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
		}, shade)
	end

	-- 🐾 LOGO
	local logo = make("Frame", {
		Name = "Logo",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -320),
		Size = UDim2.fromOffset(820, 230),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, root)
	local function bigText(props, colors, stroke)
		local label = make("TextLabel", {
			BackgroundTransparency = 1,
			Font = LUCKY,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 6,
		}, logo)
		for k, v in pairs(props) do
			label[k] = v
		end
		Kit.Gradient(label, colors[1], colors[2], 0.52) -- (2 cores com corte reto: letra de desenho)
		make("UIStroke", { Thickness = stroke, Color = Color3.fromRGB(30, 14, 40), LineJoinMode = Enum.LineJoinMode.Round }, label)
		return label
	end
	local dogText = bigText({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(1, 0.62),
		Text = "DOG FIGHTER",
	}, { Color3.fromRGB(255, 236, 120), Color3.fromRGB(255, 140, 30) }, 7)
	local simText = bigText({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromScale(0.62, 0.32),
		Text = "SIMULATOR",
	}, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 200, 255) }, 5)
	local paws = {}
	for _, side in ipairs({ -1, 1 }) do
		local paw = Kit.Text(logo, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5 + side * 0.4, 0, 0.78, 0),
			Size = UDim2.fromOffset(70, 70),
			Text = "🐾",
			Rotation = side * 18,
			ZIndex = 6,
		})
		table.insert(paws, paw)
	end
	-- 🎃 faixa da atualização
	local ribbon = Kit.Ribbon(root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 268),
		Size = UDim2.fromOffset(560, 40),
		Rotation = -3,
		ZIndex = 7,
	}, C.Orange, "🎃 HALLOWEEN UPDATE · SPOOKY CLOWN + 2 CLONES! 🎃")
	-- (troca o degradê cinza da faixa pelo brilho de abóbora girando)
	local plain = ribbon.Frame:FindFirstChildOfClass("UIGradient")
	if plain then
		plain:Destroy()
	end
	ribbon.Frame.BackgroundColor3 = Color3.new(1, 1, 1)
	Kit.Shimmer(ribbon.Frame, Kit.PUMPKIN)
	ribbon.Frame.Visible = false

	-- 🐶 dois cachorros em pose, um de cada lado
	local dogs = {}
	for i, info in ipairs({ { "clown_dog", -1, 0.4 }, { "dragon_hound", 1, -0.4 } }) do
		local ok, view = pcall(Kit.DogViewport, root, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5 + info[2] * 0.34, 0, 0.6, 0),
			Size = UDim2.fromOffset(300, 300),
			ZIndex = 4,
			Visible = false,
		})
		if ok and view then
			pcall(view.SetSpecies, info[1])
			view.Spin = false
			view.Angle = info[3]
			view.Zoom = 0.9
			dogs[i] = view
		end
	end

	-- ▶ PLAY
	local playButton = Kit.Button(root, {
		Name = "Play",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(320, 96),
		Text = "▶ PLAY",
		Font = LUCKY,
		ZIndex = 8,
		Visible = false,
	}, C.Green)
	local status = Kit.Text(root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -86),
		Size = UDim2.fromOffset(520, 26),
		Text = "Loading your save...",
		TextColor3 = C.Muted,
		ZIndex = 8,
	})
	local tagline = Kit.Text(root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.fromOffset(760, 26),
		Text = "80+ dogs · floating islands · missions · PvP Colosseum · Super Boss",
		TextColor3 = Color3.fromRGB(255, 230, 170),
		ZIndex = 8,
	})

	---------------------------------------------------------------- esconde o resto da tela
	local hidden = {}
	local function hideOthers()
		for _, g in ipairs(playerGui:GetChildren()) do
			if g:IsA("ScreenGui") and g ~= gui and g.Enabled and not KEEP[g.Name] then
				g.Enabled = false
				hidden[g] = true
			end
		end
	end
	hideOthers()
	local hideConn = RunService.Heartbeat:Connect(hideOthers)
	local core = {}
	for _, kind in ipairs({ Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Chat, Enum.CoreGuiType.EmotesMenu }) do
		local okGet, was = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, kind)
		if okGet and was then
			core[kind] = true
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, false)
		end
	end
	controls(false)

	---------------------------------------------------------------- câmera dando voltas lá no alto
	local angle = math.random() * TAU
	local t0 = os.clock()
	RunService:BindToRenderStep("TitleOrbit", Enum.RenderPriority.Camera.Value + 10, function(dt)
		camera = workspace.CurrentCamera
		if not camera then
			return
		end
		angle += dt * ORBIT_SPEED
		local t = os.clock() - t0
		camera.CameraType = Enum.CameraType.Scriptable
		local pos = CENTER + Vector3.new(math.cos(angle) * ORBIT_R, ORBIT_H + math.sin(t * 0.35) * 25, math.sin(angle) * ORBIT_R)
		camera.CFrame = CFrame.lookAt(pos, CENTER + Vector3.new(0, 15, 0))
		camera.FieldOfView = 55
	end)

	---------------------------------------------------------------- animação de entrada
	Kit.Tween(logo, 0.9, { Position = UDim2.new(0.5, 0, 0, 34) }, Enum.EasingStyle.Bounce)
	task.delay(0.7, function()
		ribbon.Frame.Visible = true
		Kit.Pop(ribbon.Frame, true)
	end)
	for i, view in pairs(dogs) do
		task.delay(0.5 + i * 0.25, function()
			if view.Frame.Parent then
				Kit.Pop(view.Frame, true)
				view.SetAction(i == 1 and "Howl" or "Roar")
			end
		end)
	end
	-- cachorros trocando de pose e patinhas subindo pela tela
	local alive = true
	task.spawn(function()
		local poses = { "Howl", "Victory", "Bark", "Wiggle", "Roar", "Shake" }
		local k = 0
		while alive do
			task.wait(2.6)
			k += 1
			for i, view in pairs(dogs) do
				if alive and view.Frame.Parent then
					view.SetAction(nil)
					task.delay(0.15, function()
						if alive then
							view.SetAction(poses[(k + i) % #poses + 1])
						end
					end)
				end
			end
		end
	end)
	task.spawn(function()
		while alive do
			task.wait(0.35)
			local size = math.random(22, 40)
			local x = math.random(5, 95) / 100
			local p = Kit.Text(root, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(x, 0, 1, 30),
				Size = UDim2.fromOffset(size, size),
				Text = math.random() < 0.8 and "🐾" or "🎃",
				TextTransparency = 0.35,
				Rotation = math.random(-30, 30),
				ZIndex = 2,
			})
			Kit.Tween(p, 6, { Position = UDim2.new(x + (math.random() - 0.5) * 0.1, 0, -0.05, 0), TextTransparency = 1, Rotation = p.Rotation + math.random(-90, 90) }, Enum.EasingStyle.Linear)
			task.delay(6.1, function()
				p:Destroy()
			end)
		end
	end)
	-- logo respirando e balançando
	local wobble = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		dogText.Rotation = math.sin(t * 1.3) * 2
		simText.Rotation = math.sin(t * 1.3 + 1) * -1.5
		for i, paw in ipairs(paws) do
			paw.Position = UDim2.new(0.5 + (i == 1 and -0.4 or 0.4), 0, 0.78 + math.abs(math.sin(t * 3 + i)) * -0.08, 0)
		end
	end)

	---------------------------------------------------------------- pronto para jogar?
	-- espera o save; quem já tem cachorro espera o cachorro aparecer (a câmera mergulha nele)
	local function readyCharacter()
		local profile = Net.Profile
		if not profile then
			return nil, "Loading your save..."
		end
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not (character and rootPart) then
			return nil, "Getting your dog ready..."
		end
		if profile.Started and character:GetAttribute("Kind") ~= "player" and os.clock() - t0 < 25 then
			return nil, "Calling your dog..."
		end
		return character, nil
	end
	local stopPulse = nil
	local shineLoop = true
	task.spawn(function()
		while gui.Parent do
			local character, why = readyCharacter()
			if character then
				break
			end
			status.Text = why
			task.wait(0.25)
		end
		if not gui.Parent then
			return
		end
		local profile = Net.Profile
		status.Text = (profile and profile.Started) and ("Welcome back, " .. player.DisplayName .. "!") or "Welcome! Your first dog is waiting in 🏡 Pawville"
		playButton.Visible = true
		Kit.Pop(playButton, true)
		stopPulse = Kit.Pulse(playButton, 0.07, 1.1)
		task.spawn(function()
			while shineLoop and playButton.Parent do
				task.wait(2.4)
				if shineLoop and playButton.Parent then
					Kit.Shine(playButton)
				end
			end
		end)
	end)

	---------------------------------------------------------------- PLAY: mergulho até o cachorro
	local leaving = false
	local function finish()
		alive = false
		done = true
		RunService:UnbindFromRenderStep("TitleSwoop")
		hideConn:Disconnect()
		wobble:Disconnect()
		for g in pairs(hidden) do
			if g.Parent then
				g.Enabled = true
			end
		end
		for kind in pairs(core) do
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, true)
		end
		local cam = workspace.CurrentCamera
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if cam then
			cam.CameraType = Enum.CameraType.Custom
			if hum then
				cam.CameraSubject = hum
			end
			cam.FieldOfView = 70
		end
		controls(true)
		for _, view in pairs(dogs) do
			pcall(view.Destroy)
		end
		gui:Destroy()
		doneEvent:Fire()
	end

	local function play()
		if leaving or not playButton.Visible then
			return
		end
		local character = readyCharacter()
		if not character then
			return
		end
		leaving = true
		shineLoop = false
		if stopPulse then
			stopPulse()
		end
		sfx("Purchase")
		Kit.Burst(root, playButton.Position, C.Gold, 22, { "🐾", "✦", "★", "🎃" }, 220)
		-- o título sai: logo sobe, cachorros e botões encolhem
		Kit.Tween(logo, 0.5, { Position = UDim2.new(0.5, 0, 0, -340) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		Kit.Pop(ribbon.Frame, false)
		for _, view in pairs(dogs) do
			Kit.Pop(view.Frame, false)
		end
		Kit.Pop(playButton, false)
		for _, label in ipairs({ status, tagline }) do
			Kit.Tween(label, 0.3, { TextTransparency = 1 })
		end
		task.delay(0.25, function()
			sfx("Whoosh")
		end)
		-- mergulho: curva do alto até atrás do cachorro, olhando cada vez mais para ele
		RunService:UnbindFromRenderStep("TitleOrbit")
		local cam = workspace.CurrentCamera
		local from = cam.CFrame
		local fromFocus = CENTER + Vector3.new(0, 15, 0)
		local fromFov = cam.FieldOfView
		local s0 = os.clock()
		RunService:BindToRenderStep("TitleSwoop", Enum.RenderPriority.Camera.Value + 10, function()
			local char = player.Character
			local rootPart = char and char:FindFirstChild("HumanoidRootPart")
			cam = workspace.CurrentCamera
			if not (cam and rootPart) then
				finish()
				return
			end
			local u = math.clamp((os.clock() - s0) / SWOOP_TIME, 0, 1)
			local e = smooth(u)
			local focus = rootPart.Position + Vector3.new(0, 2, 0)
			local look = rootPart.CFrame.LookVector
			local back = Vector3.new(-look.X, 0, -look.Z)
			back = back.Magnitude > 0.01 and back.Unit or Vector3.new(0, 0, 1)
			local size = math.clamp(rootPart.Size.Z, 1.5, 6)
			local goal = focus + back * (9 + size * 2.2) + Vector3.new(0, 4 + size, 0)
			-- ponto de controle bem acima do cachorro: a câmera "cai" do céu e faz a curva no fim
			local ctrl = focus + back * 90 + Vector3.new(0, 260, 0)
			local p = (1 - e) ^ 2 * from.Position + 2 * (1 - e) * e * ctrl + e * e * goal
			local f = fromFocus:Lerp(focus, smooth(math.min(1, u * 1.35)))
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = CFrame.lookAt(p, f)
			cam.FieldOfView = fromFov + (70 - fromFov) * e
			if u >= 1 then
				finish()
			end
		end)
	end
	playButton.Activated:Connect(play)
	-- teclado/controle: Enter, espaço ou A também jogam
	local keyConn
	keyConn = UserInputService.InputBegan:Connect(function(input, processed)
		if done then
			keyConn:Disconnect()
			return
		end
		if processed then
			return
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.Return or k == Enum.KeyCode.Space or k == Enum.KeyCode.ButtonA then
			play()
		end
	end)
end


return Title
