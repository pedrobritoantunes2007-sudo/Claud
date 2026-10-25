-- 🎟️ PASSE DE TEMPORADA no servidor (2026-10-25, pedido do dono: "cada temporada dura 30 dias e tem 30 níveis. Você
-- ganha estrelas com missões e capturas. A trilha grátis e a premium dão prêmios, e a premium inclui um cachorro
-- exclusivo no nível 30. Sugiro 199 Robux por temporada.")
-- Números, prêmios e de onde vêm as estrelas: Shared/SeasonPass. A tela (Systems/SeasonPassMenu) calcula tudo do
-- perfil (data.Season) e só pede o resgate aqui.
-- Perfil: data.Season = { Id, Stars, Premium, Free = { [nível] = true }, Paid = { [nível] = true } } — zera quando a
-- temporada muda (o Premium é de UMA temporada).
-- Remote SeasonAction (RemoteFunction): ("claim", nível, "free"|"premium") | ("claimall") -> ok, mensagem
-- Premium: produto "SeasonPass" (MonetizationService chama GrantPremium).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local SeasonPass = require(ReplicatedStorage.Shared.SeasonPass)
local Accessories = require(ReplicatedStorage.Shared.Accessories)
local Signal = require(ReplicatedStorage.Shared.Signal)
local DataService = require(script.Parent.DataService)

local SeasonPassService = {}
SeasonPassService.Changed = Signal.new() -- (player, estrelas) — placar 🎟️ da Ilha do Ranking

local remotes

local function lazy(name)
	local ok, m = pcall(require, script.Parent[name])
	return ok and m or nil
end

local function num(v, default)
	return (type(v) == "number" and v == v and math.abs(v) ~= math.huge) and math.floor(v) or default
end

-- garante o formato de data.Season (e zera na temporada nova)
local function seasonOf(data)
	local id = SeasonPass.Current()
	local s = data.Season
	if type(s) ~= "table" or s.Id ~= id then
		s = { Id = id, Stars = 0, Premium = false, Free = {}, Paid = {} }
		data.Season = s
	end
	s.Stars = math.max(0, num(s.Stars, 0))
	s.Premium = s.Premium == true
	for _, key in ipairs({ "Free", "Paid" }) do
		local clean = {}
		if type(s[key]) == "table" then
			for lvl, v in pairs(s[key]) do
				local n = tonumber(lvl)
				if v == true and n and n >= 1 and n <= SeasonPass.LEVELS then
					clean[tostring(math.floor(n))] = true
				end
			end
		end
		s[key] = clean
	end
	return s
end
SeasonPassService.SeasonOf = seasonOf

-- ⭐ dá estrelas (missões, capturas, evolução...)
function SeasonPassService.AddStars(player, n, why)
	local data = DataService.Get(player)
	n = math.floor(tonumber(n) or 0)
	if not (data and data.Started) or n <= 0 then
		return
	end
	local s = seasonOf(data)
	local before = SeasonPass.LevelOf(s.Stars)
	s.Stars += n
	local after = SeasonPass.LevelOf(s.Stars)
	DataService.MarkDirty(player)
	SeasonPassService.Changed:Fire(player, s.Stars)
	-- (só avisa quando sobe de nível: cada estrela virando aviso enchia a tela; o botão 🎟️ PASS mostra o número)
	if remotes and player.Parent and after > before then
		remotes.Notify:FireClient(player, "🎟️ SEASON PASS level " .. after .. "! Claim your reward in 🎟️ PASS.", "gold")
	end
	if remotes and player.Parent then
		remotes.Progress:FireClient(player, "stars", { Stars = n, Why = why })
	end
end

-- 🎟️ comprou o Passe: libera a trilha premium da temporada atual. Devolve false se já tinha.
function SeasonPassService.GrantPremium(player, data)
	data = data or DataService.Get(player)
	if not data then
		return false
	end
	local s = seasonOf(data)
	if s.Premium then
		return false
	end
	s.Premium = true
	DataService.MarkDirty(player)
	if remotes and player.Parent then
		remotes.Notify:FireClient(player, "🎟️ PREMIUM SEASON PASS unlocked! Claim all your premium rewards in 🎟️ PASS!", "gold")
	end
	return true
end

---------------------------------------------------------------- prêmios
-- entrega 1 prêmio. Devolve ok, texto (ok = false: não deu agora, ex. canil cheio — fica para depois)
local function give(player, data, r, seasonId)
	local info = SeasonPass.Info(seasonId)
	if r.Dog then
		local speciesId = info and info.Dog
		if not (speciesId and DogData.Species[speciesId]) then
			return false, "This season's dog isn't ready yet."
		end
		local dog, err = DataService.AddDog(player, speciesId, nil, 25)
		if not dog then
			return false, tostring(err or "Kennel full!")
		end
		if r.Title and info.Title then
			data.ExtraTitles = type(data.ExtraTitles) == "table" and data.ExtraTitles or {}
			data.ExtraTitles[info.Title] = true
		end
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and remotes then
				remotes.Notify:FireClient(p, "🎟️ " .. player.DisplayName .. " reached SEASON PASS level 30 and got the EXCLUSIVE " .. dog.Name .. "!", "gold")
			end
		end
		return true, "EXCLUSIVE " .. dog.Name .. "!"
	elseif r.Acc then
		local AccessoryService = lazy("AccessoryService")
		local item = Accessories.Get(r.Acc)
		if AccessoryService and item then
			AccessoryService.Give(player, r.Acc, data)
			return true, item.Name
		end
		return false, "Accessory unavailable."
	elseif r.Missions then
		local cash = Monetization.CashFor({ Recompensa = { Missoes = r.Missions, Cash = 300 * r.Missions } }, data)
		DataService.AddCash(player, cash, "reward")
		return true, "$" .. Config.Format(cash)
	elseif r.Leash then
		local id, n = r.Leash[1], r.Leash[2]
		if not Config.LEASH[id] then
			return false, "?"
		end
		data.Leashes = type(data.Leashes) == "table" and data.Leashes or {}
		data.Leashes[id] = (tonumber(data.Leashes[id]) or 0) + n
		return true, n .. " " .. Config.LEASH[id].Name .. (n > 1 and "es" or "")
	elseif r.Spins then
		data.Spins = (tonumber(data.Spins) or 0) + r.Spins
		return true, r.Spins .. " Spin" .. (r.Spins > 1 and "s" or "")
	elseif r.LuckySpins then
		data.LuckySpins = (tonumber(data.LuckySpins) or 0) + r.LuckySpins
		return true, r.LuckySpins .. " Lucky Spin" .. (r.LuckySpins > 1 and "s" or "")
	elseif r.XPLevels then
		local dog = data.Equipped and data.Dogs[data.Equipped]
		local xp = math.floor(Config.XPToNext(dog and dog.Level or 1) * r.XPLevels)
		DataService.GrantFoodXP(player, xp, "reward")
		return true, "+" .. Config.Format(xp) .. " XP"
	end
	return false, "?"
end

local function claim(player, level, track)
	local data = DataService.Get(player)
	if not (data and data.Started) then
		return false, "Get your first dog first! 🐶"
	end
	level = math.floor(tonumber(level) or 0)
	if level < 1 or level > SeasonPass.LEVELS then
		return false, "?"
	end
	local s = seasonOf(data)
	local reached = SeasonPass.LevelOf(s.Stars)
	if level > reached then
		return false, "Reach level " .. level .. " first! ⭐ Stars come from quests and catching dogs."
	end
	local premium = track == "premium"
	if premium and not s.Premium then
		return false, "🎟️ Get the SEASON PASS to unlock the premium rewards!"
	end
	local list = premium and s.Paid or s.Free
	local key = tostring(level)
	if list[key] then
		return false, "Already claimed!"
	end
	local r = (premium and SeasonPass.PREMIUM or SeasonPass.FREE)[level]
	if not r then
		return false, "?"
	end
	local ok, text = give(player, data, r, s.Id)
	if not ok then
		return false, text
	end
	list[key] = true
	DataService.MarkDirty(player)
	return true, "🎟️ Level " .. level .. ": " .. text
end

local function claimAll(player)
	local data = DataService.Get(player)
	if not (data and data.Started) then
		return false, "Get your first dog first! 🐶"
	end
	local s = seasonOf(data)
	local reached = SeasonPass.LevelOf(s.Stars)
	local got, last = 0, nil
	for level = 1, reached do
		for _, track in ipairs({ "free", "premium" }) do
			local list = track == "premium" and s.Paid or s.Free
			if not list[tostring(level)] and (track == "free" or s.Premium) then
				local ok, msg = claim(player, level, track)
				if ok then
					got += 1
				else
					last = msg
				end
			end
		end
	end
	if got == 0 then
		return false, last or "Nothing to claim yet!"
	end
	return true, "🎟️ Claimed " .. got .. " reward" .. (got > 1 and "s" or "") .. "!"
end

---------------------------------------------------------------- ⭐ de onde vêm as estrelas
local STAR = SeasonPass.STARS
local CLAIM_STARS = { Daily = STAR.Daily, Quick = STAR.Quick, DailyBonus = STAR.DailyBonus, Login = STAR.Login }
local CLAIM_WHY = { Daily = "daily quest", Quick = "quick quest", DailyBonus = "daily bonus", Login = "daily reward" }

local function catchStars(speciesId, shiny)
	if shiny then
		return STAR.CatchShiny
	end
	local sp = DogData.Species[speciesId]
	local order = sp and Config.RARITY[sp.Rarity] and Config.RARITY[sp.Rarity].Order or 1
	if order >= Config.RARITY.Legendary.Order then
		return STAR.CatchLegendary
	elseif order >= Config.RARITY.Rare.Order then
		return STAR.CatchRare
	end
	return STAR.Catch
end

function SeasonPassService.Start(r)
	remotes = r
	remotes.SeasonAction.OnServerInvoke = function(player, action, level, track)
		if not DataService.Throttle(player, "SeasonAction", 0.3) then
			return false, "Slow down!"
		end
		if action == "claim" then
			return claim(player, level, track)
		elseif action == "claimall" then
			return claimAll(player)
		end
		return false, "?"
	end
	DataService.Loaded.Event:Connect(function(player, data)
		seasonOf(data)
		DataService.MarkDirty(player)
	end)
	local Progression = lazy("ProgressionService")
	if Progression then
		Progression.Claimed.Event:Connect(function(player, kind)
			if CLAIM_STARS[kind] then
				SeasonPassService.AddStars(player, CLAIM_STARS[kind], CLAIM_WHY[kind])
			end
		end)
		Progression.Tracked.Event:Connect(function(player, kind, n)
			if kind == "Quest" then
				SeasonPassService.AddStars(player, STAR.IslandMission * (n or 1), "island mission")
			elseif kind == "Evolve" then
				SeasonPassService.AddStars(player, STAR.Evolve * (n or 1), "evolution")
			end
		end)
	end
	local Catch = lazy("CatchService")
	if Catch and Catch.Caught then
		Catch.Caught.Event:Connect(function(player, speciesId, _level, shiny)
			SeasonPassService.AddStars(player, catchStars(speciesId, shiny), "catch")
		end)
	end
	-- a temporada virou com o jogador no jogo: zera o passe dele
	task.spawn(function()
		while true do
			task.wait(60)
			local id = SeasonPass.Current()
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.Get(player)
				if data and type(data.Season) == "table" and data.Season.Id ~= id then
					seasonOf(data)
					DataService.MarkDirty(player)
					if remotes then
						local info = SeasonPass.Info(id)
						remotes.Notify:FireClient(player, "🎟️ A NEW SEASON started: " .. (info and info.Name or "Season " .. id) .. "!", "gold")
					end
				end
			end
		end
	end)
end

return SeasonPassService
