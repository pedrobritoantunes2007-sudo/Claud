-- 🎉 EVENTOS DE FIM DE SEMANA no servidor (2026-10-25, pedido do dono: "todo sábado e domingo entra um evento sozinho,
-- revezando entre 2x captura, 2x Cash e chuva de cachorros raros. Aparece um aviso no HUD com o tempo que falta.")
-- O calendário é do relógio (Shared/WeekendEvents) — cada sistema já confere sozinho se o evento está ligado:
-- CatchService (2x captura), MonetizationService.CashMult (2x Cash) e NPCService (chuva de cachorros raros).
-- Aqui só os AVISOS: quando o evento começa/acaba (para todo mundo no servidor) e para quem entra durante o evento.
-- O aviso do HUD com o tempo que falta é do cliente (Systems/WeekendEvent).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeekendEvents = require(ReplicatedStorage.Shared.WeekendEvents)
local DataService = require(script.Parent.DataService)

local EventService = {}

local remotes
local current = nil -- id do evento ligado agora (ou false)

local function tellAll(text, color)
	for _, p in ipairs(Players:GetPlayers()) do
		remotes.Notify:FireClient(p, text, color)
	end
end

local function check()
	local e = WeekendEvents.Current()
	local id = e and e.Id or false
	if current == nil then
		current = id -- (servidor abriu agora: sem aviso de "começou")
		return
	end
	if id ~= current then
		if id then
			tellAll("🎉 WEEKEND EVENT: " .. e.Name .. "! " .. e.Desc, "gold")
		elseif current then
			local old = WeekendEvents.ById[current]
			tellAll("🎉 " .. (old and old.Name or "The weekend event") .. " is over. See you next weekend!", "blue")
		end
		current = id
	end
end

function EventService.Start(r)
	remotes = r
	check()
	DataService.Loaded.Event:Connect(function(player)
		task.delay(10, function()
			local e, left = WeekendEvents.Current()
			if e and player.Parent then
				remotes.Notify:FireClient(player, "🎉 WEEKEND EVENT: " .. e.Name .. "! " .. e.Desc .. " (" .. WeekendEvents.FormatLeft(left) .. " left)", "gold")
			end
		end)
	end)
	workspace:GetAttributeChangedSignal("EventForce"):Connect(check)
	task.spawn(function()
		while true do
			task.wait(20)
			pcall(check)
		end
	end)
end

return EventService
