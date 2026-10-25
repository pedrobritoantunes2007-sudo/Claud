-- 🐕 LATIDO DO JOGADOR (2026-10-25, pedido do dono: "faz o cachorro latir às vezes"): a tecla B (celular: botão BARK)
-- faz o cachorro do jogador latir. O cliente que latiu já toca o som na hora (Systems/Soundscape); aqui o servidor
-- só confere (tem cachorro em campo, não está latindo sem parar) e avisa todo mundo para tocar o latido e o balão.
-- Remote Bark (RemoteEvent): cliente → servidor ("bark") · servidor → clientes (userId, "bark")
local Players = game:GetService("Players")

local VoiceService = {}

local COOLDOWN = 1.0 -- s entre latidos do mesmo jogador
local last = {} -- [player] = os.clock()

function VoiceService.Start(remotes)
	local DogService = require(script.Parent.DogService)
	local Fighters = require(script.Parent.Fighters)
	remotes.Bark.OnServerEvent:Connect(function(player, kind)
		if kind ~= "bark" then
			return
		end
		local now = os.clock()
		if last[player] and now - last[player] < COOLDOWN then
			return
		end
		local fighter = DogService.GetFighter(player)
		if not (fighter and Fighters.Alive(fighter)) then
			return
		end
		last[player] = now
		remotes.Bark:FireAllClients(player.UserId, "bark")
	end)
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
end

return VoiceService
