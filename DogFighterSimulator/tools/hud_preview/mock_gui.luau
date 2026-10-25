-- Mini-Roblox de TELAS: complemento do tools/preview/mock.luau para rodar o HUD de verdade fora do Roblox.
-- Tem UDim/UDim2/Vector2 com contas, as classes de interface com os valores padrão do Roblox, eventos
-- (Activated, MouseEnter...), serviços (Players, UserInputService, GuiService, TweenService, TextService...),
-- workspace com câmera do tamanho da tela. As animações (Tween) pulam direto para o fim; laços com
-- task.wait rodam uma vez. Usa: MOCK (o que o mock.luau devolve), METRICS (fonts_metrics.json) e SCREEN.
local PARENT_CLASS, DEFAULTS, InstMethods, Inst = MOCK.PARENT_CLASS, MOCK.DEFAULTS, MOCK.InstMethods, MOCK.Inst

---------------------------------------------------------------- sinais (eventos)
local SignalMt = {}
SignalMt.__index = SignalMt
local function newSignal()
	return setmetatable({ _fns = {} }, SignalMt)
end
function SignalMt:Connect(fn)
	table.insert(self._fns, fn)
	local list = self._fns
	return {
		Connected = true,
		Disconnect = function()
			local i = table.find(list, fn)
			if i then
				table.remove(list, i)
			end
		end,
	}
end
SignalMt.connect = SignalMt.Connect
function SignalMt:Once(fn)
	return self:Connect(fn)
end
function SignalMt:Wait()
	-- dentro de task.spawn: para para sempre (igual ao task.wait do mock) — laços "while ... :Wait()" (Kit.Rays) não travam
	local co = coroutine.running()
	if co and MOCK and MOCK.spawned and MOCK.spawned[co] then
		coroutine.yield()
	end
	return nil
end
function SignalMt:Fire(...)
	for _, fn in ipairs(table.clone(self._fns)) do
		local ok, err = pcall(fn, ...)
		if not ok then
			print("[evento erro]", err)
		end
	end
end
NEW_SIGNAL = newSignal

local EVENTS = {}
for _, k in ipairs({
	"Activated", "MouseEnter", "MouseLeave", "MouseButton1Down", "MouseButton1Up", "MouseButton1Click",
	"MouseButton2Click", "SelectionGained", "SelectionLost", "InputBegan", "InputEnded", "InputChanged",
	"Changed", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged",
	"Destroying", "Event", "OnClientEvent", "OnServerEvent", "Touched", "TouchEnded", "FocusLost", "Focused",
	"Completed", "Triggered", "PromptShown", "Died", "HealthChanged", "StateChanged", "Running", "Ended",
	"Played", "Loaded", "CharacterAdded", "CharacterRemoving", "Chatted", "MoveToFinished", "AttributeChanged",
	"PromptGamePassPurchaseFinished", "PromptProductPurchaseFinished", "MouseWheelForward", "MouseWheelBackward",
}) do
	EVENTS[k] = true
end

local oldIndex = Inst.__index
Inst.__index = function(self, k)
	local v = oldIndex(self, k)
	if v ~= nil then
		return v
	end
	if EVENTS[k] then
		local sigs = rawget(self, "_signals")
		if not sigs then
			sigs = {}
			rawset(self, "_signals", sigs)
		end
		local s = sigs[k]
		if not s then
			s = newSignal()
			sigs[k] = s
		end
		return s
	end
	return nil
end

-- ChildAdded / DescendantAdded ao mudar o Parent (como no Roblox: o objeto e tudo que já está dentro dele)
local baseNewIndex = Inst.__newindex
Inst.__newindex = function(self, k, v)
	local before = k == "Parent" and rawget(self, "_props").Parent or nil
	baseNewIndex(self, k, v)
	if k ~= "Parent" or v == nil or v == before then
		return
	end
	local sigs = rawget(v, "_signals")
	if sigs and sigs.ChildAdded then
		sigs.ChildAdded:Fire(self)
	end
	local subtree = nil
	local node = v
	while node do
		local s = rawget(node, "_signals")
		if s and s.DescendantAdded then
			if not subtree then
				subtree = { self }
				for _, d in ipairs(self:GetDescendants()) do
					table.insert(subtree, d)
				end
			end
			for _, d in ipairs(subtree) do
				s.DescendantAdded:Fire(d)
			end
		end
		node = rawget(node, "_props").Parent
	end
end

