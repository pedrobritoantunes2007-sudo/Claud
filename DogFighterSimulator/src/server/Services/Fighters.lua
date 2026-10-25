-- Registro de todos os cachorros que lutam (do jogador, NPCs e bosses) e utilidades de combate:
-- dano, knockback, congelar, ações de animação e efeitos visuais.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Signal = require(ReplicatedStorage.Shared.Signal)

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local DogBuilder = require(ReplicatedStorage.Shared.DogBuilder)
local Variants = require(ReplicatedStorage.Shared.Variants)
local Accessories = require(ReplicatedStorage.Shared.Accessories)

local Fighters = {}
Fighters.List = {} -- [model] = fighter
-- Corpos: [fighter] = os.clock() da morte. Quem morreu some sozinho depois de CORPSE_TIME,
-- mesmo que nenhum outro serviço peça (NPCService/DogService/BossService ainda podem remover antes).
Fighters.Corpses = {}
Fighters.CORPSE_TIME = { npc = 1.5, player = 1.6, boss = 3 }
Fighters.CORPSE_GRACE = 2.5 -- rede de segurança da varredura: CORPSE_TIME + isto
Fighters.Killed = Signal.new() -- (victim, killerFighter)
Fighters.DuelEnded = Signal.new() -- (fighterA, fighterB)

-- Escala de mundo. (2026-10, pedido do dono: "manter a maioria um tamanho pequeno que pareça cachorro") — antes
-- era 1,4x para todos; agora cada espécie tem o seu tamanho (DogData.GameScale: cabeça de ~2 a ~4,5 studs, só os
-- colossos míticos maiores). As telas 3D da UI usam o DogBuilder direto e não mudam. Bosses continuam enormes.
-- HipHeight, raio, barra de nome e animações já leem o tamanho real do modelo.
Fighters.BOSS_WORLD_SCALE = 1.15 -- bosses já têm Scale próprio (2.2–2.4)
-- 🦶 vão mínimo entre o chão e a caixa do corpo: sobe os degraus de 1 stud do chão de blocos andando (DogBuilder)
Fighters.MIN_CLEAR = 1.15

local nextId = 0

local remotes
local folder

function Fighters.Init(r)
	remotes = r
	-- varredura: quem está com vida 0 mas não morreu "oficialmente" morre agora
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, f in pairs(table.clone(Fighters.List)) do
				if not f.Dead and not f.Removed and f.Humanoid and f.Humanoid.Health <= 0 then
					Fighters.Die(f)
				end
			end
			-- nenhum corpo fica no mapa: morto há tempo demais e ainda lá → some agora
			local now = os.clock()
			for f, diedAt in pairs(table.clone(Fighters.Corpses)) do
				if f.Removed or not f.Model.Parent then
					Fighters.Corpses[f] = nil
				elseif now - diedAt > (Fighters.CORPSE_TIME[f.Kind] or 1.5) + Fighters.CORPSE_GRACE then
					Fighters.Remove(f)
				end
			end
		end
	end)
	folder = Instance.new("Folder")
	folder.Name = "Cachorros"
	folder.Parent = workspace
end

---------------------------------------------------------------- visual
-- 🎨 (2026-10-24, cartoon) plaquinha com contorno escuro grosso (o mesmo roxo-tinta das telas) e barra de vida chapada
local INK = Color3.fromRGB(36, 22, 58)
local function inked(label, thickness)
	label.TextStrokeTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = thickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
