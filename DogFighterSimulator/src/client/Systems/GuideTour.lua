-- 🧭 TUTORIAL DA GUIA (2026-10-23, pedido do dono: "aparece uma pessoa na frente, explica como funciona o jogo e você
-- vai seguindo ela até a parte do cachorro onde você ganha um cachorro; conversa com a pessoa que dá o cachorro, tem uma
-- animação mostrando os cachorros brincando e depois ela fala: chegou sua vez de ter um cachorro. Quando ganha, ainda
-- não vira o cachorro: ele fica te seguindo. Segue a guia até o portal da Arena (ela não entra, explica o que é), depois
-- ela explica como funciona o jogo e o objetivo — ter o cachorro mais forte de DogWorld —, depois até o portal da
-- primeira ilha (ela fala 'entre aqui' e aparece do outro lado te esperando). Na ilha mata 3 cachorros, completou o
-- tutorial e ganha nível e dinheiro").
-- Tudo aqui é do CLIENTE (cada jogador vê a sua guia e o seu cachorro seguindo): a guia anda, acena, conversa e bate
-- palmas (Shared/VillageFolk); o cachorro que segue é o DogBuilder animado pelo Animator.
-- 👑 (2026-10-23, o dono: "a pessoa do tutorial vai ser eu") a guia é o AVATAR DO DONO do jogo, com o nome dele: molde
-- "Guide" que o servidor monta primeiro de tudo (Services/VillageStars; Config.VILLAGE_PEOPLE.Guide). Sem molde, é a
-- Lily de blocos. O 🎓 professor é o avatar de um AMIGO do dono (o retrato da conversa copia o avatar do palco).
-- O que vale de verdade (fase, cachorros derrotados, prêmio) fica no servidor: Services/TutorialService.
-- Fases (data.Guide): 1-2 sem cachorro (guia → professor → cena dos cachorros → ESCOLHE 1 de 3) · 3 loja de coleiras
-- (pacote GRÁTIS) e portal da Arena · 4 até o portal da 🌻 Puppy Meadows · 5 luta na ilha (Config.TUTORIAL.Kills
-- selvagens + Config.TUTORIAL.Catches capturados com coleira) → prêmio.
-- 🦮 (2026-10-25, pedido do dono: "faz uma loja de coleira em Pawville, e faz o tutorial passar lá antes e a primeira que
-- a pessoa comprar vai ser grátis") cachorro novo agora é CAPTURADO (Systems/Catch); a roleta virou extra (1 giro grátis
-- por dia + giros comprados).
-- Começa depois do ▶ PLAY da tela de entrada (UI/Title). "skip" pula tudo (o jogador com cachorro vira o cachorro).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogBuilder = require(ReplicatedStorage.Shared.DogBuilder)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Islands = require(ReplicatedStorage.Shared.Islands)
local Village = require(ReplicatedStorage.Shared.Village)
local VillageFolk = require(ReplicatedStorage.Shared.VillageFolk)
local Client = script.Parent.Parent
local UI = Client:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Title = require(UI:WaitForChild("Title"))
local Net = require(Client:WaitForChild("Net"))
local Animator = require(Client:WaitForChild("Animator"))
local C = Kit.C
local make = Kit.make
local LUCKY = Enum.Font.LuckiestGuy

local GuideTour = {}

local player = Players.LocalPlayer
local DONE = 99
local GUIDE = (Config.TUTORIAL and Config.TUTORIAL.Guide) or "Lily"
local KILLS = (Config.TUTORIAL and Config.TUTORIAL.Kills) or 3
local CATCHES = (Config.TUTORIAL and Config.TUTORIAL.Catches) or 0
local PROF = Config.STARTER_ROLL.Professor
local GUIDE_COLOR = Color3.fromRGB(255, 150, 60)
local PROF_COLOR = Color3.fromRGB(110, 170, 240)
local SKIP = {} -- (erro de mentirinha que sai do roteiro quando o jogador pula)
local HUD_TOAST: (string) -> () = function(_text) end
local HUD_REF: any = nil
local TAU = math.pi * 2

-- caminhos da guia na 🏡 Pawville (coordenadas LOCAIS da vila: Shared/Village)
local TO_PROF = { { 0, 42 }, { 0, 28 }, { 0, 18 }, { -10, 10 } }
local TO_ARENA = { { -10, 18 }, { 0, 30 }, { 0, 50 }, { 22, 76 }, { 27, 98 }, { 22, 120 }, { 0, 136 }, { 0, 200 }, { 0, 262 }, { 11, 284 } }
local TO_MEADOWS = { { 2, 270 }, { -16, 264 }, { -46, 270 } }
-- 🦮 do canil até a loja de coleiras (barraquinha da esquerda da praça) e de lá até a rua principal
local TO_LEASH = { { -10, 18 }, { 0, 30 }, { 0, 50 }, { -22, 76 }, { -27, 98 }, { -42, 110 }, { -52, 116 } }
local LEASH_TO_ARENA = { { -42, 110 }, { -27, 98 }, { -22, 120 }, { 0, 136 }, { 0, 200 }, { 0, 262 }, { 11, 284 } }

---------------------------------------------------------------- utilidades
local function sfx(name: string, opts: any?)
	local module = script.Parent:FindFirstChild("Sfx")
	if module then
		pcall(function()
			require(module).Play(name, nil, opts)
		end)
	end
end

-- 🔊 som no mundo (sai do lugar: palmas da guia) · 🐶 voz de um cachorro (latido pelo tamanho)
local function sfxAt(name: string, where: any, opts: any?)
	local module = script.Parent:FindFirstChild("Sfx")
	if module then
		pcall(function()
			require(module).Play(name, where, opts)
		end)
	end
end
local function dogVoice(model: Instance?, kind: string?)
	local module = script.Parent:FindFirstChild("Sfx")
	if module and model then
		pcall(function()
			require(module).Voice(model, kind, { Volume = 0.6 })
		end)
	end
end

local function send(action: string, value: any?)
	local remote = Net.Remotes:FindFirstChild("TutorialAction")
	if remote then
		remote:FireServer(action, value)
	end
end

local function started(): boolean
	local p = Net.Profile
	return p ~= nil and p.Started == true
end

local function myRoot(): BasePart?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root or nil
end

-- o personagem já é o cachorro? (o cachorro do jogador tem Kind = "player")
local function isDog(): boolean
	local char = player.Character
	return char ~= nil and char:GetAttribute("Kind") == "player"
end

local function island(): string?
	return player:GetAttribute("Island")
end

local function touch(): boolean
	return Kit.IsTouch() or Kit.IsGamepad()
end

local function controls(on: boolean)
	pcall(function()
		local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
		local c = module and (require(module :: any) :: any):GetControls()
		if c then
			if on and not player:GetAttribute("AutoControl") then
				c:Enable()
			elseif not on then
				c:Disable()
			end
		end
	end)
end

local function approach(cur: number, goal: number, rate: number, dt: number): number
	return cur + (goal - cur) * math.min(1, rate * dt)
end
local function angleTo(cur: number, goal: number, rate: number, dt: number): number
	local d = (goal - cur + math.pi) % TAU - math.pi
	return cur + d * math.min(1, rate * dt)
end
local function yawOf(dx: number, dz: number): number
	return math.atan2(-dx, -dz)
end
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end
local function smooth(u: number): number
	return u * u * (3 - 2 * u)
end

-- ponto local da vila → mundo (na altura das ruas)
local function V(x: number, z: number): Vector3
	return Village.ToWorld(x, Village.GROUND_Y, z)
end

---------------------------------------------------------------- chão (raio que ignora gente, cachorros e a guia)
local folder = Instance.new("Folder")
folder.Name = "GuiaTutorial"
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
-- (2026-10-23, o dono: "ela está andando na água") o raio da GUIA atravessa a água e acha o fundo: fundo abaixo do mar
-- = água, ela não pisa lá
local landParams = RaycastParams.new()
landParams.FilterType = Enum.RaycastFilterType.Exclude
landParams.IgnoreWater = true
local WATER_Y = -1.5 -- (o mar fica em −2)
local nextFilter = 0
local function refreshFilter()
	local list: { Instance } = { folder }
	for _, name in ipairs({ "Cachorros", "VidaDaVila", "ChaoXadrez" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	rayParams.FilterDescendantsInstances = list
	landParams.FilterDescendantsInstances = list
end
local function groundY(pos: Vector3, up: number?): number?
	if os.clock() > nextFilter then
		nextFilter = os.clock() + 1
		refreshFilter()
	end
	local hit = workspace:Raycast(pos + Vector3.new(0, up or 10, 0), Vector3.new(0, -((up or 10) + 60), 0), rayParams)
	return hit and hit.Position.Y or nil
end

-- altura do chão de TERRA no ponto; nil = água (ou nada embaixo)
local function landY(pos: Vector3, up: number?): number?
	if os.clock() > nextFilter then
		nextFilter = os.clock() + 1
		refreshFilter()
	end
	local u = up or 10
	local hit = workspace:Raycast(pos + Vector3.new(0, u, 0), Vector3.new(0, -(u + 90), 0), landParams)
	if hit and hit.Position.Y > WATER_Y then
		return hit.Position.Y
	end
	return nil
end

-- o ponto de terra mais perto (anéis em volta); nil = só água por perto
local function nearestLand(pos: Vector3, maxR: number?): Vector3?
	local y = landY(pos, 12)
	if y then
		return Vector3.new(pos.X, y, pos.Z)
	end
	for r = 4, maxR or 40, 6 do
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			local p = pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local yy = landY(p, 12)
			if yy then
				return Vector3.new(p.X, yy, p.Z)
			end
		end
	end
	return nil
end

---------------------------------------------------------------- ✨ efeitos no mundo
-- "puf": estrelinhas de blocos saindo de um ponto (aparecer/sumir/virar cachorro)
local function poof(pos: Vector3, color: Color3?)
	sfx("Poof")
	for i = 1, 14 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Size = Vector3.new(0.6, 0.6, 0.6)
		p.Color = (color or C.Gold):Lerp(Color3.new(1, 1, 1), math.random() * 0.5)
		p.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
		p.Parent = folder
		local a = (i / 14) * TAU
		local dir = Vector3.new(math.cos(a), 0.5 + math.random() * 0.8, math.sin(a))
		Kit.Tween(p, 0.6, { CFrame = CFrame.new(pos + Vector3.new(0, 2, 0) + dir * (5 + math.random() * 3)) * CFrame.Angles(math.random() * 3, math.random() * 3, 0), Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1 })
		task.delay(0.65, function()
			p:Destroy()
		end)
	end
end

---------------------------------------------------------------- 🧑 a GUIA
-- 👑 o avatar do dono do jogo (molde "Guide" do servidor, em ReplicatedStorage.VillageStars) — nil enquanto não chega
local function guideTemplate(): Model?
	local f = ReplicatedStorage:FindFirstChild("VillageStars")
	local m = f and f:FindFirstChild("Guide")
	return (m and m:IsA("Model")) and m or nil
end
-- o servidor desistiu do molde (Studio sem internet, Config "-"): a guia é a Lily de blocos
local function guideTemplateGone(): boolean
	local f = ReplicatedStorage:FindFirstChild("VillageStars")
	return f ~= nil and f:GetAttribute("GuideState") == "none"
end
local function guideName(): string
	local m = guideTemplate()
	local n = m and m:GetAttribute("DisplayName")
	return (type(n) == "string" and n ~= "") and n or GUIDE
end
local function guideIsOwner(): boolean
	local m = guideTemplate()
	return m ~= nil and m:GetAttribute("IsOwner") == true
end
-- "I'm X, your guide!" — o dono se apresenta como quem fez o jogo
local function introLine(): string
	if guideIsOwner() then
		return "I'm " .. guideName() .. ", the CREATOR of this game! 👑 And today I'm YOUR guide!"
	end
	return "I'm " .. guideName() .. ", your guide!"
end

-- (sem o molde: a Lily, bonequinho de blocos)
local function guideOutfit()
	return {
		Skin = Color3.fromRGB(244, 198, 156),
		Hair = Color3.fromRGB(196, 92, 50),
		HairStyle = "ponytail",
		Shirt = GUIDE_COLOR,
		ShirtStyle = "jacket",
		Accent = Color3.fromRGB(255, 255, 255),
		Pants = Color3.fromRGB(56, 80, 150),
		Shorts = false,
		Shoes = Color3.fromRGB(240, 240, 242),
		Hat = "cap",
		HatColor = Color3.fromRGB(60, 150, 90),
		Blush = true,
		Paw = true,
		Backpack = true,
	}
end

local guide: any = nil -- { Rig, Pos, Y, Ry, Phase, W, Path, PathI, Speed, Mode, Tag, Mark, ... }

local function removeGuide(withPoof: boolean?)
	if guide then
		if withPoof then
			poof(guide.Pos, GUIDE_COLOR)
		end
		guide.Rig.Model:Destroy()
		if guide.Tag then
			guide.Tag:Destroy()
		end
		if guide.Bubble then
			guide.Bubble:Destroy()
		end
		guide = nil
	end
end

local function spawnGuide(pos: Vector3, faceTo: Vector3?, withPoof: boolean?)
	removeGuide(false)
	folder.Parent = workspace
	-- (nunca em cima da água: procura a terra mais perto; senão, do lado do jogador)
	local land = nearestLand(pos)
	if not land and faceTo then
		land = nearestLand(faceTo, 12)
	end
	if land then
		pos = land
	end
	local y = landY(pos) or groundY(pos) or pos.Y
	local ry = 0
	if faceTo then
		local d = flat(faceTo - pos)
		if d.Magnitude > 0.1 then
			ry = yawOf(d.X, d.Z)
		end
	end
	local cf = CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, ry, 0)
	local rig = nil
	local template = guideTemplate()
	if template then
		local ok, r = pcall(VillageFolk.FromAvatar, template, folder, cf)
		if ok and r then
			rig = r
		end
	end
	if not rig then
		rig = VillageFolk.Build(folder, cf, guideOutfit(), 1.05)
	end
	rig.Model.Name = "Guia_" .. guideName()
	-- plaquinha com o nome + ❗ quando ela quer falar / espera o jogador
	local tag = make("BillboardGui", {
		Name = "GuiaTag",
		Adornee = rig.Head,
		Size = UDim2.fromOffset(200, 74),
		StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0),
		LightInfluence = 0,
		MaxDistance = 260,
		AlwaysOnTop = true,
		ResetOnSpawn = false,
	}, player:WaitForChild("PlayerGui"))
	local mark = Kit.Text(tag, { Size = UDim2.new(1, 0, 0, 30), Text = "❗", TextColor3 = C.Gold, Visible = false })
	local name = Kit.Text(tag, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 26), Text = "🧭 " .. string.upper(guideName()), TextColor3 = GUIDE_COLOR })
	Kit.Thick(name, 3)
	Kit.Text(tag, { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 18), Text = guideIsOwner() and "YOUR GUIDE · 👑 GAME CREATOR" or "YOUR GUIDE", TextColor3 = C.Text })
	guide = {
		Rig = rig,
		Pos = Vector3.new(pos.X, y, pos.Z),
		Y = y,
		GroundY = y,
		Ry = ry,
		Phase = 0,
		W = { Walk = 0, Run = 0, Wave = 0, Talk = 0, Clap = 0 },
		Speed = 15,
		Tag = tag,
		Mark = mark,
		Wave = 0, -- até quando acena
		Clap = 0, -- até quando bate palmas
		NextClapSound = 0, -- (som das palmas)
		Talking = false,
		Waiting = false,
		NextRay = 0,
	}
	if withPoof then
		poof(pos, GUIDE_COLOR)
	end
