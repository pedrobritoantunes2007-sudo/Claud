-- Poderes especiais. Cada um é uma SEQUÊNCIA própria de ações (pose → movimento → efeito → dano),
-- nunca "a mesma mordida com outra partícula". Usados por cachorros de jogadores, NPCs e bosses.
-- Assinatura: Specials[nome](fighter, alvo). Roda dentro de uma thread; o CombatService marca Busy.
--
-- Ritmo visual de todos: AVISO (pose + carga/círculo no chão) → IMPACTO (efeito forte + dano + tremor)
-- → RESÍDUO (marca/fogo/gelo que fica um pouco). Os efeitos estão em client/Effects.lua (H.<Nome>).
--
-- Arena = duelo 1x1: os poderes são pensados para acertar o oponente do duelo (aproximam, perseguem,
-- miram nele). Na Boss Tower todos lutam contra o boss, e as áreas acertam quem estiver dentro.
--
-- Segurança: toda espera confere se o cachorro continua vivo e em combate (live); se ele morrer,
-- for removido ou levado para casa no meio do poder, a sequência para. Velocidade de andar e escala
-- (Titan) são sempre restauradas.

local Fighters = require(script.Parent.Fighters)
local ZoneGeo = require(script.Parent.ZoneGeo)

local Specials = {}

local A = Fighters.Alive
local C = Color3.fromRGB
local Fx = Fighters.Fx

---------------------------------------------------------------- utilidades
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- vivo e ainda lutando (não foi levado para casa/viagem)
local function live(f)
	return A(f) and not f.Controlled
end

-- alvo ainda é um inimigo válido
local function valid(f, t)
	return live(f) and t ~= nil and A(t) and Fighters.Hostile(f, t)
end

local function dirTo(f, position)
	local d = flat(position - f.Root.Position)
	if d.Magnitude < 0.01 then
		return flat(f.Root.CFrame.LookVector).Unit
	end
	return d.Unit
end

-- Ponto do chão embaixo de uma posição (ignora os cachorros)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function ground(position)
	local dogs = workspace:FindFirstChild("Cachorros")
	rayParams.FilterDescendantsInstances = dogs and { dogs } or {}
	local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -80, 0), rayParams)
	return hit and hit.Position or Vector3.new(position.X, position.Y - 3, position.Z)
end

local function feet(f)
	return f.Root.Position - Vector3.new(0, f.Root.Size.Y / 2 + f.Humanoid.HipHeight, 0)
end

-- mantém um ponto dentro da área de luta (ilha, Coliseu ou topo da Boss Tower): dash, teleporte
local function inZone(f, position)
	return ZoneGeo.Clamp(f, position, 5)
end

-- espera e confirma que o cachorro continua vivo e lutando
local function hold(f, seconds)
	task.wait(seconds)
	return live(f)
end

local function atk(f)
	return f.Stats.Atk
end

local function setSpeed(f, mult)
	if live(f) and not Fighters.IsFrozen(f) then
		f.Humanoid.WalkSpeed = f.Stats.Speed * (f.SpeedMult or 1) * mult
	end
end

-- corre até ficar a `within` studs do alvo (ou desiste depois de maxTime)
local function approach(f, t, within, maxTime)
	local start = os.clock()
	setSpeed(f, 1.7)
	while valid(f, t) and os.clock() - start < maxTime do
		if Fighters.FlatDistance(f.Root.Position, t.Root.Position) - f.Radius - t.Radius <= within then
			break
		end
		f.Humanoid:MoveTo(t.Root.Position)
		task.wait(0.1)
	end
	setSpeed(f, 1)
	Fighters.Stop(f)
	return valid(f, t)
end

-- Inimigos dentro de um retângulo (linha) que sai de origin na direção dir
local function enemiesInLine(f, origin, dir, length, width)
	local list = {}
	for _, enemy in ipairs(Fighters.Enemies(f)) do
		local rel = flat(enemy.Root.Position - origin)
		local along = rel:Dot(dir)
		local side = (rel - dir * along).Magnitude
		if along > -2 and along < length + enemy.Radius and side < width / 2 + enemy.Radius then
			table.insert(list, enemy)
		end
	end
	return list
end

local function enemiesInCone(f, origin, dir, length, angleDeg)
	local list = {}
	local cosA = math.cos(math.rad(angleDeg))
	for _, enemy in ipairs(Fighters.Enemies(f)) do
		local rel = flat(enemy.Root.Position - origin)
		if rel.Magnitude < length + enemy.Radius and (rel.Magnitude < 2 + enemy.Radius or rel.Unit:Dot(dir) > cosA) then
			table.insert(list, enemy)
		end
	end
	return list
end

-- dash por teleporte em passos rápidos (atravessa o alvo sem colidir)
local function blink(f, from, to, steps, stepTime)
	local d = flat(to - from)
	for k = 1, steps do
		if not live(f) then
			return false
		end
		Fighters.Teleport(f, ground(from:Lerp(to, k / steps)))
		if d.Magnitude > 0.1 then
			Fighters.Face(f, f.Root.Position + d)
		end
		task.wait(stepTime)
	end
	return live(f)
end

---------------------------------------------------------------- COMUNS
-- Bote: agacha (círculo de aviso onde vai cair), salta em arco e esmaga
function Specials.Pounce(f, t)
	Fighters.Stop(f)
	Fighters.Face(f, t.Root.Position)
	Fighters.SetAction(f, "Crouch", 0.5)
	Fx("Telegraph", { Position = ground(t.Root.Position), Radius = 7, Duration = 0.85, Color = C(255, 225, 160) })
	if not hold(f, 0.45) or not valid(f, t) then
		return
	end
	local d = dirTo(f, t.Root.Position)
	local dist = Fighters.FlatDistance(f.Root.Position, t.Root.Position)
	Fighters.SetAction(f, "Fly", 0.55)
	Fx("Streak", { Model = f.Model, Color = C(255, 235, 200), Duration = 0.45, Width = 1.2 })
	Fighters.Push(f, d * math.clamp(dist * 2.6, 20, 70) + Vector3.new(0, 32, 0), 0.32)
	if not hold(f, 0.5) then
		return
	end
	Fx("Impact", { Position = feet(f), Radius = 7, Color = C(255, 235, 200) })
	Fighters.DamageArea(f, f.Root.Position, 7.5, atk(f) * 1.7, { KnockbackPower = 35 })
end

