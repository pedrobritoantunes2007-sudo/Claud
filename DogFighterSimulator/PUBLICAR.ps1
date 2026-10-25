# =====================================================================
#  DOG FIGHTER SIMULATOR - PUBLICADOR AUTOMATICO
#  Faz sozinho, usando a API oficial do Roblox (Open Cloud):
#   1. Sobe as 6 musicas (pasta Musica) e as fotos de cima do mapa (pasta Imagens\Mapa)
#   2. Cria os gamepasses e os produtos da loja (e atualiza nome, descricao, preco e imagem dos que ja existem)
#   3. Coloca todos os IDs dentro do jogo
#   4. Publica o jogo
#   5. Coloca o maximo de 50 jogadores por servidor, a descricao e o nome do jogo
#  Pode rodar de novo quantas vezes quiser: o que ja foi criado e reaproveitado
#  (fica salvo em publicar_ids.json).
# =====================================================================
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfgPath = Join-Path $here 'publicar_config.json'
$idsPath = Join-Path $here 'publicar_ids.json'
$placeIn = Join-Path $here 'DogFighterSimulator.rbxlx'
$placeOut = Join-Path $here 'DogFighterSimulator_publicado.rbxlx'

function Say($msg, $color = 'White') { Write-Host $msg -ForegroundColor $color }
function Fail($msg) { Say ''; Say "ERRO: $msg" 'Red'; Say ''; Read-Host 'Aperte Enter para fechar'; exit 1 }

if (-not (Test-Path $placeIn)) { Fail "Nao achei o arquivo DogFighterSimulator.rbxlx nesta pasta." }

# ---------------------------------------------------------------- configuracao
$cfg = $null
if (Test-Path $cfgPath) { $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json }
if (-not $cfg) {
    Say '=== PRIMEIRA VEZ: so preciso da sua API Key (o resto eu descubro sozinho) ===' 'Yellow'
    $key = (Read-Host 'Cole a sua API Key do Open Cloud (botao direito do mouse cola)').Trim()
    if (-not $key) { Fail 'Nenhuma chave colada.' }

    # Ja conhecidos (Dog Fighter Simulator do dono): so falta a chave
    $PRESET_UNIVERSE = '10769677163'
    $PRESET_USER = '4531341003'

    # 1) User ID: vem escrito dentro da propria chave
    $userId = $PRESET_USER
    if (-not $userId) { try {
        $raw = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($key))
        $jwt = $raw.Substring($raw.IndexOf('eyJ'))
        $part = $jwt.Split('.')[1].Replace('-', '+').Replace('_', '/')
        while ($part.Length % 4) { $part += '=' }
        $userId = ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($part)) | ConvertFrom-Json).ownerId
    } catch { } }
    if (-not $userId) { $userId = (Read-Host 'Nao achei seu User ID na chave. Digite seu User ID (numero do seu perfil)').Trim() }
    Say "   User ID: $userId" 'DarkGray'

    # 2) O jogo: Universe ID ja conhecido; o Place ID vem do Roblox
    $universeId = $PRESET_UNIVERSE; $placeId = $null
    if ($universeId) {
        try { $placeId = (Invoke-RestMethod "https://develop.roblox.com/v1/universes/$universeId").rootPlaceId } catch { }
        if (-not $placeId) {
            try { $placeId = (Invoke-RestMethod "https://games.roblox.com/v1/games?universeIds=$universeId").data[0].rootPlaceId } catch { }
        }
        if ($placeId) { Say "   Jogo: Universe $universeId, Place $placeId" 'Green' } else { $universeId = $null }
    }
    if (-not $universeId) { try {
        $games = Invoke-RestMethod "https://games.roblox.com/v2/users/$userId/games?accessFilter=2&limit=50&sortOrder=Desc"
        $game = $games.data | Where-Object { $_.name -like '*Dog Fighter*' } | Select-Object -First 1
        if ($game) { $universeId = $game.id; $placeId = $game.rootPlace.id; Say "   Achei o jogo: $($game.name)" 'Green' }
    } catch { } }

    # 3) Nao achou (jogo privado): pede o link da pagina do jogo e tira os numeros dele
    while (-not ($universeId -and $placeId)) {
        Say ''
        Say 'Nao consegui achar o jogo sozinho (ele ainda esta privado).' 'Yellow'
        Say 'Abra create.roblox.com > Creations > clique no Dog Fighter Simulator,' 'Yellow'
        Say 'copie o ENDERECO da barra do navegador e cole aqui.' 'Yellow'
        $link = (Read-Host 'Link do jogo').Trim()
        try {
            if ($link -match 'experiences/(\d+)') {
                $universeId = $Matches[1]
                $placeId = (Invoke-RestMethod "https://develop.roblox.com/v1/universes/$universeId").rootPlaceId
            } elseif ($link -match 'games/(\d+)' -or $link -match 'places/(\d+)' -or $link -match '^(\d+)$') {
                $placeId = $Matches[1]
                $universeId = (Invoke-RestMethod "https://apis.roblox.com/universes/v1/places/$placeId/universe").universeId
            }
        } catch { Say "   Nao deu certo com esse link: $($_.Exception.Message)" 'Red' }
        if (-not ($universeId -and $placeId)) {
            $u = (Read-Host 'Se preferir, digite o Universe ID (ou Enter para tentar o link de novo)').Trim()
            if ($u) { $universeId = $u; $placeId = (Read-Host 'E o Place ID').Trim() }
        }
    }
    Say "   Universe ID: $universeId   Place ID: $placeId" 'DarkGray'

    $cfg = [pscustomobject]@{ ApiKey = $key; UniverseId = [string]$universeId; PlaceId = [string]$placeId; UserId = [string]$userId }
    $cfg | ConvertTo-Json | Set-Content $cfgPath -Encoding UTF8
    Say 'Configuracao salva em publicar_config.json (NAO compartilhe esse arquivo: tem a sua chave).' 'DarkGray'
}
foreach ($f in 'ApiKey', 'UniverseId', 'PlaceId', 'UserId') {
    if (-not $cfg.$f) { Fail "Falta '$f' no publicar_config.json. Apague o arquivo e rode de novo." }
}

