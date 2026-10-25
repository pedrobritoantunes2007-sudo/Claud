-- 🌬️ Movimento do mapa (só no cliente, não pesa o servidor): pás de moinho e engrenagens girando
-- (tag "Spinner"), balões/boias/lanternas subindo e descendo ("Bobber"), passarinhos e patinhos em
-- círculo ("Orbiter"), bandeiras e velas balançando no vento ("Swayer"), gêiseres e sopros de fogo que
-- disparam de tempos em tempos ("Burst", numa peça com ParticleEmitter), bichinhos dando pulinhos ("Hopper":
-- coelho, galinha, sapo, pinguim, caranguejo — todos de bloquinhos) e peixes saltando da água ("Leaper").
-- Só anima o que está perto da câmera. Os bichos andam em cima do chão de BLOCOS (workspace.Chao) e do Terrain.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local WorldMotion = {}

local NEAR = 900 -- studs: mais longe que isso fica parado (ninguém vê)
local NEAR_SMALL = 420 -- bichinhos e peixes (pequenos: de longe ninguém vê o pulo)
local LEAP_TIME = 1.2 -- s no ar do salto do peixe
local items = {} -- [Model] = { kind, base, ... }

local AXES = { X = Vector3.new(1, 0, 0), Y = Vector3.new(0, 1, 0), Z = Vector3.new(0, 0, 1) }

-- chão embaixo de um ponto: o Terrain antigo + o CHÃO DE BLOCOS (2026-10: as ilhas viraram blocos em
-- workspace.Chao.<ilha>.ChaoBlocos e a ilha principal em workspace.Map.ChaoBlocos). Sem isso os bichinhos que
-- passeiam não achavam o chão nas ilhas. A lista é refeita de tempos em tempos (o chão chega depois do cliente).
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local groundAt = -math.huge
local function refreshGround()
	local list: { Instance } = { workspace.Terrain }
	local chao = workspace:FindFirstChild("Chao")
	if chao then
		table.insert(list, chao)
	end
	local map = workspace:FindFirstChild("Map")
	if map then
		for _, m in ipairs(map:GetChildren()) do
			if m.Name == "ChaoBlocos" then
				table.insert(list, m)
			end
		end
	end
	groundParams.FilterDescendantsInstances = list
	groundAt = os.clock()
end
refreshGround()
local function groundY(p: Vector3): number?
	if os.clock() - groundAt > 10 then
		refreshGround()
	end
	local hit = workspace:Raycast(p + Vector3.new(0, 8, 0), Vector3.new(0, -20, 0), groundParams)
	return hit and hit.Position.Y or nil
end

local function track(kind, model)
	if items[model] then
		return
	end
	if kind == "Burst" then
		if model:IsA("BasePart") then
			local every = model:GetAttribute("BurstEvery") or 5
			items[model] = { Kind = kind, Base = model.CFrame, Every = every, Count = model:GetAttribute("BurstCount") or 30, Next = math.random() * every }
		end
		return
	end
	if not model:IsA("Model") then
		return
	end
	-- Swayer usa o WorldPivot (o eixo da bandeira/vela); os outros precisam da peça principal
	if not model.PrimaryPart and kind ~= "Swayer" then
		return
	end
	local entry = { Kind = kind, Base = model:GetPivot(), Phase = math.random() * 10 }
	if kind == "Spinner" then
		entry.Speed = model:GetAttribute("SpinSpeed") or 0.6
		entry.Axis = AXES[model:GetAttribute("SpinAxis") or "X"] or AXES.X
	elseif kind == "Bobber" then
		entry.Height = model:GetAttribute("BobHeight") or 4
		entry.Speed = model:GetAttribute("BobSpeed") or 0.8
	elseif kind == "Swayer" then
		entry.Angle = model:GetAttribute("SwayAngle") or 0.2
		entry.Speed = model:GetAttribute("SwaySpeed") or 1.4
		entry.Axis = AXES[model:GetAttribute("SwayAxis") or "Y"] or AXES.Y
	elseif kind == "Orbiter" then
		entry.Center = model:GetAttribute("Center") or entry.Base.Position
		entry.Radius = model:GetAttribute("Radius") or 30
		entry.Speed = model:GetAttribute("Speed") or 0.25
		entry.Phase = model:GetAttribute("Phase") or entry.Phase
	elseif kind == "Hopper" then
		entry.Height = model:GetAttribute("HopHeight") or 1
		entry.Speed = model:GetAttribute("HopSpeed") or 1.5
		entry.Radius = model:GetAttribute("HopRadius") or 0
		-- ciclo de 6 pulos: os primeiros andam, o resto descansa (pastando, olhando em volta)
		entry.Moving = math.clamp(math.floor(6 * (1 - (model:GetAttribute("HopRest") or 0.3)) + 0.5), 1, 6)
		entry.Angle0 = math.random() * math.pi * 2
		entry.Dir = math.random() < 0.5 and -1 or 1
		-- altura do corpo acima do chão (para seguir o chão no passeio): medida na 1ª vez que ele anima
		-- (o chão de blocos pode chegar depois do bichinho); sem chão embaixo tenta de novo a cada 5 s
		entry.Lift = nil
		entry.LiftNext = 0
	elseif kind == "Leaper" then
		entry.Every = model:GetAttribute("LeapEvery") or 6
		entry.Length = model:GetAttribute("LeapLength") or 7
		entry.Height = model:GetAttribute("LeapHeight") or 3
		entry.Under = false
	end
	items[model] = entry
