-- Efeitos sonoros do jogo inteiro: golpes, mordidas, poderes, morte, Cash, cliques, menus, avisos, loja, missões.
-- Todos os sons estão num único áudio (pacote, Shared/SfxConfig); cada um é um trecho tocado com
-- Sound.PlaybackRegion. Sem pacote o jogo fica sem efeitos (não dá erro).
-- Sons do mundo (luta, poderes) saem do lugar onde acontecem (3D); sons de interface são 2D.
-- 🔊 (2026-10-25, pedido do dono: "quero som para tudo, porque tem várias coisas sem som") pacote 2 (SfxConfig.Pack2)
-- com latidos de vários tamanhos, passos, captura, roleta, portal, falas da guia, torcida, buzina do Super Boss e
-- ambientes em loop (Sfx.Loop). Enquanto o pacote 2 não for enviado, o pacote antigo toca e cada som novo cai no
-- parecido (FALLBACK). Os avisos (HUD.Toast) tocam som pela cor; abrir/fechar menu também.
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SfxConfig = require(ReplicatedStorage.Shared.SfxConfig)

local Sfx = {}

local player = Players.LocalPlayer
local MUTE_ATTR = "SfxMudo"

local packId: string? = nil
local regions: { [string]: { number } } = {}
local loops: { [string]: { number } } = {}
local group: SoundGroup
local uiFolder: Folder
local lastPlayed: { [string]: number } = {}

-- som novo → parecido do pacote antigo (enquanto o pacote 2 não foi enviado)
local FALLBACK = {
	Yip = "Bark", Woof = "Bark", Bark2 = "Bark", Growl = "Roar", Howl = "Roar", Whine = "KO", Yelp = "Hit",
	Tick = "Click", SpinStart = "Charge", Reveal = "Magic", Select = "Click", Confirm = "Quest", Toast = "Notify",
	Tab = "Click", CashBig = "Purchase", LeashThrow = "Whoosh", LeashShake = "Click", Gotcha = "Purchase",
	Escape = "Poof", Portal = "Magic", Unlock = "Quest", Horn = "Roar", Trade = "Purchase", Paper = "Open",
	Flap = "Whoosh", Land = "Hit",
}

-- efeito visual (remote Effect) → som. Os que não estão aqui tocam DEFAULT_FX baixinho.
local FX_SOUND = {
	Bite = "Bite",
	BiteMark = "Bite",
	SpectralBite = "Bite",
	Hit = "Punch",
	Roar = "Roar",
	TitanGrow = "Roar",
	Telegraph = "Charge",
	ThunderCharge = "Thunder",
	ThunderDash = "Thunder",
	Lightning = "Thunder",
	Smoke = "Smoke",
	Cloud = "Smoke",
	Streak = "Whoosh",
	Trail = "Whoosh",
	TailSwipe = "Whoosh",
	Vortex = "Whoosh",
	Cone = "Whoosh",
	Impact = "Slam",
	Shockwave = "Slam",
	GroundSlam = "Slam",
	SonicBoom = "Explosion",
	Explosion = "Explosion",
	Meteor = "Explosion",
	EyeGlow = "Magic",
	Circle = "Magic",
	Clones = "Magic",
	TitanAura = "Magic",
	LevelUp = "Magic",
	Burn = "Burn",
	Lava = "Fire",
	LavaCracks = "Fire",
	FireSpot = "Fire",
	FireRing = "Fire",
	Ignite = "Fire",
	PhoenixRise = "Fire",
	IceField = "Ice",
	IceWave = "Ice",
	Freeze = "Freeze",
	Slash = "Slash",
	ShadowStrike = "Slash",
	Spikes = "Spikes",
	Projectile = "Projectile",
	Glob = "Water",
	Geyser = "Water",
	Fin = "Water",
	Laser = "Laser",
	Tractor = "Laser",
	SpecialName = "Howl",
	Cash = "Coin",
	XP = "XP",
}
local DEFAULT_FX = "Whoosh"
local SILENT_FX = { Shake = true, Damage = true } -- Damage só toca se for crítico (abaixo)

-- volume por som
local VOLUME = {
	Click = 0.35,
	Open = 0.4,
	Close = 0.35,
	Notify = 0.45,
	Toast = 0.35,
	Coin = 0.55,
	XP = 0.4,
	Bite = 0.7,
	Punch = 0.75,
	Whoosh = 0.5,
	Charge = 0.5,
	Eat = 0.6,
	Bark = 0.65,
	Bark2 = 0.65,
	Yip = 0.6,
	Woof = 0.7,
	Growl = 0.55,
	Howl = 0.55,
	Step = 0.16,
	Land = 0.35,
	Blip = 0.22,
	Tick = 0.4,
	Tab = 0.3,
	Clap = 0.5,
	Cheer = 0.5,
}
local MIN_GAP = 0.05 -- s: o mesmo som não repete mais rápido que isso (vários efeitos no mesmo frame)

