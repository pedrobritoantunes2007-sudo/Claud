-- 🧑🐕 VIDA DA PAWVILLE (cliente, 2026-10, pedido do dono: "uma vila com uns players e cachorros andando nela,
-- bem detalhada e cheia de vida"). Monta o ELENCO (Shared/Village.Cast) só aqui no cliente — nada replica, o
-- servidor não gasta nada — e anima:
--   • gente andando pelas ruas (rede de caminhos da vila), alguns passeando com cachorro na coleira
--   • gente fazendo coisas: vendedor, guarda, varredor, jardineiro, músico, pescador, banhista, conversa (com
--     balãozinho de fala), crianças correndo em volta do chafariz e no parquinho, gente sentada nos bancos
--   • cachorros: brincando no PARQUE do canil (andam, correm, sentam, cavam, fazem reverência, rebolam, se
--     perseguem, buscam a bolinha que o funcionário joga, um faz o circuito de agilidade), dormindo nos boxes e
--     passeando pela vila
--   • o 🎓 Prof. Barkley (montado pelo servidor) respira, olha e gesticula para quem chega perto
--   • 🧑‍🤝‍🧑 (2026-10, pedido do dono: "coloque todos serem meus amigos do Roblox, eu quero pessoas do Roblox mesmo")
--     TODO o povo são AVATARES DE VERDADE: os amigos do dono no Roblox (moldes do servidor em
--     ReplicatedStorage.VillageStars — Services/VillageStars), com a plaquinha do nome em cima. Faltando amigos, o
--     servidor completa com gente do ranking e quem está jogando; lugar que sobra fica vazio. Só se não vier NINGUÉM
--     (Studio sem internet) a vila usa o povo de blocos, para não ficar deserta.
-- Só acorda com a câmera perto da vila (Village.LIFE_RANGE); longe, tudo sai do workspace e para (não pesa).
-- ⚡ Leve: quem está longe da câmera anima menos vezes (e nada além de 420 studs); o chão de cada um é medido de novo
-- até achar (a vila pode estar chegando ainda — antes o povo ficava enterrado).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Village = require(ReplicatedStorage.Shared.Village)
local VillageFolk = require(ReplicatedStorage.Shared.VillageFolk)
local DogBuilder = require(ReplicatedStorage.Shared.DogBuilder)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Animator = require(script.Parent.Parent:WaitForChild("Animator"))

local VillageLife = {}

local player = Players.LocalPlayer
local G = Village.GROUND_Y
local TAU = math.pi * 2
local rng = Random.new()

local folder = Instance.new("Folder")
folder.Name = "VidaDaVila"
local actors = {}
local dogs = {}
local built, building, awake = false, false, false
local starsDirty, dressing = false, false
local STAR_TOP = (Config.VILLAGE_PEOPLE and Config.VILLAGE_PEOPLE.Max) or 40 -- pessoas de verdade no máximo
local graph = Village.Graph()
local nodeY = {}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function refreshFilter()
	local list = { folder }
	local dogsFolder = workspace:FindFirstChild("Cachorros")
	if dogsFolder then
		table.insert(list, dogsFolder)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	rayParams.FilterDescendantsInstances = list
end

-- altura do chão (mundo) no ponto local (x, z); o raio começa baixo para não pegar telhado/arco. O 2º valor diz se
-- achou chão de verdade (a vila ainda chegando: devolve a altura das ruas e quem chamou tenta de novo depois)
local function groundAt(x, z, fromY)
	local p = Village.ToWorld(x, (fromY or G) + 8, z)
	local hit = workspace:Raycast(p, Vector3.new(0, -40, 0), rayParams)
	if hit then
		return hit.Position.Y, true
	end
	return (fromY or G), false
end

local function lerp(a, b, t)
	return a + (b - a) * t
end
local function approach(cur, goal, rate, dt)
	return cur + (goal - cur) * math.min(1, rate * dt)
end
local function angleTo(cur, goal, rate, dt)
	local d = (goal - cur + math.pi) % TAU - math.pi
	return cur + d * math.min(1, rate * dt)
end

---------------------------------------------------------------- 💬 balãozinho de fala
local function say(actor, text)
	local head = actor.Rig and actor.Rig.Head
	if not head then
		return
	end
	if actor.Bubble then
		actor.Bubble:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Fala"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(230, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2 * actor.Rig.Scale, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.fromScale(0.5, 1)
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(40, 34, 50)
	stroke.Parent = frame
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -16, 1, -8)
	label.Position = UDim2.fromOffset(8, 4)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(40, 34, 50)
	label.Text = text
	label.Parent = frame
	gui.Parent = player:FindFirstChildOfClass("PlayerGui")
	actor.Bubble = gui
	task.delay(3.6, function()
		if actor.Bubble == gui then
			gui:Destroy()
			actor.Bubble = nil
		end
	end)
end

