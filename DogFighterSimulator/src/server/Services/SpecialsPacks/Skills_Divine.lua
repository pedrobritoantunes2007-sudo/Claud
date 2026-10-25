-- ☀️ HABILIDADES DO DIVINO (2026-10): o Sunfire Dragon guarda o Sunfire Breath (tecla 2) e ganha as teclas 3 e 4
-- novas, as maiores do jogo (orçamento Divino do Config.SKILL_TIER).
local SkillKit = require(script.Parent.Parent.SkillKit)

local C = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local G = SkillKit.Ground

local SUN = C(255, 200, 70)

return function(Specials, _Fighters)
	local function def(id, slot, fn)
		SkillKit.def(Specials, id, slot, fn)
	end

	-- asas em chamas: sobe, mergulha atravessando o inimigo com rastro solar e explode; cura
	def("SK_sun_dragon_3", 3, function(k)
		k:stop()
		k:face()
		k:aura("Fire", 1.8, SUN)
		k:pose("Fly", 1.8)
		k:fx("PhoenixRise", { Model = k.f.Model, Duration = 0.6 })
		if not k:rise(12, 0.45) then
			return
		end
		local c = k:tpos()
		local d = k:dir(c)
		local land = G(c + d * 9)
		k:tele(G(c), 8, 0.3, SUN)
		if not k:wait(0.25) then
			return
		end
		local start = k:feet()
		k:fx("Streak", { Model = k.f.Model, Color = SUN, Duration = 0.5, Width = 3, Neon = true, Sparks = true })
		if not k:land(land, 0.35, { frac = 0.6, radius = 6, opts = { Knockback = d * 30 + UP * 25, Color = SUN } }) then
			return
		end
		k:path("Fire", start, land, { Duration = 2.4, Width = 3.5, Color = SUN })
		k:fx("Explosion", { Position = G(c) + UP, Radius = k:R(9), Color = SUN })
		k:pillar("Holy", G(c), 4, { Height = 28, Time = 0.15, Hold = 0.6, Color = C(255, 230, 140) })
		for _, e in ipairs(k:area(G(c), 9, 0.4, { KnockbackPower = 25, Lift = 25, Color = SUN })) do
			k:dot(e, 2.5, 0.05, "Burn")
		end
		k:heal(0.15)
	end)

	-- um sol desce do céu, varre com raios solares e explode em supernova; cura
	def("SK_sun_dragon_4", 4, function(k)
		k:stop()
		k:face()
		k:sky("Gold", 3.8)
		k:pose("Summon", 2.8)
		local c = k:tground()
		local sky = c + UP * 30
		k:prop("Sun", { Position = sky, Path = "Hover", Time = 0.6, Hold = 2.6, Size = 1.8 * k.A, Spin = 0.5 })
		k:zone("Holy", c, 13, 3.4, 0, { color = SUN })
		for i = 1, 3 do
			k:later(0.6 + i * 0.4, function()
				local p = G(c + Vector3.new(k:rand(-6, 6), 0, k:rand(-6, 6)))
				k:fx("S_Beam", { Kind = "Sun", From = sky - UP * 3, To = p, Width = k:R(4), Duration = 0.6, Sweep = 25 })
				k:area(c, 10, 0.08, { Color = SUN })
				k:area(p, 5, 0.06, { Color = SUN })
			end)
		end
		for i = 1, 3 do
			k:later(0.5 + i * 0.6, function()
				k:heal(0.1)
			end)
		end
		k:later(2.6, function()
			k:fx("Explosion", { Position = c + UP * 2, Radius = k:R(16), Color = SUN })
			k:fx("S_Burst", { Kind = "Stars", Position = c, Count = 26, Radius = 18, Color = C(255, 240, 170) })
			k:shake(c, 1.4, 100)
			for _, e in ipairs(k:area(c, 16, 0.58, { KnockbackPower = 50, Lift = 40, Color = SUN })) do
				k:dot(e, 3, 0.04, "Burn")
			end
		end)
		k:wait(1.8)
	end)
end
