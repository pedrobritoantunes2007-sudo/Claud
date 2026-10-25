# ⚔️ Habilidades de todos os cachorros (versão 2026-10)

Pedido do dono: **refazer as habilidades de todos**, mais diferentes, **com mais animação** e **efeitos especiais únicos**;
**comum = poderes simples e fracos**, cada raridade um pouco melhor, para equilibrar o jogo; e a **4ª habilidade (Supremo)
aparece a partir do Épico**.

## Como funciona
- **1** = ataque (combo pata direita → pata esquerda → mordida, ou o tiro pela boca dos atiradores 🎯). Não mudou.
- **2** e **3** = habilidades próprias de cada cachorro (todas diferentes). Saem onde a setinha está, mesmo sem inimigo.
- **4** = 👑 **SUPREMO**, agora a partir do **Épico** (antes só Mítico e Divino). Enche batendo; quanto mais raro, mais rápido enche.
- Os Míticos e o Divino **guardaram o golpe próprio** na tecla 2 (já era único, ex.: Time Stop, Kraken Grab) e ganharam 3 e 4 novos.
- Cada habilidade é uma sequência com **poses novas** do cachorro (pulo, mortal, rolar, cavar, latir, farejar, coice, cabeçada,
  pisotear, invocar, flexionar, dançar, sacudir...) e **objetos 3D** feitos de peças (graveto, osso, frisbee, cachorro-quente,
  abelha, âncora, shuriken, haltere, espada gigante, OVNI, navio pirata, vulcão, tubarão gigante, sarcófago, máscara de Oni...).
- O Supremo muda o céu/tela de quem está perto (vermelho, dourado, noite, gelo, espaço...).

## ⚖️ Força por raridade (Config.SKILL_TIER)
Cada habilidade gasta um **orçamento** de dano medido em "ataques" do próprio cachorro (o Atk já cresce com a raridade).
O teste sem Roblox (`tools/preview/skills_test.py`) confere que cada habilidade usa ~100% do orçamento no alvo.

| Raridade | Atk (Stat) | Tecla 2 | Tecla 3 | 👑 Supremo | Recarga 2 / 3 | Área | Atordoar/queimar | Supremo enche |
|---|---|---|---|---|---|---|---|---|
| Comuns | ×1 | 1.25 | 2.10 | — | 10s / 16s | ×0.8 | ×0.6 | — |
| Incomuns | ×1.6 | 1.50 | 2.60 | — | 9.5s / 15s | ×0.9 | ×0.7 | — |
| Raros | ×2.6 | 1.80 | 3.10 | — | 9s / 14s | ×1 | ×0.85 | — |
| Épicos | ×4.2 | 2.10 | 3.70 | 6.0 | 8.5s / 13.5s | ×1.1 | ×1 | +3 por golpe |
| Lendários | ×7 | 2.40 | 4.30 | 7.5 | 8s / 13s | ×1.2 | ×1.1 | +3.5 por golpe |
| Míticos | ×12 | 2.80 | 5.00 | 9.5 | 7.5s / 12s | ×1.3 | ×1.2 | +4 por golpe |
| ☀️ Divino | ×18 | 3.20 | 6.00 | 12.0 | 7s / 11s | ×1.4 | ×1.3 | +5 por golpe |

## Comuns
Simples e fracos: um golpe só, efeito pequeno, fofo e engraçado.

