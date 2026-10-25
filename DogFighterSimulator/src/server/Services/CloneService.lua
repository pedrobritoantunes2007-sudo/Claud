-- 🤡 CLONES DO SPOOKY CLOWN (2026-10, pedido do dono: "um cachorro palhaço que vai poder fazer dois clones que
-- atacam com ele e, se ele usar uma habilidade, eles usam junto").
-- Enquanto o cachorro de um jogador for de uma espécie com Clones (DogData: Species.Clones = 2), os clones andam
-- com ele:
--   • seguem em formação (um de cada lado, um pouco atrás); longe demais (ou trocou de ilha) = teleportam;
--   • a cada patada/mordida do dono, batem também no inimigo mais perto NA FRENTE deles (mesma direção da setinha);
--   • a cada habilidade (teclas 2, 3 e o Especial) soltam a MESMA habilidade, cada um um pouco ao lado da setinha;
--   • a cada dash dão a dash junto, na mesma direção;
--   • batem mais fraco (ATK) e têm pouca vida (HP); se um cai, volta depois de RESPAWN s com confete;
--   • somem quando o dono desmaia, troca de cachorro ou sai do jogo.
-- Lutam como o dono: inimigos do dono são inimigos deles (Fighters.Hostile) e o abate conta para o dono
-- (Fighters.Damage marca o dono como quem bateu).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Fighters = require(script.Parent.Fighters)
local CombatService = require(script.Parent.CombatService)
local ZoneGeo = require(script.Parent.ZoneGeo)

local CloneService = {}

CloneService.ATK = 0.35 -- cada clone bate com 35% do ataque do dono
CloneService.HP = 0.3 -- e tem 30% da vida
CloneService.RESPAWN = 8 -- s para um clone que caiu voltar
CloneService.SIDE = 4.5 -- studs para o lado
CloneService.BACK = 2.5 -- studs para trás
CloneService.SPREAD = 4 -- habilidade do clone sai este tanto ao lado da setinha
CloneService.ECHO = 0.1 -- s de atraso entre o dono e cada clone (efeito "eco")
CloneService.LUNGE = 7 -- studs: o clone dá um bote até um inimigo na frente que esteja além do alcance da patada

local UP = Vector3.new(0, 1, 0)
local TICK = 0.1

local getFighter -- function(player) -> fighter do jogador (DogService.GetFighter)
local crew = {} -- [player] = { Master = f, Clones = { [1] = clone|nil, [2] = clone|nil }, DeadAt = { [1] = t, [2] = t } }

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function countOf(f)
	local sp = f and f.Species
	return sp and sp.Clones or 0
end

-- ponto da formação (lado -1 = esquerda, 1 = direita) no chão perto do dono
local function slotPoint(master, side)
	local cf = master.Root.CFrame
	local p = (cf * CFrame.new(side * CloneService.SIDE, 0, CloneService.BACK)).Position
	local feetY = master.Root.Position.Y - master.Humanoid.HipHeight - master.Root.Size.Y / 2
	local g = ZoneGeo.Ground(Vector3.new(p.X, feetY, p.Z), feetY + 8, 30)
	return g or Vector3.new(p.X, feetY, p.Z)
end

local function sideOf(i)
	return i == 1 and -1 or 1
end

-- 👻 clones um pouco transparentes e com brilho roxo: dá para ver quem é o de verdade
local function ghostly(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.9 and d.Name ~= "HumanoidRootPart" then
			d.Transparency = math.max(d.Transparency, 0.3)
			d.CastShadow = false
		end
	end
	local hl = Instance.new("Highlight")
	hl.Name = "CloneGlow"
	hl.FillTransparency = 1
	hl.OutlineColor = Color3.fromRGB(190, 110, 255)
	hl.OutlineTransparency = 0.25
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = model
end

local function spawnClone(player, master, i)
	local side = sideOf(i)
	local at = slotPoint(master, side)
	local ok, c = pcall(Fighters.Spawn, {
		SpeciesId = master.SpeciesId,
		Level = master.Level,
		Kind = "clone",
		Owner = player,
		DisplayName = "🤡 Clone",
		CFrame = CFrame.new(at) * master.Root.CFrame.Rotation,
		Zone = master.Zone,
		Island = master.Island,
		StatMult = { HP = CloneService.HP, Atk = CloneService.ATK },
	})
	if not ok or not c then
		warn("[CloneService] clone não nasceu:", c)
		return nil
	end
	c.CloneOf = master
	c.CloneSide = side
	c.Mode = master.Mode
	c.Controlled = false
	c.Model:SetAttribute("CloneOf", master.Id)
	ghostly(c.Model)
	Fighters.Fx("S_Burst", { Kind = "Confetti", Position = at + UP * 2, Count = 18, Radius = 5 })
	Fighters.Fx("Shockwave", { Position = at, Radius = 5, Color = Color3.fromRGB(190, 110, 255) })
	return c
end

local function removeClone(c, poof)
	if not c then
		return
	end
	if poof and c.Model.Parent then
		Fighters.Fx("S_Burst", { Kind = "Smoke", Position = c.Root.Position, Count = 10, Radius = 3 })
	end
	Fighters.Remove(c)
end

local function clearCrew(player, poof)
	local st = crew[player]
	if not st then
		return
	end
	for i = 1, 2 do
		removeClone(st.Clones[i], poof)
		st.Clones[i] = nil
	end
	crew[player] = nil
end
CloneService.Clear = clearCrew

-- clones vivos de um dono (lista)
function CloneService.Of(master)
	local list = {}
	local player = master and master.Owner
	local st = player and crew[player]
	if st and st.Master == master then
		for i = 1, 2 do
			local c = st.Clones[i]
			if Fighters.Alive(c) then
				table.insert(list, c)
			end
		end
	end
	return list
end

-- segue o dono (formação), sincroniza zona/ilha e teleporta quando fica longe
local function follow(master, c, now)
	c.Zone, c.Island, c.Mode = master.Zone, master.Island, master.Mode
	if (c.CloneBusyUntil or 0) > now or (c.Casting or 0) > 0 or Fighters.IsFrozen(c) then
		return
	end
	local goal = slotPoint(master, c.CloneSide)
	local d = Fighters.FlatDistance(c.Root.Position, goal)
	local dy = math.abs(c.Root.Position.Y - master.Root.Position.Y)
	if d > 45 or dy > 25 then
		Fighters.Teleport(c, goal)
		Fighters.Fx("S_Burst", { Kind = "Confetti", Position = goal + UP * 2, Count = 10, Radius = 3 })
		return
	end
	local speed = master.Humanoid.WalkSpeed
	c.Humanoid.WalkSpeed = math.max(8, speed * (d > 10 and 1.35 or 1.1))
	if d > 1.2 then
		c.Humanoid:MoveTo(goal)
	else
		c.Humanoid:MoveTo(c.Root.Position)
		-- parado do lado do dono: olha para onde ele olha
		local look = flat(master.Root.CFrame.LookVector)
		if look.Magnitude > 0.1 and flat(c.Root.CFrame.LookVector):Dot(look.Unit) < 0.95 then
			Fighters.Face(c, c.Root.Position + look.Unit * 5)
		end
	end
end

local function step(now)
	for player, st in pairs(crew) do
		local master = getFighter and getFighter(player)
		if player.Parent ~= Players or st.Master ~= master or not Fighters.Alive(master) or countOf(master) <= 0 then
			clearCrew(player, true)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local master = getFighter and getFighter(player)
		local n = countOf(master)
		if n > 0 and Fighters.Alive(master) and master.Kind == "player" then
			local st = crew[player]
			if not st then
				st = { Master = master, Clones = {}, DeadAt = {} }
				crew[player] = st
			end
			for i = 1, math.min(2, n) do
				local c = st.Clones[i]
				if c and not Fighters.Alive(c) then
					st.Clones[i] = nil
					st.DeadAt[i] = now
					c = nil
				end
				if not c and now - (st.DeadAt[i] or -1e9) >= CloneService.RESPAWN and (master.Zone ~= "boss") then
					st.Clones[i] = spawnClone(player, master, i)
					c = st.Clones[i]
				end
				if c then
					local ok, err = pcall(follow, master, c, now)
					if not ok then
						warn("[CloneService] follow:", err)
					end
				end
			end
		end
	end
end

---------------------------------------------------------------- espelho dos golpes do dono
local function aimDir(master, aim)
	local look = aim or master.Root.CFrame.LookVector
	look = flat(look)
	return look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
end

-- inimigo mais perto na frente do clone (mesmo cone do jogador), até o alcance da patada + o bote (LUNGE).
-- Devolve o inimigo e a distância entre os corpos
local function frontEnemy(c, look)
	local cone = math.cos(math.rad(Config.MELEE_AIM_CONE))
	local reach = Config.MELEE_REACH + CloneService.LUNGE
	local best, bestD = nil, math.huge
	for _, e in ipairs(Fighters.Enemies(c, c.Root.Position, reach + c.Radius + 2)) do
		if not e.Dummy and e.CloneOf == nil then
			local rel = flat(e.Root.Position - c.Root.Position)
			local d = rel.Magnitude - e.Radius - c.Radius
			if d <= reach and (rel.Magnitude < 0.1 or rel.Unit:Dot(look) >= cone) and d < bestD then
				best, bestD = e, d
			end
		end
	end
	return best, bestD
end

-- 🐾 patada/mordida: os clones batem junto (step = 1 pata direita, 2 pata esquerda, 3 mordida)
function CloneService.Melee(master, step, aim)
	local look = aimDir(master, aim)
	for i, c in ipairs(CloneService.Of(master)) do
		task.delay(CloneService.ECHO * i, function()
			if not Fighters.Alive(c) or Fighters.IsFrozen(c) then
				return
			end
			c.CloneBusyUntil = os.clock() + 0.35
			local enemy, gap = frontEnemy(c, look)
			if not enemy then
				-- ninguém na frente: a patada no ar, junto com o dono
				Fighters.Face(c, c.Root.Position + look * 5)
				Fighters.Melee(c, step)
				return
			end
			Fighters.Face(c, enemy.Root.Position)
			local wait = 0
			if gap > Config.MELEE_REACH - 0.5 then
				-- 🐾 bote curto até o inimigo (os clones ficam do lado/atrás do dono)
				local d = flat(enemy.Root.Position - c.Root.Position)
				d = d.Magnitude > 0.1 and d.Unit or look
				wait = 0.14
				Fighters.SetAction(c, "Dash", 0.25)
				Fighters.Push(c, d * math.clamp((gap - Config.MELEE_REACH * 0.5) / wait, 20, 80), wait)
			end
			task.delay(wait, function()
				if not (Fighters.Alive(c) and Fighters.Alive(enemy)) then
					return
				end
				Fighters.Melee(c, step)
				local rel = flat(enemy.Root.Position - c.Root.Position)
				if rel.Magnitude - enemy.Radius - c.Radius <= Config.MELEE_REACH + 1.5 then
					CombatService.Melee(c, enemy, step, Config.MELEE_COMBO[step])
				end
			end)
		end)
	end
end

-- ✨ habilidade: cada clone solta a MESMA, um pouco ao lado do ponto da setinha
function CloneService.Cast(master, name, point)
	if not (name and point) then
		return
	end
	local look = aimDir(master, point - master.Root.Position)
	local right = Vector3.new(-look.Z, 0, look.X)
	for i, c in ipairs(CloneService.Of(master)) do
		task.delay(CloneService.ECHO * i, function()
			if not Fighters.Alive(c) or Fighters.IsFrozen(c) then
				return
			end
			local p = point + right * c.CloneSide * CloneService.SPREAD
			p = ZoneGeo.Clamp(c, p, 5)
			p = ZoneGeo.Ground(p, math.max(p.Y, c.Root.Position.Y) + 30, 120) or p
			local marker = Fighters.Marker(c, p)
			Fighters.Face(c, p)
			c.Casting = (c.Casting or 0) + 1
			c.CloneBusyUntil = os.clock() + 1
			CombatService.RunSpecial(c, marker, function()
				Fighters.RemoveMarker(marker)
				c.Casting = math.max(0, (c.Casting or 1) - 1)
			end, name, true, true)
		end)
	end
end

-- 💨 dash: os clones dão a dash junto, na mesma direção
function CloneService.Dash(master, aim)
	local look = aimDir(master, aim)
	for i, c in ipairs(CloneService.Of(master)) do
		task.delay(CloneService.ECHO * i * 0.5, function()
			if not Fighters.Alive(c) or Fighters.IsFrozen(c) then
				return
			end
			c.CloneBusyUntil = os.clock() + Config.DASH_TIME + 0.2
			Fighters.Face(c, c.Root.Position + look * 5)
			Fighters.SetAction(c, "Dash", 0.3)
			Fighters.Push(c, look * Config.DASH_SPEED, Config.DASH_TIME)
			-- quem estiver no caminho leva o mesmo dano da dash do dono (com o ataque do clone)
			task.delay(Config.DASH_TIME * 0.7, function()
				if Fighters.Alive(c) then
					local mid = c.Root.Position - look * (Config.DASH_SPEED * Config.DASH_TIME * 0.4)
					Fighters.DamageArea(c, mid, Config.DASH_HIT_WIDTH + 3, c.Stats.Atk * Config.DASH_DAMAGE, { KnockbackPower = 30, Lift = 12, Color = Color3.fromRGB(200, 240, 255) })
				end
			end)
		end)
	end
end

function CloneService.Start(fighterOf)
	getFighter = fighterOf
	Players.PlayerRemoving:Connect(function(player)
		clearCrew(player, false)
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(step, os.clock())
			if not ok then
				warn("[CloneService]", err)
			end
			task.wait(TICK)
		end
	end)
end

return CloneService
