-- 🧰 KIT DAS HABILIDADES (2026-10, pedido do dono: "refaça as habilidades de todos, mais diferentes, com mais
-- animação e efeitos especiais únicos; comum = simples e fraco, cada raridade um pouco melhor").
--
-- Cada habilidade nova (SpecialsPacks/Skills_*.lua) é uma função curta que recebe `k` (este kit) e conta a
-- sequência: POSE do cachorro (k:pose, animações novas do Animator) → AVISO (k:tele) → MOVIMENTO (k:leap,
-- k:dash, k:blink, k:circle, k:glide) → EFEITO + DANO (k:hit, k:area, k:shoot, k:rain, k:zone, k:summon,
-- k:beam, k:breath, k:wave) → RESÍDUO. Os desenhos ficam no cliente (EffectsPacks/PackSkills, efeitos "S_*").
--
-- FORÇA PELA RARIDADE (Config.SKILL_TIER): o código só diz a FRAÇÃO de cada golpe (k:hit(0.4) = 40% do
-- orçamento daquela habilidade). Comum gasta pouco, Divino gasta muito: o mesmo código serve para todos.
-- Raios (k:R) e tempos de atordoar/congelar/queimar (k:secs) também crescem com a raridade.
--
-- SEGURANÇA: toda espera confere se o cachorro continua vivo e lutando (k:wait devolve false → a habilidade
-- para); buffs têm tempo e SEMPRE voltam; golpes atrasados (tiros, chuva, áreas) só checam se o dono está vivo
-- (o cachorro do jogador volta para o controle dele antes de o tiro chegar).
--
-- 🎯 MIRA DO JOGADOR (2026-10, pedido do dono: "onde estiver a seta o ataque vai, não quero ataques em que o cachorro
-- vai até lá, sempre que tento lançar um ataque trava, tem que ser rápido"). Quando o alvo é o ponto invisível da
-- setinha de quem soltou (k.aim):
--   • o jogador CONTINUA no controle (f.Casting > 0): andar, morder e soltar outro poder enquanto este acontece;
--   • o servidor só segura o corpo durante um MOVIMENTO da habilidade (k:dash/leap/blink/glide/circle/tp/behind,
--     de k:rise até k:land) — f.CastControl(+1/-1) do DogService — e o movimento vai no máximo
--     Config.SKILL_MOVE studs na direção da setinha (o ponto vem junto: "no alvo" = onde o cachorro chegou);
--   • k:approach/k:reach não andam até ninguém; virar = pedido para o cliente (atributo FaceAt);
--   • tudo mais rápido: esperas, poses, avisos, movimentos, tiros e desenhos × Config.SKILL_SPEED.
-- Selvagens e bosses (alvo de verdade) continuam como antes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Fighters = require(script.Parent.Fighters)
local ZoneGeo = require(script.Parent.ZoneGeo)

local SkillKit = {}
SkillKit.Ids = {} -- [id] = slot (2, 3 ou 4) — usado pelos testes sem Roblox

local A = Fighters.Alive
local Fx = Fighters.Fx
local C = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local GREEN = C(120, 255, 140)

---------------------------------------------------------------- utilidades
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- vivo e ainda lutando (não foi levado para casa / o jogador não pegou o controle de volta). A habilidade do JOGADOR
-- roda com ele no controle: f.Casting > 0 enquanto alguma está rodando (DogService)
local function live(f)
	return A(f) and (not f.Controlled or (f.Casting or 0) > 0)
end

local function valid(f, t)
	return live(f) and t ~= nil and A(t) and Fighters.Hostile(f, t)
end

-- chão embaixo de um ponto (ignora os cachorros); sem chão: um pouco abaixo do ponto
local function groundAt(p)
	local g = ZoneGeo.Ground(p, p.Y + 6, 90)
	return g or Vector3.new(p.X, p.Y - 3, p.Z)
end
SkillKit.Ground = groundAt

-- gira um vetor no plano (graus, em volta do eixo Y)
local function turn(v, deg)
	local r = math.rad(deg)
	local c, s = math.cos(r), math.sin(r)
	return Vector3.new(v.X * c - v.Z * s, v.Y, v.X * s + v.Z * c)
end
SkillKit.Turn = turn

-- põe o HumanoidRootPart num ponto (olhando para `look`) sem física acumulada
local function placeRoot(f, rootPos, look)
	local root = f.Root
	local d = look and flat(look) or flat(root.CFrame.LookVector)
	if d.Magnitude < 0.01 then
		d = Vector3.new(0, 0, -1)
	end
	f.Model:PivotTo(CFrame.lookAt(rootPos, rootPos + d.Unit))
	root.AssemblyLinearVelocity = Vector3.zero
end

-- altura do HumanoidRootPart acima do chão quando o cachorro está em pé
local function standHeight(f)
	return f.Humanoid.HipHeight + f.Root.Size.Y / 2 + 0.2
end

---------------------------------------------------------------- o kit
local Kit = {}
Kit.__index = Kit

function SkillKit.new(f, t, slot, id)
	local rarity = f.Species and f.Species.Rarity or "Rare"
	local tier = Config.SkillTier(rarity)
	local budget = tier.Budget[slot - 1] or tier.Budget[#tier.Budget]
	local info = DogData.Specials[id]
	local elems = DogData.ElementsOf(f.SpeciesId)
	local el = DogData.DOG_ELEMENTS[elems[1]]
	local k = setmetatable({
		f = f,
		t = t,
		id = id,
		slot = slot,
		tier = tier,
		rarity = rarity,
		power = (f.Stats.Atk or 10) * budget,
		A = tier.Area or 1,
		St = tier.Status or 1,
		color = (info and info.Color) or (el and el.Color) or C(255, 255, 255),
		size = math.clamp(f.Root.Size.Z / 4, 0.6, 4), -- cachorro grande = efeitos maiores
		rng = Random.new(),
	}, Kit)
	-- 🎯 habilidade do jogador mirando (alvo = o ponto da setinha dele): rápida, sem prender, movimentos curtos
	k.aim = t ~= nil and t.Dummy == true and t.Caster == f
	k.speed = k.aim and (Config.SKILL_SPEED or 1) or 1
	k.grabs = 0
	k.risen = 0
	-- 🪽 (2026-10, pedido do dono: "que eles possam usar as habilidades no ar") o jogador está VOANDO: os movimentos da
	-- habilidade (bote, salto, arrancada, volta...) acontecem no ar, na altura em que ele está — sem descer até o chão
	local owner = f.Owner
	k.air = k.aim and owner ~= nil and owner:GetAttribute("Flying") == true
	k.airY = k.air and f.Root.Position.Y or nil
	return k
end

-- registra uma habilidade: Specials[id](lutador, alvo) roda fn(k). No fim (ou se der erro) o corpo do cachorro
-- SEMPRE volta para o jogador.
function SkillKit.def(Specials, id, slot, fn)
	SkillKit.Ids[id] = slot
	Specials[id] = function(f, t)
		local k = SkillKit.new(f, t, slot, id)
		local ok, err = pcall(fn, k)
		k:unhold()
		k:release(true)
		if not ok then
			error(err, 0)
		end
	end
end

------------------------------------------------------------ estado e espera
function Kit:alive()
	return live(self.f)
end

function Kit:ok()
	return valid(self.f, self.t)
end

-- espera e confere se o cachorro continua vivo e lutando (do jogador: mais rápido, Config.SKILL_SPEED)
function Kit:wait(seconds)
	task.wait(seconds * self.speed)
	return live(self.f)
end

-- espera e confere também o alvo
function Kit:waitOk(seconds)
	task.wait(seconds * self.speed)
	return valid(self.f, self.t)
end

function Kit:R(r)
	return r * self.A
end

function Kit:secs(s)
	return s * self.St
end

function Kit:rand(a, b)
	return self.rng:NextNumber(a, b)
end

-- roda depois de um tempo SEM prender o cachorro (o jogador já pode andar); só precisa o dono estar vivo
function Kit:later(seconds, fn)
	task.delay(seconds * self.speed, function()
		if A(self.f) then
			fn()
		end
	end)
end

-- inimigo de verdade (não o alvo invisível da setinha)?
function Kit:real(target)
	target = target or self.t
	return target ~= nil and not target.Dummy and A(target)
end

------------------------------------------------------------ 🎯 mira do jogador
-- O servidor só segura o corpo do cachorro do jogador durante um movimento da habilidade (f.CastControl, contador
-- no DogService: movimentos de 2 habilidades ao mesmo tempo não se atrapalham).
function Kit:grab()
	if not self.aim then
		return
	end
	-- os movimentos da habilidade ficam num círculo em volta de onde o cachorro estava no 1º movimento
	self.origin = self.origin or self.f.Root.Position
	self.grabs += 1
	if self.f.CastControl then
		self.f.CastControl(1)
	end
end
-- solta 1 (ou todos, no fim da habilidade)
function Kit:release(all)
	if not self.aim or self.grabs <= 0 then
		return
	end
	local n = all and self.grabs or 1
	self.grabs -= n
	if self.f.CastControl then
		self.f.CastControl(-n)
	end
end
-- quem mexe no corpo agora é o servidor? (fora de um movimento o jogador é quem manda nele)
function Kit:held()
	return not self.aim or self.grabs > 0
end
-- segura o corpo PARADO no ar entre o k:rise e o k:land (antes a gravidade o derrubava no meio da habilidade)
function Kit:hold()
	local root = self.f.Root
	if root and root.Parent and not self.anchored then
		self.anchored = true
		root.Anchored = true
	end
end
function Kit:unhold()
	local root = self.f.Root
	if self.anchored then
		self.anchored = nil
		if root and root.Parent then
			root.Anchored = false
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end
-- movimento de habilidade do jogador: fica a no máximo SKILL_MOVE studs (× área da raridade) de onde ele começou a
-- se mexer (zigue-zague, ida e volta... nunca vai longe). O ponto da setinha vem junto, para os golpes "no alvo"
-- acertarem onde o cachorro chegou. margin = folga (o raio de uma volta em círculo)
function Kit:cap(toPos, margin)
	if not self.aim then
		return toPos
	end
	local from = self.origin or self.f.Root.Position
	local d = flat(toPos - from)
	local max = math.max(4, (Config.SKILL_MOVE or 26) * self.A - (margin or 0))
	if d.Magnitude <= max then
		return toPos
	end
	local p = Vector3.new(from.X + d.Unit.X * max, toPos.Y, from.Z + d.Unit.Z * max)
	local t = self.t
	if t and t.Dummy and t.Root then
		t.Root.CFrame = CFrame.new(groundAt(p) + UP)
	end
	return p
end
-- tempo de um desenho/efeito que acompanha a sequência (mais curto na mira do jogador)
function Kit:dur(seconds)
	return seconds and seconds * self.speed or nil
end
-- desenhos com tempo próprio (Time/Hold/Duration): na mira do jogador ficam no ritmo da habilidade
local FX_TIMES = {
	S_Ring = { Time = 0.6 },
	S_Orbit = { Duration = 1.5 },
	S_Prop = { Time = 0.6, Hold = 0.8 },
	S_Line = { Duration = 1.2 },
	S_Pillar = { Time = 0.25, Hold = 0.6 },
}
local function paced(k, name, p)
	local keys = FX_TIMES[name]
	if keys and k.speed ~= 1 then
		for key, default in pairs(keys) do
			p[key] = (p[key] or default) * k.speed
		end
	end
	return p
end

------------------------------------------------------------ posições
function Kit:me()
	return self.f.Root.Position
end

function Kit:feet()
	return groundAt(self.f.Root.Position)
end

function Kit:tpos()
	return self.t.Root.Position
end

function Kit:tground()
	return groundAt(self.t.Root.Position)
end

-- direção (no plano) do cachorro até um ponto (padrão: o alvo)
function Kit:dir(pos)
	local d = flat((pos or self.t.Root.Position) - self.f.Root.Position)
	if d.Magnitude < 0.05 then
		d = flat(self.f.Root.CFrame.LookVector)
	end
	return d.Magnitude > 0.01 and d.Unit or Vector3.new(0, 0, -1)
end

function Kit:dist(pos)
	return Fighters.FlatDistance(self.f.Root.Position, pos or self.t.Root.Position)
end

function Kit:mouth()
	local root = self.f.Root
	return root.Position + root.CFrame.LookVector * (self.f.Radius or 2) + Vector3.new(0, root.Size.Y * 0.4, 0)
end

-- ponto dentro da área de luta (dash, salto, teleporte)
function Kit:clamp(pos)
	return ZoneGeo.Clamp(self.f, pos, 5)
end

-- n pontos em volta de um centro (anel), começando no ângulo a0 (graus); jitter = sorteio do raio
function Kit:around(center, radius, n, a0, jitter)
	local list = {}
	for i = 1, n do
		local a = math.rad((a0 or 0) + (i - 1) * 360 / n)
		local r = radius * (jitter and self.rng:NextNumber(1 - jitter, 1) or 1)
		table.insert(list, groundAt(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)))
	end
	return list
end

-- n pontos sorteados dentro de um círculo (o primeiro pode ser o centro)
function Kit:scatter(center, radius, n, firstCenter)
	local list = {}
	for i = 1, n do
		if i == 1 and firstCenter then
			table.insert(list, groundAt(center))
		else
			local a = self.rng:NextNumber(0, math.pi * 2)
			local r = math.sqrt(self.rng:NextNumber()) * radius
			table.insert(list, groundAt(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)))
		end
	end
	return list
end

-- n pontos numa linha de `from` até `to`
function Kit:lineOf(from, to, n)
	local list = {}
	for i = 1, n do
		table.insert(list, groundAt(from:Lerp(to, n == 1 and 1 or (i / n))))
	end
	return list
end

-- inimigos perto de um ponto (lista)
function Kit:enemies(pos, radius)
	return Fighters.Enemies(self.f, pos, radius)
end

-- quem um golpe "no alvo" atinge: o próprio alvo, ou quem está perto do alvo invisível da setinha
function Kit:victims(target)
	target = target or self.t
	if not target then
		return {}
	end
	if target.Dummy then
		return Fighters.Enemies(self.f, target.Root.Position, Fighters.MARKER_HIT)
	end
	if A(target) and Fighters.Hostile(self.f, target) then
		return { target }
	end
	return {}
end

------------------------------------------------------------ pose e efeitos
function Kit:pose(action, duration)
	Fighters.SetAction(self.f, action, self:dur(duration), self.aim and 1 / self.speed or nil)
end

function Kit:fx(name, params)
	-- mira do jogador: desenhos com tempo (rastro, raio...) no ritmo mais rápido da habilidade
	if self.speed ~= 1 and type(params) == "table" then
		for _, key in ipairs({ "Duration", "Time" }) do
			if type(params[key]) == "number" then
				params[key] *= self.speed
			end
		end
	end
	Fx(name, params)
end

function Kit:face(pos)
	pos = pos or self.t.Root.Position
	if self:held() then
		Fighters.Face(self.f, pos)
	else
		-- o jogador está no controle do corpo: quem vira é o cliente dele (DogControl lê FaceAt)
		local m = self.f.Model
		m:SetAttribute("FaceAt", pos)
		m:SetAttribute("FaceAtN", (m:GetAttribute("FaceAtN") or 0) + 1)
	end
end

function Kit:stop()
	if self:held() then
		Fighters.Stop(self.f)
	end
end

-- aviso no chão (círculo que enche); raio já cresce com a raridade
function Kit:tele(pos, radius, duration, color)
	Fx("Telegraph", { Position = pos, Radius = self:R(radius), Duration = self:dur(duration), Color = color or self.color })
end

function Kit:impact(pos, radius, color, heavy)
	Fx("Impact", { Position = pos, Radius = self:R(radius), Color = color or self.color, Heavy = heavy })
end

function Kit:shock(pos, radius, color, thick)
	Fx("Shockwave", { Position = pos, Radius = self:R(radius), Color = color or self.color, Thick = thick })
end

function Kit:shake(pos, intensity, radius, duration)
	Fx("Shake", { Position = pos, Intensity = intensity, Radius = radius or 50, Duration = duration or 0.3 })
end

-- texto de quadrinho ("BONK!", "YAP!")
function Kit:pop(text, pos, color, size)
	Fx("S_Pop", { Position = pos or (self.f.Root.Position + Vector3.new(0, self.f.Root.Size.Y + 3, 0)), Text = text, Color = color or self.color, Size = size })
end

-- rajada de objetos/partículas num ponto (Kind = Confetti, Dirt, Leaves, Bones, Notes, Hearts...)
function Kit:burst(kind, pos, opts)
	local p = { Kind = kind, Position = pos, Color = self.color }
	for key, v in pairs(opts or {}) do
		p[key] = v
	end
	if p.Radius then
		p.Radius = self:R(p.Radius)
	end
	Fx("S_Burst", p)
end

-- brilho/carga no corpo antes do golpe
function Kit:charge(duration, color, kind)
	Fx("S_Charge", { Model = self.f.Model, Duration = self:dur(duration), Color = color or self.color, Kind = kind })
end

-- objeto grande com caminho (espada que cai, navio que passa, OVNI...)
function Kit:prop(motif, opts)
	local p = { Motif = motif, Color = self.color }
	for key, v in pairs(opts or {}) do
		p[key] = v
	end
	Fx("S_Prop", paced(self, "S_Prop", p))
end

-- linha no chão (rastro de cheiro, linha de corrida, rachadura, corte)
function Kit:path(kind, from, to, opts)
	local p = { Kind = kind, From = from, To = to, Color = self.color }
	for key, v in pairs(opts or {}) do
		p[key] = v
	end
	Fx("S_Line", paced(self, "S_Line", p))
end

-- coluna vertical (fogo, gelo, luz, raio, água...). Sem Color = a cor natural do tipo (fogo laranja, água azul...)
function Kit:pillar(kind, pos, radius, opts)
	local p = { Kind = kind, Position = pos, Radius = self:R(radius) }
	for key, v in pairs(opts or {}) do
		p[key] = v
	end
	Fx("S_Pillar", paced(self, "S_Pillar", p))
end

-- objetos girando em volta do cachorro
function Kit:orbit(motif, opts)
	local p = { Model = self.f.Model, Motif = motif, Color = self.color }
	for key, v in pairs(opts or {}) do
		p[key] = v
	end
	Fx("S_Orbit", paced(self, "S_Orbit", p))
end

-- anel de objetos que se abre a partir de um ponto
function Kit:ringOut(motif, pos, r0, r1, opts)
	local p = { Motif = motif, Position = pos, R0 = self:R(r0), R1 = self:R(r1), Color = self.color }
	for key, v in pairs(opts or {}) do
		p[key] = v
	end
	Fx("S_Ring", paced(self, "S_Ring", p))
end

-- céu/tela muda durante o Supremo (só para quem está perto)
function Kit:sky(kind, duration)
	Fx("S_Sky", { Kind = kind, Position = self.f.Root.Position, Duration = self:dur(duration) })
end

function Kit:aura(kind, duration, color)
	Fx("S_Aura", { Model = self.f.Model, Kind = kind, Duration = duration, Color = color or self.color })
end

function Kit:mark(target, kind, duration, color)
	if target and target.Model then
		Fx("S_Mark", { Model = target.Model, Kind = kind, Duration = duration, Color = color })
	end
end

------------------------------------------------------------ dano
function Kit:dmg(target, frac, opts)
	if not target or not A(self.f) then
		return 0
	end
	return Fighters.Damage(self.f, target, self.power * frac, opts or { Color = self.color })
end

-- golpe no alvo (no alvo invisível acerta quem está em volta do ponto)
function Kit:hit(frac, opts)
	return self:dmg(self.t, frac, opts)
end

-- área redonda (raio cresce com a raridade). opts = { KnockbackPower, Lift, Color, Crit }
function Kit:area(pos, radius, frac, opts)
	if not A(self.f) then
		return {}
	end
	local o = opts or {}
	if not o.Color then
		o = table.clone(o)
		o.Color = self.color
	end
	return Fighters.DamageArea(self.f, pos, self:R(radius), self.power * frac, o)
end

-- inimigos num retângulo que sai de `origin` na direção `dir`
function Kit:inLine(origin, dir, length, width, frac, opts, onHit)
	local list = {}
	dir = flat(dir)
	if dir.Magnitude < 0.01 then
		return list
	end
	dir = dir.Unit
	width = self:R(width)
	for _, enemy in ipairs(Fighters.Enemies(self.f)) do
		local rel = flat(enemy.Root.Position - origin)
		local along = rel:Dot(dir)
		local side = (rel - dir * along).Magnitude
		if along > -2 and along < length + enemy.Radius and side < width / 2 + enemy.Radius then
			table.insert(list, enemy)
			if frac and frac > 0 then
				self:dmg(enemy, frac, opts and table.clone(opts) or nil)
			end
			if onHit then
				onHit(enemy)
			end
		end
	end
	return list
end

-- inimigos num cone (ângulo = metade da abertura, em graus)
function Kit:inCone(origin, dir, length, angle, frac, opts, onHit)
	local list = {}
	dir = flat(dir)
	if dir.Magnitude < 0.01 then
		return list
	end
	dir = dir.Unit
	length = self:R(length)
	local cosA = math.cos(math.rad(angle))
	for _, enemy in ipairs(Fighters.Enemies(self.f)) do
		local rel = flat(enemy.Root.Position - origin)
		if rel.Magnitude < length + enemy.Radius and (rel.Magnitude < 2 + enemy.Radius or rel.Unit:Dot(dir) > cosA) then
			table.insert(list, enemy)
			if frac and frac > 0 then
				self:dmg(enemy, frac, opts and table.clone(opts) or nil)
			end
			if onHit then
				onHit(enemy)
			end
		end
	end
	return list
end

-- empurra para longe de um ponto (com pulinho)
function Kit:knock(target, from, power, lift)
	if A(target) and not target.Dummy then
		local d = flat(target.Root.Position - from)
		d = d.Magnitude > 0.1 and d.Unit or flat(self.f.Root.CFrame.LookVector)
		Fighters.Push(target, d * power + UP * (lift or 15), 0.2)
	end
end

-- puxa na direção de um ponto
function Kit:pull(target, to, speed, duration)
	if A(target) and not target.Dummy and target.Kind ~= "boss" then
		local d = flat(to - target.Root.Position)
		if d.Magnitude > 1.5 then
			Fighters.Push(target, d.Unit * speed, duration or 0.2)
		end
	end
end

-- joga para cima
function Kit:launch(target, up)
	if A(target) and not target.Dummy then
		Fighters.Push(target, UP * (target.Kind == "boss" and up * 0.15 or up), 0.22)
	end
end

------------------------------------------------------------ estados (alvo)
-- atordoa (não anda, não usa poder). mark = desenho em cima: Dizzy, Sleep, Pin, Web, Bubble, Vines, Cage,
-- Wrap, Honey, Dance, Shock, Fear, Charm, Stone, Time...
function Kit:stun(target, seconds, mark, color)
	seconds = self:secs(seconds)
	for _, victim in ipairs(self:victims(target)) do
		local s = victim.Kind == "boss" and seconds * 0.35 or seconds
		victim.FrozenUntil = math.max(victim.FrozenUntil or 0, os.clock() + s)
		victim.Humanoid.WalkSpeed = 0
		Fx("S_Mark", { Model = victim.Model, Kind = mark or "Dizzy", Duration = s, Color = color })
		task.delay(s, function()
			if A(victim) and os.clock() >= (victim.FrozenUntil or 0) - 0.05 then
				victim.Humanoid.WalkSpeed = victim.Stats.Speed * (victim.SpeedMult or 1)
			end
		end)
	end
end

-- obriga o alvo a fazer uma pose (dançar na Disco Fever, tremer de medo...). Não vale para bosses.
function Kit:force(target, action, seconds)
	for _, victim in ipairs(self:victims(target)) do
		if victim.Kind ~= "boss" then
			Fighters.SetAction(victim, action, seconds)
		end
	end
end

-- congela (bloco de gelo de verdade, Fighters.Freeze)
function Kit:freeze(target, seconds)
	for _, victim in ipairs(self:victims(target)) do
		Fighters.Freeze(victim, self:secs(seconds), "ice")
	end
end

-- deixa lento (mult = 0.5 → metade da velocidade)
function Kit:slow(target, seconds, mult, mark)
	seconds = self:secs(seconds)
	for _, victim in ipairs(self:victims(target)) do
		local untilT = os.clock() + seconds
		victim.SlowUntil = math.max(victim.SlowUntil or 0, untilT)
		if not Fighters.IsFrozen(victim) then
			victim.Humanoid.WalkSpeed = victim.Stats.Speed * (victim.SpeedMult or 1) * mult
		end
		Fx("S_Mark", { Model = victim.Model, Kind = mark or "Slow", Duration = seconds })
		task.delay(seconds, function()
			if A(victim) and os.clock() >= (victim.SlowUntil or 0) - 0.05 and not Fighters.IsFrozen(victim) then
				victim.Humanoid.WalkSpeed = victim.Stats.Speed * (victim.SpeedMult or 1)
			end
		end)
	end
end

-- dano ao longo do tempo (Burn, Poison, Bleed, Shock...). frac = total de todos os tiques
local DOT_COLOR = { Burn = C(255, 140, 40), Poison = C(150, 230, 70), Bleed = C(230, 50, 60), Shock = C(255, 235, 90), Curse = C(170, 90, 255) }
function Kit:dot(target, seconds, frac, kind)
	seconds = self:secs(seconds)
	local ticks = math.max(1, math.floor(seconds / 0.5))
	local per = self.power * frac / ticks
	local f = self.f
	for _, victim in ipairs(self:victims(target)) do
		Fx("S_Mark", { Model = victim.Model, Kind = kind or "Burn", Duration = seconds })
		task.spawn(function()
			for _ = 1, ticks do
				task.wait(0.5)
				if not (A(f) and A(victim)) then
					return
				end
				Fighters.Damage(f, victim, per, { Color = DOT_COLOR[kind or "Burn"] or self.color })
			end
		end)
	end
end

-- maldição: leva mais dano por um tempo (mult = 1.2 → +20%)
function Kit:curse(target, seconds, mult, mark)
	seconds = self:secs(seconds)
	for _, victim in ipairs(self:victims(target)) do
		if not victim.Cursed then
			victim.Cursed = true
			victim.DamageTaken = (victim.DamageTaken or 1) * mult
			Fx("S_Mark", { Model = victim.Model, Kind = mark or "Curse", Duration = seconds })
			task.delay(seconds, function()
				victim.DamageTaken = (victim.DamageTaken or mult) / mult
				victim.Cursed = nil
			end)
		end
	end
end

------------------------------------------------------------ estados (o próprio cachorro)
-- escudo: leva menos dano (reduce = 0.4 → −40%)
function Kit:shield(seconds, reduce, kind, color)
	local f = self.f
	if f.Shielded then
		return
	end
	f.Shielded = true
	local mult = 1 - reduce
	f.DamageTaken = (f.DamageTaken or 1) * mult
	Fx("S_Aura", { Model = f.Model, Kind = kind or "Shield", Duration = seconds, Color = color or self.color })
	task.delay(seconds, function()
		f.DamageTaken = (f.DamageTaken or mult) / mult
		f.Shielded = nil
	end)
end

-- fúria: bate mais forte (mult = 1.25 → +25%)
function Kit:rage(seconds, mult, kind, color)
	local f = self.f
	if f.Raged then
		return
	end
	f.Raged = true
	f.DamageDealt = (f.DamageDealt or 1) * mult
	Fx("S_Aura", { Model = f.Model, Kind = kind or "Rage", Duration = seconds, Color = color or self.color })
	task.delay(seconds, function()
		f.DamageDealt = (f.DamageDealt or mult) / mult
		f.Raged = nil
	end)
end

-- pressa: anda mais rápido
function Kit:haste(seconds, mult, kind, color)
	local f = self.f
	if f.Hasted then
		return
	end
	f.Hasted = true
	f.SpeedMult = (f.SpeedMult or 1) * mult
	if not Fighters.IsFrozen(f) then
		f.Humanoid.WalkSpeed = f.Stats.Speed * f.SpeedMult
	end
	Fx("S_Aura", { Model = f.Model, Kind = kind or "Haste", Duration = seconds, Color = color or self.color })
	task.delay(seconds, function()
		f.SpeedMult = (f.SpeedMult or mult) / mult
		f.Hasted = nil
		if A(f) and not Fighters.IsFrozen(f) then
			f.Humanoid.WalkSpeed = f.Stats.Speed * f.SpeedMult
		end
	end)
end

-- cura uma fração da vida máxima
function Kit:heal(frac)
	local f = self.f
	if not A(f) then
		return 0
	end
	local hum = f.Humanoid
	local amount = math.floor(hum.MaxHealth * frac)
	hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
	Fx("Damage", { Position = f.Root.Position + Vector3.new(0, f.Root.Size.Y + 2, 0), Amount = "+" .. amount, Color = GREEN })
	Fx("S_Aura", { Model = f.Model, Kind = "Heal", Duration = 1, Color = GREEN })
	return amount
end

------------------------------------------------------------ movimento
-- 🎯 mira do jogador: bote rápido na direção da setinha até ficar a `within` studs dela (100 studs/s, 0,1–0,3 s)
function Kit:lunge(within)
	local t = self.t
	local gap = self:dist() - (t.Radius or 1) - self.f.Radius - (within or 2)
	if gap > 1.5 then
		local d = self:dir()
		local was = t.Dummy and t.Root.Position
		local real = math.clamp(gap / 100, 0.1, 0.3)
		self:dash(self:me() + d * gap, real / self.speed)
		-- a setinha estava longe demais (o bote parou no limite e trouxe o ponto junto): o golpe sai `within` à frente
		-- de onde o cachorro chegou, e não em cima dele
		if was and (t.Root.Position - was).Magnitude > 0.5 and (within or 2) > 3 then
			t.Root.CFrame = CFrame.new(groundAt(self:me() + d * (within + self.f.Radius)) + UP)
		end
	end
	return self:ok()
end

-- corre até ficar a `within` studs do alvo (ou desiste depois de maxTime). Mira do jogador: não corre atrás de
-- ninguém — dá um BOTE rápido (≤ 0,3 s, no máximo SKILL_MOVE) na direção da setinha e o golpe sai ali
function Kit:approach(within, maxTime)
	if self.aim then
		return self:lunge(within)
	end
	local f, t = self.f, self.t
	local start = os.clock()
	if live(f) and not Fighters.IsFrozen(f) then
		f.Humanoid.WalkSpeed = f.Stats.Speed * (f.SpeedMult or 1) * 1.7
	end
	while valid(f, t) and os.clock() - start < maxTime do
		if Fighters.FlatDistance(f.Root.Position, t.Root.Position) - f.Radius - (t.Radius or 1) <= within then
			break
		end
		f.Humanoid:MoveTo(t.Root.Position)
		task.wait(0.1)
	end
	if live(f) and not Fighters.IsFrozen(f) then
		f.Humanoid.WalkSpeed = f.Stats.Speed * (f.SpeedMult or 1)
	end
	Fighters.Stop(f)
	return valid(f, t)
end

-- chega perto só se estiver longe (sopro/cone de alcance curto soltos na setinha lá longe)
function Kit:reach(range, maxTime)
	if self.aim then
		return self:lunge(range)
	end
	local t = self.t
	if t and self:dist() - (t.Radius or 1) - self.f.Radius > range then
		return self:approach(range, maxTime or 1)
	end
	return self:ok()
end

-- acerta quem estiver perto do cachorro durante um movimento (cada um só uma vez)
local function sweep(k, hit, done)
	if not hit then
		return
	end
	local f = k.f
	for _, e in ipairs(Fighters.Enemies(f, f.Root.Position, (hit.radius or 4) + f.Radius)) do
		if not done[e] then
			done[e] = true
			if hit.frac and hit.frac > 0 then
				k:dmg(e, hit.frac, hit.opts and table.clone(hit.opts) or nil)
			end
			if hit.on then
				hit.on(e)
			end
		end
	end
end

-- arrancada até um ponto em `time` segundos (física; para no fim). hit = { frac, radius, opts, on }
function Kit:dash(toPos, time, hit)
	self:grab()
	local ok, done = self:_dash(toPos, time * self.speed, hit)
	self:release()
	return ok, done
end
function Kit:_dash(toPos, time, hit)
	if self.air then
		return self:_swoop(toPos, 0, time, hit)
	end
	local f = self.f
	toPos = self:clamp(self:cap(toPos))
	local from = f.Root.Position
	local d = flat(toPos - from)
	local done = {}
	if d.Magnitude < 0.5 then
		return live(f), done
	end
	Fighters.Face(f, from + d)
	Fighters.Push(f, d.Unit * (d.Magnitude / time), time)
	local t0 = os.clock()
	while os.clock() - t0 < time do
		task.wait(0.04)
		if not live(f) then
			return false, done
		end
		sweep(self, hit, done)
	end
	Fighters.Stop(f)
	return live(f), done
end

-- passos de teleporte rápidos (atravessa o alvo sem bater nele)
function Kit:blink(toPos, steps, stepTime, hit)
	self:grab()
	local ok, done = self:_blink(toPos, steps, stepTime * self.speed, hit)
	self:release()
	return ok, done
end
function Kit:_blink(toPos, steps, stepTime, hit)
	local f = self.f
	toPos = self:clamp(self:cap(toPos))
	local from = f.Root.Position
	local d = flat(toPos - from)
	local done = {}
	for i = 1, steps do
		if not live(f) then
			return false, done
		end
		local step = from:Lerp(toPos, i / steps)
		if self.air then
			placeRoot(f, Vector3.new(step.X, self.airY, step.Z), d.Magnitude > 0.1 and d or nil)
		else
			Fighters.Teleport(f, groundAt(step))
		end
		if d.Magnitude > 0.1 then
			Fighters.Face(f, f.Root.Position + d)
		end
		sweep(self, hit, done)
		task.wait(stepTime)
	end
	return live(f), done
end

-- SALTO em arco até um ponto do chão (altura do arco em studs). Movimento exato (sem depender da física);
-- hit = acerta quem estiver no caminho. Chega com os pés no chão.
function Kit:leap(toPos, height, time, hit)
	self:grab()
	local ok, done = self:_leap(toPos, height, time * self.speed, hit)
	self:release()
	return ok, done
end
function Kit:_leap(toPos, height, time, hit)
	if self.air then
		return self:_swoop(toPos, height * 0.5, time, hit) -- no ar o salto vira um mergulho rasante
	end
	local f = self.f
	toPos = self:clamp(self:cap(toPos))
	local start = groundAt(f.Root.Position)
	local land = groundAt(toPos)
	local stand = standHeight(f)
	local look = flat(land - start)
	local done = {}
	local t0 = os.clock()
	while true do
		local u = math.min(1, (os.clock() - t0) / time)
		local p = start:Lerp(land, u) + Vector3.new(0, stand + 4 * height * u * (1 - u), 0)
		placeRoot(f, p, look.Magnitude > 0.1 and look or nil)
		sweep(self, hit, done)
		if u >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
		if not live(f) then
			return false, done
		end
	end
	return live(f), done
end

-- 🪽 movimento NO AR (o jogador está voando): reto até o ponto, na altura em que ele estava, com um mergulhinho de
-- `dip` studs no meio (nunca abaixo do chão)
function Kit:_swoop(toPos, dip, time, hit)
	local f = self.f
	local p = self:clamp(self:cap(toPos))
	local from = f.Root.Position
	local to = Vector3.new(p.X, self.airY or from.Y, p.Z)
	local floor = groundAt(from).Y + standHeight(f) + 1
	dip = math.clamp(dip or 0, 0, math.max(0, math.min(from.Y, to.Y) - floor))
	local look = flat(to - from)
	local done = {}
	local t0 = os.clock()
	while true do
		local u = math.min(1, (os.clock() - t0) / time)
		local e = u * u * (3 - 2 * u)
		placeRoot(f, from:Lerp(to, e) - UP * (4 * dip * u * (1 - u)), look.Magnitude > 0.1 and look or nil)
		sweep(self, hit, done)
		if u >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
		if not live(f) then
			return false, done
		end
	end
	return live(f), done
end

-- voo reto do HumanoidRootPart até um ponto no ar (subir, pairar, mergulhar). Não volta ao chão sozinho.
function Kit:glide(toRootPos, time, hit, look)
	self:grab()
	local ok, done = self:_glide(self:cap(toRootPos), time * self.speed, hit, look)
	self:release()
	return ok, done
end
function Kit:_glide(toRootPos, time, hit, look)
	local f = self.f
	local from = f.Root.Position
	local done = {}
	local dir = look or flat(toRootPos - from)
	local t0 = os.clock()
	while true do
		local u = math.min(1, (os.clock() - t0) / time)
		local e = u * u * (3 - 2 * u)
		placeRoot(f, from:Lerp(toRootPos, e), dir.Magnitude > 0.1 and dir or nil)
		sweep(self, hit, done)
		if u >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
		if not live(f) then
			return false, done
		end
	end
	return live(f), done
end

-- sobe `height` studs acima do chão e fica lá (para voltar: k:land). Mira do jogador: o corpo fica com o servidor
-- até o k:land (ou o fim da habilidade), senão ele cairia no meio
function Kit:rise(height, time)
	self:grab()
	self.risen += 1
	local goal
	if self.air then
		-- já voando: sobe só um pouco a partir de onde está
		goal = self.f.Root.Position + Vector3.new(0, math.min(height, 8), 0)
	else
		goal = groundAt(self.f.Root.Position) + Vector3.new(0, standHeight(self.f) + height, 0)
	end
	local ok, done = self:glide(goal, time)
	self:hold()
	return ok, done
end

-- desce até o chão (num ponto; padrão: embaixo de onde está). Voando: volta para a altura em que estava
function Kit:land(pos, time, hit)
	local f = self.f
	local p = self:clamp(self:cap(pos or f.Root.Position))
	local goal
	if self.air then
		goal = Vector3.new(p.X, self.airY, p.Z)
	else
		goal = groundAt(p) + Vector3.new(0, standHeight(f), 0)
	end
	local ok, done = self:glide(goal, time or 0.25, hit)
	if self.risen > 0 then
		self.risen -= 1
		if self.risen == 0 then
			self:unhold()
		end
		self:release()
	end
	return ok, done
end

-- corre em círculo em volta de um ponto (voltas, tempo total). hit = acerta quem passar perto
-- (hit.every = pode acertar o mesmo inimigo de novo a cada volta completa)
function Kit:circle(center, radius, laps, time, hit)
	self:grab()
	local ok, done = self:_circle(self:cap(center, radius), radius, laps, time * self.speed, hit)
	self:release()
	return ok, done
end
function Kit:_circle(center, radius, laps, time, hit)
	local f = self.f
	local rel = flat(f.Root.Position - center)
	local a0 = rel.Magnitude > 0.1 and math.atan2(rel.Z, rel.X) or 0
	local steps = math.max(8, math.floor(time / 0.04))
	local perLap = math.max(1, math.floor(steps / math.max(laps, 0.01)))
	local done = {}
	for i = 1, steps do
		if not live(f) then
			return false, done
		end
		local a = a0 + (i / steps) * laps * math.pi * 2
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
		if self.air then
			local q = self:clamp(center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius))
			placeRoot(f, Vector3.new(q.X, self.airY, q.Z), tangent)
		else
			local p = groundAt(self:clamp(center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)))
			placeRoot(f, p + Vector3.new(0, standHeight(f), 0), tangent)
		end
		if hit then
			if hit.every and i % perLap == 0 then
				done = {}
			end
			sweep(self, hit, done)
		end
		task.wait(time / steps)
	end
	return live(f), done
