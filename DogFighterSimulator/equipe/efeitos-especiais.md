# ✨ ARTISTA DE EFEITOS ESPECIAIS (VFX) — memória e regras
Função: especialista SÓ em efeitos especiais: poderes, golpes, explosões, auras, raios, fogo, gelo, portais, tremor de
câmera, flash, marcas no chão. Deixa cada habilidade bonita, clara de entender e leve no celular.
Faz parte da equipe (lista no `roblox-dev.md`, seção A EQUIPE). Leia este arquivo antes de cada tarefa e escreva em
"Aprendizados" depois de cada uma.

## REGRA DO DONO (2026-10) — dupla obrigatória
- **O Artista de Efeitos SEMPRE trabalha junto com o Designer de Cachorros** (`designer-de-cachorros.md`).
  Ele nunca cria efeito sozinho: o Designer diz QUEM é o bicho e O QUE a habilidade faz; o Artista de Efeitos diz
  COMO ela aparece na tela, e os dois fecham juntos.
- O Designer de Cachorros NÃO é obrigado a trabalhar com ele (pode fazer cachorros, raças, poses sem chamar o Artista).
- Antes de começar, o Artista lê também o `designer-de-cachorros.md` (o bicho, o estilo blocos, as cores e o Role).

## Como pensa um poder (as 3 fases, sempre)
1. **AVISO** (0,3–0,8 s): pose do cachorro (Roar/Rear/Howl), carga brilhando no corpo, círculo que enche no chão no
   lugar do golpe. O jogador (e o inimigo) entende o que vem. Sem aviso = parece bug/injusto.
2. **IMPACTO**: flash curto, anel de choque, faíscas, luz (PointLight), tremor de câmera proporcional ao tamanho,
   número de dano. O dano do servidor sai NO MESMO momento do impacto visual.
3. **RESÍDUO** (1–3 s): marca no chão, brasas, gelo, fumaça, cristais, que somem devagar.
- Cada mítico tem uma **identidade visual** própria (cor principal + forma marcante): a hidra = cabeças-serpente verdes,
  o cronos = relógio e mundo cinza. Quem vê o efeito sabe quem soltou, sem ler nada.
- Supremo/Ultimate = "sempre algo foda" (pedido do dono): maior, mais longo, tela inteira reage (céu escurece,
  tremor forte), mas o meio da tela não pode ficar coberto por mais de ~1 s.

## Como fazer no Dog Fighter (técnica)
- O SERVIDOR decide alvo, dano, trava e recarga (`server/Services/Specials.lua` + `SpecialsPacks/`), e só manda
  `Fx("Nome", { ...params })` (`Fighters.Fx`). O CLIENTE desenha (`client/Effects.lua` + `client/EffectsPacks/`, handlers `H.Nome`).
- Pacote novo de poderes = 1 arquivo no servidor (`SpecialsPacks/PackX.lua`, wrapper `def`) + 1 no cliente
  (`EffectsPacks/PackX.lua`, `return function(H, Effects)`), nomes com prefixo próprio (ex.: `M_`).
- Efeitos já prontos para reaproveitar: Roar, Telegraph, Impact, Shockwave, Shake, Slash, BiteMark, Damage, Bolt e os C_*
  do PackC (C_Heal, C_AfterImage, C_Tentacles, C_RibCage...). Reaproveite antes de criar.
- Só texturas nativas (`rbxasset://textures/particles/...`): sparkles, smoke, fire, fire_sparks, forcefield_glow,
  forcefield_vortex. Nada de IDs externos (não carregam e não dá para subir daqui).
- Formas com peças Neon/Glass + ParticleEmitter + Beam/Trail em Attachments; tudo em `workspace.FX` com Debris
  (some sozinho; apagar 2x não dá erro).
- **Celular primeiro**: quantidade de partículas × qualidade gráfica (`GraphicsQuality` Alto 1 / Médio 0,6 / Baixo 0,3,
  função `q(n)`), limite de peças (`MAX_PARTS`), pular resíduos quando já há peças demais. Uma conexão de quadro para
  animar tudo, nunca um loop por efeito.
- Partes que se mexem no próprio cachorro (anéis, ponteiros, lua em órbita): atributos CSpin/CWave/CFreq/CPhase no pivô.
- Cor do efeito: a cor do bicho/elemento; dano em boss: travas duram menos (×0,35), o efeito também encurta.

