"""Fotos das POSES dos cachorros sem abrir o Roblox: roda o DogBuilder (src/shared) e o Animator.lua (src/client)
DE VERDADE no mini-Roblox (mock.luau), monta cada pose com Animator.PoseAt e salva as peças em JSON
(o mesmo formato do dump.py, que o render.html desenha).

Uso:  python tools/preview/poses.py saida.json cachorro [lista.json]
- lista.json (opcional): [{"id": "voo", "label": "Voo rápido", "opts": {...opções do PoseAt...},
                           "root": {"pitch": 0, "yaw": 0, "roll": 0}}]   (root = inclinação do corpo inteiro, rad)
  Vetores (Look) vão como lista [x, y, z]. Sem lista usa a lista padrão (parado, olhar, andar, galope, voo...).
- Luau: variável de ambiente LUAU, ou ../../../../ferramentas/luau-0.740/luau.exe (pasta Dog Fighter), ou "luau".
Foto: servir esta pasta (python -m http.server) e abrir render.html; window.buildSheet(json, opções).
"""
import glob, json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SHARED = os.path.join(ROOT, 'src', 'shared')
CLIENT = os.path.join(ROOT, 'src', 'client')
LOCAL_LUAU = os.path.abspath(os.path.join(ROOT, '..', '..', 'ferramentas', 'luau-0.740', 'luau.exe'))
LUAU = os.environ.get('LUAU') or (LOCAL_LUAU if os.path.exists(LOCAL_LUAU) else 'luau')

DEFAULT_POSES = [
    {"id": "parado", "label": "Parado", "opts": {"Time": 0.4}},
    {"id": "olha_esq", "label": "Olhando a setinha (esquerda)", "opts": {"Look": [0.1, 1.7, 0]}},
    {"id": "olha_cima", "label": "Olhando para cima/direita", "opts": {"Look": [0.6, -0.9, 0]}},
    {"id": "curioso", "label": "Curioso (cabeça de lado)", "opts": {"Look": [-0.2, 0.3, 0.32]}},
    {"id": "animado", "label": "Animado (setinha rápida)", "opts": {"Excite": 1, "Time": 0.2}},
    {"id": "andar", "label": "Andando", "opts": {"Speed": 1.0, "Phase": 0.25}},
    {"id": "trote", "label": "Trote", "opts": {"Speed": 2.6, "Phase": 0.3}},
    {"id": "galope1", "label": "Galope (empurra)", "opts": {"Speed": 5.5, "Phase": 0.05}},
    {"id": "galope2", "label": "Galope (estica)", "opts": {"Speed": 5.5, "Phase": 0.55}},
    {"id": "sentado", "label": "Sentado olhando", "opts": {"Posture": "Sit", "Look": [0.25, 1.3, 0]}},
    {"id": "pulo", "label": "Pulo subindo", "opts": {"VelY": 14}},
    {"id": "queda", "label": "Caindo", "opts": {"VelY": -14, "AirT": 0.5}},
    {"id": "mordida", "label": "Mordida (bote)", "opts": {"Bite": 0.13}},
    {"id": "esquiva", "label": "Esquiva", "opts": {"Dodge": 0.17}},
    {"id": "rabo", "label": "Correndo atrás do rabo", "opts": {"Behavior": "chase", "BehaviorT": 1.1}},
    {"id": "voo", "label": "Voo planando (avião)", "opts": {"Action": "Fly", "ActionT": 3, "FlySpeed": 64}},
    {"id": "voo_curva", "label": "Voo em curva", "opts": {"Action": "Fly", "ActionT": 3, "FlySpeed": 64, "Yaw": 1.6},
     "root": {"roll": 0.7}},
    {"id": "voo_lento", "label": "Voo devagar (bate asa)", "opts": {"Action": "Fly", "ActionT": 3, "FlySpeed": 6, "Time": 0.1}},
    {"id": "voo_sobe", "label": "Voo subindo", "opts": {"Action": "Fly", "ActionT": 3, "FlySpeed": 45, "FlyVelY": 30, "Time": 0.05},
     "root": {"pitch": 0.55}},
    {"id": "voo_mergulho", "label": "Mergulho", "opts": {"Action": "Fly", "ActionT": 3, "FlySpeed": 55, "FlyVelY": -60},
     "root": {"pitch": -0.8}},
]


