# 🖥️ ESTUDO DE HUD — manual do Designer de Telas (especialista SÓ em HUD)
HUD = tudo que fica na tela o tempo todo (dinheiro, botões, objetivo, avisos). Telas que abrem e fecham (loja, check-in)
são "janelas" e seguem as mesmas regras de estilo, mas o HUD tem regras mais duras porque NUNCA sai da frente do jogo.
Leia isto inteiro antes de mexer em qualquer tela. Depois de cada trabalho, escreva o que aprendeu em `designer-de-telas.md`.

---------------------------------------------------------------------------------------------------
## 1. AS 10 LEIS DO HUD
1. **O jogo é o personagem principal.** O HUD ocupa no máximo **15–20% da tela**. O MEIO (60% central) fica livre,
   só popups rápidos podem passar por ali.
2. **Cantos e bordas.** Cada coisa mora num canto fixo e nunca muda de lugar (o jogador aprende onde olhar).
3. **Celular primeiro.** Mais da metade dos jogadores do Roblox joga no celular, deitado, com a tela pequena.
   Se funciona no celular, funciona no PC (o contrário não é verdade).
4. **Mostrar só o que importa AGORA** (revelação progressiva): listas fechadas por padrão, botões que só aparecem
   perto do lugar de usar, recursos travados escondidos ou bem discretos.
5. **Informação no MUNDO em vez de na tela** (interface "diegética"): balão em cima do hóspede, seta dourada no chão,
   placa na porta do quarto. Isso tira peso do HUD (é o que o Adopt Me faz com os balões de tarefa em cima do pet).
6. **Um destaque por vez.** Só o botão da próxima ação brilha/pulsa. Se tudo brilha, nada brilha.
7. **Ícone + número, pouco texto.** Texto longo só em janela, nunca no HUD. Objetivo = uma linha curta.
8. **Toque fácil.** Botão de toque com **no mínimo 44 × 44 px** (regra da Apple/Google), com espaço entre eles.
9. **Consistência.** Mesmo arredondamento, mesma borda, mesmo espaçamento (grade de 8 px), mesma fonte, mesmas cores.
10. **Vida (juice), sem exagero.** Número que muda dá um "pulinho", botão afunda ao tocar, aviso desliza.
    Animações curtas (0.15–0.3 s). Nada piscando o tempo todo.

---------------------------------------------------------------------------------------------------
## 2. O MAPA DA TELA (zonas proibidas e zonas boas)
```
┌──────────────────────────────────────────────────────────────┐
│ [Roblox: menu/chat]  [menu do jogo]   ESTRELAS+FAMA   [$][💎]│  ← faixa de cima (fina!)
│                        objetivo (1 linha)                    │
│ [TO DO ▸]                avisos (máx 2)                [ ▢ ] │
│                                                         [ ▢ ] │  ← coluna de botões (direita
│                 ██████  MEIO LIVRE  ██████              [ ▢ ] │     ou esquerda, no meio da altura)
│                 ██████  (o jogo)    ██████              [ ▢ ] │
│                                                               │
│ (CELULAR: analógico)     [ barra de itens do Roblox ]  (PULO) │  ← cantos de baixo PROIBIDOS no celular
└──────────────────────────────────────────────────────────────┘
```
- **Canto de cima à esquerda**: já tem os botões do Roblox (menu, chat). Nada embaixo deles por uns 60 px.
  Use `ScreenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets` (ou `GuiService:GetGuiInset()`) para fugir da barra do Roblox e do "entalhe" do celular.
- **Canto de baixo à esquerda (celular)**: analógico de andar (~35% da largura × 45% da altura). PROIBIDO.
- **Canto de baixo à direita (celular)**: botão de pular. PROIBIDO.
- **Meio de baixo**: barra de itens (Backpack) do Roblox, ~60 px de altura. Não cobrir.
- **Lugares bons**: cima-direita (dinheiro), cima-meio (objetivo/estrelas, FINO), lateral no meio da altura (botões),
  cima-esquerda abaixo do Roblox (menu pequeno / lista recolhida).