$ids = @{}
if (Test-Path $idsPath) {
    $saved = Get-Content $idsPath -Raw | ConvertFrom-Json
    foreach ($p in $saved.PSObject.Properties) { $ids[$p.Name] = [string]$p.Value }
}
function SaveIds { $ids | ConvertTo-Json | Set-Content $idsPath -Encoding UTF8 }

$client = New-Object System.Net.Http.HttpClient
$client.Timeout = [TimeSpan]::FromMinutes(10)
$client.DefaultRequestHeaders.Add('x-api-key', $cfg.ApiKey)
$api = 'https://apis.roblox.com'

function ReadResponse($resp, $what) {
    $body = $resp.Content.ReadAsStringAsync().Result
    if (-not $resp.IsSuccessStatusCode) {
        $code = [int]$resp.StatusCode
        $hint = ''
        if ($code -eq 401 -or $code -eq 403) {
            $hint = "`n`nA chave nao tem permissao para o jogo $($cfg.UniverseId) (place $($cfg.PlaceId))." +
                "`nConfira em create.roblox.com/dashboard/credentials: universe-places = write, com o Dog Fighter Simulator selecionado." +
                "`nApaguei a chave guardada: na proxima vez que rodar, cole a chave (nova ou corrigida) de novo."
            if (Test-Path $cfgPath) { Remove-Item $cfgPath -Force -ErrorAction SilentlyContinue }
        }
        throw "$what falhou: HTTP $code $body$hint"
    }
    if ($body) { return $body | ConvertFrom-Json }
    return $null
}

function MakeForm($fields, $filePath, $fileField, $fileType) {
    $form = New-Object System.Net.Http.MultipartFormDataContent
    foreach ($k in $fields.Keys) {
        $form.Add((New-Object System.Net.Http.StringContent([string]$fields[$k], [Text.Encoding]::UTF8)), $k)
    }
    if ($filePath) {
        $bytes = [IO.File]::ReadAllBytes($filePath)
        $fc = New-Object System.Net.Http.ByteArrayContent(, $bytes)
        $fc.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($fileType)
        $form.Add($fc, $fileField, [IO.Path]::GetFileName($filePath))
    }
    # (a virgula impede o PowerShell de "desmontar" o formulario em pedacos ao devolver)
    return ,$form
}

function PostForm($url, $fields, $filePath, $fileField, $fileType, $what) {
    $form = MakeForm $fields $filePath $fileField $fileType
    return ReadResponse ($client.PostAsync($url, $form).Result) $what
}

# Envia um formulario sem parar o publicador se o Roblox recusar (devolve '' se deu certo, ou o erro)
function TryForm($method, $url, $fields, $filePath, $fileField, $fileType) {
    $req = New-Object System.Net.Http.HttpRequestMessage((New-Object System.Net.Http.HttpMethod($method)), $url)
    $req.Content = MakeForm $fields $filePath $fileField $fileType
    $resp = $client.SendAsync($req).Result
    if ($resp.IsSuccessStatusCode) { return '' }
    return "HTTP $([int]$resp.StatusCode) $($resp.Content.ReadAsStringAsync().Result)"
}

