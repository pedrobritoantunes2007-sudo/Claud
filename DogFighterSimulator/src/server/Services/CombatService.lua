-- IA de luta (Arena e Boss Tower). Sem posição fixa: os cachorros andam, perseguem, circulam o
-- adversário, recuam, dão dash, pulam e sofrem knockback.
-- Ilhas (2026-10, pedido do dono): os selvagens são BRAVOS — atacam sozinhos o cachorro de jogador que chega
-- perto (Config.AGGRO_*), vários ao mesmo tempo; sem ninguém perto passeiam e recuperam vida.
-- Golpe de perto: pata direita → pata esquerda → mordida (Fighters.Melee).
-- Boss Tower: todos lutam contra o boss automaticamente (alvo mais próximo).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Fighters = require(script.Parent.Fighters)
local Specials = require(script.Parent.Specials)
local ZoneGeo = require(script.Parent.ZoneGeo)

local CombatService = {}

local TICK = 0.1
local NPC_REGEN = 0.04 -- fração da vida por segundo (NPC passeando, sem duelo)
local DOG_REGEN = Config.ARENA_REGEN -- cachorro do jogador ocioso na Arena
local rng = Random.new()

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- 🏝️ áreas de luta: ilha de raridade, Coliseu (f.Island = "colosseum") ou topo da Boss Tower (ZoneGeo)
local function zoneCenter(f)
	return ZoneGeo.Circle(f)
end

-- ponto sorteado na área, em terra firme (raiz quadrada: não amontoa no centro)
local function randomPointInZone(f, margin)
	local p = ZoneGeo.RandomPoint(f, margin, rng)
	if p then
		return p
	end
	local center, radius = zoneCenter(f)
	local a = rng:NextNumber(0, math.pi * 2)
	local r = math.sqrt(rng:NextNumber()) * math.max(4, radius - margin)
	return center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

local function clampToZone(f, p, margin)
	return ZoneGeo.Clamp(f, p, margin)
end

-- passo de passeio só vale em chão firme (nada de entrar no mar, no lago ou na lava)
local function solid(f, p)
	if f.Zone ~= "arena" or f.Island == "colosseum" or f.HomePos then
		return true
	end
	local g, mat = ZoneGeo.Ground(p, p.Y + 60, 160)
	return g ~= nil and mat ~= Enum.Material.Water and mat ~= Enum.Material.CrackedLava
end

-- distância até o cachorro mais próximo na mesma zona (duelos contam como "mais perto": ninguém
-- passeia no meio de uma briga)
local function crowding(f, p)
	local best = math.huge
	for _, other in pairs(Fighters.List) do
		if other ~= f and other.Zone == f.Zone and not other.Dead then
			local d = Fighters.FlatDistance(other.Root.Position, p)
			if other.Duel then
				d *= 0.5
			end
			if d < best then
				best = d
			end
		end
	end
	return best
end

-- passeio de NPC na Arena grande: passos curtos e para o lugar mais vazio entre alguns sorteios
local function wanderPoint(f)
	local here = f.Root.Position
	local best, bestScore = nil, -math.huge
	for i = 1, 4 do
		local p
		if i == 4 then
			p = randomPointInZone(f, 12)
		else
			local a = rng:NextNumber(0, math.pi * 2)
			p = clampToZone(f, here + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(12, 36), 12)
		end
		local score = math.min(crowding(f, p), 40) - (i == 4 and 6 or 0)
		if i < 4 and not solid(f, p) then
			score = -math.huge
		end
		if score > bestScore then
			best, bestScore = p, score
		end
	end
	return best
end

-- velocidade normal (ou corrida para alcançar o alvo do outro lado da Arena)
local function setRunSpeed(f, sprint)
	local speed = f.Stats.Speed * (f.SpeedMult or 1) * (sprint and 1.35 or 1)
	if math.abs(f.Humanoid.WalkSpeed - speed) > 0.05 then
		f.Humanoid.WalkSpeed = speed
	end
end

-- quantos selvagens estão atacando este cachorro agora
local function attackers(target)
	local n = 0
	for _, other in pairs(Fighters.List) do
		if other.Aggro == target and Fighters.Alive(other) then
			n += 1
		end
	end
	return n
end

