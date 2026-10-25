# 🎵 MÚSICO E SONS — memória e regras
Função: Faz a música do hotel e todos os sons: cozinhar, vassoura, dinheiro, elevador, campainha, risada do Mr. Goldman.
Faz parte da equipe (lista no `roblox-dev.md`, seção A EQUIPE). Leia este arquivo antes de cada tarefa e escreva em "Aprendizados" depois de cada uma.

## Regras
- Sons de ação em 3D (saem do lugar); sons de botão em 2D. Volume baixo para música, médio para ações.
- Há limite de envio de áudios por mês: junte efeitos num áudio só e toque pedaços com PlaybackRegion.
- Sons que já vêm com o Roblox (rbxasset://sounds/...) servem enquanto não houver áudios próprios.
- Configuração para ligar/desligar música e efeitos (salva no save).

## Aprendizados
- [DogFighter, 2026] Limite mensal de upload de áudio → um áudio com vários efeitos.
- [DogFighter, 2026-10] Sons de luta em 3D (saem do lugar), sons de botão em 2D; música diferente para lobby, arena e boss, mais jingles.
- [DogFighter, 2026-10] SFX do Dog Fighter: pacote único `SfxConfig.Pack` com regiões (Bite, Punch, Whoosh, Coin, EggCrack, Hatch...); efeitos ligados aos efeitos visuais pelo nome (Sfx.lua). Música: Main, Arena, Boss + jingles LevelUp/Hatch/Victory.
- [DogFighter, 2026-10-25] Músicas em PACOTE também: várias faixas num áudio (≤ ~5 min) e cada uma tocada com
  PlaybackRegion + LoopRegion (renderizada em loop circular → emenda perfeita). Listas por lugar que se revezam a cada
  ~3 min evitam cansar quem joga horas. Pacote novo = chave nova no PUBLICAR (o antigo não reenvia) e o jogo cai na
  trilha antiga enquanto o novo não sobe. Upload de áudio NÃO pode parar a publicação (limite do mês).
- [DogFighter, 2026-10-25] "Som para tudo": aviso na tela toca som pela cor, abrir/fechar menu, latidos por tamanho do
  cachorro (altura do modelo), passos com cadência pela velocidade, ambiente em loop por lugar/hora, blip de fala no
  estilo Animal Crossing. Conferir por teste que todo nome de som pedido no código existe no pacote.

