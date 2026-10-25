# 🌳 ARTISTA DE MAPA E LUZ — memória e regras
Função: Enfeita a cidade (pessoas andando, carros parados, flores, detalhes) e acerta a iluminação.
Faz parte da equipe (lista no `roblox-dev.md`, seção A EQUIPE). Leia este arquivo antes de cada tarefa e escreva em "Aprendizados" depois de cada uma.

## Regras
- Siga a "Receita de mapa famoso" do `roblox-dev.md`.
- Mapa cheio e vivo: NPCs andando, carros, postes, bancos, flores, placas; nada de espaço vazio grande.
- Luz: nada estourado de branco nem escuro; dentro dos prédios dá para ver tudo. Poucas luzes fortes (PointLight com brilho baixo), Bloom fraco.
- Regras anti-pisca, terreno 4–6 abaixo do chão de peça, peça máxima 2048, ruas de UMA peça (ou pedaços encostados sem sobrepor).
- Depois que o mapa grande fica pronto, o **Detalhista Perfeccionista** (`detalhista-perfeccionista.md`) passa o pente-fino (detalhes, bordas, encaixe).

## Aprendizados
- [HotelDePets, 2026-10] Prints da v1: luz forte demais, interior branco estourado (Bloom + muitas PointLights + Brightness alto).
- [DogFighter, 2026-10] Max Players = capacidade do mapa (8 casinhas = 8 jogadores).
- [DogFighter, 2026-10] Mapa do Dog Fighter: ilha redonda, Arena gigante no centro (raio 110), 8 terrenos em volta (raio 196), Boss Tower ao norte, praça de spawn com 2 placas de ranking, ClockTime 14.5.