end

-- teleporte instantâneo para um ponto do chão (olhando para o alvo)
function Kit:tp(pos)
	local f = self.f
	if not live(f) then
		return false
	end
	self:grab()
	local p = self:clamp(self:cap(pos))
	if self.air then
		placeRoot(f, Vector3.new(p.X, self.airY, p.Z), self.t and flat(self.t.Root.Position - p) or nil)
	else
		Fighters.Teleport(f, groundAt(p))
		if self.t then
			Fighters.Face(f, self.t.Root.Position)
		end
	end
	self:release()
	return true
end

-- aparece do outro lado do alvo (atrás dele), olhando para ele
function Kit:behind(dist)
	local f, t = self.f, self.t
	local d = self:dir()
	self:grab()
	local p = self:clamp(self:cap(t.Root.Position + d * ((t.Radius or 1) + f.Radius + (dist or 2))))
	if self.air then
		placeRoot(f, Vector3.new(p.X, self.airY, p.Z), flat(t.Root.Position - p))
	else
		Fighters.Teleport(f, groundAt(p))
		Fighters.Face(f, t.Root.Position)
	end
	self:release()
	return live(f)
end

------------------------------------------------------------ tiros, chuva, áreas, criaturas
-- dano de um projétil que chegou em `p`: área (radius) ou o 1º inimigo perto do ponto
local function landHit(k, p, o, target)
	if not A(k.f) then
		return
	end
	local opts = o.opts and table.clone(o.opts) or { Color = o.color or k.color }
	if o.radius then
		local hits = Fighters.DamageArea(k.f, p, k:R(o.radius), k.power * (o.frac or 0.2), opts)
		if o.on then
			for _, e in ipairs(hits) do
				o.on(e)
			end
		end
		return
	end
	local best, bestD = nil, 3
	if target and A(target) and not target.Dummy and Fighters.Hostile(k.f, target) then
		local d = Fighters.FlatDistance(target.Root.Position, p) - (target.Radius or 1)
		if d < 4 then
			best, bestD = target, d
		end
	end
	if not best then
		for _, e in ipairs(Fighters.Enemies(k.f, p, 3)) do
			local d = Fighters.FlatDistance(e.Root.Position, p) - e.Radius
			if d < bestD then
				best, bestD = e, d
			end
		end
	end
	if best then
		k:dmg(best, o.frac or 0.2, opts)
		if o.on then
			o.on(best)
		end
	end
