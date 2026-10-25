"""TESTE DAS HABILIDADES SEM ROBLOX (2026-10).

Roda TODAS as habilidades novas (server/Services/SkillKit.lua + SpecialsPacks/Skills_*.lua) num mini-mundo com
relógio falso (skills_harness.luau) em 4 cenários: inimigo de verdade, alvo invisível com inimigo perto, alvo
invisível sozinho e 🎯 MIRA DO JOGADOR (setinha longe, jogador no controle). Confere:
  - erro de código (qualquer erro em qualquer cenário)
  - se a habilidade termina (e quanto tempo prende o cachorro)
  - dano no alvo principal em "orçamentos" (1.00 = todo o orçamento da raridade, Config.SKILL_TIER)
  - se todo efeito "Fx" usado existe no cliente (client/Effects.lua + client/EffectsPacks/*.lua)
  - se toda pose (SetAction) existe no Animator (senão cai na genérica)
  - parâmetros estranhos (posição não-Vector3, NaN, raio negativo...)
  - se buffs (velocidade, escudo, fúria) voltaram ao normal
  - 🎯 mira do jogador (2026-10, "onde está a seta o ataque vai, sem travar, rápido"): quanto tempo o servidor segura
    o corpo (só nos movimentos), quanto o cachorro anda (no máximo Config.SKILL_MOVE × área), se o kit mexeu no
    corpo sem segurar, se sobrou o corpo preso no fim e se a habilidade foi atrás de um inimigo do lado

Uso:  python tools/preview/skills_test.py              (resumo + problemas)
      python tools/preview/skills_test.py --all        (uma linha por habilidade)
      python tools/preview/skills_test.py --no-client  (sem os desenhos do cliente: mais rápido)
No cenário A os efeitos "S_*" do cliente (client/EffectsPacks/PackSkills.lua + client/SkillArt.lua) rodam DE
VERDADE, quadro a quadro, com os mesmos dados que o servidor mandou (erros aparecem como "cliente ...").
"""
import glob, json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(ROOT, 'src')
LOCAL_LUAU = os.path.abspath(os.path.join(ROOT, '..', '..', 'ferramentas', 'luau-0.740', 'luau.exe'))
LUAU = os.environ.get('LUAU') or (LOCAL_LUAU if os.path.exists(LOCAL_LUAU) else 'luau')


def module(name, path):
    return f'MODULES[{json.dumps(name)}] = function(script)\n{open(path, encoding="utf-8").read()}\nend\n'


def lua_list(names):
    return '{' + ', '.join(json.dumps(n) for n in names) + '}'


def client_handlers():
    names = set()
    files = [os.path.join(SRC, 'client', 'Effects.lua')] + glob.glob(os.path.join(SRC, 'client', 'EffectsPacks', '*.lua'))
    for path in files:
        text = open(path, encoding='utf-8').read()
        names.update(re.findall(r'function H\.([A-Za-z_0-9]+)', text))
        names.update(re.findall(r'\bH\.([A-Za-z_0-9]+)\s*=', text))
    return names


def animator_actions():
    text = open(os.path.join(SRC, 'client', 'Animator.lua'), encoding='utf-8').read()
    return set(re.findall(r'function ACTIONS\.([A-Za-z]+)', text))