-- 😠 selvagem bravo: continua no alvo dele (até AGGRO_LEASH), revida quem o mordeu (duelo) ou procura o
-- cachorro de jogador mais perto dentro do AGGRO_RANGE (no máximo AGGRO_MAX selvagens no mesmo cachorro; menos se
-- ele for iniciante).
-- O cachorro atacado ganha o selvagem como alvo principal (duelo) se ainda não estava brigando: é isso que
-- liga a barra da luta, a música e o passo do tutorial.
local function wildTarget(f, now)
	local cur = f.Aggro
	if cur and Fighters.Hostile(f, cur) and Fighters.FlatDistance(f.Root.Position, cur.Root.Position) < Config.AGGRO_LEASH then
		if not (cur.Duel and Fighters.Alive(cur.Duel)) then
			Fighters.SetDuel(cur, f)
		end
		return cur
	end
	f.Aggro = nil
	local duel = f.Duel
	if duel and Fighters.Hostile(f, duel) then
		f.Aggro = duel
		return duel
	end
	if now < (f.NextScan or 0) then
		return nil
	end
	f.NextScan = now + rng:NextNumber(0.4, 0.7)
	local best, bestDist = nil, f.Champion and Config.AGGRO_CHAMPION_RANGE or Config.AGGRO_RANGE
	for _, other in pairs(Fighters.List) do
		if other.Kind == "player" and Fighters.Hostile(f, other) then
			local d = Fighters.FlatDistance(f.Root.Position, other.Root.Position) - other.Radius
			if d < bestDist and attackers(other) < Config.MaxAttackers(other.Level) then
				best, bestDist = other, d
			end
		end
	end
	if best then
		f.Aggro = best
		-- avisa que viu você: "❗" vermelho em cima e um rosnado
		Fighters.Fx("Damage", { Position = f.Root.Position + Vector3.new(0, f.Root.Size.Y + 3, 0), Amount = "❗", Color = Color3.fromRGB(255, 70, 60) })
		Fighters.SetAction(f, "Roar", 0.45)
		if not (best.Duel and Fighters.Alive(best.Duel)) then
			Fighters.SetDuel(best, f)
		end
	end
	return best
end

local function pickTarget(f, now)
	if f.Zone == "arena" and f.Kind ~= "boss" then
		if f.Kind == "npc" then
			return wildTarget(f, now)
		end
		local duel = f.Duel
		if duel and Fighters.Hostile(f, duel) then
			return duel
		end
		return nil
	end
	local current = f.Target
	if current and Fighters.Hostile(f, current) then
		-- troca só se aparecer alguém bem mais perto
		local dist = Fighters.FlatDistance(f.Root.Position, current.Root.Position)
		if dist < 40 or rng:NextNumber() > 0.05 then
			return current
		end
	end
	local best, bestScore = nil, math.huge
	for _, other in pairs(Fighters.List) do
		if Fighters.Hostile(f, other) then
			local score = Fighters.FlatDistance(f.Root.Position, other.Root.Position)
			-- NPCs preferem quem já está brigando com eles
			if other.Target == f then
				score *= 0.7
			end
			if score < bestScore then
				best, bestScore = other, score
			end
		end
	end
	return best
end

local function specialCooldown(f)
	if f.Kind == "boss" then
		return Specials.BOSS_COOLDOWN
	end
	-- (2026-10) recarga da habilidade 2 pela raridade (Config.SKILL_TIER)
	local tier = Config.SKILL_TIER[f.Species.Rarity]
	return tier and tier.Cooldown[1] or Specials.COOLDOWN[f.Species.Rarity] or 8
end

