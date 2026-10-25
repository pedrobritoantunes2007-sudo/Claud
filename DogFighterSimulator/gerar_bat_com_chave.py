"""Gera o PUBLICAR_DogFighter.bat de novo MANTENDO a chave embutida do .bat atual.

Uso (na pasta do projeto, depois do rojo build do .rbxlx):  python3 gerar_bat_com_chave.py
- Lê a chave do .bat atual (nunca mostra a chave), roda gerar_bat_unico.py e coloca a chave no lugar do Read-Host.
- Arquivos lidos/escritos com newline='' (o .bat usa CRLF; o modo texto normal estragava a troca).
- Se algo der errado, o .bat antigo volta.
"""
import base64, gzip, re, shutil, subprocess, sys

BAT = 'PUBLICAR_DogFighter.bat'
BACKUP = BAT + '.antigo'

old = open(BAT, encoding='utf-8', newline='').read()
m = re.search(r"\$key = '([A-Za-z0-9+/=]+)'  # chave embutida", old)
if not m:
    sys.exit('ERRO: o .bat atual não tem a chave embutida')
key = m.group(1)
shutil.copyfile(BAT, BACKUP)
try:
    subprocess.run([sys.executable, 'gerar_bat_unico.py'], check=True)
    new = open(BAT, encoding='utf-8', newline='').read()
    lines = new.split('\r\n')
    idx = [i for i, l in enumerate(lines) if 'Read-Host' in l and '$key' in l]
    assert len(idx) == 1 and len(lines) > 100, 'linha da chave não encontrada'
    indent = re.match(r'\s*', lines[idx[0]]).group(0)
    lines[idx[0]] = indent + "$key = '" + key + "'  # chave embutida (pedido do dono)"
    open(BAT, 'w', encoding='utf-8', newline='').write('\r\n'.join(lines))
    chk = open(BAT, encoding='utf-8', newline='').read()
    assert ("$key = '" + key + "'  # chave embutida") in chk
    data = gzip.decompress(base64.b64decode(''.join(chk[chk.rindex('#PAYLOAD_RBXLX#') + 15:].split())))
    assert data == open('DogFighterSimulator.rbxlx', 'rb').read(), 'jogo embutido diferente do .rbxlx'
except Exception as e:
    shutil.copyfile(BACKUP, BAT)
    sys.exit('ERRO (o .bat antigo voltou): ' + str(e))
finally:
    import os
    if os.path.exists(BACKUP):
        os.remove(BACKUP)
print('OK: .bat novo com a chave mantida e o jogo atual embutido (%d KB)' % (len(chk) // 1024))
