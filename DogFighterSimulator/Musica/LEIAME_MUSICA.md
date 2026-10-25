# Música e sons do Dog Fighter Simulator

Tudo é **sintetizado por código** (sem samples) — rode de novo para mudar.

| Script | Gera | Usado por |
|---|---|---|
| `gerar_trilha2.py` | `musicas_a.ogg`, `musicas_b.ogg`, `musicas_c.ogg` + `src/shared/MusicPacks.lua` | `Systems/Music` (trilha 2, 2026-10-25) |
| `gerar_sfx.py` | `sfx_pack2.ogg` (+ `mp3/sfx_pack2.mp3`) + `src/shared/SfxConfig.lua` | `Systems/Sfx`, `Systems/Soundscape` |
| `gerar_musica.py` | trilha 1 (`tema_principal`, `arena`, `boss`, jingles) | reserva enquanto a trilha 2 não sobe |

- Precisa de `numpy`, `scipy` (e `pyloudnorm`, opcional) e `ffmpeg` com libvorbis.
- `python3 Musica/gerar_trilha2.py` refaz tudo (~2 min). `python3 Musica/gerar_trilha2.py --wav village` salva uma
  prévia em `Musica/previa/`.
- Os IDs: o `PUBLICAR_DogFighter.bat` envia os pacotes (chaves `MusicA/MusicB/MusicC` e `Pack2`) e coloca os números
  no jogo. Os scripts mantêm os IDs que já estiverem nos `.lua`.
- Mudou um pacote que JÁ foi enviado? Dê outra chave/nome de arquivo (ou apague a linha `Music_<chave>` do
  `publicar_ids.json`), senão o .bat acha que já está enviado.
