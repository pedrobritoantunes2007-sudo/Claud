-- ✨ Orbes (pedido do dono): bolas brilhantes que o jogador usa chegando perto e apertando E.
-- (2026-10, mapa novo) Nascem nos pontos marcados de cada ilha (OrbSpot) onde tem jogador, e no chão do
-- Coliseu quando tem gente lá. Até MAX_PER_ISLAND por ilha; os que ninguém pega somem depois de LIFETIME s.
--   💚 Vida: +40% de vida   🔥 Fúria: +50% de dano por 10 s   💰 Cash: dinheiro pelo level
--   👑 Supremo: +35% na barra do Supremo (Míticos) / XP para os outros
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local DataService = require(script.Parent.DataService)
local Fighters = require(script.Parent.Fighters)

local ArenaOrbs = {}

local MAX_PER_ISLAND = 6
local MAX_COLOSSEUM = 8
local SPAWN_EVERY = 4
local LIFETIME = 150

local TYPES = {
	{ Id = "Heal", Color = Color3.fromRGB(90, 235, 120), Label = "💚 HEAL", Weight = 4 },
	{ Id = "Rage", Color = Color3.fromRGB(255, 70, 50), Label = "🔥 RAGE", Weight = 3 },
	{ Id = "Cash", Color = Color3.fromRGB(255, 205, 60), Label = "💰 CASH", Weight = 3 },
	{ Id = "Power", Color = Color3.fromRGB(190, 110, 255), Label = "👑 POWER", Weight = 2 },
	{ Id = "Shield", Color = Color3.fromRGB(110, 200, 255), Label = "🛡️ SHIELD", Weight = 3 },
	{ Id = "Speed", Color = Color3.fromRGB(255, 255, 255), Label = "⚡ SPEED", Weight = 3 },
	{ Id = "Jackpot", Color = Color3.fromRGB(255, 140, 0), Label = "🎰 JACKPOT", Weight = 1 },
}

local remotes
local folder
local counts = {} -- [ilha] = orbes vivos
local spotCache = {} -- [ilha] = { posições }

local function pickType()
	local total = 0
	for _, t in ipairs(TYPES) do
		total += t.Weight
	end
	local r = math.random() * total
	for _, t in ipairs(TYPES) do
		r -= t.Weight
		if r <= 0 then
			return t
		end
	end
	return TYPES[1]
end

local function apply(f, kind)
	local player = f.Owner
	local hum = f.Humanoid
	if kind.Id == "Heal" then
		hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.4)
	elseif kind.Id == "Rage" then
		f.DamageDealt = (f.DamageDealt or 1) * 1.5
		f.Model:SetAttribute("Raging", true)
		task.delay(10, function()
			f.DamageDealt = (f.DamageDealt or 1.5) / 1.5
			if f.Model.Parent then
				f.Model:SetAttribute("Raging", nil)
			end
		end)
	elseif kind.Id == "Cash" then
		DataService.AddCash(player, math.floor(30 + f.Level * 12), "reward")
	elseif kind.Id == "Shield" then
		-- 🛡️ escudo: toma metade do dano por 8 s
		f.DamageTaken = (f.DamageTaken or 1) * 0.5
		f.Model:SetAttribute("Shielded", true)
		task.delay(8, function()
			f.DamageTaken = (f.DamageTaken or 0.5) / 0.5
			if f.Model.Parent then
				f.Model:SetAttribute("Shielded", nil)
			end
		end)
	elseif kind.Id == "Speed" then
		-- ⚡ 40% mais rápido por 8 s (o cliente lê BaseSpeed do modelo)
		local base = f.Model:GetAttribute("BaseSpeed") or f.Stats.Speed
		f.Model:SetAttribute("BaseSpeed", base * 1.4)
		task.delay(8, function()
			if f.Model.Parent then
				f.Model:SetAttribute("BaseSpeed", f.Stats.Speed)
			end
		end)
	elseif kind.Id == "Jackpot" then
		DataService.AddCash(player, math.floor(300 + f.Level * 60), "reward")
		Fighters.Fx("Cash", { Position = f.Root.Position + Vector3.new(0, 4, 0), Amount = math.floor(300 + f.Level * 60), Player = player.UserId })
	elseif kind.Id == "Power" then
		if Config.HasSupreme(f.Species.Rarity) and Config.PowerUnlocked(f.Level, 3, f.Species.Rarity) then
			player:SetAttribute("Supreme", math.min(100, (player:GetAttribute("Supreme") or 0) + 35))
		else
			DataService.GiveXP(player, math.floor(20 + f.Level * 6), "reward")
		end
	end
	Fighters.Fx("Shockwave", { Position = f.Root.Position, Radius = 10, Color = kind.Color, Thick = true })
	Fighters.Fx("Impact", { Position = f.Root.Position, Radius = 6, Color = kind.Color })
	remotes.Notify:FireClient(player, kind.Label .. "!", "gold")