---------------------------------------------------------------------------------------------------
## 3. MEDIDAS DE REFERÊNCIA
| Coisa | Celular (deitado) | PC 1080p |
|---|---|---|
| Tela típica | 667×375, 844×390, 915×412 | 1366×768, 1920×1080 |
| Botão de menu | 48–56 px | 56–64 px |
| Faixa de estrelas/fama | 32–38 px de altura | 40–44 px |
| Pílula de dinheiro | 34–40 px de altura | 40–44 px |
| Texto mínimo | 14 px | 14–16 px |
| Número de dinheiro | 18–22 px, grosso, com contorno | 20–26 px |
| Espaço entre botões | 8 px | 8–12 px |
| Margem da borda | 8–12 px (+ área segura) | 12–16 px |
| Lista TO DO aberta | ≤ 200 px de largura, máx 3 linhas | ≤ 260 px, máx 4 linhas |
| Avisos (toasts) | máx 2 na tela, 2–3 s | igual |
Escala: calcule pelo LADO MENOR da tela (`camera.ViewportSize`), ex.: `scale = clamp(menor / 720, 0.6, 1)` e aplique
um `UIScale` em cada grupo do HUD; atualize quando `ViewportSize` mudar (girar o celular, mudar a janela).

---------------------------------------------------------------------------------------------------
## 4. O QUE OS JOGOS FAMOSOS FAZEM (ideias, nunca copiar arte/nome)
- **Botões grandes e gordinhos numa coluna lateral** (menu, loja, inventário), sempre no mesmo lugar.
- **Dinheiro em pílulas no topo à direita**, com ícone 3D (moeda de verdade) e botão "+" para a loja.
- **Tarefas mostradas no mundo** (balões em cima do personagem/pet) em vez de uma lista enorme na tela.
- **Objetivo atual curto no topo** ("Hatch 5 eggs", "Check in the guest").
- **Avisos que deslizam e somem** (ganhou moedas, nova conquista), com som curto.
- **Telas grandes só quando o jogador pede** (loja, inventário), com fundo escurecido e botão X bem visível.
- **Recursos travados**: cadeado discreto e cinza; não ocupam lugar de destaque.
- **Barra de habilidades** (jogos de luta): PC com teclas + clique; celular com 3 botões redondos acima do pulo; recarga visível no botão.
- **Ações em massa**: grade de 10 + CONTINUE + SKIP ALL fixo embaixo (abrir 170 ovos sem 170 animações).
- **Marca registrada**: uma identidade de cor/forma forte e repetida (no nosso jogo: preto + dourado elegante).

---------------------------------------------------------------------------------------------------
## 5. ESTILO DO NOSSO JOGO (2026-10: o dono trocou para CARTOON COLORIDO com ÍCONES 3D — ver prévia huds/v5; o preto+dourado abaixo é o antigo)
- Preto/grafite (≈ rgb 18–30) com borda/gradiente dourado (rgb 212,175,55 → 255,215,90), cantos arredondados,
  texto branco ou dourado com contorno escuro. (ANTIGO) Hoje: ícones 3D com o módulo Icons3D, nada de desenho nem emoji.
- Painel do HUD semi-transparente (BackgroundTransparency 0.1–0.25) para não "pesar".
- Contraste de texto ≥ 4.5:1; não usar só cor para informar (cor + ícone).

---------------------------------------------------------------------------------------------------
## 6. COMO FAZER NO ROBLOX (técnico)
- **Scale × Offset**: posição por âncora de canto (`AnchorPoint` + `UDim2.new(1, -12, 0, 12)`), tamanho em pixels
  multiplicado pelo `UIScale` do grupo. Ícones com `UIAspectRatioConstraint`.
- **Texto**: `TextScaled = true` + `UITextSizeConstraint` (MinTextSize 12–14, MaxTextSize 22–28) → nunca gigante, nunca sumido.
  Ou `AutomaticSize = X` para pílulas que crescem com o texto (com `UIPadding`).