end

-- balãozinho de fala em cima da cabeça (frases curtas enquanto o jogador luta/anda)
local function bubble(text: string, seconds: number?)
	if not guide then
		return
	end
	if guide.Bubble then
		guide.Bubble:Destroy()
	end
	local gui = make("BillboardGui", {
		Name = "Fala",
		Adornee = guide.Rig.Head,
		Size = UDim2.fromOffset(250, 50),
		StudsOffsetWorldSpace = Vector3.new(0, 5.4, 0),
		LightInfluence = 0,
		MaxDistance = 160,
		AlwaysOnTop = true,
		ResetOnSpawn = false,
	}, player:WaitForChild("PlayerGui"))
	local frame = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, gui)
	Kit.Corner(frame, 14)
	Kit.Stroke(frame, Color3.fromRGB(40, 34, 50), 2)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Font = Kit.Font,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(40, 34, 50),
		Text = text,
	}, frame)
	local scale = make("UIScale", { Scale = 0.4 }, frame)
	Kit.Tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	guide.Bubble = gui
	task.delay(seconds or 3.2, function()
		if guide and guide.Bubble == gui then
			guide.Bubble = nil
		end
		gui:Destroy()
	end)
end

-- anda pelo caminho (pontos no mundo); waitPlayer = para e espera quando o jogador fica para trás
local function walkGuide(points: { Vector3 }, waitPlayer: boolean?, speed: number?)
	if not guide then
		return
	end
	guide.Path = points
	guide.PathI = 1
	guide.WaitPlayer = waitPlayer
	guide.Speed = speed or 15
end

local WAIT_DIST = 24
local function updateGuide(dt: number, now: number)
	local g = guide
	if not g then
		return
	end
	local root = myRoot()
	local moving = false
	local toPlayer = root and flat(root.Position - g.Pos) or nil
	local dist = toPlayer and toPlayer.Magnitude or 0
	-- ✨ "puf" até o ponto (outra ilha / o caminho passa pelo mar): ela nunca atravessa a água andando
	local function hop(target: Vector3)
		local land = nearestLand(target) or target
		poof(g.Pos, GUIDE_COLOR)
		g.Pos = land
		g.Y, g.GroundY = land.Y, land.Y
		g.Blocked = 0
		poof(land, GUIDE_COLOR)
	end
	if g.Path then
		g.Waiting = g.WaitPlayer and dist > WAIT_DIST
		if not g.Waiting then
			local target = g.Path[g.PathI]
			local d = flat(target - g.Pos)
			local step = g.Speed * dt
			if d.Magnitude > 300 then
				hop(target)
				g.PathI += 1
			elseif d.Magnitude <= step + 0.05 then
				g.Pos = Vector3.new(target.X, g.Pos.Y, target.Z)
				g.PathI += 1
			else
				local nextPos = g.Pos + d.Unit * step
				local y = landY(nextPos, 8)
				if y then
					g.Pos = nextPos
					g.GroundY = y
					g.Blocked = 0
					g.Ry = angleTo(g.Ry, yawOf(d.X, d.Z), 8, dt)
					moving = true
				else
					-- água na frente: espera um instante e aparece do outro lado
					g.Blocked = (g.Blocked or 0) + dt
					if g.Blocked > 0.8 then
						hop(target)
						g.PathI += 1
					end
				end
			end
			if g.PathI > #g.Path then
				g.Path = nil
				if g.OnArrive then
					local fn = g.OnArrive
					g.OnArrive = nil
					task.spawn(fn)
				end
			end
		end
	elseif g.Follow and root then
		-- acompanha o jogador de longe (na luta): fica a ~12 studs, corre se ficar longe — SÓ em terra (com o jogador
		-- na beira, "atrás" pode ser o mar: tenta os outros lados)
		if now > (g.NextWant or 0) then
			g.NextWant = now + 0.3
			local look, right = root.CFrame.LookVector, root.CFrame.RightVector
			g.Want = nil
			for _, off in ipairs({ -look * 9 + right * 7, -look * 9 - right * 7, right * 10, -right * 10, look * 8 + right * 6 }) do
				local p = root.Position + off
				if landY(p, 8) then
					g.Want = p
					break
				end
			end
		end
		local want = g.Want
		if want then
			local d = flat(want - g.Pos)
			if d.Magnitude > 90 then
				hop(want)
			elseif d.Magnitude > 6 then
				local speed = math.clamp(d.Magnitude * 1.4, 8, 30)
				local nextPos = g.Pos + d.Unit * math.min(d.Magnitude, speed * dt)
				local y = landY(nextPos, 8)
				if y then
					g.Pos = nextPos
					g.GroundY = y
					g.Ry = angleTo(g.Ry, yawOf(d.X, d.Z), 8, dt)
					moving = true
					g.Speed = speed
				end
			end
		end
	end
	if not moving and toPlayer and dist > 0.5 and dist < 80 then
		-- parada: olha para o jogador (o corpo vira devagar)
		g.Ry = angleTo(g.Ry, yawOf(toPlayer.X, toPlayer.Z), 4, dt)
	end
	-- chão (raio de vez em quando; a altura muda suave)
	if now > g.NextRay then
		g.NextRay = now + 0.1
		local y = landY(g.Pos, 8)
		if y then
			g.GroundY = y
		end
	end
	g.Y = approach(g.Y, g.GroundY, 14, dt)
	g.Pos = Vector3.new(g.Pos.X, g.Y, g.Pos.Z)
	-- pose
	local w = g.W
	local fast = moving and g.Speed > 17
	w.Walk = approach(w.Walk, (moving and not fast) and 1 or 0, 8, dt)
	w.Run = approach(w.Run, fast and 1 or 0, 8, dt)
	w.Wave = approach(w.Wave, (now < g.Wave or g.Waiting) and 1 or 0, 6, dt)
	w.Clap = approach(w.Clap, (now < g.Clap) and 1 or 0, 6, dt)
	-- 👏 o som das palmas (no ritmo da animação)
	if now < g.Clap and now >= (g.NextClapSound or 0) then
		g.NextClapSound = now + 0.3
		sfxAt("Clap", g.Pos + Vector3.new(0, 3, 0), { Volume = 0.4, Gap = 0.2 })
	end
	w.Talk = approach(w.Talk, (g.Talking and now >= g.Wave and now >= g.Clap) and 1 or 0, 5, dt)
	if moving then
		g.Phase += dt * g.Speed * (fast and 1.05 or 1.3)
	end
	local st = { Walk = w.Walk, Run = w.Run, Phase = g.Phase, Wave = w.Wave, Talk = w.Talk, Clap = w.Clap }
	if toPlayer and not moving and dist < 40 and dist > 0.5 then
		local rel = (CFrame.Angles(0, g.Ry, 0)):VectorToObjectSpace(toPlayer.Unit)
		st.LookYaw = math.clamp(math.atan2(-rel.X, -rel.Z), -0.9, 0.9)
	end
	local s = g.Rig.Scale
	g.Rig.Root.CFrame = CFrame.new(g.Pos.X, g.Y + 3 * s, g.Pos.Z) * CFrame.Angles(0, g.Ry, 0)
	VillageFolk.Pose(g.Rig, now, st)
	if g.Mark then
		g.Mark.Visible = g.Waiting or g.WantTalk == true
		g.Mark.Position = UDim2.fromOffset(0, -math.abs(math.sin(now * 4)) * 8)
	end
