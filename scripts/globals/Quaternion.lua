--fast quaternions for lua by skarph

--dependencies(?)
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos
local acos = math.acos
local exp = math.exp
--ok done with thatj

--quaternions sans tables--
local function add(ar,ai,aj,ak, br,bi,bj,bk)
    return ar+br, ai+bi, aj+bj, ak+bk
end


local function sub(ar,ai,aj,ak, br,bi,bj,bk)
    return ar-br, ai-bi, aj-bj, ak-bk
end

local function smul(s, ar,ai,aj,ak) --scalar multiply
    return s*ar, s*ai, s*aj, s*ak
end

-- q1*q2 := qmulc(q1, q2) 
local function qmul(ar,ai,aj,ak, br,bi,bj,bk) --quaternion multiplication
    return
        ar*br - ai*bi - aj*bj - ak*bk,
        ar*bi + ai*br + aj*bk - ak*bj,
        ar*bj - ai*bk + aj*br + ak*bi,
        ar*bk + ai*bj - aj*bi + ak*br
end

-- q2*q1 := qmulc(q1, q2) 
--c for commuted
local function qmulc(br,bi,bj,bk, ar,ai,aj,ak) --quaternion multiplication
    return
        ar*br - ai*bi - aj*bj - ak*bk,
        ar*bi + ai*br + aj*bk - ak*bj,
        ar*bj - ai*bk + aj*br + ak*bi,
        ar*bk + ai*bj - aj*bi + ak*br
end

local function mag(ar,ai,aj,ak)
    return sqrt(ar*ar+ai*ai+aj*aj+ak*ak)
end

local function magSquare(ar,ai,aj,ak)
    return ar*ar+ai*ai+aj*aj+ak*ak
end

local function conj(ar,ai,aj,ak) --Quaternion Conjugation
    return ar,-ai,-aj,-ak
end

local function qlog(ar,ai,aj,ak) --natural log, only for normalized quaternions
    ar = acos(ar)--internal angle
    return 0,ai*ar,aj*ar,ak*ar
end

local function qexp(ar,ai,aj,ak) --exponential function, any quaternion
    local vecMag = sqrt(ai*ai+aj*aj+ak*ak)
    if(vecMag==0) then --e^1 = 1
        return 1,0,0,0
    end
    local e = exp(ar)
    local c = e*cos(vecMag)
    local s = e*sin(vecMag)/vecMag
    return c+ar*s,c+ai*s,c+aj*s,c+ak*s
end

local function spow(ar,ai,aj,ak, t) --Quaternion-scalar exponentation
    local r, i, j, k = qlog(ar,ai,aj,ak)
    r, i, j, k = smul(r,i,j,k, t)
    return qexp( r, i, j, k )
end

local function qpow(ar,ai,aj,ak, br,bi,bj,bk) --Quaternion-quaternion exponentation 
    local r, i, j, k = qlog(ar,ai,aj,ak)
    r, i, j, k = qmul(r,i,j,k, br,bi,bj,bk)
    return qexp( r, i, j, k )
end

local function normalize(ar,ai,aj,ak) --Normalizes a Quaternion
    local m = 1/sqrt(ar*ar+ai*ai+aj*aj+ak*ak)
    return ar*m, ai*m, aj*m, ak*m
end

local function inverse(ar,ai,aj,ak) --Gets the inverse of a Quaternion
    local m = 1/(ar*ar+ai*ai+aj*aj+ak*ak)
    return ar*m,-ai*m,-aj*m,-ak*m
end

local function rotate(x,y,z, ar,ai,aj,ak) --Rotates a 3-vector [vector] using Quaternion [rotQ]
    local w
    w,x,y,z = qmul(ar,ai,aj,ak, 0,x,y,z)
    w,x,y,z = qmul(w,x,y,z, ar,-ai,-aj,-ak)
    return x,y,z
end

local function fromaa(a, x,y,z) --makes quaternion from axis-angle
    local s = sin(0.5*a) --/sqrt(x*x+y*y+z*z)
    return cos(0.5*a),x*s,y*s,z*s
end

local function slerp(ar,ai,aj,ak, br,bi,bj,bk, t) --slerp from a to b at t
    local r, i, j, k = qmul(ar,-ai,-aj,-ak, br,bi,bj,bk)
    r, i, j, k = spow(r, i, j, k, t)
    return qmul(ar,ai,aj,ak, r, i, j, k)
end

--x, y, z vetor order i think?
local function frombasisvectors(ax,ay,az, bx,by,bz, cx,cy,cz) --follows right hand rule.
    local trace = ax+by+cz

    if(trace > 0) then --implied epsilon is 0
        local f = 2 * math.sqrt(1+trace) -- 4*real
        return 0.25*f, (cy-bz)/f, (az-cx)/f, (bx-ay)/f
    elseif((ax > by) and (ax > cz)) then --is x biggest?
        local f = 2 * math.sqrt(1+ax-by-cz) -- 4*i
        return (cy-bz)/f, 0.25*f, (ay+bx)/f, (az+cx)/f
    elseif(by > cz) then -- is y biggest?
        local f = 2 * math.sqrt(1-ax+by-cz) -- 4*j
        return (az-cx)/f, (ay+bx)/f, 0.25*f, (bz+cy)/f
    else --assume z is biggest. give up.
        local f = 2 * math.sqrt(1-ax-by+cz) -- 4*k
        return (bx-ay)/f, (az+cx)/f, (bz+cy)/f, 0.25*f
    end
end

local function shortestrot(ax,ay,az, bx,by,bz) --returns the quaterion representing the rotation with the shortest arclength from a to b, where both are unit vectors
    local r,i,j,k = qmul(0,ax,ay,az, 0,bx,by,bz)
        if(r > 0.9999) then --are vectors parallel?
    return 0,j,-i,k --return a 180 degree turn about an axis that *isnt* the vector
        end
    return 1-r,i,j,k
end

--https://en.wikipedia.org/wiki/Conversion_between_quaternions_and_Euler_angles
-- roll (x), pitch (y), yaw (z), angles are in radians
local function fromea(roll, pitch, yaw)
    local cr = cos(roll * 0.5);
    local sr = sin(roll * 0.5);
    local cp = cos(pitch * 0.5);
    local sp = sin(pitch * 0.5);
    local cy = cos(yaw * 0.5);
    local sy = sin(yaw * 0.5);

    return
    cr * cp * cy + sr * sp * sy,
    sr * cp * cy - cr * sp * sy,
    cr * sp * cy + sr * cp * sy,
    cr * cp * sy - sr * sp * cy

end

local function tostring(r,i,j,k)
    return string.format("%+f %+fi %+fj %+fk",r,i,j,k)
end
--[[
  function Quaternion.__equ(a,b)
    if(getmetatable(a)~=Quaternion or getmetatable(b)~=Quaternion) then return end
    return a.r==b.r and a.i==b.i and a.j==b.j and a.k==b.k
  end
  ]]


return {
    add = add,
    sub = sub,
    smul = smul,
    qmul = qmul,
    qmulc = qmulc,
    mag = mag,
    magSquare = magSquare,
    conj = conj,
    qlog = qlog,
    qexp = qexp,
    spow = spow,
    qpow = qpow,
    normalize = normalize,
    inverse = inverse,
    rotate = rotate,
    fromaa = fromaa,
    slerp = slerp,
    frombasisvectors = frombasisvectors,
    shortestrot = shortestrot,
    fromea = fromea,
    tostring = tostring
}