| Cachorro | Elementos | 1 | 2 | 3 |
|---|---|---|---|---|
| Caramel Mutt | ⛰️ Earth | 🐾 Combo + 🦷 | **Stick Fetch** — Joga um graveto com a boca e corre para pegar no ar (o graveto e o salto acertam). | **Dirt Kick** — Vira de costas, cava e chuta uma onda de terra e pedrinhas para trás; deixa lento. |
| Pug | ⛰️ Earth | 🐾 Combo + 🦷 | **Belly Flop** — Dá um pulinho e cai de barriga em cima do inimigo (BONK!). | **Snore Quake** — Deita e ronca 3 vezes; cada ronco faz o chão tremer e o último dá sono. |
| Pinscher | 🌪️ Wind | 🐾 Combo + 🦷 | **Nervous Nip** — Treme de nervoso, dispara até o inimigo, dá 2 mordidinhas e volta correndo. | **Tiny Twister** — Gira tão rápido que solta um tornadinho que vai até o inimigo e empurra. |
| Poodle | 🌪️ Wind | 🐾 Combo + 🦷 | **Pom-Pom Pirouette** — Faz uma pirueta chique e solta pompons para todo lado. | **Perfume Breeze** — Sopra uma brisa de perfume rosa com coraçõezinhos que encanta (para) o inimigo. |
| Bulldog | ⛰️ Earth | 🐾 Combo + 🦷 | **Grumpy Headbutt** — Abaixa a cabeça, carrega e dá uma cabeçada (BONK!). | **Grumpy Stomp** — Pisa forte 2 vezes; o chão racha e a 2ª pisada deixa tonto. |
| Beagle | 🌿 Nature | 🐾 Combo + 🦷 | **Scent Track** — Fareja, aparece um rastro de cheiro verde até o inimigo, corre por ele e morde. | **Leafy Howl** — Uiva e solta um anel de folhas que prende os inimigos em vinhas. |
| Corgi | 🌪️ Wind | 🐾 Combo + 🦷 | **Butt Bounce** — Dá um mortal, cai sentado em cima do inimigo e quica de novo (BOING!). | **Loaf Roll** — Vira um pãozinho e sai rolando por cima dos inimigos (solta farelos). |
| Dachshund | ⛰️ Earth | 🎯 Bone Shot | **Hot Dog Toss** — Joga um cachorro-quente que quica 2 vezes (acerta 3 vezes). | **Tunnel Pop** — Cava um túnel, o chão racha até o inimigo e ele sai do chão jogando o inimigo para cima. |
| Chihuahua | 🌪️ Wind | 🎯 Bark Wave | **Yap Yap Yap** — Treme de raiva e dá 3 latidos em cone (YAP!); o 3º deixa tonto. | **Tiny Tantrum** — Faz birra pulando sem parar; cada pulo solta uma onda de som e a última empurra longe. |

## Incomuns
Um pouco melhores: 2 tempos e um efeito extra (lento, preso, cura, escudo).

| Cachorro | Elementos | 1 | 2 | 3 |
|---|---|---|---|---|
| Snow Husky | ❄️ Ice | 🎯 Ice Shard | **Sled Dash** — Escorrega de barriga como trenó deixando um rastro de gelo; quem é atingido fica lento. | **Snowstorm Howl** — Uiva e faz uma nevasca no inimigo; no fim congela. |
| Armored Doberman | ⛰️ Earth | 🐾 Combo + 🦷 | **Armor Charge** — A armadura brilha e ele atropela todos numa linha reta. | **Iron Fortress** — Fica firme com escudo de pedra (leva menos dano) e depois solta um terremoto em volta. |
| Racer Boxer | 🌪️ Wind | 🐾 Combo + 🦷 | **One-Two Punch** — Fica em pé e dá socos: POW! BAM! e um gancho final que joga para cima. | **Turbo Lap** — Dá uma volta turbo em volta do inimigo; o anel de vento fecha e acerta 2 vezes. |
| Golden Retriever | ✨ Light | 🐾 Combo + 🦷 | **Tennis Fetch** — Joga uma bolinha de tênis que bate e volta; pegar a bolinha cura um pouco. | **Sunny Heart** — Senta feliz e solta 3 pulsos de luz dourada: machuca em volta e cura. |
| Dalmatian | 💧 Water | 🎯 Water Blast | **Fire Hose** — Mangueira de bombeiro: jato de água forte que empurra. | **Spot Splash** — Sacode como cachorro molhado e as pintas pretas voam e estouram como bexigas d'água. |
| German Shepherd | ⚡ Thunder | 🐾 Combo + 🦷 | **K9 Takedown** — Fareja, a mira trava, salta e prende o inimigo no chão mordendo. | **Siren Bark** — Liga a sirene de polícia: latidos em ondas vermelhas e azuis e um choque que atordoa. |
| Border Collie | 🌪️ Wind | 🐾 Combo + 🦷 | **Frisbee Catch** — Joga o frisbee e salta para pegar no ar (os dois acertam). | **Herding Rush** — Corre em volta pastoreando, junta os inimigos no meio e late empurrando. |
| St. Bernard | ❄️ Ice | 🐾 Combo + 🦷 | **Rescue Barrel** — Joga o barrilzinho de resgate; estoura em neve e o chocolate quente cura. | **Avalanche Ball** — Bate no chão e solta uma bola de neve gigante que rola por cima dos inimigos. |
| Akita | ⛰️ Earth | 🐾 Combo + 🦷 | **Stone Wall** — Levanta um muro de pedra na frente e derruba em cima do inimigo. | **Loyal Leap** — Pula bem alto e cai com um anel de pedras saindo do chão. |
| Greyhound | 🌪️ Wind | 🐾 Combo + 🦷 | **Slipstream** — Corre atravessando o inimigo e volta (2 passadas) deixando um túnel de vento. | **Starting Gate** — Semáforo de corrida 3, 2, 1, GO! e uma largada foguete que joga o inimigo longe. |