end


---------------------------------------------------------------- 🐶 o cachorro que SEGUE o jogador (ainda pessoa)
local pet: any = nil -- { Model, Root, Lift, Pos, Ry, Ground, Idle, Name, Tag }

local function removePet(withPoof: boolean?)
	if pet then
		if withPoof then
			poof(pet.Pos, C.Pink)
		end
		Animator.Untrack(pet.Model)
		pet.Model:Destroy()
		if pet.Tag then
			pet.Tag:Destroy()
		end
		pet = nil
	end
end

local function spawnPet(species: string, name: string, at: Vector3)
	removePet(false)
	local ok, model = pcall(DogBuilder.Build, species, { scale = DogData.GameScale(species) })
	if not (ok and model) then
		return
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		elseif d:IsA("Humanoid") then
			d:Destroy()
		end
	end
	local root = model.PrimaryPart
	root.Anchored = true
	local hip = model:GetAttribute("HipHeight") or 2
	local y = groundY(at) or at.Y
	pet = {
		Model = model,
		Root = root,
		Lift = hip + root.Size.Y / 2,
		Pos = Vector3.new(at.X, y, at.Z),
		Ground = y,
		Ry = 0,
		Idle = 0,
		NextRay = 0,
		NextTrick = os.clock() + 4,
		Name = name,
		Hop = 0,
	}
	root.CFrame = CFrame.new(at.X, y + pet.Lift, at.Z)
	folder.Parent = workspace
	model.Parent = folder
	Animator.Track(model)
	local tag = make("BillboardGui", {
		Name = "PetTag",
		Adornee = root,
		Size = UDim2.fromOffset(180, 30),
		StudsOffsetWorldSpace = Vector3.new(0, root.Size.Y / 2 + hip + 1.6, 0),
		LightInfluence = 0,
		MaxDistance = 120,
		ResetOnSpawn = false,
	}, player:WaitForChild("PlayerGui"))
	Kit.Text(tag, { Size = UDim2.fromScale(1, 1), Text = "🐶 " .. name, TextColor3 = C.Pink })
	pet.Tag = tag
	poof(pet.Pos, C.Pink)
	model:SetAttribute("Action", "Victory")
	task.delay(0.35, dogVoice, model, "bark")
	task.delay(1.2, function()
		if pet and pet.Model == model then
			model:SetAttribute("Action", nil)
		end
	end)
end

local function updatePet(dt: number, now: number)
	local p = pet
	if not p then
		return
	end
	if isDog() then
		-- virou o cachorro: o que seguia "entra" no jogador
		removePet(true)
		return
	end
	local root = myRoot()
	if not root then
		return
	end
	local want = root.Position - root.CFrame.LookVector * 4.5 + root.CFrame.RightVector * 2.8
	local d = flat(want - p.Pos)
	local moving = false
	if d.Magnitude > 70 then
		-- o jogador passou num portal / caiu: o cachorro aparece do lado dele
		p.Pos = Vector3.new(want.X, root.Position.Y, want.Z)
		p.Ground = groundY(p.Pos, 6) or root.Position.Y - 3
		poof(p.Pos, C.Pink)
	elseif d.Magnitude > 1.2 then
		local speed = math.clamp(d.Magnitude * 2.8, 4, 30)
		p.Pos += d.Unit * math.min(d.Magnitude, speed * dt)
		p.Ry = angleTo(p.Ry, yawOf(d.X, d.Z), 9, dt)
		moving = true
	end
	if moving then
		p.Idle = 0
		if p.Model:GetAttribute("Action") == "Sit" then
			p.Model:SetAttribute("Action", nil)
		end
	else
		p.Idle += dt
		local look = flat(root.CFrame.LookVector)
		if look.Magnitude > 0.1 then
			p.Ry = angleTo(p.Ry, yawOf(look.X, look.Z), 2, dt)
		end
		if p.Idle > 2.5 and p.Model:GetAttribute("Action") == nil then
			p.Model:SetAttribute("Action", "Sit")
		end
		-- de vez em quando um truque (rebola, late, pula)
		if now > p.NextTrick and p.Idle > 1 then
			p.NextTrick = now + math.random(6, 11)
			local trick = ({ "Wiggle", "Bark", "Bounce", "Twirl" })[math.random(1, 4)]
			p.Model:SetAttribute("Action", trick)
			task.delay(1.4, function()
				if pet == p and p.Model:GetAttribute("Action") == trick then
					p.Model:SetAttribute("Action", nil)
				end
			end)
		end
	end
	if now > p.NextRay then
		p.NextRay = now + 0.12
		local y = landY(p.Pos, 6)
		if y then
			p.Ground = y
		else
			-- 🌊 na água ele NADA: metade do corpo para baixo da superfície (não anda por cima do mar)
			p.Ground = WATER_Y - 0.5 - p.Lift * 0.55
		end
	end
	p.Root.CFrame = CFrame.new(p.Pos.X, p.Ground + p.Lift, p.Pos.Z) * CFrame.Angles(0, p.Ry, 0)
end

---------------------------------------------------------------- tela: diálogo, objetivo, prêmio, faixas de cinema
local ui: any = nil
local goalOffset = 112

local function abilityGap(): number
	return Kit.IsTouch() and 132 or 112
end

