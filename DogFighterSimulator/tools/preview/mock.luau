-- Mini-Roblox de mentirinha para rodar o DogBuilder FORA do Roblox (só para tirar fotos dos cachorros).
-- Tem o básico que o DogBuilder usa: Vector3, CFrame, Color3, Enum, Instance (Part, Weld...), Random.
-- Não tem física nem render: o render.js desenha as peças que o dump.luau imprime.

local function mt(typeName)
	return { __type = typeName }
end

local rawTypeof = typeof
function typeof(v)
	local m = getmetatable(v)
	if type(m) == "table" and rawget(m, "__type") then
		return m.__type
	end
	return rawTypeof(v)
end

---------------------------------------------------------------- Vector3
local V3 = mt("Vector3")
local V3methods = {}
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
V3.__index = function(t, k)
	if k == "Magnitude" then
		return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
	elseif k == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		if m == 0 then
			return v3(0, 0, 0)
		end
		return v3(t.X / m, t.Y / m, t.Z / m)
	elseif k == "x" then
		return t.X
	elseif k == "y" then
		return t.Y
	elseif k == "z" then
		return t.Z
	end
	return V3methods[k]
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(a)
	return string.format("%g, %g, %g", a.X, a.Y, a.Z)
end
function V3methods.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3methods.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3methods.Lerp(a, b, t)
	return a + (b - a) * t
end
function V3methods.Abs(a)
	return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
function V3methods.Min(a, b)
	return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
function V3methods.Max(a, b)
	return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
function V3methods.FuzzyEq(a, b, eps)
	return (a - b).Magnitude <= (eps or 1e-5)
end
Vector3 = {
	new = v3,
	zero = v3(0, 0, 0),
	one = v3(1, 1, 1),
	xAxis = v3(1, 0, 0),
	yAxis = v3(0, 1, 0),
	zAxis = v3(0, 0, 1),
}

local V2 = mt("Vector2")
V2.__index = function(t, k)
	if k == "Magnitude" then
		return math.sqrt(t.X * t.X + t.Y * t.Y)
	end
	return nil
end
Vector2 = {
	new = function(x, y)
		return setmetatable({ X = x or 0, Y = y or 0 }, V2)
	end,
}

