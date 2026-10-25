-- Poderes do Pacote B (Épicos/Lendários do DogPacks/PackB). Cada um com sua própria sequência
-- AVISO (pose + marca no chão/carga) → IMPACTO (efeito + dano) → RESÍDUO (água, ácido, gelo, fogo...),
-- pensados para duelo 1x1 (perseguem/miram no oponente). Efeitos "B_*" em client/EffectsPacks/PackB.
-- Toda espera confere se o cachorro continua vivo e lutando; velocidade/dano recebido sempre voltam.

local ZoneGeo = require(script.Parent.Parent.ZoneGeo)

local C = Color3.fromRGB

return function(Specials, Fighters)
	local A = Fighters.Alive
	local Fx = Fighters.Fx

	------------------------------------------------------------ utilidades (iguais às do Specials.lua)
	local function flat(v)
		return Vector3.new(v.X, 0, v.Z)
	end

	local function live(f)
		return A(f) and not f.Controlled
	end

	local function valid(f, t)
		return live(f) and t ~= nil and A(t) and Fighters.Hostile(f, t)
	end

	local function dirTo(f, position)
		local d = flat(position - f.Root.Position)
		if d.Magnitude < 0.01 then
			local look = flat(f.Root.CFrame.LookVector)
			return look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
		end
		return d.Unit
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local function ground(position)
		local dogs = workspace:FindFirstChild("Cachorros")
		rayParams.FilterDescendantsInstances = dogs and { dogs } or {}
		local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -80, 0), rayParams)
		return hit and hit.Position or Vector3.new(position.X, position.Y - 3, position.Z)
	end

	local function feet(f)
		return f.Root.Position - Vector3.new(0, f.Root.Size.Y / 2 + f.Humanoid.HipHeight, 0)
	end

	local function inZone(f, position)
		return ZoneGeo.Clamp(f, position, 5)
	end

	local function hold(f, seconds)
		task.wait(seconds)
		return live(f)
	end

	local function atk(f)
		return f.Stats.Atk
	end

	local function setSpeed(f, mult)
		if live(f) and not Fighters.IsFrozen(f) then
			f.Humanoid.WalkSpeed = f.Stats.Speed * (f.SpeedMult or 1) * mult
		end
	end

	local function approach(f, t, within, maxTime)
		local start = os.clock()
		setSpeed(f, 1.7)
		while valid(f, t) and os.clock() - start < maxTime do
			if Fighters.FlatDistance(f.Root.Position, t.Root.Position) - f.Radius - t.Radius <= within then
				break
			end
			f.Humanoid:MoveTo(t.Root.Position)
			task.wait(0.1)
		end
		setSpeed(f, 1)
		Fighters.Stop(f)
		return valid(f, t)
	end

	-- inimigos num retângulo que sai de origin na direção dir
	local function enemiesInLine(f, origin, dir, length, width)
		local list = {}
		for _, enemy in ipairs(Fighters.Enemies(f)) do
			local rel = flat(enemy.Root.Position - origin)
			local along = rel:Dot(dir)
			local side = (rel - dir * along).Magnitude
			if along > -2 and along < length + enemy.Radius and side < width / 2 + enemy.Radius then
				table.insert(list, enemy)
			end
		end
		return list
	end

	local function mouth(f)
		return f.Root.Position + f.Root.CFrame.LookVector * f.Radius + Vector3.new(0, f.Root.Size.Y * 0.4, 0)
	end

	-- Atordoa sem gelo (preso / dormindo / tonto): mesma regra do Fighters.Freeze, efeito próprio
	local function stun(t, seconds, fxName)
		if not A(t) then
			return
		end
		if t.Kind == "boss" then
			seconds *= 0.35
		end
		t.FrozenUntil = math.max(t.FrozenUntil or 0, os.clock() + seconds)
		t.Humanoid.WalkSpeed = 0
		Fx(fxName, { Model = t.Model, Duration = seconds })
		task.delay(seconds, function()
			if A(t) and os.clock() >= (t.FrozenUntil or 0) - 0.05 then
				t.Humanoid.WalkSpeed = t.Stats.Speed * (t.SpeedMult or 1)
			end
		end)
	end

	-- dano contínuo numa área (resíduo); para se o dono morrer
	local function areaTicks(f, center, radius, amount, ticks, interval, color)
		task.spawn(function()
			for _ = 1, ticks do
				task.wait(interval)
				if not live(f) then
					return
				end
				Fighters.DamageArea(f, center, radius, amount, { Color = color })
			end
		end)
	end

	-- envenena/sangra: dano contínuo no alvo (não para se o alvo andar)
	local function dot(f, t, amount, ticks, interval, color)
		task.spawn(function()
			for _ = 1, ticks do
				task.wait(interval)
				if not live(f) or not valid(f, t) then
					return
				end
				Fighters.Damage(f, t, amount, { Color = color })
			end
		end)
	end

	-- deixa o alvo mais lento por um tempo (respeita congelado/atordoado)
	local function slow(t, mult, seconds)
		if not A(t) or Fighters.IsFrozen(t) then
			return
		end
		local token = {}
		t.B_SlowToken = token
		t.Humanoid.WalkSpeed = t.Stats.Speed * (t.SpeedMult or 1) * mult
		task.delay(seconds, function()
			if A(t) and t.B_SlowToken == token and not Fighters.IsFrozen(t) then
				t.Humanoid.WalkSpeed = t.Stats.Speed * (t.SpeedMult or 1)
			end
		end)
	end

	local function heal(f, amount)
		if A(f) then
			f.Humanoid.Health = math.min(f.Humanoid.MaxHealth, f.Humanoid.Health + amount)
		end
	end

	------------------------------------------------------------ ÉPICOS
	-- Âncora do Capitão (Pirata): gira a âncora (aviso), arremessa presa na corrente, puxa o alvo
	-- de volta e esmaga no chão com um respingo de água que fica
	function Specials.B_AnchorHook(f, t)
		local sea = C(90, 170, 255)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Rear", 0.7)
		Fx("B_AnchorSpin", { Model = f.Model, Duration = 0.7 })
		Fx("Telegraph", { Position = ground(t.Root.Position), Radius = 5, Duration = 0.7, Color = sea })
		if not hold(f, 0.7) or not valid(f, t) then
			return
		end
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Open", 1.2)
		Fx("B_Anchor", { Model = f.Model, Target = t.Model, Duration = 1.25, Travel = 0.28 })
		if not hold(f, 0.28) or not valid(f, t) then
			return
		end
		Fighters.Damage(f, t, atk(f) * 0.8, { Color = sea })
		-- puxa até a frente do pirata
		local d = dirTo(f, t.Root.Position)
		local dist = Fighters.FlatDistance(f.Root.Position, t.Root.Position) - f.Radius - t.Radius - 2
		if dist > 1 then
			Fighters.Push(t, -d * math.clamp(dist / 0.35, 20, 120) + Vector3.new(0, 10, 0), 0.35)
		end
		if not hold(f, 0.45) or not valid(f, t) then
			return
		end
		Fighters.SetAction(f, "Slam", 0.45)
		if not hold(f, 0.12) or not valid(f, t) then
			return
		end
		local spot = ground(t.Root.Position)
		Fx("Impact", { Position = spot, Radius = 7, Color = C(200, 230, 255), Heavy = true })
		Fx("B_Splash", { Position = spot, Radius = 8, Duration = 3 })
		Fighters.Damage(f, t, atk(f) * 1.7, { Knockback = Vector3.new(0, 35, 0) + d * 12, Color = sea })
		slow(t, 0.7, 2.5)
	end

	-- Ferroada (Escorpião): ergue a cauda brilhando, crava o ferrão três vezes e deixa o alvo
	-- envenenado (dano contínuo) e lento
	function Specials.B_Stinger(f, t)
		local amber, venom = C(255, 170, 40), C(170, 255, 60)
		if not approach(f, t, 9, 1.3) then
			return
		end
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Aim", 1.6)
		Fx("EyeGlow", { Model = f.Model, Color = amber, Duration = 0.5 })
		Fx("Telegraph", { Position = ground(t.Root.Position), Radius = 4.5, Duration = 0.5, Color = amber })
		if not hold(f, 0.5) then
			return
		end
		for i = 1, 3 do
			if not valid(f, t) then
				return
			end
			Fighters.Face(f, t.Root.Position)
			Fighters.Push(f, dirTo(f, t.Root.Position) * 14, 0.08)
			Fx("B_Sting", { Model = f.Model, To = t.Root.Position, Color = i == 3 and venom or amber })
			task.wait(0.14)
			if valid(f, t) then
				Fighters.Damage(f, t, atk(f) * (i == 3 and 0.9 or 0.5), { Color = i == 3 and venom or amber })
			end
			task.wait(0.22)
		end
		if not valid(f, t) then
			return
		end
		Fx("B_Poison", { Model = t.Model, Duration = 4 })
		dot(f, t, atk(f) * 0.3, 4, 1, venom)
		slow(t, 0.6, 4)
	end

	-- Bote da Dioneia: vinhas brotam do chão e prendem o alvo; a cabeça de planta corre, abre e
	-- abocanha; o ácido que sobra fica corroendo o chão
	function Specials.B_VineSnare(f, t)
		local green, acid = C(90, 200, 70), C(180, 255, 60)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Crouch", 0.6)
		local spot = ground(t.Root.Position)
		Fx("Telegraph", { Position = spot, Radius = 6, Duration = 0.6, Color = green })
		if not hold(f, 0.6) or not valid(f, t) then
			return
		end
		spot = ground(t.Root.Position)
		Fx("B_Vines", { Position = spot, Model = t.Model, Duration = 2 })
		Fighters.Damage(f, t, atk(f) * 0.6, { Color = green })
		stun(t, 1.8, "B_Stun")
		if not approach(f, t, 2, 1.0) then
			return
		end
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Open", 0.35)
		if not hold(f, 0.3) or not valid(f, t) then
			return
		end
		local d = dirTo(f, t.Root.Position)
		Fighters.Push(f, d * 30, 0.12)
		Fighters.Bite(f)
		Fx("BiteMark", { Position = t.Root.Position, Direction = d, Color = acid, Big = true })
		Fighters.Damage(f, t, atk(f) * 1.8, { Knockback = d * 30 + Vector3.new(0, 12, 0), Color = acid })
		local pool = ground(t.Root.Position)
		Fx("B_Acid", { Position = pool, Radius = 7, Duration = 3 })
		areaTicks(f, pool, 7, atk(f) * 0.25, 3, 1, acid)
	end

	-- Bass Drop (DJ): três batidas que crescem e empurram; "drop" final que atordoa e deixa a
	-- pista de dança acesa no chão
	function Specials.B_BassDrop(f, t)
		local cyan, pink = C(0, 240, 220), C(255, 60, 200)
		if not approach(f, t, 8, 1.3) then
			return
		end
		for i = 1, 3 do
			if not live(f) then
				return
			end
			Fighters.SetAction(f, i % 2 == 0 and "Crouch" or "Roar", 0.35)
			local r = 8 + i * 2
			Fx("B_Beat", { Model = f.Model, Position = feet(f), Radius = r, Color = i % 2 == 0 and pink or cyan })
			Fighters.DamageArea(f, f.Root.Position, r, atk(f) * 0.35, { KnockbackPower = 18, Lift = 6, Color = cyan })
			task.wait(0.42)
		end
		if not live(f) then
			return
		end
		Fighters.SetAction(f, "Rear", 0.6)
		Fx("Telegraph", { Position = feet(f), Radius = 16, Duration = 0.6, Color = pink })
		if not hold(f, 0.6) then
			return
		end
		Fighters.SetAction(f, "Slam", 0.45)
		local p = feet(f)
		Fx("B_Drop", { Position = p, Radius = 16, Duration = 2.5 })
		Fx("Shake", { Position = p, Intensity = 0.7, Radius = 60, Duration = 0.5 })
		for _, enemy in ipairs(Fighters.DamageArea(f, f.Root.Position, 16, atk(f) * 1.8, { KnockbackPower = 45, Lift = 25, Color = pink })) do
			stun(enemy, 1.2, "B_Stun")
		end
	end

	-- Escudo e Lança (Cavaleiro): ergue o escudo (toma 70% menos dano) e contra-ataca com três
	-- estocadas e uma final que arremessa
	function Specials.B_ShieldLance(f, t)
		local gold = C(255, 215, 90)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Crouch", 1.1)
		Fx("B_Shield", { Model = f.Model, Duration = 1.1 })
		local token = {}
		f.B_ShieldToken = token
		f.DamageTaken = 0.3
		task.delay(1.1, function()
			if f.B_ShieldToken == token then
				f.DamageTaken = 1
			end
		end)
		for _ = 1, 4 do
			if not hold(f, 0.27) then
				return
			end
			if valid(f, t) then
				Fighters.Face(f, t.Root.Position)
			end
		end
		if not valid(f, t) then
			return
		end
		for i = 1, 4 do
			if not valid(f, t) then
				return
			end
			local d = dirTo(f, t.Root.Position)
			Fighters.Face(f, t.Root.Position)
			local final = i == 4
			Fighters.SetAction(f, "Charge", 0.22)
			Fighters.Push(f, d * (final and 60 or 35), final and 0.18 or 0.1)
			Fx("B_Thrust", { Model = f.Model, Direction = d, Length = final and 16 or 11, Color = final and gold or C(230, 235, 255) })
			task.wait(0.1)
			for _, enemy in ipairs(enemiesInLine(f, flat(f.Root.Position), d, final and 16 or 11, 5)) do
				if final then
					Fx("Impact", { Position = ground(enemy.Root.Position), Radius = 7, Color = gold, Heavy = true })
					Fighters.Damage(f, enemy, atk(f) * 1.6, { Knockback = d * 60 + Vector3.new(0, 22, 0), Color = gold })
				else
					Fighters.Damage(f, enemy, atk(f) * 0.5, { Knockback = d * 8 })
				end
			end
			task.wait(final and 0.2 or 0.18)
		end
	end

	-- Bola Blindada (Tatu): enrola numa bola de casco, quica no alvo três vezes e termina com uma
	-- quicada alta que racha o chão
	function Specials.B_RollingBall(f, t)
		local shell = C(170, 140, 110)
		Fighters.Stop(f)
		Fighters.SetAction(f, "Crouch", 0.35)
		if not hold(f, 0.3) or not valid(f, t) then
			return
		end
		Fighters.SetAction(f, "Vanish", 3)
		Fx("B_Ball", { Model = f.Model, Duration = 2.9, Color = shell })
		for _ = 1, 3 do
			if not valid(f, t) then
				break
			end
			local d = dirTo(f, t.Root.Position)
			local dist = Fighters.FlatDistance(f.Root.Position, t.Root.Position)
			local time = math.clamp(dist / 75, 0.12, 0.45)
			Fighters.Push(f, d * 75 + Vector3.new(0, 10, 0), time)
			local start = os.clock()
			while os.clock() - start < time + 0.1 do
				task.wait(0.03)
				if not live(f) then
					return
				end
				if valid(f, t) and Fighters.FlatDistance(f.Root.Position, t.Root.Position) < f.Radius + t.Radius + 1.5 then
					Fx("Impact", { Position = ground(t.Root.Position), Radius = 5, Color = shell })
					Fighters.Damage(f, t, atk(f) * 0.7, { Knockback = d * 30 + Vector3.new(0, 14, 0) })
					break
				end
			end
			-- ricochete
			Fighters.Push(f, -d * 28 + Vector3.new(0, 26, 0), 0.18)
			task.wait(0.4)
		end
		if not live(f) then
			return
		end
		if valid(f, t) then
			local d = dirTo(f, t.Root.Position)
			local dist = Fighters.FlatDistance(f.Root.Position, t.Root.Position)
			Fx("Telegraph", { Position = ground(t.Root.Position), Radius = 9, Duration = 0.55, Color = shell })
			Fighters.Push(f, d * math.clamp(dist / 0.5, 5, 80) + Vector3.new(0, 45, 0), 0.3)
		end
		if not hold(f, 0.6) then
			return
		end
		Fighters.SetAction(f, nil)
		local p = feet(f)
		Fx("Shockwave", { Position = p, Radius = 10, Color = shell, Thick = true })
		Fighters.DamageArea(f, f.Root.Position, 9, atk(f) * 1.4, { KnockbackPower = 40, Lift = 28 })
	end

	-- Fúria do Sabre: rugido que paralisa quem está perto, bote, garras em X e mordida de sabre que
	-- deixa o alvo sangrando
	function Specials.B_SaberMaul(f, t)
		local orange, blood = C(255, 160, 50), C(230, 40, 50)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Roar", 0.7)
		Fx("Roar", { Model = f.Model, Color = orange })
		if not hold(f, 0.35) or not valid(f, t) then
			return
		end
		if Fighters.FlatDistance(f.Root.Position, t.Root.Position) < 18 then
			stun(t, 0.9, "B_Stun")
		end
		if not hold(f, 0.3) or not valid(f, t) then
			return
		end
		local d = dirTo(f, t.Root.Position)
		local dist = Fighters.FlatDistance(f.Root.Position, t.Root.Position)
		Fighters.SetAction(f, "Fly", 0.45)
		Fx("Streak", { Model = f.Model, Color = orange, Duration = 0.4, Width = 1.2 })
		Fighters.Push(f, d * math.clamp(dist * 2.5, 20, 75) + Vector3.new(0, 25, 0), 0.3)
		if not hold(f, 0.45) then
			return
		end
		for i = 1, 2 do
			if not valid(f, t) then
				return
			end
			Fighters.Face(f, t.Root.Position)
			Fx("B_ClawX", { Position = t.Root.Position, Direction = dirTo(f, t.Root.Position), Color = i == 1 and C(255, 230, 200) or orange })
			Fighters.Damage(f, t, atk(f) * 0.6, { Knockback = dirTo(f, t.Root.Position) * 6, Color = orange })
			task.wait(0.22)
		end
		if not valid(f, t) then
			return
		end
		d = dirTo(f, t.Root.Position)
		Fighters.Bite(f)
		Fx("BiteMark", { Position = t.Root.Position, Direction = d, Color = blood, Big = true })
		Fighters.Damage(f, t, atk(f) * 1.3, { Knockback = d * 35 + Vector3.new(0, 14, 0), Color = blood })
		Fx("B_Bleed", { Model = t.Model, Duration = 3 })
		dot(f, t, atk(f) * 0.25, 3, 1, blood)
	end

	------------------------------------------------------------ LENDÁRIOS
	-- Chuva de Foguetes (Astronauta): liga o jato e sobe; foguetes saem da mochila em curva e caem
	-- nos círculos de aviso em volta do alvo
	function Specials.B_RocketBarrage(f, t)
		local orange = C(255, 140, 40)
		Fighters.Stop(f)
		Fighters.SetAction(f, "Float", 2.6)
		Fx("B_Jet", { Model = f.Model, Duration = 2.4 })
		Fighters.Push(f, Vector3.new(0, 14, 0), 0.4)
		if not hold(f, 0.5) then
			return
		end
		for i = 1, 6 do
			if not valid(f, t) then
				break
			end
			local spread = (i == 1 or i == 6) and 0 or 7
			local p = ground(t.Root.Position + Vector3.new(math.random(-spread, spread), 0, math.random(-spread, spread)))
			Fx("Telegraph", { Position = p, Radius = 4.5, Duration = 0.6, Color = orange })
			Fx("B_Rocket", { Model = f.Model, To = p, Duration = 0.6, Side = i % 2 == 0 and 1 or -1 })
			task.delay(0.6, function()
				if live(f) then
					Fx("Explosion", { Position = p + Vector3.new(0, 1, 0), Radius = 5, Color = orange })
					Fighters.DamageArea(f, p, 5, atk(f) * 0.75, { KnockbackPower = 18, Lift = 16, Color = orange })
				end
			end)
			task.wait(0.2)
		end
		hold(f, 0.6)
	end

	-- Avalanche (Yeti): fica de pé erguendo uma bola de neve que cresce; arremessa, ela explode,
	-- congela quem pegar e deixa o chão de gelo
	function Specials.B_Avalanche(f, t)
		local ice = C(190, 235, 255)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Rear", 1.1)
		Fx("B_Snowball", { Model = f.Model, Duration = 1.05 })
		if not hold(f, 0.6) or not valid(f, t) then
			return
		end
		local target = ground(t.Root.Position)
		Fx("Telegraph", { Position = target, Radius = 10, Duration = 1.0, Color = ice })
		if not hold(f, 0.45) then
			return
		end
		Fighters.SetAction(f, "Slam", 0.45)
		Fx("B_SnowThrow", { Model = f.Model, To = target, Duration = 0.55 })
		if not hold(f, 0.55) then
			return
		end
		Fx("B_SnowBurst", { Position = target, Radius = 10 })
		Fx("IceField", { Position = target, Radius = 8, Duration = 3, Grow = 0.3 })
		for _, enemy in ipairs(Fighters.DamageArea(f, target, 10, atk(f) * 2.1, { KnockbackPower = 35, Lift = 22, Color = ice })) do
			Fighters.Freeze(enemy, 1.6)
		end
	end

	-- Fúria Lunar (Lobisomem): uiva e a lua cheia aparece; salta em volta do alvo dando garradas
	-- que roubam vida e termina com um gancho para cima
	function Specials.B_LunarFrenzy(f, t)
		local moon, silver = C(255, 245, 200), C(200, 210, 255)
		Fighters.Stop(f)
		Fighters.SetAction(f, "Howl", 1.0)
		Fx("Roar", { Model = f.Model, Color = moon, Howl = true })
		Fx("B_Moon", { Position = f.Root.Position + Vector3.new(0, 26, 0), Duration = 3.8 })
		if not hold(f, 1.0) then
			return
		end
		local base = math.random() * math.pi * 2
		for i = 1, 4 do
			if not valid(f, t) then
				return
			end
			local a = base + i * 2.2
			local to = inZone(f, t.Root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * (t.Radius + f.Radius + 2))
			Fx("Trail", { From = f.Root.Position, To = to + Vector3.new(0, 1, 0), Color = silver, Width = 1.2, Duration = 0.3, Neon = true })
			Fighters.SetAction(f, "Dash", 0.2)
			Fighters.Teleport(f, ground(to))
			Fighters.Face(f, t.Root.Position)
			Fx("B_Claw", { Position = t.Root.Position, Direction = dirTo(f, t.Root.Position), Color = silver })
			local dmg = Fighters.Damage(f, t, atk(f) * 0.55, { Knockback = dirTo(f, t.Root.Position) * 8, Color = silver })
			if dmg > 0 then
				heal(f, dmg * 0.4)
				Fx("B_Heal", { Model = f.Model })
			end
			task.wait(0.26)
		end
		if not valid(f, t) then
			return
		end
		Fighters.SetAction(f, "Rear", 0.45)
		if not hold(f, 0.2) or not valid(f, t) then
			return
		end
		Fx("Slash", { Position = t.Root.Position, Direction = Vector3.new(0, 1, 0) + dirTo(f, t.Root.Position) * 0.3, Color = moon, Size = 9 })
		Fx("Impact", { Position = ground(t.Root.Position), Radius = 6, Color = moon })
		local dmg = Fighters.Damage(f, t, atk(f) * 1.4, { Knockback = Vector3.new(0, 55, 0), Color = moon })
		heal(f, dmg * 0.4)
	end

	-- Tinta e Tentáculos (Polvo): cospe tinta que cega (mancha preta), tentáculos saem do chão,
	-- apertam o alvo e o batem contra o chão
	function Specials.B_InkTentacles(f, t)
		local ink, pink = C(30, 20, 45), C(200, 80, 170)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Open", 0.55)
		if not hold(f, 0.3) or not valid(f, t) then
			return
		end
		Fx("Glob", { From = mouth(f), To = t.Root.Position, Duration = 0.35, Color = ink })
		if not hold(f, 0.35) or not valid(f, t) then
			return
		end
		Fx("B_Ink", { Model = t.Model, Duration = 3 })
		Fighters.Damage(f, t, atk(f) * 0.5, { Color = C(120, 90, 160) })
		slow(t, 0.5, 1)
		local spot = ground(t.Root.Position)
		Fx("Telegraph", { Position = spot, Radius = 5, Duration = 0.4, Color = pink })
		if not hold(f, 0.4) or not valid(f, t) then
			return
		end
		spot = ground(t.Root.Position)
		Fighters.SetAction(f, "Roar", 1.3)
		Fx("B_Tentacles", { Position = spot, Model = t.Model, Duration = 1.9 })
		stun(t, 1.6, "B_Stun")
		for _ = 1, 3 do
			task.wait(0.35)
			if not valid(f, t) then
				return
			end
			Fighters.Damage(f, t, atk(f) * 0.4, { Color = pink })
		end
		Fighters.Push(t, Vector3.new(0, 45, 0), 0.2)
		task.wait(0.3)
		if not valid(f, t) then
			return
		end
		Fighters.Push(t, Vector3.new(0, -100, 0), 0.15)
		task.wait(0.15)
		if valid(f, t) then
			Fx("Impact", { Position = ground(t.Root.Position), Radius = 8, Color = pink, Heavy = true })
			Fighters.Damage(f, t, atk(f) * 1.4, { Color = pink })
		end
	end

	-- Artilharia Pesada (Tanque): mira com laser vermelho, dispara um projétil enorme (o tanque
	-- recua), explosão grande e o chão fica pegando fogo
	function Specials.B_TankShell(f, t)
		local fire = C(255, 120, 30)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Aim", 1.5)
		Fx("B_LaserSight", { Model = f.Model, Target = t.Model, Duration = 1.0 })
		for _ = 1, 5 do
			if not hold(f, 0.2) then
				return
			end
			if valid(f, t) then
				Fighters.Face(f, t.Root.Position)
			end
		end
		if not valid(f, t) then
			return
		end
		local spot = ground(t.Root.Position)
		local d = dirTo(f, spot)
		Fx("Telegraph", { Position = spot, Radius = 10, Duration = 0.3, Color = fire })
		Fx("B_Shell", { Model = f.Model, To = spot, Duration = 0.3 })
		Fighters.Push(f, -d * 30, 0.15)
		if not hold(f, 0.3) then
			return
		end
		Fx("Explosion", { Position = spot + Vector3.new(0, 1, 0), Radius = 11, Color = fire })
		Fx("Shake", { Position = spot, Intensity = 0.9, Radius = 80, Duration = 0.5 })
		Fx("B_Crater", { Position = spot, Radius = 9, Duration = 3.5 })
		Fighters.DamageArea(f, spot, 10, atk(f) * 2.5, { KnockbackPower = 60, Lift = 32, Color = fire })
		areaTicks(f, spot, 7, atk(f) * 0.25, 3, 1, fire)
	end

	-- Orbes Arcanos (Feiticeiro): três orbes giram em volta, disparam um a um no alvo e um selo
	-- mágico se abre embaixo dele e explode
	function Specials.B_ArcaneOrbs(f, t)
		local arcane, magenta = C(120, 220, 255), C(255, 120, 230)
		Fighters.Stop(f)
		Fighters.SetAction(f, "Float", 2.4)
		Fx("B_Orbs", { Model = f.Model, Duration = 0.9 })
		if not hold(f, 0.9) then
			return
		end
		for i = 1, 3 do
			if not valid(f, t) then
				return
			end
			Fighters.Face(f, t.Root.Position)
			Fx("B_OrbShot", { Model = f.Model, Target = t.Model, Duration = 0.3, Color = i == 2 and magenta or arcane, Index = i })
			task.delay(0.3, function()
				if valid(f, t) then
					Fighters.Damage(f, t, atk(f) * 0.55, { Knockback = dirTo(f, t.Root.Position) * 6, Color = arcane })
				end
			end)
			task.wait(0.22)
		end
		if not valid(f, t) then
			return
		end
		local spot = ground(t.Root.Position)
		Fx("B_Seal", { Position = spot, Radius = 8, Duration = 0.9 })
		slow(t, 0.4, 0.9)
		if not hold(f, 0.9) then
			return
		end
		Fx("Explosion", { Position = spot + Vector3.new(0, 1, 0), Radius = 9, Color = C(160, 110, 255), Kind = "void" })
		Fighters.DamageArea(f, spot, 8.5, atk(f) * 1.9, { KnockbackPower = 20, Lift = 40, Color = magenta })
	end

	------------------------------------------------------------ proteção comum
	-- igual ao Specials.lua: só começa vivo e com alvo; a velocidade sempre volta ao normal
	for _, name in ipairs({
		"B_AnchorHook",
		"B_Stinger",
		"B_VineSnare",
		"B_BassDrop",
		"B_ShieldLance",
		"B_RollingBall",
		"B_SaberMaul",
		"B_RocketBarrage",
		"B_Avalanche",
		"B_LunarFrenzy",
		"B_InkTentacles",
		"B_TankShell",
		"B_ArcaneOrbs",
	}) do
		local fn = Specials[name]
		Specials[name] = function(f, t)
			if not live(f) or not (t and A(t)) then
				return
			end
			local ok, err = pcall(fn, f, t)
			if f.B_ShieldToken then
				f.B_ShieldToken = nil
				f.DamageTaken = 1
			end
			if live(f) and not f.RageToken then
				setSpeed(f, 1)
				if f.Model:GetAttribute("Action") == "Vanish" then
					Fighters.SetAction(f, nil)
				end
			end
			if not ok then
				error(err, 0)
			end
		end
	end
end