---------------------------------------------------------------- montagem
local function placeRig(actor)
	local rig = actor.Rig
	rig.Root.CFrame = Village.CF * CFrame.new(actor.X, actor.Y, actor.Z) * CFrame.Angles(0, actor.Ry, 0)
end

-- altura da raiz acima do chão (bonequinho de blocos ou avatar R15)
local function rootHeight(rig, how, scale)
	if rig.Avatar then
		return VillageFolk.RootHeight(rig, how)
	end
	local s = scale or 1
	if how == "Sit" then
		return 2.2 + s
	elseif how == "SitGround" then
		return 1.15 * s
	end
	return 3 * s
end

-- pessoa do elenco SEM boneco ainda (o boneco é posto por dress: blocos ou avatar dos top 30)
local function newFolk(a, slot)
	local gy, gok = groundAt(a.X, a.Z)
	local actor = {
		Kind = "Folk",
		Cast = a,
		Slot = slot,
		Role = a.Role,
		How = a.How,
		X = a.X,
		Z = a.Z,
		Ry = a.Ry or 0,
		-- a.Y = altura local do piso quando não é o chão (deque do cais)
		Ground = a.Y or gy,
		-- chão medido de verdade? (senão mede de novo — a vila pode estar chegando)
		GroundOk = a.Y ~= nil or gok,
		RootH = 3,
		Y = 0,
		NextSay = os.clock() + rng:NextNumber(3, 14),
		Phase = a.Phase or rng:NextNumber(0, TAU),
		W = { Walk = 0, Run = 0, Sit = a.How == "Sit" and 1 or 0, SitGround = a.How == "SitGround" and 1 or 0 },
		Seed = rng:NextNumber(0, 100),
		NextRay = 0,
		Ball = a.Ball,
	}
	if a.How == "Walk" then
		actor.From = a.Node
		local links = graph.Links[a.Node]
		actor.To = links[rng:NextInteger(1, #links)]
		actor.Dist = 0
		actor.Speed = a.Speed or 6
		actor.Side = (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(1.6, 3.6)
		actor.PauseUntil = 0
	elseif a.How == "Run" then
		actor.CX, actor.CZ, actor.R = a.CX, a.CZ, a.R
		actor.Ang = a.Phase or 0
		actor.Speed = rng:NextNumber(9, 12)
		actor.Dir = rng:NextNumber() < 0.5 and -1 or 1
	end
	return actor
end

---------------------------------------------------------------- 🌟 top 30 (avatares de verdade)
-- moldes do servidor, do 1º lugar para baixo
local function starList()
	local f = ReplicatedStorage:FindFirstChild("VillageStars")
	local list = {}
	if f then
		for _, m in ipairs(f:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("Rank") then
				table.insert(list, m)
			end
		end
	end
	table.sort(list, function(a, b)
		return a:GetAttribute("Rank") < b:GetAttribute("Rank")
	end)
	while #list > STAR_TOP do
		table.remove(list)
	end
	return list
end

-- plaquinha em cima da cabeça: o nome de exibição e quem é (🤝 amigo do dono, 💪 do ranking, 🎮 jogando agora)
local KIND_TAG = {
	friend = { "🤝 FRIEND", Color3.fromRGB(140, 230, 255) },
	top = { "💪 TOP PLAYER", Color3.fromRGB(255, 190, 120) },
	here = { "🎮 PLAYING NOW", Color3.fromRGB(150, 255, 150) },
}
local function nameTag(rig, star)
	local head = rig.Head
	if not head then
		return
	end
	local kind = KIND_TAG[star:GetAttribute("Kind") or ""] or KIND_TAG.friend
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nome"
	gui.Size = UDim2.fromOffset(210, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.3, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.6)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextStrokeTransparency = 0.25
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = tostring(star:GetAttribute("DisplayName") or "Player")
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.Size = UDim2.fromScale(1, 0.4)
	sub.Font = Enum.Font.FredokaOne
	sub.TextScaled = true
	sub.TextStrokeTransparency = 0.35
	sub.TextColor3 = kind[2]
	sub.Text = kind[1]
	sub.Parent = gui
	gui.Parent = head
end

-- coleira: fio do cachorro até a mão do dono (de novo sempre que o dono troca de boneco)
local function leash(dog)
	if dog.LeashParts then
		for _, inst in ipairs(dog.LeashParts) do
			inst:Destroy()
		end
		dog.LeashParts = nil
	end
	local rig = dog.Owner and dog.Owner.Rig
	if not rig then
		return
	end
	local hand = rig.Hand or rig.Model:FindFirstChild("RightArm")
	if not hand then
		return
	end
	local root = dog.Root
	local a0 = Instance.new("Attachment")
	a0.Position = rig.Avatar and Vector3.new(0, -hand.Size.Y * 0.4, 0) or Vector3.new(0, -0.95, -0.2) * rig.Scale
	a0.Parent = hand
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, root.Size.Y * 0.25, -root.Size.Z * 0.45)
	a1.Parent = root
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0, beam.Width1 = 0.14, 0.14
	beam.Color = ColorSequence.new(Color3.fromRGB(190, 50, 60))
	beam.Segments = 6
	beam.CurveSize0, beam.CurveSize1 = -0.6, 0.6
	beam.FaceCamera = true
	beam.Parent = root
	dog.LeashParts = { a0, a1, beam }
end

-- o boneco que cada pessoa deve ter: "avatar:<id>" (gente de verdade), "none" (lugar sobrando: fica vazio) ou
-- "block" (povo de blocos — só quando não veio ninguém de verdade, para a vila não ficar deserta, e enquanto o
-- servidor ainda está montando os avatares: Loading na pasta; cada lugar troca para o amigo assim que ele chega)
local function wantFor(actor, stars, loading)
	local k = actor.Slot
	local star = k and stars[k]
	if star then
		return "avatar:" .. tostring(star:GetAttribute("UserId")) .. ":" .. tostring(star:GetAttribute("Rank")), star
	end
	if #stars == 0 or loading then
		return "block", nil
	end
	return "none", nil
end

-- põe (ou troca) o boneco da pessoa
local function dress(actor, key, star)
	if actor.Dressed == key then
		return
	end
	if actor.Rig then
		actor.Rig.Model:Destroy()
		actor.Rig = nil
	end
	if actor.Bubble then
		actor.Bubble:Destroy()
		actor.Bubble = nil
	end
	actor.Dressed = key
	if key ~= "none" then
		local a = actor.Cast
		local cf = Village.CF * CFrame.new(actor.X, actor.Ground, actor.Z) * CFrame.Angles(0, actor.Ry, 0)
		local rig = nil
		if star then
			local ok, r = pcall(VillageFolk.FromAvatar, star, folder, cf)
			if ok and r then
				rig = r
				nameTag(rig, star)
			end
		end
		if not rig then
			local outfit = VillageFolk.Outfit(a.Seed, a.Role)
			if a.Role == "Vendor" and a.Say and a.Say[1] and a.Say[1]:find("Balloon") then
				outfit.Hold = "balloons"
			end
			rig = VillageFolk.Build(folder, cf, outfit, a.Scale or 1)
		end
		actor.Rig = rig
		-- avatar de jogador de verdade não "fala" frases inventadas (só gesticula)
		actor.Say = not rig.Avatar and a.Say or nil
		actor.RootH = rootHeight(rig, actor.How, a.Scale)
		actor.Y = actor.Ground + actor.RootH
		placeRig(actor)
	end
	for _, d in ipairs(dogs) do
		if d.Owner == actor then
			leash(d)
		end
	end
end

-- põe em todo mundo o boneco certo (no começo e quando o ranking muda), um pouco por quadro
local function applyStars()
	if dressing then
		return
	end
	dressing = true
	local stars = starList()
	local f = ReplicatedStorage:FindFirstChild("VillageStars")
	local loading = f ~= nil and f:GetAttribute("Loading") == true
	local n = 0
	for _, actor in ipairs(actors) do
		local key, star = wantFor(actor, stars, loading)
		if actor.Dressed ~= key then
			local ok, err = pcall(dress, actor, key, star)
			if not ok then
				warn("[VillageLife] boneco:", err)
			end
			n += 1
			if n % 3 == 0 then
				task.wait()
			end
		end
	end
	dressing = false
end

local function prepDog(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		elseif d:IsA("Humanoid") then
			d:Destroy()
		end
	end
	model.PrimaryPart.Anchored = true
end

local function buildDog(a, owners)
	-- (2026-10) do mesmo tamanho do cachorro de jogador daquela raça (DogData.GameScale)
	local ok, model = pcall(DogBuilder.Build, a.Species, { scale = DogData.GameScale(a.Species) })
	if not (ok and model) then
		return nil
	end
	prepDog(model)
	local hip = model:GetAttribute("HipHeight") or 2
	local root = model.PrimaryPart
	local actor = {
		Kind = "Dog",
		Role = a.Role,
		Model = model,
		Root = root,
		Lift = hip + root.Size.Y / 2,
		X = a.X,
		Z = a.Z,
		Ry = a.Ry or 0,
		CX = a.CX,
		CZ = a.CZ,
		R = a.R,
		State = "Idle",
		Until = os.clock() + rng:NextNumber(1, 5),
		NextRay = 0,
	}
	if a.Role == "Leash" then
		actor.Owner = owners[a.Owner]
	end
	local ground, gok = groundAt(a.X, a.Z)
	if a.Role == "Booth" then
		ground += 0.95 -- em cima da caminha (o raio pega o piso do box; a almofada é enfeite)
		actor.Action = "Snore"
		model:SetAttribute("Action", "Snore")
	end
	actor.Ground = ground
	actor.GroundOk = gok
	root.CFrame = Village.CF * CFrame.new(a.X, ground + actor.Lift, a.Z) * CFrame.Angles(0, actor.Ry, 0)
	model.Parent = folder
	Animator.Track(model)
	-- coleira: fio do cachorro até a mão do dono
	leash(actor)
	return actor
end

local professor = nil
local function findProfessor()
	for _, m in ipairs(CollectionService:GetTagged("VillageFolk")) do
		if m:IsDescendantOf(workspace) and m:GetAttribute("Role") == "Professor" then
			local rig = VillageFolk.RigFrom(m)
			if rig then
				return { Rig = rig, Model = m, Phase = 0, NextWave = 0 }
			end
		end
	end
	return nil
end

-- monta o elenco aos poucos (sem travar): gente primeiro, cachorros 1 por quadro
local function buildAll()
	if built or building then
		return
	end
	building = true
	-- espera a vila terminar de montar (servidor novo leva uns 25 s) e chegar aqui: o povo precisa do chão para ficar
	-- em pé nele (antes nascia antes do chão e ficava enterrado)
	local t0 = os.clock()
	while os.clock() - t0 < 45 do
		local isles = workspace:FindFirstChild("Islands")
		local v = isles and isles:FindFirstChild(Village.Id)
		if v and v:GetAttribute("Ready") then
			task.wait(1.5)
			break
		end
		task.wait(0.5)
	end
	refreshFilter()
	local cast = Village.Cast(2026)
	local slotOf = Village.Residents(cast)
	local owners = {}
	for i, a in ipairs(cast) do
		if a.Kind == "Folk" then
			local ok, actor = pcall(newFolk, a, slotOf[i])
			if ok and actor then
				owners[i] = actor
				table.insert(actors, actor)
			end
		end
	end
	-- bonecos: avatares dos top 30 nos moradores, povo de blocos no resto
	applyStars()
	for _, a in ipairs(cast) do
		if a.Kind == "Dog" then
			local ok, actor = pcall(buildDog, a, owners)
			if ok and actor then
				table.insert(dogs, actor)
			end
			task.wait()
		end
	end
	-- 1 cachorro do parque busca a bolinha do funcionário; outro faz o circuito de agilidade
	local staff = nil
	for _, actor in ipairs(actors) do
		if actor.Ball then
			staff = actor
		end
	end
	local parkDogs = {}
	for _, d in ipairs(dogs) do
		if d.Role == "Park" then
			table.insert(parkDogs, d)
		end
	end
	if staff and parkDogs[1] then
		parkDogs[1].Role = "Fetch"
		parkDogs[1].Staff = staff
		staff.Fetcher = parkDogs[1]
		local ball = Instance.new("Part")
		ball.Name = "Bolinha"
		ball.Size = Vector3.new(0.9, 0.9, 0.9)
		ball.Color = Color3.fromRGB(255, 80, 80)
		ball.Material = Enum.Material.SmoothPlastic
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.Parent = folder
		staff.BallPart = ball
	end
	if parkDogs[2] then
		parkDogs[2].Role = "Agility"
		parkDogs[2].Leg = 1
	end
	built = true
	building = false
end

---------------------------------------------------------------- 🚶 gente
local function nextNode(at, from)
	local links = graph.Links[at]
	if #links == 1 then
		return links[1]
	end
	for _ = 1, 6 do
		local n = links[rng:NextInteger(1, #links)]
		if n ~= from then
			return n
		end
	end
	return links[1]
end
local function nodeHeight(i)
	local h = nodeY[i]
	if not h then
		local n = graph.Nodes[i]
		local ok
		h, ok = groundAt(n[1], n[2])
		if ok then
			nodeY[i] = h -- (só guarda chão de verdade: a vila pode estar chegando)
		end
	end
	return h
end

local function updateFolk(actor, dt, now, camDist)
	local st = { Phase = actor.Phase }
	local w = actor.W
	local moving, running = false, false
	if actor.How == "Walk" then
		if now < actor.PauseUntil then
			-- parado olhando em volta (às vezes acena)
			st.LookYaw = math.sin(now * 0.7 + actor.Seed) * 0.6
			st.Wave = actor.Waving and 1 or 0
		else
			local a, b = graph.Nodes[actor.From], graph.Nodes[actor.To]
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local len = math.max(0.01, math.sqrt(dx * dx + dz * dz))
			actor.Dist += actor.Speed * dt
			if actor.Dist >= len then
				local from = actor.To
				actor.To = nextNode(from, actor.From)
				actor.From = from
				actor.Dist = 0
				if rng:NextNumber() < 0.14 then
					actor.PauseUntil = now + rng:NextNumber(2, 6)
					actor.Waving = rng:NextNumber() < 0.35
				end
				a, b = graph.Nodes[actor.From], graph.Nodes[actor.To]
				dx, dz = b[1] - a[1], b[2] - a[2]
				len = math.max(0.01, math.sqrt(dx * dx + dz * dz))
			end
			local t = actor.Dist / len
			local ux, uz = dx / len, dz / len
			local px = a[1] + dx * t + uz * actor.Side
			local pz = a[2] + dz * t - ux * actor.Side
			actor.X = approach(actor.X, px, 6, dt)
			actor.Z = approach(actor.Z, pz, 6, dt)
			actor.Ry = angleTo(actor.Ry, Village.Face(0, 0, ux, uz), 8, dt)
			local gy = lerp(nodeHeight(actor.From), nodeHeight(actor.To), t)
			if camDist < 250 and now > actor.NextRay then
				actor.NextRay = now + 0.35
				local ry, ok = groundAt(actor.X, actor.Z, gy)
				actor.RayY = ok and ry or nil
			end
			actor.Ground = approach(actor.Ground, actor.RayY or gy, 10, dt)
			actor.Phase += dt * actor.Speed * 1.35
			moving = true
		end
	elseif actor.How == "Run" then
		actor.Ang += dt * actor.Speed / actor.R * actor.Dir
		local px = actor.CX + math.cos(actor.Ang) * actor.R
		local pz = actor.CZ + math.sin(actor.Ang) * actor.R
		local tx, tz = -math.sin(actor.Ang) * actor.Dir, math.cos(actor.Ang) * actor.Dir
		actor.X, actor.Z = px, pz
		actor.Ry = Village.Face(0, 0, tx, tz)
		if camDist < 250 and now > actor.NextRay then
			actor.NextRay = now + 0.3
			local ry, ok = groundAt(px, pz)
			if ok then
				actor.Ground = ry
			end
		end
		actor.Phase += dt * actor.Speed * 1.2
		running = true
	end
	w.Walk = approach(w.Walk, moving and 1 or 0, 8, dt)
	w.Run = approach(w.Run, running and 1 or 0, 8, dt)
	st.Walk, st.Run, st.Phase = w.Walk, w.Run, actor.Phase
	st.Sit, st.SitGround = w.Sit, w.SitGround
	-- o que cada um faz parado
	local role = actor.Role
	local cycle = (now + actor.Seed) % 12
	if role == "Greeter" then
		st.Wave = (cycle < 3.5) and 1 or 0
		st.Talk = (cycle >= 3.5 and cycle < 7) and 1 or 0
	elseif role == "Vendor" or role == "Chat" then
		st.Talk = (cycle < 8) and 1 or 0
		st.Wave = (role == "Vendor" and cycle >= 9 and cycle < 10.5) and 1 or 0
	elseif role == "Music" then
		st.Strum = 1
	elseif role == "Sweep" then
		st.Sweep = 1
	elseif role == "Garden" then
		st.Garden = 1
	elseif role == "Fish" then
		st.Fish = 1
	elseif role == "Guard" then
		st.LookYaw = math.sin(now * 0.4 + actor.Seed) * 0.5
	elseif role == "Sit" then
		st.Talk = (cycle < 4) and 0.6 or 0
		st.LookYaw = math.sin(now * 0.3 + actor.Seed) * 0.4
	elseif role == "Staff" then
		if actor.Throwing then
			st.Throw = 1
			st.ThrowT = actor.ThrowT or 0
		else
			st.Wave = (not actor.Ball and cycle < 2.5) and 1 or 0
			st.Clap = (actor.Ball and actor.Clapping) and 1 or 0
		end
	elseif role == "Beach" then
		st.LookYaw = math.sin(now * 0.25 + actor.Seed) * 0.5
	end
	if actor.Say and now > actor.NextSay then
		actor.NextSay = now + rng:NextNumber(8, 16)
		if camDist < 80 then
			say(actor, actor.Say[rng:NextInteger(1, #actor.Say)])
		end
	end
	-- parado e o chão ainda não foi achado (a vila chegando): mede de novo a cada segundo
	if not actor.GroundOk and actor.How ~= "Walk" and now > (actor.NextGround or 0) then
		actor.NextGround = now + 1
		local gy, ok = groundAt(actor.X, actor.Z)
		if ok then
			actor.Ground, actor.GroundOk = gy, true
		end
	end
	actor.Y = actor.Ground + actor.RootH
	placeRig(actor)
	-- longe: pose só às vezes (e nada além de 420 studs)
	if camDist < 160 or (camDist < 420 and (actor.Skip or 0) <= 0) then
		VillageFolk.Pose(actor.Rig, now + actor.Seed, st)
		actor.Skip = 3
	else
		actor.Skip = (actor.Skip or 0) - 1
	end
end

---------------------------------------------------------------- 🐕 cachorros
local PARK_ACTIONS = { "Sit", "Bow", "Dig", "Sniff", "Wiggle", "Bark", "Shake", false, false }
-- 🎉 FESTA no parque (cena do tutorial: "os cachorros brincando", VillageLife.Party): mais correria e truques
local PARTY_ACTIONS = { "Wiggle", "Bark", "Bow", "Flip", "Twirl", "Bounce", "Victory", "Roll" }
local partyUntil = 0
local TOWN_ACTIONS = { "Sit", "Sniff", "Bark", false, false, false }

local function setAction(dog, action)
	if dog.Action ~= action then
		dog.Action = action
		dog.Model:SetAttribute("Action", action or nil)
	end
end

local function moveDog(dog, tx, tz, speed, dt, now, camDist)
	local dx, dz = tx - dog.X, tz - dog.Z
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 0.4 then
		return true
	end
	local step = math.min(d, speed * dt)
	dog.X += dx / d * step
	dog.Z += dz / d * step
	dog.Ry = angleTo(dog.Ry, Village.Face(0, 0, dx, dz), 7, dt)
	if camDist < 260 and now > dog.NextRay then
		dog.NextRay = now + 0.3
		local gy, ok = groundAt(dog.X, dog.Z, dog.Ground)
		if ok then
			dog.Ground, dog.GroundOk = gy, true
		end
	end
	return d - step < 0.4
end

-- circuito de agilidade (local da vila): obstáculos, túnel e slalom
local AG = Village.PARK.Agility
local AGILITY = {
	{ AG.X + 6, AG.Z + 28 },
	{ AG.X + 6, AG.Z - 12 },
	{ AG.X - 7, AG.Z - 16 },
	{ AG.X - 7, AG.Z + 1 },
	{ AG.X - 5.6, AG.Z + 5.5 },
	{ AG.X - 8.4, AG.Z + 8.5 },
	{ AG.X - 5.6, AG.Z + 11.5 },
	{ AG.X - 8.4, AG.Z + 14.5 },
	{ AG.X - 5.6, AG.Z + 17.5 },
	{ AG.X - 8.4, AG.Z + 20.5 },
	{ AG.X - 7, AG.Z + 27 },
}
local HURDLES = { AG.Z + 20, AG.Z + 10, AG.Z }

local function updateDog(dog, dt, now, camDist)
	local role = dog.Role
	local hop = 0
	-- chão ainda não achado (a vila chegando): mede de novo a cada segundo
	if not dog.GroundOk and now > (dog.NextGround or 0) then
		dog.NextGround = now + 1
		local gy, ok = groundAt(dog.X, dog.Z)
		if ok then
			dog.Ground, dog.GroundOk = gy + (role == "Booth" and 0.95 or 0), true
			dog.Root.CFrame = Village.CF * CFrame.new(dog.X, dog.Ground + dog.Lift, dog.Z) * CFrame.Angles(0, dog.Ry, 0)
		end
	end
	if role == "Booth" then
		return
	elseif role == "Leash" then
		local o = dog.Owner
		if not (o and o.Rig) then
			return
		end
		local fx, fz = -math.sin(o.Ry), -math.cos(o.Ry)
		local tx, tz = o.X - fz * 2.2 - fx * 2.4, o.Z + fx * 2.2 - fz * 2.4
		local dx, dz = tx - dog.X, tz - dog.Z
		local d = math.sqrt(dx * dx + dz * dz)
		local speed = math.clamp(d * 3.2, 0, 22)
		if d > 0.3 then
			moveDog(dog, tx, tz, speed, dt, now, camDist)
			setAction(dog, nil)
		else
			dog.Ry = angleTo(dog.Ry, o.Ry, 4, dt)
			if (now + o.Seed) % 9 < 2 then
				setAction(dog, "Sniff")
			end
		end
	elseif role == "Agility" then
		local p = AGILITY[dog.Leg]
		if moveDog(dog, p[1], p[2], 15, dt, now, camDist) then
			dog.Leg = dog.Leg % #AGILITY + 1
		end
		-- pulinho em cada obstáculo
		if math.abs(dog.X - (AG.X + 6)) < 2 then
			for _, hz in ipairs(HURDLES) do
				local k = math.abs(dog.Z - hz)
				if k < 2.4 then
					hop = math.max(hop, 2.6 * math.cos(k / 2.4 * math.pi / 2))
				end
			end
		end
	elseif role == "Fetch" then
		local staff = dog.Staff
		local ball = staff and staff.BallPart
		if not (staff and ball) then
			return
		end
		local state = dog.State
		if state == "Idle" or state == "Wait" then
			-- espera na frente do funcionário (sentado)
			local fx, fz = -math.sin(staff.Ry), -math.cos(staff.Ry)
			local wx, wz = staff.X + fx * 3, staff.Z + fz * 3
			if moveDog(dog, wx, wz, 10, dt, now, camDist) then
				dog.Ry = angleTo(dog.Ry, staff.Ry + math.pi, 5, dt)
				setAction(dog, "Sit")
			end
			if now > dog.Until and not staff.Throwing then
				-- joga a bolinha!
				staff.Throwing = true
				staff.ThrowT = 0
				local tx, tz = Village.ParkSpot(rng)
				dog.BallFrom = Vector3.new(staff.X, staff.Ground + 5.5, staff.Z)
				dog.BallTo = Vector3.new(tx, groundAt(tx, tz) + 0.45, tz)
				dog.State = "Throw"
				dog.T = 0
				setAction(dog, "Bow")
			end
			if state == "Idle" then
				dog.State = "Wait"
				dog.Until = now + rng:NextNumber(3, 5)
			end
		elseif state == "Throw" then
			dog.T += dt
			staff.ThrowT = math.min(1, dog.T / 0.7)
			if dog.T >= 0.4 then
				local k = math.min(1, (dog.T - 0.4) / 1.1)
				local p = dog.BallFrom:Lerp(dog.BallTo, k) + Vector3.new(0, math.sin(k * math.pi) * 9, 0)
				ball.CFrame = Village.CF * CFrame.new(p)
				if dog.T > 0.55 then
					setAction(dog, nil)
					moveDog(dog, dog.BallTo.X, dog.BallTo.Z, 18, dt, now, camDist)
				end
				if k >= 1 then
					staff.Throwing = false
					dog.State = "Chase"
				end
			else
				ball.CFrame = staff.Rig.Root.CFrame * CFrame.new(1.4, 1.4, -0.6)
			end
		elseif state == "Chase" then
			ball.CFrame = Village.CF * CFrame.new(dog.BallTo)
			if moveDog(dog, dog.BallTo.X, dog.BallTo.Z, 18, dt, now, camDist) then
				dog.State = "Bring"
			end
		elseif state == "Bring" then
			ball.CFrame = dog.Root.CFrame * CFrame.new(0, dog.Root.Size.Y * 0.2, -dog.Root.Size.Z * 0.75)
			local sx, sz = -math.sin(staff.Ry), -math.cos(staff.Ry)
			if moveDog(dog, staff.X + sx * 3, staff.Z + sz * 3, 14, dt, now, camDist) then
				dog.State = "Idle"
				dog.Until = now + rng:NextNumber(2.5, 4)
				staff.Clapping = true
				task.delay(1.6, function()
					staff.Clapping = false
				end)
				ball.CFrame = Village.CF * CFrame.new(staff.X + sx * 1.6, staff.Ground + 0.45, staff.Z + sz * 1.6)
			end
		end
	else
		-- 🐾 passeio livre: no parque (pontos do gramado) ou em volta de um lugar da vila
		local state = dog.State
		if state == "Idle" or state == "Do" then
			if now > dog.Until then
				-- próximo passeio: às vezes corre atrás de outro cachorro (na festa, quase sempre)
				local party = role == "Park" and now < partyUntil
				if role == "Park" and rng:NextNumber() < (party and 0.55 or 0.22) then
					local other = dogs[rng:NextInteger(1, #dogs)]
					if other ~= dog and other.Role == "Park" then
						dog.State = "Chase"
						dog.Target = other
						dog.Until = now + rng:NextNumber(3, 6)
						setAction(dog, nil)
						return
					end
				end
				local tx, tz
				if role == "Park" then
					tx, tz = Village.ParkSpot(rng)
				else
					-- passeio em volta do lugar dele, sempre em terra (nada de entrar no mar ou no lago)
					tx, tz = dog.X, dog.Z
					for _ = 1, 10 do
						local a, r = rng:NextNumber(0, TAU), math.sqrt(rng:NextNumber()) * (dog.R or 30)
						local x, z = (dog.CX or dog.X) + math.cos(a) * r, (dog.CZ or dog.Z) + math.sin(a) * r
						if Village.Walkable(x, z) then
							tx, tz = x, z
							break
						end
					end
				end
				dog.TX, dog.TZ = tx, tz
				dog.Speed = (party or rng:NextNumber() < 0.4) and rng:NextNumber(13, 17) or rng:NextNumber(5, 8)
				dog.State = "Go"
				setAction(dog, nil)
			end
		elseif state == "Go" then
			if moveDog(dog, dog.TX, dog.TZ, dog.Speed, dt, now, camDist) then
				local party = role == "Park" and now < partyUntil
				local list = party and PARTY_ACTIONS or (role == "Park" and PARK_ACTIONS or TOWN_ACTIONS)
				local act = list[rng:NextInteger(1, #list)]
				setAction(dog, act or nil)
				dog.State = act and "Do" or "Idle"
				dog.Until = now + (party and rng:NextNumber(1.2, 2.4) or rng:NextNumber(3, 8))
			end
		elseif state == "Chase" then
			local t = dog.Target
			if t and now < dog.Until then
				local fx, fz = -math.sin(t.Ry), -math.cos(t.Ry)
				moveDog(dog, t.X - fx * 3, t.Z - fz * 3, 16, dt, now, camDist)
			else
				dog.State = "Idle"
				dog.Until = now + rng:NextNumber(1, 3)
				setAction(dog, "Wiggle")
			end
		end
	end
	dog.Root.CFrame = Village.CF * CFrame.new(dog.X, dog.Ground + dog.Lift + hop, dog.Z) * CFrame.Angles(0, dog.Ry, 0)
end

---------------------------------------------------------------- 🎓 professor
local function updateProfessor(dt, now)
	local p = professor
	if not (p and p.Model.Parent and p.Model:IsDescendantOf(workspace)) then
		professor = findProfessor()
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local st = {}
	local near = false
	if root then
		local rel = p.Rig.Root.CFrame:PointToObjectSpace(root.Position)
		local dist = rel.Magnitude
		if dist < 26 then
			near = true
			-- olha para quem chega (só a cabeça)
			st.LookYaw = math.clamp(math.atan2(-rel.X, -rel.Z), -1, 1)
			st.LookPitch = math.clamp(math.atan2(rel.Y, math.max(1, -rel.Z)) * 0.5, -0.3, 0.3)
			if not p.WasNear then
				p.NextWave = now + 2.2
			end
		end
	end
	p.WasNear = near
	st.Wave = (near and now < p.NextWave) and 1 or 0
	st.Talk = (near and now >= p.NextWave) and 0.8 or 0
	VillageFolk.Pose(p.Rig, now, st)
end

---------------------------------------------------------------- laço
local function wake()
	if awake then
		return
	end
	awake = true
	folder.Parent = workspace
	if not built then
		task.spawn(buildAll)
	else
		for _, d in ipairs(dogs) do
			Animator.Track(d.Model)
			if d.Action then
				d.Model:SetAttribute("Action", d.Action)
			end
		end
	end
end
local function sleep()
	if not awake then
		return
	end
	awake = false
	folder.Parent = nil -- (o Animator para sozinho de animar quem saiu do workspace)
end

-- avisa quando a pasta dos top 30 muda (ela pode chegar depois do cliente começar)
local function watchStars()
	local function hook(f)
		f:GetAttributeChangedSignal("Version"):Connect(function()
			starsDirty = true
		end)
		f:GetAttributeChangedSignal("Loading"):Connect(function()
			starsDirty = true
		end)
		starsDirty = true
	end
	local f = ReplicatedStorage:FindFirstChild("VillageStars")
	if f then
		hook(f)
	else
		local conn
		conn = ReplicatedStorage.ChildAdded:Connect(function(child)
			if child.Name == "VillageStars" then
				conn:Disconnect()
				hook(child)
			end
		end)
	end
end

-- 🎉 festa no parque do canil por `seconds` (cena dos cachorros brincando no tutorial da guia): todo mundo corre,
-- persegue os outros e faz truques (cambalhota, giro, pulinhos, rolar)
function VillageLife.Party(seconds: number?)
	partyUntil = os.clock() + (seconds or 10)
	for _, dog in ipairs(dogs) do
		if dog.Role == "Park" and (dog.State == "Idle" or dog.State == "Do") then
			dog.Until = 0
		end
	end
end

function VillageLife.Start()
	watchStars()
	local acc, filterAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local camPos = cam.CFrame.Position
		acc += dt
		if acc > 1 then
			acc = 0
			local d = (camPos - Village.Center).Magnitude
			if d < Village.LIFE_RANGE then
				wake()
			elseif d > Village.LIFE_RANGE + 200 then
				sleep()
			end
			-- 🌟 o ranking mudou (servidor trocou os moldes): troca os bonecos de quem mudou
			if starsDirty and built and not dressing then
				starsDirty = false
				task.spawn(applyStars)
			end
		end
		if not awake then
			return
		end
		filterAcc += dt
		if filterAcc > 3 then
			filterAcc = 0
			refreshFilter()
		end
		local now = os.clock()
		dt = math.min(dt, 0.1)
		-- ⚡ perto da câmera: todo quadro; mais longe: 10x por segundo; bem longe: 2x por segundo (anda do mesmo jeito)
		local function due(who, camDist, near, far)
			who.Acc = (who.Acc or 0) + dt
			local every = camDist < near and 0 or camDist < far and 0.1 or 0.5
			if who.Acc < every then
				return nil
			end
			local step = math.min(who.Acc, 0.5)
			who.Acc = 0
			return step
		end
		for _, actor in ipairs(actors) do
			if actor.Rig then
				local camDist = (actor.Rig.Root.Position - camPos).Magnitude
				local step = due(actor, camDist, 160, 420)
				if step then
					local ok, err = pcall(updateFolk, actor, step, now, camDist)
					if not ok and not actor.Warned then
						actor.Warned = true
						warn("[VillageLife] pessoa:", err)
					end
				end
			end
		end
		for _, dog in ipairs(dogs) do
			local camDist = (dog.Root.Position - camPos).Magnitude
			local step = due(dog, camDist, 200, 450)
			if step then
				local ok, err = pcall(updateDog, dog, step, now, camDist)
				if not ok and not dog.Warned then
					dog.Warned = true
					warn("[VillageLife] cachorro:", err)
				end
			end
		end
		pcall(updateProfessor, dt, now)
	end)
end

return VillageLife
