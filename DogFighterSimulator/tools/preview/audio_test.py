"""TESTE DO ÁUDIO SEM ROBLOX (2026-10-25, trilha 2 + "som para tudo").

Roda client/Systems/Music.lua e Sfx.lua DE VERDADE (com Shared/MusicConfig, MusicPacks e SfxConfig de verdade) num
mini-Roblox feito aqui (Sound, SoundGroup, TweenService, atributos do jogador, relógio próprio). Confere:
  • cada lugar toca a música certa (Pawville → Village, ilha 1 → Meadows, Coliseu → Arena, Super Boss → Boss...)
  • cada música é o trecho certo do pacote (PlaybackRegion = LoopRegion = começo..fim, Looped)
  • o revezamento troca de música depois de um tempo e volta para a 1ª
  • vinhetas tocam o trecho certo sem loop e abaixam a música
  • sem os pacotes novos enviados, cai na trilha antiga (Main/Arena/Boss)
  • efeitos: pacote 2 com os sons novos (latidos, loops de ambiente); sem ele, o pacote antigo com o som parecido
  • a voz do cachorro pelo tamanho (pequeno = Yip, médio = Bark, grande = Woof)

Uso:  python tools/preview/audio_test.py
"""
import json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(ROOT, 'src')
LOCAL_LUAU = os.path.abspath(os.path.join(ROOT, '..', '..', 'ferramentas', 'luau-0.740', 'luau.exe'))
LUAU = os.environ.get('LUAU') or (LOCAL_LUAU if os.path.exists(LOCAL_LUAU) else 'luau')

PRELUDE = 'local os = setmetatable({ clock = function() return CLOCK end }, { __index = os })\n'

