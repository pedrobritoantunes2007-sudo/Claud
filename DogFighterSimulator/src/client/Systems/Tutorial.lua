-- 🎓 TUTORIAL (2026-10, pedido do dono: "o tutorial explicando exatamente como tudo funciona, bem explicado e bem
-- feito, com várias animações, e parte por parte"). (2026-10-23: a 1ª vez virou o passeio com a guia —
-- Systems/GuideTour —; estes cartões continuam como o 📖 GUIA: tecla H e ⚙️ SETTINGS ➜ HOW TO PLAY.)
-- PARTES: 1 Bem-vindo · 2 Andar · 3 Primeiro cachorro (só quem ainda não tem) · 4 Luta · 5 Ilhas e missões ·
-- 6 Cachorros e ovos · 7 Mais diversão · fim (+$500 no TutorialService).
-- Dois tipos de passo:
--   CARTÃO (Kind "info"): janela no meio com o cachorro 3D fazendo a ação, teclas/mouse/ícones animados e o texto
--   (versão de celular quando precisa); ▶ NEXT, ◀ BACK (setas do teclado também) e "skip tutorial".
--   FAÇA (Kind "do"): painel embaixo com a tarefa; seta 👉 no botão certo do HUD/menu, ⬇ em cima do alvo no mundo
--   e linha dourada no chão até o destino. Termina SOZINHO quando o jogador faz (andar, correr, atacar, dash, falar
--   com o professor, entrar no portal, pegar missão, brigar, abrir o ovo, abrir o menu...). "▶" pula o passo.
-- O passo fica salvo na conta (data.Tutorial, remote TutorialAction; o servidor só guarda depois do 1º cachorro).
-- 📖 GUIA: depois de terminar, os cartões abrem de novo (com abas por parte) pela tecla H ou pelo botão
-- "HOW TO PLAY" das ⚙️ Settings (HUD.Toggle("Guide")).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Village = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Village"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))
local C = Kit.C
local make = Kit.make
local LUCKY = Enum.Font.LuckiestGuy

local Tutorial = {}

local player = Players.LocalPlayer

---------------------------------------------------------------- o mundo (alvos das setas e da linha dourada)
local function myRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- cachorro selvagem mais perto do meu cachorro (ou de mim)
local function nearestWild()
	local folder = workspace:FindFirstChild("Cachorros")
	local root = myRoot()
	if not (folder and root) then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("Kind") == "npc" and model.PrimaryPart and model:GetAttribute("Action") ~= "KO" then
			local d = (model.PrimaryPart.Position - root.Position).Magnitude
			if d < bestDist then
				best, bestDist = model.PrimaryPart, d
			end
		end
	end
	return best
end

-- 🌀 portal da ⚔️ ARENA no fim da rua principal da 🏡 Pawville (a vila fica longe de tudo, sem ponte)
local function arenaPortal()
	local isles = workspace:FindFirstChild("Islands")
	local village = isles and isles:FindFirstChild(Village.Id)
	local portal = village and village:FindFirstChild("ArenaPortal", true)
	return portal and portal:FindFirstChild("Swirl")
end
-- portal da 🌻 Puppy Meadows na Praça dos Portais (primeira ilha: os selvagens mais fracos)
local function puppyPortal()
	if player:GetAttribute("Island") == Village.Id then
		return arenaPortal()
	end
	local map = workspace:FindFirstChild("Map")
	local isle = map and map:FindFirstChild("IlhaPrincipal")
	local plaza = isle and isle:FindFirstChild("PracaPortais")
	local portal = plaza and plaza:FindFirstChild("Portal_common")
	return portal and portal:FindFirstChild("Swirl")
end
local function puppyPortalPos()
	local swirl = puppyPortal()
	if swirl then
		return swirl.Position - Vector3.new(0, 22, 0)
	end
	if player:GetAttribute("Island") == Village.Id then
		local P = Village.ARENA_PORTAL
		return Village.ToWorld(P.X, Village.GROUND_Y + 0.5, P.Z)
	end
	return nil
end
-- 📜 NPC das missões na entrada da ilha onde o jogador está
local function questGiver()
	local folder = workspace:FindFirstChild("QuestGivers")
	local model = folder and folder:FindFirstChild("QuestGiver_" .. (player:GetAttribute("Island") or "common"))
	return model and model:FindFirstChild("HumanoidRootPart") or nil
end
local function questGiverPos()
	local root = questGiver()
	return root and (root.Position - Vector3.new(0, 2.5, 0)) or nil
end
local function wildPos()
	local target = nearestWild()
	return target and target.Position or nil
end
-- 🎓 Prof. Barkley (o ProximityPrompt do sorteio fica nele)
local function professor()
	for _, prompt in ipairs(CollectionService:GetTagged("ProfessorPrompt")) do
		local part = prompt.Parent
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end
local function professorPos()
	local part = professor()
	return part and (part.Position - Vector3.new(0, 2.5, 0)) or nil
end

local function started()
	local p = Net.Profile
	return p ~= nil and p.Started == true
end

---------------------------------------------------------------- as partes e os passos
local PARTS = {
	welcome = { Order = 1, Name = "WELCOME", Tab = "HELLO", Color = C.Gold },
	move = { Order = 2, Name = "MOVING", Tab = "MOVE", Color = C.Blue },
	first = { Order = 3, Name = "YOUR FIRST DOG", Tab = "1ST DOG", Color = C.Pink },
	fight = { Order = 4, Name = "FIGHTING", Tab = "FIGHT", Color = C.Red },
	islands = { Order = 5, Name = "ISLANDS & MISSIONS", Tab = "ISLANDS", Color = C.Green },
	dogs = { Order = 6, Name = Config.EGGS and "DOGS & EGGS" or "DOGS & CATCHING", Tab = "DOGS", Color = C.Purple },
	more = { Order = 7, Name = "MORE FUN", Tab = "MORE", Color = C.Orange },
}
local PART_LIST = { "welcome", "move", "first", "fight", "islands", "dogs", "more" }

