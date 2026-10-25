-- 📜 CATÁLOGO DAS HABILIDADES (2026-10, pedido do dono: "refaça as habilidades de todos, mais diferentes, com
-- mais animação e efeitos especiais únicos; comum = simples e fraco, cada raridade melhor; a 4ª habilidade
-- aparece a partir do Épico").
--
-- Cada cachorro tem a sua lista: [1] = habilidade 2 (tecla 2), [2] = habilidade 3 (tecla 3), [3] = SUPREMO
-- (tecla 4, só Épico para cima). Id "SK_<cachorro>_<tecla>" = programado em server/Services/SpecialsPacks/
-- Skills_<raridade>.lua (com o kit server/Services/SkillKit.lua). O golpe próprio (tecla 2) dos Míticos e do
-- Divino (Hell Gate, Time Stop, Moonfall...) foi refeito no kit em Skills_Signature.lua (2026-10: sai na setinha,
-- rápido e sem prender o cachorro); o poder antigo de mesmo nome ficou só para os bosses.
-- Name/Desc aparecem no jogo (inglês); Pt é a explicação em português (HABILIDADES.md).
-- Icon = ícone desenhado do botão (UI/Icons). Color = cor principal do efeito (senão, a cor do elemento).
local Skills = {}

local C = Color3.fromRGB

local function S(id, name, icon, desc, pt, color)
	return { Id = id, Name = name, Icon = icon, Desc = desc, Pt = pt, Color = color }
end

Skills.BySpecies = {
	------------------------------------------------------------ COMUNS (simples e fracos: 1 golpe, efeito pequeno)
	caramelo = {
		S("SK_caramelo_2", "Stick Fetch", "bone", "Tosses a stick at the enemy and runs to catch it in the air.", "Joga um graveto com a boca e corre para pegar no ar (o graveto e o salto acertam).", C(170, 120, 70)),
		S("SK_caramelo_3", "Dirt Kick", "boulder", "Turns around, digs and kicks a wave of dirt that slows enemies.", "Vira de costas, cava e chuta uma onda de terra e pedrinhas para trás; deixa lento.", C(170, 130, 80)),
	},
	pug = {
		S("SK_pug_2", "Belly Flop", "paw", "Hops up and lands belly-first on the enemy. BONK!", "Dá um pulinho e cai de barriga em cima do inimigo (BONK!).", C(225, 190, 140)),
		S("SK_pug_3", "Snore Quake", "boulder", "Lies down and snores so loud the ground shakes. The last snore puts enemies to sleep.", "Deita e ronca 3 vezes; cada ronco faz o chão tremer e o último dá sono.", C(205, 180, 140)),
	},
	pinscher = {
		S("SK_pinscher_2", "Nervous Nip", "fang", "Trembles, zips in for two quick nips and zips back.", "Treme de nervoso, dispara até o inimigo, dá 2 mordidinhas e volta correndo.", C(240, 240, 255)),
		S("SK_pinscher_3", "Tiny Twister", "wind", "Spins so fast it makes a little tornado that runs into the enemy.", "Gira tão rápido que solta um tornadinho que vai até o inimigo e empurra.", C(200, 245, 230)),
	},
	poodle = {
		S("SK_poodle_2", "Pom-Pom Pirouette", "heart", "A fancy pirouette that throws pom-poms all around.", "Faz uma pirueta chique e solta pompons para todo lado.", C(255, 200, 225)),
		S("SK_poodle_3", "Perfume Breeze", "wind", "Blows a pink perfume breeze that charms enemies for a moment.", "Sopra uma brisa de perfume rosa com coraçõezinhos que encanta (para) o inimigo.", C(255, 150, 210)),
	},
	bulldog = {
		S("SK_bulldog_2", "Grumpy Headbutt", "shield", "Lowers its head and rams the enemy. BONK!", "Abaixa a cabeça, carrega e dá uma cabeçada (BONK!).", C(220, 200, 170)),
		S("SK_bulldog_3", "Grumpy Stomp", "boulder", "Stomps twice: the ground cracks and the second stomp dizzies.", "Pisa forte 2 vezes; o chão racha e a 2ª pisada deixa tonto.", C(190, 160, 120)),
	},
	beagle = {
		S("SK_beagle_2", "Scent Track", "paw", "Sniffs out the enemy, follows the green scent trail and bites.", "Fareja, aparece um rastro de cheiro verde até o inimigo, corre por ele e morde.", C(140, 255, 120)),
		S("SK_beagle_3", "Leafy Howl", "leaf", "A howl that blows a ring of leaves and roots enemies in vines.", "Uiva e solta um anel de folhas que prende os inimigos em vinhas.", C(110, 200, 80)),
	},
	corgi = {
		S("SK_corgi_2", "Butt Bounce", "paw", "Flips onto the enemy and bounces on its fluffy butt. BOING!", "Dá um mortal, cai sentado em cima do inimigo e quica de novo (BOING!).", C(255, 205, 150)),
		S("SK_corgi_3", "Loaf Roll", "wind", "Tucks into a bread loaf and rolls right through enemies.", "Vira um pãozinho e sai rolando por cima dos inimigos (solta farelos).", C(255, 225, 175)),
	},
	salsicha = {
		S("SK_salsicha_2", "Hot Dog Toss", "bone", "Throws a hot dog that bounces twice on the enemy.", "Joga um cachorro-quente que quica 2 vezes (acerta 3 vezes).", C(230, 120, 70)),
		S("SK_salsicha_3", "Tunnel Pop", "boulder", "Digs a tunnel under the enemy and pops out launching it up.", "Cava um túnel, o chão racha até o inimigo e ele sai do chão jogando o inimigo para cima.", C(170, 130, 80)),
	},
	chihuahua = {
		S("SK_chihuahua_2", "Yap Yap Yap", "wind", "Three angry yaps in a cone. The third one dizzies.", "Treme de raiva e dá 3 latidos em cone (YAP!); o 3º deixa tonto.", C(255, 150, 210)),
		S("SK_chihuahua_3", "Tiny Tantrum", "star", "Jumps up and down in a tantrum making angry sound waves.", "Faz birra pulando sem parar; cada pulo solta uma onda de som e a última empurra longe.", C(255, 120, 190)),
	},

	------------------------------------------------------------ INCOMUNS (um pouco melhores: 2 tempos, 1 efeito extra)
	snow_husky = {
		S("SK_snow_husky_2", "Sled Dash", "ice", "Slides on its belly leaving an ice trail. Enemies hit are slowed.", "Escorrega de barriga como trenó deixando um rastro de gelo; quem é atingido fica lento.", C(190, 235, 255)),
		S("SK_snow_husky_3", "Snowstorm Howl", "ice", "Howls up a small blizzard on the enemy that ends in a freeze.", "Uiva e faz uma nevasca no inimigo; no fim congela.", C(170, 225, 255)),
	},
	armored_doberman = {
		S("SK_armored_doberman_2", "Armor Charge", "shield", "Its armor shines and it charges through everyone in a line.", "A armadura brilha e ele atropela todos numa linha reta.", C(200, 210, 230)),
		S("SK_armored_doberman_3", "Iron Fortress", "shield", "Braces in a stone shield (less damage), then breaks it in a quake.", "Fica firme com escudo de pedra (leva menos dano) e depois solta um terremoto em volta.", C(170, 160, 150)),
	},
	boxer = {
		S("SK_boxer_2", "One-Two Punch", "paw", "Stands up and boxes: POW! BAM! and a final uppercut.", "Fica em pé e dá socos: POW! BAM! e um gancho final que joga para cima.", C(255, 210, 80)),
		S("SK_boxer_3", "Turbo Lap", "wind", "Runs a turbo lap around the enemy; the wind ring closes and hits twice.", "Dá uma volta turbo em volta do inimigo; o anel de vento fecha e acerta 2 vezes.", C(210, 245, 255)),
	},
	golden = {
		S("SK_golden_2", "Tennis Fetch", "heart", "Throws a tennis ball that bounces back; catching it heals a little.", "Joga uma bolinha de tênis que bate e volta; pegar a bolinha cura um pouco.", C(205, 232, 60)),
		S("SK_golden_3", "Sunny Heart", "star", "Sits happily and pulses warm light: damages around and heals.", "Senta feliz e solta 3 pulsos de luz dourada: machuca em volta e cura.", C(255, 220, 120)),
	},
	dalmatian = {
		S("SK_dalmatian_2", "Fire Hose", "water", "Sprays a strong water jet that pushes enemies back.", "Mangueira de bombeiro: jato de água forte que empurra.", C(90, 170, 255)),
		S("SK_dalmatian_3", "Spot Splash", "water", "Shakes off its black spots: they fly out and splash like water balloons.", "Sacode como cachorro molhado e as pintas pretas voam e estouram como bexigas d'água.", C(60, 140, 240)),
	},
	pastor_alemao = {
		S("SK_pastor_alemao_2", "K9 Takedown", "target", "Locks on, leaps and pins the enemy down with bites.", "Fareja, a mira trava, salta e prende o inimigo no chão mordendo.", C(255, 70, 60)),
		S("SK_pastor_alemao_3", "Siren Bark", "bolt", "Police siren on! Red and blue bark waves end in a shocking zap.", "Liga a sirene de polícia: latidos em ondas vermelhas e azuis e um choque que atordoa.", C(80, 140, 255)),
	},
	border_collie = {
		S("SK_border_collie_2", "Frisbee Catch", "target", "Throws a frisbee and leaps to catch it mid-air.", "Joga o frisbee e salta para pegar no ar (os dois acertam).", C(235, 70, 60)),
		S("SK_border_collie_3", "Herding Rush", "wind", "Herds enemies together running around them, then barks them away.", "Corre em volta pastoreando, junta os inimigos no meio e late empurrando.", C(215, 250, 240)),
	},
	sao_bernardo = {
		S("SK_sao_bernardo_2", "Rescue Barrel", "heart", "Throws its rescue barrel; it bursts in snow and the hot cocoa heals it.", "Joga o barrilzinho de resgate; estoura em neve e o chocolate quente cura.", C(230, 245, 255)),
		S("SK_sao_bernardo_3", "Avalanche Ball", "ice", "Slams the ground and a giant snowball rolls over enemies.", "Bate no chão e solta uma bola de neve gigante que rola por cima dos inimigos.", C(220, 240, 255)),
	},
	akita = {
		S("SK_akita_2", "Stone Wall", "shield", "Raises a stone wall in front, then knocks it down on the enemy.", "Levanta um muro de pedra na frente e derruba em cima do inimigo.", C(150, 135, 120)),
		S("SK_akita_3", "Loyal Leap", "boulder", "Leaps high and lands with a ring of stones.", "Pula bem alto e cai com um anel de pedras saindo do chão.", C(175, 140, 95)),
	},
	galgo = {
		S("SK_galgo_2", "Slipstream", "wind", "Sprints through the enemy and back, leaving a wind tunnel.", "Corre atravessando o inimigo e volta (2 passadas) deixando um túnel de vento.", C(220, 250, 245)),
		S("SK_galgo_3", "Starting Gate", "wind", "3, 2, 1, GO! A rocket start that sends enemies flying.", "Semáforo de corrida 3, 2, 1, GO! e uma largada foguete que joga o inimigo longe.", C(255, 230, 90)),
	},

	------------------------------------------------------------ RAROS (2–3 tempos e um estado: atordoa, queima, veneno...)
	storm_pup = {
		S("SK_storm_pup_2", "Thunder Hunt", "bolt", "Zigzags around the enemy leaving lightning, then strikes and shocks.", "Corre em zigue-zague em volta do inimigo deixando raios e termina com um golpe que dá choque.", C(255, 235, 90)),
		S("SK_storm_pup_3", "Static Storm", "bolt", "A storm cloud over the enemy drops four lightning bolts.", "Uma nuvem de tempestade em cima do inimigo solta 4 raios (cada um dá choque).", C(255, 230, 80)),
	},
	stone_hound = {
		S("SK_stone_hound_2", "Boulder Toss", "boulder", "Rips a boulder from the ground and throws it.", "Arranca uma pedra enorme do chão e arremessa.", C(150, 130, 110)),
		S("SK_stone_hound_3", "Rock Armor Roll", "boulder", "Covers itself in rocks and rolls through enemies twice, then bursts them.", "Se cobre de pedras, vira bola, rola 2 vezes pelos inimigos e explode as pedras.", C(140, 125, 110)),
	},
	robo_dog = {
		S("SK_robo_dog_2", "Laser Sweep", "target", "Fires a red laser from its eyes and sweeps it across.", "Laser vermelho dos olhos varrendo de um lado para o outro.", C(255, 60, 60)),
		S("SK_robo_dog_3", "Mini Missiles", "gear", "Its back opens and six mini missiles rain on the enemy.", "As costas abrem e 6 mini mísseis caem em volta do inimigo.", C(255, 120, 60)),
	},
	horned_pup = {
		S("SK_horned_pup_2", "Horn Toss", "shield", "Charges, tosses the enemy up with its horns and rams it again.", "Investe, joga o inimigo para cima com os chifres e dá outra chifrada quando ele cai.", C(220, 190, 150)),
		S("SK_horned_pup_3", "Spirit Stampede", "boulder", "Stomps and a stampede of spirit bulls charges through the enemy.", "Pisa forte e uma manada de touros fantasmas atravessa o inimigo.", C(255, 170, 90)),
	},
	skull_dog = {
		S("SK_skull_dog_2", "Boomerang Bone", "bone", "Throws a spinning bone that hits on the way out and on the way back.", "Joga um osso que gira, acerta na ida e na volta.", C(243, 227, 192)),
		S("SK_skull_dog_3", "Bone Rattle", "shadow", "Rattles its ribs: bones burst from the ground and curse the enemy.", "Chacoalha as costelas: ossos saem do chão em volta do inimigo e ele fica amaldiçoado (leva mais dano).", C(170, 100, 255)),
	},
	crystal_hound = {
		S("SK_crystal_hound_2", "Crystal Path", "ice", "A line of crystals erupts from the ground toward the enemy.", "Uma fila de cristais brota do chão até o inimigo.", C(190, 230, 255)),
		S("SK_crystal_hound_3", "Prism Beam", "star", "Its gem charges and fires a beam that splits in three; heals a little.", "A pedra preciosa carrega e solta um raio que se divide em 3; cura um pouco.", C(220, 200, 255)),
	},
	cactus_dog = {
		S("SK_cactus_dog_2", "Needle Volley", "leaf", "Shakes and fires a fan of seven needles.", "Sacode e atira um leque de 7 espinhos.", C(150, 220, 110)),
		S("SK_cactus_dog_3", "Cactus Bloom", "leaf", "Plants itself, blooms and fires needles all around, rooting enemies.", "Se planta no chão, floresce e atira espinhos para todos os lados; prende em vinhas.", C(255, 120, 170)),
	},
	bee_dog = {
		S("SK_bee_dog_2", "Bee Swarm", "poison", "Releases a buzzing swarm that chases and poisons the enemy.", "Solta um enxame de abelhas que persegue e envenena.", C(255, 210, 40)),
		S("SK_bee_dog_3", "Honey Trap", "poison", "Throws sticky honey: enemies get stuck and the bees dive in.", "Joga mel grudento: o inimigo fica preso e as abelhas mergulham picando.", C(255, 175, 30)),
	},
	balloon_dog = {
		S("SK_balloon_dog_2", "Water Balloons", "water", "Tosses three water balloons that pop in splashes.", "Joga 3 bexigas d'água em arco que estouram.", C(90, 170, 255)),
		S("SK_balloon_dog_3", "Party Popper", "star", "Puffs up and POPS in a confetti explosion that launches enemies.", "Enche, enche... e ESTOURA numa explosão de confete que joga para cima.", C(255, 120, 200)),
	},
	windup_dog = {
		S("SK_windup_dog_2", "Wind-Up Rush", "gear", "Its key winds up and it zooms around like a toy, sparking.", "A chave nas costas dá corda e ele sai correndo em zigue-zague como brinquedo, soltando faíscas.", C(255, 220, 90)),
		S("SK_windup_dog_3", "Spring Bounce", "bolt", "Boings on the enemy three times with electric sparks.", "Pula como mola em cima do inimigo 3 vezes com faíscas elétricas.", C(255, 235, 110)),
	},
	mushroom_dog = {
		S("SK_mushroom_dog_2", "Sleepy Spores", "poison", "A puff of sleepy spores puts the enemy to sleep.", "Uma nuvem de esporos que faz o inimigo dormir.", C(190, 120, 230)),
		S("SK_mushroom_dog_3", "Fairy Ring", "poison", "A ring of mushrooms sprouts around the enemy and puffs poison.", "Um círculo de cogumelos brota em volta do inimigo e solta veneno 3 vezes.", C(200, 80, 200)),
	},

	------------------------------------------------------------ ÉPICOS (golpes grandes + 👑 SUPREMO liberado)
	brute_bulldog = {
		S("SK_brute_bulldog_2", "Muscle Flex", "shield", "Flexes so hard it pushes enemies away and hits harder for a while.", "Faz pose de músculo: empurra os inimigos e bate mais forte por um tempo.", C(255, 160, 80)),
		S("SK_brute_bulldog_3", "Meteor Belly Slam", "boulder", "Jumps sky-high and falls belly-first like a meteor.", "Pula até o céu e cai de barriga como um meteoro (cratera e pedras).", C(255, 140, 60)),
		S("SK_brute_bulldog_4", "GYM TITAN", "crown", "SUPREME: lifts a giant dumbbell and slams it down three times. The last one stuns.", "SUPREMO: levanta um haltere gigante e bate no chão 3 vezes, cada vez maior; a última atordoa.", C(255, 190, 60)),
	},
	samurai_shiba = {
		S("SK_samurai_shiba_2", "Iaijutsu", "sword", "A lightning-fast draw: dashes through the enemy and the cut lands a moment later.", "Saque relâmpago: atravessa o inimigo e o corte aparece um instante depois.", C(235, 240, 255)),
		S("SK_samurai_shiba_3", "Sakura Storm", "sword", "Spins its katana in a storm of cherry petals.", "Gira a katana numa tempestade de pétalas de cerejeira.", C(255, 170, 200)),
		S("SK_samurai_shiba_4", "THOUSAND CUTS", "crown", "SUPREME: the sky darkens, dozens of cuts appear around the enemy and all strike at once.", "SUPREMO: o céu escurece, dezenas de cortes aparecem em volta do inimigo e cortam todos juntos.", C(255, 200, 220)),
	},
	ghost_hound = {
		S("SK_ghost_hound_2", "Phase Bite", "shadow", "Fades away and reappears behind the enemy with a critical bite.", "Some, aparece atrás do inimigo e dá uma mordida crítica.", C(200, 230, 255)),
		S("SK_ghost_hound_3", "Haunting Wail", "shadow", "Wails and little ghosts fly out to haunt and slow the enemies.", "Uiva assombrado e fantasminhas voam atrás dos inimigos, deixando lentos.", C(190, 220, 255)),
		S("SK_ghost_hound_4", "POLTERGEIST NIGHT", "crown", "SUPREME: night falls, ghosts rise from the ground and dive at enemies. BOO!", "SUPREMO: vira noite, fantasmas saem do chão e mergulham nos inimigos; termina com um BOO! gigante.", C(170, 210, 255)),
	},
	toxic_hound = {
		S("SK_toxic_hound_2", "Acid Spit", "poison", "Spits three acid globs that leave burning puddles.", "Cospe 3 bolas de ácido que deixam poças que queimam.", C(150, 240, 70)),
		S("SK_toxic_hound_3", "Toxic Cloud", "poison", "Breathes a huge toxic cloud that poisons and slows.", "Solta uma nuvem tóxica enorme que envenena e deixa lento.", C(140, 230, 60)),
		S("SK_toxic_hound_4", "TOXIC FLOOD", "crown", "SUPREME: the sky turns green and toxic geysers erupt everywhere.", "SUPREMO: o céu fica verde e gêiseres de veneno estouram por toda parte.", C(130, 240, 60)),
	},
	frost_beast = {
		S("SK_frost_beast_2", "Icicle Barrage", "ice", "Icicles grow on its back and launch at the enemy.", "Pingentes de gelo crescem nas costas e são disparados.", C(170, 225, 255)),
		S("SK_frost_beast_3", "Frozen Domain", "ice", "Slams the ground: everything around freezes solid.", "Bate no chão: tudo em volta congela.", C(160, 220, 255)),
		S("SK_frost_beast_4", "ETERNAL WINTER", "crown", "SUPREME: an eternal winter falls; giant icicles rain and everything freezes.", "SUPREMO: inverno eterno; pingentes gigantes caem do céu e tudo congela.", C(190, 235, 255)),
	},
	magma_hound = {
		S("SK_magma_hound_2", "Lava Pools", "fire", "Spits three lava globs that leave burning pools.", "Cospe 3 bolas de lava que viram poças de fogo.", C(255, 120, 30)),
		S("SK_magma_hound_3", "Magma Burst", "fire", "Cracks the ground and lava geysers erupt in a line.", "Racha o chão e gêiseres de lava estouram em linha até o inimigo.", C(255, 110, 25)),
		S("SK_magma_hound_4", "VOLCANO HEART", "crown", "SUPREME: a volcano rises under the enemy and erupts lava bombs.", "SUPREMO: um vulcão sobe do chão embaixo do inimigo e solta bombas de lava.", C(255, 100, 20)),
	},
	mummy_dog = {
		S("SK_mummy_dog_2", "Mummy Wrap", "shadow", "Shoots bandages that wrap the enemy up and pull it close.", "Atira faixas que embrulham o inimigo (fica preso) e puxam para perto.", C(240, 230, 205)),
		S("SK_mummy_dog_3", "Sandstorm Curse", "shadow", "A cursed sandstorm with scarabs: enemies take more damage.", "Tempestade de areia amaldiçoada com escaravelhos: os inimigos levam mais dano.", C(225, 195, 130)),
		S("SK_mummy_dog_4", "PHARAOH'S TOMB", "crown", "SUPREME: a golden sarcophagus traps the enemy and explodes in light.", "SUPREMO: um sarcófago dourado prende o inimigo, a areia cobre e explode em luz dourada.", C(255, 210, 80)),
	},
	shark_dog = {
		S("SK_shark_dog_2", "Fin Dive", "water", "Dives into the ground like water and bursts out biting.", "Mergulha no chão como se fosse água, só a barbatana aparece, e sai mordendo.", C(90, 160, 230)),
		S("SK_shark_dog_3", "Feeding Frenzy", "fang", "Circles the enemy with its fin, then bites from three sides.", "Nada em volta do inimigo com a barbatana e morde de 3 lados.", C(80, 150, 230)),
		S("SK_shark_dog_4", "MEGALODON", "crown", "SUPREME: a giant shark bursts from the ground and chomps everything.", "SUPREMO: um tubarão gigante sai do chão e abocanha tudo, com onda em volta.", C(70, 140, 220)),
	},
	alien_dog = {
		S("SK_alien_dog_2", "Tractor Beam", "target", "A UFO lifts the enemy up in its beam and drops it.", "Um disco voador puxa o inimigo para cima no raio e solta.", C(120, 255, 180)),
		S("SK_alien_dog_3", "Crop Circles", "star", "Glowing crop circles appear and blast up one after another.", "Círculos misteriosos brilham no chão e explodem para cima um atrás do outro.", C(150, 255, 200)),
		S("SK_alien_dog_4", "MOTHERSHIP", "crown", "SUPREME: the mothership arrives and fires a giant laser down.", "SUPREMO: a nave-mãe chega no céu e solta um laser gigante.", C(120, 255, 170)),
	},
	ninja_dog = {
		S("SK_ninja_dog_2", "Shuriken Fan", "sword", "Throws five spinning shurikens in a fan.", "Atira 5 shurikens girando em leque.", C(200, 205, 220)),
		S("SK_ninja_dog_3", "Shadow Clones", "shadow", "Three shadow clones attack from three sides and vanish in smoke.", "3 clones de sombra atacam de 3 lados e somem na fumaça.", C(110, 70, 170)),
		S("SK_ninja_dog_4", "THOUSAND SHADOWS", "crown", "SUPREME: vanishes and strikes from every direction, then a final X cut.", "SUPREMO: some e ataca de todos os lados, chuva de kunais e um corte em X no fim.", C(150, 90, 220)),
	},
	pirate_dog = {
		S("SK_pirate_dog_2", "Anchor Hook", "water", "Throws its anchor, hooks the enemy and pulls it in.", "Joga a âncora, engancha o inimigo e puxa para perto.", C(160, 170, 185)),
		S("SK_pirate_dog_3", "Cannon Barrage", "water", "Cannonballs fly in from the sea around the enemy.", "Balas de canhão chegam do mar em volta do inimigo.", C(90, 90, 100)),
		S("SK_pirate_dog_4", "GHOST SHIP", "crown", "SUPREME: a ghost ship sails through, fires a broadside and a giant wave.", "SUPREMO: um navio pirata fantasma passa atirando todos os canhões e solta uma onda gigante.", C(90, 200, 220)),
	},
	scorpion_dog = {
		S("SK_scorpion_dog_2", "Stinger", "poison", "Strikes with its tail stinger and poisons.", "Ferroada com o rabo de escorpião que envenena.", C(160, 240, 80)),
		S("SK_scorpion_dog_3", "Toxic Sands", "poison", "A sand pit opens under the enemy, pulling it in and poisoning.", "Abre um buraco de areia que puxa o inimigo e envenena.", C(225, 195, 130)),
		S("SK_scorpion_dog_4", "DESERT KING", "crown", "SUPREME: a giant scorpion tail rises from the sand and stabs three times.", "SUPREMO: um rabo de escorpião gigante sai da areia e ferroa 3 vezes.", C(150, 230, 70)),
	},
	flytrap_dog = {
		S("SK_flytrap_dog_2", "Snap Trap", "leaf", "A flytrap pops out under the enemy and snaps it shut.", "Uma planta carnívora brota embaixo do inimigo e fecha nele (fica preso).", C(110, 210, 80)),
		S("SK_flytrap_dog_3", "Vine Whip", "leaf", "Vines burst out and whip everything around four times.", "Vinhas saem do chão e chicoteiam tudo em volta 4 vezes.", C(90, 190, 70)),
		S("SK_flytrap_dog_4", "JUNGLE DEVOUR", "crown", "SUPREME: a giant flytrap swallows the enemy and the jungle grows around.", "SUPREMO: uma planta carnívora gigante engole o inimigo e a selva cresce em volta.", C(100, 220, 80)),
	},
	dj_dog = {
		S("SK_dj_dog_2", "Bass Drop", "wind", "Speakers drop in and pump three bass waves.", "Caixas de som aparecem e soltam 3 ondas de grave que empurram.", C(255, 120, 220)),
		S("SK_dj_dog_3", "Disco Fever", "star", "A disco ball and dance floor: enemies can't stop dancing!", "Globo de discoteca e pista de dança: os inimigos não param de dançar!", C(200, 120, 255)),
		S("SK_dj_dog_4", "THUNDER RAVE", "crown", "SUPREME: a stage of speakers, lightning on every beat and a huge drop.", "SUPREMO: palco de caixas de som, raios em cada batida e uma explosão de confete no fim.", C(255, 100, 230)),
	},
	knight_dog = {
		S("SK_knight_dog_2", "Shield Bash", "shield", "Raises its shield and bashes the enemy, stunning it.", "Levanta o escudo e dá uma escudada que atordoa.", C(150, 180, 255)),
		S("SK_knight_dog_3", "Holy Lance", "sword", "Charges with a glowing lance and plants a pillar of light.", "Investe com uma lança brilhante e finca uma coluna de luz.", C(255, 230, 140)),
		S("SK_knight_dog_4", "EXCALIBUR", "crown", "SUPREME: a giant golden sword falls from the sky. Heals the knight.", "SUPREMO: uma espada dourada gigante cai do céu no inimigo; cura o cavaleiro.", C(255, 215, 90)),
	},
	armadillo_dog = {
		S("SK_armadillo_dog_2", "Rolling Ball", "boulder", "Curls into a ball and rolls into the enemy.", "Vira uma bola e rola no inimigo.", C(190, 160, 130)),
		S("SK_armadillo_dog_3", "Pinball", "boulder", "Bounces around the enemy like a pinball, four hits.", "Quica em volta do inimigo como fliperama (4 batidas).", C(200, 170, 140)),
		S("SK_armadillo_dog_4", "BOULDER AVALANCHE", "crown", "SUPREME: becomes a giant boulder and crushes a huge circle around.", "SUPREMO: vira uma pedra gigante e esmaga tudo dando uma volta enorme.", C(170, 150, 130)),
	},
	saber_dog = {
		S("SK_saber_dog_2", "Saber Maul", "fang", "Pounces and slashes with its saber fangs, making the enemy bleed.", "Dá o bote e corta com os dentes de sabre; o inimigo sangra.", C(230, 60, 70)),
		S("SK_saber_dog_3", "Ice Age Roar", "ice", "A freezing roar that turns enemies into ice.", "Um rugido congelante que transforma o inimigo em gelo.", C(170, 225, 255)),
		S("SK_saber_dog_4", "EXTINCTION", "crown", "SUPREME: glaciers rise and a giant sabertooth spirit leaps through.", "SUPREMO: geleiras sobem e um espírito gigante de dente-de-sabre atravessa tudo.", C(180, 230, 255)),
	},

	------------------------------------------------------------ LENDÁRIOS
	dragon_hound = {
		S("SK_dragon_hound_2", "Dragon Breath", "fire", "Takes a deep breath and sweeps a flamethrower.", "Puxa o ar e solta um lança-chamas varrendo.", C(255, 130, 40)),
		S("SK_dragon_hound_3", "Blazing Wings", "wing", "Flies up and dives through the enemy, leaving a trail of fire.", "Voa e mergulha atravessando o inimigo, deixando um rastro de fogo.", C(255, 120, 30)),
		S("SK_dragon_hound_4", "DRAGON'S FURY", "crown", "SUPREME: soars high, rains giant fireballs and breathes fire from the sky.", "SUPREMO: sobe ao céu, faz chover bolas de fogo gigantes e sopra fogo lá de cima.", C(255, 110, 20)),
	},
	twin_fang = {
		S("SK_twin_fang_2", "Double Assault", "fang", "The dark and light heads take turns biting; the last bite is critical.", "As 2 cabeças (sombra e luz) mordem alternando; a última é crítica.", C(200, 140, 255)),
		S("SK_twin_fang_3", "Eclipse", "shadow", "A light orb and a dark orb orbit, then crash together over the enemy.", "Uma bola de luz e uma de sombra giram e se chocam em cima do inimigo.", C(230, 200, 255)),
		S("SK_twin_fang_4", "TWILIGHT JUDGMENT", "crown", "SUPREME: pillars of light and shadow fall in turns, then a total eclipse.", "SUPREMO: colunas de luz e sombra caem alternadas e no fim um eclipse total; cura.", C(220, 180, 255)),
	},
	velocity_hound = {
		S("SK_velocity_hound_2", "Sonic Rush", "wind", "Breaks the sound barrier dashing through the enemy.", "Quebra a barreira do som atravessando o inimigo.", C(150, 230, 255)),
		S("SK_velocity_hound_3", "Storm Rush", "bolt", "Five zigzag dashes leave lightning that explodes.", "5 arrancadas em zigue-zague deixam raios que explodem.", C(255, 235, 90)),
		S("SK_velocity_hound_4", "LIGHTSPEED", "crown", "SUPREME: runs circles so fast a lightning tornado forms, then a hyper dash.", "SUPREMO: corre em círculos tão rápido que forma um tornado de raios e termina com uma hiper arrancada.", C(255, 240, 120)),
	},
	storm_wolf = {
		S("SK_storm_wolf_2", "Thunder Fang", "bolt", "An electric bite that chains lightning to nearby enemies.", "Mordida elétrica e o raio pula para os inimigos perto.", C(255, 235, 90)),
		S("SK_storm_wolf_3", "Howling Tempest", "wind", "Howls up a cyclone with lightning around the enemy.", "Uiva e cria um ciclone com raios em volta do inimigo.", C(200, 230, 255)),
		S("SK_storm_wolf_4", "WOLF PACK STORM", "crown", "SUPREME: a storm brings four lightning wolves that hunt the enemies.", "SUPREMO: uma tempestade traz 4 lobos de raio que caçam os inimigos.", C(255, 240, 120)),
	},
	inferno_hound = {
		S("SK_inferno_hound_2", "Inferno Ring", "fire", "A ring of fire bursts out around it and burns.", "Um anel de fogo sai em volta dele e queima.", C(255, 120, 30)),
		S("SK_inferno_hound_3", "Hellfire Pillars", "fire", "Five pillars of fire erupt toward the enemy.", "5 colunas de fogo estouram em fila até o inimigo.", C(255, 100, 20)),
		S("SK_inferno_hound_4", "INFERNO APOCALYPSE", "crown", "SUPREME: the ground turns to lava and a fire tornado rages.", "SUPREMO: o chão vira lava e um tornado de fogo aparece no inimigo.", C(255, 90, 20)),
	},
	shadow_doberman = {
		S("SK_shadow_doberman_2", "Shadow Step", "shadow", "Melts into a shadow, slides under the enemy and bursts out biting.", "Vira sombra, desliza até embaixo do inimigo e sai mordendo para cima.", C(120, 60, 190)),
		S("SK_shadow_doberman_3", "Nightmare Clones", "shadow", "Four nightmare clones rush in from all sides and explode.", "4 clones de pesadelo correm de todos os lados e explodem.", C(130, 70, 200)),
		S("SK_shadow_doberman_4", "ETERNAL NIGHT", "crown", "SUPREME: total darkness and bites from everywhere, then a critical strike.", "SUPREMO: escuridão total, mordidas de todos os lados e um golpe crítico no fim.", C(140, 80, 220)),
	},
	celestial_dog = {
		S("SK_celestial_dog_2", "Star Shower", "star", "A shower of falling stars on the enemy.", "Uma chuva de estrelas cadentes no inimigo.", C(255, 240, 150)),
		S("SK_celestial_dog_3", "Heaven's Wings", "wing", "Its wings glow and rain holy feathers; heals.", "As asas brilham e fazem chover penas sagradas; cura.", C(255, 245, 200)),
		S("SK_celestial_dog_4", "CONSTELLATION", "crown", "SUPREME: draws a constellation in the sky that comes alive and pounces.", "SUPREMO: desenha uma constelação no céu que ganha vida e pula no inimigo.", C(200, 220, 255)),
	},
	astronaut_dog = {
		S("SK_astronaut_dog_2", "Rocket Barrage", "fire", "Fires four little rockets.", "Dispara 4 foguetinhos.", C(255, 150, 60)),
		S("SK_astronaut_dog_3", "Zero Gravity", "star", "Gravity turns off: enemies float up... and crash down.", "A gravidade desliga: os inimigos flutuam... e caem com tudo.", C(180, 160, 255)),
		S("SK_astronaut_dog_4", "SUPERNOVA LAUNCH", "crown", "SUPREME: blasts off on a rocket and crashes down in a supernova.", "SUPREMO: decola num foguete e cai como uma supernova.", C(255, 200, 80)),
	},
	yeti_dog = {
		S("SK_yeti_dog_2", "Avalanche Toss", "ice", "Lifts a huge snow boulder and throws it.", "Levanta uma bola de neve gigante e arremessa.", C(230, 245, 255)),
		S("SK_yeti_dog_3", "Glacier Quake", "ice", "Stomps and ice shards erupt in a cross.", "Pisa e lascas de gelo e pedra estouram em cruz.", C(180, 225, 255)),
		S("SK_yeti_dog_4", "ABOMINABLE BLIZZARD", "crown", "SUPREME: a roaring blizzard and giant ice fists slam from the sky.", "SUPREMO: nevasca rugindo e punhos de gelo gigantes caem do céu.", C(200, 235, 255)),
	},
	werewolf_dog = {
		S("SK_werewolf_dog_2", "Lunar Fury", "fang", "A frenzy of five claw slashes.", "5 garradas seguidas em fúria.", C(200, 90, 255)),
		S("SK_werewolf_dog_3", "Moon Howl", "shadow", "A full moon rises; its howl makes it stronger and scares enemies.", "Aparece a lua cheia; o uivo deixa ele mais forte e assusta os inimigos.", C(230, 230, 255)),
		S("SK_werewolf_dog_4", "BLOOD MOON", "crown", "SUPREME: a blood moon rises and three giant claw slashes rip the ground.", "SUPREMO: lua de sangue e 3 garradas gigantes rasgam o chão.", C(255, 70, 80)),
	},
	octopus_dog = {
		S("SK_octopus_dog_2", "Ink Cloud", "shadow", "Sprays a cloud of ink that slows and hurts.", "Solta uma nuvem de tinta que deixa lento e machuca.", C(40, 30, 60)),
		S("SK_octopus_dog_3", "Tentacle Slam", "water", "Four tentacles burst from the ground and slam down.", "4 tentáculos saem do chão e batem.", C(170, 90, 200)),
		S("SK_octopus_dog_4", "ABYSSAL WHIRLPOOL", "crown", "SUPREME: a dark whirlpool pulls enemies into tentacles from the deep.", "SUPREMO: um redemoinho escuro puxa os inimigos para os tentáculos do fundo do mar.", C(90, 60, 180)),
	},
	tank_dog = {
		S("SK_tank_dog_2", "Tank Shell", "fire", "Fires a heavy cannon shell that explodes.", "Dispara um projétil de canhão que explode.", C(255, 150, 60)),
		S("SK_tank_dog_3", "Heavy Artillery", "target", "Six artillery shells rain on marked spots.", "6 bombas de artilharia caem nos pontos marcados.", C(255, 120, 40)),
		S("SK_tank_dog_4", "CARPET BOMB", "crown", "SUPREME: bomber planes fly over and drop a line of bombs.", "SUPREMO: aviões bombardeiros passam e soltam uma fila de bombas.", C(255, 130, 50)),
	},
	wizard_dog = {
		S("SK_wizard_dog_2", "Arcane Orbs", "star", "Three orbs of fire, ice and lightning orbit and fire at the enemy.", "3 orbes (fogo, gelo e raio) giram em volta e são lançados (queima, deixa lento e dá choque).", C(200, 140, 255)),
		S("SK_wizard_dog_3", "Elemental Trinity", "star", "Pillars of fire, ice and lightning surround the enemy and merge.", "Colunas de fogo, gelo e raio cercam o inimigo e se juntam numa explosão.", C(220, 160, 255)),
		S("SK_wizard_dog_4", "GRAND SPELLBOOK", "crown", "SUPREME: a giant magic circle casts meteors, blizzard and lightning at once.", "SUPREMO: um círculo mágico gigante solta meteoros, nevasca e raios juntos.", C(190, 130, 255)),
	},

	------------------------------------------------------------ MÍTICOS (golpe próprio refeito na setinha; 3 e 4 de cinema)
	shadow_cerberus = {
		S("SK_shadow_cerberus_2", "Hell Gate", "shadow", "A hell portal opens where you aim: three spectral heads bite and shadow spikes launch enemies.", "Um portal do inferno abre na setinha: 3 cabeças espectrais mordem e espinhos de sombra jogam os inimigos para cima.", C(255, 50, 90)),
		S("SK_shadow_cerberus_3", "Triple Inferno", "fire", "The three heads breathe shadow fire in three directions, spinning.", "As 3 cabeças soltam fogo de sombra em 3 direções girando; queima.", C(255, 80, 60)),
		S("SK_shadow_cerberus_4", "HELLHOUND PACK", "crown", "SUPREME: the sky burns red and three hellhounds hunt the enemies down.", "SUPREMO: o céu fica vermelho e 3 cães do inferno caçam os inimigos e explodem.", C(255, 70, 50)),
	},
	titan_mastiff = {
		S("SK_titan_mastiff_2", "Titan Rage", "boulder", "Roars and becomes a TITAN for a few seconds (bigger, stronger, every bite quakes); golden cracks race to where you aim.", "Urra e vira TITÃ por alguns segundos (cresce, bate mais forte, cada mordida treme o chão); rachaduras douradas correm até a setinha.", C(255, 210, 120)),
		S("SK_titan_mastiff_3", "Titan Stomp", "boulder", "Leaps and lands on all fours: golden cracks race forward and launch enemies.", "Pula e cai com as 4 patas: rachaduras douradas correm para a frente jogando os inimigos para cima.", C(255, 210, 110)),
		S("SK_titan_mastiff_4", "TITAN'S JUDGMENT", "crown", "SUPREME: golden pillars surround the enemy and a giant fist smashes down.", "SUPREMO: colunas douradas cercam o inimigo e um punho gigante cai do céu.", C(255, 200, 80)),
	},
	cosmic_dog = {
		S("SK_cosmic_dog_2", "Starfall", "star", "Floats glowing and a shower of comets crashes where you aim.", "Flutua brilhando e uma chuva de cometas cai na setinha (3 no centro).", C(255, 240, 160)),
		S("SK_cosmic_dog_3", "Constellation Trap", "star", "Five stars surround the enemy, link up with light and explode.", "5 estrelas cercam o inimigo, se ligam com linhas de luz e explodem.", C(200, 170, 255)),
		S("SK_cosmic_dog_4", "BIG BANG", "crown", "SUPREME: rises into the sky, everything goes dark... and explodes into a galaxy.", "SUPREMO: sobe ao céu, tudo escurece... e explode numa galáxia.", C(190, 150, 255)),
	},
	phoenix_hound = {
		S("SK_phoenix_hound_2", "Phoenix Dive", "fire", "Wings ablaze, dives toward where you aim and explodes, leaving burning ground.", "Asas em chamas, mergulha na direção da setinha e explode; o chão fica pegando fogo.", C(255, 130, 30)),
		S("SK_phoenix_hound_3", "Firestorm Dive", "fire", "Circles high above the enemy and dives like a meteor, leaving the ground ablaze.", "Voa em círculo acima do inimigo e mergulha como meteoro; o chão fica pegando fogo.", C(255, 130, 30)),
		S("SK_phoenix_hound_4", "PHOENIX SKYFALL", "crown", "SUPREME: a giant fire phoenix sweeps the sky and burning feathers rain down.", "SUPREMO: uma fênix de fogo gigante cruza o céu e penas de fogo caem; cura.", C(255, 150, 40)),
	},
	void_beast = {
		S("SK_void_beast_2", "Void Rift", "shadow", "A black hole opens where you aim, pulls everyone in and implodes.", "Um buraco negro abre na setinha, puxa todo mundo para o centro e implode.", C(170, 90, 255)),
		S("SK_void_beast_3", "Third Eye Beam", "shadow", "Its third eye charges and fires a void beam that pierces and slows.", "O 3º olho carrega e solta um raio do vazio que atravessa e deixa lento.", C(170, 90, 255)),
		S("SK_void_beast_4", "ABYSS MAW", "crown", "SUPREME: a giant void mouth opens under the enemies and chomps shut.", "SUPREMO: uma boca gigante do vazio abre embaixo dos inimigos e fecha mordendo.", C(150, 60, 240)),
	},
	hydra_hound = {
		S("SK_hydra_hound_2", "Hydra Frenzy", "poison", "The five heads stretch like snakes and bite from five sides. Every bite that lands heals.", "As 5 cabeças esticam como cobras e mordem a setinha de 5 lados; cada mordida que acerta cura.", C(150, 255, 120)),
		S("SK_hydra_hound_3", "Venom Tide", "poison", "A wave of poisoned water crashes over the enemies.", "Uma onda de água envenenada passa por cima dos inimigos.", C(110, 220, 120)),
		S("SK_hydra_hound_4", "HYDRA RISING", "crown", "SUPREME: five giant serpent heads rise from the ground and strike. Heals.", "SUPREMO: 5 cabeças de serpente gigantes saem do chão e atacam; cura.", C(100, 230, 110)),
	},
	bone_dragon = {
		S("SK_bone_dragon_2", "Bone Cage", "bone", "Falls apart into bones that rebuild where you aim as a rib cage that traps and crushes.", "Desmonta em ossos que remontam na setinha como uma gaiola de costelas que prende e esmaga.", C(90, 255, 200)),
		S("SK_bone_dragon_3", "Ghost Fire Breath", "fire", "Breathes ghost fire that curses enemies to take more damage.", "Sopra fogo fantasma que amaldiçoa (o inimigo leva mais dano).", C(90, 255, 220)),
		S("SK_bone_dragon_4", "GRAVEYARD RISING", "crown", "SUPREME: the ground turns into a graveyard and skeleton dogs rise to attack.", "SUPREMO: o chão vira cemitério e cães esqueletos saem da terra para atacar.", C(110, 255, 210)),
	},
	kraken_hound = {
		S("SK_kraken_hound_2", "Kraken Grab", "water", "Giant tentacles burst where you aim, lift enemies up and smash them down. Ends in a blast of ink.", "Tentáculos gigantes saem na setinha, levantam os inimigos e esmagam no chão; termina com tinta.", C(255, 120, 200)),
		S("SK_kraken_hound_3", "Whirlpool", "water", "A whirlpool pulls enemies in while tentacles slap them.", "Um redemoinho puxa os inimigos enquanto tentáculos batem.", C(70, 140, 230)),
		S("SK_kraken_hound_4", "RELEASE THE KRAKEN", "crown", "SUPREME: eight giant tentacles rise and slam, then a tidal wave.", "SUPREMO: 8 tentáculos gigantes saem e batem um por um, depois uma onda gigante.", C(80, 130, 230)),
	},
	chrono_hound = {
		S("SK_chrono_hound_2", "Time Stop", "bolt", "A giant clock stops time where you aim. Its echoes slash from every side and it all explodes when time resumes.", "Um relógio gigante para o tempo na setinha; imagens dele cortam de 5 lados e tudo explode quando o tempo volta.", C(150, 210, 255)),
		S("SK_chrono_hound_3", "Rewind Strike", "bolt", "Strikes, rewinds time and strikes again from the same spot, three times.", "Ataca, volta no tempo e ataca de novo do mesmo lugar, 3 vezes; deixa lento.", C(255, 235, 150)),
		S("SK_chrono_hound_4", "JUDGMENT HOUR", "crown", "SUPREME: a giant clock strikes six; each strike is a bolt of holy lightning.", "SUPREMO: um relógio gigante bate 6 horas; cada badalada é um raio sagrado.", C(255, 230, 120)),
	},
	singularity_pup = {
		S("SK_singularity_pup_2", "Event Horizon", "shadow", "A black hole forms where you aim, grinds enemies in orbit and spits them far away through a white hole.", "Um buraco negro nasce na setinha, tritura em órbita e cospe longe num buraco branco.", C(255, 160, 70)),
		S("SK_singularity_pup_3", "Gravity Crush", "shadow", "Lifts the enemies into the air and crushes them into the ground.", "Levanta os inimigos no ar e esmaga no chão.", C(150, 90, 230)),
		S("SK_singularity_pup_4", "SUPERMASSIVE", "crown", "SUPREME: a supermassive black hole pulls everything in and bursts in white light.", "SUPREMO: um buraco negro gigante puxa tudo e explode em luz branca.", C(170, 110, 255)),
	},
	seraph_hound = {
		S("SK_seraph_hound_2", "Divine Judgement", "wing", "Spreads its six wings: pillars of light surround where you aim and close into a holy column. Heals a little.", "Abre as 6 asas: colunas de luz cercam a setinha e fecham numa coluna sagrada; cura um pouco.", C(255, 225, 120)),
		S("SK_seraph_hound_3", "Feather Storm", "wing", "Its six wings unleash a storm of razor-sharp golden feathers.", "As 6 asas soltam uma tempestade de penas douradas cortantes.", C(255, 230, 150)),
		S("SK_seraph_hound_4", "HEAVEN'S GATE", "crown", "SUPREME: the gates of heaven open and holy spears rain down. Heals.", "SUPREMO: o portão do céu abre e lanças sagradas caem; cura.", C(255, 240, 180)),
	},
	crystal_golem = {
		S("SK_crystal_golem_2", "Crystal Prison", "ice", "Crystal spikes race to where you aim and trap enemies in a giant crystal, then a huge crystal shatters it.", "Espinhos de cristal correm até a setinha e prendem num cristal gigante; um cristal enorme cai e estilhaça a prisão.", C(80, 245, 225)),
		S("SK_crystal_golem_3", "Shard Quake", "ice", "Punches the ground and a wave of crystal spikes races to the enemy.", "Soca o chão e uma onda de espinhos de cristal corre até o inimigo.", C(170, 220, 255)),
		S("SK_crystal_golem_4", "DIAMOND FORTRESS", "crown", "SUPREME: giant crystals rise around it as a shield, then explode outward.", "SUPREMO: cristais gigantes sobem em volta como escudo e depois explodem para fora.", C(200, 235, 255)),
	},
	frost_phoenix = {
		S("SK_frost_phoenix_2", "Glacial Rebirth", "ice", "Becomes an ice egg and heals; it cracks into a freezing storm and a volley of ice feathers flies where you aim.", "Vira um ovo de gelo e se cura; o ovo racha numa tempestade que congela e penas de gelo voam até a setinha.", C(170, 225, 255)),
		S("SK_frost_phoenix_3", "Blizzard Wings", "ice", "Flaps its wings into a freezing blizzard.", "Bate as asas e solta uma nevasca que congela.", C(170, 225, 255)),
		S("SK_frost_phoenix_4", "FROZEN SKY", "crown", "SUPREME: a giant ice phoenix crosses the frozen sky and icicles rain down.", "SUPREMO: uma fênix de gelo gigante cruza o céu congelado e caem pingentes.", C(190, 235, 255)),
	},
	thunder_colossus = {
		S("SK_thunder_colossus_2", "Thunder Wall", "bolt", "Three stomps: each sends a wall of lightning marching to where you aim. The last one shocks.", "3 pisadas: cada uma solta um muro de raios que marcha até a setinha; o último dá choque.", C(255, 230, 80)),
		S("SK_thunder_colossus_3", "Storm Fist", "bolt", "A giant fist of lightning falls from the sky on the enemy.", "Um punho gigante de raio cai do céu no inimigo; dá choque.", C(255, 235, 90)),
		S("SK_thunder_colossus_4", "STORM TITAN", "crown", "SUPREME: lightning strikes everywhere for three seconds while the ground shakes.", "SUPREMO: raios caem por toda parte por 3 segundos e o chão treme.", C(255, 240, 110)),
	},
	rainbow_unicorn = {
		S("SK_rainbow_unicorn_2", "Rainbow Bridge", "star", "A rainbow forms toward where you aim; it gallops across and lands horn-first in a burst of color.", "Um arco-íris nasce até a setinha; galopa por cima e cai com o chifre numa explosão de cores.", C(255, 160, 230)),
		S("SK_rainbow_unicorn_3", "Prism Burst", "star", "Fires three rainbow beams in a fan.", "Solta 3 raios de arco-íris em leque.", C(255, 200, 255)),
		S("SK_rainbow_unicorn_4", "RAINBOW DELUGE", "crown", "SUPREME: a rainbow sky and a downpour of colorful stars. Heals.", "SUPREMO: céu de arco-íris e chuva de estrelas coloridas; cura.", C(255, 180, 240)),
	},
	demon_samurai = {
		S("SK_demon_samurai_2", "Oni Blades", "sword", "The four katanas fly out, spin around where you aim slicing, then return for a final X slash.", "As 4 katanas voam, giram cortando na setinha e voltam num corte final em X.", C(255, 60, 60)),
		S("SK_demon_samurai_3", "Demon Dash", "sword", "Three slashing dashes leave burning cuts that explode.", "3 arrancadas cortando deixam cortes de fogo que explodem.", C(255, 90, 50)),
		S("SK_demon_samurai_4", "BLAZING TEMPEST", "crown", "SUPREME: an Oni mask in the sky, a fire tornado and spinning blades.", "SUPREMO: uma máscara de Oni no céu, um tornado de fogo e espadas girando no inimigo.", C(255, 80, 40)),
	},
	mecha_hound = {
		S("SK_mecha_hound_2", "Missile Barrage", "target", "Locks onto where you aim and fires a barrage of missiles, then a plasma cannon blast.", "Trava a mira na setinha e dispara mísseis; termina com o canhão de plasma.", C(255, 160, 60)),
		S("SK_mecha_hound_3", "Photon Cannon", "target", "Charges its chest cannon and fires a massive photon beam.", "Carrega o canhão do peito e solta um raio de fótons enorme.", C(120, 230, 255)),
		S("SK_mecha_hound_4", "OMEGA PROTOCOL", "crown", "SUPREME: targets locked — orbital lasers strike from space.", "SUPREMO: miras travam nos inimigos e lasers caem do espaço.", C(110, 220, 255)),
	},
	planet_hound = {
		S("SK_planet_hound_2", "Moonfall", "boulder", "The moon leaves orbit and crashes where you aim; its rings become a shockwave.", "A lua sai da órbita e cai na setinha; os anéis viram uma onda de choque.", C(230, 220, 200)),
		S("SK_planet_hound_3", "World Bloom", "leaf", "Flowers bloom, water geysers burst and vines hold the enemies.", "Flores brotam, gêiseres de água estouram e vinhas prendem os inimigos.", C(110, 220, 120)),
		S("SK_planet_hound_4", "LIVING PLANET", "crown", "SUPREME: a whole planet falls from the sky, oceans and jungles follow.", "SUPREMO: um planeta inteiro cai do céu; depois vem o oceano e a selva.", C(90, 200, 255)),
	},

	------------------------------------------------------------ ☀️ DIVINO
	-- 🎃 HALLOWEEN (os 2 clones soltam a mesma habilidade junto: Services/CloneService)
	clown_dog = {
		S("SK_clown_dog_2", "Pie Prank", "star", "Throws 3 cream pies toward where you aim. SPLAT! Enemies hit are slowed. Your clones throw too!", "Joga 3 tortas de creme na direção da setinha (SPLAT!); quem leva fica lento. Os clones jogam junto.", C(255, 248, 235)),
		S("SK_clown_dog_3", "Jack-in-the-Box", "shadow", "A jack-in-the-box pops up where you aim: BOING! The spring clown launches enemies up and makes them dizzy.", "Uma caixa-surpresa sobe na setinha: BOING! O palhaço de mola joga todo mundo para cima e deixa tonto.", C(255, 135, 30)),
		S("SK_clown_dog_4", "Circus of Doom", "crown", "SUPREME: a haunted circus tent drops where you aim, pumpkins rain, clown heads fly out and it ends in a confetti blast.", "SUPREMO: uma tenda de circo assombrada cai na setinha, chovem abóboras, cabeças de palhaço voam e tudo explode em confete.", C(255, 120, 20)),
	},
	-- 🎟️ AURORA PUP (exclusivo do Passe de Temporada 1): os poderes da fênix de gelo com nome de aurora
	-- (SpecialsPacks/Skills_Season.lua: cada SK_aurora_pup_* roda o SK_frost_phoenix_* do mesmo número)
	aurora_pup = {
		S("SK_aurora_pup_2", "Aurora Rebirth", "ice", "Wraps itself in aurora light and heals; the light bursts into a freezing storm and glowing feathers fly where you aim.", "Se enrola na luz da aurora e se cura; a luz explode numa tempestade que congela e penas brilhantes voam até a setinha.", C(140, 255, 225)),
		S("SK_aurora_pup_3", "Northern Wings", "ice", "Flaps its aurora wings into a freezing blizzard.", "Bate as asas de aurora e solta uma nevasca que congela.", C(150, 200, 255)),
		S("SK_aurora_pup_4", "AURORA SKY", "crown", "SUPREME: a giant aurora phoenix crosses the frozen sky and icicles rain down.", "SUPREMO: uma fênix de aurora gigante cruza o céu congelado e caem pingentes.", C(255, 150, 225)),
	},
	sun_dragon = {
		S("SK_sun_dragon_2", "Sunfire Breath", "fire", "A sweeping beam of golden sunfire toward where you aim, then a small sun crashes there. Heals.", "Raio de fogo solar dourado varrendo na direção da setinha; um pequeno sol cai lá e explode; cura.", C(255, 200, 70)),
		S("SK_sun_dragon_3", "Solar Wings", "wing", "Wings ablaze, dives through the enemy and bursts in a solar flare. Heals.", "Asas em chamas, mergulha atravessando o inimigo e explode numa erupção solar; cura.", C(255, 200, 70)),
		S("SK_sun_dragon_4", "DIVINE SUNFIRE", "crown", "SUPREME: a sun descends from the sky, sweeps with solar rays and goes supernova.", "SUPREMO: um sol desce do céu, varre tudo com raios solares e explode em supernova; cura.", C(255, 190, 60)),
	},
}

-- lista de ids [habilidade 2, habilidade 3, supremo] de um cachorro (nil se não está no catálogo)
function Skills.For(speciesId)
	local list = Skills.BySpecies[speciesId]
	if not list then
		return nil
	end
	return { list[1] and list[1].Id, list[2] and list[2].Id, list[3] and list[3].Id }
end

return Skills
