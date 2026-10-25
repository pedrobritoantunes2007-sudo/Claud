# Imagens da página do jogo (ícone + 5 imagens)

Feitas com o jogo de verdade (ilhas e cachorros do código), em estilo cartoon:

| Arquivo | Onde vai | O que mostra |
|---|---|---|
| `icone.png` (512×512) | **Ícone** do jogo | Shiba Samurai rugindo + "DOG FIGHTER" |
| `imagem1_luta.png` (1920×1080) | Imagem 1 | Luta na Puppy Meadows — "BE A DOG AND FIGHT!" |
| `imagem2_colecao.png` | Imagem 2 | Cachorros de todas as raridades — "COLLECT 80+ DOGS!" |
| `imagem3_voar.png` | Imagem 3 | Fênix de Gelo voando no Sky Kingdom — "FLY TO 8 ISLANDS!" |
| `imagem4_superboss.png` | Imagem 4 | Super Boss no Coliseu — "TEAM UP VS THE SUPER BOSS!" |
| `imagem5_halloween.png` | Imagem 5 | Palhaço + 2 clones à noite — "HALLOWEEN!" |

## Como colocar (1 minuto, no computador)
1. Abra **create.roblox.com** → **Creations** → clique no **Dog Fighter Simulator**.
2. No menu do jogo, procure a parte de **Icon** (ícone) e **Thumbnails** (imagens) — fica em **Basic Settings**
   ou dentro de **Places** → o lugar principal, dependendo da versão do site.
3. Ícone: envie `icone.png`. Imagens: envie as 5 na ordem (1 a 5) e salve.

O **nome** e a **descrição** do jogo o `PUBLICAR_DogFighter.bat` coloca sozinho.
Depois do Halloween (a partir de 08/11) a imagem 5 pode sair ou ir para o fim.

## Refazer as imagens (para quem mexe no código)
`python3 tools/preview/thumbs.py` (cada imagem é um arquivo em `tools/preview/thumbs/*.json`: câmera, ilha,
cachorros, poses e textos). Precisa do luau (variável `LUAU`) e do Chromium do Playwright.
