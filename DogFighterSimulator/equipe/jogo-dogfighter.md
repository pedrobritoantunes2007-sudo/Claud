# 🐶 FICHA DO JOGO: DOG FIGHTER SIMULATOR (estado em 2026-10)
Todos os membros leem isto antes de mexer no Dog Fighter. Quem mudar o jogo ATUALIZA esta ficha (estado, números, decisões, o que falta).

## 1. O jogo em 1 frase
"Seja o seu cachorro: pegue MISSÕES com o NPC de cada ilha (estilo Blox Fruits), derrote cães selvagens e campeões, suba de nível para liberar os poderes, abra ilhas e ovos melhores e enfrente o Super Boss e os Bosses da torre."
- Pasta: `/home/user/DogFighterSimulator` (Rojo). Universe ID 10769677163. Máx. 8 jogadores (8 casinhas).
- Jogo em INGLÊS. Estilo atual: cartoon, fontes LuckiestGuy/FredokaOne, contorno escuro. HUD novo (2026-10) no estilo A escuro com
  ÍCONES 3D (`UI/Icons3D.lua`); os MENUS (DOGS, EGGS, SHOP...) ainda usam emoji.
- Arquivos para o dono: `PUBLICAR_DogFighter.bat` (publica tudo, tem a chave embutida — NUNCA compartilhar/mostrar),
  `DogFighterSimulator.rbxl` (abrir no Studio), `PROJETO_COMPLETO_DogFighter.zip` (backup sem chave), `TUDO_QUE_APRENDI.pdf`.

## 2. Loop principal (2026-10: estilo Blox Fruits, pedido do dono)
ENTRAR NA ILHA → falar com o ❗ NPC das missões na entrada → MISSÃO (derrotar N selvagens da ilha ou o campeão) → Cash + XP →
o cachorro sobe de nível e LIBERA OS PODERES (Lv.10 / 25 / 50) → ABRIR A PRÓXIMA ILHA e COMPRAR OS OVOS dela → cães melhores → repete.
(Casinha, estande de treino e time que rende SAÍRAM — `Config.HOUSES = false`.)

## 3. O jogador É o cachorro (Parte A, pronta)
- O cão equipado é o `player.Character` (`CharacterAutoLoads = false`; avatar só antes de escolher o 1º cão).
- Anda/pula/corre (Shift ou botão RUN no celular; velocidade do cão × 1,6). Câmera de jogador normal (guard no `DogControl`).
- 👀 (2026-10) SEM câmera travada: mouse livre e o cão OLHA PARA A SETINHA (cabeça + corpo torcendo; parado, vira o corpo
  se a setinha vai muito para o lado; setinha em cima dele = olha para você). Outros jogadores veem (remote `LookAt` →
  atributo `LookAt`). Golpes vão para a setinha (`UseAbility(slot, mira)`). Celular/controle: olha para onde a câmera aponta.
- Cães COM ASAS (ou que flutuavam) ficam no chão; tecla F (botão FLY no celular) liga/desliga o VOO de verdade: o cliente voa com LinearVelocity + AlignOrientation (PlatformStand); o servidor só marca `Flying` e o Animator usa a pose "Fly".
  ✈️ (2026-10) VOO DE AVIÃO: sempre para a frente; PC: a setinha é o manche (lado = curva inclinando, cima/baixo = sobe/mergulha), A/D curva, espaço sobe, C/Ctrl desce, W acelera, S freia, Shift turbo, Q = parafuso; celular/controle: analógico aponta para onde ir, pular sobe, câmera para baixo desce, RUN turbo. Mergulho ganha velocidade, subida perde; perto do chão empina sozinho; a câmera vem para trás do cão. Pose: asas retas planando, patas recolhidas, rabo de leme, cabeça nivelada nas curvas, rastro branco nas pontas das asas (DogFX).
- Trocar de cão no DOGS: o novo aparece no mesmo lugar.
- **Z (ou botão HUMAN no celular)**: volta a ser a pessoa (avatar no mesmo lugar, atributo HumanMode); Z de novo ou equipar um cão no DOGS vira o cão ali mesmo. Não vale na torre, nocauteado ou em luta PvP. Como pessoa, o cão (IA, servidor) anda até o estande e TREINA sozinho. Como cão, o avatar fica parado (ancorado) na frente da casinha (`Layout.PLOT.OwnerSpot`, `DogService.ParkAvatar`). Nocaute: renasce na casinha em 5 s.
- Atributo `AutoControl` = servidor no comando (poder especial, torre do boss): controles travados até devolver.

