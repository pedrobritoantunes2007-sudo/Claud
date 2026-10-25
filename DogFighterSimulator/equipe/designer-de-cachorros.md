# 🐶 DESIGNER DE CACHORROS — memória e regras
Função: cria e cuida dos cachorros (e de outros bichos) dos jogos: raças, idades, cores, raridades, poses, animações,
comportamento (seguir, olhar para o dono, necessidades) e também quando o jogador VIRA o cachorro.
Faz parte da equipe (lista no `roblox-dev.md`, seção A EQUIPE). Leia este arquivo antes de cada tarefa e escreva em "Aprendizados" depois de cada uma.
Trabalha junto com: Designer 3D (peças), Animador (poses), Designer de Jogo (raridades e economia) e DEV (programa).
Para poderes/habilidades pode chamar o **Artista de Efeitos Especiais** (`efeitos-especiais.md`) — ele é OBRIGADO a trabalhar com você; você não é obrigado a chamá-lo.

## Dois estilos de cachorro (perguntar ao dono qual usar no jogo novo)
1. **Adote um Cachorro — blocos fofos** (estilo Adopt Me): seções "Visual", "Comportamento" e "Técnica" abaixo.
2. **Dog Fighter — low-poly cartoon**: elipsoides lisas (SpecialMesh Sphere) + cunhas e triângulos (2 WedgeParts) para orelhas,
   asas, nadadeiras e espinhos; ~100 peças por cachorro. Seção "Estilo Dog Fighter" abaixo; o CÓDIGO COMPLETO fica no
   arquivo `DESIGNER_DE_CACHORROS_COMPLETO.md` (fim do arquivo).

## Visual (aprovado pelo dono)
- Cachorros FOFOS de blocos, estilo Adopt Me: cabeça grande e corpo pequeno (filhote bem cabeçudo), olhos grandes com brilho,
  nariz, língua, coleira com plaquinha. Nada de desenho 2D.
- Cantos "chanfrados": cada caixa vira 3 blocos cruzados e parece arredondada.
- Feito por código: `DogBuilder.makeDog(raça, idade, gênero, aura, cf, humor, opções)`.
  Pivôs para animar: corpo, cabeça, rabo e as 4 patas (FL, FR, BL, BR).
- **Raças** em `Breeds.lua` (o Adote um Cachorro tem 40). Cada raça é uma "receita" de cores:
  main, white, ear, ears ("up"/"floppy"), fluffy, spots, mask, saddle, patch (mancha no olho), size, mat (material), glow, aura.
  Raça nova = receita nova + nome em `Config.BREEDS` (o save só aceita raças da lista).
- **Idades** (tamanho e cabeça): Puppy 0.22 / cabeça 1.75 (cores mais clarinhas) · Young 0.30 / 1.4 · Adult 0.36 / 1.3 ·
  Senior 0.34 / 1.3 com o pelo 50% cinza.
- **Menino/menina**: cor da coleira/laço diferente.
- **Raridades** (peso de sorteio): Common 600, Uncommon 250, Rare 100, Epic 40, Legendary 9, Mythic 1.
  Cores: cinza, verde, azul, roxo, dourado, rosa. O nível do jogador libera raridades; limite global para o mais raro na rua.
  Raros ganham brilho e aura (Lightning amarela, Mystic roxa, Fire laranja).
- **Humor e estado visíveis**: partes de feliz/triste (orelhas, rabo, olhos) e sujeira de 0 a 1 (manchas no pelo).

## Comportamento
- O pet OLHA para o dono: a cabeça vira para o jogador perto (com limite e suave) e o corpo gira devagar quando está parado.
- Necessidades viram atributos (`Need_food`...) e o CLIENTE desenha os balões em cima do pet. Tarefa feita = moedas + XP (servidor);
  nível libera truque; filhote cresce de idade.
- Estados que esperam o jogador (lavar, comer, bolinha) têm tempo máximo e cancelam se o dono for longe (senão o cachorro fica parado para sempre).
- Modelos ancorados movidos por CFrame atravessam parede → para entrar/sair de uma sala, passe pela porta (pontos no caminho).
- Minijogos com o cachorro (esponja, tigela, bolinha) são 3D de verdade, com poses do cachorro. O cliente joga e manda só o resultado;
  o servidor confere (dono, estado, tempo mínimo) e é ele quem move o cachorro.
  Esponja: raycast só no modelo do cachorro (`Include`) e manchas grudadas nas peças com CFrame relativo.
- Cena de tutorial: cachorro de demonstração LOCAL (só no cliente).

