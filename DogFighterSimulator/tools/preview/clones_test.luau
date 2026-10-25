-- TESTE DOS CLONES DO SPOOKY CLOWN (2026-10) sem Roblox. Usado pelo clones_test.py, que monta antes deste arquivo:
-- MODULES (módulos de verdade), SHARED_NAMES, PACK_NAMES e PART ("hostile" ou "service").
--   hostile: Fighters.Hostile DE VERDADE com clones (dono, selvagem, outro jogador no Coliseu, clone do mesmo dono)
--   service: CloneService DE VERDADE com um Fighters/CombatService falso que anota tudo, relógio falso:
--            nascem 2 clones só para o palhaço, seguem o dono, batem junto, soltam a mesma habilidade ao lado da
--            setinha, dão a dash junto, um clone que cai volta depois de RESPAWN s e somem quando o dono cai.

---------------------------------------------------------------- relógio falso + agenda
local VT = 0
local realOs = os
os = setmetatable({ clock = function()
	return VT
end, time = function()
	return 1000 + VT
end }, { __index = realOs })
local queue, errors = {}, {}
local function schedule(at, co, ...)
	table.insert(queue, { at = at, co = co, args = table.pack(...) })
end
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		table.insert(errors, tostring(err) .. " | " .. debug.traceback(co, nil, 1):gsub("\n", " / "))
	end
end
task = {
	wait = function(s)
		local co = coroutine.running()
		schedule(VT + math.max(s or 0, 1 / 60), co)
		coroutine.yield()
		return s or 0
	end,
	spawn = function(fn, ...)
		local co = type(fn) == "thread" and fn or coroutine.create(fn)
		resume(co, ...)
		return co
	end,
	delay = function(s, fn, ...)
		local co = coroutine.create(fn)
		schedule(VT + (s or 0), co, ...)
		return co
	end,
	defer = function(fn, ...)
		local co = coroutine.create(fn)
		schedule(VT, co, ...)
		return co
	end,
	cancel = function() end,
}
local function runUntil(limit)
	while true do
		local best = nil
		for i = 1, #queue do
			if not best or queue[i].at < queue[best].at then
				best = i
			end
		end
		local nextAt = best and queue[best].at or math.huge
		if best and nextAt <= VT then
			local item = table.remove(queue, best)
			if coroutine.status(item.co) == "suspended" then
				resume(item.co, table.unpack(item.args, 1, item.args.n))
			end
		elseif VT >= limit then
			break
		else
			VT = math.min(nextAt, limit)
		end
	end
	VT = math.max(VT, limit)
end

---------------------------------------------------------------- serviços
local function signal()
	local list = {}
	return {
		Connect = function(_, fn)
			table.insert(list, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, fn in ipairs(list) do
				fn(...)
			end
		end,
	}
end
local Shared = Instance.new("Folder")
Shared.Name = "Shared"
for _, n in ipairs(SHARED_NAMES) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Parent = Shared
end
local packsFolder = Instance.new("Folder")
packsFolder.Name = "DogPacks"
packsFolder.Parent = Shared
for _, n in ipairs(PACK_NAMES) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Parent = packsFolder
end
local RS = Instance.new("Folder")
RS.Name = "ReplicatedStorage"
Shared.Parent = RS
local PlayersList = {}
local PlayersService = {
	PlayerRemoving = signal(),
	GetPlayers = function()
		return PlayersList
	end,
}
local Services = Instance.new("Folder")
Services.Name = "Services"
for _, n in ipairs({ "Fighters", "CombatService", "ZoneGeo", "CloneService" }) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Parent = Services
end
local wsAttrs = {}
workspace = {
	GetAttribute = function(_, k)
		return wsAttrs[k]
	end,
	SetAttribute = function(_, k, v)
		wsAttrs[k] = v
	end,
}
game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return RS
		elseif name == "Players" then
			return PlayersService
		end
		return {
			AddTag = function() end,
			HasTag = function()
				return false
			end,
			Create = function()
				return { Play = function() end }
			end,
		}
	end,
}
local cache = {}
local overrides = {}
function require(m)
	local name = m.Name
	if overrides[name] then
		return overrides[name]
	end
	if cache[name] == nil then
		local fn = MODULES[name]
		assert(fn, "módulo desconhecido: " .. tostring(name))
		cache[name] = fn(m)
	end
	return cache[name]
