-- Música: trilha do lugar em loop com troca suave (crossfade), jingles em eventos e botão de som (alto-falante) no
-- canto direito da barra do Roblox.
-- 🎵 TRILHA 2 (2026-10-25, pedido do dono: "faz a música de novo... têm que ser viciantes, porque vão ficar horas no
-- jogo"): as músicas novas ficam em 3 pacotes de áudio (Shared/MusicPacks, gerados por Musica/gerar_trilha2.py); cada
-- música é um trecho do pacote tocado com PlaybackRegion + LoopRegion. Cada lugar tem uma LISTA de músicas que se
-- revezam (PLAYLISTS): depois de ROTATE segundos a próxima entra com crossfade, para não cansar.
-- Pacote ainda sem ID (não enviado) = a música cai na trilha antiga (Shared/MusicConfig: Main/Arena/Boss).
-- Music.Jingle(nome) toca uma vinheta (LevelUp, Victory, Gotcha, RareWin, Unlock) abaixando a música.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local MusicConfig = require(ReplicatedStorage.Shared.MusicConfig)
local MusicPacks = require(ReplicatedStorage.Shared.MusicPacks)

local Music = {}

local player = Players.LocalPlayer
local MUTE_ATTR = "MusicaMudo"

-- 🎶 o que toca em cada lugar (as da mesma lista se revezam)
local PLAYLISTS = {
	hub = { "Village", "Sunny" }, -- 🏡 Pawville e ilha principal
	low = { "Meadows", "Adventure" }, -- 🌻 ilhas do começo
	mid = { "Adventure", "Meadows" }, -- ilhas do meio
	high = { "Mystic", "Adventure" }, -- ilhas mágicas (Mítica, Divina, Nuvens)
	arena = { "Arena" }, -- ⚔️ Coliseu / PvP
	boss = { "Boss" }, -- 🌍 Super Boss
}
local ISLAND_AREA = {
	village = "hub", main = "hub",
	common = "low", uncommon = "low", rare = "mid", epic = "mid", legendary = "mid",
	mythic = "high", divine = "high", cloud = "high",
	colosseum = "arena",
}
-- música nova → trilha antiga, enquanto o pacote dela não foi enviado
local FALLBACK = { Village = "Main", Sunny = "Main", Meadows = "Arena", Adventure = "Arena", Mystic = "Main", Arena = "Arena", Boss = "Boss" }
local ROTATE = 170 -- s tocando a mesma música antes de passar para a próxima da lista

local musicGroup: SoundGroup
local jingleGroup: SoundGroup
local songs: { [string]: Sound } = {} -- músicas novas (trechos dos pacotes)
local oldTracks: { [string]: Sound } = {} -- trilha antiga (Main/Arena/Boss)
local playing: Sound? = nil
local playingName: string? = nil
local playingSince = 0
local currentArea: string? = nil
local areaIndex: { [string]: number } = {}
local muted = false
local duck = 1

local function assetId(id: number?): string?
	if typeof(id) == "number" and id > 0 then
		return "rbxassetid://" .. tostring(math.floor(id))
	end
	return nil
end

local function packId(pack: string?): string?
	return pack and assetId(MusicPacks.Packs[pack]) or nil
end

local function makeGroup(name: string, volume: number): SoundGroup
	local group = SoundService:FindFirstChild(name)
	if not (group and group:IsA("SoundGroup")) then
		group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = SoundService
	end
	group.Volume = volume
	return group :: SoundGroup
end

local function fadeTo(sound: Sound, volume: number, seconds: number)
	TweenService:Create(sound, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Volume = volume }):Play()
end

local function playerVolume(): number
	local v = player:GetAttribute("MusicVolume")
	if typeof(v) == "number" and v == v then
		return math.clamp(v, 0, 1)
	end
	return 1
end

local function applyGroupVolume()
	if musicGroup then
		local target = muted and 0 or MusicConfig.MusicVolume * duck * playerVolume()
		TweenService:Create(musicGroup, TweenInfo.new(0.4), { Volume = target }):Play()
	end
	if jingleGroup then
		jingleGroup.Volume = muted and 0 or MusicConfig.JingleVolume * playerVolume()
	end
end

-- Sound de um trecho do pacote (PlaybackRegion; com loop, LoopRegion do mesmo tamanho = loop perfeito)
local function regionSound(name: string, parent: Instance, group: SoundGroup): Sound?
	local info = MusicPacks.Songs[name]
	local id = info and packId(info.Pack)
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.PlaybackRegionsEnabled = true
	sound.PlaybackRegion = NumberRange.new(info.Start, info.Start + info.Length)
	if info.Loop then
		sound.LoopRegion = NumberRange.new(info.Start, info.Start + info.Length)
		sound.Looped = true
	end
	sound.Volume = 0
	sound.SoundGroup = group
	sound.Parent = parent
	return sound