-- Visual: Dog = espécie ("mine" = a do jogador) + Action (pose do Animator) + Walk; Keys = teclas apertando em
-- sequência; Mouse = "left"/"right"/"wheel"; Flow = ícones aparecendo em sequência com setas; Chips = etiquetas.
-- TextTouch = texto do celular/controle. Do = função (ctx) -> true quando o jogador fez; Event/Menu/Attr = idem.
local STEPS = {
	---------------------------------------------------------------- 1. BEM-VINDO
	{
		Part = "welcome",
		Kind = "info",
		Icon = "🐶",
		Title = "WELCOME, FIGHTER!",
		Text = "In this game YOU are a DOG! Explore floating islands, battle wild dogs, collect 80+ dogs and become the strongest dog of all!",
		Visual = { Dog = "mine", Action = "Howl" },
	},
	{
		Part = "welcome",
		Kind = "info",
		Icon = "🗺️",
		Title = "HOW IT WORKS",
		Text = "1) Get a dog  2) Take MISSIONS on the islands  3) Win fights for 💵 Cash and ⭐ XP  4) Level up, unlock POWERS and CATCH rarer dogs!",
		Visual = { Flow = { "🐶", "📜", "⚔️", "⭐" }, Dog = "mine", Action = "Victory" },
	},
	---------------------------------------------------------------- 2. ANDAR
	{
		Part = "move",
		Kind = "info",
		Icon = "⌨️",
		Title = "MOVE AROUND",
		Text = "W A S D to walk, SPACE to jump and hold SHIFT to RUN fast!",
		TextTouch = "Use the JOYSTICK to walk, ⤴ to jump and the RUN button to run fast!",
		Visual = { Keys = { "W", "A", "S", "D", "Space", "Shift" }, Dog = "mine", Walk = true },
	},
	{
		Part = "move",
		Kind = "do",
		Icon = "🚶",
		Title = "TRY IT!",
		Text = "Walk around a little",
		Moved = 25,
	},
	{
		Part = "move",
		Kind = "do",
		Icon = "🏃",
		Title = "NOW RUN!",
		Text = "Hold SHIFT while walking",
		TextTouch = "Tap RUN and walk",
		Run = true,
	},
	{
		Part = "move",
		Kind = "info",
		Icon = "🎥",
		Title = "THE CAMERA",
		Text = "Hold the RIGHT mouse button and drag to turn the camera, scroll to zoom. Press CTRL for CAMERA LOCK: the camera follows the mouse and a cross in the middle shows where you aim!",
		TextTouch = "Drag the screen with your finger to turn the camera. Pinch to zoom in and out.",
		Visual = { Mouse = "right", Keys = { "Ctrl" }, Dog = "mine", Action = "Sniff" },
	},
	---------------------------------------------------------------- 3. PRIMEIRO CACHORRO (só quem ainda não tem)
	{
		Part = "first",
		Kind = "info",
		Icon = "🎓",
		Title = "YOUR FIRST DOG",
		Text = "🎓 Prof. Barkley gives every new fighter a dog! Follow the golden paws to his kennel here in 🏡 Pawville and talk to him. You get 3 spins to choose!",
		Visual = { Dog = "caramelo", Action = "Bark", Flow = { "🎓", "🎰", "🐶" } },
		Only = function()
			return not started()
		end,
	},
	{
		Part = "first",
		Kind = "do",
		Icon = "🎓",
		Title = "MEET PROF. BARKLEY",
		Text = "Follow the golden line and talk to him",
		Path = professorPos,
		Mark = professor,
		Do = started,
		NoSkip = true,
		Only = function()
			return not started()
		end,
	},
	---------------------------------------------------------------- 4. LUTA
	{
		Part = "fight",
		Kind = "info",
		Icon = "⚔️",
		Title = "ATTACK & COMBO",
		Text = "CLICK (or press 1) to attack. 3 hits in a row make a COMBO: right paw, left paw and a BIG BITE that throws the enemy away!",
		TextTouch = "Tap the ATTACK button. 3 hits in a row make a COMBO: right paw, left paw and a BIG BITE!",
		Visual = { Mouse = "left", Keys = { "1" }, Flow = { "🐾", "🐾", "💥" }, Dog = "mine", Action = "Dash" },
	},
	{
		Part = "fight",
		Kind = "info",
		Icon = "🎯",
		Title = "AIM WHERE YOU WANT",
		Text = "Attacks and powers go where your CURSOR points. Point at the enemy and hit! Nothing aims by itself.",
		TextTouch = "Attacks go where your JOYSTICK points (standing still: where the camera looks).",
		Visual = { Flow = { "🖱️", "➜", "🎯", "🐺" }, Dog = "mine", Action = "Aim" },
	},
	{
		Part = "fight",
		Kind = "do",
		Icon = "🐾",
		Title = "ATTACK!",
		Text = "Click (or 1) three times: paw, paw, BITE!",
		TextTouch = "Tap ATTACK three times: paw, paw, BITE!",
		Attr = "CD1",
		Count = 3,
		Only = started,
	},
	{
		Part = "fight",
		Kind = "info",
		Icon = "💨",
		Title = "DASH",
		Text = "Press Q to DASH where you are walking. Dash THROUGH enemies to hit them, or dash away to dodge their attacks!",
		TextTouch = "Tap DASH to dash where your joystick points. Dash through enemies to hit them, or away to dodge!",
		Visual = { Keys = { "Q" }, Dog = "mine", Action = "Dash" },
	},
	{
		Part = "fight",
		Kind = "do",
		Icon = "💨",
		Title = "DASH!",
		Text = "Walk and press Q",
		TextTouch = "Tap DASH",
		Attr = "CD4",
		Count = 1,
		Only = started,
	},
	{
		Part = "fight",
		Kind = "info",
		Icon = "✨",
		Title = "POWERS",
		Text = "Keys 2, 3 and 4 are POWERS: they unlock as your dog levels up — Common dogs at Lv.3 and Lv.5, rarer dogs later (key 4 = SUPREME, Epic dogs and up). Powers land where you aim and need a moment to recharge.",
		TextTouch = "The 2, 3 and 4 buttons are POWERS: they unlock as your dog levels up (Common dogs at Lv.3 and Lv.5). Powers land where you aim and need a moment to recharge.",
		Visual = { Keys = { "2", "3", "4" }, Flow = { "🔒", "⚡", "🔥", "👑" }, Dog = "mine", Action = "Roar" },
	},
	{
		Part = "fight",
		Kind = "info",
		Icon = "🆚",
		Title = "ELEMENTS",
		Text = "Every dog has ELEMENTS. Hit an element you are strong against = SUPER! (+30% damage). Hit one you are weak against = WEAK. Check them in 🐶 DOGS!",
		Visual = { Chips = { { "🔥 FIRE", C.Orange }, { "❄️ ICE", C.Blue }, { "⚡ THUNDER", C.Gold }, { "🌿 NATURE", C.Green } }, Dog = "mine", Action = "Charge" },
	},
	---------------------------------------------------------------- 5. ILHAS E MISSÕES
	{
		Part = "islands",
		Kind = "info",
		Icon = "🌀",
		Title = "FLOATING ISLANDS",
		Text = "The PORTALS on the Main Island take you to the islands. Each island has its own wild dogs: the farther, the stronger! To open the next island: level up your dog, do MISSIONS, beat the island CHAMPION and pay the Cash. See it all in the MAP!",
		Visual = { Flow = { "🏝️", "🌀", "🌻", "🌋", "☁️" }, Dog = "mine", Walk = true },
	},
	{
		Part = "islands",
		Kind = "do",
		Icon = "🌀",
		Title = "GO EXPLORE!",
		Text = "Take the portal to 🌻 Puppy Meadows",
		Path = puppyPortalPos,
		Mark = puppyPortal,
		Do = function()
			return player:GetAttribute("Island") == "common"
		end,
		Only = started,
	},
	{
		Part = "islands",
		Kind = "info",
		Icon = "📜",
		Title = "MISSIONS = MONEY",
		Text = "Talk to the ❗ MISSION NPC at the entrance of each island. Missions pay lots of 💵 Cash and XP. Beating wild dogs without a mission gives only a little!",
		Visual = { Flow = { "❗", "📜", "💵" }, Dog = "mine", Action = "Sniff" },
	},
	{
		Part = "islands",
		Kind = "do",
		Icon = "📜",
		Title = "GET A MISSION",
		Text = "Talk to the ❗ Mission NPC and pick a mission",
		Path = questGiverPos,
		Mark = questGiver,
		Do = function()
			return player:GetAttribute("QuestText") ~= nil
		end,
		Only = started,
	},
	{
		Part = "islands",
		Kind = "do",
		Icon = "🥊",
		Title = "FIGHT!",
		Text = "Walk to a wild dog ⬇ — it will attack you! Hit it back",
		Path = wildPos,
		Mark = nearestWild,
		Event = "Duel",
		Only = started,
	},
	{
		Part = "islands",
		Kind = "info",
		Icon = "👑",
		Title = "ISLAND CHAMPIONS",
		Text = "Every island has a giant 👑 CHAMPION on its stage. Beat it in a BOSS mission for huge rewards! Your health comes back by itself when you are out of a fight.",
		Visual = { Flow = { "👑", "⚔️", "🏆" }, Dog = "mine", Action = "Roar" },
	},
	---------------------------------------------------------------- 6. CACHORROS E OVOS
	-- 🦮 (2026-10-25) cachorro novo agora é capturado com coleira (Systems/Catch); ovo e roleta viraram extra
	{
		Part = "dogs",
		Kind = "info",
		Icon = "🦮",
		Title = "CATCH DOGS!",
		Text = "Fight a wild dog and make it WEAK, then press CATCH (G) to throw a 🐾 LEASH! Less health = easier. Buy leashes at the 🐾 LEASH SHOP in Pawville or from the ❗ mission dog-keeper on each island.",
		Visual = { Flow = { "⚔️", "🐾", "🦮", "🐶" }, Chips = { { "NORMAL", Color3.fromRGB(70, 140, 235) }, { "SUPER", Color3.fromRGB(170, 90, 240) }, { "GOLDEN", Color3.fromRGB(240, 180, 40) } }, Dog = "mine", Action = "Wiggle" },
	},
	{
		Part = "dogs",
		Kind = "info",
		Icon = "🥚",
		Egg = true,
		Title = "EGGS",
		Text = "Buy EGGS in 🎒 EGGS with Cash. Each egg can hatch dogs of different rarities: Common, Uncommon, Rare, Epic, Legendary, Mythic... and 🎃 HALLOWEEN!",
		Visual = { Flow = { "🥚", "💥", "🐶" }, Chips = { { "RARE", Color3.fromRGB(70, 160, 255) }, { "EPIC", Color3.fromRGB(180, 90, 255) }, { "MYTHIC", Color3.fromRGB(255, 60, 110) } }, Dog = "mine", Action = "Wiggle" },
	},
	{
		Part = "dogs",
		Kind = "info",
		Icon = "🎰",
		Title = "DOG ROULETTE",
		Text = "Talk to 🎓 Prof. Barkley in Pawville to spin the DOG ROULETTE: 1 FREE spin every day! Every dog can drop. 🍀 LUCKY SPINS have no Commons and way more Legendary and Mythic dogs.",
		Visual = { Flow = { "🎓", "🎰", "🍀", "🐉" }, Dog = "dragon_hound", Action = "Victory" },
	},
	{
		Part = "dogs",
		Kind = "do",
		Icon = "🎁",
		Egg = true,
		Title = "FREE EGG!",
		Text = "🎒 EGGS ➜ OPEN your free egg",
		Target = "Inventario",
		Inner = "TutOpenEgg",
		Event = "Hatched",
		Only = started,
	},
	{
		Part = "dogs",
		Kind = "do",
		Icon = "🐶",
		Title = "YOUR DOGS",
		Text = "Open 🐶 DOGS to see and equip your dogs",
		Target = "Dogs",
		Menu = "Dogs",
		Only = started,
	},
	{
		Part = "dogs",
		Kind = "info",
		Icon = "⭐",
		Title = "LEVEL UP",
		Text = "Fights and missions give XP. Every level makes your dog stronger, and it earns a ★ STAR at Lv.10, 25, 50, 75 and 100. Rarer dogs are MUCH stronger!",
		Visual = { Flow = { "⭐", "⬆️", "💪" }, Dog = "mine", Action = "Victory" },
	},
	---------------------------------------------------------------- 7. MAIS DIVERSÃO
	{
		Part = "more",
		Kind = "info",
		Icon = "🦅",
		Title = "FLY!",
		Text = "Dogs with WINGS can fly: press F. Steer with the mouse, W to go fast, let go of W to HOVER in the air — and you can use powers while flying!",
		TextTouch = "Dogs with WINGS can fly: tap FLY. Steer with the joystick, and you can use powers while flying!",
		Visual = { Keys = { "F", "W", "Shift", "Space", "C" }, Dog = "dragon_hound", Action = "Fly" },
	},
	{
		Part = "more",
		Kind = "info",
		Icon = "⚔️",
		Title = "THE COLOSSEUM",
		Text = "Inside the COLOSSEUM it's PvP: everyone against everyone! Every 30 minutes the 🌍 SUPER BOSS wakes up for 10 minutes: PvP stops and everybody fights the boss together!",
		Visual = { Flow = { "🏟️", "⚔️", "🌍" }, Dog = "mine", Action = "Roar" },
	},
	{
		Part = "more",
		Kind = "info",
		Icon = "🎃",
		Title = "HALLOWEEN!",
		Text = "The SPOOKY CLOWN fights with 2 CLONES that copy every attack, dash and power! Find him in the 🎃 Spooky Egg.",
		Visual = { Dog = "clown_dog", Action = "Summon", Flow = { "🤡", "🤡", "🤡" } },
	},
	{
		Part = "more",
		Kind = "info",
		Icon = "🧍",
		Title = "HUMAN MODE",
		Text = "Press Z to walk as a person (your dog waits) and Z again to be a dog. Trade dogs with friends in 🤝 TRADE and type 🎟️ CODES for gifts!",
		TextTouch = "Tap HUMAN to walk as a person and again to be a dog. Trade dogs with friends in 🤝 TRADE and type 🎟️ CODES for gifts!",
		Visual = { Keys = { "Z" }, Flow = { "🧍", "⇄", "🐶" }, Dog = "mine", Action = "Sit" },
	},
	{
		Part = "more",
		Kind = "do",
		Icon = "📜",
		Title = "DAILY QUESTS",
		Text = "Open QUESTS: free rewards every day!",
		Target = "Missoes",
		Menu = "Missoes",
		Only = started,
	},
	{
		Part = "more",
		Kind = "info",
		Icon = "🏆",
		Title = "YOU'RE READY!",
		Text = "🎁 +$500 Cash to start! Press H anytime (or ⚙️ SETTINGS ➜ HOW TO PLAY) to see this guide again. Have fun and collect them all!",
		TextTouch = "🎁 +$500 Cash to start! Open ⚙️ SETTINGS ➜ HOW TO PLAY anytime to see this guide again. Have fun!",
		GuideText = "That's everything! Come back to this guide anytime with H or ⚙️ SETTINGS ➜ HOW TO PLAY. Have fun and collect them all!",
		Visual = { Flow = { "🏆", "🐶", "🎉" }, Dog = "mine", Action = "Victory" },
		Finish = true,
	},
}
-- 🥚 (2026-10-25) sem ovos (Config.EGGS = false) os cartões de ovo saem do guia
if not Config.EGGS then
	for i = #STEPS, 1, -1 do
		if STEPS[i].Egg then
			table.remove(STEPS, i)
		end
	end
