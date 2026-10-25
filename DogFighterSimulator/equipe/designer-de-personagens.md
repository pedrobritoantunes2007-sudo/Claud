# 🧍 DESIGNER DE PERSONAGENS — memória e regras
Função: Cuida dos bonecos: hóspedes variados, ternos dos funcionários por nível, Mr. Goldman e pessoas da cidade.
Faz parte da equipe (lista no `roblox-dev.md`, seção A EQUIPE). Leia este arquivo antes de cada tarefa e escreva em "Aprendizados" depois de cada uma.

## Regras
- Bonecos de verdade (R15, estilo jogador do Roblox), nunca desenho 2D.
- Mr. Goldman: cartola preta com faixa dourada, terno preto, gravata vermelha, pele amarela clássica.
- Funcionários sempre de terno; o terno muda a cada nível (Trainee cinza, Pro preto com gravata, Expert azul-marinho com gravata-borboleta dourada, Master smoking branco e dourado).
- Hóspedes com roupas sorteadas por tipo (mochileiro, turista, família, executivo, celebridade, realeza).
- Roupas de catálogo precisam de IDs válidos; sem eles, usar cores do corpo + acessórios de peças.

## Aprendizados
- [DogFighter, 2026-10] Jogador vira bicho: modelo com Humanoid + HumanoidRootPart vira o `player.Character`; `CharacterAutoLoads = false`.
- [DogFighter, 2026-10] Scripts de "personagem novo" ignoram quando o novo personagem é o bicho; um guard no cliente põe a câmera sempre no personagem atual.
- [DogFighter, 2026-10] Bicho com asas fica no chão; espaço 2x (pular 2x no celular) liga/desliga o voo. Correr: Shift (sem Shift Lock), × 1,6; botão RUN no celular.
- [DogFighter, 2026-10] Os cães do Dog Fighter são modelos por código (DogBuilder, escala de mundo 1.4) com HumanoidRootPart; atributos no modelo: Species, Wings, GroundHip, HipHeight, Float, BaseSpeed.
- [DogFighter, 2026-10] Cão com asas: no chão HipHeight = GroundHip; voando = GroundHip + 6 (o atributo Float muda a pose no Animator).
