-- 🏝️ Ilhas (2026-10, mapa novo): abrir cada ilha com Cash (em ordem: a anterior precisa estar aberta),
-- portais (Praça dos Portais ⇄ portal 🏠 HOME de cada ilha), viagem pelo menu 🗺️ MAP, em que ilha cada
-- jogador está (atributo "Island" = id, "colosseum", "village" (🏡 Pawville, ilha de entrada) ou "main"),
-- chão de lava que queima, quem cai das
-- nuvens é pego pelo vento e volta para cima, e quem chega numa ilha fechada (nadando, voando) volta.
-- Remotes: IslandAction (cliente → servidor) e IslandEvent (servidor → cliente: "locked"/"unlocked").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Islands = require(ReplicatedStorage.Shared.Islands)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Village = require(ReplicatedStorage.Shared.Village)
local RankIsland = require(ReplicatedStorage.Shared.RankIsland)
local DataService = require(script.Parent.DataService)
local DogService = require(script.Parent.DogService)
local Fighters = require(script.Parent.Fighters)
local ZoneGeo = require(script.Parent.ZoneGeo)

local IslandService = {}

local LAVA_DAMAGE = 0.06 -- fração da vida máxima a cada meio segundo em cima da lava
local remotes
local portals = {} -- { Part, CF, To, From }
local cooldown = {} -- [player] = os.clock() do último teleporte
local lockedToast = {} -- [player] = os.clock() do último aviso de portal trancado
local lastCloud = {} -- [player] = os.clock() da última vez em cima das nuvens
local lavaToast = {}
local outside = {} -- [player] = os.clock() desde quando está numa ilha fechada

function IslandService.IsOpen(player, id)
	if id == "common" or id == "main" or id == "colosseum" or id == Village.Id or id == RankIsland.Id then
		return true
	end
	local data = DataService.Get(player)
	return data ~= nil and type(data.Islands) == "table" and data.Islands[id] == true
end

-- a ilha já terminou de ser montada? (o WorldBuilder monta uma por vez quando o servidor abre)
local function ready(id)
	if id == "main" or id == "colosseum" then
		return true
	end
	if id == Village.Id then
		local folder = workspace:FindFirstChild("Islands")
		local model = folder and folder:FindFirstChild(id)
		return model ~= nil and model:GetAttribute("Ready") == true
	end
	local folder = workspace:FindFirstChild("Islands")
	local model = folder and folder:FindFirstChild(id)
	return model ~= nil and model:GetAttribute("Ready") == true
end
local function building(id)
	local name = id == Village.Id and Village.Name or id == RankIsland.Id and RankIsland.Name or Islands.List[id].Name
	return "🏗️ " .. name .. " is still being built... try again in a few seconds!"
end

-- chão de verdade embaixo de um ponto (as ilhas são mais altas que o mar)
local function groundAt(pos)
	local g = ZoneGeo.Ground(pos, pos.Y + 320, 700)
	return g or pos
end

local function teleport(player, pos)
	local now = os.clock()
	if now - (cooldown[player] or 0) < 1.5 then
		return false
	end
	cooldown[player] = now
	local f = DogService.GetFighter(player)
	local char = player.Character
	if f and Fighters.Alive(f) and char == f.Model then
		Fighters.EndDuel(f)
		f.Target = nil
		Fighters.Teleport(f, pos)
	elseif char and char.PrimaryPart then
		char:PivotTo(CFrame.new(pos + Vector3.new(0, 5, 0)))
	else
		return false
	end
	remotes.Effect:FireClient(player, "Teleport", { Position = pos })
	return true
end

-- chegada numa ilha (na frente do portal HOME dela) / na praça (na frente do portal daquela ilha)
function IslandService.ArrivalPos(id)
	if id == "main" then
		return groundAt(Layout.SPAWN_PLAZA + Vector3.new(0, 4, 0))
	elseif id == "colosseum" then
		return groundAt(Vector3.new(0, 4, Layout.COLOSSEUM_WALL + 26))
	elseif id == Village.Id then
		local sp = Village.SPAWN
		return groundAt(Village.ToWorld(sp.X, Village.GROUND_Y + 4, sp.Z))
	elseif id == RankIsland.Id then
		local sp = RankIsland.SPAWN
		return groundAt(RankIsland.ToWorld(sp.X, RankIsland.GROUND_Y + 4, sp.Z))
	end
	return groundAt(Islands.ArrivalPoint(id) + Vector3.new(0, 4, 0))
end
local function plazaFront(id)
	local cf = Islands.PlazaPortalCFrame(id) * CFrame.new(0, 4, -30)
	return groundAt(cf.Position)
end

