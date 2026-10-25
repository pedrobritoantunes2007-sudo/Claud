# Dog Fighter Simulator v2

Abra `DogFighterSimulator.rbxlx` no Roblox Studio e aperte Play.
Para o save funcionar no Studio: Game Settings > Security > Enable Studio Access to API Services.
Para usar com Rojo: `rojo serve` nesta pasta.

## Loop
Escolhe o cachorro → dá nome → casinha → come nas tigelas sozinho → XP → level → mais forte →
ovo a cada 3 min → cachorros melhores → Arena (NPC/PvP) → Cash → melhora casa/tigelas → Bosses.

## Onde mexer
| Quero mudar... | Arquivo |
|---|---|
| Preços, XP das tigelas, timer do ovo, raridades, recompensas | `src/shared/Config.lua` |
| Cachorros (aparência, stats, special), chances dos ovos, NPCs, bosses | `src/shared/DogData.lua` |
| Como o modelo 3D é montado (orelhas, caudas, asas, chifres...) | `src/shared/DogBuilder.lua` |
| Poderes especiais (sequência de ações) | `src/server/Services/Specials.lua` |
| IA de luta (perseguir, circular, recuar, dash) | `src/server/Services/CombatService.lua` |
| Mapa | `src/server/Services/MapBuilder.lua` |
| Casinha (5 níveis) e tigelas | `src/server/Services/HouseBuilder.lua` |
| Animações (andar, uivar, agachar, morder...) | `src/client/Animator.lua` |
| Efeitos (raio, fogo, gelo, clones, meteoros...) | `src/client/Effects.lua` |
| Telas | `src/client/UI/` |

## Notas
- Recompensa de comida do Season Pass: chame `DataService.GrantFoodXP(player, 1000)` no servidor.
  O XP vai direto para o cachorro equipado e aparece o popup "+1,000 XP! LV.8 → LV.9".
- O mapa é gerado por código. Para editar à mão: Play → copie `Workspace.Map` → Stop → cole no Workspace.
- Os cachorros são modelos procedurais (elipsoides + articulações). Para qualidade "de loja",
  o próximo passo é trocar as peças principais por MeshParts feitos no Blender, mantendo
  os nomes das articulações (Body, Neck1, Jaw1, LegFL...) para a animação continuar funcionando.