## 4. Combate (Parte B, pronta)
- 2026-10 (pedido do dono) — REGRAS NOVAS DE LUTA:
  - 😠 **Selvagens BRAVOS**: o selvagem que vê um cão de jogador a até `Config.AGGRO_RANGE` (40; Campeão 30) ataca sozinho
    ("❗" + rosnado), vários ao mesmo tempo (máx. `AGGRO_MAX` = 6 no mesmo cão), persegue até `AGGRO_LEASH` (110) e desiste se o
    cão sai da ilha. Na ilha, selvagem × cão de jogador é sempre inimigo (`Fighters.Hostile`); bater num selvagem faz ele brigar
    com você (`f.Aggro`). O duelo virou só o "alvo principal" (barra da luta, música, tutorial). PvP continua por duelo no Coliseu.
  - 🐾 **Ataque 1 de quem não atira = COMBO**: pata DIREITA → pata ESQUERDA → MORDIDA (finalizador que empurra). Força
    `Config.MELEE_COMBO` {0,6; 0,7; 1,5}, intervalo `MELEE_GAP`, alcance `MELEE_REACH` 6. O cliente toca a patada na hora
    (`Effects.Melee`/`Animator.PlayMelee`, riscos de unha); o servidor manda `Fighters.Melee` (efeito "Melee") para os outros.
    NPCs, bosses e o treino no estande também batem assim.
  - 🎯 **Tiro pela boca vai BEM LONGE** (`SHOT_RANGE` 150, voo até `SHOT_MAX_TIME` 2 s) na direção da setinha e acerta o
    PRIMEIRO inimigo na linha (folga `SHOT_AIM_WIDTH`); voando, a linha é 3D.
  - ✨ **Poderes (2, 3, 4) SEM inimigo e em qualquer lugar**: saem no ponto da setinha (até `POWER_REACH` 60). Inimigo a até
    `POWER_SNAP` (12) do ponto vira o alvo; senão o poder vai num ALVO INVISÍVEL (`Fighters.Marker`): só o dono o vê como inimigo
    e golpe direto nele acerta quem estiver a 6 studs do ponto. Celular: o poder sai na frente (ou no inimigo mais perto).
- Remote `UseAbility(slot, mira, pontoDaSetinha)` (servidor decide alvo, dano, recarga):
  - **1 Mordida** (até 2026-10; agora é o combo acima): clique / tecla 1 / botão. Acerta o cão mais perto na FRENTE (alcance ~5).
  - **🎯 1 = TIRO PELA BOCA nos ATIRADORES** (2026-10, pedido do dono: "uns mordem, outros atiram de longe"): 32 de 77 cães
    (`DogData.RANGED` → estilo em `DogData.SHOT_STYLES`: Fireball, Ice Shard, Laser, Bone Shot, Yap Blast...). Alcance 40, mira em
    cone na frente, 75% do dano da mordida, recarga 1,15 s, 3º tiro seguido = tiro grande que empurra (`Config.SHOT_*`).
    Servidor: `CombatService.Shoot` (o dano sai quando o tiro chega). Cliente: efeito `MouthShot` em `Effects.lua`.
    NPCs atiradores ficam a meia distância circulando e atiram; o boss sempre morde. Botão 1 mostra ícone+nome do tiro.
  - **2 Poder especial**: tecla 2 / botão. O poder da espécie (26 poderes), alcance 30, recarga 6–9 s (pela raridade).
  - **2 e 3**: `DogData.PowersFor(espécie)` = { poder 2, poder 3 }: o poder da espécie (se ninguém mais usa) + 64 poderes ELEMENTAIS (8 elementos × 8 formas, `SpecialsPacks/PackElements.lua`), distribuídos para quase ninguém repetir; elemento combina com o nome. O 3 é ULTIMATE (decisão do dono: "sempre algo foda"): sempre forma grande (Rain/Vortex/Slam/Beam), +60% de dano, preparação maior (raio, onda gigante, tremida forte) e recarga 60% maior.
  - Bug corrigido: poderes de IA só rodam com `Controlled=false` — liga só durante o poder do jogador.
  - **3 = combo ULTIMATE** (`Ult_<Elemento>_<Forma>`): elemento ERUPCIONA do chão em linha até o alvo → forma grande → explosão final.
  - **4 = SUPREMO (só Míticos)** (`Supreme_<Elemento>`, slot 5 no servidor): barra `Supreme` 0–100 enche +4 por golpe; cheia, sobe no ar, chuva de 14 meteoros + raios e explosão gigante (raio 30, 5× ataque). Aviso para o servidor todo.
  - ⚠️ **2026-10: as teclas 2, 3 e 4 foram REFEITAS** (seção 4g): habilidades próprias de cada cão, força pela raridade e Supremo a partir do Épico.
  - **Q Esquiva**: impulso no cliente + 0,45 s invencível no servidor ("MISS"), recarga 1,5 s.
  - Barra embaixo no MEIO (pedido do dono); TRAIN fica acima dela. PC: mouse livre, o golpe vai para a setinha (a câmera travada saiu em 2026-10).
  - Mordida dá um bote para a frente e tremidinha de câmera; poderes tremem mais.
- Só na ARENA (entra andando). Morder um NPC começa o duelo e ele revida pela IA antiga. PvP só se os DOIS ligaram PvP (menu ARENA).
- Sair da Arena andando encerra a luta. Prêmios de vitória (Cash + XP) iguais aos de antes.
- Celular: 3 botões redondos à esquerda do pulo; PC: canto de baixo à direita com teclas.
- **Boss (Parte C, pronta)**: o jogador controla o cão na torre (sem duelos: todos contra o boss), câmera normal; mordida e poderes valem no boss.
- Soltar poder: o cão urra (Roar/Rear) com aura e onda na cor da raridade por 0,35 s e só então o poder sai.

## 4h. 🔓 PODERES LIBERADOS POR NÍVEL (2026-10, pedido do dono, "tipo Blox Fruits")
- Nível do CACHORRO (cada cão sobe sozinho): tecla 2 no **Lv.10**, tecla 3 no **Lv.25**, tecla 4 (Supremo, do Épico para cima) no
  **Lv.50**. O ataque 1 sempre funciona. `Config.POWER_UNLOCK = { 10, 25, 50 }` (mudar aqui muda tudo).
