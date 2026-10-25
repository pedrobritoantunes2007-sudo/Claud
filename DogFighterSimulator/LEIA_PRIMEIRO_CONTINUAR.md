# Dog Fighter Simulator — pacote completo para continuar em outro lugar

## Para quem continuar (IA ou pessoa)
- Dono fala português, não é programador: responder em português simples. Texto DENTRO do jogo em inglês.
- Projeto Rojo. Código em `src/` (client, server, shared). Build: `rojo build -o DogFighterSimulator.rbxl`.
- Depois de toda mudança: rodar `CHECK.sh` (ler a saída inteira), gerar .rbxl/.rbxlx, regenerar o
  `PUBLICAR_DogFighter.bat` com `python3 gerar_bat_unico.py` mantendo a chave embutida, mandar os arquivos
  e pedir prints (nada foi testado dentro do Roblox por quem editou).
- Leia também: `TUDO_QUE_APRENDI.md`, `GUIA_CRIAR_JOGO_ROBLOX.md`, `EQUIPE_COMPLETA_v3.md`, `equipe/*.md`
  (ficha do jogo: `equipe/jogo-dogfighter.md`), `agente/roblox-dev.md` (lições do agente).

## Publicar automático
- `PUBLICAR_DogFighter.bat` (Windows): dois cliques e publica direto no Roblox. A chave Open Cloud do dono
  está EMBUTIDA nele (pedido do dono). NÃO compartilhar esse .bat nem este zip com ninguém.
- Ao regenerar: rodar `python3 gerar_bat_com_chave.py` (faz tudo abaixo sozinho e confere). Jeito manual: ler a linha `$key = '...'  # chave embutida` do .bat antigo, rodar `gerar_bat_unico.py` e
  trocar a linha do `Read-Host` por `$key = '<chave>'  # chave embutida (pedido do dono)`.
- IDs do jogo: `publicar_ids.json`.

## Estado atual (últimas mudanças)
- 🌊🏆✨ LOTE 2026-10-25 (10 pedidos do dono + "crie um HUD donation, onde os jogadores podem doar robux para mim").
  Nada disso foi testado dentro do Roblox ainda: pedir prints. Códigos do dono (botão 🎟️ CODES) para testar:
  `eventcatch2x` / `eventcash2x` / `eventrain` / `eventoff` / `eventauto`, `shiny`, `triplo`, `stars`.
  - 🌊 MAR (bug): água no retângulo do mundo inteiro (`Layout.WORLD`: X −4400..4400, Z −5600..6800 + 1200 de mar)
    em blocos de 2048 (`MapBuilder.buildWater`), CHÃO invisível no fundo (Y −20) e 4 PAREDES invisíveis
    (`MapBuilder.BuildLimits` → workspace "Limites"). `IslandService` resgata quem cair abaixo de Y −60 ou sair das
    paredes (volta para a ilha aberta/vila/ranking/principal).
  - 🏆 ILHA DO RANKING (`Shared/RankIsland`, `World/RankIsland.lua`, centro 0,0,−4300): os 6 PLACARES só ficam lá
    (`LeaderboardService` reescrito): Strongest, Weekly Wins, Most Catches, Most Complete Dex, Best Clans (semana) e
    Season Pass. Portais: praça da ilha principal (`MainIsland.RankPortalCFrame`, ângulo 120°) e Pawville
    (`RankIsland.VILLAGE_PORTAL`, ao lado do fim da rua principal, placa 🏆 RANKING na seta). O chip da ilha no HUD mostra o nome dela.
  - ✨ SHINY (`Shared/Variants`): 1 em 500 selvagens nasce shiny (brilho + cor), aviso para o servidor inteiro, continua
    shiny quando capturado (`dog.Shiny`), +15% de força. 🧬 EVOLUIR (`Services/EvolveService`, botão EVOLVE no DOGS):
    3 iguais (mesma espécie e mesma versão) → 1 GOLD (×1.6); 3 GOLD → 1 RAINBOW (×2.5). O novo fica com o MAIOR level
    dos 3 e é shiny se algum era; favoritos ⭐ (fora o escolhido) e cachorros oferecidos numa troca ficam de fora; o
    equipado pode entrar (não no meio de uma luta). `dog.Tier` = "Gold"/"Rainbow". Venda/troca × `Variants.ValueMult`.
  - 📖 DEX COM PRÊMIOS (`Shared/DexRewards`): 10/25/50 descobertos e cada raridade completa dão coleiras, giros, Cash e
    TÍTULOS (painel no DEX; títulos novos "x:<nome>" em `data.ExtraTitles`).
  - 🎩 ACESSÓRIOS (`Shared/Accessories`, `Services/AccessoryService`, tela `Systems/StyleMenu`, botão STYLE): chapéu,
    coleira, óculos e capa no cachorro (todo mundo vê, `Accessories.Attach`), bônus pequeno (Cash, XP, captura,
    velocidade; soma no máximo 30%). 16 com Cash; 4 com Robux (`Acc_crown` 99, `Acc_galaxy` 129, `Acc_diamond` 79,
    `Acc_visor` 69); 2 do Passe de Temporada.
  - 🎉 EVENTOS DE FIM DE SEMANA (`Shared/WeekendEvents`, `Services/EventService`, chip `Systems/WeekendEvent`): sábado
    00:00 até segunda 00:00 (Brasília), revezando 2x CAPTURE / 2x CASH / CHUVA DE RAROS (cachorros raros caindo nas
    ilhas com gente). Atributo `EventForce` do workspace força um (códigos acima).
  - 🎟️ PASSE DE TEMPORADA (`Shared/SeasonPass`, `Services/SeasonPassService`, tela `Systems/SeasonPassMenu`, botão
    PASS): 30 dias, 30 níveis (10 ⭐ por nível), estrelas de missões, login, capturas e evoluções
    (`SeasonPass.STARS`), trilha FREE e PREMIUM.
    Premium = produto `SeasonPass` 199 Robux (vale só para a temporada atual); nível 30 premium dá o exclusivo
    `aurora_pup` (Mítico, `DogPacks/PackF`, poderes do frost_phoenix em `SpecialsPacks/Skills_Season`; não sai em
    ovo/roleta/selvagem: `Exclusive = true`). Temporada 1 "Aurora Season" começa em 2026-10-25 00:00 (Brasília).
  - 🚩 CLÃS (`Services/ClanService`, tela `Systems/ClanMenu`, botão CLAN): criar por 5.000 Cash (`Config.CLAN`), até 20,
    convidar/aceitar, aberto ou só convite, sair, expulsar (líder), sigla [TAG] colorida em cima da cabeça, pontos da
    semana (vitória 1, captura 3, missão 5) no placar Best Clans. DataStores `DogClans_v1`/`DogClanNames_v1`,
    avisos entre servidores pelo MessagingService.
  - 🤝 TROCAS MELHORES (`TradeService` + `Systems/Trade`): os 2 confirmam, qualquer mudança zera a confirmação, mostra o
    valor de cada cachorro e o total de cada lado, destaque para shiny/GOLD/RAINBOW.
  - 💖 DOAÇÃO (`Services/DonationService`, tela `Systems/DonateMenu`, botão de coração ao lado do SETTINGS): produtos
    `Donate10/25/50/100/500/1000` (não dão item no jogo), título 💖 Supporter / Super Supporter (500) / Legendary
    Supporter (2500), agradecimento para o servidor, chuva de corações, lista TOP SUPPORTERS (`TopDonors_v1`).
  - Loja/publicar: `PUBLICAR.ps1` (lista `$items`) cria os 11 produtos novos; imagens em `Imagens/Loja/` (feitas com
    `tools/preview/shop_images.py`, que agora aceita chave com "_"). Aba STYLE nova na loja.
  - Testes novos: `tools/preview/novidades_test.luau` (regras: variantes, evoluir, Dex, acessórios, eventos, passe,
    limites do mapa, ilha do ranking) e `tools/preview/novidades_servidor_test.py` (serviços com o mock: captura shiny,
    evoluir, acessórios, passe, clãs, troca, doação). Prévia das telas: `tools/hud_preview/hud_dump.py` com as flags
    `menuPass`, `menuStyle`, `menuClan` (+`clanmember`), `menuDonate`, `menuDogs,variants`, `event`.
