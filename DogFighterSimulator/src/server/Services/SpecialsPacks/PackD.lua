-- Poder próprio do Pacote D (o DIVINO, Sunfire Dragon). Habilidade 2.
-- SUNFIRE BREATH: ergue-se e urra (aviso no chão), sopra um raio de fogo-do-sol que VARRE da esquerda para a
-- direita (queima quem estiver na frente) e no fim um pequeno sol explode no alvo; a Luz cura 10% da vida.
local C = Color3.fromRGB

return function(Specials, Fighters)
	local A = Fighters.Alive
	local Fx = Fighters.Fx

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
	local function feet(m)
		return m.Root.Position - Vector3.new(0, m.Humanoid.HipHeight + m.Root.Size.Y / 2, 0)
	end
	local function mouth(f)
		return f.Root.Position + f.Root.CFrame.LookVector * (f.Root.Size.Z * 0.6) + Vector3.new(0, f.Root.Size.Y * 0.4, 0)
	end

	local GOLD = C(255, 200, 80)
	local RED = C(255, 90, 50)

	local function sunfireBreath(f, t)
		Fighters.Stop(f)
		Fighters.Face(f, t.Root.Position)
		Fighters.SetAction(f, "Rear", 0.6)
		Fx("Roar", { Model = f.Model, Color = GOLD })
		Fx("Telegraph", { Position = feet(t), Radius = 9, Duration = 0.55, Color = RED })
		if not hold(f, 0.5) or not valid(f, t) then
			return
		end
		-- o raio varre da esquerda para a direita do alvo
		Fighters.SetAction(f, "Open", 1.3)
		local right = f.Root.CFrame.RightVector
		for i = -3, 3 do
			if not valid(f, t) then
				return
			end
			local aim = t.Root.Position + right * i * 2.5
			Fx("Laser", { Model = f.Model, Points = { mouth(f), aim }, Color = i % 2 == 0 and GOLD or RED, Width = 1.6, Duration = 0.18 })
			for _, enemy in ipairs(Fighters.Enemies(f, aim, 5)) do
				if Fighters.Damage(f, enemy, f.Stats.Atk * 0.35, { Color = RED }) > 0 then
					Fx("Burn", { Model = enemy.Model, Duration = 1.2, Color = RED })
				end
			end
			task.wait(0.12)
		end
		if not valid(f, t) then
			return
		end
		-- o sol explode no alvo
		local pos = feet(t)
		Fx("Explosion", { Position = pos + Vector3.new(0, 1, 0), Radius = 10, Color = GOLD })
		Fx("Shockwave", { Position = pos, Radius = 12, Color = RED, Thick = true })
		Fx("Shake", { Position = pos, Intensity = 0.8, Radius = 60, Duration = 0.4 })
		Fighters.DamageArea(f, pos, 10, f.Stats.Atk * 1.6, { KnockbackPower = 30, Lift = 20, Color = GOLD })
		-- ✨ Luz: cura 10% da vida
		local h = f.Humanoid
		local amount = math.floor(h.MaxHealth * 0.1)
		if amount > 0 and live(f) then
			h.Health = math.min(h.MaxHealth, h.Health + amount)
			Fx("Damage", { Position = f.Root.Position + Vector3.new(0, f.Root.Size.Y, 0), Amount = amount, Color = C(120, 255, 140) })
		end
	end

	Specials.D_SunfireBreath = function(f, t)
		if not valid(f, t) then
			return
		end
		local ok, err = pcall(sunfireBreath, f, t)
		if not ok then
			error(err, 0)
		end
	end
end