## Raros
2–3 tempos e um estado marcante (choque, veneno, maldição, sono).

| Cachorro | Elementos | 1 | 2 | 3 |
|---|---|---|---|---|
| Storm Pup | ⚡ Thunder | 🐾 Combo + 🦷 | **Thunder Hunt** — Corre em zigue-zague em volta do inimigo deixando raios e termina com um golpe que dá choque. | **Static Storm** — Uma nuvem de tempestade em cima do inimigo solta 4 raios (cada um dá choque). |
| Stone Hound | ⛰️ Earth | 🐾 Combo + 🦷 | **Boulder Toss** — Arranca uma pedra enorme do chão e arremessa. | **Rock Armor Roll** — Se cobre de pedras, vira bola, rola 2 vezes pelos inimigos e explode as pedras. |
| Robo Dog | ⚡ Thunder | 🎯 Laser | **Laser Sweep** — Laser vermelho dos olhos varrendo de um lado para o outro. | **Mini Missiles** — As costas abrem e 6 mini mísseis caem em volta do inimigo. |
| Horned Hound | ⛰️ Earth | 🐾 Combo + 🦷 | **Horn Toss** — Investe, joga o inimigo para cima com os chifres e dá outra chifrada quando ele cai. | **Spirit Stampede** — Pisa forte e uma manada de touros fantasmas atravessa o inimigo. |
| Skull Dog | 🌑 Shadow | 🎯 Bone Shot | **Boomerang Bone** — Joga um osso que gira, acerta na ida e na volta. | **Bone Rattle** — Chacoalha as costelas: ossos saem do chão em volta do inimigo e ele fica amaldiçoado (leva mais dano). |
| Crystal Dog | ❄️ Ice + ✨ Light | 🐾 Combo + 🦷 | **Crystal Path** — Uma fila de cristais brota do chão até o inimigo. | **Prism Beam** — A pedra preciosa carrega e solta um raio que se divide em 3; cura um pouco. |
| Cactus Dog | 🌿 Nature + ⛰️ Earth | 🎯 Needle Spit | **Needle Volley** — Sacode e atira um leque de 7 espinhos. | **Cactus Bloom** — Se planta no chão, floresce e atira espinhos para todos os lados; prende em vinhas. |
| Bee Dog | ☠️ Poison + 🦅 Fly | 🎯 Bee Spit | **Bee Swarm** — Solta um enxame de abelhas que persegue e envenena. | **Honey Trap** — Joga mel grudento: o inimigo fica preso e as abelhas mergulham picando. |
| Balloon Dog | 🦅 Fly | 🎯 Balloon Pop | **Water Balloons** — Joga 3 bexigas d'água em arco que estouram. | **Party Popper** — Enche, enche... e ESTOURA numa explosão de confete que joga para cima. |
| Wind-Up Dog | ⚡ Thunder | 🐾 Combo + 🦷 | **Wind-Up Rush** — A chave nas costas dá corda e ele sai correndo em zigue-zague como brinquedo, soltando faíscas. | **Spring Bounce** — Pula como mola em cima do inimigo 3 vezes com faíscas elétricas. |
| Mushroom Dog | 🌿 Nature + ☠️ Poison | 🎯 Spore Puff | **Sleepy Spores** — Uma nuvem de esporos que faz o inimigo dormir. | **Fairy Ring** — Um círculo de cogumelos brota em volta do inimigo e solta veneno 3 vezes. |

## Épicos
Golpes grandes com cenário e o 👑 Supremo liberado.

