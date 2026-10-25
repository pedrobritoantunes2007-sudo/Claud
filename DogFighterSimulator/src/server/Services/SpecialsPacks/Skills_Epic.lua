-- 🟣 HABILIDADES DOS ÉPICOS (2026-10): golpes grandes com cenário (haltere, katana, fantasmas, vulcão, OVNI,
-- navio...) e o 👑 SUPREMO (tecla 4), que agora aparece a partir do Épico (pedido do dono): o céu muda (k:sky),
-- um objeto gigante entra em cena e o golpe final é forte. Frações somam ~1 do orçamento de cada tecla.
local SkillKit = require(script.Parent.Parent.SkillKit)

local C = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local G = SkillKit.Ground
local turn = SkillKit.Turn

local function side(d)
	return Vector3.new(-d.Z, 0, d.X)
end

return function(Specials, _Fighters)
	local function def(id, slot, fn)
		SkillKit.def(Specials, id, slot, fn)
	end

	------------------------------------------------------------ Buff Bulldog
	def("SK_brute_bulldog_2", 2, function(k)
		if not k:approach(3, 1) then
			return
		end
		k:pose("Flex", 0.9)
		k:rage(4, 1.25, "Rage")
		k:pop("FLEX!", nil, C(255, 170, 80))
		if not k:wait(0.35) then
			return
		end
		local g = k:feet()
		k:shock(g, 9, C(255, 160, 80), true)
		k:area(g, 9, 1, { KnockbackPower = 30, Lift = 16 })
	end)

	def("SK_brute_bulldog_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Crouch", 0.35)
		k:tele(k:tground(), 9, 1.25, C(255, 140, 60))
		if not k:wait(0.35) then
			return
		end
		k:pose("Belly", 1)
		k:fx("Streak", { Model = k.f.Model, Color = C(255, 140, 50), Duration = 0.9, Width = 2.2, Neon = true, Sparks = true })
		if not k:leap(k:tpos(), 22, 0.85) then
			return
		end
		local g = k:feet()
		k:impact(g, 9, C(255, 140, 60), true)
		k:fx("Explosion", { Position = g + UP, Radius = k:R(8), Color = C(255, 130, 50) })
		k:burst("Rocks", g, { Count = 12, Radius = 12 })
		k:area(g, 9, 1, { KnockbackPower = 26, Lift = 32 })
		k:zone("Crack", g, 7, 2, 0, { color = C(255, 120, 40) })
	end)

	def("SK_brute_bulldog_4", 4, function(k)
		k:stop()
		k:sky("Gold", 3.2)
		k:pose("Flex", 0.9)
		k:prop("Dumbbell", { Position = k:me() + UP * 9, Path = "Hover", Time = 0.4, Hold = 0.5, Size = 2.4 * k.A, Color = C(220, 50, 40) })
		if not k:wait(0.8) then
			return
		end
		local fracs = { 0.25, 0.3, 0.45 }
		for i = 1, 3 do
			local c = k:tground()
			k:pose("Slam", 0.45)
			k:prop("Dumbbell", { Position = c + UP * 1.2, Path = "Fall", Height = 26, Time = 0.32, Hold = 0.2, Size = (2 + i * 0.4) * k.A, Color = C(220, 50, 40), Impact = "Rock", Shake = 0.4 + i * 0.2 })
			if not k:wait(0.32) then
				return
			end
			k:shock(c, 6 + i * 2.5, C(255, 190, 60), true)
			k:pop(i == 3 and "MAX REP!" or ("REP " .. i), c + UP * 6, C(255, 200, 80))
			local hits = k:area(c, 6 + i * 2.5, fracs[i], { KnockbackPower = 10 + i * 8, Lift = 20 })
			if i == 3 then
				for _, e in ipairs(hits) do
					k:stun(e, 1.5, "Dizzy")
				end
			end
			if not k:wait(0.3) then
				return
			end
		end
	end)

	------------------------------------------------------------ Shiba Samurai
	def("SK_samurai_shiba_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Guard", 0.5)
		k:charge(0.4, C(235, 240, 255))
		if not k:wait(0.45) then
			return
		end
		local d = k:dir()
		local start = k:feet()
		local through = k:tpos() + d * 6
		k:pose("Slash", 0.6)
		local victims = k:inLine(start, d, k:dist(through), 4, 0)
		if not k:blink(through, 2, 0.03) then
			return
		end
		k:path("Slash", start, G(through), { Color = C(235, 240, 255) })
		k:pop("ZAN!", nil, C(235, 240, 255), 0.9)
		k:later(0.35, function()
			for _, e in ipairs(victims) do
				k:dmg(e, 1, { Color = C(255, 200, 220) })
				k:burst("Petals", e.Root.Position, { Count = 8, Color = C(255, 175, 205) })
			end
		end)
	end)

	def("SK_samurai_shiba_3", 3, function(k)
		if not k:approach(3, 1) then
			return
		end
		k:pose("Spin", 1.2)
		local g = k:feet()
		k:ringOut("Petal", g, 2, 9, { Count = 12, Time = 1.1, Height = 2, Swirl = 6, Color = C(255, 175, 205) })
		for i = 1, 4 do
			if not k:wait(0.27) then
				return
			end
			local a = k:rand(0, 360)
			local d = turn(Vector3.new(1, 0, 0), a)
			k:fx("Slash", { Position = k:me(), Direction = d, Color = C(255, 220, 235), Size = 8, Tilt = k:rand(-30, 30) })
			k:area(k:feet(), 8, 0.25, { KnockbackPower = 8, Lift = 8, Color = C(255, 200, 220) })
		end
	end)

	def("SK_samurai_shiba_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Dark", 3)
		k:pose("Guard", 1.2)
		k:pop("...", nil, C(255, 255, 255), 0.8)
		local c = k:tground()
		k:zone("Rune", c, 9, 2.2, 0, { color = C(255, 200, 220) })
		for i = 1, 9 do
			k:later(0.25 + i * 0.09, function()
				local a = k:rand(0, 180)
				local d = turn(Vector3.new(1, 0, 0), a)
				k:path("Slash", c - d * 8, c + d * 8, { Color = C(255, 230, 240), Height = k:rand(0.8, 3) })
				k:area(c, 6, 0.04, { Color = C(255, 200, 220) })
			end)
		end
		if not k:wait(1.4) then
			return
		end
		k:pose("Slash", 0.6)
		k:pop("SLASH!", c + UP * 6, C(255, 120, 160), 1.6)
		k:burst("Petals", c, { Count = 30, Radius = 14, Color = C(255, 175, 205) })
		k:shake(c, 1, 70)
		k:area(c, 10, 0.64, { KnockbackPower = 30, Lift = 26, Color = C(255, 120, 160) })
	end)

	------------------------------------------------------------ Ghost Dog
	def("SK_ghost_hound_2", 2, function(k)
		k:stop()
		k:fx("Smoke", { Position = k:feet(), Color = C(200, 230, 255), Size = 5 })
		k:pose("Vanish", 0.4)
		if not k:wait(0.35) then
			return
		end
		if not k:behind(2) then
			return
		end
		k:fx("Smoke", { Position = k:feet(), Color = C(200, 230, 255), Size = 5 })
		k:pose("Leap", 0.3)
		k:fx("Bite", { Model = k.f.Model, Head = 1 })
		k:fx("BiteMark", { Position = k:tpos(), Direction = k:dir(), Color = C(200, 230, 255) })
		k:hit(0.5, { Crit = true, Knockback = k:dir() * 30 + UP * 12, Color = C(200, 230, 255) })
	end)

	def("SK_ghost_hound_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Howl", 1)
		k:fx("Roar", { Model = k.f.Model, Color = C(190, 220, 255), Howl = true })
		if not k:wait(0.4) then
			return
		end
		local pts = {}
		for _, e in ipairs(k:enemies(k:tpos(), 14)) do
			if #pts < 3 then
				table.insert(pts, G(e.Root.Position))
			end
		end
		while #pts < 3 do
			table.insert(pts, G(k:tpos() + Vector3.new(k:rand(-3, 3), 0, k:rand(-3, 3))))
		end
		k:summon("Ghost", {
			points = pts,
			time = 0.8,
			gap = 0.15,
			frac = 0.34,
			radius = 4,
			color = C(200, 230, 255),
			on = function(e)
				k:slow(e, 2, 0.5, "Fear")
			end,
		})
	end)

	def("SK_ghost_hound_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Night", 3.2)
		k:pose("Summon", 1.6)
		local c = k:tground()
		k:zone("Grave", c, 10, 3, 0)
		k:summon("Ghost", { points = k:around(c, 3, 6, k:rand(0, 60), 0.5), time = 0.7, gap = 0.15, frac = 0.14, radius = 4.5, color = C(180, 215, 255), path = "Rise" })
		if not k:wait(1.8) then
			return
		end
		k:pose("Howl", 0.6)
		k:pop("BOO!", c + UP * 6, C(200, 230, 255), 1.8)
		k:shock(c, 11, C(200, 230, 255))
		for _, e in ipairs(k:area(c, 11, 0.4, { KnockbackPower = 30, Lift = 14, Color = C(200, 230, 255) })) do
			k:stun(e, 1.2, "Fear")
			k:force(e, "Crouch", 1.2)
		end
	end)

	------------------------------------------------------------ Toxic Hound
	def("SK_toxic_hound_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Spit", 0.8)
		local c = k:tpos()
		local pts = { k:tground(), G(c + Vector3.new(k:rand(-3, 3), 0, k:rand(-3, 3))), G(c + Vector3.new(k:rand(-3, 3), 0, k:rand(-3, 3))) }
		local t = k:shoot("Acid", { points = pts, speed = 45, arc = 5, frac = 0.2, radius = 3.5, gap = 0.15, impact = "Poison", color = C(150, 240, 70) })
		for i, p in ipairs(pts) do
			k:later((i - 1) * 0.15 + (t - 0.3), function()
				k:zone("Poison", p, 3.5, 1.8, 0.13, { color = C(150, 240, 70) })
			end)
		end
	end)

	def("SK_toxic_hound_3", 3, function(k)
		if not k:reach(k:R(16) * 0.7, 1) then
			return
		end
		k:face()
		k:pose("Inhale", 0.4)
		if not k:wait(0.4) then
			return
		end
		k:pose("Open", 1)
		k:breath("Poison", { length = 16, angle = 32, time = 1, ticks = 3, frac = 0.4, color = C(140, 230, 60) })
		local c = k:tground()
		k:zone("Poison", c, 7, 3, 0.6, {
			color = C(140, 230, 60),
			on = function(e)
				k:slow(e, 0.6, 0.6)
			end,
		})
	end)

	def("SK_toxic_hound_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Toxic", 3)
		k:pose("Summon", 1.6)
		local c = k:tground()
		local pts = k:scatter(c, 8, 6, true)
		for i, p in ipairs(pts) do
			k:later(0.2 + i * 0.2, function()
				k:tele(p, 3.5, 0.25, C(140, 230, 60))
			end)
			k:later(0.45 + i * 0.2, function()
				k:pillar("Poison", p, 2.5, { Height = 16, Time = 0.2, Hold = 0.7 })
				for _, e in ipairs(k:area(p, 4, 0.1, { Lift = 30, KnockbackPower = 4, Color = C(140, 230, 60) })) do
					k:dot(e, 2, 0.06, "Poison")
				end
			end)
		end
		k:later(1.8, function()
			k:zone("Poison", c, 10, 2.5, 0.3, {
				color = C(130, 240, 60),
				on = function(e)
					k:slow(e, 0.6, 0.5)
				end,
			})
		end)
		k:wait(1.8)
	end)

	------------------------------------------------------------ Frost Beast
	def("SK_frost_beast_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Rear", 0.5)
		k:orbit("Icicle", { Count = 5, Radius = 1.6, Speed = 4, Height = 2.5, Duration = 0.5, Size = 1.2, Color = C(180, 230, 255) })
		if not k:wait(0.5) then
			return
		end
		k:pose("Spit", 0.4)
		k:shoot("Icicle", { from = k:me() + UP * 3, count = 5, spread = 24, speed = 70, arc = 2, frac = 0.2, radius = 3, size = 1.3, gap = 0.05, impact = "Shatter", color = C(180, 230, 255) })
	end)

	def("SK_frost_beast_3", 3, function(k)
		if not k:approach(4, 1) then
			return
		end
		k:pose("Slam", 0.5)
		if not k:wait(0.22) then
			return
		end
		local g = k:feet()
		k:zone("Ice", g, 11, 2.5, 0.4, {
			on = function(e)
				k:slow(e, 0.6, 0.6)
			end,
		})
		k:ringOut("Crystal", g, 2, 11, { Count = 10, Time = 0.45, Rise = 1.5, Size = 1.3, Color = C(180, 230, 255) })
		k:shock(g, 11, C(170, 225, 255), true)
		for _, e in ipairs(k:area(g, 11, 0.6, { Color = C(170, 225, 255) })) do
			k:freeze(e, 1.2)
		end
	end)

	def("SK_frost_beast_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Ice", 3.2)
		k:pose("Howl", 1.2)
		k:fx("Roar", { Model = k.f.Model, Color = C(200, 240, 255), Howl = true })
		local c = k:tground()
		k:zone("Snow", c, 14, 3, 0.25, {
			on = function(e)
				k:slow(e, 0.6, 0.6)
			end,
		})
		k:later(0.5, function()
			k:rain("Icicle", k:scatter(c, 9, 10, true), { fall = 0.7, gap = 0.12, size = 3, frac = 0.08, radius = 4, impact = "Shatter", color = C(190, 235, 255) })
		end)
		if not k:wait(2.4) then
			return
		end
		k:shock(c, 12, C(220, 245, 255), true)
		k:fx("S_Burst", { Kind = "Shards", Position = c, Count = 20, Radius = 14, Color = C(200, 240, 255) })
		for _, e in ipairs(k:area(c, 12, 0.35, { Color = C(190, 235, 255) })) do
			k:freeze(e, 2)
		end
	end)

	------------------------------------------------------------ Magma Hound
	def("SK_magma_hound_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Spit", 0.8)
		local c = k:tpos()
		local pts = { k:tground(), G(c + Vector3.new(k:rand(-3, 3), 0, k:rand(-3, 3))), G(c + Vector3.new(k:rand(-3, 3), 0, k:rand(-3, 3))) }
		local t = k:shoot("Lava", { points = pts, speed = 45, arc = 5, frac = 0.2, radius = 3.5, gap = 0.15, impact = "Fire", color = C(255, 120, 30) })
		for i, p in ipairs(pts) do
			k:later((i - 1) * 0.15 + (t - 0.3), function()
				k:zone("Lava", p, 3.5, 2, 0.13)
			end)
		end
	end)

	def("SK_magma_hound_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Stomp", 0.6)
		local from = k:feet()
		local to = G(k:tpos() + k:dir() * 3)
		k:path("Crack", from, to, { Duration = 1.4, Color = C(255, 110, 30) })
		local pts = k:lineOf(from + k:dir() * 3, to, 5)
		for i, p in ipairs(pts) do
			k:later(0.25 + i * 0.12, function()
				k:pillar("Lava", p, 2.4, { Height = 14, Time = 0.18, Hold = 0.5 })
				for _, e in ipairs(k:area(p, 4, 0.2, { Lift = 26, KnockbackPower = 6, Color = C(255, 120, 30) })) do
					k:dot(e, 2, 0.04, "Burn")
				end
			end)
		end
		k:wait(0.6)
	end)

	def("SK_magma_hound_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Fire", 3.2)
		k:pose("Summon", 1.4)
		local c = k:tground()
		k:tele(c, 7, 0.6, C(255, 100, 20))
		k:prop("Volcano", { Position = c, Path = "Rise", Depth = 10, Time = 0.6, Hold = 2, Size = 1.5 * k.A, Impact = "Dirt", Shake = 0.8, End = "Sink" })
		k:later(0.6, function()
			k:area(c, 7, 0.35, { Lift = 45, KnockbackPower = 10, Color = C(255, 110, 25) })
			k:pillar("Lava", c + UP * 6, 2.5, { Height = 22, Time = 0.25, Hold = 1.4 })
		end)
		k:later(0.9, function()
			k:rain("Lava", k:scatter(c, 10, 10, false), { fall = 0.6, gap = 0.1, size = 1.5, frac = 0.06, radius = 4, impact = "Fire", height = 30 })
		end)
		k:later(2, function()
			k:zone("Lava", c, 9, 2, 0.3)
		end)
		k:wait(1.6)
	end)

	------------------------------------------------------------ Mummy Dog
	def("SK_mummy_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Spit", 0.5)
		local t = k:shoot("Bandage", { speed = 60, arc = 0, frac = 0.5, size = 1.5, impact = "Dust", radius = 3 })
		k:later(t, function()
			if k:real() then
				k:stun(k.t, 1.4, "Wrap")
				k:pull(k.t, k:me(), 35, 0.3)
			end
		end)
		if not k:wait(t + 0.4) then
			return
		end
		k:pose("Bark", 0.3)
		k:hit(0.5, { Color = C(240, 230, 205) })
	end)

	def("SK_mummy_dog_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Summon", 1)
		local c = k:tground()
		local cursed = {}
		k:zone("Sand", c, 9, 3, 0.6, {
			color = C(225, 195, 130),
			on = function(e)
				if not cursed[e] then
					cursed[e] = true
					k:curse(e, 4, 1.2)
				end
			end,
		})
		k:summon("Scarab", { from = c + Vector3.new(8, 0, 0), points = k:scatter(c, 4, 4, true), time = 0.9, gap = 0.2, frac = 0.1, radius = 3.5, path = "Run" })
		k:wait(0.6)
	end)

	def("SK_mummy_dog_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Sand", 3.2)
		k:pose("Summon", 1.6)
		local d = k:dir()
		local c = k:tground()
		k:prop("Pyramid", { Position = c + d * 12, Look = -d, Path = "Rise", Depth = 9, Time = 0.6, Hold = 2.4, Size = 2 * k.A, Impact = "Sand", End = "Sink" })
		k:later(0.3, function()
			k:prop("Sarcophagus", { Position = c + UP * 1.5, Look = d, Path = "Rise", Depth = 4, Time = 0.4, Hold = 1.3, Size = 1.4 * k.A, Impact = "Sand", End = "Shatter", Color = C(255, 210, 80) })
		end)
		k:later(0.7, function()
			k:stun(k.t, 2, "Wrap")
			k:zone("Sand", c, 7, 1.9, 0.3, { color = C(225, 195, 130) })
		end)
		if not k:wait(2) then
			return
		end
		k:fx("Explosion", { Position = c + UP, Radius = k:R(9), Color = C(255, 210, 80) })
		k:pillar("Holy", c, 4, { Height = 24, Time = 0.2, Hold = 0.6, Color = C(255, 220, 120) })
		k:area(c, 9, 0.7, { KnockbackPower = 35, Lift = 30, Color = C(255, 210, 80) })
	end)

	------------------------------------------------------------ Shark Dog
	def("SK_shark_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Dive", 0.6)
		k:burst("Drops", k:feet(), { Count = 8 })
		if not k:wait(0.5) then
			return
		end
		k:pose("Vanish", 0.6)
		k:fx("Fin", { Model = k.f.Model, Duration = 0.7 })
		local target = k:tpos()
		k:path("Water", k:feet(), G(target), { Duration = 1.2, Width = 2.5, Color = C(90, 160, 230) })
		if not k:blink(target, 6, 0.08) then
			return
		end
		k:pose("Leap", 0.5)
		k:fx("Bite", { Model = k.f.Model, Head = 1 })
		k:burst("Drops", G(target), { Count = 14, Radius = 9 })
		k:impact(G(target), 5, C(90, 160, 230))
		k:area(G(target), 5, 1, { Lift = 42, KnockbackPower = 8, Color = C(90, 160, 230) })
		k:leap(target, 4, 0.35)
	end)

	def("SK_shark_dog_3", 3, function(k)
		k:stop()
		k:pose("Vanish", 1.6)
		k:fx("Fin", { Model = k.f.Model, Duration = 1.4 })
		local c = k:tground()
		k:zone("Water", c, 8, 2.2, 0)
		if not k:circle(c, 7, 1.5, 1.1) then
			return
		end
		local a0 = k:rand(0, 360)
		for i = 1, 3 do
			local a = math.rad(a0 + i * 120)
			local p = G(k:tpos() + Vector3.new(math.cos(a), 0, math.sin(a)) * 3.5)
			k:tp(p)
			k:face()
			k:pose("Leap", 0.3)
			k:fx("Bite", { Model = k.f.Model, Head = 1 })
			k:fx("BiteMark", { Position = k:tpos(), Direction = k:dir(), Color = C(220, 240, 255) })
			k:burst("Drops", p, { Count = 6 })
			k:hit(0.33, { Knockback = k:dir() * 10 + UP * 8, Color = C(90, 160, 230) })
			if not k:wait(0.22) then
				return
			end
		end
	end)

	def("SK_shark_dog_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Ocean", 3)
		k:pose("Dive", 0.8)
		local c = k:tground()
		local d = k:dir()
		k:zone("Water", c, 11, 2.8, 0)
		k:tele(c, 8, 0.8, C(80, 150, 230))
		k:later(0.8, function()
			k:prop("Megalodon", { Position = c + UP * 5, Look = -d, Tilt = 60, Path = "Rise", Depth = 18, Time = 0.45, Hold = 0.9, Size = 1.1 * k.A, Impact = "Splash", Shake = 1, End = "Sink" })
		end)
		k:later(1.2, function()
			k:pop("CHOMP!", c + UP * 9, C(220, 240, 255), 1.6)
			k:area(c, 8, 0.6, { Lift = 48, KnockbackPower = 12, Color = C(80, 150, 230) })
		end)
		k:later(1.8, function()
			for i = 0, 3 do
				local dd = turn(d, i * 90)
				k:wave("Water", { from = c, dir = dd, length = 14, width = 10, speed = 35, frac = 0.1, color = C(80, 150, 230) })
			end
		end)
		k:wait(1.2)
	end)

	------------------------------------------------------------ Alien Dog
	def("SK_alien_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Aim", 0.5)
		local c = k:tground()
		k:prop("UFO", { Position = c + UP * 14, Path = "Hover", Time = 0.4, Hold = 1.3, Size = 1.3, Spin = 2, Color = C(120, 255, 180) })
		k:later(0.4, function()
			k:fx("Tractor", { From = c + UP * 13, To = c, Duration = 1, Color = C(120, 255, 180) })
			k:stun(k.t, 1.1, "Lift")
			if k:real() then
				k:launch(k.t, 28)
			end
			k:hit(0.4, { Color = C(120, 255, 180) })
		end)
		k:later(1.45, function()
			k:impact(c, 5, C(120, 255, 180))
			k:area(c, 5, 0.6, { KnockbackPower = 12, Lift = 6, Color = C(120, 255, 180) })
		end)
		k:wait(0.5)
	end)

	def("SK_alien_dog_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Summon", 1.3)
		local c = k:tground()
		local pts = { c }
		for _, p in ipairs(k:around(c, 6, 3, k:rand(0, 120))) do
			table.insert(pts, p)
		end
		for i, p in ipairs(pts) do
			k:later((i - 1) * 0.3, function()
				k:zone("Rune", p, 4, 0.7, 0, { color = C(150, 255, 200) })
			end)
			k:later((i - 1) * 0.3 + 0.45, function()
				k:pillar("Light", p, 2.5, { Height = 20, Time = 0.15, Hold = 0.4, Color = C(170, 255, 210) })
				k:area(p, 4.5, 0.25, { Lift = 30, KnockbackPower = 4, Color = C(150, 255, 200) })
			end)
		end
		k:wait(0.8)
	end)

	def("SK_alien_dog_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Space", 3.2)
		k:pose("Summon", 1.8)
		local c = k:tground()
		local sky = c + UP * 26
		k:prop("UFO", { Position = sky, Path = "Hover", Time = 0.6, Hold = 2.2, Size = 3.2 * k.A, Spin = 1, Color = C(120, 255, 170) })
		for i = 1, 3 do
			k:later(0.6 + i * 0.35, function()
				local p = G(c + Vector3.new(k:rand(-6, 6), 0, k:rand(-6, 6)))
				k:fx("Tractor", { From = sky - UP * 2, To = p, Duration = 0.45, Color = C(120, 255, 170) })
				k:area(p, 5, 0.1, { Color = C(120, 255, 170) })
			end)
		end
		k:later(2.1, function()
			k:pillar("Plasma", c, 6, { Height = 26, Time = 0.15, Hold = 0.7, Color = C(120, 255, 170) })
			k:fx("Explosion", { Position = c + UP, Radius = k:R(9), Color = C(120, 255, 170) })
			k:area(c, 9, 0.7, { KnockbackPower = 30, Lift = 26, Color = C(120, 255, 170) })
		end)
		k:wait(1.6)
	end)

	------------------------------------------------------------ Ninja Dog
	def("SK_ninja_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Throw", 0.45)
		if not k:wait(0.2) then
			return
		end
		k:shoot("Shuriken", { count = 5, spread = 40, speed = 80, arc = 0.5, frac = 0.24, radius = 2.5, size = 1.1, gap = 0.03 })
	end)

	def("SK_ninja_dog_3", 3, function(k)
		k:stop()
		k:fx("Smoke", { Position = k:feet(), Color = C(110, 70, 170), Size = 6 })
		k:pose("Vanish", 0.9)
		local c = k:tground()
		local a0 = k:rand(0, 360)
		for i = 1, 3 do
			local a = math.rad(a0 + i * 120)
			local from = G(c + Vector3.new(math.cos(a), 0, math.sin(a)) * 10)
			k:summon("Shade", { from = from, points = { c }, time = 0.45, frac = 0.3, radius = 4, color = C(110, 70, 170) })
		end
		if not k:wait(0.6) then
			return
		end
		k:fx("Smoke", { Position = c, Color = C(110, 70, 170), Size = 8 })
		if not k:behind(2) then
			return
		end
		k:pose("Slash", 0.4)
		k:hit(0.1, { Knockback = k:dir() * 20 + UP * 10, Color = C(150, 90, 220) })
	end)

	def("SK_ninja_dog_4", 4, function(k)
		k:stop()
		k:sky("Night", 3)
		k:fx("Smoke", { Position = k:feet(), Color = C(110, 70, 170), Size = 7 })
		k:pose("Vanish", 2.4)
		local c = k:tground()
		k:rain("Kunai", k:scatter(c, 5, 8, true), { fall = 0.4, gap = 0.08, size = 1.4, frac = 0.03, radius = 3, impact = "Burst", height = 25, tele = false })
		for i = 1, 8 do
			if not k:wait(0.15) then
				return
			end
			local a = math.rad(i * 135 + k:rand(-20, 20))
			local p = G(k:tpos() + Vector3.new(math.cos(a), 0, math.sin(a)) * 5)
			k:tp(p)
			k:path("Slash", p, G(k:tpos() - (p - k:tpos())), { Color = C(170, 110, 255), Height = 1.6 })
			k:hit(0.06, { Color = C(170, 110, 255) })
		end
		if not k:wait(0.3) then
			return
		end
		k:behind(3)
		k:pose("Slash", 0.6)
		local tc = k:tground()
		k:path("Slash", tc + Vector3.new(-6, 0, -6), tc + Vector3.new(6, 0, 6), { Color = C(220, 180, 255), Height = 2 })
		k:path("Slash", tc + Vector3.new(-6, 0, 6), tc + Vector3.new(6, 0, -6), { Color = C(220, 180, 255), Height = 2 })
		k:pop("X!", tc + UP * 6, C(220, 180, 255), 1.5)
		k:hit(0.26, { Crit = true, Knockback = k:dir() * 40 + UP * 20, Color = C(220, 180, 255) })
	end)

	------------------------------------------------------------ Pirate Dog
	def("SK_pirate_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Throw", 0.5)
		if not k:wait(0.22) then
			return
		end
		local t = k:shoot("Anchor", { speed = 55, arc = 2, frac = 0.5, size = 1.4, impact = "Rock", radius = 3 })
		k:later(t, function()
			if k:real() then
				k:path("Trail", k:feet(), k:tground(), { Duration = 0.5, Width = 0.4, Color = C(120, 120, 130) })
				k:pull(k.t, k:me(), 35, 0.35)
				k:stun(k.t, 0.6, "Pin")
			end
		end)
		if not k:wait(t + 0.4) then
			return
		end
		k:pose("Headbutt", 0.4)
		k:impact(k:tpos(), 4, C(160, 170, 185))
		k:hit(0.5, { Knockback = k:dir() * 25 + UP * 10, Color = C(160, 170, 185) })
	end)

	def("SK_pirate_dog_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Bark", 0.6)
		k:pop("FIRE!", nil, C(255, 200, 80), 1)
		local c = k:tground()
		k:rain("Cannonball", k:scatter(c, 6, 6, true), { fall = 0.8, gap = 0.15, size = 1.2, frac = 0.2, radius = 4, impact = "Explode", height = 30 })
		k:wait(0.6)
	end)

	def("SK_pirate_dog_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Abyss", 3.2)
		k:pose("Victory", 1)
		local c = k:tground()
		local d = k:dir()
		local s = side(d)
		local shipA = c - s * 32 - d * 10
		local shipB = c + s * 32 - d * 10
		k:prop("Ship", { Position = shipA + UP * 1, To = shipB + UP * 1, Path = "Fly", Time = 2.4, Size = 1.6 * k.A, Bob = 0.5, Roll = 0.08 })
		for v = 1, 3 do
			k:later(0.5 + v * 0.45, function()
				local from = shipA:Lerp(shipB, (0.5 + v * 0.45) / 2.4) + UP * 3
				k:shoot("Cannonball", { from = from, points = k:scatter(c, 6, 4, v == 2), speed = 50, arc = 6, frac = 0.06, radius = 4, size = 1, impact = "Explode" })
			end)
		end
		k:later(2.3, function()
			k:wave("Water", { from = G(c - d * 14), dir = d, length = 28, width = 14, speed = 35, frac = 0.3, color = C(90, 200, 220) })
		end)
		k:wait(1.6)
	end)

	------------------------------------------------------------ Scorpion Dog
	def("SK_scorpion_dog_2", 2, function(k)
		if not k:approach(4, 1) then
			return
		end
		k:face()
		k:pose("Rear", 0.6)
		if not k:wait(0.3) then
			return
		end
		k:shoot("Needle", { from = k:me() + UP * 3.5, speed = 90, arc = 0, frac = 0.5, size = 2, color = C(160, 240, 80), impact = "Poison", radius = 3 })
		k:dot(k.t, 3, 0.5, "Poison")
	end)

	def("SK_scorpion_dog_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Dig", 0.7)
		local c = k:tground()
		local poisoned = {}
		k:zone("Sand", c, 7, 2.5, 0.5, {
			color = C(225, 195, 130),
			on = function(e)
				k:pull(e, c, 16, 0.3)
				if not poisoned[e] then
					poisoned[e] = true
					k:dot(e, 3, 0.5, "Poison")
				end
			end,
		})
		k:wait(0.6)
	end)

	def("SK_scorpion_dog_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Sand", 3.2)
		k:pose("Summon", 1.6)
		local c = k:tground()
		local d = k:dir()
		k:zone("Sand", c, 10, 3, 0.2, { color = C(225, 195, 130) })
		for i = 1, 3 do
			k:later(0.4 + (i - 1) * 0.6, function()
				local base = G(k:real() and k:tground() or c) - d * 4.5
				k:prop("ScorpionTail", { Position = base, Look = d, Path = "Swing", Time = 0.45, Hold = 0.1, Reach = 4.5 * k.A, Size = 1.4 * k.A, Impact = "Poison", End = "Sink", Color = C(150, 230, 70) })
			end)
			k:later(0.85 + (i - 1) * 0.6, function()
				local p = k:real() and k:tground() or c
				for _, e in ipairs(k:area(p, 5, i == 3 and 0.3 or 0.2, { Lift = 20, KnockbackPower = 6, Color = C(150, 230, 70) })) do
					k:dot(e, 2, 0.03, "Poison")
					if i == 3 then
						k:stun(e, 1, "Dizzy")
					end
				end
			end)
		end
		k:wait(2)
	end)

	------------------------------------------------------------ Flytrap Dog
	def("SK_flytrap_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Dig", 0.5)
		local c = k:tground()
		k:prop("Flytrap", { Position = c, Offset = UP * 3, Look = k:dir(), Path = "Grow", Depth = 6, Time = 0.3, Hold = 1, Size = 0.9 * k.A, Impact = "Leaves", End = "Sink" })
		k:later(0.3, function()
			k:stun(k.t, 1.4, "Vines")
			k:area(c, 4, 0.6, { Color = C(110, 210, 80) })
			k:pop("SNAP!", c + UP * 5, C(140, 230, 90))
		end)
		k:later(1.1, function()
			k:area(c, 4, 0.4, { Lift = 25, KnockbackPower = 8, Color = C(110, 210, 80) })
		end)
		k:wait(0.4)
	end)

	def("SK_flytrap_dog_3", 3, function(k)
		if not k:approach(3, 1) then
			return
		end
		k:pose("Stomp", 1.1)
		local g = k:feet()
		local d = k:dir()
		for i = 1, 4 do
			k:later((i - 1) * 0.25, function()
				local dd = turn(d, (i - 1) * 90)
				k:prop("Tentacle", { Position = g + dd * 2, Look = dd, Path = "Swing", Time = 0.35, Hold = 0.05, Reach = 6, Size = 0.9 * k.A, Impact = "Leaves", Color = C(80, 180, 60), Color2 = C(160, 230, 110), End = "Sink" })
			end)
			k:later((i - 1) * 0.25 + 0.35, function()
				k:area(g, 9, 0.25, { KnockbackPower = 16, Lift = 10, Color = C(90, 190, 70) })
			end)
		end
		k:wait(1)
	end)

	def("SK_flytrap_dog_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Toxic", 3.2)
		k:pose("Summon", 1.6)
		local c = k:tground()
		k:zone("Flowers", c, 12, 3, 0.2, {
			on = function(e)
				k:slow(e, 0.6, 0.6)
			end,
		})
		k:prop("Flytrap", { Position = c, Offset = UP * 7, Look = k:dir(), Path = "Grow", Depth = 12, Time = 0.5, Hold = 1.7, Size = 2.4 * k.A, Impact = "Leaves", Shake = 0.8, End = "Sink" })
		k:later(0.5, function()
			k:stun(k.t, 1.8, "Vines")
			k:pop("GULP!", c + UP * 12, C(140, 230, 90), 1.5)
			k:area(c, 6, 0.4, { Color = C(110, 220, 80) })
		end)
		if not k:wait(2.1) then
			return
		end
		k:burst("Leaves", c + UP * 6, { Count = 20, Radius = 14 })
		k:pop("PTUI!", c + UP * 10, C(140, 230, 90), 1.2)
		k:area(c, 7, 0.4, { Lift = 50, KnockbackPower = 20, Color = C(110, 220, 80) })
	end)

	------------------------------------------------------------ DJ Dog
	def("SK_dj_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Wiggle", 1.4)
		local c = k:tground()
		local s = side(k:dir())
		for _, sgn in ipairs({ -1, 1 }) do
			k:prop("Speaker", { Position = c + s * sgn * 6 + UP * 0.8, Look = -s * sgn, Path = "Rise", Depth = 4, Time = 0.25, Hold = 1.3, Size = 1.4 * k.A, Color = C(255, 120, 220), Impact = "Notes", End = "Sink" })
		end
		for i = 1, 3 do
			if not k:wait(0.4) then
				return
			end
			k:shock(c, 5 + i * 2, C(255, 120, 220))
			k:ringOut("Note", c, 1, 5 + i * 2, { Count = 6, Time = 0.4, Height = 2, Color = C(255, 120, 220) })
			k:area(c, 5 + i * 2, 0.333, { KnockbackPower = 18, Lift = 8, Color = C(255, 120, 220) })
		end
	end)

	def("SK_dj_dog_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Wiggle", 1.6)
		local c = k:tground()
		k:prop("DiscoBall", { Position = c + UP * 11, Path = "Hover", Time = 0.4, Hold = 2, Size = 1.6, Spin = 2, Color = C(255, 120, 220) })
		k:zone("Dance", c, 9, 2.4, 0.6)
		k:later(0.4, function()
			for _, e in ipairs(k:area(c, 9, 0.4, { Color = C(200, 120, 255) })) do
				k:stun(e, 1.6, "Dance")
				k:force(e, "Wiggle", 1.6)
			end
			for i = 1, 3 do
				local p = G(c + Vector3.new(k:rand(-6, 6), 0, k:rand(-6, 6)))
				k:fx("S_Beam", { Kind = "Rainbow", From = c + UP * 10, To = p, Width = 1.2, Duration = 1.2, Sweep = 30 * i })
			end
		end)
		k:wait(0.5)
	end)

	def("SK_dj_dog_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Rainbow", 3.2)
		k:pose("Wiggle", 2.4)
		local c = k:tground()
		for i = 0, 3 do
			local dd = turn(Vector3.new(1, 0, 0), i * 90 + 45)
			k:prop("Speaker", { Position = c + dd * 10 + UP * 1, Look = -dd, Path = "Rise", Depth = 5, Time = 0.3, Hold = 2.4, Size = 2 * k.A, Color = C(255, 100, 230), Impact = "Notes", End = "Sink" })
		end
		k:zone("Dance", c, 11, 2.8, 0)
		for b = 1, 4 do
			k:later(0.4 + b * 0.45, function()
				k:shock(c, 11, C(255, 100, 230))
				for _ = 1, 2 do
					k:pillar("Lightning", G(c + Vector3.new(k:rand(-6, 6), 0, k:rand(-6, 6))), 2.2, { Color = C(255, 140, 240) })
				end
				k:area(c, 9, 0.15, { Color = C(255, 140, 240) })
			end)
		end
		if not k:wait(2.4) then
			return
		end
		k:pop("DROP!", c + UP * 8, C(255, 100, 230), 1.8)
		k:burst("Confetti", c, { Count = 30, Radius = 14 })
		k:fx("Explosion", { Position = c + UP, Radius = k:R(10), Color = C(255, 100, 230) })
		k:area(c, 11, 0.4, { KnockbackPower = 30, Lift = 45, Color = C(255, 100, 230) })
	end)

	------------------------------------------------------------ Knight Dog
	def("SK_knight_dog_2", 2, function(k)
		if not k:approach(8, 1) then
			return
		end
		k:face()
		k:pose("Guard", 0.4)
		k:shield(1.2, 0.4, "Metal", C(150, 180, 255))
		if not k:wait(0.35) then
			return
		end
		k:pose("Headbutt", 0.4)
		local d = k:dir()
		k:dash(k:tpos() - d * 1.5, 0.2, {
			frac = 1,
			radius = 3,
			opts = { Knockback = d * 40 + UP * 14, Color = C(150, 180, 255) },
			on = function(e)
				k:stun(e, 1.1, "Dizzy")
				k:pop("BASH!", e.Root.Position + UP * 4, C(150, 180, 255))
				k:impact(e.Root.Position, 4, C(150, 180, 255))
			end,
		})
	end)

	def("SK_knight_dog_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Charge", 0.7)
		k:charge(0.35, C(255, 230, 140))
		if not k:wait(0.3) then
			return
		end
		local d = k:dir()
		k:fx("Streak", { Model = k.f.Model, Color = C(255, 230, 140), Duration = 0.5, Width = 1.6, Neon = true })
		k:dash(k:tpos() - d * 1, 0.35, { frac = 0.6, radius = 3.5, opts = { Knockback = d * 25 + UP * 10, Color = C(255, 230, 140) } })
		local p = k:tground()
		k:pillar("Holy", p, 3, { Height = 22, Time = 0.2, Hold = 0.8 })
		k:prop("Lance", { Position = p + UP * 2, Path = "Fall", Height = 3, Time = 0.1, Hold = 0.9, Size = 2, Color = C(255, 230, 140), Impact = "Holy", Shake = 0.3 })
		k:area(p, 5, 0.4, { Lift = 24, Color = C(255, 230, 140) })
	end)

	def("SK_knight_dog_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Holy", 3.2)
		k:pose("Summon", 1.5)
		local c = k:tground()
		k:tele(c, 10, 1.1, C(255, 215, 90))
		k:prop("Sword", { Position = c + UP * 4.5 * k.A, Path = "Fall", Height = 50, Time = 0.9, Hold = 1.3, Size = 2 * k.A, Color = C(255, 215, 90), Impact = "Holy", Shake = 1, End = "Up" })
		if not k:wait(0.9) then
			return
		end
		k:pillar("Holy", c, 4, { Height = 30, Time = 0.15, Hold = 0.8 })
		k:area(c, 10, 0.7, { KnockbackPower = 40, Lift = 30, Color = C(255, 215, 90) })
		k:heal(0.2)
		if not k:wait(0.7) then
			return
		end
		k:shock(c, 9, C(255, 230, 140))
		k:area(c, 9, 0.3, { KnockbackPower = 20, Lift = 10, Color = C(255, 230, 140) })
	end)

	------------------------------------------------------------ Armadillo Dog
	def("SK_armadillo_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Curl", 0.3)
		if not k:wait(0.28) then
			return
		end
		k:pose("Roll", 0.7)
		local d = k:dir()
		k:dash(k:tpos() + d * 5, 0.45, { frac = 1, radius = 3.5, opts = { Knockback = d * 35 + UP * 22, Color = C(200, 170, 140) }, on = function(e)
			k:impact(e.Root.Position, 4, C(200, 170, 140))
		end })
	end)

	def("SK_armadillo_dog_3", 3, function(k)
		k:stop()
		k:pose("Curl", 0.25)
		if not k:wait(0.25) then
			return
		end
		k:pose("Roll", 1.8)
		local c = k:tpos()
		local a0 = k:rand(0, 360)
		for i = 1, 4 do
			local a = math.rad(a0 + i * 100)
			local p = c + Vector3.new(math.cos(a), 0, math.sin(a)) * 7
			if not k:dash(p, 0.28, { frac = 0.25, radius = 3.5, opts = { Knockback = Vector3.new(math.cos(a), 0, math.sin(a)) * 14 + UP * 12, Color = C(200, 170, 140) }, on = function(e)
				k:pop("PING!", e.Root.Position + UP * 4, C(255, 230, 120), 0.8)
			end }) then
				return
			end
			c = k:real() and k:tpos() or c
		end
	end)

	def("SK_armadillo_dog_4", 4, function(k)
		k:stop()
		k:sky("Dark", 3)
		k:aura("Stone", 2.8, C(170, 150, 130))
		k:shield(2.8, 0.3)
		k:orbit("Boulder", { Count = 4, Radius = 1.4, Speed = 9, Height = 0.4, Duration = 2.6, Size = 1.4 })
		k:pose("Roll", 2.8)
		local c = k:tground()
		if not k:circle(c, 6, 1.5, 1.8, { frac = 0.2, radius = 6, every = 1, opts = { Knockback = UP * 18, Color = C(170, 150, 130) } }) then
			return
		end
		local d = k:dir()
		k:dash(k:tpos() + d * 3, 0.3, { frac = 0.4, radius = 5, opts = { Knockback = d * 40 + UP * 30, Color = C(170, 150, 130) } })
		local g = k:feet()
		k:impact(g, 9, C(170, 150, 130), true)
		k:burst("Rocks", g, { Count = 14, Radius = 12 })
		k:area(g, 9, 0.4, { KnockbackPower = 20, Lift = 25, Color = C(170, 150, 130) })
	end)

	------------------------------------------------------------ Sabertooth Dog
	def("SK_saber_dog_2", 2, function(k)
		if not k:approach(8, 1) then
			return
		end
		k:face()
		k:pose("Crouch", 0.3)
		if not k:wait(0.3) then
			return
		end
		k:pose("Leap", 0.4)
		if not k:leap(k:tpos() - k:dir() * 2, 5, 0.35) then
			return
		end
		for i = 1, 2 do
			k:pose("Slash", 0.35)
			local d = k:dir()
			k:fx("Slash", { Position = k:tpos(), Direction = turn(d, i == 1 and 70 or -70), Color = C(240, 70, 80), Size = 6, Tilt = i == 1 and 40 or -40 })
			k:hit(0.35, { Color = C(240, 70, 80) })
			if not k:wait(0.25) then
				return
			end
		end
		k:dot(k.t, 3, 0.3, "Bleed")
	end)

	def("SK_saber_dog_3", 3, function(k)
		if not k:reach(k:R(16) * 0.7, 1) then
			return
		end
		k:face()
		k:pose("Roar", 0.5)
		if not k:wait(0.3) then
			return
		end
		k:pose("Open", 0.8)
		k:breath("Frost", { length = 16, angle = 35, time = 0.8, ticks = 3, frac = 0.5, color = C(170, 225, 255) })
		k:inCone(k:me(), k:dir(), 16, 35, 0.5, { Color = C(170, 225, 255) }, function(e)
			k:freeze(e, 1.5)
		end)
	end)

	def("SK_saber_dog_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Ice", 3.2)
		k:pose("Howl", 1)
		k:fx("Roar", { Model = k.f.Model, Color = C(200, 240, 255), Howl = true })
		local c = k:tground()
		for i, p in ipairs(k:around(c, 11, 8, 0)) do
			k:later(0.1 * i, function()
				k:pillar("Ice", p, 2, { Height = 12, Time = 0.25, Hold = 2 })
			end)
		end
		if not k:wait(0.9) then
			return
		end
		k:summon("Spirit", { from = k:me() - k:dir() * 6, points = { c }, time = 0.7, frac = 0.5, radius = 6, color = C(180, 230, 255), path = "Fly" })
		if not k:wait(0.75) then
			return
		end
		local d = k:dir()
		k:fx("Slash", { Position = c + UP * 2, Direction = turn(d, 45), Color = C(220, 245, 255), Size = 14, Tilt = 45 })
		k:fx("Slash", { Position = c + UP * 2, Direction = turn(d, -45), Color = C(220, 245, 255), Size = 14, Tilt = -45 })
		for _, e in ipairs(k:area(c, 10, 0.5, { KnockbackPower = 20, Lift = 20, Color = C(190, 235, 255) })) do
			k:freeze(e, 2)
		end
	end)
end