function IslandService.Travel(player, id)
	if id ~= "main" and id ~= "colosseum" and id ~= Village.Id and id ~= RankIsland.Id and not Islands.List[id] then
		return false, "Unknown island."
	end
	if player:GetAttribute("InTower") then
		return false, "Leave the Boss Tower first."
	end
	if not IslandService.IsOpen(player, id) then
		return false, "🔒 Unlock " .. Islands.List[id].Name .. " first!"
	end
	if not ready(id) then
		return false, building(id)
	end
	if not teleport(player, IslandService.ArrivalPos(id)) then
		return false, "Wait a moment..."
	end
	local name = id == "main" and "the Main Island"
		or id == "colosseum" and "the ⚔️ Colosseum"
		or id == Village.Id and Village.Emoji .. " " .. Village.Name
		or id == RankIsland.Id and RankIsland.Emoji .. " the " .. RankIsland.Name
		or Islands.EMOJI[id] .. " " .. Islands.List[id].Name
	return true, "Welcome to " .. name .. "!"
end

function IslandService.Unlock(player, id)
	local def = Islands.List[id]
	local data = DataService.Get(player)
	if not (def and data and data.Started) then
		return false, "Invalid island."
	end
	if data.Islands[id] then
		return true, def.Name .. " is already open!"
	end
	-- 🔐 (2026-10-24) cada ilha pede cada vez mais: a anterior aberta, o level do cachorro, o campeão da anterior
	-- derrotado, missões feitas lá e o Cash (Islands.Requirements — o menu MAP mostra a mesma lista)
	local list = Islands.Requirements(data, id, Islands.EquippedLevel(data))
	for _, r in ipairs(list) do
		if not r.Done then
			if r.Kind == "island" then
				return false, "🔒 Open " .. r.Name .. " first!"
			elseif r.Kind == "level" then
				return false, "🐶 Your dog needs to be Lv." .. r.Need .. " (now Lv." .. r.Have .. ")"
			elseif r.Kind == "champion" then
				return false, "👑 Beat " .. r.Name .. ", the champion of " .. r.Island .. "!"
			elseif r.Kind == "missions" then
				return false, "📜 Finish " .. r.Need .. " missions in " .. r.Island .. " (" .. r.Have .. "/" .. r.Need .. ")"
			end
		end
	end
	local price = def.Price or 0
	if price > 0 and not DataService.Spend(player, price) then
		return false, "Not enough Cash! You need $" .. Config.Format(price)
	end
	data.Islands[id] = true
	DataService.MarkDirty(player)
	remotes.IslandEvent:FireClient(player, "unlocked", id)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			remotes.Notify:FireClient(p, "🏝️ " .. player.DisplayName .. " unlocked " .. def.Name .. "!", "gold")
		end
	end
	return true, "🏝️ " .. def.Name .. " unlocked! Step into the portal!"
end

---------------------------------------------------------------- portais
local function addPortal(part)
	local cf = part:GetAttribute("PortalCF")
	local to = part:GetAttribute("PortalTo")
	if typeof(cf) ~= "CFrame" or type(to) ~= "string" then
		return
	end
	table.insert(portals, { Part = part, CF = cf, To = to, From = part:GetAttribute("PortalFrom") })
end

local function usePortal(player, portal)
	if portal.To == "main" then
		if portal.From and Islands.List[portal.From] then
			teleport(player, plazaFront(portal.From))
		elseif teleport(player, IslandService.ArrivalPos("main")) and portal.From == Village.Id then
			-- 🌀 portal da ⚔️ ARENA da Pawville (a vila fica longe de tudo, sem ponte)
			remotes.Notify:FireClient(player, "⚔️ Welcome to the Arena! The portals to the islands are all around the Colosseum.", "gold")
		end
		return
	end
	if portal.To == RankIsland.Id then
		-- 🏆 portal da Ilha do Ranking (Pawville e Praça dos Portais)
		if not ready(RankIsland.Id) then
			local now = os.clock()
			if now - (lockedToast[player] or 0) > 3 then
				lockedToast[player] = now
				remotes.Notify:FireClient(player, building(RankIsland.Id), "gold")
			end
		elseif teleport(player, IslandService.ArrivalPos(RankIsland.Id)) then
			remotes.Notify:FireClient(player, "🏆 Welcome to the Ranking Island! See the best players, clans and Season Pass levels.", "gold")
		end
		return
	end
	if portal.To == Village.Id then
		-- 🏡 portal da Pawville na ilha principal: volta para a pracinha da vila
		if not ready(Village.Id) then
			local now = os.clock()
			if now - (lockedToast[player] or 0) > 3 then
				lockedToast[player] = now
				remotes.Notify:FireClient(player, building(Village.Id), "gold")
			end
		elseif teleport(player, IslandService.ArrivalPos(Village.Id)) then
			remotes.Notify:FireClient(player, Village.Emoji .. " Welcome back to " .. Village.Name .. "!", "gold")
		end
		return
	end
	if IslandService.IsOpen(player, portal.To) then
		if not ready(portal.To) then
			local now = os.clock()
			if now - (lockedToast[player] or 0) > 3 then
				lockedToast[player] = now
				remotes.Notify:FireClient(player, building(portal.To), "gold")
			end
			return
		end
		local ok = teleport(player, IslandService.ArrivalPos(portal.To))
		if ok then
			local def = Islands.List[portal.To]
			remotes.Notify:FireClient(player, Islands.EMOJI[portal.To] .. " " .. def.Name .. " — wild dogs Lv." .. def.Levels[1] .. "-" .. def.Levels[2], "gold")
		end
		return
	end
	local now = os.clock()
	if now - (lockedToast[player] or 0) > 3 then
		lockedToast[player] = now
		remotes.IslandEvent:FireClient(player, "locked", portal.To)
	end