def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass
    show_all = '--all' in sys.argv
    shared = sorted(glob.glob(os.path.join(SRC, 'shared', '*.lua')))
    packs = sorted(glob.glob(os.path.join(SRC, 'shared', 'DogPacks', '*.lua')))
    skill_packs = sorted(glob.glob(os.path.join(SRC, 'server', 'Services', 'SpecialsPacks', 'Skills_*.lua')))
    parts = ['local MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
             'local MODULES = {}\n']
    for p in shared + packs:
        parts.append(module(os.path.basename(p)[:-4], p))
    parts.append(module('SkillKit', os.path.join(SRC, 'server', 'Services', 'SkillKit.lua')))
    for p in skill_packs:
        parts.append(module(os.path.basename(p)[:-4], p))
    # cliente: os desenhos de verdade rodam no cenário A (--no-client desliga)
    client_on = '--no-client' not in sys.argv
    if client_on:
        parts.append(module('SkillArt', os.path.join(SRC, 'client', 'SkillArt.lua')))
        parts.append(module('PackSkills', os.path.join(SRC, 'client', 'EffectsPacks', 'PackSkills.lua')))
    own_text = open(os.path.join(SRC, 'client', 'EffectsPacks', 'PackSkills.lua'), encoding='utf-8').read()
    own = set(re.findall(r'function H\.([A-Za-z_0-9]+)', own_text))
    legacy = sorted(client_handlers() - own)
    parts.append('CLIENT_ON = %s\nLEGACY_FX = %s\n' % ('true' if client_on else 'false', lua_list(legacy)))
    parts.append('SHARED_NAMES = %s\nPACK_NAMES = %s\nSKILL_PACKS = %s\n' % (
        lua_list([os.path.basename(p)[:-4] for p in shared]),
        lua_list([os.path.basename(p)[:-4] for p in packs]),
        lua_list([os.path.basename(p)[:-4] for p in skill_packs])))
    parts.append(open(os.path.join(HERE, 'skills_harness.luau'), encoding='utf-8').read())
    bundle = os.path.join(tempfile.gettempdir(), 'skills_test_bundle.luau')
    open(bundle, 'w', encoding='utf-8').write(''.join(parts))
    res = subprocess.run([LUAU, bundle], capture_output=True, text=True, encoding='utf-8', errors='replace')
    if res.returncode != 0:
        sys.stderr.write(res.stdout[-3000:] + '\n' + res.stderr[-3000:])
        sys.exit('luau falhou')

    handlers = client_handlers()
    actions = animator_actions()
    rows, problems = [], []
    aim_rows = []
    by_rarity = {}
    MOVE = 26
    for line in open(os.path.join(SRC, 'shared', 'Config.lua'), encoding='utf-8'):
        m = re.match(r'Config\.SKILL_MOVE = ([0-9.]+)', line)
        if m:
            MOVE = float(m.group(1))
    for line in res.stdout.splitlines():
        if not line.startswith('SKILL\t'):
            if line.strip() and not line.startswith('FIM'):
                print(line)
            continue
        f = line.split('\t')
        (_, sid, slot, rarity, dur, main_b, total_b, marker_b, buff_left, fx, acts, bad, errs,
         d_dur, d_grab, d_travel, d_aim, d_side, d_ungrab, d_held, e_dur, e_drop, e_aim) = (f + [''] * 23)[:23]
        rows.append(f)
        missing_fx = [n for n in fx.split(',') if n and n not in handlers]
        missing_act = [n for n in acts.split(',') if n and n not in actions]
        issues = []
        if errs:
            issues.append('ERRO: ' + errs[:600])
        if dur == 'NAO_ACABOU':
            issues.append('não terminou em 14 s')
        elif float(dur) > 3.2:
            issues.append(f'prende o cachorro {dur}s')
        if missing_fx:
            issues.append('efeito sem desenho no cliente: ' + ', '.join(missing_fx))
        if missing_act:
            issues.append('pose sem animação (usa a genérica): ' + ', '.join(missing_act))
        if bad:
            issues.append('parâmetros estranhos: ' + bad)
        if buff_left == 'true':
            issues.append('buff/velocidade não voltou ao normal')
        if float(main_b) < 0.5:
            issues.append(f'dano baixo no alvo ({main_b} do orçamento)')
        if float(main_b) > 1.6:
            issues.append(f'dano alto no alvo ({main_b} do orçamento)')
        if float(marker_b) <= 0:
            issues.append('sem dano quando sai na setinha (alvo invisível com inimigo perto)')
        # 🎯 mira do jogador
        area = {'Common': 0.8, 'Uncommon': 0.9, 'Rare': 1, 'Epic': 1.1, 'Legendary': 1.2, 'Mythic': 1.3, 'Divine': 1.4}.get(rarity, 1)
        if d_dur == 'NAO_ACABOU':
            issues.append('mira: não terminou em 14 s')
        elif d_dur and float(d_dur) > 2.6:
            issues.append(f'mira: demora {d_dur}s')
        # o Especial (tecla 4, recarga maior) pode ter uma cena curta no ar; o resto quase não segura
        if d_grab and float(d_grab) > (1.5 if slot == '4' else 1.0):
            issues.append(f'mira: segura o cachorro {d_grab}s')
        if d_travel and float(d_travel) > MOVE * area + 8:
            issues.append(f'mira: anda {d_travel} studs (máx {MOVE * area:.0f})')
        if d_ungrab and d_ungrab != '0':
            issues.append(f'mira: mexeu no corpo do jogador sem segurar ({d_ungrab}x)')
        if d_held and d_held != '0':
            issues.append('mira: o corpo ficou preso no fim')
        if d_side and float(d_side) > 0 and (not d_aim or float(d_aim) <= 0):
            issues.append(f'mira: acertou o inimigo do lado ({d_side}) e nada na setinha')
        # 🪽 voando (cenário E): a habilidade acontece no ar, sem puxar o cachorro para o chão
        if e_dur == 'NAO_ACABOU':
            issues.append('no ar: não terminou em 14 s')
        if e_drop and float(e_drop) > 20:  # (um mergulho de verdade, como o da fênix, pode descer um pouco e voltar)
            issues.append(f'no ar: desceu {e_drop} studs (devia ficar no ar)')
        aim_rows.append((sid, rarity, d_dur, d_grab, d_travel, d_aim, d_side, e_drop))
        by_rarity.setdefault((rarity, slot), []).append(float(main_b))
        if issues:
            problems.append((sid, issues))
        if show_all:
            print(f'{sid:28s} {rarity:9s} tecla {slot}  dura {dur:>5s}s  alvo {main_b}  total {total_b}  setinha {marker_b}'
                  f'  | mira: dura {d_dur}s segura {d_grab}s anda {d_travel} setinha {d_aim} lado {d_side}')
    print(f'\n{len(rows)} habilidades testadas em 5 cenários.')
    if aim_rows:
        def avg(i):
            vals = [float(r[i]) for r in aim_rows if r[i] not in ('', 'NAO_ACABOU')]
            return sum(vals) / max(1, len(vals)), max(vals) if vals else 0
        d_avg, d_max = avg(2)
        g_avg, g_max = avg(3)
        t_avg, t_max = avg(4)
        hits = sum(1 for r in aim_rows if r[5] and float(r[5]) > 0)
        print(f'🎯 Mira do jogador: dura {d_avg:.2f}s em média (máx {d_max:.2f}) · segura o corpo {g_avg:.2f}s (máx {g_max:.2f})'
              f' · anda {t_avg:.1f} studs (máx {t_max:.1f}) · {hits}/{len(aim_rows)} acertam perto da setinha longe')
        e_avg, e_max = avg(7)
        print(f'🪽 Voando: desce {e_avg:.1f} studs em média (máx {e_max:.1f}) durante a habilidade')
    print('Dano médio no alvo principal (em orçamentos da raridade):')
    order = ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Mythic', 'Divine']
    for (rarity, slot), vals in sorted(by_rarity.items(), key=lambda kv: (order.index(kv[0][0]) if kv[0][0] in order else 9, kv[0][1])):
        print(f'  {rarity:9s} tecla {slot}: {sum(vals) / len(vals):.2f}  ({len(vals)} habilidades)')
    if problems:
        print(f'\n⚠️ {len(problems)} habilidades com algo para olhar:')
        for sid, issues in problems:
            print('  -', sid)
            for i in issues:
                print('      ', i)
    else:
        print('\n✅ nenhum problema encontrado')


if __name__ == '__main__':
    main()
