"""Gera PUBLICAR_DogFighter.bat: um arquivo só com o publicador, os IDs e o jogo embutidos."""
import base64, gzip, json

ps = open('PUBLICAR.ps1', encoding='utf-8-sig').read()
ps = ps.replace("$here = Split-Path -Parent $MyInvocation.MyCommand.Path", "$here = Split-Path -Parent $selfPath")
ps = ps.replace("$placeIn = Join-Path $here 'DogFighterSimulator.rbxlx'", """$placeIn = Join-Path $env:TEMP 'DogFighterSimulator_embutido.rbxlx'
# o jogo vem embutido no final deste arquivo (base64 + gzip)
$selfText = [IO.File]::ReadAllText($selfPath, [Text.Encoding]::UTF8)
$mark = $selfText.LastIndexOf('#PAYLOAD_RBXLX#')
$b64 = $selfText.Substring($mark + 15).Trim()
$gz = New-Object IO.Compression.GZipStream((New-Object IO.MemoryStream(,[Convert]::FromBase64String($b64))), [IO.Compression.CompressionMode]::Decompress)
$outMs = New-Object IO.MemoryStream
$gz.CopyTo($outMs)
[IO.File]::WriteAllBytes($placeIn, $outMs.ToArray())""")
ps = ps.replace("$placeOut = Join-Path $here 'DogFighterSimulator_publicado.rbxlx'", "$placeOut = Join-Path $env:TEMP 'DogFighterSimulator_publicado.rbxlx'")
ids = json.load(open('publicar_ids.json'))
ids_ps = "@{ " + "; ".join(f"'{k}' = '{v}'" for k, v in ids.items()) + " }"
ps = ps.replace("$ids = @{}\nif (Test-Path $idsPath) {", f"$ids = {ids_ps}\nif (Test-Path $idsPath) {{")
for must in ("$selfPath", "#PAYLOAD_RBXLX#", ids_ps):
    assert must in ps, must
payload = base64.b64encode(gzip.compress(open('DogFighterSimulator.rbxlx', 'rb').read(), 9)).decode()
payload = '\r\n'.join(payload[i:i + 120] for i in range(0, len(payload), 120))
head = ('@echo off\r\n'
        'cd /d "%~dp0"\r\n'
        'powershell -NoProfile -ExecutionPolicy Bypass -Command "$selfPath=\'%~f0\'; '
        '$t=[IO.File]::ReadAllText($selfPath,[Text.Encoding]::UTF8); $n=[string][char]10; '
        '$a=$t.IndexOf($n+\'#PS1_START#\')+12; $b=$t.IndexOf($n+\'#PS1_END#\'); '
        'Invoke-Expression $t.Substring($a,$b-$a)"\r\n'
        'pause\r\n'
        'exit /b\r\n')
body = head + '#PS1_START#\r\n' + ps.replace('\r\n', '\n').replace('\n', '\r\n') + '\r\n#PS1_END#\r\n#PAYLOAD_RBXLX#\r\n' + payload + '\r\n'
open('PUBLICAR_DogFighter.bat', 'w', encoding='utf-8', newline='').write(body)

# conferência: o que o PowerShell vai extrair
t = body
a = t.index('\n#PS1_START#') + 12
b = t.index('\n#PS1_END#')
script = t[a:b]
assert '#PS1_END#' not in script and 'Read-Host' in script
data = gzip.decompress(base64.b64decode(''.join(t[t.rindex('#PAYLOAD_RBXLX#') + 15:].split())))
assert data == open('DogFighterSimulator.rbxlx', 'rb').read()
print('OK', len(body) // 1024, 'KB')