def luau_value(v, key=None):
    if key == 'Look' and isinstance(v, list):
        return 'Vector3.new(%s)' % ', '.join(str(float(x)) for x in v)
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, float)):
        return repr(float(v))
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, list):
        return '{ ' + ', '.join(luau_value(x) for x in v) + ' }'
    if isinstance(v, dict):
        return '{ ' + ', '.join('%s = %s' % (k, luau_value(x, k)) for k, x in v.items()) + ' }'
    raise ValueError(v)


def module(name, path):
    src = open(path, encoding='utf-8').read()
    return f'MODULES[{json.dumps(name)}] = function(script)\n{src}\nend\n'


def main():
    args = sys.argv[1:]
    if len(args) < 2:
        sys.exit(__doc__)
    out_path, dog = args[0], args[1]
    poses = json.load(open(args[2], encoding='utf-8')) if len(args) > 2 else DEFAULT_POSES

    parts = ['local MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
             'local MODULES = {}\n']
    for name in ['Config', 'DogData', 'AntiPisca', 'DogBuilder']:
        parts.append(module(name, os.path.join(SHARED, name + '.lua')))
    packs = sorted(glob.glob(os.path.join(SHARED, 'DogPacks', '*.lua')))
    for p in packs:
        parts.append(module(os.path.basename(p)[:-4], p))
    parts.append(module('Animator', os.path.join(CLIENT, 'Animator.lua')))
    pack_names = [os.path.basename(p)[:-4] for p in packs]
    pose_list = '{\n' + ',\n'.join('\t{ id = %s, label = %s, opts = %s, root = %s }' % (
        json.dumps(p['id'], ensure_ascii=False), json.dumps(p.get('label', p['id']), ensure_ascii=False), luau_value(p.get('opts', {})),
        luau_value(p.get('root', {}))) for p in poses) + '\n}'

    parts.append('''
-- o mínimo do Roblox que o Animator usa no PoseAt (serviços, sinais, raio)
local SIG = { Connect = function() return { Disconnect = function() end } end }
MOCK.InstMethods.DescendantAdded = SIG
MOCK.InstMethods.DescendantRemoving = SIG
MOCK.InstMethods.AncestryChanged = SIG
local services = {
	CollectionService = { GetInstanceAddedSignal = function() return SIG end, GetTagged = function() return {} end,
		HasTag = function() return false end, AddTag = function() end },
	Debris = { AddItem = function() end },
	Players = {},
	RunService = { PreSimulation = SIG, Heartbeat = SIG, RenderStepped = SIG },
}
game = { GetService = function(_, name) return services[name] or {} end }
workspace = { Raycast = function() return nil end }
RaycastParams = { new = function() return {} end }

local shared = Instance.new("Folder")
shared.Name = "Shared"
for _, n in ipairs({ "Config", "DogData", "AntiPisca", "DogBuilder" }) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Parent = shared
end
local packs = Instance.new("Folder")
packs.Name = "DogPacks"
packs.Parent = shared
for _, n in ipairs(%s) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Parent = packs
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
local DogData = require(shared.DogData)
local DogBuilder = require(shared.DogBuilder)
local Config = require(shared.Config)
local animScript = Instance.new("ModuleScript")
animScript.Name = "Animator"
local Animator = require(animScript)

local id = %s
local sp = assert(DogData.Species[id], "cachorro não existe: " .. id)
local model = DogBuilder.Build(id)
local root = model.PrimaryPart
local joints = {}
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("JointInstance") and d.Part0 and d.Part1 then
		table.insert(joints, d)
	end
end
-- posições das peças a partir do HumanoidRootPart, seguindo as juntas (Part1 = Part0 * C0 * C1^-1)
local function solve(rootCF)
	root.CFrame = rootCF
	local done = { [root] = true }
	local progress = true
	while progress do
		progress = false
		for _, j in ipairs(joints) do
			local p0, p1 = j.Part0, j.Part1
			if done[p0] and not done[p1] then
				p1.CFrame = p0.CFrame * j.C0 * j.C1:Inverse()
				done[p1] = true
				progress = true
			elseif done[p1] and not done[p0] then
				p0.CFrame = p1.CFrame * j.C1 * j.C0:Inverse()
				done[p0] = true
				progress = true
			end
		end
	end
end
local function f(n)
	return string.format("%%.4f", n)
end
local r = Config.RARITY[sp.Rarity]
for _, pose in ipairs(%s) do
	local rc = pose.root
	local rootCF = CFrame.Angles(0, rc.yaw or 0, 0) * CFrame.Angles(rc.pitch or 0, 0, 0) * CFrame.Angles(0, 0, rc.roll or 0)
	root.CFrame = rootCF
	local ok, err = pcall(Animator.PoseAt, model, pose.opts)
	if not ok then
		print("ERR|" .. pose.id .. "|" .. tostring(err))
		continue
	end
	solve(rootCF)
	print(string.format("DOG|%%s|%%s|%%s|%%s|%%s|%%s", pose.id, pose.label, sp.Name, f(r.Color.R) .. "," .. f(r.Color.G) .. "," .. f(r.Color.B), f(model:GetAttribute("GroundHip") or 0), f(root.Size.Y)))
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.98 then
			local mesh = p:FindFirstChildOfClass("SpecialMesh")
			local x, y, z, a, b, c, d, e, g, h, i, j = p.CFrame:GetComponents()
			print(table.concat({
				"P", p.ClassName, p.Shape and p.Shape.Name or "Block", mesh and mesh.MeshType and mesh.MeshType.Name or "",
				f(p.Size.X), f(p.Size.Y), f(p.Size.Z),
				f(x), f(y), f(z), f(a), f(b), f(c), f(d), f(e), f(g), f(h), f(i), f(j),
				f(p.Color.R), f(p.Color.G), f(p.Color.B),
				p.Material and p.Material.Name or "Plastic", f(p.Transparency), p.Name,
			}, "|"))
		end
	end
end
''' % (json.dumps(pack_names).replace('[', '{').replace(']', '}'), json.dumps(dog), pose_list))

    bundle = os.path.join(tempfile.gettempdir(), 'dog_poses_bundle.luau')
    open(bundle, 'w', encoding='utf-8').write(''.join(parts))
    res = subprocess.run([LUAU, bundle], capture_output=True, text=True, encoding='utf-8', errors='replace')
    if res.returncode != 0:
        sys.stderr.write(res.stderr[-3000:] + res.stdout[-2000:])
        sys.exit('luau falhou')
    dogs, cur = [], None
    for line in res.stdout.splitlines():
        f = line.split('|')
        if f[0] == 'DOG':
            cur = {'id': f[1], 'name': f[2], 'label': f[2], 'rarity': f[3], 'rarityLabel': f[3],
                   'rarityColor': [float(v) for v in f[4].split(',')], 'hip': float(f[5]), 'rootY': float(f[6]), 'parts': []}
            dogs.append(cur)
        elif f[0] == 'P' and cur is not None:
            cur['parts'].append({
                'cls': f[1], 'shape': f[2], 'mesh': f[3],
                'size': [float(v) for v in f[4:7]],
                'cf': [float(v) for v in f[7:19]],
                'color': [float(v) for v in f[19:22]],
                'mat': f[22], 'tr': float(f[23]), 'name': f[24],
            })
        elif f[0] == 'ERR':
            print('ERRO na pose', f[1], f[2])
        elif line.strip():
            print(line)
    json.dump(dogs, open(out_path, 'w'))
    print('ok:', len(dogs), 'poses de', dog)


if __name__ == '__main__':
    main()