| Cachorro | Elementos | 1 | 2 | 3 | 👑 4 Supremo |
|---|---|---|---|---|---|
| Buff Bulldog | ⛰️ Earth | 🐾 Combo + 🦷 | **Muscle Flex** — Faz pose de músculo: empurra os inimigos e bate mais forte por um tempo. | **Meteor Belly Slam** — Pula até o céu e cai de barriga como um meteoro (cratera e pedras). | **GYM TITAN** — SUPREMO: levanta um haltere gigante e bate no chão 3 vezes, cada vez maior; a última atordoa. |
| Shiba Samurai | 🌪️ Wind | 🐾 Combo + 🦷 | **Iaijutsu** — Saque relâmpago: atravessa o inimigo e o corte aparece um instante depois. | **Sakura Storm** — Gira a katana numa tempestade de pétalas de cerejeira. | **THOUSAND CUTS** — SUPREMO: o céu escurece, dezenas de cortes aparecem em volta do inimigo e cortam todos juntos. |
| Ghost Dog | 🌑 Shadow | 🐾 Combo + 🦷 | **Phase Bite** — Some, aparece atrás do inimigo e dá uma mordida crítica. | **Haunting Wail** — Uiva assombrado e fantasminhas voam atrás dos inimigos, deixando lentos. | **POLTERGEIST NIGHT** — SUPREMO: vira noite, fantasmas saem do chão e mergulham nos inimigos; termina com um BOO! gigante. |
| Toxic Hound | ☠️ Poison | 🎯 Venom Spit | **Acid Spit** — Cospe 3 bolas de ácido que deixam poças que queimam. | **Toxic Cloud** — Solta uma nuvem tóxica enorme que envenena e deixa lento. | **TOXIC FLOOD** — SUPREMO: o céu fica verde e gêiseres de veneno estouram por toda parte. |
| Frost Beast | ❄️ Ice | 🎯 Ice Shard | **Icicle Barrage** — Pingentes de gelo crescem nas costas e são disparados. | **Frozen Domain** — Bate no chão: tudo em volta congela. | **ETERNAL WINTER** — SUPREMO: inverno eterno; pingentes gigantes caem do céu e tudo congela. |
| Magma Hound | 🔥 Fire + ⛰️ Earth | 🎯 Lava Spit | **Lava Pools** — Cospe 3 bolas de lava que viram poças de fogo. | **Magma Burst** — Racha o chão e gêiseres de lava estouram em linha até o inimigo. | **VOLCANO HEART** — SUPREMO: um vulcão sobe do chão embaixo do inimigo e solta bombas de lava. |
| Mummy Dog | 🌑 Shadow + ⛰️ Earth | 🐾 Combo + 🦷 | **Mummy Wrap** — Atira faixas que embrulham o inimigo (fica preso) e puxam para perto. | **Sandstorm Curse** — Tempestade de areia amaldiçoada com escaravelhos: os inimigos levam mais dano. | **PHARAOH'S TOMB** — SUPREMO: um sarcófago dourado prende o inimigo, a areia cobre e explode em luz dourada. |
| Shark Dog | 💧 Water | 🐾 Combo + 🦷 | **Fin Dive** — Mergulha no chão como se fosse água, só a barbatana aparece, e sai mordendo. | **Feeding Frenzy** — Nada em volta do inimigo com a barbatana e morde de 3 lados. | **MEGALODON** — SUPREMO: um tubarão gigante sai do chão e abocanha tudo, com onda em volta. |
| Alien Dog | ✨ Light | 🎯 Plasma Shot | **Tractor Beam** — Um disco voador puxa o inimigo para cima no raio e solta. | **Crop Circles** — Círculos misteriosos brilham no chão e explodem para cima um atrás do outro. | **MOTHERSHIP** — SUPREMO: a nave-mãe chega no céu e solta um laser gigante. |
| Ninja Dog | 🌑 Shadow + 🌪️ Wind | 🐾 Combo + 🦷 | **Shuriken Fan** — Atira 5 shurikens girando em leque. | **Shadow Clones** — 3 clones de sombra atacam de 3 lados e somem na fumaça. | **THOUSAND SHADOWS** — SUPREMO: some e ataca de todos os lados, chuva de kunais e um corte em X no fim. |
| Pirate Dog | 💧 Water | 🐾 Combo + 🦷 | **Anchor Hook** — Joga a âncora, engancha o inimigo e puxa para perto. | **Cannon Barrage** — Balas de canhão chegam do mar em volta do inimigo. | **GHOST SHIP** — SUPREMO: um navio pirata fantasma passa atirando todos os canhões e solta uma onda gigante. |
| Scorpion Dog | ☠️ Poison + ⛰️ Earth | 🐾 Combo + 🦷 | **Stinger** — Ferroada com o rabo de escorpião que envenena. | **Toxic Sands** — Abre um buraco de areia que puxa o inimigo e envenena. | **DESERT KING** — SUPREMO: um rabo de escorpião gigante sai da areia e ferroa 3 vezes. |
| Flytrap Dog | 🌿 Nature | 🐾 Combo + 🦷 | **Snap Trap** — Uma planta carnívora brota embaixo do inimigo e fecha nele (fica preso). | **Vine Whip** — Vinhas saem do chão e chicoteiam tudo em volta 4 vezes. | **JUNGLE DEVOUR** — SUPREMO: uma planta carnívora gigante engole o inimigo e a selva cresce em volta. |
| DJ Dog | ⚡ Thunder | 🎯 Bark Wave | **Bass Drop** — Caixas de som aparecem e soltam 3 ondas de grave que empurram. | **Disco Fever** — Globo de discoteca e pista de dança: os inimigos não param de dançar! | **THUNDER RAVE** — SUPREMO: palco de caixas de som, raios em cada batida e uma explosão de confete no fim. |
| Knight Dog | ✨ Light | 🐾 Combo + 🦷 | **Shield Bash** — Levanta o escudo e dá uma escudada que atordoa. | **Holy Lance** — Investe com uma lança brilhante e finca uma coluna de luz. | **EXCALIBUR** — SUPREMO: uma espada dourada gigante cai do céu no inimigo; cura o cavaleiro. |
| Armadillo Dog | ⛰️ Earth | 🐾 Combo + 🦷 | **Rolling Ball** — Vira uma bola e rola no inimigo. | **Pinball** — Quica em volta do inimigo como fliperama (4 batidas). | **BOULDER AVALANCHE** — SUPREMO: vira uma pedra gigante e esmaga tudo dando uma volta enorme. |
| Sabertooth Dog | ❄️ Ice | 🐾 Combo + 🦷 | **Saber Maul** — Dá o bote e corta com os dentes de sabre; o inimigo sangra. | **Ice Age Roar** — Um rugido congelante que transforma o inimigo em gelo. | **EXTINCTION** — SUPREMO: geleiras sobem e um espírito gigante de dente-de-sabre atravessa tudo. |

