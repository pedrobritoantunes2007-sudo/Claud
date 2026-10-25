-- Terreno de cada jogador: casinha, estande de treino 🪵 (atrás, no canto) e upgrades.
-- ⚠️ 2026-10 (pedido do dono): com Config.HOUSES = false NÃO existe mais terreno/casinha/estande — ninguém
-- recebe terreno, as funções devolvem nil e o SendHome leva para a pracinha da 🏡 Pawville (DogService.HomeCFrame).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Signal)

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Village = require(ReplicatedStorage.Shared.Village)
local DataService = require(script.Parent.DataService)
local HouseBuilder = require(script.Parent.HouseBuilder)

local PlotService = {}

-- Altura real do chão (Terrain) num ponto: o gramado do Terrain fica um pouco acima de Y=0
-- e deixava tigelas/ração/ovos enterrados. Tudo do terreno se apoia em cima da grama.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }
local function snap(cf)
	local p = cf.Position
	local hit = workspace:Raycast(p + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), groundParams)
	if hit then
		return cf + Vector3.new(0, hit.Position.Y - p.Y, 0)
	end
	return cf
end
PlotService.Snap = snap
PlotService.EggPressed = Signal.new() -- (player, eggIndex) — legado (ninho não existe mais)

local plots = {} -- [index] = player
local byPlayer = {} -- [player] = { Index, Model, Stand = { Model, Body }, HouseSig }
local remotes

function PlotService.Index(player)
	local p = byPlayer[player]
	return p and p.Index
end

function PlotService.Folder(player)
	local p = byPlayer[player]
	return p and p.Model:FindFirstChild("Dinamico")
end

function PlotService.CFrame(player)
	local p = byPlayer[player]
	return p and Layout.PlotCFrame(p.Index)
end

function PlotService.WorldPoint(player, localCf)
	local cf = PlotService.CFrame(player)
	return cf and (cf * localCf).Position
end

---------------------------------------------------------------- estande de treino
-- { Model, Body, Position (meio do boneco), Spot (onde o cachorro para), Path (caminho do lado da casa), XP }
function PlotService.GetStand(player)
	local p = byPlayer[player]
	if not (p and p.Stand and p.Stand.Model.Parent) then
		return nil
	end
	local data = DataService.Get(player)
	local level = data and data.Stand or 1
	local cf = Layout.PlotCFrame(p.Index)
	return {
		Model = p.Stand.Model,
		Body = p.Stand.Body,
		Position = p.Stand.Body.Position,
		Spot = snap(cf * Layout.PLOT.StandSpot).Position,
		Path = snap(cf * Layout.PLOT.StandPath).Position,
		XP = (Config.STAND[level] or Config.STAND[1]).XP,
	}
end

---------------------------------------------------------------- render
local function equippedName(data)
	local dog = data.Equipped and data.Dogs[data.Equipped]
	return dog and dog.Name or "Buddy"
end

local function renderHouse(player, p, data)
	local sig = data.HouseLevel .. "|" .. tostring(data.Stand) .. "|" .. equippedName(data)
	if sig == p.HouseSig then
		return
	end
	p.HouseSig = sig
	local dynamic = p.Model.Dinamico
	for _, name in ipairs({ "Casa", "Estande", "Ninho" }) do
		local old = dynamic:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local cf = Layout.PlotCFrame(p.Index)
	local house = HouseBuilder.House(data.HouseLevel, snap(cf * Layout.PLOT.House), equippedName(data))
	house.Parent = dynamic
	local stand, body = HouseBuilder.Stand(data.Stand or 1, snap(cf * Layout.PLOT.Stand))
	stand.Parent = dynamic
	p.Stand = { Model = stand, Body = body }
end

local function render(player)
	local p = byPlayer[player]
	local data = DataService.Get(player)
	if not (p and data) then
		return
	end
	renderHouse(player, p, data)
end
PlotService.Render = render

---------------------------------------------------------------- upgrades
local function upgradeHouse(player)
	local data = DataService.Get(player)
	if not data then
		return false, "Loading..."
	end
	if not DataService.Throttle(player, "Upgrade", 0.25) then
		return false, "Slow down!"
	end
	local nextLevel = Config.HOUSE[data.HouseLevel + 1]
	if not nextLevel then
		return false, "Doghouse is already max level!"
	end
	if not DataService.Spend(player, nextLevel.Cost) then
		return false, "Not enough Cash"
	end
	data.HouseLevel += 1
	DataService.MarkDirty(player)
	render(player)
	local bonus = math.floor((data.HouseLevel - 1) * Config.HOUSE_INCOME_BONUS * 100 + 0.5)
	return true, "🏠 " .. nextLevel.Name .. "! Your Team earns +" .. bonus .. "% Cash."
end