end

local fails = 0
local function check(ok, msg)
	if ok then
		print("OK|" .. msg)
	else
		fails += 1
		print("FAIL|" .. msg)
	end
end

local V = Vector3.new
local function fakeModel()
	local m = Instance.new("Model")
	m.Parent = Instance.new("Folder")
	return m
end

---------------------------------------------------------------- parte 1: Fighters.Hostile de verdade
if PART == "hostile" then
	local Fighters = require(Services.Fighters)
	local function F(kind, owner, island, extra)
		local f = {
			Kind = kind,
			Owner = owner,
			Zone = "arena",
			Island = island,
			Model = fakeModel(),
			Humanoid = { Health = 100 },
			Root = { Position = V(0, 0, 0) },
		}
		for k, v in pairs(extra or {}) do
			f[k] = v
		end
		return f
	end
	local p1, p2 = { Name = "P1" }, { Name = "P2" }
	local clown = F("player", p1, "colosseum")
	local clone = F("clone", p1, "colosseum", { CloneOf = clown })
	local clone2 = F("clone", p1, "colosseum", { CloneOf = clown })
	local other = F("player", p2, "colosseum")
	local wild = F("npc", nil, "colosseum")
	check(not Fighters.Hostile(clone, clown), "clone não briga com o próprio dono")
	check(not Fighters.Hostile(clown, clone), "dono não briga com o próprio clone")
	check(not Fighters.Hostile(clone, clone2), "clones do mesmo dono não brigam entre si")
	check(Fighters.Hostile(clone, wild) and Fighters.Hostile(wild, clone), "clone e selvagem da mesma ilha são inimigos")
	check(Fighters.Hostile(clone, other) and Fighters.Hostile(other, clone), "PvP do Coliseu: clone x outro jogador")
	workspace:SetAttribute("SuperBossAwake", true)
	check(not Fighters.Hostile(clone, other), "Super Boss acordado: clone não briga com outro jogador")
	workspace:SetAttribute("SuperBossAwake", nil)
	local far = F("npc", nil, "fire")
	check(not Fighters.Hostile(clone, far), "selvagem de outra ilha não é inimigo do clone")
	local home = F("clone", p1, nil, { CloneOf = F("player", p1, nil, { Zone = "home" }), Zone = "home" })
	check(not Fighters.Hostile(home, wild), "em casa ninguém briga")
	local marker = { Dummy = true, Caster = clone, Removed = false }
	check(Fighters.Hostile(clone, marker), "o alvo da setinha do clone é inimigo só dele")
	check(not Fighters.Hostile(clown, marker), "o alvo da setinha do clone não é do dono")
	print(string.format("END|%d", fails))
	return
end

---------------------------------------------------------------- parte 2: CloneService com Fighters falso
local log = { spawned = 0, removed = 0, melee = 0, hits = 0, runs = {}, pushes = 0, areas = 0, teleports = 0, moves = 0 }
local List = {}
local nextId = 0
local function newFighter(o)
	nextId += 1
	local root = { Position = o.At or V(0, 3, 0), Size = V(1.4, 1.2, 2.8) }
	root.CFrame = CFrame.new(root.Position)
	local f
	f = {
		Id = nextId,
		Kind = o.Kind,
		Owner = o.Owner,
		Zone = o.Zone or "arena",
		Island = o.Island or "colosseum",
		SpeciesId = o.SpeciesId,
		Species = (require(Shared.DogData)).Species[o.SpeciesId],
		Level = o.Level or 10,
		Model = fakeModel(),
		Root = root,
		Radius = 1.4,
		HipHeight = 1.15,
		Stats = { Atk = 100 * ((o.StatMult and o.StatMult.Atk) or 1), MaxHP = 1000, Speed = 19 },
		Humanoid = {
			Health = 1000,
			HipHeight = 1.15,
			WalkSpeed = 19,
			MoveTo = function(_, p)
				log.moves += 1
				-- anda direto até o ponto (o teste só quer ver que ele segue)
				root.Position = V(p.X, root.Position.Y, p.Z)
				root.CFrame = CFrame.new(root.Position)
			end,
		},
		FrozenUntil = 0,
	}
	List[f] = true
	return f
