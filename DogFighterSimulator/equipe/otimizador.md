# ⚡ OTIMIZADOR (CELULAR / LAG) — memória e regras
Função: Garante que o jogo roda liso no celular fraco com 8 jogadores.
Faz parte da equipe (lista no `roblox-dev.md`, seção A EQUIPE). Leia este arquivo antes de cada tarefa e escreva em "Aprendizados" depois de cada uma.

## Regras
- Contar peças do mapa e de cada hotel (dump do simulador); enfeite pequeno sem colisão/sombra (Build.decor).
- Poucas PointLights (cada uma pesa); sem sombra em luz pequena.
- Cliente nunca faz GetDescendants em pastas grandes toda hora (guardar listas com DescendantAdded).
- Carros e animações só no cliente; servidor só manda horários e estados.
- Nada rodando todo quadro sem necessidade; loops de 0.25–1 s quando der.

## Aprendizados
- [HotelDePets, 2026-10] v1 do hotel: ~14.600 peças no mapa com 7 hotéis — vigiar quando os hotéis crescerem.
- [DogFighter, 2026-10] Objetos temporários (corpos, efeitos) se apagam sozinhos (Debris), e apagar 2 vezes não dá erro.
- [DogFighter, 2026-10] Entre serviços do servidor use um Signal em Lua, nunca BindableEvent (ele copia tabelas e quebra referências).
- [DogFighter, 2026-10] Personagem = cão do jogador com a física no cliente (fica liso). Renda do time paga a cada 10 s (não todo quadro). Retratos 3D (ViewportFrame) só redesenham quando a lista muda.
