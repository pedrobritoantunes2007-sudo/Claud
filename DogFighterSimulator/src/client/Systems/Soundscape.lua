-- 🌳🐶 SONS DO MUNDO (2026-10-25, pedido do dono: "quero som para tudo, porque tem várias coisas sem som, faz o cachorro
-- latir às vezes"). Tudo no CLIENTE, com os sons do pacote de efeitos (Systems/Sfx):
--   • ambiente em loop pelo lugar e pela hora: passarinhos (dia) ou grilos (noite), mar na Pawville, vento nas ilhas
--     altas, torcida no Coliseu (Sfx.Loop — só com o pacote 2 enviado; sem ele fica sem ambiente)
--   • cachorros latem às vezes: o meu (fora de luta), os selvagens perto, os da vila; o tamanho decide a voz
--   • passos, pulo e pouso do meu cachorro; ganido quando ele apanha; uivo quando sobe de level
--   • tecla B (celular: botão BARK) = o meu cachorro late para todo mundo ouvir (remote Bark) + balão "WOOF!"
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Parent
local UI = Client:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local TouchPad = require(UI:WaitForChild("TouchPad"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local Soundscape = {}

local player = Players.LocalPlayer
local rng = Random.new()

---------------------------------------------------------------- ajustes
local AMB_BY_AREA = {
	-- [lugar] = { {loop, volume}, ... }   ("Day" = passarinhos de dia, grilos de noite)
	hub = { { "Day", 0.32 }, { "AmbWaves", 0.2 } },
	low = { { "Day", 0.34 } },
	mid = { { "Day", 0.28 }, { "AmbWind", 0.1 } },
	high = { { "AmbWind", 0.3 }, { "Day", 0.12 } },
	arena = { { "AmbCrowd", 0.26 } },
}
local ISLAND_AREA = {
	village = "hub", main = "hub",
	common = "low", uncommon = "low", rare = "mid", epic = "mid", legendary = "mid",
	mythic = "high", divine = "high", cloud = "high",
	colosseum = "arena",
}
local MY_IDLE = { 16, 34 } -- s entre um latido e outro do meu cachorro (fora de luta)
local WILD_TICK = 1.3 -- s: de quanto em quanto um selvagem perto pode latir
local WILD_CHANCE = 0.32
local WILD_GAP = 2.4 -- s mínimos entre latidos de selvagens (com 80 cachorros na ilha, não vira barulho)
local WILD_RANGE = 75
local VILLAGE_GAP = 5 -- s entre latidos dos cachorros da Pawville
local BARK_COOLDOWN = 1.2 -- s da tecla B

---------------------------------------------------------------- cachorros
local function dogsFolder(): Instance?
	return workspace:FindFirstChild("Cachorros")
end

local function alive(model: Instance?): boolean
	if not (model and model.Parent) then
		return false
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and model:GetAttribute("Action") ~= "KO"
end

local function myDog(): Model?
	-- (o personagem do jogador É o cachorro quando ele está de cachorro)
	local character = player.Character
	if character and character:GetAttribute("Kind") == "player" then
		return character
	end
	local folder = dogsFolder()
	if not folder then
		return nil
	end
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("Kind") == "player" and model:GetAttribute("Owner") == player.UserId then
			return model
		end
	end
	return nil
end

local function dogOf(userId: number): Model?
	local folder = dogsFolder()
	if not folder then
		return nil
	end
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("Kind") == "player" and model:GetAttribute("Owner") == userId then
			return model
		end
	end
	return nil
end

local function inFight(model: Instance): boolean
	local id = model:GetAttribute("DuelId")
	return typeof(id) == "number" and id ~= 0
end

local function listenerPos(): Vector3?
	local camera = workspace.CurrentCamera
	return camera and camera.Focus.Position or nil
end

-- 💬 balão "WOOF!" em cima do cachorro
local function bubble(model: Model, text: string)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Latido"
	gui.Size = UDim2.fromOffset(130, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, Sfx.HeightOf(model) * 0.6 + 2.2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Adornee = root
	local label = Kit.Text(gui, {
		Size = UDim2.fromScale(1, 1),
		Font = Kit.Title,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
	})
	Kit.Thick(label, 3)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = label
	gui.Parent = player:FindFirstChildOfClass("PlayerGui")
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(gui, TweenInfo.new(1.1, Enum.EasingStyle.Sine), { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 2, 0) }):Play()
	task.delay(0.75, function()
		TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		end
	end)
	task.delay(1.2, function()
		gui:Destroy()
	end)
end

local function barkWord(model: Model): string
	local h = Sfx.HeightOf(model)
	if h < 2.6 then
		return rng:NextNumber() < 0.5 and "YIP!" or "ARF!"
	elseif h < 4.2 then
		return rng:NextNumber() < 0.5 and "BARK!" or "WOOF!"
	end
	return "WOOF!"
end

---------------------------------------------------------------- ambiente
local ambFolder: Folder
local ambSounds: { [string]: Sound } = {}
local ambTarget: { [string]: number } = {}

local function isNight(): boolean
	local t = Lighting.ClockTime
	return t >= 18.6 or t < 5.8
end

local function updateAmbience()
	local island = player:GetAttribute("Island")
	local area = (type(island) == "string" and ISLAND_AREA[island]) or "hub"
	local want = {}
	for _, item in ipairs(AMB_BY_AREA[area] or {}) do
		local name = item[1]
		if name == "Day" then
			name = isNight() and "AmbNight" or "AmbBirds"
		end
		want[name] = (want[name] or 0) + item[2]
	end
	local user = Sfx.UserVolume()
	for name, vol in pairs(want) do
		if not ambSounds[name] then
			local sound = Sfx.Loop(name, ambFolder)
			if sound then
				ambSounds[name] = sound
			end
		end
	end
	for name, sound in pairs(ambSounds) do
		local target = (want[name] or 0) * user
		if ambTarget[name] ~= target then
			ambTarget[name] = target
			TweenService:Create(sound, TweenInfo.new(2.5, Enum.EasingStyle.Sine), { Volume = target }):Play()
		end
	end
end

---------------------------------------------------------------- latidos
local nextMyBark = os.clock() + rng:NextNumber(MY_IDLE[1], MY_IDLE[2])
local lastWild = 0
local lastVillage = 0
local lastManual = 0

local function idleBarks()
	local now = os.clock()
	-- o meu cachorro
	local mine = myDog()
	if mine and now >= nextMyBark then
		nextMyBark = now + rng:NextNumber(MY_IDLE[1], MY_IDLE[2])
		if alive(mine) and not inFight(mine) then
			Sfx.Voice(mine, rng:NextNumber() < 0.12 and "howl" or "bark", { Volume = 0.5 })
		end
	end
	-- um selvagem perto (de vez em quando, nunca vários ao mesmo tempo)
	local at = listenerPos()
	local folder = dogsFolder()
	if at and folder and now - lastWild > WILD_GAP and rng:NextNumber() < WILD_CHANCE then
		local near = {}
		for _, model in ipairs(folder:GetChildren()) do
			if model:IsA("Model") and model:GetAttribute("Kind") == "npc" and model.PrimaryPart then
				local d = (model.PrimaryPart.Position - at).Magnitude
				if d < WILD_RANGE and alive(model) then
					table.insert(near, model)
				end
			end
		end
		if #near > 0 then
			lastWild = now
			local model = near[rng:NextInteger(1, #near)]
			Sfx.Voice(model, (inFight(model) and rng:NextNumber() < 0.5) and "growl" or "bark", { Volume = 0.42 })
		end
	end
	-- os cachorros da Pawville (enfeite)
	local village = workspace:FindFirstChild("VidaDaVila")
	if at and village and now - lastVillage > VILLAGE_GAP and rng:NextNumber() < 0.4 then
		local near = {}
		for _, model in ipairs(village:GetChildren()) do
			if model:IsA("Model") and model:GetAttribute("Species") and model.PrimaryPart then
				if (model.PrimaryPart.Position - at).Magnitude < 60 then
					table.insert(near, model)
				end
			end
		end
		if #near > 0 then
			lastVillage = now
			Sfx.Voice(near[rng:NextInteger(1, #near)], rng:NextNumber() < 0.08 and "howl" or "bark", { Volume = 0.38 })
		end
	end
end

-- 🐕 o meu cachorro late (tecla B / botão BARK): toca aqui na hora e o servidor espalha para os outros
local barkRemote: RemoteEvent? = nil
local function manualBark()
	local now = os.clock()
	if now - lastManual < BARK_COOLDOWN then
		return
	end
	local mine = myDog()
	if not (mine and alive(mine)) then
		return
	end
	lastManual = now
	nextMyBark = now + rng:NextNumber(MY_IDLE[1], MY_IDLE[2])
	Sfx.Voice(mine, "bark", { Volume = 0.75 })
	bubble(mine, barkWord(mine))
	if barkRemote then
		barkRemote:FireServer("bark")
	end
end

---------------------------------------------------------------- passos, pulo, pouso, apanhar
local watched: Model? = nil
local conns: { RBXScriptConnection } = {}
local stepTimer = 0
local flapTimer = 0
local lastHealth = 0
local fallSpeed = 0

local function unwatch()
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	table.clear(conns)
	watched = nil
end

local function watchMine(model: Model)
	unwatch()
	watched = model
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	lastHealth = hum.Health
	table.insert(conns, hum.HealthChanged:Connect(function(health)
		local drop = lastHealth - health
		lastHealth = health
		if drop > math.max(1, hum.MaxHealth * 0.015) and health > 0 then
			Sfx.Play("Hit", model, { Volume = 0.3, Gap = 0.25 })
			if rng:NextNumber() < 0.35 then
				Sfx.Play("Yelp", model, { Volume = 0.4, Gap = 1.2, Pitch = Sfx.VoiceFor(Sfx.HeightOf(model)) == "Yip" and 1.25 or 1 })
			end
		end
	end))
	table.insert(conns, hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			Sfx.Play("Jump", model, { Volume = 0.3 })
		elseif new == Enum.HumanoidStateType.Landed then
			if fallSpeed > 18 then
				Sfx.Play("Land", model, { Volume = math.clamp(fallSpeed / 90, 0.15, 0.45) })
			end
		end
	end))
end

local function updateSteps(dt: number)
	local mine = myDog()
	if mine ~= watched then
		if mine then
			watchMine(mine)
		else
			unwatch()
		end
	end
	if not mine then
		return
	end
	local hum = mine:FindFirstChildOfClass("Humanoid")
	local root = mine.PrimaryPart
	if not (hum and root) or hum.Health <= 0 then
		return
	end
	local v = root.AssemblyLinearVelocity
	fallSpeed = math.max(0, -v.Y)
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	-- 🪽 voando: bate as asas
	if player:GetAttribute("Flying") == true then
		flapTimer -= dt
		if flapTimer <= 0 then
			flapTimer = speed > 40 and 0.75 or 0.5
			Sfx.Play("Flap", root, { Volume = 0.22, Pitch = 0.9 + rng:NextNumber() * 0.2, Gap = 0.2 })
		end
	end
	if hum.FloorMaterial == Enum.Material.Air or speed < 2.5 or player:GetAttribute("Flying") == true then
		stepTimer = 0.05
		return
	end
	stepTimer -= dt
	if stepTimer <= 0 then
		stepTimer = math.clamp(5.2 / speed, 0.15, 0.42)
		local h = Sfx.HeightOf(mine)
		Sfx.Play("Step", root, { Volume = 0.1 + math.min(0.08, speed / 400), Pitch = math.clamp(1.35 - h * 0.08, 0.8, 1.3) * (0.92 + rng:NextNumber() * 0.16), Gap = 0.08 })
	end
end

---------------------------------------------------------------- liga
function Soundscape.Start(_HUD)
	ambFolder = Instance.new("Folder")
	ambFolder.Name = "Ambiente"
	ambFolder.Parent = SoundService

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:WaitForChild("Bark", 10)
	if remote and remote:IsA("RemoteEvent") then
		barkRemote = remote
		remote.OnClientEvent:Connect(function(userId, _kind)
			if userId == player.UserId then
				return -- (o meu já tocou na hora)
			end
			local model = typeof(userId) == "number" and dogOf(userId)
			if model and alive(model) then
				Sfx.Voice(model, "bark", { Volume = 0.6 })
				bubble(model, barkWord(model))
			end
		end)
	end

	-- 🐕 tecla B / botão do celular
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			manualBark()
		end
	end)
	TouchPad.Add("Bark", { Icon = "🐶", Icon3D = "dog", Label = "BARK", Color = Kit.C.Orange, Order = 7 }, manualBark)

	-- 🧍↔🐶 virou pessoa/cachorro · 🪽 decolou/pousou
	player:GetAttributeChangedSignal("HumanMode"):Connect(function()
		Sfx.Play("Poof", nil, { Volume = 0.5 })
		Sfx.Play("Magic", nil, { Volume = 0.35 })
	end)
	player:GetAttributeChangedSignal("Flying"):Connect(function()
		local mine = myDog()
		if player:GetAttribute("Flying") == true then
			Sfx.Play("Flap", mine, { Volume = 0.35 })
			Sfx.Play("Whoosh", mine, { Volume = 0.3, Pitch = 0.9 })
		else
			Sfx.Play("Land", mine, { Volume = 0.3 })
		end
	end)

	-- ⭐ subiu de level: o meu cachorro uiva de alegria
	local levelUp = remotes:FindFirstChild("LevelUp")
	if levelUp and levelUp:IsA("RemoteEvent") then
		levelUp.OnClientEvent:Connect(function()
			task.delay(0.8, function()
				local mine = myDog()
				if mine then
					Sfx.Voice(mine, "howl", { Volume = 0.55 })
				end
			end)
		end)
	end

	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(updateSteps, dt)
		if not ok then
			warn("[Soundscape] passos:", err)
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(idleBarks)
			if not ok then
				warn("[Soundscape] latidos:", err)
			end
			task.wait(WILD_TICK)
		end
	end)
	task.spawn(function()
		task.wait(2)
		while true do
			local ok, err = pcall(updateAmbience)
			if not ok then
				warn("[Soundscape] ambiente:", err)
			end
			task.wait(1.5)
		end
	end)
end

return Soundscape