- **Layouts**: `UIListLayout` + `UIPadding` em colunas/linhas; nada de posições "na mão" para listas.
- **Camadas (DisplayOrder)**: HUD 0 · avisos 5 · popups 10 · janelas 20 · minijogo/editor 25 · cena/intro 30.
- **ResetOnSpawn = false** em todo ScreenGui do HUD. `IgnoreGuiInset` só em telas cheias (cena, escurecer fundo).
- **Celular**: `UserInputService.TouchEnabled` e `UserInputService.KeyboardEnabled` para ajustar (ex.: esconder dicas de tecla "R"/"E" no celular).
- **Desempenho**: atualizar HUD por evento (`GetAttributeChangedSignal`), não todo quadro; tweens curtos; reaproveitar linhas da lista.
- **Esconder durante ações**: atributo Busy (minijogo, editor, cena) → some o HUD de botões, fica só o essencial.

---------------------------------------------------------------------------------------------------
## 7. TESTE OBRIGATÓRIO (antes de entregar)
1. Studio → aba **Test → Device** (emulador): iPhone SE / iPhone 14 / um Android 16:9 / iPad / 1080p.
2. Em cada um: nada sobreposto, nada embaixo da barra do Roblox, cantos de baixo livres no celular, meio livre.
3. Com o chat aberto, com a barra de itens aparecendo, com a lista TO DO aberta e fechada.
4. Texto legível no menor celular; botões tocáveis com o dedão.
5. Conta: o HUD cobre menos de 20% da tela? (some a área de cada peça visível).
6. Peça print ao dono em celular E PC.

---------------------------------------------------------------------------------------------------
## 8. CHECKLIST RÁPIDO
- [ ] Meio da tela livre · [ ] cantos de baixo livres no celular · [ ] nada sob a barra do Roblox (ScreenInsets)
- [ ] UIScale pela tela menor · [ ] texto com UITextSizeConstraint · [ ] botões ≥ 44 px
- [ ] Lista TO DO recolhida, some quando vazia · [ ] objetivo em 1 linha · [ ] máx 2 avisos
- [ ] 1 destaque por vez · [ ] ícones 3D (Icons3D), sem desenho nem emoji · [ ] cores cartoon consistentes
- [ ] Testado em 4 tamanhos · [ ] prints pedidos ao dono

## 9. ERROS QUE O DONO JÁ VIU (nunca repetir)
- v1: HUD claro "antigo e simples"; textos minúsculos ("A guest is here!").
- v2: HUD GRANDE demais: caixa TO DO enorme vazia na esquerda, faixa de estrelas larga no meio, mapinha de 9 quadrados embaixo,
  coluna de 5 botões grandes — cobria o jogo, ruim no celular e no PC.
- v3/v4: preto+dourado e depois cartoon com ícones DESENHADOS (SVG): "feio", "pegada de IA". Ícone tem que ser OBJETO 3D (Icons3D + ViewportFrame),
  fonte LuckiestGuy/FredokaOne, contorno escuro (UIStroke) em botões e textos, sombra dura (frame deslocado), sem brilho de vidro.

---------------------------------------------------------------------------------------------------
## 10. HUD APROVADO DO DOG FIGHTER (v2, estilo A escuro, 2026-10)
Prévia aprovada: `Previa_HUD/HUD_novo_PC.png` e `HUD_novo_celular.png`. Fotos do código de verdade: `Previa_HUD/HUD_jogo_*.png`.
- **Cima-esquerda** (grupo "Left"): cartão do cão (rosto 3D do modelo de verdade num círculo, selo LV, nome + estrelas, vida, XP;
  clicar abre DOGS) · faixa do TIME (+$/min e barra até o pagamento) · TRADE / CODES / SETTINGS (redondos, nome embaixo só no PC) ·
  MISSÕES: PC = painel com as 3 diárias e CLAIM! direto; celular = pílula "QUESTS" com bolinha.
