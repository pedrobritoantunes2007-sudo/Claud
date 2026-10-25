"""TESTE DO RECOMEÇO DE TODOS (2026-10-25, pedido do dono: "quero reiniciar o de todos" → "zerar progresso de todos").

Roda o server/Services/DataService.lua DE VERDADE num mini-Roblox (mock.luau) com um DataStore falso de dois saves:
o antigo (Config.OLD_DATASTORE_NAME) e o novo (Config.DATASTORE_NAME). Confere: quem jogava começa do ZERO no save novo
(sem cachorro, sem Cash, tutorial de novo) mas fica com o que pagou com Robux (Config.RESTART_KEEP); o save antigo só é
LIDO (nunca escrito) e só na 1ª entrada; quem é novo entra normal; se o save antigo não puder ser lido, o jogador sai
sem perder nada e na próxima entrada traz as compras.

Uso:  python tools/preview/reset_test.py
"""
import glob, json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(ROOT, 'src')
LOCAL_LUAU = os.path.abspath(os.path.join(ROOT, '..', '..', 'ferramentas', 'luau-0.740', 'luau.exe'))
LUAU = os.environ.get('LUAU') or (LOCAL_LUAU if os.path.exists(LOCAL_LUAU) else 'luau')

HARNESS = r'''
---------------------------------------------------------------- tarefas: wait/delay ficam parados até pump()
local waiting, delayed = {}, {}
local function run(fn, ...)
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		print("ERRO numa tarefa: " .. tostring(err))
		ERRORS += 1
	end
	return co
end
task = {
	spawn = run,
	defer = run,
	wait = function()
		local co = coroutine.running()
		table.insert(waiting, co)
		coroutine.yield()
		return 0
	end,
	delay = function(_, fn, ...)
		table.insert(delayed, { fn, { ... } })
	end,
}
local function pump(n)
	for _ = 1, n or 1 do
		local list = waiting
		waiting = {}
		for _, co in ipairs(list) do
			if coroutine.status(co) == "suspended" then
				local ok, err = coroutine.resume(co)
				if not ok then
					print("ERRO numa tarefa: " .. tostring(err))
					ERRORS += 1
				end
			end
		end
	end
	local d = delayed
	delayed = {}
	for _, x in ipairs(d) do
		run(x[1], table.unpack(x[2]))
	end
end

local function signal()
	local fns = {}
	local s = {}
	function s:Connect(fn)
		table.insert(fns, fn)
		return { Disconnect = function() end }
	end
	s.Event = s
	function s:Fire(...)
		for _, fn in ipairs(fns) do
			run(fn, ...) -- (como no Roblox: cada conexão roda na sua própria thread)
		end
	end
	return s
end

local function deep(t)
	if type(t) ~= "table" then
		return t
	end
	local o = {}
	for k, v in pairs(t) do
		o[k] = deep(v)
	end
	return o
end

---------------------------------------------------------------- DataStore falso
local stores = {}
local function newStore(name)
	local st = { Name = name, Data = {}, Gets = 0, Writes = 0, FailGet = false }
	function st:GetAsync(key)
		self.Gets += 1
		if self.FailGet then
			error("DataStore fora do ar")
		end
		return deep(self.Data[key])
	end
	function st:UpdateAsync(key, fn)
		self.Writes += 1
		local out = fn(deep(self.Data[key]))
		if out ~= nil then
			self.Data[key] = deep(out)
		end
		return out
	end
	return st
end
local DataStoreService = {
	GetDataStore = function(_, name)
		stores[name] = stores[name] or newStore(name)
		return stores[name]
	end,
}

---------------------------------------------------------------- Roblox falso
local players = {}
local kicked = {}
local PLAYERS_FOLDER = Instance.new("Folder")
PLAYERS_FOLDER.Name = "Players"
local function newPlayer(name, userId)
	local p = Instance.new("Player")
	p.Name = name
	p.UserId = userId
	p.DisplayName = name
	p.Parent = PLAYERS_FOLDER
	p.Kick = function(self, msg)
		kicked[self] = msg
		self.Parent = nil
	end
	return p
end
local PlayersService = {
	GetPlayers = function()
		return players
	end,
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
}
local REPLICATED = Instance.new("Folder")
REPLICATED.Name = "ReplicatedStorage"
Shared.Parent = REPLICATED
game = {
	JobId = "servidor-novo",
	BindToClose = function() end,
	GetService = function(_, name)
		if name == "Players" then
			return PlayersService
		elseif name == "ReplicatedStorage" then
			return REPLICATED
		elseif name == "DataStoreService" then
			return DataStoreService
		elseif name == "RunService" then
			return { IsStudio = function()
				return false
			end }
		end
		return {}
	end,
}
workspace = Instance.new("Folder")
workspace.Name = "Workspace"

local notes = {}
local function remote()
	return { FireClient = function() end, OnServerEvent = signal() }
end
local remotes = setmetatable({
	Notify = { FireClient = function(_, player, text)
		table.insert(notes, { player, text })
	end },
}, { __index = function(t, k)
	local r = remote()
	rawset(t, k, r)
	return r
end })

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
local function noted(p, fragment)
	for _, n in ipairs(notes) do
		if n[1] == p and string.find(n[2], fragment, 1, true) then
			return true
		end
	end
	return false
end
local function count(t)
	local n = 0
	for _ in pairs(t or {}) do
		n += 1
	end
	return n
end

local Config = require(Shared.Config)
check(Config.DATASTORE_NAME ~= Config.OLD_DATASTORE_NAME, "save novo tem outro nome")
local old = DataStoreService:GetDataStore(Config.OLD_DATASTORE_NAME)
local new = DataStoreService:GetDataStore(Config.DATASTORE_NAME)
-- quem jogava: cachorro forte, muito Cash, passe, recibo, giros e turbinada comprados
old.Data.player_1 = {
	Version = Config.DATA_VERSION, Started = true, Cash = 99999, Tutorial = 99, Equipped = "a",
	Dogs = { a = { Id = "a", Species = "caramelo", Name = "Rex", Level = 30, XP = 0 } },
	Purchases = { Passes = { LuckyPaw = true }, Receipts = { recibo1 = 1700000000 } },
	Spins = 7, LuckySpins = 2, Boosts = { Cash = 300 },
}
local oldCopy = deep(old.Data.player_1)

local DataService = require(Services.DataService)
DataService.Start(remotes)

local alice = newPlayer("Alice", 1)
players = { alice }
PlayersService.PlayerAdded:Fire(alice)
pump(2)
local a = DataService.Get(alice)
check(a ~= nil, "Alice carregou")
if a then
	check(a.Started == false and count(a.Dogs) == 0, "Alice começa SEM cachorro")
	check(a.Cash == 0, "Alice começa sem Cash ($" .. tostring(a.Cash) .. ")")
	check(a.Tutorial == 0, "Alice faz o tutorial de novo")
	check(a.Purchases and a.Purchases.Passes and a.Purchases.Passes.LuckyPaw == true, "o passe comprado veio junto")
	check(a.Purchases and a.Purchases.Receipts and a.Purchases.Receipts.recibo1 ~= nil, "os recibos vieram (compra não é entregue 2x)")
	check(a.Spins == 7 and a.LuckySpins == 2, "giros comprados vieram")
	check(a.Boosts and a.Boosts.Cash == 300, "turbinada comprada veio")
	check(a.Carried == true, "marcado: já trouxe do save antigo")
end
check(noted(alice, "RESTARTED"), "aviso de recomeço para quem jogava")
check(old.Writes == 0, "save antigo nunca é escrito")
check(old.Gets == 1, "save antigo lido 1 vez")

-- sai e volta: não lê o antigo de novo e continua com as compras
PlayersService.PlayerRemoving:Fire(alice)
pump(1)
check(new.Data.player_1 and new.Data.player_1.Carried == true and new.Data.player_1.Session == nil, "save novo gravado e liberado")
local alice2 = newPlayer("Alice", 1)
players = { alice2 }
notes = {}
PlayersService.PlayerAdded:Fire(alice2)
pump(2)
local a2 = DataService.Get(alice2)
check(a2 and a2.Spins == 7 and a2.Purchases.Passes.LuckyPaw == true, "voltou: compras continuam")
check(old.Gets == 1, "voltou: não lê o save antigo de novo")
check(not noted(alice2, "RESTARTED"), "voltou: sem aviso repetido")

-- jogador novo de verdade
local bob = newPlayer("Bob", 2)
players = { alice2, bob }
PlayersService.PlayerAdded:Fire(bob)
pump(2)
local b = DataService.Get(bob)
check(b and b.Started == false and b.Carried == true and b.Spins == 0, "jogador novo entra normal")
check(not noted(bob, "RESTARTED"), "jogador novo: sem aviso de recomeço")

-- save antigo fora do ar: sai sem perder nada e traz na próxima vez
old.Data.player_3 = { Version = Config.DATA_VERSION, Started = true, Cash = 5, Dogs = {}, Purchases = { Passes = { BigKennel = true } }, Spins = 3 }
old.FailGet = true
local carl = newPlayer("Carl", 3)
players = { alice2, bob, carl }
PlayersService.PlayerAdded:Fire(carl)
pump(8)
check(kicked[carl] ~= nil, "save antigo fora do ar: pede para voltar depois")
check(DataService.Get(carl) == nil, "nada carregado")
check(not (new.Data.player_3 and new.Data.player_3.Carried), "não marcou como trazido")
old.FailGet = false
local carl2 = newPlayer("Carl", 3)
players = { alice2, bob, carl2 }
PlayersService.PlayerAdded:Fire(carl2)
pump(2)
local c = DataService.Get(carl2)
check(c and c.Spins == 3 and c.Purchases.Passes.BigKennel == true and c.Started == false, "na próxima entrada trouxe as compras")

-- o save antigo continua igual (dá para desfazer)
local same = true
for k, v in pairs(oldCopy) do
	if type(v) ~= "table" and old.Data.player_1[k] ~= v then
		same = false
	end
end
check(same and old.Data.player_1.Dogs.a.Level == 30, "save antigo intacto (dá para voltar atrás)")

print(string.format("RESULTADO: %d ok, %d falharam, %d erros de execução", passed, failed, ERRORS))
'''


