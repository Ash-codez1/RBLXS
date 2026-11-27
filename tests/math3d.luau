--[[
	Vector3 and CFrame for the Lune test harness, following Roblox's conventions:
	right-handed, Y up, LookVector = -Z column, CFrame.Angles(rx, ry, rz) = Rx * Ry * Rz.
	Only what the game's world code uses. Not shipped to Roblox.
]]

local M = {}

-- ===== Vector3 =====
local V3 = {}
local V3methods = {}

local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, _type = "Vector3" }, V3)
end

V3.__index = function(v, key)
	if key == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif key == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then
			return v3(0, 0, 0)
		end
		return v3(v.X / m, v.Y / m, v.Z / m)
	elseif key == "x" then
		return v.X
	elseif key == "y" then
		return v.Y
	elseif key == "z" then
		return v.Z
	end
	return V3methods[key]
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
V3.__tostring = function(v)
	return ("%g, %g, %g"):format(v.X, v.Y, v.Z)
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
function V3methods.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	return math.abs(a.X - b.X) <= eps and math.abs(a.Y - b.Y) <= eps and math.abs(a.Z - b.Z) <= eps
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

M.Vector3 = {
	new = v3,
	zero = v3(0, 0, 0),
	one = v3(1, 1, 1),
	xAxis = v3(1, 0, 0),
	yAxis = v3(0, 1, 0),
	zAxis = v3(0, 0, 1),
}

-- ===== CFrame =====
-- Stored as position (x, y, z) and a row-major rotation matrix r[1..9]:
-- | r1 r2 r3 |   columns: RightVector, UpVector, -LookVector
-- | r4 r5 r6 |
-- | r7 r8 r9 |
local CF = {}
local CFmethods = {}

local function cf(x, y, z, r)
	return setmetatable({ _x = x, _y = y, _z = z, _r = r, _type = "CFrame" }, CF)
end

local IDENTITY = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }

local function matMul(a, b)
	return {
		a[1] * b[1] + a[2] * b[4] + a[3] * b[7], a[1] * b[2] + a[2] * b[5] + a[3] * b[8], a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
		a[4] * b[1] + a[5] * b[4] + a[6] * b[7], a[4] * b[2] + a[5] * b[5] + a[6] * b[8], a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
		a[7] * b[1] + a[8] * b[4] + a[9] * b[7], a[7] * b[2] + a[8] * b[5] + a[9] * b[8], a[7] * b[3] + a[8] * b[6] + a[9] * b[9],
	}
end

local function transpose(r)
	return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
end

local function rotate(r, x, y, z)
	return r[1] * x + r[2] * y + r[3] * z, r[4] * x + r[5] * y + r[6] * z, r[7] * x + r[8] * y + r[9] * z
end