- 🎵🔊 2026-10-25 (o dono: "faz a música de novo e quero som para tudo, porque tem várias coisas sem som, faz o
  cachorro latir às vezes... algumas músicas, mas têm que ser viciantes, porque vão ficar horas no jogo"):
  - 🎵 TRILHA 2 (`Musica/gerar_trilha2.py`, usa os instrumentos do `gerar_musica.py`): Village, Sunny (Pawville),
    Meadows (ilhas do começo), Adventure (meio), Mystic (ilhas mágicas), Arena (Coliseu/PvP), Boss + vinhetas
    LevelUp, Victory, Gotcha (captura), RareWin (Lendário+), Unlock. Ficam em 3 PACOTES (`Musica/musicas_a/b/c.ogg`,
    ≤ 5:20 cada, por causa do limite de envios de áudio do Roblox) e o jogo toca cada uma com PlaybackRegion +
    LoopRegion (`src/shared/MusicPacks.lua`, gerado). `Systems/Music`: listas por lugar que se revezam a cada ~3 min
    (PLAYLISTS), `Music.Jingle(nome)`. Pacote sem ID = cai na trilha antiga (MusicConfig Main/Arena/Boss).
  - 🔊 PACOTE DE EFEITOS 2 (`Musica/gerar_sfx.py` → `sfx_pack2.ogg`, `SfxConfig.Pack2/Regions/Loops`; o antigo continua em
    `Pack/OldRegions` até o 2 ser enviado, com `FALLBACK` de som parecido): latidos por tamanho (Yip/Bark/Bark2/Woof),
    rosnado, uivo, choro, ganido, passos, pouso, asas, coleira (jogar/balançar/GOTCHA/fugiu), roleta (tique, giro,
    revelação), blip das falas da guia, palmas, portal, torcida, buzina do Super Boss, papel da missão e 5 ambientes em
    loop (passarinhos, grilos, vento, torcida, mar). `Sfx.Voice(model)`, `Sfx.Loop(nome)`; todo `HUD.Toast` toca som
    pela cor (`HUD.OnToast`), abrir/fechar menu toca Open/Close.
  - 🐶 `Systems/Soundscape`: ambiente por lugar/hora, latidos de vez em quando (o meu fora de luta, selvagens perto, os
    da vila), passos/pulo/pouso/asas do meu cachorro, ganido quando apanha, uivo no level up; tecla **B** (celular:
    botão BARK) = latido para todo mundo (remote `Bark` → `Services/VoiceService`) com balão "WOOF!".
  - PUBLICAR.bat envia `sfx_pack2` e os 3 pacotes de música primeiro; se o limite de áudio do mês acabar, NÃO para a
    publicação (o jogo fica com a trilha/sons antigos e tenta de novo na próxima vez).
  - Teste: `tools/preview/audio_test.py` (músicas por lugar, revezamento, loop exato, vinhetas, trilha antiga, efeitos
    novos e antigos, todo som pedido existe, voz por tamanho).
- 🥚⚖️ 2026-10-25 (o dono: "equilibra o dano e tira o ovo e só deixa o spin, meu inicial tá muito forte"):
  - ⚖️ `Config.ROOKIE` = Atk 0.8 / Def 0.45 / Full 4 / End 12 (era 1.5 / 0.6 / 5 / 15: no Lv 5 derrubava ~10 por vida;
    agora ~2 no Lv 1 e ~4 no Lv 5). O `rookie_test.luau` falha se passar de 5 por vida.
  - 🥚 `Config.EGGS = false` desliga os ovos SEM apagar código (true = volta tudo): sem botão EGGS (HUD), sem compra de ovo
    (EggService "buy" recusa), pedestais de ovo das ilhas viram LOJA DE COLEIRAS com a estátua de um cachorro da ilha
    (`IslandKit:LeashStand`, placas `ctx.EggSign`), prêmio de ovo (tutorial, missões, login, conquistas) vira 1 giro da
    roleta (`Spin`), missão "Hatch" e conquistas de ovo somem, cartões de ovo saem do guia H, Dex mostra onde capturar.
    Loja de Robux: Crystal Egg e Auto Hatch saem das abas (`SoOvo`) e o PUBLICAR.bat tira de venda no site (`OffSale`);
    Starter Pack dá 5 Super Leashes no lugar dos 2 ovos; ovo pago ainda não entregue vira 5 giros
    (`Monetization.SPINS_PER_EGG`).
- 🐾 2026-10-25 (o dono: "dobra o número de cachorro em cada ilha"): `Islands.List[id].Wild` DOBROU de novo
  (80/80/80/72/72/64/64/56). Os cachorros da Pawville (enfeite, `Village.DOGS`) ficaram iguais.
- 🦮🔄 LOTE 2026-10-25 (pedidos do dono: "se para ter cachorro não fosse mais com ovo e sim tipo pokémon?"; "faz uma loja de
  coleira em Pawville, e faz o tutorial passar lá antes e a primeira que a pessoa comprar vai ser grátis"; "faz"; "quero
  reiniciar o de todos" → escolheu "zerar progresso de todos"):
  - 🦮 CAPTURA: luta com um selvagem, deixa fraco e joga uma COLEIRA (botão CATCH / tecla G; no celular botões redondos
    CATCH e coleira no arco do pulo + a chance em cima do selvagem). Servidor `Services/CatchService` (remote CatchAction:
    state/buy/throw), cliente `Systems/Catch` (botão, animação da coleira balançando, loja). Regras em `Config.LEASHES`,
    `Config.CATCH`, `Config.CatchChance` (raridade × vida × coleira × level × sorte × campeão). Pegou = o selvagem sai da
    ilha (`NPCService.Captured`) e entra no canil no MESMO level. Campeão só depois de vencido 1 vez.
  - 🐾 LOJA DE COLEIRAS: barraquinha da praça da Pawville (`Village.STALLS[1]`, prompt com etiqueta "LeashShopPrompt") e o
    NPC das missões de cada ilha (botão F "Leashes"). 1ª compra GRÁTIS (5 coleiras, `data.LeashGift`). Coleira Divina e
    pacote de Douradas só por Robux (`LeashDivine3`, `LeashGolden10`).
  - 🐶 1º CACHORRO ESCOLHIDO (1 de 3: `Config.STARTER_CHOICES`) com o professor; a roleta ficou extra: 1 giro GRÁTIS por
    dia (`data.FreeSpinDay`) + giros comprados. Ovos continuam como extra.
  - 🧭 TUTORIAL: professor (escolha) → guia leva à LOJA DE COLEIRAS (pega o pacote grátis) → portal da Arena → Puppy
    Meadows: derrota `Config.TUTORIAL.Kills` (2) e captura `Catches` (1). A captura do tutorial nunca falha
    (`Config.TutorialCatch`). Guia "H" ganhou o cartão CATCH DOGS.
  - 🔄 RECOMEÇO DE TODOS: save novo `Config.DATASTORE_NAME = "DogFighter_v3"`; o antigo ("DogFighter_v2") só é LIDO uma vez
    por jogador para trazer o que foi pago com Robux (`Config.RESTART_KEEP`: Purchases, Spins, LuckySpins, Boosts) e
    continua guardado (para DESFAZER: voltar o nome para "DogFighter_v2"). Placares novos (`Config.BOARD_*`). Quem jogava
    antes recebe o aviso "DogWorld RESTARTED!".
  - Testes: `tools/preview/catch_test.py` (captura, loja, chance, tutorial, escolha, giro do dia),
    `tools/preview/reset_test.py` (recomeço), `tour_test.py` e `quest_test.py` atualizados. Prévias: flags
    `starterchoose`, `menuColeiras`, `leashgift`, `catchwidget` no `tools/hud_preview/hud_dump.py`.
- 🎨🗺️🛒🖼️ LOTE 2026-10-24/25 (pedidos do dono: "quero mudar todo o HUD e menus... não quero 3D, quero cartoon... HUD
  não muito grande... tira o cachorro de cima"; "esse radar vire o mapa mostrando o mapa"; "cada vez mais difícil ir para
  outras ilhas"; "reformule toda a loja e crie passes novos"; "crie imagens novas, mude a descrição e talvez o nome, quero
  5 imagens"; "esse mapa seja exatamente o mapa de cima"; "todos os cachorros olham para trás, faça olhar para frente"):
  - 🎨 CARTOON 2D: `UI/Icons.lua` desenha os ícones com formas da interface (sem 3D, sem emoji); `Kit.Cartoon` troca o
    emoji do começo dos textos por ícone desenhado em TODA a PlayerGui e no mundo (`Systems/Cartoon`). HUD menor, sem o
    retrato do cachorro em cima. Prévia sem Roblox: `tools/hud_preview` (flags `menu<Nome>`, `loja_<aba>`, `icons`...).
  - 🗺️ MINIMAPA + MAPA: o radar virou minimapa desenhado (`UI/WorldMap`) girando com a câmera; o MAP mostra as ilhas.
    Fotos DE CIMA de verdade (`tools/preview/map_tiles.py` → `Imagens/Mapa`, `Shared/MapTiles`); o PUBLICAR.bat sobe
    como Decal e o servidor (`Services/MapImages`) acha a imagem. Sem foto = o desenho.
  - 🔐 ILHAS MAIS DIFÍCEIS: `Islands.GATES` (level do cachorro + vencer o campeão + missões da ilha anterior + Cash, preços
    maiores) e `Islands.Requirements` (servidor e MAP usam a mesma regra). Perfil: `Champions`, `IslandQuests`.
    Teste: `run_shared.py tools/preview/island_gates_test.luau`.
  - 🛒 LOJA NOVA (`Systems/StoreMenu`): abas FEATURED / PASSES / CASH / DOGS & SPINS / BOOSTS com cartões desenhados.
    Passes novos: 🍀 Lucky Paw (sorte nos ovos: `DogData.EggOdds(ovo, level, sorte)`), 💨 Speedy Paws (+20%), 💖 Quick
    Revive (desmaio 2 s), 🏠 Big Kennel (antigo ExtraNest: +100 no canil, `Config.MaxDogs`). Cash que cresce com a melhor
    ilha (`Monetization.CashFor`) + Treasure of Cash. Turbinadas de 30 min (Cash Rush 2x, Lucky Rush) que somam e só
    contam jogando (`Boost_<tipo>` + `data.Boosts`; chip no HUD). Imagens dos itens: `Imagens/Loja` (`shop_images.py`).
    O PUBLICAR.bat cria os itens novos e atualiza nome/descrição/preço/imagem dos antigos (`Info_<chave>` no ids).
    Testes: `tools/preview/store_test.py` (servidor) e `run_shared.py tools/preview/shop_test.luau`.
  - 🖼️ IMAGENS DO JOGO: `Imagens/Jogo` (ícone + 5 imagens; como colocar: `Imagens/Jogo/COMO_COLOCAR.md`), feitas por
    `tools/preview/thumbs.py` com as ilhas e cachorros de verdade. O PUBLICAR.bat põe a descrição nova e o nome
    "[HALLOWEEN] Dog Fighter Simulator" até 07/11 (depois "Dog Fighter Simulator").
  - 🐶 Cachorros dos menus olhando para a FRENTE (`Kit.DogViewport`/`DogPortrait`: o cachorro olha para −Z, a câmera fica
    na frente; o giro virou balanço).
- 🧑‍🤝‍🧑🍼🐾 LOTE 2026-10-24 (pedido do dono: "quero que as pessoas sejam amigos que eu tenho na minha conta do Roblox, a
  pessoa do tutorial vai ser eu, deixa o cachorro um pouco mais forte o nosso mas somente no início porque eu comecei e não
  consegui matar nenhum cachorro, morri várias vezes, tem alguns cachorros que estão deslizando arruma isso"):
  - 🧭 A GUIA DO TUTORIAL É O DONO: `Services/VillageStars` monta PRIMEIRO o avatar do dono (molde "Guide" em
    `ReplicatedStorage.VillageStars`, atributos DisplayName/IsOwner; pasta GuideState = "ok"/"none") e o `GuideTour` usa o
    avatar (anda/acena/fala pelo `VillageFolk.Pose`), o nome dele nas falas ("I'm X, the CREATOR of this game! 👑") e no
    retrato (cópia do avatar no ViewportFrame; `rig.HeadRel` mira a cabeça). Sem molde: a Lily de blocos.
    `Config.VILLAGE_PEOPLE.Guide`: vazio = dono, "-" = Lily, nome de usuário = essa pessoa.
  - 🎓 O PROFESSOR virou o 1º AMIGO do dono (`Config.VILLAGE_PEOPLE.Professor`: vazio = 1º amigo, "owner" = o dono, "-" =
    blocos): plaquinha "🤝 <nome> · FRIEND" embaixo do 🎓 PROF. BARKLEY (Starter) e a guia apresenta "my friend <nome>".
  - 🧑‍🤝‍🧑 O POVO CHEGA AOS POUCOS: antes a vila esperava os 40 avatares (>1 min de povo de blocos, bem no tutorial). Agora
    3 montam ao mesmo tempo (`VillageStars.WORKERS`) e cada um entra na vila assim que fica pronto, na ordem da lista
    (`buildMany`); pasta com `Loading = true` até a 1ª leitura acabar — o cliente (VillageLife) mantém o povo de blocos só
    nos lugares ainda vazios. Ranking só é lido se faltar amigo. Teste: `tools/preview/village_stars_test.py`.
  - 🍼 REFORÇO DE INICIANTE (`Config.ROOKIE`, `Config.RookieBoost`, `Config.MaxAttackers`): contra selvagens/bosses (PvP não)
    o cachorro do jogador bate +150% e apanha 60% menos e só 1 selvagem ataca de cada vez — inteiro até o Lv 5, some aos
    poucos até o Lv 15 (`Fighters.RookieMult` no `Fighters.Damage`; `CombatService.wildTarget`). Mamadeira 🍼 no cartão do
    HUD enquanto vale; a guia avisa na luta do tutorial. Conta: `tools/preview/rookie_test.luau` (Lv 1: sem reforço caía em
    3 s sem derrubar nenhum; com reforço derruba ~4 por vida).
  - 🐾 CACHORROS DESLIZANDO (Animator): depois que os cachorros diminuíram, a perna não alcançava a velocidade (teto de 3,4
    passos/s para todos e passo calculado com o LegLen, que é 1,3–2x menor que a perna de verdade) → a pata "patinava"
    40–80% (os baixinhos, mais). Agora: passo = 2·alavanca·sen(abertura)/apoio com a ALAVANCA de verdade (ombro até a sola,
    `s.LeverRatio` no refresh), teto do ritmo por tamanho (`TUNE.Cycle.Hz/√perna`, até 11/s), passo que estica quando
    passa do teto (`TUNE.Stretch`, galope voador), suavização das pernas que acompanha o ritmo (`s.LegRate`), uma andadura
    de cada vez com folga (`GAIT_SLACK`) e andando de LADO (trava do Ctrl) a perna balança para o lado. Resultado: pata
    plantada (patina 0–13%). Teste: `tools/preview/slide_test.py [raças]` (SWEEP=1 varre velocidades; DEBUG=1 detalha).
- 🧭🎰 LOTE 2026-10-23 (3) (pedido do dono: "dash menos longe, cachorro mais rápido, trava no Ctrl e correr no Shift,
  nascer na ilha do cachorro, arrumar o mapa que tem dois mapas um em cima do outro, uma pessoa que explica e você segue
  até o cachorro... ele te segue... portal da Arena... objetivo... portal da 1ª ilha... mata 3 cachorros e ganha nível e
  dinheiro"; e o pedido anterior da roleta: "chance de ter todos os cachorros, 10 giros por Robux e 10 giros de sorte"):
  - 🧭 TUTORIAL COM A GUIA LILY (`client/Systems/GuideTour.lua`, começa depois do PLAY): bonequinho de blocos
    (VillageFolk) que aparece com um "puf", acena, fala (caixa de diálogo com retrato 3D, máquina de escrever, ▶ CLICK /
    SPACE, skip com 2 cliques) e anda na frente esperando o jogador (❗ e linha dourada). Roteiro: pracinha → 🎓 professor
    → CENA (câmera de cinema voando sobre o parque do canil, faixas pretas, `VillageLife.Party` = cachorros fazendo
    festa) → "chegou sua vez" → roleta (`Starter.Open`/`Starter.Kept`) → o cachorro aparece e SEGUE a pessoa (só no
    cliente; o servidor deixa a pessoa em `HumanMode` no `DogService.GrantStarter` enquanto `data.Tutorial < 99`) →
    portal da ⚔️ ARENA (explica arena/Super Boss, como o jogo funciona e o OBJETIVO: o cachorro mais forte de DogWorld)
    → portal NOVO 🌻 PUPPY MEADOWS na Pawville (`Village.MEADOWS_PORTAL`, à esquerda do fim da rua; "entre que eu te
    espero do outro lado") → na ilha ela já está lá; botão "🐶 BECOME <NOME>!" (`TutorialService` "dog" →
    `DogService.BecomeDog`) → controles → derrotar `Config.TUTORIAL.Kills` (3) selvagens (contagem no servidor, golpe
    final ou ajuda ≥ 20%) → 🎉 prêmio: +$1.000, +3 níveis (XP exata) e 1 ovo. Fases salvas em `data.Guide` (3 cachorro,
    4 arena vista, 5 luta) + `data.GuideKills`. Os cartões antigos viraram só o 📖 guia (H / Settings).
  - 🎰 ROLETA (`Services/StarterService` + `client/Systems/Starter`): chances de TODAS as raridades (`Config.ROULETTE`:
    Normal = 3 giros grátis do 1º cachorro e giros comprados; Lucky = sem Comum). Depois do 1º cachorro o professor abre a
    ROLETA PAGA: 🎰 SPIN (data.Spins) / 🍀 LUCKY SPIN (data.LuckySpins), o cachorro vai direto para o DOGS, 📊 ODDS na tela,
    JACKPOT sem pegadinha quando sai Lendário+, aviso para o servidor inteiro. Produtos novos (o .bat cria sozinho):
    `Spins10` (49 R$) e `LuckySpins10` (149 R$) — Developer Products (compra várias vezes), marcados `Aleatorio`.
  - 🗺️ MAPA "dois mapas um em cima do outro": o servidor monta tudo certo (fotos de todas as ilhas). O chão de LONGE das
    ilhas agora fica guardado em `ReplicatedStorage.ChaoLonge.<id>` e o cliente (GroundTiles) traz só quando a ilha está
    longe — antes as DUAS versões nasciam no mundo e apareciam juntas até o cliente trocar. A câmera da tela de entrada
    voava a 720 de altura, dentro do ☁️ Reino das Nuvens (700): agora 430. PEDIR PRINT se ainda aparecer algo duplicado.
  - 🏡 NASCER NA ILHA ERRADA (o dono viu depois): o avatar carregava antes do mapa montar (sem placa de nascer) e caía no
    meio da ilha principal. Agora a placa "SpawnPawville" nasce no `Main.server.lua` antes de tudo, o PlotService manda
    para a vila o avatar que já estava no jogo, a vila conta só pelo mapa de cima no `IslandService` (afundar no mar da
    vila não vira "main") e a guia espera a vila ficar pronta (`Ready`).
  - 🌊 GUIA "andando na água / não entra no portal" (o dono viu): a guia só pisa em TERRA (raio que atravessa a água:
    fundo abaixo de −1,5 = mar); caminho pelo mar ou outra ilha = some e aparece lá ("puf"); acompanhando o jogador ela
    escolhe um lado com terra. Nos portais ela ENTRA (anda até o arco, some no redemoinho) e espera do outro lado:
    portal da 🌻 Puppy Meadows e, se o jogador começar fora da vila, o portal 🏡 Pawville da ilha principal. O cachorro
    que segue a pessoa nada (meio afundado) em vez de andar sobre o mar.
  - Todo mundo nasce na 🏡 Pawville (`DogService.VillageCFrame`); 🔒 trava da câmera no CTRL e correr no SHIFT; dash
    0,16 s (~15 studs, era ~19); cachorro do jogador 15% mais rápido (`Config.PLAYER_SPEED_MULT`).
  - Testes novos: `tools/preview/tour_test.py` (tutorial + roleta, 40 checagens, chances com 20 mil giros),
    `groundtiles_test.py` com o chão de longe guardado; prévias `hud_dump.py ... tourguide|tourprof|tourchoice|tourreward|
    roulette`.
- 🎬🎓 LOTE 2026-10-23 (2) (pedido do dono: "arrumar os rabos, o spawn, 50 jogadores, tela de entrada com o nome do
  jogo e as ilhas de cima, PLAY com animação e depois o tutorial explicando tudo parte por parte com várias animações"):
  - 🐕 RABOS: juntas redondas nas dobras (`Builder:Chain` no estilo Blocky — sem buracos), curva mais suave e o abanar
    gira num eixo calculado pelo próprio rabo (atributo `WagAxis` no pivô `TailBase`; o Animator usa).
  - 📍 SPAWN: quem já tem cachorro nasce na praça da ilha principal (`DogService.PlazaCFrame`; voltar para casa também);
    quem não tem continua na 🏡 Pawville. 👥 50 JOGADORES: o `PUBLICAR.ps1` manda `serverSize 50` (republicar com o .bat;
    se não pegar, pôr Max Players = 50 no site).
  - 🎬 TELA DE ENTRADA (`client/UI/Title.lua`): câmera girando alto sobre as ilhas, logo DOG FIGHTER SIMULATOR, faixa
    do Halloween, cachorros 3D, botão ▶ PLAY (espera o save e o cachorro), mergulho da câmera até o cachorro.
    API: `Title.Done`, `Title.IsDone()`, `Title.WaitDone()`. Prévia: `hud_dump.py pc x.json title`.
  - 🎓 TUTORIAL NOVO (`client/Systems/Tutorial.lua`, começa depois do PLAY): 7 PARTES (Bem-vindo, Andar, Primeiro
    cachorro — só quem não tem —, Luta, Ilhas e missões, Cachorros e ovos, Mais diversão). CARTÕES no meio da tela
    (cachorro 3D fazendo a ação, teclas/mouse animados, ícones em sequência, NEXT/BACK/skip; texto de celular separado)
    e passos "FAÇA" (painel acima da barra de golpes + seta 👉 no botão + ⬇ no alvo + linha dourada no chão; terminam
    sozinhos: andar, correr, falar com o professor, 3 golpes, dash, portal, missão, briga, ovo grátis, menus).
    Passo salvo em `data.Tutorial` (índice da lista STEPS; o servidor só guarda depois do 1º cachorro; 99 = fim, +$500).
    📖 GUIA: tecla H ou ⚙️ SETTINGS ➜ HOW TO PLAY reabre os cartões com abas por parte (menu "Guide" do HUD).
    Prévia: `hud_dump.py pc x.json tut<N>` / `guide<N>` (o desenhista agora quebra linha de TextWrapped).
- 🐕🎃🔒 LOTE 2026-10-23 (pedido do dono: "cachorros de tamanho de cachorro, cachorro palhaço Halloween com 2 clones,
  trava de Shift, voar parado, poderes no ar, mais animação"):
  - 🐕 TAMANHO: `DogData.GAME_SIZE` dá o tamanho de cada espécie no jogo (antes todos eram 1,4x o desenho e os míticos
    gigantes tinham 4 bonecos de altura). Cabeça de ~2 a ~4,5 studs (boneco do Roblox ~5); só os colossos míticos
    passam. Bosses continuam enormes. `tools/preview/sizes.py` mede e sugere a tabela (`--lua` imprime).
    Degraus: o chão de blocos tem degraus de 1 stud e o Humanoid só sobe o que fica abaixo da caixa do corpo — cachorro
    de perna curta ganha "lift" (`DogBuilder` options.minClear = `Fighters.MIN_CLEAR` 1,15): a caixa encolhe por baixo
    e, se precisar, sobe (a junta Body desce o corpo desenhado). Atributos: HipHeight/GroundHip contam o lift, LegLen =
    perna de verdade (passo do Animator), Lift. Teste: `tools/preview/lift_test.py` (os 79 sobem degrau, pés no chão).
    Patada: `Config.MELEE_REACH` 4,5 (era 6).
  - 🎃 HALLOWEEN: raridade nova (`Config.RARITY.Halloween`, Order 6,5, entre Mítico e Divino; brilho abóbora/roxo/limão
    `Kit.PUMPKIN`), 🎃 Spooky Egg (`DogData.Eggs.halloween`, $150k: Épico 52 / Lendário 38 / Mítico 8 / Halloween 2).
    🤡 SPOOKY CLOWN (`DogPacks/PackE.lua`): roupa roxa de bolinhas, rosto branco, nariz vermelho, peruca, chapéu de cone,
    gola de babado. 2 CLONES (`Services/CloneService.lua`, `Species.Clones = 2`): andam do lado dele, batem junto (bote
    até o inimigo da frente), soltam a MESMA habilidade ao lado da setinha, dash junto, voltam 8 s depois de cair,
    somem quando ele cai/troca. Batem 35% e têm 30% da vida (`CloneService.ATK/HP`). Lutam como o dono
    (`Fighters.Hostile`) e o abate conta para o dono (`Fighters.Damage` → LastHitBy). Poderes
    (`SpecialsPacks/Skills_Halloween.lua`): Torta na Cara, Caixa-Surpresa, Supremo Circo do Terror (objetos novos no
    `client/SkillArt.lua`: Pie, JackBox, Pumpkin, ClownHead, BigTop; céu "Spooky"). Teste: `tools/preview/clones_test.py`.
  - 🔒 TRAVA DE SHIFT (`DogControl`): Shift liga/desliga (PC). Mira no meio da tela, câmera por cima do ombro girando com o
    mouse, cachorro vira com a câmera; voando, o avião segue a câmera. CORRER passou para o Ctrl (voando: Ctrl = turbo,
    C = descer). O Shift Lock do próprio Roblox continua desligado (default.project.json).
  - 🪽 VOO PARADO + PODERES NO AR: sem W o cachorro freia e fica pairando batendo as asas, virado para a setinha (espaço
    sobe, C desce). Todos os poderes funcionam no ar (`SkillKit` k.air: arrancadas viram rasantes, saltos viram
    mergulhos curtos e ele volta para a altura); no ar as poses misturam a pose de voo (Animator airAction).
  - 💨 DASH com bote esticado (Animator `pounce`; `PlayDodge(..., true)`).
- 🆘 CORREÇÕES (2026-10, o dono testou: "o HUD todo sumiu, nasci na ilha de boas-vindas, o jogo quebrou; a ilha está
  muito lagada, tem pessoas embaixo da terra; coloque todos serem meus amigos do Roblox"):
  - HUD: aparecia só depois do 1º cachorro (`gui.Enabled = profile.Started`) — perfil novo (ou save que não carregou no
    Studio) ficava com a tela VAZIA. Agora aparece sempre (barra "FIRST: Get your dog from Prof. Barkley"). Enquanto o
    perfil não chega: "Loading your save..." no meio da tela. `Main.client.lua` liga cada parte com pcall. No Studio sem o
    save, aviso vermelho explicando (DataService).
  - 🧑‍🤝‍🧑 POVO = AMIGOS DO DONO: `Services/VillageStars.lua` lê os amigos de quem publicou o jogo
    (`Players:GetFriendsAsync`; `Config.VILLAGE_PEOPLE.FriendsOf` troca a pessoa) e monta o avatar de cada um; completa com
    o ranking 💪 e quem está jogando; no máximo `Config.VILLAGE_PEOPLE.Max` (40). TODOS os lugares do povo
    (`Village.RESIDENTS`: passeio com cachorro, conversa, banco, vendedor, praia, crianças, guarda...) viram avatar,
    com plaquinha do nome ("🤝 FRIEND"). Povo de blocos só se não vier ninguém. 🎓 O Prof. Barkley vira o avatar do dono
    (`Config.VILLAGE_PEOPLE.Professor`; "-" = o de blocos), mesmo palco e mesmo botão Talk.
  - Ninguém enterrado: a altura do avatar vem das JUNTAS (`VillageFolk.AvatarRootHeight`; o HipHeight vinha errado),
    também nos NPCs de missão; o povo espera a vila ficar pronta e mede o chão de novo até achar.
  - Vila mais leve: 24 cachorros (eram 38, cada um ~170 peças), 22 passeando (eram 30), quem está longe anima menos
    vezes; detalhes pequenos somem a 420–480 studs (eram 470–540).
- ⚔️ COMBATE NA SETINHA (2026-10, pedido do dono: "onde estiver a seta o ataque vai, não quero ataques que o cachorro
  vai até lá, sempre que tento lançar trava"): todo poder sai no ponto da setinha/analógico (`Fighters.Marker`), o
  jogador continua no controle (`SkillKit` k.aim; o servidor só segura o corpo nas arrancadas curtas, até
  `Config.SKILL_MOVE`), tudo × `Config.SKILL_SPEED`. Os 19 golpes próprios dos Míticos/Divino foram refeitos no kit
  (`SpecialsPacks/Skills_Signature.lua`). Especial (tecla 4) sem barra: recarga 1,5× a da tecla 3. Patada/mordida só na
  frente da setinha (`MELEE_AIM_CONE`), ataque e tiro um pouco mais rápidos, Q = DASH no analógico que machuca quem
  está no caminho (`DogService.dashHits`). Orbes desligados (`Config.ORBS = false`). Teste: `tools/preview/skills_test.py`.
- ⚔️ ARENA (2026-10): PvP liga sozinho no chão do Coliseu, todos contra todos (`Fighters.ColosseumPvP`, sem botão);
  🌍 Super Boss com horário do relógio do mundo: 30 min dormindo (PvP) / 10 min acordado (sem PvP) — `WorldBoss.lua`;
  🛡️ barreira invisível: no PvP não sai voando (DogControl + conferência no servidor), só andando pelos portões.
  (Tudo do mesmo pedido ficou pronto: ilha da arena maior e ilhas mais longe, voo parado, poderes no ar, cachorros
  menores, palhaço Halloween com clones, trava de Shift — ver o lote 2026-10-23 acima.)
- 🏡 PAWVILLE LONGE DE TUDO + TOP 30 + SEM BOSS TOWER (2026-10, pedido do dono: "faça essa ilha bem afastada de tudo,
  os players sejam jogadores mesmo, os top 30, e tenha um portal que vai lá para a Arena; o lugar de boss não vai ter mais"):
  - A vila (`Shared/Village.lua`) foi para `Village.Center = (0, 0, 5000)` — ~2000 studs depois da Puppy Meadows,
    sozinha no mar. A PONTE SAIU. Mar próprio em volta (`Village.OCEAN_R = 2000`, `MapBuilder.buildWater`), emendando
    no oceano do mapa (raio 3600).
  - 🌀 Portal "⚔️ ARENA" no fim da rua principal da vila (`Village.ARENA_PORTAL`, `World/Village.lua arenaPortal`,
    placa em cima feita por `Deco.LabeledPortal`): leva para a praça de spawn da ilha principal (o Coliseu na frente).
    Na ilha principal, no fim da avenida do spawn (onde chegava a ponte), o portal "🏡 Pawville" traz de volta
    (`Layout.PAWVILLE_PORTAL`, `World/MainIsland.lua pawvillePortal`). `IslandService.usePortal` trata os dois.
    O menu 🗺️ MAP continua viajando para a vila. Tutorial, dica do HUD e avisos do Starter falam do portal (não da ponte).
  - Bug antigo corrigido: sem casinha, o avatar novo era mandado para a praça da ilha principal (`PlotService.sendHome`)
    e tinha que atravessar a ponte para pegar o 1º cachorro. Agora fica na pracinha da Pawville.
  - 🌟 TOP 30 DE VERDADE: `Services/VillageStars.lua` lê o ranking 💪 (OrderedDataStore "TopPower_v1", o mesmo do
    placar) a cada 10 min e monta o AVATAR do Roblox de cada um como molde em `ReplicatedStorage.VillageStars`
    (Star_01 = 1º). O cliente (`Systems/VillageLife.lua`) põe esses avatares no lugar dos MORADORES da vila, na ordem
    `Village.RESIDENTS` (quem passeia com cachorro, conversa, banco, praia, passeio), com plaquinha "👑 #1 Nome" e a
    força. Avatar anda/senta com as juntas R15 (`VillageFolk.FromAvatar`; joelhos dobram para sentar). Funcionários,
    músico, pescador e crianças continuam de blocos. Com 30 no ranking a vila fica com os 30 + funcionários; com menos,
    o povo de blocos completa até 30; sem ranking (Studio sem API) usa quem está no servidor; sem ninguém, a vila fica
    como antes. Teste: `python3 tools/preview/village_stars_test.py`.
  - 🏰 BOSS TOWER desligada: `Config.BOSS_TOWER = false`. Sem torre, sem arena do topo, sem botão BOSS/BossMenu,
    sem missões e conquistas de boss da torre (missões antigas de boss são sorteadas de novo), sem estátuas
    "👑 Tower Bosses", sem cinzas/faíscas da torre. O rochedo virou um MIRANTE gramado (bancos, lunetas, árvores,
    lanternas azuis) no caminho do ☁️ Gêiser do Céu — a ponte até ele continua. O 🌍 Super Boss do Coliseu e os 👑
    campeões das ilhas continuam. Para voltar a torre: `Config.BOSS_TOWER = true`.
  - Mosaicos na frente dos portais da Praça não piscam mais: cada anel é feito de 4 retângulos que só encostam
    (antes eram 7 quadrados empilhados a 0,02 e o anti-pisca às vezes não separava).
  - Prévia: `python3 tools/preview/islands_dump.py saida.json village` monta a vila (fotos em `Previa_Mapa/Vila_*.png`).

- Cachorros estilo BLOCOS (DogBuilder.lua, versão do dono) com joelhos e cotovelo nas asas.
  Bug corrigido: `CF()` sem argumento dava erro (CFrame.new(nil)) e quebrava o jogo inteiro.
- Animação nova do dono (Animator.lua v2) + Abilities com mordida/esquiva instantâneas.
- Orbes da Arena: usar com a tecla E (ProximityPrompt).
- Voo 2x mais rápido (FLY_MULT = 4 em DogControl.lua).
- Chão da ilha: terreno Mud pintado de verde (a grama Grass tinha grama 3D alta).
- Controles: Shift corre, F voa (avião), mouse LIVRE (o cão olha para a setinha; a câmera travada saiu), Z humano/cachorro,
  Q esquiva (no ar: parafuso), 1/2/3 golpes (vão para a setinha), 4 Supremo.

- NOVO: 🦷 mordedores x 🎯 atiradores — 32 cães atiram pela boca no ataque 1 (DogData.RANGED / SHOT_STYLES,
  CombatService.Shoot, efeito MouthShot). NPCs atiradores também atiram.
- NOVO membro da equipe: Artista de Efeitos Especiais (`equipe/efeitos-especiais.md`), SEMPRE junto com o Designer de Cachorros.
- Habilidades dos Míticos: dono quer 2, 3 e 4 novas (54). Lista v2 em `HABILIDADES_MITICOS.md` esperando aprovação.
- Ferramentas: baixar Rojo 7.4.4 em /tmp/rojo e luau-lsp 1.32.1 + globalTypes.d.luau da MESMA versão (tag 1.32.1) em /tmp/lsp.
  O CHECK.sh mostra 6 avisos antigos de tipo (Sfx, Mobile, Sea) que já existiam — não são erros novos.
  Ao gerar o .bat: ler arquivos com newline='' (o .bat usa CRLF; ler em modo texto normal estraga a troca da chave).

- NOVO: ELEMENTOS — 11 elementos (com Fly), cada cão com 1–3 (`DogData.SPECIES_ELEMENTS`, tabela `ELEMENTOS.md`), mostrados nos
  menus e na plaquinha. VANTAGEM estilo Pokémon: +30% "SUPER!" / −20% "WEAK" (`DogData.ELEMENT_STRONG`, `Fighters.Damage`).

- NOVO: celular com botões redondos em volta do pulo (UI/TouchPad.lua): RUN, HUMAN/DOG e FLY (o 🎯 LOCK saiu em 2026-10).
- NOVO: prévia 3D dos cães em `tools/preview/` (ver LEIAME lá). Divino: dono gostou do A; v2 com 5 versões esperando escolha.

- NOVO: HABILIDADES POR ELEMENTO + FUSÃO para todos (2 = próprio, 3 = elemento/fusão, 4 = Supremo de fusão).
  Tabela: `HABILIDADES.md`. Wind/Fly/Nature agora têm poderes próprios.
- NOVO: raridade DIVINE + Sunfire Dragon (PackD), vendido por Robux (DivineDog, 399). Ícone em `Icones/13_...png`.
- Teste rápido dos dados sem Roblox: `python3 tools/preview/run_shared.py teste.luau` (usa src/shared de verdade).

- NOVO: botão 🎟️ CODES (em cima do SETTINGS): `divino` = 100 Divinos, `max` = nível máximo. Só para o dono/Studio.

- NOVO (GRANDE): 🏝️ MAPA NOVO — a Arena saiu. Ilha principal com ⚔️ COLISEU (Super Boss cooperativo dormindo acorrentado,
  PvP só lá e só com ele dormindo), Praça dos Portais (8 portais) e Gêiser do Céu atrás da Boss Tower. 8 ilhas: uma por raridade
  (Puppy Meadows, Frosty Peaks, Bone Canyon, Pirate Cove, Inferno Volcano, Cosmic Rift, Sunfire Sanctum) + Sky Kingdom nas nuvens
  (Sky Egg só com cães que voam). Abrir ilha com Cash em ordem; ovo só compra com a ilha aberta. Menu 🗺️ MAP no lugar do ⚔️ ARENA.
  Tudo explicado na ficha `equipe/jogo-dogfighter.md` (seção 6b). Dados: `src/shared/Islands.lua`; ilhas: `src/server/World/`.
  Prévia sem Roblox: `python3 tools/preview/islands_dump.py /tmp/x.json common` (ou `main`) + `node tools/preview/islands_render.js
  /tmp/x.json foto.png` (precisa do Chromium do Playwright e do three.js em tools/preview/vendor).
- O publicador agora REINICIA todos os servidores depois de publicar (precisa da permissão universe:write na chave).

- NOVO (2026-10): membro 🔍 Detalhista Perfeccionista (`equipe/detalhista-perfeccionista.md`) e a 1ª passada de detalhes no
  mapa inteiro (~6.400 peças em células LOD: `World/Details.lua`, `World/MainDetails.lua`, `details(ctx)` em cada ilha; o cliente
  só mostra os detalhes perto da câmera; bichinhos pulando e peixes saltando no `WorldMotion`). Prévias: `Previa_Mapa/Detalhes/`.

- NOVO (2026-10): 🖥️ HUD NOVO no estilo A escuro (escolhido pelo dono) com ÍCONES 3D de peças (`UI/Icons3D.lua`, 34 ícones):
  cartão do cão com rosto 3D, TIME, TRADE/CODES/SETTINGS, MISSÕES com CLAIM!, chip da ilha, barra NEXT, avisos com ícone 3D,
  dinheiro com "+", chip do SUPER BOSS, radar (PC) e 6 botões; golpes e botões do celular com ícones 3D. Ficha seção 6a e
  `equipe/ESTUDO_HUD.md` seções 10–12. Foto do código de verdade sem Roblox: `tools/hud_preview/` (hud_dump.py + hud_render.js).

- CORRIGIDO (2026-10): mapa inteiro afundado (bancos, canteiros, estátuas, passarela) — o terreno do Roblox aparece ~2 studs acima
  do pedido. O MapBuilder (praça) e o TerrainGen (cada ilha) medem o chão de verdade com raios depois
  de prontos e refazem o terreno descontando a diferença (log do servidor "[Terreno] ...").
- CORRIGIDO: publicador dava "DuplicateProductName" (produto já criado numa vez anterior): agora procura pelo nome e reaproveita.

- NOVO (2026-10): 🎬 ANIMAÇÕES (pedido do dono: "tirar o modo travar, o cachorro olha para a setinha, mexe mais o corpo,
  voo tipo avião, melhorar todas"). `client/Systems/DogControl.lua` (sem trava; setinha → `Animator.SetLookAt` e remote
  `LookAt` → atributo `LookAt`; parado vira o corpo para a setinha; golpe vira rápido; VOO DE AVIÃO com manche na setinha,
  curva inclinando, mergulho/subida com energia, câmera de perseguição, parafuso na esquiva, anti-bater no chão),
  `client/Animator.lua` (olhar com mola + corpo torcendo com patas plantadas `bodyTurn`, cabeça vira na ordem certa `HEAD`,
  "laser": setinha rápida perto = animado/reverência, setinha parada = cabeça de lado, novo comportamento correr atrás do
  rabo, andar/trote/galope com mais corpo, bote da mordida com o corpo, esquiva torcendo, pose de voo de avião com asas RETAS
  medidas no modelo `WingFlat`, orelhas no vento), `Abilities.lua` (mira na setinha; dica do voo no PC no lugar do "CTRL =
  free the mouse"), `DogService.lua` (`UseAbility(slot, mira)` e `LookAt`), `DogFX.lua` (rastro branco nas pontas das asas).
  Prévia: `Previa_Animacoes/animacoes_novas.png`. Fotos das poses sem Roblox: `python tools/preview/poses.py saida.json <cão>`.
- PC do dono (Windows): ferramentas em `Documents/Dog Fighter/ferramentas` (rojo 7.7.1, luau-lsp 1.70.1 + globalTypes.d.luau,
  luau 0.740). Checagem: `bash CHECK_PC.sh` (Git Bash). Aviso antigo que já existia: 2 TypeError no WorldMotion.lua.
- NOVO (2026-10): ⚔️ LUTA NOVA (pedido do dono): selvagens BRAVOS atacam quem chega perto (vários juntos,
  `Config.AGGRO_*`, `CombatService.wildTarget`); ataque 1 = combo pata direita → pata esquerda → mordida
  (`Fighters.Melee`, `Animator.PlayMelee`, `Effects.Melee`); tiro pela boca vai BEM LONGE e acerta o 1º no caminho
  (`SHOT_RANGE` 150); poderes funcionam SEM inimigo e em qualquer lugar, saindo na setinha (alvo invisível
  `Fighters.Marker`). Testes sem Roblox feitos: 281 poderes contra o alvo invisível (0 erros), regras de inimigo
  (Hostile/Marker/Damage) e o laço da animação com o combo. Detalhes: `equipe/jogo-dogfighter.md` seção 4.

- NOVO (2026-10, GRANDE): ⚔️ HABILIDADES NOVAS DE TODOS (pedido do dono: "refaça as habilidades de todos, mais diferentes,
  com mais animação e efeitos especiais únicos; comum = simples e fraco, cada raridade um pouco melhor; a 4ª habilidade
  aparece a partir do Épico"). 188 habilidades novas (os Míticos e o Divino guardam o golpe próprio na tecla 2):
  catálogo `src/shared/Skills.lua` · força por raridade `Config.SKILL_TIER` (orçamento de dano por tecla, recargas, área,
  estados, quanto o Supremo enche) · kit `server/Services/SkillKit.lua` · habilidades `SpecialsPacks/Skills_<raridade>.lua` ·
  efeitos `client/EffectsPacks/PackSkills.lua` (S_*) · 104 objetos 3D de peças `client/SkillArt.lua` · 29 poses novas no
  `client/Animator.lua` (seção 6b). 👑 Supremo a partir do ÉPICO (`Config.HasSupreme`); botão 4 mostra o nome do Supremo;
  menu DOGS mostra as 3 habilidades. Tabela para o dono: `HABILIDADES.md` (gerada: `python tools/preview/skills_doc.py`).
  Fotos: `Previa_Habilidades/` (poses novas + uma folha por raridade). Detalhes: `equipe/jogo-dogfighter.md` seção 4g.
  TESTE SEM ROBLOX (rodar depois de mexer em habilidade): `python tools/preview/skills_test.py` — roda as 188 em 3 cenários
  com os desenhos do cliente quadro a quadro (resultado atual: 0 erros, cada uma ~100% do orçamento de dano).
  Fotos 3D dos efeitos: `tools/preview/skill_shots.py`; galeria dos objetos: `tools/preview/motifs_dump.py`.
- CORRIGIDO junto: os 25 efeitos "A_*" do Pacote A (Beagle, Corgi, Chihuahua, Pastor Alemão, Abelha...) não existiam no
  cliente (os poderes desses cães saíam sem desenho). Substituídos pelas habilidades novas.
- NOVO (2026-10, GRANDE): 🧱 MAPA EM BLOQUINHOS (pedido do dono: "tudo quadradinho, super detalhado, o chão igual às
  fotos"). Estilo: `src/shared/BlockStyle.lua` (paletas). Chão de blocos: `World/BlockGround.lua` + `TerrainGen` (ilhas, em
  workspace.Chao.<id>) + MapBuilder (ilha principal); o cliente pinta o xadrez de 3 verdes perto do personagem
  (`client/Systems/GroundTiles.lua`). Árvores `World/BlockTrees.lua`; kit `World/Deco.lua` (Ball/Cyl viraram quadrados).
  ✨ `World/AntiPisca.lua`: depois de montar cada ilha, separa faces no mesmo plano (o dono viu "blocos piscando").
  Prévias: `Previa_Mapa/Blocos/`. Ferramentas: `tools/preview/zfight.py` (acha faces piscando), `overlap.py` (objetos se
  atravessando), `houses_dump.py` (casinhas), `trees_dump.py` (árvores).
- CORRIGIDO: cão afundando no chão — o cliente trocava o chão de perto (com colisão) pelo de longe (sem colisão) olhando a
  distância da CÂMERA ao CENTRO da ilha; nas ilhas grandes a beira contava como "longe" e depois de portal demorava 0,5 s.
  Agora usa o personagem e a beira da ilha (atributo Radius) e confere todo frame.

- CORRIGIDO (2026-10, dono: "continua piscando"): 4 causas de PISCAR achadas e tiradas:
  1) praia: topo de bloco no mesmo plano da água (−2) → `BlockGround.Level` afunda para −2,7 o que cai a <0,5 da água;
  2) xadrez do chão: eram placas finas EM CIMA da tampa (de longe brigavam) → `GroundTiles` agora esconde a tampa só
     para o jogador (LocalTransparencyModifier) e põe quadrados do MESMO volume no lugar (uma superfície só);
  3) casinhas (HouseBuilder) e cachorros (DogBuilder) não passavam pelo anti-pisca → agora passam (no cão, as soldas
     C0/C1 compensam e cada peça cresce no máx. 0,2); `AntiPisca` mudou para `src/shared/` (empurrão 0,12);
  4) praça do spawn: pisos em discos empilhados a 0,01 → anéis que se encaixam (`vring` em Landmarks).
  Medido na prévia (`tools/preview/zfight.py`): ilha principal 3.401 → 158 faces, cães 1.066 → 184, casas 567 → 105.

- CORRIGIDO (2026-10, dono: "o chão das outras ilhas..." + "o jogo está muito travado"):
  1) o servidor manda as DUAS versões do chão de cada ilha (perto = ChaoBlocos, longe = ChaoLonge) e o cliente só
     mexia quando faltava a certa — nunca tirava a outra: o chão de longe ficava POR CIMA do de verdade em todas as
     ilhas (piscando) e ~80 mil peças de chão eram desenhadas sempre. `GroundTiles.swapIslands` agora deixa só UMA
     (perto = na hora; guardar = 1 ilha por quadro). Teste: `python tools/preview/groundtiles_test.py` (a versão
     antiga reprova nele).
  2) anti-pisca dos cães custava ~6x a montagem (cada selvagem que nasce travava): agora guarda a RECEITA por
     (espécie, estilo) e só repete; só no servidor. Teste: `python tools/preview/dogcache_test.py`.
  3) casinhas: cada nível é montado 1 vez (molde) e copiado para o terreno (`HouseBuilder.House`).
  4) quadradinhos do chão sem sombra própria (peso). Contagem de peças por ilha: aparece no islands_dump ("CONTAGEM").

- CORRIGIDO (2026-10, dono: "o servidor está muito pesado, travando"): o anti-pisca nas ilhas inteiras deixava a
  montagem do mapa 4–6x mais lenta (prévia: ilha principal 70 s, Puppy Meadows 48 s). `src/shared/AntiPisca.lua`
  reescrito (mesmo resultado): do chão só topo e lados, chaves numéricas, conta direta para retângulos alinhados,
  passadas seguintes só nas gavetas que mexeram, pausa a cada ~6 ms → 26 s / 7 s. E as montagens agora PAUSAM a cada
  ~8 ms (Deco.YieldFn no WorldBuilder/MapBuilder, part() do MapBuilder, BlockGround): antes uma ilha inteira de
  enfeites saía sem pausa e o servidor congelava. Receitas do anti-pisca dos cães: `DogBuilder.Prewarm()` depois do
  mapa (com pausas). Cliente: no máx. ~250 quadradinhos novos por quadro (`GroundTiles`).
  Tempos por ilha na prévia: linhas "TEMPO" do islands_dump.

- NOVO (2026-10, GRANDE): 🐶 OS 80 CACHORROS REFEITOS no estilo "BLOCOS, MAIS DETALHADOS" (escolhido e aprovado pelo dono
  depois de ver 4 exemplos). `DogBuilder.STYLE = "Blocky2"`: rosto montado na frente da cabeça-caixa (focinho em 2 tons,
  nariz com brilho, risquinho da boca, língua, presas, bochechas de pelo, olhos grandes com brilho e sobrancelhas chapadas),
  orelhas em degraus / caídas em forma de folha, patas retas com 3 dedinhos e almofadinha rosa atrás, peito com babador
  em degraus e tufinhos, pelagem em risquinhos arrumados (escamas em losango nos bichos de escama), pontinha fofa no rabo.
  Por cachorro: cabeças maiores nos comuns/incomuns (mais fofos) e coleiras coloridas com plaquinha nos cães de raça;
  Cérbero mais legível (focinho claro, chifres e juba espetada vermelhos). Ficou MAIS LEVE: ~16.800 peças nos 80 (antes
  ~22.700). Nomes das peças e juntas iguais (Animator, habilidades e pacotes continuam funcionando; os pacotes medem a
  cabeça por `look.V2` e põem enfeites no tronco de blocos por `B.Surf`). Estátuas do mapa continuam lisas ("Round").
  O estilo antigo ainda existe (`STYLE = "Blocky"`) se precisar voltar. Fotos: `Previa_Cachorros_Novos/` (antes x novo
  dos 4 exemplos, rostos de perto e catálogo de todos). Testado sem Roblox: os 80 montam, poses (andar, galope, sentar,
  morder, pular, voar) e as 188 habilidades (0 problemas). Prévia: `python tools/preview/dump.py saida.json ALL`
  (`--style Blocky` para ver o antigo) e `render.html` → `saveSheet(...)` com o `save_server.py` (ver LEIAME de lá).

- NOVO (2026-10, GRANDE): 🗡️ ESTILO BLOX FRUITS (pedido do dono). (1) 🔓 PODERES POR NÍVEL do cachorro: tecla 2 no Lv.10,
  tecla 3 no Lv.25, tecla 4/Supremo (Épico+) no Lv.50 (`Config.POWER_UNLOCK`; botões com cadeado). (2) 📜 MISSÕES: NPC com o avatar
  de um usuário do Roblox na entrada de cada ilha (`Config.QUEST_GIVER.UserName` — o dono vai mandar o nome) dá missão NORMAL
  (derrotar N selvagens da ilha) ou BOSS (o campeão) que pagam Cash + XP (`Islands.QUESTS`); é de onde vem o dinheiro (selvagem
  sozinho não paga). (3) SAÍRAM casinha, estande de treino e time que rende (`Config.HOUSES = false`; nasce na Praça dos Portais,
  vida volta sozinha fora de briga, terrenos viraram bosque). (4) O DOBRO de selvagens nas ilhas. Gamepass "Fast Training" virou
  "Fast Missions" (cada selvagem conta 2). Detalhes: `equipe/jogo-dogfighter.md` seções 2, 4h e 5a. Teste: `python
  tools/preview/quest_test.py` (43 ok).

- JUNTADO (2026-10): versão nova do dono (80 cães refeitos, estilo Blox Fruits, sem casinhas — Config.HOUSES = false —,
  missões, selvagens em dobro) + o mapa de bloquinhos e as correções de piscar/lag. Sem casinhas: o anel dos terrenos
  vira bosque (MapBuilder, árvores de bloquinhos nas células LOD) e os enfeites dos terrenos (MainDetails.plots) saem.

## Pendente
- 🆕 PEDIDOS DO DONO (2026-10-24) FEITOS: amigos na vila (mais rápido), guia = o dono, professor = 1º amigo, reforço de
  iniciante e cachorros sem deslizar. PEDIR prints/vídeo: a guia com o avatar do dono (andando, retrato da conversa), o
  professor-amigo, a vila enchendo de amigos, a 1ª luta na Puppy Meadows (dá para ganhar?) e os cachorros correndo (pata
  plantada). Se os amigos ainda não aparecerem: perguntar se o jogo é do perfil dele ou de um grupo e se ele testa no
  jogo publicado ou no Studio (no Studio, o lugar precisa estar publicado ou ele precisa estar logado).
- 🆕 PEDIDOS DO DONO (2026-10-23) FEITOS: rabos, spawn, 50 jogadores, tela de entrada, tutorial com a guia, roleta com
  todos os cachorros + 10 giros + 10 giros de sorte. PEDIR prints/vídeo: o tutorial inteiro (guia andando, cena dos
  cachorros, cachorro seguindo, portais, luta, prêmio), a roleta paga e se o mapa ainda aparece duplicado em algum lugar.
  Republicar com o .bat (cria os produtos Spins10/LuckySpins10 e põe os IDs no jogo).
- Pedir prints/vídeo no Roblox: tamanho novo dos cachorros (subir degraus andando, nada afundando), Spooky Clown e os
  clones (seguindo, batendo junto, poderes em 3), trava de Shift (mira, câmera, voo).
- Missões/Blox Fruits (2026-10): o dono vai mandar o NOME DO USUÁRIO do Roblox do NPC das missões → pôr em
  `Config.QUEST_GIVER.UserName` (shared/Config.lua). Renomear no site o passe "Fast Training" para "Fast Missions". Testar no Studio:
  NPC na entrada de cada ilha, janela, contagem, prêmio, cadeados dos poderes e o equilíbrio do dinheiro (`Islands.QUESTS`).
- Cachorros novos (2026-10): o dono aprovou pelas fotos mas ainda não viu no Roblox. Pedir prints de perto (rosto, orelhas,
  patas andando) no PC e no celular; conferir se algo ficou torto/flutuando com a luz do Roblox e se o celular aguenta.
  Ajustes por cão ficam no `Look` (DogData / DogPacks); o estilo geral no DogBuilder (funções *V2).
- Habilidades novas (2026-10): o dono ainda não viu no Roblox. Pedir prints/vídeo de alguns cães de cada raridade usando 2, 3 e
  4 (ex.: Caramel Mutt, Pug, Snow Husky, Storm Pup, Buff Bulldog, Knight Dog, Dragon Hound, Shadow Cerberus, Sunfire Dragon).
  Conferir: força (Config.SKILL_TIER), recargas, se algum objeto aparece torto/grande demais, se pesa no celular e se o
  Supremo dos Épicos enche rápido demais (Charge). Ajustes de cada golpe: frações em `Skills_<raridade>.lua`.
- Luta nova (2026-10): conferir no Roblox se os selvagens não ficam fortes demais em grupo (AGGRO_MAX/AGGRO_RANGE no Config),
  o ritmo do combo de patas e os poderes soltos na setinha sem inimigo.
- Animações novas (2026-10): o dono ainda não viu no Roblox — pedir prints/vídeo do cão olhando a setinha, virando o corpo,
  voando de avião (curva, mergulho, parafuso com Q) e no celular. Ajustes finos ficam no TUNE do Animator e no FLY do DogControl.
- Conferir no Roblox: piscando? cão afunda? (pedir prints). Rodada 2 do "super detalhado" parou no meio por limite em 3
  agentes: ilha principal (parte), chão (detalhes do solo no cliente: tufos/flores/pedrinhas — não feito), ilhas
  Divine e Cloud (enfeites próprios ainda do jeito antigo, mas já quadrados pelo kit).
- Conferir no Roblox se o chão ficou na altura certa (pé dos bancos, canteiros, casinhas, passarela da galeria) e se nada flutua.
- HUD novo: o dono ainda não viu dentro do Roblox (pedir prints no PC e no celular; conferir os ícones 3D e o retrato do cão).
- Mapa novo: o dono ainda não viu no Roblox (pedir prints de cada ilha, do Coliseu, do menu MAP e dos portais).
- Detalhes novos: conferir no Roblox se algum objeto ficou flutuando/enterrado, se os bichinhos andam no chão e se pesou no celular.
- Dono ainda não confirmou no jogo: modo Z (cachorro treinando + boneco na frente da casa), cachorros de
  blocos (agora estilo novo, ~210 peças cada), habilidades, chão novo.
- Combinado mas não feito (as 3 habilidades únicas dos Míticos FICARAM PRONTAS em 2026-10 com as habilidades novas): Economia parte 2 (ossos/baús no mapa,
  petiscos de XP, passe "Auto Buy Egg"); fusão de cachorros; novas áreas + Rebirth ($1M, +50%);
  menus com ícones 3D. Dono precisa renomear o passe "Fast Eggs" para "Fast Training" no site.
