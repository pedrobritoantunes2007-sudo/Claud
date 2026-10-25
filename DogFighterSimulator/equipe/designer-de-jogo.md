# 🧠 DESIGNER DE JOGO — memória e regras
Função: Cuida do ritmo e da economia: preços, quanto cada hóspede paga, quando cada coisa libera, para o jogo nunca ficar chato nem fácil demais. Inventa missões e metas.
Faz parte da equipe (lista no `roblox-dev.md`, seção A EQUIPE). Leia este arquivo antes de cada tarefa e escreva em "Aprendizados" depois de cada uma.

## Regras
- Siga a "Receita de JOGO famoso" do `roblox-dev.md` (objetivo principal + secundários + continuação).
- Sempre algo novo a cada 2–5 minutos no começo; metas maiores depois (horas, dias).
- Faça a CONTA de cada passo do tutorial: o dinheiro inicial + o que o tutorial paga tem que dar para o que ele pede comprar.
- Tabela de ritmo do roteiro (seção 12 do `ROTEIRO_COMPLETO.md`) é a meta; confira com contas (tempo por hóspede × ganho).
- Móvel mais caro = hóspede paga mais (estilo The Sims): cada móvel tem preço e "pontos de conforto/luxo".

## Aprendizados
- [HotelDePets, 2026-10] O tutorial pedia upgrade de 300 e o jogador só teria 289 → começo foi para 300 moedas.
- [DogFighter, 2026-10] Ciclo de simulador: ganhar → comprar ovo → bicho melhor → ganhar mais; várias fontes e vários gastos; sempre um próximo objetivo.
- [DogFighter, 2026-10] Rebirth: zera dinheiro e níveis, mantém a coleção, dá +50% de dinheiro para sempre.
- [DogFighter, 2026-10] Jogadores avançavam rápido demais → o XP necessário cresce mais depois do nível 15.
- [DogFighter, 2026-10] Botão de clique para bônus não conta em missões de batidas (autoclicker).
- [DogFighter, 2026-10] Vender raridades altas só nos repetidos, guardando o melhor de cada espécie; venda automática e venda rápida são qualidade de vida que o dono pediu.
- [DogFighter, 2026-10] Combate: 1 = ataque, 2 = poder especial, 3 = poder do tipo; PvP só quando os dois ligaram; sair da arena encerra a luta.
- [DogFighter, 2026-10] Números atuais do Dog Fighter na ficha (seção 5): ovos $100→$300k, estande 15 níveis (XP 4→60/batida), time 2→6 vagas, renda/min por raridade (6/15/40/110/300/900, +4% por nível).
- [DogFighter, 2026-10] O dono pediu para PLANEJAR o dinheiro antes de programar: mostrar onde se ganha e onde se gasta, com preços, e esperar aprovação.
- [DogFighter, 2026-10] Dinheiro precisa de MUITOS gastos (ovos, estande, vagas, casinha, petiscos, fundir, áreas, rebirth), senão vira número parado.
- [DogFighter, 2026-10] Habilidade 3: uma por TIPO (Role) para os comuns; os 19 Míticos têm 3 únicas (pedido do dono).
- [DogFighter, 2026-10] Vantagem de elemento estilo Pokémon: cada elemento forte contra 2 (com motivo fácil de entender: água apaga fogo, raio derruba quem voa), +30% / −20%, cães com vários elementos somam +1/−1 por par. Mostrar STRONG/WEAK no menu e "SUPER!" na luta ensina sem texto. Os números ficam no Config.
- [DogFighter, 2026-10] Item exclusivo de Robux (Divino): não aleatório (sem PolicyService), nunca sai de ovo, não pode ser solto/vendido (evita perda acidental de compra), preço ~4x o item aleatório da mesma faixa (Random Mythic 100 → Divino 399).
