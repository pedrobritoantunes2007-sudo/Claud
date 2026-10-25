-- 🐺 CLÃS / MATILHAS (2026-10-25, pedido do dono: "criar um clã por 5.000 Cash, com até 20 membros, convidar, entrar e
-- sair. A sigla do clã aparece em cima da cabeça e o ranking semanal dos clãs fica na Ilha do Ranking.")
-- Números: Config.CLAN. Os clãs valem em TODOS os servidores: cada clã é um registro no DataStore Config.CLAN_STORE
-- ("clan_<id>" = { Id, Name, Tag, Color, Owner, Members = { [userId] = { N = nome, J = quando entrou } }, Count,
-- Open, Created, Gone }) e o nome fica reservado em Config.CLAN_NAMES (2 clãs não têm o mesmo nome). O perfil guarda
-- só data.Clan = id (conferido no registro quando o jogador entra: quem foi expulso fora do jogo sai sozinho).
-- Mudança feita em outro servidor chega pelo MessagingService ("DogClans": expulsão e atualização).
--   * criar: nome + sigla (filtrados pelo Roblox) + cor, paga Config.CLAN.Cost · convidar: qualquer membro convida
--     quem está no MESMO servidor e sem clã (o convite vale Config.CLAN.InviteTime s) · entrar: aceitando o convite
--     ou num clã ABERTO (o dono abre/fecha) · sair: o dono que sai passa o clã para o membro mais antigo; o último a
--     sair desfaz o clã · expulsar: só o dono.
--   * a sigla [TAG] aparece em cima da cabeça (atributos ClanTag/ClanColor do jogador → Fighters.RefreshLabel).
--   * 🏆 semana: cada vitória, captura e missão de um membro soma pontos (Config.CLAN.Points) no OrderedDataStore
--     Config.BOARD_CLANS .. semana (o placar fica na Ilha do Ranking — LeaderboardService).
-- Remote ClanAction (RemoteFunction): ("state") | ("create", nome, sigla, cor) | ("invite", jogador) |
--   ("accept", id) | ("decline", id) | ("join", id) | ("leave") | ("kick", userId) | ("open", bool) -> ok, msg/estado
-- Remote ClanEvent (servidor → cliente): ("invite", { Id, Name, Tag, From }) | ("changed")
-- Sem DataStore (Studio sem acesso às APIs): tudo funciona na memória do servidor (nada fica salvo).
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Fighters = require(script.Parent.Fighters)

local ClanService = {}

local C = Config.CLAN
local TOPIC = "DogClans"
local CACHE_TIME = 60 -- s que um registro lido fica valendo
local WEEK = 7 * 24 * 3600
local MONDAY_EPOCH = 4 * 24 * 3600 -- 1970-01-05 (segunda-feira), igual ao LeaderboardService

local remotes
local cache = {} -- [id] = { Rec = registro|false, At = os.clock() }
local invites = {} -- [jogador] = { [id] = { Name, Tag, From, Until } }
local points = {} -- [id] = pontos da semana ainda não gravados
local busy = {} -- [jogador] = true durante uma ação que espera o DataStore

local function lazy(name)
	local ok, m = pcall(require, script.Parent[name])
	return ok and m or nil
end

---------------------------------------------------------------- DataStore (com memória no Studio)
local IS_STUDIO = RunService:IsStudio()
local function newStore(name, ordered)
	local real
	local ok, result = pcall(function()
		return ordered and DataStoreService:GetOrderedDataStore(name) or DataStoreService:GetDataStore(name)
	end)
	real = ok and result or nil
	local mem = {}
	local useMem = real == nil
	local s = {}
	-- roda a chamada de verdade; no Studio sem API cai para a memória
	local function call(fn, memFn)
		if not useMem then
			local okCall, a = pcall(fn)
			if okCall then
				return true, a
			end
			if not IS_STUDIO then
				warn("[ClanService] DataStore " .. name .. ": " .. tostring(a))
				return false, a
			end
			useMem = true
		end
		return true, memFn()
	end
	function s.Get(key)
		return call(function()
			return real:GetAsync(key)
		end, function()
			return mem[key]
		end)
	end
	function s.Update(key, fn)
		return call(function()
			return real:UpdateAsync(key, fn)
		end, function()
			local new = fn(mem[key])
			if new ~= nil then
				mem[key] = new
			end
			return new
		end)
	end
	function s.Remove(key)
		return call(function()
			return real:RemoveAsync(key)
		end, function()
			mem[key] = nil
		end)
	end
	function s.Increment(key, n)
		return call(function()
			return real:IncrementAsync(key, n)
		end, function()
			mem[key] = (mem[key] or 0) + n
			return mem[key]
		end)
	end
	function s.Top(n)
		return call(function()
			local page = real:GetSortedAsync(false, n):GetCurrentPage()
			return page
		end, function()
			local list = {}
			for k, v in pairs(mem) do
				table.insert(list, { key = k, value = v })
			end
			table.sort(list, function(a, b)
				return a.value > b.value
			end)
			local out = {}
			for i = 1, math.min(n, #list) do
				out[i] = list[i]
			end
			return out
		end)
	end
	return s
end

local Clans = newStore(Config.CLAN_STORE)
local Names = newStore(Config.CLAN_NAMES)
local weekStores = {}
local function weekIndex(t)
	return math.floor(((t or os.time()) - MONDAY_EPOCH) / WEEK)
end
local function weekStore()
	local w = weekIndex()
	if not weekStores[w] then
		weekStores[w] = newStore(Config.BOARD_CLANS .. w, true)
	end
	return weekStores[w]
end
ClanService.WeekStore = weekStore -- (placar 🐺 BEST CLANS da Ilha do Ranking)

---------------------------------------------------------------- registros
local function keyOf(id)
	return "clan_" .. id
end

local function remember(id, rec)
	cache[id] = { Rec = rec or false, At = os.clock() }
end

-- registro do clã (do cache, ou lido de novo se `fresh` / velho). nil = não existe / desfeito
function ClanService.Get(id, fresh)
	if type(id) ~= "string" then
		return nil
	end
	local c = cache[id]
	if c and not fresh and os.clock() - c.At < CACHE_TIME then
		return c.Rec or nil
	end
	local ok, rec = Clans.Get(keyOf(id))
	if not ok then
		return c and c.Rec or nil
	end
	if type(rec) ~= "table" or rec.Gone then
		remember(id, false)
		return nil
	end
	remember(id, rec)
	return rec
end

-- "[TAG] Nome" (placar)
function ClanService.Describe(id)
	local rec = ClanService.Get(id)
	if not rec then
		return nil
	end
	return "[" .. rec.Tag .. "] " .. rec.Name, rec
end

local function colorOf(rec)
	return C.Colors[rec and rec.Color or 1] or C.Colors[1]
end

-- liga/desliga a sigla do jogador (atributos + plaquinha do cachorro em campo)
local function applyTag(player, rec)
	player:SetAttribute("ClanId", rec and rec.Id or nil)
	player:SetAttribute("ClanTag", rec and rec.Tag or nil)
	player:SetAttribute("ClanName", rec and rec.Name or nil)
	player:SetAttribute("ClanColor", rec and colorOf(rec) or nil)
	local DogService = lazy("DogService")
	local f = DogService and DogService.GetFighter(player)
	if f and Fighters.Alive(f) then
		Fighters.RefreshLabel(f)
	end
end

local function setMine(player, rec)
	local data = DataService.Get(player)
	if data then
		data.Clan = rec and rec.Id or nil
		DataService.MarkDirty(player)
	end
	applyTag(player, rec)
end

local function publish(msg)
	task.spawn(function()
		pcall(MessagingService.PublishAsync, MessagingService, TOPIC, msg)
	end)
end

-- avisa os membros do clã que estão NESTE servidor (e atualiza a tela deles)
local function tellMembers(id, text, color, except)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= except and p:GetAttribute("ClanId") == id then
			if text then
				remotes.Notify:FireClient(p, text, color or "blue")
			end
			remotes.ClanEvent:FireClient(p, "changed")
		end
	end
end

-- o registro mudou (aqui ou em outro servidor): todo mundo dele neste servidor vê de novo
local function refreshMembers(id, rec)
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("ClanId") == id then
			if rec and rec.Members[tostring(p.UserId)] then
				applyTag(p, rec)
			else
				setMine(p, nil)
				remotes.Notify:FireClient(p, "🚩 You are no longer in that clan.", "red")
			end
			remotes.ClanEvent:FireClient(p, "changed")
		end
	end
end

---------------------------------------------------------------- texto
local function clean(text)
	if type(text) ~= "string" then
		return nil
	end
	return (text:gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " "))
end

local function filter(player, text)
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return nil, "Couldn't check the name right now, try again"
	end
	if result:find("#") then
		return nil, "That name isn't allowed, try another one"
	end
	return result
end

---------------------------------------------------------------- ações
local function create(player, name, tag, color)
	local data = DataService.Get(player)
	if not (data and data.Started) then
		return false, "Get your first dog first! 🐶"
	end
	if data.Clan then
		return false, "Leave your clan first."
	end
	name, tag = clean(name), clean(tag)
	if not name or not tag then
		return false, "Type a name and a tag."
	end
	tag = string.upper(tag)
	local nlen = utf8.len(name) or 0
	if nlen < C.Name[1] or nlen > C.Name[2] then
		return false, "The name needs " .. C.Name[1] .. " to " .. C.Name[2] .. " letters."
	end
	if not tag:match("^[A-Z0-9]+$") or #tag < C.Tag[1] or #tag > C.Tag[2] then
		return false, "The tag needs " .. C.Tag[1] .. " to " .. C.Tag[2] .. " letters or numbers (A-Z, 0-9)."
	end
	color = math.clamp(math.floor(tonumber(color) or 1), 1, #C.Colors)
	if data.Cash < C.Cost then
		return false, "You need $" .. Config.Format(C.Cost) .. " to create a clan."
	end
	local fname, err = filter(player, name)
	if not fname then
		return false, err
	end
	local ftag, err2 = filter(player, tag)
	if not ftag then
		return false, err2
	end
	if not player.Parent or DataService.Get(player) ~= data or data.Clan then
		return false, "Try again."
	end
	-- reserva o nome (2 clãs não têm o mesmo nome)
	local id = tostring(player.UserId) .. "-" .. tostring(os.time())
	local nameKey = string.lower(fname)
	local takenBy = nil
	local okName = Names.Update(nameKey, function(old)
		if type(old) == "string" and old ~= "" and old ~= id then
			takenBy = old
			return nil
		end
		return id
	end)
	if not okName then
		return false, "Couldn't create the clan right now, try again."
	end
	if takenBy then
		-- o nome era de um clã desfeito? então pode usar
		if ClanService.Get(takenBy, true) then
			return false, "That clan name is taken, try another one."
		end
		Names.Update(nameKey, function()
			return id
		end)
	end
	if not DataService.Spend(player, C.Cost) then
		Names.Remove(nameKey)
		return false, "You need $" .. Config.Format(C.Cost) .. " to create a clan."
	end
	local rec = {
		Id = id,
		Name = fname,
		Tag = ftag,
		Color = color,
		Owner = player.UserId,
		Members = { [tostring(player.UserId)] = { N = player.DisplayName, J = os.time() } },
		Count = 1,
		Open = false,
		Created = os.time(),
	}
	local okRec = Clans.Update(keyOf(id), function()
		return rec
	end)
	if not okRec then
		DataService.AddCash(player, C.Cost, "refund")
		Names.Remove(nameKey)
		return false, "Couldn't create the clan right now, try again."
	end
	remember(id, rec)
	setMine(player, rec)
	DataService.SaveNow(player)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			remotes.Notify:FireClient(p, "🚩 " .. player.DisplayName .. " created the clan [" .. ftag .. "] " .. fname .. "!", "blue")
		end
	end
	return true, "🚩 Clan [" .. ftag .. "] " .. fname .. " created! Invite your friends."
end

-- entra no clã (aceitou convite ou clã aberto)
local function joinClan(player, id, viaInvite)
	local data = DataService.Get(player)
	if not (data and data.Started) then
		return false, "Get your first dog first! 🐶"
	end
	if data.Clan then
		return false, "Leave your clan first."
	end
	local uid = tostring(player.UserId)
	local fail = nil
	local ok, rec = Clans.Update(keyOf(id), function(old)
		if type(old) ~= "table" or old.Gone then
			fail = "That clan doesn't exist anymore."
			return nil
		end
		if not old.Open and not viaInvite then
			fail = "This clan is invite-only."
			return nil
		end
		if old.Members[uid] then
			return old
		end
		if (old.Count or 0) >= C.Max then
			fail = "This clan is full (" .. C.Max .. " members)."
			return nil
		end
		old.Members[uid] = { N = player.DisplayName, J = os.time() }
		old.Count = (old.Count or 0) + 1
		return old
	end)
	if fail then
		return false, fail
	end
	if not (ok and type(rec) == "table") then
		return false, "Couldn't join right now, try again."
	end
	if not player.Parent or DataService.Get(player) ~= data or data.Clan then
		return false, "Try again."
	end
	remember(id, rec)
	setMine(player, rec)
	DataService.SaveNow(player)
	invites[player] = nil
	tellMembers(id, "🚩 " .. player.DisplayName .. " joined the clan!", "green", player)
	publish({ K = "upd", C = id })
	return true, "🚩 Welcome to [" .. rec.Tag .. "] " .. rec.Name .. "!"
end

-- tira um membro do registro (sair ou expulsar). O dono que sai passa o clã para o mais antigo; sem ninguém, desfaz.
local function removeMember(id, userId)
	local uid = tostring(userId)
	local gone, name = false, nil
	local ok, rec = Clans.Update(keyOf(id), function(old)
		if type(old) ~= "table" then
			return nil
		end
		if old.Members[uid] then
			old.Members[uid] = nil
			old.Count = math.max(0, (old.Count or 1) - 1)
		end
		if old.Owner == userId then
			local nextUid, nextJ = nil, math.huge
			for m, info in pairs(old.Members) do
				local j = type(info) == "table" and tonumber(info.J) or 0
				if j < nextJ then
					nextUid, nextJ = m, j
				end
			end
			if nextUid then
				old.Owner = tonumber(nextUid)
			else
				old.Gone = true
			end
		end
		gone = old.Gone == true
		name = old.Name
		return old
	end)
	if ok and gone and name then
		Names.Remove(string.lower(name))
	end
	if ok then
		remember(id, (type(rec) == "table" and not rec.Gone) and rec or false)
	end
	return ok, (type(rec) == "table" and not rec.Gone) and rec or nil
end

local function leave(player)
	local data = DataService.Get(player)
	local id = data and data.Clan
	if not id then
		return false, "You're not in a clan."
	end
	local ok, rec = removeMember(id, player.UserId)
	if not ok then
		return false, "Couldn't leave right now, try again."
	end
	setMine(player, nil)
	DataService.SaveNow(player)
	if rec then
		refreshMembers(id, rec)
		tellMembers(id, "🚩 " .. player.DisplayName .. " left the clan.", "orange")
	end
	publish({ K = "upd", C = id })
	return true, "You left the clan."
end

local function kick(player, userId)
	local data = DataService.Get(player)
	local id = data and data.Clan
	local rec = id and ClanService.Get(id, true)
	userId = tonumber(userId)
	if not (rec and userId) then
		return false, "You're not in a clan."
	end
	if rec.Owner ~= player.UserId then
		return false, "Only the clan leader can kick."
	end
	if userId == player.UserId then
		return false, "Use LEAVE to leave your own clan."
	end
	if not rec.Members[tostring(userId)] then
		return false, "Not in your clan."
	end
	local ok, newRec = removeMember(id, userId)
	if not ok then
		return false, "Couldn't kick right now, try again."
	end
	local target = Players:GetPlayerByUserId(userId)
	if target then
		setMine(target, nil)
		remotes.Notify:FireClient(target, "🚩 You were removed from [" .. rec.Tag .. "] " .. rec.Name .. ".", "red")
		remotes.ClanEvent:FireClient(target, "changed")
	else
		publish({ K = "kick", C = id, U = userId })
	end
	if newRec then
		refreshMembers(id, newRec)
	end
	publish({ K = "upd", C = id })
	return true, "Kicked."
end

local function setOpen(player, value)
	local data = DataService.Get(player)
	local id = data and data.Clan
	if not id then
		return false, "You're not in a clan."
	end
	local fail = nil
	local ok, rec = Clans.Update(keyOf(id), function(old)
		if type(old) ~= "table" or old.Gone then
			fail = "That clan doesn't exist anymore."
			return nil
		end
		if old.Owner ~= player.UserId then
			fail = "Only the clan leader can change this."
			return nil
		end
		old.Open = value == true
		return old
	end)
	if fail then
		return false, fail
	end
	if not ok then
		return false, "Try again."
	end
	remember(id, rec)
	refreshMembers(id, rec)
	publish({ K = "upd", C = id })
	return true, value and "🔓 Anyone can join your clan now." or "🔒 Invite-only."
end

local function invite(player, target)
	local data = DataService.Get(player)
	local id = data and data.Clan
	local rec = id and ClanService.Get(id)
	if not rec then
		return false, "Create or join a clan first."
	end
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target.Parent ~= Players or target == player then
		return false, "Player not found."
	end
	local tdata = DataService.Get(target)
	if not (tdata and tdata.Started) then
		return false, "That player isn't ready yet."
	end
	if tdata.Clan then
		return false, target.DisplayName .. " is already in a clan."
	end
	if (rec.Count or 0) >= C.Max then
		return false, "Your clan is full (" .. C.Max .. " members)."
	end
	if not DataService.Throttle(player, "ClanInvite", 3) then
		return false, "Wait a bit before inviting again."
	end
	invites[target] = invites[target] or {}
	local inv = { Id = id, Name = rec.Name, Tag = rec.Tag, From = player.DisplayName, Until = os.clock() + C.InviteTime }
	invites[target][id] = inv
	remotes.ClanEvent:FireClient(target, "invite", { Id = id, Name = rec.Name, Tag = rec.Tag, From = player.DisplayName })
	return true, "🚩 Invite sent to " .. target.DisplayName .. "!"
end

local function accept(player, id)
	local inv = invites[player] and invites[player][id]
	if not inv or inv.Until < os.clock() then
		return false, "That invite expired."
	end
	return joinClan(player, id, true)
end

---------------------------------------------------------------- tela
local function view(player)
	local data = DataService.Get(player)
	local out = { Cost = C.Cost, Max = C.Max, Colors = #C.Colors, Invites = {}, Browse = {} }
	local id = data and data.Clan
	local rec = id and ClanService.Get(id)
	if rec then
		local members = {}
		for uid, info in pairs(rec.Members) do
			local n = tonumber(uid)
			table.insert(members, {
				UserId = n,
				Name = type(info) == "table" and info.N or "?",
				Leader = n == rec.Owner,
				Online = Players:GetPlayerByUserId(n or 0) ~= nil,
				Joined = type(info) == "table" and info.J or 0,
			})
		end
		table.sort(members, function(a, b)
			if a.Leader ~= b.Leader then
				return a.Leader
			end
			return a.Joined < b.Joined
		end)
		local okP, pts = weekStore().Get(id)
		out.Clan = {
			Id = rec.Id,
			Name = rec.Name,
			Tag = rec.Tag,
			Color = rec.Color,
			Open = rec.Open == true,
			Leader = rec.Owner == (player.UserId),
			Count = rec.Count or #members,
			Members = members,
			Week = ((okP and tonumber(pts)) or 0) + (points[id] or 0),
		}
	end
	local now = os.clock()
	for cid, inv in pairs(invites[player] or {}) do
		if inv.Until > now then
			table.insert(out.Invites, { Id = cid, Name = inv.Name, Tag = inv.Tag, From = inv.From })
		end
	end
	-- clãs de quem está neste servidor (para entrar nos abertos)
	local seen = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local cid = p:GetAttribute("ClanId")
		if cid and not seen[cid] and cid ~= id then
			seen[cid] = true
			local r = ClanService.Get(cid)
			if r then
				table.insert(out.Browse, { Id = cid, Name = r.Name, Tag = r.Tag, Color = r.Color, Count = r.Count or 0, Open = r.Open == true })
			end
		end
	end
	return out
end

---------------------------------------------------------------- 🏆 pontos da semana
function ClanService.AddPoints(player, n)
	local id = player and player:GetAttribute("ClanId")
	n = math.floor(tonumber(n) or 0)
	if type(id) == "string" and n > 0 then
		points[id] = (points[id] or 0) + n
	end
end

local function flushPoints()
	local list = points
	points = {}
	local store = weekStore()
	for id, n in pairs(list) do
		local ok = store.Increment(id, n)
		if not ok then
			points[id] = (points[id] or 0) + n -- tenta de novo na próxima
		end
	end
end
ClanService.FlushPoints = flushPoints

-- confere o clã do perfil quando o jogador entra (expulso fora do jogo / clã desfeito = sai)
local function onLoaded(player, data)
	local id = data.Clan
	if not id then
		return
	end
	local rec = ClanService.Get(id, true)
	if not player.Parent then
		return
	end
	if rec and rec.Members[tostring(player.UserId)] then
		applyTag(player, rec)
	elseif rec ~= nil or cache[id] then
		-- (registro lido e ele não está mais lá) — se o DataStore falhou, deixa como está
		setMine(player, nil)
		remotes.Notify:FireClient(player, "🚩 You are no longer in your old clan.", "orange")
	end
end

function ClanService.Start(r)
	remotes = r
	remotes.ClanAction.OnServerInvoke = function(player, action, a, b, c)
		if not DataService.Throttle(player, "ClanAction", 0.3) then
			return false, "Slow down!"
		end
		if action == "state" then
			return true, view(player)
		end
		if busy[player] then
			return false, "Wait a moment..."
		end
		busy[player] = true
		local ok, res, msg = pcall(function()
			if action == "create" then
				return create(player, a, b, c)
			elseif action == "invite" then
				return invite(player, a)
			elseif action == "accept" and type(a) == "string" then
				return accept(player, a)
			elseif action == "decline" and type(a) == "string" then
				if invites[player] then
					invites[player][a] = nil
				end
				return true, "Declined."
			elseif action == "join" and type(a) == "string" then
				return joinClan(player, a, false)
			elseif action == "leave" then
				return leave(player)
			elseif action == "kick" then
				return kick(player, a)
			elseif action == "open" then
				return setOpen(player, a)
			end
			return false, "?"
		end)
		busy[player] = nil
		if not ok then
			warn("[ClanService]", res)
			return false, "That didn't work, try again."
		end
		return res, msg
	end
	DataService.Loaded.Event:Connect(function(player, data)
		task.spawn(onLoaded, player, data)
	end)
	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		busy[player] = nil
	end)
	-- a sigla e o título em cima da cabeça mudam na hora
	local function watch(player)
		for _, attr in ipairs({ "ClanTag", "Title" }) do
			player:GetAttributeChangedSignal(attr):Connect(function()
				local DogService = lazy("DogService")
				local f = DogService and DogService.GetFighter(player)
				if f and Fighters.Alive(f) then
					Fighters.RefreshLabel(f)
				end
			end)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in ipairs(Players:GetPlayers()) do
		watch(p)
	end
	-- 🏆 pontos: vitória (selvagem, campeão ou PvP), captura e missão de ilha
	Fighters.Killed.Event:Connect(function(victim, killer)
		if killer and killer.Kind == "player" and killer.Owner and (victim.Kind == "npc" or victim.Kind == "player" or victim.Kind == "boss") then
			ClanService.AddPoints(killer.Owner, C.Points.Win)
		end
	end)
	local Catch = lazy("CatchService")
	if Catch and Catch.Caught then
		Catch.Caught.Event:Connect(function(player)
			ClanService.AddPoints(player, C.Points.Catch)
		end)
	end
	local Progression = lazy("ProgressionService")
	if Progression and Progression.Tracked then
		Progression.Tracked.Event:Connect(function(player, kind, n)
			if kind == "Quest" then
				ClanService.AddPoints(player, C.Points.Quest * (n or 1))
			end
		end)
	end
	task.spawn(function()
		while true do
			task.wait(60)
			pcall(flushPoints)
		end
	end)
	game:BindToClose(function()
		pcall(flushPoints)
	end)
	-- mudanças feitas em outro servidor
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				local m = message and message.Data
				if type(m) ~= "table" or type(m.C) ~= "string" then
					return
				end
				if m.K == "kick" then
					local target = Players:GetPlayerByUserId(tonumber(m.U) or 0)
					if target and target:GetAttribute("ClanId") == m.C then
						setMine(target, nil)
						remotes.Notify:FireClient(target, "🚩 You were removed from your clan.", "red")
						remotes.ClanEvent:FireClient(target, "changed")
					end
				elseif m.K == "upd" then
					local here = false
					for _, p in ipairs(Players:GetPlayers()) do
						here = here or p:GetAttribute("ClanId") == m.C
					end
					if here then
						refreshMembers(m.C, ClanService.Get(m.C, true))
					end
				end
			end)
		end)
	end)
end

return ClanService
