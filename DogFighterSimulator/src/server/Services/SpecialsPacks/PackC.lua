-- Poderes do Pacote C (míticos do DogPacks/PackC). Cada um é uma sequência própria:
-- AVISO (pose + marca) → IMPACTO (efeito único + dano) → RESÍDUO. Efeitos "C_*" em client/EffectsPacks/PackC.
-- Todos funcionam no duelo 1x1 (miram/perseguem o oponente) e na Boss Tower (áreas acertam todos;
-- travas duram menos em boss). Toda espera confere se o cachorro continua vivo e lutando; velocidade,
-- dano recebido e travas são sempre restaurados (wrapper `def`).

local ZoneGeo = require(script.Parent.Parent.ZoneGeo)

local C = Color3.fromRGB

return function(Specials, Fighters)
	local A = Fighters.Alive
	local Fx = Fighters.Fx

	------------------------------------------------------------ utilidades
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

	-- trava o alvo no lugar sem o bloco de gelo padrão (o efeito visual é do próprio poder)
	local function lock(t, seconds)
		if not A(t) then
			return
		end
		if t.Kind == "boss" then
			seconds *= 0.35
		end
		t.FrozenUntil = math.max(t.FrozenUntil or 0, os.clock() + seconds)
		t.Humanoid.WalkSpeed = 0
		task.delay(seconds, function()
			if A(t) and os.clock() >= t.FrozenUntil - 0.05 then
				t.Humanoid.WalkSpeed = t.Stats.Speed * (t.SpeedMult or 1)
			end
		end)
	end

	local function heal(f, fraction, color)
		if not live(f) then
			return
		end
		local hum = f.Humanoid
		local amount = math.floor(hum.MaxHealth * fraction)
		if amount <= 0 then
			return
		end
		hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
		Fx("Damage", { Position = f.Root.Position + Vector3.new(0, f.Root.Size.Y, 0), Amount = amount, Color = color or C(120, 255, 140) })
		Fx("C_Heal", { Model = f.Model, Color = color })
	end

	-- registra o poder com a mesma proteção dos poderes base (Specials.lua)
	local function def(name, fn)
		Specials[name] = function(f, t)
			if not live(f) or not (t and A(t)) then
				return
			end
			local ok, err = pcall(fn, f, t)
			f.DamageTaken = 1
			if live(f) and not f.RageToken then
				setSpeed(f, 1)
			end
			if not ok then
				error(err, 0)
			end
		end
	end

	------------------------------------------------------------ HIDRA
	-- Ergue-se, as 5 cabeças esticam como serpentes em sequência; cada mordida que acerta cura.
	-- Final: as cinco mordem juntas.
	def("C_HydraFrenzy", function(f, t)
		local green = C(150, 255, 120)
		if not approach(f, t, 12, 1.2) then
			return
		end
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Rear", 0.7)
		Fx("Roar", { Model = f.Model, Color = green })
		Fx("Telegraph", { Position = ground(t.Root.Position), Radius = 6, Duration = 0.6, Color = green })
		if not hold(f, 0.55) then
			return
		end
		local order = { 4, 1, 2, 3, 5 }
		local hits = 0
		for _, h in ipairs(order) do
			if not valid(f, t) then
				break
			end
			Fighters.Face(f, t.Root.Position)
			Fx("C_HydraNeck", { Model = f.Model, Head = h, To = t.Root.Position, Color = green, Duration = 0.45 })
			if h <= 3 then
				Fighters.Bite(f, h)
			end
			task.wait(0.22)
			if valid(f, t) then
				Fx("BiteMark", { Position = t.Root.Position, Direction = dirTo(f, t.Root.Position), Color = green })
				Fighters.Damage(f, t, atk(f) * 0.6, { Knockback = dirTo(f, t.Root.Position) * 6, Color = green })
				hits += 1
			end
			task.wait(0.1)
		end
		if not valid(f, t) then
			return
		end
		Fighters.SetAction(f, "Charge", 0.5)
		for h = 1, 5 do
			Fx("C_HydraNeck", { Model = f.Model, Head = h, To = t.Root.Position, Color = green, Duration = 0.5 })
		end
		task.wait(0.25)
		if valid(f, t) then
			Fx("Impact", { Position = ground(t.Root.Position), Radius = 7, Color = green, Heavy = true })
			Fighters.Damage(f, t, atk(f) * 1.4, { Knockback = dirTo(f, t.Root.Position) * 40 + Vector3.new(0, 20, 0), Color = green })
			hits += 1
		end
		heal(f, 0.025 * hits, green)
	end)

	------------------------------------------------------------ DRAGÃO-ESQUELETO
	-- Desmonta numa pilha de ossos, remonta ao lado do alvo; uma caixa torácica gigante brota e o esmaga.
	def("C_BoneCage", function(f, t)
		local ghost = C(90, 255, 200)
		Fighters.Stop(f)
		Fighters.SetAction(f, "Vanish", 0.9)
		Fx("C_BonePile", { Position = feet(f), Mode = "fall", Color = ghost })
		if not hold(f, 0.45) or not valid(f, t) then
			return
		end
		local center = ground(t.Root.Position)
		Fx("Telegraph", { Position = center, Radius = 7, Duration = 0.5, Color = ghost })
		local d = dirTo(f, t.Root.Position)
		local spot = inZone(f, center - d * (t.Radius + f.Radius + 5))
		Fighters.Teleport(f, ground(spot))
		Fighters.Face(f, t.Root.Position)
		Fx("C_BonePile", { Position = ground(spot), Mode = "rise", Color = ghost })
		if not hold(f, 0.45) or not valid(f, t) then
			return
		end
		Fighters.SetAction(f, "Rear", 1.2)
		center = ground(t.Root.Position)
		Fx("C_RibCage", { Position = center, Radius = 6 + t.Radius, Duration = 1.7 })
		lock(t, 1.5)
		for _ = 1, 2 do
			if not hold(f, 0.45) then
				return
			end
			if valid(f, t) then
				Fighters.Damage(f, t, atk(f) * 0.55, { Color = ghost })
			end
		end
		if not hold(f, 0.45) then
			return
		end
		Fx("Shockwave", { Position = center, Radius = 10, Color = ghost, Thick = true })
		Fighters.DamageArea(f, center, 7 + t.Radius, atk(f) * 1.8, { KnockbackPower = 25, Lift = 40, Color = ghost })
	end)

	------------------------------------------------------------ KRAKEN
	-- Tentáculos brotam do chão em volta do alvo, erguem e esmagam; jato de tinta no fim.
	def("C_KrakenGrab", function(f, t)
		local pink = C(255, 120, 200)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Roar", 0.8)
		Fx("Roar", { Model = f.Model, Color = pink })
		local center = ground(t.Root.Position)
		Fx("Telegraph", { Position = center, Radius = 7, Duration = 0.6, Color = C(120, 200, 230) })
		if not hold(f, 0.55) or not valid(f, t) then
			return
		end
		center = ground(t.Root.Position)
		Fx("C_Tentacles", { Position = center, Radius = 6 + t.Radius, Count = 6, Duration = 2.2 })
		Fx("Shake", { Position = center, Intensity = 0.4, Radius = 60, Duration = 0.4 })
		if not hold(f, 0.6) then
			return
		end
		for _, enemy in ipairs(Fighters.Enemies(f, center, 7 + t.Radius)) do
			lock(enemy, 1.3)
			Fighters.Damage(f, enemy, atk(f) * 0.6, { Color = pink })
			Fighters.Push(enemy, Vector3.new(0, 38, 0), 0.3)
		end
		if not hold(f, 0.65) then
			return
		end
		for _, enemy in ipairs(Fighters.Enemies(f, center, 9 + t.Radius)) do
			Fighters.Push(enemy, Vector3.new(0, -90, 0), 0.2)
		end
		if not hold(f, 0.15) then
			return
		end
		Fx("Impact", { Position = center, Radius = 9, Color = pink, Heavy = true })
		Fx("C_Ink", { Position = center, Radius = 9 })
		Fighters.DamageArea(f, center, 9 + t.Radius, atk(f) * 2.0, { KnockbackPower = 30, Lift = 15, Color = pink })
	end)

	------------------------------------------------------------ CRONOS
	-- Para o tempo: relógio gigante no céu, mundo cinza, inimigos travados. Ele pisca em volta do alvo
	-- dando golpes "guardados" que explodem todos juntos quando o tempo volta.
	def("C_TimeStop", function(f, t)
		local blue = C(150, 210, 255)
		Fighters.Stop(f)
		Fighters.SetAction(f, "Howl", 0.8)
		Fx("Roar", { Model = f.Model, Color = blue, Howl = true })
		if not hold(f, 0.5) or not valid(f, t) then
			return
		end
		local duration = 2.6
		Fx("C_TimeStop", { Position = feet(f), Radius = 32, Duration = duration })
		for _, enemy in ipairs(Fighters.Enemies(f, f.Root.Position, 32)) do
			lock(enemy, duration)
		end
		if not hold(f, 0.35) then
			return
		end
		local stored = {}
		for i = 1, 5 do
			if not valid(f, t) then
				break
			end
			local a = i / 5 * math.pi * 2 + math.random()
			local spot = inZone(f, t.Root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * (t.Radius + f.Radius + 2))
			Fx("C_AfterImage", { Model = f.Model, Duration = 1.6 })
			Fighters.Teleport(f, ground(spot))
			Fighters.Face(f, t.Root.Position)
			Fighters.SetAction(f, "Dash", 0.25)
			Fighters.Bite(f)
			Fx("Slash", { Position = t.Root.Position, Direction = dirTo(f, t.Root.Position), Color = blue, Size = 6 })
			table.insert(stored, dirTo(f, t.Root.Position))
			task.wait(0.3)
		end
		if not live(f) then
			return
		end
		-- o tempo volta: todos os golpes acontecem de uma vez
		task.wait(math.max(0, duration - 0.35 - 0.3 * #stored - 0.1))
		if valid(f, t) and #stored > 0 then
			for _, d in ipairs(stored) do
				Fx("Slash", { Position = t.Root.Position, Direction = d, Color = C(235, 245, 255), Size = 9 })
			end
			Fx("Explosion", { Position = t.Root.Position, Radius = 7, Color = blue, Kind = "void" })
			Fighters.Damage(f, t, atk(f) * 0.75 * #stored, { Crit = #stored >= 5, Knockback = stored[#stored] * 50 + Vector3.new(0, 25, 0), Color = blue })
		end
	end)

	------------------------------------------------------------ SINGULARIDADE
	-- O filhote vira um buraco negro: puxa tudo para si, tritura quem chega perto e cospe longe.
	def("C_EventHorizon", function(f, t)
		local orange = C(255, 160, 70)
		Fighters.Stop(f)
		Fighters.SetAction(f, "Float", 2.8)
		Fighters.Push(f, Vector3.new(0, 8, 0), 0.3)
		Fx("C_Singularity", { Model = f.Model, Duration = 2.4, Radius = 14 })
		if not hold(f, 0.3) then
			return
		end
		for _ = 1, 10 do
			if not live(f) then
				return
			end
			local center = f.Root.Position
			for _, enemy in ipairs(Fighters.Enemies(f, center, 26)) do
				local pull = flat(center - enemy.Root.Position)
				local dist = pull.Magnitude - enemy.Radius - f.Radius
				if dist > 2 then
					Fighters.Push(enemy, pull.Unit * 34 + Vector3.new(0, 4, 0), 0.18)
				else
					-- dentro do horizonte: triturado em órbita
					local tangent = Vector3.new(-pull.Z, 0, pull.X)
					if tangent.Magnitude > 0.01 then
						Fighters.Push(enemy, tangent.Unit * 30, 0.18)
					end
					Fighters.Damage(f, enemy, atk(f) * 0.3, { Color = orange })
				end
			end
			task.wait(0.2)
		end
		if not live(f) then
			return
		end
		local center = f.Root.Position
		Fx("C_WhiteHole", { Position = center, Radius = 11 })
		Fighters.DamageArea(f, center, 11, atk(f) * 1.6, { KnockbackPower = 95, Lift = 40, Color = C(255, 245, 230) })
	end)

	------------------------------------------------------------ SERAFIM
	-- Abre as seis asas; seis pilares de luz num hexagrama varrem até o alvo e viram uma coluna sagrada.
	def("C_Judgement", function(f, t)
		local gold = C(255, 225, 120)
		Fighters.Stop(f)
		Fighters.SetAction(f, "Float", 2.4)
		Fighters.Push(f, Vector3.new(0, 10, 0), 0.4)
		Fx("EyeGlow", { Model = f.Model, Color = gold, Duration = 2.2, Body = true })
		if not hold(f, 0.35) or not valid(f, t) then
			return
		end
		local center = ground(t.Root.Position)
		local duration = 1.6
		Fx("C_Judgement", { Position = center, Radius = 12, Duration = duration })
		for k = 1, 3 do
			if not hold(f, duration / 4) then
				return
			end
			local r = 12 * (1 - k / 4)
			for _, enemy in ipairs(Fighters.Enemies(f, center, r + 2)) do
				Fighters.Damage(f, enemy, atk(f) * 0.35, { Color = gold })
			end
		end
		if not hold(f, duration / 4) then
			return
		end
		Fighters.DamageArea(f, center, 7, atk(f) * 2.4, { KnockbackPower = 20, Lift = 35, Color = gold })
		heal(f, 0.08, gold)
	end)

	------------------------------------------------------------ GOLEM DE CRISTAL
	-- Soca o chão: cristais correm até o alvo e o aprisionam; o golem salta e estilhaça a prisão.
	def("C_CrystalPrison", function(f, t)
		local cry = C(80, 245, 225)
		if not approach(f, t, 14, 1.2) then
			return
		end
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Rear", 0.55)
		if not hold(f, 0.45) or not valid(f, t) then
			return
		end
		Fighters.SetAction(f, "Slam", 0.4)
		Fx("Shockwave", { Position = feet(f), Radius = 12, Color = cry, Thick = true })
		Fx("Shake", { Position = f.Root.Position, Intensity = 0.6, Radius = 70, Duration = 0.4 })
		local origin = feet(f)
		local d = dirTo(f, t.Root.Position)
		local dist = Fighters.FlatDistance(origin, t.Root.Position)
		local pts = {}
		for k = 1, math.max(1, math.floor(dist / 4)) do
			table.insert(pts, ground(origin + d * (k * 4)))
		end
		Fx("Spikes", { Positions = pts, Color = cry, Height = 4, Interval = 0.04 })
		task.wait(#pts * 0.04)
		if not valid(f, t) then
			return
		end
		Fx("C_CrystalPrison", { Model = t.Model, Duration = 1.4 })
		lock(t, 1.4)
		Fighters.Damage(f, t, atk(f) * 0.6, { Color = cry })
		if not hold(f, 0.6) or not valid(f, t) then
			return
		end
		-- salto pesado
		Fighters.SetAction(f, "Fly", 0.6)
		local dd = dirTo(f, t.Root.Position)
		local jump = Fighters.FlatDistance(f.Root.Position, t.Root.Position) - t.Radius
		Fighters.Push(f, dd * math.clamp(jump * 2.4, 15, 70) + Vector3.new(0, 40, 0), 0.32)
		if not hold(f, 0.6) then
			return
		end
		local spot = valid(f, t) and ground(t.Root.Position) or feet(f)
		Fx("C_CrystalShatter", { Position = spot })
		Fighters.DamageArea(f, spot, 10 + t.Radius, atk(f) * 2.4, { KnockbackPower = 55, Lift = 30, Color = cry })
	end)

	------------------------------------------------------------ FÊNIX DE GELO
	-- Vira um ovo de gelo invulnerável e se cura; o ovo explode numa tempestade de penas que congela.
	def("C_GlacialRebirth", function(f, t)
		local ice = C(170, 225, 255)
		Fighters.Stop(f)
		Fighters.SetAction(f, "Crouch", 1.4)
		Fx("C_IceEgg", { Model = f.Model, Duration = 1.3 })
		f.DamageTaken = 0
		if not hold(f, 0.5) then
			return
		end
		heal(f, 0.12, ice)
		if not hold(f, 0.8) then
			return
		end
		f.DamageTaken = 1
		Fighters.SetAction(f, "Fly", 0.9)
		Fighters.Push(f, Vector3.new(0, 25, 0), 0.25)
		local center = feet(f)
		Fx("C_FeatherStorm", { Position = f.Root.Position, Count = 14, Radius = 16 })
		if not hold(f, 0.4) then
			return
		end
		for _, enemy in ipairs(Fighters.DamageArea(f, center, 16, atk(f) * 1.7, { KnockbackPower = 25, Lift = 15, Color = ice })) do
			Fighters.Freeze(enemy, 1.6)
		end
		-- se o alvo estava fora da tempestade, uma última pena teleguiada
		if valid(f, t) and Fighters.FlatDistance(center, t.Root.Position) > 16 then
			Fx("C_FeatherStorm", { Position = t.Root.Position + Vector3.new(0, 2, 0), Count = 5, Radius = 4 })
			Fighters.Damage(f, t, atk(f) * 1, { Color = ice })
			Fighters.Freeze(t, 1)
		end
	end)

	------------------------------------------------------------ COLOSSO DO TROVÃO
	-- A nuvem das costas descarrega nele; cada pisada solta uma muralha de raios que marcha até o alvo.
	def("C_ThunderWall", function(f, t)
		local yellow = C(255, 230, 80)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Rear", 0.7)
		Fx("C_RodStrike", { Model = f.Model })
		if not hold(f, 0.65) then
			return
		end
		for i = 1, 3 do
			if not valid(f, t) then
				return
			end
			Fighters.Face(f, t.Root.Position)
			Fighters.SetAction(f, "Slam", 0.35)
			if not hold(f, 0.12) then
				return
			end
			local origin = feet(f)
			local d = dirTo(f, t.Root.Position)
			local len = Fighters.FlatDistance(origin, t.Root.Position) + 8
			Fx("Shockwave", { Position = origin, Radius = 8, Color = yellow })
			Fx("C_ThunderWall", { From = origin + d * f.Radius, Direction = d, Length = len, Width = 9 + i * 2, Duration = 0.45 })
			Fx("Shake", { Position = origin, Intensity = 0.5, Radius = 80, Duration = 0.3 })
			task.delay(0.3, function()
				if live(f) then
					for _, enemy in ipairs(enemiesInLine(f, flat(origin), d, len + f.Radius, 9 + i * 2)) do
						Fighters.Damage(f, enemy, atk(f) * (i == 3 and 1.3 or 0.8), { Knockback = d * 20 + Vector3.new(0, 15, 0), Color = yellow })
					end
				end
			end)
			if not hold(f, 0.5) then
				return
			end
		end
	end)

	------------------------------------------------------------ UNICÓRNIO
	-- Um arco-íris se forma no ar; ele galopa por cima e cai chifrando o alvo numa explosão prismática.
	def("C_RainbowBridge", function(f, t)
		local pink = C(255, 160, 230)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Crouch", 0.45)
		if not hold(f, 0.35) or not valid(f, t) then
			return
		end
		local from = feet(f)
		local to = ground(t.Root.Position)
		local height = math.clamp((to - from).Magnitude * 0.45, 8, 16)
		Fx("C_Rainbow", { From = from, To = to, Height = height, Duration = 1.8 })
		Fx("Telegraph", { Position = to, Radius = 8, Duration = 0.9, Color = pink })
		if not hold(f, 0.3) then
			return
		end
		Fighters.SetAction(f, "Dash", 0.7)
		local steps = 12
		for k = 1, steps do
			if not live(f) then
				return
			end
			local u = k / steps
			local p = from:Lerp(to, u) + Vector3.new(0, math.sin(u * math.pi) * (height + 2), 0)
			Fighters.Teleport(f, inZone(f, p))
			Fighters.Face(f, f.Root.Position + (to - from))
			task.wait(0.05)
		end
		if not live(f) then
			return
		end
		local spot = ground(f.Root.Position)
		Fx("C_Prism", { Position = spot, Radius = 10 })
		if valid(f, t) and Fighters.FlatDistance(spot, t.Root.Position) < 9 + t.Radius then
			Fighters.Damage(f, t, atk(f) * 1.2, { Knockback = Vector3.new(0, 45, 0), Color = pink })
		end
		Fighters.DamageArea(f, spot, 9, atk(f) * 1.5, { KnockbackPower = 45, Lift = 25, Color = pink })
	end)

	------------------------------------------------------------ SAMURAI ONI
	-- As quatro katanas se soltam, giram em volta do alvo cortando e voltam; corte final em X.
	def("C_FlyingBlades", function(f, t)
		local red = C(255, 60, 60)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Roar", 0.6)
		Fx("Roar", { Model = f.Model, Color = red })
		if not hold(f, 0.4) or not valid(f, t) then
			return
		end
		local duration = 2.2
		Fx("C_Blades", { Model = f.Model, Target = t.Model, Duration = duration, Count = 4 })
		if not hold(f, 0.3) then
			return
		end
		for _ = 1, 6 do
			if not valid(f, t) then
				break
			end
			Fighters.Damage(f, t, atk(f) * 0.38, { Color = red })
			for _, other in ipairs(Fighters.Enemies(f, t.Root.Position, 6)) do
				if other ~= t then
					Fighters.Damage(f, other, atk(f) * 0.2, { Color = red })
				end
			end
			task.wait(0.25)
		end
		if not valid(f, t) then
			return
		end
		Fighters.SetAction(f, "Dash", 0.3)
		local d = dirTo(f, t.Root.Position)
		local right = Vector3.new(-d.Z, 0, d.X)
		Fx("Slash", { Position = t.Root.Position, Direction = (d + right).Unit, Color = red, Size = 11 })
		Fx("Slash", { Position = t.Root.Position, Direction = (d - right).Unit, Color = red, Size = 11 })
		Fx("Impact", { Position = ground(t.Root.Position), Radius = 6, Color = red })
		Fighters.Damage(f, t, atk(f) * 1.4, { Knockback = d * 40 + Vector3.new(0, 20, 0), Color = red })
	end)

	------------------------------------------------------------ MECHA
	-- Casulos abrem: 12 mísseis teleguiados sobem e caem no alvo; termina com o canhão de plasma.
	def("C_MissileBarrage", function(f, t)
		local orange = C(255, 160, 60)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Aim", 3)
		Fx("EyeGlow", { Model = f.Model, Color = C(80, 230, 255), Duration = 0.5 })
		if not hold(f, 0.45) or not valid(f, t) then
			return
		end
		local count, flight, interval = 12, 1.1, 0.08
		Fx("C_Missiles", { Model = f.Model, Target = t.Model, Position = t.Root.Position, Count = count, Flight = flight, Interval = interval })
		for i = 1, count do
			task.delay((i - 1) * interval + flight, function()
				if live(f) and A(t) then
					Fighters.DamageArea(f, t.Root.Position, 4 + t.Radius, atk(f) * 0.3, { Color = orange })
				end
			end)
		end
		if not hold(f, flight + count * interval + 0.2) or not valid(f, t) then
			return
		end
		Fighters.Face(f, t.Root.Position)
		Fx("C_Cannon", { Model = f.Model, To = t.Root.Position })
		Fighters.Damage(f, t, atk(f) * 1.3, { Knockback = dirTo(f, t.Root.Position) * 55 + Vector3.new(0, 20, 0), Color = C(80, 230, 255) })
	end)

	------------------------------------------------------------ PLANETA
	-- A lua sai de órbita, cresce no céu e cai sobre o alvo; os anéis viram uma onda de choque.
	def("C_MoonFall", function(f, t)
		local moon = C(230, 220, 200)
		Fighters.Stop(f)
		Fighters.SetAction(f, "Howl", 1.2)
		Fx("Roar", { Model = f.Model, Color = C(150, 200, 255), Howl = true })
		if not hold(f, 0.3) or not valid(f, t) then
			return
		end
		local delay = 1.5
		local radius = 10 + t.Radius
		local spot = ground(t.Root.Position)
		Fx("C_MoonFall", { Model = f.Model, Position = spot, Delay = delay, Radius = radius })
		Fx("Telegraph", { Position = spot, Radius = radius, Duration = delay, Color = C(255, 200, 150) })
		if not hold(f, delay) then
			return
		end
		Fighters.DamageArea(f, spot, radius, atk(f) * 2.8, { KnockbackPower = 60, Lift = 35, Color = moon })
		if not hold(f, 0.25) then
			return
		end
		-- onda dos anéis: pega quem escapou da cratera
		for _, enemy in ipairs(Fighters.Enemies(f, spot, radius * 2)) do
			if Fighters.FlatDistance(enemy.Root.Position, spot) > radius then
				Fighters.Damage(f, enemy, atk(f) * 0.8, { Knockback = flat(enemy.Root.Position - spot).Unit * 35 + Vector3.new(0, 15, 0), Color = moon })
			end
		end
	end)
end