local function muted(): boolean
	return player:GetAttribute(MUTE_ATTR) == true
end

local function userVolume(): number
	local v = player:GetAttribute("SfxVolume")
	if typeof(v) ~= "number" or v ~= v then
		return 1
	end
	return math.clamp(v, 0, 1)
end

local function region(name: string)
	local r = regions[name]
	if not r and FALLBACK[name] then
		r = regions[FALLBACK[name]]
	end
	return r
end

-- O som existe (no pacote que está valendo)?
function Sfx.Has(name: string): boolean
	return packId ~= nil and region(name) ~= nil
end

-- onde o som fica: nil (2D), Vector3 (ponto no mundo) ou BasePart/Model (segue o objeto)
local function holderFor(where: any): (Instance, Instance?)
	if typeof(where) == "Vector3" then
		local att = Instance.new("Attachment")
		att.WorldPosition = where
		att.Parent = workspace.Terrain
		return att, att
	elseif typeof(where) == "Instance" then
		local part = where:IsA("BasePart") and where or (where:IsA("Model") and where.PrimaryPart)
		if part and part.Parent then
			return part, nil
		end
	end
	return uiFolder, nil
end

-- Toca um som. where: nil (2D), Vector3 ou BasePart/Model. opts: { Volume, Pitch, Gap }
function Sfx.Play(name: string, where: any?, opts: { Volume: number?, Pitch: number?, Gap: number? }?)
	if not packId or muted() then
		return
	end
	local r = region(name)
	if not r then
		return
	end
	local now = os.clock()
	if now - (lastPlayed[name] or 0) < ((opts and opts.Gap) or MIN_GAP) then
		return
	end
	lastPlayed[name] = now

	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = packId
	sound.SoundGroup = group
	sound.PlaybackRegionsEnabled = true
	sound.PlaybackRegion = NumberRange.new(r[1], r[1] + r[2])
	sound.Volume = ((opts and opts.Volume) or VOLUME[name] or 0.6) * userVolume()
	local pitch = (opts and opts.Pitch) or (where ~= nil and (0.92 + math.random() * 0.16) or 1)
	sound.PlaybackSpeed = pitch
	sound.RollOffMinDistance = 12
	sound.RollOffMaxDistance = 220

	local holder, temp = holderFor(where)
	sound.Parent = holder
	sound:Play()
	task.delay(r[2] / pitch + 0.2, function()
		sound:Destroy()
		if temp then
			temp:Destroy()
		end
	end)
end

-- 🌳 ambiente em loop (pacote 2): devolve o Sound (volume 0, já tocando) ou nil. Quem chamou controla o volume.
function Sfx.Loop(name: string, parent: Instance?): Sound?
	local r = loops[name]
	if not (packId and r) then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = packId
	sound.SoundGroup = group
	sound.PlaybackRegionsEnabled = true
	sound.PlaybackRegion = NumberRange.new(r[1], r[1] + r[2])
	sound.LoopRegion = NumberRange.new(r[1], r[1] + r[2])
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = parent or uiFolder
	sound:Play()
	return sound
end

-- volume de efeitos escolhido pelo jogador (0 a 1) e se está mudo — para quem toca loops
function Sfx.UserVolume(): number
	return muted() and 0 or userVolume()
end

-- 🐶 voz de um cachorro pelo tamanho (altura em studs): pequenos latem fino, grandes grosso
function Sfx.VoiceFor(height: number, kind: string?): (string, number)
	kind = kind or "bark"
	if kind == "howl" then
		return "Howl", math.clamp(1.35 - height * 0.08, 0.75, 1.3)
	elseif kind == "growl" then
		return "Growl", math.clamp(1.3 - height * 0.07, 0.75, 1.25)
	elseif kind == "whine" then
		return "Whine", math.clamp(1.3 - height * 0.06, 0.8, 1.25)
	end
	if height < 2.6 then
		return "Yip", 1.05 + math.random() * 0.2
	elseif height < 4.2 then
		return (math.random() < 0.5 and "Bark" or "Bark2"), 0.95 + math.random() * 0.15
	end
	return "Woof", math.clamp(1.15 - (height - 4.2) * 0.06, 0.78, 1.05) + math.random() * 0.06
end

local heightCache = setmetatable({}, { __mode = "k" })
function Sfx.HeightOf(model: Instance): number
	local h = heightCache[model]
	if not h and model:IsA("Model") then
		local ok, size = pcall(model.GetExtentsSize, model)
		h = ok and size.Y or 3
		heightCache[model] = h
	end
	return h or 3