end

local function watch(tag)
	for _, m in ipairs(CollectionService:GetTagged(tag)) do
		track(tag, m)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(m)
		task.defer(track, tag, m)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(m)
		items[m] = nil
	end)
end

function WorldMotion.Start()
	watch("Spinner")
	watch("Bobber")
	watch("Orbiter")
	watch("Swayer")
	watch("Burst")
	watch("Hopper")
	watch("Leaper")
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local camPos = cam.CFrame.Position
		for model, e in pairs(items) do
			if not model.Parent then
				items[model] = nil
				continue
			end
			local pos = e.Kind == "Orbiter" and e.Center or e.Base.Position
			local small = e.Kind == "Hopper" or e.Kind == "Leaper"
			if (pos - camPos).Magnitude > (small and NEAR_SMALL or NEAR) then
				continue
			end
			if e.Kind == "Burst" then
				if t >= e.Next then
					e.Next = t + e.Every
					for _, pe in ipairs(model:GetChildren()) do
						if pe:IsA("ParticleEmitter") then
							pe:Emit(e.Count)
						end
					end
				end
			elseif e.Kind == "Spinner" then
				model:PivotTo(e.Base * CFrame.fromAxisAngle(e.Axis, (t + e.Phase) * e.Speed))
			elseif e.Kind == "Bobber" then
				model:PivotTo(e.Base + Vector3.new(0, math.sin((t + e.Phase) * e.Speed) * e.Height, 0))
			elseif e.Kind == "Swayer" then
				model:PivotTo(e.Base * CFrame.fromAxisAngle(e.Axis, math.sin((t + e.Phase) * e.Speed) * e.Angle))
			elseif e.Kind == "Hopper" then
				local tt = (t + e.Phase) * e.Speed
				local n = math.floor(tt)
				local u = tt - n
				local inCycle = n % 6
				local moving = inCycle < e.Moving
				local hop = moving and math.sin(u * math.pi) * e.Height or 0
				-- pulos inteiros já dados (só os que andam) + o pedaço do pulo de agora
				local done = (n // 6) * e.Moving + math.min(inCycle, e.Moving)
				local frac = moving and u or 0
				if e.Radius > 0 and e.Lift == nil and t >= e.LiftNext then
					local g = groundY(e.Base.Position)
					if g and math.abs(e.Base.Position.Y - g) < 6 then
						e.Lift = e.Base.Position.Y - g
					else
						e.LiftNext = t + 5
					end
				end
				-- empina o nariz na subida e abaixa na descida (cara de bichinho de blocos saltitando)
				local lean = CFrame.Angles(moving and math.cos(u * math.pi) * 0.22 or 0, 0, 0)
				if e.Radius > 0 then
					-- passeio numa volta torta (o raio muda pelo caminho: não parece círculo perfeito)
					local function at(k)
						local a = e.Angle0 + e.Dir * k * 1.5 / e.Radius
						local r = e.Radius * (0.7 + 0.3 * math.sin(a * 2 + e.Angle0))
						return e.Base.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
					end
					if e.HopK ~= done then
						-- 1 consulta de chão por pulo: onde ele está e onde vai cair
						if e.HopK == done - 1 and e.G1 then
							e.G0 = e.G1
						else
							e.G0 = e.Lift and groundY(at(done)) or nil
						end
						e.HopK = done
						e.G1 = e.Lift and groundY(at(done + 1)) or nil
					end
					local p = at(done + frac)
					local base = e.Base.Position.Y
					if e.Lift and e.G0 and e.G1 then
						base = e.G0 + (e.G1 - e.G0) * frac + e.Lift
					end
					local q = at(done + frac + 0.25)
					p = Vector3.new(p.X, base + hop, p.Z)
					model:PivotTo(CFrame.lookAt(p, Vector3.new(q.X, p.Y, q.Z)) * lean)
				else
					-- no lugar: vira um pouquinho durante cada pulo (sem dar tranco)
					local function yaw(k)
						return math.sin(k * 1.7) * 0.7
					end
					model:PivotTo(e.Base * CFrame.new(0, hop, 0) * CFrame.Angles(0, yaw(done) + (yaw(done + 1) - yaw(done)) * frac, 0) * lean)
				end
			elseif e.Kind == "Leaper" then
				local c = (t + e.Phase) % e.Every
				if c < LEAP_TIME then
					local u = c / LEAP_TIME
					local pitch = math.atan2(math.cos(u * math.pi) * math.pi * e.Height, e.Length)
					model:PivotTo(e.Base * CFrame.new(0, math.sin(u * math.pi) * e.Height, -(u - 0.5) * e.Length) * CFrame.Angles(pitch, 0, 0))
					e.Under = false
				elseif not e.Under then
					e.Under = true
					model:PivotTo(e.Base - Vector3.new(0, 4, 0)) -- embaixo d'água esperando o próximo salto
				end
			else
				local a = (t * e.Speed) + e.Phase
				local p = e.Center + Vector3.new(math.cos(a) * e.Radius, math.sin(a * 2.3) * 2, math.sin(a) * e.Radius)
				local ahead = e.Center + Vector3.new(math.cos(a + 0.1) * e.Radius, 0, math.sin(a + 0.1) * e.Radius)
				model:PivotTo(CFrame.lookAt(p, Vector3.new(ahead.X, p.Y, ahead.Z)))
			end
		end
	end)
end

return WorldMotion