end
local FakeFighters = {
	Spawn = function(o)
		log.spawned += 1
		return newFighter({ Kind = o.Kind, Owner = o.Owner, SpeciesId = o.SpeciesId, Level = o.Level, At = o.CFrame.Position + V(0, 2, 0), Zone = o.Zone, Island = o.Island, StatMult = o.StatMult })
	end,
	Alive = function(f)
		return f ~= nil and not f.Dead and not f.Removed and f.Humanoid.Health > 0
	end,
	Remove = function(f)
		if f and not f.Removed then
			f.Removed = true
			List[f] = nil
			log.removed += 1
		end
	end,
	Fx = function() end,
	Face = function() end,
	SetAction = function() end,
	Melee = function()
		log.melee += 1
	end,
	Push = function(f, v, t)
		log.pushes += 1
		-- anda o tanto do empurrão (o bote do clone chega no inimigo)
		f.Root.Position += V(v.X, 0, v.Z) * t
		f.Root.CFrame = CFrame.new(f.Root.Position)
	end,
	Teleport = function(f, p)
		log.teleports += 1
		f.Root.Position = p + V(0, 2, 0)
		f.Root.CFrame = CFrame.new(f.Root.Position)
	end,
	IsFrozen = function(f)
		return os.clock() < (f.FrozenUntil or 0)
	end,
	FlatDistance = function(a, b)
		return V(a.X - b.X, 0, a.Z - b.Z).Magnitude
	end,
	Enemies = function(f, pos, radius)
		local out = {}
		for o in pairs(List) do
			if o.Kind == "npc" and not o.Removed then
				local d = V(o.Root.Position.X - pos.X, 0, o.Root.Position.Z - pos.Z).Magnitude
				if d <= radius + 1 then
					table.insert(out, o)
				end
			end
		end
		return out
	end,
	DamageArea = function()
		log.areas += 1
		return {}
	end,
	Marker = function(caster, p)
		return { Dummy = true, Caster = caster, Root = { Position = p } }
	end,
	RemoveMarker = function(m)
		m.Removed = true
	end,
}
overrides.Fighters = FakeFighters
overrides.CombatService = {
	Melee = function()
		log.hits += 1
	end,
	RunSpecial = function(f, target, onDone, name, playerCast, quiet)
		table.insert(log.runs, { f = f, target = target, name = name, playerCast = playerCast, quiet = quiet })
		task.delay(0.5, onDone)
	end,
}
overrides.ZoneGeo = {
	Ground = function(p)
		return V(p.X, 0, p.Z)
	end,
	Clamp = function(_, p)
		return p
	end,
}
local CloneService = require(Services.CloneService)

