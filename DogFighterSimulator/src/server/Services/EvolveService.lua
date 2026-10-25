-- 🧬 EVOLUIR (2026-10-25, pedido do dono: "3 cachorros iguais viram 1 versão Gold, mais forte. 3 Gold viram 1 Rainbow,
-- ainda mais forte. Assim os repetidos que você captura servem para alguma coisa.")
-- Regras (Shared/Variants): o cachorro escolhido + mais 2 da MESMA espécie e da MESMA versão (normal, Gold) viram 1 da
-- versão de cima. Favoritos ⭐ (fora o escolhido) e cachorros oferecidos numa troca ficam de fora. O novo fica com o
-- MAIOR level dos 3, o nome do escolhido e é shiny se algum dos 3 era shiny (ninguém perde o seu shiny).
-- Remote EvolveAction (RemoteFunction):
--   ("preview", uid) -> ok, { Have, Need, Tier, Uids, Mult }  ·  ("evolve", uid) -> ok, { Uid, Tier, Label, Name }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Variants = require(ReplicatedStorage.Shared.Variants)
local DataService = require(script.Parent.DataService)

local EvolveService = {}
EvolveService.Evolved = Signal.new() -- (player, dog novo)

local remotes

local function lazy(name)
	local ok, m = pcall(require, script.Parent[name])
	return ok and m or nil
end

-- cachorros que não podem entrar (oferecidos numa troca aberta)
local function blockedOf(player)
	local Trade = lazy("TradeService")
	if Trade and Trade.Offered then
		local ok, set = pcall(Trade.Offered, player)
		if ok and type(set) == "table" then
			return set
		end
	end
	return {}
end

local function preview(player, uid)
	local data = DataService.Get(player)
	local dog = data and type(uid) == "string" and data.Dogs[uid]
	if not dog then
		return false, "Pick a dog first!"
	end
	if not Variants.CanEvolve(dog) then
		return false, "🌈 RAINBOW is the top! This dog can't evolve more."
	end
	local list, have = Variants.EvolvePick(data.Dogs, uid, blockedOf(player))
	local tier = Variants.TierOf(dog) + 1
	return true, {
		Have = have,
		Need = Variants.EVOLVE_COUNT,
		Tier = tier,
		Label = Variants.TIERS[tier].Label,
		Mult = Variants.TIERS[tier].Mult,
		Uids = list,
	}
end

local function evolve(player, uid)
	local data = DataService.Get(player)
	local main = data and type(uid) == "string" and data.Dogs[uid]
	if not (data and data.Started and main) then
		return false, "Pick a dog first!"
	end
	if not Variants.CanEvolve(main) then
		return false, "🌈 RAINBOW is the top! This dog can't evolve more."
	end
	local list, have = Variants.EvolvePick(data.Dogs, uid, blockedOf(player))
	if not list then
		local species = DogData.Species[main.Species]
		local what = (Variants.TierOf(main) == 1 and "GOLD " or "") .. (species and species.Name or "dogs")
		return false, string.format("You need %d %s to evolve (you have %d). ⭐ Favorites are kept safe!", Variants.EVOLVE_COUNT, what, have)
	end
	-- o cachorro em campo está no meio de uma luta: espera (evoluir renasce o cachorro com a vida cheia)
	if table.find(list, data.Equipped) then
		local DogService = lazy("DogService")
		local Fighters = lazy("Fighters")
		local f = DogService and DogService.GetFighter(player)
		local s = DogService and DogService.GetState(player)
		if s and (s.State == "ko" or s.Pending) then
			return false, "Wait for your dog to wake up first."
		end
		if f and Fighters and Fighters.Alive(f) and (f.Zone == "boss" or (f.Duel and Fighters.Alive(f.Duel))) then
			return false, "Finish the fight before evolving your dog!"
		end
	end
	-- o novo: maior level dos 3, nome do escolhido, shiny se algum era
	local best, shiny, wasEquipped = main, false, false
	for _, id in ipairs(list) do
		local d = data.Dogs[id]
		if d.Level > best.Level or (d.Level == best.Level and d.XP > best.XP) then
			best = d
		end
		shiny = shiny or d.Shiny == true
		wasEquipped = wasEquipped or data.Equipped == id
	end
	local tier = Variants.TierOf(main) + 1
	local newUid = DataService.NewUid(data)
	local dog = {
		Id = newUid,
		Species = main.Species,
		Name = main.Name,
		Level = best.Level,
		XP = best.XP,
		Fav = main.Fav == true,
		Stars = Config.StarsFor(best.Level),
		Shiny = shiny or nil,
		Tier = tier,
	}
	for _, id in ipairs(list) do
		data.Dogs[id] = nil
		if type(data.Team) == "table" then
			local i = table.find(data.Team, id)
			if i then
				table.remove(data.Team, i)
			end
		end
	end
	data.Dogs[newUid] = dog
	if wasEquipped or not data.Dogs[data.Equipped or ""] then
		data.Equipped = newUid
	end
	data.Evolves = (tonumber(data.Evolves) or 0) + 1
	DataService.MarkDirty(player)
	DataService.SaveNow(player)
	-- o cachorro em campo era um dos 3: volta já evoluído (brilhando), no mesmo lugar
	if wasEquipped then
		local DogService = lazy("DogService")
		if DogService and DogService.Respawn then
			task.defer(function()
				local f = DogService.GetFighter(player)
				local s = DogService.GetState(player)
				if f and f.Uid ~= newUid and player.Parent and s.State ~= "ko" and not player:GetAttribute("HumanMode") then
					pcall(DogService.Respawn, player, true)
				end
			end)
		end
	end
	local info = Variants.TIERS[tier]
	local label = Variants.Label(dog)
	if tier >= 2 then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				remotes.Notify:FireClient(p, "🌈 " .. player.DisplayName .. " evolved a " .. label .. " " .. dog.Name .. "!", "gold")
			end
		end
	end
	EvolveService.Evolved:Fire(player, dog)
	local Progression = lazy("ProgressionService")
	if Progression and Progression.Track then
		pcall(Progression.Track, player, "Evolve", 1)
	end
	return true, { Uid = newUid, Tier = tier, Label = info.Label, Name = dog.Name, Species = dog.Species, Shiny = shiny }
end

function EvolveService.Start(r)
	remotes = r
	remotes.EvolveAction.OnServerInvoke = function(player, action, uid)
		if not DataService.Throttle(player, "EvolveAction", 0.4) then
			return false, "Slow down!"
		end
		if action == "preview" then
			return preview(player, uid)
		elseif action == "evolve" then
			return evolve(player, uid)
		end
		return false, "?"
	end
end

return EvolveService