- Servidor recusa ("🔒 This power unlocks at Lv.X!") em `DogService.useAbility`; a barra do Supremo só enche depois do Lv.50
  (`Fighters`, orbe de Poder). Botões com 🔒 + "Lv.X" (`Systems/Abilities.lua`); menu DOGS mostra "🔒Lv.X" em cada poder;
  ao chegar no nível sai o aviso "🔓 NEW POWER UNLOCKED". Selvagens e bosses usam os poderes como antes.

## 4b. Elementos (2026-10, pedido do dono)
- 11 elementos dos cães (`DogData.DOG_ELEMENTS`): Fire, Water, Ice, Thunder, Wind, Fly (dono pediu: os que voam de asas),
  Earth (ícone ⛰️ — 🪨 é emoji novo e pode não aparecer no Roblox), Nature, Poison, Shadow, Light.
- Cada cão tem 1 (43), 2 (33) ou 3 (Wizard Dog e Planet Dog) — `DogData.SPECIES_ELEMENTS`, `ElementsOf`, `ElementLabel`.
  Tabela para o dono: `ELEMENTOS.md`. No DOGS/Índice: ícones no palco 3D + STRONG/WEAK; tela do ovo e plaquinha com ícones.
- 🆚 VANTAGEM (dono escolheu estilo Pokémon): `DogData.ELEMENT_STRONG` (cada um forte contra 2), `ElementAdvantage` soma +1/−1
  por par → `Fighters.Damage` aplica ×1,3 "SUPER!" ou ×0,8 "WEAK" (`Config.ELEMENT_*`), aviso no máx. 1,5 s por dupla. Vale em tudo.
- Os poderes elementais 2/3 seguem o 1º elemento com poderes (Nature→Poison, Wind e Fly→Thunder).

## 4c. Celular (2026-10, pedido do dono)
- `client/UI/TouchPad.lua`: botões REDONDOS em arco em volta do PULO do Roblox (lê a posição real do JumpButton; acompanha
  girar a tela). Ordem: 🏃 RUN (Sprint) · 🧍 HUMAN/🐶 DOG (DogControl) · ~~🎯 LOCK~~ (saiu em 2026-10, sem câmera travada) ·
  🦅 FLY/LAND (só cães que voam). Ligado = cor forte + borda branca. Substituiu os botões retangulares soltos na direita.
- ~~Trava de câmera no celular~~ (saiu em 2026-10: o cão olha para onde a câmera aponta, sem travar).

## 4f. 🎟️ CODES (2026-10, pedido do dono, para TESTE)
- Botão "🎟️ CODES" em cima do "⚙️ SETTINGS" (Visuals.lua) → janela `client/Systems/Codes.lua` → remote `RedeemCode` →
  `server/Services/CodeService.lua`. Códigos (maiúscula/minúscula tanto faz): `divino` = completa EXATAMENTE 100 Sunfire
  Dragons; `max` = todos os cães no nível máximo. SÓ o dono do jogo (ou dono do grupo, rank 255) e o Studio; para os
  outros é "código inválido" (senão todo mundo pegaria de graça o Divino de 399 Robux).
- Os Divinos NÃO contam no canil (`DataService.DogCount`, `Net.DogCount`, sanitização com limite próprio
  `Config.MAX_DIVINE = 100`) e não podem ser trocados no TRADE, soltos nem vendidos.

## 4g. ⚔️ HABILIDADES NOVAS DE TODOS (2026-10, pedido do dono) — substitui o 4e para os cães de jogador
- Pedido: "refaça as habilidades de todos, mais diferentes, com mais animação e efeitos especiais únicos; comum = simples e
  fraco, incomum um pouco melhor... para equilibrar o jogo; a 4ª habilidade aparece a partir do Épico".
- **Catálogo** `src/shared/Skills.lua` (nome/descrição em inglês + `Pt` em português, ícone 3D, cor): cada cão tem [tecla 2,
  tecla 3, Supremo]. Ids `SK_<cão>_<tecla>`. Os Míticos e o Divino guardam o golpe próprio na tecla 2 (`Keep`: HellGate,
  C_TimeStop, D_SunfireBreath...). `DogData.PowersFor` lê o catálogo (o sistema de elementos/fusões do 4e fica só de reserva
  para cães novos sem catálogo e para os bosses). Tabela para o dono: `HABILIDADES.md` (gerada por `tools/preview/skills_doc.py`).
- **Força por raridade** `Config.SKILL_TIER`: ORÇAMENTO de dano por tecla em "ataques" do cão (Comum 1,25/2,1 → Divino
  3,2/6/12), recargas (Comum 10/16 s → Divino 7/11 s), multiplicador de ÁREA (×0,8 → ×1,4), de ESTADOS (atordoar,
  congelar, queimar ×0,6 → ×1,3) e quanto o Supremo enche por golpe (Épico +3, Lendário +3,5, Mítico +4, Divino +5).
  O Atk já cresce com a raridade (Stat). Habilidade nova NÃO tem mais o +60% antigo da tecla 3 (o orçamento já conta).
- **👑 Supremo a partir do ÉPICO**: `Config.HasSupreme` (Order ≥ Épico) e `DogData.SUPREME_RARITY`; o botão 4 mostra o
  nome do Supremo. Todo Supremo muda o céu/tela de quem está perto (`S_Sky`).