HARNESS = r'''
---------------------------------------------------------------- relógio, tarefas e sinais
local waiting, delayed = {}, {}
local function run(fn, ...)
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		print("ERRO numa tarefa: " .. tostring(err))
		ERRORS += 1
	end
end
task = {
	spawn = run,
	defer = run,
	wait = function(s)
		local co = coroutine.running()
		table.insert(waiting, { co, CLOCK + (s or 0) })
		coroutine.yield()
		return s or 0
	end,
	delay = function(s, fn, ...)
		table.insert(delayed, { CLOCK + (s or 0), fn, { ... } })
	end,
}
-- avança o relógio, rodando o que vence
local function advance(seconds)
	local target = CLOCK + seconds
	while true do
		local nextT = target
		for _, w in ipairs(waiting) do
			nextT = math.min(nextT, w[2])
		end
		for _, d in ipairs(delayed) do
			nextT = math.min(nextT, d[1])
		end
		CLOCK = math.max(CLOCK, nextT)
		local list, dl = waiting, delayed
		waiting, delayed = {}, {}
		for _, w in ipairs(list) do
			if w[2] <= CLOCK then
				local ok, err = coroutine.resume(w[1])
				if not ok then
					print("ERRO numa tarefa: " .. tostring(err))
					ERRORS += 1
				end
			else
				table.insert(waiting, w)
			end
		end
		for _, d in ipairs(dl) do
			if d[1] <= CLOCK then
				run(d[2], table.unpack(d[3]))
			else
				table.insert(delayed, d)
			end
		end
		if CLOCK >= target then
			break
		end
	end
end

local function signal()
	local fns = {}
	local s = {}
	function s:Connect(fn)
		table.insert(fns, fn)
		return { Disconnect = function() end }
	end
	function s:Once(fn)
		return s:Connect(fn)
	end
	s.Event = s
	function s:Fire(...)
		for _, fn in ipairs(fns) do
			run(fn, ...)
		end
	end
	return s
end

---------------------------------------------------------------- Instance falso
NumberRange = { new = function(a, b)
	return { Min = a, Max = b or a }
end }
Vector2 = { new = function(x, y)
	return { X = x, Y = y }
end }
UDim2 = { new = function(...)
	return { ... }
end, fromOffset = function(...)
	return { ... }
end, fromScale = function(...)
	return { ... }
end }
UDim = { new = function(...)
	return { ... }
end }
Color3 = { fromRGB = function(...)
	return { ... }
end, new = function(...)
	return { ... }
end }
TweenInfo = { new = function(...)
	return { ... }
end }
Enum = setmetatable({}, { __index = function(_, k)
	return setmetatable({}, { __index = function(_, v)
		return k .. "." .. v
	end })
end })

local ALL = {}
local function newInst(className, name)
	local o = { ClassName = className, Name = name or className, _children = {}, _attrs = {}, _attrSignals = {}, _propSignals = {} }
	o.Parent = nil
	if className == "Sound" then
		o.Volume, o.PlaybackSpeed, o.TimePosition = 0.5, 1, 0
		o.IsPlaying, o.Looped, o.PlaybackRegionsEnabled = false, false, false
		o.Ended = signal()
		o.Played = 0
	end
	function o:IsA(c)
		return self.ClassName == c or (c == "GuiButton" and (self.ClassName == "TextButton" or self.ClassName == "ImageButton")) or (c == "BasePart" and self.ClassName == "Part")
	end
	function o:FindFirstChild(n)
		for _, c in ipairs(self._children) do
			if c.Name == n then
				return c
			end
		end
		return nil
	end
	o.WaitForChild = o.FindFirstChild
	function o:FindFirstChildOfClass(c)
		for _, ch in ipairs(self._children) do
			if ch.ClassName == c then
				return ch
			end
		end
		return nil
	end
	function o:GetChildren()
		return table.clone(self._children)
	end
	function o:GetDescendants()
		local out = {}
		local function walk(i)
			for _, c in ipairs(i._children) do
				table.insert(out, c)
				walk(c)
			end
		end
		walk(self)
		return out
	end
	o.DescendantAdded = signal()
	o.Activated = signal()
	function o:GetAttribute(k)
		return self._attrs[k]
	end
	function o:SetAttribute(k, v)
		self._attrs[k] = v
		if self._attrSignals[k] then
			self._attrSignals[k]:Fire()
		end
	end
	function o:GetAttributeChangedSignal(k)
		self._attrSignals[k] = self._attrSignals[k] or signal()
		return self._attrSignals[k]
	end
	function o:GetPropertyChangedSignal(k)
		self._propSignals[k] = self._propSignals[k] or signal()
		return self._propSignals[k]
	end
	function o:Play()
		self.IsPlaying = true
		self.Played += 1
		self.TimePosition = (self.PlaybackRegionsEnabled and self.PlaybackRegion) and self.PlaybackRegion.Min or 0
	end
	function o:Resume()
		self.IsPlaying = true
	end
	function o:Pause()
		self.IsPlaying = false
	end
	function o:Stop()
		self.IsPlaying = false
	end
	function o:Destroy()
		self.Destroyed = true
		self:_setParent(nil)
	end
	function o:_setParent(p)
		local old = rawget(self, "_parent")
		if old then
			local i = table.find(old._children, self)
			if i then
				table.remove(old._children, i)
			end
		end
		rawset(self, "_parent", p)
		if p then
			table.insert(p._children, self)
		end
	end
	table.insert(ALL, o)
	return setmetatable(o, {
		__index = function(t, k)
			if k == "Parent" then
				return rawget(t, "_parent")
			end
			-- (filho pelo nome, como no Roblox: ReplicatedStorage.Shared.MusicConfig)
			for _, c in ipairs(rawget(t, "_children")) do
				if rawget(c, "Name") == k then
					return c
				end
			end
			return nil
		end,
		__newindex = function(t, k, v)
			if k == "Parent" then
				t:_setParent(v)
			else
				rawset(t, k, v)
			end
		end,
	})
end
Instance = { new = function(c)
	return newInst(c)
end }

---------------------------------------------------------------- serviços
local SoundService = newInst("SoundService")
local ReplicatedStorage = newInst("ReplicatedStorage")
local Shared = newInst("Folder", "Shared")
Shared.Parent = ReplicatedStorage
local Remotes = newInst("Folder", "Remotes")
Remotes.Parent = ReplicatedStorage
for _, n in ipairs({ "Effect", "Notify", "Hatched", "Purchased", "Progress", "FoodReward", "LevelUp", "IslandEvent" }) do
	local r = newInst("RemoteEvent", n)
	r.OnClientEvent = signal()
	r.Parent = Remotes
end
for _, n in ipairs(SHARED_NAMES) do
	local m = newInst("ModuleScript", n)
	m.Parent = Shared
end
local player = newInst("Player", "Tester")
player.UserId = 7
local PlayerGui = newInst("PlayerGui", "PlayerGui")
PlayerGui.Parent = player
local Players = { LocalPlayer = player }
workspace = newInst("Workspace")
workspace.CurrentCamera = newInst("Camera")
local Terrain = newInst("Terrain")
workspace.Terrain = Terrain
local tweens = {}
local SERVICES = {
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	SoundService = SoundService,
	ContentProvider = { PreloadAsync = function() end },
	TweenService = { Create = function(_, inst, _info, props)
		return { Play = function()
			for k, v in pairs(props) do
				inst[k] = v
			end
		end }
	end },
	GuiService = { GetGuiInset = function()
		return { Y = 58 }, { Y = 0 }
	end },
	CollectionService = { GetTagged = function()
		return {}
	end, GetInstanceAddedSignal = function()
		return signal()
	end },
}
game = { GetService = function(_, n)
	return assert(SERVICES[n], "serviço sem mock: " .. n)
end }

-- módulos (require pelo nome)
local Client = newInst("Folder", "Client")
local UIf = newInst("Folder", "UI")
UIf.Parent = Client
local Icons = newInst("ModuleScript", "Icons")
Icons.Parent = UIf
local Systems = newInst("Folder", "Systems")
Systems.Parent = Client
local MusicMod = newInst("ModuleScript", "Music")
MusicMod.Parent = Systems
local SfxMod = newInst("ModuleScript", "Sfx")
SfxMod.Parent = Systems
MODULES.Icons = function()
	return { Make = function()
		return newInst("ImageLabel")
	end, Set = function() end }
end
local cache = {}
function require(m)
	local name = m.Name
	if cache[name] == nil then
		cache[name] = assert(MODULES[name], "módulo desconhecido: " .. tostring(name))(m)
	end
	return cache[name]
end

---------------------------------------------------------------- testes
local passed, failed = 0, 0
local function check(ok, what)
	if ok then
		passed += 1
	else
		failed += 1
		print("FALHOU: " .. what)
	end
end
local function near(a, b)
	return math.abs(a - b) < 1e-6
end

local MusicPacks = require(Shared:FindFirstChild("MusicPacks"))
local MusicConfig = require(Shared:FindFirstChild("MusicConfig"))
local SfxConfig = require(Shared:FindFirstChild("SfxConfig"))
check(MusicPacks.Songs.Village and MusicPacks.Songs.Boss and MusicPacks.Songs.Gotcha, "MusicPacks tem as músicas e vinhetas")
for _, pack in pairs(MusicPacks.Packs) do
	check(pack == 0, "pacote de música ainda sem ID no código (o PUBLICAR.bat coloca)")
end

-- 1) pacotes "enviados" (IDs de mentira)
MusicPacks.Packs.MusicA, MusicPacks.Packs.MusicB, MusicPacks.Packs.MusicC = 111, 222, 333
local Music = require(MusicMod)
player:SetAttribute("Island", "village")
Music.Start({})
advance(0.1)
local folder = SoundService:FindFirstChild("Musicas")
check(folder ~= nil, "pasta das músicas")
local village = folder and folder:FindFirstChild("Village")
check(village and village.SoundId == "rbxassetid://111", "Village vem do pacote A")
local info = MusicPacks.Songs.Village
check(village and village.PlaybackRegionsEnabled and near(village.PlaybackRegion.Min, info.Start) and near(village.PlaybackRegion.Max, info.Start + info.Length), "Village: PlaybackRegion = trecho certo")
check(village and village.Looped and near(village.LoopRegion.Min, info.Start) and near(village.LoopRegion.Max, info.Start + info.Length), "Village: LoopRegion = mesmo trecho (loop perfeito)")
check(Music.Current() == "Village" and village.IsPlaying and village.Volume == 1, "na Pawville toca a Village")

player:SetAttribute("Island", "common")
advance(2)
check(Music.Current() == "Meadows", "ilha 1 → Meadows (" .. tostring(Music.Current()) .. ")")
check(folder:FindFirstChild("Meadows").IsPlaying and village.Volume == 0, "crossfade: a Village abaixa e a Meadows toca")
advance(175)
check(Music.Current() == "Adventure", "revezamento: depois de um tempo vem a Adventure (" .. tostring(Music.Current()) .. ")")
advance(175)
check(Music.Current() == "Meadows", "revezamento volta para a Meadows")
player:SetAttribute("Island", "cloud")
advance(2)
check(Music.Current() == "Mystic", "ilha das nuvens → Mystic")
player:SetAttribute("Island", "colosseum")
player:SetAttribute("DogState", "arena")
advance(2)
check(Music.Current() == "Arena", "Coliseu → Arena")
workspace:SetAttribute("SuperBossAwake", true)
advance(2)
check(Music.Current() == "Boss", "Super Boss acordado → Boss")
workspace:SetAttribute("SuperBossAwake", false)
player:SetAttribute("DogState", nil)
player:SetAttribute("Island", "village")
advance(2)
check(Music.Current() == "Village", "voltou para a Pawville → Village de novo")

-- vinheta
local before = #SoundService:GetChildren()
Music.Jingle("Gotcha")
local jingle = SoundService:FindFirstChild("JingleGotcha")
local gi = MusicPacks.Songs.Gotcha
check(jingle and jingle.SoundId == "rbxassetid://333" and not jingle.Looped, "vinheta Gotcha: pacote C, sem loop")
check(jingle and near(jingle.PlaybackRegion.Min, gi.Start) and near(jingle.PlaybackRegion.Max, gi.Start + gi.Length), "vinheta Gotcha: trecho certo")
local group = SoundService:FindFirstChild("Musica")
check(group and group.Volume < MusicConfig.MusicVolume, "a música abaixa durante a vinheta")
advance(gi.Length + 1)
check(jingle.Destroyed and near(group.Volume, MusicConfig.MusicVolume), "vinheta acaba: some e a música volta")

-- 2) sem os pacotes novos: trilha antiga
cache.Music = nil
MusicPacks.Packs.MusicA, MusicPacks.Packs.MusicB, MusicPacks.Packs.MusicC = 0, 0, 0
local SS2 = newInst("SoundService")
SERVICES.SoundService = SS2
local Music2 = require(MusicMod)
player:SetAttribute("Island", "village")
Music2.Start({})
advance(0.1)
local f2 = SS2:FindFirstChild("Musicas")
check(f2 and f2:FindFirstChild("Village") == nil, "sem pacote: não cria a música nova")
local main = f2 and f2:FindFirstChild("Antiga_Main")
check(main and main.IsPlaying and main.Looped, "sem pacote: a trilha antiga (Main) toca no lugar")

-- 3) efeitos: pacote antigo (Pack2 = 0)
check(SfxConfig.Pack2 == 0 and SfxConfig.Pack > 0, "efeitos: pacote 2 sem ID, antigo com ID")
local Sfx = require(SfxMod)
local HUD = { MenuChanged = signal(), Toast = function() end }
Sfx.Start(HUD)
check(type(HUD.OnToast) == "function", "efeitos: avisos do HUD ganham som")
local ui = SS2:FindFirstChild("SfxUI")
Sfx.Play("Yip")
local yip = ui and ui:FindFirstChild("Yip")
local old = SfxConfig.OldRegions.Bark
check(yip and yip.SoundId == "rbxassetid://" .. SfxConfig.Pack and near(yip.PlaybackRegion.Min, old[1]), "sem pacote 2: Yip toca o Bark do pacote antigo")
check(Sfx.Loop("AmbBirds") == nil, "sem pacote 2: sem ambiente (não dá erro)")
HUD.MenuChanged:Fire("Dogs")
check(ui:FindFirstChild("Open") ~= nil, "abrir menu toca Open")
HUD.OnToast("Not enough Cash!", "red")
check(ui:FindFirstChild("Error") ~= nil, "aviso vermelho toca Error")

-- 4) efeitos: pacote 2
cache.Sfx = nil
SfxConfig.Pack2 = 444
local SS3 = newInst("SoundService")
SERVICES.SoundService = SS3
local SfxB = require(SfxMod)
SfxB.Start(HUD)
local ui3 = SS3:FindFirstChild("SfxUI")
SfxB.Play("Yip")
local yip2 = ui3:FindFirstChild("Yip")
local r = SfxConfig.Regions.Yip
check(yip2 and yip2.SoundId == "rbxassetid://444" and near(yip2.PlaybackRegion.Min, r[1]) and near(yip2.PlaybackRegion.Max, r[1] + r[2]), "pacote 2: Yip é o trecho dele")
local birds = SfxB.Loop("AmbBirds")
local lr = SfxConfig.Loops.AmbBirds
check(birds and birds.Looped and near(birds.LoopRegion.Min, lr[1]) and near(birds.LoopRegion.Max, lr[1] + lr[2]) and birds.Volume == 0, "pacote 2: ambiente em loop (começa mudo)")
for name in pairs(SfxConfig.Regions) do
	check(SfxB.Has(name), "pacote 2 tem " .. name)
end
-- todo som que o jogo pede existe no pacote 2
for _, name in ipairs(USED) do
	check(SfxConfig.Regions[name] ~= nil, "o jogo pede o som " .. name .. " e ele existe")
end

-- 5) voz pelo tamanho
check(SfxB.VoiceFor(2.0) == "Yip", "cachorro pequeno: Yip")
local mid = SfxB.VoiceFor(3.2)
check(mid == "Bark" or mid == "Bark2", "cachorro médio: Bark")
check(SfxB.VoiceFor(6) == "Woof", "cachorro grande: Woof")
check(SfxB.VoiceFor(3, "howl") == "Howl" and SfxB.VoiceFor(3, "growl") == "Growl", "uivo e rosnado")

print(string.format("RESULTADO: %d ok, %d falharam, %d erros de execução", passed, failed, ERRORS))
'''


