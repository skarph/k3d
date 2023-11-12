--based on hump's vector-light
--https://github.com/vrld/hump/blob/master/vector-light.lua
local function setChildrenPosition(obj, x,y)
	obj:setPosition(x,y)
	for _,child in ipairs(obj.children) do
		setChildrenPosition(obj, x,y)
	end
end
--dependencies(?)
local sqrt, cos, sin, atan2 = math.sqrt, math.cos, math.sin, math.atan2

local function str(x,y,z)
	return "("..tonumber(x)..","..tonumber(y)..","..tonumber(z)..")"
end

local function scale(s, x,y,z)
	return s*x, s*y, s*z
end

local function div(s, x,y,z)
	return x/s, y/s, y/s
end

local function add(x1,y1,z1, x2,y2,z2)
	return x1+x2, y1+y2, z1+z2
end

local function sub(x1,y1,z1, x2,y2,z2)
	return x1-x2, y1-y2, z1-z2
end

local function permul(x1,y1,z1, x2,y2,z2)
	return x1*x2, y1*y2, z1*z2
end

local function dot(x1,y1,z1, x2,y2,z2)
	return x1*x2 + y1*y2 + z1*z2
end

local function cross(x1,y1,z1, x2,y2,z2)
	return
		  y1*z2 - z1*y2,
		  z1*x2 - x1*z2,
		  x1*y2 - y1*x2
end
--[[
local function det(x1,y1, x2,y2)
	return x1*y2 - y1*x2
end
]]

local function eq(x1,y1,z1, x2,y2,z2)
	return x1 == x2 and y1 == y2 and z1 == z2
end

--[[
local function lt(x1,y1, x2,y2)
	return x1 < x2 or (x1 == x2 and y1 < y2)
end

local function le(x1,y1, x2,y2)
	return x1 <= x2 and y1 <= y2
end
]]

local function len2(x,y,z)
	return x*x + y*y + z*z
end

local function len(x,y,z)
	return sqrt(x*x + y*y + z*z)
end

--[[
local function fromPolar(angle, radius)
	radius = radius or 1
	return cos(angle)*radius, sin(angle)*radius
end

local function randomDirection(len_min, len_max)
	len_min = len_min or 1
	len_max = len_max or len_min

	assert(len_max > 0, "len_max must be greater than zero")
	assert(len_max >= len_min, "len_max must be greater than or equal to len_min")

	return fromPolar(math.random()*2*math.pi,
	                 math.random() * (len_max-len_min) + len_min)
end

local function toPolar(x, y)
	return atan2(y,x), len(x,y)
end
]]

local function dist2(x1,y1,z1, x2,y2,z2)
	return len2(x1-x2, y1-y2, z1-z2)
end

local function dist(x1,y1,z1, x2,y2,z2)
	return len(x1-x2, y1-y2, z1-z2)
end

local function normalize(x,y,z)
	local l = len(x,y,z)
	if l > 0 then
		return x/l, y/l, z/l
	end
	return x,y,z
end

--[[
local function rotate(phi, x,y)
	local c, s = cos(phi), sin(phi)
	return c*x - s*y, s*x + c*y
end

local function perpendicular(x,y)
	return -y, x
end

local function project(x,y, u,v)
	local s = (x*u + y*v) / (u*u + v*v)
	return s*u, s*v
end

local function mirror(x,y, u,v)
	local s = 2 * (x*u + y*v) / (u*u + v*v)
	return s*u - x, s*v - y
end

-- ref.: http://blog.signalsondisplay.com/?p=336
local function trim(maxLen, x, y)
	local s = maxLen * maxLen / len2(x, y)
	s = s > 1 and 1 or math.sqrt(s)
	return x * s, y * s
end

local function angleTo(x,y, u,v)
	if u and v then
		return atan2(y, x) - atan2(v, u)
	end
	return atan2(y, x)
end
]]

-- the module
return {
	str = str,

	-- arithmetic
	div    = div,
	add    = add,
	sub    = sub,
    scale  = scale,
	permul = permul,
	dot    = dot,
	cross  = cross,

	-- relation
	eq = eq,

	-- misc operations
	len2          = len2,
	len           = len,
	dist2         = dist2,
	dist          = dist,
	normalize     = normalize,
}