end

-- o cachorro (Model) fala: "bark" | "howl" | "growl" | "whine"
function Sfx.Voice(model: Instance, kind: string?, opts: { Volume: number? }?)
	if not (model and model.Parent) then
		return
	end
	local name, pitch = Sfx.VoiceFor(Sfx.HeightOf(model), kind)
	Sfx.Play(name, model, { Pitch = pitch, Volume = opts and opts.Volume, Gap = 0.15 })
end

---------------------------------------------------------------- efeitos de luta/poder
local function fxWhere(params: { [string]: any }): any
	local p = params.Position or params.From or params.Center or params.At
	if typeof(p) == "Vector3" then
		return p
	end
	if typeof(params.Positions) == "table" and typeof(params.Positions[1]) == "Vector3" then
		return params.Positions[1]
	end
	if typeof(params.Model) == "Instance" then
		return params.Model
	end
	return nil
end

local function onEffect(name: string, params: any)
	if type(params) ~= "table" then
		return
	end
	if name == "Damage" then
		if params.Crit then
			Sfx.Play("Crit", fxWhere(params))
		end
		return
	end
	if SILENT_FX[name] then
		return
	end
	if name == "Freeze" and params.Kind and params.Kind ~= "ice" then
		Sfx.Play("Magic", fxWhere(params))
		return
	end
	-- Cash/XP: só para quem ganhou (quando o servidor diz o jogador)
	if (name == "Cash" or name == "XP") and params.Player and params.Player ~= player.UserId then
		return
	end
	local sound = FX_SOUND[name]
	if sound then
		Sfx.Play(sound, fxWhere(params))
	else
		Sfx.Play(DEFAULT_FX, fxWhere(params), { Volume = 0.3 })
	end
end

---------------------------------------------------------------- cachorros: comer, desmaiar, sumir, duelo
local ACTION_SOUND = {
	KO = "KO",
	Eat = "Eat",
	Spin = "Whoosh",
	Dive = "Whoosh",
}

