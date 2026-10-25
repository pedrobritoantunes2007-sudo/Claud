# Como publicar o Dog Fighter Simulator

## ⚡ JEITO AUTOMÁTICO: PUBLICAR.bat (faz quase tudo sozinho)
O `PUBLICAR.bat` sobe as 6 músicas, cria os 6 gamepasses e os 6 produtos (com preço e descrição),
coloca todos os IDs dentro do jogo, publica, põe máximo de 8 jogadores e a descrição.

**Só 1 vez, antes (5 minutos):**
1. Abra `DogFighterSimulator.rbxl` no Studio → **File → Publish to Roblox → Create new game**
   (nome: Dog Fighter Simulator). Isso cria o jogo; a API do Roblox não consegue criar jogo novo.
2. Pegue os números:
   - **Universe ID** e **Place ID**: em create.roblox.com → Creations → seu jogo → menu **⋯** → *Copy Universe ID* / *Copy Start Place ID*.
   - **User ID**: abra seu perfil no roblox.com; é o número na barra de endereço (`/users/123456/profile`).
3. Crie a chave: create.roblox.com → **Open Cloud → API Keys → Create API Key**:
   - Em *Access Permissions* adicione: **assets** (read + write), **game-passes** (write),
     **developer-products** (write), **universe-places** (write), **universe.place** (write), **universe** (write).
     Onde pedir o jogo, escolha o **Dog Fighter Simulator**.
   - *Accepted IP Addresses*: `0.0.0.0/0` · Gere e **copie a chave** (só aparece uma vez).

**Depois é só:** dar 2 cliques no `PUBLICAR.bat`. Na primeira vez ele pergunta a chave e os 3 números
e guarda em `publicar_config.json` (**não mande esse arquivo para ninguém**).
Pode rodar de novo sempre que quiser atualizar o jogo: o que já foi criado não é criado de novo
(os IDs ficam em `publicar_ids.json`).

No fim falta só, no site: ícone + imagens e deixar o jogo **Público**, e no Studio ligar
**Game Settings → Security → Enable Studio Access to API Services**.
Obs.: conta sem verificação de ID pode subir só 10 áudios por mês (são 6 aqui, ok).

---

## JEITO MANUAL (se preferir fazer à mão)

## 1. Abrir e testar
1. Abra `DogFighterSimulator.rbxl` no Roblox Studio (File → Open from File).
2. Aperte **Play** e jogue uns minutos. Abra **View → Output** e confira se não aparece nada em vermelho.
3. Teste com 2 jogadores: aba **Test** → **Clients and Servers** → 2 Players → Start.

## 2. Publicar
1. **File → Publish to Roblox** → "Create new game".
2. Nome: **Dog Fighter Simulator** · Gênero: Simulator · descrição (sugestão abaixo).
3. Depois de publicar, vá em **Home → Game Settings**:
   - **Security** → ligue **Enable Studio Access to API Services** (sem isso o progresso não salva no Studio).
   - **Places → ... → Configure Place → Max Players = 8** ⚠️ o mapa tem exatamente 8 casinhas.
   - **Avatar**: pode deixar o padrão.
4. No site (create.roblox.com → seu jogo): coloque **ícone** e **thumbnails** (tire prints no Studio da Arena, da casinha e de um Mítico).
5. Em **Settings → Privacy**, mude para **Public** quando estiver pronto.

## 3. Música (para tocar no jogo)
1. create.roblox.com → **Creations → Audio → Upload**: envie os arquivos da pasta `Musica/`.
2. Copie o número (ID) de cada áudio e cole em `ReplicatedStorage → Shared → MusicConfig`:

| Arquivo | Campo no MusicConfig |
|---|---|
| tema_principal.ogg | `Tracks.Main` |
| arena.ogg | `Tracks.Arena` |
| boss.ogg | `Tracks.Boss` |
| jingle_level_up.ogg | `Jingles.LevelUp` |
| jingle_ovo.ogg | `Jingles.Hatch` |
| jingle_vitoria.ogg | `Jingles.Victory` |

Enquanto um ID estiver 0, aquela música só não toca (não dá erro).

## 4. Gamepasses e Pacote Inicial
Siga o `GAMEPASSES.md`: crie cada passe/produto no Creator Hub e cole os IDs em
`ReplicatedStorage → Shared → Monetization`. Enquanto o ID for 0 o item aparece como "em breve".

## 5. Publicar as mudanças
Sempre que mudar algo no Studio: **File → Publish to Roblox** (ou Alt+P).

---

### Sugestão de descrição
🐶 Choque ovos, colecione 77 cachorros e lute na Arena!
🏠 Seu cachorro come sozinho na casinha e sobe de level.
🥚 Ovos a cada 3 minutos — do Comum ao Mítico (Hidra, Kraken, Mecha Ômega...).
⚔️ Escolha seu oponente na Arena, ganhe Cash e XP, e enfrente os Bosses da Torre!
📜 Missões diárias, conquistas e evolução ★ dos seus cachorros.
