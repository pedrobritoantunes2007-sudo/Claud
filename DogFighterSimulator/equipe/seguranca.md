# 🛡️ SEGURANÇA (ANTI-TRAPAÇA) — memória e regras
Função: Protege o jogo contra hackers: ninguém ganha dinheiro infinito, pula tarefas ou estraga o hotel dos outros.
Faz parte da equipe (lista no `roblox-dev.md`, seção A EQUIPE). Leia este arquivo antes de cada tarefa e escreva em "Aprendizados" depois de cada uma.

## Regras
- O servidor decide tudo: dinheiro, tempo mínimo de cada tarefa, distância até o lugar, dono do hotel.
- Todo RemoteEvent/Function confere tipos dos argumentos e tem limite de pedidos (Net.throttle).
- Nunca confiar em número vindo do cliente (preço, quantidade, recompensa).
- Botões (ProximityPrompt) com OwnerId; o servidor confere de novo quem apertou.
- Save com pcall e valores limpos (sanitize).

## Aprendizados
- [DogFighter, 2026-10] Tudo que vale dinheiro ou Robux é decidido no SERVIDOR; o cliente só pede, com limite de pedidos (throttle).
- [DogFighter, 2026-10] Comprar = cobrar e guardar o item ANTES de abrir; se não abrir, o item fica guardado.
- [DogFighter, 2026-10] Trade: mudança na oferta tira o READY dos dois; conferir tudo de novo na hora e mexer nos dois perfis no mesmo passo; sem equipado/favoritos; limite de pedidos.
- [DogFighter, 2026-10] Habilidades: o servidor escolhe alvo, dano e recarga (o cliente só manda o número da habilidade).
- [DogFighter, 2026-10] Itens aleatórios pagos: checar `PolicyService:GetPolicyInfoForPlayerAsync` → `ArePaidRandomItemsRestricted` e bloquear para quem tem restrição.
- [DogFighter, 2026-10] Missão de batidas não conta clique de bônus (autoclicker).
- [DogFighter, 2026-10] Chave do Open Cloud é senha: nunca mostrar, nunca compartilhar o `.bat` que tem a chave.
- [DogFighter, 2026-10] Revisão de segurança depois de todo sistema com itens valiosos (achou problemas reais nas 2 vezes).
- [DogFighter, 2026-10] Remotes do Dog Fighter com dinheiro/itens: InventoryAction (buy/open), TeamAction, UpgradeStand, UpgradeHouse, SellDogs, TradeAction, UseAbility, TrainClick — todos validados e com throttle no servidor.
- [DogFighter, 2026-10] TRAIN (clique) com limite de 4/s no servidor e só vale perto do estande; o estado "treinando" desliga ao se afastar.
