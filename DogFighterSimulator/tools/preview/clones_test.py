"""TESTE DOS CLONES DO SPOOKY CLOWN (2026-10) sem Roblox — roda clones_test.luau em 2 partes:
  1. Fighters.Hostile DE VERDADE com clones (dono, selvagem, PvP do Coliseu, Super Boss, outra ilha, casa, setinha)
  2. CloneService DE VERDADE (Fighters/CombatService falsos, relógio falso): nascem 2 clones só para o palhaço,
     seguem o dono, batem junto, soltam a mesma habilidade ao lado da setinha, dash junto, voltam depois de cair,
     teleportam junto e somem quando o dono cai ou troca de cachorro.
Uso:  python tools/preview/clones_test.py        (Luau: variável LUAU, como no dump.py)
"""
import glob, json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(ROOT, 'src')
LOCAL_LUAU = os.path.abspath(os.path.join(ROOT, '..', '..', 'ferramentas', 'luau-0.740', 'luau.exe'))
LUAU = os.environ.get('LUAU') or (LOCAL_LUAU if os.path.exists(LOCAL_LUAU) else 'luau')


def module(name, path):
    return 'MODULES[%s] = function(script)\n%s\nend\n' % (json.dumps(name), open(path, encoding='utf-8').read())


def lua_list(names):
    return '{' + ', '.join(json.dumps(n) for n in names) + '}'


def run(part):
    shared = sorted(glob.glob(os.path.join(SRC, 'shared', '*.lua')))
    packs = sorted(glob.glob(os.path.join(SRC, 'shared', 'DogPacks', '*.lua')))
    parts = ['local MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
             'local MODULES = {}\n']
    for p in shared + packs:
        parts.append(module(os.path.basename(p)[:-4], p))
    for name in ['Fighters', 'CloneService']:
        parts.append(module(name, os.path.join(SRC, 'server', 'Services', name + '.lua')))
    parts.append('SHARED_NAMES = %s\nPACK_NAMES = %s\nPART = %s\n' % (
        lua_list([os.path.basename(p)[:-4] for p in shared]), lua_list([os.path.basename(p)[:-4] for p in packs]),
        json.dumps(part)))
    parts.append(open(os.path.join(HERE, 'clones_test.luau'), encoding='utf-8').read())
    bundle = os.path.join(tempfile.gettempdir(), 'clones_test_bundle_%s.luau' % part)
    open(bundle, 'w', encoding='utf-8').write(''.join(parts))
    res = subprocess.run([LUAU, bundle], capture_output=True, text=True, encoding='utf-8', errors='replace')
    if res.returncode != 0:
        sys.stderr.write(res.stderr[-3000:] + res.stdout[-3000:])
        return None
    fails = None
    for line in res.stdout.splitlines():
        if line.startswith('OK|') or line.startswith('FAIL|'):
            print(('✅ ' if line.startswith('OK|') else '❌ ') + line.split('|', 1)[1])
        elif line.startswith('END|'):
            fails = int(line.split('|')[1])
        elif line.startswith('[warn]') or 'erro' in line:
            print('   ' + line)
    return fails


def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass
    total = 0
    for part in ('hostile', 'service'):
        print('== %s ==' % part)
        fails = run(part)
        if fails is None:
            print('❌ luau falhou na parte', part)
            total += 1
        else:
            total += fails
    print('✅ clones OK' if total == 0 else '❌ %d problema(s) nos clones' % total)
    sys.exit(1 if total else 0)


if __name__ == '__main__':
    main()