- **Kit do servidor** `server/Services/SkillKit.lua`: cada habilidade é uma função curta `def(id, tecla, function(k) ... end)`
  em `SpecialsPacks/Skills_<raridade>.lua` (188 novas). O código diz só a FRAÇÃO de cada golpe (`k:hit(0.4)`). Movimentos
  exatos sem física (`k:leap` arco, `k:glide`/`k:rise`/`k:land` voo, `k:circle`, `k:dash`, `k:blink`, `k:tp`), golpes
  (`k:area`, `k:inLine`, `k:inCone`, `k:shoot`, `k:rain`, `k:zone`, `k:summon`, `k:beam`, `k:breath`, `k:wave`), estados
  (`k:stun` com marca, `k:freeze`, `k:slow`, `k:dot`, `k:curse`, `k:force` pose no inimigo), buffs (`k:shield`, `k:rage`,
  `k:haste`, `k:heal`) e visuais (`k:pose`, `k:prop`, `k:pop`, `k:sky`...). Golpes atrasados (`k:later`) não prendem o cão.
- **Efeitos** `client/EffectsPacks/PackSkills.lua` (S_Shot, S_Rain, S_Ring, S_Orbit, S_Prop, S_Line, S_Zone, S_Mark,
  S_Aura, S_Burst, S_Beam, S_Cone, S_Wave, S_Pillar, S_Summon, S_Sky, S_Charge, S_Pop) + **objetos 3D**
  `client/SkillArt.lua` (104 motivos de peças: graveto, osso, cachorro-quente, abelha, âncora, haltere, espada gigante, OVNI,
  navio, vulcão, megalodonte, sarcófago, máscara de Oni...). Selvagens usam a tecla 2 nova da espécie.
- **Poses novas** no `client/Animator.lua` (seção 6b, 29): Leap, Flip, Roll, Curl, Drill, Kick, Dig, Bark, Spit, Sniff, Bow,
  Throw, Uppercut, Headbutt, Stomp, Summon, Focus, Flex, Slide, Bounce, Twirl, Guard, Slash, Inhale, Belly, Snore, Victory,
  Wiggle, Shake.
- **Testes sem Roblox**: `tools/preview/skills_test.py` (188 habilidades × 3 cenários, com os desenhos do cliente rodando quadro
  a quadro: 0 erros, cada uma ~100% do orçamento), `skill_shots.py` (fotos 3D dos efeitos), `motifs_dump.py` (galeria dos
  objetos), `poses.py` (poses). Fotos em `Previa_Habilidades/`.
- Corrigido junto: 25 efeitos A_* (Pacote A: Beagle, Corgi, Chihuahua, Pastor Alemão...) nunca existiram no cliente — os
  poderes desses cães não tinham desenho. As habilidades novas substituem todos eles.

## 4e. HABILIDADES POR ELEMENTO + FUSÃO (2026-10, pedido do dono) — substitui o plano das 54 dos Míticos (⚠️ trocado pelo 4g)
- `DogData.PowersFor(id)` = { 2 = golpe PRÓPRIO (sp.Special, decisão do dono: "cada um guarda o próprio"),
  3 = `Ult_<Elem>_<Forma>` (1 elemento) ou `Fus_<E1>_<E2>[_<E3>]_<Forma>` (2–3 elementos), 4 = `Supreme_<Elem>` ou
  `SupFus_<...>` (só Mítico/Divino, `Config.HasSupreme`) }. Formas grandes variadas (Rain/Vortex/Slam/Beam) por hash.
- Os 11 elementos têm poderes (PackElements): + Wind (joga longe), Fly (golpe extra do céu), Nature (raízes prendem + cura;
  `Freeze(..., "vines")` sem bloco de gelo). FUSÃO = erupção do 1º elemento → forma grande do 2º → (3º) explosão →
  explosão de fusão com TODOS (cada um aplica o seu efeito). Supremo de fusão: meteoros revezam os elementos.
- Nomes das 28 combinações em `FUSION_NAMES` (Magma Burst, Eclipse, Plasma Storm, Sunfire Nova...). Tabela para o dono:
  `HABILIDADES.md` (gerada com `tools/preview/run_shared.py`). `HABILIDADES_MITICOS.md` ficou só como ideia antiga.

## 4d. Cachorro DIVINO (PRONTO 2026-10)
- Dono quer uma raridade ACIMA do Mítico, "Divine", com UM cão só, inspirado na Ice Phoenix (o favorito dele).
- Prévias: `CANDIDATOS_DIVINO.png` (v1, dono gostou do A) e `CANDIDATOS_DIVINO_v2.png` (5 versões bem diferentes do A:
  Crystal Sovereign, Twin Crown, Starlight, Frost Dragon, Celestial Gyro) — código em `tools/preview/candidatos_divino*.lua`.
- Dono escolheu a FORMA do nº 4 da v2 (dragão-fênix: asas de dragão, chifres, cristais nas costas) e NÃO quer gelo:
  tudo que era gelo vira DOURADO. Paletas de ouro em `CANDIDATOS_DIVINO_CORES.png` (`candidatos_divino_v4.lua`):
  Divine Gold, Sunfire, Royal Amethyst, Black & Gold Emperor, Emerald Crown, Rose Gold — esperando a escolha.
- FEITO: dono escolheu a paleta 2 "Sunfire". Espécie `sun_dragon` "Sunfire Dragon" em `DogPacks/PackD.lua`
  (Fogo + Luz + Voador, atirador "Sunfire Shot", 2 = `D_SunfireBreath` em `SpecialsPacks/PackD.lua`, 3 = Sunfire Nova,
  4 = SUPREME DIVINE SUNFIRE). Raridade `Divine` (Order 7, Stat 18, renda 2500/min, brilho `Kit.SUNFIRE`).
