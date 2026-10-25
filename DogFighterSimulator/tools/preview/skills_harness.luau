-- TESTE DAS HABILIDADES SEM ROBLOX (2026-10). Roda cada habilidade de verdade (SkillKit + SpecialsPacks/Skills_*)
-- num mini-mundo: relógio falso (task.wait/delay/os.clock), chão plano, Fighters falso que só anota dano, efeitos
-- e poses. Cenários: A = inimigo de verdade (e um segundo do lado) · B = alvo invisível (setinha) com inimigo
-- perto · C = alvo invisível sem ninguém · D = 🎯 MIRA DO JOGADOR (2026-10): o jogador continua no controle, a
-- setinha está LONGE (40 studs); mede quanto tempo o servidor segura o corpo, quanto o cachorro anda, o dano perto
-- da setinha e num inimigo do lado (não pode ir atrás dele sozinho) e se o kit mexeu no corpo sem segurar.
-- Usado pelo skills_test.py (que confere os nomes dos efeitos e poses).
-- Variáveis que o skills_test.py coloca antes deste arquivo: MODULES, SHARED_NAMES, PACK_NAMES, SKILL_PACKS.

---------------------------------------------------------------- relógio falso + agenda
local VT = 0
local realOs = os
os = setmetatable({ clock = function()
	return VT
end }, { __index = realOs })

local queue = {}
local errors = {}
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
local renderCallbacks = {}
CLIENT_ACTIVE = false
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
		elseif CLIENT_ACTIVE and #renderCallbacks > 0 then
			VT = math.min(nextAt, VT + 1 / 60, limit)
			for _, fn in ipairs(renderCallbacks) do
				local ok, err = pcall(fn, 1 / 60)
				if not ok then
					table.insert(errors, "cliente (quadro): " .. tostring(err))
				end
			end
		else
			VT = math.min(nextAt, limit)
		end
	end
	VT = math.max(VT, limit)
end

---------------------------------------------------------------- serviços
local noopSignal = { Connect = function()
	return { Disconnect = function() end }
end, Wait = function()
	task.wait(1 / 60)
	return 1 / 60
end }
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
local LocalPlayer = Instance.new("Folder")
LocalPlayer.Name = "LocalPlayer"
LocalPlayer:SetAttribute("GraphicsQuality", "Alto")
local Lighting = Instance.new("Folder")
Lighting.Name = "Lighting"
local services = {
	ReplicatedStorage = RS,
	RunService = {
		Heartbeat = noopSignal,
		Stepped = noopSignal,
		PreSimulation = noopSignal,
		RenderStepped = { Connect = function(_, fn)
			table.insert(renderCallbacks, fn)
			return { Disconnect = function() end }
		end },
	},
	Players = { LocalPlayer = LocalPlayer, GetPlayers = function()
		return {}
	end },
	Debris = { AddItem = function() end },
	CollectionService = {
		HasTag = function()
			return false
		end,
		AddTag = function() end,
		GetTagged = function()
			return {}
		end,
		GetInstanceAddedSignal = function()
			return noopSignal
		end,
	},
	TweenService = { Create = function()
		return { Play = function() end, Cancel = function() end }
	end },
	Lighting = Lighting,
}
TweenInfo = { new = function(...)
	return { Args = { ... } }
end }
UDim2.fromOffset = function(x, y)
	return UDim2.new(0, x, 0, y)
end
UDim2.fromScale = function(x, y)
	return UDim2.new(x, 0, y, 0)
end
MOCK.InstMethods.Destroying = noopSignal
MOCK.InstMethods.Emit = function() end
-- peças avisam quando são apagadas (o limite de peças dos efeitos conta com isso)
do
	local newInst = Instance.new
	local destroy = MOCK.InstMethods.Destroy
	Instance.new = function(className, parent)
		local inst = newInst(className, parent)
		if className == "Part" or className == "WedgePart" or className == "CornerWedgePart" then
			local fns = {}
			inst.Destroying = { Connect = function(_, fn)
				table.insert(fns, fn)
				return { Disconnect = function() end }
			end }
			inst.Destroy = function(self)
				local list = table.clone(fns)
				table.clear(fns)
				for _, fn in ipairs(list) do
					pcall(fn)
				end
				destroy(self)
			end
		end
		return inst
	end