# Igual ao SendJson, mas sem parar nem mexer na chave guardada se o Roblox recusar (devolve '' ou o erro)
function TryJson($method, $url, $obj) {
    $req = New-Object System.Net.Http.HttpRequestMessage((New-Object System.Net.Http.HttpMethod($method)), $url)
    $req.Content = New-Object System.Net.Http.StringContent(($obj | ConvertTo-Json -Compress), [Text.Encoding]::UTF8, 'application/json')
    $resp = $client.SendAsync($req).Result
    if ($resp.IsSuccessStatusCode) { return '' }
    return "HTTP $([int]$resp.StatusCode) $($resp.Content.ReadAsStringAsync().Result)"
}

function SendJson($method, $url, $obj, $what) {
    $req = New-Object System.Net.Http.HttpRequestMessage((New-Object System.Net.Http.HttpMethod($method)), $url)
    $json = $obj | ConvertTo-Json -Compress
    $req.Content = New-Object System.Net.Http.StringContent($json, [Text.Encoding]::UTF8, 'application/json')
    return ReadResponse ($client.SendAsync($req).Result) $what
}

# Procura no Roblox um gamepass/produto que JA EXISTE com este nome (ex.: criado numa vez anterior, com o
# publicar_ids.json em outra pasta). Devolve o ID ou $null.
function FindExisting($type, $name) {
    if ($type -eq 'GamePass') {
        $urls = @("$api/game-passes/v1/universes/$($cfg.UniverseId)/game-passes/creator", "$api/game-passes/v1/universes/$($cfg.UniverseId)/game-passes")
    } else {
        $urls = @("$api/developer-products/v2/universes/$($cfg.UniverseId)/developer-products/creator", "$api/developer-products/v2/universes/$($cfg.UniverseId)/developer-products")
    }
    foreach ($base in $urls) {
        $token = ''
        for ($page = 0; $page -lt 20; $page++) {
            $url = "$($base)?pageSize=50"
            if ($token) { $url += "&pageToken=$([uri]::EscapeDataString($token))" }
            $resp = $client.GetAsync($url).Result
            if (-not $resp.IsSuccessStatusCode) { break }
            $data = $resp.Content.ReadAsStringAsync().Result | ConvertFrom-Json
            if (-not $data) { break }
            foreach ($prop in $data.PSObject.Properties) {
                if ($prop.Value -is [string] -or -not ($prop.Value -is [System.Collections.IEnumerable])) { continue }
                foreach ($x in @($prop.Value)) {
                    $n = $x.name
                    if (-not $n) { $n = $x.displayName }
                    if ($n -and ($n.Trim() -eq $name.Trim())) {
                        foreach ($f in 'productId', 'developerProductId', 'gamePassId', 'id') {
                            if ($x.$f) { return [string]$x.$f }
                        }
                    }
                }
            }
            $token = $data.nextPageToken
            if (-not $token) { break }
        }
    }
    return $null
}

# (2026-10-24, loja nova) gamepass/produto que ja existe: nome, descricao, preco e a imagem (Imagens\Loja\<Chave>.png)
function UpdateItem($it, $id, $img) {
    # (2026-10-25) OffSale = item que saiu do jogo (ovos): continua de quem comprou, mas sai de venda no site
    $sale = 'true'
    if ($it.OffSale) { $sale = 'false' }
    $fields = @{ name = $it.Name; description = $it.Desc; isForSale = $sale; price = [string]$it.Price }
    if ($it.Type -eq 'GamePass') {
        $url = "$api/game-passes/v1/universes/$($cfg.UniverseId)/game-passes/$id"
    } else {
        $url = "$api/developer-products/v2/universes/$($cfg.UniverseId)/developer-products/$id"
    }
    $err = TryForm 'PATCH' $url $fields $img 'imageFile' 'image/png'
    if ($err -and $img) { $err = TryForm 'PATCH' $url $fields $null $null $null }
    return $err
}

function CreateItem($it, $name) {
    $fields = @{ name = $name; description = $it.Desc; isForSale = 'true'; price = [string]$it.Price }
    if ($it.Type -eq 'GamePass') {
        $r = PostForm "$api/game-passes/v1/universes/$($cfg.UniverseId)/game-passes" $fields $null $null $null "Criar gamepass $name"
        return [string]$r.gamePassId
    }
    $r = PostForm "$api/developer-products/v2/universes/$($cfg.UniverseId)/developer-products" $fields $null $null $null "Criar produto $name"
    return [string]$r.productId
}

