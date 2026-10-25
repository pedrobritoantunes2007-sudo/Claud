-- 🐕 HABILIDADES DOS INCOMUNS (2026-10): um pouco melhores que os comuns — 2 tempos e 1 efeito extra
-- (lento, preso, cura, escudo). Frações somam ~1 (o orçamento vem do Config.SKILL_TIER).
local SkillKit = require(script.Parent.Parent.SkillKit)

local C = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local G = SkillKit.Ground

return function(Specials, _Fighters)
	local function def(id, slot, fn)
		SkillKit.def(Specials, id, slot, fn)
	end

	------------------------------------------------------------ Snow Husky
	-- escorrega de barriga como trenó deixando gelo; quem é atingido fica lento
	def("SK_snow_husky_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Bow", 0.3)
		if not k:wait(0.3) then
			return
		end
		local d = k:dir()
		local from = k:feet()
		local to = k:tpos() + d * 7
		k:pose("Slide", 0.7)
		k:path("Ice", from, G(to), { Duration = 2, Color = C(190, 235, 255), Width = 3 })
		k:dash(to, 0.5, {
			frac = 0.8,
			radius = 3.5,
			opts = { Knockback = d * 22 + UP * 10, Color = C(190, 235, 255) },
			on = function(e)
				k:slow(e, 2.5, 0.5)
			end,
		})
		k:burst("Snow", k:feet(), { Count = 10 })
		k:area(k:feet(), 5, 0.2, { Color = C(190, 235, 255) })
	end)

	-- uiva e faz uma nevasca no inimigo; no fim congela
	def("SK_snow_husky_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Howl", 1)
		k:fx("Roar", { Model = k.f.Model, Color = C(200, 235, 255), Howl = true })
		if not k:wait(0.45) then
			return
		end
		local c = k:tground()
		k:zone("Snow", c, 8, 2.2, 0.65, {
			every = 0.55,
			color = C(220, 240, 255),
			on = function(e)
				k:slow(e, 0.8, 0.6)
			end,
		})
		k:ringOut("Snowflake", c, 9, 1.5, { Count = 10, Time = 2, Height = 3, Swirl = 6, Color = C(210, 240, 255) })
		k:later(2.1, function()
			k:impact(c, 7, C(190, 235, 255))
			for _, e in ipairs(k:area(c, 8, 0.35, { Color = C(190, 235, 255) })) do
				k:freeze(e, 1.4)
			end
		end)
	end)

	------------------------------------------------------------ Armored Doberman
	-- armadura brilha e atropela todos numa linha
	def("SK_armored_doberman_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Headbutt", 0.35)
		k:aura("Metal", 1, C(200, 210, 230))
		if not k:wait(0.3) then
			return
		end
		local d = k:dir()
		k:pose("Charge", 0.6)
		k:fx("Streak", { Model = k.f.Model, Color = C(210, 220, 240), Duration = 0.5, Width = 1.4 })
		k:dash(k:tpos() + d * 9, 0.45, {
			frac = 1,
			radius = 3.5,
			opts = { Knockback = d * 40 + UP * 16, Color = C(210, 220, 240) },
			on = function(e)
				k:impact(e.Root.Position, 4, C(210, 220, 240))
			end,
		})
	end)

	-- escudo de pedra (leva menos dano) e depois um terremoto em volta
	def("SK_armored_doberman_3", 3, function(k)
		if not k:approach(3, 1) then
			return
		end
		k:pose("Guard", 1)
		k:shield(3, 0.4, "Stone")
		k:shock(k:feet(), 6, C(170, 160, 150))
		if not k:wait(0.9) then
			return
		end
		k:pose("Stomp", 0.5)
		if not k:wait(0.3) then
			return
		end
		local g = k:feet()
		k:shock(g, 11, C(170, 150, 120), true)
		k:burst("Rocks", g, { Count = 10 })
		k:area(g, 11, 1, { KnockbackPower = 30, Lift = 20, Color = C(190, 170, 140) })
	end)

	------------------------------------------------------------ Racer Boxer
	-- em pé: POW! BAM! e gancho
	def("SK_boxer_2", 2, function(k)
		if not k:approach(3, 1) then
			return
		end
		k:face()
		k:pose("Rear", 0.8)
		local words = { "POW!", "BAM!" }
		for i = 1, 2 do
			if not k:wait(0.22) then
				return
			end
			k:pop(words[i], k:tpos() + UP * 3, C(255, 220, 80), 0.8)
			k:impact(k:tpos(), 2.5, C(255, 220, 80))
			k:hit(0.3, { Knockback = k:dir() * 8, Color = C(255, 220, 80) })
		end
		if not k:wait(0.2) then
			return
		end
		k:pose("Uppercut", 0.6)
		if not k:wait(0.25) then
			return
		end
		k:pop("KO!", k:tpos() + UP * 4, C(255, 120, 60))
		k:impact(k:tpos(), 4, C(255, 200, 80))
		k:hit(0.4, { Knockback = k:dir() * 18 + UP * 42, Color = C(255, 200, 80) })
	end)

	-- volta turbo em volta do inimigo; o anel de vento fecha e acerta 2 vezes
	def("SK_boxer_3", 3, function(k)
		k:stop()
		local c = k:tground()
		k:pose("Dash", 1.1)
		k:aura("Haste", 1, C(210, 245, 255))
		k:fx("Streak", { Model = k.f.Model, Color = C(230, 250, 255), Duration = 0.9, Width = 1.1 })
		if not k:circle(c, 7, 1, 0.75) then
			return
		end
		k:face(c)
		k:ringOut("Feather", c, 9, 1, { Count = 10, Time = 0.35, Height = 1.5, Swirl = 3, Color = C(235, 250, 255) })
		k:shock(c, 8, C(220, 245, 255))
		k:area(c, 8, 0.5, { KnockbackPower = 4, Lift = 12, Color = C(220, 245, 255) })
		if not k:wait(0.25) then
			return
		end
		k:shock(c, 6, C(220, 245, 255))
		k:area(c, 7, 0.5, { KnockbackPower = 20, Lift = 18, Color = C(220, 245, 255) })
	end)

	------------------------------------------------------------ Golden Retriever
	-- bolinha de tênis que bate e volta; pegar cura um pouco
	def("SK_golden_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Throw", 0.5)
		if not k:wait(0.22) then
			return
		end
		local t = k:shoot("Ball", { speed = 60, arc = 3, frac = 0.75, back = true, backFrac = 0.25, radius = 3 })
		k:pose("Bow", t * 2)
		if not k:wait(t * 1.9) then
			return
		end
		k:pose("Victory", 0.5)
		k:heal(0.05)
	end)

	-- 3 pulsos de luz dourada: machuca em volta e cura
	def("SK_golden_3", 3, function(k)
		if not k:approach(3, 1) then
			return
		end
		k:pose("Sit", 1.3)
		k:aura("Holy", 1.6, C(255, 220, 120))
		for i = 1, 3 do
			if not k:wait(0.4) then
				return
			end
			local g = k:feet()
			k:shock(g, 7 + i * 2, C(255, 220, 120))
			k:burst("Hearts", k:me(), { Count = 3, Color = C(255, 150, 170) })
			k:area(g, 7 + i * 2, 0.333, { KnockbackPower = 10, Lift = 8, Color = C(255, 220, 120) })
			k:heal(0.03)
		end
	end)

	------------------------------------------------------------ Dalmatian
	-- mangueira de bombeiro
	def("SK_dalmatian_2", 2, function(k)
		if not k:reach(k:R(26) * 0.75, 1) then
			return
		end
		k:face()
		k:pose("Open", 1)
		k:beam("Water", {
			length = 26,
			width = 3,
			time = 0.9,
			ticks = 3,
			frac = 1,
			on = function(e)
				k:knock(e, k:me(), 14, 4)
			end,
		})
		k:burst("Drops", k:tpos(), { Count = 8 })
	end)

	-- sacode e as pintas pretas voam como bexigas d'água
	def("SK_dalmatian_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Shake", 0.9)
		if not k:wait(0.3) then
			return
		end
		local pts = k:around(k:tpos(), 5, 5, k:rand(0, 70), 0.4)
		table.insert(pts, 1, k:tground())
		k:shoot("Ink", { points = pts, speed = 35, arc = 6, frac = 0.18, radius = 4, impact = "Splash", size = 0.9, gap = 0.04 })
	end)

	------------------------------------------------------------ German Shepherd
	-- fareja, mira, salta e prende mordendo
	def("SK_pastor_alemao_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Sniff", 0.5)
		k:mark(k.t, "Reticle", 0.9)
		if not k:wait(0.5) then
			return
		end
		k:pose("Leap", 0.5)
		if not k:leap(k:tpos() - k:dir() * 2, 5, 0.42) then
			return
		end
		k:face()
		k:fx("Bite", { Model = k.f.Model, Head = 1 })
		k:impact(k:tground(), 4, C(255, 230, 200))
		k:hit(0.5, { Color = C(255, 90, 70) })
		k:stun(k.t, 1.3, "Pin")
		for _ = 1, 2 do
			if not k:wait(0.3) then
				return
			end
			k:fx("Bite", { Model = k.f.Model, Head = 1 })
			k:fx("BiteMark", { Position = k:tpos(), Direction = k:dir(), Color = C(255, 230, 210) })
			k:hit(0.25, { Color = C(255, 90, 70) })
		end
	end)

	-- sirene de polícia + latidos em ondas vermelhas e azuis + choque
	def("SK_pastor_alemao_3", 3, function(k)
		if not k:approach(4, 1) then
			return
		end
		k:face()
		k:aura("Siren", 1.6)
		k:pose("Bark", 1)
		for i = 1, 3 do
			if not k:wait(0.32) then
				return
			end
			local col = i % 2 == 1 and C(255, 60, 60) or C(70, 120, 255)
			k:shock(k:feet(), 5 + i * 2.5, col)
			k:area(k:feet(), 5 + i * 2.5, 0.2, { Color = col })
		end
		if not k:wait(0.2) then
			return
		end
		for _, e in ipairs(k:area(k:feet(), 12, 0.4, { Color = C(255, 240, 120) })) do
			k:pillar("Lightning", G(e.Root.Position), 2, { Color = C(170, 200, 255) })
			k:stun(e, 1, "Shock")
		end
	end)

	------------------------------------------------------------ Border Collie
	-- joga o frisbee e salta para pegar no ar
	def("SK_border_collie_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Throw", 0.5)
		if not k:wait(0.22) then
			return
		end
		local far = k:tground() + k:dir() * 4
		local t = k:shoot("Frisbee", { points = { far }, speed = 45, arc = 4, frac = 0.5, radius = 4, color = C(235, 70, 60) })
		if not k:wait(t * 0.4) then
			return
		end
		k:pose("Leap", 0.8)
		if not k:leap(far, 7, 0.6, { frac = 0.5, radius = 4 }) then
			return
		end
		k:pose("Victory", 0.5)
		k:pop("CATCH!", nil, C(255, 240, 120), 0.9)
	end)

	-- pastoreia: corre em volta juntando os inimigos e late
	def("SK_border_collie_3", 3, function(k)
		k:stop()
		local c = k:tground()
		k:pose("Dash", 1.2)
		k:fx("Streak", { Model = k.f.Model, Color = C(235, 250, 245), Duration = 0.9, Width = 1 })
		local a0 = k:rand(0, 360)
		for i = 1, 3 do
			local a = math.rad(a0 + i * 120)
			local p = c + Vector3.new(math.cos(a), 0, math.sin(a)) * 9
			if not k:blink(p, 2, 0.05) then
				return
			end
			k:path("Wind", p, c, { Duration = 0.5, Width = 3 })
			for _, e in ipairs(k:enemies(c, 13)) do
				k:pull(e, c, 18, 0.2)
			end
			if not k:wait(0.15) then
				return
			end
		end
		k:face(c)
		k:pose("Bark", 0.4)
		k:shock(c, 8, C(235, 250, 245))
		k:area(c, 8, 1, { KnockbackPower = 26, Lift = 12, Color = C(235, 250, 245) })
	end)

	------------------------------------------------------------ St. Bernard
	-- joga o barril de resgate; estoura em neve; o chocolate quente cura
	def("SK_sao_bernardo_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Throw", 0.5)
		if not k:wait(0.22) then
			return
		end
		local t = k:shoot("Barrel", { speed = 40, arc = 6, frac = 0.85, radius = 5, impact = "Snow" })
		k:later(t, function()
			local p = k:tground()
			k:burst("Snow", p, { Count = 12 })
			k:zone("Snow", p, 5, 1.5, 0.15)
		end)
		k:pose("Sit", 0.8)
		if k:wait(0.4) then
			k:heal(0.06)
			k:pop("COCOA!", nil, C(200, 140, 90), 0.7)
		end
	end)

	-- bate no chão e uma bola de neve gigante rola por cima dos inimigos
	def("SK_sao_bernardo_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Rear", 0.6)
		if not k:wait(0.5) then
			return
		end
		k:pose("Slam", 0.4)
		local d = k:dir()
		local from = k:feet() + d * 3
		local to = from + d * 28
		k:shake(from, 0.4, 40)
		k:shoot("Snowball", { from = from + UP * 2.5, points = { to }, speed = 32, arc = 0, size = 4 * k.A, frac = 0, impact = "Snow" })
		k:wave("Snow", {
			silent = true,
			from = from,
			dir = d,
			length = 28,
			width = 7,
			speed = 32,
			frac = 1,
			on = function(e)
				k:launch(e, 30)
				k:burst("Snow", e.Root.Position, { Count = 6 })
			end,
		})
	end)

	------------------------------------------------------------ Akita
	-- levanta um muro de pedra e derruba no inimigo
	def("SK_akita_2", 2, function(k)
		if not k:approach(4, 1) then
			return
		end
		k:face()
		k:pose("Guard", 0.9)
		local d = k:dir()
		local base = k:feet() + d * 3
		k:shield(1.2, 0.3, "Stone")
		k:prop("Slab", { Position = base, Look = d, Path = "Rise", Time = 0.35, Hold = 0.25, Depth = 6, Size = 0.9 * k.A, End = "Sink" })
		if not k:wait(0.6) then
			return
		end
		k:pose("Headbutt", 0.5)
		k:prop("Slab", { Position = base, Look = d, Path = "Swing", Time = 0.5, Hold = 0.4, Reach = 5 * k.A, Size = 0.9 * k.A, Impact = "Rock", End = "Sink" })
		if not k:wait(0.5) then
			return
		end
		local hitAt = base + d * 4.5
		k:area(hitAt, 6, 1, { KnockbackPower = 22, Lift = 14, Color = C(170, 150, 130) })
	end)

	-- pula alto e cai com um anel de pedras
	def("SK_akita_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Crouch", 0.3)
		k:tele(k:tground(), 9, 0.95)
		if not k:wait(0.3) then
			return
		end
		k:pose("Leap", 0.7)
		if not k:leap(k:tpos(), 10, 0.65) then
			return
		end
		k:pose("Slam", 0.4)
		local g = k:feet()
		k:ringOut("Rock", g, 2, 9, { Count = 8, Time = 0.4, Rise = 1, Size = 1.2 })
		k:shock(g, 9, C(175, 140, 95), true)
		k:area(g, 9, 1, { KnockbackPower = 20, Lift = 30, Color = C(190, 160, 120) })
	end)

	------------------------------------------------------------ Greyhound (galgo)
	-- atravessa o inimigo e volta deixando um túnel de vento
	def("SK_galgo_2", 2, function(k)
		k:stop()
		k:face()
		local d = k:dir()
		local a = k:feet()
		local b = k:tpos() + d * 8
		k:pose("Dash", 1)
		k:aura("Haste", 1)
		k:path("Wind", a, G(b), { Duration = 0.9, Width = 3 })
		if not k:dash(b, 0.35, { frac = 0.5, radius = 3.5, opts = { Knockback = d * 12 } }) then
			return
		end
		k:face(a)
		k:path("Wind", G(b), a, { Duration = 0.9, Width = 3 })
		k:dash(a, 0.35, { frac = 0.5, radius = 3.5, opts = { Knockback = -d * 12 } })
	end)

	-- semáforo 3, 2, 1, GO! e largada foguete
	def("SK_galgo_3", 3, function(k)
		k:stop()
		k:face()
		local d = k:dir()
		k:pose("Crouch", 1)
		k:prop("Lights", { Position = k:feet() + Vector3.new(d.Z, 0, -d.X) * 4, Look = -d, Path = "Countdown", Time = 0.9, Size = 0.8 })
		k:path("Race", k:feet(), G(k:feet() + d * 30), { Duration = 1.8, Width = 2.5, Color = C(40, 40, 50) })
		if not k:wait(0.95) then
			return
		end
		k:pose("Dash", 0.6)
		k:aura("Haste", 0.6)
		k:fx("Streak", { Model = k.f.Model, Color = C(255, 230, 90), Duration = 0.5, Width = 1.6 })
		k:dash(k:tpos() + d * 10, 0.35, {
			frac = 1,
			radius = 4,
			opts = { Knockback = d * 70 + UP * 30, Color = C(255, 230, 90) },
			on = function(e)
				k:pop("ZOOM!", e.Root.Position + UP * 4, C(255, 230, 90))
				k:impact(e.Root.Position, 5, C(255, 230, 90))
			end,
		})
	end)
end
