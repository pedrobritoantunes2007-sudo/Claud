-- 🟡 HABILIDADES DOS LENDÁRIOS (2026-10): mais tempos, mais área e Supremos maiores (céu muda, objetos
-- gigantes, criaturas). Frações somam ~1 do orçamento de cada tecla (Config.SKILL_TIER).
local SkillKit = require(script.Parent.Parent.SkillKit)

local C = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local G = SkillKit.Ground
local turn = SkillKit.Turn

local YELLOW = C(255, 235, 90)
local FIRE = C(255, 130, 40)

local function side(d)
	return Vector3.new(-d.Z, 0, d.X)
end

return function(Specials, _Fighters)
	local function def(id, slot, fn)
		SkillKit.def(Specials, id, slot, fn)
	end

	------------------------------------------------------------ Dragon Hound
	def("SK_dragon_hound_2", 2, function(k)
		if not k:reach(k:R(18) * 0.7, 1) then
			return
		end
		k:face()
		k:pose("Inhale", 0.45)
		if not k:wait(0.45) then
			return
		end
		k:pose("Open", 1.2)
		k:breath("Fire", {
			length = 18,
			angle = 30,
			time = 1.2,
			ticks = 4,
			frac = 0.75,
			color = FIRE,
		})
		k:dot(k.t, 2.5, 0.25, "Burn")
	end)

	def("SK_dragon_hound_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Fly", 1.6)
		k:fx("PhoenixRise", { Model = k.f.Model, Duration = 0.6 })
		if not k:rise(14, 0.5) then
			return
		end
		local c = k:tpos()
		local d = k:dir(c)
		local land = G(c + d * 8)
		k:tele(G(c), 6, 0.35, FIRE)
		if not k:wait(0.3) then
			return
		end
		k:fx("Streak", { Model = k.f.Model, Color = FIRE, Duration = 0.5, Width = 2.5, Neon = true, Sparks = true })
		local start = k:feet()
		if not k:land(land, 0.4, { frac = 0.6, radius = 5, opts = { Knockback = d * 25 + UP * 25, Color = FIRE } }) then
			return
		end
		k:path("Fire", start, land, { Duration = 2.2, Width = 3, Color = FIRE })
		k:fx("Explosion", { Position = land + UP, Radius = k:R(6), Color = FIRE })
		k:area(land, 6, 0.25, { KnockbackPower = 16, Lift = 18, Color = FIRE })
		k:zone("Fire", G(c), 5, 2, 0.15)
	end)

	def("SK_dragon_hound_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Fire", 3.4)
		k:pose("Fly", 3.2)
		k:fx("PhoenixRise", { Model = k.f.Model, Duration = 1 })
		if not k:rise(18, 0.5) then
			return
		end
		local c = k:tground()
		local pts = {}
		for i = 1, 8 do
			local a = math.rad(i * 70)
			local r = 2 + i * 0.9
			table.insert(pts, G(c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)))
		end
		table.insert(pts, 1, c)
		k:rain("Meteor", pts, { fall = 0.7, gap = 0.13, size = 2, frac = 0.07, radius = 5, impact = "Explode", height = 45 })
		if not k:wait(0.9) then
			return
		end
		k:face(c)
		k:fx("S_Beam", { Kind = "Fire", Model = k.f.Model, From = k:mouth(), To = c, Width = k:R(5), Duration = 0.8 })
		k:later(0.4, function()
			k:fx("Explosion", { Position = c + UP, Radius = k:R(10), Color = FIRE })
			for _, e in ipairs(k:area(c, 10, 0.4, { KnockbackPower = 30, Lift = 26, Color = FIRE })) do
				k:dot(e, 3, 0.1, "Burn")
			end
			k:zone("Lava", c, 8, 2, 0)
		end)
		if not k:wait(0.55) then
			return
		end
		k:land(nil, 0.35)
	end)

	------------------------------------------------------------ Twin Fang
	def("SK_twin_fang_2", 2, function(k)
		if not k:approach(3, 1) then
			return
		end
		local cols = { C(150, 80, 220), C(255, 245, 200) }
		for i = 1, 4 do
			k:face()
			k:fx("Bite", { Model = k.f.Model, Head = (i % 2) + 1 })
			k:fx("BiteMark", { Position = k:tpos(), Direction = turn(k:dir(), i % 2 == 0 and 30 or -30), Color = cols[(i % 2) + 1] })
			if i == 4 then
				k:hit(0.25, { Crit = true, Knockback = k:dir() * 30 + UP * 12, Color = cols[1] })
			else
				k:hit(0.17, { Color = cols[(i % 2) + 1] })
			end
			if not k:wait(0.2) then
				return
			end
		end
	end)

	def("SK_twin_fang_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Summon", 1.2)
		k:fx("S_Orbit", { Model = k.f.Model, Motif = "Orb", Count = 2, Radius = 2, Speed = 6, Height = 2, Duration = 0.8, Size = 1.3, Colors = { C(255, 245, 200), C(80, 30, 140) }, End = "Fire", Target = k:real() and k.t.Model or nil, To = k:tground() })
		if not k:wait(1.1) then
			return
		end
		local c = k:tground()
		k:fx("Explosion", { Position = c + UP * 2, Radius = k:R(7), Color = C(150, 80, 220), Kind = "void" })
		k:pillar("Holy", c, 3, { Height = 18, Time = 0.15, Hold = 0.4, Color = C(255, 245, 200) })
		k:area(c, 7, 1, { KnockbackPower = 22, Lift = 22, Color = C(200, 150, 255) })
	end)

	def("SK_twin_fang_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Dark", 3.2)
		k:pose("Summon", 2.2)
		local c = k:tground()
		local pts = k:around(c, 5, 6, k:rand(0, 60))
		for i, p in ipairs(pts) do
			k:later(0.2 + i * 0.25, function()
				local light = i % 2 == 0
				k:pillar(light and "Holy" or "Shadow", p, 2.5, { Height = 22, Time = 0.15, Hold = 0.4, Color = light and C(255, 245, 200) or C(90, 40, 150) })
				k:area(p, 4.5, 0.1, { Color = light and C(255, 245, 200) or C(150, 80, 220) })
			end)
		end
		if not k:wait(2) then
			return
		end
		k:prop("Moon", { Position = c + UP * 12, Path = "Hover", Time = 0.3, Hold = 0.4, Size = 3, Color = C(40, 20, 70) })
		k:fx("Explosion", { Position = c + UP, Radius = k:R(11), Color = C(200, 150, 255), Kind = "void" })
		k:area(c, 11, 0.45, { KnockbackPower = 30, Lift = 30, Color = C(220, 180, 255) })
		k:heal(0.2)
	end)

	------------------------------------------------------------ Velocity Hound
	def("SK_velocity_hound_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Crouch", 0.25)
		if not k:wait(0.25) then
			return
		end
		local d = k:dir()
		k:pose("Dash", 0.5)
		k:fx("SonicBoom", { Position = k:me(), Direction = d, Radius = k:R(5), Color = C(150, 230, 255) })
		k:aura("Haste", 0.6, C(150, 230, 255))
		k:dash(k:tpos() + d * 10, 0.28, { frac = 1, radius = 4, opts = { Knockback = d * 45 + UP * 18, Color = C(150, 230, 255) } })
		k:fx("SonicBoom", { Position = k:me(), Direction = d, Radius = k:R(7), Color = C(220, 245, 255) })
	end)

	def("SK_velocity_hound_3", 3, function(k)
		k:stop()
		k:pose("Dash", 1.3)
		k:aura("Storm", 1.4, YELLOW)
		local c = k:tpos()
		local prev = k:feet()
		local lines = {}
		for i = 1, 5 do
			local a = math.rad(i * 144 + k:rand(-15, 15))
			local p = G(c + Vector3.new(math.cos(a), 0, math.sin(a)) * 7)
			if not k:dash(p, 0.14, { frac = 0.08, radius = 3.5, opts = { Color = YELLOW } }) then
				return
			end
			k:path("Bolt", prev, k:feet(), { Color = YELLOW, Width = 2 })
			table.insert(lines, { prev, k:feet() })
			prev = k:feet()
		end
		k:later(0.3, function()
			for _, l in ipairs(lines) do
				local seg = l[2] - l[1]
				k:pillar("Lightning", l[1]:Lerp(l[2], 0.5), 1.5, { Color = YELLOW })
				k:inLine(l[1], seg, seg.Magnitude, 5, 0.12, { Color = YELLOW })
			end
		end)
	end)

	def("SK_velocity_hound_4", 4, function(k)
		k:stop()
		k:sky("Storm", 3.2)
		k:pose("Dash", 2.6)
		k:aura("Storm", 2.6, YELLOW)
		local c = k:tground()
		k:fx("Streak", { Model = k.f.Model, Color = YELLOW, Duration = 2, Width = 1.8, Neon = true, Sparks = true })
		k:prop("Tornado", { Position = c, Path = "Spin", Time = 1.6, Hold = 0.4, Size = 4 * k.A, Spin = 12, Color = C(255, 240, 150) })
		if not k:circle(c, 6, 3, 1.6, { frac = 0.12, radius = 5, every = 1, opts = { Knockback = UP * 12, Color = YELLOW } }) then
			return
		end
		for _ = 1, 3 do
			k:pillar("Lightning", G(c + Vector3.new(k:rand(-4, 4), 0, k:rand(-4, 4))), 2.5, { Color = YELLOW })
		end
		k:area(c, 7, 0.2, { Color = YELLOW })
		local d = k:dir()
		k:fx("SonicBoom", { Position = k:me(), Direction = d, Radius = k:R(8), Color = YELLOW })
		k:dash(k:tpos() + d * 14, 0.25, { frac = 0.44, radius = 5, opts = { Knockback = d * 60 + UP * 30, Color = YELLOW } })
	end)

	------------------------------------------------------------ Storm Wolf
	def("SK_storm_wolf_2", 2, function(k)
		if not k:approach(3, 1) then
			return
		end
		k:face()
		k:pose("Leap", 0.3)
		k:fx("Bite", { Model = k.f.Model, Head = 1 })
		k:pillar("Lightning", k:tground(), 1.8, { Color = YELLOW })
		k:hit(0.6, { Color = YELLOW })
		k:stun(k.t, 0.6, "Shock")
		local from = k:tpos()
		local n = 0
		for _, e in ipairs(k:enemies(from, 14)) do
			if e ~= k.t and n < 2 then
				n += 1
				k:fx("S_Line", { Kind = "Bolt", From = from, To = e.Root.Position, Color = YELLOW, Width = 1.5 })
				k:dmg(e, 0.4, { Color = YELLOW })
				k:stun(e, 0.5, "Shock")
			end
		end
		if n == 0 then
			k:hit(0.4, { Color = YELLOW })
		end
	end)

	def("SK_storm_wolf_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Howl", 1.2)
		k:fx("Roar", { Model = k.f.Model, Color = C(200, 230, 255), Howl = true })
		local c = k:tground()
		k:prop("Tornado", { Position = c, Path = "Spin", Time = 1.5, Hold = 0.3, Size = 3.4 * k.A, Spin = 10, Color = C(210, 235, 255) })
		for i = 1, 4 do
			k:later(0.3 * i, function()
				k:pillar("Lightning", G(c + Vector3.new(k:rand(-4, 4), 0, k:rand(-4, 4))), 2, { Color = YELLOW })
				for _, e in ipairs(k:area(c, 7, 0.22, { Color = C(210, 235, 255) })) do
					k:pull(e, c, 14, 0.25)
				end
			end)
		end
		k:later(1.5, function()
			k:area(c, 8, 0.12, { KnockbackPower = 30, Lift = 30, Color = YELLOW })
		end)
		k:wait(0.6)
	end)

	def("SK_storm_wolf_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Storm", 3.2)
		k:pose("Howl", 1.4)
		k:fx("Roar", { Model = k.f.Model, Color = YELLOW, Howl = true })
		local c = k:tground()
		k:zone("Storm", c, 12, 3, 0)
		local pts = {}
		for _, e in ipairs(k:enemies(c, 18)) do
			if #pts < 4 then
				table.insert(pts, G(e.Root.Position))
			end
		end
		while #pts < 4 do
			table.insert(pts, G(c + Vector3.new(k:rand(-3, 3), 0, k:rand(-3, 3))))
		end
		k:summon("Wolf", { from = k:me(), points = pts, time = 0.8, gap = 0.2, frac = 0.18, radius = 5, color = YELLOW, path = "Run", on = function(e)
			k:stun(e, 0.6, "Shock")
		end })
		k:later(1.9, function()
			for _ = 1, 3 do
				k:pillar("Lightning", G(c + Vector3.new(k:rand(-5, 5), 0, k:rand(-5, 5))), 2.5, { Color = YELLOW })
			end
			k:area(c, 10, 0.28, { KnockbackPower = 20, Lift = 20, Color = YELLOW })
		end)
		k:wait(1.6)
	end)

	------------------------------------------------------------ Inferno Hound
	def("SK_inferno_hound_2", 2, function(k)
		if not k:approach(3, 1) then
			return
		end
		k:pose("Roar", 0.6)
		if not k:wait(0.25) then
			return
		end
		local g = k:feet()
		k:ringOut("Flame", g, 1, 11, { Count = 12, Time = 0.55, Height = 0.5, Size = 1.4, Color = FIRE })
		k:fx("FireRing", { Position = g, Radius = k:R(9), Duration = 1 })
		for _, e in ipairs(k:area(g, 10, 0.7, { KnockbackPower = 20, Lift = 12, Color = FIRE })) do
			k:dot(e, 3, 0.3, "Burn")
		end
	end)

	def("SK_inferno_hound_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Stomp", 0.9)
		local from = k:feet() + k:dir() * 3
		local to = G(k:tpos() + k:dir() * 2)
		for i, p in ipairs(k:lineOf(from, to, 5)) do
			k:later(0.15 + i * 0.15, function()
				k:tele(p, 3, 0.15, FIRE)
			end)
			k:later(0.3 + i * 0.15, function()
				k:pillar("Fire", p, 2.6, { Height = 18, Time = 0.18, Hold = 0.6 })
				for _, e in ipairs(k:area(p, 4, 0.2, { Lift = 24, KnockbackPower = 6, Color = FIRE })) do
					k:dot(e, 1.5, 0.04, "Burn")
				end
			end)
		end
		k:wait(0.9)
	end)

	def("SK_inferno_hound_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Fire", 3.2)
		k:pose("Summon", 1.6)
		local c = k:tground()
		k:zone("Lava", c, 12, 3, 0.3)
		k:zone("Crack", c, 12, 3, 0, { color = C(255, 110, 30) })
		k:prop("Tornado", { Position = c, Path = "Spin", Time = 2, Hold = 0.4, Size = 4.5 * k.A, Spin = 9, Color = C(255, 120, 40) })
		for i = 1, 5 do
			k:later(0.3 * i, function()
				for _, e in ipairs(k:area(c, 7, 0.08, { Color = FIRE })) do
					k:pull(e, c, 16, 0.25)
				end
			end)
		end
		k:later(0.8, function()
			k:rain("Meteor", k:scatter(c, 9, 5, false), { fall = 0.7, gap = 0.2, size = 1.6, frac = 0.06, radius = 4.5, impact = "Explode", height = 45 })
		end)
		k:later(2.2, function()
			k:fx("Explosion", { Position = c + UP, Radius = k:R(11), Color = FIRE })
			for _, e in ipairs(k:area(c, 11, 0.3, { KnockbackPower = 30, Lift = 30, Color = FIRE })) do
				k:dot(e, 3, 0.1, "Burn")
			end
		end)
		k:wait(1.6)
	end)

	------------------------------------------------------------ Shadow Doberman
	def("SK_shadow_doberman_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Shadow", 0.9)
		local from = k:feet()
		local to = k:tground()
		k:path("Trail", from, to, { Duration = 1, Width = 3, Color = C(40, 15, 60) })
		if not k:blink(to, 6, 0.08) then
			return
		end
		k:pose("Leap", 0.4)
		k:fx("Bite", { Model = k.f.Model, Head = 1 })
		k:pillar("Shadow", to, 2.5, { Height = 10, Time = 0.15, Hold = 0.3 })
		k:area(to, 4.5, 1, { Lift = 40, KnockbackPower = 6, Color = C(140, 80, 220) })
		k:leap(to + k:dir() * 1, 4, 0.35)
	end)

	def("SK_shadow_doberman_3", 3, function(k)
		k:stop()
		k:pose("Roar", 0.6)
		local c = k:tground()
		local a0 = k:rand(0, 360)
		for i = 1, 4 do
			local a = math.rad(a0 + i * 90)
			local from = G(c + Vector3.new(math.cos(a), 0, math.sin(a)) * 12)
			k:summon("Shade", { from = from, points = { c }, time = 0.55 + i * 0.05, frac = 0.25, radius = 4, color = C(130, 70, 200) })
		end
		k:later(0.85, function()
			k:fx("Explosion", { Position = c + UP, Radius = k:R(6), Color = C(130, 70, 200), Kind = "void" })
		end)
		k:wait(0.5)
	end)

	def("SK_shadow_doberman_4", 4, function(k)
		k:stop()
		k:sky("Night", 3.2)
		k:pose("Shadow", 2.6)
		k:zone("Shadow", k:tground(), 12, 3, 0)
		for i = 1, 8 do
			if not k:wait(0.17) then
				return
			end
			local a = math.rad(i * 137)
			local p = G(k:tpos() + Vector3.new(math.cos(a), 0, math.sin(a)) * 4)
			k:tp(p)
			k:fx("Bite", { Model = k.f.Model, Head = 1 })
			k:fx("BiteMark", { Position = k:tpos(), Direction = k:dir(), Color = C(220, 60, 80) })
			k:hit(0.06, { Color = C(170, 90, 230) })
		end
		if not k:wait(0.25) then
			return
		end
		k:behind(2)
		k:pose("Leap", 0.5)
		k:fx("Explosion", { Position = k:tpos(), Radius = k:R(7), Color = C(140, 80, 220), Kind = "void" })
		k:hit(0.26, { Crit = true, Knockback = k:dir() * 40 + UP * 20, Color = C(220, 60, 80) })
	end)

	------------------------------------------------------------ Celestial Dog
	def("SK_celestial_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Summon", 0.9)
		local c = k:tground()
		k:rain("Star", k:scatter(c, 4, 6, true), { fall = 0.6, gap = 0.1, size = 1.4, frac = 0.18, radius = 4, impact = "Stars", height = 40, color = C(255, 240, 150) })
		k:wait(0.5)
	end)

	def("SK_celestial_dog_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Summon", 1.4)
		k:aura("Holy", 1.6, C(255, 245, 200))
		local c = k:tground()
		k:rain("Feather", k:scatter(c, 7, 10, true), { fall = 0.5, gap = 0.08, size = 1.8, frac = 0.1, radius = 4, impact = "Feathers", height = 30, color = C(255, 245, 200), tele = false })
		k:later(1, function()
			k:area(c, 8, 0.4, { Color = C(255, 245, 200) })
			k:heal(0.1)
		end)
		k:wait(0.9)
	end)

	def("SK_celestial_dog_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Space", 3.4)
		k:pose("Summon", 2.6)
		local c = k:tground()
		local stars = k:around(c, 9, 6, 0)
		for i, p in ipairs(stars) do
			k:later(0.15 * i, function()
				k:prop("Star", { Position = p + UP * 12, Path = "Hover", Time = 0.3, Hold = 1.4, Size = 1.8, Spin = 2, Color = C(220, 230, 255) })
			end)
		end
		k:later(1.1, function()
			for i = 1, #stars do
				local a, b = stars[i] + UP * 12, stars[(i % #stars) + 1] + UP * 12
				k:fx("S_Line", { Kind = "Slash", From = a, To = b, Color = C(200, 220, 255), Height = 0 })
			end
		end)
		if not k:wait(1.8) then
			return
		end
		k:summon("Spirit", { from = c + UP * 14, points = { c }, time = 0.6, frac = 0.6, radius = 7, color = C(200, 220, 255), path = "Dive" })
		k:later(0.6, function()
			k:fx("S_Burst", { Kind = "Stars", Position = c, Count = 20, Radius = 14, Color = C(220, 230, 255) })
			k:area(c, 10, 0.4, { KnockbackPower = 30, Lift = 25, Color = C(200, 220, 255) })
		end)
	end)

	------------------------------------------------------------ Astro Dog
	def("SK_astronaut_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Aim", 0.5)
		if not k:wait(0.3) then
			return
		end
		k:pose("Spit", 0.6)
		k:shoot("Rocket", { from = k:me() + UP * 2, count = 4, spread = 30, speed = 55, arc = 4, frac = 0.25, radius = 4, gap = 0.1, trail = "Smoke", impact = "Explode", size = 0.9 })
	end)

	def("SK_astronaut_dog_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Summon", 1.6)
		local c = k:tground()
		k:zone("Gravity", c, 9, 1.8, 0)
		local lifted = k:enemies(c, k:R(9))
		for _, e in ipairs(lifted) do
			k:launch(e, 30)
			k:stun(e, 1.2, "Lift")
		end
		k:area(c, 9, 0.3, { Color = C(180, 160, 255) })
		k:later(1.3, function()
			k:shock(c, 9, C(180, 160, 255), true)
			k:area(c, 9, 0.7, { KnockbackPower = 10, Lift = 4, Color = C(180, 160, 255) })
			k:burst("Rocks", c, { Count = 8 })
		end)
		k:wait(0.8)
	end)

	def("SK_astronaut_dog_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Space", 3.4)
		k:pose("Focus", 0.5)
		k:prop("Rocket", { Position = k:feet() + UP * 2, To = k:feet() + UP * 40, Path = "Fly", Time = 0.8, Size = 3 * k.A })
		k:pose("Fly", 2)
		if not k:rise(30, 0.8) then
			return
		end
		local c = k:tground()
		k:tele(c, 11, 1, C(255, 200, 80))
		if not k:wait(0.6) then
			return
		end
		k:fx("Streak", { Model = k.f.Model, Color = C(255, 200, 80), Duration = 0.5, Width = 3, Neon = true, Sparks = true })
		if not k:land(c, 0.4) then
			return
		end
		k:pose("Slam", 0.5)
		k:fx("Explosion", { Position = c + UP, Radius = k:R(12), Color = C(255, 210, 120) })
		k:fx("S_Burst", { Kind = "Stars", Position = c, Count = 24, Radius = 16, Color = C(255, 230, 150) })
		k:shake(c, 1.2, 80)
		k:area(c, 12, 1, { KnockbackPower = 40, Lift = 35, Color = C(255, 210, 120) })
	end)

	------------------------------------------------------------ Yeti Dog
	def("SK_yeti_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Rear", 0.6)
		k:prop("Snowball", { Position = k:me() + UP * (k.f.Root.Size.Y + 3), Path = "Hover", Time = 0.25, Hold = 0.2, Size = 3 })
		if not k:wait(0.45) then
			return
		end
		k:pose("Throw", 0.5)
		local t = k:shoot("Snowball", { speed = 40, arc = 8, frac = 0.8, radius = 6, size = 3, impact = "Snow" })
		k:later(t, function()
			for _, e in ipairs(k:area(k:real() and k:tground() or k:feet() + k:dir() * 20, 6, 0.2, { Color = C(230, 245, 255) })) do
				k:slow(e, 2, 0.5)
			end
		end)
	end)

	def("SK_yeti_dog_3", 3, function(k)
		if not k:approach(6, 1) then
			return
		end
		k:pose("Stomp", 0.8)
		if not k:wait(0.3) then
			return
		end
		local g = k:feet()
		local d = k:dir()
		for i = 0, 3 do
			k:wave("Ice", { from = g, dir = turn(d, i * 90), length = 18, width = 6, speed = 40, frac = i == 0 and 0.6 or 0.15, color = C(180, 225, 255), on = function(e)
				k:launch(e, 24)
				k:slow(e, 1.5, 0.6)
			end })
		end
		k:shock(g, 8, C(180, 225, 255), true)
		k:area(g, 8, 0.25, { Color = C(180, 225, 255) })
	end)

	def("SK_yeti_dog_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Ice", 3.2)
		k:pose("Roar", 0.8)
		k:fx("Roar", { Model = k.f.Model, Color = C(220, 245, 255) })
		local c = k:tground()
		k:zone("Snow", c, 13, 3, 0.2, {
			on = function(e)
				k:slow(e, 0.6, 0.6)
			end,
		})
		local pts = { c }
		for _, p in ipairs(k:around(c, 6, 3, k:rand(0, 120))) do
			table.insert(pts, p)
		end
		k:later(0.5, function()
			k:summon("Fist", { points = pts, time = 0.6, gap = 0.35, frac = 0.18, radius = 5, color = C(200, 235, 255), path = "Dive" })
		end)
		k:later(2.1, function()
			for _, e in ipairs(k:area(c, 9, 0.1, { Color = C(200, 235, 255) })) do
				k:freeze(e, 1.5)
			end
		end)
		k:wait(1.6)
	end)

	------------------------------------------------------------ Werewolf Dog
	def("SK_werewolf_dog_2", 2, function(k)
		if not k:approach(3, 1) then
			return
		end
		for i = 1, 5 do
			k:face()
			k:pose("Slash", 0.25)
			local d = k:dir()
			k:fx("Slash", { Position = k:tpos(), Direction = turn(d, (i % 2 == 0) and 70 or -70), Color = C(200, 90, 255), Size = 6, Tilt = (i % 2 == 0) and 35 or -35 })
			k:hit(i == 5 and 0.28 or 0.18, { Knockback = d * (i == 5 and 30 or 5), Color = C(200, 90, 255) })
			if not k:wait(0.18) then
				return
			end
		end
	end)

	def("SK_werewolf_dog_3", 3, function(k)
		if not k:approach(6, 1) then
			return
		end
		k:pose("Howl", 1.2)
		k:prop("Moon", { Position = k:me() + UP * 16, Path = "Hover", Time = 0.4, Hold = 1.4, Size = 3, Color = C(235, 235, 255) })
		k:fx("Roar", { Model = k.f.Model, Color = C(230, 230, 255), Howl = true })
		k:rage(5, 1.3, "Shadow", C(140, 80, 220))
		if not k:wait(0.6) then
			return
		end
		local g = k:feet()
		k:shock(g, 12, C(200, 200, 255))
		for _, e in ipairs(k:area(g, 13, 0.8, { KnockbackPower = 18, Lift = 10, Color = C(200, 90, 255) })) do
			k:slow(e, 2.5, 0.5, "Fear")
		end
	end)

	def("SK_werewolf_dog_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Red", 3.2)
		k:pose("Howl", 1)
		k:prop("Moon", { Position = k:me() + UP * 20, Path = "Hover", Time = 0.5, Hold = 2.2, Size = 5, Color = C(255, 70, 80) })
		k:rage(3, 1.2, "Rage", C(255, 70, 80))
		if not k:wait(0.9) then
			return
		end
		local d = k:dir()
		for i = 1, 3 do
			k:pose("Slash", 0.35)
			local c = k:tground()
			local dir = turn(d, (i - 2) * 35)
			k:fx("Slash", { Position = c + UP * 2, Direction = dir, Color = C(255, 70, 80), Size = 16, Tilt = (i - 2) * 30 })
			k:path("Crack", c - dir * 9, c + dir * 9, { Duration = 1.6, Color = C(255, 60, 70) })
			k:inLine(c - dir * 9, dir, 18, 5, 0.27, { Knockback = dir * 20 + UP * 12, Color = C(255, 70, 80) })
			if not k:wait(0.35) then
				return
			end
		end
	end)

	------------------------------------------------------------ Octopus Dog
	def("SK_octopus_dog_2", 2, function(k)
		if not k:reach(k:R(15) * 0.7, 1) then
			return
		end
		k:face()
		k:pose("Spit", 0.6)
		k:breath("Ink", { length = 15, angle = 30, time = 0.6, ticks = 2, frac = 0.4 })
		local c = k:tground()
		k:zone("Ink", c, 7, 2.5, 0.6, {
			on = function(e)
				k:slow(e, 0.6, 0.5, "Ink")
			end,
		})
	end)

	def("SK_octopus_dog_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Summon", 1.2)
		local c = k:tground()
		for i = 1, 4 do
			k:later((i - 1) * 0.22, function()
				local dd = turn(Vector3.new(1, 0, 0), i * 90 + 45)
				local base = c - dd * 5
				k:prop("Tentacle", { Position = base, Look = dd, Path = "Swing", Time = 0.4, Hold = 0.1, Reach = 5, Size = 1.1 * k.A, Impact = "Splash", Color = C(170, 90, 200), Color2 = C(230, 170, 240), End = "Sink" })
			end)
			k:later((i - 1) * 0.22 + 0.4, function()
				k:area(c, 5, 0.25, { Lift = 18, KnockbackPower = 8, Color = C(170, 90, 200) })
			end)
		end
		k:wait(0.8)
	end)

	def("SK_octopus_dog_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Abyss", 3.2)
		k:pose("Summon", 2)
		local c = k:tground()
		k:zone("Water", c, 12, 3, 0.25, {
			on = function(e)
				k:pull(e, c, 18, 0.3)
			end,
		})
		k:summon("Tentacle", { points = k:around(c, 6, 6, k:rand(0, 60)), time = 0.5, gap = 0.2, frac = 0.08, radius = 5, color = C(90, 60, 180), path = "Rise" })
		k:later(2, function()
			k:wave("Water", { from = G(c - k:dir() * 12), dir = k:dir(), length = 24, width = 14, speed = 32, frac = 0.35, color = C(60, 50, 140) })
		end)
		k:wait(1.6)
	end)

	------------------------------------------------------------ Tank Dog
	def("SK_tank_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Aim", 0.5)
		if not k:wait(0.4) then
			return
		end
		k:pose("Spit", 0.4)
		k:shake(k:me(), 0.3, 30)
		k:shoot("Shell", { from = k:mouth(), speed = 90, arc = 1, frac = 1, radius = 5, size = 1.5, trail = "Smoke", impact = "Explode" })
	end)

	def("SK_tank_dog_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Aim", 1)
		local c = k:tground()
		k:mark(k.t, "Reticle", 1)
		k:rain("Shell", k:scatter(c, 6, 6, true), { fall = 0.9, gap = 0.12, size = 1.2, frac = 0.2, radius = 4.5, impact = "Explode", height = 45 })
		k:wait(0.7)
	end)

	def("SK_tank_dog_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Dark", 3.2)
		k:pose("Bark", 0.6)
		k:pop("AIR STRIKE!", nil, C(255, 200, 80), 1.2)
		local c = k:tground()
		local d = k:dir()
		local s = side(d)
		for lane = -1, 1 do
			local pts = k:lineOf(c - d * 8 + s * lane * 5, c + d * 8 + s * lane * 5, 4)
			k:later(0.3 + (lane + 1) * 0.35, function()
				k:summon("Plane", { from = c - d * 60, points = pts, time = 0.9, gap = 0.12, frac = 0.07, radius = 5, size = 1.2 })
			end)
		end
		k:later(2.4, function()
			k:fx("Explosion", { Position = c + UP, Radius = k:R(10), Color = C(255, 140, 50) })
			k:area(c, 10, 0.3, { KnockbackPower = 30, Lift = 26, Color = C(255, 140, 50) })
		end)
		k:wait(1.4)
	end)

	------------------------------------------------------------ Wizard Dog
	def("SK_wizard_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Summon", 1.1)
		local cols = { C(255, 120, 40), C(150, 220, 255), C(255, 235, 90) }
		k:fx("S_Orbit", { Model = k.f.Model, Motif = "ArcaneOrb", Count = 3, Radius = 2.2, Speed = 5, Height = 2.5, Duration = 0.8, Size = 1.2, Colors = cols, End = "Fire", Target = k:real() and k.t.Model or nil, To = k:tground() })
		k:later(1.05, function()
			k:hit(0.3, { Color = cols[1] })
			k:dot(k.t, 2, 0.1, "Burn")
		end)
		k:later(1.13, function()
			k:hit(0.25, { Color = cols[2] })
			k:slow(k.t, 2, 0.6)
		end)
		k:later(1.21, function()
			k:hit(0.25, { Color = cols[3] })
			k:stun(k.t, 0.6, "Shock")
		end)
		k:wait(0.9)
	end)

	def("SK_wizard_dog_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Summon", 1.6)
		local c = k:tground()
		k:zone("Rune", c, 9, 1.8, 0, { color = C(200, 140, 255) })
		local kinds = { "Fire", "Ice", "Lightning" }
		for i, p in ipairs(k:around(c, 6, 3, k:rand(0, 120))) do
			k:later(0.3 + i * 0.25, function()
				k:pillar(kinds[i], p, 2.6, { Height = 20, Time = 0.2, Hold = 0.8 })
				k:area(p, 4.5, 0.12, { Color = C(220, 160, 255) })
			end)
		end
		k:later(1.5, function()
			k:fx("Explosion", { Position = c + UP, Radius = k:R(8), Color = C(200, 140, 255) })
			for _, e in ipairs(k:area(c, 8, 0.64, { KnockbackPower = 25, Lift = 25, Color = C(220, 160, 255) })) do
				k:dot(e, 2, 0.05, "Burn")
				k:slow(e, 2, 0.6)
			end
		end)
		k:wait(1)
	end)

	def("SK_wizard_dog_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Space", 3.4)
		k:pose("Summon", 2.8)
		local c = k:tground()
		k:zone("Rune", c, 13, 3.2, 0, { color = C(190, 130, 255) })
		k:later(0.4, function()
			k:rain("Meteor", { c, G(c + Vector3.new(5, 0, 3)), G(c + Vector3.new(-4, 0, -4)) }, { fall = 0.8, gap = 0.25, size = 2.4, frac = 0.12, radius = 6, impact = "Explode", height = 50 })
		end)
		k:later(1.2, function()
			k:zone("Snow", c, 10, 1.6, 0.15, {
				on = function(e)
					k:slow(e, 0.6, 0.5)
				end,
			})
		end)
		for i = 1, 4 do
			k:later(1.4 + i * 0.25, function()
				k:pillar("Lightning", G(c + Vector3.new(k:rand(-5, 5), 0, k:rand(-5, 5))), 2.5, { Color = YELLOW })
				k:area(c, 9, 0.05, { Color = YELLOW })
			end)
		end
		k:later(2.7, function()
			k:fx("Explosion", { Position = c + UP, Radius = k:R(12), Color = C(200, 140, 255) })
			k:area(c, 12, 0.3, { KnockbackPower = 35, Lift = 35, Color = C(220, 160, 255) })
		end)
		k:wait(1.6)
	end)
end