local function chooseSpecial(f)
	if f.Specials and #f.Specials > 0 then
		return f.Specials[rng:NextInteger(1, #f.Specials)]
	end
	return f.Special
end

-- playerCast = habilidade do jogador mirando (SkillKit): ele continua no controle — não fica "ocupado" (pode morder
-- e soltar outro poder) e no fim não mexe na velocidade nem na pose dele
local function runSpecial(f, target, onDone, forcedName, playerCast, quiet)
	local name = forcedName or chooseSpecial(f)
	local fn = Specials[name]
	if not fn then
		if onDone then
			pcall(onDone)
		end
		return
	end
	if not playerCast then
		f.Busy = true
	end
	f.NextSpecial = os.clock() + specialCooldown(f) * rng:NextNumber(0.85, 1.2)
	if not quiet then -- (os clones do palhaço não repetem o nome do poder na tela)
		Fighters.Fx("SpecialName", { Model = f.Model, Name = name })
	end
	task.spawn(function()
		local ok, err = pcall(fn, f, target)
		if not ok then
			warn("[Specials] erro em", name, err)
		end
		if not playerCast then
			f.Busy = false
			if Fighters.Alive(f) and not f.Model:GetAttribute("Raging") then
				f.Humanoid.WalkSpeed = f.Stats.Speed * (f.SpeedMult or 1)
			end
			local action = f.Model.Parent and f.Model:GetAttribute("Action")
			if action and action ~= "KO" then
				f.Model:SetAttribute("Action", nil)
			end
		end
		if onDone then
			pcall(onDone)
		end
	end)
	return true
end
-- usados pelo cachorro controlado pelo jogador (DogService, habilidades 1 e 2)
CombatService.RunSpecial = runSpecial
CombatService.SpecialCooldown = function(f)
	return specialCooldown(f)
end

-- golpe de perto já com a animação tocada: step 1/2 = patada, 3 = mordida (empurra mais). mult = força do golpe
local function melee(f, target, step, mult)
	local d = flat(target.Root.Position - f.Root.Position)
	d = d.Magnitude > 0.01 and d.Unit or flat(f.Root.CFrame.LookVector)
	local isBite = step == 3
	Fighters.Damage(f, target, f.Stats.Atk * (mult or 1), { Knockback = d * (isBite and 24 or 14) + Vector3.new(0, isBite and 10 or 6, 0) })
	-- Titan Rage: cada golpe causa impacto no chão
	if f.Raging and os.clock() < f.Raging then
		local p = f.Root.Position - Vector3.new(0, f.Humanoid.HipHeight + f.Root.Size.Y / 2, 0)
		Fighters.Fx("Shockwave", { Position = p, Radius = 12, Color = Color3.fromRGB(255, 210, 120) })
		Fighters.Fx("Shake", { Position = p, Intensity = 0.4, Radius = 40, Duration = 0.25 })
		Fighters.DamageArea(f, p, 10, f.Stats.Atk * 0.5, { KnockbackPower = 30, Lift = 18, NoText = true })
	end
end
-- IA: pata direita → pata esquerda → mordida; as patas um pouco mais fracas e a mordida mais forte (média igual)
local AI_STEP = { 0.85, 0.95, 1.2 }
local function bite(f, target)
	f.NextAttack = os.clock() + Config.BITE_COOLDOWN * rng:NextNumber(0.8, 1.2) * (f.Kind == "boss" and 0.9 or 1)
	local step = Fighters.Melee(f)
	melee(f, target, step, AI_STEP[step])
end

CombatService.Bite = function(f, target)
	bite(f, target)
end
-- cachorro do jogador (DogService): o combo dele escolhe o step e a força
CombatService.Melee = melee

-- 🎯 Tiro pela boca (cachorros atiradores, DogData.RANGED): o tiro voa até o alvo e só dá dano quando
-- chega (se o alvo ainda for inimigo). target = nil → tiro no vazio, só o visual (jogador errou).
-- mult = força do combo; big = tiro grande do finalizador (empurra longe).
local function shoot(f, target, mult, big, missAt)
	local styleName, style = DogData.ShotFor(f.SpeciesId)
	if not style then
		return
	end
	-- jogador: recarga fixa (mais rápida); selvagens e bosses: a de antes, com sorteio
	if f.Kind == "player" then
		f.NextAttack = os.clock() + Config.SHOT_COOLDOWN
	else
		f.NextAttack = os.clock() + Config.SHOT_AI_COOLDOWN * rng:NextNumber(0.85, 1.15)
	end
	local look = flat(f.Root.CFrame.LookVector)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local mouth = f.Root.Position + look * f.Radius + Vector3.new(0, f.Root.Size.Y * 0.5, 0)
	local to = target and target.Root.Position or missAt or (mouth + look * Config.SHOT_RANGE)
	local travel = style.Speed and math.clamp((to - mouth).Magnitude / style.Speed, 0.05, Config.SHOT_MAX_TIME) or 0.06
	local head = math.random(1, f.Model:GetAttribute("Heads") or 1)
	Fighters.Fx("MouthShot", {
		Model = f.Model,
		Head = head,
		Target = target and target.Model or nil,
		To = to,
		Style = styleName,
		Big = big == true,
		Time = travel,
	})
	if not target then
		return
	end
	task.delay(travel, function()
		if not (Fighters.Alive(f) and Fighters.Alive(target)) then
			return
		end
		local d = flat(target.Root.Position - f.Root.Position)
		d = d.Magnitude > 0.01 and d.Unit or look
		local push = big and (d * 50 + Vector3.new(0, 22, 0)) or (d * 10 + Vector3.new(0, 4, 0))
		Fighters.Damage(f, target, f.Stats.Atk * Config.SHOT_DAMAGE * (mult or 1), { Knockback = push, Color = style.Color })
	end)
end
CombatService.Shoot = shoot

local function think(f, now)
	local hum = f.Humanoid
	if Fighters.IsFrozen(f) then
		hum:MoveTo(f.Root.Position)
		return
	end
	local target = pickTarget(f, now)
	f.Target = target

	-- mantém dentro da área (ilha, Coliseu, palco do campeão ou topo da torre)
	if not ZoneGeo.Inside(f, f.Root.Position, -2) then
		hum:MoveTo(ZoneGeo.Clamp(f, f.Root.Position, 20))
		return
	end

	if not target then
		if f.Zone == "arena" and not f.Duel and hum.Health < hum.MaxHealth then
			local rate = f.Kind == "npc" and NPC_REGEN or DOG_REGEN
			hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * rate * TICK)
		end
		if f.Kind == "player" and f.Zone == "arena" then
			-- ocioso: espera o jogador clicar no próximo adversário
			if not f.Idle then
				f.Idle = true
				Fighters.Stop(f)
			end
			if now > (f.NextWander or 0) then
				f.NextWander = now + rng:NextNumber(4, 8)
				if rng:NextNumber() < 0.5 then
					Fighters.SetAction(f, "Sit", 3)
				end
			end
			return
		end
		if now > (f.NextWander or 0) then
			setRunSpeed(f, false)
			if f.Zone == "arena" and rng:NextNumber() < 0.3 then
				-- para um pouco (cheira o chão / senta) em vez de andar sem parar
				f.NextWander = now + rng:NextNumber(3, 6)
				Fighters.Stop(f)
				Fighters.SetAction(f, "Sit", 2.5)
			else
				f.NextWander = now + rng:NextNumber(3, 6)
				hum:MoveTo(f.Zone == "arena" and wanderPoint(f) or randomPointInZone(f, 10))
			end
		end
		return
	end
	f.Idle = false
	if f.Model:GetAttribute("Action") == "Sit" then
		f.Model:SetAttribute("Action", nil) -- estava sentado esperando: levanta para lutar
	end

	local tp = target.Root.Position
	local dist = Fighters.FlatDistance(f.Root.Position, tp) - f.Radius - target.Radius
	local hpPct = hum.Health / hum.MaxHealth

	-- recuar quando está fraco (de vez em quando)
	if f.RetreatUntil and now < f.RetreatUntil then
		local away = flat(f.Root.Position - tp)
		away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
		local p = f.Root.Position + away * 14
		if not ZoneGeo.Inside(f, p, -6) then
			p = f.Root.Position + Vector3.new(-away.Z, 0, away.X) * 14
		end
		hum:MoveTo(p)
		return
	end
	if f.Kind ~= "boss" and hpPct < 0.3 and rng:NextNumber() < 0.025 then
		f.RetreatUntil = now + rng:NextNumber(1, 1.8)
		return
	end

	-- poder especial
	if now >= f.NextSpecial and dist < 30 then
		runSpecial(f, target)
		return
	end

	-- 🎯 atirador: fica a meia distância andando de lado e atira pela boca (boss sempre morde)
	if f.Kind ~= "boss" and DogData.ShotFor(f.SpeciesId) then
		if dist <= Config.SHOT_AI_RANGE and now >= f.NextAttack then
			Fighters.Face(f, tp)
			shoot(f, target, 1, false)
		end
		local want = target.Radius + f.Radius + 14
		local rel = flat(f.Root.Position - tp)
		rel = rel.Magnitude > 0.1 and rel.Unit or Vector3.new(1, 0, 0)
		f.Orbit = f.Orbit or (rng:NextNumber() < 0.5 and -1 or 1)
		if rng:NextNumber() < 0.03 then
			f.Orbit = -f.Orbit
		end
		local goal
		if dist > Config.SHOT_AI_RANGE - 2 then
			setRunSpeed(f, dist > 30)
			goal = tp
		else
			setRunSpeed(f, false)
			-- perto demais: recua; senão circula o alvo na distância boa
			local angle = (dist < 9 and 0.2 or 0.6) * f.Orbit
			local rotated = Vector3.new(rel.X * math.cos(angle) - rel.Z * math.sin(angle), 0, rel.X * math.sin(angle) + rel.Z * math.cos(angle))
			goal = tp + rotated * want
		end
		hum:MoveTo(clampToZone(f, goal, 4))
		return
	end

	local reach = 2.5
	if dist <= reach + 4 then
		setRunSpeed(f, false)
	end
	if dist <= reach then
		if now >= f.NextAttack then
			Fighters.Face(f, tp)
			bite(f, target)
		end
		-- circula o adversário entre as mordidas
		f.Orbit = f.Orbit or (rng:NextNumber() < 0.5 and -1 or 1)
		if rng:NextNumber() < 0.04 then
			f.Orbit = -f.Orbit
		end
		local rel = flat(f.Root.Position - tp)
		rel = rel.Magnitude > 0.1 and rel.Unit or Vector3.new(1, 0, 0)
		local angle = 0.7 * f.Orbit
		local rotated = Vector3.new(rel.X * math.cos(angle) - rel.Z * math.sin(angle), 0, rel.X * math.sin(angle) + rel.Z * math.cos(angle))
		hum:MoveTo(tp + rotated * (target.Radius + f.Radius + 1.5))
	else
		-- longe (Arena grande): corre mais rápido até chegar perto
		setRunSpeed(f, dist > 18 and f.Kind ~= "boss")
		-- mira um pouco à frente de quem está fugindo
		local lead = target.Root.AssemblyLinearVelocity
		lead = Vector3.new(lead.X, 0, lead.Z) * math.clamp(dist / 40, 0, 0.6)
		hum:MoveTo(dist > 6 and clampToZone(f, tp + lead, 4) or tp)
		-- dash para fechar distância
		if dist > 10 and dist < 28 and rng:NextNumber() < 0.03 and now > (f.NextDash or 0) then
			f.NextDash = now + 3
			local d = flat(tp - f.Root.Position).Unit
			Fighters.SetAction(f, "Dash", 0.25)
			Fighters.Push(f, d * 70 + Vector3.new(0, 6, 0), 0.22)
		end
		-- pulinho
		if rng:NextNumber() < 0.012 then
			hum.Jump = true
		end
	end
end

-- Cachorro arremessado para fora da Arena / do topo da Boss Tower (knockback, poderes) volta para dentro.
-- Modelo destruído pelo motor (caiu no vazio) vira nocaute para renascer.
local function rescue(f)
	if f.Removed or f.Dead then
		return
	end
	if not f.Model.Parent or not f.Root.Parent then
		Fighters.Vanished(f)
		return
	end
	local pos = f.Root.Position
	if f.Zone == "boss" or f.Zone == "tower" then
		local off = pos - Layout.BOSS_CENTER
		if Vector3.new(off.X, 0, off.Z).Magnitude > Layout.BOSS_RADIUS + 6 or off.Y < -20 then
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0, Layout.BOSS_RADIUS - 14)
			Fighters.Teleport(f, Layout.BOSS_CENTER + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		end
	elseif f.Zone == "arena" then
		-- (o jogador anda livre: só os selvagens e os bosses voltam quando são jogados para fora)
		if f.Kind ~= "player" and f.Kind ~= "clone" and (not ZoneGeo.Inside(f, pos, 12) or pos.Y < zoneCenter(f).Y - 15) then
			-- volta perto de onde saiu (não do outro lado da ilha, longe do duelo)
			local back = ZoneGeo.Clamp(f, pos, 14)
			local g = ZoneGeo.Ground(back, zoneCenter(f).Y + 200, 400)
			Fighters.Teleport(f, g or randomPointInZone(f, 14))
		end
	elseif pos.Y < Layout.GROUND_Y - 40 then
		-- caiu da ilha fora da Arena/torre (em casa, no caminho): conta como nocaute para o dono
		-- (DogService) renascer o cachorro no terreno
		Fighters.Vanished(f)
	end
end

function CombatService.Start()
	task.spawn(function()
		local lastRescue = 0
		while true do
			local now = os.clock()
			if now - lastRescue > 0.5 then
				lastRescue = now
				for _, f in pairs(table.clone(Fighters.List)) do
					local ok, err = pcall(rescue, f)
					if not ok then
						warn("[Combat] rescue", err)
					end
				end
			end
			for _, f in pairs(Fighters.List) do
				if (f.Zone == "arena" or f.Zone == "boss") and not f.Busy and not f.Controlled and f.Kind ~= "clone" and Fighters.Alive(f) then
					local ok, err = pcall(think, f, now)
					if not ok then
						warn("[Combat]", err)
					end
				end
			end
			task.wait(TICK)
		end
	end)
end

return CombatService