## Lendários
Mais tempos e mais área; Supremos maiores.

| Cachorro | Elementos | 1 | 2 | 3 | 👑 4 Supremo |
|---|---|---|---|---|---|
| Dragon Hound | 🔥 Fire + 🦅 Fly | 🎯 Fireball | **Dragon Breath** — Puxa o ar e solta um lança-chamas varrendo. | **Blazing Wings** — Voa e mergulha atravessando o inimigo, deixando um rastro de fogo. | **DRAGON'S FURY** — SUPREMO: sobe ao céu, faz chover bolas de fogo gigantes e sopra fogo lá de cima. |
| Twin Fang | 🌑 Shadow + ✨ Light | 🐾 Combo + 🦷 | **Double Assault** — As 2 cabeças (sombra e luz) mordem alternando; a última é crítica. | **Eclipse** — Uma bola de luz e uma de sombra giram e se chocam em cima do inimigo. | **TWILIGHT JUDGMENT** — SUPREMO: colunas de luz e sombra caem alternadas e no fim um eclipse total; cura. |
| Velocity Hound | 🌪️ Wind + ⚡ Thunder | 🐾 Combo + 🦷 | **Sonic Rush** — Quebra a barreira do som atravessando o inimigo. | **Storm Rush** — 5 arrancadas em zigue-zague deixam raios que explodem. | **LIGHTSPEED** — SUPREMO: corre em círculos tão rápido que forma um tornado de raios e termina com uma hiper arrancada. |
| Storm Wolf | ⚡ Thunder + 🌪️ Wind | 🐾 Combo + 🦷 | **Thunder Fang** — Mordida elétrica e o raio pula para os inimigos perto. | **Howling Tempest** — Uiva e cria um ciclone com raios em volta do inimigo. | **WOLF PACK STORM** — SUPREMO: uma tempestade traz 4 lobos de raio que caçam os inimigos. |
| Inferno Hound | 🔥 Fire | 🎯 Fireball | **Inferno Ring** — Um anel de fogo sai em volta dele e queima. | **Hellfire Pillars** — 5 colunas de fogo estouram em fila até o inimigo. | **INFERNO APOCALYPSE** — SUPREMO: o chão vira lava e um tornado de fogo aparece no inimigo. |
| Shadow Doberman | 🌑 Shadow | 🐾 Combo + 🦷 | **Shadow Step** — Vira sombra, desliza até embaixo do inimigo e sai mordendo para cima. | **Nightmare Clones** — 4 clones de pesadelo correm de todos os lados e explodem. | **ETERNAL NIGHT** — SUPREMO: escuridão total, mordidas de todos os lados e um golpe crítico no fim. |
| Celestial Dog | ✨ Light + 🦅 Fly | 🎯 Holy Beam | **Star Shower** — Uma chuva de estrelas cadentes no inimigo. | **Heaven's Wings** — As asas brilham e fazem chover penas sagradas; cura. | **CONSTELLATION** — SUPREMO: desenha uma constelação no céu que ganha vida e pula no inimigo. |
| Astro Dog | ✨ Light + 🔥 Fire | 🎯 Rocket Shot | **Rocket Barrage** — Dispara 4 foguetinhos. | **Zero Gravity** — A gravidade desliga: os inimigos flutuam... e caem com tudo. | **SUPERNOVA LAUNCH** — SUPREMO: decola num foguete e cai como uma supernova. |
| Yeti Dog | ❄️ Ice + ⛰️ Earth | 🐾 Combo + 🦷 | **Avalanche Toss** — Levanta uma bola de neve gigante e arremessa. | **Glacier Quake** — Pisa e lascas de gelo e pedra estouram em cruz. | **ABOMINABLE BLIZZARD** — SUPREMO: nevasca rugindo e punhos de gelo gigantes caem do céu. |
| Werewolf Dog | 🌑 Shadow | 🐾 Combo + 🦷 | **Lunar Fury** — 5 garradas seguidas em fúria. | **Moon Howl** — Aparece a lua cheia; o uivo deixa ele mais forte e assusta os inimigos. | **BLOOD MOON** — SUPREMO: lua de sangue e 3 garradas gigantes rasgam o chão. |
| Octopus Dog | 💧 Water + 🌑 Shadow | 🎯 Ink Shot | **Ink Cloud** — Solta uma nuvem de tinta que deixa lento e machuca. | **Tentacle Slam** — 4 tentáculos saem do chão e batem. | **ABYSSAL WHIRLPOOL** — SUPREMO: um redemoinho escuro puxa os inimigos para os tentáculos do fundo do mar. |
| Tank Dog | ⛰️ Earth + 🔥 Fire | 🎯 Rocket Shot | **Tank Shell** — Dispara um projétil de canhão que explode. | **Heavy Artillery** — 6 bombas de artilharia caem nos pontos marcados. | **CARPET BOMB** — SUPREMO: aviões bombardeiros passam e soltam uma fila de bombas. |
| Wizard Dog | 🔥 Fire + ❄️ Ice + ⚡ Thunder | 🎯 Arcane Orb | **Arcane Orbs** — 3 orbes (fogo, gelo e raio) giram em volta e são lançados (queima, deixa lento e dá choque). | **Elemental Trinity** — Colunas de fogo, gelo e raio cercam o inimigo e se juntam numa explosão. | **GRAND SPELLBOOK** — SUPREMO: um círculo mágico gigante solta meteoros, nevasca e raios juntos. |

