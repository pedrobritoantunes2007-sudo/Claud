> ⚠️ O jogo está em INGLÊS: os nomes e as descrições dos itens estão em **PASSES_COPIAR.md**.

# ⭐ Loja do Dog Fighter Simulator (loja nova, 2026-10-24)

**Você não precisa criar nada à mão:** o **PUBLICAR.bat** cria no site do Roblox os passes e produtos que ainda
não existem, troca o nome, a descrição, o preço e a imagem dos antigos e coloca os números dentro do jogo.

Tudo da loja fica em **um arquivo só**: `src/shared/Monetization.lua` (itens, preços, textos e os números em
`Monetization.IDS`). As imagens de cada item ficam em `Imagens/Loja/<Chave>.png`
(refaça com `python3 tools/preview/shop_images.py`).

## A loja no jogo

Botão **SHOP** (ou o **+** do dinheiro). Abas na esquerda:

- **FEATURED**: o Pacote Inicial (enquanto não comprou; depois o Sunfire Dragon) e os destaques.
- **PASSES**: os gamepasses (para sempre).
- **CASH**: pacotes de Cash. **Crescem com a melhor ilha aberta** (contam como missões da ilha), com um mínimo.
- **DOGS & SPINS**: giros da roleta, Ovo de Cristal, Mítico aleatório e o Sunfire Dragon (Divino).
- **BOOSTS**: turbinadas de 30 minutos (contam só com o jogador no jogo; comprar de novo soma mais tempo).
  Enquanto valem, aparece um chip pequeno com o tempo ao lado do SUPER BOSS.

## Itens

| Item | Tipo | Robux | O que faz |
|---|---|---|---|
| 🎁 STARTER PACK (`StarterPack`) | Produto | 49 | Cachorro RARO + $1,500 + 500 XP + 2 Ovos Azuis. 1 vez por conta |
| 👑 VIP (`VIP`) | Passe | 79 | Tag VIP + 10% de Cash e XP |
| 💵 2x Cash (`Cash2x`) | Passe | 99 | Dobro de Cash |
| ⭐ 2x XP (`XP2x`) | Passe | 99 | Dobro de XP |
| 🍀 Lucky Paw (`LuckyPaw`) — NOVO | Passe | 129 | Mais sorte em TODOS os ovos e nas capturas (+4 pontos de sorte) |
| 💨 Speedy Paws (`SpeedBoost`) — NOVO | Passe | 59 | Cachorro 20% mais rápido |
| 📜 Fast Missions (`FastEggs`) | Passe | 49 | Cada selvagem conta 2 nas missões (antigo "Fast Eggs") |
| 💖 Quick Revive (`QuickRevive`) — NOVO | Passe | 39 | Volta do desmaio em 2 s em vez de 5 |
| 🐣 Auto Hatch (`AutoHatch`) | Passe | 69 | Abre os ovos do inventário sozinho (liga/desliga na loja) |
| 🏠 Big Kennel (`ExtraNest`) — NOVO | Passe | 49 | +100 lugares no canil (antigo "Auto Collect", que não fazia mais nada) |
| 💰 Pouch of Cash (`CashSmall`) | Produto | 25 | 3 missões da melhor ilha (mínimo $750) |
| 💰 Bag of Cash (`CashMedium`) | Produto | 59 | 8 missões +10% (mínimo $2,500) |
| 🏦 Vault of Cash (`CashBig`) | Produto | 129 | 20 missões +20% (mínimo $7,000) |
| 🪙 Treasure of Cash (`CashHuge`) — NOVO | Produto | 299 | 50 missões +35% (mínimo $20,000) |
| 🍀 10 LUCKY Spins (`LuckySpins10`) | Produto | 149 | 10 giros de sorte na roleta |
| 🎰 10 Roulette Spins (`Spins10`) | Produto | 49 | 10 giros na roleta |
| 🐾 3 DIVINE Leashes (`LeashDivine3`) — NOVO | Produto | 59 | 3 coleiras divinas (4x chance de captura; só vendem aqui) |
| 🐾 10 Golden Leashes (`LeashGolden10`) — NOVO | Produto | 99 | 10 coleiras douradas (2.4x chance de captura) |
| 🔮 Crystal Egg (`SpecialEgg`) | Produto | 35 | 1 Ovo de Cristal |
| 🐶 Random Mythic Dog (`MythicDog`) | Produto | 100 | 1 Mítico aleatório |
| ☀️ Sunfire Dragon (`DivineDog`) | Produto | 399 | O único Divino |
| 💵 Cash Rush (`CashRush`) — NOVO | Produto | 39 | 2x Cash por 30 min (soma com o passe 2x Cash) |
| 🍀 Lucky Rush (`LuckRush`) — NOVO | Produto | 39 | Mais sorte nos ovos por 30 min (soma com o Lucky Paw) |

O preço **de verdade** é o do site: a loja lê o preço do site sozinha quando o item já existe.
Onde a lei proíbe itens pagos aleatórios (PolicyService), somem os giros, ovos, Mítico aleatório e a sorte.

## No Roblox Studio

Item sem número (`0`) mostra **TEST**: clique para simular a compra e conferir a recompensa (não gasta Robux).

## Como funciona por dentro (para quem mexe no código)

- `src/server/Services/MonetizationService.lua`
  - Gamepasses: `UserOwnsGamePassAsync` com `pcall` + cache, e `PromptGamePassPurchaseFinished`.
    Quem comprou fica gravado em `Purchases.Passes` no perfil; o jogador ganha o atributo `Pass_<Chave>`.
  - Developer Products: `ProcessReceipt` **idempotente** (cada `PurchaseId` vai para `Purchases.Receipts`).
  - Recompensa que não cabe agora (canil cheio) espera em `Purchases.Pending` e entra sozinha depois.
  - Turbinadas: atributo `Boost_Cash` / `Boost_Luck` (quando acaba) e `data.Boosts` (segundos que faltam).
  - Usado pelos outros serviços: `CashMult`, `XPMult`, `SpeedMult` (DogService), `ReviveMult` (DogService),
    `LuckBonus` (EggService → `DogData.RollSpecies`), `Owns(player, key)`, `IsVIP(player)`.
    O canil usa `Config.MaxDogs(player)`.
- `src/client/Systems/StoreMenu.lua` — a tela da loja (abas e cartões com ícones desenhados).
- Testes: `python3 tools/preview/store_test.py` (servidor) e `tools/preview/shop_test.luau` (regras).