end
game = { GetService = function(_, name)
	return services[name] or {}
end }
workspace = Instance.new("Folder")
workspace.Name = "Workspace"
local terrain = Instance.new("Folder")
terrain.Name = "Terrain"
terrain.Parent = workspace
local camera = Instance.new("Camera")
camera.CFrame = CFrame.new(Vector3.new(0, 25, 30), Vector3.new(0, 0, -14))
workspace.CurrentCamera = camera
workspace.BulkMoveTo = function(_, parts, cfs)
	for i, p in ipairs(parts) do
		assert(cfs[i] ~= nil, "BulkMoveTo sem CFrame")
		local pos = cfs[i].Position
		assert(pos.X == pos.X and pos.Y == pos.Y and pos.Z == pos.Z, "BulkMoveTo com posição NaN")
		p.CFrame = cfs[i]
	end
end

---------------------------------------------------------------- Fighters falso
local FX_LOG, ACTION_LOG = {}, {}
local BAD_FX = {}
local DAMAGE_LOG = {}
local FAKE = { List = {}, MARKER_HIT = 6 }
local function flatDist(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
function FAKE.Alive(f)
	return f ~= nil and not f.Dead and not f.Removed and f.Humanoid.Health > 0
end
function FAKE.Hostile(a, b)
	if a == b then
		return false
	end
	if a.Dummy or b.Dummy then
		local m, o = a.Dummy and a or b, a.Dummy and b or a
		return m.Caster == o and not m.Removed and FAKE.Alive(o)
	end
	return FAKE.Alive(a) and FAKE.Alive(b) and a.Team ~= b.Team
end
function FAKE.FlatDistance(a, b)
	return flatDist(a, b)
end
function FAKE.Enemies(f, pos, radius)
	local out = {}
	for _, o in ipairs(FAKE.List) do
		if FAKE.Hostile(f, o) and (not pos or flatDist(o.Root.Position, pos) - o.Radius <= radius) then
			table.insert(out, o)
		end
	end
	return out
end
-- confere os parâmetros dos efeitos que vão para o cliente (Vector3/Model onde precisa)
local NEEDS = {
	Position = "Vector3",
	From = "Vector3",
	To = "Vector3",
	Dir = "Vector3",
}
local CLIENT_H = nil
function FAKE.Fx(name, params)
	FX_LOG[name] = (FX_LOG[name] or 0) + 1
	if CLIENT_ACTIVE and CLIENT_H and type(params) == "table" then
		local h = CLIENT_H[name]
		if h then
			local ok, err = pcall(h, params)
			if not ok then
				table.insert(errors, "cliente " .. name .. ": " .. tostring(err))
			end
		end
	end
	if type(params) ~= "table" then
		BAD_FX[name .. ": params não é tabela"] = true
		return
	end
	for key, kind in pairs(NEEDS) do
		local v = params[key]
		if v ~= nil and typeof(v) ~= kind then
			BAD_FX[name .. "." .. key .. " = " .. typeof(v)] = true
		elseif v ~= nil and (v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z) then
			BAD_FX[name .. "." .. key .. " = NaN"] = true
		end
	end
	if params.Points then
		for _, p in ipairs(params.Points) do
			if typeof(p) ~= "Vector3" or p.X ~= p.X then
				BAD_FX[name .. ".Points inválido"] = true
			end
		end
	end
	for _, key in ipairs({ "Radius", "Duration", "Time", "Size", "Length", "Width" }) do
		local v = params[key]
		if v ~= nil and (type(v) ~= "number" or v ~= v or v < 0) then
			BAD_FX[name .. "." .. key .. " = " .. tostring(v)] = true
		end
	end
	if (name == "S_Mark" or name == "S_Aura" or name == "S_Charge" or name == "S_Orbit") and not params.Model then
		BAD_FX[name .. " sem Model"] = true
	end
end
function FAKE.SetAction(_f, action, _dur)
	ACTION_LOG[action] = (ACTION_LOG[action] or 0) + 1
end
-- 🎯 cenário D: o servidor só pode mexer no corpo do jogador enquanto segura (f.CastControl)
local AIM = { On = false, Caster = nil, Grabs = 0, GrabAt = 0, Grabbed = 0, Ungrabbed = 0, BadRelease = 0 }
local function touchBody(f)
	if AIM.On and f == AIM.Caster and AIM.Grabs <= 0 then
		AIM.Ungrabbed += 1
	end
end
function FAKE.Face(f)
	touchBody(f)
end
function FAKE.Stop(f)
	touchBody(f)
end
local function standY(f)
	return f.Humanoid.HipHeight + f.Root.Size.Y / 2 + 0.2
end
function FAKE.Teleport(f, pos)
	assert(typeof(pos) == "Vector3" and pos.X == pos.X, "Teleport com posição inválida")
	touchBody(f)
	f.Model:PivotTo(CFrame.new(pos + Vector3.new(0, standY(f), 0)))
end
-- empurrão: anda de verdade (para o dash funcionar no teste)
function FAKE.Push(f, v, d)
	assert(typeof(v) == "Vector3" and v.X == v.X, "Push com velocidade inválida")
	touchBody(f)
	if not FAKE.Alive(f) or f.Dummy then
		return
	end
	task.spawn(function()
		local steps = math.max(1, math.floor(d * 60))
		for _ = 1, steps do
			local p = f.Root.Position + Vector3.new(v.X, 0, v.Z) / 60
			f.Model:PivotTo(CFrame.new(Vector3.new(p.X, standY(f), p.Z)))
			task.wait(1 / 60)
		end
	end)
end
function FAKE.Freeze(f, s)
	if FAKE.Alive(f) then
		f.FrozenUntil = math.max(f.FrozenUntil or 0, VT + s)
	end
end
function FAKE.IsFrozen(f)
	return VT < (f.FrozenUntil or 0)
end
function FAKE.Damage(attacker, target, amount, opts)
	assert(type(amount) == "number" and amount == amount and amount >= 0, "dano inválido: " .. tostring(amount))
	if target and target.Dummy then
		local total = 0
		for _, e in ipairs(FAKE.Enemies(attacker, target.Root.Position, FAKE.MARKER_HIT)) do
			total += FAKE.Damage(attacker, e, amount, opts)
		end
		return total
	end
	if not FAKE.Alive(target) or (attacker ~= target and not FAKE.Hostile(attacker, target)) then
		return 0
	end
	if opts and opts.Knockback then
		assert(typeof(opts.Knockback) == "Vector3", "Knockback não é Vector3")
	end
	local dmg = amount * (attacker and attacker.DamageDealt or 1) * (target.DamageTaken or 1)
	if opts and opts.Crit then
		dmg *= 2
	end
	target.Taken = (target.Taken or 0) + dmg
	table.insert(DAMAGE_LOG, dmg)
	return dmg
end
function FAKE.DamageArea(attacker, position, radius, amount, opts)
	assert(typeof(position) == "Vector3" and position.X == position.X, "DamageArea com posição inválida")
	assert(type(radius) == "number" and radius == radius, "DamageArea com raio inválido")
	local hits = {}
	for _, e in ipairs(FAKE.Enemies(attacker, position, radius)) do
		FAKE.Damage(attacker, e, amount, opts)
		table.insert(hits, e)
	end
	return hits
end
function FAKE.Scale() end

local FAKE_ZONE = {
	Ground = function(p)
		return Vector3.new(p.X, 0, p.Z), Enum.Material.Grass
	end,
	Clamp = function(_f, p)
		return p
	end,
}

---------------------------------------------------------------- módulos
local Services = Instance.new("Folder")
Services.Name = "Services"
for _, n in ipairs({ "SkillKit", "Fighters", "ZoneGeo" }) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Parent = Services
end
local SP = Instance.new("Folder")
SP.Name = "SpecialsPacks"
SP.Parent = Services
for _, n in ipairs(SKILL_PACKS) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Parent = SP
end
local cache = {}
function require(m)
	local name = m.Name
	if name == "Fighters" then
		return FAKE
	elseif name == "ZoneGeo" then
		return FAKE_ZONE
	end
	if cache[name] == nil then
		cache[name] = assert(MODULES[name], "módulo desconhecido: " .. tostring(name))(m)
	end
	return cache[name]
end

local DogData = require(Shared.DogData)
local Config = require(Shared.Config)
local SkillKit = require(Services.SkillKit)

-- cliente: SkillArt + EffectsPacks/PackSkills de verdade; efeitos antigos (Telegraph, Explosion...) = vazios
if CLIENT_ON then
	local Client = Instance.new("Folder")
	Client.Name = "Client"
	local art = Instance.new("ModuleScript")
	art.Name = "SkillArt"
	art.Parent = Client
	local packs = Instance.new("Folder")
	packs.Name = "EffectsPacks"
	packs.Parent = Client
	local pack = Instance.new("ModuleScript")
	pack.Name = "PackSkills"
	pack.Parent = packs
	local legacy = {}
	for _, n in ipairs(LEGACY_FX) do
		legacy[n] = function() end
	end
	CLIENT_H = setmetatable({}, { __index = legacy })
	local Effects = { Bolt = function() end }
	require(pack)(CLIENT_H, Effects)
end
local Specials = {}
for _, n in ipairs(SKILL_PACKS) do
	require(SP[n])(Specials, FAKE)
end

---------------------------------------------------------------- lutadores falsos
local DogBuilder = SNAP_IDS and require(Shared.DogBuilder) or nil
local function makeFighter(speciesId, pos, team, kind)
	local sp = DogData.Species[speciesId]
	local model, root
	if DogBuilder then
		model = DogBuilder.Build(speciesId)
		root = model.PrimaryPart
		root.CFrame = CFrame.new(pos + Vector3.new(0, (model:GetAttribute("GroundHip") or model:GetAttribute("HipHeight") or 2) + root.Size.Y / 2, 0))
	else
		model = Instance.new("Model")
		model.Name = speciesId
		root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(3, 2.5, 4)
		root.CFrame = CFrame.new(pos + Vector3.new(0, 2 + 1.25 + 0.2, 0))
		root.Parent = model
		model.PrimaryPart = root
	end
	model.Parent = workspace
	-- só uma peça: move direto (o PivotTo do mini-Roblox acumula erro de giro em centenas de passos)
	local fighter = nil
	model.PivotTo = function(_, cf)
		if fighter then
			touchBody(fighter)
		end
		root.CFrame = CFrame.new(cf.Position) * cf.Rotation:Orthonormalize()
	end
	model.GetPivot = function()
		return root.CFrame
	end
	local f = {
		Model = model,
		Root = root,
		Humanoid = {
			Health = 1e9,
			MaxHealth = 1e9,
			HipHeight = DogBuilder and (model:GetAttribute("GroundHip") or model:GetAttribute("HipHeight") or 2) or 2,
			WalkSpeed = 16,
		},
		Stats = { Atk = 100, Speed = 16, MaxHP = 1e9, Power = 1 },
		Species = sp,
		SpeciesId = speciesId,
		Radius = DogBuilder and root.Size.Z / 2 or 2,
		Kind = kind or "npc",
		Team = team,
		DamageTaken = 1,
		DamageDealt = 1,
		SpeedMult = 1,
		FrozenUntil = 0,
		Zone = "arena",
	}
	fighter = f
	function f.Humanoid.MoveTo(_self, goal)
		local here = f.Root.Position
		local d = Vector3.new(goal.X - here.X, 0, goal.Z - here.Z)
		if d.Magnitude > 0.1 then
			local step = math.min(d.Magnitude, f.Humanoid.WalkSpeed * 0.1)
			local p = here + d.Unit * step
			model:PivotTo(CFrame.new(p))
		end
	end
	table.insert(FAKE.List, f)
	return f
end

local function makeMarker(caster, pos)
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Size = Vector3.new(2, 2, 2)
	root.CFrame = CFrame.new(pos + Vector3.new(0, 1, 0))
	root.Parent = model
	model.PrimaryPart = root
	model.Parent = workspace
	return {
		Dummy = true,
		Caster = caster,
		Kind = "dummy",
		Model = model,
		Root = root,
		Radius = 1,
		Zone = caster.Zone,
		FrozenUntil = 0,
		SpeedMult = 1,
		DamageTaken = 1,
		DamageDealt = 1,
		Stats = { Speed = 0, Atk = 0, MaxHP = 1, Power = 0 },
		Humanoid = { Health = 1, MaxHealth = 1, HipHeight = 0, WalkSpeed = 0, MoveTo = function() end },
	}
end

---------------------------------------------------------------- roda
local ids = {}
for id in pairs(SkillKit.Ids) do
	table.insert(ids, id)
end
table.sort(ids)

local function keys(t)
	local out = {}
	for k in pairs(t) do
		table.insert(out, k)
	end
	table.sort(out)
	return table.concat(out, ",")
end

local function scenario(id, speciesId, mode)
	table.clear(FAKE.List)
	table.clear(errors)
	table.clear(queue)
	table.clear(DAMAGE_LOG)
	VT = 1000
	-- (cenário E: o jogador está VOANDO, 30 studs acima do chão)
	local f = makeFighter(speciesId, Vector3.new(0, mode == "E" and 30 or 0, 0), "A", "player")
	f.Model:PivotTo(CFrame.lookAt(f.Root.Position, f.Root.Position + Vector3.new(0, 0, -1)))
	if mode == "E" then
		f.Owner = { UserId = 1, GetAttribute = function(_, k) return k == "Flying" end }
	end
	local e1, e2, target
	if mode == "A" then
		e1 = makeFighter("caramelo", Vector3.new(0, 0, -14), "B")
		e2 = makeFighter("caramelo", Vector3.new(5, 0, -17), "B")
		target = e1
	elseif mode == "B" then
		e1 = makeFighter("caramelo", Vector3.new(2, 0, -18), "B")
		target = makeMarker(f, Vector3.new(0, 0, -18))
	elseif mode == "D" or mode == "E" then
		-- 🎯 mira do jogador: setinha LONGE (40), um inimigo perto dela e outro do lado, atrás do cachorro
		e1 = makeFighter("caramelo", Vector3.new(2, 0, -40), "B")
		e2 = makeFighter("caramelo", Vector3.new(14, 0, 6), "B")
		target = makeMarker(f, Vector3.new(0, 0, -40))
		f.Controlled = true
		f.Casting = 1
		f.CastControl = function(delta)
			local before = AIM.Grabs
			AIM.Grabs += delta
			if AIM.Grabs < 0 then
				AIM.BadRelease += 1
				AIM.Grabs = 0
			end
			if before <= 0 and AIM.Grabs > 0 then
				AIM.GrabAt = VT
			elseif before > 0 and AIM.Grabs <= 0 then
				AIM.Grabbed += VT - AIM.GrabAt
			end
		end
		AIM.On, AIM.Caster, AIM.Grabs, AIM.Grabbed, AIM.Ungrabbed, AIM.BadRelease = true, f, 0, 0, 0, 0
	else
		target = makeMarker(f, Vector3.new(0, 0, -18))
	end
	CLIENT_ACTIVE = (mode == "A") and CLIENT_ON == true
	local finished = nil
	local start = VT
	local travel = 0
	local origin = f.Root.Position
	local minY = origin.Y
	if mode == "D" or mode == "E" then
		-- quanto o cachorro andou (no plano) durante a habilidade
		task.spawn(function()
			while finished == nil and VT - start < 14 do
				local p = f.Root.Position
				travel = math.max(travel, Vector3.new(p.X - origin.X, 0, p.Z - origin.Z).Magnitude)
				minY = math.min(minY, p.Y)
				task.wait(1 / 60)
			end
		end)
	end
	task.spawn(function()
		local ok, err = pcall(Specials[id], f, target)
		if not ok then
			table.insert(errors, "pcall: " .. tostring(err))
		end
		finished = VT - start
	end)
	runUntil(start + 14)
	if f.Root.Anchored then
		table.insert(errors, "o corpo ficou ancorado no fim")
	end
	if mode == "D" or mode == "E" then
		if AIM.Grabs > 0 then
			AIM.Grabbed += VT - AIM.GrabAt
		end
		AIM.On = false
	end
	local dmg = 0
	for _, x in ipairs(DAMAGE_LOG) do
		dmg += x
	end
	local tier = Config.SkillTier(f.Species.Rarity)
	local slot = SkillKit.Ids[id]
	local budget = f.Stats.Atk * (tier.Budget[slot - 1] or 1)
	local onMain = (e1 and e1.Taken or 0) / budget
	return {
		errors = table.clone(errors),
		finished = finished,
		total = dmg / budget,
		main = onMain,
		side = (e2 and e2.Taken or 0) / budget,
		travel = travel,
		drop = origin.Y - minY,
		grabbed = AIM.Grabbed,
		ungrabbed = AIM.Ungrabbed,
		leftHeld = AIM.Grabs,
		badRelease = AIM.BadRelease,
		frozenLeft = (f.Humanoid.WalkSpeed ~= 16) or (f.DamageTaken ~= 1) or (f.DamageDealt ~= 1) or (f.SpeedMult ~= 1),
	}
end

---------------------------------------------------------------- 📸 modo foto (skill_shots.py)
local function f4(n)
	return string.format("%.4f", n)
end
local function printPart(p)
	local mesh = p:FindFirstChildOfClass("SpecialMesh")
	local x, y, z, a, b, c, d, e, g, h, i, j = p.CFrame:GetComponents()
	print(table.concat({
		"P", p.ClassName, p.Shape and p.Shape.Name or "Block", mesh and mesh.MeshType and mesh.MeshType.Name or "",
		f4(p.Size.X), f4(p.Size.Y), f4(p.Size.Z),
		f4(x), f4(y), f4(z), f4(a), f4(b), f4(c), f4(d), f4(e), f4(g), f4(h), f4(i), f4(j),
		f4(p.Color.R), f4(p.Color.G), f4(p.Color.B),
		p.Material and p.Material.Name or "Plastic", f4(p.Transparency), p.Name,
	}, "|"))
end
-- posições das peças do cachorro a partir do HumanoidRootPart, seguindo as juntas (pose de descanso)
local function solve(model)
	local root = model.PrimaryPart
	local joints = {}
	for _, dd in ipairs(model:GetDescendants()) do
		if dd:IsA("JointInstance") and dd.Part0 and dd.Part1 then
			table.insert(joints, dd)
		end
	end
	local done = { [root] = true }
	local progress = true
	while progress do
		progress = false
		for _, jn in ipairs(joints) do
			local p0, p1 = jn.Part0, jn.Part1
			if done[p0] and not done[p1] then
				p1.CFrame = p0.CFrame * jn.C0 * jn.C1:Inverse()
				done[p1] = true
				progress = true
			elseif done[p1] and not done[p0] then
				p0.CFrame = p1.CFrame * jn.C1 * jn.C0:Inverse()
				done[p0] = true
				progress = true
			end
		end
	end
end
local function snapshot(label, fighters)
	print("DOG|" .. label .. "|" .. label .. "|shot|1,1,1|0|0")
	for _, fi in ipairs(fighters) do
		solve(fi.Model)
		for _, p in ipairs(fi.Model:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 0.98 and p.Name ~= "HumanoidRootPart" then
				printPart(p)
			end
		end
	end
	local fx = workspace:FindFirstChild("FX")
	if fx then
		for _, p in ipairs(fx:GetChildren()) do
			if p:IsA("BasePart") and p.Transparency < 0.98 then
				printPart(p)
			end
		end
	end
end
if SNAP_IDS then
	for _, id in ipairs(SNAP_IDS) do
		local speciesId = string.match(id, "^SK_(.+)_%d$") or SNAP_SPECIES[id]
		table.clear(FAKE.List)
		table.clear(queue)
		local fx = workspace:FindFirstChild("FX")
		if fx then
			fx:ClearAllChildren()
		end
		VT = 5000
		CLIENT_ACTIVE = true
		local f = makeFighter(speciesId, Vector3.new(0, 0, 0), "A", "player")
		f.Model:PivotTo(CFrame.lookAt(f.Root.Position, f.Root.Position + Vector3.new(0, 0, -1)))
		local e1 = makeFighter(SNAP_TARGET or "caramelo", Vector3.new(0, 0, -16), "B")
		e1.Model:PivotTo(CFrame.lookAt(e1.Root.Position, e1.Root.Position + Vector3.new(0, 0, 1)))
		local start = VT
		task.spawn(function()
			pcall(Specials[id], f, e1)
		end)
		for _, t in ipairs(SNAP_TIMES) do
			runUntil(start + t)
			snapshot(id .. "@" .. tostring(t), { f, e1 })
		end
		runUntil(start + 8)
		for _, err in ipairs(errors) do
			print("ERRO", id, err)
		end
		table.clear(errors)
		f.Model.Parent = nil
		e1.Model.Parent = nil
	end
	return
end

for _, id in ipairs(ids) do
	local speciesId, slotText = string.match(id, "^SK_(.+)_(%d)$")
	table.clear(FX_LOG)
	table.clear(ACTION_LOG)
	table.clear(BAD_FX)
	local a = scenario(id, speciesId, "A")
	local b = scenario(id, speciesId, "B")
	local c = scenario(id, speciesId, "C")
	local d = scenario(id, speciesId, "D")
	local e = scenario(id, speciesId, "E")
	local errs = {}
	for _, list in ipairs({ a.errors, b.errors, c.errors, d.errors, e.errors }) do
		for _, e in ipairs(list) do
			table.insert(errs, e)
		end
	end
	print(table.concat({
		"SKILL",
		id,
		slotText,
		DogData.Species[speciesId].Rarity,
		a.finished and string.format("%.2f", a.finished) or "NAO_ACABOU",
		string.format("%.2f", a.main),
		string.format("%.2f", a.total),
		string.format("%.2f", b.total),
		tostring(a.frozenLeft or b.frozenLeft or c.frozenLeft),
		keys(FX_LOG),
		keys(ACTION_LOG),
		keys(BAD_FX),
		table.concat(errs, " || "),
		d.finished and string.format("%.2f", d.finished) or "NAO_ACABOU",
		string.format("%.2f", d.grabbed),
		string.format("%.1f", d.travel),
		string.format("%.2f", d.main),
		string.format("%.2f", d.side),
		tostring(d.ungrabbed),
		tostring(d.leftHeld + d.badRelease),
		e.finished and string.format("%.2f", e.finished) or "NAO_ACABOU",
		string.format("%.1f", e.drop),
		string.format("%.2f", e.main),
	}, "\t"))
end
print("FIM", #ids)