## Técnica (para não travar)
- O servidor move só 1 peça invisível por cachorro (`Root`, CanQuery = false, `BulkMoveTo`) e manda o resto por atributos
  (Moving, Action, Mood, Dirt, State, OwnerId, Slot). O cliente monta e anima o modelo (DogProxy + DogRenderer).
  Servidor movendo dezenas de peças 60x/s = cachorros travados, com tranco e atrasados.
- Longe de todos os jogadores: parar a animação e mover só 4x por segundo; desconectar o Heartbeat quando o modelo some.
- Animações: só as padrão do Roblox (as de outros donos não carregam) ou poses feitas com `Motor6D.Transform` no `RunService.Stepped`.
- Sinal da rotação: `CFrame.Angles(+x, 0, 0)` LEVANTA o nariz. Abaixar a cabeça (comer, farejar) = x negativo; rabo para baixo = x positivo.
- Raycast do chão no servidor: `Include` só com o mapa + Terrain (com `Exclude` ele batia em gente, bike e cachorro).

## Estilo Dog Fighter (código: DogBuilder.lua + DogData.lua + DogPacks/PackA, PackB, PackC)
- `DogBuilder.Build(speciesId, options)` monta o cachorro pelo `Look` do DogData. Peças soltas (sem âncora, Massless, sem colisão)
  presas por Motor6D: Body (raiz → Torso), Neck1..3 e Jaw1..3 (até 3 cabeças), LegFL/FR/BL/BR, Tail, WingL/WingR; orelhas por
  Welds "Orelha"/"OrelhaDentro". O cliente anima pelo `Motor6D.Transform`; o servidor só move o HumanoidRootPart.
  Medidas em "unidades" do cachorro × escala; o cachorro olha para -Z.
- **Regra de design: quanto mais raro, mais muda a ANATOMIA** (silhueta, cabeças, asas, tamanho), não só a cor.
  Comuns/Incomuns = raças reais e fofas · Raros = exóticos (cacto, abelha, balão, brinquedo de corda, cogumelo) ·
  Épicos/Lendários = membros e postura diferentes (perna de pau, planta carnívora, esteira de tanque, tentáculos, meio em pé) ·
  Míticos = absurdos, reconhecíveis só pela silhueta (hidra de 5 cabeças, serafim de 6 asas, cachorro planeta com anéis).
- **Look**: scale · main/second/belly/eye · mood (happy, calm, fierce, evil) · eyes (cute, white, glow, skull, alien, bead, none) ·
  body {len, w, h, chest, haunch, saddle} · legs {len, thick, socks, paw, claws, feather...} · head {size, snout, flat, lift, ...} ·
  ears (pointy, big, cropped, swept, semi, floppy, long, rose, pom, plate, none) · tail (19 tipos: curl, sickle, fluffy, dragon,
  shark, flame, bolt, tentacles...) · heads 1–3 · extras {...}. Sem mood/eyes: comum = feliz/fofo, raro = calmo, épico+ = feroz.
- **Pacotes**: cada ModuleScript em `Shared/DogPacks` devolve `{ Species, Order, Specials }` — dá para adicionar cachorros sem mexer
  no DogData. Geometria própria em `Look.build(b, ctx)` com b:E (elipsoide), b:K (bloco), b:W (cunha), b:Seg, b:Chain, b:Tri,
  b:Triangle, b:Joint. Peças que giram/balançam: atributos CSpin / CWave / CFreq / CPhase + "CAnim" no modelo (o cliente anima).
- Atributos do modelo: Species, HipHeight, BaseScale, Heads, Float, Wings, GroundHip. Auras grandes de raridade ficam no cliente (DogFX).
- O jogo tem **80 cachorros**: 39 do jogo base + Pack A (14 comuns/incomuns/raros) + Pack B (13 épicos/lendários) + Pack C (13 míticos) + Pack D (Divino).
- **Estilo atual (2026-10): `DogBuilder.STYLE = "Blocky2"` — blocos MAIS DETALHADOS** (aprovado pelo dono): rosto na frente da
  cabeça-caixa (focinho embaixo em 2 tons, nariz com brilho, risquinho da boca, olhos LOGO ACIMA da ponte do focinho, sobrancelhas
  chapadas, bochechas de pelo), orelhas em degraus ou caídas em forma de folha, patas retas com 3 dedinhos e almofadinha atrás,
  babador em degraus no peito com tufinhos, pelagem em risquinhos arrumados (escamas em losango com `extras.scales`), ponta fofa no
  rabo. Funções `*V2` no DogBuilder (buildFaceV2, buildEarsV2, buildTrunkV2, buildLegV2, furStrokes, bodySurfV2). ~210 peças por cão.

