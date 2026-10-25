-- 📱 Ajustes para celular: os textos 3D do mundo (nome/vida em cima dos cachorros, números de dano,
-- placas) têm tamanho fixo em pixels e numa tela pequena ocupam muito espaço. No celular eles
-- ficam 30% menores. (A escala da interface 2D fica em Kit.ScaleFactor e nos banners do HUD.)
local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))

local Mobile = {}

local SHRINK = 0.7

local function shrink(obj: Instance)
	if not obj:IsA("BillboardGui") or obj:GetAttribute("MobileScaled") then
		return
	end
	obj:SetAttribute("MobileScaled", true)
	local s = obj.Size
	obj.Size = UDim2.new(s.X.Scale * SHRINK, s.X.Offset * SHRINK, s.Y.Scale * SHRINK, s.Y.Offset * SHRINK)
end

function Mobile.Start(_HUD)
	if not Kit.IsTouch() then
		return
	end
	for _, obj in ipairs(workspace:GetDescendants()) do
		shrink(obj)
	end
	workspace.DescendantAdded:Connect(function(obj)
		if obj:IsA("BillboardGui") then
			-- espera o script que criou terminar de configurar o tamanho
			task.defer(shrink, obj)
		end
	end)
end

return Mobile