local function upgradeStand(player)
	local data = DataService.Get(player)
	if not data then
		return false, "Loading..."
	end
	if not DataService.Throttle(player, "Upgrade", 0.25) then
		return false, "Slow down!"
	end
	local nextLevel = Config.STAND[(data.Stand or 1) + 1]
	if not nextLevel then
		return false, "Training Post is already max level!"
	end
	if not DataService.Spend(player, nextLevel.Cost) then
		return false, "Not enough Cash"
	end
	data.Stand = (data.Stand or 1) + 1
	DataService.MarkDirty(player)
	render(player)
	return true, "🥊 " .. Config.StandName(data.Stand) .. "! " .. nextLevel.XP .. " XP per hit"
end

---------------------------------------------------------------- jogadores
local function setSign(index, text)
	local plot = workspace.Map.Terrenos:FindFirstChild("Terreno" .. index)
	local label = plot and plot:FindFirstChild("PlacaDono", true)
	local texto = label and label:FindFirstChild("Texto")
	local dono = texto and texto:FindFirstChild("Dono")
	if dono then
		dono.Text = text
	end
end

local function sendHome(player, character)
	local cf = PlotService.CFrame(player)
	if not character then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return
	end
	if cf then
		character:PivotTo(cf * Layout.PLOT.PlayerSpawn * CFrame.Angles(0, math.pi, 0))
	elseif not Config.HOUSES then
		-- 🏡 todo mundo nasce na Pawville (2026-10-23, pedido do dono: "a pessoa nasça na ilha onde você consegue o
		-- cachorro"), na pracinha do spawn olhando para o canil do professor, que dá o 1º cachorro
		local sp = Village.SPAWN
		character:PivotTo(Village.LocalCF(sp.X, Village.GROUND_Y + 3.5, sp.Z, sp.Ry))
	end
end
PlotService.SendHome = sendHome

local function assign(player)
	if byPlayer[player] then
		return byPlayer[player].Index
	end
	for i = 1, Layout.PLOT_COUNT do
		if not plots[i] then
			plots[i] = player
			local plot = workspace.Map.Terrenos:FindFirstChild("Terreno" .. i)
			if not (plot and plot:FindFirstChild("Dinamico")) then
				warn("[PlotService] Terreno" .. i .. " não existe no mapa")
				plots[i] = nil
				continue
			end
			byPlayer[player] = { Index = i, Model = plot }
			setSign(i, "🏠 " .. player.DisplayName)
			player:SetAttribute("Plot", i)
			render(player)
			return i
		end
	end
	warn("[PlotService] Sem terreno livre para", player.Name)
	return nil
end

local function release(player)
	local p = byPlayer[player]
	if not p then
		return
	end
	byPlayer[player] = nil
	plots[p.Index] = nil
	local dynamic = p.Model:FindFirstChild("Dinamico")
	if dynamic then
		dynamic:ClearAllChildren()
	end
	setSign(p.Index, "Free")
end

function PlotService.Start(r)
	remotes = r
	if not Config.HOUSES then
		local function gone()
			return false, "The doghouse and the training post are gone — do 📜 missions on the islands!"
		end
		remotes.UpgradeHouse.OnServerInvoke = gone
		remotes.UpgradeStand.OnServerInvoke = gone
		-- avatar novo (antes de escolher o 1º cachorro): na praça
		local function hookSpawn(player)
			player.CharacterAdded:Connect(function(character)
				if character:GetAttribute("Kind") == "player" or player:GetAttribute("HumanMode") or player:GetAttribute("InTower") then
					return
				end
				task.wait()
				sendHome(player, character)
			end)
		end
		Players.PlayerAdded:Connect(hookSpawn)
		for _, player in ipairs(Players:GetPlayers()) do
			hookSpawn(player)
			-- (2026-10-23) quem entrou ENQUANTO o mapa montava já tem avatar (nasceu antes daqui): vai para a Pawville
			local character = player.Character
			if character and character:GetAttribute("Kind") ~= "player" and not player:GetAttribute("HumanMode") and not player:GetAttribute("InTower") then
				task.spawn(sendHome, player, character)
			end
		end
		return
	end
	remotes.UpgradeHouse.OnServerInvoke = upgradeHouse
	remotes.UpgradeStand.OnServerInvoke = upgradeStand

	DataService.Loaded.Event:Connect(function(player)
		if not player.Parent then
			return
		end
		if assign(player) and player.Character then
			sendHome(player, player.Character)
		end
	end)
	DataService.Changed.Event:Connect(function(player)
		render(player)
	end)
	local function hook(player)
		player.CharacterAdded:Connect(function(character)
			-- o cachorro virou o personagem: quem decide onde ele aparece é o DogService
			if character:GetAttribute("Kind") == "player" or player:GetAttribute("HumanMode") then
				return
			end
			if byPlayer[player] and not player:GetAttribute("InTower") then
				task.wait()
				sendHome(player, character)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
	Players.PlayerRemoving:Connect(release)
end

return PlotService