- Como conseguir (dono escolheu): Developer Product `DivineDog` 399 Robux (Monetization.lua; o PUBLICAR.bat cria o
  produto e coloca o ID). Ícone: `Icones/13_DivineDog_SunfireDragon.png` (dono sobe no site). Nunca sai de ovo, não pode
  ser solto nem vendido (venda automática/rápida não incluem Divine). Loja: seção "☀️ DIVINE" no topo.

## 5a. 📜 MISSÕES DAS ILHAS (2026-10, pedido do dono, "tipo Blox Fruits") — o dinheiro do jogo vem daqui
- Na ENTRADA de cada ilha (perto da chegada do portal, `Islands.QuestGiverCFrame`) fica o NPC das missões com o AVATAR DE UM
  USUÁRIO DO ROBLOX: `Config.QUEST_GIVER.UserName` (o dono vai mandar o nome; vazio = avatar do dono do jogo ou boneco padrão;
  `ByIsland` = pessoa diferente por ilha). ❗ + "MISSIONS" em cima da cabeça, botão "Talk" (ProximityPrompt).
- Falando com ele: 🐶 **WILD DOGS** (derrotar N selvagens daquela ilha) ou 👑 **BOSS** (derrotar o campeão da ilha). Uma missão
  por vez (SWITCH troca, ABANDON desiste). Conta para quem deu o último golpe e para quem tirou ≥ 20% da vida (`QUEST_HELP_SHARE`).
- Prêmios em `Islands.QUESTS` (Count, Cash, XP, BossCash, BossXP por ilha): ~6 missões normais + 1 de boss pagam a próxima ilha;
  o XP leva um cão do começo ao fim dos níveis da ilha em ~5–10 missões. Gamepass 2x Cash/2x XP valem; "Fast Missions" (chave
  antiga FastEggs) conta 2 por selvagem.
- Selvagem SEM missão: não paga Cash e dá só 30% do XP de antes (`Config.WILD_XP_MULT`). Bosses da torre, Super Boss e orbes
  continuam pagando.
- Código: `server/Services/QuestService.lua` (NPCs, aceitar, contar, pagar; save `data.Quest`, `data.QuestsDone`),
  `client/Systems/Quests.lua` (janela do NPC + banner), barra do topo do HUD mostra "MISSION: Defeat 8 wild dogs 3/8" (atributos
  Quest* do jogador). Teste sem Roblox: `python tools/preview/quest_test.py` (43 conferências).
- Missões diárias: tipo novo "Complete N island missions"; Cash das diárias acompanha a ilha mais avançada aberta.
- 🐾 Ilhas com o DOBRO de selvagens (14–20, `Islands.List[id].Wild`).
- 🏠 SAÍRAM (2026-10): casinha, estande de treino, time que rende, botão HOME, faixa do TIME, botão TRAIN. O jogador nasce na Praça
  dos Portais (ou na entrada da ilha onde estava, ao desmaiar). A vida volta sozinha fora de briga (`Config.REGEN_*`). Os terrenos
  das casinhas viraram bosque. Tudo guardado atrás de `Config.HOUSES` (true = volta o jeito antigo).

## 5. Economia (Parte 1, pronta) — ⚠️ 2026-10: time, casinha e estande DESLIGADOS (ver 5a)
- **Ovos à venda** (menu 🥚 EGGS): Paw $100 · Spotted $500 · Blue $2.5k · Crystal $12k · Golden $60k · Celestial $300k.
  BUY = compra e abre (animação); BUY ×3 abre 3. Ovos ganhos (Robux, missões, tutorial) ficam guardados (🎁 OPEN). Cães NÃO botam mais ovos.
- **Estande de treino** (canto de trás da casinha, à direita — atrás não coube): 15 níveis = 5 materiais × 3
  (Madeira grátis/$150/$300 · Pedra $500/$1k/$2k · Ferro $5k/$10k/$20k · Ouro $40k/$80k/$150k · Diamante $250k/$500k/$1M).
  XP por batida 4→60. Chegar perto = bate sozinho a cada 1,6 s; botão 🥊 TRAIN (ou T) = batida extra de 50% (máx 4/s; não conta na missão).
- **Time** (renda parada): começa com 2 vagas; 3ª $2k, 4ª $20k, 5ª $150k, 6ª $1M. Renda/min Lv1: Comum 6, Incomum 15, Raro 40, Épico 110, Lendário 300, Mítico 900; +4% por nível; casinha +10% por nível; paga a cada 10 s. Cão novo entra sozinho se tiver vaga.
- **Casinha** (5 níveis, $120 → $40k): visual + renda do time.
- Venda: AUTO SELL por raridade (só repetidos) e QUICK SELL no DOGS (Lendário/Mítico só repetidos, guarda o melhor).
- Tigelas/ração e ninho de ovos foram REMOVIDOS (perfis antigos migrados: estande ≈ nível das tigelas; ovos do ninho → inventário).

