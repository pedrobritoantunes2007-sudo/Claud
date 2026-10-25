-- 🐶 HABILIDADES DOS COMUNS (2026-10). Regra do dono: comum = SIMPLES e FRACO — um golpe só, efeito pequeno,
-- fofo e engraçado (graveto, barrigada, ronco, latido). A força vem do orçamento da raridade (Config.SKILL_TIER):
-- aqui só as frações de cada golpe (somam ~1). Kit: server/Services/SkillKit.lua · nomes: shared/Skills.lua.
local SkillKit = require(script.Parent.Parent.SkillKit)

local C = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local G = SkillKit.Ground

return function(Specials, _Fighters)
	local function def(id, slot, fn)
		SkillKit.def(Specials, id, slot, fn)
	end

	------------------------------------------------------------ Caramel Mutt (vira-lata caramelo)
	-- joga o graveto com a boca e corre para pegar no ar
	def("SK_caramelo_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Throw", 0.5)
		if not k:wait(0.22) then
			return
		end
		local land = k:tground()
		local t = k:shoot("Stick", { points = { land }, speed = 50, arc = 5, frac = 0.55, radius = 3, size = 1.1 })
		k:pose("Dash", t + 0.5)
		if not k:wait(t * 0.6) then
			return
		end
		k:pose("Leap", 0.5)
		if not k:leap(land, 3, 0.4, { frac = 0.45, radius = 3, opts = { Knockback = k:dir(land) * 18 + UP * 10 } }) then
			return
		end
		k:pose("Victory", 0.5)
		k:pop("FETCH!", nil, C(255, 220, 120), 0.8)
	end)

	-- vira de costas, cava e chuta terra para trás (deixa lento)
	def("SK_caramelo_3", 3, function(k)
		k:stop()
		local d = k:dir()
		k:face(k:me() - d * 5)
		k:pose("Dig", 0.6)
		k:burst("Dirt", k:feet(), { Count = 5 })
		if not k:wait(0.55) then
			return
		end
		k:pose("Kick", 0.6)
		if not k:wait(0.18) then
			return
		end
		local from = k:feet()
		k:burst("Dirt", from + d * 1.5, { Count = 14, Dir = d + UP * 0.4, Cone = 0.45, Radius = 10 })
		k:wave("Sand", {
			from = from,
			dir = d,
			length = 15,
			width = 7,
			speed = 40,
			frac = 0.7,
			color = C(170, 130, 80),
			on = function(e)
				k:slow(e, 2, 0.6)
			end,
		})
		k:shoot("Rock", { from = from + UP * 1.5, count = 3, spread = 30, speed = 45, arc = 3, frac = 0.1, size = 0.5 })
	end)

	------------------------------------------------------------ Pug
	-- pulinho e barrigada em cima do inimigo (BONK!)
	def("SK_pug_2", 2, function(k)
		if not k:approach(8, 1) then
			return
		end
		k:face()
		k:pose("Crouch", 0.3)
		k:tele(k:tground(), 6, 0.6)
		if not k:wait(0.3) then
			return
		end
		k:pose("Belly", 0.7)
		if not k:leap(k:tpos(), 6, 0.45) then
			return
		end
		local g = k:feet()
		k:impact(g, 6, C(225, 190, 140))
		k:pop("BONK!", nil, C(255, 200, 120))
		k:area(g, 6, 1, { KnockbackPower = 18, Lift = 22 })
		if k:wait(0.3) then
			k:pose("Shake", 0.5)
		end
	end)

	-- deita e ronca 3 vezes; cada ronco treme o chão e o último dá sono
	def("SK_pug_3", 3, function(k)
		if not k:approach(2, 1) then
			return
		end
		k:pose("Snore", 2)
		for i = 1, 3 do
			if not k:wait(0.55) then
				return
			end
			local g = k:feet()
			k:pop("Z" .. string.rep("z", i), k:me() + UP * 4, C(200, 220, 255), 0.7 + i * 0.15)
			k:shock(g, 6 + i * 2, C(205, 180, 140))
			local hits = k:area(g, 6 + i * 2, i == 3 and 0.45 or 0.275, { KnockbackPower = 10 + i * 6, Lift = 10 })
			if i == 3 then
				for _, e in ipairs(hits) do
					k:stun(e, 1.2, "Sleep")
				end
			end
		end
	end)

	------------------------------------------------------------ Pinscher
	-- treme de nervoso, dispara, 2 mordidinhas e volta
	def("SK_pinscher_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Focus", 0.35)
		k:pop("!!", nil, C(255, 120, 120), 0.7)
		if not k:wait(0.35) then
			return
		end
		local home = k:feet()
		k:pose("Dash", 0.7)
		k:fx("Streak", { Model = k.f.Model, Color = C(240, 240, 255), Duration = 0.6, Width = 0.8 })
		if not k:blink(k:tpos() - k:dir() * 2.5, 3, 0.03) then
			return
		end
		for _ = 1, 2 do
			k:face()
			k:fx("Bite", { Model = k.f.Model, Head = 1 })
			k:fx("BiteMark", { Position = k:tpos(), Direction = k:dir(), Color = C(255, 255, 255) })
			k:hit(0.5)
			if not k:wait(0.18) then
				return
			end
		end
		k:blink(home, 3, 0.03)
	end)

	-- gira e solta um tornadinho que vai até o inimigo
	def("SK_pinscher_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Twirl", 0.6)
		if not k:wait(0.45) then
			return
		end
		local from, to = k:feet(), k:tground()
		local time = math.clamp(k:dist() / 30, 0.3, 0.9)
		k:prop("Tornado", { Position = from, To = to, Path = "Fly", Time = time, Size = 2.4 * k.A, Color = C(215, 245, 235) })
		k:later(time, function()
			k:prop("Tornado", { Position = to, Path = "Spin", Time = 0.5, Hold = 0.2, Size = 2.4 * k.A, Spin = 9, Color = C(215, 245, 235) })
			k:burst("Leaves", to, { Count = 8 })
			k:area(to, 6, 0.6, { KnockbackPower = 24, Lift = 18 })
		end)
		k:later(time + 0.4, function()
			k:area(to, 6, 0.4, { KnockbackPower = 16, Lift = 12 })
		end)
	end)

	------------------------------------------------------------ Poodle
	-- pirueta chique soltando pompons
	def("SK_poodle_2", 2, function(k)
		if not k:approach(2, 1) then
			return
		end
		k:pose("Twirl", 0.8)
		if not k:wait(0.35) then
			return
		end
		local g = k:feet()
		k:ringOut("Pom", g, 1, 8, { Count = 8, Time = 0.5, Height = 1.5, Size = 0.9, Color = C(255, 225, 238) })
		k:area(g, 8, 1, { KnockbackPower = 16, Lift = 12 })
		k:burst("Hearts", k:me(), { Count = 4, Color = C(255, 140, 190) })
	end)

	-- brisa de perfume rosa que encanta
	def("SK_poodle_3", 3, function(k)
		if not k:reach(k:R(19) * 0.7, 1) then
			return
		end
		k:face()
		k:pose("Inhale", 0.4)
		if not k:wait(0.4) then
			return
		end
		k:pose("Open", 0.9)
		k:breath("Perfume", {
			length = 19,
			angle = 28,
			time = 0.9,
			ticks = 3,
			frac = 0.8,
			color = C(255, 150, 210),
			on = function(e)
				k:knock(e, k:me(), 5, 4)
			end,
		})
		k:inCone(k:me(), k:dir(), 19, 28, 0.2, nil, function(e)
			k:stun(e, 1.2, "Charm")
		end)
	end)

	------------------------------------------------------------ Bulldog
	-- cabeçada carregada (BONK!)
	def("SK_bulldog_2", 2, function(k)
		if not k:approach(9, 1) then
			return
		end
		k:face()
		k:pose("Headbutt", 0.6)
		if not k:wait(0.22) then
			return
		end
		local d = k:dir()
		k:dash(k:tpos() - d * 1.5, 0.18, {
			frac = 1,
			radius = 3,
			opts = { Knockback = d * 45 + UP * 18 },
			on = function(e)
				k:pop("BONK!", e.Root.Position + UP * 4, C(255, 230, 120))
				k:impact(e.Root.Position, 4, C(220, 200, 170))
			end,
		})
	end)

	-- pisa forte 2 vezes; a 2ª deixa tonto
	def("SK_bulldog_3", 3, function(k)
		if not k:approach(7, 0.8) then
			return
		end
		k:face()
		k:pose("Stomp", 0.8)
		for i = 1, 2 do
			if not k:wait(0.36) then
				return
			end
			local g = k:feet() + k:dir() * 2
			k:shock(g, 6 + i * 2, C(190, 160, 120), i == 2)
			k:burst("Rocks", g, { Count = 4 + i * 2 })
			local hits = k:area(g, 6 + i * 2, i == 1 and 0.4 or 0.6, { KnockbackPower = 10, Lift = 16 })
			if i == 2 then
				for _, e in ipairs(hits) do
					k:stun(e, 1, "Dizzy")
				end
			end
		end
	end)

	------------------------------------------------------------ Beagle
	-- fareja, rastro de cheiro até o inimigo, corre por ele e morde
	def("SK_beagle_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Sniff", 0.6)
		k:path("Scent", k:feet(), k:tground(), { Duration = 1.4, Color = C(140, 255, 120) })
		if not k:wait(0.55) then
			return
		end
		k:pose("Dash", 0.4)
		local d = k:dir()
		k:path("Paw", k:feet(), k:tground(), { Duration = 1.2, Color = C(120, 90, 60) })
		if not k:dash(k:tpos() - d * 2, 0.3) then
			return
		end
		k:face()
		k:fx("Bite", { Model = k.f.Model, Head = 1 })
		k:fx("BiteMark", { Position = k:tpos(), Direction = d, Color = C(200, 255, 190) })
		k:hit(1, { Knockback = d * 25 + UP * 8 })
	end)

	-- uivo com anel de folhas que prende em vinhas
	def("SK_beagle_3", 3, function(k)
		if not k:approach(4, 0.9) then
			return
		end
		k:pose("Howl", 1)
		k:fx("Roar", { Model = k.f.Model, Color = C(150, 230, 120), Howl = true })
		if not k:wait(0.4) then
			return
		end
		local g = k:feet()
		k:ringOut("Leaf", g, 1, 11, { Count = 10, Time = 0.7, Height = 1, Swirl = 2, Color = C(110, 200, 80) })
		local hits = k:area(g, 11, 1, { KnockbackPower = 14, Lift = 8 })
		for _, e in ipairs(hits) do
			k:stun(e, 1, "Vines")
		end
	end)

	------------------------------------------------------------ Corgi
	-- mortal e cai sentado em cima (BOING!), quica de novo
	def("SK_corgi_2", 2, function(k)
		if not k:approach(10, 1) then
			return
		end
		k:face()
		k:pose("Crouch", 0.3)
		k:tele(k:tground(), 6, 0.85)
		if not k:wait(0.3) then
			return
		end
		k:pose("Flip", 0.6)
		if not k:leap(k:tpos(), 8, 0.55) then
			return
		end
		k:pose("Bounce", 0.85)
		local g = k:feet()
		k:pop("BOING!", nil, C(255, 205, 150))
		k:shock(g, 6, C(255, 205, 150))
		k:area(g, 6, 0.7, { KnockbackPower = 20, Lift = 26 })
		if not k:wait(0.42) then
			return
		end
		k:shock(k:feet(), 4, C(255, 205, 150))
		k:area(k:feet(), 4.5, 0.3, { KnockbackPower = 10, Lift = 16 })
	end)

	-- vira um pãozinho e sai rolando
	def("SK_corgi_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Curl", 0.3)
		if not k:wait(0.25) then
			return
		end
		k:pose("Roll", 0.8)
		local d = k:dir()
		k:fx("Streak", { Model = k.f.Model, Color = C(255, 230, 190), Duration = 0.6, Width = 1.2 })
		k:dash(k:tpos() + d * 8, 0.55, {
			frac = 1,
			radius = 3.5,
			opts = { Knockback = d * 30 + UP * 25 },
			on = function(e)
				k:burst("Crumbs", e.Root.Position, { Count = 8 })
				k:pop("ROLL!", e.Root.Position + UP * 4, C(255, 225, 175), 0.8)
			end,
		})
		k:burst("Crumbs", k:feet(), { Count = 6 })
	end)

	------------------------------------------------------------ Dachshund (salsicha)
	-- cachorro-quente que quica 2 vezes
	def("SK_salsicha_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Throw", 0.5)
		if not k:wait(0.22) then
			return
		end
		local d = k:dir()
		local p1 = k:tground()
		local p2 = G(p1 + d * 1.5)
		local p3 = G(p1 + d * 2.5)
		local t1 = k:shoot("HotDog", { points = { p1 }, speed = 45, arc = 6, frac = 0.5, radius = 4 })
		k:later(t1, function()
			k:shoot("HotDog", { from = p1 + UP, points = { p2 }, speed = 12, arc = 3, frac = 0.3, radius = 4 })
		end)
		k:later(t1 + 0.3, function()
			k:shoot("HotDog", { from = p2 + UP, points = { p3 }, speed = 10, arc = 2, frac = 0.2, radius = 4 })
		end)
		k:pose("Bow", 0.6)
	end)

	-- cava um túnel e sai do chão embaixo do inimigo
	def("SK_salsicha_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Dive", 0.75)
		k:burst("Dirt", k:feet(), { Count = 8 })
		if not k:wait(0.6) then
			return
		end
		local target = k:tground()
		k:path("Crack", k:feet(), target, { Duration = 1, Color = C(120, 90, 60) })
		k:pose("Vanish", 0.45)
		if not k:wait(0.4) then
			return
		end
		k:blink(target, 1, 0.01)
		k:pose("Leap", 0.5)
		k:burst("Dirt", target, { Count = 14, Radius = 8 })
		k:impact(target, 5, C(170, 130, 80), true)
		k:area(target, 5, 1, { KnockbackPower = 6, Lift = 42 })
		k:leap(target + k:dir() * 0.5, 4, 0.35)
	end)

	------------------------------------------------------------ Chihuahua
	-- 3 latidos em cone; o 3º deixa tonto
	def("SK_chihuahua_2", 2, function(k)
		if not k:reach(k:R(18) * 0.7, 1) then
			return
		end
		k:face()
		k:pose("Focus", 0.35)
		k:pop("!!!", nil, C(255, 80, 80), 0.8)
		if not k:wait(0.35) then
			return
		end
		k:pose("Bark", 1)
		for i = 1, 3 do
			k:face()
			local d = k:dir()
			k:fx("S_Cone", { Kind = "Sound", Model = k.f.Model, Length = k:R(18), Angle = 26, Duration = 0.25, Color = C(255, 150, 210) })
			k:pop("YAP!", k:mouth() + UP, C(255, 120, 200), 0.6 + i * 0.15)
			k:inCone(k:me(), d, 18, 26, i == 3 and 0.4 or 0.3, { Knockback = d * (i == 3 and 30 or 4) }, i == 3 and function(e)
				k:stun(e, 1, "Dizzy")
			end or nil)
			if not k:wait(0.32) then
				return
			end
		end
	end)

	-- birra: 3 pulinhos furiosos indo na direção do inimigo; cada um solta uma onda de som; a última empurra longe
	def("SK_chihuahua_3", 3, function(k)
		k:stop()
		k:face()
		local step = math.max(0, k:dist() - 4) / 3
		for i = 1, 3 do
			k:pose("Bounce", 0.45)
			if not k:leap(k:me() + k:dir() * step, 2.5, 0.3) then
				return
			end
			local g = k:feet()
			k:pop(i == 3 and "GRRR!" or "!", k:me() + UP * 3, C(255, 90, 120), 0.6 + i * 0.2)
			k:shock(g, 6 + i * 2, C(255, 140, 200))
			k:ringOut("Note", g, 1, 6 + i * 2, { Count = 6, Time = 0.4, Height = 1.5, Color = C(255, 120, 200) })
			k:area(g, 6 + i * 2, i == 3 and 0.5 or 0.25, { KnockbackPower = i == 3 and 40 or 12, Lift = 12 })
		end
	end)
end