-- Investida: ruge e cava o chão, dispara de cabeça baixa e para no primeiro impacto
function Specials.Charge(f, t)
	Fighters.Stop(f)
	Fighters.Face(f, t.Root.Position)
	Fighters.SetAction(f, "Roar", 0.6)
	Fx("Roar", { Model = f.Model, Color = C(255, 240, 220) })
	for _ = 1, 2 do
		if not hold(f, 0.25) then
			return
		end
		Fx("Smoke", { Position = feet(f) - f.Root.CFrame.LookVector * f.Radius, Color = C(190, 170, 140), Size = 3 })
	end
	if not valid(f, t) then
		return
	end
	local d = dirTo(f, t.Root.Position)
	local dist = Fighters.FlatDistance(f.Root.Position, t.Root.Position) + 6
	local speed = 80
	local duration = dist / speed
	Fighters.SetAction(f, "Charge", duration + 0.1)
	Fighters.Push(f, d * speed, duration)
	Fx("Streak", { Model = f.Model, Color = C(230, 210, 180), Duration = duration, Width = 1.6 })
	local start = os.clock()
	while os.clock() - start < duration do
		if not live(f) then
			return
		end
		if valid(f, t) and Fighters.FlatDistance(f.Root.Position, t.Root.Position) < f.Radius + t.Radius + 2 then
			Fighters.Push(f, d * 5, 0.05)
			Fx("Impact", { Position = ground(t.Root.Position), Radius = 7, Color = C(255, 235, 200), Heavy = true })
			Fighters.Damage(f, t, atk(f) * 2, { Knockback = d * 65 + Vector3.new(0, 24, 0) })
			return
		end
		task.wait(0.03)
	end
	-- errou: derrapa levantando poeira
	Fx("Smoke", { Position = feet(f), Color = C(190, 170, 140), Size = 4 })
end

-- Zoomies: corre em volta alucinado deixando rastro e mordendo de lados diferentes
function Specials.Zoomies(f, t)
	if not approach(f, t, 8, 1.5) then
		return
	end
	local hum = f.Humanoid
	setSpeed(f, 2.5)
	Fighters.SetAction(f, "Zoom", 2.2)
	Fx("Streak", { Model = f.Model, Color = C(255, 255, 255), Duration = 2.1, Width = 0.9, Lifetime = 0.5 })
	for i = 1, 8 do
		if not valid(f, t) then
			break
		end
		local a = i * (math.pi * 2 / 5)
		local p = t.Root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * (t.Radius + f.Radius + 3)
		hum:MoveTo(p)
		if i % 2 == 1 then
			Fx("Smoke", { Position = feet(f), Color = C(200, 185, 160), Size = 2 })
		end
		task.wait(0.25)
		if i % 2 == 0 and valid(f, t) then
			Fighters.Face(f, t.Root.Position)
			Fighters.Bite(f)
			Fx("BiteMark", { Position = t.Root.Position, Direction = t.Root.Position - f.Root.Position, Color = C(255, 240, 200) })
			Fighters.Damage(f, t, atk(f) * 0.6, { Knockback = dirTo(f, t.Root.Position) * 12 })
		end
	end
	setSpeed(f, 1)
end

---------------------------------------------------------------- INCOMUNS / RAROS
-- Osso bumerangue: três ossos em curva (esquerda, direita, meio) que voltam acertando de novo
function Specials.BoneToss(f, t)
	Fighters.Stop(f)
	Fighters.Face(f, t.Root.Position)
	Fighters.SetAction(f, "Open", 0.75)
	for i = 1, 3 do
		if not valid(f, t) then
			return
		end
		Fighters.Face(f, t.Root.Position)
		local curve = (i == 1 and -5) or (i == 2 and 5) or 0
		local mouth = f.Root.Position + f.Root.CFrame.LookVector * f.Radius + Vector3.new(0, f.Root.Size.Y * 0.4, 0)
		Fx("Projectile", { From = mouth, To = t.Root.Position, Duration = 0.35, Return = true, Kind = "bone", Curve = curve })
		task.delay(0.35, function()
			if valid(f, t) then
				Fighters.Damage(f, t, atk(f) * 0.55, { Knockback = dirTo(f, t.Root.Position) * 10 })
			end
		end)
		task.delay(0.7, function()
			if valid(f, t) then
				Fighters.Damage(f, t, atk(f) * 0.35, { Knockback = -dirTo(f, t.Root.Position) * 8 })
			end
		end)
		task.wait(0.2)
	end
	hold(f, 0.6)
end

-- Uivo gelado: chega perto, uiva para o céu e o chão congela em volta
function Specials.FreezeHowl(f, t)
	if not approach(f, t, 6, 1.4) then
		return
	end
	Fighters.SetAction(f, "Howl", 1.1)
	Fx("Roar", { Model = f.Model, Color = C(170, 220, 255), Howl = true })
	Fx("Telegraph", { Position = feet(f), Radius = 13, Duration = 0.7, Color = C(170, 220, 255) })
	if not hold(f, 0.7) then
		return
	end
	Fx("IceField", { Position = feet(f), Radius = 13, Duration = 2.5, Grow = 0.4 })
	for _, enemy in ipairs(Fighters.DamageArea(f, f.Root.Position, 13, atk(f) * 1.2, { Color = C(170, 220, 255) })) do
		Fighters.Freeze(enemy, 1.8)
	end
	hold(f, 0.4)
end

-- Thunder Hunt: para, abaixa, eletricidade nas patas, encara o inimigo; dash muito rápido
-- ATRAVESSANDO o alvo; um raio cai em cima dele e o joga longe
function Specials.ThunderHunt(f, t)
	local blue = C(140, 225, 255)
	Fighters.Stop(f)
	Fighters.SetAction(f, "Crouch", 1.3)
	Fx("ThunderCharge", { Model = f.Model, Color = blue, Duration = 1.2 })
	for _ = 1, 4 do
		if not valid(f, t) then
			return
		end
		Fighters.Face(f, t.Root.Position)
		task.wait(0.28)
	end
	if not valid(f, t) then
		return
	end
	local d = dirTo(f, t.Root.Position)
	local from = f.Root.Position
	local dest = inZone(f, t.Root.Position + d * (t.Radius + f.Radius + 9))
	local strikeAt = ground(t.Root.Position)
	Fx("Telegraph", { Position = strikeAt, Radius = 5, Duration = 0.3, Color = blue })
	Fighters.SetAction(f, "Dash", 0.4)
	Fx("ThunderDash", { From = ground(from), To = ground(dest), Color = blue })
	if not blink(f, from, dest, 3, 0.03) then
		return
	end
	-- o corte do dash
	if valid(f, t) then
		Fighters.Damage(f, t, atk(f) * 0.8, { Color = blue })
	end
	Fighters.Push(f, d * 25, 0.12)
	if not hold(f, 0.2) then
		return
	end
	-- o raio cai
	if valid(f, t) then
		Fighters.Face(f, t.Root.Position)
		Fx("Lightning", { Position = ground(t.Root.Position), Color = C(170, 235, 255) })
		Fighters.Damage(f, t, atk(f) * 2.1, { Knockback = d * 60 + Vector3.new(0, 30, 0), Color = blue })
		for _, other in ipairs(Fighters.Enemies(f, t.Root.Position, 7)) do
			if other ~= t then
				Fighters.Damage(f, other, atk(f) * 0.8, { Color = blue })
			end
		end
	end
	hold(f, 0.3)
end