end

local function send(action, value)
	local remote = Net.Remotes:FindFirstChild("TutorialAction")
	if remote then
		remote:FireServer(action, value)
	end
end

local function sfx(name)
	local module = script.Parent:FindFirstChild("Sfx")
	if module then
		pcall(function()
			require(module).Play(name)
		end)
	end
end

local function touch()
	return Kit.IsTouch() or Kit.IsGamepad()
end

local function textOf(step, guide: boolean?)
	return (guide and step.GuideText) or (touch() and step.TextTouch) or step.Text
end

---------------------------------------------------------------- tela
local ui = nil -- montada na 1ª vez (tutorial ou guia)

local function buildUI(HUD)
	local playerGui = player:WaitForChild("PlayerGui")
	local gui, root = Kit.Screen("Tutorial", 35) -- abaixo da tela de chocar ovo (40)
	local u = { Gui = gui, Root = root }

	---------------------------------------------------------------- CARTÃO (info)
	local dim = make("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 6, 24),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 1,
	}, gui)
	local card = Kit.Panel(root, {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(700, 430),
		Visible = false,
		ZIndex = 2,
	})
	local header = make("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = C.Gold, BorderSizePixel = 0, ZIndex = 3 }, card)
	Kit.Corner(header, 20)
	make("Frame", { Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = C.Gold, BorderSizePixel = 0, ZIndex = 3 }, header).Name = "Square"
	local partLabel = Kit.Text(header, {
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.new(1, -36, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = LUCKY,
		ZIndex = 4,
	})
	local barBack = make("Frame", {
		Position = UDim2.fromOffset(18, 58),
		Size = UDim2.new(1, -36, 0, 8),
		BackgroundColor3 = C.Dark,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, card)
	Kit.Corner(barBack, 4)
	local barFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold, BorderSizePixel = 0, ZIndex = 4 }, barBack)
	Kit.Corner(barFill, 4)
	-- abas das partes (só no guia)
	local tabs = make("Frame", {
		Position = UDim2.new(0, 18, 0, -46),
		Size = UDim2.new(1, -36, 0, 40),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 3,
	}, card)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }, tabs)
	-- cachorro 3D
	local stage = make("Frame", {
		Position = UDim2.fromOffset(18, 80),
		Size = UDim2.fromOffset(260, 260),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, card)
	Kit.Corner(stage, 18)
	Kit.Stroke(stage, C.Dark, 3)
	Kit.Gradient(stage, Color3.fromRGB(150, 205, 255), Color3.fromRGB(95, 75, 160)) -- céu (o degradê multiplica o fundo branco)
	local floor = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(0.8, 0, 0, 30),
		BackgroundColor3 = Color3.fromRGB(110, 200, 110),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, stage)
	Kit.Corner(floor, 999)
	local okView, view = pcall(Kit.DogViewport, stage, { Size = UDim2.fromScale(1, 1), ZIndex = 4 })
	if not okView then
		view = nil
	end
	local bigIcon = Kit.Text(card, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(268, 92),
		Size = UDim2.fromOffset(74, 74),
		Text = "",
		ZIndex = 6,
	})
	local iconScale = make("UIScale", {}, bigIcon)
	local titleLabel = Kit.Text(card, {
		Position = UDim2.fromOffset(300, 82),
		Size = UDim2.fromOffset(380, 46),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Gold,
		Font = LUCKY,
		ZIndex = 3,
	})
	Kit.Thick(titleLabel, 3)
	local bodyLabel = Kit.Text(card, {
		Position = UDim2.fromOffset(300, 134),
		Size = UDim2.fromOffset(380, 116),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 3,
	})
	make("UITextSizeConstraint", { MaxTextSize = 26 }, bodyLabel)
	local visual = make("Frame", {
		Position = UDim2.fromOffset(300, 258),
		Size = UDim2.fromOffset(380, 84),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, card)
	local nextButton = Kit.Button(card, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -16),
		Size = UDim2.fromOffset(180, 58),
		Text = "NEXT ▶",
		ZIndex = 4,
	}, C.Green)
	local backButton = Kit.Button(card, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -18),
		Size = UDim2.fromOffset(116, 48),
		Text = "◀ BACK",
		ZIndex = 4,
	}, C.Panel2)
	local skipButton = Kit.Button(card, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -40, 1, -24),
		Size = UDim2.fromOffset(170, 34),
		Text = "skip tutorial ✕",
		ZIndex = 4,
	}, C.Panel2)

	---------------------------------------------------------------- PAINEL "FAÇA" (do)
	local panel = Kit.Panel(root, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -112),
		Size = UDim2.fromOffset(520, 96),
		Visible = false,
		ZIndex = 2,
	})
	local pIcon = Kit.Text(panel, { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(76, 76), Text = "", ZIndex = 3 })
	local pIconScale = make("UIScale", {}, pIcon)
	local pPart = Kit.Text(panel, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 0, -4),
		Size = UDim2.fromOffset(300, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	local pTitle = Kit.Text(panel, {
		Position = UDim2.fromOffset(94, 10),
		Size = UDim2.new(1, -230, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Gold,
		Font = LUCKY,
		ZIndex = 3,
	})
	local pBody = Kit.Text(panel, {
		Position = UDim2.fromOffset(94, 46),
		Size = UDim2.new(1, -230, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		ZIndex = 3,
	})
	make("UITextSizeConstraint", { MaxTextSize = 22 }, pBody)
	local pCount = Kit.Text(panel, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -136, 0.5, 0),
		Size = UDim2.fromOffset(60, 40),
		Text = "",
		TextColor3 = C.Cash,
		ZIndex = 3,
	})
	local pSkip = Kit.Button(panel, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(110, 54),
		Text = "skip ▶",
		ZIndex = 3,
	}, C.Panel2)

	-- seta 👉 que aponta botões (HUD e dentro dos menus)
	local arrowGui = Kit.Gui("TutorialArrow", 36)
	local arrow = Kit.Text(arrowGui, { AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(64, 64), Text = "👉", Visible = false })
	local highlight = Instance.new("UIStroke")
	highlight.Thickness = 5
	highlight.Color = C.Gold
	highlight.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	-- seta ⬇ em cima do alvo no mundo
	local mark = Instance.new("BillboardGui")
	mark.Size = UDim2.fromOffset(80, 80)
	mark.StudsOffset = Vector3.new(0, 5, 0)
	mark.AlwaysOnTop = true
	mark.LightInfluence = 0
	mark:SetAttribute("MobileScaled", true)
	local markText = Kit.Text(mark, { Size = UDim2.fromScale(1, 1), Text = "⬇", TextColor3 = C.Gold })

	-- linha dourada no chão: do jogador até o destino
	local pathFolder = Instance.new("Folder")
	pathFolder.Name = "TutorialPath"
	local anchorPart = Instance.new("Part")
	anchorPart.Anchored = true
	anchorPart.CanCollide = false
	anchorPart.CanQuery = false
	anchorPart.CanTouch = false
	anchorPart.Transparency = 1
	anchorPart.Size = Vector3.new(0.2, 0.2, 0.2)
	anchorPart.Parent = pathFolder
	local a1 = Instance.new("Attachment")
	a1.Parent = anchorPart
	local beam = Instance.new("Beam")
	beam.Attachment1 = a1
	beam.Width0, beam.Width1 = 1.4, 1.4
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(C.Gold)
	beam.LightEmission = 1
	beam.Segments = 20
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.Parent = anchorPart

	u.Dim, u.Card, u.Header, u.HeaderSquare, u.PartLabel = dim, card, header, header:FindFirstChild("Square"), partLabel
	u.BarFill, u.Tabs, u.View, u.BigIcon, u.IconScale = barFill, tabs, view, bigIcon, iconScale
	u.TitleLabel, u.BodyLabel, u.Visual = titleLabel, bodyLabel, visual
	u.Next, u.Back, u.Skip = nextButton, backButton, skipButton
	u.Panel, u.PIcon, u.PIconScale, u.PPart, u.PTitle, u.PBody, u.PCount, u.PSkip = panel, pIcon, pIconScale, pPart, pTitle, pBody, pCount, pSkip
	u.ArrowGui, u.Arrow, u.Highlight, u.Mark, u.MarkText = arrowGui, arrow, highlight, mark, markText
	u.PathFolder, u.AnchorPart, u.Beam = pathFolder, anchorPart, beam
	u.PlayerGui = playerGui
	u.HUD = HUD
	return u
