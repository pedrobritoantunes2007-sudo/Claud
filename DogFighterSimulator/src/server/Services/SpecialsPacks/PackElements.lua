-- Poderes ELEMENTAIS (pedido do dono: "tem vários com o mesmo golpe, faça vários"):
-- 11 elementos × 8 formas = 88 poderes "El_<Elemento>_<Forma>", ex.: El_Fire_Bolt, El_Ice_Nova.
-- (2026-10) + Vento (joga longe), Voador (golpe extra do céu) e Natureza (raízes prendem + cura).
-- Cada um tem AVISO (pose + marca) → IMPACTO (efeito do elemento + dano) e o efeito do elemento
-- (queimar, congelar, raio extra, veneno, jogar para cima, golpe crítico, espinhos, cura).
-- Os nomes e descrições ficam em DogData e a escolha por cachorro em DogData.PowersFor:
-- 2 = golpe próprio, 3 = ULTIMATE do elemento ou FUSÃO (2–3 elementos), 4 = SUPREMO (Míticos e Divino).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DogData = require(ReplicatedStorage.Shared.DogData)

return function(Specials, Fighters)
	local A = Fighters.Alive
	local Fx = Fighters.Fx

	local function flat(v)
		return Vector3.new(v.X, 0, v.Z)
	end
	local function live(f)
		return A(f) and not f.Controlled
	end
	local function valid(f, t)
		return live(f) and t ~= nil and A(t) and Fighters.Hostile(f, t)
	end
	local function hold(f, seconds)
		task.wait(seconds)
		return live(f)
	end
	local function dirTo(f, position)
		local d = flat(position - f.Root.Position)
		if d.Magnitude < 0.01 then
			return flat(f.Root.CFrame.LookVector).Unit
		end
		return d.Unit
	end
	local function feetOf(m)
		return m.Root.Position - Vector3.new(0, m.Humanoid.HipHeight + m.Root.Size.Y / 2, 0)
	end
	local function mouth(f)
		return f.Root.Position + f.Root.CFrame.LookVector * (f.Root.Size.Z * 0.6) + Vector3.new(0, f.Root.Size.Y * 0.4, 0)
	end
	local function atk(f)
		return f.Stats.Atk
	end

	------------------------------------------------------------ elementos
	-- cada elemento: cor, efeito de impacto e o que faz com quem leva o golpe
	local ELEMENTS = {}
	for id, e in pairs(DogData.ELEMENTS) do
		ELEMENTS[id] = { Color = e.Color }
	end

	-- efeito visual no ponto do golpe
	local function burst(id, pos, radius)
		local color = ELEMENTS[id].Color
		if id == "Fire" then
			Fx("Explosion", { Position = pos, Radius = radius, Color = color })
		elseif id == "Thunder" or id == "Light" then
			Fx("Lightning", { Position = pos, Color = color, Big = radius > 8 })
			Fx("Shockwave", { Position = pos, Radius = radius, Color = color })
		elseif id == "Water" then
			Fx("Geyser", { Position = pos, Radius = math.min(radius, 6) })
		elseif id == "Earth" then
			local pts = {}
			for i = 1, 6 do
				local a = i / 6 * math.pi * 2
				table.insert(pts, pos + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * 0.5)
			end
			Fx("Spikes", { Positions = pts, Color = color, Height = 4, Interval = 0.03 })
		elseif id == "Wind" then
			-- 🌪️ redemoinho rápido + estouro de vento
			Fx("Vortex", { Position = pos, Radius = math.min(radius, 10), Duration = 0.6 })
			Fx("SonicBoom", { Position = pos + Vector3.new(0, 2, 0), Color = color, Radius = radius * 0.8, Direction = Vector3.new(0, 0, -1) })
		elseif id == "Fly" then
			-- 🦅 tempestade de penas descendo do céu
			Fx("C_FeatherStorm", { Position = pos, Radius = radius, Count = math.clamp(math.floor(radius), 6, 14) })
			Fx("Shockwave", { Position = pos, Radius = radius, Color = color })
		elseif id == "Nature" then
			-- 🌿 espinhos/raízes brotando em anel
			local pts = {}
			for i = 1, 7 do
				local a = i / 7 * math.pi * 2
				table.insert(pts, pos + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * 0.55)
			end
			Fx("Spikes", { Positions = pts, Color = color, Height = 3.5, Interval = 0.02 })
			Fx("Impact", { Position = pos, Radius = radius * 0.7, Color = color })
		else
			Fx("Impact", { Position = pos, Radius = radius, Color = color, Heavy = true })
			Fx("Shockwave", { Position = pos, Radius = radius, Color = color })
		end
		Fx("Shake", { Position = pos, Intensity = 0.3, Radius = 40, Duration = 0.2 })
	end

	-- efeito do elemento em quem levou o golpe
	local function afflict(f, id, t)
		if not A(t) then
			return
		end
		local color = ELEMENTS[id].Color
		if id == "Fire" or id == "Poison" then
			Fx("Burn", { Model = t.Model, Duration = 2.4, Color = color, Kind = id == "Poison" and "poison" or nil })
			task.spawn(function()
				for _ = 1, 4 do
					task.wait(0.6)
					if not (A(f) and A(t) and Fighters.Hostile(f, t)) then
						return
					end
					Fighters.Damage(f, t, atk(f) * 0.25, { Color = color })
				end
			end)
		elseif id == "Ice" then
			Fighters.Freeze(t, 1.3)
		elseif id == "Thunder" then
			task.delay(0.35, function()
				if A(t) and A(f) and Fighters.Hostile(f, t) then
					Fx("Lightning", { Position = feetOf(t), Color = color })
					Fighters.Damage(f, t, atk(f) * 0.6, { Color = color })
				end
			end)
		elseif id == "Water" then
			Fighters.Push(t, Vector3.new(0, 45, 0), 0.25)
		elseif id == "Earth" then
			Fighters.Freeze(t, 0.7)
		elseif id == "Wind" then
			-- joga longe, para trás (de quem soltou)
			local away = flat(t.Root.Position - f.Root.Position)
			away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
			Fighters.Push(t, away * 70 + Vector3.new(0, 22, 0), 0.25)
		elseif id == "Fly" then
			-- uma pena-lâmina desce do céu e acerta de novo
			task.delay(0.4, function()
				if A(t) and A(f) and Fighters.Hostile(f, t) then
					Fx("Impact", { Position = t.Root.Position, Radius = 4, Color = color, Heavy = true })
					Fighters.Damage(f, t, atk(f) * 0.5, { Color = color })
				end
			end)
		elseif id == "Nature" then
			-- raízes prendem o alvo
			Fx("B_Vines", { Position = feetOf(t), Model = t.Model, Duration = 1 })
			Fighters.Freeze(t, 0.9, "vines")
		end
	end

	-- dano + efeito do elemento (Sombra = crítico; Luz = cura quem bateu)
	local function strike(f, id, t, mult, kb)
		local opts = { Color = ELEMENTS[id].Color, Crit = id == "Shadow" }
		if kb then
			opts.Knockback = kb
		end
		local dmg = Fighters.Damage(f, t, atk(f) * mult, opts)
		if dmg > 0 then
			afflict(f, id, t)
			if (id == "Light" or id == "Nature") and A(f) then
				-- Luz cura metade do dano; Natureza cura um pouco (as raízes "bebem" a vida)
				local h = f.Humanoid
				h.Health = math.min(h.MaxHealth, h.Health + dmg * (id == "Light" and 0.5 or 0.25))
			end
		end
	end

	local function area(f, id, pos, radius, mult)
		for _, enemy in ipairs(Fighters.Enemies(f, pos, radius)) do
			local away = flat(enemy.Root.Position - pos)
			away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
			strike(f, id, enemy, mult, away * 30 + Vector3.new(0, 16, 0))
		end
	end

	------------------------------------------------------------ formas
	local SHAPES = {}

	-- Bola: cospe uma bola do elemento no alvo
	function SHAPES.Bolt(f, t, id)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Open", 0.5)
		if not hold(f, 0.25) or not valid(f, t) then
			return
		end
		local from, to = mouth(f), t.Root.Position
		Fx("Glob", { From = from, To = to, Color = ELEMENTS[id].Color, Duration = 0.35 })
		task.wait(0.35)
		if valid(f, t) then
			burst(id, t.Root.Position, 6)
			strike(f, id, t, 2.2, dirTo(f, t.Root.Position) * 25 + Vector3.new(0, 10, 0))
		end
	end

	-- Tiro triplo: três bolas em leque
	function SHAPES.Volley(f, t, id)
		Fighters.Face(f, t.Root.Position)
		for i = -1, 1 do
			if not valid(f, t) then
				return
			end
			Fighters.SetAction(f, "Open", 0.2)
			local side = f.Root.CFrame.RightVector * i * 4
			Fx("Glob", { From = mouth(f), To = t.Root.Position + side, Color = ELEMENTS[id].Color, Duration = 0.3 })
			task.delay(0.3, function()
				if valid(f, t) then
					burst(id, t.Root.Position + side * 0.5, 4)
					area(f, id, t.Root.Position + side * 0.5, 5, 0.9)
				end
			end)
			if not hold(f, 0.22) then
				return
			end
		end
	end

	-- Explosão em volta (nova)
	function SHAPES.Nova(f, _t, id)
		Fighters.Stop(f)
		Fighters.SetAction(f, "Howl", 0.7)
		local pos = feetOf(f)
		Fx("Telegraph", { Position = pos, Radius = 15, Duration = 0.5, Color = ELEMENTS[id].Color })
		if not hold(f, 0.5) then
			return
		end
		burst(id, pos, 15)
		area(f, id, pos, 15, 1.8)
	end

	-- Investida: dispara envolto no elemento e explode ao chegar
	function SHAPES.Rush(f, t, id)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Crouch", 0.35)
		if not hold(f, 0.3) or not valid(f, t) then
			return
		end
		local d = dirTo(f, t.Root.Position)
		Fighters.SetAction(f, "Dash", 0.4)
		Fx("Streak", { Model = f.Model, Color = ELEMENTS[id].Color, Width = 1.6, Lifetime = 0.4 })
		Fighters.Push(f, d * 80, 0.3)
		if not hold(f, 0.32) then
			return
		end
		burst(id, f.Root.Position, 9)
		area(f, id, f.Root.Position, 9, 2)
	end

	-- Chuva: o elemento cai do céu em volta do alvo
	function SHAPES.Rain(f, t, id)
		Fighters.Stop(f)
		Fighters.SetAction(f, "Howl", 1)
		local center = feetOf(t)
		Fx("Telegraph", { Position = center, Radius = 12, Duration = 1.2, Color = ELEMENTS[id].Color })
		for _ = 1, 6 do
			if not live(f) then
				return
			end
			local a = math.random() * math.pi * 2
			local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random() * 9
			Fx("Meteor", { Position = p, Delay = 0.35, Radius = 4, Kind = id ~= "Fire" and "star" or nil })
			task.delay(0.35, function()
				if live(f) then
					burst(id, p, 5)
					area(f, id, p, 5, 0.75)
				end
			end)
			task.wait(0.2)
		end
	end

	-- Raio laser contínuo
	function SHAPES.Beam(f, t, id)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Open", 1)
		for _ = 1, 4 do
			if not valid(f, t) then
				return
			end
			Fighters.Face(f, t.Root.Position)
			Fx("Laser", { Model = f.Model, Points = { mouth(f), t.Root.Position }, Color = ELEMENTS[id].Color, Width = 1.2, Duration = 0.25 })
			strike(f, id, t, 0.65)
			if not hold(f, 0.25) then
				return
			end
		end
	end

	-- Pancada no chão: pula e cai com tudo
	function SHAPES.Slam(f, t, id)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Rear", 0.4)
		local d = dirTo(f, t.Root.Position)
		local dist = Fighters.FlatDistance(f.Root.Position, t.Root.Position)
		Fighters.Push(f, d * math.clamp(dist * 2.2, 10, 60) + Vector3.new(0, 45, 0), 0.3)
		if not hold(f, 0.55) then
			return
		end
		Fighters.SetAction(f, "Slam", 0.4)
		local pos = feetOf(f)
		burst(id, pos, 11)
		Fx("Shake", { Position = pos, Intensity = 0.7, Radius = 50, Duration = 0.35 })
		area(f, id, pos, 11, 2.1)
	end

	-- Redemoinho: puxa os inimigos e machuca várias vezes
	function SHAPES.Vortex(f, t, id)
		Fighters.SetAction(f, "Spin", 1.2)
		local center = feetOf(t)
		Fx("Vortex", { Position = center, Radius = 12, Duration = 1.4 })
		Fx("Shockwave", { Position = center, Radius = 12, Color = ELEMENTS[id].Color })
		for _ = 1, 4 do
			if not live(f) then
				return
			end
			for _, enemy in ipairs(Fighters.Enemies(f, center, 12)) do
				local pull = flat(center - enemy.Root.Position)
				if pull.Magnitude > 1 then
					Fighters.Push(enemy, pull.Unit * 25, 0.15)
				end
				strike(f, id, enemy, 0.55)
			end
			task.wait(0.3)
		end
		burst(id, center, 8)
	end

	------------------------------------------------------------ 💥 ULTIMATE (habilidade 3): combo em 3 fases
	-- 1) o elemento ERUPCIONA do chão em linha até o alvo (gelo/espinhos/lava/raios saindo do chão)
	-- 2) a forma grande (Rain/Vortex/Slam/Beam)  3) explosão final em volta do alvo
	local function eruption(f, t, id)
		local color = ELEMENTS[id].Color
		local from = feetOf(f)
		local to = feetOf(t)
		local d = flat(to - from)
		local len = math.max(8, d.Magnitude + 6)
		local dir = d.Magnitude > 0.1 and d.Unit or flat(f.Root.CFrame.LookVector).Unit
		Fighters.SetAction(f, "Slam", 0.4)
		Fx("Shake", { Position = from, Intensity = 0.6, Radius = 60, Duration = 0.6 })
		local steps = math.clamp(math.floor(len / 3), 4, 12)
		for i = 1, steps do
			if not live(f) then
				return
			end
			local p = from + dir * (i * len / steps)
			local side = Vector3.new(-dir.Z, 0, dir.X)
			Fx("Spikes", { Positions = { p, p + side * 2.2, p - side * 2.2 }, Color = color, Height = 5 + i * 0.4, Interval = 0 })
			if i % 3 == 0 then
				burst(id, p, 5)
			end
			area(f, id, p, 4.5, 0.45)
			task.wait(0.05)
		end
	end

	local function finisher(f, t, id)
		if not live(f) then
			return
		end
		local pos = A(t) and feetOf(t) or feetOf(f)
		Fx("Telegraph", { Position = pos, Radius = 14, Duration = 0.35, Color = ELEMENTS[id].Color })
		task.wait(0.35)
		if not live(f) then
			return
		end
		burst(id, pos, 14)
		Fx("Explosion", { Position = pos + Vector3.new(0, 1, 0), Radius = 14, Color = ELEMENTS[id].Color })
		Fx("Shake", { Position = pos, Intensity = 1.1, Radius = 80, Duration = 0.5 })
		area(f, id, pos, 14, 1.6)
	end

	------------------------------------------------------------ 👑 SUPREMO (habilidade 4, Míticos e o Divino)
	-- o cachorro sobe no ar, o céu desaba: chuva gigante de meteoros + raios, e uma explosão enorme.
	-- elems = { elemento } ou, na FUSÃO, os 2–3 elementos do cachorro (os meteoros se revezam entre eles)
	local function supreme(f, t, elems)
		local id = elems[1]
		local color = ELEMENTS[id].Color
		local center = feetOf(t)
		Fighters.SetAction(f, "Fly", 2.6)
		Fx("Roar", { Model = f.Model, Color = color })
		Fighters.Push(f, Vector3.new(0, 60, 0), 0.35)
		Fx("Telegraph", { Position = center, Radius = 28, Duration = 2.2, Color = color })
		Fx("Shake", { Position = center, Intensity = 1.4, Radius = 120, Duration = 2.4 })
		Fx("Vortex", { Position = center, Radius = 26, Duration = 2.4 })
		for i = 1, 14 do
			if not live(f) then
				return
			end
			local a = math.random() * math.pi * 2
			local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random() * 24
			local e = elems[(i - 1) % #elems + 1]
			Fx("Meteor", { Position = p, Delay = 0.3, Radius = 6, Kind = e ~= "Fire" and "star" or nil })
			if i % 2 == 0 then
				Fx("Lightning", { Position = p, Color = ELEMENTS[e].Color, Big = true })
			end
			task.delay(0.3, function()
				if live(f) then
					burst(e, p, 7)
					area(f, e, p, 7, 1.1 / math.sqrt(#elems))
				end
			end)
			task.wait(0.12)
		end
		task.wait(0.35)
		if not live(f) then
			return
		end
		-- impacto final: explosão gigante + onda dupla
		Fighters.SetAction(f, "Slam", 0.6)
		Fx("Explosion", { Position = center + Vector3.new(0, 2, 0), Radius = 30, Color = color })
		for i, e in ipairs(elems) do
			Fx("Shockwave", { Position = center, Radius = 34 - (i - 1) * 6, Color = ELEMENTS[e].Color, Thick = i == 1 })
			if i > 1 then
				burst(e, center, 18)
			end
		end
		Fx("Shockwave", { Position = center, Radius = 22, Color = Color3.new(1, 1, 1) })
		Fx("Shake", { Position = center, Intensity = 2, Radius = 150, Duration = 0.9 })
		-- cada elemento acerta com a sua parte do dano (e aplica o seu efeito)
		local mult = #elems == 1 and 5 or 5 / #elems * 1.15
		for _, e in ipairs(elems) do
			area(f, e, center, 30, mult)
		end
	end

	------------------------------------------------------------ 🌀 FUSÃO (habilidade 3 de quem tem 2 ou 3 elementos)
	-- 1) o 1º elemento ERUPCIONA do chão até o alvo  2) a forma grande com o 2º elemento
	-- 3) (3 elementos) explosão do 3º elemento em volta do alvo  4) explosão de FUSÃO: todos juntos, cada um
	--    com o seu efeito (queima + congela + joga longe...)
	local function fusionBlast(f, t, elems, radius, mult)
		if not live(f) then
			return
		end
		local pos = A(t) and feetOf(t) or feetOf(f)
		Fx("Telegraph", { Position = pos, Radius = radius, Duration = 0.4, Color = ELEMENTS[elems[1]].Color })
		task.wait(0.4)
		if not live(f) then
			return
		end
		for i, e in ipairs(elems) do
			burst(e, pos, radius * (1 - (i - 1) * 0.15))
			Fx("Shockwave", { Position = pos, Radius = radius * (0.7 + i * 0.25), Color = ELEMENTS[e].Color, Thick = i == 1 })
		end
		Fx("Explosion", { Position = pos + Vector3.new(0, 1, 0), Radius = radius, Color = ELEMENTS[elems[#elems]].Color })
		Fx("Shake", { Position = pos, Intensity = 1.2, Radius = 90, Duration = 0.55 })
		for _, e in ipairs(elems) do
			area(f, e, pos, radius, mult / #elems * 1.15)
		end
	end

	local function fusion(f, t, elems, shape)
		eruption(f, t, elems[1])
		if valid(f, t) then
			SHAPES[shape](f, t, elems[2])
		end
		if elems[3] and valid(f, t) then
			local pos = feetOf(t)
			Fx("Telegraph", { Position = pos, Radius = 10, Duration = 0.3, Color = ELEMENTS[elems[3]].Color })
			task.wait(0.3)
			if live(f) then
				burst(elems[3], pos, 10)
				area(f, elems[3], pos, 10, 0.9)
			end
		end
		fusionBlast(f, t, elems, 15, 1.8)
	end

	------------------------------------------------------------ registra os 64
	for _, elem in ipairs(DogData.ELEMENT_ORDER) do
		for _, shape in ipairs(DogData.SHAPE_ORDER) do
			local fn = SHAPES[shape]
			Specials["El_" .. elem .. "_" .. shape] = function(f, t)
				if not valid(f, t) then
					return
				end
				fn(f, t, elem)
			end
		end
	end
	-- ULTIMATE de cada elemento × forma grande e o SUPREMO de cada elemento
	for _, elem in ipairs(DogData.ELEMENT_ORDER) do
		for _, shape in ipairs(DogData.BIG_SHAPES) do
			local fn = SHAPES[shape]
			Specials["Ult_" .. elem .. "_" .. shape] = function(f, t)
				if not valid(f, t) then
					return
				end
				eruption(f, t, elem)
				if valid(f, t) then
					fn(f, t, elem)
				end
				finisher(f, t, elem)
			end
		end
		Specials["Supreme_" .. elem] = function(f, t)
			if valid(f, t) then
				supreme(f, t, { elem })
			end
		end
	end
	-- 🌀 FUSÕES em uso (DogData.FusionPowers): "Fus_<E1>_<E2>[_<E3>]_<Forma>" e "SupFus_<E1>_<E2>[_<E3>]"
	for _, name in ipairs(DogData.FusionPowers()) do
		local parts = string.split(name, "_")
		if parts[1] == "Fus" then
			local shape = parts[#parts]
			local elems = { table.unpack(parts, 2, #parts - 1) }
			Specials[name] = function(f, t)
				if valid(f, t) then
					fusion(f, t, elems, shape)
				end
			end
		elseif parts[1] == "SupFus" then
			local elems = { table.unpack(parts, 2) }
			Specials[name] = function(f, t)
				if valid(f, t) then
					supreme(f, t, elems)
				end
			end
		end
	end
end
