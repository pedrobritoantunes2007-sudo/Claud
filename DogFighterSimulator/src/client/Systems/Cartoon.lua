-- 🎨 Textos do MUNDO sem emoji (2026-10-24, pedido do dono: "não quero 3D, quero cartoon"): plaquinhas em cima dos
-- cachorros e das pessoas, placas das ilhas, avisos 3D e marcadores. Mesma regra das telas (Kit.Cartoon): o emoji do
-- começo de um texto vira um ícone DESENHADO (UI/Icons) e o resto dos emoji some. As telas (Kit.Gui) já fazem isso
-- sozinhas; aqui é o workspace e a PlayerGui (o que o servidor cria também passa, só na tela deste jogador).
local Players = game:GetService("Players")

local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))

local Cartoon = {}

function Cartoon.Start(_HUD)
	Kit.Cartoon(workspace)
	-- (plaquinhas 3D que o próprio jogo põe na PlayerGui — seta do alvo, falas — e telas feitas sem o Kit.Gui)
	Kit.Cartoon(Players.LocalPlayer:WaitForChild("PlayerGui"))
end

return Cartoon