---------------------------------------------------------------- CFrame (posição + matriz 3x3; colunas = right, up, back)
local CFm = mt("CFrame")
local CFmethods = {}
local function cfraw(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	return setmetatable({ x = x, y = y, z = z, r00 = r00, r01 = r01, r02 = r02, r10 = r10, r11 = r11, r12 = r12, r20 = r20, r21 = r21, r22 = r22 }, CFm)
end
local function fromCols(p, rx, ry, rz)
	return cfraw(p.X, p.Y, p.Z, rx.X, ry.X, rz.X, rx.Y, ry.Y, rz.Y, rx.Z, ry.Z, rz.Z)
end
CFm.__index = function(c, k)
	if k == "Position" or k == "p" then
		return v3(c.x, c.y, c.z)
	elseif k == "X" then
		return c.x
	elseif k == "Y" then
		return c.y
	elseif k == "Z" then
		return c.z
	elseif k == "RightVector" or k == "XVector" then
		return v3(c.r00, c.r10, c.r20)
	elseif k == "UpVector" or k == "YVector" then
		return v3(c.r01, c.r11, c.r21)
	elseif k == "LookVector" then
		return v3(-c.r02, -c.r12, -c.r22)
	elseif k == "ZVector" then
		return v3(c.r02, c.r12, c.r22)
	elseif k == "Rotation" then
		return cfraw(0, 0, 0, c.r00, c.r01, c.r02, c.r10, c.r11, c.r12, c.r20, c.r21, c.r22)
	end
	return CFmethods[k]
end
local function rot(c, v)
	return v3(c.r00 * v.X + c.r01 * v.Y + c.r02 * v.Z, c.r10 * v.X + c.r11 * v.Y + c.r12 * v.Z, c.r20 * v.X + c.r21 * v.Y + c.r22 * v.Z)
end
local function rotT(c, v)
	return v3(c.r00 * v.X + c.r10 * v.Y + c.r20 * v.Z, c.r01 * v.X + c.r11 * v.Y + c.r21 * v.Z, c.r02 * v.X + c.r12 * v.Y + c.r22 * v.Z)
end
CFm.__mul = function(a, b)
	if typeof(b) == "Vector3" then
		local r = rot(a, b)
		return v3(r.X + a.x, r.Y + a.y, r.Z + a.z)
	end
	local p = rot(a, v3(b.x, b.y, b.z))
	return cfraw(
		p.X + a.x,
		p.Y + a.y,
		p.Z + a.z,
		a.r00 * b.r00 + a.r01 * b.r10 + a.r02 * b.r20,
		a.r00 * b.r01 + a.r01 * b.r11 + a.r02 * b.r21,
		a.r00 * b.r02 + a.r01 * b.r12 + a.r02 * b.r22,
		a.r10 * b.r00 + a.r11 * b.r10 + a.r12 * b.r20,
		a.r10 * b.r01 + a.r11 * b.r11 + a.r12 * b.r21,
		a.r10 * b.r02 + a.r11 * b.r12 + a.r12 * b.r22,
		a.r20 * b.r00 + a.r21 * b.r10 + a.r22 * b.r20,
		a.r20 * b.r01 + a.r21 * b.r11 + a.r22 * b.r21,
		a.r20 * b.r02 + a.r21 * b.r12 + a.r22 * b.r22
	)
end
CFm.__add = function(a, v)
	return cfraw(a.x + v.X, a.y + v.Y, a.z + v.Z, a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22)
end
CFm.__sub = function(a, v)
	return cfraw(a.x - v.X, a.y - v.Y, a.z - v.Z, a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22)
end
function CFmethods.Inverse(c)
	local p = rotT(c, v3(-c.x, -c.y, -c.z))
	return cfraw(p.X, p.Y, p.Z, c.r00, c.r10, c.r20, c.r01, c.r11, c.r21, c.r02, c.r12, c.r22)
end
function CFmethods.ToObjectSpace(a, b)
	return a:Inverse() * b
end
function CFmethods.ToWorldSpace(a, b)
	return a * b
end
function CFmethods.PointToWorldSpace(a, v)
	return a * v
end
function CFmethods.PointToObjectSpace(a, v)
	return a:Inverse() * v
end
function CFmethods.VectorToWorldSpace(a, v)
	return rot(a, v)
end
function CFmethods.VectorToObjectSpace(a, v)
	return rotT(a, v)
end
function CFmethods.GetComponents(c)
	return c.x, c.y, c.z, c.r00, c.r01, c.r02, c.r10, c.r11, c.r12, c.r20, c.r21, c.r22
end
CFmethods.components = CFmethods.GetComponents
function CFmethods.ToEulerAnglesXYZ(c)
	local ry = math.asin(math.clamp(c.r02, -1, 1))
	local rx = math.atan2(-c.r12, c.r22)
	local rz = math.atan2(-c.r01, c.r00)
	return rx, ry, rz
end
-- quaternions para o Lerp
local function toQuat(c)
	local tr = c.r00 + c.r11 + c.r22
	local w, x, y, z
	if tr > 0 then
		local s = math.sqrt(tr + 1) * 2
		w = 0.25 * s
		x = (c.r21 - c.r12) / s
		y = (c.r02 - c.r20) / s
		z = (c.r10 - c.r01) / s
	elseif c.r00 > c.r11 and c.r00 > c.r22 then
		local s = math.sqrt(1 + c.r00 - c.r11 - c.r22) * 2
		w = (c.r21 - c.r12) / s
		x = 0.25 * s
		y = (c.r01 + c.r10) / s
		z = (c.r02 + c.r20) / s
	elseif c.r11 > c.r22 then
		local s = math.sqrt(1 + c.r11 - c.r00 - c.r22) * 2
		w = (c.r02 - c.r20) / s
		x = (c.r01 + c.r10) / s
		y = 0.25 * s
		z = (c.r12 + c.r21) / s
	else
		local s = math.sqrt(1 + c.r22 - c.r00 - c.r11) * 2
		w = (c.r10 - c.r01) / s
		x = (c.r02 + c.r20) / s
		y = (c.r12 + c.r21) / s
		z = 0.25 * s
	end
	return w, x, y, z
end
local function fromQuat(px, py, pz, w, x, y, z)
	local n = math.sqrt(w * w + x * x + y * y + z * z)
	w, x, y, z = w / n, x / n, y / n, z / n
	return cfraw(
		px,
		py,
		pz,
		1 - 2 * (y * y + z * z),
		2 * (x * y - z * w),
		2 * (x * z + y * w),
		2 * (x * y + z * w),
		1 - 2 * (x * x + z * z),
		2 * (y * z - x * w),
		2 * (x * z - y * w),
		2 * (y * z + x * w),
		1 - 2 * (x * x + y * y)
	)
end
function CFmethods.Lerp(a, b, t)
	local aw, ax, ay, az = toQuat(a)
	local bw, bx, by, bz = toQuat(b)
	if aw * bw + ax * bx + ay * by + az * bz < 0 then
		bw, bx, by, bz = -bw, -bx, -by, -bz
	end
	return fromQuat(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t, aw + (bw - aw) * t, ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t)
end
function CFmethods.Orthonormalize(c)
	return c
end

local function angles(rx, ry, rz)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	local X = cfraw(0, 0, 0, 1, 0, 0, 0, cx, -sx, 0, sx, cx)
	local Y = cfraw(0, 0, 0, cy, 0, sy, 0, 1, 0, -sy, 0, cy)
	local Z = cfraw(0, 0, 0, cz, -sz, 0, sz, cz, 0, 0, 0, 1)
	return X * Y * Z
end
local function lookAt(at, target, up)
	up = up or v3(0, 1, 0)
	local look = (target - at).Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(v3(0, 0, 1))
	end
	right = right.Unit
	local up2 = right:Cross(look)
	return fromCols(at, right, up2, -look)
end
CFrame = {
	new = function(a, b, c, ...)
		if a == nil then
			return cfraw(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
		end
		if typeof(a) == "Vector3" then
			if b ~= nil then
				return lookAt(a, b)
			end
			return cfraw(a.X, a.Y, a.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
		end
		local rest = { ... }
		if #rest == 9 then
			return cfraw(a, b, c, table.unpack(rest))
		elseif #rest == 4 then
			-- quaternion qx, qy, qz, qw
			return fromQuat(a, b, c, rest[4], rest[1], rest[2], rest[3])
		end
		return cfraw(a, b, c, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end,
	Angles = angles,
	fromEulerAnglesXYZ = angles,
	fromEulerAnglesYXZ = function(rx, ry, rz)
		return angles(0, ry, 0) * angles(rx, 0, 0) * angles(0, 0, rz)
	end,
	fromOrientation = function(rx, ry, rz)
		return angles(0, ry, 0) * angles(rx, 0, 0) * angles(0, 0, rz)
	end,
	lookAt = lookAt,
	fromMatrix = function(p, vx, vy, vz)
		vz = vz or vx:Cross(vy).Unit
		return fromCols(p, vx, vy, vz)
	end,
	fromAxisAngle = function(axis, a)
		local u = axis.Unit
		local s = math.sin(a / 2)
		return fromQuat(0, 0, 0, math.cos(a / 2), u.X * s, u.Y * s, u.Z * s)
	end,
}
CFrame.identity = CFrame.new()

---------------------------------------------------------------- Color3 e sequências
local C3 = mt("Color3")
local C3methods = {}
C3.__index = C3methods
local function c3(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
end
function C3methods.Lerp(a, b, t)
	return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function C3methods.ToHSV(c)
	local r, g, b = c.R, c.G, c.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then
			h = ((g - b) / d) % 6
		elseif mx == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h /= 6
	end
	return h, mx == 0 and 0 or d / mx, mx
end
function C3methods.ToHex(c)
	local function byte(v)
		return math.clamp(math.floor(v * 255 + 0.5), 0, 255)
	end
	return string.format("%02X%02X%02X", byte(c.R), byte(c.G), byte(c.B))
end
C3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
Color3 = {
	new = c3,
	fromRGB = function(r, g, b)
		return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
	end,
	fromHSV = function(h, s, v)
		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		i %= 6
		if i == 0 then
			return c3(v, t, p)
		elseif i == 1 then
			return c3(q, v, p)
		elseif i == 2 then
			return c3(p, v, t)
		elseif i == 3 then
			return c3(p, q, v)
		elseif i == 4 then
			return c3(t, p, v)
		end
		return c3(v, p, q)
	end,
}
BrickColor = {
	new = function(name)
		return { Name = name, Color = c3(0.6, 0.6, 0.6) }
	end,
}
local function seq(typeName)
	return {
		new = function(...)
			return setmetatable({ Args = { ... } }, mt(typeName))
		end,
	}
end
NumberSequence = seq("NumberSequence")
NumberSequenceKeypoint = seq("NumberSequenceKeypoint")
ColorSequence = seq("ColorSequence")
ColorSequenceKeypoint = seq("ColorSequenceKeypoint")
NumberRange = seq("NumberRange")
UDim2 = seq("UDim2")
UDim = seq("UDim")
PhysicalProperties = seq("PhysicalProperties")

---------------------------------------------------------------- Enum (itens criados na hora, sempre o mesmo objeto)
local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, enumName)
		local items = enumCache[enumName]
		if not items then
			items = setmetatable({}, {
				__index = function(t, itemName)
					-- (Value: número estável por nome — o jogo soma em RenderPriority.Camera.Value + 1 etc.)
					local value = ({ Camera = 200, Character = 300, Input = 100, First = 0, Last = 2000 })[itemName] or 0
					local item = setmetatable({ Name = itemName, EnumType = enumName, Value = value }, {
						__type = "EnumItem",
						__tostring = function()
							return "Enum." .. enumName .. "." .. itemName
						end,
					})
					rawset(t, itemName, item)
					return item
				end,
			})
			enumCache[enumName] = items
		end
		return items
	end,
})

---------------------------------------------------------------- Random (determinístico)
local RandomMt = { __type = "Random" }
RandomMt.__index = RandomMt
function RandomMt:_next()
	self.s = (self.s * 1103515245 + 12345) % 2147483648
	return self.s / 2147483648
end
function RandomMt:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + (b - a) * self:_next()
end
function RandomMt:NextInteger(a, b)
	return a + math.floor(self:_next() * (b - a + 1))
end
Random = {
	new = function(seed)
		local r = setmetatable({ s = math.floor(math.abs(seed or 1)) % 2147483648 + 1 }, RandomMt)
		return r
	end,
}

---------------------------------------------------------------- Instance
local PARENT_CLASS = {
	Part = "BasePart",
	WedgePart = "BasePart",
	MeshPart = "BasePart",
	CornerWedgePart = "BasePart",
	TrussPart = "BasePart",
	BasePart = "PVInstance",
	Model = "PVInstance",
	PVInstance = "Instance",
	Weld = "JointInstance",
	Motor6D = "JointInstance",
	JointInstance = "Instance",
	WeldConstraint = "Instance",
	SpecialMesh = "DataModelMesh",
	DataModelMesh = "Instance",
	ModuleScript = "LuaSourceContainer",
	Script = "BaseScript",
	LocalScript = "Script",
	BaseScript = "LuaSourceContainer",
	LuaSourceContainer = "Instance",
	PointLight = "Light",
	SpotLight = "Light",
	Light = "Instance",
}
local DEFAULTS = {
	BasePart = function()
		return {
			Size = v3(4, 1, 2),
			CFrame = CFrame.new(),
			Color = c3(0.64, 0.64, 0.64),
			Material = Enum.Material.Plastic,
			Transparency = 0,
			Reflectance = 0,
			Shape = Enum.PartType.Block,
			Anchored = false,
			CanCollide = true,
			Massless = false,
		}
	end,
	JointInstance = function()
		return { C0 = CFrame.new(), C1 = CFrame.new(), Transform = CFrame.new(), Enabled = true }
	end,
}

local Inst = { __type = "Instance" }
local InstMethods = {}

local function isA(className, target)
	local c = className
	while c do
		if c == target then
			return true
		end
		c = PARENT_CLASS[c] or (c ~= "Instance" and "Instance" or nil)
	end
	return false
end

Inst.__index = function(self, k)
	local props = rawget(self, "_props")
	local v = props[k]
	if v ~= nil then
		return v
	end
	if k == "Position" and props.CFrame then
		return props.CFrame.Position
	elseif k == "Orientation" then
		return v3(0, 0, 0)
	end
	local m = InstMethods[k]
	if m then
		return m
	end
	for _, child in ipairs(rawget(self, "_children")) do
		if child._props.Name == k then
			return child
		end
	end
	return nil
end
Inst.__newindex = function(self, k, v)
	local props = rawget(self, "_props")
	if k == "Parent" then
		local old = props.Parent
		if old then
			local list = rawget(old, "_children")
			local i = table.find(list, self)
			if i then
				table.remove(list, i)
			end
		end
		props.Parent = v
		if v then
			table.insert(rawget(v, "_children"), self)
		end
		return
	end
	if k == "Position" and props.CFrame then
		props.CFrame = props.CFrame.Rotation + v
		return
	end
	if k == "Shape" and v and (v.Name == "Ball") and props.Size then
		local m = math.min(props.Size.X, props.Size.Y, props.Size.Z)
		props.Size = v3(m, m, m)
	end
	props[k] = v
	local listeners = rawget(self, "_changed")[k]
	if listeners then
		for _, fn in ipairs(listeners) do
			fn()
		end
	end
end
Inst.__tostring = function(self)
	return self._props.Name
end

local function newInstance(className)
	local props = { ClassName = className, Name = className, Archivable = true }
	local c = className
	while c do
		local d = DEFAULTS[c]
		if d then
			for k, v in pairs(d()) do
				props[k] = v
			end
		end
		c = PARENT_CLASS[c]
	end
	return setmetatable({ _props = props, _children = {}, _attrs = {}, _changed = {} }, Inst)
end

function InstMethods.IsA(self, name)
	return isA(self._props.ClassName, name)
end
function InstMethods.GetChildren(self)
	return table.clone(self._children)
end
function InstMethods.GetDescendants(self)
	local out = {}
	local function walk(i)
		for _, c in ipairs(i._children) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function InstMethods.FindFirstChild(self, name, recursive)
	for _, c in ipairs(self._children) do
		if c._props.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in ipairs(self._children) do
			local f = c:FindFirstChild(name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
InstMethods.WaitForChild = InstMethods.FindFirstChild
function InstMethods.FindFirstChildOfClass(self, className)
	for _, c in ipairs(self._children) do
		if c._props.ClassName == className then
			return c
		end
	end
	return nil
end
function InstMethods.FindFirstChildWhichIsA(self, className)
	for _, c in ipairs(self._children) do
		if c:IsA(className) then
			return c
		end
	end
	return nil
end
function InstMethods.IsDescendantOf(self, ancestor)
	local p = self.Parent
	while p do
		if p == ancestor then
			return true
		end
		p = p.Parent
	end
	return false
end
function InstMethods.IsAncestorOf(self, descendant)
	return descendant:IsDescendantOf(self)
end
function InstMethods.FindFirstAncestorOfClass(self, className)
	local p = self._props.Parent
	while p do
		if p._props.ClassName == className then
			return p
		end
		p = p._props.Parent
	end
	return nil
end
function InstMethods.SetAttribute(self, k, v)
	self._attrs[k] = v
end
function InstMethods.GetAttribute(self, k)
	return self._attrs[k]
end
function InstMethods.GetAttributes(self)
	return table.clone(self._attrs)
end
function InstMethods.GetPropertyChangedSignal(self, prop)
	return {
		Connect = function(_, fn)
			local list = self._changed[prop] or {}
			self._changed[prop] = list
			table.insert(list, fn)
			return { Disconnect = function() end }
		end,
	}
end
function InstMethods.Destroy(self)
	self.Parent = nil
	for _, c in ipairs(table.clone(self._children)) do
		c:Destroy()
	end
end
function InstMethods.ClearAllChildren(self)
	for _, c in ipairs(table.clone(self._children)) do
		c:Destroy()
	end
end
function InstMethods.Clone(self)
	local map = {}
	local function copy(i)
		local n = newInstance(i._props.ClassName)
		map[i] = n
		for k, v in pairs(i._props) do
			if k ~= "Parent" then
				n._props[k] = v
			end
		end
		for k, v in pairs(i._attrs) do
			n._attrs[k] = v
		end
		for _, c in ipairs(i._children) do
			local cc = copy(c)
			cc.Parent = n
		end
		return n
	end
	local root = copy(self)
	-- referências dentro da cópia apontam para as peças copiadas (como no Roblox)
	for _, n in pairs(map) do
		for k, v in pairs(n._props) do
			if k ~= "Parent" and type(v) == "table" and map[v] then
				n._props[k] = map[v]
			end
		end
	end
	return root
end
function InstMethods.GetPivot(self)
	if self._props.ClassName == "Model" then
		local pp = self._props.PrimaryPart
		return pp and pp._props.CFrame or CFrame.new()
	end
	return self._props.CFrame
end
function InstMethods.PivotTo(self, cf)
	local old = self:GetPivot()
	local delta = cf * old:Inverse()
	if self._props.ClassName == "Model" then
		for _, d in ipairs(self:GetDescendants()) do
			if d:IsA("BasePart") then
				d._props.CFrame = delta * d._props.CFrame
			end
		end
	else
		self._props.CFrame = cf
	end
end
function InstMethods.ScaleTo() end
function InstMethods.GetScale()
	return 1
end

Instance = {
	new = function(className, parent)
		local i = newInstance(className)
		if parent then
			i.Parent = parent
		end
		return i
	end,
}

---------------------------------------------------------------- globais diversas
function warn(...)
	print("[warn]", ...)
end
-- task.spawn roda a função numa corrotina; dentro dela task.wait pausa para sempre (laços infinitos de
-- animação no servidor não travam o preview). Fora de corrotina task.wait não espera.
local spawned = setmetatable({}, { __mode = "k" })
local function spawnCo(fn, ...)
	local co = coroutine.create(fn)
	spawned[co] = true
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		print("[task.spawn erro]", err)
	end
	return co
end
task = {
	wait = function()
		local co = coroutine.running()
		if co and spawned[co] then
			coroutine.yield()
		end
		return 0
	end,
	spawn = spawnCo,
	defer = spawnCo,
	delay = function() end,
}
tick = os.clock
time = os.clock

return {
	newInstance = newInstance,
	-- partes internas (o mini-Roblox de telas em tools/hud_preview/mock_gui.luau estende estas)
	PARENT_CLASS = PARENT_CLASS,
	DEFAULTS = DEFAULTS,
	InstMethods = InstMethods,
	Inst = Inst,
	spawned = spawned,
}