local function rx(a)
	local c, s = math.cos(a), math.sin(a)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function ry(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rz(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end

local function lookAt(at, target, up)
	up = up or v3(0, 1, 0)
	local look = (target - at).Unit
	if look.Magnitude == 0 then
		return cf(at.X, at.Y, at.Z, table.clone(IDENTITY))
	end
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(v3(0, 0, 1))
	end
	right = right.Unit
	local realUp = right:Cross(look).Unit
	-- columns: right, up, -look
	return cf(at.X, at.Y, at.Z, { right.X, realUp.X, -look.X, right.Y, realUp.Y, -look.Y, right.Z, realUp.Z, -look.Z })
end

CF.__index = function(c, key)
	local r = c._r
	if key == "Position" or key == "p" then
		return v3(c._x, c._y, c._z)
	elseif key == "X" then
		return c._x
	elseif key == "Y" then
		return c._y
	elseif key == "Z" then
		return c._z
	elseif key == "LookVector" then
		return v3(-r[3], -r[6], -r[9])
	elseif key == "RightVector" then
		return v3(r[1], r[4], r[7])
	elseif key == "UpVector" then
		return v3(r[2], r[5], r[8])
	elseif key == "Rotation" then
		return cf(0, 0, 0, table.clone(r))
	end
	return CFmethods[key]
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		local x, y, z = rotate(a._r, b._x, b._y, b._z)
		return cf(a._x + x, a._y + y, a._z + z, matMul(a._r, b._r))
	end
	local x, y, z = rotate(a._r, b.X, b.Y, b.Z)
	return v3(a._x + x, a._y + y, a._z + z)
end
CF.__add = function(a, b)
	return cf(a._x + b.X, a._y + b.Y, a._z + b.Z, table.clone(a._r))
end
CF.__sub = function(a, b)
	return cf(a._x - b.X, a._y - b.Y, a._z - b.Z, table.clone(a._r))
end
CF.__eq = function(a, b)
	if a._x ~= b._x or a._y ~= b._y or a._z ~= b._z then
		return false
	end
	for i = 1, 9 do
		if a._r[i] ~= b._r[i] then
			return false
		end
	end
	return true
end
CF.__tostring = function(c)
	return ("CFrame(%g, %g, %g)"):format(c._x, c._y, c._z)
end

function CFmethods.Inverse(c)
	local t = transpose(c._r)
	local x, y, z = rotate(t, -c._x, -c._y, -c._z)
	return cf(x, y, z, t)
end
function CFmethods.ToWorldSpace(c, other)
	return c * other
end
function CFmethods.ToObjectSpace(c, other)
	return c:Inverse() * other
end
function CFmethods.PointToWorldSpace(c, v)
	return c * v
end
function CFmethods.PointToObjectSpace(c, v)
	return c:Inverse() * v
end
function CFmethods.VectorToWorldSpace(c, v)
	local x, y, z = rotate(c._r, v.X, v.Y, v.Z)
	return v3(x, y, z)
end
function CFmethods.VectorToObjectSpace(c, v)
	local x, y, z = rotate(transpose(c._r), v.X, v.Y, v.Z)
	return v3(x, y, z)
end
function CFmethods.Lerp(a, b, t)
	-- Position lerp + normalised matrix lerp: close enough for tests.
	local r = {}
	for i = 1, 9 do
		r[i] = a._r[i] + (b._r[i] - a._r[i]) * t
	end
	local out = cf(a._x + (b._x - a._x) * t, a._y + (b._y - a._y) * t, a._z + (b._z - a._z) * t, r)
	local look = out.LookVector
	if look.Magnitude < 1e-6 then
		return cf(out._x, out._y, out._z, table.clone(b._r))
	end
	local pos = out.Position
	return lookAt(pos, pos + look.Unit, out.UpVector)
end
function CFmethods.GetComponents(c)
	local r = c._r
	return c._x, c._y, c._z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]
end
CFmethods.components = CFmethods.GetComponents
function CFmethods.ToOrientation(c)
	-- Roblox orientation order is YXZ (radians).
	local r = c._r
	local x = math.asin(math.clamp(-r[6], -1, 1))
	local y = math.atan2(r[3], r[9])
	local z = math.atan2(r[4], r[5])
	return x, y, z
end

M.CFrame = {
	new = function(a, b, c, ...)
		if a == nil then
			return cf(0, 0, 0, table.clone(IDENTITY))
		end
		if type(a) == "table" then
			if b ~= nil then
				return lookAt(a, b) -- CFrame.new(pos, lookAt)
			end
			return cf(a.X, a.Y, a.Z, table.clone(IDENTITY))
		end
		local rest = { ... }
		if #rest == 9 then
			return cf(a, b, c, rest)
		end
		return cf(a, b, c, table.clone(IDENTITY))
	end,
	Angles = function(x, y, z)
		return cf(0, 0, 0, matMul(matMul(rx(x or 0), ry(y or 0)), rz(z or 0)))
	end,
	fromEulerAnglesYXZ = function(x, y, z)
		return cf(0, 0, 0, matMul(matMul(ry(y or 0), rx(x or 0)), rz(z or 0)))
	end,
	lookAt = lookAt,
	fromMatrix = function(pos, right, up, back)
		back = back or right:Cross(up)
		return cf(pos.X, pos.Y, pos.Z, { right.X, up.X, back.X, right.Y, up.Y, back.Y, right.Z, up.Z, back.Z })
	end,
	identity = cf(0, 0, 0, table.clone(IDENTITY)),
}
M.CFrame.fromEulerAnglesXYZ = M.CFrame.Angles
M.CFrame.fromOrientation = M.CFrame.fromEulerAnglesYXZ

M.isCFrame = function(value)
	return getmetatable(value) == CF
end
M.isVector3 = function(value)
	return getmetatable(value) == V3
end

return M