- **Cima-meio** ("Center"): chip da ilha (nome + nível dos selvagens, cor do tema; Home Island / Colosseum) · barra NEXT
  (próxima ilha → melhorar a casinha → Super Boss; vira "READY:" dourado quando dá para comprar; clicar abre o menu certo) ·
  avisos (máx. 2; o emoji vira ícone 3D). Durante a luta da torre a barra NEXT some e a barra do boss fica no lugar dela.
- **Cima-direita** ("Right"): dinheiro (contador + "+" que abre a SHOP) · chip SUPER BOSS (relógio; acordado = vermelho e pulsando) ·
  radar (só PC; vermelho = selvagens, azul = jogadores, coroa = campeão, portal = volta; N gira com a câmera).
- **Direita**: frame "Side" com HOME / DOGS / EGGS / MAP / BOSS / SHOP (nomes de menu Shop, Dogs, Inventario, Map, Boss, Loja —
  o Tutorial acha os botões por `HUD.GetButton`). MAP fica vermelho no PvP. SHOP com faixa STARTER PACK.
- **Embaixo**: golpes (ícone 3D por elemento/poder, recarga em "pizza", tecla no canto no PC); chip de estado acima deles.
- Cada grupo tem UIScale próprio: PC 1, toque 1,4. `layout()` refaz tudo quando a tela muda (NEXT encolhe, radar some se não couber,
  menu 1 coluna → 2 colunas; celular: grade 3x2 que encolhe para não passar de 57% da altura).
- Cores: painel #3a2f63 → #241c40 · contorno/sombra #1b1430 · texto apagado #c9c1e6 · verde #7ef06a → #38b544 · XP #7fd6ff → #2f9cf0 ·
  dourado #ffe066 → #ffb81c · missão #5fe0c8 → #2fb39b · dinheiro #3e8a3a → #245a26 (texto #8dff6e) · boss #5a2e7c → #33184d.

## 11. TESTAR SEM O ROBLOX: foto do código de verdade (`tools/hud_preview`)
- `python3 tools/hud_preview/hud_dump.py <pc|phone|LxA|LxAt> /tmp/h.json [estados]` roda `HUD.lua`, `Kit`, `Icons3D`, `Abilities`,
  `TouchPad` e `Music` num mini-Roblox de telas (Luau CLI) com um perfil de teste, e salva a árvore de telas.
  Estados: `ko,awake,colosseum,home,pvp,mythic,longname,allclaimed,reserve,streak,noteam`.
- `node tools/hud_preview/hud_render.js /tmp/h.json foto.png` desenha no Chromium com as regras do Roblox (UDim2 + AnchorPoint,
  UIScale, listas, grade, padding, AutomaticSize, TextScaled, cantos, contornos, degradês, ZIndex) e os ícones 3D com three.js.
- Telas obrigatórias: `pc` (1920x1080), `1366x768`, `phone` (844x390), `667x375t` (iPhone pequeno), `1024x768t` (tablet).
- Limites: não anima (tweens pulam para o fim), luz 3D aproximada, cenário de fundo fixo. Não substitui o print do dono.

## 12. REGRAS DO ROBLOX PARA TELAS (conferidas)
- UIScale cresce em volta do **AnchorPoint** e multiplica tudo dentro (offsets, contornos, textos).
- UIStroke **Border** desenha POR FORA da caixa; **Contextual** num texto = contorno das letras.
- O filho sempre aparece por cima do pai → sombra dura = IRMÃO atrás (holder > sombra + corpo). Escala de clique no frame do meio.
- Largura de pílula com texto: `TextService:GetTextSize` (mesma fonte e tamanho) — dá para pôr sombra do tamanho certo.
- Ícone 3D: modelo montado uma vez e clonado; câmera pela caixa exata do modelo girado; FOV 24.
- Bolinha de aviso que pode ficar larga ("NEW"): âncora na direita, cresce para dentro da tela.