end

---------------------------------------------------------------- desenhos animados do cartão
local animToken = 0
local LOOPING = { Fly = true, Float = true, Sit = true, Sniff = true, Aim = true, Snore = true }

local function keyCap(parent, key, x)
	local wide = #key > 1
	local w = wide and (key == "Space" and 108 or 70) or 50
	local cap = make("Frame", {
		Position = UDim2.fromOffset(x, 18),
		Size = UDim2.fromOffset(w, 50),
		BackgroundColor3 = Color3.fromRGB(235, 232, 245),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, parent)
	Kit.Corner(cap, 10)
	Kit.Stroke(cap, C.Dark, 3)
	Kit.Gradient(cap, Color3.new(1, 1, 1), Color3.fromRGB(180, 176, 200))
	Kit.Text(cap, { Size = UDim2.fromScale(1, 1), Text = string.upper(key), TextColor3 = C.Ink, Outline = false, ZIndex = 5, Font = LUCKY })
	local scale = make("UIScale", {}, cap)
	return cap, w, scale
end

local function mouseIcon(parent, x, which)
	local body = make("Frame", {
		Position = UDim2.fromOffset(x, 6),
		Size = UDim2.fromOffset(48, 72),
		BackgroundColor3 = Color3.fromRGB(235, 232, 245),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, parent)
	Kit.Corner(body, 22)
	Kit.Stroke(body, C.Dark, 3)
	local buttons = {}
	for i, side in ipairs({ "left", "right" }) do
		local b = make("Frame", {
			Position = UDim2.fromOffset((i - 1) * 24 + 3, 3),
			Size = UDim2.fromOffset(18, 30),
			BackgroundColor3 = Color3.fromRGB(200, 196, 215),
			BorderSizePixel = 0,
			ZIndex = 5,
		}, body)
		Kit.Corner(b, 9)
		buttons[side] = b
	end
	local wheel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(6, 16),
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, body)
	Kit.Corner(wheel, 3)
	buttons.wheel = wheel
	return body, buttons[which] or buttons.left
end

-- monta o desenho do passo e anima em loop até o próximo cartão
local function showVisual(u, step)
	animToken += 1
	local token = animToken
	u.Visual:ClearAllChildren()
	local vis = step.Visual or {}
	-- 🐶 cachorro 3D fazendo a ação
	if u.View then
		local species = vis.Dog
		if species == "mine" or not species then
			local eq = Net.Equipped()
			species = eq and eq.Species or "caramelo"
		end
		if u.ViewSpecies ~= species then
			u.ViewSpecies = species
			pcall(u.View.SetSpecies, species)
		end
		u.View.Spin = not vis.Walk
		u.View.Walk = vis.Walk == true
		u.View.Angle = vis.Walk and 1.2 or 0.6
		u.View.SetAction(nil)
		-- ações de uma vez (bote, latido, uivo...) repetem a cada 3 s; as contínuas (voar, sentar) ficam
		local action = vis.Action
		task.spawn(function()
			task.wait(0.25)
			while animToken == token and action do
				u.View.SetAction(action)
				if LOOPING[action] then
					return
				end
				task.wait(2.8)
				if animToken ~= token then
					return
				end
				u.View.SetAction(nil)
				task.wait(0.2)
			end
		end)
	end
	local x = 0
	-- ⌨️ teclas apertando uma de cada vez (em loop)
	local caps = {}
	if vis.Keys and not touch() then
		for _, key in ipairs(vis.Keys) do
			local cap, w, scale = keyCap(u.Visual, key, x)
			table.insert(caps, { Frame = cap, Scale = scale })
			x += w + 8
		end
	end
	-- 🖱️ mouse com o botão piscando
	local mouseButton = nil
	if vis.Mouse and not touch() then
		local _, b = mouseIcon(u.Visual, x + 4, vis.Mouse)
		mouseButton = b
		x += 60
	end
	-- ➜ ícones aparecendo em sequência (ou etiquetas)
	local flow = {}
	if vis.Flow then
		local left = x > 0 and x + 6 or 0
		local spacing = math.min(64, (380 - left) / math.max(1, #vis.Flow))
		for i, icon in ipairs(vis.Flow) do
			local label = Kit.Text(u.Visual, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(left + (i - 0.5) * spacing, 42),
				Size = UDim2.fromOffset(spacing - 6, spacing - 6),
				Text = icon,
				ZIndex = 4,
			})
			local scale = make("UIScale", { Scale = 0 }, label)
			table.insert(flow, scale)
		end
	elseif vis.Chips then
		local cx = x
		for _, chip in ipairs(vis.Chips) do
			local w = 18 + #chip[1] * 9
			Kit.Chip(u.Visual, { Position = UDim2.fromOffset(cx, 24), Size = UDim2.fromOffset(w, 34), ZIndex = 4 }, chip[2], chip[1])
			cx += w + 6
		end
	end
	-- os ícones entram um de cada vez; depois um deles "pula" por vez, junto com a tecla apertada
	for i, s in ipairs(flow) do
		task.delay((i - 1) * 0.22, function()
			if animToken == token then
				Kit.Tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end)
	end
	task.spawn(function()
		task.wait(#flow * 0.22 + 0.3)
		local k = 0
		while animToken == token do
			k += 1
			if #flow > 0 then
				local s = flow[(k - 1) % #flow + 1]
				s.Scale = 1.25
				Kit.Tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			end
			if #caps > 0 then
				local cap = caps[(k - 1) % #caps + 1]
				cap.Frame.BackgroundColor3 = C.Gold
				Kit.Tween(cap.Scale, 0.08, { Scale = 0.86 })
				sfx("Click")
				task.wait(0.18)
				if animToken ~= token then
					return
				end
				Kit.Tween(cap.Scale, 0.16, { Scale = 1 }, Enum.EasingStyle.Back)
				cap.Frame.BackgroundColor3 = Color3.fromRGB(235, 232, 245)
			end
			if mouseButton then
				mouseButton.BackgroundColor3 = C.Gold
				task.delay(0.2, function()
					if mouseButton.Parent then
						mouseButton.BackgroundColor3 = Color3.fromRGB(200, 196, 215)
					end
				end)
			end
			task.wait(0.55)
		end
	end)
end

---------------------------------------------------------------- o tutorial em si
local running = nil -- estado do tutorial/guia aberto

local function partSteps(guide)
	local list = {}
	for i, step in ipairs(STEPS) do
		if not guide or step.Kind == "info" then
			table.insert(list, i)
		end
	end
	return list
end

local function run(HUD, guide: boolean, startAt: number?)
	if running then
		return
	end
	ui = ui or buildUI(HUD)
	local u = ui
	u.Gui.Enabled = true
	u.ArrowGui.Enabled = true
	local order = partSteps(guide)
	local pos = 1
	if startAt then
		for i, idx in ipairs(order) do
			if idx >= startAt then
				pos = i
				break
			end
		end
	end
	local st: { [string]: any } = { Guide = guide, Finished = false, Count = 0, Moved = 0 }
	local a0: Attachment? = nil -- começo da linha dourada (no jogador; refeito quando o personagem nasce de novo)
	running = st
	local conns = {}

	local function stepAt(p)
		return STEPS[order[p]]
	end
	-- passos que não valem agora (ex.: "primeiro cachorro" para quem já tem) são pulados
	local function valid(p)
		local step = stepAt(p)
		return step and (guide or not step.Only or step.Only())
	end

	local function close(reason)
		if st.Finished then
			return
		end
		st.Finished = true
		running = nil
		animToken += 1
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		u.Gui.Enabled = false
		u.ArrowGui.Enabled = false
		u.Card.Visible = false
		u.Panel.Visible = false
		u.Dim.Visible = false
		u.Arrow.Visible = false
		u.Highlight.Parent = nil
		u.Mark.Parent = nil
		u.PathFolder.Parent = nil
		if a0 then
			a0:Destroy()
			a0 = nil
		end
		if u.View then
			pcall(u.View.SetSpecies, nil)
			u.ViewSpecies = nil
		end
		if not guide then
			if reason == "finish" then
				send("finish")
			elseif reason == "skip" then
				send("skip")
			end
		elseif not st.FromMenu and HUD.IsOpen("Guide") then
			HUD.Toggle("Guide")
		end
	end
	st.Close = close

	local show

	local function go(delta)
		local p = pos + delta
		while p >= 1 and p <= #order and not valid(p) do
			p += delta
		end
		if p < 1 then
			return
		end
		if p > #order then
			close(guide and "guide" or "finish")
			return
		end
		pos = p
		if not guide then
			send("step", order[pos])
		end
		show()
	end

	local function partHeader(step)
		local part = PARTS[step.Part]
		local total = #PART_LIST
		local n = part.Order
		if not guide and started() then
			-- (quem já tem cachorro não vê a parte 3)
			total -= 1
			if n > PARTS.first.Order then
				n -= 1
			end
		end
		return part, string.format("PART %d/%d · %s", n, total, part.Name)
	end

	function show()
		local step = stepAt(pos)
		local part, label = partHeader(step)
		st.Count, st.Moved, st.LastPos = 0, 0, nil
		u.Arrow.Visible = false
		u.Highlight.Parent = nil
		if step.Kind == "info" then
			st.CardHidden = false
			u.Panel.Visible = false
			u.Dim.Visible = true
			u.Card.Visible = true
			u.Header.BackgroundColor3 = part.Color
			if u.HeaderSquare then
				u.HeaderSquare.BackgroundColor3 = part.Color
			end
			u.PartLabel.Text = label
			u.BarFill.BackgroundColor3 = part.Color
			Kit.Tween(u.BarFill, 0.35, { Size = UDim2.fromScale(pos / #order, 1) })
			u.BigIcon.Text = step.Icon
			u.TitleLabel.Text = step.Title
			u.BodyLabel.Text = textOf(step, guide)
			u.Next.Text = step.Finish and "FINISH ✔" or "NEXT ▶"
			u.Back.Visible = pos > 1
			u.Skip.Text = guide and "close ✕" or "skip tutorial ✕"
			u.Skip.Visible = guide or Config.TUTORIAL_SKIP == true -- (2026-10-25: o tutorial não pode ser pulado)
			u.IconScale.Scale = 0.3
			Kit.Tween(u.IconScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			Kit.Pop(u.Card, true)
			showVisual(u, step)
			-- abas das partes (guia)
			u.Tabs.Visible = guide
			if guide then
				u.Tabs:ClearAllChildren()
				make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }, u.Tabs)
				for _, id in ipairs(PART_LIST) do
					local p = PARTS[id]
					local tab = Kit.Button(u.Tabs, { Size = UDim2.fromOffset(88, 36), Text = p.Tab, ZIndex = 4 }, id == step.Part and p.Color or C.Panel2)
					tab.Activated:Connect(function()
						for i, idx in ipairs(order) do
							if STEPS[idx].Part == id then
								pos = i
								show()
								return
							end
						end
					end)
				end
			end
		else
			animToken += 1
			u.Card.Visible = false
			u.Dim.Visible = false
			u.Panel.Visible = true
			u.PIcon.Text = step.Icon
			u.PTitle.Text = step.Title
			u.PBody.Text = textOf(step)
			u.PPart.Text = label
			u.PPart.TextColor3 = part.Color
			u.PCount.Text = step.Count and step.Count > 1 and ("0/" .. step.Count) or ""
			u.PIconScale.Scale = 0.4
			Kit.Tween(u.PIconScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			Kit.Pop(u.Panel, true)
		end
		sfx("Quest")
	end

	table.insert(conns, u.Next.Activated:Connect(function()
		local step = stepAt(pos)
		if step and step.Kind == "info" then
			if step.Finish then
				sfx("Purchase")
				Kit.Burst(u.Root, UDim2.fromScale(0.5, 0.5), C.Gold, 26, { "★", "🐾", "✦", "🎉" }, 240)
			end
			go(1)
		end
	end))
	table.insert(conns, u.Back.Activated:Connect(function()
		go(-1)
	end))
	table.insert(conns, u.Skip.Activated:Connect(function()
		if not guide and not Config.TUTORIAL_SKIP then
			return
		end
		close(guide and "guide" or "skip")
	end))
	table.insert(conns, u.PSkip.Activated:Connect(function()
		go(1)
	end))
	-- teclado: → / Enter = próximo, ← = voltar, H/Esc fecham o guia
	table.insert(conns, UserInputService.InputBegan:Connect(function(input, processed)
		if processed or st.Finished then
			return
		end
		local step = stepAt(pos)
		if not (step and step.Kind == "info") then
			return
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.Right or k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA then
			go(1)
		elseif k == Enum.KeyCode.Left or k == Enum.KeyCode.ButtonB then
			go(-1)
		elseif guide and (k == Enum.KeyCode.Escape) then
			close("guide")
		end
	end))

	---------------------------------------------------------------- ações que completam os passos "faça"
	local function eventDone(kind)
		local step = stepAt(pos)
		if not st.Finished and step and step.Kind == "do" and step.Event == kind then
			go(1)
		end
	end
	table.insert(conns, Net.Remotes:WaitForChild("Hatched").OnClientEvent:Connect(function()
		eventDone("Hatched")
	end))
	table.insert(conns, HUD.MenuChanged:Connect(function(name)
		local step = stepAt(pos)
		if not st.Finished and name and step and step.Kind == "do" and step.Menu == name then
			go(1)
		end
	end))
	local function watchDog(model)
		if not model:IsA("Model") then
			return
		end
		table.insert(conns, model:GetAttributeChangedSignal("DuelId"):Connect(function()
			local id = model:GetAttribute("DuelId")
			if model:GetAttribute("Owner") == player.UserId and typeof(id) == "number" and id ~= 0 then
				eventDone("Duel")
			end
		end))
	end
	for _, model in ipairs(CollectionService:GetTagged("Dog")) do
		watchDog(model)
	end
	table.insert(conns, CollectionService:GetInstanceAddedSignal("Dog"):Connect(watchDog))
	-- atributos de recarga (CD1 = golpe, CD4 = dash): cada mudança = uma vez que o jogador usou
	local function attrChanged(name)
		local step = stepAt(pos)
		if st.Finished or not (step and step.Kind == "do" and step.Attr == name) then
			return
		end
		st.Count += 1
		u.PCount.Text = (step.Count or 1) > 1 and (math.min(st.Count, step.Count) .. "/" .. step.Count) or ""
		Kit.Pop(u.PCount, true)
		if st.Count >= (step.Count or 1) then
			task.delay(0.35, function()
				if stepAt(pos) == step then
					go(1)
				end
			end)
		end
	end
	local watched = {}
	for _, step in ipairs(STEPS) do
		if step.Attr and not watched[step.Attr] then
			watched[step.Attr] = true
			local name = step.Attr
			table.insert(conns, player:GetAttributeChangedSignal(name):Connect(function()
				attrChanged(name)
			end))
		end
	end

	-- começa no 1º passo que vale
	while pos <= #order and not valid(pos) do
		pos += 1
	end
	if pos > #order then
		close("finish")
		return
	end
	if not guide then
		send("step", order[pos])
	end
	show()

	---------------------------------------------------------------- laço (setas, linha dourada, condições)
	local accum = 0
	table.insert(conns, RunService.Heartbeat:Connect(function(dt)
		if st.Finished then
			return
		end
		accum += dt
		local step = stepAt(pos)
		if not step then
			return
		end
		local t = os.clock()
		local playerGui = u.PlayerGui

		-- telas cheias (chocar ovo, sorteio do 1º cachorro): some tudo
		local blocking = false
		for _, name in ipairs({ "Hatch", "StarterRoll" }) do
			local other = playerGui:FindFirstChild(name)
			if other and other:IsA("ScreenGui") and other.Enabled then
				blocking = true
			end
		end
		u.Gui.Enabled = not blocking
		u.ArrowGui.Enabled = not blocking
		if blocking then
			u.Beam.Enabled = false
			u.Mark.Enabled = false
			return
		end

		-- cartão: o ícone grande balança e espera fechar o menu que estiver aberto (o próprio guia não conta);
		-- passo "faça": com menu aberto o painel vai para o topo
		local menuOpen = HUD.IsOpen() and not HUD.IsOpen("Guide")
		local above = Kit.IsTouch() and 132 or 112
		if step.Kind == "info" then
			u.BigIcon.Rotation = math.sin(t * 3) * 8
			u.Beam.Enabled = false
			u.Mark.Enabled = false
			if menuOpen ~= (st.CardHidden == true) then
				st.CardHidden = menuOpen
				u.Dim.Visible = not menuOpen
				if menuOpen then
					u.Card.Visible = false
				else
					Kit.Pop(u.Card, true)
				end
			end
			return
		end
		u.Panel.AnchorPoint = menuOpen and Vector2.new(0.5, 0) or Vector2.new(0.5, 1)
		u.Panel.Position = menuOpen and UDim2.new(0.5, 0, 0, 6) or UDim2.new(0.5, 0, 1, -above)
		u.PSkip.Visible = not menuOpen and not step.NoSkip and Config.TUTORIAL_SKIP == true
		u.PIcon.Rotation = math.sin(t * 3) * 6

		-- seta 👉: botão dentro do menu aberto, senão o botão do HUD
		local target = nil
		if menuOpen and step.Inner then
			local found = playerGui:FindFirstChild(step.Inner, true)
			if found and found:IsA("GuiObject") and found.Visible and found.AbsoluteSize.X > 0 then
				local sg = found:FindFirstAncestorOfClass("ScreenGui")
				if sg and sg.Enabled then
					target = found
				end
			end
		elseif not menuOpen and step.Target then
			target = HUD.GetButton and HUD.GetButton(step.Target)
			if not target then
				local side = HUD.Root and HUD.Root:FindFirstChild("Side", true)
				target = side and side:FindFirstChild(step.Target)
			end
		end
		if target and target.AbsoluteSize.X > 0 then
			u.Arrow.Visible = true
			local p, s = target.AbsolutePosition, target.AbsoluteSize
			local wobble = math.abs(math.sin(t * 5)) * 14
			local viewSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
			if p.X + s.X / 2 < viewSize.X / 2 then
				u.Arrow.Text = "👈"
				u.Arrow.AnchorPoint = Vector2.new(0, 0.5)
				u.Arrow.Position = UDim2.fromOffset(p.X + s.X + 4 + wobble, p.Y + s.Y / 2)
			else
				u.Arrow.Text = "👉"
				u.Arrow.AnchorPoint = Vector2.new(1, 0.5)
				u.Arrow.Position = UDim2.fromOffset(p.X - 4 - wobble, p.Y + s.Y / 2)
			end
			u.Highlight.Transparency = 0.5 - 0.5 * math.sin(t * 6)
			if u.Highlight.Parent ~= target then
				u.Highlight.Parent = target
			end
		else
			u.Arrow.Visible = false
			u.Highlight.Parent = nil
		end

		-- seta ⬇ balançando em cima do alvo
		u.Mark.StudsOffset = Vector3.new(0, 5 + math.abs(math.sin(t * 4)) * 1.5, 0)
		u.MarkText.TextColor3 = C.Gold:Lerp(Color3.new(1, 1, 1), 0.5 + 0.5 * math.sin(t * 6))
		u.Beam.Transparency = NumberSequence.new(0.25 + 0.25 * math.sin(t * 4))

		-- 🚶 andar / 🏃 correr
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if step.Moved and rootPart then
			local here = rootPart.Position
			if st.LastPos then
				local d = Vector3.new(here.X - st.LastPos.X, 0, here.Z - st.LastPos.Z).Magnitude
				if d < 8 then -- (teleporte não conta)
					st.Moved += d
				end
			end
			st.LastPos = here
			if st.Moved >= step.Moved then
				go(1)
				return
			end
		end
		if step.Run and hum and character then
			local base = character:GetAttribute("BaseSpeed") or 16
			if hum.WalkSpeed > base * 1.25 and hum.MoveDirection.Magnitude > 0.1 then
				st.Run = (st.Run or 0) + dt
				if st.Run > 0.6 then
					st.Run = 0
					go(1)
					return
				end
			end
		end

		if accum < 0.25 then
			return
		end
		accum = 0

		-- alvo no mundo (⬇) e linha dourada
		local markPart = step.Mark and step.Mark() or nil
		u.Mark.Adornee = markPart
		u.Mark.Parent = markPart and playerGui or nil
		u.Mark.Enabled = markPart ~= nil and not menuOpen
		local rawDest = step.Path and step.Path() or nil
		local dest: Vector3? = nil
		if typeof(rawDest) == "Vector3" then
			dest = rawDest
		elseif typeof(rawDest) == "Instance" and rawDest:IsA("BasePart") then
			dest = rawDest.Position
		end
		if dest and rootPart and not menuOpen then
			if not a0 or a0.Parent ~= rootPart then
				if a0 then
					a0:Destroy()
				end
				local start = Instance.new("Attachment")
				start.Name = "TutorialPathStart"
				start.Position = Vector3.new(0, -1.5, 0)
				start.Parent = rootPart
				a0 = start
				u.Beam.Attachment0 = start
			end
			u.AnchorPart.Position = dest + Vector3.new(0, 0.5, 0)
			u.PathFolder.Parent = workspace
			u.Beam.Enabled = (dest - rootPart.Position).Magnitude > 8
		else
			u.Beam.Enabled = false
		end

		if step.Do then
			local ok, did = pcall(step.Do, st)
			if ok and did then
				go(1)
			end
		end
	end))
end

-- abre o tutorial (guide = false, a partir do passo startAt) ou o 📖 guia (guide = true) — usado também pela prévia
function Tutorial.Open(HUD, guide: boolean, startAt: number?)
	run(HUD, guide, startAt)
end

function Tutorial.Start(HUD)
	-- 📖 guia: H (PC) ou ⚙️ SETTINGS ➜ HOW TO PLAY (HUD.Toggle("Guide"))
	HUD.RegisterMenu("Guide", {
		Open = function()
			if not running then
				task.spawn(run, HUD, true)
			end
		end,
		Close = function()
			if running and running.Guide then
				running.FromMenu = true
				running.Close("guide")
			end
		end,
	})
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.H or UserInputService:GetFocusedTextBox() then
			return
		end
		if not running or running.Guide then
			HUD.Toggle("Guide")
		end
	end)

	-- (2026-10-23) a 1ª vez agora é o passeio com a guia Lily (Systems/GuideTour); os cartões ficam só como 📖 guia
end

return Tutorial