end

local function checkPortals(player, pos)
	for _, portal in ipairs(portals) do
		local c = portal.CF.Position
		if math.abs(pos.X - c.X) < 30 and math.abs(pos.Z - c.Z) < 30 and portal.Part.Parent then
			local l = portal.CF:PointToObjectSpace(pos)
			if math.abs(l.X) < 16 and l.Y > -2 and l.Y < 46 and math.abs(l.Z) < 4.5 then
				usePortal(player, portal)
				return
			end
		end
	end
end

---------------------------------------------------------------- vigia (presença, lava, nuvens, ilhas fechadas)
local function watch(player, now)
	local char = player.Character
	local root = char and char.PrimaryPart
	if not root then
		return
	end
	local pos = root.Position
	checkPortals(player, pos)
	local island = Islands.At(pos, 30)
	-- (a vila conta só pelo mapa de cima: cachorro afundando no mar dela continua "na vila" e renasce lá, não na ilha
	-- principal — 2026-10-23, "estou nascendo na ilha errada")
	local flatPos = Vector3.new(pos.X, Village.Center.Y + Village.GROUND_Y, pos.Z)
	local where = island
		or (Layout.InArena(pos) and "colosseum")
		or (Village.Inside(flatPos, 40) and Village.Id)
		or (RankIsland.Inside(Vector3.new(pos.X, RankIsland.GROUND_Y, pos.Z), 40) and RankIsland.Id)
		or "main"
	if player:GetAttribute("Island") ~= where then
		player:SetAttribute("Island", where)
	end
	-- 🌊 rede de segurança (2026-10-25, "para ninguém cair no limbo"): afundou abaixo do chão invisível do mar ou passou
	-- das paredes invisíveis da beira do mundo (Layout.WORLD) → volta para a terra (a ilha onde estava, se aberta)
	if pos.Y < Layout.WORLD.RescueY or not Layout.InWorld(pos, -40) then
		local back = (island and IslandService.IsOpen(player, island) and island)
			or ((where == Village.Id or where == RankIsland.Id) and where)
			or "main"
		cooldown[player] = 0
		if teleport(player, IslandService.ArrivalPos(back)) then
			remotes.Notify:FireClient(player, "🌊 Whoa, too far! Back to dry land!", "gold")
		end
		return
	end
	-- chegou numa ilha que ainda não abriu (nadando/voando): volta para a praça
	if island and not IslandService.IsOpen(player, island) then
		outside[player] = outside[player] or now
		if now - outside[player] > 1 then
			outside[player] = nil
			teleport(player, plazaFront(island))
			remotes.IslandEvent:FireClient(player, "locked", island)
		end
	else
		outside[player] = nil
	end
	-- ☁️ caiu das nuvens: o vento pega e leva de volta para cima
	if island == "cloud" then
		lastCloud[player] = now
	elseif now - (lastCloud[player] or -99) < 12 and pos.Y < Islands.CLOUD_Y - 80 and pos.Y > -80 then
		lastCloud[player] = now
		cooldown[player] = 0
		if teleport(player, IslandService.ArrivalPos("cloud")) then
			remotes.Notify:FireClient(player, "☁️ Whoa! The wind caught you!", "gold")
		end
	end
	-- 🔥 lava queima (o chão CrackedLava do vulcão)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.FloorMaterial == Enum.Material.CrackedLava then
		local f = DogService.GetFighter(player)
		if f and Fighters.Alive(f) and f.Model == char then
			Fighters.Damage(nil, f, f.Humanoid.MaxHealth * LAVA_DAMAGE, { Color = Color3.fromRGB(255, 120, 40) })
		else
			hum.Health -= hum.MaxHealth * LAVA_DAMAGE
		end
		if now - (lavaToast[player] or 0) > 4 then
			lavaToast[player] = now
			remotes.Notify:FireClient(player, "🔥 HOT! Lava burns — get out!", "red")
		end
	end
end

function IslandService.Start(r)
	remotes = r
	for _, part in ipairs(CollectionService:GetTagged("IslandPortal")) do
		addPortal(part)
	end
	CollectionService:GetInstanceAddedSignal("IslandPortal"):Connect(function(part)
		task.defer(addPortal, part)
	end)
	remotes.IslandAction.OnServerInvoke = function(player, action, id)
		if not DataService.Throttle(player, "IslandAction", 0.4) then
			return false, "Easy!"
		end
		if action == "unlock" and type(id) == "string" then
			return IslandService.Unlock(player, id)
		elseif action == "travel" and type(id) == "string" then
			return IslandService.Travel(player, id)
		end
		return false, "Invalid action."
	end
	Players.PlayerRemoving:Connect(function(player)
		cooldown[player] = nil
		lockedToast[player] = nil
		lastCloud[player] = nil
		lavaToast[player] = nil
		outside[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(watch, player, now)
				if not ok then
					warn("[IslandService]", err)
				end
			end
		end
	end)
end

return IslandService