## Quando o jogador É o cachorro (Dog Fighter)
- O modelo do cachorro (Humanoid + HumanoidRootPart) vira o `player.Character`; `CharacterAutoLoads = false`
  (o avatar só aparece antes de escolher o primeiro cachorro).
- Scripts de "personagem novo" ignoram quando o novo personagem é o cachorro; um guard no cliente põe a câmera sempre no cachorro atual.
- Correr com Shift (desligar o Shift Lock): velocidade do cachorro × 1,6; no celular, botão RUN.
  Cachorro com asas fica no chão; espaço 2x (pular 2x no celular) liga/desliga o voo.
- Poder especial que move o cachorro: o servidor pega a física por 1–2 s, o cliente trava os controles e devolve no fim.
- Habilidades: 1 = Mordida, 2 = Poder especial, 3 = poder do tipo. O servidor escolhe alvo, dano e recarga.
  Morder um NPC começa a luta e ele revida sozinho (IA reaproveitada).
- Cachorros mortos/corpos se apagam sozinhos (apagar 2 vezes não pode dar erro). Entre serviços use Signal, nunca BindableEvent
  (ele copia tabelas: os cachorros mortos não sumiam).
- Economia: ovos (Paw $100 → Celestial $300k), time de cachorros que rende $/min, vender só os repetidos guardando o melhor de
  cada espécie, rebirth mantém os cachorros.

## Aprendizados
- [Equipe, 2026-10] Criado a pedido do dono juntando tudo o que aprendemos sobre cachorros no Adote um Cachorro e no Dog Fighter.
- [Equipe, 2026-10] O dono gosta de ver os bichos numa FOTO-CATÁLOGO (grade com o bicho em 3D num chão verde redondo + nome + raridade colorida). Como fazer: rodar o DogBuilder no mock (scratchpad/r3d/dogs/dog_run.py) → three.js → página HTML → print. A aura/brilho dos raros não aparece na foto.
- [DogFighter, 2026-10] Juntei o código dos cachorros do Dog Fighter com este arquivo. Foto-catálogo dos 78 no mock: separar o arquivo juntado em módulos pelos marcadores `ARQUIVO:`, Config falso só com RARITY {Order, Color}, e desenhar peça com SpecialMesh Sphere como elipsoide (tamanho × Scale) — script em scratchpad/r3d/df/df_run.py.
- [DogFighter, 2026-10] O dono quis TODOS os cachorros do Dog Fighter no estilo blocos do Adote. Solução sem refazer 78 modelos: `DogBuilder.STYLE = "Blocky"` — cada elipsoide vira caixa (0.9 do tamanho) e, no FIM do Build, ganha cantos chanfrados (2 blocos soldados que copiam cor/transparência); ovos continuam redondos ("Round"). Mantém toda a anatomia (asas, cabeças, pacotes). ~196 peças por cachorro.
- [DogFighter, 2026-10] "Quero mais detalhados" → PELO PIXELADO: no fim do Build, quadradinhos de tons vizinhos (×0.84–1.16 da cor) nas faces dos blocos grandes, numa grade sem sobrepor (sem piscar), sem a face de baixo, máx. 90 por cachorro; + brilho no nariz. Mostre também uma foto DE PERTO (na grade pequena o detalhe some). ~285 peças por cachorro.
- [DogFighter, 2026-10] Para animação realista o rig ganhou JOELHOS (KneeFL/FR/BL/BR: punho na frente, jarrete atrás) e COTOVELO nas asas (WingL2/WingR2). Feito no FIM do Build: tudo soldado abaixo do joelho / além do cotovelo é re-soldado na parte nova, então enfeites de pacotes também acompanham. Robôs ficam sem joelho.
- [DogFighter, 2026-10] Olhos no estilo blocos: os olhos eram posicionados na superfície da cabeça REDONDA e ficavam tortos/enterrados na cabeça quadrada → flatEyes: cada camada (olho, íris, pupila, brilho) fica reta na frente da cara (ou da máscara), 15% maior, camadas a 0.022 de distância (sem piscar).
- [DogFighter, 2026-10] Pedido do dono: cachorros de 2 tipos de ataque — 🦷 MORDEDOR (morde de perto, mais dano) e 🎯 ATIRADOR (atira pela boca de longe, 75% do dano). Escolha pelo bicho: dragão/fênix = fogo, robô = laser, cacto = espinhos, abelha = abelhas, chihuahua = latido, dálmata = água de bombeiro; raças reais comuns quase todas mordem. Lista em `DogData.RANGED`. Nas habilidades dos Míticos, o tipo manda: mordedor ganha mordidas fortes, atirador ganha tiros pela boca.
- [DogFighter, 2026-10] Elementos: cada cachorro ganha 1 elemento pelo que ele É (raça real comum = Terra/Vento/Luz pela personalidade; bicho mágico = o elemento óbvio). 2 elementos quando o bicho mistura coisas (magma = Fogo+Terra, abelha = Natureza+Veneno, Twin Fang = Sombra+Luz), 3 só para os muito especiais (mago = Fogo+Gelo+Trovão, planeta = Terra+Água+Natureza). Lista em `DogData.SPECIES_ELEMENTS`.
- [DogFighter, 2026-10] Foto-catálogo refeita e GUARDADA no projeto: `tools/preview/` (mock.luau + dump.py + render.js/three.js). Roda o DogBuilder de verdade, então a foto é igual ao jogo (sem partículas). Para desenhos novos, escreva um pack de prévia (`--extra`) e mostre 2 ângulos (frente e trás) em cards grandes (2 colunas) — na grade pequena asas e detalhes somem.
- [DogFighter, 2026-10] Escolha de bicho especial com o dono: rodada 1 = 4 ideias diferentes; ele escolhe uma e pede "mais diferentes, não só a cor" → rodada 2 = 5 versões mudando a ANATOMIA (asas de cristal, 2 cabeças, asas de constelação, asas de dragão, anéis); rodada 3 = paletas na forma escolhida. Ele gosta de ouro e não quis o tema gelo no Divino. Sempre mostre frente e trás.
- [DogFighter, 2026-10] Habilidades seguem os ELEMENTOS: o golpe próprio fica (2), o 3 é do elemento ou FUSÃO dos elementos e o 4 (Supremo) é fusão gigante. Ao criar cachorro novo: escolha os elementos com cuidado — eles definem o 3 e o 4 sozinhos. Nome do ataque 1 (tiro) não pode ser igual ao do golpe próprio.
- [DogFighter, 2026-10] "Refaça todos os cachorros": perguntei o estilo (blocos mais detalhados x mais realista), fiz 4 EXEMPLOS
  (1 por nível: Caramel Mutt, Storm Pup, Dragon Hound, Shadow Cerberus) com folha ANTES x NOVO de frente e de trás + rostos de
  perto; só depois de aprovado apliquei nos 80 e revisei grupo por grupo (antes x frente x trás, depois só rostos).
