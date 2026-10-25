-- 🔴 HABILIDADES DOS MÍTICOS (2026-10). O golpe próprio (tecla 2) de cada Mítico continua (já era único:
-- Hell Gate, Time Stop, Kraken Grab...). As teclas 3 e 4 são NOVAS e de cinema: céu muda, criaturas e objetos
-- gigantes, vários tempos e um final forte. Frações somam ~1 do orçamento (Config.SKILL_TIER).
local SkillKit = require(script.Parent.Parent.SkillKit)

local C = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local G = SkillKit.Ground
local turn = SkillKit.Turn

local YELLOW = C(255, 235, 90)
local GOLD = C(255, 210, 90)

local function side(d)
	return Vector3.new(-d.Z, 0, d.X)
end

return function(Specials, _Fighters)
	local function def(id, slot, fn)
		SkillKit.def(Specials, id, slot, fn)
	end

	-- inimigos perto de um ponto viram destinos (criaturas que caçam); completa até n pontos
	local function huntPoints(k, center, n, radius)
		local pts = {}
		for _, e in ipairs(k:enemies(center, radius or 16)) do
			if #pts < n then
				table.insert(pts, G(e.Root.Position))
			end
		end
		while #pts < n do
			table.insert(pts, G(center + Vector3.new(k:rand(-3, 3), 0, k:rand(-3, 3))))
		end
		return pts
	end

	------------------------------------------------------------ Shadow Cerberus
	def("SK_shadow_cerberus_3", 3, function(k)
		if not k:approach(4, 1) then
			return
		end
		k:face()
		k:pose("Roar", 0.4)
		if not k:wait(0.35) then
			return
		end
		k:pose("Open", 1.3)
		local d = k:dir()
		for h = 1, 3 do
			k:fx("S_Cone", { Kind = "Fire", Model = k.f.Model, Head = h, Length = k:R(15), Angle = 24, Duration = 1.2, Color = C(255, 80, 60) })
		end
		local burned = {}
		for i = 1, 4 do
			if not k:wait(0.3) then
				return
			end
			for _, ang in ipairs({ -40, 0, 40 }) do
				k:inCone(k:me(), turn(d, ang + (i - 2.5) * 8), 15, 22, ang == 0 and 0.15 or 0.06, { Color = C(255, 80, 60) }, function(e)
					if not burned[e] then
						burned[e] = true
						k:dot(e, 3, 0.25, "Burn")
					end
				end)
			end
		end
	end)

	def("SK_shadow_cerberus_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Red", 3.4)
		k:pose("Howl", 1.4)
		k:fx("Roar", { Model = k.f.Model, Color = C(255, 70, 50), Howl = true })
		local c = k:tground()
		k:zone("Shadow", c, 12, 3.2, 0)
		k:zone("Lava", c, 6, 3.2, 0.1)
		k:later(0.5, function()
			k:summon("Hound", { from = k:me(), points = huntPoints(k, c, 3, 18), time = 0.9, gap = 0.25, frac = 0.2, radius = 5, color = C(255, 70, 50), path = "Run", on = function(e)
				k:dot(e, 2, 0.04, "Burn")
			end })
		end)
		k:later(2.2, function()
			k:fx("Explosion", { Position = c + UP, Radius = k:R(11), Color = C(255, 70, 50) })
			k:fx("Explosion", { Position = c + UP * 2, Radius = k:R(7), Color = C(90, 30, 120), Kind = "void" })
			k:area(c, 11, 0.3, { KnockbackPower = 35, Lift = 30, Color = C(255, 70, 50) })
		end)
		k:wait(1.4)
	end)

	------------------------------------------------------------ Titan Mastiff
	def("SK_titan_mastiff_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Crouch", 0.35)
		if not k:wait(0.35) then
			return
		end
		k:pose("Leap", 0.7)
		local d = k:dir()
		local land = k:me() + d * math.min(12, k:dist() * 0.5)
		if not k:leap(land, 12, 0.6) then
			return
		end
		k:pose("Slam", 0.5)
		local g = k:feet()
		k:shock(g, 9, GOLD, true)
		k:area(g, 7, 0.3, { KnockbackPower = 20, Lift = 20, Color = GOLD })
		k:wave("Spikes", { from = g, dir = d, length = 26, width = 8, speed = 45, frac = 0.7, color = GOLD, on = function(e)
			k:launch(e, 32)
		end })
		k:path("Crack", g, G(g + d * 26), { Duration = 1.6, Color = GOLD })
	end)

	def("SK_titan_mastiff_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Gold", 3.4)
		k:pose("Summon", 1.8)
		local c = k:tground()
		for i, p in ipairs(k:around(c, 8, 6, 0)) do
			k:later(0.15 * i, function()
				k:pillar("Holy", p, 2.5, { Height = 26, Time = 0.2, Hold = 1.6 })
				k:area(p, 4, 0.02, { Color = GOLD })
			end)
		end
		k:tele(c, 8, 1.6, GOLD)
		k:later(1, function()
			k:summon("Fist", { points = { c }, time = 0.6, frac = 0.6, radius = 8, color = GOLD, size = 2.5, path = "Dive", on = function(e)
				k:stun(e, 1.2, "Dizzy")
			end })
		end)
		k:later(1.65, function()
			k:shock(c, 12, GOLD, true)
			k:fx("Explosion", { Position = c + UP, Radius = k:R(10), Color = GOLD })
			k:area(c, 12, 0.3, { KnockbackPower = 30, Lift = 20, Color = GOLD })
		end)
		k:wait(1.6)
	end)

	------------------------------------------------------------ Cosmic Dog
	def("SK_cosmic_dog_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Summon", 1.4)
		local c = k:tground()
		local stars = k:around(c, 6, 5, k:rand(0, 72))
		for i, p in ipairs(stars) do
			k:later(0.1 * i, function()
				k:prop("Star", { Position = p + UP * 3, Path = "Hover", Time = 0.25, Hold = 0.9, Size = 1.6, Spin = 3, Color = C(220, 200, 255) })
			end)
		end
		k:later(0.75, function()
			for i = 1, #stars do
				k:fx("S_Line", { Kind = "Slash", From = stars[i] + UP * 3, To = stars[(i % #stars) + 1] + UP * 3, Color = C(220, 200, 255), Height = 0 })
			end
			for _, e in ipairs(k:enemies(c, k:R(7))) do
				k:pull(e, c, 14, 0.2)
			end
		end)
		k:later(1.3, function()
			k:fx("S_Burst", { Kind = "Stars", Position = c, Count = 16, Radius = 12, Color = C(220, 200, 255) })
			k:fx("Explosion", { Position = c + UP, Radius = k:R(7), Color = C(200, 170, 255), Kind = "void" })
			k:area(c, 7, 1, { KnockbackPower = 25, Lift = 25, Color = C(200, 170, 255) })
		end)
		k:wait(1)
	end)

	def("SK_cosmic_dog_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Space", 3.6)
		k:pose("Float", 2.8)
		if not k:rise(14, 0.5) then
			return
		end
		k:charge(1, C(255, 255, 255))
		k:pop("...", nil, C(255, 255, 255), 1)
		local c = k:tground()
		k:fx("Vortex", { Position = c, Radius = k:R(12), Duration = 1.2 })
		for _ = 1, 4 do
			if not k:wait(0.2) then
				return
			end
			for _, e in ipairs(k:enemies(c, k:R(14))) do
				k:pull(e, c, 20, 0.25)
			end
		end
		k:sky("Holy", 0.6)
		k:fx("Explosion", { Position = c + UP * 2, Radius = k:R(14), Color = C(200, 160, 255), Kind = "void" })
		k:fx("S_Ring", { Motif = "Star", Position = c, R0 = 1, R1 = k:R(16), Count = 16, Time = 0.8, Height = 2, Swirl = 3, Size = 1.4, Color = C(255, 240, 200) })
		k:shake(c, 1.3, 90)
		k:area(c, 14, 1, { KnockbackPower = 45, Lift = 35, Color = C(220, 190, 255) })
		if not k:wait(0.5) then
			return
		end
		k:land(nil, 0.4)
	end)

	------------------------------------------------------------ Phoenix Hound
	def("SK_phoenix_hound_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Fly", 1.6)
		k:fx("PhoenixRise", { Model = k.f.Model, Duration = 0.8 })
		if not k:rise(16, 0.5) then
			return
		end
		local c = k:tground()
		k:zone("Rune", c, 7, 0.9, 0, { color = C(255, 140, 40) })
		if not k:glide(c + UP * 18, 0.4) then
			return
		end
		k:fx("Streak", { Model = k.f.Model, Color = C(255, 130, 30), Duration = 0.5, Width = 3, Neon = true, Sparks = true })
		if not k:land(c, 0.3) then
			return
		end
		k:fx("Explosion", { Position = c + UP, Radius = k:R(9), Color = C(255, 130, 30) })
		for _, e in ipairs(k:area(c, 9, 0.75, { KnockbackPower = 30, Lift = 30, Color = C(255, 130, 30) })) do
			k:dot(e, 3, 0.1, "Burn")
		end
		k:zone("Fire", c, 7, 2.5, 0.15)
	end)

	def("SK_phoenix_hound_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Fire", 3.4)
		k:pose("Summon", 2)
		local c = k:tground()
		k:summon("Bird", { from = k:me(), points = { c }, time = 1, frac = 0.35, radius = 10, color = C(255, 140, 40), size = 9, path = "Over" })
		k:later(0.6, function()
			k:rain("Feather", k:scatter(c, 9, 10, true), { fall = 0.6, gap = 0.1, size = 2, frac = 0.04, radius = 4, impact = "Fire", height = 30, color = C(255, 150, 40), tele = false })
		end)
		k:later(2, function()
			k:fx("Explosion", { Position = c + UP, Radius = k:R(11), Color = C(255, 140, 40) })
			for _, e in ipairs(k:area(c, 11, 0.3, { KnockbackPower = 30, Lift = 30, Color = C(255, 140, 40) })) do
				k:dot(e, 3, 0.05, "Burn")
			end
			k:heal(0.25)
			k:aura("Fire", 3, C(255, 150, 40))
		end)
		k:wait(1.5)
	end)

	------------------------------------------------------------ Void Beast
	def("SK_void_beast_3", 3, function(k)
		if not k:reach(26, 1) then
			return
		end
		k:face()
		k:pose("Focus", 0.6)
		k:charge(0.6, C(170, 90, 255))
		if not k:wait(0.6) then
			return
		end
		k:pose("Open", 0.9)
		k:beam("Void", { length = 34, width = 4, time = 0.8, ticks = 3, frac = 1, color = C(170, 90, 255), on = function(e)
			k:slow(e, 2.5, 0.5)
		end })
	end)

	def("SK_void_beast_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Abyss", 3.2)
		k:pose("Summon", 1.8)
		local c = k:tground()
		k:zone("Shadow", c, 11, 2.8, 0)
		k:fx("S_Ring", { Motif = "Fang", Position = c, R0 = k:R(10), R1 = k:R(2), Count = 12, Time = 1, Height = 2, Rise = 1, Size = 3, Color = C(255, 255, 255) })
		for _ = 1, 4 do
			if not k:wait(0.25) then
				return
			end
			for _, e in ipairs(k:enemies(c, k:R(12))) do
				k:pull(e, c, 18, 0.25)
			end
		end
		k:pop("CHOMP!", c + UP * 6, C(200, 140, 255), 1.6)
		k:fx("Explosion", { Position = c + UP, Radius = k:R(9), Color = C(150, 60, 240), Kind = "void" })
		k:area(c, 9, 0.7, { KnockbackPower = 20, Lift = 35, Color = C(170, 90, 255) })
		k:summon("Tentacle", { points = k:around(c, 4, 3, k:rand(0, 120)), time = 0.45, gap = 0.15, frac = 0.1, radius = 4.5, color = C(120, 50, 200), path = "Rise" })
	end)

	------------------------------------------------------------ Five-Headed Hydra
	def("SK_hydra_hound_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Rear", 0.6)
		if not k:wait(0.5) then
			return
		end
		k:pose("Roar", 0.5)
		local poisoned = {}
		k:wave("Water", { from = k:feet(), dir = k:dir(), length = math.min(34, k:dist() + 10), width = 12, speed = 38, frac = 0.6, color = C(110, 220, 120), on = function(e)
			k:knock(e, k:me(), 20, 14)
			if not poisoned[e] then
				poisoned[e] = true
				k:dot(e, 4, 0.4, "Poison")
			end
		end })
	end)

	def("SK_hydra_hound_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Toxic", 3.4)
		k:pose("Summon", 2)
		local c = k:tground()
		k:zone("Poison", c, 9, 3, 0)
		k:summon("Snake", { points = k:around(c, 3.5, 5, k:rand(0, 72)), time = 0.6, gap = 0.25, frac = 0.16, radius = 4.5, color = C(100, 230, 110), size = 1.8, path = "Rise", on = function(e)
			k:dot(e, 2, 0.02, "Poison")
		end })
		k:later(2, function()
			k:area(c, 9, 0.12, { KnockbackPower = 25, Lift = 20, Color = C(100, 230, 110) })
			k:heal(0.3)
		end)
		k:wait(1.6)
	end)

	------------------------------------------------------------ Bone Dragon
	def("SK_bone_dragon_3", 3, function(k)
		if not k:reach(k:R(18) * 0.7, 1) then
			return
		end
		k:face()
		k:pose("Inhale", 0.4)
		if not k:wait(0.4) then
			return
		end
		k:pose("Open", 1.1)
		local cursed = {}
		k:breath("Ghost", { length = 18, angle = 30, time = 1, ticks = 4, frac = 0.85, color = C(90, 255, 220), on = function(e)
			if not cursed[e] then
				cursed[e] = true
				k:curse(e, 4, 1.2)
			end
		end })
		k:dot(k.t, 2, 0.15, "Curse")
	end)

	def("SK_bone_dragon_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Night", 3.4)
		k:pose("Summon", 2.2)
		local c = k:tground()
		k:zone("Grave", c, 12, 3.2, 0)
		k:summon("Skeleton", { points = huntPoints(k, c, 5, 16), time = 0.7, gap = 0.2, frac = 0.12, radius = 4.5, path = "Rise" })
		k:later(1.4, function()
			k:summon("Hand", { points = { c }, time = 0.5, frac = 0.2, radius = 5, path = "Rise", on = function(e)
				k:stun(e, 1.5, "Cage", C(240, 230, 200))
			end })
		end)
		k:later(2.3, function()
			k:shock(c, 11, C(110, 255, 210))
			k:area(c, 11, 0.2, { KnockbackPower = 25, Lift = 20, Color = C(110, 255, 210) })
		end)
		k:wait(1.6)
	end)

	------------------------------------------------------------ Kraken Dog
	def("SK_kraken_hound_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Summon", 1.4)
		local c = k:tground()
		k:zone("Water", c, 9, 2.6, 0.5, {
			on = function(e)
				k:pull(e, c, 18, 0.3)
			end,
		})
		for i = 1, 2 do
			k:later(0.5 + i * 0.6, function()
				local dd = turn(Vector3.new(1, 0, 0), k:rand(0, 360))
				k:prop("Tentacle", { Position = c - dd * 5, Look = dd, Path = "Swing", Time = 0.4, Hold = 0.1, Reach = 5, Size = 1.3 * k.A, Impact = "Splash", Color = C(70, 140, 230), Color2 = C(180, 220, 255), End = "Sink" })
			end)
			k:later(0.9 + i * 0.6, function()
				k:area(c, 6, 0.25, { Lift = 20, KnockbackPower = 6, Color = C(70, 140, 230) })
			end)
		end
		k:wait(0.8)
	end)

	def("SK_kraken_hound_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Abyss", 3.4)
		k:pose("Summon", 2.4)
		local c = k:tground()
		k:zone("Water", c, 13, 3.2, 0.1, {
			on = function(e)
				k:pull(e, c, 14, 0.3)
			end,
		})
		k:summon("Tentacle", { points = k:around(c, 5, 8, k:rand(0, 45)), time = 0.5, gap = 0.15, frac = 0.07, radius = 5, color = C(80, 130, 230), size = 1.6, path = "Rise" })
		k:later(2.1, function()
			k:wave("Water", { from = G(c - k:dir() * 14), dir = k:dir(), length = 30, width = 16, speed = 34, frac = 0.35, color = C(70, 120, 220) })
		end)
		k:wait(1.6)
	end)

	------------------------------------------------------------ Chrono Dog
	def("SK_chrono_hound_3", 3, function(k)
		k:stop()
		k:face()
		local home = k:feet()
		k:pose("Dash", 1.6)
		k:pop("REWIND!", nil, C(255, 235, 150), 0.9)
		local slowed = {}
		for _ = 1, 3 do
			local d = k:dir()
			if not k:dash(k:tpos() + d * 5, 0.2, { frac = 0.33, radius = 3.5, opts = { Color = C(255, 235, 150) }, on = function(e)
				if not slowed[e] then
					slowed[e] = true
					k:slow(e, 3, 0.5, "Time")
				end
			end }) then
				return
			end
			k:path("Trail", k:feet(), home, { Duration = 0.4, Width = 1.5, Color = C(255, 235, 150) })
			k:fx("Smoke", { Position = k:feet(), Color = C(220, 220, 240), Size = 3 })
			if not k:tp(home) then
				return
			end
			if not k:wait(0.12) then
				return
			end
		end
	end)

	def("SK_chrono_hound_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Time", 3.6)
		k:pose("Summon", 2.6)
		local c = k:tground()
		k:prop("Clock", { Position = c + UP * 15, Look = -k:dir(), Path = "Hover", Time = 0.4, Hold = 2.6, Size = 4 * k.A })
		k:zone("Time", c, 9, 3, 0)
		for i = 1, 6 do
			k:later(0.4 + i * 0.32, function()
				local p = i % 2 == 0 and c or G(c + Vector3.new(k:rand(-5, 5), 0, k:rand(-5, 5)))
				k:pillar("Lightning", p, 2.5, { Color = C(255, 230, 120) })
				k:pop("DONG", c + UP * 8, C(255, 235, 150), 0.6 + i * 0.1)
				k:area(p, 5, 0.1, { Color = C(255, 230, 120) })
			end)
		end
		k:later(2.5, function()
			k:fx("Explosion", { Position = c + UP, Radius = k:R(11), Color = C(255, 230, 120) })
			for _, e in ipairs(k:area(c, 11, 0.4, { KnockbackPower = 30, Lift = 25, Color = C(255, 230, 120) })) do
				k:stun(e, 1.5, "Time")
			end
		end)
		k:wait(1.6)
	end)

	------------------------------------------------------------ Singularity Pup
	def("SK_singularity_pup_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Summon", 1.3)
		local c = k:tground()
		k:zone("Gravity", c, 8, 1.4, 0)
		for _, e in ipairs(k:enemies(c, k:R(8))) do
			k:launch(e, 36)
			k:stun(e, 1, "Lift")
		end
		k:area(c, 8, 0.3, { Color = C(150, 90, 230) })
		k:later(1.05, function()
			k:shock(c, 9, C(150, 90, 230), true)
			k:fx("Explosion", { Position = c + UP, Radius = k:R(7), Color = C(150, 90, 230), Kind = "void" })
			k:burst("Rocks", c, { Count = 10 })
			k:area(c, 9, 0.7, { KnockbackPower = 10, Lift = 4, Color = C(150, 90, 230) })
		end)
		k:wait(0.9)
	end)

	def("SK_singularity_pup_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Space", 3.4)
		k:pose("Focus", 2.6)
		local c = k:tground()
		k:prop("Orb", { Position = c + UP * 7, Path = "Spin", Time = 2.2, Hold = 0.2, Size = 4 * k.A, Spin = 4, Color = C(40, 10, 70) })
		k:fx("Vortex", { Position = c, Radius = k:R(14), Duration = 2.2 })
		for _ = 1, 10 do
			if not k:wait(0.2) then
				return
			end
			for _, e in ipairs(k:enemies(c, k:R(16))) do
				k:pull(e, c, 22, 0.22)
			end
			k:area(c, 7, 0.035, { Color = C(170, 110, 255) })
		end
		k:sky("Holy", 0.6)
		k:fx("Explosion", { Position = c + UP * 2, Radius = k:R(14), Color = C(255, 255, 255) })
		k:pop("WHITE HOLE!", c + UP * 8, C(255, 255, 255), 1.4)
		k:area(c, 14, 0.65, { KnockbackPower = 50, Lift = 35, Color = C(230, 220, 255) })
	end)

	------------------------------------------------------------ Six-Winged Seraph
	def("SK_seraph_hound_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Summon", 1.4)
		k:aura("Holy", 1.6, C(255, 230, 150))
		local c = k:tground()
		k:rain("Feather", k:scatter(c, 6, 14, true), { fall = 0.45, gap = 0.06, size = 2, frac = 0.09, radius = 3.5, impact = "Holy", height = 26, color = C(255, 225, 130), tele = false })
		k:wait(1)
	end)

	def("SK_seraph_hound_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Holy", 3.4)
		k:pose("Summon", 2.4)
		local c = k:tground()
		local d = k:dir()
		k:prop("Gate", { Position = c + d * 9, Look = -d, Path = "Rise", Depth = 12, Time = 0.6, Hold = 2.2, Size = 1.4 * k.A, Impact = "Holy", End = "Sink" })
		k:later(0.7, function()
			k:summon("Spear", { points = k:scatter(c, 5, 6, true), time = 0.6, gap = 0.2, frac = 0.12, radius = 4.5, color = C(255, 230, 150), path = "Dive" })
		end)
		k:later(2.3, function()
			k:pillar("Holy", c, 5, { Height = 34, Time = 0.2, Hold = 0.8 })
			k:area(c, 10, 0.28, { KnockbackPower = 30, Lift = 25, Color = C(255, 230, 150) })
			k:heal(0.3)
		end)
		k:wait(1.6)
	end)

	------------------------------------------------------------ Crystal Golem
	def("SK_crystal_golem_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Slam", 0.5)
		if not k:wait(0.2) then
			return
		end
		local len = math.min(36, k:dist() + 6)
		k:wave("Crystal", { length = len, width = 7, speed = 40, frac = 0.8, color = C(170, 220, 255), on = function(e)
			k:launch(e, 30)
		end })
		k:later(len / 40, function()
			local p = k:real() and k:tground() or nil
			if p then
				k:fx("S_Burst", { Kind = "Crystals", Position = p, Count = 12, Radius = 10, Color = C(190, 230, 255) })
				k:area(p, 6, 0.2, { Color = C(170, 220, 255) })
			end
		end)
	end)

	def("SK_crystal_golem_4", 4, function(k)
		if not k:approach(6, 1) then
			return
		end
		k:sky("Ice", 3.2)
		k:pose("Guard", 2.4)
		k:shield(4, 0.5, "Crystal", C(200, 235, 255))
		local g = k:feet()
		for i, p in ipairs(k:around(g, 7, 8, 0)) do
			k:later(0.08 * i, function()
				k:pillar("Ice", p, 2.2, { Height = 14, Time = 0.25, Hold = 1.6 })
			end)
		end
		if not k:wait(2) then
			return
		end
		k:pose("Slam", 0.5)
		g = k:feet()
		k:shoot("Crystal", { from = g + UP * 3, points = k:around(g, 15, 12, 15), speed = 50, arc = 2, frac = 0.05, radius = 3.5, size = 1.6, impact = "Crystal", color = C(200, 235, 255) })
		k:shock(g, 13, C(200, 235, 255), true)
		for _, e in ipairs(k:area(g, 13, 0.75, { KnockbackPower = 35, Lift = 20, Color = C(200, 235, 255) })) do
			k:freeze(e, 1)
		end
	end)

	------------------------------------------------------------ Ice Phoenix
	def("SK_frost_phoenix_3", 3, function(k)
		if not k:reach(k:R(18) * 0.7, 1) then
			return
		end
		k:face()
		k:pose("Summon", 1.3)
		k:breath("Frost", { length = 18, angle = 40, time = 1, ticks = 4, frac = 0.6, color = C(170, 225, 255) })
		k:inCone(k:me(), k:dir(), 18, 40, 0.4, { Color = C(170, 225, 255) }, function(e)
			k:freeze(e, 1.3)
		end)
	end)

	def("SK_frost_phoenix_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Ice", 3.4)
		k:pose("Fly", 2.4)
		local c = k:tground()
		k:summon("Bird", { from = k:me(), points = { c }, time = 1, frac = 0.3, radius = 10, color = C(190, 235, 255), size = 9, path = "Over" })
		k:later(0.8, function()
			k:rain("Icicle", k:scatter(c, 8, 8, true), { fall = 0.6, gap = 0.1, size = 2.5, frac = 0.06, radius = 4.5, impact = "Shatter", color = C(190, 235, 255) })
		end)
		k:later(2.2, function()
			k:fx("S_Burst", { Kind = "Shards", Position = c, Count = 20, Radius = 14, Color = C(210, 240, 255) })
			for _, e in ipairs(k:area(c, 11, 0.25, { Color = C(190, 235, 255) })) do
				k:freeze(e, 2)
			end
		end)
		k:wait(1.6)
	end)

	------------------------------------------------------------ Thunder Colossus
	def("SK_thunder_colossus_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Summon", 1)
		local c = k:tground()
		k:tele(c, 7, 0.9, YELLOW)
		k:later(0.3, function()
			k:summon("Fist", { points = { c }, time = 0.6, frac = 0.8, radius = 7, color = YELLOW, size = 2, path = "Dive", on = function(e)
				k:stun(e, 1.2, "Shock")
			end })
		end)
		k:later(0.9, function()
			k:pillar("Lightning", c, 3, { Color = YELLOW })
			k:shock(c, 9, YELLOW)
			k:area(c, 9, 0.2, { KnockbackPower = 20, Lift = 15, Color = YELLOW })
		end)
		k:wait(0.8)
	end)

	def("SK_thunder_colossus_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Storm", 3.4)
		k:pose("Stomp", 2.8)
		local c = k:tground()
		k:zone("Storm", c, 12, 3, 0)
		for i = 1, 10 do
			k:later(0.25 * i, function()
				local p = i % 3 == 0 and (k:real() and k:tground() or c) or G(c + Vector3.new(k:rand(-8, 8), 0, k:rand(-8, 8)))
				k:pillar("Lightning", p, 2.4, { Color = YELLOW })
				k:area(p, 4.5, 0.07, { Color = YELLOW })
			end)
		end
		for i = 1, 4 do
			k:later(0.6 * i, function()
				k:shock(c, 12, C(255, 240, 150), true)
				k:shake(c, 0.6, 60)
				k:area(c, 12, 0.03, { Color = YELLOW })
			end)
		end
		k:later(2.8, function()
			for _, e in ipairs(k:area(c, 11, 0.2, { KnockbackPower = 25, Lift = 25, Color = YELLOW })) do
				k:stun(e, 1.2, "Shock")
			end
		end)
		k:wait(1.8)
	end)

	------------------------------------------------------------ Rainbow Unicorn
	def("SK_rainbow_unicorn_3", 3, function(k)
		if not k:reach(22, 1) then
			return
		end
		k:face()
		k:pose("Summon", 0.6)
		k:charge(0.5, C(255, 200, 255))
		if not k:wait(0.5) then
			return
		end
		k:pose("Open", 0.9)
		local d = k:dir()
		for _, ang in ipairs({ -22, 22 }) do
			k:fx("S_Beam", { Kind = "Rainbow", Model = k.f.Model, From = k:mouth(), To = k:mouth() + turn(d, ang) * 26, Width = k:R(3), Duration = 0.8 })
			k:inLine(k:me(), turn(d, ang), 26, 4, 0.15, { Color = C(255, 200, 255) })
		end
		k:beam("Rainbow", { length = 30, width = 4, time = 0.8, ticks = 3, frac = 0.85 })
	end)

	def("SK_rainbow_unicorn_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Rainbow", 3.4)
		k:pose("Victory", 2.4)
		local c = k:tground()
		local cols = { C(255, 90, 100), C(255, 220, 80), C(90, 220, 130), C(110, 170, 255), C(190, 120, 255) }
		for i, col in ipairs(cols) do
			k:later(0.2 + i * 0.25, function()
				k:rain("Star", k:scatter(c, 7, 3, i == 3), { fall = 0.55, gap = 0.08, size = 1.5, frac = 0.06, radius = 4, impact = "Stars", height = 35, color = col, tele = false })
			end)
		end
		for i = 1, 3 do
			k:later(0.6 * i, function()
				k:heal(0.08)
			end)
		end
		k:later(2.1, function()
			k:fx("S_Burst", { Kind = "Confetti", Position = c, Count = 30, Radius = 14 })
			k:area(c, 11, 0.3, { KnockbackPower = 30, Lift = 25, Color = C(255, 180, 240) })
		end)
		k:wait(1.6)
	end)

	------------------------------------------------------------ Oni Samurai
	def("SK_demon_samurai_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Slash", 1.4)
		local lines = {}
		for i = 1, 3 do
			local d = k:dir()
			local s = side(d) * ((i % 2 == 0) and 3 or -3)
			local from = k:feet()
			local to = k:tpos() + d * 6 + s
			if not k:dash(to, 0.16, { frac = 0.18, radius = 3.5, opts = { Color = C(255, 90, 50) } }) then
				return
			end
			k:path("Fire", from, k:feet(), { Duration = 1.2, Width = 2.5, Color = C(255, 90, 50) })
			table.insert(lines, { from, k:feet() })
			k:face()
			if not k:wait(0.1) then
				return
			end
		end
		k:later(0.5, function()
			for _, l in ipairs(lines) do
				local seg = l[2] - l[1]
				k:fx("Explosion", { Position = l[1]:Lerp(l[2], 0.5) + UP, Radius = k:R(4), Color = C(255, 90, 50) })
				k:inLine(l[1], seg, seg.Magnitude, 5, 0.15, { Color = C(255, 90, 50) })
			end
		end)
	end)

	def("SK_demon_samurai_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Red", 3.4)
		k:pose("Summon", 2.4)
		local c = k:tground()
		k:prop("Mask", { Position = c + UP * 24, Look = -k:dir(), Path = "Hover", Time = 0.5, Hold = 2.4, Size = 4 * k.A })
		k:prop("Tornado", { Position = c, Path = "Spin", Time = 2.2, Hold = 0.3, Size = 4 * k.A, Spin = 10, Color = C(255, 80, 40) })
		local center = k.t and k.t.Model or nil
		if center then
			k:fx("S_Orbit", { Model = center, Motif = "Blade", Count = 4, Radius = 3.5, Speed = 8, Height = 2, Duration = 1.9, Size = 1.6, Color = C(255, 80, 40), End = "Burst" })
		end
		for i = 1, 8 do
			k:later(0.25 * i, function()
				for _, e in ipairs(k:area(c, 6, 0.08, { Color = C(255, 90, 50) })) do
					k:pull(e, c, 10, 0.2)
				end
			end)
		end
		k:later(2.3, function()
			k:fx("Explosion", { Position = c + UP, Radius = k:R(10), Color = C(255, 80, 40) })
			for _, e in ipairs(k:area(c, 10, 0.36, { KnockbackPower = 35, Lift = 30, Color = C(255, 80, 40) })) do
				k:dot(e, 2, 0.04, "Burn")
			end
		end)
		k:wait(1.6)
	end)

	------------------------------------------------------------ Omega Mecha Dog
	def("SK_mecha_hound_3", 3, function(k)
		if not k:reach(28, 1) then
			return
		end
		k:face()
		k:pose("Aim", 0.8)
		k:charge(0.8, C(120, 230, 255))
		if not k:wait(0.8) then
			return
		end
		k:pose("Open", 1)
		k:shake(k:me(), 0.6, 50)
		k:beam("Photon", { length = 40, width = 6, time = 1, ticks = 4, frac = 1, color = C(120, 230, 255) })
	end)

	def("SK_mecha_hound_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Dark", 3.4)
		k:pose("Aim", 2.6)
		local c = k:tground()
		local spots = huntPoints(k, c, 4, 18)
		for i, p in ipairs(spots) do
			k:later(0.1 * i, function()
				for _, e in ipairs(k:enemies(p, 3)) do
					k:mark(e, "Reticle", 1.2)
				end
				k:tele(p, 4, 0.9, C(120, 230, 255))
			end)
			k:later(1 + i * 0.3, function()
				k:pillar("Plasma", p, 3.5, { Height = 45, Time = 0.12, Hold = 0.5, Color = C(120, 230, 255) })
				k:area(p, 5, 0.18, { Lift = 20, KnockbackPower = 10, Color = C(120, 230, 255) })
			end)
		end
		k:later(0.6, function()
			k:shoot("Missile", { from = k:me() + UP * 3, points = k:scatter(c, 6, 6, true), speed = 45, arc = 12, frac = 0.04, radius = 4, gap = 0.06, size = 0.9, trail = "Smoke", impact = "Explode" })
		end)
		k:later(2.4, function()
			k:pillar("Plasma", c, 6, { Height = 50, Time = 0.15, Hold = 0.7, Color = C(150, 240, 255) })
			k:fx("Explosion", { Position = c + UP, Radius = k:R(10), Color = C(120, 230, 255) })
			k:area(c, 10, 0.22, { KnockbackPower = 30, Lift = 26, Color = C(120, 230, 255) })
		end)
		k:wait(1.6)
	end)

	------------------------------------------------------------ Planet Dog
	def("SK_planet_hound_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Summon", 1.4)
		local c = k:tground()
		k:zone("Flowers", c, 9, 2.6, 0.3, {
			on = function(e)
				k:slow(e, 0.6, 0.6)
			end,
		})
		for i, p in ipairs(k:around(c, 4, 3, k:rand(0, 120))) do
			k:later(0.3 * i, function()
				k:pillar("Water", p, 2.4, { Height = 16, Time = 0.2, Hold = 0.5 })
				k:area(p, 4.5, 0.15, { Lift = 30, KnockbackPower = 4, Color = C(90, 170, 255) })
			end)
		end
		k:later(1.3, function()
			for _, e in ipairs(k:area(c, 9, 0.25, { Color = C(110, 220, 120) })) do
				k:stun(e, 1, "Vines")
			end
		end)
		k:wait(1)
	end)

	def("SK_planet_hound_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Space", 3.6)
		k:pose("Summon", 2.4)
		local c = k:tground()
		k:tele(c, 12, 1, C(90, 200, 255))
		k:prop("Planet", { Position = c + UP * 4 * k.A, Path = "Fall", Height = 60, Time = 1, Hold = 0.6, Size = 3 * k.A, Color = C(90, 170, 110), Color2 = C(200, 230, 255), Impact = "Explode", Shake = 1.2 })
		k:later(1, function()
			k:area(c, 12, 0.5, { KnockbackPower = 40, Lift = 35, Color = C(90, 200, 255) })
			k:rain("Rock", k:scatter(c, 10, 8, false), { fall = 0.5, gap = 0.08, size = 2, frac = 0.03, radius = 4, impact = "Rock", height = 25, tele = false })
		end)
		k:later(1.6, function()
			for i = 0, 3 do
				k:wave("Water", { from = c, dir = turn(k:dir(), i * 90 + 45), length = 16, width = 10, speed = 32, frac = 0.06, color = C(70, 150, 240) })
			end
		end)
		k:later(2.1, function()
			k:zone("Flowers", c, 10, 2, 0.15, {
				on = function(e)
					k:slow(e, 0.6, 0.6)
				end,
			})
		end)
		k:wait(1.6)
	end)
end
