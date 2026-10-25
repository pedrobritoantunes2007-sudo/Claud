-- 💎 HABILIDADES DOS RAROS (2026-10): 2–3 tempos e um ESTADO marcante (choque, veneno, maldição, sono, preso).
-- Frações somam ~1 (orçamento do Config.SKILL_TIER).
local SkillKit = require(script.Parent.Parent.SkillKit)

local C = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local G = SkillKit.Ground

local YELLOW = C(255, 235, 90)

return function(Specials, _Fighters)
	local function def(id, slot, fn)
		SkillKit.def(Specials, id, slot, fn)
	end

	------------------------------------------------------------ Storm Pup
	-- zigue-zague em volta do inimigo deixando raios; golpe final dá choque
	def("SK_storm_pup_2", 2, function(k)
		k:stop()
		k:charge(0.35, YELLOW)
		k:pose("Crouch", 0.35)
		if not k:wait(0.35) then
			return
		end
		local c = k:tpos()
		local prev = k:feet()
		k:pose("Dash", 1)
		local a0 = k:rand(0, 360)
		for i = 1, 3 do
			local a = math.rad(a0 + i * 120)
			local p = G(c + Vector3.new(math.cos(a), 0, math.sin(a)) * 6)
			if not k:blink(p, 2, 0.03) then
				return
			end
			local now = k:feet()
			k:path("Bolt", prev, now, { Color = YELLOW, Width = 2 })
			local seg = now - prev
			k:inLine(prev, seg, seg.Magnitude, 4, 0.15, { Color = YELLOW })
			prev = now
			if not k:wait(0.08) then
				return
			end
		end
		k:blink(c - k:dir(c) * 2.5, 1, 0.01)
		k:face(c)
		k:pillar("Lightning", G(c), 2, { Color = YELLOW })
		k:hit(0.55, { Color = YELLOW })
		k:stun(k.t, 1, "Shock")
	end)

	-- nuvem de tempestade solta 4 raios
	def("SK_storm_pup_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Summon", 1.6)
		local c = k:tground()
		k:zone("Storm", c, 9, 2.3, 0)
		for i = 1, 4 do
			if not k:wait(0.35) then
				return
			end
			local p = (i == 1 or i == 4) and k:tground() or G(c + Vector3.new(k:rand(-4, 4), 0, k:rand(-4, 4)))
			k:tele(p, 3.5, 0.25, YELLOW)
			k:later(0.25, function()
				k:pillar("Lightning", p, 2.2, { Color = YELLOW })
				for _, e in ipairs(k:area(p, 4.5, 0.25, { Color = YELLOW })) do
					k:stun(e, 0.6, "Shock")
				end
			end)
		end
	end)

	------------------------------------------------------------ Stone Hound
	-- arranca uma pedra enorme do chão e arremessa
	def("SK_stone_hound_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Dig", 0.4)
		k:burst("Rocks", k:feet() + k:dir() * 2, { Count = 6 })
		if not k:wait(0.35) then
			return
		end
		k:pose("Throw", 0.5)
		if not k:wait(0.2) then
			return
		end
		local t = k:shoot("Boulder", { speed = 40, arc = 7, frac = 0.8, radius = 5, size = 1.6, impact = "Rock" })
		k:later(t, function()
			local p = k:real() and k:tground() or nil
			if p then
				k:shock(p, 7, C(150, 130, 110), true)
				for _, e in ipairs(k:area(p, 7, 0.2, { Color = C(150, 130, 110) })) do
					k:stun(e, 0.7, "Dizzy")
				end
			end
		end)
	end)

	-- se cobre de pedras, rola 2 vezes e explode as pedras
	def("SK_stone_hound_3", 3, function(k)
		k:stop()
		k:face()
		k:aura("Stone", 2.2, C(140, 125, 110))
		k:shield(2, 0.3)
		k:pose("Curl", 0.35)
		if not k:wait(0.3) then
			return
		end
		k:pose("Roll", 1.3)
		local d = k:dir()
		local a = k:feet()
		local b = k:tpos() + d * 7
		if not k:dash(b, 0.45, { frac = 0.4, radius = 3.5, opts = { Knockback = d * 20 + UP * 14 } }) then
			return
		end
		if not k:dash(a, 0.45, { frac = 0.4, radius = 3.5, opts = { Knockback = -d * 20 + UP * 14 } }) then
			return
		end
		k:pose("Stomp", 0.4)
		local g = k:feet()
		k:shoot("Rock", { from = g + UP * 2, points = k:around(g, 9, 6, k:rand(0, 60)), speed = 35, arc = 4, frac = 0.2, radius = 3, size = 0.9 })
	end)

	------------------------------------------------------------ Robo Dog
	-- laser dos olhos varrendo
	def("SK_robo_dog_2", 2, function(k)
		if not k:reach(22, 1) then
			return
		end
		k:face()
		k:pose("Aim", 0.4)
		k:mark(k.t, "Reticle", 0.5)
		if not k:wait(0.35) then
			return
		end
		k:pose("Open", 1)
		k:beam("Laser", { length = 30, width = 3, time = 0.9, ticks = 4, frac = 1, sweep = 10, color = C(255, 60, 60) })
	end)

	-- 6 mini mísseis caem em volta do inimigo
	def("SK_robo_dog_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Aim", 0.6)
		k:charge(0.45, C(255, 120, 60))
		if not k:wait(0.45) then
			return
		end
		k:pose("Spit", 0.7)
		local pts = k:scatter(k:tpos(), 5, 6, true)
		k:shoot("Missile", { from = k:me() + UP * 2, points = pts, speed = 45, arc = 10, frac = 0.17, radius = 4, gap = 0.08, size = 0.8, trail = "Smoke", impact = "Explode" })
	end)

	------------------------------------------------------------ Horned Hound
	-- investe, joga o inimigo para cima com os chifres e chifra de novo
	def("SK_horned_pup_2", 2, function(k)
		if not k:approach(8, 1) then
			return
		end
		k:face()
		k:pose("Headbutt", 0.6)
		if not k:wait(0.2) then
			return
		end
		local d = k:dir()
		k:dash(k:tpos() - d * 1.5, 0.2, {
			frac = 0.55,
			radius = 3,
			opts = { Color = C(255, 220, 160) },
			on = function(e)
				k:launch(e, 45)
				k:impact(e.Root.Position, 4, C(255, 220, 160))
			end,
		})
		if not k:wait(0.45) then
			return
		end
		k:pose("Uppercut", 0.5)
		if not k:wait(0.2) then
			return
		end
		k:pop("TOSS!", k:tpos() + UP * 4, C(255, 210, 150))
		k:hit(0.45, { Knockback = d * 35 + UP * 15, Color = C(255, 220, 160) })
	end)

	-- manada de touros fantasmas atravessa o inimigo
	def("SK_horned_pup_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Stomp", 0.8)
		k:shake(k:me(), 0.4, 40)
		if not k:wait(0.5) then
			return
		end
		local c = k:tground()
		local d = k:dir()
		local side = Vector3.new(-d.Z, 0, d.X)
		local pts = {}
		for i = -1, 1 do
			table.insert(pts, G(c + side * i * 3 + d * 1.5))
		end
		k:summon("Bull", { from = k:feet() - d * 4, points = pts, time = 0.6, gap = 0.12, frac = 0.34, radius = 4, color = C(255, 170, 90), path = "Run" })
		k:path("Crack", k:feet(), G(c + d * 6), { Duration = 1.2, Color = C(110, 80, 50) })
	end)

	------------------------------------------------------------ Skull Dog
	-- osso bumerangue
	def("SK_skull_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Throw", 0.5)
		if not k:wait(0.22) then
			return
		end
		local t = k:shoot("Bone", { speed = 50, arc = 2, frac = 0.75, size = 1.6, back = true, backFrac = 0.25, radius = 3.5 })
		k:pose("Bow", t * 1.9)
	end)

	-- chacoalha as costelas: ossos saem do chão e amaldiçoam
	def("SK_skull_dog_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Shake", 0.8)
		if not k:wait(0.4) then
			return
		end
		local c = k:tground()
		k:zone("Grave", c, 7, 1.8, 0)
		k:ringOut("Bone", c, 7, 2, { Count = 8, Time = 0.45, Height = 1, Rise = 2.5, Size = 1.1 })
		k:later(0.4, function()
			k:burst("Bones", c, { Count = 8 })
			for _, e in ipairs(k:area(c, 7, 0.7, { Color = C(190, 130, 255) })) do
				k:curse(e, 3.5, 1.2)
			end
		end)
		k:later(1.2, function()
			k:area(c, 7, 0.3, { Color = C(190, 130, 255) })
			k:burst("Bones", c, { Count = 5 })
		end)
	end)

	------------------------------------------------------------ Crystal Dog
	-- fila de cristais brotando até o inimigo
	def("SK_crystal_hound_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Stomp", 0.4)
		if not k:wait(0.25) then
			return
		end
		k:wave("Crystal", { length = math.min(36, k:dist() + 6), width = 5, speed = 45, frac = 0.8, color = C(190, 230, 255), on = function(e)
			k:launch(e, 26)
			k:slow(e, 1.5, 0.6)
		end })
		k:later(math.min(36, k:dist() + 6) / 45, function()
			local p = k:real() and k:tground() or nil
			if p then
				k:fx("S_Burst", { Kind = "Crystals", Position = p, Count = 10, Color = C(200, 235, 255) })
				k:area(p, 5, 0.2, { Color = C(190, 230, 255) })
			end
		end)
	end)

	-- raio que se divide em 3; cura um pouco
	def("SK_crystal_hound_3", 3, function(k)
		if not k:reach(22, 1) then
			return
		end
		k:face()
		k:pose("Focus", 0.5)
		k:charge(0.5, C(220, 200, 255))
		if not k:wait(0.5) then
			return
		end
		k:pose("Open", 0.9)
		local d = k:dir()
		for _, ang in ipairs({ -22, 22 }) do
			k:fx("S_Beam", { Kind = "Ice", Model = k.f.Model, From = k:mouth(), To = k:mouth() + SkillKit.Turn(d, ang) * 22, Width = k:R(2), Duration = 0.8 })
			k:inLine(k:me(), SkillKit.Turn(d, ang), 22, 3, 0.15, { Color = C(190, 230, 255) }, function(e)
				k:slow(e, 1.5, 0.6)
			end)
		end
		k:beam("Rainbow", { length = 28, width = 3, time = 0.8, ticks = 3, frac = 0.75 })
		k:heal(0.06)
	end)

	------------------------------------------------------------ Cactus Dog
	-- leque de 7 espinhos
	def("SK_cactus_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Shake", 0.5)
		if not k:wait(0.3) then
			return
		end
		k:pose("Spit", 0.4)
		k:shoot("Needle", { count = 7, spread = 50, speed = 80, arc = 1, frac = 0.2, radius = 2.5, size = 1.4 })
	end)

	-- se planta, floresce e atira espinhos para todo lado
	def("SK_cactus_dog_3", 3, function(k)
		if not k:approach(5, 1) then
			return
		end
		k:pose("Dig", 0.6)
		k:burst("Dirt", k:feet(), { Count = 6 })
		if not k:wait(0.5) then
			return
		end
		k:pose("Focus", 0.8)
		local g = k:feet()
		k:prop("Flower", { Position = g + UP * (k.f.Root.Size.Y + 3), Path = "Spin", Time = 0.7, Hold = 0.3, Size = 3 * k.A, Spin = 2, Color = C(255, 120, 170) })
		if not k:wait(0.35) then
			return
		end
		k:shoot("Needle", { from = g + UP * 2, points = k:around(g, 8, 12, 0), speed = 70, arc = 1, frac = 0.15, radius = 3, size = 1.3 })
		for _, e in ipairs(k:area(g, 9, 0.55, { Color = C(150, 220, 110) })) do
			k:stun(e, 1.1, "Vines")
		end
	end)

	------------------------------------------------------------ Bee Dog
	-- enxame de abelhas que persegue e envenena
	def("SK_bee_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Spit", 0.6)
		local t = k:summon("Bee", { count = 2, time = 0.7, gap = 0.2, frac = 0.25, radius = 4, color = C(255, 210, 40), path = "Swarm" })
		k:later(t, function()
			k:dot(k.t, 3, 0.5, "Poison")
		end)
	end)

	-- mel grudento prende e as abelhas mergulham picando
	def("SK_bee_dog_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Throw", 0.5)
		if not k:wait(0.22) then
			return
		end
		local p = k:tground()
		local t = k:shoot("Honey", { points = { p }, speed = 40, arc = 6, frac = 0.2, radius = 5, size = 1.5, impact = "Honey" })
		k:later(t, function()
			k:zone("Honey", p, 6, 2.5, 0.2, {
				on = function(e)
					k:slow(e, 0.6, 0.35, "Honey")
				end,
			})
			k:stun(k.t, 1, "Honey")
			k:summon("Bee", { from = p + UP * 12, points = k:scatter(p, 3, 3, true), time = 0.6, gap = 0.25, frac = 0.2, radius = 4, color = C(255, 210, 40), path = "Swarm" })
		end)
	end)

	------------------------------------------------------------ Balloon Dog
	-- 3 bexigas d'água em arco
	def("SK_balloon_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Throw", 0.7)
		if not k:wait(0.2) then
			return
		end
		local c = k:tpos()
		local pts = { k:tground(), G(c + Vector3.new(k:rand(-3, 3), 0, k:rand(-3, 3))), G(c + Vector3.new(k:rand(-3, 3), 0, k:rand(-3, 3))) }
		k:shoot("Balloon", { points = pts, speed = 35, arc = 8, frac = 0.34, radius = 4, gap = 0.15, impact = "Splash", color = C(90, 170, 255) })
	end)

	-- enche e ESTOURA em confete
	def("SK_balloon_dog_3", 3, function(k)
		if not k:approach(3, 1) then
			return
		end
		k:pose("Focus", 0.8)
		k:charge(0.7, C(255, 120, 200))
		for i = 1, 3 do
			k:later(i * 0.2, function()
				k:pop(string.rep(".", i), nil, C(255, 255, 255), 0.6)
			end)
		end
		if not k:wait(0.8) then
			return
		end
		local g = k:feet()
		k:pose("Bounce", 0.5)
		k:pop("POP!", nil, C(255, 120, 200), 1.4)
		k:burst("Confetti", k:me(), { Count = 26, Radius = 12 })
		k:shock(g, 10, C(255, 160, 220))
		k:area(g, 10, 1, { KnockbackPower = 14, Lift = 40, Color = C(255, 140, 210) })
	end)

	------------------------------------------------------------ Wind-Up Dog
	-- dá corda e corre em zigue-zague como brinquedo
	def("SK_windup_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Focus", 0.55)
		k:prop("Key", { Position = k:me() + UP * (k.f.Root.Size.Y * 0.5 + 1.5), Path = "Spin", Time = 0.5, Hold = 0.6, Size = 1.5, Spin = 14 })
		k:pop("TIC TIC", nil, C(255, 220, 90), 0.6)
		if not k:wait(0.55) then
			return
		end
		k:pose("Zoom", 0.9)
		local c = k:tpos()
		local d = k:dir()
		local side = Vector3.new(-d.Z, 0, d.X)
		for i = 1, 3 do
			local p = c + side * ((i % 2 == 0) and 4 or -4) + d * (i - 2) * 3
			if not k:dash(p, 0.18, { frac = 0.33, radius = 3.5, opts = { Color = YELLOW } }) then
				return
			end
			k:burst("Stars", k:feet(), { Count = 3, Color = YELLOW })
		end
	end)

	-- pula como mola 3 vezes no inimigo
	def("SK_windup_dog_3", 3, function(k)
		k:stop()
		k:face()
		for i = 1, 3 do
			k:pose("Bounce", 0.5)
			if not k:leap(k:tpos() + Vector3.new(k:rand(-1, 1), 0, k:rand(-1, 1)), 6, 0.38) then
				return
			end
			local g = k:feet()
			k:pop("BOING!", nil, YELLOW, 0.6 + i * 0.15)
			k:shock(g, 5, YELLOW)
			k:pillar("Lightning", g, 1.5, { Color = YELLOW })
			for _, e in ipairs(k:area(g, 5, 0.33, { KnockbackPower = 10, Lift = 18, Color = YELLOW })) do
				if i == 3 then
					k:stun(e, 0.8, "Shock")
				end
			end
		end
	end)

	------------------------------------------------------------ Mushroom Dog
	-- nuvem de esporos que faz dormir
	def("SK_mushroom_dog_2", 2, function(k)
		k:stop()
		k:face()
		k:pose("Spit", 0.4)
		local p = k:tground()
		local t = k:shoot("Spore", { points = { p }, speed = 30, arc = 4, frac = 0.4, radius = 5, size = 1.5, impact = "Poison", color = C(190, 120, 230) })
		k:later(t, function()
			k:zone("Spores", p, 5, 1.6, 0.6)
			k:stun(k.t, 1.4, "Sleep")
		end)
	end)

	-- círculo de cogumelos solta veneno 3 vezes
	def("SK_mushroom_dog_3", 3, function(k)
		k:stop()
		k:face()
		k:pose("Summon", 1.2)
		local c = k:tground()
		k:zone("Spores", c, 8, 2.4, 0)
		for i = 1, 3 do
			k:later(0.5 + i * 0.55, function()
				k:fx("S_Ring", { Motif = "Spore", Position = c, R0 = k:R(8), R1 = 1, Count = 8, Time = 0.4, Height = 1, Color = C(200, 80, 200) })
				for _, e in ipairs(k:area(c, 8, 0.2, { Color = C(200, 80, 200) })) do
					k:slow(e, 0.6, 0.6)
				end
			end)
		end
		k:later(0.6, function()
			k:dot(k.t, 3, 0.4, "Poison")
		end)
	end)
end
