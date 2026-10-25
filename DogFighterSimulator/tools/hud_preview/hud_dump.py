"""Roda o HUD DE VERDADE (src/client/UI) no mini-Roblox de telas e salva a árvore de telas em JSON.

Uso:  python3 tools/hud_preview/hud_dump.py <pc|phone> saida.json
Depois: node tools/hud_preview/hud_render.js saida.json foto.png
Precisa do luau em /tmp/luau/luau (github.com/luau-lang/luau/releases → luau-ubuntu.zip).
A cena é fixa (Puppy Meadows, $1.240, Caramelo LV 12, missões, 2 avisos) para comparar com a prévia aprovada.
"""
import glob, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(ROOT, 'src')
LUAU = os.environ.get('LUAU', '/tmp/luau/luau')

mode = sys.argv[1]
out_path = sys.argv[2]
# estados para testar (3º argumento, separados por vírgula): ko, awake, colosseum, home, pvp, mythic,
# longname, allclaimed, reserve, streak, noteam, title (🎬 tela de entrada por cima),
# tut<N> (🎓 passo N do tutorial: cartão ou painel "faça"), guide<N> (📖 guia aberto no N-ésimo cartão)
FLAGS = sys.argv[3].split(',') if len(sys.argv) > 3 else []
# pc = 1920x1080; phone = 844x390 (toque); ou LxA com "t" no fim para toque (ex.: 1366x768, 667x375t, 1024x768t)
if mode == 'phone':
    mode = '844x390t'
elif mode == 'pc':
    mode = '1920x1080'
touch = mode.endswith('t')
w, h = mode.rstrip('t').split('x')
SCREEN = {'W': int(w), 'H': int(h), 'Touch': touch, 'Inset': 36 if touch else 58}
PHONE = touch


def module(name, path):
    src = open(path, encoding='utf-8').read()
    return f'MODULES[{json.dumps(name)}] = function(script)\n{src}\nend\n'


metrics = json.load(open(os.path.join(HERE, 'fonts_metrics.json'), encoding='utf-8'))


def lua_table(d):
    items = []
    for k, v in d.items():
        key = '[' + json.dumps(k, ensure_ascii=False) + ']'
        if isinstance(v, dict):
            items.append(f'{key} = {lua_table(v)}')
        elif isinstance(v, bool):
            items.append(f'{key} = {"true" if v else "false"}')
        else:
            items.append(f'{key} = {json.dumps(v, ensure_ascii=False)}')
    return '{' + ', '.join(items) + '}'