end
local function makeBillboard(f)
	local rarity = Config.RARITY[f.Species.Rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	-- plaquinha compacta (NPCs menores ainda); a ficha completa aparece ao passar o mouse/selecionar
	if f.Kind == "boss" then
		gui.Size = UDim2.fromOffset(200, 60)
	elseif f.Kind == "npc" then
		gui.Size = UDim2.fromOffset(96, 30)
	else
		gui.Size = UDim2.fromOffset(120, 38)
	end
	gui.StudsOffsetWorldSpace = Vector3.new(0, f.Root.Size.Y * 0.5 + f.HipHeight * 0.4 + 2.5 * f.BaseScale ^ 0.5 + (f.Kind == "boss" and 4 or 0), 0)
	gui.MaxDistance = f.Kind == "boss" and 400 or (f.Kind == "npc" and 70 or 120)
	gui.LightInfluence = 0
	gui.Adornee = f.Root

	local name = Instance.new("TextLabel")
	name.Name = "Nome"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.45, 0)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = f.Kind == "npc" and Color3.fromRGB(255, 200, 190) or Color3.new(1, 1, 1)
	name.Text = f.DisplayName
	inked(name, 2)
	name.Parent = gui

	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.42)
	sub.Size = UDim2.new(1, 0, 0.28, 0)
	sub.Font = Enum.Font.FredokaOne
	sub.TextScaled = true
	sub.TextColor3 = rarity.Color
	sub.Text = f.Kind == "npc" and ("Lv." .. f.Level) or ("Lv." .. f.Level .. "  " .. rarity.Label)
	inked(sub, 1.5)
	sub.Parent = gui

	local back = Instance.new("Frame")
	back.Position = UDim2.fromScale(0.1, 0.74)
	back.Size = UDim2.fromScale(0.8, 0.2)
	back.BackgroundColor3 = INK
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = back
	local backStroke = Instance.new("UIStroke")
	backStroke.Color = INK
	backStroke.Thickness = 2
	backStroke.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(110, 230, 110)
	fill.BorderSizePixel = 0
	fill.Parent = back
	corner:Clone().Parent = fill

	gui.Parent = f.Model
	f.Billboard = gui
	f.Humanoid.HealthChanged:Connect(function(hp)
		local pct = math.clamp(hp / math.max(1, f.Humanoid.MaxHealth), 0, 1)
		fill.Size = UDim2.fromScale(pct, 1)
		fill.BackgroundColor3 = Color3.fromRGB(235, 70, 60):Lerp(Color3.fromRGB(110, 230, 110), pct)
	end)
end

function Fighters.RefreshLabel(f)
	if f.Billboard then
		local rarity = Config.RARITY[f.Species.Rarity]
		-- (cartoon, sem emoji: em PvP o nome fica vermelho; os elementos aparecem na ficha ao mirar)
		f.Billboard.Nome.Text = f.DisplayName
		if f.Kind ~= "npc" then
			f.Billboard.Nome.TextColor3 = f.Mode == "pvp" and Color3.fromRGB(255, 120, 120) or Color3.new(1, 1, 1)
		end
		-- ✨ shiny / 🥇 Gold / 🌈 Rainbow aparecem na plaquinha (Shared/Variants)
		local special = Variants.Label(f.Variant, true)
		local sub = f.Kind == "npc" and ("Lv." .. f.Level) or ("Lv." .. f.Level .. "  " .. rarity.Label)
		f.Billboard.Sub.Text = special ~= "" and (sub .. "  " .. special) or sub
		f.Billboard.Sub.TextColor3 = Variants.Color(f.Variant) or rarity.Color
		-- 🐺 sigla do clã + 🏅 título em cima da cabeça (ClanService põe o atributo ClanTag; ProgressionService, o Title)
		local owner = f.Kind == "player" and f.Owner or nil
		local tag = owner and owner:GetAttribute("ClanTag")
		local title = owner and owner:GetAttribute("Title")
		local clan = f.Billboard:FindFirstChild("Cla")
		local top = {}
		if type(tag) == "string" and tag ~= "" then
			table.insert(top, "[" .. tag .. "]")
		end
		if type(title) == "string" and title ~= "" then
			table.insert(top, title)
		end
		if #top > 0 then
			if not clan then
				clan = Instance.new("TextLabel")
				clan.Name = "Cla"
				clan.BackgroundTransparency = 1
				clan.Position = UDim2.fromScale(0, -0.36)
				clan.Size = UDim2.new(1, 0, 0.36, 0)
				clan.Font = Enum.Font.FredokaOne
				clan.TextScaled = true
				inked(clan, 1.5)
				clan.Parent = f.Billboard
			end
			clan.Text = table.concat(top, " ")
			local color = (type(tag) == "string" and tag ~= "") and owner:GetAttribute("ClanColor") or nil
			clan.TextColor3 = typeof(color) == "Color3" and color or Color3.fromRGB(255, 220, 120)
		elseif clan then
			clan:Destroy()
		end
	end
	if f.Model.Parent then
		f.Model:SetAttribute("DogName", f.DisplayName)
		f.Model:SetAttribute("DogLevel", f.Level)
		f.Model:SetAttribute("Power", f.Stats.Power)
		f.Model:SetAttribute("Mode", f.Mode)
	end