## 6. Outros sistemas prontos
- 77 cães, 6 raridades (19 Míticos).
- **Bosses (2026-10)**: ESCADA de 12 chefes na torre (topo raio 120; `data.BossBeaten` libera o próximo), lacaios nas fases, círculo vermelho de aviso que explode a cada 4–8 s; **🌍 Boss do Mundo** (`WorldBoss.lua`): a cada 10 min um chefe gigante na Arena, todos lutam juntos, sempre um dos 3 últimos chefes, gigante (escala 2,2), vida 12+6 por jogador × a do chefe, dano 3x, couraça (−40% dano), círculos de explosão em todos a cada 4 s e onda gigante a cada 30 s, prêmio 5x, some em 8 min. Cada chefe da torre tem CENÁRIO próprio (`BossArenas.lua`: gelo, lava, vazio, oceano, arcano, inferno, cosmos...).
- Abrir muitos ovos: grade de 10 + CONTINUE + SKIP ALL laranja fixo embaixo.
- TRADE (botão 🤝): até 6 cães por lado, READY dos dois + contagem de 5 s, qualquer mudança tira o READY; sem equipado/favoritos. 2026-10-25: mostra o valor de cada cão e o total de cada lado, destaque shiny/GOLD/RAINBOW.
- Rankings globais: desde 2026-10-25 só na 🏆 ILHA DO RANKING (ver 6c), 6 placares.
- Missões/conquistas/login diário, tutorial visual (10 passos, prêmio $500), Settings (gráficos/música/efeitos), música e SFX (1 áudio com pedaços).
- Gamepasses: 2x Cash, 2x XP, **Fast Training** (era Fast Eggs — RENOMEAR no site), Auto Collect (SEM EFEITO até virar Auto Buy Egg), Auto Hatch, VIP, Starter Pack.
  Produtos: Cash pequeno/médio/grande, Crystal Egg, Random Mythic Dog (aleatórios bloqueados por PolicyService).

- **🏝️ MAPA NOVO (2026-10, pedido do dono: "tirar a Arena, uma ilha para cada raridade")** — ver seção 6b.
- ~~Arena (2026-10)~~ (SAIU no mapa novo; texto antigo abaixo só de histórico): raio 380 (dono pediu 3x e depois dobrar; ilha 542, terrenos 466, Boss Tower em z −670), até 18 orbes, o DOBRO de NPCs + 2 👑 Campeões (3x vida, gigantes), ✨ orbes em `ArenaOrbs.lua` (Vida, Fúria, Cash, Poder/Supremo, Escudo, Velocidade, Jackpot; ímã de 9 studs, coluna de luz). Mordida tem COMBO (1x, 1,3x, 3º = finalizador 2,2x que arremessa). Animator: pouso mais pesado com poeira, impulso no pulo, voo plana/bate conforme sobe; voo inclina nas curvas. Tela antiga de FIGHT (Targeting) desligada. CTRL liga/desliga a trava da câmera; F voa/pousa; C desce voando.

## 6a. 🖥️ HUD NOVO (2026-10, estilo A escuro aprovado pelo dono)
- Prévia aprovada: `Previa_HUD/HUD_novo_PC.png` / `HUD_novo_celular.png`. Fotos do código de verdade: `Previa_HUD/HUD_jogo_*.png`.
- Layout completo, medidas e cores: `equipe/ESTUDO_HUD.md` seções 10–12. Código: `src/client/UI/HUD.lua` (APIs antigas mantidas +
  `HUD.SetQuests`, `HUD.GetButton`, `HUD.IconFor`, `HUD.StripEmoji`) e `src/client/UI/Icons3D.lua` (34 ícones de peças).
- Saíram da coluna da direita: QUESTS (virou painel/pílula na esquerda) e TRADE (botão redondo na esquerda). CODES e SETTINGS
  (antes no canto de baixo, no `Visuals.lua`) viraram botões redondos na esquerda. Botão de som: canto direito da barra do Roblox.
- Golpes (`Systems/Abilities.lua`) e botões do celular (`UI/TouchPad.lua`, opção `Icon3D`) com ícones 3D; o ícone de cada golpe vem
  de `Icons3D.ForPower` / `ForShot` (fogo, gelo, raio, veneno, água, sombra, pedra, estrela, vento, asa, folha, osso, espada...).
- Foto sem Roblox: `python3 tools/hud_preview/hud_dump.py pc /tmp/h.json` + `node tools/hud_preview/hud_render.js /tmp/h.json foto.png`.

## 6b. 🏝️ MAPA NOVO — ilhas por raridade (2026-10)
- **Ilha principal** (raio 542): no meio o ⚔️ **COLISEU** (chão raio 150 = `Layout.ARENA_RADIUS`, muralha 226) com o 🌍 **Super Boss**
  dormindo acorrentado (estátua some quando ele acorda; placar no alto com o tempo). Em volta a **Praça dos Portais** (234–344) com
  8 portais (um por ilha, `Islands.PlazaPortalCFrame`; alguns desviados dos portões: `PLAZA_ANGLE`). Casinhas (466), Boss Tower (norte,
  z −670) e, atrás dela, a ilhota do ☁️ **Gêiser do Céu** (ponte de pedra; o gêiser leva até as nuvens). Código: `World/MainIsland.lua`
  (Coliseu, praça, gêiser) + `Services/MapBuilder.lua` (terreno, casinhas, caminhos, natureza nova com `Deco`).
- **8 ilhas** (anel de raio 2000, `Shared/Islands.lua` = dados de tudo: preço, ovo, níveis, campeão, formato):
  🌻 Puppy Meadows (Comum, grátis, Lv.1–8, Paw) · ❄️ Frosty Peaks (Incomum, $1.5k, Lv.8–16, Spotted, lago de gelo escorrega) ·
  🦴 Bone Canyon (Raro, $7.5k, Lv.15–25, Blue) · 🏴‍☠️ Pirate Cove (Épico, $35k, Crystal, campeão no convés do navio) · 🌋 Inferno Volcano
  (Lendário, $175k, Golden, LAVA QUEIMA = chão CrackedLava) · 🌌 Cosmic Rift (Mítico, $900k, Celestial, pedaços flutuantes com
  plataformas de pulo) · ☀️ Sunfire Sanctum (Divino, $3M, sem ovo: santuário vende o Sunfire Dragon por Robux; selvagens dourados) ·
  ☁️ Sky Kingdom (Y=700, $400k, precisa do vulcão, **Sky Egg** só com cães que voam, selvagens voam).
  Cada ilha: `World/Isles/<Nome>.lua` (Spec = terreno por funções de altura; Build = peças, ~1.200–3.100 peças cada).