import re
_main = open(os.path.join(SRC, 'server', 'Main.server.lua'), encoding='utf-8').read()
_block = _main.split('local REMOTES = {', 1)[1].split('\n}', 1)[0]
REMOTE_LIST = dict(re.findall(r'^\s*([A-Za-z]+)\s*=\s*"(Remote(?:Event|Function))"', _block, re.M))
parts = [
    f'REMOTE_LIST = {lua_table(REMOTE_LIST)}\n',
    'FLAGS = {' + ', '.join('[' + json.dumps(f) + '] = true' for f in FLAGS) + '}\n',
    f'SCREEN = {lua_table(SCREEN)}\n',
    f'METRICS = {lua_table(metrics)}\n',
    'MOCK = (function()\n' + open(os.path.join(ROOT, 'tools', 'preview', 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
    'GUI = (function()\n' + open(os.path.join(HERE, 'mock_gui.luau'), encoding='utf-8').read() + '\nend)()\n',
    'MODULES = {}\n',
    # (Systems/GuideTour mede o chão com raios: aqui não há mundo, o raio não acha nada)
    'RaycastParams = RaycastParams or { new = function() return { FilterDescendantsInstances = {} } end }\n',
]
# todos os módulos de src/shared (o HUD e o que ele usa vão ganhando dependências novas: Village, Skills...)
shared_names = sorted(os.path.basename(p)[:-4] for p in glob.glob(os.path.join(SRC, 'shared', '*.lua')))
for name in shared_names:
    if name != 'MusicConfig':
        parts.append(module(name, os.path.join(SRC, 'shared', name + '.lua')))
packs = sorted(glob.glob(os.path.join(SRC, 'shared', 'DogPacks', '*.lua')))
for p in packs:
    parts.append(module(os.path.basename(p)[:-4], p))
pack_names = [os.path.basename(p)[:-4] for p in packs]
ui_names = ['Kit', 'Icons', 'WorldMap', 'HUD', 'TouchPad', 'Title']
for name in ui_names:
    parts.append(module(name, os.path.join(SRC, 'client', 'UI', name + '.lua')))
parts.append(module('Abilities', os.path.join(SRC, 'client', 'Systems', 'Abilities.lua')))
parts.append(module('Music', os.path.join(SRC, 'client', 'Systems', 'Music.lua')))
parts.append(module('Tutorial', os.path.join(SRC, 'client', 'Systems', 'Tutorial.lua')))
parts.append(module('GuideTour', os.path.join(SRC, 'client', 'Systems', 'GuideTour.lua')))
parts.append(module('Starter', os.path.join(SRC, 'client', 'Systems', 'Starter.lua')))
parts.append(module('MusicConfig', os.path.join(SRC, 'shared', 'MusicConfig.lua')))
# 🎨 menus (flag "menu<Nome>": abre o menu de verdade por cima do HUD, ex.: menuDogs, menuInventario, menuLoja)
MENU_UI = ['DogsMenu', 'MapMenu', 'ShopMenu', 'Hatch']
MENU_SYS = ['Inventory', 'StoreMenu', 'Progression', 'Settings', 'Codes', 'Trade', 'Quests', 'Catch',
            'SeasonPassMenu', 'StyleMenu', 'ClanMenu', 'DonateMenu', 'WeekendEvent']  # (2026-10-25: telas novas)
for name in MENU_UI:
    parts.append(module(name, os.path.join(SRC, 'client', 'UI', name + '.lua')))
for name in MENU_SYS:
    parts.append(module(name, os.path.join(SRC, 'client', 'Systems', name + '.lua')))
# o Abilities usa o DogControl e o Effects (mira e golpes): aqui só de mentirinha, a foto é da tela
parts.append('''MODULES["DogControl"] = function()
	return { AimDirection = function() return nil end, AimPoint = function() return nil end, FaceAim = function() end,
		FaceDirection = function() end, BarrelRoll = function() return false end }
end
MODULES["Effects"] = function()
	return { Melee = function() end }
end
''')

parts.append(r'''
---------------------------------------------------------------- hierarquia e require
local folder = GUI.folder
local RS = game:GetService("ReplicatedStorage")
local shared = folder("Shared", RS)
local function ms(name, parent)
	local m = Instance.new("ModuleScript")
	m.Name = name
	m.Parent = parent
	return m
end
for _, n in ipairs(SHARED_NAMES) do
	ms(n, shared)
end
local packs = folder("DogPacks", shared)
for _, n in ipairs(PACK_NAMES) do
	ms(n, packs)
end
local remotes = folder("Remotes", RS)
-- (todos os remotes do servidor: a lista sai do REMOTES do Main.server.lua)
for n, cls in pairs(REMOTE_LIST) do
	local r = Instance.new(cls)
	r.Name = n
	r.Parent = remotes
end
local client = folder("Client", GUI.LocalPlayer.PlayerScripts)
local ui = folder("UI", client)
for _, n in ipairs({ "Kit", "Icons", "WorldMap", "HUD", "TouchPad", "Title" }) do
	ms(n, ui)
end
for _, n in ipairs({ "DogsMenu", "MapMenu", "ShopMenu", "Hatch" }) do
	ms(n, ui)
end
local systems = folder("Systems", client)
for _, n in ipairs({ "Inventory", "StoreMenu", "Progression", "Settings", "Codes", "Trade", "Quests", "Catch", "SeasonPassMenu", "StyleMenu", "ClanMenu", "DonateMenu", "WeekendEvent" }) do
	ms(n, systems)
end
ms("Abilities", systems)
ms("Music", systems)
ms("Tutorial", systems)
ms("GuideTour", systems)
ms("Starter", systems)
ms("DogControl", systems)
ms("Effects", client)
ms("Net", client)
ms("Animator", client)

---------------------------------------------------------------- 📜 retrato das missões (menu QUESTS da prévia)
PROGRESS_STATE = {
	Daily = {
		{ Kind = "wins", Icon = "⚔️", Text = "Win 5 fights", Goal = 5, Count = 3, Claimed = false, Reward = { Cash = 500, XP = 0, Egg = false } },
		{ Kind = "eggs", Icon = "🥚", Text = "Hatch 2 eggs", Goal = 2, Count = 2, Claimed = false, Reward = { Cash = 300, XP = 120, Egg = false } },
		{ Kind = "train", Icon = "🥊", Text = "Hit the training post 50 times", Goal = 50, Count = 50, Claimed = true, Reward = { Cash = 0, XP = 400, Egg = false } },
	},
	Quick = { Kind = "wild", Icon = "🐺", Text = "Beat 10 wild dogs", Goal = 10, Count = 4, Claimed = false, Reward = { Cash = 200, XP = 0, Egg = false } },
	Bonus = { Claimed = false, Reward = "$2,000 + 🥚 Egg" },
	Rerolls = 1,
	ResetIn = 5 * 3600 + 120,
	QuickIn = 1260,
	Login = {
		Claimable = true,
		Streak = 3,
		Day = 3,
		Rewards = {
			{ Cash = 100, XP = 0, Egg = false }, { Cash = 0, XP = 200, Egg = false }, { Cash = 300, XP = 0, Egg = false },
			{ Cash = 0, XP = 0, Egg = true }, { Cash = 500, XP = 200, Egg = false }, { Cash = 0, XP = 400, Egg = false },
			{ Cash = 1000, XP = 0, Egg = true },
		},
	},
	Achievements = {
		{ Id = "first_win", Icon = "🏆", Name = "First Victory", Desc = "Win a fight", Goal = 1, Have = 1, Done = true, Reward = "$100" },
		{ Id = "hunter_100", Icon = "🐺", Name = "Hunter", Desc = "Beat 100 wild dogs", Goal = 100, Have = 37, Done = false, Title = "Hunter", Reward = "$1,000" },
		{ Id = "eggs_10", Icon = "🥚", Name = "Egg Hatcher", Desc = "Hatch 10 eggs", Goal = 10, Have = 4, Done = false, Reward = "$500" },
		{ Id = "rare", Icon = "💎", Name = "So Lucky!", Desc = "Get a Rare dog", Goal = 3, Have = 3, Done = true, Reward = "$300" },
	},
	Titles = { { Id = "first_win", Title = "Rookie" } },
	Title = nil,
	Stats = {},
}
-- 🗺️ "maptiles": as fotos de cima do mapa (Imagens/Mapa/*.png) como se o servidor já tivesse aberto os Decals
if FLAGS.maptiles then
	for _, key in ipairs({ "main", "village", "common", "uncommon", "rare", "epic", "legendary", "mythic", "divine", "cloud" }) do
		game:GetService("ReplicatedStorage"):SetAttribute("MapTile_" .. key, "maptiles/" .. key .. ".png")
	end
end
if FLAGS.loginclaimed then
	PROGRESS_STATE.Login.Claimable = false
end
local baseInvoke = MOCK.InstMethods.InvokeServer
MOCK.InstMethods.InvokeServer = function(self, action, ...)
	if self.Name == "ProgressAction" and action == "state" then
		return true, PROGRESS_STATE
	end
	return baseInvoke(self, action, ...)
end

---------------------------------------------------------------- cena de teste (igual à prévia aprovada)
SERVER_TIME = 100000
function MOCK.InstMethods.GetServerTimeNow()
	return SERVER_TIME
end
local Islands
PROFILE = {
	Started = true,
	Cash = 1240,
	Islands = { common = true },
	HouseLevel = 3,
	Stand = 2,
	Team = { 1, 2 },
	TeamSlots = 3,
	Equipped = 1,
	Dogs = { [1] = { Id = 1, Species = "caramelo", Name = "Caramelo", Level = 12, XP = 120 } },
	Streak = 0,
	Leashes = { Normal = 4, Golden = 1 },
	LeashGift = not FLAGS.leashgift,
	-- (2026-10-25) 🎟️ passe da temporada atual · 🎩 acessórios
	Season = { Id = 1, Stars = 47, Premium = FLAGS.premium == true, Free = { ["1"] = true, ["2"] = true }, Paid = {} },
	Acc = { Owned = { cap = true, bowtie = true, shades = true }, On = { Hat = "cap", Collar = "bowtie" } },
	Discovered = { caramelo = true, pug = true, beagle = true, corgi = true, poodle = true, bulldog = true, salsicha = true, chihuahua = true, pinscher = true, akita = true, snow_husky = true },
}
-- ✨🥇🌈 (flag "variants"): cachorros shiny / Gold / Rainbow no DOGS
if FLAGS.variants then
	PROFILE.Dogs[2] = { Id = 2, Species = "pug", Name = "Pug", Level = 8, XP = 0, Shiny = true }
	PROFILE.Dogs[3] = { Id = 3, Species = "corgi", Name = "Corgi", Level = 15, XP = 0, Tier = 1 }
	PROFILE.Dogs[4] = { Id = 4, Species = "beagle", Name = "Beagle", Level = 20, XP = 0, Tier = 2, Shiny = true }
	PROFILE.Dogs[5] = { Id = 5, Species = "caramelo", Name = "Caramelo", Level = 4, XP = 0 }
	PROFILE.Dogs[6] = { Id = 6, Species = "caramelo", Name = "Caramelo", Level = 6, XP = 0 }
end
MODULES.Net = function(script)
	local Net = {}
	Net.Remotes = remotes
	Net.Profile = PROFILE
	Net.Changed = Instance.new("BindableEvent")
	function Net.WaitProfile()
		return Net.Profile
	end
	function Net.Equipped()
		local p = Net.Profile
		return p and p.Equipped and p.Dogs[p.Equipped]
	end
	-- (as telas novas pedem o estado ao servidor: respostas de mentirinha)
	function Net.Invoke(remote, action)
		if remote == "ClanAction" and action == "state" then
			local s = { Cost = 5000, Max = 20, Colors = 8, Invites = {}, Browse = {} }
			if FLAGS.clanmember then
				s.Clan = { Id = "1-1", Name = "Super Pups", Tag = "SP", Color = 3, Open = true, Leader = true, Count = 4, Week = 1280, Members = {
					{ UserId = 1, Name = "You", Leader = true, Online = true, Joined = 1 },
					{ UserId = 2, Name = "Bruna", Leader = false, Online = true, Joined = 2 },
					{ UserId = 3, Name = "Leo", Leader = false, Online = false, Joined = 3 },
					{ UserId = 4, Name = "Mia", Leader = false, Online = false, Joined = 4 },
				} }
			else
				s.Invites = { { Id = "7-1", Name = "Doggo Kings", Tag = "DK", From = "Bruna" } }
				s.Browse = { { Id = "9-1", Name = "Paw Patrol", Tag = "PAW", Color = 4, Count = 12, Open = true } }
			end
			return true, s
		elseif remote == "DonateAction" and action == "state" then
			return true, { Total = 150, Top = { { Name = "Bruna", Amount = 1000 }, { Name = "Leo", Amount = 500 }, { Name = "You", Amount = 150 } } }
		end
		return true, ""
	end
	-- (contas iguais às do Net de verdade, para os menus)
	function Net.Power(dog)
		local Config = require(shared.Config)
		local DogData = require(shared.DogData)
		local species = dog and DogData.Species[dog.Species]
		if not species then
			return 0
		end
		return Config.Stats(species, dog.Level).Power
	end
	function Net.DogCount()
		local n = 0
		for _ in pairs(Net.Profile.Dogs) do
			n += 1
		end
		return n
	end
	function Net.SortedDogs(onlyFav)
		local list = {}
		for _, dog in pairs(Net.Profile.Dogs) do
			if not onlyFav or dog.Fav then
				table.insert(list, dog)
			end
		end
		table.sort(list, function(a, b)
			return a.Id < b.Id
		end)
		return list
	end
	return Net
end
MODULES.Animator = function(script)
	local A = {}
	for _, k in ipairs({ "Start", "Track", "Untrack", "PlayBite", "PlayDodge", "Play" }) do
		A[k] = function() end
	end
	return A
end

if FLAGS.longname then
	PROFILE.Dogs[1].Name = "Sir Barksalot"
end
if FLAGS.noteam then
	PROFILE.Team = {}
end
if FLAGS.streak then
	PROFILE.Streak = 5
end

local cache = {}
function require(m)
	local name = m.Name
	if cache[name] == nil then
		local fn = MODULES[name]
		assert(fn, "módulo desconhecido: " .. tostring(name))
		cache[name] = fn(m)
	end
	return cache[name]
end

Islands = require(shared.Islands)
if FLAGS.mythic then
	local DogData = require(shared.DogData)
	local Config = require(shared.Config)
	for _, id in ipairs(DogData.Order) do
		local sp = DogData.Species[id]
		if sp and Config.HasSupreme(sp.Rarity) then
			PROFILE.Dogs[1].Species = id
			print("mítico:", id)
			break
		end
	end
end
local lp = GUI.LocalPlayer
lp:SetAttribute("Island", FLAGS.colosseum and "colosseum" or FLAGS.home and "main" or FLAGS.village and "village" or "common")
if FLAGS.newbie then
	PROFILE.Started = false
	PROFILE.Dogs = {}
	PROFILE.Equipped = nil
end
lp:SetAttribute("TeamIncome", 120)
lp:SetAttribute("TeamPayAt", SERVER_TIME + 3.8)
lp:SetAttribute("DogState", FLAGS.ko and "ko" or "arena")
-- (loja: o servidor já respondeu que itens aleatórios pagos são permitidos para este jogador)
lp:SetAttribute("PaidRandomRestricted", false)
if FLAGS.boosts then
	lp:SetAttribute("Boost_Cash", SERVER_TIME + 1234)
	lp:SetAttribute("Pass_LuckyPaw", true)
end
if FLAGS.ko then
	lp:SetAttribute("RespawnAt", SERVER_TIME + 4)
end
lp:SetAttribute("ArenaMode", FLAGS.pvp and "pvp" or (FLAGS.streak and "arena" or "off"))
if FLAGS.mythic then
	lp:SetAttribute("Supreme", 45)
end
workspace:SetAttribute("SuperBossAwake", FLAGS.awake == true)
workspace:SetAttribute("SuperBossIn", 252)

-- cachorros no mundo (radar): o meu, 4 selvagens e 1 de outro jogador
local cachorros = folder("Cachorros", workspace)
local function dogAt(lx, lz, kind, owner, species)
	local m = Instance.new("Model")
	m.Name = "Dog"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(Islands.ToWorld("common", lx, 3, lz))
	root.Parent = m
	m.PrimaryPart = root
	m:SetAttribute("Kind", kind)
	m:SetAttribute("Owner", owner)
	m:SetAttribute("Species", species)
	local hum = Instance.new("Humanoid")
	hum.Health = 820
	hum.MaxHealth = 1000
	hum.Parent = m
	m.Parent = cachorros
	return m
end
-- (jogador novo, sem cachorro: o personagem é a pessoa)
local me = PROFILE.Dogs[1] and dogAt(-60, -80, "player", 1, PROFILE.Dogs[1].Species) or Instance.new("Model")
lp.Character = me
for _, o in ipairs({ { -100, -140 }, { -130, -60 }, { 10, -10 }, { -40, 20 } }) do
	dogAt(o[1], o[2], "npc", 0, "pug")
end
dogAt(-150, -150, "player", 2, "husky")
local camPos = Islands.ToWorld("common", -60, 30, -10)
local camLook = Islands.ToWorld("common", -60, 0, -100)
workspace.CurrentCamera.CFrame = CFrame.lookAt(camPos, camLook)

---------------------------------------------------------------- 🎬 tela de entrada (estado "title")
if FLAGS.title then
	-- (na foto, o que entra depois de um tempinho — cachorros 3D, faixa — já aparece)
	local realDelay = task.delay
	task.delay = function(_t, fn, ...)
		pcall(fn, ...)
	end
	local okTitle, errTitle = pcall(function()
		require(ui.Title).Start()
	end)
	task.delay = realDelay
	if not okTitle then
		print("ERRO|Title.Start|" .. tostring(errTitle))
	end
end

---------------------------------------------------------------- roda o HUD de verdade
local HUD = require(ui.HUD)
local ok, err = pcall(HUD.Start)
if not ok then
	print("ERRO|HUD.Start|" .. tostring(err))
end
for _, name in ipairs({ "Shop", "Dogs", "Inventario", "Map", "Boss", "Loja", "Missoes", "Trade", "Codes", "Settings" }) do
	HUD.RegisterMenu(name, { Open = function() end, Close = function() end })
end
local claimed = FLAGS.allclaimed == true
HUD.SetQuests({
	Daily = {
		{ Text = "Win 5 fights", Count = claimed and 5 or 3, Goal = 5, Claimed = claimed },
		{ Text = "Hatch 2 eggs", Count = 2, Goal = 2, Claimed = claimed },
		{ Text = "Earn $1,000", Count = claimed and 1000 or 450, Goal = 1000, Claimed = claimed },
	},
	ResetIn = 11 * 3600 + 2 * 60 + 30,
}, function() end, os.clock())
HUD.SetBadge("Shop", "!")
HUD.SetBadge("Dogs", "NEW")
HUD.SetBadge("Missoes", "1")
HUD.Toast("💵 +$250 Wild Pug defeated!", "green")
if not SCREEN.Touch then
	HUD.Toast("📜 Daily quest complete! Claim it in QUESTS", "gold")
end

if FLAGS.reserve then
	HUD.SetTopReserve(92)
end
local Abilities = require(systems.Abilities)
ok, err = pcall(Abilities.Start, HUD)
if not ok then
	print("ERRO|Abilities.Start|" .. tostring(err))
end
me:SetAttribute("Kind", "player")
-- 🗺️ "farmap": minimapa no zoom de longe (clique no minimapa)
if FLAGS.farmap then
	local zoom = HUD.Root and HUD.Root:FindFirstChild("Zoom", true)
	if zoom then
		zoom.Activated:Fire()
	else
		print("ERRO|farmap|botão Zoom não achado")
	end
end
-- recarga do golpe 2 em 62%: começa com 4,8 s e o relógio anda 1,8 s
lp:SetAttribute("CD2", SERVER_TIME + 4.8)
SERVICES.RunService.Heartbeat:Fire(1 / 60)
SERVER_TIME += 1.8
SERVICES.RunService.Heartbeat:Fire(1 / 60)
SERVICES.RunService.RenderStepped:Fire(1 / 60) -- (minimapa: gira e anda a cada quadro)

if SCREEN.Touch then
	local Kit = require(ui.Kit)
	local TouchPad = require(ui.TouchPad)
	TouchPad.Add("Run", { Icon = "R", Icon3D = "wind", Label = "RUN", Color = Kit.C.Green, Order = 1 })
	TouchPad.Add("Human", { Icon = "H", Icon3D = "person", Label = "HUMAN", Color = Kit.C.Blue, Order = 2 })
	TouchPad.Add("Fly", { Icon = "F", Icon3D = "wing", Label = "FLY", Color = Kit.C.Purple, Order = 4 })
	-- (2026-10: a trava LOCK saiu do jogo; 2026-10-25: BARK = o cachorro late, Systems/Soundscape)
	TouchPad.Add("Bark", { Icon = "B", Icon3D = "dog", Label = "BARK", Color = Kit.C.Orange, Order = 7 })
end
ok, err = pcall(function()
	require(systems.Music).Start(HUD)
end)
if not ok then
	print("ERRO|Music.Start|" .. tostring(err))
end

---------------------------------------------------------------- 🎓 tutorial / 📖 guia (tut<N> / guide<N>)
for flag in pairs(FLAGS) do
	local kind, n = string.match(flag, "^(%a+)(%d+)$")
	if kind == "tut" or kind == "guide" then
		local realDelay = task.delay
		task.delay = function(_t, fn, ...)
			pcall(fn, ...)
		end
		local okTut, errTut = pcall(function()
			local Tutorial = require(systems.Tutorial)
			if kind == "guide" then
				HUD.RegisterMenu("Guide", { Open = function() end, Close = function() end })
				HUD.Toggle("Guide")
			end
			Tutorial.Open(HUD, kind == "guide", tonumber(n))
			-- (um quadro do laço: seta 👉, painel no lugar certo; câmera do cachorro 3D no lugar)
			SERVICES.RunService.Heartbeat:Fire(0.3)
			SERVICES.RunService.RenderStepped:Fire(1 / 60)
		end)
		task.delay = realDelay
		if not okTut then
			print("ERRO|Tutorial|" .. tostring(errTut))
		end
	end
end

---------------------------------------------------------------- 👑 guia = avatar do dono (flag "owner", 2026-10-24)
-- molde R15 de mentirinha (blocos nas medidas de um R15, já montado em pé com a raiz em Y = 3) no lugar do que o
-- Services/VillageStars monta: o retrato da conversa e o nome da guia vêm dele
if FLAGS.owner then
	local stars = folder("VillageStars", RS)
	stars:SetAttribute("GuideState", "ok")
	local m = Instance.new("Model")
	m.Name = "Guide"
	local P = {}
	local function part(name, size, x, y, color)
		local pt = Instance.new("Part")
		pt.Name = name
		pt.Size = size
		pt.CFrame = CFrame.new(x, y, 0)
		pt.Color = color
		pt.Parent = m
		P[name] = pt
		return pt
	end
	local skin, shirt, pants = Color3.fromRGB(255, 205, 160), Color3.fromRGB(40, 120, 230), Color3.fromRGB(40, 40, 60)
	part("HumanoidRootPart", Vector3.new(2, 2, 1), 0, 3, skin).Transparency = 1
	part("LowerTorso", Vector3.new(2, 0.4, 1), 0, 2.2, shirt)
	part("UpperTorso", Vector3.new(2, 1.6, 1), 0, 3.2, shirt)
	part("Head", Vector3.new(1.2, 1.2, 1.2), 0, 4.6, skin)
	part("Hat", Vector3.new(1.4, 0.4, 1.4), 0, 5.3, Color3.fromRGB(220, 40, 40))
	for _, side in ipairs({ "Left", "Right" }) do
		local sx = side == "Left" and -1 or 1
		part(side .. "UpperArm", Vector3.new(1, 1, 1), sx * 1.5, 3.4, shirt)
		part(side .. "LowerArm", Vector3.new(1, 1, 1), sx * 1.5, 2.4, skin)
		part(side .. "Hand", Vector3.new(1, 0.3, 1), sx * 1.5, 1.75, skin)
		part(side .. "UpperLeg", Vector3.new(1, 1, 1), sx * 0.5, 1.5, pants)
		part(side .. "LowerLeg", Vector3.new(1, 0.8, 1), sx * 0.5, 0.6, pants)
		part(side .. "Foot", Vector3.new(1, 0.2, 1), sx * 0.5, 0.1, Color3.fromRGB(30, 30, 30))
	end
	local function motor(name, p0, p1, c0, c1)
		local j = Instance.new("Motor6D")
		j.Name = name
		j.Part0, j.Part1, j.C0, j.C1 = P[p0], P[p1], c0, c1
		j.Parent = P[p1]
	end
	motor("Root", "HumanoidRootPart", "LowerTorso", CFrame.new(0, -0.8, 0), CFrame.new())
	motor("Waist", "LowerTorso", "UpperTorso", CFrame.new(0, 0.2, 0), CFrame.new(0, -0.8, 0))
	motor("Neck", "UpperTorso", "Head", CFrame.new(0, 0.8, 0), CFrame.new(0, -0.6, 0))
	local hatWeld = Instance.new("Weld")
	hatWeld.Part0, hatWeld.Part1, hatWeld.C0 = P.Head, P.Hat, CFrame.new(0, 0.7, 0)
	hatWeld.Parent = P.Hat
	for _, side in ipairs({ "Left", "Right" }) do
		local sx = side == "Left" and -1 or 1
		motor(side .. "Shoulder", "UpperTorso", side .. "UpperArm", CFrame.new(sx * 1.5, 0.7, 0), CFrame.new(0, 0.5, 0))
		motor(side .. "Elbow", side .. "UpperArm", side .. "LowerArm", CFrame.new(0, -0.5, 0), CFrame.new(0, 0.5, 0))
		motor(side .. "Wrist", side .. "LowerArm", side .. "Hand", CFrame.new(0, -0.5, 0), CFrame.new(0, 0.15, 0))
		motor(side .. "Hip", "LowerTorso", side .. "UpperLeg", CFrame.new(sx * 0.5, -0.2, 0), CFrame.new(0, 0.5, 0))
		motor(side .. "Knee", side .. "UpperLeg", side .. "LowerLeg", CFrame.new(0, -0.5, 0), CFrame.new(0, 0.4, 0))
		motor(side .. "Ankle", side .. "LowerLeg", side .. "Foot", CFrame.new(0, -0.4, 0), CFrame.new(0, 0.1, 0))
	end
	local hum = Instance.new("Humanoid")
	hum.Parent = m
	m.PrimaryPart = P.HumanoidRootPart
	m:SetAttribute("Role", "Guide")
	m:SetAttribute("UserId", 1)
	m:SetAttribute("DisplayName", "Daniel")
	m:SetAttribute("IsOwner", true)
	m:SetAttribute("RootH", 3)
	m.Parent = stars
end

---------------------------------------------------------------- 🧭 passeio da guia (tourguide / tourprof / tourchoice / tourreward)
for flag in pairs(FLAGS) do
	local what = string.match(flag, "^tour(%a+)$")
	if what then
		local okTour, errTour = pcall(function()
			require(systems.GuideTour).Preview(what)
			SERVICES.RunService.RenderStepped:Fire(1 / 60)
		end)
		if not okTour then
			print("ERRO|GuideTour|" .. tostring(errTour))
		end
	end
end

---------------------------------------------------------------- 🐶 escolha do 1º cachorro (starterchoose)
if FLAGS.starterchoose then
	local okS, errS = pcall(function()
		require(systems.Starter).Preview(HUD, "choose")
		SERVICES.RunService.RenderStepped:Fire(1 / 60)
	end)
	if not okS then
		print("ERRO|Escolha|" .. tostring(errS))
	end
end

---------------------------------------------------------------- 🎰 roleta paga (roulette)
if FLAGS.roulette then
	local okR, errR = pcall(function()
		require(systems.Starter).Preview(HUD)
	end)
	if not okR then
		print("ERRO|Roleta|" .. tostring(errR))
	end
end

---------------------------------------------------------------- árvore de telas em JSON
local function num(n)
	return math.floor(n * 10000 + 0.5) / 10000
end
local function conv(v)
	local t = typeof(v)
	if t == "UDim2" then
		return { num(v.X.Scale), num(v.X.Offset), num(v.Y.Scale), num(v.Y.Offset) }
	elseif t == "UDim" then
		return { num(v.Scale), num(v.Offset) }
	elseif t == "Vector2" then
		return { num(v.X), num(v.Y) }
	elseif t == "Vector3" then
		return { num(v.X), num(v.Y), num(v.Z) }
	elseif t == "Color3" then
		return { num(v.R), num(v.G), num(v.B) }
	elseif t == "EnumItem" then
		return v.Name
	elseif t == "CFrame" then
		return { v:GetComponents() }
	elseif t == "ColorSequence" then
		local a = v.Args
		if typeof(a[1]) == "Color3" and a[2] == nil then
			return { { 0, a[1].R, a[1].G, a[1].B }, { 1, a[1].R, a[1].G, a[1].B } }
		elseif typeof(a[1]) == "Color3" then
			return { { 0, a[1].R, a[1].G, a[1].B }, { 1, a[2].R, a[2].G, a[2].B } }
		end
		local out = {}
		for _, k in ipairs(a[1]) do
			local c = k.Args[2]
			table.insert(out, { k.Args[1], c.R, c.G, c.B })
		end
		return out
	elseif t == "NumberSequence" then
		local a = v.Args
		if type(a[1]) == "number" and a[2] == nil then
			return { { 0, a[1] }, { 1, a[1] } }
		elseif type(a[1]) == "number" then
			return { { 0, a[1] }, { 1, a[2] } }
		end
		local out = {}
		for _, k in ipairs(a[1]) do
			table.insert(out, { k.Args[1], k.Args[2] })
		end
		return out
	elseif t == "number" or t == "string" or t == "boolean" then
		return v
	end
	return nil
end
local PROPS = {
	"Position", "Size", "AnchorPoint", "Visible", "ZIndex", "BackgroundTransparency", "BackgroundColor3", "Rotation",
	"AutomaticSize", "ClipsDescendants", "LayoutOrder", "Text", "TextSize", "TextScaled", "Font", "TextColor3",
	"TextXAlignment", "TextYAlignment", "TextTransparency", "TextWrapped", "ImageTransparency", "Enabled", "DisplayOrder",
	"IgnoreGuiInset", "Thickness", "Color", "Transparency", "ApplyStrokeMode", "CornerRadius", "Scale", "Offset",
	"PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom", "FillDirection", "Padding", "HorizontalAlignment",
	"VerticalAlignment", "SortOrder", "CellSize", "CellPadding", "FillDirectionMaxCells", "MaxTextSize", "MinTextSize",
	"Ambient", "LightColor", "LightDirection", "RichText", "AspectRatio", "AspectType", "DominantAxis", "MinSize",
	"MaxSize", "SizeConstraint", "Image", "ImageTransparency",
}
local nodeId = 0
local function dumpNode(inst)
	nodeId += 1
	local node = { c = inst.ClassName, n = inst.Name, id = nodeId, p = {}, k = {} }
	-- atributos (o Kit guarda neles a conta do ícone da ponta dos textos: LeadPad/LeadBase/LeadMax)
	local attrs = inst:GetAttributes()
	if next(attrs) then
		node.a = {}
		for k, v in pairs(attrs) do
			node.a[k] = conv(v)
		end
	end
	for _, prop in ipairs(PROPS) do
		local v = rawget(inst, "_props")[prop]
		if v ~= nil then
			node.p[prop] = conv(v)
		end
	end
	if inst.ClassName == "ViewportFrame" then
		local cam = inst.CurrentCamera
		node.cam = cam and { cf = { cam.CFrame:GetComponents() }, fov = cam.FieldOfView } or nil
		node.parts = {}
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 0.98 then
				local mesh = d:FindFirstChildOfClass("SpecialMesh")
				table.insert(node.parts, {
					cls = d.ClassName,
					shape = d.Shape and d.Shape.Name or "Block",
					mesh = mesh and mesh.MeshType and mesh.MeshType.Name or "",
					size = conv(d.Size),
					cf = { d.CFrame:GetComponents() },
					color = conv(d.Color),
					mat = d.Material and d.Material.Name or "Plastic",
					tr = d.Transparency,
				})
			end
		end
		return node
	end
	for _, child in ipairs(inst:GetChildren()) do
		if child:IsA("GuiObject") or child:IsA("UIComponent") or child:IsA("LayerCollector") then
			table.insert(node.k, dumpNode(child))
		end
	end
	return node
end

local function encode(v)
	local t = type(v)
	if t == "table" then
		if #v > 0 or next(v) == nil then
			local out = {}
			for _, x in ipairs(v) do
				table.insert(out, encode(x))
			end
			if #v == 0 then
				return "[]"
			end
			return "[" .. table.concat(out, ",") .. "]"
		end
		local out = {}
		for k, x in pairs(v) do
			table.insert(out, string.format("%q", tostring(k)) .. ":" .. encode(x))
		end
		return "{" .. table.concat(out, ",") .. "}"
	elseif t == "string" then
		return '"' .. v:gsub('[%c"\\]', function(c)
			if c == '"' then
				return '\\"'
			elseif c == "\\" then
				return "\\\\"
			elseif c == "\n" then
				return "\\n"
			end
			return string.format("\\u%04x", string.byte(c))
		end) .. '"'
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			return "0"
		end
		return tostring(v)
	elseif t == "boolean" then
		return v and "true" or "false"
	end
	return "null"
end

---------------------------------------------------------------- 🎨 menus de verdade (flag "menu<Nome do HUD>")
local MENU_MODULE = {
	Dogs = ui.DogsMenu, Map = ui.MapMenu, Shop = ui.ShopMenu, Inventario = systems.Inventory, Loja = systems.StoreMenu,
	Missoes = systems.Progression, Settings = systems.Settings, Codes = systems.Codes, Trade = systems.Trade,
	Coleiras = systems.Catch,
	-- (2026-10-25) 🎟️ passe · 🎩 acessórios · 🐺 clãs · 💖 doações
	Pass = systems.SeasonPassMenu, Style = systems.StyleMenu, Clan = systems.ClanMenu, Donate = systems.DonateMenu,
}
for flag in pairs(FLAGS) do
	local name = string.match(flag, "^menu(%a+)$")
	if name then
		local mod = MENU_MODULE[name]
		local okM, errM = pcall(function()
			assert(mod, "menu desconhecido: " .. name)
			require(mod).Start(HUD)
			HUD.Toggle(name)
			for _ = 1, 3 do
				SERVICES.RunService.Heartbeat:Fire(1 / 60)
				SERVICES.RunService.RenderStepped:Fire(1 / 60)
			end
		end)
		if not okM then
			print("ERRO|menu " .. name .. "|" .. tostring(errM))
		end
	end
end

-- 🎉 "event": a pílula do evento de fim de semana (2x CATCH ligado pelo código de teste)
if FLAGS.event then
	workspace:SetAttribute("EventForce", "Catch2x")
	local okE, errE = pcall(function()
		require(systems.WeekendEvent).Start(HUD)
	end)
	if not okE then
		print("ERRO|WeekendEvent|" .. tostring(errE))
	end
end

-- 🦮 "catchwidget": o botão CATCH (com um selvagem perto) · "leashgift": a loja de coleiras antes do pacote grátis
for flag in pairs(FLAGS) do
	if flag == "catchwidget" then
		local okC, errC = pcall(function()
			local Catch = require(systems.Catch)
			if not FLAGS.menuColeiras then
				Catch.Start(HUD)
			end
			Catch.Preview()
		end)
		if not okC then
			print("ERRO|Catch|" .. tostring(errC))
		end
	end
end

-- 🛒 "loja_<aba>": a loja aberta numa aba (loja_passes, loja_cash, loja_dogs, loja_boosts)
for flag in pairs(FLAGS) do
	local tab = string.match(flag, "^loja_(%a+)$")
	local shop = tab and HUD.GetMenu and HUD.GetMenu("Loja")
	if shop and shop.Tab then
		shop.Tab(tab)
		for _ = 1, 2 do
			SERVICES.RunService.Heartbeat:Fire(1 / 60)
			SERVICES.RunService.RenderStepped:Fire(1 / 60)
		end
	end
end

---------------------------------------------------------------- 🛒 imagem de um item da loja (flag "shopicon_<Chave>")
-- (tools/preview/shop_images.py: a figura que o PUBLICAR.bat coloca no passe/produto do site do Roblox; o site mostra
-- os passes num CÍRCULO, então tudo que importa fica no meio)
for flag in pairs(FLAGS) do
	local key = string.match(flag, "^shopicon_([%w_]+)$")
	if key then
		local Monetization = require(shared.Monetization)
		local Kit = require(ui.Kit)
		local Icons = require(ui.Icons)
		local item = Monetization.ByKey[key]
		assert(item, "item da loja desconhecido: " .. key)
		local C = Kit.C
		local TAB_COLOR = { passes = C.Purple, cash = C.Green, dogs = C.Blue, boosts = C.Orange }
		local color = C[item.Tint or ""] or (item.Divino and C.Orange) or TAB_COLOR[item.Tab] or C.Pink
		local gui = Instance.new("ScreenGui")
		gui.Name = "ShopIcon"
		gui.DisplayOrder = 999
		gui.IgnoreGuiInset = true
		gui.Parent = GUI.playerGui
		-- (desenha pequeno e aumenta 4x: o Roblox não deixa letra com TextScaled passar de 100 px — a estrela do XP é letra)
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromOffset(SCREEN.W / 4, SCREEN.H / 4)
		bg.BackgroundColor3 = color
		bg.BorderSizePixel = 0
		bg.Parent = gui
		local zoom = Instance.new("UIScale")
		zoom.Scale = 4
		zoom.Parent = bg
		Kit.Gradient(bg, color:Lerp(Color3.new(1, 1, 1), 0.12), color:Lerp(Color3.new(0, 0, 0), 0.12), 0.5)
		Kit.Rays(bg, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.25, 1.25),
			ZIndex = 2,
		}, color:Lerp(Color3.new(1, 1, 1), 0.45), 12)
		local icon = item.Icon or "star"
		local egg = string.match(icon, "^egg:(.+)$")
		local art = Icons.Make(bg, egg and Kit.EggIcon(egg) or icon, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.48),
			Size = UDim2.fromScale(0.62, 0.62),
			ZIndex = 4,
		})
		-- (contorno das letras do ícone: no jogo o Icons mede o AbsoluteSize, que aqui não conta a UIScale)
		for _, st in ipairs(art:GetDescendants()) do
			if st:IsA("UIStroke") and st:GetAttribute("Frac") then
				st.Thickness = 0.62 * SCREEN.W / 4 * st:GetAttribute("Frac") / 100
			end
		end
		if item.Badge then
			local chip, label = Kit.Chip(bg, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.64, 0.7),
				Size = UDim2.fromScale(0.34, 0.15),
				Rotation = -8,
				ZIndex = 6,
			}, C.Red, item.Badge)
			label.Font = Kit.Title
			label.ZIndex = 7
		end
		for _ = 1, 2 do
			SERVICES.RunService.Heartbeat:Fire(1 / 60)
			SERVICES.RunService.RenderStepped:Fire(1 / 60)
		end
	end
end

---------------------------------------------------------------- 🎨 folha com todos os ícones cartoon (flag "icons")
if FLAGS.icons then
	local Icons = require(ui.Icons)
	local sheet = Instance.new("ScreenGui")
	sheet.Name = "IconSheet"
	sheet.DisplayOrder = 999
	sheet.IgnoreGuiInset = true
	sheet.Parent = GUI.playerGui
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(120, 200, 110)
	bg.Parent = sheet
	local names = Icons.Names()
	local cols = 11
	for i, name in ipairs(names) do
		local cx = ((i - 1) % cols) * 170 + 30
		local cy = math.floor((i - 1) / cols) * 190 + 20
		Icons.Make(bg, name, { Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(110, 110), ZIndex = 2 })
		Icons.Make(bg, name, { Position = UDim2.fromOffset(cx + 115, cy + 70), Size = UDim2.fromOffset(40, 40), ZIndex = 2 })
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(cx - 10, cy + 116)
		l.Size = UDim2.fromOffset(150, 26)
		l.Text = name
		l.TextScaled = true
		l.Font = Enum.Font.FredokaOne
		l.TextColor3 = Color3.new(1, 1, 1)
		l.ZIndex = 2
		local st = Instance.new("UIStroke")
		st.Thickness = 2
		st.Parent = l
		l.Parent = bg
	end
end

local guis = {}
for _, g in ipairs(GUI.playerGui:GetChildren()) do
	if g:IsA("ScreenGui") then
		table.insert(guis, dumpNode(g))
	end
end
print("JSON|" .. encode({ screen = SCREEN, guis = guis }))
''')
parts[-1] = parts[-1].replace('PACK_NAMES', '{' + ', '.join(json.dumps(n) for n in pack_names) + '}')
parts[-1] = parts[-1].replace('SHARED_NAMES', '{' + ', '.join(json.dumps(n) for n in shared_names) + '}')

bundle = os.path.join('/tmp', 'hud_preview_bundle.luau')
open(bundle, 'w', encoding='utf-8').write(''.join(parts))
res = subprocess.run([LUAU, bundle], capture_output=True, text=True)
data = None
for line in res.stdout.splitlines():
    if line.startswith('JSON|'):
        data = line[5:]
    elif line.strip():
        print(line[:400])
if res.returncode != 0 or data is None:
    sys.stderr.write(res.stderr[-4000:])
    sys.exit('luau falhou')
open(out_path, 'w', encoding='utf-8').write(data)
print('ok:', out_path, len(data) // 1024, 'KB')