local function buildUI()
	local gui, root = Kit.Screen("GuideTour", 34) -- (a roleta é 48, o ovo 40, os cartões do guia 35)
	local u: any = { Gui = gui, Root = root }

	-- 🎬 faixas pretas de cinema (cena dos cachorros)
	u.Bars = {}
	for _, top in ipairs({ true, false }) do
		local bar = make("Frame", {
			AnchorPoint = Vector2.new(0, top and 0 or 1),
			Position = UDim2.fromScale(0, top and 0 or 1),
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = 1,
		}, gui)
		table.insert(u.Bars, bar)
	end

	-- 💬 caixa de diálogo
	local panel = Kit.Panel(root, {
		Name = "Dialogo",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -abilityGap()),
		Size = UDim2.fromOffset(800, 158),
		Visible = false,
		ZIndex = 3,
	})
	local portraitFrame = make("Frame", {
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.fromOffset(130, 130),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, panel)
	Kit.Corner(portraitFrame, 65)
	local portraitStroke = Kit.Stroke(portraitFrame, GUIDE_COLOR, 4)
	local portraitGrad = Kit.Gradient(portraitFrame, Color3.fromRGB(255, 230, 190), Color3.fromRGB(255, 170, 110))
	local vp = make("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(180, 175, 195),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.3, -0.6, -1),
		ZIndex = 5,
	}, portraitFrame)
	Kit.Corner(vp, 65)
	local vpCam = make("Camera", { FieldOfView = 26 }, vp)
	vp.CurrentCamera = vpCam
	local world = make("WorldModel", {}, vp)
	local portraitScale = make("UIScale", {}, portraitFrame)
	local nameChip, nameLabel = Kit.Chip(panel, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(160, 0),
		Size = UDim2.fromOffset(250, 40),
		ZIndex = 6,
	}, GUIDE_COLOR, string.upper(GUIDE))
	nameLabel.Font = LUCKY
	local text = Kit.Text(panel, {
		Position = UDim2.fromOffset(164, 26),
		Size = UDim2.fromOffset(612, 104),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 4,
	})
	make("UITextSizeConstraint", { MaxTextSize = 30 }, text)
	local hint = Kit.Text(panel, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -8),
		Size = UDim2.fromOffset(170, 24),
		Text = touch() and "▶ TAP" or "▶ CLICK / SPACE",
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 4,
	})
	local click = make("TextButton", {
		Name = "Avancar",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 7,
	}, panel)
	local choice = Kit.Button(panel, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, 28),
		Size = UDim2.fromOffset(320, 66),
		Text = "",
		Visible = false,
		ZIndex = 9,
	}, C.Green)
	local skip = Kit.Button(panel, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0, 0),
		Size = UDim2.fromOffset(170, 34),
		Text = "skip tutorial ✕",
		ZIndex = 8,
	}, C.Panel2)

	-- 🎯 objetivo (em cima do diálogo / da barra de golpes)
	local goal = Kit.Panel(root, {
		Name = "Objetivo",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -abilityGap()),
		Size = UDim2.fromOffset(560, 58),
		Visible = false,
		ZIndex = 3,
	})
	local goalIcon = Kit.Text(goal, { Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(46, 46), Text = "🎯", ZIndex = 4 })
	local goalText = Kit.Text(goal, {
		Position = UDim2.fromOffset(62, 8),
		Size = UDim2.new(1, -150, 0, 42),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	local goalCount = Kit.Text(goal, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(80, 40),
		Text = "",
		TextColor3 = C.Cash,
		ZIndex = 4,
	})
	Kit.Thick(goalCount, 3)
	local goalBar = make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 62, 1, -5),
		Size = UDim2.new(1, -150, 0, 6),
		BackgroundColor3 = C.Dark,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 4,
	}, goal)
	Kit.Corner(goalBar, 3)
	local goalFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Cash, BorderSizePixel = 0, ZIndex = 5 }, goalBar)
	Kit.Corner(goalFill, 3)

	-- 🎉 prêmio
	local reward = Kit.Panel(root, {
		Name = "Premio",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(540, 330),
		Visible = false,
		ZIndex = 10,
	})
	-- (os raios ficam ATRÁS do quadro: filho desenha por cima do pai, então são irmãos dele)
	local rays = Kit.Rays(root, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(900, 900), ZIndex = 9, Visible = false }, C.Gold, 14)
	local rTitle = Kit.Text(reward, {
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -40, 0, 58),
		Text = "🎉 TUTORIAL COMPLETE!",
		TextColor3 = C.Gold,
		Font = LUCKY,
		ZIndex = 11,
	})
	Kit.Thick(rTitle, 4)
	local rows = {}
	for i = 1, 3 do
		local row = Kit.Box(reward, { Position = UDim2.fromOffset(30, 80 + (i - 1) * 58), Size = UDim2.new(1, -60, 0, 50), ZIndex = 11 }, C.Panel2)
		local label = Kit.Text(row, { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 1, -12), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 })
		rows[i] = { Box = row, Label = label }
	end
	local rOk = Kit.Button(reward, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(240, 58),
		Text = "AWESOME! ✔",
		ZIndex = 12,
	}, C.Green)

	u.Panel, u.Portrait, u.PortraitStroke, u.PortraitGrad, u.Viewport, u.VpCam, u.World = panel, portraitFrame, portraitStroke, portraitGrad, vp, vpCam, world
	u.PortraitScale, u.NameChip, u.NameLabel, u.Text, u.Hint, u.Click, u.Choice, u.Skip = portraitScale, nameChip, nameLabel, text, hint, click, choice, skip
	u.Goal, u.GoalIcon, u.GoalText, u.GoalCount, u.GoalBar, u.GoalFill = goal, goalIcon, goalText, goalCount, goalBar, goalFill
	u.Reward, u.Rays, u.Rows, u.RewardOk = reward, rays, rows, rOk
	return u
end

---------------------------------------------------------------- 🖼️ retrato de quem fala (3D, mexendo a cabeça)
local portraits = {} -- ["quem:userId"] = rig dentro do ViewportFrame
local portraitRig: any = nil

-- o 🎓 professor do palco quando ele é um avatar de verdade (um amigo do dono — Services/VillageStars)
local function professorAvatar(): Model?
	for _, m in ipairs(CollectionService:GetTagged("VillageFolk")) do
		if m:IsDescendantOf(workspace) and m:GetAttribute("Role") == "Professor" and m:FindFirstChild("LowerTorso") then
			return m
		end
	end
	return nil
end

-- retrato: o avatar de verdade (a guia = o dono; o professor = o amigo do palco) ou o boneco de blocos
local function portraitOf(who: string)
	local source = if who == "prof" then professorAvatar() else guideTemplate()
	local key = who .. ":" .. tostring(source and source:GetAttribute("UserId") or "blocos")
	local rig = portraits[key]
	if rig then
		return rig, key
	end
	if source then
		local ok, r = pcall(VillageFolk.FromAvatar, source, ui.World, CFrame.new())
		if ok and r then
			rig = r
		end
	end
	if not rig then
		local outfit = who == "prof" and VillageFolk.ProfessorOutfit() or guideOutfit()
		rig = VillageFolk.Build(ui.World, CFrame.new(0, 0, 0), outfit, 1)
	end
	portraits[key] = rig
	return rig, key
end

local function showPortrait(who: string)
	local rig, key = portraitOf(who)
	for k, r in pairs(portraits) do
		r.Model.Parent = k == key and ui.World or nil
	end
	portraitRig = rig
	-- (avatar: a cabeça pelas juntas — o molde chega com as peças fora do lugar até o mundo montar)
	local headPos = rig.HeadRel and (rig.Root.CFrame * rig.HeadRel).Position or rig.Head.Position
	-- (avatar: um pouco mais longe e mirando mais alto — cabelo e chapéu do Roblox não ficam cortados)
	local back, lift = 5.6, 0.05
	if rig.Avatar then
		back, lift = 5.4, 0.2
	end
	ui.VpCam.CFrame = CFrame.lookAt(headPos + Vector3.new(0.4, 0.3 + lift, -back), headPos + Vector3.new(0, lift, 0))
	local color = who == "prof" and PROF_COLOR or GUIDE_COLOR
	ui.PortraitStroke.Color = color
	ui.PortraitGrad.Color = who == "prof" and ColorSequence.new(Color3.fromRGB(210, 230, 255), Color3.fromRGB(140, 180, 240))
		or ColorSequence.new(Color3.fromRGB(255, 230, 190), Color3.fromRGB(255, 170, 110))
	ui.NameChip.BackgroundColor3 = color
	ui.NameLabel.Text = who == "prof" and string.upper(PROF) or string.upper(guideName())
end

---------------------------------------------------------------- estado do passeio
local tour: any = nil -- { Cancelled, Clicked, Choice, Talking, Kills, Done, Reward, ... }

local function check()
	if not tour or tour.Cancelled then
		error(SKIP, 0)
	end
end

local function sleep(t: number)
	local t0 = os.clock()
	while os.clock() - t0 < t do
		check()
		task.wait()
	end
end

local function waitFor(cond: () -> boolean, timeout: number?): boolean
	local t0 = os.clock()
	while true do
		check()
		local ok, res = pcall(cond)
		if ok and res then
			return true
		end
		if timeout and os.clock() - t0 > timeout then
			return false
		end
		task.wait(0.1)
	end
end

local function waitGuideArrived(orWhen: (() -> boolean)?)
	local t0 = os.clock()
	while guide and guide.Path do
		check()
		if orWhen and orWhen() then
			return
		end
		task.wait(0.1)
		if os.clock() - t0 > 240 then
			break
		end
	end
end

-- telas cheias (roleta, chocar ovo, cartões do guia): o diálogo some enquanto elas estão abertas
local function blocked(): boolean
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return false
	end
	for _, name in ipairs({ "StarterRoll", "Hatch", "Tutorial" }) do
		local g = pg:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled then
			return true
		end
	end
	return false
end

-- 🎯 objetivo: texto, ícone e (opcional) contagem
local function objective(icon: string?, text: string?, count: number?, goalN: number?)
	if not ui then
		return
	end
	if not text then
		ui.Goal.Visible = false
		return
	end
	local changed = ui.GoalText.Text ~= Kit.CleanText(text)
	ui.GoalIcon.Text = icon or "🎯"
	ui.GoalText.Text = text
	ui.GoalCount.Text = count and (math.min(count, goalN or count) .. "/" .. (goalN or count)) or ""
	ui.GoalBar.Visible = count ~= nil
	if count and goalN then
		Kit.Tween(ui.GoalFill, 0.35, { Size = UDim2.fromScale(math.clamp(count / goalN, 0, 1), 1) })
	end
	if changed or not ui.Goal.Visible then
		Kit.Pop(ui.Goal, true)
		sfx("Quest")
	end
end