local attrSignals = setmetatable({}, { __mode = "k" })
function InstMethods.GetAttributeChangedSignal(self, name)
	local map = attrSignals[self]
	if not map then
		map = {}
		attrSignals[self] = map
	end
	map[name] = map[name] or newSignal()
	return map[name]
end
local rawSetAttribute = InstMethods.SetAttribute
function InstMethods.SetAttribute(self, k, v)
	rawSetAttribute(self, k, v)
	local map = attrSignals[self]
	if map and map[k] then
		map[k]:Fire()
	end
end
function InstMethods.Fire(self, ...)
	self.Event:Fire(...)
end
function InstMethods.FireServer() end
function InstMethods.FireClient() end
function InstMethods.InvokeServer()
	return true, ""
end
function InstMethods.GetFullName(self)
	local names = {}
	local p = self
	while p do
		table.insert(names, 1, p._props.Name)
		p = p._props.Parent
	end
	return table.concat(names, ".")
end
function InstMethods.IsDescendantOf(self, other)
	local p = self._props.Parent
	while p do
		if p == other then
			return true
		end
		p = p._props.Parent
	end
	return false
end
function InstMethods.FindFirstAncestor(self, name)
	local p = self._props.Parent
	while p do
		if p._props.Name == name then
			return p
		end
		p = p._props.Parent
	end
	return nil
end
function InstMethods.FindFirstAncestorWhichIsA(self, className)
	local p = self._props.Parent
	while p do
		if p:IsA(className) then
			return p
		end
		p = p._props.Parent
	end
	return nil
end
function InstMethods.GetBoundingBox(self)
	local minV, maxV = nil, nil
	for _, d in ipairs(self:GetDescendants()) do
		if d:IsA("BasePart") then
			local cf, s = d.CFrame, d.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local w = cf * Vector3.new(s.X * sx, s.Y * sy, s.Z * sz)
						minV = minV and minV:Min(w) or w
						maxV = maxV and maxV:Max(w) or w
					end
				end
			end
		end
	end
	if not minV then
		return CFrame.new(), Vector3.new(0, 0, 0)
	end
	return CFrame.new((minV + maxV) / 2), maxV - minV
end
function InstMethods.GetExtentsSize(self)
	local _, size = self:GetBoundingBox()
	return size
end
function InstMethods.LoadAnimation()
	return { Play = function() end, Stop = function() end, AdjustSpeed = function() end }
end

---------------------------------------------------------------- UDim, UDim2, Vector2 (com contas)
local UDimMt = { __type = "UDim" }
UDimMt.__index = UDimMt
local function udim(s, o)
	return setmetatable({ Scale = s or 0, Offset = o or 0 }, UDimMt)
end
UDimMt.__add = function(a, b)
	return udim(a.Scale + b.Scale, a.Offset + b.Offset)
end
UDimMt.__sub = function(a, b)
	return udim(a.Scale - b.Scale, a.Offset - b.Offset)
end
UDimMt.__eq = function(a, b)
	return a.Scale == b.Scale and a.Offset == b.Offset
end
UDim = { new = udim }

local UDim2Mt = { __type = "UDim2" }
UDim2Mt.__index = function(t, k)
	if k == "Width" then
		return rawget(t, "X")
	elseif k == "Height" then
		return rawget(t, "Y")
	elseif k == "Lerp" then
		return function(a, b, alpha)
			return setmetatable({
				X = udim(a.X.Scale + (b.X.Scale - a.X.Scale) * alpha, a.X.Offset + (b.X.Offset - a.X.Offset) * alpha),
				Y = udim(a.Y.Scale + (b.Y.Scale - a.Y.Scale) * alpha, a.Y.Offset + (b.Y.Offset - a.Y.Offset) * alpha),
			}, UDim2Mt)
		end
	end
	return nil
end
local function udim2(xs, xo, ys, yo)
	if typeof(xs) == "UDim" then
		return setmetatable({ X = xs, Y = xo }, UDim2Mt)
	end
	return setmetatable({ X = udim(xs, xo), Y = udim(ys, yo) }, UDim2Mt)
