-- ⭐ GOLPES PRÓPRIOS DOS MÍTICOS E DO DIVINO, REFEITOS (2026-10, pedido do dono: "onde estiver a seta o ataque vai,
-- não quero mais ataques que o cachorro vai até lá, sempre que tento lançar um ataque trava, tem que ser rápido").
-- Os 19 golpes próprios (tecla 2) eram poderes antigos (Specials.lua, SpecialsPacks/PackC e PackD) que levavam o
-- cachorro até o inimigo e prendiam o controle. Agora são habilidades do kit (SkillKit): o mesmo desenho de antes
-- (os efeitos C_*, Meteor, Vortex... do cliente), mas saem NA SETINHA, rápidas e sem prender o cachorro.
-- Os poderes antigos continuam guardados para os bosses (DogData.BOSSES). Frações somam ~1 do orçamento da tecla 2.
local SkillKit = require(script.Parent.Parent.SkillKit)

local C = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local G = SkillKit.Ground

local function side(d)
	return Vector3.new(-d.Z, 0, d.X)
end

local function flatDist(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

return function(Specials, Fighters)
	local function def(id, fn)
		SkillKit.def(Specials, id, 2, fn)
	end

	------------------------------------------------------------ Shadow Cerberus: Hell Gate
	-- portal do inferno na setinha: 3 cabeças espectrais mordem, sombras pontudas brotam e jogam para cima
	local HELL = C(255, 50, 90)
	def("SK_shadow_cerberus_2", function(k)
		k:face()
		k:pose("Roar", 0.6)
		k:fx("Roar", { Model = k.f.Model, Color = C(255, 40, 80) })
		local c = k:tground()
		k:fx("Circle", { Position = c, Radius = k:R(9), Color = C(200, 20, 60), Duration = 1.8, Kind = "hell" })
		if not k:wait(0.3) then
			return
		end
		for h = 1, 3 do
			local a = h / 3 * math.pi * 2 + k:rand(0, 1)
			local from = c + Vector3.new(math.cos(a), 0, math.sin(a)) * k:R(8) + UP
			k:fx("SpectralBite", { From = from, To = c + UP * 2, Color = HELL, Big = h == 3 })
			k:later(0.2, function()
				k:area(c, 5, h == 3 and 0.25 or 0.12, { Color = HELL })
			end)
			if not k:wait(0.16) then
				return
			end
		end
		k:fx("Spikes", { Positions = k:around(c, k:R(6), 10, 0), Color = C(40, 10, 30), Height = 9, Interval = 0.03, Kind = "shadow" })
		if not k:wait(0.25) then
			return
		end
		k:fx("Explosion", { Position = c + UP, Radius = k:R(8), Color = C(200, 20, 60), Kind = "void" })
		k:shake(c, 0.5, 50, 0.3)
		k:area(c, 9, 0.5, { KnockbackPower = 10, Lift = 40, Color = HELL })
	end)

	------------------------------------------------------------ Titan Mastiff: Titan Rage
	-- urra e vira TITÃ por alguns segundos (cresce, bate mais forte, cada mordida faz o chão tremer — CombatService
	-- lê f.Raging); a pisada solta rachaduras douradas que correm até a setinha e explodem lá
	local GOLD = C(255, 210, 120)
	local RAGE_TIME = 7
	local RAGE_DAMAGE = 1.3
	local TITAN_HEIGHT = 14 -- altura máxima do titã (studs): cachorro pequeno cresce mais, grande cresce menos

	local function titanSize(f)
		local s = f.ScaleNow or 1
		local base = (f.HipHeight or f.Humanoid.HipHeight / s) + f.Root.Size.Y / s * 1.5
		return math.clamp(TITAN_HEIGHT / math.max(base, 1), 1.5, 3)
	end
	-- muda a escala erguendo o corpo antes, para as patas não afundarem no chão
	local function titanScale(f, factor)
		local old = f.ScaleNow or 1
		if factor > old then
			local rootY = f.Root.Size.Y / old
			local lift = ((f.HipHeight or 2) + rootY / 2) * (factor - old)
			f.Model:PivotTo(f.Model:GetPivot() + UP * lift)
		end
		Fighters.Scale(f, factor)
	end
	local function titanEnd(f, token)
		while f.RageToken == token and Fighters.Alive(f) and os.clock() < (f.Raging or 0) do
			task.wait(0.25)
		end
		if f.RageToken ~= token then
			return
		end
		f.RageToken = nil
		f.Raging = nil
		f.DamageDealt = (f.DamageDealt or RAGE_DAMAGE) / RAGE_DAMAGE
		if not Fighters.Alive(f) then
			return
		end
		f.Model:SetAttribute("Raging", nil)
		local from = f.ScaleNow or 1
		for i = 1, 4 do
			if not Fighters.Alive(f) or f.RageToken then
				return
			end
			Fighters.Scale(f, from + (1 - from) * i / 4)
			task.wait(0.08)
		end
		Fighters.Fx("Smoke", { Position = SkillKit.Ground(f.Root.Position), Color = C(200, 180, 140), Size = 6 })
	end

	def("SK_titan_mastiff_2", function(k)
		local f = k.f
		k:face()
		k:pose("Roar", 0.7)
		k:fx("Roar", { Model = f.Model, Color = GOLD })
		k:shake(k:me(), 0.8, 90, 0.5)
		k:shock(k:feet(), 10, GOLD, true)
		if not f.RageToken then
			local token = {}
			f.RageToken = token
			local from, target = f.ScaleNow or 1, titanSize(f)
			-- crescer mexe no corpo: o servidor segura só neste instante
			k:grab()
			for i = 1, 4 do
				if not k:alive() then
					break
				end
				titanScale(f, from + (target - from) * i / 4)
				if i % 2 == 0 then
					k:fx("TitanGrow", { Model = f.Model })
				end
				task.wait(0.06 * k.speed)
			end
			k:release()
			local seconds = k:secs(RAGE_TIME)
			f.Raging = os.clock() + seconds
			f.DamageDealt = (f.DamageDealt or 1) * RAGE_DAMAGE
			f.Model:SetAttribute("Raging", true)
			Fighters.Fx("TitanAura", { Model = f.Model, Duration = seconds })
			task.spawn(titanEnd, f, token)
		end
		if not k:alive() then
			return
		end
		k:pose("Stomp", 0.4)
		local g, c = k:feet(), k:tground()
		local d = k:dir(c)
		local len = math.max(8, k:dist(c))
		k:path("Crack", g, c, { Duration = 1.4, Width = 3, Color = GOLD })
		local travel = k:wave("Spikes", { from = g, dir = d, length = len, width = 7, speed = 75, frac = 0.4, color = GOLD, on = function(e)
			k:launch(e, 25)
		end })
		if not k:wait(travel / k.speed) then
			return
		end
		k:impact(c, 8, GOLD, true)
		k:pillar("Rock", c, 3, { Height = 12, Color = GOLD })
		k:area(c, 8, 0.6, { KnockbackPower = 35, Lift = 30, Color = GOLD })
	end)

	------------------------------------------------------------ Cosmic Dog: Starfall
	-- flutua brilhando e estrelas caem na setinha (a 1ª, a do meio e a última bem no centro)
	local STAR = C(255, 240, 160)
	def("SK_cosmic_dog_2", function(k)
		k:face()
		k:pose("Float", 1.2)
		k:fx("EyeGlow", { Model = k.f.Model, Color = STAR, Duration = 1.2, Body = true })
		k:orbit("Star", { Count = 4, Radius = 3, Duration = 1, Color = STAR })
		if not k:wait(0.2) then
			return
		end
		local c = k:tground()
		local around = k:scatter(c, k:R(7), 4)
		local pts = { c, around[1], around[2], c, around[3], around[4], c }
		k:rain("Comet", pts, { fall = 0.45, gap = 0.1, radius = 5, frac = 0.2, size = 1.2, color = STAR })
		k:wait(0.35)
	end)

	------------------------------------------------------------ Phoenix Hound: Phoenix Dive
	-- as asas pegam fogo, ela sobe e mergulha em chamas na direção da setinha (até onde alcança); o chão explode
	local FIRE = C(255, 130, 30)
	def("SK_phoenix_hound_2", function(k)
		k:face()
		k:pose("Fly", 0.9)
		k:fx("PhoenixRise", { Model = k.f.Model, Duration = 0.9 })
		local land = k:tground()
		k:tele(land, 9, 0.4, FIRE)
		if not k:wait(0.15) then
			return
		end
		k:fx("Streak", { Model = k.f.Model, Color = C(255, 110, 20), Duration = 0.7, Width = 3, Neon = true, Lifetime = 0.5, Sparks = true })
		if not k:leap(land, 12, 0.45, { frac = 0.2, radius = 4, opts = { Color = FIRE } }) then
			return
		end
		local spot = k:feet()
		k:pose("Slam", 0.4)
		k:fx("Explosion", { Position = spot + UP, Radius = k:R(10), Color = FIRE })
		k:fx("Lava", { Position = spot, Radius = k:R(6), Duration = 2.5 })
		k:fx("FireRing", { Position = spot, Radius = k:R(8), Duration = 1.2 })
		k:shake(spot, 0.6, 60, 0.35)
		for _, e in ipairs(k:area(spot, 10, 0.65, { KnockbackPower = 45, Lift = 25, Color = FIRE })) do
			k:dot(e, 2, 0.15, "Burn")
		end
	end)

	------------------------------------------------------------ Void Beast: Void Rift
	-- buraco negro na setinha: puxa todo mundo para o centro, tritura e implode
	local VOID = C(170, 90, 255)
	def("SK_void_beast_2", function(k)
		k:face()
		k:pose("Roar", 0.6)
		k:fx("Roar", { Model = k.f.Model, Color = VOID })
		local c = k:tground()
		k:fx("Vortex", { Position = c, Radius = k:R(14), Duration = 1.6 })
		for i = 1, 6 do
			if not k:wait(0.17) then
				return
			end
			for _, e in ipairs(k:enemies(c, k:R(18))) do
				k:pull(e, c, 30, 0.18)
			end
			if i % 2 == 0 then
				k:area(c, 6, 0.06, { Color = VOID })
			end
		end
		k:fx("Explosion", { Position = c + UP * 1.5, Radius = k:R(11), Color = C(150, 70, 255), Kind = "void" })
		k:shake(c, 0.8, 70, 0.4)
		k:area(c, 11, 0.8, { KnockbackPower = 60, Lift = 30, Color = C(190, 130, 255) })
	end)

	------------------------------------------------------------ Hydra Hound: Hydra Frenzy
	-- as 5 cabeças esticam como cobras e mordem a setinha de 5 lados; no fim mordem juntas. Cada mordida que acerta
	-- cura um pouco. Setinha longe: um bote curto antes (as cabeças esticam até ~18 studs)
	local VENOM = C(150, 255, 120)
	def("SK_hydra_hound_2", function(k)
		k:lunge(k:R(14))
		if not k:alive() then
			return
		end
		k:face()
		k:pose("Rear", 0.8)
		k:fx("Roar", { Model = k.f.Model, Color = VENOM })
		local c = k:tpos()
		local heads = math.max(1, k.f.Model:GetAttribute("Heads") or 5)
		local hits = 0
		for _, h in ipairs({ 4, 1, 2, 3, 5 }) do
			local p = c + Vector3.new(k:rand(-1.5, 1.5), 0, k:rand(-1.5, 1.5))
			k:fx("C_HydraNeck", { Model = k.f.Model, Head = (h - 1) % heads + 1, To = p, Color = VENOM, Duration = 0.45 })
			k:later(0.13, function()
				k:fx("BiteMark", { Position = p, Direction = k:dir(p), Color = VENOM })
				hits += #k:area(G(p), 5, 0.1, { Color = VENOM })
			end)
			if not k:wait(0.1) then
				return
			end
		end
		if not k:wait(0.12) then
			return
		end
		k:pose("Charge", 0.4)
		for h = 1, heads do
			k:fx("C_HydraNeck", { Model = k.f.Model, Head = h, To = c, Color = VENOM, Duration = 0.5 })
		end
		if not k:wait(0.15) then
			return
		end
		k:impact(G(c), 7, VENOM, true)
		hits += #k:area(G(c), 6, 0.5, { KnockbackPower = 35, Lift = 20, Color = VENOM })
		if hits > 0 then
			k:fx("C_Heal", { Model = k.f.Model, Color = VENOM })
			k:heal(math.min(0.12, 0.02 * hits))
		end
	end)

	------------------------------------------------------------ Bone Dragon: Bone Cage
	-- desmonta numa pilha de ossos; os ossos remontam na setinha como uma gaiola de costelas que prende e esmaga
	local GHOST = C(90, 255, 200)
	def("SK_bone_dragon_2", function(k)
		k:face()
		k:pose("Vanish", 0.5)
		k:fx("C_BonePile", { Position = k:feet(), Mode = "fall", Color = GHOST })
		local c = k:tground()
		k:tele(c, 7, 0.35, GHOST)
		if not k:wait(0.3) then
			return
		end
		k:fx("C_BonePile", { Position = c, Mode = "rise", Color = GHOST })
		k:fx("C_BonePile", { Position = k:feet(), Mode = "rise", Color = GHOST })
		k:pose("Rear", 0.7)
		k:fx("C_RibCage", { Position = c, Radius = k:R(6), Duration = 1.4 })
		for _, e in ipairs(k:enemies(c, k:R(6))) do
			k:stun(e, 1.1, "Cage", GHOST)
		end
		for _ = 1, 2 do
			if not k:wait(0.25) then
				return
			end
			k:area(c, 6, 0.15, { Color = GHOST })
		end
		if not k:wait(0.25) then
			return
		end
		k:shock(c, 10, GHOST, true)
		k:impact(c, 7, GHOST, true)
		k:area(c, 7, 0.7, { KnockbackPower = 25, Lift = 40, Color = GHOST })
	end)

	------------------------------------------------------------ Kraken Hound: Kraken Grab
	-- tentáculos gigantes saem do chão na setinha, agarram, levantam e esmagam no chão; jato de tinta no fim
	local INK = C(255, 120, 200)
	def("SK_kraken_hound_2", function(k)
		k:face()
		k:pose("Roar", 0.6)
		k:fx("Roar", { Model = k.f.Model, Color = INK })
		local c = k:tground()
		k:tele(c, 7, 0.3, C(120, 200, 230))
		if not k:wait(0.25) then
			return
		end
		k:fx("C_Tentacles", { Position = c, Radius = k:R(6), Count = 6, Duration = 1.6 })
		k:shake(c, 0.4, 60, 0.35)
		if not k:wait(0.3) then
			return
		end
		local grabbed = k:area(c, 7, 0.3, { Color = INK })
		for _, e in ipairs(grabbed) do
			k:stun(e, 0.9, "Grab", INK)
			k:launch(e, 38)
		end
		if not k:wait(0.45) then
			return
		end
		for _, e in ipairs(grabbed) do
			k:launch(e, -90)
		end
		if not k:wait(0.1) then
			return
		end
		k:impact(c, 9, INK, true)
		k:fx("C_Ink", { Position = c, Radius = k:R(8) })
		k:area(c, 9, 0.7, { KnockbackPower = 30, Lift = 15, Color = INK })
	end)

	------------------------------------------------------------ Chrono Hound: Time Stop
	-- relógio gigante no céu da setinha e o tempo para lá; imagens dele cortam o alvo de 5 lados e, quando o tempo
	-- volta, todos os cortes acontecem juntos
	local TIME = C(150, 210, 255)
	def("SK_chrono_hound_2", function(k)
		k:face()
		k:pose("Howl", 0.6)
		k:fx("Roar", { Model = k.f.Model, Color = TIME, Howl = true })
		local c = k:tground()
		local r = k:R(14)
		k:fx("C_TimeStop", { Position = c, Radius = r, Duration = 1.9 })
		for _, e in ipairs(k:enemies(c, r)) do
			k:stun(e, 1.2, "Time", TIME)
		end
		k:fx("C_AfterImage", { Model = k.f.Model, Duration = 1.2 })
		local stored = {}
		for i = 1, 5 do
			if not k:wait(0.12) then
				return
			end
			local a = i / 5 * math.pi * 2 + k:rand(0, 0.6)
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			k:fx("Slash", { Position = c + UP * 2, Direction = d, Color = TIME, Size = 6 })
			table.insert(stored, d)
		end
		if not k:wait(0.35) then
			return
		end
		for _, d in ipairs(stored) do
			k:fx("Slash", { Position = c + UP * 2, Direction = d, Color = C(235, 245, 255), Size = 9 })
		end
		k:fx("Explosion", { Position = c + UP, Radius = k:R(8), Color = TIME, Kind = "void" })
		k:shake(c, 0.6, 60, 0.3)
		k:area(c, 8, 0.5, { KnockbackPower = 45, Lift = 25, Color = TIME, Crit = true }) -- crítico: dano em dobro
	end)

	------------------------------------------------------------ Singularity Pup: Event Horizon
	-- um buraco negro nasce na setinha (no alvo invisível dela): suga, tritura em órbita e cospe longe num buraco branco
	local HORIZON = C(255, 160, 70)
	def("SK_singularity_pup_2", function(k)
		k:face()
		k:pose("Float", 1.4)
		local holeModel = k.aim and k.t.Model or k.f.Model
		k:fx("C_Singularity", { Model = holeModel, Duration = 1.5, Radius = k:R(11) })
		for i = 1, 6 do
			if not k:wait(0.18) then
				return
			end
			local center = k.aim and k:tground() or k:feet()
			for _, e in ipairs(k:enemies(center, k:R(20))) do
				k:pull(e, center, 34, 0.18)
			end
			if i % 2 == 0 then
				k:area(center, 5, 0.06, { Color = HORIZON })
			end
		end
		local center = k.aim and k:tground() or k:feet()
		k:fx("C_WhiteHole", { Position = center, Radius = k:R(9) })
		k:shake(center, 0.7, 60, 0.35)
		k:area(center, 9, 0.8, { KnockbackPower = 90, Lift = 40, Color = C(255, 245, 230) })
	end)

	------------------------------------------------------------ Seraph Hound: Divine Judgement
	-- abre as 6 asas; 6 colunas de luz cercam a setinha, fecham no centro e viram uma coluna sagrada; cura um pouco
	local HOLY = C(255, 225, 120)
	def("SK_seraph_hound_2", function(k)
		k:face()
		k:pose("Float", 1.2)
		k:fx("EyeGlow", { Model = k.f.Model, Color = HOLY, Duration = 1.2, Body = true })
		local c = k:tground()
		local dur = 1.2
		k:fx("C_Judgement", { Position = c, Radius = k:R(10), Duration = dur })
		for i = 1, 3 do
			if not k:wait(dur / 4) then
				return
			end
			k:area(c, 10 * (1 - i / 4) + 2, 0.12, { Color = HOLY })
		end
		if not k:wait(dur / 4) then
			return
		end
		k:pillar("Holy", c, 4, { Height = 30, Color = C(255, 240, 180) })
		k:area(c, 6, 0.6, { KnockbackPower = 20, Lift = 35, Color = HOLY })
		k:heal(0.06)
	end)

	------------------------------------------------------------ Crystal Golem: Crystal Prison
	-- soca o chão: espinhos de cristal correm até a setinha e prendem quem está lá num cristal gigante; um cristal
	-- enorme cai do céu e estilhaça a prisão
	local CRY = C(80, 245, 225)
	def("SK_crystal_golem_2", function(k)
		k:face()
		k:pose("Slam", 0.45)
		k:shock(k:feet(), 10, CRY, true)
		k:shake(k:me(), 0.6, 70, 0.35)
		local origin, c = k:feet(), k:tground()
		local d = k:dir(c)
		local pts = {}
		for i = 1, math.clamp(math.floor(k:dist(c) / 4), 1, 14) do
			table.insert(pts, G(origin + d * (i * 4)))
		end
		k:fx("Spikes", { Positions = pts, Color = CRY, Height = 4, Interval = 0.03 })
		-- (os espinhos têm o ritmo próprio deles: a espera acompanha)
		if not k:wait(math.min(0.4, #pts * 0.03) / k.speed) then
			return
		end
		local jailed = k:enemies(c, k:R(6))
		k:area(c, 6, 0.3, { Color = CRY })
		for _, e in ipairs(jailed) do
			k:fx("C_CrystalPrison", { Model = e.Model, Duration = 1.2 })
			k:stun(e, 1, "Stone", CRY)
		end
		if #jailed == 0 then
			k:fx("C_CrystalPrison", { Model = k.t.Model, Duration = 0.8 })
		end
		if not k:wait(0.45) then
			return
		end
		k:pose("Stomp", 0.4)
		k:rain("Crystal", { c }, { fall = 0.3, radius = 8, frac = 0.7, size = 2.5, color = CRY })
		k:later(0.3, function()
			k:fx("C_CrystalShatter", { Position = c })
		end)
		k:wait(0.3)
	end)

	------------------------------------------------------------ Frost Phoenix: Glacial Rebirth
	-- vira um ovo de gelo (quase não leva dano) e se cura; o ovo racha numa tempestade de penas de gelo em volta e
	-- uma rajada de penas voa até a setinha congelando
	local ICE = C(170, 225, 255)
	def("SK_frost_phoenix_2", function(k)
		k:face()
		k:pose("Crouch", 0.6)
		k:fx("C_IceEgg", { Model = k.f.Model, Duration = 0.7 })
		k:shield(0.8, 0.85, "Ice", ICE)
		k:heal(0.1)
		if not k:wait(0.45) then
			return
		end
		k:pose("Fly", 0.6)
		k:fx("C_FeatherStorm", { Position = k:me(), Count = 10, Radius = k:R(10) })
		for _, e in ipairs(k:area(k:feet(), 10, 0.3, { KnockbackPower = 25, Lift = 15, Color = ICE })) do
			k:freeze(e, 1)
		end
		local c = k:tground()
		k:shoot("Feather", { points = k:scatter(c, 3, 6, true), speed = 85, gap = 0.04, frac = 0.15, radius = 3, color = ICE, trail = true, on = function(e)
			k:slow(e, 1.5, 0.6)
		end })
		k:later(0.4, function()
			k:fx("C_FeatherStorm", { Position = c + UP * 2, Count = 5, Radius = 4 })
		end)
		k:wait(0.3)
	end)

	------------------------------------------------------------ Thunder Colossus: Thunder Wall
	-- a nuvem das costas descarrega nele; 3 pisadas, cada uma solta um muro de raios que marcha até a setinha
	local VOLT = C(255, 230, 80)
	def("SK_thunder_colossus_2", function(k)
		k:face()
		k:pose("Rear", 0.45)
		k:fx("C_RodStrike", { Model = k.f.Model })
		if not k:wait(0.3) then
			return
		end
		local fracs = { 0.25, 0.25, 0.5 }
		for i = 1, 3 do
			k:pose("Stomp", 0.3)
			local origin, c = k:feet(), k:tground()
			local d = k:dir(c)
			local len = math.min(k:dist(c) + 8, 60)
			local width = 8 + i * 2
			k:shock(origin, 7, VOLT)
			k:fx("C_ThunderWall", { From = origin + d * k.f.Radius, Direction = d, Length = len, Width = k:R(width), Duration = 0.45 })
			k:shake(origin, 0.5, 80, 0.3)
			k:wave("Shock", { from = origin, dir = d, length = len, width = width, speed = 90, frac = fracs[i], silent = true, color = VOLT, on = function(e)
				if i == 3 then
					k:stun(e, 0.5, "Shock", VOLT)
				end
			end })
			if not k:wait(0.28) then
				return
			end
		end
	end)

	------------------------------------------------------------ Rainbow Unicorn: Rainbow Bridge
	-- um arco-íris nasce até a setinha (até onde alcança); galopa por cima e cai com o chifre numa explosão de cores
	local PINK = C(255, 160, 230)
	def("SK_rainbow_unicorn_2", function(k)
		k:face()
		k:pose("Crouch", 0.3)
		local from = k:feet()
		local to = G(k:clamp(k:cap(k:tground())))
		local height = math.clamp((to - from).Magnitude * 0.45, 6, 14)
		k:fx("C_Rainbow", { From = from, To = to, Height = height, Duration = 1.4 })
		k:tele(to, 8, 0.5, PINK)
		if not k:wait(0.2) then
			return
		end
		k:pose("Dash", 0.6)
		if not k:leap(to, height, 0.45, { frac = 0.15, radius = 4, opts = { Color = PINK } }) then
			return
		end
		local spot = k:feet()
		k:fx("C_Prism", { Position = spot, Radius = k:R(9) })
		k:shake(spot, 0.5, 50, 0.3)
		for _, e in ipairs(k:area(spot, 9, 0.85, { KnockbackPower = 40, Lift = 30, Color = PINK })) do
			k:stun(e, 0.4, "Dizzy", PINK)
		end
	end)

	------------------------------------------------------------ Demon Samurai: Oni Blades
	-- as 4 katanas voam dos braços de demônio, giram em volta da setinha cortando e voltam num corte final em X
	local ONI = C(255, 60, 60)
	def("SK_demon_samurai_2", function(k)
		k:face()
		k:pose("Roar", 0.4)
		k:fx("Roar", { Model = k.f.Model, Color = ONI })
		k:fx("C_Blades", { Model = k.f.Model, Target = k.t.Model, Duration = 1.5, Count = 4 })
		if not k:wait(0.25) then
			return
		end
		for _ = 1, 5 do
			k:area(k:tground(), 6, 0.09, { Color = ONI })
			if not k:wait(0.18) then
				return
			end
		end
		k:pose("Slash", 0.35)
		local c = k:tground()
		local d = k:dir(c)
		local right = side(d)
		k:fx("Slash", { Position = c + UP * 2, Direction = (d + right).Unit, Color = ONI, Size = 11 })
		k:fx("Slash", { Position = c + UP * 2, Direction = (d - right).Unit, Color = ONI, Size = 11 })
		k:impact(c, 6, ONI)
		k:area(c, 7, 0.55, { KnockbackPower = 40, Lift = 20, Color = ONI })
	end)

	------------------------------------------------------------ Mecha Hound: Missile Barrage
	-- trava a mira na setinha, abre os casulos e 8 mísseis sobem e caem lá; termina com o canhão de plasma
	local MECH = C(255, 160, 60)
	local PLASMA = C(80, 230, 255)
	def("SK_mecha_hound_2", function(k)
		k:face()
		k:pose("Aim", 1.4)
		k:fx("EyeGlow", { Model = k.f.Model, Color = PLASMA, Duration = 0.4 })
		local c = k:tground()
		local count, flight, gap = 8, 0.75, 0.06
		k:mark(k.t, "Reticle", 1.2 * k.speed, C(255, 80, 60))
		k:fx("C_Missiles", { Model = k.f.Model, Target = k.t.Model, Position = k:tpos(), Count = count, Flight = flight * k.speed, Interval = gap * k.speed })
		for i = 1, count do
			k:later((i - 1) * gap + flight, function()
				k:area(k:real() and k:tground() or c, 4, 0.08, { Color = MECH })
			end)
		end
		if not k:wait(flight + count * gap) then
			return
		end
		k:face()
		local to = k:real() and k:tpos() or c + UP
		k:fx("C_Cannon", { Model = k.f.Model, To = to })
		k:inLine(k:me(), k:dir(to), k:dist(to) + 4, 5, 0.36, { Color = PLASMA }, function(e)
			k:knock(e, k:me(), 45, 20)
		end)
	end)

	------------------------------------------------------------ Planet Hound: Moonfall
	-- a lua sai da órbita, cresce no céu e cai na setinha; os anéis viram uma onda que pega quem escapou da cratera
	local MOON = C(230, 220, 200)
	def("SK_planet_hound_2", function(k)
		k:face()
		k:pose("Howl", 0.8)
		k:fx("Roar", { Model = k.f.Model, Color = C(150, 200, 255), Howl = true })
		local c = k:tground()
		local r = k:R(8)
		local delay = 0.9
		k:fx("C_MoonFall", { Model = k.f.Model, Position = c, Delay = delay * k.speed, Radius = r })
		k:tele(c, 8, delay, C(255, 200, 150))
		if not k:wait(delay) then
			return
		end
		k:shake(c, 1, 80, 0.5)
		k:area(c, 8, 0.75, { KnockbackPower = 55, Lift = 35, Color = MOON })
		if not k:wait(0.2) then
			return
		end
		k:shock(c, 16, C(200, 220, 255), true)
		for _, e in ipairs(k:enemies(c, r * 2)) do
			if flatDist(e.Root.Position, c) > r then
				k:dmg(e, 0.3, { Color = MOON })
				k:knock(e, c, 35, 15)
			end
		end
	end)

	------------------------------------------------------------ ☀️ Sun Dragon: Sunfire Breath
	-- raio de fogo solar dourado varrendo na direção da setinha; um pequeno sol cai lá, explode e cura
	local SUN = C(255, 200, 70)
	def("SK_sun_dragon_2", function(k)
		k:face()
		k:pose("Open", 1)
		k:charge(0.3, SUN)
		if not k:wait(0.2) then
			return
		end
		local c = k:tground()
		local burned = {}
		k:beam("Sun", { length = math.clamp(k:dist(c) + 6, 16, 44), width = 5, time = 0.8, ticks = 4, frac = 0.45, sweep = 28, color = SUN, color2 = C(255, 120, 40), on = function(e)
			if not burned[e] then
				burned[e] = true
				k:dot(e, 2, 0.1, "Burn")
			end
		end })
		if not k:alive() then
			return
		end
		k:rain("Sun", { c }, { fall = 0.35, radius = 8, frac = 0.45, size = 1.6, color = SUN })
		k:later(0.35, function()
			k:fx("Explosion", { Position = c + UP, Radius = k:R(9), Color = SUN })
			k:shock(c, 11, C(255, 90, 60), true)
			k:shake(c, 0.7, 60, 0.35)
		end)
		k:heal(0.08)
		k:wait(0.35)
	end)
end
