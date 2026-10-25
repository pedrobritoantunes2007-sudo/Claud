# 🖥️ DESIGNER DE TELAS (UI) — memória e regras
Função: Deixa todas as telas bonitas e fáceis no celular, no estilo preto e dourado.
Faz parte da equipe (lista no `roblox-dev.md`, seção A EQUIPE). Leia este arquivo antes de cada tarefa e escreva em "Aprendizados" depois de cada uma.

## Regras
- ESPECIALISTA EM HUD: antes de qualquer trabalho leia o manual completo `equipe/ESTUDO_HUD.md` (10 leis, mapa da tela, medidas, técnica Roblox, teste e checklist).
- Estilo atual (2026-10): CARTOON com ÍCONES 3D DE VERDADE (módulo Icons3D num ViewportFrame), fonte LuckiestGuy/FredokaOne, contorno escuro. Desenho plano/emoji = "pegada de IA" (o dono não quer). Antigo: preto com dourado.
  No Dog Fighter o dono escolheu o **estilo A (escuro)**: painéis roxo-escuros em degradê (#3a2f63 → #241c40), contorno #1b1430, sombra dura embaixo, botões coloridos.
- Antes de entregar qualquer HUD: tirar a FOTO DO CÓDIGO DE VERDADE com `tools/hud_preview` (ver `ESTUDO_HUD.md` seção 11) em 5 telas e nos estados raros.
- Celular primeiro: botões de no mínimo 44 px, letra legível (nada minúsculo), nada se sobrepondo, testar 800×400 e 1920×1080.
- Pouco texto; ícone + número. Toda tela tem X para fechar e nunca deixa o jogador preso.
- Personagens nas telas aparecem em 3D (ViewportFrame), nunca como "fotinha".

## Aprendizados
- [HotelDePets, 2026-10] O dono achou o primeiro HUD "antigo e simples"; gostou do preto, mas quer símbolos tipo Roblox e bonecos de verdade.
- [HotelDePets, 2026-10] Nos prints da v1 os textos do HUD ficaram muito pequenos ("A guest is here!").
- [HotelDePets, 2026-10] v3 do HUD: tudo nos cantos, cada canto um grupo com UIScale (lado menor/720, mínimo 0.85 no toque) e um layout() que calcula o espaço livre (faixa do meio encolhe ou tira o título; botões da direita viram 2–3 colunas antes do botão de pular).
- [HotelDePets, 2026-10] Em 800×360 a barra do Roblox (58 px) come 1/6 da altura: a lista TO DO aberta só cabe 1 linha acima do analógico — por isso fica fechada (pílula "TO DO 2") e a meta de 1 linha é que guia o jogador.
- [HotelDePets, 2026-10] Letra "pequena demais" = caixa estreita + TextScaled + UIScale baixo (UI.fit chegava a 0.47). Regra: tamanho fixo (TextSize) em pixels base e escala mínima (0.78–0.85) para dar ≥ 14 px reais; fazer a conta px base × escala em 800×360 e 1128×596 antes de entregar.
- [DogFighter, 2026-10] Barra de habilidades: PC com teclas e clique; celular com 3 botões redondos; recarga visível. Botão RUN no celular.
- [DogFighter, 2026-10] Ações em massa (170 ovos): grade de 10 + CONTINUE + SKIP ALL fixo embaixo, que para a animação na hora.
- [DogFighter, 2026-10] Telas importantes (ovo, primeira vez) ficam ACIMA do tutorial, e o tutorial se esconde enquanto elas estão abertas.
- [DogFighter, 2026-10] Banners e avisos menores e curtos no celular (o level up tampava a tela). Sempre ter Settings (gráficos, música, efeitos) salvo na conta.
- [DogFighter, 2026-10] (v1, já trocado) HUD antigo: card do cão em cima à esquerda, coluna de 8 botões à direita, emoji em tudo.
- [DogFighter, 2026-10] Menus do Dog Fighter ainda usam emoji: quando mexer, trocar para ícones 3D (padrão novo da equipe).
- [DogFighter, 2026-10] Celular: botões de ação (correr, virar pessoa, travar câmera, voar) ficam REDONDOS em ARCO em volta do botão de pulo do Roblox (lendo o JumpButton real em PlayerGui.TouchGui), com ícone grande + nome pequeno dentro, estado ligado = cor forte e borda branca. Retângulos soltos na direita o dono não achava.
- [DogFighter, 2026-10] HUD v2 (estilo A escuro) aprovado pela prévia e programado (`UI/HUD.lua`, `UI/Icons3D.lua`): cima-esquerda cartão (rosto 3D do cão, LV, nome, estrelas, vida, XP) + TIME + TRADE/CODES/SETTINGS + MISSÕES (PC: painel com CLAIM!; celular: pílula); cima-meio chip da ilha + barra NEXT (próxima ilha → casinha → Super Boss) + no máximo 2 avisos; cima-direita dinheiro (+ abre a loja) + chip do SUPER BOSS + radar (só PC); direita 6 botões (PC coluna, vira 2 colunas se não couber; celular grade 3x2 acima do arco do pulo). O emoji de cada aviso vira ícone 3D.
- [DogFighter, 2026-10] Medidas do HUD v2 (pixels de design no PC; no celular cada grupo ×1,4): margem 12 · cartão 272×83 · time 272×35 · botões redondos 48 · missões 264×141 · chip da ilha 40 de altura · NEXT 432×43 (encolhe para caber entre os grupos) · dinheiro 240×48 · chip do boss 186×37 · radar 141 · botões do menu 70 (celular 84) · golpes 67 (celular 88) · contorno 3 · sombra 4.
- [DogFighter, 2026-10] A foto do código de verdade (`tools/hud_preview`) achou 2 erros antes do dono ver: bolinha "NEW" saindo da tela (badge cresce para a ESQUERDA: AnchorPoint (1, 0.5)) e o aviso de desmaio em cima do "CTRL = free the mouse". Sempre testar os estados raros, não só a tela "bonita".
