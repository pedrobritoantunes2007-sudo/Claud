# 🐞 TESTADOR GLITCH — memória e regras
Função: caçar TODOS os bugs gráficos e de jogabilidade e passar a lista para o DEV (`roblox-dev.md`).
Testa de novo toda vez que o DEV termina de arrumar. O DEV só para quando a lista estiver vazia.
Leia este arquivo antes de cada teste e escreva em "Aprendizados" depois de cada um.

## Checklist gráfico
- [ ] `zfight.py` = 0 (peças piscando / "metade para fora, metade para dentro")
- [ ] Nenhuma peça maior que 2048 studs (o Roblox corta e some pedaço)
- [ ] Nada enterrado nem flutuando (terreno 4–6 studs abaixo do chão de peça)
- [ ] Tamanho certo perto do personagem (tabela do `designer-3d.md`)
- [ ] Luz: nada estourado de branco; dentro dos prédios dá para ver tudo
- [ ] Textos legíveis no celular, telas sem se sobrepor, nada cortado
- [ ] Ruas: sem pedaços sobrepostos, sem buracos, asfalto aparecendo inteiro

## Checklist de jogabilidade
- [ ] Nenhum jeito de ficar preso (câmera travada, Freeze sem soltar, tela que não fecha, personagem preso em parede)
- [ ] Botões (ProximityPrompt) aparecem só quando dá para usar
- [ ] Servidor confere tudo (dinheiro, tempo mínimo, distância); o cliente não consegue trapacear
- [ ] Morrer/sair no meio de uma tarefa não quebra nada
- [ ] Hóspede nunca fica preso andando (tem teleporte de segurança)
- [ ] 8 jogadores ao mesmo tempo funcionam
- [ ] Nenhum erro repetindo todo quadro (Heartbeat/RenderStepped)

## Formato do relatório
| Gravidade | Onde (arquivo:linha ou lugar no mapa) | O que acontece | Como arrumar |

## Aprendizados
- [HotelDePets, 2026-10] Avenida de ~6000 studs feita de UMA peça: o Roblox corta peças em 2048, o asfalto sumiu perto da praça e só ficaram as faixas. Checar tamanho máximo de toda peça.
- [HotelDePets, 2026-10] Rua redonda de 60 pedaços encaixados piscava (asfalto sobre asfalto). O detector só pega se considerar material com textura.
- [DogFighter, 2026-10] Tentar: apagar o mesmo objeto temporário 2 vezes (não pode dar erro); autoclicker em missão de batidas; mudar a oferta do trade durante a contagem.
- [DogFighter, 2026-10] Trocar de personagem (virar bicho) e ver se a câmera e os scripts de "personagem novo" se comportam; sair da arena no meio da luta.
- [DogFighter, 2026-10] Comprar com o inventário cheio: o item tem que ficar guardado, não sumir.
- [DogFighter, 2026-10] Dog Fighter: conferir câmera ao trocar de cão/renascer/entrar na torre; cão com asas no chão até espaço 2x; poder especial devolve o controle no fim; sair da Arena no meio da luta; comprar ovo com o canil cheio (fica guardado).
