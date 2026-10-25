-- 🐾 Cachorros selvagens (2026-10, mapa novo): cada ilha de raridade tem os seus — Islands.List[id].Wild
-- cachorros da raridade da ilha, nos levels da ilha — e o 👑 Campeão gigante perto do palco dele.
-- Só existem enquanto tem jogador na ilha: ilha vazia por EMPTY_GRACE s → os selvagens somem (servidor leve).
-- Reino das Nuvens: só cachorros que voam (flutuam acima das nuvens). Sunfire Sanctum: Sun Guardians dourados.
-- São BRAVOS (2026-10, pedido do dono): atacam sozinhos o cachorro de jogador que chega perto (CombatService,
-- Config.AGGRO_*), vários ao mesmo tempo. Sem ninguém perto eles passeiam e recuperam vida.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DogData = require(ReplicatedStorage.Shared.DogData)
local Islands = require(ReplicatedStorage.Shared.Islands)
local Fighters = require(script.Parent.Fighters)
local ZoneGeo = require(script.Parent.ZoneGeo)

local NPCService = {}

local RESPAWN = 5
local CHAMPION_RESPAWN = 45
local EMPTY_GRACE = 45 -- s sem ninguém na ilha até os selvagens sumirem
-- Selvagens são um pouco mais fracos que um cachorro treinado do mesmo level: o starter Lv.1
-- vence o Street Dog com folga e cada ilha exige ~1 upgrade de raridade/level.
local DEFAULT_MULT = 0.75
local GOLD = Color3.fromRGB(255, 200, 70)
local FLY_RARITIES = { "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

local rng = Random.new()
local active = {} -- [id] = { List = { [fighter] = true }, EmptySince = os.clock()?, Champion = fighter? }

local function pool(def)
	if def.Flyers then
		local list = {}
		for _, r in ipairs(FLY_RARITIES) do
			for _, id in ipairs(DogData.SpeciesWithElement(r, "Fly")) do
				table.insert(list, id)
			end
		end
		return list
	end
	local rarity = def.Golden and "Mythic" or def.Rarity
	local list = {}
	for _, id in ipairs(DogData.SpeciesOfRarity(rarity)) do
		if not DogData.Species[id].BossOnly then
			table.insert(list, id)
		end
	end
	return list
end

local function islandHasPlayers(id)
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Island") == id then
			return true
		end
	end
	return false
end

-- ponto em terra firme, o mais longe possível dos outros cachorros (não nasce no meio de um duelo)
local function spawnPoint(id)
	local best, bestGap = nil, -1
	for _ = 1, 6 do
		local p = ZoneGeo.RandomIslandPoint(id, 30, rng)
		if p then
			local gap = math.huge
			for _, other in pairs(Fighters.List) do
				if other.Island == id and other.Root.Parent then
					gap = math.min(gap, Fighters.FlatDistance(other.Root.Position, p) * (other.Duel and 0.5 or 1))
				end
			end
			if gap > bestGap then
				best, bestGap = p, gap
			end
			if gap > 30 then
				break
			end
		end
	end
	return best
end

-- deixa o cachorro dourado (Sun Guardian) / flutuando (nuvens)
local function dress(f, def)
	if def.Golden then
		for _, d in ipairs(f.Model:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 1 and d.Material ~= Enum.Material.Neon then
				d.Color = d.Color:Lerp(GOLD, 0.55)
			end
		end
	end
	if def.Flyers then
		f.Humanoid.HipHeight += 5
		f.HipHeight = f.Humanoid.HipHeight
		f.Model:SetAttribute("Float", true)
	end
end

local function spawnWild(id)
	local state = active[id]
	local def = Islands.List[id]
	if not state or not def then
		return
	end
	local list = pool(def)
	if #list == 0 then
		return
	end
	local pos = spawnPoint(id)
	if not pos then
		return
	end
	local speciesId = list[rng:NextInteger(1, #list)]
	local name = DogData.Species[speciesId].Name
	local f = Fighters.Spawn({
		SpeciesId = speciesId,
		Level = rng:NextInteger(def.Levels[1], def.Levels[2]),
		Kind = "npc",
		DisplayName = (def.Golden and "☀️ Sun Guardian " or "Wild ") .. name,
		CFrame = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
		Zone = "arena",
		Island = id,
		StatMult = def.Golden and { HP = 1.1, Atk = 1 } or { HP = DEFAULT_MULT, Atk = DEFAULT_MULT },
	})
	f.Def = { Island = id }
	dress(f, def)
	state.List[f] = true
end

local function spawnChampion(id)
	local state = active[id]
	local def = Islands.List[id]
	local c = def and def.Champion
	if not (state and c) or (state.Champion and Fighters.Alive(state.Champion)) then
		return
	end
	local speciesId = c.Species
	if not DogData.Species[speciesId] then
		local list = pool(def)
		speciesId = list[rng:NextInteger(1, #list)]
	end
	local at = def.ChampionAt
	local world = def.CF:PointToWorldSpace(Vector3.new(at.X, def.ChampionY or at.Y, at.Z))
	local ground = ZoneGeo.Ground(world, world.Y + 60, 200) or world
	local f = Fighters.Spawn({
		SpeciesId = speciesId,
		Level = c.Level,
		Kind = "npc",
		DisplayName = "👑 " .. c.Name,
		CFrame = CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
		Zone = "arena",
		Island = id,
		Scale = c.Scale * 0.6,
		StatMult = { HP = 4, Atk = 1.15 },
		HomePos = ground,
		HomeRadius = def.ChampionY and 12 or (def.Floating and 40 or 26),
	})
	f.Def = { Island = id, Champion = true }
	f.Champion = true
	dress(f, def)
	state.Champion = f
	state.List[f] = true
end

local function activate(id)
	if active[id] then
		active[id].EmptySince = nil
		return
	end
	active[id] = { List = {}, EmptySince = nil }
	local def = Islands.List[id]
	task.spawn(function()
		for _ = 1, def.Wild or 8 do
			if not active[id] then
				return
			end
			local ok, err = pcall(spawnWild, id)
			if not ok then
				warn("[NPCService] selvagem falhou em", id, err)
			end
			task.wait(0.15)
		end
		local ok, err = pcall(spawnChampion, id)
		if not ok then
			warn("[NPCService] campeão falhou em", id, err)
		end
	end)
end

local function deactivate(id)
	local state = active[id]
	if not state then
		return
	end
	active[id] = nil
	for f in pairs(state.List) do
		if not f.Removed then
			pcall(Fighters.Remove, f)
		end
	end
end

function NPCService.Start()
	-- liga/desliga as ilhas conforme os jogadores chegam e saem
	task.spawn(function()
		while true do
			task.wait(2)
			local now = os.clock()
			for id in pairs(Islands.List) do
				if islandHasPlayers(id) then
					activate(id)
				elseif active[id] then
					local state = active[id]
					state.EmptySince = state.EmptySince or now
					if now - state.EmptySince > EMPTY_GRACE then
						deactivate(id)
					end
				end
			end
		end
	end)
	Fighters.Killed.Event:Connect(function(victim)
		if victim.Kind ~= "npc" or not victim.Def then
			return
		end
		local id = victim.Def.Island
		local state = id and active[id]
		if state then
			state.List[victim] = nil
		end
		-- o derrotado some logo (não fica deitado no chão)
		task.delay(1.2, function()
			Fighters.Remove(victim)
		end)
		local champion = victim.Def.Champion
		task.delay(champion and CHAMPION_RESPAWN or RESPAWN, function()
			if not (id and active[id]) then
				return
			end
			local ok, err = pcall(champion and spawnChampion or spawnWild, id)
			if not ok then
				warn("[NPCService] falha ao renascer em", id, err)
			end
		end)
	end)
end

-- 🦮 selvagem CAPTURADO (Services/CatchService): sai sem "morrer" (nada de prêmio de abate) e outro nasce depois
function NPCService.Captured(victim)
	if not victim or victim.Removed then
		return
	end
	local id = victim.Def and victim.Def.Island
	local state = id and active[id]
	if state then
		state.List[victim] = nil
		if state.Champion == victim then
			state.Champion = nil
		end
	end
	pcall(Fighters.Remove, victim)
	local champion = victim.Def and victim.Def.Champion
	task.delay(champion and CHAMPION_RESPAWN or RESPAWN, function()
		if not (id and active[id]) then
			return
		end
		local ok, err = pcall(champion and spawnChampion or spawnWild, id)
		if not ok then
			warn("[NPCService] falha ao renascer em", id, err)
		end
	end)
end

-- quantos selvagens vivos tem numa ilha (o menu MAP mostra)
function NPCService.Count(id)
	local state = active[id]
	local n = 0
	if state then
		for f in pairs(state.List) do
			if Fighters.Alive(f) then
				n += 1
			end
		end
	end
	return n
end

return NPCService
