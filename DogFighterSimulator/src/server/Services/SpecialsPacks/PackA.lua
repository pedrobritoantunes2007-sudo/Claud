-- Poderes do Pacote A (cachorros Comuns/Incomuns/Raros do DogPacks/PackA).
-- Mesmo ritmo dos poderes base: AVISO (pose + marca no chão) → IMPACTO (efeito + dano) → RESÍDUO.
-- Toda espera confere se o cachorro continua vivo e lutando; a velocidade de andar é sempre restaurada
-- (o CombatService também restaura ao fim do poder). Efeitos novos "A_*" ficam em client/EffectsPacks/PackA.

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

	local function enemiesInCone(f, origin, dir, length, angleDeg)
		local list = {}
		local cosA = math.cos(math.rad(angleDeg))
		for _, enemy in ipairs(Fighters.Enemies(f)) do
			local rel = flat(enemy.Root.Position - origin)
			if rel.Magnitude < length + enemy.Radius and (rel.Magnitude < 2 + enemy.Radius or rel.Unit:Dot(dir) > cosA) then
				table.insert(list, enemy)
			end
		end
		return list
	end

	local function blink(f, from, to, steps, stepTime)
		local d = flat(to - from)
		for k = 1, steps do
			if not live(f) then
				return false
			end
			Fighters.Teleport(f, ground(from:Lerp(to, k / steps)))
			if d.Magnitude > 0.1 then
				Fighters.Face(f, f.Root.Position + d)
			end
			task.wait(stepTime)
		end
		return live(f)
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

	------------------------------------------------------------ COMUNS
	-- Bumbum Saltitante (Corgi): agacha, pula de costas e cai sentado; quica mais duas vezes menores
	function Specials.A_CorgiBounce(f, t)
		local peach = C(255, 205, 150)
		if not approach(f, t, 7, 1.2) then
			return
		end
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Crouch", 0.5)
		Fx("Telegraph", { Position = ground(t.Root.Position), Radius = 8, Duration = 0.85, Color = peach })
		if not hold(f, 0.45) or not valid(f, t) then
			return
		end
		local d = dirTo(f, t.Root.Position)
		local dist = Fighters.FlatDistance(f.Root.Position, t.Root.Position)
		Fighters.SetAction(f, "Fly", 0.6)
		Fx("Streak", { Model = f.Model, Color = C(255, 240, 220), Duration = 0.45, Width = 1.1 })
		Fighters.Push(f, d * math.clamp(dist * 2.4, 15, 60) + Vector3.new(0, 38, 0), 0.32)
		if not hold(f, 0.55) then
			return
		end
		Fighters.SetAction(f, "Sit", 0.9)
		Fx("A_Boing", { Position = feet(f), Radius = 9, Color = peach })
		Fighters.DamageArea(f, f.Root.Position, 8, atk(f) * 1.5, { KnockbackPower = 28, Lift = 36, Color = peach })
		for i = 1, 2 do
			Fighters.Push(f, Vector3.new(0, 24 - i * 6, 0), 0.14)
			if not hold(f, 0.38) then
				return
			end
			Fx("A_Boing", { Position = feet(f), Radius = 7 - i * 1.5, Color = peach, Small = true })
			Fighters.DamageArea(f, f.Root.Position, 6.5 - i, atk(f) * 0.4, { KnockbackPower = 15, Lift = 20, Color = peach })
		end
	end

	-- Latido Estridente (Chihuahua): treme de raiva e solta três latidos em cone; o último atordoa
	function Specials.A_YapBlast(f, t)
		local pink = C(255, 150, 200)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Crouch", 0.65)
		Fx("A_Angry", { Model = f.Model, Duration = 0.65 })
		if not hold(f, 0.6) or not valid(f, t) then
			return
		end
		for i = 1, 3 do
			if not valid(f, t) then
				return
			end
			Fighters.Face(f, t.Root.Position)
			local d = dirTo(f, t.Root.Position)
			Fighters.SetAction(f, "Roar", 0.28)
			Fx("A_YapCone", { Model = f.Model, Direction = d, Length = 15, Angle = 32, Color = pink, Big = i == 3 })
			for _, enemy in ipairs(enemiesInCone(f, flat(f.Root.Position), d, 15, 32)) do
				Fighters.Damage(f, enemy, atk(f) * (i == 3 and 0.8 or 0.5), { Knockback = d * (i == 3 and 40 or 18), Color = pink })
				if i == 3 then
					stun(enemy, 1.1, "A_Dizzy")
				end
			end
			task.wait(0.32)
		end
	end

	------------------------------------------------------------ INCOMUNS
	-- Imobilização K9 (Pastor Alemão): fareja, a mira trava no alvo, salta e o prende mordendo
	function Specials.A_K9Takedown(f, t)
		local red = C(255, 70, 60)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Crouch", 1.0)
		Fx("A_Sniff", { Model = f.Model, Duration = 0.9 })
		Fx("A_Reticle", { Model = t.Model, Duration = 0.95, Color = red })
		for _ = 1, 3 do
			if not valid(f, t) then
				return
			end
			Fighters.Face(f, t.Root.Position)
			task.wait(0.3)
		end
		if not valid(f, t) then
			return
		end
		local d = dirTo(f, t.Root.Position)
		local dist = Fighters.FlatDistance(f.Root.Position, t.Root.Position)
		Fighters.SetAction(f, "Fly", 0.5)
		Fx("Streak", { Model = f.Model, Color = C(255, 230, 200), Duration = 0.4, Width = 1.2 })
		Fighters.Push(f, d * math.clamp(dist * 2.8, 25, 85) + Vector3.new(0, 26, 0), 0.3)
		if not hold(f, 0.42) then
			return
		end
		if not valid(f, t) or Fighters.FlatDistance(f.Root.Position, t.Root.Position) > f.Radius + t.Radius + 6 then
			Fx("Smoke", { Position = feet(f), Color = C(190, 170, 140), Size = 4 })
			return
		end
		Fighters.Stop(f)
		Fx("Impact", { Position = ground(t.Root.Position), Radius = 6, Color = C(255, 230, 200) })
		Fighters.Damage(f, t, atk(f) * 0.8, { Color = red })
		stun(t, 1.4, "A_Pin")
		for _ = 1, 3 do
			if not hold(f, 0.3) or not valid(f, t) then
				return
			end
			Fighters.Face(f, t.Root.Position)
			Fighters.Bite(f)
			Fx("BiteMark", { Position = t.Root.Position, Direction = t.Root.Position - f.Root.Position, Color = C(255, 230, 210) })
			Fighters.Damage(f, t, atk(f) * 0.45, { Color = red })
		end
		if hold(f, 0.15) and valid(f, t) then
			Fighters.Damage(f, t, atk(f) * 0.6, { Knockback = dirTo(f, t.Root.Position) * 40 + Vector3.new(0, 20, 0), Color = red })
		end
	end

	-- Frisbee Perfeito (Border Collie): o disco faz a curva por trás do alvo e o collie salta por cima
	-- dele para pegar no ar (o salto também acerta)
	function Specials.A_Frisbee(f, t)
		local disc = C(255, 90, 60)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Open", 0.4)
		if not hold(f, 0.35) or not valid(f, t) then
			return
		end
		local d = dirTo(f, t.Root.Position)
		local right = Vector3.new(-d.Z, 0, d.X)
		local side = math.random() < 0.5 and -1 or 1
		local from = mouth(f)
		local tp = t.Root.Position
		local landing = inZone(f, tp + d * (t.Radius + f.Radius + 7))
		local catchAt = ground(landing) + Vector3.new(0, f.Root.Size.Y + f.Humanoid.HipHeight + 1.5, 0)
		local control = tp + right * side * (t.Radius + 9) + Vector3.new(0, 3, 0)
		local flight = 0.9
		Fx("A_Frisbee", { From = from, Control = control, To = catchAt, Duration = flight, Color = disc })
		Fx("Telegraph", { Position = ground(landing), Radius = 5, Duration = flight, Color = C(255, 200, 120) })
		-- o disco passa pelo alvo na curva
		task.delay(flight * 0.45, function()
			if valid(f, t) then
				Fighters.Damage(f, t, atk(f) * 0.6, { Knockback = right * -side * 14, Color = disc })
			end
		end)
		if not hold(f, 0.3) then
			return
		end
		-- corre e salta por cima do alvo
		local travel = flat(ground(landing) - f.Root.Position)
		local air = flight - 0.35
		Fighters.SetAction(f, "Fly", air + 0.1)
		Fx("Streak", { Model = f.Model, Color = C(255, 255, 255), Duration = air, Width = 1, Neon = true })
		Fighters.Push(f, travel / air + Vector3.new(0, 30, 0), air * 0.55)
		local start = os.clock()
		local hit = false
		while os.clock() - start < air do
			if not live(f) then
				return
			end
			if not hit and valid(f, t) and Fighters.FlatDistance(f.Root.Position, t.Root.Position) < f.Radius + t.Radius + 2 then
				hit = true
				Fighters.Damage(f, t, atk(f) * 1.2, { Knockback = Vector3.new(0, 38, 0) + d * 10, Color = C(255, 240, 200) })
			end
			task.wait(0.03)
		end
		Fighters.Bite(f)
		Fx("A_Catch", { Model = f.Model, Color = disc })
		Fx("Impact", { Position = feet(f), Radius = 5, Color = C(255, 240, 220) })
		if not hit then
			Fighters.DamageArea(f, f.Root.Position, 6, atk(f) * 0.8, { KnockbackPower = 25 })
		end
	end

	-- Avalanche (São Bernardo): uiva, a bola de neve rola crescendo até o alvo e soterra a área
	function Specials.A_Avalanche(f, t)
		local snow = C(235, 245, 255)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Howl", 0.9)
		Fx("Roar", { Model = f.Model, Color = C(200, 230, 255), Howl = true })
		local target = ground(t.Root.Position)
		Fx("Telegraph", { Position = target, Radius = 7, Duration = 1.45, Color = C(200, 230, 255) })
		if not hold(f, 0.75) or not valid(f, t) then
			return
		end
		local d = dirTo(f, target)
		local from = feet(f) + d * (f.Radius + 1)
		local finish = target + d * 2
		local roll = math.clamp(Fighters.FlatDistance(from, finish) / 40, 0.45, 0.9)
		Fighters.SetAction(f, "Roar", roll)
		Fx("A_Snowball", { From = from, To = finish, Duration = roll, R0 = 1, R1 = 4.5 })
		if not hold(f, roll) then
			return
		end
		Fx("Impact", { Position = target, Radius = 8, Color = snow, Heavy = true })
		Fx("A_SnowPatch", { Position = target, Radius = 7.5, Duration = 3.5 })
		for _, enemy in ipairs(Fighters.DamageArea(f, target, 7, atk(f) * 2, { KnockbackPower = 35, Lift = 28, Color = snow })) do
			Fighters.Freeze(enemy, 0.9)
		end
	end

	------------------------------------------------------------ RAROS
	-- Rajada de Espinhos (Cão Cacto): incha, dispara três leques de espinhos; os que caem no chão
	-- continuam furando quem pisar
	function Specials.A_CactusVolley(f, t)
		local green = C(150, 230, 110)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Crouch", 0.7)
		Fx("A_Puff", { Model = f.Model, Duration = 0.65, Color = green })
		Fx("A_ConeMark", { Position = feet(f), Direction = dirTo(f, t.Root.Position), Length = 16, Angle = 25, Duration = 0.65, Color = green })
		if not hold(f, 0.65) or not valid(f, t) then
			return
		end
		local last = ground(t.Root.Position)
		for i = 1, 3 do
			if not live(f) then
				return
			end
			if valid(f, t) then
				Fighters.Face(f, t.Root.Position)
				last = ground(t.Root.Position)
			end
			local d = dirTo(f, last)
			Fighters.SetAction(f, "Roar", 0.25)
			Fx(
				"A_Needles",
				{ From = f.Root.Position, Direction = d, Count = 7, Spread = 26, Length = 16, Duration = 0.22, Color = C(250, 248, 220), Stick = i == 3 }
			)
			Fighters.Push(f, -d * 8, 0.08)
			for _, enemy in ipairs(enemiesInCone(f, flat(f.Root.Position), d, 16, 25)) do
				Fighters.Damage(f, enemy, atk(f) * 0.55, { Knockback = d * 10, Color = green })
			end
			task.wait(0.3)
		end
		if not live(f) then
			return
		end
		-- resíduo: tapete de espinhos onde o alvo estava
		Fx("A_SpinePatch", { Position = last, Radius = 5, Duration = 3 })
		areaTicks(f, last, 5, atk(f) * 0.25, 3, 1, green)
	end

	-- Enxame (Cão-Abelha): zumbe parado no ar, solta o enxame que persegue o alvo e termina com uma
	-- ferroada que envenena
	function Specials.A_BeeSwarm(f, t)
		local yellow = C(255, 210, 60)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Float", 2.6)
		Fx("A_Buzz", { Model = f.Model, Duration = 0.7, Color = yellow })
		if not hold(f, 0.6) or not valid(f, t) then
			return
		end
		Fx("A_Swarm", { From = f.Model, Target = t.Model, Duration = 2, Color = yellow })
		for _ = 1, 5 do
			if not hold(f, 0.38) then
				return
			end
			if valid(f, t) then
				Fighters.Damage(f, t, atk(f) * 0.28, { Color = yellow })
			end
		end
		if not valid(f, t) then
			return
		end
		-- ferroada: atravessa até as costas do alvo
		local d = dirTo(f, t.Root.Position)
		Fighters.SetAction(f, "Dash", 0.35)
		Fx("Streak", { Model = f.Model, Color = yellow, Duration = 0.2, Width = 0.8, Neon = true })
		local dest = inZone(f, t.Root.Position + d * (t.Radius + f.Radius + 2))
		if not blink(f, f.Root.Position, dest, 3, 0.03) then
			return
		end
		if valid(f, t) then
			Fighters.Face(f, t.Root.Position)
			Fx("Impact", { Position = ground(t.Root.Position), Radius = 4, Color = yellow })
			Fighters.Damage(f, t, atk(f) * 1.1, { Knockback = d * 25 + Vector3.new(0, 12, 0), Color = yellow })
			Fx("A_Poison", { Model = t.Model, Duration = 3, Color = C(170, 230, 70) })
			task.spawn(function()
				for _ = 1, 3 do
					task.wait(1)
					if not valid(f, t) then
						return
					end
					Fighters.Damage(f, t, atk(f) * 0.22, { Color = C(170, 230, 70) })
				end
			end)
		end
	end

	-- Bexigas d'Água (Cão de Balão): infla três bexigas e as arremessa em arco em volta do alvo;
	-- cada uma estoura em splash e deixa uma poça
	function Specials.A_BalloonBarrage(f, t)
		local water = C(110, 200, 255)
		local colors = { C(255, 90, 160), C(90, 200, 255), C(255, 220, 70) }
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Open", 1.9)
		Fx("A_Inflate", { Model = f.Model, Duration = 0.5, Colors = colors })
		if not hold(f, 0.45) or not valid(f, t) then
			return
		end
		local d = dirTo(f, t.Root.Position)
		local right = Vector3.new(-d.Z, 0, d.X)
		local tp = t.Root.Position
		local spots = {
			ground(tp + right * 5 - d * 2),
			ground(tp - right * 5 - d * 2),
			ground(tp + d * 1.5),
		}
		for i, spot in ipairs(spots) do
			Fx("Telegraph", { Position = spot, Radius = 5.5, Duration = 0.75 + i * 0.3, Color = water })
		end
		for i, spot in ipairs(spots) do
			if not hold(f, 0.3) then
				return
			end
			Fighters.Face(f, spot)
			Fx("A_Balloon", { From = mouth(f) + Vector3.new(0, 1, 0), To = spot, Duration = 0.6, Color = colors[i] })
			Fighters.Push(f, -dirTo(f, spot) * 10, 0.1)
			task.delay(0.6, function()
				if not live(f) then
					return
				end
				Fx("Explosion", { Position = spot + Vector3.new(0, 1, 0), Radius = 6, Color = water, Kind = "water" })
				Fx("A_Puddle", { Position = spot, Radius = 5, Duration = 3, Color = colors[i] })
				Fighters.DamageArea(f, spot, 5.5, atk(f) * (i == 3 and 1.3 or 0.9), { KnockbackPower = 32, Lift = 30, Color = water })
			end)
		end
		hold(f, 0.65)
	end

	-- Faro Certeiro (Beagle): fareja, o rastro brilhante aparece até o alvo, corre por ele e solta o
	-- uivo de caça que empurra quem estiver perto
	function Specials.A_ScentHowl(f, t)
		local gold = C(255, 215, 120)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Crouch", 0.8)
		Fx("A_Sniff", { Model = f.Model, Duration = 0.75 })
		if not hold(f, 0.45) or not valid(f, t) then
			return
		end
		Fx("A_ScentTrail", { From = feet(f), To = ground(t.Root.Position), Duration = 1.6, Color = gold })
		if not hold(f, 0.3) or not valid(f, t) then
			return
		end
		local d = dirTo(f, t.Root.Position)
		local dist = math.max(0, Fighters.FlatDistance(f.Root.Position, t.Root.Position) - f.Radius - t.Radius - 3)
		if dist > 1 then
			local speed = 75
			Fighters.SetAction(f, "Dash", dist / speed + 0.1)
			Fx("Streak", { Model = f.Model, Color = gold, Duration = dist / speed, Width = 1 })
			Fighters.Push(f, d * speed, dist / speed)
			if not hold(f, dist / speed) then
				return
			end
		end
		Fighters.Stop(f)
		if valid(f, t) then
			Fighters.Face(f, t.Root.Position)
		end
		Fighters.SetAction(f, "Howl", 0.8)
		Fx("Roar", { Model = f.Model, Color = gold, Howl = true })
		Fx("Shockwave", { Position = feet(f), Radius = 11, Color = gold })
		Fighters.DamageArea(f, f.Root.Position, 10, atk(f) * 1.6, { KnockbackPower = 45, Lift = 20, Color = gold })
		hold(f, 0.5)
	end

	-- Rolo de Salsicha (Salsicha): enrola como roda, atravessa o alvo e volta rolando (bumerangue)
	function Specials.A_SausageRoll(f, t)
		local tan = C(220, 140, 80)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Crouch", 0.45)
		Fx("Telegraph", { Position = ground(t.Root.Position), Radius = 4, Duration = 0.5, Color = tan })
		if not hold(f, 0.45) or not valid(f, t) then
			return
		end
		local origin = f.Root.Position
		local d = dirTo(f, t.Root.Position)
		local far = inZone(f, t.Root.Position + d * (t.Radius + f.Radius + 7))
		for leg = 1, 2 do
			local goal = leg == 1 and far or inZone(f, origin)
			local travel = flat(goal - f.Root.Position)
			if travel.Magnitude < 1 then
				break
			end
			local speed = 70
			local time = travel.Magnitude / speed
			Fighters.SetAction(f, "Spin", time + 0.05)
			Fx("Streak", { Model = f.Model, Color = tan, Duration = time, Width = 1.2 })
			Fighters.Push(f, travel.Unit * speed, time)
			local start, hit = os.clock(), false
			while os.clock() - start < time do
				if not live(f) then
					return
				end
				if not hit and valid(f, t) and Fighters.FlatDistance(f.Root.Position, t.Root.Position) < f.Radius + t.Radius + 2 then
					hit = true
					Fx("Impact", { Position = ground(t.Root.Position), Radius = 5, Color = tan })
					Fighters.Damage(f, t, atk(f) * (leg == 1 and 1.1 or 0.8), { Knockback = travel.Unit * 22 + Vector3.new(0, 18, 0), Color = tan })
				end
				task.wait(0.03)
			end
			Fx("Smoke", { Position = feet(f), Color = C(190, 170, 140), Size = 3 })
			if leg == 1 and not hold(f, 0.15) then
				return
			end
		end
	end

	-- Postura do Guardião (Akita): firma as patas, escudo dourado reduz o dano recebido por um tempo
	-- e, no fim, revida com uma patada no chão
	function Specials.A_GuardianStance(f, t)
		local gold = C(255, 210, 110)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Roar", 0.6)
		Fx("Roar", { Model = f.Model, Color = gold })
		local duration = 2.4
		Fx("A_Shield", { Model = f.Model, Duration = duration, Color = gold })
		local token = {}
		f.A_GuardToken = token
		f.DamageTaken = (f.DamageTaken or 1) * 0.5
		local function release()
			if f.A_GuardToken == token then
				f.A_GuardToken = nil
				f.DamageTaken = (f.DamageTaken or 0.5) / 0.5
			end
		end
		task.delay(duration, release)
		-- avança devagar, firme, até perto do alvo
		local start = os.clock()
		setSpeed(f, 0.7)
		while valid(f, t) and os.clock() - start < duration - 0.8 do
			if Fighters.FlatDistance(f.Root.Position, t.Root.Position) - f.Radius - t.Radius > 4 then
				f.Humanoid:MoveTo(t.Root.Position)
			else
				Fighters.Stop(f)
				Fighters.Face(f, t.Root.Position)
			end
			task.wait(0.1)
		end
		setSpeed(f, 1)
		Fighters.Stop(f)
		if not live(f) then
			release()
			return
		end
		Fighters.SetAction(f, "Rear", 0.55)
		Fx("Telegraph", { Position = feet(f), Radius = 10, Duration = 0.55, Color = gold })
		if not hold(f, 0.5) then
			return
		end
		Fighters.SetAction(f, "Slam", 0.4)
		if not hold(f, 0.1) then
			return
		end
		Fx("Shockwave", { Position = feet(f), Radius = 11, Color = gold, Thick = true })
		Fighters.DamageArea(f, f.Root.Position, 10, atk(f) * 1.9, { KnockbackPower = 50, Lift = 26, Color = gold })
	end

	-- Arrancada de Corrida (Galgo): marca a pista, dispara em linha reta atravessando o alvo e, um
	-- instante depois, o vácuo corta tudo ao longo da linha
	function Specials.A_Slipstream(f, t)
		local wind = C(210, 235, 255)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Crouch", 0.7)
		local from = f.Root.Position
		local d = dirTo(f, t.Root.Position)
		local dest = inZone(f, t.Root.Position + d * (t.Radius + f.Radius + 12))
		Fx("A_RaceLine", { From = ground(from), To = ground(dest), Duration = 0.7, Color = wind })
		if not hold(f, 0.7) then
			return
		end
		local travel = flat(dest - f.Root.Position)
		if travel.Magnitude < 2 then
			return
		end
		local speed = 120
		local time = travel.Magnitude / speed
		Fighters.SetAction(f, "Dash", time + 0.1)
		Fx("Streak", { Model = f.Model, Color = wind, Duration = time, Width = 1, Neon = true })
		Fighters.Push(f, travel.Unit * speed, time)
		local origin = flat(f.Root.Position)
		local hitList = {}
		local start = os.clock()
		while os.clock() - start < time do
			if not live(f) then
				return
			end
			for _, enemy in ipairs(Fighters.Enemies(f, f.Root.Position, f.Radius + 2)) do
				if not hitList[enemy] then
					hitList[enemy] = true
					Fighters.Damage(f, enemy, atk(f) * 0.9, { Color = wind })
				end
			end
			task.wait(0.03)
		end
		Fighters.Stop(f)
		local finish = flat(f.Root.Position)
		Fx("Trail", {
			From = ground(Vector3.new(origin.X, from.Y, origin.Z)) + Vector3.new(0, 1, 0),
			To = feet(f) + Vector3.new(0, 1, 0),
			Color = wind,
			Width = 1.6,
			Duration = 0.6,
			Neon = true,
		})
		if not hold(f, 0.3) then
			return
		end
		-- o vácuo: corte atrasado em toda a linha
		local dir = finish - origin
		if dir.Magnitude > 0.5 then
			for _, enemy in ipairs(Fighters.Enemies(f)) do
				local rel = flat(enemy.Root.Position) - origin
				local along = rel:Dot(dir.Unit)
				local side = (rel - dir.Unit * along).Magnitude
				if along > -2 and along < dir.Magnitude + 2 and side < 3 + enemy.Radius then
					Fx("Slash", { Position = enemy.Root.Position, Direction = dir.Unit, Color = wind, Size = 7 })
					Fighters.Damage(f, enemy, atk(f) * 1.3, { Knockback = Vector3.new(0, 30, 0), Color = wind })
				end
			end
		end
	end

	-- Corda Total (Cão de Corda): gira a chave, dispara em zigue-zague acertando o alvo três vezes
	-- e termina "sem corda", soltando engrenagens
	function Specials.A_WindUpRush(f, t)
		local gold = C(255, 210, 90)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Crouch", 1.0)
		Fx("A_WindUp", { Model = f.Model, Duration = 1.0, Color = gold })
		for _ = 1, 4 do
			if not valid(f, t) then
				return
			end
			Fighters.Face(f, t.Root.Position)
			task.wait(0.25)
		end
		for i = 1, 3 do
			if not valid(f, t) then
				break
			end
			local d = dirTo(f, t.Root.Position)
			local right = Vector3.new(-d.Z, 0, d.X)
			local goal = inZone(f, t.Root.Position + d * (t.Radius + 6) + right * (i % 2 == 0 and 5 or -5))
			local travel = flat(goal - f.Root.Position)
			if travel.Magnitude < 1 then
				travel = d * 8
			end
			local speed = 95
			local time = travel.Magnitude / speed
			Fighters.SetAction(f, "Charge", time + 0.05)
			Fx("Streak", { Model = f.Model, Color = gold, Duration = time, Width = 0.9, Sparks = true })
			Fighters.Push(f, travel.Unit * speed, time)
			local start = os.clock()
			local hit = false
			while os.clock() - start < time do
				if not live(f) then
					return
				end
				if not hit and valid(f, t) and Fighters.FlatDistance(f.Root.Position, t.Root.Position) < f.Radius + t.Radius + 2.5 then
					hit = true
					Fx("Impact", { Position = ground(t.Root.Position), Radius = 5, Color = gold })
					Fighters.Damage(f, t, atk(f) * (i == 3 and 1.1 or 0.7), { Knockback = travel.Unit * 20 + Vector3.new(0, 14, 0), Color = gold })
				end
				task.wait(0.03)
			end
			task.wait(0.08)
		end
		if not live(f) then
			return
		end
		-- acabou a corda
		Fighters.Stop(f)
		Fighters.SetAction(f, "Sit", 0.7)
		Fx("A_Gears", { Position = feet(f), Duration = 2.5 })
		hold(f, 0.6)
	end

	-- Nuvem do Sono (Cão Cogumelo): o chapéu pulsa e infla, solta esporos que fazem o alvo cochilar;
	-- a nuvem fica um tempo e cogumelinhos brotam no chão
	function Specials.A_SporeBurst(f, t)
		local purple = C(200, 150, 255)
		if not approach(f, t, 6, 1.3) then
			return
		end
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Crouch", 0.8)
		Fx("A_CapPulse", { Model = f.Model, Duration = 0.8, Color = purple })
		Fx("Telegraph", { Position = feet(f), Radius = 11, Duration = 0.8, Color = purple })
		if not hold(f, 0.8) then
			return
		end
		local center = feet(f)
		Fighters.SetAction(f, "Howl", 0.6)
		Fx("A_SporeCloud", { Position = center, Radius = 11, Duration = 3.5, Color = purple })
		for _, enemy in ipairs(Fighters.DamageArea(f, f.Root.Position, 11, atk(f) * 1.3, { Color = purple })) do
			stun(enemy, 1.6, "A_Sleep")
		end
		areaTicks(f, center, 11, atk(f) * 0.25, 3, 1, purple)
		hold(f, 0.4)
	end
end