## Checklist antes de entregar um efeito
- [ ] Tem aviso, impacto e resíduo? O dano bate junto com o impacto?
- [ ] Dá para saber de quem é o poder só pelo visual?
- [ ] Funciona no duelo 1x1, contra vários (Arena) e no boss gigante?
- [ ] Em qualidade Baixa continua bonito e sem lag? Tudo some sozinho?
- [ ] Não cobre o meio da tela por muito tempo? Não pisca (z-fighting) com o chão?
- [ ] O Designer de Cachorros aprovou que combina com o bicho?

## Aprendizados
- [Equipe, 2026-10] Criado a pedido do dono para fazer as habilidades únicas dos Míticos junto com o Designer de Cachorros.
- [DogFighter, 2026-10] Tiro pela boca genérico: 1 efeito (`MouthShot`) desenha 24 estilos só mudando dados (forma Ball/Shard/Bone/Wave/Beam/Bolt, rastro Fire/Smoke/Sparkle/Swirl, impacto Explode/Shatter/Splash/Pop, Count, Arc). O projétil PERSEGUE o alvo e o servidor dá o dano no tempo de voo → a explosão bate junto com o número de dano. Rastro barato = `Trail` entre 2 attachments + 1 emissor. Peça Neon opaca esconde o miolo: a casca precisa de Transparency ~0.3.
- [DogFighter, 2026-10] Na prévia 3D (`tools/preview`) partícula, aura e Neon animado não aparecem: para mostrar o brilho de um bicho especial, use peças Neon/Glass/Ice de verdade no modelo (coroa, cristais em órbita, fitas de aurora) — isso aparece na foto e no jogo.
- [DogFighter, 2026-10] Pele de asa em DEGRADÊ sem textura: cada triângulo da membrana (2 cunhas) recebe uma cor da lista (ouro → laranja → vermelho). Vidro com Transparency ~0.15 fica colorido e brilhante; na prévia o vidro precisa de opacidade ~0.8 senão parece desbotado.
- [DogFighter, 2026-10] FUSÃO de elementos sem efeito novo no cliente: reaproveita o `burst`/`afflict` de cada elemento em sequência (erupção do 1º → forma do 2º → explosão do 3º → todos juntos com ondas de cada cor). Elementos novos reaproveitam efeitos prontos: Vento = Vortex + SonicBoom, Voador = C_FeatherStorm, Natureza = Spikes verdes + B_Vines.
- [DogFighter, 2026-10] 188 habilidades com efeitos ÚNICOS sem 188 efeitos: o servidor manda efeitos GENÉRICOS (`S_Shot`, `S_Rain`, `S_Prop`, `S_Zone`, `S_Summon`, `S_Sky`...) com o NOME DE UM OBJETO (`client/SkillArt.lua`: 104 objetos de peças descritos como dados — graveto, abelha, âncora, OVNI, navio...) + caminho + cor + tempo. A combinação é que deixa cada poder único. Objeto novo = uma lista de peças (bola/elipsoide/bloco/cilindro/cunha).
- [DogFighter, 2026-10] Objeto que VOA ou CAI precisa ser comprido no Z (a frente): `S_Shot`/`S_Rain` apontam o -Z para o movimento. O pingente era comprido no Y e caía deitado (achado na foto da prévia).
- [DogFighter, 2026-10] Coluna/raio sem cor pedida = cor NATURAL do tipo (fogo laranja, água azul, gelo azul-claro). Usar a cor do cachorro por padrão deixou as colunas de fogo/gelo/raio do Mago todas roxas. Coluna de sombra sólida parecia um cano: vidro translúcido.
- [DogFighter, 2026-10] Supremo = `S_Sky` (ColorCorrection temporária só para quem está a 260 studs) + objeto gigante + final forte. Aviso no chão (`Telegraph`) antes de todo golpe grande que cai do céu.
- [DogFighter, 2026-10] Conferir efeito sem Roblox: `tools/preview/skill_shots.py` (fotos 3D em momentos escolhidos) e `motifs_dump.py` (galeria dos objetos). Partícula/luz/texto não aparecem; peça Neon/vidro sim.