local p1 = { Name = "Clown", UserId = 1, Parent = PlayersService }
local p2 = { Name = "Normal", UserId = 2, Parent = PlayersService }
PlayersList = { p1, p2 }
local clown = newFighter({ Kind = "player", Owner = p1, SpeciesId = "clown_dog", At = V(0, 3, 0) })
local normal = newFighter({ Kind = "player", Owner = p2, SpeciesId = "caramelo", At = V(100, 3, 0) })
local masters = { [p1] = clown, [p2] = normal }
CloneService.Start(function(player)
	return masters[player]
end)
runUntil(0.5)
local clones = CloneService.Of(clown)
check(#clones == 2, "o palhaço ganhou 2 clones (" .. #clones .. ")")
check(#CloneService.Of(normal) == 0, "cachorro normal não ganha clone")
check(clones[1] and clones[1].Kind == "clone" and clones[1].CloneOf == clown and clones[1].Owner == p1, "clone sabe quem é o dono")
check(clones[1] and clones[1].Stats.Atk < clown.Stats.Atk, "clone bate mais fraco que o dono")
-- 🚶 o dono anda: os clones vão atrás (um de cada lado)
clown.Root.Position = V(30, 3, 0)
clown.Root.CFrame = CFrame.new(clown.Root.Position)
runUntil(1.5)
local ok = true
for _, c in ipairs(clones) do
	if FakeFighters.FlatDistance(c.Root.Position, clown.Root.Position) > 8 then
		ok = false
	end
end
check(ok, "clones seguem o dono")
check(clones[1].Root.Position.X ~= clones[2].Root.Position.X or clones[1].Root.Position.Z ~= clones[2].Root.Position.Z, "um clone de cada lado")
-- 🐾 patada do dono: os 2 batem junto; o inimigo na frente do dono leva (os clones dão um bote até ele)
local wild = newFighter({ Kind = "npc", SpeciesId = "pug", At = clown.Root.Position + V(0, 0, -4) })
CloneService.Melee(clown, 1, V(0, 0, -1))
runUntil(2)
check(log.melee == 2, "os 2 clones fizeram a patada (" .. log.melee .. ")")
check(log.hits == 2, "o inimigo na frente do dono levou a patada dos 2 clones (" .. log.hits .. ")")
wild.Removed = true
List[wild] = nil
-- patada sem ninguém na frente: patada no ar, sem bote
local pushes0 = log.pushes
CloneService.Melee(clown, 2, V(0, 0, -1))
runUntil(2.5)
check(log.melee == 4 and log.pushes == pushes0, "sem inimigo: os clones batem no ar, sem bote")
log.pushes = 0
-- ✨ habilidade: cada clone solta a MESMA, um de cada lado da setinha, sem repetir o nome na tela
local point = clown.Root.Position + V(0, -3, -20)
CloneService.Cast(clown, "SK_clown_dog_3", point)
runUntil(3)
check(#log.runs == 2, "os 2 clones soltaram a habilidade (" .. #log.runs .. ")")
local sides = {}
for _, r in ipairs(log.runs) do
	sides[#sides + 1] = r.target.Root.Position
	check(r.name == "SK_clown_dog_3" and r.playerCast == true and r.quiet == true, "clone: mesma habilidade, rápida e sem o nome na tela")
	check(r.target.Dummy and r.target.Caster == r.f, "clone mira o próprio alvo invisível")
	check(FakeFighters.FlatDistance(r.target.Root.Position, point) <= 4.5, "alvo do clone perto da setinha do dono")
end
check(#sides == 2 and (sides[1] - sides[2]).Magnitude > 4, "um clone de cada lado da setinha")
runUntil(4)
for _, c in ipairs(clones) do
	check((c.Casting or 0) == 0, "o clone terminou a habilidade (Casting = 0)")
end
-- 💨 dash junto
CloneService.Dash(clown, V(1, 0, 0))
runUntil(5)
check(log.pushes == 2, "os 2 clones deram a dash (" .. log.pushes .. ")")
-- 💀 um clone cai: volta depois de RESPAWN
clones[1].Humanoid.Health = 0
runUntil(5.5)
check(#CloneService.Of(clown) == 1, "clone que caiu sumiu da lista")
runUntil(5.5 + CloneService.RESPAWN + 0.5)
check(#CloneService.Of(clown) == 2, "clone voltou depois de " .. CloneService.RESPAWN .. " s")
-- 🏝️ dono teleporta para longe (outra ilha): os clones vão junto
clown.Root.Position = V(900, 3, 900)
clown.Root.CFrame = CFrame.new(clown.Root.Position)
clown.Island = "fire"
runUntil(VT + 0.5)
local near = true
for _, c in ipairs(CloneService.Of(clown)) do
	if FakeFighters.FlatDistance(c.Root.Position, clown.Root.Position) > 10 or c.Island ~= "fire" then
		near = false
	end
end
check(near, "clones teleportam junto quando o dono vai para longe")
-- dono desmaia: os clones somem
clown.Humanoid.Health = 0
runUntil(VT + 0.5)
check(#CloneService.Of(clown) == 0 and log.removed >= 2, "dono caiu: clones somem")
-- troca de cachorro: sem clones
local back = newFighter({ Kind = "player", Owner = p1, SpeciesId = "pug", At = V(0, 3, 0) })
masters[p1] = back
runUntil(VT + 0.5)
check(#CloneService.Of(back) == 0, "trocou para um cachorro normal: sem clones")
for _, e in ipairs(errors) do
	fails += 1
	print("FAIL|erro: " .. e)
end
print(string.format("END|%d", fails))
