-- 🐕 TIME: os cachorros escalados rendem Cash por minuto, mesmo parados (pago a cada TEAM_PAY_EVERY s).
-- Começa com Config.TEAM_START vagas; as outras são compradas com Cash (Config.TEAM_SLOT_COST).
-- Renda = soma de Config.TeamIncome(cachorro) × casinha (+10%/nível) × gamepass de Cash.
-- Remote TeamAction: ("toggle", uid) põe/tira do time | ("slot") compra a próxima vaga.
-- Atributos no jogador para a UI: TeamIncome ($/min) e TeamPayAt (horário do próximo pagamento).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local DataService = require(script.Parent.DataService)

local TeamService = {}

local remotes
local leftover = {} -- [player] = fração de Cash que ainda não virou $1

local monetization
local function cashMult(player)
	if monetization == nil then
		local ok, m = pcall(require, script.Parent.MonetizationService)
		monetization = ok and m or false
	end
	if monetization then
		local ok, v = pcall(monetization.CashMult, player)
		if ok and type(v) == "number" and v > 0 then
			return v
		end
	end
	return 1
end

-- tira do time cachorros que não existem mais (vendidos, trocados) e vagas a mais
local function clean(data)
	local team, seen = {}, {}
	for _, uid in ipairs(data.Team) do
		if data.Dogs[uid] and not seen[uid] and #team < data.TeamSlots then
			seen[uid] = true
			table.insert(team, uid)
		end
	end
	data.Team = team
end

-- $/min do time deste jogador (já com casinha e gamepass)
function TeamService.Income(player)
	local data = DataService.Get(player)
	if not (data and data.Started) then
		return 0
	end
	clean(data)
	local total = 0
	for _, uid in ipairs(data.Team) do
		local dog = data.Dogs[uid]
		local species = DogData.Species[dog.Species]
		if species then
			total += Config.TeamIncome(species, dog.Level)
		end
	end
	local house = 1 + Config.HOUSE_INCOME_BONUS * math.max(0, data.HouseLevel - 1)
	return total * house * cashMult(player)
end

local function toggle(player, uid)
	local data = DataService.Get(player)
	if not (data and data.Started) or type(uid) ~= "string" or not data.Dogs[uid] then
		return false, "Invalid dog"
	end
	clean(data)
	local i = table.find(data.Team, uid)
	if i then
		table.remove(data.Team, i)
		DataService.MarkDirty(player)
		return true, "Removed from your 💵 Team"
	end
	if #data.Team >= data.TeamSlots then
		return false, "Team full (" .. data.TeamSlots .. "/" .. Config.TEAM_MAX .. ")! Buy more slots in 🏠 HOME"
	end
	table.insert(data.Team, uid)
	DataService.MarkDirty(player)
	local species = DogData.Species[data.Dogs[uid].Species]
	return true, "💵 " .. species.Name .. " joined your Team! +$" .. Config.Format(math.floor(Config.TeamIncome(species, data.Dogs[uid].Level))) .. "/min"
end

local function buySlot(player)
	local data = DataService.Get(player)
	if not (data and data.Started) then
		return false, "Loading..."
	end
	local nextSlot = data.TeamSlots + 1
	local cost = Config.TEAM_SLOT_COST[nextSlot]
	if not cost then
		return false, "Your Team is already max size!"
	end
	if not DataService.Spend(player, cost) then
		return false, "Not enough Cash"
	end
	data.TeamSlots = nextSlot
	DataService.MarkDirty(player)
	DataService.SaveNow(player)
	return true, "🐕 New Team slot! " .. nextSlot .. "/" .. Config.TEAM_MAX
end

local function pay(player)
	local data = DataService.Get(player)
	if not (data and data.Started) then
		return
	end
	local perMin = TeamService.Income(player)
	if player:GetAttribute("TeamIncome") ~= math.floor(perMin) then
		player:SetAttribute("TeamIncome", math.floor(perMin))
	end
	player:SetAttribute("TeamPayAt", workspace:GetServerTimeNow() + Config.TEAM_PAY_EVERY)
	if perMin <= 0 then
		return
	end
	local amount = perMin * Config.TEAM_PAY_EVERY / 60 + (leftover[player] or 0)
	local whole = math.floor(amount)
	leftover[player] = amount - whole
	if whole > 0 then
		DataService.AddCash(player, whole, "team")
	end
end

function TeamService.Start(r)
	remotes = r
	-- ⚠️ 2026-10 (pedido do dono): o TIME que rende Cash saiu — o dinheiro vem das 📜 missões (QuestService)
	if not Config.HOUSES then
		remotes.TeamAction.OnServerInvoke = function()
			return false, "The Team is gone — earn 💵 with 📜 missions on the islands!"
		end
		return
	end
	remotes.TeamAction.OnServerInvoke = function(player, action, arg)
		if not DataService.Throttle(player, "TeamAction", 0.2) then
			return false, "Easy!"
		end
		if action == "toggle" then
			return toggle(player, arg)
		elseif action == "slot" then
			return buySlot(player)
		end
		return false, "Invalid action"
	end
	Players.PlayerRemoving:Connect(function(player)
		leftover[player] = nil
	end)
	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(pay, player)
				if not ok then
					warn("[TeamService]", err)
				end
			end
			task.wait(Config.TEAM_PAY_EVERY)
		end
	end)
end

return TeamService