- **Sistemas**: `IslandService` (abrir com Cash em ordem, portais por posição, viagem do MAP, atributo `Island` do jogador, lava,
  quem cai das nuvens volta, quem chega numa ilha fechada volta), `NPCService` (selvagens POR ILHA só com jogador lá; campeão no palco
  com `HomePos`), `ArenaOrbs` (orbes nos `OrbSpot` das ilhas com gente + Coliseu), `WorldBoss` (Super Boss no Coliseu, sem PvP
  acordado), `ZoneGeo` (formato das áreas de luta: zona "arena" + `f.Island`), save `data.Islands` (perfil antigo ganha as ilhas
  até a raridade do melhor cão que já tem). Ovo só compra com a ilha dele aberta (`Islands.EGG_ISLAND`).
- **PvP**: só no Coliseu e só com o Super Boss dormindo (toggle no menu 🗺️ MAP).
- **Cliente**: menu 🗺️ MAP (substituiu ⚔️ ARENA), `Systems/Islands.lua` (placas dos portais por jogador, faixa com o nome da ilha,
  ar/neblina de cada ilha, plataformas de pulo, gêiser, anéis de vento, esconde enfeites de ilha longe), `Visuals` (cor de cada ilha),
  `WorldMotion` (coisas que se mexem: tags Spinner/Bobber/Orbiter/Swayer/Burst — anima só no cliente), tutorial (passo do portal).
- **🔍 Detalhes (2026-10, Detalhista Perfeccionista)**: `World/Details.lua` (objetos pequenos por tema) + `ctx:Detail/Put/PutAt` no
  IslandKit: tudo em células LOD de 160 studs (tag `DetailCell`); o cliente (`Systems/Islands.lua`) só mostra até ~470 studs da câmera
  (gráfico Baixo 0,65x). Cada ilha tem `details(ctx)` no fim do `Build`. Ilha principal: `World/MainDetails.lua`, chamado no fim do
  `Landmarks.Build` (desvia dos marcos/árvores por uma grade das peças). Bichinhos: tags `Hopper` (coelho, galinha, ovelha, sapo,
  pinguim, caranguejo, lagartixa, gosma) e `Leaper` (peixe pulando) no `WorldMotion`. Escada do mirante é TrussPart (dá para subir).
- **Prévia sem Roblox**: `python3 tools/preview/islands_dump.py saida.json <ilha|main>` + `node tools/preview/islands_render.js` (PNG).

## 6c. 🌊🏆✨ NOVIDADES 2026-10-25 (10 pedidos do dono + doação)
- 🌊 Mar no mundo inteiro (`Layout.WORLD`) + chão e paredes invisíveis + resgate de quem cair/sair (`MapBuilder`, `IslandService`).
- 🏆 Ilha do Ranking (`Shared/RankIsland`, `World/RankIsland`): portais na praça da ilha principal e na Pawville; placares Strongest, Weekly Wins, Most Catches, Most Complete Dex, Best Clans (semana) e Season Pass.
- ✨ Shiny 1/500 (aviso no servidor, +15%) e 🧬 EVOLUIR: 3 iguais → GOLD (×1.6), 3 GOLD → RAINBOW (×2.5) (`Shared/Variants`, `EvolveService`).
- 📖 Dex com prêmios: 10/25/50 descobertos e raridade completa → coleiras, giros, Cash e títulos (`Shared/DexRewards`).
- 🎩 Acessórios (chapéu, coleira, óculos, capa; todos veem; bônus pequeno; Cash, 4 de Robux, 2 do passe) (`Shared/Accessories`, tela STYLE).
- 🎉 Eventos de fim de semana automáticos (sáb–dom, Brasília): 2x captura, 2x Cash, chuva de raros, revezando (`Shared/WeekendEvents`).
- 🎟️ Passe de Temporada: 30 dias, 30 níveis, FREE + PREMIUM (199 Robux por temporada), cão exclusivo `aurora_pup` no nível 30 premium.
- 🚩 Clãs: 5.000 Cash, até 20, convite/entrar/sair/expulsar, [TAG] em cima da cabeça, ranking semanal (`ClanService`, tela CLAN).
- 💖 Doação para o criador: 10/25/50/100/500/1000 Robux, título Supporter, chuva de corações, TOP SUPPORTERS (`DonationService`).
- Detalhes, arquivos e testes: `LEIA_PRIMEIRO_CONTINUAR.md` (Estado atual) e `tools/preview/LEIAME.md`.