-- Ground Slam: chega perto, fica de pé (aviso do alcance no chão) e bate as patas: onda de rochas
function Specials.GroundSlam(f, t)
	if not approach(f, t, 8, 1.4) then
		return
	end
	Fighters.Face(f, t.Root.Position)
	Fighters.SetAction(f, "Rear", 0.75)
	Fx("Telegraph", { Position = feet(f), Radius = 18, Duration = 0.8, Color = C(230, 190, 130) })
	if not hold(f, 0.7) then
		return
	end
	Fighters.SetAction(f, "Slam", 0.45)
	if not hold(f, 0.12) then
		return
	end
	local p = feet(f)
	Fx("GroundSlam", { Position = p, Radius = 20 })
	Fighters.DamageArea(f, f.Root.Position, 18, atk(f) * 2, { KnockbackPower = 70, Lift = 32 })
	-- tremor secundário (só visual)
	task.wait(0.35)
	if live(f) then
		Fx("Shockwave", { Position = p, Radius = 12, Color = C(200, 170, 130) })
	end
end

-- Olhos laser: mira tremendo (olhos acendem), feixe varre o chão através do alvo deixando queimado
function Specials.LaserEyes(f, t)
	Fighters.Stop(f)
	Fighters.Face(f, t.Root.Position)
	Fighters.SetAction(f, "Aim", 2)
	Fx("EyeGlow", { Model = f.Model, Color = C(255, 60, 60), Duration = 0.55 })
	if not hold(f, 0.55) or not valid(f, t) then
		return
	end
	local d = dirTo(f, t.Root.Position)
	local right = Vector3.new(-d.Z, 0, d.X)
	local base = ground(t.Root.Position)
	local points = {}
	for i = -2, 2 do
		table.insert(points, base + right * i * 3 + d * (i % 2) * 1.5)
	end
	local duration = 1.2
	Fx("Laser", { Model = f.Model, Points = points, Duration = duration, Color = C(255, 50, 50), Width = 0.9 })
	local ticks = 5
	for i = 1, ticks do
		task.wait(duration / ticks)
		if not live(f) then
			return
		end
		local k = (i - 0.5) / ticks
		local seg = k * (#points - 1)
		local a = math.clamp(math.floor(seg) + 1, 1, #points)
		local b = math.min(a + 1, #points)
		local aim = points[a]:Lerp(points[b], seg - (a - 1))
		local origin = flat(f.Root.Position)
		local dir = flat(aim) - origin
		if dir.Magnitude > 0.1 then
			for _, enemy in ipairs(enemiesInLine(f, origin, dir.Unit, dir.Magnitude + 3, 4)) do
				Fighters.Damage(f, enemy, atk(f) * 0.6, { Color = C(255, 80, 80) })
			end
		end
	end
end

-- Espinhos de cristal: ruge e os cristais brotam em linha do chão até o alvo
function Specials.CrystalSpikes(f, t)
	Fighters.Stop(f)
	Fighters.Face(f, t.Root.Position)
	Fighters.SetAction(f, "Roar", 0.6)
	Fx("Roar", { Model = f.Model, Color = C(210, 160, 255) })
	if not hold(f, 0.35) or not valid(f, t) then
		return
	end
	local origin = feet(f)
	local d = dirTo(f, t.Root.Position)
	local dist = Fighters.FlatDistance(origin, t.Root.Position) + 8
	local points = {}
	for k = 1, math.floor(dist / 3.5) do
		table.insert(points, ground(origin + d * (k * 3.5 + f.Radius)))
	end
	Fx("Spikes", { Positions = points, Color = C(200, 150, 255), Height = 6, Interval = 0.05 })
	task.wait(#points * 0.05)
	if not live(f) then
		return
	end
	for _, enemy in ipairs(enemiesInLine(f, flat(origin), d, dist + 2, 6)) do
		Fx("Shockwave", { Position = ground(enemy.Root.Position), Radius = 6, Color = C(210, 170, 255) })
		Fighters.Damage(f, enemy, atk(f) * 1.9, { Knockback = Vector3.new(0, 45, 0), Color = C(210, 170, 255) })
	end
end

---------------------------------------------------------------- ÉPICOS
-- Corte Samurai: brilho da lâmina, três cortes em zigue-zague e... o golpe final "atrasado" (iai)
function Specials.SamuraiSlash(f, t)
	Fighters.Stop(f)
	Fighters.Face(f, t.Root.Position)
	Fighters.SetAction(f, "Crouch", 0.45)
	Fx("EyeGlow", { Model = f.Model, Color = C(255, 255, 255), Duration = 0.4 })
	if not hold(f, 0.45) then
		return
	end
	local dirs = {}
	for i = 1, 3 do
		if not valid(f, t) then
			return
		end
		local d = dirTo(f, t.Root.Position)
		local right = Vector3.new(-d.Z, 0, d.X)
		local goal = inZone(f, t.Root.Position + d * (t.Radius + 6) + right * (i % 2 == 0 and 5 or -5))
		local travel = flat(goal - f.Root.Position)
		if travel.Magnitude < 1 then
			travel = d * 8
		end
		local speed = 130
		local time = travel.Magnitude / speed
		Fighters.SetAction(f, "Dash", time + 0.05)
		Fx("Streak", { Model = f.Model, Color = C(255, 255, 255), Duration = time, Width = 0.8, Neon = true })
		Fighters.Push(f, travel.Unit * speed, time)
		Fx("Slash", { Position = t.Root.Position, Direction = travel.Unit, Color = C(200, 230, 255), Size = 7 })
		table.insert(dirs, travel.Unit)
		task.wait(time)
		if valid(f, t) then
			Fighters.Damage(f, t, atk(f) * 0.6, { Knockback = travel.Unit * 8 })
		end
		task.wait(0.1)
	end
	-- pausa dramática, depois todos os cortes "abrem" de uma vez
	if not hold(f, 0.3) or not valid(f, t) then
		return
	end
	for _, d in ipairs(dirs) do
		Fx("Slash", { Position = t.Root.Position, Direction = d, Color = C(255, 255, 255), Size = 10 })
	end
	Fx("Impact", { Position = ground(t.Root.Position), Radius = 6, Color = C(220, 240, 255) })
	Fighters.Damage(f, t, atk(f) * 1.7, { Knockback = Vector3.new(0, 30, 0), Color = C(220, 240, 255) })
end

-- Clones Sombrios: vira sombra, some, 3 clones cercam o alvo, o verdadeiro aparece atrás (crítico)
function Specials.ShadowClones(f, t)
	Fighters.Stop(f)
	Fighters.SetAction(f, "Shadow", 0.45)
	Fx("Smoke", { Position = f.Root.Position, Color = C(40, 20, 60), Size = 7 })
	if not hold(f, 0.4) or not valid(f, t) then
		return
	end
	Fighters.SetAction(f, "Vanish", 1.5)
	Fx("Smoke", { Position = f.Root.Position, Color = C(25, 10, 40), Size = 9 })
	local center = t.Root.Position
	local frames = {}
	local base = math.random() * math.pi * 2
	local rootHeight = f.Humanoid.HipHeight + f.Root.Size.Y / 2
	for k = 0, 2 do
		local a = base + k * math.pi * 2 / 3
		local p = ground(center + Vector3.new(math.cos(a), 0, math.sin(a)) * (t.Radius + f.Radius + 4)) + Vector3.new(0, rootHeight, 0)
		-- CFrame do HumanoidRootPart de cada clone, olhando para o alvo
		table.insert(frames, CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z)))
	end
	Fx("Clones", { Model = f.Model, CFrames = frames, Duration = 1.3, Center = center })
	if not hold(f, 0.95) or not valid(f, t) then
		return
	end
	-- o verdadeiro aparece atrás do alvo
	local behind = inZone(f, t.Root.Position - flat(t.Root.CFrame.LookVector).Unit * (t.Radius + f.Radius + 1.5))
	Fighters.Teleport(f, ground(behind))
	Fighters.Face(f, t.Root.Position)
	Fighters.SetAction(f, "Shadow", 0.3)
	Fx("ShadowStrike", { Position = t.Root.Position, Direction = dirTo(f, t.Root.Position), Color = C(190, 100, 255) })
	if not hold(f, 0.15) then
		return
	end
	Fighters.SetAction(f, nil)
	Fighters.Bite(f)
	if valid(f, t) then
		Fighters.Damage(f, t, atk(f) * 2.2, { Crit = true, Knockback = dirTo(f, t.Root.Position) * 40 + Vector3.new(0, 15, 0), Color = C(210, 140, 255) })
	end
end

-- Nuvem tóxica: cospe uma bola de veneno em arco; onde cai, nuvem borbulhante com dano contínuo
function Specials.ToxicCloud(f, t)
	Fighters.Stop(f)
	Fighters.Face(f, t.Root.Position)
	Fighters.SetAction(f, "Open", 0.7)
	if not hold(f, 0.35) or not valid(f, t) then
		return
	end
	local center = ground(t.Root.Position)
	local mouth = f.Root.Position + f.Root.CFrame.LookVector * f.Radius + Vector3.new(0, f.Root.Size.Y * 0.4, 0)
	Fx("Glob", { From = mouth, To = center, Duration = 0.45, Color = C(130, 230, 60) })
	if not hold(f, 0.45) then
		return
	end
	Fx("Cloud", { Position = center, Radius = 11, Color = C(130, 230, 60), Duration = 5 })
	task.spawn(function()
		for _ = 1, 5 do
			if not live(f) then
				return
			end
			Fighters.DamageArea(f, center, 11, atk(f) * 0.45, { Color = C(150, 255, 80) })
			task.wait(1)
		end
	end)
	hold(f, 0.3)
end

-- Anel Infernal: rosna e o chão pega fogo; corre em círculo em volta do inimigo deixando um anel de
-- fogo; salta e explode no meio do anel (quem ficou preso leva tudo)
function Specials.InfernoRing(f, t)
	Fighters.Stop(f)
	Fighters.Face(f, t.Root.Position)
	Fighters.SetAction(f, "Roar", 0.8)
	Fx("Roar", { Model = f.Model, Color = C(255, 120, 40) })
	Fx("Ignite", { Position = feet(f), Radius = 4.5, Duration = 1.4 })
	if not hold(f, 0.75) or not valid(f, t) then
		return
	end
	local center = ground(t.Root.Position)
	local radius = math.min(t.Radius + f.Radius + 6, 14)
	local hum = f.Humanoid
	setSpeed(f, 2.6)
	Fighters.SetAction(f, "Zoom", 2.2)
	local start = math.atan2(f.Root.Position.Z - center.Z, f.Root.Position.X - center.X)
	local steps = 12
	for i = 1, steps do
		if not live(f) then
			return
		end
		local a = start + i / steps * math.pi * 2
		hum:MoveTo(center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius)
		task.wait(0.15)
		if live(f) then
			Fx("FireSpot", { Position = ground(f.Root.Position), Duration = 3.2 - i * 0.12, Size = 2 })
		end
		-- quem tentar atravessar o anel se queima
		if i % 3 == 0 and valid(f, t) then
			local d = Fighters.FlatDistance(t.Root.Position, center)
			if math.abs(d - radius) < 3 then
				Fighters.Damage(f, t, atk(f) * 0.3, { Color = C(255, 140, 50) })
			end
		end
	end
	setSpeed(f, 1)
	if not live(f) then
		return
	end
	Fx("FireRing", { Position = center, Radius = radius, Duration = 1.6 })
	Fighters.SetAction(f, "Fly", 0.6)
	Fighters.Push(f, flat(center - f.Root.Position) / 0.4 + Vector3.new(0, 45, 0), 0.35)
	if not hold(f, 0.6) then
		return
	end
	Fx("Explosion", { Position = center + Vector3.new(0, 1, 0), Radius = radius + 2, Color = C(255, 110, 30) })
	Fighters.DamageArea(f, center, radius + 2, atk(f) * 2.4, { KnockbackPower = 60, Lift = 30, Color = C(255, 140, 50) })
end

-- Amarras da Múmia: tira de bandagem voa, enrola o alvo e o prende no lugar
function Specials.MummyBind(f, t)
	Fighters.Stop(f)
	Fighters.Face(f, t.Root.Position)
	Fighters.SetAction(f, "Open", 0.6)
	Fx("Smoke", { Position = feet(f), Color = C(220, 200, 150), Size = 4 })
	Fx("Projectile", { From = f.Root.Position, To = t.Root.Position, Duration = 0.4, Kind = "bandage" })
	if not hold(f, 0.4) then
		return
	end
	if valid(f, t) then
		Fighters.Freeze(t, 2.6, "bandage")
		Fighters.Damage(f, t, atk(f) * 1.3, { Color = C(240, 220, 160) })
	end
	hold(f, 0.3)
end

-- Mergulho: afunda no chão (só a barbatana corta a terra), persegue, e explode num gêiser embaixo do alvo
function Specials.SharkDive(f, t)
	Fighters.Stop(f)
	Fighters.SetAction(f, "Dive", 3.2)
	Fx("Smoke", { Position = feet(f), Color = C(160, 135, 100), Size = 4 })
	if not hold(f, 0.4) then
		return
	end
	local hum = f.Humanoid
	setSpeed(f, 2)
	local started = os.clock()
	while valid(f, t) and os.clock() - started < 2.2 do
		hum:MoveTo(t.Root.Position)
		Fx("Fin", { Model = f.Model, Duration = 0.25 })
		if Fighters.FlatDistance(f.Root.Position, t.Root.Position) < t.Radius + f.Radius + 1 then
			break
		end
		task.wait(0.2)
	end
	setSpeed(f, 1)
	if not live(f) then
		return
	end
	Fighters.Stop(f)
	local spot = ground(f.Root.Position)
	Fx("Telegraph", { Position = spot, Radius = 8, Duration = 0.3, Color = C(90, 180, 255) })
	if not hold(f, 0.3) then
		return
	end
	Fighters.SetAction(f, "Fly", 0.6)
	Fighters.Push(f, Vector3.new(0, 55, 0), 0.3)
	Fx("Geyser", { Position = spot, Radius = 8 })
	Fighters.DamageArea(f, spot, 8.5, atk(f) * 2.4, { KnockbackPower = 20, Lift = 55, Color = C(120, 200, 255) })
end

-- Raio trator: feixe verde ergue o alvo e o arremessa contra o chão
function Specials.TractorBeam(f, t)
	Fighters.Stop(f)
	Fighters.Face(f, t.Root.Position)
	Fighters.SetAction(f, "Aim", 1.7)
	Fx("EyeGlow", { Model = f.Model, Color = C(120, 255, 160), Duration = 0.3 })
	if not hold(f, 0.3) or not valid(f, t) then
		return
	end
	Fx("Tractor", { From = f.Model, To = t.Model, Color = C(120, 255, 160), Duration = 1.3 })
	Fighters.Push(t, Vector3.new(0, 18, 0), 0.9)
	if not hold(f, 1.0) then
		return
	end
	if valid(f, t) then
		Fighters.Push(t, Vector3.new(0, -110, 0), 0.2)
		task.wait(0.2)
		if valid(f, t) then
			Fx("Impact", { Position = ground(t.Root.Position), Radius = 9, Color = C(140, 255, 180), Heavy = true })
			Fighters.Damage(f, t, atk(f) * 2.1, { Color = C(150, 255, 180) })
		end
	end
end

-- Domínio Congelado: cabeça pra cima e uiva; o gelo cresce no chão; desliza para trás no gelo;
-- uma onda de cristais atravessa e congela quem pegar
function Specials.FrozenDomain(f, t)
	local ice = C(180, 230, 255)
	Fighters.Stop(f)
	Fighters.Face(f, t.Root.Position)
	Fighters.SetAction(f, "Howl", 1.25)
	Fx("Roar", { Model = f.Model, Color = ice, Howl = true })
	if not hold(f, 0.5) then
		return
	end
	Fx("IceField", { Position = feet(f), Radius = 18, Duration = 4, Grow = 0.8 })
	if not hold(f, 0.7) then
		return
	end
	local d = valid(f, t) and dirTo(f, t.Root.Position) or flat(f.Root.CFrame.LookVector).Unit
	Fighters.Face(f, f.Root.Position + d)
	Fx("Streak", { Model = f.Model, Color = ice, Duration = 0.35, Width = 0.8 })
	Fighters.Push(f, -d * 38, 0.35)
	if not hold(f, 0.45) then
		return
	end
	if valid(f, t) then
		d = dirTo(f, t.Root.Position)
		Fighters.Face(f, t.Root.Position)
	end
	local origin = feet(f)
	local length, width, duration = 60, 16, 0.9
	Fighters.SetAction(f, "Roar", 0.5)
	Fx("IceWave", { From = origin, Direction = d, Length = length, Width = width, Color = ice, Duration = duration })
	-- dano quando a onda chega em cada inimigo
	local hit = {}
	local started = os.clock()
	while os.clock() - started < duration do
		task.wait(0.05)
		if not live(f) then
			return
		end
		local reach = length * (os.clock() - started) / duration
		for _, enemy in ipairs(enemiesInLine(f, flat(origin), d, reach, width)) do
			if not hit[enemy] then
				hit[enemy] = true
				Fighters.Damage(f, enemy, atk(f) * 2, { Color = ice })
				Fighters.Freeze(enemy, 2.6)
			end
		end
	end
end

---------------------------------------------------------------- LENDÁRIOS
-- Dragon Breath: recua, abre a boca e solta fogo em cone (queima o chão), termina com golpe de cauda
function Specials.DragonBreath(f, t)
	if not approach(f, t, 14, 1.2) then
		return
	end
	local d = dirTo(f, t.Root.Position)
	Fighters.Face(f, t.Root.Position)
	Fighters.Push(f, -d * 32 + Vector3.new(0, 8, 0), 0.25)
	Fighters.SetAction(f, "Rear", 0.45)
	Fx("Smoke", { Position = feet(f), Color = C(90, 70, 60), Size = 4 })
	if not hold(f, 0.45) then
		return
	end
	if valid(f, t) then
		Fighters.Face(f, t.Root.Position)
	end
	Fighters.SetAction(f, "Open", 1.7)
	Fx("Cone", { Model = f.Model, Length = 24, Angle = 28, Color = C(255, 120, 30), Duration = 1.55, Kind = "fire" })
	local burned = {}
	for _ = 1, 7 do
		if not live(f) then
			return
		end
		if valid(f, t) then
			Fighters.Face(f, t.Root.Position)
		end
		local look = flat(f.Root.CFrame.LookVector)
		if look.Magnitude > 0.1 then
			for _, enemy in ipairs(enemiesInCone(f, flat(f.Root.Position), look.Unit, 24, 30)) do
				Fighters.Damage(f, enemy, atk(f) * 0.42, { Color = C(255, 150, 40) })
				if not burned[enemy] then
					burned[enemy] = true
					Fx("Burn", { Model = enemy.Model, Duration = 1.8 })
				end
			end
		end
		task.wait(0.22)
	end
	-- golpe de cauda girando
	if valid(f, t) and Fighters.FlatDistance(f.Root.Position, t.Root.Position) > 12 then
		Fighters.Push(f, dirTo(f, t.Root.Position) * 40, 0.2)
	end
	Fighters.SetAction(f, "Spin", 0.5)
	if not hold(f, 0.25) then
		return
	end
	Fx("TailSwipe", { Model = f.Model, Radius = 11, Color = C(255, 140, 60) })
	Fighters.DamageArea(f, f.Root.Position, 11, atk(f) * 1.5, { KnockbackPower = 65, Lift = 20 })
end

-- Double Assault: as cabeças mordem ALTERNADAS (cada uma com sua cor) e terminam juntas (crítico)
function Specials.DoubleAssault(f, t)
	if not approach(f, t, 3, 1.5) then
		return
	end
	local heads = f.Model:GetAttribute("Heads") or 2
	local colors = { C(255, 160, 70), C(110, 200, 255), C(255, 90, 140) }
	for i = 1, 6 do
		if not valid(f, t) then
			return
		end
		local h = (i - 1) % heads + 1
		local d = dirTo(f, t.Root.Position)
		Fighters.Face(f, t.Root.Position)
		Fighters.Push(f, d * 18, 0.1)
		Fighters.Bite(f, h)
		local side = Vector3.new(-d.Z, 0, d.X) * (h == 1 and -1 or 1) * 0.8
		Fx("BiteMark", { Position = t.Root.Position + side, Direction = d, Color = colors[h] or colors[1] })
		Fighters.Damage(f, t, atk(f) * 0.55, { Knockback = d * 8, Color = colors[h] })
		task.wait(0.24)
	end
	if not valid(f, t) then
		return
	end
	Fighters.SetAction(f, "Roar", 0.5)
	Fx("EyeGlow", { Model = f.Model, Color = C(255, 230, 150), Duration = 0.35, All = true })
	if not hold(f, 0.35) or not valid(f, t) then
		return
	end
	local d = dirTo(f, t.Root.Position)
	Fighters.Push(f, d * 30, 0.12)
	for h = 1, heads do
		Fighters.Bite(f, h)
	end
	Fx("BiteMark", { Position = t.Root.Position, Direction = d, Color = C(255, 230, 150), Big = true })
	Fighters.Damage(f, t, atk(f) * 2.1, { Crit = true, Knockback = d * 50 + Vector3.new(0, 20, 0) })
end

-- Sonic Rush: some num estrondo; rastros cortam a arena e acertam de vários lados; reaparece atrás
function Specials.SonicRush(f, t)
	local yellow = C(255, 230, 90)
	Fighters.Stop(f)
	Fx("SonicBoom", { Position = f.Root.Position, Direction = f.Root.CFrame.LookVector, Color = yellow, Radius = 7 })
	Fighters.SetAction(f, "Vanish", 2.1)
	if not hold(f, 0.2) then
		return
	end
	local last = f.Root.Position
	for i = 1, 6 do
		if not valid(f, t) then
			break
		end
		local a = math.random() * math.pi * 2
		local c = t.Root.Position
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local from = inZone(f, c + dir * 28)
		local to = inZone(f, c - dir * 28)
		if i == 1 then
			Fx("Trail", { From = last, To = from, Color = yellow, Width = 1, Duration = 0.25, Neon = true })
		end
		Fx("Trail", { From = from, To = to, Color = yellow, Width = 1.6, Duration = 0.45, Neon = true })
		Fx("Slash", { Position = c, Direction = to - from, Color = C(255, 245, 160), Size = 6 })
		Fx("SonicBoom", { Position = c + Vector3.new(0, 1, 0), Direction = to - from, Color = yellow, Radius = 4 })
		Fighters.Teleport(f, ground(to))
		last = to
		Fighters.Damage(f, t, atk(f) * 0.5, { Knockback = flat(to - from).Unit * 10 })
		task.wait(i < 4 and 0.18 or 0.13)
	end
	if not live(f) then
		return
	end
	if valid(f, t) then
		local behind = inZone(f, t.Root.Position - flat(t.Root.CFrame.LookVector).Unit * (t.Radius + f.Radius + 1))
		Fighters.Teleport(f, ground(behind))
		Fighters.Face(f, t.Root.Position)
	end
	Fighters.SetAction(f, nil)
	Fx("SonicBoom", { Position = f.Root.Position, Direction = f.Root.CFrame.LookVector, Color = yellow, Radius = 8 })
	if valid(f, t) then
		Fighters.Bite(f)
		Fx("BiteMark", { Position = t.Root.Position, Direction = dirTo(f, t.Root.Position), Color = yellow, Big = true })
		Fighters.Damage(f, t, atk(f) * 1.3, { Knockback = dirTo(f, t.Root.Position) * 45 + Vector3.new(0, 15, 0) })
	end
end

-- Chuva de estrelas: flutua brilhando e estrelas caem (com aviso no chão) em volta do alvo
function Specials.Starfall(f, t)
	Fighters.Stop(f)
	Fighters.SetAction(f, "Float", 2.5)
	Fighters.Push(f, Vector3.new(0, 10, 0), 0.4)
	Fx("EyeGlow", { Model = f.Model, Color = C(255, 240, 160), Duration = 2.2, Body = true })
	if not hold(f, 0.5) then
		return
	end
	for i = 1, 7 do
		if not valid(f, t) then
			break
		end
		-- a primeira e a última miram direto no alvo
		local spread = (i == 1 or i == 7) and 0 or 8
		local p = ground(t.Root.Position) + Vector3.new(math.random(-spread, spread), 0, math.random(-spread, spread))
		Fx("Meteor", { Position = p, Delay = 0.5, Radius = 5, Kind = "star" })
		task.delay(0.5, function()
			if live(f) then
				Fighters.DamageArea(f, p, 5.5, atk(f) * 0.8, { KnockbackPower = 15, Lift = 15, Color = C(255, 240, 150) })
			end
		end)
		task.wait(0.22)
	end
	hold(f, 0.5)
end

-- Hell Gate: rosna, um portal (pentagrama) abre no chão sob o inimigo; cabeças espectrais saem do
-- portal e mordem uma a uma; sombras pontudas brotam em volta e erguem o inimigo
function Specials.HellGate(f, t)
	local red = C(255, 50, 90)
	Fighters.Stop(f)
	Fighters.Face(f, t.Root.Position)
	Fighters.SetAction(f, "Roar", 0.8)
	Fx("Roar", { Model = f.Model, Color = C(255, 40, 80) })
	local center = ground(t.Root.Position)
	Fx("Circle", { Position = center, Radius = 13, Color = C(200, 20, 60), Duration = 3.2, Kind = "hell" })
	if not hold(f, 0.75) then
		return
	end
	local heads = math.max(3, f.Model:GetAttribute("Heads") or 3)
	for h = 1, heads do
		if not valid(f, t) then
			break
		end
		local a = h / heads * math.pi * 2 + math.random()
		local from = center + Vector3.new(math.cos(a), 0, math.sin(a)) * 11 + Vector3.new(0, 1, 0)
		Fighters.Bite(f, (h - 1) % (f.Model:GetAttribute("Heads") or 1) + 1)
		Fx("SpectralBite", { From = from, To = t.Root.Position, Color = red, Big = h == heads })
		task.wait(0.35)
		if valid(f, t) then
			Fighters.Damage(f, t, atk(f) * (h == heads and 1.2 or 0.8), { Color = red, Knockback = flat(t.Root.Position - from).Unit * 10 })
		end
	end
	if not live(f) then
		return
	end
	local ring = {}
	for k = 1, 10 do
		local a = k / 10 * math.pi * 2
		table.insert(ring, center + Vector3.new(math.cos(a), 0, math.sin(a)) * 9)
	end
	Fx("Spikes", { Positions = ring, Color = C(40, 10, 30), Height = 9, Interval = 0.03, Kind = "shadow" })
	task.wait(0.3)
	if live(f) then
		Fx("Explosion", { Position = center + Vector3.new(0, 1, 0), Radius = 9, Color = C(200, 20, 60), Kind = "void" })
		Fighters.DamageArea(f, center, 13, atk(f) * 1.4, { KnockbackPower = 10, Lift = 45, Color = red })
	end
end

-- Titan Rage: ruge, o chão treme, câmera sente o impacto e ele cresce em passos até perto de 4x.
-- Gigante anda pesado (Animator lê "Raging") e cada mordida bate no chão (CombatService).
local RAGE_TIME = 8
local MAX_TITAN_HEIGHT = 20 -- studs de altura máxima (segurança: não atravessa teto/escada da torre)

local function titanFactor(f)
	if f.Kind == "boss" then
		return 1.5
	end
	local height = f.Model:GetExtentsSize().Y / math.max(f.ScaleNow or 1, 0.01)
	return math.clamp(MAX_TITAN_HEIGHT / math.max(height, 1), 1.6, 4)
end

-- muda a escala erguendo o corpo antes, para as patas não afundarem no chão
local function titanScale(f, factor)
	if not A(f) then
		return
	end
	local old = f.ScaleNow or 1
	if factor > old then
		local rootY = f.Root.Size.Y / old
		local lift = (f.HipHeight + rootY / 2) * (factor - old)
		f.Model:PivotTo(f.Model:GetPivot() + Vector3.new(0, lift, 0))
	end
	Fighters.Scale(f, factor)
end

local function endRage(f, token)
	if f.RageToken ~= token then
		return
	end
	f.RageToken = nil
	f.Raging = nil
	f.DamageDealt = 1
	f.SpeedMult = 1
	if not A(f) then
		return
	end
	f.Model:SetAttribute("Raging", nil)
	local from = f.ScaleNow or 1
	for k = 1, 4 do
		if not A(f) or f.RageToken then
			return
		end
		titanScale(f, from + (1 - from) * k / 4)
		task.wait(0.08)
	end
	Fx("Smoke", { Position = feet(f), Color = C(200, 180, 140), Size = 6 })
	if not Fighters.IsFrozen(f) then
		f.Humanoid.WalkSpeed = f.Stats.Speed
	end
end

function Specials.TitanRage(f, _t)
	Fighters.Stop(f)
	Fighters.SetAction(f, "Roar", 1.4)
	Fx("Roar", { Model = f.Model, Color = C(255, 200, 80) })
	Fx("Shake", { Position = f.Root.Position, Intensity = 1, Radius = 90, Duration = 1 })
	Fx("Shockwave", { Position = feet(f), Radius = 14, Color = C(255, 210, 120), Thick = true })
	if not hold(f, 0.6) then
		return
	end
	local token = {}
	f.RageToken = token
	local target = titanFactor(f)
	local from = f.ScaleNow or 1
	local steps = 6
	for k = 1, steps do
		if f.RageToken ~= token then
			return
		end
		if not live(f) then
			task.spawn(endRage, f, token) -- interrompido no meio: volta ao tamanho normal
			return
		end
		titanScale(f, from + (target - from) * k / steps)
		if k % 2 == 0 then
			Fx("TitanGrow", { Model = f.Model })
			Fx("Shake", { Position = f.Root.Position, Intensity = 0.35 + 0.15 * k / steps, Radius = 70, Duration = 0.3 })
		end
		task.wait(0.12)
	end
	if not live(f) then
		task.spawn(endRage, f, token)
		return
	end
	Fx("Shockwave", { Position = feet(f), Radius = 22, Color = C(255, 210, 120), Thick = true })
	Fx("Shake", { Position = f.Root.Position, Intensity = 0.9, Radius = 100, Duration = 0.6 })
	f.Raging = os.clock() + RAGE_TIME
	f.DamageDealt = 1.5
	f.SpeedMult = 0.8
	setSpeed(f, 1)
	f.Model:SetAttribute("Raging", true)
	Fx("TitanAura", { Model = f.Model, Duration = RAGE_TIME })
	-- vigia: acaba o modo titã no tempo, ou antes se ele sair do combate
	task.spawn(function()
		while f.RageToken == token and A(f) and os.clock() < f.Raging and not f.Controlled do
			task.wait(0.25)
		end
		endRage(f, token)
	end)
end

---------------------------------------------------------------- MÍTICOS
-- Mergulho da Fênix: asas pegam fogo, sobe alto, mira (aviso no chão) e mergulha em chamas
function Specials.PhoenixDive(f, t)
	Fighters.Stop(f)
	Fighters.SetAction(f, "Fly", 1.6)
	Fx("PhoenixRise", { Model = f.Model, Duration = 1.3 })
	Fighters.Push(f, Vector3.new(0, 70, 0), 0.5)
	if not hold(f, 0.45) or not valid(f, t) then
		return
	end
	Fx("Telegraph", { Position = ground(t.Root.Position), Radius = 12, Duration = 0.5, Color = C(255, 140, 40) })
	if not hold(f, 0.3) or not valid(f, t) then
		return
	end
	local target = t.Root.Position
	local diff = target - f.Root.Position
	local speed = 130
	local time = math.min(diff.Magnitude / speed, 0.6)
	Fx("Streak", { Model = f.Model, Color = C(255, 110, 20), Duration = time + 0.1, Width = 3, Neon = true, Lifetime = 0.5, Sparks = true })
	Fighters.Push(f, diff.Unit * speed, time)
	if not hold(f, time) then
		return
	end
	local spot = ground(target)
	Fx("Explosion", { Position = spot + Vector3.new(0, 1, 0), Radius = 13, Color = C(255, 130, 30) })
	Fx("Lava", { Position = spot, Radius = 7, Duration = 2.5 })
	Fx("FireRing", { Position = spot, Radius = 9, Duration = 1.2 })
	Fighters.DamageArea(f, spot, 13, atk(f) * 2.7, { KnockbackPower = 55, Lift = 28, Color = C(255, 160, 50) })
end

-- Fenda do Vazio: buraco negro sob o inimigo, puxa todos para o centro e implode
function Specials.VoidRift(f, t)
	Fighters.Stop(f)
	Fighters.SetAction(f, "Roar", 0.8)
	Fx("Roar", { Model = f.Model, Color = C(170, 90, 255) })
	if not hold(f, 0.5) or not valid(f, t) then
		return
	end
	local center = ground(t.Root.Position)
	Fx("Vortex", { Position = center, Radius = 18, Duration = 2.2 })
	for _ = 1, 10 do
		if not live(f) then
			return
		end
		for _, enemy in ipairs(Fighters.Enemies(f, center, 22)) do
			local pull = flat(center - enemy.Root.Position)
			if pull.Magnitude > 1.5 then
				Fighters.Push(enemy, pull.Unit * 26, 0.18)
			end
		end
		task.wait(0.2)
	end
	if not live(f) then
		return
	end
	Fx("Explosion", { Position = center + Vector3.new(0, 1.5, 0), Radius = 15, Color = C(150, 70, 255), Kind = "void" })
	Fx("Shake", { Position = center, Intensity = 1, Radius = 70, Duration = 0.5 })
	Fighters.DamageArea(f, center, 15, atk(f) * 3, { KnockbackPower = 75, Lift = 30, Color = C(190, 130, 255) })
end

---------------------------------------------------------------- BOSS
-- Fase 1 do Volcanic Cerberus: cada cabeça dá um bote com a boca em chamas e deixa o alvo queimando
function Specials.FireBite(f, t)
	if not approach(f, t, 4, 1.2) then
		return
	end
	local heads = f.Model:GetAttribute("Heads") or 1
	for h = 1, heads do
		if not valid(f, t) then
			return
		end
		local d = dirTo(f, t.Root.Position)
		Fighters.Face(f, t.Root.Position)
		Fighters.Push(f, d * 28, 0.12)
		Fighters.Bite(f, h)
		Fx("Cone", { Model = f.Model, Head = h, Length = 10, Angle = 22, Color = C(255, 120, 30), Duration = 0.35, Kind = "fire" })
		Fx("BiteMark", { Position = t.Root.Position, Direction = d, Color = C(255, 140, 40), Big = h == heads })
		Fx("Burn", { Model = t.Model, Duration = 1.4 })
		Fighters.Damage(f, t, atk(f) * (h == heads and 1.4 or 1), { Knockback = d * 25, Color = C(255, 140, 40) })
		task.wait(0.32)
	end
	if valid(f, t) then
		Fx("FireSpot", { Position = ground(t.Root.Position), Duration = 2, Size = 2.2 })
	end
end

-- Fase 2: uiva para o céu e meteoros caem sobre cada inimigo (com aviso que enche no chão)
function Specials.Meteor(f, _t)
	Fighters.Stop(f)
	Fighters.SetAction(f, "Howl", 1.2)
	Fx("Roar", { Model = f.Model, Color = C(255, 120, 40), Howl = true })
	if not hold(f, 0.6) then
		return
	end
	local enemies = Fighters.Enemies(f)
	for i = 1, 8 do
		if not live(f) then
			return
		end
		local p
		local e = enemies[(i - 1) % math.max(1, #enemies) + 1]
		if e and A(e) then
			p = ground(e.Root.Position) + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
		else
			p = ground(f.Root.Position + Vector3.new(math.random(-30, 30), 0, math.random(-30, 30)))
		end
		Fx("Meteor", { Position = p, Delay = 1.1, Radius = 8 })
		task.delay(1.1, function()
			if live(f) then
				Fighters.DamageArea(f, p, 8, atk(f) * 1.6, { KnockbackPower = 40, Lift = 25, Color = C(255, 140, 40) })
			end
		end)
		task.wait(0.15)
	end
	hold(f, 0.6)
end

-- Fase 3: bate as patas, rachaduras de lava correm pelo chão e o piso vira lava (dano contínuo)
function Specials.LavaFloor(f, _t)
	Fighters.Stop(f)
	Fighters.SetAction(f, "Slam", 0.6)
	if not hold(f, 0.2) then
		return
	end
	local base = feet(f)
	Fx("Shockwave", { Position = base, Radius = 16, Color = C(255, 120, 40), Thick = true })
	Fx("Shake", { Position = f.Root.Position, Intensity = 1, Radius = 90, Duration = 0.6 })
	local pools = {}
	local enemies = Fighters.Enemies(f)
	for i = 1, 5 do
		local e = enemies[i]
		local p
		if e and A(e) then
			p = ground(e.Root.Position + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
		else
			local a = math.random() * math.pi * 2
			local r = math.random(10, 40)
			p = ground(inZone(f, base + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)))
		end
		table.insert(pools, p)
	end
	Fx("LavaCracks", { From = base, Tos = pools, Duration = 6.5 })
	for _, p in ipairs(pools) do
		Fx("Telegraph", { Position = p, Radius = 9, Duration = 0.9, Color = C(255, 90, 30) })
	end
	task.spawn(function()
		task.wait(0.9)
		if not live(f) then
			return
		end
		for _, p in ipairs(pools) do
			Fx("Lava", { Position = p, Radius = 9, Duration = 6 })
		end
		for _ = 1, 6 do
			if not live(f) then
				return
			end
			for _, p in ipairs(pools) do
				for _, enemy in ipairs(Fighters.DamageArea(f, p, 9, atk(f) * 0.4, { Color = C(255, 120, 30) })) do
					Fx("Burn", { Model = enemy.Model, Duration = 0.9 })
				end
			end
			task.wait(1)
		end
	end)
	hold(f, 0.6)
end

-- Tempestade (Rei Trovão): uiva, círculos de aviso e raios caindo sobre os inimigos
function Specials.LightningStorm(f, _t)
	Fighters.Stop(f)
	Fighters.SetAction(f, "Howl", 1.4)
	Fx("Roar", { Model = f.Model, Color = C(150, 220, 255), Howl = true })
	local enemies = Fighters.Enemies(f)
	for i = 1, 9 do
		if not live(f) then
			return
		end
		local e = enemies[(i - 1) % math.max(1, #enemies) + 1]
		local base = (e and A(e)) and e.Root.Position or f.Root.Position
		local p = ground(base + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8)))
		Fx("Telegraph", { Position = p, Radius = 6, Duration = 0.8, Color = C(150, 220, 255) })
		task.delay(0.8, function()
			if live(f) then
				Fx("Lightning", { Position = p, Color = C(170, 230, 255), Big = false })
				Fighters.DamageArea(f, p, 6, atk(f) * 1.4, { KnockbackPower = 20, Lift = 20, Color = C(170, 230, 255) })
			end
		end)
		task.wait(0.2)
	end
	hold(f, 0.8)
end

---------------------------------------------------------------- proteção comum
-- Todo poder começa só com o cachorro vivo, em combate e com um alvo; se der erro ou ele morrer no
-- meio, a velocidade volta ao normal (a pose é limpa pelo CombatService).
for name, fn in pairs(Specials) do
	if type(fn) == "function" then
		Specials[name] = function(f, t)
			if not live(f) or not (t and A(t)) then
				return
			end
			local ok, err = pcall(fn, f, t)
			if live(f) and not f.RageToken then
				setSpeed(f, 1)
			end
			if not ok then
				error(err, 0)
			end
		end
	end
end

-- Tempo de recarga por raridade (bosses usam o próprio)
Specials.COOLDOWN = { Common = 9, Uncommon = 8, Rare = 8, Epic = 7, Legendary = 7, Mythic = 6, Halloween = 6, Divine = 5.5 }
Specials.BOSS_COOLDOWN = 4.5

-- Pacotes extras: cada ModuleScript em Services/SpecialsPacks retorna function(Specials, Fighters)
-- que adiciona novos poderes (Specials.MeuPoder = function(f, alvo) ... end).
do
	local packs = script.Parent:FindFirstChild("SpecialsPacks")
	if packs then
		for _, module in ipairs(packs:GetChildren()) do
			if module:IsA("ModuleScript") then
				local ok, err = pcall(function()
					require(module)(Specials, Fighters)
				end)
				if not ok then
					warn("[Specials] pacote falhou", module.Name, err)
				end
			end
		end
	end
end

return Specials