end

local function spawnOrb(key, pos)
	local kind = pickType()
	local holder = Instance.new("Model")
	holder.Name = "Orb"
	local orb = Instance.new("Part")
	orb.Name = "Orb_" .. kind.Id
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(3.4, 3.4, 3.4)
	orb.Color = kind.Color
	orb.Material = Enum.Material.Neon
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CFrame = CFrame.new(pos)
	local light = Instance.new("PointLight")
	light.Color = kind.Color
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = orb
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 6
	sparkle.Lifetime = NumberRange.new(0.6, 1)
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.LightEmission = 1
	sparkle.Color = ColorSequence.new(kind.Color)
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.Parent = orb
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(110, 26)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Parent = orb
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = kind.Label
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = kind.Color
	label.TextStrokeTransparency = 0
	label.Parent = gui
	-- coluna de luz: dá para ver o orbe de longe na Arena gigante
	local beam = Instance.new("Part")
	beam.Name = "Coluna"
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(60, 1.2, 1.2)
	beam.CFrame = CFrame.new(pos + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Color = kind.Color
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.6
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Parent = orb
	local taken = false
	local function take(f)
		if taken then
			return
		end
		taken = true
		counts[key] = math.max(0, (counts[key] or 1) - 1)
		holder:Destroy()
		if f then
			apply(f, kind)
		end
	end
	task.delay(LIFETIME, function()
		if not taken then
			take(nil)
		end
	end)
	-- tecla E (ProximityPrompt; no celular aparece o botão para tocar): o jogador escolhe quando usar o orbe
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Use " .. kind.Label
	prompt.ObjectText = "Orb"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = orb
	prompt.Triggered:Connect(function(p)
		local character = p.Character
		local f = character and Fighters.List[character]
		if f and f.Kind == "player" and Fighters.Alive(f) and (f.Root.Position - orb.Position).Magnitude < 18 then
			take(f)
		end
	end)
	orb.Parent = holder
	-- sobe e desce devagar (quem anima é o cliente: tag "Bobber" do WorldMotion)
	holder.PrimaryPart = orb
	holder:SetAttribute("BobHeight", 0.6)
	holder:SetAttribute("BobSpeed", 2)
	game:GetService("CollectionService"):AddTag(holder, "Bobber")
	holder.Parent = folder
	counts[key] = (counts[key] or 0) + 1
end

-- pontos marcados nas ilhas (World/Isles: ctx:OrbSpot), lidos uma vez quando a ilha fica pronta
local function islandSpots(id)
	if spotCache[id] then
		return spotCache[id]
	end
	local isles = workspace:FindFirstChild("Islands")
	local model = isles and isles:FindFirstChild(id)
	if not (model and model:GetAttribute("Ready")) then
		return nil
	end
	local list = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d.Name == "OrbSpot" and d:IsA("BasePart") then
			table.insert(list, d.Position)
		end
	end
	spotCache[id] = list
	return list
end

local function freeSpot(list)
	for _ = 1, 6 do
		local p = list[math.random(1, #list)]
		local busy = false
		for _, o in ipairs(folder:GetChildren()) do
			if o.PrimaryPart and (o.PrimaryPart.Position - p).Magnitude < 8 then
				busy = true
				break
			end
		end
		if not busy then
			return p
		end
	end
	return nil
end

local function colosseumPoint()
	local a = math.random() * math.pi * 2
	local r = math.sqrt(math.random()) * (Layout.ARENA_RADIUS - 16)
	return Layout.ARENA_CENTER + Vector3.new(math.cos(a) * r, 3.5, math.sin(a) * r)
end

local function spawnRound()
	local present = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local where = p:GetAttribute("Island")
		-- (a 🏡 Pawville é zona segura: sem orbes)
		if type(where) == "string" and where ~= "main" and where ~= "village" then
			present[where] = true
		end
	end
	for key in pairs(present) do
		if key == "colosseum" then
			if (counts[key] or 0) < MAX_COLOSSEUM then
				spawnOrb(key, colosseumPoint())
			end
		elseif (counts[key] or 0) < MAX_PER_ISLAND then
			local list = islandSpots(key)
			local pos = list and #list > 0 and freeSpot(list)
			if pos then
				spawnOrb(key, pos)
			end
		end
	end
end

function ArenaOrbs.Start(r)
	remotes = r
	folder = Instance.new("Folder")
	folder.Name = "ArenaOrbs"
	folder.Parent = workspace
	task.spawn(function()
		task.wait(5)
		while true do
			local ok, err = pcall(spawnRound)
			if not ok then
				warn("[Orbs]", err)
			end
			task.wait(SPAWN_EVERY)
		end
	end)
end

return ArenaOrbs