## Míticos
Golpe próprio continua (tecla 2); teclas 3 e 4 novas, de cinema.

| Cachorro | Elementos | 1 | 2 | 3 | 👑 4 Supremo |
|---|---|---|---|---|---|
| Shadow Cerberus | 🌑 Shadow + 🔥 Fire | 🐾 Combo + 🦷 | **Hell Gate** — Portal no chão, as 3 cabeças atacam e sombras sobem (golpe próprio, continua). | **Triple Inferno** — As 3 cabeças soltam fogo de sombra em 3 direções girando; queima. | **HELLHOUND PACK** — SUPREMO: o céu fica vermelho e 3 cães do inferno caçam os inimigos e explodem. |
| Titan Mastiff | ⛰️ Earth + ✨ Light | 🐾 Combo + 🦷 | **Titan Rage** — Urra, o chão treme e ele cresce até 4x; cada golpe causa impacto (golpe próprio, continua). | **Titan Stomp** — Pula e cai com as 4 patas: rachaduras douradas correm para a frente jogando os inimigos para cima. | **TITAN'S JUDGMENT** — SUPREMO: colunas douradas cercam o inimigo e um punho gigante cai do céu. |
| Cosmic Dog | ✨ Light + 🌑 Shadow | 🎯 Star Shot | **Starfall** — Flutua e faz chover estrelas nos inimigos (golpe próprio, continua). | **Constellation Trap** — 5 estrelas cercam o inimigo, se ligam com linhas de luz e explodem. | **BIG BANG** — SUPREMO: sobe ao céu, tudo escurece... e explode numa galáxia. |
| Phoenix Hound | 🔥 Fire + 🦅 Fly | 🎯 Fireball | **Phoenix Dive** — Voa alto e mergulha em chamas no alvo (golpe próprio, continua). | **Firestorm Dive** — Voa em círculo acima do inimigo e mergulha como meteoro; o chão fica pegando fogo. | **PHOENIX SKYFALL** — SUPREMO: uma fênix de fogo gigante cruza o céu e penas de fogo caem; cura. |
| Void Beast | 🌑 Shadow | 🐾 Combo + 🦷 | **Void Rift** — Buraco negro que puxa todos e explode (golpe próprio, continua). | **Third Eye Beam** — O 3º olho carrega e solta um raio do vazio que atravessa e deixa lento. | **ABYSS MAW** — SUPREMO: uma boca gigante do vazio abre embaixo dos inimigos e fecha mordendo. |
| Five-Headed Hydra | ☠️ Poison + 💧 Water | 🐾 Combo + 🦷 | **Hydra Frenzy** — As cabeças esticam como cobras e mordem de 5 lados (golpe próprio, continua). | **Venom Tide** — Uma onda de água envenenada passa por cima dos inimigos. | **HYDRA RISING** — SUPREMO: 5 cabeças de serpente gigantes saem do chão e atacam; cura. |
| Bone Dragon | 🌑 Shadow + 🦅 Fly | 🎯 Ghost Fire | **Bone Cage** — Desmonta em ossos, remonta embaixo do alvo e prende numa gaiola de costelas (golpe próprio, continua). | **Ghost Fire Breath** — Sopra fogo fantasma que amaldiçoa (o inimigo leva mais dano). | **GRAVEYARD RISING** — SUPREMO: o chão vira cemitério e cães esqueletos saem da terra para atacar. |
| Kraken Dog | 💧 Water + 🌑 Shadow | 🎯 Water Blast | **Kraken Grab** — Tentáculos gigantes agarram o alvo, levantam e batem no chão (golpe próprio, continua). | **Whirlpool** — Um redemoinho puxa os inimigos enquanto tentáculos batem. | **RELEASE THE KRAKEN** — SUPREMO: 8 tentáculos gigantes saem e batem um por um, depois uma onda gigante. |
| Chrono Dog | ✨ Light + ⚡ Thunder | 🐾 Combo + 🦷 | **Time Stop** — Relógio no céu e o tempo para (golpe próprio, continua). | **Rewind Strike** — Ataca, volta no tempo e ataca de novo do mesmo lugar, 3 vezes; deixa lento. | **JUDGMENT HOUR** — SUPREMO: um relógio gigante bate 6 horas; cada badalada é um raio sagrado. |
| Singularity Pup | 🌑 Shadow + ⛰️ Earth | 🎯 Void Orb | **Event Horizon** — Vira um buraco negro que suga o alvo e cospe longe (golpe próprio, continua). | **Gravity Crush** — Levanta os inimigos no ar e esmaga no chão. | **SUPERMASSIVE** — SUPREMO: um buraco negro gigante puxa tudo e explode em luz branca. |
| Six-Winged Seraph | ✨ Light + 🦅 Fly | 🎯 Holy Beam | **Divine Judgement** — Abre as 6 asas e colunas de luz cercam o alvo (golpe próprio, continua). | **Feather Storm** — As 6 asas soltam uma tempestade de penas douradas cortantes. | **HEAVEN'S GATE** — SUPREMO: o portão do céu abre e lanças sagradas caem; cura. |
| Crystal Golem | ⛰️ Earth + ❄️ Ice | 🐾 Combo + 🦷 | **Crystal Prison** — Prende o alvo num cristal gigante (golpe próprio, continua). | **Shard Quake** — Soca o chão e uma onda de espinhos de cristal corre até o inimigo. | **DIAMOND FORTRESS** — SUPREMO: cristais gigantes sobem em volta como escudo e depois explodem para fora. |
| Ice Phoenix | ❄️ Ice + 🦅 Fly | 🎯 Ice Shard | **Glacial Rebirth** — Vira um ovo de gelo, cura e explode em penas de gelo (golpe próprio, continua). | **Blizzard Wings** — Bate as asas e solta uma nevasca que congela. | **FROZEN SKY** — SUPREMO: uma fênix de gelo gigante cruza o céu congelado e caem pingentes. |
| Thunder Colossus | ⚡ Thunder + ⛰️ Earth | 🐾 Combo + 🦷 | **Thunder Wall** — Cada pisada solta um muro de raios (golpe próprio, continua). | **Storm Fist** — Um punho gigante de raio cai do céu no inimigo; dá choque. | **STORM TITAN** — SUPREMO: raios caem por toda parte por 3 segundos e o chão treme. |
| Rainbow Unicorn | ✨ Light + 💧 Water | 🎯 Rainbow Beam | **Rainbow Bridge** — Galopa por um arco-íris e cai com o chifre no alvo (golpe próprio, continua). | **Prism Burst** — Solta 3 raios de arco-íris em leque. | **RAINBOW DELUGE** — SUPREMO: céu de arco-íris e chuva de estrelas coloridas; cura. |
| Oni Samurai | 🔥 Fire + 🌪️ Wind | 🐾 Combo + 🦷 | **Oni Blades** — As 4 katanas voam e giram cortando o alvo (golpe próprio, continua). | **Demon Dash** — 3 arrancadas cortando deixam cortes de fogo que explodem. | **BLAZING TEMPEST** — SUPREMO: uma máscara de Oni no céu, um tornado de fogo e espadas girando no inimigo. |
| Omega Mecha Dog | ⚡ Thunder + 🔥 Fire | 🎯 Photon Cannon | **Missile Barrage** — Abre os compartimentos e dispara 12 mísseis (golpe próprio, continua). | **Photon Cannon** — Carrega o canhão do peito e solta um raio de fótons enorme. | **OMEGA PROTOCOL** — SUPREMO: miras travam nos inimigos e lasers caem do espaço. |
| Planet Dog | ⛰️ Earth + 💧 Water + 🌿 Nature | 🎯 Meteor Spit | **Moonfall** — A lua sai da órbita e cai no alvo (golpe próprio, continua). | **World Bloom** — Flores brotam, gêiseres de água estouram e vinhas prendem os inimigos. | **LIVING PLANET** — SUPREMO: um planeta inteiro cai do céu; depois vem o oceano e a selva. |