end

---------------------------------------------------------------- criação
-- opts: SpeciesId, Level, Kind, Owner, DisplayName, CFrame, Scale, StatMult = {HP, Atk}
function Fighters.Spawn(opts)
	local species = DogData.Species[opts.SpeciesId]
	local world = (opts.Kind == "boss") and Fighters.BOSS_WORLD_SCALE or DogData.GameScale(opts.SpeciesId)
	local model = DogBuilder.Build(opts.SpeciesId, { scale = (opts.Scale or 1) * world, minClear = Fighters.MIN_CLEAR })
	local root = model.PrimaryPart
	local hip = model:GetAttribute("HipHeight")
	-- 🪽 cachorros com asas andam no chão (o do jogador voa com espaço 2x; ver DogService.SetFlying)
	if model:GetAttribute("Wings") and opts.Kind ~= "boss" then
		hip = model:GetAttribute("GroundHip") or hip
		model:SetAttribute("Float", false)
	end
	local baseScale = model:GetAttribute("BaseScale")
	-- ✨ shiny / 🥇 Gold / 🌈 Rainbow: pinta e deixa mais forte · 🎩 acessórios do jogador (todo mundo vê)
	if opts.Variant then
		Variants.Paint(model, opts.Variant)
	end
	if opts.Accessories then
		Accessories.Attach(model, opts.Accessories)
	end

	local stats = Config.Stats(species, opts.Level, opts.Variant)
	if opts.Kind == "player" then
		stats.Speed *= Config.PLAYER_SPEED_MULT * (opts.SpeedBonus or 1)
	end
	if opts.StatMult then
		stats.MaxHP = math.floor(stats.MaxHP * (opts.StatMult.HP or 1))
		stats.Atk = math.floor(stats.Atk * (opts.StatMult.Atk or 1))
		stats.Power = math.floor(stats.MaxHP / 10 + stats.Atk * 3)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = hip
	humanoid.MaxHealth = stats.MaxHP
	humanoid.Health = stats.MaxHP
	humanoid.WalkSpeed = stats.Speed
	humanoid.JumpPower = 40
	humanoid.UseJumpPower = true
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
	humanoid.Parent = model

	local f: any = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Kind = opts.Kind or "npc",
		Owner = opts.Owner,
		Mode = "off",
		Zone = opts.Zone or "home",
		Island = opts.Island, -- ilha onde luta (id do Islands.lua) ou "colosseum"
		HomePos = opts.HomePos, -- campeões: ficam perto do palco deles
		HomeRadius = opts.HomeRadius,
		SpeciesId = opts.SpeciesId,
		Species = species,
		-- (2026-10) selvagens usam a habilidade 2 nova da espécie (shared/Skills.lua)
		Special = DogData.PowersFor(opts.SpeciesId)[1] or species.Special,
		Specials = opts.Specials, -- lista (bosses)
		Level = opts.Level,
		Stats = stats,
		Variant = opts.Variant, -- { Shiny, Tier } (Shared/Variants) ou nil
		DisplayName = opts.DisplayName or species.Name,
		HipHeight = hip,
		BaseScale = baseScale,
		ScaleNow = 1,
		Busy = false,
		FrozenUntil = 0,
		NextAttack = 0,
		NextSpecial = os.clock() + math.random(3, 6),
		DamageTaken = 1,
		DamageDealt = 1,
		Contributions = {}, -- [player] = dano (bosses/NPCs)
		Radius = root.Size.Z / 2,
	}
	nextId += 1
	f.Id = nextId
	model:SetAttribute("Kind", f.Kind)
	model:SetAttribute("Owner", opts.Owner and opts.Owner.UserId or 0)
	-- dados lidos pelo cliente (painel de seleção / barra do duelo)
	model:SetAttribute("FighterId", f.Id)
	model:SetAttribute("DuelId", 0)
	model:SetAttribute("DogName", f.DisplayName)
	model:SetAttribute("DogLevel", f.Level)
	model:SetAttribute("Rarity", species.Rarity)
	model:SetAttribute("Power", stats.Power)
	model:SetAttribute("Mode", f.Mode)
	model:PivotTo((opts.CFrame or CFrame.new()) + Vector3.new(0, hip + root.Size.Y / 2 + 0.5, 0))
	model.Parent = folder
	root:SetNetworkOwner(nil)
	makeBillboard(f)
	if f.Variant then
		Fighters.RefreshLabel(f)
	end
	CollectionService:AddTag(model, "Dog")
	Fighters.List[model] = f

	humanoid.Died:Connect(function()
		Fighters.Die(f)
	end)
	return f