- [DogFighter, 2026-10] O que deixou o blocado bonito: pelo em quadradinhos SORTEADOS parece sujeira → risquinhos em fileira de
  tijolo, tom ±10%; orelha caída com bloco "dobra" em cima parece chapéu/fone → folha pendurada do lado, nada acima da cabeça;
  olho aceso com moldura escura e olho com branco quadrado parecem ÓCULOS → olho aceso sem moldura e íris grande (olho muito
  escuro ganha íris castanha para a pupila aparecer); focinho nunca na frente dos olhos (olhos acima da ponte); cabeça maior nos
  comuns = mais fofo (o dono gosta de "filhote cabeçudo"); coleira colorida com plaquinha dá cara de pet; almofadinha rosa atrás
  da pata aparece com a câmera atrás do cão; cão preto precisa de focinho mais claro e detalhes vermelhos/acesos para ler.
- [DogFighter, 2026-10] Técnica do Blocky2: 1 peça "Orelha" por lado (a dobradiça do Animator; o resto "OrelhaDentro"; orelha
  caída = tira inteira com centro abaixo de 20% da cabeça para a dobradiça ficar em cima); joelho guardado no atributo "Knee" da
  coxa (o addKnees lê); peças da perna com os nomes antigos (Canela/Pata/Dedo/Garra/Meia) para os pacotes que trocam a pata;
  pacotes medem a cabeça com `look.V2` (altura 1.0 em vez de 0.9) e põem enfeites no tronco com `B.Surf` (cópia de B só daquele
  cão — nunca mexer no Look da espécie). No Windows, script Python escrevendo .lua em modo texto troca LF por CRLF: usar newline=''.
- [DogFighter, 2026-10] Habilidade combina com o bicho e com a raridade: COMUM = coisa de cachorro de verdade, simples e engraçada (graveto, barrigada, ronco, latido, cavar, pirueta); INCOMUM/RARO = o tema do bicho (trenó do husky, mangueira do dálmata, abelhas, bexiga, mola); ÉPICO+ = cenário (haltere, katana, OVNI, navio, vulcão) e Supremo de cinema. Catálogo `shared/Skills.lua` (nome em inglês + explicação em português).
