"""📸 FOTOS DAS HABILIDADES sem Roblox (2026-10).

Roda habilidades de verdade (servidor: SkillKit + Skills_*.lua; cliente: PackSkills + SkillArt) no mini-mundo do
skills_harness.luau com os cachorros montados pelo DogBuilder, e tira "fotos" (todas as peças dos efeitos e dos
cachorros) em alguns momentos. Sai um JSON no formato do render.html (cada foto = uma "carta").
Partículas, luzes e textos não aparecem (só peças).

Uso:  python tools/preview/skill_shots.py saida.json SK_caramelo_2 SK_pug_3 ... [--times 0.3,0.7,1.2] [--target pug]
      python tools/preview/skill_shots.py saida.json --rarity Epic --times 1.0
Foto: servir tools/preview (python -m http.server) e abrir render.html: window.buildSheet(json, opções).
"""
import glob, json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import skills_test as T  # noqa: E402


def main():
    args = sys.argv[1:]
    if len(args) < 2:
        sys.exit(__doc__)
    out = args[0]
    times = [0.4, 0.9, 1.5]
    target = 'caramelo'
    rarity = None
    ids = []
    i = 1
    while i < len(args):
        a = args[i]
        if a == '--times':
            times = [float(x) for x in args[i + 1].split(',')]
            i += 2
        elif a == '--target':
            target = args[i + 1]
            i += 2
        elif a == '--rarity':
            rarity = args[i + 1]
            i += 2
        else:
            ids.append(a)
            i += 1
    src = T.SRC
    if rarity:
        text = open(os.path.join(src, 'shared', 'Skills.lua'), encoding='utf-8').read()
        # lista na ordem do catálogo; filtra pela raridade com a lista do teste
        res = subprocess.run([sys.executable, os.path.join(HERE, 'skills_test.py'), '--all', '--no-client'], capture_output=True, text=True, encoding='utf-8', errors='replace')
        for line in res.stdout.splitlines():
            m = re.match(r'^(SK_\S+)\s+(\w+)\s+tecla', line)
            if m and m.group(2) == rarity:
                ids.append(m.group(1))
    shared = sorted(glob.glob(os.path.join(src, 'shared', '*.lua')))
    packs = sorted(glob.glob(os.path.join(src, 'shared', 'DogPacks', '*.lua')))
    skill_packs = sorted(glob.glob(os.path.join(src, 'server', 'Services', 'SpecialsPacks', 'Skills_*.lua')))
    parts = ['local MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
             'local MODULES = {}\n']
    for p in shared + packs:
        parts.append(T.module(os.path.basename(p)[:-4], p))
    parts.append(T.module('SkillKit', os.path.join(src, 'server', 'Services', 'SkillKit.lua')))
    for p in skill_packs:
        parts.append(T.module(os.path.basename(p)[:-4], p))
    parts.append(T.module('SkillArt', os.path.join(src, 'client', 'SkillArt.lua')))
    parts.append(T.module('PackSkills', os.path.join(src, 'client', 'EffectsPacks', 'PackSkills.lua')))
    own_text = open(os.path.join(src, 'client', 'EffectsPacks', 'PackSkills.lua'), encoding='utf-8').read()
    own = set(re.findall(r'function H\.([A-Za-z_0-9]+)', own_text))
    legacy = sorted(T.client_handlers() - own)
    parts.append('CLIENT_ON = true\nLEGACY_FX = %s\n' % T.lua_list(legacy))
    parts.append('SNAP_IDS = %s\nSNAP_TIMES = {%s}\nSNAP_TARGET = %s\nSNAP_SPECIES = {}\n' % (
        T.lua_list(ids), ', '.join(str(t) for t in times), json.dumps(target)))
    parts.append('SHARED_NAMES = %s\nPACK_NAMES = %s\nSKILL_PACKS = %s\n' % (
        T.lua_list([os.path.basename(p)[:-4] for p in shared]),
        T.lua_list([os.path.basename(p)[:-4] for p in packs]),
        T.lua_list([os.path.basename(p)[:-4] for p in skill_packs])))
    parts.append(open(os.path.join(HERE, 'skills_harness.luau'), encoding='utf-8').read())
    bundle = os.path.join(tempfile.gettempdir(), 'skill_shots_bundle.luau')
    open(bundle, 'w', encoding='utf-8').write(''.join(parts))
    res = subprocess.run([T.LUAU, bundle], capture_output=True, text=True, encoding='utf-8', errors='replace')
    if res.returncode != 0:
        sys.stderr.write(res.stdout[-3000:] + '\n' + res.stderr[-3000:])
        sys.exit('luau falhou')
    shots, cur = [], None
    for line in res.stdout.splitlines():
        f = line.split('|')
        if f[0] == 'DOG':
            cur = {'id': f[1], 'name': f[1], 'label': f[1], 'rarity': '', 'rarityLabel': '', 'rarityColor': [1, 1, 1],
                   'hip': 0, 'rootY': 0, 'parts': []}
            shots.append(cur)
        elif f[0] == 'P' and cur is not None:
            cur['parts'].append({
                'cls': f[1], 'shape': f[2], 'mesh': f[3],
                'size': [float(v) for v in f[4:7]],
                'cf': [float(v) for v in f[7:19]],
                'color': [float(v) for v in f[19:22]],
                'mat': f[22], 'tr': float(f[23]), 'name': f[24],
            })
        elif line.startswith('ERRO'):
            print(line)
    json.dump(shots, open(out, 'w'))
    print('ok:', len(shots), 'fotos de', len(ids), 'habilidades')


if __name__ == '__main__':
    main()
