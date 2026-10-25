"""Tamanho dos cachorros NO JOGO (DogData.GAME_SIZE) — mede o topo da cabeça de cada um e sugere o fator.

Uso:  python tools/preview/sizes.py            -> tabela: cabeça no jogo hoje (studs) e o fator sugerido
      python tools/preview/sizes.py --lua      -> imprime a tabela DogData.GAME_SIZE sugerida (para colar)

Regra (2026-10, pedido do dono: "a maioria um tamanho pequeno que pareça cachorro"): cabeça até 2,8 studs fica
como o DogBuilder desenha; acima disso cresce só 32% do resto (os gigantes encolhem muito) e cada raridade ganha um
bônus pequeno (BONUS). O boneco do Roblox tem ~5 studs. Também mostra o vão do degrau (MIN_CLEAR do Fighters):
pernas curtas ganham "lift" (a caixa do corpo sobe para subir degraus de 1 stud).
"""
import json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
BONUS = {'Common': 1.0, 'Uncommon': 1.0, 'Rare': 1.02, 'Epic': 1.05, 'Legendary': 1.08, 'Mythic': 1.12, 'Divine': 1.3,
         'Halloween': 1.1}
KNEE, SOFT, MIN_CLEAR = 2.8, 0.32, 1.15
ORDER = ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Mythic', 'Divine', 'Halloween']


def ext(p):
    cf = p['cf']; sx, sy, sz = p['size']
    R = [cf[3:6], cf[6:9], cf[9:12]]
    return [(cf[i] - (abs(R[i][0]) * sx + abs(R[i][1]) * sy + abs(R[i][2]) * sz) / 2,
             cf[i] + (abs(R[i][0]) * sx + abs(R[i][1]) * sy + abs(R[i][2]) * sz) / 2) for i in range(3)]


def head_height(g):
    """topo da cabeça (Head1) acima das patas, na escala do DogBuilder (sem o fator do jogo)"""
    legs = [p for p in g['parts'] if p['name'] in ('Pata', 'Dedo', 'Canela', 'LegFL', 'LegFR', 'LegBL', 'LegBR')]
    vis = [p for p in g['parts'] if p['tr'] < 0.9]
    ground = min(ext(p)[1][0] for p in (legs or vis))
    head = [p for p in g['parts'] if p['name'] == 'Head1']
    if head:
        return max(ext(p)[1][1] for p in head) - ground
    torso = [p for p in g['parts'] if p['name'] == 'Torso']
    return (max(ext(p)[1][1] for p in torso) - ground) * 1.5 if torso else 3.0


def suggested(h1, rarity):
    tgt = h1 if h1 <= KNEE else KNEE + (h1 - KNEE) * SOFT
    return round(tgt * BONUS.get(rarity, 1) / h1, 2)


def current_table():
    src = open(os.path.join(ROOT, 'src', 'shared', 'DogData.lua'), encoding='utf-8').read()
    m = re.search(r'DogData\.GAME_SIZE = \{(.*?)\n\}', src, re.S)
    return {k: float(v) for k, v in re.findall(r'(\w+) = ([\d.]+)', m.group(1))} if m else {}


def main():
    out = os.path.join(tempfile.gettempdir(), 'dog_sizes_dump.json')
    subprocess.run([sys.executable, os.path.join(HERE, 'dump.py'), out, 'ALL'], check=True, stdout=subprocess.DEVNULL)
    dogs = json.load(open(out))
    table = current_table()
    rows = []
    for g in dogs:
        h1 = head_height(g)
        G = table.get(g['id'], 1)
        hip = g.get('groundHip', g['hip']) * G
        rows.append((g['rarity'], g['id'], round(h1 * G, 2), G, suggested(h1, g['rarity']), round(hip, 2),
                     round(max(0, MIN_CLEAR - hip), 2)))
    rows.sort(key=lambda r: (ORDER.index(r[0]) if r[0] in ORDER else 99, r[2]))
    if '--lua' in sys.argv:
        for rarity in ORDER:
            items = sorted((r[1], r[4]) for r in rows if r[0] == rarity)
            if items:
                print('\t-- ' + rarity.lower())
                line = '\t'
                for i, v in items:
                    item = '%s = %s, ' % (i, ('%.2f' % v).rstrip('0').rstrip('.'))
                    if len(line) + len(item) > 118:
                        print(line.rstrip())
                        line = '\t'
                    line += item
                print(line.rstrip())
        return
    print('%-10s %-20s %10s %7s %9s %7s %6s' % ('raridade', 'cachorro', 'cabeça(st)', 'fator', 'sugerido', 'perna', 'lift'))
    for r in rows:
        print('%-10s %-20s %10s %7s %9s %7s %6s' % r)


if __name__ == '__main__':
    main()
