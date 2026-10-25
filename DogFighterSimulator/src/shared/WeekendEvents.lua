-- 🎉 EVENTOS DE FIM DE SEMANA (2026-10-25, pedido do dono: "todo sábado e domingo entra um evento sozinho, revezando
-- entre 2x captura, 2x Cash e chuva de cachorros raros. Aparece um aviso no HUD com o tempo que falta.")
-- Tudo pelo relógio (igual em todos os servidores e no cliente, sem DataStore): começa sábado 00:00 e acaba
-- segunda 00:00 no horário de Brasília (UTC_OFFSET = −3). A cada fim de semana entra o próximo da lista.
--   Catch2x  → chance de captura em dobro (CatchService)
--   Cash2x   → todo Cash ganho em dobro (MonetizationService.CashMult)
--   RareRain → cachorros raros caem do céu nas ilhas (NPCService) e mais chance de shiny
-- Teste no Studio: o código "event catch2x|cash2x|rain|off" (CODES, só o dono) liga um evento na hora
-- (atributo "EventForce" do workspace).
local WeekendEvents = {}

local C = Color3.fromRGB

WeekendEvents.UTC_OFFSET = -3 * 3600 -- horário de Brasília
WeekendEvents.LIST = {
	{ Id = "Catch2x", Name = "2x CATCH WEEKEND", Short = "2x CATCH", Icon = "leash", Color = C(90, 200, 255), Desc = "Leashes work twice as well: catch chance is DOUBLED!" },
	{ Id = "Cash2x", Name = "2x CASH WEEKEND", Short = "2x CASH", Icon = "coins", Color = C(120, 220, 90), Desc = "Every Cash you earn is DOUBLED!" },
	{ Id = "RareRain", Name = "RARE DOG RAIN", Short = "RARE RAIN", Icon = "star", Color = C(255, 170, 60), Desc = "Rare dogs fall from the sky on every island! More shinies too!" },
}
WeekendEvents.ById = {}
for i, e in ipairs(WeekendEvents.LIST) do
	e.Index = i
	WeekendEvents.ById[e.Id] = e
end
-- códigos de teste → id
WeekendEvents.CODES = { catch2x = "Catch2x", catch = "Catch2x", cash2x = "Cash2x", cash = "Cash2x", rain = "RareRain", rarerain = "RareRain" }

-- números de cada evento
WeekendEvents.CATCH_MULT = 2
WeekendEvents.CASH_MULT = 2
WeekendEvents.RAIN_EVERY = 25 -- s entre um cachorro raro caindo e outro (em cada ilha com gente)
WeekendEvents.RAIN_MAX = 4 -- no máximo tantos cachorros da chuva vivos por ilha
WeekendEvents.RAIN_SHINY_MULT = 3 -- shiny 3x mais comum durante a chuva

local DAY = 86400
local WEEK = 7 * DAY
-- 1970-01-03 foi um SÁBADO: a semana do evento conta a partir dele
local SATURDAY_EPOCH = 2 * DAY

-- evento da semana k (revezando a lista)
local function eventOfWeek(k)
	return WeekendEvents.LIST[(k % #WeekendEvents.LIST) + 1]
end

-- Evento agora: devolve (evento, segundos que faltam) ou (nil, segundos até o próximo, próximo evento).
-- force = id forçado pelo código de teste (atributo EventForce) — "off" desliga.
function WeekendEvents.At(t, force)
	t = t or os.time()
	if force == "off" then
		return nil, math.huge, nil
	end
	if type(force) == "string" and WeekendEvents.ById[force] then
		return WeekendEvents.ById[force], 3600, nil
	end
	local lt = t + WeekendEvents.UTC_OFFSET - SATURDAY_EPOCH
	local k = math.floor(lt / WEEK)
	local into = lt - k * WEEK -- segundos desde sábado 00:00 (horário local)
	if into < 2 * DAY then
		return eventOfWeek(k), 2 * DAY - into, nil
	end
	return nil, WEEK - into, eventOfWeek(k + 1)
end

-- o evento ativo agora (para o servidor e o cliente) — lê o EventForce do workspace se existir
function WeekendEvents.Current()
	local force = workspace:GetAttribute("EventForce")
	local now = os.time()
	local ok, server = pcall(function()
		return workspace:GetServerTimeNow()
	end)
	if ok and type(server) == "number" then
		now = math.floor(server)
	end
	return WeekendEvents.At(now, force)
end

function WeekendEvents.IsActive(id)
	local e = WeekendEvents.Current()
	return e ~= nil and e.Id == id
end

-- "1d 4h" / "3h 12m" / "12:34"
function WeekendEvents.FormatLeft(seconds)
	seconds = math.max(0, math.floor(seconds))
	local d = seconds // DAY
	local h = (seconds % DAY) // 3600
	local m = (seconds % 3600) // 60
	if d > 0 then
		return string.format("%dd %dh", d, h)
	elseif h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%d:%02d", m, seconds % 60)
end

return WeekendEvents
