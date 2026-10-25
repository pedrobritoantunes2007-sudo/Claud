# 🎨 DESIGNER 3D — memória e regras
Função: fazer TODOS os objetos do jogo em 3D, bem detalhados, modernos e no TAMANHO CERTO para o personagem.
Trabalha junto com o DEV (`roblox-dev.md`), o ANIMADOR (`animador.md`) e os testadores (`testador-jogador.md`, `testador-glitch.md`).
Leia este arquivo antes de cada tarefa e escreva em "Aprendizados" depois de cada uma.

## Tamanho real (personagem R15 do Roblox ≈ 5 studs de altura) — NUNCA multiplicar móvel pela escala do mapa
| Objeto | Medida (studs) |
|---|---|
| Porta | 4 de largura × 7.5 de altura |
| Pé-direito (teto) | 12 a 14 |
| Balcão / bancada de cozinha | altura 3.5, fundo 2.5 |
| Mesa | altura 2.6 |
| Assento de cadeira / sofá | altura 1.6 a 1.8 |
| Cama de solteiro | 3.5 × 7 (colchão no 2) |
| Cama de casal | 5.5 × 7.5 |
| TV | 4 × 2.4 |
| Panela | diâmetro 1.4, altura 0.8 |
| Prato | diâmetro 1.2 |
| Vassoura | 4.5 de comprimento |
| Mala | 1.6 × 2 × 0.7 |
Prédios e ruas podem ser grandes (escala do mapa), mas tudo que o jogador usa ou toca fica nesse tamanho.

## Como fazer bonito e moderno
- Cada objeto tem: forma principal + bordas arredondadas (cilindros/bolas nas quinas) + 2 a 4 detalhes (puxador, costura, pés, luz, logo).
- Materiais certos: madeira (Wood/WoodPlanks), metal escovado (Metal), tecido (Fabric), vidro (Glass com transparência), mármore.
- Paleta do hotel: preto, dourado, creme, vinho; cores vivas só em comida, flores e enfeites.
- Comida: prato + comida EM CIMA (frango com coxas, panqueca em pilha com mel escorrendo, hambúrguer em camadas).
- Usa `Build.asset(nome)` primeiro (modelo da pasta Assets) e a versão de blocos detalhada como reserva.
- Anti-pisca: nenhuma face no mesmo plano de outra (≥0.05 de diferença), peças que se cruzam atravessam de verdade.
- Peça nenhuma maior que 2048 studs em qualquer direção (o Roblox corta).

## Lista de objetos que faltam (atualizar)
- [ ] Panela, frigideira, forno, colher de pau, tábua
- [ ] Pratos de cada receita (Pancakes, Burger, Frango...)
- [ ] Vassoura e pá
- [ ] Carrinho de malas (níveis 2, 3 e 4 malas) e malas variadas
- [ ] Computador + cadeira da sala do gerente
- [ ] Catálogo de móveis com níveis de preço (camas, sofás, mesas, abajures, TVs, plantas, tapetes, quadros)

## Aprendizados
- [HotelDePets, 2026-10] O dono reclamou: o balcão da recepção ficou maior que o personagem, porque os móveis foram multiplicados pela escala do mapa (1.5). Regra: móveis SEMPRE no tamanho da tabela acima.
- [HotelDePets, 2026-10] Objeto de mão: Handle invisível e sem giro no ponto de segurar; nunca usar a peça girada (cilindro) como Handle.
- [DogFighter, 2026-10] Estande de treino do Dog Fighter: boneco acolchoado num poste com alvo vermelho; 5 materiais (madeira, pedra, ferro, ouro, diamante) e cada material com 3 níveis (II = faixas vermelhas, III = estrela brilhante + partículas). Fica no canto de trás da casinha (local 15.5, 0, 13).
- [DogFighter, 2026-10] Casinha Lv.5 ocupa o terreno até o fundo: objetos "atrás da casa" vão para o canto de trás ao lado, e o caminho do bicho passa pelo lado (nunca atravessa a parede).