def module(name, path, prelude=''):
    return f'MODULES[{json.dumps(name)}] = function(script)\n{prelude}{open(path, encoding="utf-8").read()}\nend\n'


def used_sounds():
    """nomes de sons pedidos no código do cliente (Sfx.Play("X"... / sfx("X"...)"""
    import re
    names = set()
    for dirpath, _, files in os.walk(os.path.join(SRC, 'client')):
        for f in files:
            if f.endswith('.lua'):
                text = open(os.path.join(dirpath, f), encoding='utf-8').read()
                names.update(re.findall(r'(?:sfx|sfxAt|Sfx\.Play|S\.Play)\("([A-Z][A-Za-z0-9]+)"', text))
    return sorted(names)


def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass
    shared = ['MusicConfig', 'MusicPacks', 'SfxConfig']
    out = ['ERRORS = 0\nCLOCK = 1000\nMODULES = {}\n',
           'SHARED_NAMES = ' + json.dumps(shared).replace('[', '{').replace(']', '}') + '\n',
           'USED = ' + json.dumps(used_sounds()).replace('[', '{').replace(']', '}') + '\n']
    for n in shared:
        out.append(module(n, os.path.join(SRC, 'shared', n + '.lua')))
    out.append(module('Music', os.path.join(SRC, 'client', 'Systems', 'Music.lua'), PRELUDE))
    out.append(module('Sfx', os.path.join(SRC, 'client', 'Systems', 'Sfx.lua'), PRELUDE))
    out.append(HARNESS)
    bundle = os.path.join(tempfile.gettempdir(), 'audio_test_bundle.luau')
    open(bundle, 'w', encoding='utf-8').write(''.join(out))
    res = subprocess.run([LUAU, bundle], capture_output=True, text=True, encoding='utf-8', errors='replace')
    sys.stdout.write(res.stdout)
    if res.returncode != 0 or 'FALHOU' in res.stdout or ' 0 erros' not in res.stdout:
        sys.stderr.write(res.stderr[-4000:])
        sys.exit(1)


if __name__ == '__main__':
    main()