end
UDim2Mt.__add = function(a, b)
	return udim2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UDim2Mt.__sub = function(a, b)
	return udim2(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
end
UDim2Mt.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
UDim2 = {
	new = udim2,
	fromOffset = function(x, y)
		return udim2(0, x or 0, 0, y or 0)
	end,
	fromScale = function(x, y)
		return udim2(x or 0, 0, y or 0, 0)
	end,
}

local V2 = { __type = "Vector2" }
local V2m = {}
local function v2(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
V2.__index = function(t, k)
	if k == "Magnitude" then
		return math.sqrt(t.X * t.X + t.Y * t.Y)
	elseif k == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y)
		return m > 0 and v2(t.X / m, t.Y / m) or v2(0, 0)
	elseif k == "x" then
		return t.X
	elseif k == "y" then
		return t.Y
	end
	return V2m[k]
end
V2.__add = function(a, b)
	return v2(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
V2.__mul = function(a, b)
	if type(a) == "number" then
		return v2(a * b.X, a * b.Y)
	elseif type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	if type(b) == "number" then
		return v2(a.X / b, a.Y / b)
	end
	return v2(a.X / b.X, a.Y / b.Y)
end
V2.__unm = function(a)
	return v2(-a.X, -a.Y)
end
V2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
function V2m.Dot(a, b)
	return a.X * b.X + a.Y * b.Y
end
function V2m.Lerp(a, b, t)
	return a + (b - a) * t
end
function V2m.Min(a, b)
	return v2(math.min(a.X, b.X), math.min(a.Y, b.Y))
end
function V2m.Max(a, b)
	return v2(math.max(a.X, b.X), math.max(a.Y, b.Y))
end
Vector2 = { new = v2, zero = v2(0, 0), one = v2(1, 1) }

-- sequências guardam os valores para o desenho (o mock base já cria { Args = {...} })
TweenInfo = {
	new = function(time, style, direction, repeatCount, reverses, delay)
		return { Time = time or 1, RepeatCount = repeatCount or 0, Reverses = reverses or false }
	end,
}
Rect = {
	new = function(...)
		return { Args = { ... } }
	end,
}
Font = {
	new = function(family)
		return { Family = family }
	end,
	fromEnum = function(e)
		return { Family = e.Name }
	end,
}

---------------------------------------------------------------- classes de interface e valores padrão
for child, parent in pairs({
	GuiBase2d = "Instance",
	GuiObject = "GuiBase2d",
	LayerCollector = "GuiBase2d",
	ScreenGui = "LayerCollector",
	BillboardGui = "LayerCollector",
	SurfaceGui = "LayerCollector",
	Frame = "GuiObject",
	ScrollingFrame = "GuiObject",
	CanvasGroup = "GuiObject",
	ViewportFrame = "GuiObject",
	TextLabel = "GuiObject",
	TextBox = "GuiObject",
	ImageLabel = "GuiObject",
	GuiButton = "GuiObject",
	TextButton = "GuiButton",
	ImageButton = "GuiButton",
	UIComponent = "Instance",
	UIStroke = "UIComponent",
	UICorner = "UIComponent",
	UIGradient = "UIComponent",
	UIScale = "UIComponent",
	UIPadding = "UIComponent",
	UIConstraint = "UIComponent",
	UITextSizeConstraint = "UIConstraint",
	UISizeConstraint = "UIConstraint",
	UIAspectRatioConstraint = "UIConstraint",
	UILayout = "UIComponent",
	UIGridStyleLayout = "UILayout",
	UIListLayout = "UIGridStyleLayout",
	UIGridLayout = "UIGridStyleLayout",
	Camera = "Instance",
	WorldModel = "Model",
	BindableEvent = "Instance",
	BindableFunction = "Instance",
	RemoteEvent = "Instance",
	RemoteFunction = "Instance",
	Folder = "Instance",
	Player = "Instance",
	PlayerGui = "Instance",
	Humanoid = "Instance",
	Attachment = "Instance",
	ParticleEmitter = "Instance",
	Trail = "Instance",
	Beam = "Instance",
	Sound = "Instance",
	SoundGroup = "Instance",
	Highlight = "Instance",
	Workspace = "Model",
	LinearVelocity = "Instance",
}) do
	PARENT_CLASS[child] = parent
end

local white, black = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
DEFAULTS.GuiObject = function()
	return {
		Position = udim2(0, 0, 0, 0),
		Size = udim2(0, 100, 0, 100),
		AnchorPoint = v2(0, 0),
		Visible = true,
		ZIndex = 1,
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(163, 162, 165),
		BorderSizePixel = 1,
		Rotation = 0,
		AutomaticSize = Enum.AutomaticSize.None,
		ClipsDescendants = false,
		LayoutOrder = 0,
		Active = false,
		Selectable = false,
		AbsolutePosition = v2(0, 0),
		AbsoluteSize = v2(100, 100),
	}
end
local function textDefaults(text)
	return function()
		return {
			Text = text,
			TextSize = 14,
			TextScaled = false,
			Font = Enum.Font.Legacy,
			TextColor3 = black,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTransparency = 0,
			TextWrapped = false,
			RichText = false,
			TextStrokeTransparency = 1,
		}
	end
end
DEFAULTS.TextLabel = textDefaults("Label")
DEFAULTS.TextButton = textDefaults("Button")
DEFAULTS.TextBox = textDefaults("")
DEFAULTS.GuiButton = function()
	return { AutoButtonColor = true }
end
DEFAULTS.ImageLabel = function()
	-- (na prévia toda imagem "já carregou")
	return { Image = "", ImageTransparency = 0, ImageColor3 = white, IsLoaded = true }
end
DEFAULTS.ImageButton = DEFAULTS.ImageLabel
DEFAULTS.ViewportFrame = function()
	return {
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.fromRGB(140, 140, 140),
		LightDirection = Vector3.new(-1, -1, -1),
		ImageTransparency = 0,
		ImageColor3 = white,
	}
end
DEFAULTS.ScreenGui = function()
	return { Enabled = true, DisplayOrder = 0, IgnoreGuiInset = false, ResetOnSpawn = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }
end
DEFAULTS.UIStroke = function()
	return { Thickness = 1, Color = black, Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Enabled = true, LineJoinMode = Enum.LineJoinMode.Round }
end
DEFAULTS.UICorner = function()
	return { CornerRadius = udim(0, 8) }
end
DEFAULTS.UIGradient = function()
	return { Color = ColorSequence.new(white), Rotation = 0, Transparency = NumberSequence.new(0), Offset = v2(0, 0), Enabled = true }
end
DEFAULTS.UIScale = function()
	return { Scale = 1 }
end
DEFAULTS.UIPadding = function()
	return { PaddingLeft = udim(0, 0), PaddingRight = udim(0, 0), PaddingTop = udim(0, 0), PaddingBottom = udim(0, 0) }
end
DEFAULTS.UIListLayout = function()
	return {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = udim(0, 0),
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}
end
DEFAULTS.UIGridLayout = function()
	return {
		CellSize = udim2(0, 100, 0, 100),
		CellPadding = udim2(0, 5, 0, 5),
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = 0,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}
end
DEFAULTS.UITextSizeConstraint = function()
	return { MaxTextSize = 100, MinTextSize = 1 }
end
DEFAULTS.UISizeConstraint = function()
	return { MinSize = v2(0, 0), MaxSize = v2(math.huge, math.huge) }
end
DEFAULTS.UIAspectRatioConstraint = function()
	return { AspectRatio = 1 }
end
DEFAULTS.Camera = function()
	return { CFrame = CFrame.new(), FieldOfView = 70, ViewportSize = v2(SCREEN.W, SCREEN.H) }
end
DEFAULTS.Sound = function()
	return { Volume = 0.5, IsPlaying = false, TimePosition = 0, Looped = false, SoundId = "", PlaybackSpeed = 1 }
end
DEFAULTS.SoundGroup = function()
	return { Volume = 0.5 }
end
for _, k in ipairs({ "Play", "Pause", "Resume", "Stop" }) do
	InstMethods[k] = function() end
end
DEFAULTS.Humanoid = function()
	return { Health = 100, MaxHealth = 100, WalkSpeed = 16, MoveDirection = Vector3.new(0, 0, 0) }
end

---------------------------------------------------------------- serviços
local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local Workspace = Instance.new("Workspace")
Workspace.Name = "Workspace"
local camera = Instance.new("Camera")
camera.Name = "Camera"
camera.CFrame = CFrame.lookAt(Vector3.new(0, 20, 40), Vector3.new(0, 0, 0))
camera.Parent = Workspace
Workspace.CurrentCamera = camera
function InstMethods.GetServerTimeNow()
	return 100000
end
workspace = Workspace

local LocalPlayer = Instance.new("Player")
LocalPlayer.Name = "Tester"
LocalPlayer.DisplayName = "Tester"
LocalPlayer.UserId = 1
local playerGui = Instance.new("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = LocalPlayer
folder("PlayerScripts", LocalPlayer)
function InstMethods.GetMouse()
	return { X = 0, Y = 0, Hit = CFrame.new(), Icon = "" }
end

local Players = {
	LocalPlayer = LocalPlayer,
	PlayerAdded = newSignal(),
	PlayerRemoving = newSignal(),
	GetPlayers = function()
		return { LocalPlayer }
	end,
	GetPlayerFromCharacter = function()
		return nil
	end,
}

local function measure(text, size, fontName)
	local adv = METRICS[fontName] or METRICS.FredokaOne
	local w = 0
	for _, code in utf8.codes(text) do
		local ch = utf8.char(code)
		w += (adv[ch] or 60) * size / 100
	end
	return w
end
MEASURE_TEXT = measure

local touch = SCREEN.Touch
SERVICES = {
	Players = Players,
	Workspace = Workspace,
	ReplicatedStorage = folder("ReplicatedStorage"),
	ReplicatedFirst = folder("ReplicatedFirst"),
	StarterPlayer = folder("StarterPlayer"),
	Lighting = folder("Lighting"),
	SoundService = folder("SoundService"),
	UserInputService = {
		TouchEnabled = touch,
		KeyboardEnabled = not touch,
		MouseEnabled = not touch,
		GamepadEnabled = false,
		MouseIconEnabled = true,
		MouseBehavior = Enum.MouseBehavior.Default,
		InputBegan = newSignal(),
		InputEnded = newSignal(),
		InputChanged = newSignal(),
		LastInputTypeChanged = newSignal(),
		TouchStarted = newSignal(),
		TouchEnded = newSignal(),
		JumpRequest = newSignal(),
		GetLastInputType = function()
			return touch and Enum.UserInputType.Touch or Enum.UserInputType.MouseMovement
		end,
		GetFocusedTextBox = function()
			return nil
		end,
		IsKeyDown = function()
			return false
		end,
		GetMouseLocation = function()
			return v2(0, 0)
		end,
		GetConnectedGamepads = function()
			return {}
		end,
	},
	GuiService = {
		GetGuiInset = function()
			return v2(0, SCREEN.Inset), v2(0, 0)
		end,
		MenuOpened = newSignal(),
		MenuClosed = newSignal(),
		SelectedObject = nil,
	},
	RunService = {
		Heartbeat = newSignal(),
		RenderStepped = newSignal(),
		Stepped = newSignal(),
		PreRender = newSignal(),
		BindToRenderStep = function() end,
		UnbindFromRenderStep = function() end,
		IsClient = function()
			return true
		end,
		IsServer = function()
			return false
		end,
		IsStudio = function()
			return false
		end,
	},
	TweenService = {
		Create = function(_, inst, info, props)
			return {
				Completed = newSignal(),
				Cancel = function() end,
				Pause = function() end,
				Play = function()
					-- animação em loop (pulsar, piscar) fica no começo; o resto pula para o fim
					if info and info.RepeatCount and info.RepeatCount ~= 0 then
						return
					end
					for k, v in pairs(props) do
						inst[k] = v
					end
				end,
			}
		end,
	},
	TextService = {
		GetTextSize = function(_, text, size, font)
			return v2(measure(text, size, font and font.Name or "FredokaOne"), size)
		end,
	},
	Debris = { AddItem = function() end },
	StarterGui = {
		SetCoreGuiEnabled = function() end,
		SetCore = function() end,
		GetCore = function()
			return nil
		end,
	},
	CollectionService = {
		GetTagged = function()
			return {}
		end,
		GetInstanceAddedSignal = function()
			return newSignal()
		end,
		GetInstanceRemovedSignal = function()
			return newSignal()
		end,
		HasTag = function()
			return false
		end,
		AddTag = function() end,
		RemoveTag = function() end,
	},
	HttpService = {
		JSONEncode = function()
			return "{}"
		end,
		GenerateGUID = function()
			return "guid"
		end,
	},
	ContextActionService = { BindAction = function() end, UnbindAction = function() end },
	ProximityPromptService = { PromptTriggered = newSignal(), PromptShown = newSignal() },
	MarketplaceService = { PromptProductPurchase = function() end, PromptGamePassPurchase = function() end },
	TeleportService = {},
	VRService = { VREnabled = false },
	ContentProvider = { PreloadAsync = function() end }, -- (Systems/Music e Sfx pré-carregam os áudios)
}
SERVICES.Workspace = Workspace

game = setmetatable({ Workspace = Workspace }, {
	__index = function(_, k)
		if k == "GetService" then
			return function(_, name)
				local s = SERVICES[name]
				assert(s, "serviço sem mock: " .. tostring(name))
				return s
			end
		end
		return SERVICES[k]
	end,
})

return {
	newSignal = newSignal,
	measure = measure,
	playerGui = playerGui,
	LocalPlayer = LocalPlayer,
	folder = folder,
}
