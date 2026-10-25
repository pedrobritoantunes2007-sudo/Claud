# 🎬 ANIMADOR — memória e regras
Função: TODA tarefa do jogo vira uma animação 3D (o personagem faz a ação de verdade, com o objeto na mão).
Trabalha com o DESIGNER 3D (`designer-3d.md`, faz os objetos), o DEV (`roblox-dev.md`) e os testadores.
Leia este arquivo antes de cada tarefa e escreva em "Aprendizados" depois de cada uma.

## Como animar no Roblox sem enviar arquivos de animação
- Animação feita por CÓDIGO no aparelho do jogador: a cada quadro muda `Motor6D.Transform` (braços, tronco, cabeça)
  com curvas suaves (seno, easing) e cola o objeto na mão (Weld no RightHand/LeftHand).
- O servidor só avisa "fulano está cozinhando/limpando"; cada aparelho anima igual (fica liso, sem travar).
- Animações prontas do Roblox (públicas, servem em qualquer jogo, R15): rir 507770818, acenar 507770239,
  apontar 507770453, comemorar 507770677, dançar 507771019, andar 507777826, parado 507766388.
- Sempre volta para a pose normal no fim (e se o jogador morrer ou sair no meio).
- Trava o andar só durante a ação (Freeze) e solta SEMPRE.
- Jogo em R15 (Game Settings → Avatar → R15), senão os nomes das juntas mudam.

## Tarefas e animações (atualizar)
| Tarefa | Animação |
|---|---|
| Cozinhar | colocar a comida na panela, mexer com colher, fritar (sacudir a frigideira), ou forno (abrir, pôr, fechar), ou os dois |
| Limpar | vassoura aparece na mão, varrer de um lado para o outro; lixo some com poeirinha |
| Malas | malas aparecem embaixo; ao pegar, aparece um carrinho na mão; empurrar o carrinho (2 malas; evolui para 3 e 4) |
| Entregar | bater na porta, entregar a bandeja/mala |
| Check-in | digitar no computador do balcão, entregar a chave |
| Rival (Mr. Goldman) | aparecer na frente do jogador, apontar e RIR |
| Hóspedes | andar, deitar, sentar, comer, acenar |

## Aprendizados
- [DogFighter, 2026-10] Poder especial que move o personagem: o servidor pega a física por 1–2 s, o cliente trava os controles e devolve no fim.
- [DogFighter, 2026-10] Voo liga/desliga com espaço 2x; animação de voo só enquanto voa.
- [DogFighter, 2026-10] Animação dos cães é procedural no cliente (`src/client/Animator.lua`): lê velocidade do corpo e o atributo Action do modelo (Bite, Sit, Eat, KO, Dash...). O servidor só muda o atributo.
- [DogFighter, 2026-10] Treino no estande = `Fighters.Bite` (mordida) + flash de "Hit" no boneco; cada batida mostra o XP subindo.
- [DogFighter, 2026-10] OLHAR para a setinha: o cliente faz o raio da câmera pela setinha e chama `Animator.SetLookAt`; os outros
  veem pelo atributo `LookAt` (remote, ~7x/s). Cabeça numa mola rápida (parece cachorro), o corpo torce uma parte (`bodyTurn`
  mantém as patas plantadas: perna desfaz a inclinação e inclina para o lado contrário do giro).
- [DogFighter, 2026-10] Cabeça olhando para cima E para o lado: usar `CFrame.fromEulerAnglesYXZ` (vira, depois levanta o nariz);
  `CFrame.Angles(x, y, z)` gira o lado já com o nariz levantado e entorta a cabeça.
- [DogFighter, 2026-10] Giro de 360° (correr atrás do rabo, Spin): multiplicar POR CIMA da pose e sem suavizar o corpo;
  misturar (Lerp) 360° dá zero.
- [DogFighter, 2026-10] Asa de avião: cada modelo de asa sobe num ângulo diferente; medir no C0 (cotovelo da asa) quanto
  descer para ficar reta (`WingFlat`). Voo inclinado de verdade = AlignOrientation no HumanoidRootPart (todo mundo vê); a pose
  só completa (asas, patas, rabo de leme, cabeça nivelada).
- [DogFighter, 2026-10] Conferir poses sem Roblox: `python tools/preview/poses.py saida.json <cão>` (Animator e DogBuilder de
  verdade) e abrir `tools/preview/render.html` servido por http. Vale MUITO: achou a cabeça torta antes de entregar.
- [DogFighter, 2026-10] Patada (combo pata direita → esquerda → mordida): camada `swipePose` por cima da pose (perna
  sobe e abre para fora, desce cruzando para dentro; corpo inclina para o lado contrário). O cliente toca na hora do clique
  (isLocal) e ignora o aviso do servidor para o mesmo cachorro por 0,45 s, senão a patada tocava duas vezes.
- [DogFighter, 2026-10] 29 poses novas para as habilidades (Animator seção 6b): Leap, Flip, Roll, Curl, Drill, Kick, Dig, Bark, Spit, Sniff, Bow, Throw, Uppercut, Headbutt, Stomp, Summon, Focus, Flex, Slide, Bounce, Twirl, Guard, Slash, Inhale, Belly, Snore, Victory, Wiggle, Shake. Cada habilidade encadeia poses (prepara → golpe → volta) com `k:pose`.
- [DogFighter, 2026-10] Pose que acontece no ar (salto em arco pelo servidor) vai em `NO_AIR_ACTIONS` (senão a pose de queda mistura por cima); pose parada vai em `STILL_ACTIONS` (as patas não "andam"). Giros (Flip/Roll/Drill/Twirl/Shake) usam `c.fast.Body = true`.
- [DogFighter, 2026-10] Salto de poder EXATO: o servidor põe o cachorro num arco (PivotTo a cada Heartbeat, velocidade zerada) em vez de empurrão + gravidade; a pose Leap lê a velocidade vertical (subindo = nariz para cima, caindo = patas na frente).
