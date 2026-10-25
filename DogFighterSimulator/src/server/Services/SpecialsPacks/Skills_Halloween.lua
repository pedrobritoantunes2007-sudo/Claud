-- 🎃 HABILIDADES DO HALLOWEEN (2026-10): o Spooky Clown. Os 2 clones dele (Services/CloneService) soltam a MESMA
-- habilidade junto, cada um um pouco ao lado da setinha — por isso cada poder é curto, rápido e fica bonito em 3.
-- Orçamento = o do Mítico (Config.SKILL_TIER.Halloween); frações somam ~1.
local SkillKit = require(script.Parent.Parent.SkillKit)

local C = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)

local CREAM = C(255, 248, 235)
local ORANGE = C(255, 135, 30)
local PURPLE = C(150, 60, 220)
local LIME = C(150, 235, 60)

return function(Specials, _Fighters)
	local function def(id, slot, fn)
		SkillKit.def(Specials, id, slot, fn)
	end

	-- 🥧 TORTA NA CARA: 3 tortas de creme em leque até a setinha; quem leva fica lento (creme no olho)
	def("SK_clown_dog_2", 2, function(k)
		k:face()
		k:pose("Throw", 0.5)
		if not k:wait(0.12) then
			return
		end
		k:shoot("Pie", {
			count = 3,
			spread = 22,
			speed = 85,
			arc = 3,
			spin = 6,
			frac = 0.3,
			radius = 4.5,
			impact = "Splash",
			size = 1.6,
			color = CREAM,
			on = function(e)
				k:slow(e, 1.6, 0.6, "Honey")
			end,
		})
		k:later(0.35, function()
			k:pop("SPLAT!", k:tground() + UP * 5, CREAM, 1.1)
		end)
		k:wait(0.3)
	end)

	-- 🎁 CAIXA-SURPRESA: a caixa sobe do chão na setinha, a tampa abre — BOING! — o palhaço de mola pula, joga
	-- todo mundo para cima e deixa tonto; confete para todo lado
	def("SK_clown_dog_3", 3, function(k)
		k:face()
		k:pose("Summon", 0.6)
		local c = k:tground()
		local d = k:dir(c)
		k:tele(c, 7, 0.4, ORANGE)
		k:prop("JackBox", { Position = c, Path = "Grow", Time = 0.35, Hold = 1.3, Size = 2.4 * k.A, Look = -d, Impact = "Confetti", Radius = 6, Shake = 0.3 })
		if not k:wait(0.4) then
			return
		end
		k:pop("BOING!", c + UP * 7, LIME, 1.4)
		k:burst("Confetti", c + UP * 3, { Count = 30, Radius = 8 })
		for _, e in ipairs(k:area(c, 7, 0.6, { KnockbackPower = 12, Lift = 40, Color = ORANGE })) do
			k:stun(e, 1.1, "Dizzy", PURPLE)
		end
		k:shake(c, 0.5, 40)
		k:later(0.55, function()
			k:burst("Confetti", c + UP * 2, { Count = 18, Radius = 6 })
			k:area(c, 8, 0.35, { KnockbackPower = 25, Lift = 15, Color = LIME })
		end)
	end)

	-- 🎪 CIRCO DO TERROR (Supremo): uma tenda de circo assombrada cai na setinha, o céu fica laranja, abóboras chovem
	-- em volta, cabeças de palhaço voam para fora e tudo termina numa explosão de confete que joga longe
	def("SK_clown_dog_4", 4, function(k)
		k:face()
		k:sky("Spooky", 3.2)
		k:pose("Summon", 2)
		local c = k:tground()
		k:tele(c, 13, 0.5, ORANGE)
		k:prop("BigTop", { Position = c, Path = "Fall", Time = 0.45, Hold = 2.3, Size = 3 * k.A, Impact = "Confetti", Radius = 10, Shake = 0.7, End = "Sink" })
		k:zone("Shadow", c, 13, 3, 0.2, { color = PURPLE })
		k:later(0.5, function()
			k:rain("Pumpkin", k:scatter(c, 12, 7), { fall = 0.5, gap = 0.12, radius = 4, frac = 0.04, impact = "Explode", color = ORANGE, size = 1.3 })
		end)
		k:later(1.5, function()
			k:ringOut("ClownHead", c, 2, 12, { Time = 0.7, Count = 8 })
			k:pop("HA HA HA!", c + UP * 10, ORANGE, 1.6)
		end)
		k:later(2.3, function()
			k:fx("Explosion", { Position = c + UP * 2, Radius = k:R(13), Color = ORANGE })
			k:burst("Confetti", c + UP * 4, { Count = 60, Radius = 14 })
			k:shake(c, 1.2, 80)
			for _, e in ipairs(k:area(c, 13, 0.5, { KnockbackPower = 45, Lift = 35, Color = ORANGE })) do
				k:stun(e, 1.2, "Dizzy", ORANGE)
			end
		end)
		k:wait(1.2)
	end)
end