end

-- Corpo some: placa some na hora, o corpo cai, fica transparente e é destruído.
local function fadeOut(f)
	if f.Billboard then
		f.Billboard.Enabled = false
	end
	local delayTime = Fighters.CORPSE_TIME[f.Kind] or 1.5
	local fade = math.min(0.8, delayTime * 0.6)
	task.delay(delayTime - fade, function()
		if f.Removed or not f.Model.Parent then
			return
		end
		local info = TweenInfo.new(fade, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, part in ipairs(f.Model:GetDescendants()) do
			if part:IsA("BasePart") and part.Transparency < 1 then
				TweenService:Create(part, info, { Transparency = 1 }):Play()
			elseif part:IsA("Decal") and part.Transparency < 1 then
				TweenService:Create(part, info, { Transparency = 1 }):Play()
			end
		end
	end)
	task.delay(delayTime, function()
		if not f.Removed then
			Fighters.Remove(f)
		end
	end)
end

-- Morte única e garantida. Humanoid.Died nem sempre dispara nestes rigs montados por código,
-- então também é chamada quando a vida chega a 0 (Damage) e por uma varredura periódica.
-- Cada passo é protegido: um erro em um deles não impede o corpo de sumir.
local function dead(f, killer)
	if not f or f.Dead or f.Removed then
		return
	end
	f.Dead = true
	f.Busy = false
	Fighters.List[f.Model] = nil
	Fighters.Corpses[f] = os.clock()
	if f.Model.Parent then
		pcall(f.Model.SetAttribute, f.Model, "Action", "KO")
	end
	local ok, err = pcall(fadeOut, f)
	if not ok then
		warn("[Fighters] fadeOut:", err)
	end
	ok, err = pcall(Fighters.EndDuel, f)
	if not ok then
		warn("[Fighters] EndDuel:", err)
	end
	Fighters.Killed:Fire(f, killer)
end

function Fighters.Die(f)
	dead(f, f and f.LastHitBy)
end

function Fighters.Remove(f)
	if not f then
		return
	end
	Fighters.List[f.Model] = nil
	Fighters.Corpses[f] = nil
	if f.Removed then
		pcall(f.Model.Destroy, f.Model)
		return
	end
	f.Removed = true -- antes do EndDuel: quem ouve DuelEnded sabe que este saiu (e não desmaiou)
	local ok, err = pcall(Fighters.EndDuel, f)
	if not ok then
		warn("[Fighters] EndDuel:", err)
	end
	pcall(f.Model.Destroy, f.Model)
end

-- O modelo sumiu sem morrer (caiu do mapa e foi destruído pelo motor): trata como nocaute
-- para o dono/NPCService renascerem o cachorro em vez de ele ficar "fantasma" para sempre.
function Fighters.Vanished(f)
	dead(f, nil)
end

function Fighters.Alive(f)
	return f and not f.Dead and not f.Removed and f.Model.Parent ~= nil and f.Humanoid.Health > 0
end

---------------------------------------------------------------- duelos (Arena)
-- Duelo (A.Duel = B, B.Duel = A) = com quem o cachorro está brigando AGORA (barra da luta, música, tutorial).
-- 2026-10: os selvagens atacam sozinhos quem chega perto (CombatService, f.Aggro) e brigam com qualquer
-- cachorro de jogador da ilha (Hostile), então o duelo virou só o "alvo principal". Entre JOGADORES (PvP no
-- Coliseu) o duelo continua obrigatório. Na Boss Tower todos continuam contra o boss.
local function setDuelAttr(f, id)
	if f.Model.Parent then
		f.Model:SetAttribute("DuelId", id)
	end
end

function Fighters.EndDuel(f)
	if not f or not f.Duel then
		return
	end
	local other = f.Duel
	f.Duel = nil
	if f.Target == other then
		f.Target = nil
	end
	setDuelAttr(f, 0)
	if other.Duel == f then
		other.Duel = nil
		if other.Target == f then
			other.Target = nil
		end
		setDuelAttr(other, 0)
	end
	Fighters.DuelEnded:Fire(f, other)
end

function Fighters.SetDuel(a, b)
	if a.Duel ~= b then
		Fighters.EndDuel(a)
	end
	if b.Duel ~= a then
		Fighters.EndDuel(b)
	end
	a.Duel = b
	b.Duel = a
	a.Target = b
	b.Target = a
	a.RetreatUntil = nil
	b.RetreatUntil = nil
	setDuelAttr(a, b.Id)
	setDuelAttr(b, a.Id)
end

-- Quem pode lutar com quem
-- ⚔️ PvP do Coliseu (2026-10, pedido do dono: "assim que você entrar na arena vai ser ativado o PvP; se o Super Boss
-- está lá eles não podem se matar, se ele não está, o PvP é ativado"): vale para todo mundo que está no chão do
-- Coliseu, sem botão e sem duelo — só não vale com o 🌍 Super Boss acordado (aí é todo mundo contra ele)
function Fighters.ColosseumPvP()
	return workspace:GetAttribute("SuperBossAwake") ~= true
end

function Fighters.Hostile(a, b)
	if a == b then
		return false
	end
	-- ✨ alvo invisível de um poder (setinha do mouse): só quem soltou o poder "luta" com ele
	if a.Dummy or b.Dummy then
		local m, other = a.Dummy and a or b, a.Dummy and b or a
		return m.Caster == other and not m.Removed and Fighters.Alive(other)
	end
	if not Fighters.Alive(a) or not Fighters.Alive(b) then
		return false
	end
	-- 🤡 clones do palhaço (CloneService): lutam como o dono — os mesmos amigos e os mesmos inimigos
	if a.CloneOf or b.CloneOf then
		local ma, mb = a.CloneOf or a, b.CloneOf or b
		return ma ~= mb and Fighters.Hostile(ma, mb)
	end
	if a.Zone ~= b.Zone or (a.Zone ~= "arena" and a.Zone ~= "boss") then
		return false
	end
	-- 🏝️ zona "arena" = área de luta; cada ilha (e o Coliseu) é separada: só briga quem está na mesma
	if a.Zone == "arena" and a.Island ~= b.Island then
		return false
	end
	if a.Zone == "arena" then
		-- 🌍 Boss do Mundo na Arena: briga com todos os cachorros de jogadores (sem duelo)
		local aBoss, bBoss = a.Kind == "boss", b.Kind == "boss"
		if aBoss or bBoss then
			return (aBoss and b.Kind == "player") or (bBoss and a.Kind == "player")
		end
		-- 😠 selvagens (2026-10, pedido do dono): brigam com QUALQUER cachorro de jogador da mesma ilha, sem
		-- precisar de duelo (vários podem atacar o mesmo jogador; o jogador acerta qualquer um deles)
		local aWild, bWild = a.Kind == "npc", b.Kind == "npc"
		if aWild and bWild then
			return false
		end
		if aWild or bWild then
			return (aWild and b.Kind == "player") or (bWild and a.Kind == "player")
		end
		-- ⚔️ dois jogadores: todos contra todos no chão do Coliseu enquanto o 🌍 Super Boss dorme; nas ilhas, nunca
		return a.Kind == "player" and b.Kind == "player" and a.Owner ~= b.Owner and a.Island == "colosseum" and Fighters.ColosseumPvP()
	end
	local aWild = a.Kind == "npc" or a.Kind == "boss"
	local bWild = b.Kind == "npc" or b.Kind == "boss"
	if aWild and bWild then
		return false
	end
	if aWild or bWild then
		return true
	end
	-- dois cachorros de jogadores: só se os dois ativaram PvP
	return a.Owner ~= b.Owner and a.Mode == "pvp" and b.Mode == "pvp"
end

function Fighters.Enemies(f, position, radius)
	local list = {}
	for _, other in pairs(Fighters.List) do
		if Fighters.Hostile(f, other) then
			if not position or Fighters.FlatDistance(other.Root.Position, position) - other.Radius <= radius then
				table.insert(list, other)
			end
		end
	end
	return list
end

function Fighters.FlatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

---------------------------------------------------------------- ações/efeitos
function Fighters.Fx(name, params)
	remotes.Effect:FireAllClients(name, params)
end

-- Pose de animação lida pelo cliente (Crouch, Howl, Rear, Roar, Open, Eat, Fly, Shadow, Dive, Spin, KO).
-- speed = velocidade da animação da pose (habilidade do jogador é mais rápida: Config.SKILL_SPEED); nil = normal
function Fighters.SetAction(f, action, duration, speed)
	if not f.Model.Parent then
		return
	end
	f.Model:SetAttribute("ActionSpeed", speed)
	f.Model:SetAttribute("Action", action)
	f.Model:SetAttribute("ActionAt", os.clock())
	if duration then
		local token = os.clock()
		f.ActionToken = token
		task.delay(duration, function()
			if f.ActionToken == token and f.Model.Parent and not f.Dead then
				f.Model:SetAttribute("Action", nil)
			end
		end)
	end
end

function Fighters.Bite(f, headIndex)
	Fighters.Fx("Bite", { Model = f.Model, Head = headIndex or math.random(1, f.Model:GetAttribute("Heads") or 1) })
end

-- 🐾 golpe de perto com animação (2026-10, pedido do dono): step 1 = pata DIREITA, 2 = pata ESQUERDA,
-- 3 = MORDIDA. Sem step: o próximo da sequência (NPCs e treino; recomeça depois de 2 s sem bater).
-- Devolve o step usado.
function Fighters.Melee(f, step)
	if not step then
		local now = os.clock()
		if now - (f.MeleeAt or 0) > 2 then
			f.MeleeStep = 0
		end
		f.MeleeAt = now
		f.MeleeStep = (f.MeleeStep or 0) % 3 + 1
		step = f.MeleeStep
	end
	Fighters.Fx("Melee", { Model = f.Model, Step = step, Head = math.random(1, f.Model:GetAttribute("Heads") or 1) })
	return step
end

---------------------------------------------------------------- ✨ alvo invisível dos poderes
-- Poder SEM inimigo (2026-10, pedido do dono): o poder é solto num alvo invisível parado onde a setinha está.
-- Ele tem só o que os poderes leem de um alvo (Root, Radius, Model, Humanoid, Stats...). Só quem soltou o
-- poder o vê como inimigo (Hostile) e golpe direto nele acerta quem estiver em volta do ponto (Damage).
-- Some no fim do poder (RemoveMarker) ou sozinho depois de 15 s.
Fighters.MARKER_HIT = 6 -- studs em volta do ponto
local markerFolder = nil
function Fighters.Marker(caster, position)
	if not (markerFolder and markerFolder.Parent) then
		markerFolder = Instance.new("Folder")
		markerFolder.Name = "AlvosDePoder"
		markerFolder.Parent = workspace
	end
	local model = Instance.new("Model")
	model.Name = "AlvoDoPoder"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new(position + Vector3.new(0, 1, 0))
	root.Parent = model
	model.PrimaryPart = root
	model.Parent = markerFolder
	local noop = function() end
	local m: any = {
		Dummy = true,
		Caster = caster,
		Kind = "dummy",
		Model = model,
		Root = root,
		Radius = 1,
		Zone = caster.Zone,
		Island = caster.Island,
		HipHeight = 0,
		FrozenUntil = 0,
		SpeedMult = 1,
		DamageTaken = 1,
		DamageDealt = 1,
		Contributions = {},
		Stats = { Speed = 0, Atk = 0, MaxHP = 1, Power = 0 },
		Humanoid = { Health = 1, MaxHealth = 1, HipHeight = 0, WalkSpeed = 0, MoveTo = noop, TakeDamage = noop },
	}
	task.delay(15, function()
		Fighters.RemoveMarker(m)
	end)
	return m
end

function Fighters.RemoveMarker(m)
	if m and not m.Removed then
		m.Removed = true
		m.Dead = true
		pcall(m.Model.Destroy, m.Model)
	end
end

-- Empurra (dash, salto, knockback) com uma velocidade fixa por alguns instantes
function Fighters.Push(f, velocity, duration)
	if not Fighters.Alive(f) then
		return
	end
	local root = f.Root
	local attachment = root:FindFirstChild("PushAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "PushAttachment"
		attachment.Parent = root
	end
	local old = root:FindFirstChild("Push")
	if old then
		old:Destroy()
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Push"
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	lv.MaxForce = math.huge
	lv.VectorVelocity = velocity
	lv.Parent = root
	task.delay(duration, function()
		if lv.Parent then
			lv:Destroy()
		end
	end)
end

function Fighters.Face(f, position)
	if not Fighters.Alive(f) then
		return
	end
	local root = f.Root
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

function Fighters.Stop(f)
	if Fighters.Alive(f) then
		f.Humanoid:MoveTo(f.Root.Position)
	end
end

function Fighters.Teleport(f, position)
	if Fighters.Alive(f) then
		f.Model:PivotTo(CFrame.new(position + Vector3.new(0, f.HipHeight + f.Root.Size.Y / 2 + 0.2, 0)) * f.Root.CFrame.Rotation)
	end
end

function Fighters.Freeze(f, seconds, kind)
	if not Fighters.Alive(f) then
		return
	end
	if f.Kind == "boss" then
		seconds *= 0.35
	end
	f.FrozenUntil = math.max(f.FrozenUntil, os.clock() + seconds)
	f.Humanoid.WalkSpeed = 0
	Fighters.Fx("Freeze", { Model = f.Model, Duration = seconds, Kind = kind or "ice" })
	task.delay(seconds, function()
		if Fighters.Alive(f) and os.clock() >= f.FrozenUntil - 0.05 then
			f.Humanoid.WalkSpeed = f.Stats.Speed * (f.SpeedMult or 1)
		end
	end)
end

function Fighters.IsFrozen(f)
	return os.clock() < (f.FrozenUntil or 0)
end

-- Muda o tamanho do cachorro (Titan Rage)
function Fighters.Scale(f, factor)
	if not Fighters.Alive(f) then
		return
	end
	f.Model:ScaleTo(factor)
	f.ScaleNow = factor
	f.Humanoid.HipHeight = f.HipHeight * factor
	f.Radius = f.Root.Size.Z / 2
end

---------------------------------------------------------------- dano
-- o cachorro de jogador por trás de um lutador (ele mesmo ou o dono do clone 🤡); nil = selvagem/boss
local function playerDog(f)
	local src = f and (f.CloneOf or f)
	return (src and src.Kind == "player") and src or nil
end

-- 🍼 reforço de iniciante (Config.ROOKIE): cachorro de jogador de level baixo bate mais e apanha menos de selvagens
-- e bosses (jogador contra jogador não muda)
function Fighters.RookieMult(attacker, target)
	local mine, theirs = playerDog(attacker), playerDog(target)
	if mine and not theirs then
		return 1 + Config.ROOKIE.Atk * Config.RookieBoost(mine.Level)
	elseif theirs and not mine then
		return 1 - Config.ROOKIE.Def * Config.RookieBoost(theirs.Level)
	end
	return 1
end

-- opts = { Knockback = Vector3, Crit = bool, Color = Color3, NoText = bool }
function Fighters.Damage(attacker, target, amount, opts)
	opts = opts or {}
	-- ✨ golpe no alvo invisível de um poder (setinha): acerta quem estiver em volta daquele ponto
	if target and target.Dummy then
		if not attacker or attacker ~= target.Caster or target.Removed then
			return 0
		end
		local total = 0
		for _, enemy in ipairs(Fighters.Enemies(attacker, target.Root.Position, Fighters.MARKER_HIT)) do
			total += Fighters.Damage(attacker, enemy, amount, table.clone(opts))
		end
		return total
	end
	if not Fighters.Alive(target) then
		return 0
	end
	-- poderes longos continuam rodando depois que o duelo acaba / o alvo vai para casa:
	-- só machuca quem ainda é inimigo de verdade
	if attacker and attacker ~= target and not Fighters.Hostile(attacker, target) then
		return 0
	end
	-- 💨 esquiva (Q) do jogador: invencível por um instante
	if target.DodgeUntil and os.clock() < target.DodgeUntil then
		Fighters.Fx("Damage", { Position = target.Root.Position + Vector3.new(0, target.Root.Size.Y, 0), Amount = "MISS", Color = Color3.fromRGB(180, 230, 255) })
		return 0
	end
	local dmg = amount * (attacker and attacker.DamageDealt or 1) * (target.DamageTaken or 1) * Fighters.RookieMult(attacker, target)
	-- 🆚 vantagem de elemento: forte = +30% ("SUPER!"), fraco = −20% ("WEAK"); aviso no máx. a cada 1,5 s por dupla
	local advantage = attacker and attacker ~= target and DogData.ElementAdvantage(attacker.SpeciesId, target.SpeciesId) or 0
	if advantage ~= 0 then
		dmg *= advantage > 0 and Config.ELEMENT_STRONG or Config.ELEMENT_WEAK
		attacker.ElementToast = attacker.ElementToast or setmetatable({}, { __mode = "k" }) -- não segura alvos que sumiram
		local now = os.clock()
		if now - (attacker.ElementToast[target] or 0) > 1.5 then
			attacker.ElementToast[target] = now
			Fighters.Fx("Damage", {
				Position = target.Root.Position + Vector3.new(0, target.Root.Size.Y + 4.5, 0),
				Amount = advantage > 0 and "SUPER!" or "WEAK",
				Color = advantage > 0 and Color3.fromRGB(255, 120, 60) or Color3.fromRGB(170, 170, 185),
			})
		end
	end
	if opts.Crit then
		dmg *= 2
	end
	dmg = math.max(1, math.floor(dmg * (0.9 + math.random() * 0.2)))
	-- 🤡 golpe de clone conta para o dono (abate, recompensa e missões)
	target.LastHitBy = attacker and attacker.CloneOf or attacker
	if attacker and attacker.Owner then
		target.Contributions[attacker.Owner] = (target.Contributions[attacker.Owner] or 0) + dmg
	end
	target.Humanoid:TakeDamage(dmg)
	-- (2026-10: o Especial da tecla 4 não enche mais batendo — tem recarga, Config.SpecialCooldown)
	if target.Humanoid.Health <= 0 then
		Fighters.Die(target)
	end
	if not opts.NoText then
		Fighters.Fx("Damage", { Position = target.Root.Position + Vector3.new(0, target.Root.Size.Y, 0), Amount = dmg, Crit = opts.Crit, Color = opts.Color })
	end
	Fighters.Fx("Hit", { Model = target.Model })
	if opts.Knockback and Fighters.Alive(target) then
		local kb = opts.Knockback
		if target.Kind == "boss" then
			kb *= 0.15
		end
		Fighters.Push(target, kb, 0.18)
	end
	return dmg
end

function Fighters.DamageArea(attacker, position, radius, amount, opts)
	opts = opts or {}
	local hits = {}
	for _, enemy in ipairs(Fighters.Enemies(attacker, position, radius)) do
		local o = table.clone(opts)
		if opts.KnockbackPower then
			local away = Vector3.new(enemy.Root.Position.X - position.X, 0, enemy.Root.Position.Z - position.Z)
			if away.Magnitude < 0.1 then
				away = Vector3.new(1, 0, 0)
			end
			o.Knockback = away.Unit * opts.KnockbackPower + Vector3.new(0, opts.Lift or 18, 0)
		end
		Fighters.Damage(attacker, enemy, amount, o)
		table.insert(hits, enemy)
	end
	return hits
end

return Fighters