-- 💬 fala: mostra a caixa e espera o clique (o 1º clique mostra o texto inteiro)
local function say(who: string, text: string, opts: any?)
	check()
	opts = opts or {}
	local speaker = (who == "prof") and "prof" or "guide"
	ui.Panel.Visible = true
	showPortrait(speaker)
	if ui.Panel:GetAttribute("Shown") ~= true then
		ui.Panel:SetAttribute("Shown", true)
		Kit.Pop(ui.Panel, true)
	end
	ui.Text.Text = text
	ui.Text.MaxVisibleGraphemes = 0
	ui.Hint.Visible = false
	ui.Choice.Visible = false
	ui.PortraitScale.Scale = 0.86
	Kit.Tween(ui.PortraitScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	if guide then
		guide.Talking = speaker == "guide"
		guide.WantTalk = false
		if opts.Wave then
			guide.Wave = os.clock() + 1.6
		elseif opts.Clap then
			guide.Clap = os.clock() + 1.8
		end
	end
	tour.Speaker = speaker
	tour.Clicked = false
	-- máquina de escrever
	local total = utf8.len(text) or #text
	local shown = 0
	local t0 = os.clock()
	local blip = 0
	while shown < total do
		check()
		if tour.Clicked then
			tour.Clicked = false
			break
		end
		task.wait()
		shown = math.min(total, math.floor((os.clock() - t0) * 48))
		ui.Text.MaxVisibleGraphemes = shown
		if shown - blip >= 3 then
			blip = shown
			-- 🗨️ "voz" de bichinho (cada letra um blip, a guia mais fina, o professor mais grosso)
			sfx("Blip", { Volume = 0.2, Pitch = (speaker == "prof" and 0.78 or 1.22) * (0.93 + math.random() * 0.14), Gap = 0.04 })
		end
	end
	ui.Text.MaxVisibleGraphemes = -1
	if opts.Choice then
		-- botão grande (ex.: "🐶 BECOME REX!"): só ele continua
		ui.Choice.Text = opts.Choice
		ui.Choice.Visible = true
		Kit.Pop(ui.Choice, true)
		local stopPulse = Kit.Pulse(ui.Choice, 0.05, 0.9)
		tour.Choice = false
		while not tour.Choice do
			if not tour or tour.Cancelled then
				stopPulse()
			end
			check()
			task.wait()
		end
		stopPulse()
		ui.Choice.Visible = false
	elseif opts.Auto then
		sleep(opts.Auto)
	else
		ui.Hint.Visible = true
		tour.Clicked = false
		while not tour.Clicked do
			check()
			task.wait()
		end
	end
	tour.Clicked = false
	sfx("Click")
	if guide then
		guide.Talking = false
	end
end

local function hideDialog()
	if ui and ui.Panel.Visible then
		ui.Panel:SetAttribute("Shown", false)
		Kit.Pop(ui.Panel, false)
	end
end

---------------------------------------------------------------- 🎬 câmera de cinema (cachorros brincando)
local cam: any = nil -- { From, FromLook, To, ToLook, T0, Dur, Glide }
local hiddenGuis: { [ScreenGui]: boolean } = {}

local function cinema(on: boolean)
	for _, bar in ipairs(ui.Bars) do
		Kit.Tween(bar, 0.6, { Size = UDim2.new(1, 0, 0, on and 70 or 0) })
	end
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if on then
		controls(false)
		if pg then
			for _, g in ipairs(pg:GetChildren()) do
				if g:IsA("ScreenGui") and g.Enabled and g ~= ui.Gui and g.Name ~= "Fala" then
					hiddenGuis[g] = true
					g.Enabled = false
				end
			end
		end
	else
		for g in pairs(hiddenGuis) do
			if g.Parent then
				g.Enabled = true
			end
		end
		table.clear(hiddenGuis)
		controls(true)
	end
end

-- a câmera desliza até o começo do plano (Glide s) e depois anda devagar até o fim (Dur s)
local function shot(fromPos: Vector3, fromLook: Vector3, toPos: Vector3, toLook: Vector3, dur: number)
	local camera = workspace.CurrentCamera
	local cf = camera.CFrame
	cam = {
		Start = cf.Position,
		StartLook = cf.Position + cf.LookVector * 30,
		From = fromPos,
		FromLook = fromLook,
		To = toPos,
		ToLook = toLook,
		T0 = os.clock(),
		Glide = 1.1,
		Dur = dur,
	}
	RunService:UnbindFromRenderStep("GuideCam")
	RunService:BindToRenderStep("GuideCam", Enum.RenderPriority.Camera.Value + 20, function()
		local c = cam
		local camera2 = workspace.CurrentCamera
		if not (c and camera2) then
			return
		end
		camera2.CameraType = Enum.CameraType.Scriptable
		local t = os.clock() - c.T0
		local pos, look
		if t < c.Glide then
			local e = smooth(t / c.Glide)
			pos = c.Start:Lerp(c.From, e)
			look = c.StartLook:Lerp(c.FromLook, e)
		else
			local e = smooth(math.clamp((t - c.Glide) / c.Dur, 0, 1))
			pos = c.From:Lerp(c.To, e)
			look = c.FromLook:Lerp(c.ToLook, e)
		end
		camera2.CFrame = CFrame.lookAt(pos, look)
	end)
end

-- volta a câmera para trás do personagem (desliza e devolve o controle)
local function endShots()
	local root = myRoot()
	local camera = workspace.CurrentCamera
	if root and camera then
		local look = flat(root.CFrame.LookVector)
		look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
		local goal = root.Position - look * 14 + Vector3.new(0, 6, 0)
		shot(goal, root.Position + Vector3.new(0, 2, 0), goal, root.Position + Vector3.new(0, 2, 0), 0.01)
		cam.Glide = 0.9
		local t0 = os.clock()
		while os.clock() - t0 < 1 do
			task.wait()
		end
	end
	RunService:UnbindFromRenderStep("GuideCam")
	cam = nil
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

---------------------------------------------------------------- linha dourada e ⬇ no alvo
local guideLine: any = nil
local function buildLine()
	local anchor = make("Part", { Name = "GuiaLinha", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2) }, folder)
	local a1 = make("Attachment", {}, anchor)
	local beam = make("Beam", {
		Attachment1 = a1,
		Width0 = 1.3,
		Width1 = 1.3,
		FaceCamera = true,
		Color = ColorSequence.new(C.Gold),
		LightEmission = 1,
		Segments = 20,
		Enabled = false,
	}, anchor)
	local mark = make("BillboardGui", {
		Name = "GuiaAlvo",
		Size = UDim2.fromOffset(70, 70),
		StudsOffsetWorldSpace = Vector3.new(0, 5, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	local arrow = Kit.Text(mark, { Size = UDim2.fromScale(1, 1), Text = "⬇", TextColor3 = C.Gold })
	guideLine = { Anchor = anchor, Beam = beam, A0 = nil, Mark = mark, Arrow = arrow, Target = nil }
end

-- alvo: Vector3 (lugar) ou BasePart (segue a peça); markPart = onde vai a ⬇ (nil = sem seta)
local function pointTo(target: any, markPart: BasePart?)
	if not guideLine then
		buildLine()
	end
	guideLine.Target = target
	guideLine.Mark.Adornee = markPart
	guideLine.Mark.Enabled = markPart ~= nil
end

local function updateLine(now: number)
	local l = guideLine
	if not l then
		return
	end
	local root = myRoot()
	local target = l.Target
	local pos: Vector3? = nil
	if typeof(target) == "Vector3" then
		pos = target
	elseif typeof(target) == "Instance" and target:IsA("BasePart") and target:IsDescendantOf(workspace) then
		pos = target.Position
	elseif type(target) == "function" then
		local ok, res = pcall(target)
		if ok and typeof(res) == "Vector3" then
			pos = res
		end
	end
	if not (pos and root) or cam ~= nil or blocked() then
		l.Beam.Enabled = false
		l.Mark.Enabled = false
		return
	end
	if not l.A0 or l.A0.Parent ~= root then
		if l.A0 then
			l.A0:Destroy()
		end
		l.A0 = make("Attachment", { Name = "GuiaLinhaInicio", Position = Vector3.new(0, -1.6, 0) }, root)
		l.Beam.Attachment0 = l.A0
	end
	folder.Parent = workspace
	l.Anchor.Position = pos + Vector3.new(0, 0.4, 0)
	local d = flat(pos - root.Position).Magnitude
	l.Beam.Enabled = d > 16 and d < 1500
	l.Beam.Transparency = NumberSequence.new(0.25 + 0.2 * math.sin(now * 4))
	l.Mark.Enabled = l.Mark.Adornee ~= nil
	l.Arrow.Position = UDim2.fromOffset(0, -math.abs(math.sin(now * 4)) * 10)
end

local function guidePos(): Vector3?
	return guide and guide.Pos or nil
end

-- 🌀 portal que leva para `to` saindo de `from` (as peças "Swirl" com a tag IslandPortal)
local function portalSwirl(to: string, from: string?): BasePart?
	for _, part in ipairs(CollectionService:GetTagged("IslandPortal")) do
		if part:IsA("BasePart") and part:GetAttribute("PortalTo") == to and (from == nil or part:GetAttribute("PortalFrom") == from) and part:IsDescendantOf(workspace) then
			return part
		end
	end
	return nil
end

-- centro (no chão) e um ponto 14 studs na frente do arco de um portal
local function portalSpots(swirl: BasePart): (Vector3, Vector3)
	local cf = swirl:GetAttribute("PortalCF")
	if typeof(cf) ~= "CFrame" then
		cf = CFrame.new(swirl.Position.X, swirl.Position.Y - 20, swirl.Position.Z) * swirl.CFrame.Rotation
	end
	local center = (cf :: CFrame).Position
	local look = flat((cf :: CFrame).LookVector)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	return center, center + look * 14
end

-- 🌻 portal da Puppy Meadows na Praça dos Portais da ilha principal
local function plazaMeadowsPortal(): BasePart?
	local map = workspace:FindFirstChild("Map")
	local isle = map and map:FindFirstChild("IlhaPrincipal")
	local plaza = isle and isle:FindFirstChild("PracaPortais")
	local portal = plaza and plaza:FindFirstChild("Portal_common")
	local swirl = portal and portal:FindFirstChild("Swirl")
	return swirl and swirl:IsA("BasePart") and swirl or nil
end

-- cachorro selvagem mais perto (alvo da luta)
local function nearestWild(): BasePart?
	local f = workspace:FindFirstChild("Cachorros")
	local root = myRoot()
	if not (f and root) then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, m in ipairs(f:GetChildren()) do
		if m:GetAttribute("Kind") == "npc" and m.PrimaryPart and m:GetAttribute("Action") ~= "KO" then
			local d = (m.PrimaryPart.Position - root.Position).Magnitude
			if d < bestD and d < 400 then
				best, bestD = m.PrimaryPart, d
			end
		end
	end
	return best
end

---------------------------------------------------------------- 🎓 professor
local function professorPart(): BasePart?
	for _, prompt in ipairs(CollectionService:GetTagged("ProfessorPrompt")) do
		local part = prompt.Parent
		if part and part:IsA("BasePart") and part:IsDescendantOf(workspace) then
			return part
		end
	end
	return nil
end
local function profPos(): Vector3
	local part = professorPart()
	return part and part.Position or V(Village.PROFESSOR.X, Village.PROFESSOR.Z)
end
local function nearPlayer(pos: Vector3?, dist: number): boolean
	local root = myRoot()
	return pos ~= nil and root ~= nil and flat(root.Position - pos).Magnitude < dist
end
local function waitRoot(): BasePart
	local root = nil
	waitFor(function()
		root = myRoot()
		return root ~= nil
	end)
	return root :: BasePart
end

local function pathOf(list: { { number } }): { Vector3 }
	local out = {}
	for _, p in ipairs(list) do
		table.insert(out, V(p[1], p[2]))
	end
	return out
end

-- a guia aparece na frente do jogador (olhando para ele)
local function guideInFront(dist: number?)
	local root = waitRoot()
	local look = flat(root.CFrame.LookVector)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	local at = root.Position + look * (dist or 9)
	spawnGuide(at, root.Position, true)
	if guide then
		guide.Wave = os.clock() + 2.2
	end
end

-- 🌀 a guia ENTRA no portal (2026-10-23, o dono: "ela não está entrando no portal"): anda até o arco, some no
-- redemoinho e espera do outro lado. Volta sozinha se o jogador passar antes dela (stop() = true).
local function enterPortal(center: Vector3, front: Vector3, color: Color3, stop: (() -> boolean)?)
	if not guide then
		return
	end
	walkGuide({ front, center }, false, 13)
	waitGuideArrived(stop)
	if guide then
		sfx("Whoosh")
		poof(guide.Pos + Vector3.new(0, 1, 0), color)
		poof(guide.Pos + Vector3.new(0, 4, 0), Color3.new(1, 1, 1))
		removeGuide(false)
	end
end

---------------------------------------------------------------- roteiro
local Starter: any = nil
local VillageLife: any = nil
local petName = "your dog"
local talkedToProf = false
local rollStage = false

local function phaseIntro()
	-- (servidor novo / Studio: a Pawville ainda pode estar montando — a guia espera a vila e o jogador estar nela)
	objective("⏳", "Pawville is getting ready...")
	waitFor(function()
		local isles = workspace:FindFirstChild("Islands")
		local v = isles and isles:FindFirstChild(Village.Id)
		return v ~= nil and v:GetAttribute("Ready") == true
	end, 150)
	-- 👑 o avatar da guia (o dono do jogo) é o 1º que o servidor monta: espera um pouco por ele
	waitFor(function()
		return guideTemplate() ~= nil or guideTemplateGone()
	end, 12)
	waitFor(function()
		return island() == Village.Id
	end, 20)
	local function inVillage()
		return island() == Village.Id
	end
	local met = false
	if not inVillage() then
		-- (veio parar fora da Pawville: a guia leva até o portal 🏡 PAWVILLE da ilha principal e entra nele — ela nunca
		-- atravessa o mar andando)
		objective("👋", "Meet your guide!")
		waitRoot()
		sleep(0.6)
		guideInFront(10)
		sfx("Magic")
		say("guide", "Hi there! 👋 Welcome to DogWorld! " .. introLine(), { Wave = true })
		say("guide", "Every adventure starts in 🏡 PAWVILLE, the dog town. Follow me to its portal!")
		hideDialog()
		local swirl = portalSwirl(Village.Id)
		if swirl and not inVillage() then
			local center, front = portalSpots(swirl)
			objective("🧭", "Follow " .. guideName() .. " to the PAWVILLE portal")
			walkGuide({ front }, true, 15)
			pointTo(guidePos, guide and guide.Rig.Head or nil)
			waitGuideArrived(inVillage)
			if not inVillage() then
				waitFor(function()
					return nearPlayer(guide and guide.Pos, 24) or inVillage()
				end)
			end
			if not inVillage() then
				say("guide", "This portal goes to 🏡 PAWVILLE! Come with me, I'll wait for you there! 😉", { Wave = true })
				hideDialog()
				enterPortal(center, front, Village.Color, inVillage)
			end
			objective("🌀", "Walk into the 🏡 PAWVILLE portal")
			pointTo(center + Vector3.new(0, 2, 0), nil)
		end
		waitFor(inVillage)
		pointTo(nil, nil)
		met = true
		sleep(0.6)
	end
	objective("👋", "Meet your guide!")
	waitRoot()
	sleep(0.6)
	guideInFront(10)
	sfx("Magic")
	sleep(0.4)
	if met then
		say("guide", "Here we are! 🏡 Welcome to PAWVILLE!", { Wave = true })
	else
		say("guide", "Hi there! 👋 Welcome to DogWorld!", { Wave = true })
		say("guide", introLine())
		say("guide", "Here, everyone has a DOG: your best friend AND your fighting partner! 🐶")
	end
	say("guide", "But... you don't have a dog yet! Let's fix that right now.")
	say("guide", "Follow me to the Kennel. " .. PROF .. " is waiting for you! 🐾", { Wave = true })
	hideDialog()
	objective("🧭", "Follow " .. guideName() .. " to the Kennel")
	walkGuide(pathOf(TO_PROF), true, 14)
	pointTo(guidePos, guide and guide.Rig.Head or nil)
	waitGuideArrived()
	if guide then
		guide.WantTalk = true
	end
	objective("🎓", "Walk up to " .. PROF)
	pointTo(function()
		return profPos()
	end, professorPart())
	waitFor(function()
		return talkedToProf or nearPlayer(profPos(), 20)
	end)
	pointTo(nil, nil)
end

local function phaseProfessor()
	objective("🎓", "Talk to " .. PROF)
	local prof = professorAvatar()
	local profName = prof and prof:GetAttribute("DisplayName")
	if type(profName) == "string" and profName ~= "" and prof:GetAttribute("Kind") == "friend" then
		-- (o professor é um amigo do dono: a guia apresenta pelo nome)
		say("guide", "Here we are! This is " .. (guideIsOwner() and "my friend " or "") .. profName .. ", our " .. string.upper(PROF) .. ": the dog expert of Pawville! 🎓")
	else
		say("guide", "Here we are! This is " .. PROF .. ", the dog expert of Pawville! 🎓")
	end
	say("prof", "Well, hello there, young fighter! Welcome to my Kennel! 🐾")
	-- 🎬 cena: a câmera voa sobre o parque do canil enquanto os cachorros fazem festa
	cinema(true)
	if VillageLife and VillageLife.Party then
		VillageLife.Party(22)
	end
	local function P(x: number, y: number, z: number): Vector3
		return Village.ToWorld(x, Village.GROUND_Y + y, z)
	end
	shot(P(-8, 34, 36), P(0, 4, -40), P(-46, 24, 2), P(-20, 3, -52), 6)
	say("prof", "Look at them play! Every dog here is waiting for a friend... just like YOU.")
	shot(P(64, 20, -6), P(28, 3, -40), P(60, 16, -78), P(24, 3, -52), 6)
	say("prof", "They run, they fetch, they jump... and with a fighter by their side, they become SUPER strong! 💪")
	shot(P(-30, 52, -90), P(0, 2, -36), P(36, 46, -92), P(0, 2, -30), 6)
	say("prof", "Some dogs are Common, some are RARE... and some are even LEGENDARY or MYTHIC! ✨")
	local stage = P(0, 6, 22)
	shot(stage, profPos() + Vector3.new(0, 1, 0), stage + Vector3.new(0, -1, -4), profPos() + Vector3.new(0, 1, 0), 3)
	say("prof", "And now... it's YOUR turn to have a dog! 🎉")
	endShots()
	cinema(false)
	local names = {}
	for _, c in ipairs(Config.STARTER_CHOICES) do
		local sp = DogData.Species[c.Species]
		table.insert(names, sp and sp.Name or c.Species)
	end
	local list = #names > 1 and (table.concat(names, ", ", 1, #names - 1) .. " or " .. names[#names]) or (names[1] or "")
	say("prof", "Choose your PARTNER! 🐶 " .. list .. ": pick the one you love the most!")
	hideDialog()
	-- 🐶 escolha (Systems/Starter): espera o jogador ficar com um cachorro
	rollStage = true
	objective("🐶", "Choose your partner!")
	local kept: { any }? = nil
	local conn = Starter.Kept:Connect(function(species, name)
		kept = { species, name }
	end)
	Starter.Open()
	local ok = pcall(waitFor, function()
		if not kept and not blocked() and not started() then
			-- (fechou a escolha sem escolher: fala com o professor de novo)
			objective("🎓", "Talk to " .. PROF .. " to choose your dog")
		end
		return kept ~= nil or started()
	end)
	conn:Disconnect()
	check()
	if not ok then
		error(SKIP, 0)
	end
	local species = kept and kept[1]
	petName = kept and kept[2] or petName
	if not species then
		local dog = Net.Equipped()
		species = dog and dog.Species
		petName = dog and dog.Name or petName
	end
	-- 🐶 o cachorro aparece na frente do professor e corre até o jogador (ainda somos a pessoa)
	sleep(0.3)
	if species and not isDog() then
		local S = Village.STARTER_SPOT
		spawnPet(species, petName, V(S.X, S.Z))
	end
	say("prof", "Wonderful! Take good care of " .. petName .. "! 🐶")
	say("prof", "More dogs? CATCH them in the wild! And come back EVERY DAY for a FREE SPIN at my Dog Roulette! 🎰")
	say("guide", "Yaaay! Look, " .. petName .. " already loves you! Your dog will follow you everywhere you go! 💕", { Clap = true })
	send("phase", 3)
end

-- 🦮 loja de coleiras: a guia leva até a barraquinha e o jogador pega o pacote GRÁTIS
local function hasGift(): boolean
	local p = Net.Profile
	return p ~= nil and p.LeashGift == true
end

local function leashPos(): Vector3
	for _, prompt in ipairs(CollectionService:GetTagged("LeashShopPrompt")) do
		local part = prompt.Parent
		if part and part:IsA("BasePart") and part:IsDescendantOf(workspace) and Village.Inside(part.Position) then
			return part.Position
		end
	end
	return V(Village.LEASH_SHOP.X, Village.LEASH_SHOP.Z)
end

local function openLeashShop()
	if HUD_REF and HUD_REF.HasMenu and HUD_REF.HasMenu("Coleiras") and not HUD_REF.IsOpen("Coleiras") then
		HUD_REF.Toggle("Coleiras")
	end
end

local function phaseLeash()
	if not guide then
		guideInFront(9)
		say("guide", "Welcome back! Let's continue your adventure! 😄", { Wave = true })
	end
	say("guide", "Now, how do you get MORE dogs? You CATCH them! 🐾 Come with me to the LEASH SHOP!")
	hideDialog()
	objective("🧭", "Follow " .. guideName() .. " to the LEASH SHOP")
	local path = pathOf(TO_LEASH)
	local best, bestD = 1, math.huge
	for i, p in ipairs(path) do
		local d = guide and flat(p - guide.Pos).Magnitude or 0
		if d < bestD then
			best, bestD = i, d
		end
	end
	local rest = {}
	for i = best, #path do
		table.insert(rest, path[i])
	end
	walkGuide(rest, true, 14)
	pointTo(guidePos, guide and guide.Rig.Head or nil)
	local function leftVillage()
		return island() ~= Village.Id
	end
	waitGuideArrived(function()
		return leftVillage() or hasGift()
	end)
	if guide then
		guide.WantTalk = true
	end
	waitFor(function()
		return nearPlayer(guide and guide.Pos, 20) or leftVillage() or hasGift()
	end)
	pointTo(nil, nil)
	if leftVillage() then
		return
	end
	if not hasGift() then
		say("guide", "This is the 🐾 LEASH SHOP! Here you buy LEASHES to catch wild dogs!", { Wave = true })
		say("guide", "Fight a wild dog, make it WEAK... then throw a leash with the CATCH button! The weaker it is, the easier! 🦮")
		say("guide", "And guess what? Your FIRST pack is FREE! 🎁 Go get it!", { Clap = true })
		hideDialog()
		if touch() then
			objective("🎁", "Tap SHOP at the LEASH SHOP: get your FREE leashes")
		else
			objective("🎁", "Press E at the LEASH SHOP: get your FREE leashes")
		end
		local at = leashPos()
		pointTo(at + Vector3.new(0, 3, 0), nil)
		local opened = os.clock()
		waitFor(function()
			-- (ficou parado sem abrir: a guia abre a loja para ele)
			if os.clock() - opened > 25 and nearPlayer(at, 30) then
				opened = os.clock() + 1e6
				openLeashShop()
			end
			return hasGift() or leftVillage()
		end)
		pointTo(nil, nil)
		if leftVillage() then
			return
		end
		sfx("Coin")
		say("guide", "YAY! 🎉 5 LEASHES for you! Let's go find some wild dogs!", { Clap = true })
	end
	if HUD_REF and HUD_REF.IsOpen and HUD_REF.IsOpen("Coleiras") then
		waitFor(function()
			return not HUD_REF.IsOpen("Coleiras")
		end, 20)
	end
end

local function phaseArena()
	if not guide then
		guideInFront(9)
		say("guide", "Welcome back! Let's continue your adventure! 😄", { Wave = true })
	end
	say("guide", "Now come with me! I'll show you the way to adventure!")
	hideDialog()
	objective("🧭", "Follow " .. guideName() .. " to the Arena portal")
	-- (começa do lugar onde ela está: o 1º ponto do caminho é o mais perto dela; da loja de coleiras ela dá a volta
	-- pela praça)
	local fromLeash = guide ~= nil and flat(guide.Pos - V(-52, 116)).Magnitude < 30
	local path = pathOf(fromLeash and LEASH_TO_ARENA or TO_ARENA)
	local best, bestD = 1, math.huge
	for i, p in ipairs(path) do
		local d = guide and flat(p - guide.Pos).Magnitude or 0
		if d < bestD then
			best, bestD = i, d
		end
	end
	local rest = {}
	for i = best, #path do
		table.insert(rest, path[i])
	end
	walkGuide(rest, true, 15)
	pointTo(guidePos, guide and guide.Rig.Head or nil)
	local function leftVillage()
		return island() ~= Village.Id
	end
	waitGuideArrived(leftVillage)
	if guide then
		guide.WantTalk = true
	end
	waitFor(function()
		return nearPlayer(guide and guide.Pos, 22) or leftVillage()
	end)
	pointTo(nil, nil)
	say("guide", "This is the ARENA PORTAL! ⚔️ It takes you to the Main Island.", { Wave = true })
	say("guide", "There's the giant COLOSSEUM! Inside it, players battle each other... and every 30 minutes the SUPER BOSS 🌍 shows up for EVERYONE to fight together!")
	say("guide", "Now, how does DogWorld work? Fight wild dogs to earn 💵 CASH and ⭐ XP. Your dog levels up, gets stronger and unlocks POWERS! ⚡")
	say("guide", "CATCH wild dogs with 🐾 LEASHES: Common, Rare, Epic, Legendary, Mythic... even 🎃 HALLOWEEN dogs! Or try your luck at the 🎰 DOG ROULETTE!")
	say("guide", "And your GOAL: have the STRONGEST DOG in all of DogWorld! 🏆", { Clap = true })
	say("guide", "But first, let's practice with the weakest wild dogs. Follow me! 🌻")
	hideDialog()
	send("phase", 4)
end

local function phaseMeadows()
	local inVillage = island() == Village.Id
	if inVillage then
		if not guide then
			guideInFront(9)
		end
		objective("🧭", "Follow " .. guideName() .. " to the Puppy Meadows portal")
		walkGuide(pathOf(TO_MEADOWS), true, 14)
		pointTo(guidePos, guide and guide.Rig.Head or nil)
		local function away()
			return island() ~= Village.Id
		end
		waitGuideArrived(away)
		waitFor(function()
			return nearPlayer(guide and guide.Pos, 24) or away()
		end)
		local MP = Village.MEADOWS_PORTAL
		local portalPos = V(MP.X, MP.Z)
		local swirl = portalSwirl("common", Village.Id)
		local center, front = portalPos, portalPos + flat(V(0, 270) - portalPos).Unit * 14
		if swirl then
			center, front = portalSpots(swirl)
			portalPos = center
		end
		if not away() then
			say("guide", "This portal goes to 🌻 PUPPY MEADOWS, the first island! The wild dogs there are the weakest. Perfect to practice!")
			say("guide", "Come with me! I'll wait for you on the other side! 😉", { Wave = true })
			hideDialog()
			objective("🌀", "Walk into the PUPPY MEADOWS portal")
			pointTo(portalPos + Vector3.new(0, 2, 0), nil)
			enterPortal(center, front, Color3.fromRGB(120, 220, 90), away)
		end
		objective("🌀", "Walk into the PUPPY MEADOWS portal")
		pointTo(portalPos + Vector3.new(0, 2, 0), nil)
	else
		-- (voltou ao jogo longe da vila, ou passou pelo portal da Arena antes da hora: o portal da 🌻 também fica na
		-- Praça dos Portais da ilha principal)
		removeGuide(false)
		objective("🌻", "Go to PUPPY MEADOWS: take the 🌻 portal in the Portal Plaza")
		pointTo(function()
			local swirl = plazaMeadowsPortal()
			return swirl and swirl.Position - Vector3.new(0, 18, 0) or nil
		end, nil)
	end
	waitFor(function()
		return island() == "common"
	end)
	pointTo(nil, nil)
end

local function phaseFight()
	-- ela já está esperando do outro lado do portal
	local root = waitRoot()
	sleep(0.5)
	root = waitRoot()
	local def = Islands.List.common
	local toCenter = flat(def.Center - root.Position)
	toCenter = toCenter.Magnitude > 1 and toCenter.Unit or flat(root.CFrame.LookVector).Unit
	spawnGuide(root.Position + toCenter * 11 + Vector3.new(0, 0, 0), root.Position, false)
	if guide then
		guide.Wave = os.clock() + 2.5
	end
	say("guide", "Here we are! 🌻 Welcome to PUPPY MEADOWS!", { Wave = true })
	if not isDog() then
		say("guide", "Wild dogs only fight other dogs... so YOU and " .. petName .. " will become ONE! 🐶✨")
		say("guide", "Ready? Let's go!", { Choice = "🐶 BECOME " .. string.upper(petName) .. "!" })
		hideDialog()
		send("dog")
		local ok = waitFor(isDog, 6)
		if not ok then
			send("dog")
			waitFor(isDog, 8)
		end
		local r = myRoot()
		if r then
			poof(r.Position, C.Pink)
		end
		sfx("Magic")
		sleep(0.8)
		say("guide", "AWESOME! Now YOU are " .. petName .. "! Look at you! 🐾", { Clap = true })
	end
	if touch() then
		say("guide", "Tap ATTACK to bite: 3 hits in a row make a COMBO! Tap DASH to dash through enemies and RUN to run fast.")
	else
		say("guide", "CLICK to attack: 3 hits in a row make a COMBO! Press Q to DASH through enemies and hold SHIFT to run.")
	end
	-- 🍼 (2026-10-24) reforço de iniciante (Config.ROOKIE)
	local rookie = Config.ROOKIE
	if rookie and Config.RookieBoost(1) > 0 then
		say("guide", "Don't worry: new dogs get a 🍼 ROOKIE BOOST! You hit HARDER and take LESS damage until level " .. rookie.End .. ". 💪")
	end
	say("guide", "Your attacks go where you aim. Now defeat " .. KILLS .. " wild dogs! I'll be cheering for you! 📣", { Wave = true })
	hideDialog()
	if guide then
		guide.Follow = true
	end
	objective("⚔️", "Defeat wild dogs", tour.Kills or 0, KILLS)
	local seen = tour.Kills or 0
	waitFor(function()
		local kills = tour.Kills or 0
		if kills ~= seen then
			seen = kills
			objective("⚔️", "Defeat wild dogs", kills, KILLS)
			Kit.Pop(ui.GoalCount, true)
			if guide then
				guide.Clap = os.clock() + 2
			end
			bubble(kills >= KILLS and "YOU DID IT!! 🎉" or ({ "Nice one! 🎉", "Great job! 💪", "Wooo! 🔥" })[math.min(kills, 3)] .. " " .. kills .. "/" .. KILLS)
			sfx("Coin")
		end
		pointTo(nearestWild(), nearestWild())
		return tour.Done ~= nil or kills >= KILLS
	end)
	pointTo(nil, nil)
	if tour.Done == nil and (tour.Catches or 0) < CATCHES then
		-- 🦮 agora a captura: deixa um selvagem fraco e joga a coleira
		if guide then
			guide.Follow = false
		end
		say("guide", "AMAZING! 💪 Now let's CATCH one! Fight a wild dog and make it WEAK...", { Clap = true })
		if touch() then
			say("guide", "...then tap CATCH to throw a 🐾 LEASH! When it says GOTCHA, the dog is YOURS! 🦮")
		else
			say("guide", "...then press G (or click CATCH) to throw a 🐾 LEASH! When it says GOTCHA, the dog is YOURS! 🦮")
		end
		if not hasGift() then
			say("guide", "Oh! You don't have leashes yet... here, your FIRST pack is FREE! 🎁")
			hideDialog()
			openLeashShop()
			waitFor(hasGift, 30)
		end
		hideDialog()
		if guide then
			guide.Follow = true
		end
		objective("🦮", "Catch a wild dog", tour.Catches or 0, CATCHES)
		waitFor(function()
			pointTo(nearestWild(), nearestWild())
			return tour.Done ~= nil or (tour.Catches or 0) >= CATCHES
		end)
		pointTo(nil, nil)
		objective("🦮", "Catch a wild dog", tour.Catches or 0, CATCHES)
		Kit.Pop(ui.GoalCount, true)
		if guide then
			guide.Clap = os.clock() + 2
		end
		bubble("GOTCHA!! 🎉")
	end
	waitFor(function()
		return tour.Done ~= nil
	end, 8)
	if tour.Done == nil then
		-- (o servidor ainda não mandou o prêmio: espera mais, mostrando o que falta)
		waitFor(function()
			if (tour.Kills or 0) < KILLS then
				objective("⚔️", "Defeat wild dogs", tour.Kills or 0, KILLS)
			end
			return tour.Done ~= nil
		end)
	end
end

local function showReward(r: any)
	ui.Rows[1].Label.Text = "💵  +$" .. Config.Format(r.Cash or 0) .. " Cash"
	ui.Rows[2].Label.Text = "⭐  " .. petName .. ": Lv." .. tostring(r.From or 1) .. "  →  Lv." .. tostring(r.To or 1)
	ui.Rows[3].Label.Text = r.Egg and "🥚  +1 free egg in 🎒 EGGS" or r.Spin and "🎰  +1 FREE SPIN at the Dog Roulette" or "🏆  You're a real Dog Fighter!"
	ui.Reward.Visible = true
	ui.Rays.Visible = true
	Kit.Pop(ui.Reward, true)
	sfx("Purchase")
	for k = 0, 3 do
		task.delay(k * 0.25, function()
			Kit.Burst(ui.Root, UDim2.fromScale(0.5, 0.42), ({ C.Gold, C.Pink, C.Blue, C.Green })[k + 1], 26, { "✦", "★", "🐾", "🎉" }, 360)
		end)
	end
	for i, row in ipairs(ui.Rows) do
		row.Box.Visible = false
		task.delay(0.35 + i * 0.3, function()
			row.Box.Visible = true
			Kit.Pop(row.Box, true)
			sfx("Coin")
		end)
	end
	tour.RewardOk = false
	waitFor(function()
		return tour.RewardOk == true
	end, 14)
	Kit.Pop(ui.Reward, false)
	ui.Rays.Visible = false
end

local function phaseEnd()
	objective(nil, nil)
	local r = tour.Done or {}
	if guide then
		guide.Follow = false
		guide.Clap = os.clock() + 3
	end
	say("guide", "YOU DID IT! 🎉🎉 You're a real DOG FIGHTER now!", { Clap = true })
	hideDialog()
	showReward(r)
	say("guide", "Explore the islands, take ❗ MISSIONS for lots of Cash, CATCH rare dogs... and become the STRONGEST DOG of DogWorld! 🏆")
	if touch() then
		say("guide", "Need help? Open ⚙️ SETTINGS ➜ HOW TO PLAY anytime. Bye-bye! 👋", { Wave = true })
	else
		say("guide", "Need help? Press H anytime for the full guide. Bye-bye! 👋", { Wave = true })
	end
	hideDialog()
	sleep(1.2)
	removeGuide(true)
end

---------------------------------------------------------------- liga / desliga
local function cleanup()
	pointTo(nil, nil)
	objective(nil, nil)
	hideDialog()
	if ui then
		ui.Reward.Visible = false
		ui.Rays.Visible = false
		for _, bar in ipairs(ui.Bars) do
			bar.Size = UDim2.new(1, 0, 0, 0)
		end
	end
	if cam then
		RunService:UnbindFromRenderStep("GuideCam")
		cam = nil
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
		end
	end
	if next(hiddenGuis) then
		cinema(false)
	end
	removeGuide(true)
	removePet(true)
	if Starter then
		Starter.Touring = false
	end
end

local function run(profile: any)
	tour = { Kills = tonumber(profile.GuideKills) or 0, Catches = tonumber(profile.GuideCatch) or 0 }
	if not ui then
		ui = buildUI()
		ui.Click.Activated:Connect(function()
			if tour then
				tour.Clicked = true
			end
		end)
		ui.Choice.Activated:Connect(function()
			if tour then
				tour.Choice = true
			end
		end)
		ui.RewardOk.Activated:Connect(function()
			if tour then
				tour.RewardOk = true
			end
		end)
		local armed = 0
		ui.Skip.Activated:Connect(function()
			if not tour then
				return
			end
			if os.clock() - armed < 3 then
				tour.Cancelled = true
				send("skip")
				HUD_TOAST("⏭️ Tutorial skipped. Press H anytime for the full guide!")
			else
				armed = os.clock()
				ui.Skip.Text = "click again to skip"
				task.delay(3, function()
					if ui then
						ui.Skip.Text = "skip tutorial ✕"
					end
				end)
			end
		end)
		UserInputService.InputBegan:Connect(function(input, processed)
			if not (tour and ui.Panel.Visible) or UserInputService:GetFocusedTextBox() then
				return
			end
			local k = input.KeyCode
			if k == Enum.KeyCode.Space or k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA or (k == Enum.KeyCode.E and not processed) then
				tour.Clicked = true
			end
		end)
	end
	ui.Gui.Enabled = true
	Starter.Touring = true
	talkedToProf = false
	rollStage = false
	local phase = tonumber(profile.Guide) or 0
	local ok, err = pcall(function()
		if not started() then
			phaseIntro()
			phaseProfessor()
			phase = 3
		else
			local dog = Net.Equipped()
			petName = dog and dog.Name or petName
		end
		-- (quem volta ao jogo no meio continua da fase salva; a loja e a Arena só fazem sentido dentro da vila)
		if phase < 4 and island() == Village.Id and not hasGift() then
			phaseLeash()
		end
		if phase < 4 and island() == Village.Id then
			phaseArena()
			phase = 4
		end
		if island() ~= "common" then
			phaseMeadows()
		end
		send("phase", 5)
		phaseFight()
		phaseEnd()
	end)
	if not ok and err ~= SKIP then
		warn("[GuideTour]", err)
	end
	cleanup()
	tour = nil
	ui.Gui.Enabled = false
end

---------------------------------------------------------------- laço (guia, cachorro, linha, telas cheias)
function GuideTour.Start(HUD)
	HUD_REF = HUD
	HUD_TOAST = function(text)
		if HUD and HUD.Toast then
			HUD.Toast(text, "gold")
		end
	end
	Starter = require(script.Parent:WaitForChild("Starter"))
	local okLife, life = pcall(require, script.Parent:WaitForChild("VillageLife"))
	VillageLife = okLife and life or nil
	-- o jogador sem cachorro falou com o professor: a guia cuida (conversa + cena) até a hora da roleta
	Starter.Intercept = function()
		if tour and not rollStage then
			talkedToProf = true
			return true
		end
		return false
	end
	Net.Remotes:WaitForChild("TutorialAction").OnClientEvent:Connect(function(kind, a, _b)
		if not tour then
			return
		end
		if kind == "kills" and type(a) == "number" then
			tour.Kills = a
		elseif kind == "catch" and type(a) == "number" then
			tour.Catches = a
		elseif kind == "done" then
			tour.Done = type(a) == "table" and a or {}
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		if not tour and not guide and not pet then
			return
		end
		local now = os.clock()
		local ok, err = pcall(function()
			updateGuide(dt, now)
			updatePet(dt, now)
			updateLine(now)
			if ui then
				-- telas cheias (roleta, ovo): o diálogo e o objetivo somem
				local hide = blocked()
				ui.Gui.Enabled = tour ~= nil and not hide
				-- o objetivo sobe quando o diálogo está aberto
				local above = abilityGap() + (ui.Panel.Visible and 186 or 0)
				goalOffset = approach(goalOffset, above, 10, dt)
				ui.Goal.Position = UDim2.new(0.5, 0, 1, -goalOffset)
				ui.Hint.TextTransparency = 0.25 + 0.25 * math.sin(now * 5)
				if portraitRig and ui.Panel.Visible then
					VillageFolk.Pose(portraitRig, now, { Talk = (tour and tour.Speaker and ui.Text.MaxVisibleGraphemes ~= -1) and 1 or 0.3 })
				end
			end
		end)
		if not ok then
			warn("[GuideTour] laço:", err)
		end
	end)

	-- começa depois do ▶ PLAY
	Title.WaitDone()
	local profile = Net.WaitProfile()
	if (tonumber(profile.Tutorial) or 0) >= DONE then
		return
	end
	task.wait(0.5)
	run(profile)
end

-- (preview/testes) abre o passeio na hora
function GuideTour.Run(profile)
	run(profile)
end

-- (prévia das telas, tools/hud_preview: tour<guide|prof|choice|reward>) mostra a caixa de diálogo, o objetivo e o prêmio
-- sem rodar o roteiro
function GuideTour.Preview(what: string)
	tour = { Kills = 1 }
	ui = ui or buildUI()
	ui.Gui.Enabled = true
	if what == "reward" then
		ui.Rows[1].Label.Text = "💵  +$1,000 Cash"
		ui.Rows[2].Label.Text = "⭐  Rex: Lv.1  →  Lv.4"
		ui.Rows[3].Label.Text = Config.EGGS and "🥚  +1 free egg in 🎒 EGGS" or "🎰  +1 FREE SPIN at the Dog Roulette"
		ui.Reward.Visible = true
		ui.Rays.Visible = true
		return
	end
	ui.Panel.Visible = true
	showPortrait(what == "prof" and "prof" or "guide")
	ui.Text.Text = what == "prof" and "They run, they fetch, they jump... and with a fighter by their side, they become SUPER strong! 💪"
		or "This is the ARENA PORTAL! ⚔️ It takes you to the Main Island. There's the giant COLOSSEUM!"
	ui.Hint.Visible = what ~= "choice"
	if what == "choice" then
		ui.Text.Text = "Ready? Let's go!"
		ui.Choice.Text = "🐶 BECOME REX!"
		ui.Choice.Visible = true
	end
	objective("⚔️", "Defeat wild dogs", 1, KILLS)
	ui.Goal.Position = UDim2.new(0.5, 0, 1, -(abilityGap() + 186))
end

return GuideTour