end

-- Em que lugar o jogador está (qual lista de músicas)
local function wantedArea(): string
	if player:GetAttribute("InTower") then
		return "boss"
	end
	local where = player:GetAttribute("Island")
	if where == "colosseum" and workspace:GetAttribute("SuperBossAwake") then
		return "boss"
	end
	if player:GetAttribute("DogState") == "arena" then
		return "arena"
	end
	return (type(where) == "string" and ISLAND_AREA[where]) or "hub"
end

-- Sound de uma música (a nova; sem pacote, a antiga equivalente)
local function soundFor(name: string): Sound?
	return songs[name] or oldTracks[FALLBACK[name] or "Main"] or oldTracks.Main
end

local function switchTo(name: string, fade: number?)
	local sound = soundFor(name)
	if sound == playing then
		playingName = name
		return
	end
	local seconds: number = fade or MusicConfig.Crossfade
	local old = playing
	if old then
		fadeTo(old, 0, seconds)
		task.delay(seconds + 0.05, function()
			if old ~= playing and old.Volume <= 0.001 then
				old:Pause()
			end
		end)
	end
	playing = sound
	playingName = name
	playingSince = os.clock()
	if sound then
		if not sound.IsPlaying then
			-- (volta de onde parou, se já tinha tocado)
			if sound.TimePosition > 0 and sound.TimePosition < (sound.PlaybackRegionsEnabled and sound.PlaybackRegion.Max or math.huge) then
				sound:Resume()
			else
				sound:Play()
			end
		end
		fadeTo(sound, 1, seconds)
	end
end

local function update()
	local area = wantedArea()
	local list = PLAYLISTS[area] or PLAYLISTS.hub
	if area ~= currentArea then
		currentArea = area
		areaIndex[area] = areaIndex[area] or 1
		switchTo(list[areaIndex[area]])
		return
	end
	-- 🔁 revezamento: depois de ROTATE s, a próxima música da lista (só se ela existir de verdade)
	if #list > 1 and os.clock() - playingSince > ROTATE then
		local nextIndex = (areaIndex[area] or 1) % #list + 1
		local nextName = list[nextIndex]
		if songs[nextName] and soundFor(nextName) ~= playing then
			areaIndex[area] = nextIndex
			switchTo(nextName, 3.5)
		else
			playingSince = os.clock()
		end
	end
end

-- 🎺 vinheta (música abaixa enquanto ela toca)
local function playJingle(key: string)
	if muted then
		return
	end
	local sound = regionSound(key, SoundService, jingleGroup)
	local length = MusicPacks.Songs[key] and MusicPacks.Songs[key].Length or 6
	if not sound then
		-- (sem o pacote novo: a vinheta antiga, se houver uma)
		local id = assetId(MusicConfig.Jingles[key])
		if not id then
			return
		end
		sound = Instance.new("Sound")
		sound.SoundId = id
		sound.SoundGroup = jingleGroup
		sound.Parent = SoundService
		length = 8
	end
	sound.Name = "Jingle" .. key
	sound.Volume = 1
	duck = MusicConfig.DuckDuringJingle
	applyGroupVolume()
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		duck = 1
		applyGroupVolume()
		sound:Destroy()
	end
	sound.Ended:Once(finish)
	sound:Play()
	task.delay(length + 0.6, finish)
end

function Music.Jingle(key: string)
	pcall(playJingle, key)
end

-- nome da música tocando agora (para testes/depuração)
function Music.Current(): string?
	return playingName
end