end

-- TIRO(S) com um objeto (Motif: Bone, Ball, Frisbee, Bubble, Note, Star, Missile...). Sai da boca.
-- o = { count, spread (graus do leque), speed (studs/s), arc (altura do arco), frac (cada tiro), radius (área no
-- impacto; sem = um alvo), size, color, color2, trail, impact, homing (persegue o alvo), back (bumerangue),
-- spin, gap (s entre tiros), points (lista de destinos), from, on(enemy) }. Devolve o tempo até o último chegar.
function Kit:shoot(motif, o)
	o = o or {}
	local f, t = self.f, self.t
	local count = o.count or (o.points and #o.points) or 1
	local from = o.from or self:mouth()
	local aim = t and t.Root.Position or (from + f.Root.CFrame.LookVector * 30)
	local base = flat(aim - from)
	local dist = math.max(4, base.Magnitude)
	base = base.Magnitude > 0.01 and base.Unit or flat(f.Root.CFrame.LookVector)
	local speed = (o.speed or 70) / self.speed
	local gap = (o.gap or 0) * self.speed
	local points, times, delays = {}, {}, {}
	local last = 0
	for i = 1, count do
		local p
		if o.points then
			p = o.points[i]
		else
			local ang = count > 1 and (o.spread or 0) * ((i - 1) / (count - 1) - 0.5) or 0
			p = groundAt(from + turn(base, ang) * dist)
			if o.homing and t and not t.Dummy and i == 1 and count == 1 then
				p = t.Root.Position
			end
		end
		points[i] = p
		times[i] = math.clamp((p - from).Magnitude / speed, 0.08, 2.5)
		delays[i] = (i - 1) * gap
		last = math.max(last, delays[i] + times[i] * (o.back and 2 or 1))
	end
	Fx("S_Shot", {
		Model = f.Model,
		From = from,
		Points = points,
		Times = times,
		Delays = delays,
		Motif = motif,
		Size = (o.size or 1) * math.sqrt(self.size),
		Color = o.color or self.color,
		Color2 = o.color2,
		Arc = o.arc,
		Spin = o.spin,
		Trail = o.trail,
		Impact = o.impact,
		Target = (o.homing and t and not t.Dummy) and t.Model or nil,
		Back = o.back,
		Radius = o.radius and self:R(o.radius) or nil,
	})
	for i = 1, count do
		task.delay(delays[i] + times[i], function()
			local p = points[i]
			if o.homing and t and A(t) and not t.Dummy then
				p = t.Root.Position
			end
			landHit(self, p, o, t)
		end)
		if o.back then
			-- bumerangue: acerta de novo na volta (no meio do caminho)
			task.delay(delays[i] + times[i] * 1.6, function()
				local mid = points[i]:Lerp(f.Root.Position, 0.4)
				local o2 = table.clone(o)
				o2.frac = (o.backFrac or o.frac or 0.2)
				o2.radius = o.radius or 4
				o2.on = nil
				landHit(self, mid, o2, nil)
			end)
		end
	end
	return last
end

-- CHUVA: objetos caindo do céu em pontos (com aviso no chão). o = { fall (s), gap (s entre quedas), radius,
-- frac (cada queda), size, color, impact, height, tele (false = sem aviso), on(enemy) }. Devolve o tempo total.
function Kit:rain(motif, points, o)
	o = o or {}
	local fall = (o.fall or 0.6) * self.speed
	local gap = (o.gap or 0.12) * self.speed
	local radius = o.radius or 5
	Fx("S_Rain", {
		Motif = motif,
		Points = points,
		Fall = fall,
		Gap = gap,
		Height = o.height or 40,
		Size = (o.size or 1) * math.sqrt(self.size),
		Color = o.color or self.color,
		Color2 = o.color2,
		Impact = o.impact,
		Radius = self:R(radius),
		Tele = o.tele ~= false,
		Spin = o.spin,
	})
	for i, p in ipairs(points) do
		task.delay((i - 1) * gap + fall, function()
			landHit(self, p, { radius = radius, frac = o.frac or 0.15, opts = o.opts, on = o.on, color = o.color }, nil)
		end)
	end
	return (#points - 1) * gap + fall
end

-- ÁREA que fica no chão por um tempo (poça, fogo, gelo, veneno, areia, flores...). Dano em tiques.
-- o = { every (s), color, on(enemy) a cada tique, opts }. frac = total de todos os tiques
function Kit:zone(kind, center, radius, duration, frac, o)
	o = o or {}
	local f = self.f
	duration *= self.speed
	local every = (o.every or 0.5) * self.speed
	local ticks = math.max(1, math.floor(duration / every))
	local r = self:R(radius)
	Fx("S_Zone", { Kind = kind, Position = center, Radius = r, Duration = duration, Color = o.color or self.color })
	task.spawn(function()
		for _ = 1, ticks do
			task.wait(every)
			if not A(f) then
				return
			end
			if frac and frac > 0 then
				local opts = o.opts and table.clone(o.opts) or { Color = o.color or self.color }
				local hits = Fighters.DamageArea(f, center, r, self.power * frac / ticks, opts)
				if o.on then
					for _, e in ipairs(hits) do
						o.on(e)
					end
				end
			elseif o.on then
				for _, e in ipairs(Fighters.Enemies(f, center, r)) do
					o.on(e)
				end
			end
		end
	end)
end

-- CRIATURAS (abelhas, fantasmas, lobos de raio, esqueletos, clones...) que saem do cachorro e atacam.
-- o = { count, time (s até chegar), frac (cada uma), radius (área ao chegar), color, size, path, gap, points, on }
function Kit:summon(kind, o)
	o = o or {}
	local f, t = self.f, self.t
	local count = o.count or 3
	local points = o.points
	if not points then
		points = {}
		local center = t and t.Root.Position or (f.Root.Position + f.Root.CFrame.LookVector * 20)
		for i = 1, count do
			local a = math.rad((i - 1) * 360 / count + self.rng:NextNumber(-20, 20))
			local r = count > 1 and self.rng:NextNumber(1, 4) or 0
			points[i] = groundAt(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		end
	end
	local time = (o.time or 0.8) * self.speed
	local gap = (o.gap or 0.15) * self.speed
	Fx("S_Summon", {
		Kind = kind,
		Model = f.Model,
		From = o.from or f.Root.Position,
		Points = points,
		Time = time,
		Gap = gap,
		Color = o.color or self.color,
		Size = (o.size or 1) * math.sqrt(self.size),
		Path = o.path,
		Target = (t and not t.Dummy) and t.Model or nil,
	})
	for i, p in ipairs(points) do
		task.delay((i - 1) * gap + time, function()
			landHit(self, p, { radius = o.radius or 4, frac = o.frac or 0.15, opts = o.opts, on = o.on, color = o.color }, nil)
		end)
	end
	return (#points - 1) * gap + time
end

-- RAIO/JATO contínuo da boca até um ponto. o = { length, width, time (segura), ticks, frac (total), color,
-- color2, from, on } — acerta em tiques quem estiver na linha
function Kit:beam(kind, o)
	o = o or {}
	local f = self.f
	local length = o.length or 30
	local width = o.width or 4
	local time = (o.time or 0.8) * self.speed
	local ticks = o.ticks or 3
	local from = o.from or self:mouth()
	local dir = o.dir or self:dir()
	Fx("S_Beam", {
		Kind = kind,
		Model = f.Model,
		From = from,
		To = from + dir * length,
		Width = self:R(width),
		Duration = time,
		Color = o.color or self.color,
		Color2 = o.color2,
		Sweep = o.sweep,
	})
	for i = 1, ticks do
		if not live(f) then
			return false
		end
		task.wait(time / ticks)
		local d = dir
		if o.sweep then
			d = turn(dir, o.sweep * ((i / ticks) - 0.5) * 2)
		end
		self:inLine(flat(f.Root.Position), d, length, width, (o.frac or 0.3) / ticks, o.opts, o.on)
	end
	return live(f)
end

-- SOPRO em cone da boca (fogo, gelo, vento, perfume, veneno, som...). Segue o alvo enquanto sopra.
-- o = { length, angle, time, ticks, frac (total), color, on }
function Kit:breath(kind, o)
	o = o or {}
	local f, t = self.f, self.t
	local length = o.length or 16
	local angle = o.angle or 30
	local time = (o.time or 1) * self.speed
	local ticks = o.ticks or 4
	Fx("S_Cone", { Kind = kind, Model = f.Model, Length = self:R(length), Angle = angle, Duration = time, Color = o.color or self.color })
	for _ = 1, ticks do
		task.wait(time / ticks)
		if not live(f) then
			return false
		end
		if t and valid(f, t) and not self.aim then
			Fighters.Face(f, t.Root.Position)
		end
		-- mira do jogador: o sopro vai para a setinha (o corpo é dele: pode estar andando para o lado)
		local look = self.aim and self:dir() or flat(f.Root.CFrame.LookVector)
		self:inCone(flat(f.Root.Position), look, length, angle, (o.frac or 0.3) / ticks, o.opts, o.on)
	end
	return live(f)
end

-- ONDA que anda pelo chão em linha (água, areia, choque, som, fogo...). Cada inimigo leva o golpe quando a
-- onda passa por ele. o = { length, width, speed, frac, color, on, from, dir }
function Kit:wave(kind, o)
	o = o or {}
	local f = self.f
	local from = o.from or self:feet()
	local dir = o.dir or self:dir()
	local length = o.length or 30
	local width = o.width or 8
	local speed = (o.speed or 50) / self.speed
	if not o.silent then
		Fx("S_Wave", { Kind = kind, Position = from, Dir = dir, Length = length, Width = self:R(width), Speed = speed, Color = o.color or self.color })
	end
	local list = self:inLine(flat(from), dir, length, width, 0)
	for _, e in ipairs(list) do
		local along = flat(e.Root.Position - from):Dot(dir)
		task.delay(math.max(0, along) / speed, function()
			if A(f) and A(e) then
				self:dmg(e, o.frac or 0.3, o.opts and table.clone(o.opts) or nil)
				if o.on then
					o.on(e)
				end
			end
		end)
	end
	return length / speed
end

return SkillKit