def module(name, path):
    return f'MODULES[{json.dumps(name)}] = function(script)\n{open(path, encoding="utf-8").read()}\nend\n'


def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass
    mods = sorted(glob.glob(os.path.join(SRC, 'shared', '*.lua')))
    packs = sorted(glob.glob(os.path.join(SRC, 'shared', 'DogPacks', '*.lua')))
    out = ['ERRORS = 0\nlocal MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
           'MODULES = {}\n']
    for p in mods + packs:
        out.append(module(os.path.basename(p)[:-4], p))
    out.append(module('DataService', os.path.join(SRC, 'server', 'Services', 'DataService.lua')))
    names = [os.path.basename(p)[:-4] for p in mods]
    pnames = [os.path.basename(p)[:-4] for p in packs]
    out.append('''
Shared = Instance.new("Folder")
Shared.Name = "Shared"
for _, n in ipairs(%s) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Parent = Shared
end
local packs = Instance.new("Folder")
packs.Name = "DogPacks"
packs.Parent = Shared
for _, n in ipairs(%s) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Parent = packs
end
Services = Instance.new("Folder")
Services.Name = "Services"
local ds = Instance.new("ModuleScript")
ds.Name = "DataService"
ds.Parent = Services
local cache = {}
function require(m)
	local name = m.Name
	if cache[name] == nil then
		cache[name] = assert(MODULES[name], "módulo desconhecido: " .. tostring(name))(m)
	end
	return cache[name]
end
''' % (json.dumps(names).replace('[', '{').replace(']', '}'), json.dumps(pnames).replace('[', '{').replace(']', '}')))
    out.append(HARNESS)
    bundle = os.path.join(tempfile.gettempdir(), 'reset_test_bundle.luau')
    open(bundle, 'w', encoding='utf-8').write(''.join(out))
    res = subprocess.run([LUAU, bundle], capture_output=True, text=True, encoding='utf-8', errors='replace')
    sys.stdout.write(res.stdout)
    if res.returncode != 0 or 'FALHOU' in res.stdout or ' 0 erros' not in res.stdout:
        sys.stderr.write(res.stderr[-4000:])
        sys.exit(1)


if __name__ == '__main__':
    main()