## 7. Mapa dos arquivos (onde mexer)
| Assunto | Arquivo |
|---|---|
| Números (preços, XP, estande, time, ovos) | `src/shared/Config.lua` |
| Cães, ovos, bosses, poderes (descrição) | `src/shared/DogData.lua` + `DogPacks/` |
| Modelo 3D dos cães (asas, HipHeight) | `src/shared/DogBuilder.lua` |
| Posições do mapa (estande, Coliseu, terrenos) | `src/shared/Layout.lua` · ilhas: `src/shared/Islands.lua` |
| Ilhas (terreno + enfeites) | `src/server/World/` (TerrainGen, Deco, Details, IslandKit, WorldBuilder, MainIsland, MainDetails, Isles/*) |
| Abrir ilhas, portais, viagem, lava | `src/server/Services/IslandService.lua` · selvagens: `NPCService.lua` · áreas: `ZoneGeo.lua` |
| Cão do jogador, treino, habilidades, voo, equipar | `src/server/Services/DogService.lua` |
| IA de luta, mordida, poderes (execução) | `CombatService.lua`, `Specials.lua`, `Fighters.lua` |
| Comprar/abrir ovos | `EggService.lua` · Time: `TeamService.lua` (desligado) · Trade: `TradeService.lua` |
| 📜 Missões das ilhas (NPC, prêmios) | `QuestService.lua` + `Islands.QUESTS` · tela: `client/Systems/Quests.lua` |
| Casinha e estande (modelos) | `HouseBuilder.lua`, `PlotService.lua` |
| Save e migrações | `DataService.lua` |
| Telas | `src/client/UI/` (HUD, Icons3D, TouchPad, DogsMenu, ShopMenu=HOME, Hatch, MapMenu, BossMenu) · foto: `tools/hud_preview/` |
| Controles/sistemas do jogador | `src/client/Systems/` (DogControl, Abilities, Sprint, Training, Trade, Inventory=EGGS, Tutorial) |

## 8. Decisões do dono (não mudar sem perguntar)
- Jogador SEMPRE é o cão; luta controlada em TODAS as lutas (ilhas, Coliseu/PvP e Boss).
- Mapa (2026-10): SEM Arena; uma ilha por raridade do tamanho da ilha antiga, cada uma com tema; Coliseu grande com Super Boss
  cooperativo; ilha de nuvens bem alta com cães que voam. Dono pediu MUITA vegetação, árvores cheias, nada de árvore no caminho,
  caminhos contínuos, água sem falhas e coisas se mexendo.
- 3 habilidades: 1 Mordida, 2 poder da espécie, 3 poder do TIPO (Role: Tank, Assassin, Shooter, Control, Speedy...);
  os **19 Míticos têm as 3 habilidades ÚNICAS** (57 poderes novos); os outros podem ser parecidos.
- Time começa com 2 vagas; estande atrás/ao lado da casinha; treino sozinho + clique; 3 níveis por material.
- Rebirth reinicia o dinheiro E os níveis dos cães (mantém os cães), +50% de dinheiro para sempre.
- Economia: ossos/baús no mapa, petiscos de XP, fundir 3 iguais (Dourado → Diamante), áreas novas (Neve $100k, Vulcão $1M), Rebirth ($1M).
- Progressão (2026-10): estilo Blox Fruits — poderes liberam no Lv.10/25/50 do cachorro; DINHEIRO vem das MISSÕES do NPC de cada
  ilha (normal ou boss); sem casinha, sem estande, sem time que rende; mais selvagens nas ilhas.
- Visual dos cachorros (2026-10): estilo "BLOCOS, MAIS DETALHADOS" (`DogBuilder.STYLE = "Blocky2"`), aprovado pelo dono depois de ver
  4 exemplos antes x novo. Não voltar para elipsoides lisas nem trocar para realista sem perguntar. Fotos: `Previa_Cachorros_Novos/`.

## 9. O que falta (ordem combinada)
2. **Parte D**: o dono escolheu **2, 3 e 4 NOVAS e únicas** para os 18 Míticos jogáveis (54 poderes; Volcanic Cerberus é só do boss).
   Lista v2 em `HABILIDADES_MITICOS.md` (Designer de Cachorros + Artista de Efeitos), com 🦷 MORDEDORES (habilidades de mordida)
   e 🎯 ATIRADORES (tiros pela boca) — ESPERANDO APROVAÇÃO do dono. Depois: fazer em partes de ~6 Míticos (pacote novo `M_`).
3. **Economia Parte 2**: ossos e baús pelo mapa, petiscos de XP, passe Auto Collect → **Auto Buy Egg**.
4. **Economia Parte 3**: fundir cães. **Parte 4**: áreas novas + Rebirth.
5. Pendências: renomear "Fast Eggs" no site; testar no Studio as Partes A e B (o dono ainda não confirmou); MENUS com Icons3D (o HUD já usa);
   prints do HUD novo no PC e no celular (o dono ainda não viu dentro do Roblox).

## 9b. Mapa novo — pendente / ideias
- Dono ainda não viu no Roblox o mapa completo (pedir prints de cada ilha, do Coliseu e do menu MAP).
- Músicas próprias para cada ilha (hoje: Main / Arena nas ilhas / Boss no Coliseu com o Super Boss acordado).
- Peças: ~31.000 no total (ilhas ~23.700 + ilha principal ~7.300); ~6.400 são detalhes em células que só aparecem perto da
  câmera. Se o celular pesar: diminuir o raio das células (Systems/Islands.lua), StreamingEnabled ou menos enfeites.

## 10. Riscos conhecidos
- Trade: os 2 saves não são atômicos (servidor caindo no segundo da troca pode duplicar/perder).
- Poderes antigos foram feitos para IA: alguns podem empurrar/teleportar estranho com o jogador no controle — testar cada um na Parte D.
- Testes aqui são só pelo código e pela checagem; o teste de verdade é o dono no Studio/Roblox (pedir prints).
- Terreno: o Roblox desenha o Fill* ~2 studs acima do pedido (o dono viu o mapa inteiro afundado, 2026-10). O MapBuilder mede o
  chão da praça e o TerrainGen os pontos planos de cada ilha, depois de prontos, e refazem descontando; log do servidor: "[Terreno] ...".