local function watchDog(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local lastPos: Vector3? = nil
	model:GetAttributeChangedSignal("Action"):Connect(function()
		local action = model:GetAttribute("Action")
		if action == "Howl" then
			Sfx.Voice(model, "howl")
		elseif action == "Roar" then
			Sfx.Play("Roar", model)
		elseif action == "KO" then
			Sfx.Play("KO", model)
			Sfx.Voice(model, "whine", { Volume = 0.45 })
		else
			local sound = action and ACTION_SOUND[action]
			if sound then
				Sfx.Play(sound, model)
			end
		end
	end)
	-- duelo começou (o meu cachorro): gongo · o selvagem que veio brigar comigo rosna
	model:GetAttributeChangedSignal("DuelId"):Connect(function()
		local id = model:GetAttribute("DuelId")
		if typeof(id) ~= "number" or id == 0 then
			return
		end
		if model:GetAttribute("Owner") == player.UserId then
			Sfx.Play("Duel")
		elseif model:GetAttribute("Kind") == "npc" then
			task.delay(0.15, Sfx.Voice, model, "growl", { Volume = 0.5 })
		end
	end)
	local function track()
		local root = model.PrimaryPart
		if root then
			lastPos = root.Position
		end
	end
	track()
	task.spawn(function()
		while model.Parent do
			track()
			task.wait(0.5)
		end
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if not parent and lastPos and model:GetAttribute("Action") == "KO" then
			Sfx.Play("Poof", lastPos)
		end
	end)
end

---------------------------------------------------------------- interface
local function hookButton(obj: Instance)
	if obj:IsA("GuiButton") then
		obj.Activated:Connect(function()
			Sfx.Play("Click")
		end)
	end
end

-- 🔔 todo aviso (HUD.Toast: do servidor e do próprio cliente) toca um som pela cor/texto
local function onToast(message: any, color: any)
	if typeof(message) ~= "string" then
		return
	end
	if message:find("🥚 An egg appeared", 1, true) then
		Sfx.Play("EggPop")
	elseif message:find("woke up", 1, true) or message:find("full HP", 1, true) then
		Sfx.Play("Respawn")
	elseif message:find("recovered", 1, true) then
		Sfx.Play("Heal")
	elseif message:find("🏆", 1, true) or message:find("DEFEATED", 1, true) then
		Sfx.Play("CashBig")
		if player:GetAttribute("Island") == "colosseum" then
			Sfx.Play("Cheer")
		end
	elseif message:find("Auto-sold", 1, true) or message:find("+$", 1, true) then
		Sfx.Play("Coin")
	elseif message:find("UNLOCKED", 1, true) or message:find("unlocked", 1, true) then
		Sfx.Play("Unlock")
	elseif color == "red" then
		Sfx.Play("Error")
	elseif color == "green" then
		Sfx.Play("Confirm")
	elseif color == "gold" then
		Sfx.Play("Notify")
	else
		Sfx.Play("Toast")
	end
end

function Sfx.Start(HUD)
	-- pacote 2 (novo) se já foi enviado; senão o antigo com os tempos dele
	local id2, id1 = SfxConfig.Pack2, SfxConfig.Pack
	if typeof(id2) == "number" and id2 > 0 then
		packId = "rbxassetid://" .. tostring(math.floor(id2))
		regions = SfxConfig.Regions
		loops = SfxConfig.Loops or {}
	elseif typeof(id1) == "number" and id1 > 0 then
		packId = "rbxassetid://" .. tostring(math.floor(id1))
		regions = SfxConfig.OldRegions or {}
		loops = {}
	end
	local existing = SoundService:FindFirstChild("Efeitos")
	if existing and existing:IsA("SoundGroup") then
		group = existing
	else
		local newGroup = Instance.new("SoundGroup")
		newGroup.Name = "Efeitos"
		newGroup.Volume = 0.8
		newGroup.Parent = SoundService
		group = newGroup
	end
	uiFolder = Instance.new("Folder")
	uiFolder.Name = "SfxUI"
	uiFolder.Parent = SoundService
	if not packId then
		return
	end
	-- carrega o pacote antes do primeiro som (senão o primeiro golpe sai mudo)
	task.spawn(function()
		local preload = Instance.new("Sound")
		preload.SoundId = packId
		preload.Parent = uiFolder
		pcall(function()
			ContentProvider:PreloadAsync({ preload })
		end)
		preload:Destroy()
	end)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("Effect").OnClientEvent:Connect(function(name, params)
		local ok, err = pcall(onEffect, name, params)
		if not ok then
			warn("[Sfx]", name, err)
		end
	end)
	-- avisos: pelo HUD (pega os do servidor e os do cliente); sem HUD, só os do servidor
	if HUD and HUD.Toast then
		HUD.OnToast = onToast
	else
		remotes:WaitForChild("Notify").OnClientEvent:Connect(onToast)
	end
	-- menus abrindo e fechando
	if HUD and HUD.MenuChanged then
		HUD.MenuChanged:Connect(function(name)
			Sfx.Play(name and "Open" or "Close")
		end)
	end
	remotes:WaitForChild("Hatched").OnClientEvent:Connect(function()
		Sfx.Play("EggCrack")
		task.delay(0.35, Sfx.Play, "EggCrack", nil, { Pitch = 1.15 })
		task.delay(0.9, Sfx.Play, "Hatch")
	end)
	local purchased = remotes:FindFirstChild("Purchased")
	if purchased and purchased:IsA("RemoteEvent") then
		purchased.OnClientEvent:Connect(function()
			Sfx.Play("Purchase")
		end)
	end
	local progress = remotes:FindFirstChild("Progress")
	if progress and progress:IsA("RemoteEvent") then
		progress.OnClientEvent:Connect(function(kind)
			if kind == "done" or kind == "achievement" then
				Sfx.Play("Quest")
			elseif kind == "bonus" then
				Sfx.Play("CashBig")
			elseif kind == "evolve" then
				Sfx.Play("Magic")
			end
		end)
	end
	local food = remotes:FindFirstChild("FoodReward")
	if food and food:IsA("RemoteEvent") then
		food.OnClientEvent:Connect(function()
			Sfx.Play("XP")
		end)
	end
	-- 🌀 trocou de ilha (portal) · 🌍 Super Boss acordou (buzina + rugido)
	local lastIsland = player:GetAttribute("Island")
	local since = os.clock()
	player:GetAttributeChangedSignal("Island"):Connect(function()
		local now = player:GetAttribute("Island")
		if now ~= lastIsland and os.clock() - since > 3 then
			Sfx.Play("Portal", nil, { Volume = 0.55 })
		end
		lastIsland = now
	end)
	workspace:GetAttributeChangedSignal("SuperBossAwake"):Connect(function()
		if workspace:GetAttribute("SuperBossAwake") then
			Sfx.Play("Horn", nil, { Volume = 0.6 })
			task.delay(1.0, Sfx.Play, "Roar", nil, { Volume = 0.6, Pitch = 0.8 })
		end
	end)

	for _, model in ipairs(CollectionService:GetTagged("Dog")) do
		watchDog(model)
	end
	CollectionService:GetInstanceAddedSignal("Dog"):Connect(watchDog)

	local gui = player:WaitForChild("PlayerGui")
	for _, obj in ipairs(gui:GetDescendants()) do
		hookButton(obj)
	end
	gui.DescendantAdded:Connect(hookButton)
end

return Sfx
