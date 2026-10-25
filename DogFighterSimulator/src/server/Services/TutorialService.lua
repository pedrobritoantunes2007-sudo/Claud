-- 🧭 TUTORIAL DA GUIA (2026-10-23, pedido do dono): a guia Lily (cliente, Systems/GuideTour) leva o jogador novo da
-- pracinha da 🏡 Pawville até o 🎓 Prof. Barkley (cachorros brincando + sorteio do 1º cachorro), depois até o
-- portal da ⚔️ ARENA (explica a arena e o objetivo do jogo) e até o portal da 🌻 PUPPY MEADOWS. Lá o jogador vira o
-- cachorro e derrota Config.TUTORIAL.Kills selvagens: tutorial completo = Cash + níveis para o cachorro + 1 ovo.
-- Aqui fica o que vale de verdade (salvo na conta):
--   data.Tutorial  >= DONE = terminado/pulado (o tutorial não aparece mais)
--   data.Guide     = fase da guia (só sobe): 3 = já tem cachorro, 4 = já viu a arena, 5 = lutando na 1ª ilha
--   data.GuideKills = selvagens derrotados na fase 5 · data.GuideCatch = 🦮 selvagens capturados (2026-10-25: o tutorial
--   termina com Config.TUTORIAL.Kills derrotados E Config.TUTORIAL.Catches capturados)
-- Remote TutorialAction (RemoteEvent):
--   cliente → servidor: ("phase", n) · ("dog") vira o cachorro · ("skip") · (antigos: "step", "finish")
--   servidor → cliente: ("kills", n, meta) · ("catch", n, meta) · ("done", prêmio)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Fighters = require(script.Parent.Fighters)

local TutorialService = {}

TutorialService.DONE = 99
TutorialService.FIGHT = 5 -- fase da luta na Puppy Meadows
TutorialService.REWARD_CASH = Config.TUTORIAL.Cash

local remotes

local function giveNestEgg(_player, data)
	if data.TutorialEgg then
		return false
	end
	data.TutorialEgg = true
	data.EggInv = data.EggInv or {}
	data.EggInv.paw = (data.EggInv.paw or 0) + 1
	return true
end

local function done(data)
	return (tonumber(data.Tutorial) or 0) >= TutorialService.DONE
end

-- 🎉 tutorial completo: Cash + níveis no cachorro equipado + ovo de presente
local function complete(player, data)
	if done(data) then
		return
	end
	data.Tutorial = TutorialService.DONE
	data.GuideKills = nil
	data.GuideCatch = nil
	DataService.AddCash(player, Config.TUTORIAL.Cash, "tutorial")
	local dog = data.Equipped and data.Dogs[data.Equipped]
	local oldLevel = dog and dog.Level or 1
	if dog then
		-- XP exata para subir Config.TUTORIAL.Levels níveis a partir de onde ele está
		local need = -(dog.XP or 0)
		for l = dog.Level, math.min(Config.MAX_LEVEL - 1, dog.Level + Config.TUTORIAL.Levels - 1) do
			need += Config.XPToNext(l)
		end
		if need > 0 then
			DataService.GiveXP(player, need, "tutorial")
		end
	end
	-- 🎰 sem ovos (Config.EGGS = false): o presente vira 1 giro da roleta (uma vez só, como o ovo)
	local egg, spin = false, false
	if Config.EGGS then
		egg = giveNestEgg(player, data)
	elseif not data.TutorialEgg then
		data.TutorialEgg = true
		data.Spins = (tonumber(data.Spins) or 0) + 1
		spin = true
	end
	DataService.MarkDirty(player)
	if DataService.SaveNow then
		DataService.SaveNow(player)
	end
	remotes.TutorialAction:FireClient(player, "done", {
		Cash = Config.TUTORIAL.Cash,
		From = oldLevel,
		To = dog and dog.Level or oldLevel,
		Egg = egg,
		Spin = spin,
	})
end