local function makeButton(_HUD)
	-- botão de som no canto direito da barra do Roblox (o HUD novo usa o espaço embaixo dela),
	-- quadradinho escuro igual aos botões do Roblox, com alto-falante desenhado (mudo = X vermelho)
	local GuiService = game:GetService("GuiService")
	local UI = script.Parent.Parent:WaitForChild("UI")
	local Icons = require(UI:WaitForChild("Icons"))

	local gui = Instance.new("ScreenGui")
	gui.Name = "MusicButton"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.Name = "Som"
	button.AnchorPoint = Vector2.new(1, 0)
	button.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	button.BackgroundTransparency = 0.45
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Text = ""
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = button
	local icon = Icons.Make(button, muted and "mute" or "speaker", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
	})

	-- tamanho e altura da barra do Roblox (PC 58 px, celular 36 px)
	local function place()
		local inset = math.max(GuiService:GetGuiInset().Y, 36)
		local size = math.clamp(inset - 14, 30, 44)
		button.Size = UDim2.fromOffset(size, size)
		button.Position = UDim2.new(1, -12, 0, math.max(2, math.floor((inset - size) / 2)))
	end
	place()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end

	local function refresh()
		Icons.Set(icon, muted and "mute" or "speaker")
	end
	refresh()
	button.Activated:Connect(function()
		muted = not muted
		player:SetAttribute(MUTE_ATTR, muted)
		refresh()
		applyGroupVolume()
	end)
	player:GetAttributeChangedSignal(MUTE_ATTR):Connect(function()
		muted = player:GetAttribute(MUTE_ATTR) == true
		refresh()
	end)
end

function Music.Start(HUD)
	muted = player:GetAttribute(MUTE_ATTR) == true
	musicGroup = makeGroup("Musica", MusicConfig.MusicVolume)
	jingleGroup = makeGroup("Jingles", MusicConfig.JingleVolume)

	local anyId = false
	-- trilha 2 (pacotes)
	local folder = Instance.new("Folder")
	folder.Name = "Musicas"
	folder.Parent = SoundService
	local preload = {}
	for name, info in pairs(MusicPacks.Songs) do
		if info.Loop then
			local sound = regionSound(name, folder, musicGroup)
			if sound then
				songs[name] = sound
				anyId = true
				table.insert(preload, sound)
			end
		end
	end
	-- trilha antiga (enquanto um pacote não foi enviado)
	for name, id in pairs(MusicConfig.Tracks) do
		local soundId = assetId(id)
		if soundId then
			anyId = true
			local sound = Instance.new("Sound")
			sound.Name = "Antiga_" .. name
			sound.SoundId = soundId
			sound.Looped = true
			sound.Volume = 0
			sound.SoundGroup = musicGroup
			sound.Parent = folder
			oldTracks[name] = sound
		end
	end
	for _, id in pairs(MusicConfig.Jingles) do
		if assetId(id) then
			anyId = true
		end
	end
	for _, id in pairs(MusicPacks.Packs) do
		if assetId(id) then
			anyId = true
		end
	end
	if not anyId then
		return -- nada enviado ainda: sem música, sem botão
	end
	-- (carrega os pacotes antes de tocar: senão o 1º trecho começa mudo)
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(preload)
		end)
	end)

	makeButton(HUD)
	applyGroupVolume()
	update()

	player:GetAttributeChangedSignal("DogState"):Connect(update)
	player:GetAttributeChangedSignal("InTower"):Connect(update)
	player:GetAttributeChangedSignal("Island"):Connect(update)
	player:GetAttributeChangedSignal(MUTE_ATTR):Connect(function()
		muted = player:GetAttribute(MUTE_ATTR) == true
		applyGroupVolume()
	end)
	player:GetAttributeChangedSignal("MusicVolume"):Connect(applyGroupVolume)
	task.spawn(function()
		while true do
			task.wait(1)
			update()
		end
	end)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local levelUp = remotes:FindFirstChild("LevelUp")
	if levelUp and levelUp:IsA("RemoteEvent") then
		levelUp.OnClientEvent:Connect(function()
			playJingle("LevelUp")
		end)
	end
	local hatched = remotes:FindFirstChild("Hatched")
	if hatched and hatched:IsA("RemoteEvent") then
		hatched.OnClientEvent:Connect(function()
			playJingle(MusicPacks.Songs.RareWin and "RareWin" or "Hatch")
		end)
	end
	local notify = remotes:FindFirstChild("Notify")
	if notify and notify:IsA("RemoteEvent") then
		notify.OnClientEvent:Connect(function(message)
			if typeof(message) ~= "string" then
				return
			end
			if message:find("🏆", 1, true) or message:find("DEFEATED", 1, true) then
				playJingle("Victory")
			elseif message:find("POWER UNLOCKED", 1, true) or message:find("New boss unlocked", 1, true) then
				playJingle("Unlock")
			end
		end)
	end
	-- 🏝️ ilha nova aberta (só quem comprou; os outros recebem só o aviso)
	local islandEvent = remotes:FindFirstChild("IslandEvent")
	if islandEvent and islandEvent:IsA("RemoteEvent") then
		islandEvent.OnClientEvent:Connect(function(kind)
			if kind == "unlocked" then
				playJingle("Unlock")
			end
		end)
	end
end

return Music