try {
    # ------------------------------------------------------------ 1. musicas
    Say ''
    Say '1/5  Subindo as musicas...' 'Cyan'
    # (2026-10-25) TRILHA 2 + sons novos primeiro: se o limite de audios do mes do Roblox acabar no meio, o jogo
    # continua com a trilha/sons antigos e na proxima vez o .bat tenta de novo (nada para a publicacao)
    $music = @(
        @{ Key = 'Pack2'; File = 'sfx_pack2.ogg'; Name = 'Dog Fighter - Sound Effects 2' },
        @{ Key = 'MusicA'; File = 'musicas_a.ogg'; Name = 'Dog Fighter - Musicas A (Pawville)' },
        @{ Key = 'MusicB'; File = 'musicas_b.ogg'; Name = 'Dog Fighter - Musicas B (Ilhas)' },
        @{ Key = 'MusicC'; File = 'musicas_c.ogg'; Name = 'Dog Fighter - Musicas C (Boss e vinhetas)' },
        @{ Key = 'Main'; File = 'tema_principal.ogg'; Name = 'Dog Fighter - Tema Principal' },
        @{ Key = 'Arena'; File = 'arena.ogg'; Name = 'Dog Fighter - Arena' },
        @{ Key = 'Boss'; File = 'boss.ogg'; Name = 'Dog Fighter - Boss' },
        @{ Key = 'LevelUp'; File = 'jingle_level_up.ogg'; Name = 'Dog Fighter - Level Up' },
        @{ Key = 'Hatch'; File = 'jingle_ovo.ogg'; Name = 'Dog Fighter - Ovo' },
        @{ Key = 'Victory'; File = 'jingle_vitoria.ogg'; Name = 'Dog Fighter - Vitoria' },
        @{ Key = 'Pack'; File = 'sfx_pack.ogg'; Name = 'Dog Fighter - Sound Effects' }
    )
    # (o .bat pode estar na pasta do projeto ou ao lado dela, como vem nos zips)
    $musicDir = Join-Path $here 'Musica'
    if (-not (Test-Path $musicDir)) { $musicDir = Join-Path (Join-Path $here 'DogFighterSimulator') 'Musica' }
    foreach ($m in $music) {
        $idKey = 'Music_' + $m.Key
        if ($ids[$idKey]) { Say "   ja enviada: $($m.File) -> $($ids[$idKey])" 'DarkGray'; continue }
        $path = Join-Path $musicDir $m.File
        if (-not (Test-Path $path)) { Say "   pulei (arquivo nao encontrado): $($m.File)" 'Yellow'; continue }
        try {
            $request = @{
                assetType       = 'Audio'
                displayName     = $m.Name
                description     = 'Original soundtrack of Dog Fighter Simulator'
                creationContext = @{ creator = @{ userId = [string]$cfg.UserId } }
            } | ConvertTo-Json -Depth 5 -Compress
            $op = PostForm "$api/assets/v1/assets" @{ request = $request } $path 'fileContent' 'audio/ogg' "Upload de $($m.File)"
            $assetId = $null
            for ($i = 0; $i -lt 60 -and -not $assetId; $i++) {
                if ($op.done -and $op.response.assetId) { $assetId = $op.response.assetId; break }
                if ($op.error) { throw "Upload de $($m.File): $($op.error.message)" }
                Start-Sleep -Seconds 2
                $op = ReadResponse ($client.GetAsync("$api/assets/v1/$($op.path)").Result) "Status do upload de $($m.File)"
            }
            if (-not $assetId) { throw "O Roblox demorou demais para processar $($m.File). Rode de novo daqui a pouco." }
            $ids[$idKey] = [string]$assetId
            SaveIds
            Say "   OK $($m.File) -> $assetId" 'Green'
        } catch {
            Say "   nao consegui subir $($m.File): $($_.Exception.Message)" 'Yellow'
            Say '   -> o jogo continua com a musica/sons antigos. Se for o limite de audios do mes, rode o .bat de novo outro dia.' 'Yellow'
        }
    }

    # ------------------------------------------------------------ 1b. fotos de cima do mapa (Imagens\Mapa)
    # (2026-10-24: o MAP e o minimapa mostram as ilhas de verdade vistas de cima; cada foto vira um Decal)
    Say ''
    Say '1b/5 Subindo as fotos do mapa...' 'Cyan'
    # (o .bat pode estar na pasta do projeto ou ao lado dela, como vem nos zips)
    $mapDir = Join-Path (Join-Path $here 'Imagens') 'Mapa'
    if (-not (Test-Path $mapDir)) { $mapDir = Join-Path (Join-Path (Join-Path $here 'DogFighterSimulator') 'Imagens') 'Mapa' }
    $mapKeys = @('main', 'village', 'common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic', 'divine', 'cloud', 'rank')
    foreach ($k in $mapKeys) {
        $idKey = 'Map_' + $k
        if ($ids[$idKey]) { Say "   ja enviada: mapa $k -> $($ids[$idKey])" 'DarkGray'; continue }
        $path = Join-Path $mapDir ($k + '.png')
        if (-not (Test-Path $path)) { Say "   pulei (arquivo nao encontrado): Imagens\Mapa\$k.png" 'Yellow'; continue }
        try {
            $request = @{
                assetType       = 'Decal'
                displayName     = "Dog Fighter - Mapa $k"
                description     = 'Top-down map of Dog Fighter Simulator'
                creationContext = @{ creator = @{ userId = [string]$cfg.UserId } }
            } | ConvertTo-Json -Depth 5 -Compress
            $op = PostForm "$api/assets/v1/assets" @{ request = $request } $path 'fileContent' 'image/png' "Upload do mapa $k"
            $assetId = $null
            for ($i = 0; $i -lt 60 -and -not $assetId; $i++) {
                if ($op.done -and $op.response.assetId) { $assetId = $op.response.assetId; break }
                if ($op.error) { throw "Upload do mapa ${k}: $($op.error.message)" }
                Start-Sleep -Seconds 2
                $op = ReadResponse ($client.GetAsync("$api/assets/v1/$($op.path)").Result) "Status do upload do mapa $k"
            }
            if (-not $assetId) { throw "O Roblox demorou demais para processar o mapa $k." }
            $ids[$idKey] = [string]$assetId
            SaveIds
            Say "   OK mapa $k -> $assetId" 'Green'
        } catch {
            # (o jogo funciona sem a foto: fica o mapa desenhado; na proxima vez tenta de novo)
            Say "   nao consegui subir a foto do mapa ${k}: $($_.Exception.Message)" 'Yellow'
        }
    }

    # ------------------------------------------------------------ 2. gamepasses e produtos
    Say ''
    Say '2/5  Criando gamepasses e produtos...' 'Cyan'
    $items = @(
    @{ Key = 'StarterPack'; Type = 'Product'; Price = 49; Name = 'STARTER PACK'; Desc = 'Guaranteed RARE dog + $1,500 Cash + 500 food XP + 5 Super Leashes. Only once per account!' }
    @{ Key = 'VIP'; Type = 'GamePass'; Price = 79; Name = 'VIP'; Desc = 'VIP tag above your head + 10% more Cash and XP. Forever!' }
    @{ Key = 'Cash2x'; Type = 'GamePass'; Price = 99; Name = '2x Cash'; Desc = 'Double Cash from missions, champions and bosses. Forever!' }
    @{ Key = 'XP2x'; Type = 'GamePass'; Price = 99; Name = '2x XP'; Desc = 'Your dog earns double XP: level up and unlock powers twice as fast!' }
    @{ Key = 'LuckyPaw'; Type = 'GamePass'; Price = 129; Name = 'Lucky Paw'; Desc = 'Way better luck when you CATCH wild dogs: catch Rare, Epic, Legendary and Mythic dogs way easier!' }
    @{ Key = 'SpeedBoost'; Type = 'GamePass'; Price = 59; Name = 'Speedy Paws'; Desc = 'Your dog runs 20% faster. Get to every island and fight first!' }
    @{ Key = 'FastEggs'; Type = 'GamePass'; Price = 49; Name = 'Fast Missions'; Desc = 'Every wild dog counts as 2 in your island missions: finish missions 2x faster!' }
    @{ Key = 'QuickRevive'; Type = 'GamePass'; Price = 39; Name = 'Quick Revive'; Desc = 'Fainted? Your dog is back in 2 seconds instead of 5!' }
    @{ Key = 'AutoHatch'; Type = 'GamePass'; Price = 69; Name = 'Auto Hatch'; Desc = 'Opens the eggs in your Inventory for you, one at a time. Turn it ON/OFF in the Shop.'; OffSale = $true }
    @{ Key = 'ExtraNest'; Type = 'GamePass'; Price = 49; Name = 'Big Kennel'; Desc = '+100 dog slots in your kennel: keep every dog you catch!' }
    @{ Key = 'CashSmall'; Type = 'Product'; Price = 25; Name = 'Pouch of Cash'; Desc = 'Cash worth 3 missions on your best island.' }
    @{ Key = 'CashMedium'; Type = 'Product'; Price = 59; Name = 'Bag of Cash'; Desc = 'Cash worth 8 missions on your best island, +10% bonus.' }
    @{ Key = 'CashBig'; Type = 'Product'; Price = 129; Name = 'Vault of Cash'; Desc = 'Cash worth 20 missions on your best island, +20% bonus.' }
    @{ Key = 'CashHuge'; Type = 'Product'; Price = 299; Name = 'Treasure of Cash'; Desc = 'Cash worth 50 missions on your best island, +35% bonus!' }
    @{ Key = 'LuckySpins10'; Type = 'Product'; Price = 149; Name = '10 LUCKY Spins'; Desc = '10 LUCKY spins at the Dog Roulette: no Common dogs and way better odds of Epic, Legendary, Mythic, Halloween and Divine!' }
    @{ Key = 'Spins10'; Type = 'Product'; Price = 49; Name = '10 Roulette Spins'; Desc = '10 spins at the Dog Roulette in Pawville! Every dog can drop: even Mythic, Halloween and Divine!' }
    @{ Key = 'SpecialEgg'; Type = 'Product'; Price = 35; Name = 'Crystal Egg'; Desc = '1 Crystal Egg: Rare, Epic, Legendary or even Mythic!'; OffSale = $true }
    @{ Key = 'MythicDog'; Type = 'Product'; Price = 100; Name = 'Random Mythic Dog'; Desc = 'Instantly get 1 random MYTHIC dog (Hydra, Kraken, Mecha Omega, Cerberus...)!' }
    @{ Key = 'LeashDivine3'; Type = 'Product'; Price = 59; Name = '3 DIVINE Leashes'; Desc = 'The BEST leash: 4x catch power! Catch Legendary and Mythic wild dogs way easier.' }
    @{ Key = 'LeashGolden10'; Type = 'Product'; Price = 99; Name = '10 Golden Leashes'; Desc = '10 Golden Leashes: 2.4x catch power to catch rare wild dogs!' }
    @{ Key = 'DivineDog'; Type = 'Product'; Price = 399; Name = 'Sunfire Dragon (DIVINE)'; Desc = 'The only DIVINE dog! Fire + Light + Fly, Sunfire Breath and the DIVINE SUNFIRE Supreme.' }
    @{ Key = 'CashRush'; Type = 'Product'; Price = 39; Name = 'Cash Rush (30 min)'; Desc = '2x Cash for 30 minutes of play (on top of the 2x Cash pass!). Buy again to add more time.' }
    @{ Key = 'LuckRush'; Type = 'Product'; Price = 39; Name = 'Lucky Rush (30 min)'; Desc = 'Extra catch luck for 30 minutes of play (adds to Lucky Paw!). Buy again to add more time.' }
    @{ Key = 'SeasonPass'; Type = 'Product'; Price = 199; Name = 'SEASON PASS'; Desc = 'Unlock the PREMIUM track of this season: way more rewards, 2 season accessories and the EXCLUSIVE season dog at level 30!' }
    @{ Key = 'Acc_crown'; Type = 'Product'; Price = 99; Name = 'Royal Crown'; Desc = 'A golden crown with jewels for your dog: +10% Cash forever! Everyone sees it.' }
    @{ Key = 'Acc_galaxy'; Type = 'Product'; Price = 129; Name = 'Galaxy Cape'; Desc = 'A starry galaxy cape for your dog: +8% speed forever! Everyone sees it.' }
    @{ Key = 'Acc_diamond'; Type = 'Product'; Price = 79; Name = 'Diamond Collar'; Desc = 'A sparkling diamond collar for your dog: +8% catch chance forever! Everyone sees it.' }
    @{ Key = 'Acc_visor'; Type = 'Product'; Price = 69; Name = 'Star Visor'; Desc = 'A glowing star visor for your dog: +10% XP forever! Everyone sees it.' }
    @{ Key = 'Donate10'; Type = 'Product'; Price = 10; Name = 'Donate 10 Robux'; Desc = 'Support the creator of Dog Fighter Simulator! Thank you! (no in-game items)' }
    @{ Key = 'Donate25'; Type = 'Product'; Price = 25; Name = 'Donate 25 Robux'; Desc = 'Support the creator of Dog Fighter Simulator! Thank you! (no in-game items)' }
    @{ Key = 'Donate50'; Type = 'Product'; Price = 50; Name = 'Donate 50 Robux'; Desc = 'Support the creator of Dog Fighter Simulator! Thank you! (no in-game items)' }
    @{ Key = 'Donate100'; Type = 'Product'; Price = 100; Name = 'Donate 100 Robux'; Desc = 'Support the creator of Dog Fighter Simulator! Thank you! (no in-game items)' }
    @{ Key = 'Donate500'; Type = 'Product'; Price = 500; Name = 'Donate 500 Robux'; Desc = 'Support the creator of Dog Fighter Simulator! Thank you! (no in-game items)' }
    @{ Key = 'Donate1000'; Type = 'Product'; Price = 1000; Name = 'Donate 1000 Robux'; Desc = 'Support the creator of Dog Fighter Simulator! Thank you SO much! (no in-game items)' }
    )
    foreach ($it in $items) {
        if ($ids[$it.Key]) { Say "   ja existe: $($it.Name) -> $($ids[$it.Key])" 'DarkGray'; continue }
        if ($it.OffSale) { continue }  # (saiu do jogo: nao cria)
        $newId = $null
        try {
            $newId = CreateItem $it $it.Name
        } catch {
            $msg = $_.Exception.Message
            if ($msg -notmatch 'Duplicate|already exists') { throw }
            # ja foi criado antes (o numero ficou salvo em outra pasta): usa o que ja existe no Roblox
            $found = FindExisting $it.Type $it.Name
            if ($found) {
                $ids[$it.Key] = $found
                SaveIds
                Say "   ja existia no Roblox: $($it.Name) -> $found" 'DarkGray'
                continue
            }
            # nao achou na lista: cria com um nome um pouco diferente (o antigo fica sem uso)
            $newId = CreateItem $it "$($it.Name) - Dog Fighter"
        }
        $ids[$it.Key] = $newId
        SaveIds
        Say "   OK $($it.Type) $($it.Name) ($($it.Price) Robux) -> $($ids[$it.Key])" 'Green'
    }
    # (2026-10-24, loja nova) os que ja existiam ganham o nome, a descricao, o preco e a imagem novos.
    # Fica anotado no publicar_ids.json: so atualiza de novo se algo mudar.
    $shopDir = Join-Path (Join-Path $here 'Imagens') 'Loja'
    if (-not (Test-Path $shopDir)) { $shopDir = Join-Path (Join-Path (Join-Path $here 'DogFighterSimulator') 'Imagens') 'Loja' }
    foreach ($it in $items) {
        if (-not $ids[$it.Key]) { continue }
        $img = Join-Path $shopDir ($it.Key + '.png')
        if (-not (Test-Path $img)) { $img = $null }
        $sig = "$($it.Name)|$($it.Price)|$($it.Desc)|$([bool]$img)|v1"
        if ($it.OffSale) { $sig += '|off' }
        if ($ids['Info_' + $it.Key] -eq $sig) { continue }
        $err = UpdateItem $it $ids[$it.Key] $img
        if ($err) {
            Say "   nao consegui atualizar $($it.Name) (fica como estava no site): $err" 'Yellow'
        } else {
            $ids['Info_' + $it.Key] = $sig
            SaveIds
            Say "   atualizado no site: $($it.Name) ($($it.Price) Robux)" 'Green'
        }
    }

    # ------------------------------------------------------------ 3. IDs dentro do jogo
    Say ''
    Say '3/5  Colocando os IDs dentro do jogo...' 'Cyan'
    $xml = [IO.File]::ReadAllText($placeIn, [Text.Encoding]::UTF8)
    foreach ($it in $items) {
        if ($ids[$it.Key]) { $xml = [regex]::Replace($xml, "\b$($it.Key) = \d+ --\[\[ID\]\]", "$($it.Key) = $($ids[$it.Key]) --[[ID]]") }
    }
    foreach ($m in $music) {
        $idKey = 'Music_' + $m.Key
        if ($ids[$idKey]) { $xml = [regex]::Replace($xml, "\b$($m.Key) = \d+ --\[\[ID_Music\]\]", "$($m.Key) = $($ids[$idKey]) --[[ID_Music]]") }
    }
    foreach ($k in $mapKeys) {
        $idKey = 'Map_' + $k
        if ($ids[$idKey]) { $xml = [regex]::Replace($xml, "\b$k = \d+ --\[\[ID_Map\]\]", "$k = $($ids[$idKey]) --[[ID_Map]]") }
    }
    [IO.File]::WriteAllText($placeOut, $xml, (New-Object Text.UTF8Encoding($false)))
    Say '   OK (DogFighterSimulator_publicado.rbxlx)' 'Green'

    # ------------------------------------------------------------ 4. publicar
    Say ''
    Say "4/5  Publicando o jogo (Universe $($cfg.UniverseId), Place $($cfg.PlaceId))..." 'Cyan'
    $content = New-Object System.Net.Http.ByteArrayContent(, [IO.File]::ReadAllBytes($placeOut))
    $content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/xml')
    $pub = ReadResponse ($client.PostAsync("$api/universes/v1/$($cfg.UniverseId)/places/$($cfg.PlaceId)/versions?versionType=Published", $content).Result) 'Publicar o jogo'
    Say "   OK versao $($pub.versionNumber) publicada!" 'Green'

    # ------------------------------------------------------------ 5. ajustes
    Say ''
    Say '5/5  Ajustes finais...' 'Cyan'
    try {
        # (2026-10, pedido do dono: "aumentar o limite para 50 jogadores"; antes eram 8 por causa das 8 casinhas)
        SendJson 'PATCH' "$api/cloud/v2/universes/$($cfg.UniverseId)/places/$($cfg.PlaceId)?updateMask=serverSize" @{ serverSize = 50 } 'Maximo de jogadores' | Out-Null
        Say '   OK maximo de 50 jogadores por servidor' 'Green'
    } catch { Say "   nao consegui mudar o maximo de jogadores: $($_.Exception.Message)" 'Yellow'; Say '   -> mude a mao: Creator Hub > o jogo > Places > Configure Place > Server Size = 50 (ou no Studio: Game Settings > Places > Max Players = 50)' 'Yellow' }
    try {
        # (2026-10-25, pedido do dono: descricao nova em ingles, com as novidades) texto da pagina do jogo (ingles, ate 1000 letras)
        $desc = @(
            '🔥 NEW UPDATE: 🏆 Ranking Island, ✨ SHINY dogs, 🧬 EVOLVE, 🚩 Clans, 🎟️ Season Pass and 🎉 Weekend Events!',
            '',
            '🐶 Be a dog and FIGHT! Get your first pup in Pawville, battle wild dogs, weaken them and throw a 🦮 LEASH to catch them.',
            '',
            '⭐ FEATURES ⭐',
            '🐾 Catch 80+ dogs: Common to Mythic, Halloween and Divine',
            '✨ 1 in 500 wild dogs is SHINY: catch it before anyone else!',
            '🌈 EVOLVE: 3 equal dogs = 1 GOLD, 3 GOLD = 1 RAINBOW',
            '⚡ Aim your powers, dash and combo: every dog has its own skills',
            '🪽 Winged dogs really FLY between the islands',
            '🏝️ Beat each island champion to open the next one',
            '🎩 Hats, collars, glasses and capes for your dog',
            '🚩 Create a CLAN with friends and climb the weekly ranking',
            '🎟️ Season Pass with an EXCLUSIVE dog at level 30',
            '🎉 Weekend events: 2x Catch, 2x Cash and Rare Dog Rain',
            '⚔️ PvP in the Colosseum and a 👹 Super Boss for everyone',
            '🤝 Safe trades with friends and 🏆 Ranking Island leaderboards',
            '',
            '👍 Like the game and ⭐ add it to your favorites to get every new update!'
        ) -join "`n"
        SendJson 'PATCH' "$api/cloud/v2/universes/$($cfg.UniverseId)?updateMask=description" @{ description = $desc } 'Descricao' | Out-Null
        Say '   OK descricao do jogo' 'Green'
    } catch { Say "   nao consegui colocar a descricao (pode colocar a mao): $($_.Exception.Message)" 'Yellow' }
    # nome do jogo: com a etiqueta do evento ate 07/11 (aparece na lista de jogos e chama atencao), depois volta ao normal
    $gameName = 'Dog Fighter Simulator'
    if ((Get-Date) -lt [datetime]'2026-11-08') { $gameName = '[HALLOWEEN] Dog Fighter Simulator' }
    $err = TryJson 'PATCH' "$api/cloud/v2/universes/$($cfg.UniverseId)?updateMask=displayName" @{ displayName = $gameName }
    if ($err) {
        Say "   nao consegui mudar o nome (pode mudar a mao no site para: $gameName): $err" 'Yellow'
    } else {
        Say "   OK nome do jogo: $gameName" 'Green'
    }
    # reinicia todos os servidores para todo mundo entrar na versao nova (pedido do dono)
    try {
        SendJson 'POST' "$api/cloud/v2/universes/$($cfg.UniverseId):restartServers" @{} 'Reiniciar servidores' | Out-Null
        Say '   OK todos os servidores reiniciados (versao nova para todos)' 'Green'
    } catch { Say "   nao consegui reiniciar os servidores: $($_.Exception.Message)" 'Yellow'; Say '   -> a chave precisa da permissao universe:write (ou use Creator Hub > ... > Restart Servers)' 'Yellow' }
} catch {
    Fail $_.Exception.Message
}

Say ''
Say '=====================================================' 'Green'
Say ' PRONTO! O jogo foi publicado com musicas e loja.' 'Green'
Say ' Falta so (no site create.roblox.com, 1 minuto):' 'Green'
Say '  - colocar o icone e as 5 imagens novas (pasta Imagens\Jogo)' 'Green'
Say '  - deixar o jogo PUBLICO (Settings > Privacy)' 'Green'
Say '=====================================================' 'Green'
# (pedido do dono: "eu abro e rodo e voce faz tudo") abre a pasta das imagens e a pagina do jogo no site
try {
    $imgDir = Join-Path (Join-Path $here 'Imagens') 'Jogo'
    if (-not (Test-Path $imgDir)) { $imgDir = Join-Path (Join-Path (Join-Path $here 'DogFighterSimulator') 'Imagens') 'Jogo' }
    if (Test-Path $imgDir) { Start-Process explorer.exe $imgDir }
    Start-Process "https://create.roblox.com/dashboard/creations/experiences/$($cfg.UniverseId)/overview"
    Say ' Abri a pasta com o icone e as 5 imagens e a pagina do jogo: arraste as imagens para Icon e Thumbnails.' 'Green'
} catch { }
Read-Host 'Aperte Enter para fechar'