## ☀️ Divino
As maiores do jogo.

| Cachorro | Elementos | 1 | 2 | 3 | 👑 4 Supremo |
|---|---|---|---|---|---|
| Sunfire Dragon | 🔥 Fire + ✨ Light + 🦅 Fly | 🎯 Sunfire Shot | **Sunfire Breath** — Raio de fogo solar dourado varrendo (golpe próprio, continua). | **Solar Wings** — Asas em chamas, mergulha atravessando o inimigo e explode numa erupção solar; cura. | **DIVINE SUNFIRE** — SUPREMO: um sol desce do céu, varre tudo com raios solares e explode em supernova; cura. |


## 🧪 Como testar sem Roblox
- `python tools/preview/skills_test.py` — roda as 188 habilidades novas num mini-mundo (com os desenhos do cliente de verdade):
  erros, quanto tempo prende o cachorro, dano no alvo em orçamentos, efeitos e poses que não existem.
- `python tools/preview/skill_shots.py saida.json SK_knight_dog_4 ...` — fotos 3D dos efeitos em alguns momentos.
- `python tools/preview/motifs_dump.py saida.json` — galeria de todos os objetos 3D dos poderes.
- `python tools/preview/poses.py saida.json caramelo lista.json` — fotos das poses (inclui as 29 poses novas).
- Arquivos: catálogo `src/shared/Skills.lua` · kit `src/server/Services/SkillKit.lua` · habilidades
  `src/server/Services/SpecialsPacks/Skills_*.lua` · efeitos `src/client/EffectsPacks/PackSkills.lua` · objetos
  `src/client/SkillArt.lua` · poses `src/client/Animator.lua` (seção 6b).