-- um selvagem caiu: conta para quem está na fase da luta (golpe final ou ajuda, como as missões)
local function onKilled(victim, killer)
	if victim.Kind ~= "npc" then
		return
	end
	local credited = {}
	if killer and killer.Kind == "player" and killer.Owner then
		credited[killer.Owner] = true
	end
	local maxHP = (victim.Humanoid and victim.Humanoid.MaxHealth) or 1
	for player, dmg in pairs(victim.Contributions or {}) do
		if typeof(player) == "Instance" and player:IsA("Player") and dmg >= maxHP * (Config.QUEST_HELP_SHARE or 0.2) then
			credited[player] = true
		end
	end
	for player in pairs(credited) do
		local data = player.Parent and DataService.Get(player)
		if data and data.Started and not done(data) and (tonumber(data.Guide) or 0) >= TutorialService.FIGHT then
			data.GuideKills = (tonumber(data.GuideKills) or 0) + 1
			DataService.MarkDirty(player)
			remotes.TutorialAction:FireClient(player, "kills", data.GuideKills, Config.TUTORIAL.Kills)
			TutorialService.Check(player, data)
		end
	end
end

-- 🎉 terminou quando derrotou E capturou o bastante
function TutorialService.Check(player, data)
	if (tonumber(data.GuideKills) or 0) >= Config.TUTORIAL.Kills and (tonumber(data.GuideCatch) or 0) >= (Config.TUTORIAL.Catches or 0) then
		task.delay(1.2, function()
			if player.Parent and DataService.Get(player) == data then
				complete(player, data)
			end
		end)
	end
end

-- 🦮 capturou um selvagem na fase da luta
local function onCaught(player)
	local data = player.Parent and DataService.Get(player)
	if data and data.Started and not done(data) and (tonumber(data.Guide) or 0) >= TutorialService.FIGHT then
		data.GuideCatch = (tonumber(data.GuideCatch) or 0) + 1
		DataService.MarkDirty(player)
		remotes.TutorialAction:FireClient(player, "catch", data.GuideCatch, Config.TUTORIAL.Catches or 0)
		TutorialService.Check(player, data)
	end
end

function TutorialService.Start(r)
	remotes = r
	-- (o DogService começa antes: BecomeDog transforma a pessoa no cachorro)
	local DogService = require(script.Parent.DogService)
	remotes.TutorialAction.OnServerEvent:Connect(function(player, action, value)
		local data = DataService.Get(player)
		if not data or not DataService.Throttle(player, "TutorialAction", 0.2) then
			return
		end
		if done(data) then
			return
		end
		if action == "skip" then
			-- pular: acaba aqui (sem prêmio); quem ainda é a pessoa com cachorro vira o cachorro
			data.Tutorial = TutorialService.DONE
			DataService.MarkDirty(player)
			if data.Started then
				DogService.BecomeDog(player)
			end
			return
		end
		if not data.Started then
			return -- antes do 1º cachorro nada é salvo (quem sai volta para o começo da guia)
		end
		if action == "phase" and type(value) == "number" and value == value then
			local phase = math.clamp(math.floor(value), 0, TutorialService.FIGHT)
			if phase > (tonumber(data.Guide) or 0) then
				data.Guide = phase
				DataService.MarkDirty(player)
			end
			if phase >= TutorialService.FIGHT then
				-- (quem já tinha derrotado selvagens antes de sair continua de onde parou)
				remotes.TutorialAction:FireClient(player, "kills", tonumber(data.GuideKills) or 0, Config.TUTORIAL.Kills)
				remotes.TutorialAction:FireClient(player, "catch", tonumber(data.GuideCatch) or 0, Config.TUTORIAL.Catches or 0)
				TutorialService.Check(player, data)
			end
		elseif action == "dog" then
			DogService.BecomeDog(player)
		elseif action == "step" and type(value) == "number" and value == value then
			-- (tutorial antigo de cartões: guarda o passo e dá o ovo de presente)
			local step = math.clamp(math.floor(value), 0, TutorialService.DONE - 1)
			if step > (tonumber(data.Tutorial) or 0) then
				data.Tutorial = step
			end
			giveNestEgg(player, data)
			DataService.MarkDirty(player)
		elseif action == "finish" then
			complete(player, data)
		end
	end)
	Fighters.Killed.Event:Connect(function(victim, killer)
		local ok, err = pcall(onKilled, victim, killer)
		if not ok then
			warn("[TutorialService] kill:", err)
		end
	end)
	local okC, CatchService = pcall(require, script.Parent.CatchService)
	if okC and CatchService.Caught then
		CatchService.Caught.Event:Connect(function(player)
			local ok, err = pcall(onCaught, player)
			if not ok then
				warn("[TutorialService] catch:", err)
			end
		end)
	end
end

return TutorialService
