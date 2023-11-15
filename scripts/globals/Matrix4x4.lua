-- written by groverbuger for g3d edited by skarph for k3d
-- september 2021
-- MIT license
--depdendencies
local Vector = libRequire("k3d","scripts.globals.Vector3")
local vectorCrossProduct = Vector.cross
local vectorDotProduct = Vector.dot
local vectorNormalize = Vector.normalize

local Quaternion = libRequire("k3d","scripts.globals.Quaternion")
local q_rotate = Quaternion.rotate
local q_from_basis_vectors = Quaternion.frombasisvectors
local q_inverse = Quaternion.inverse
----------------------------------------------------------------------------------------------------
-- matrix class
----------------------------------------------------------------------------------------------------
-- matrices are 16 numbers in table, representing a 4x4 matrix like so:
--
-- |  1[00]   2[01]   3[02]   4[03]  |
-- |                                 |
-- |  5[10]   6[11]   7[12]   8[13]  |
-- |                                 |
-- |  9[20]   10[21]  11[22]  12[23] |
-- |                                 |
-- |  13[30]  14[31]  15[32]  16[33] |

local matrix = {}
matrix.__index = matrix

local function newMatrix(a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p)
    local self = setmetatable({}, matrix)
    if(a) then
        if(b) then
            self:set(a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p)
        else
            self:set(unpack(a))
        end
    else
        -- initialize a matrix as the identity matrix
        self[1],  self[2],  self[3],  self[4]  = 1, 0, 0, 0
        self[5],  self[6],  self[7],  self[8]  = 0, 1, 0, 0
        self[9],  self[10], self[11], self[12] = 0, 0, 1, 0
        self[13], self[14], self[15], self[16] = 0, 0, 0, 1
    end
    return self
end

function matrix:clone()
    return newMatrix(self)
end
-- automatically converts a matrix to a string
-- for printing to console and debugging
function matrix:__tostring()
    return ("%+f,\t%+f,\t%+f,\t%+f,\n%+f,\t%+f,\t%+f,\t%+f,\n%+f,\t%+f,\t%+f,\t%+f,\n%+f,\t%+f,\t%+f,\t%+f,"):format(unpack(self))
end

----------------------------------------------------------------------------------------------------
-- transformation, projection, and rotation matrices
----------------------------------------------------------------------------------------------------
-- the three most important matrices for 3d graphics
-- these three matrices are all you need to write a simple 3d shader

-- returns a transformation matrix
-- translation, rotation, and scale are all 3d vectors
-- given euler angles
-- unused for now?
--[[
function matrix:setTransformationMatrix(translation, rotation, scale)
    -- translations
    self[4]  = translation[1]
    self[8]  = translation[2]
    self[12] = translation[3]

    -- rotations
    if #rotation == 3 then
        -- use 3D rotation vector as euler angles
        -- source: https://en.wikipedia.org/wiki/Rotation_matrix
        local ca, cb, cc = math.cos(rotation[3]), math.cos(rotation[2]), math.cos(rotation[1])
        local sa, sb, sc = math.sin(rotation[3]), math.sin(rotation[2]), math.sin(rotation[1])
        self[1], self[2],  self[3]  = ca*cb, ca*sb*sc - sa*cc, ca*sb*cc + sa*sc
        self[5], self[6],  self[7]  = sa*cb, sa*sb*sc + ca*cc, sa*sb*cc - ca*sc
        self[9], self[10], self[11] = -sb, cb*sc, cb*cc
    else
        -- use 4D rotation vector as a quaternion
        local qx, qy, qz, qw = rotation[1], rotation[2], rotation[3], rotation[4]
        self[1], self[2],  self[3]  = 1 - 2*qy^2 - 2*qz^2, 2*qx*qy - 2*qz*qw,   2*qx*qz + 2*qy*qw
        self[5], self[6],  self[7]  = 2*qx*qy + 2*qz*qw,   1 - 2*qx^2 - 2*qz^2, 2*qy*qz - 2*qx*qw
        self[9], self[10], self[11] = 2*qx*qz - 2*qy*qw,   2*qy*qz + 2*qx*qw,   1 - 2*qx^2 - 2*qy^2
    end

    -- scale
    local sx, sy, sz = scale[1], scale[2], scale[3]
    self[1], self[2],  self[3]  = self[1] * sx, self[2]  * sy, self[3]  * sz
    self[5], self[6],  self[7]  = self[5] * sx, self[6]  * sy, self[7]  * sz
    self[9], self[10], self[11] = self[9] * sx, self[10] * sy, self[11] * sz

    -- fourth row is not used, just set it to the fourth row of the identity matrix
    self[13], self[14], self[15], self[16] = 0, 0, 0, 1
    return self
end
]]

-- returns a perspective projection matrix
-- (things farther away appear smaller)
-- all arguments are scalars aka normal numbers
-- aspectRatio is defined as window width divided by window height
function matrix:setProjectionMatrix(fov, near, far, aspectRatio)
    local top = near * math.tan(fov/2)
    local bottom = -1*top
    local right = top * aspectRatio
    local left = -1*right

    self[1],  self[2],  self[3],  self[4]  = 2*near/(right-left), 0, (right+left)/(right-left), 0
    self[5],  self[6],  self[7],  self[8]  = 0, 2*near/(top-bottom), (top+bottom)/(top-bottom), 0
    self[9],  self[10], self[11], self[12] = 0, 0, -1*(far+near)/(far-near), -2*far*near/(far-near)
    self[13], self[14], self[15], self[16] = 0, 0, -1, 0
    return self
end
-- returns an orthographic projection matrix
-- (things farther away are the same size as things closer)
-- all arguments are scalars aka normal numbers
-- aspectRatio is defined as window width divided by window height
function matrix:setOrthographicMatrix(fov, size, near, far, aspectRatio)
    local top = size * math.tan(fov/2)
    local bottom = -1*top
    local right = top * aspectRatio
    local left = -1*right

    self[1],  self[2],  self[3],  self[4]  = 2/(right-left), 0, 0, -1*(right+left)/(right-left)
    self[5],  self[6],  self[7],  self[8]  = 0, 2/(top-bottom), 0, -1*(top+bottom)/(top-bottom)
    self[9],  self[10], self[11], self[12] = 0, 0, -2/(far-near), -(far+near)/(far-near)
    self[13], self[14], self[15], self[16] = 0, 0, 0, 1
    return self
end
--i spent 3 days trying to debug my camera3d lookat and the function i needed was here the whole time
--returns a view matrix for the camera, at cam_x,y,z , looking at point pnt_x,y,z, using up_x,y,z as the refrence world up
--scales whole matrix by sx,sy,sz
function matrix:setLookAtMatrix(cam_x,cam_y,cam_z, pnt_x,pnt_y,pnt_z, up_x,up_y,up_z, sx,sy,sz)
    local z1, z2, z3 = vectorNormalize(cam_x - pnt_x, cam_y - pnt_y, cam_z - pnt_z)
    local x1, x2, x3 = vectorNormalize(vectorCrossProduct(up_x, up_y, up_z, z1, z2, z3))
    local y1, y2, y3 = vectorCrossProduct(z1, z2, z3, x1, x2, x3)

    self[1],  self[2],  self[3],  self[4]  = x1, x2, x3, -sx*vectorDotProduct(x1, x2, x3, cam_x, cam_y, cam_z)
    self[5],  self[6],  self[7],  self[8]  = y1, y2, y3, -sy*vectorDotProduct(y1, y2, y3, cam_x, cam_y, cam_z)
    self[9],  self[10], self[11], self[12] = z1, z2, z3, -sz*vectorDotProduct(z1, z2, z3, cam_x, cam_y, cam_z)
    self[13], self[14], self[15], self[16] = 0, 0, 0, 1
    return self
end

--setLookAtMatrix for normal non-camera purpouses
function matrix:setPointToMatrix(tx,ty,tz, pnt_x,pnt_y,pnt_z, up_x,up_y,up_z, sx,sy,sz)
    local z1, z2, z3 = vectorNormalize(pnt_x - tx, pnt_y - ty, pnt_z - tz)
    local x1, x2, x3 = vectorNormalize(vectorCrossProduct(up_x, up_y, up_z, z1, z2, z3))
    local y1, y2, y3 = vectorCrossProduct(z1, z2, z3, x1, x2, x3)

    self[1],  self[2],  self[3],  self[4]  = x1, y1, z1, tx
    self[5],  self[6],  self[7],  self[8]  = x2, y2, z2, ty
    self[9],  self[10], self[11], self[12] = x3, y3, z3, tz
    self[13], self[14], self[15], self[16] = 0, 0, 0, 1
    return self
end
-- returns a transform matrix
-- q is a quaternion (real, i,j,k) is a scale, x,y,z is translation
-- applies in order rotate -> scale -> translate 
function matrix:setQST(qr,qi,qj,qk, sx,sy,sz, tx,ty,tz)
        tx = tx or 0
        ty = ty or 0
        tz = tz or 0
        
        sx = sx or 1
        sy = sy or 1
        sz = sz or 1
        
        qr = qr or 1
        qi = qi or 0
        qj = qj or 0
        qk = qk or 0
        
        local i2 = qi*qi
        local j2 = qj*qj
        local k2 = qk*qk
        local ri = qi*qr
        local rj = qj*qr
        local rk = qk*qr
        local ij = qi*qj
        local ik = qi*qk
        local jk = qj*qk

        self[1],  self[2],  self[3],  self[4], 
        self[5],  self[6],  self[7],  self[8],  
        self[9],  self[10], self[11], self[12], 
        self[13], self[14], self[15], self[16]
        =
        sx*(1 - 2*j2 - 2*k2 ), sy*(2*ij - 2*rk),     sz*(2*ik + 2*rj),    tx,
        sx*(2*ij + 2*rk) ,     sy*(1 - 2*i2 - 2*k2), sz*(2*jk - 2*ri),    ty,
        sx*(2*ik - 2*rj) ,     sy*(2*jk + 2*ri) ,    sz*(1- 2*i2 - 2*j2), tz,
        0,0,0,1
        
        return self
end

-- returns a transform matrix from basis vectors a,b,c
-- makes a 4x4 with matrix values:
-- ax bx cx
-- ay by cy
-- az bz cz
-- scale sx, sy, sz
-- translation x,y,z
function matrix:setBST(ax,ay,az, bx,by,bz, cx,cy,cz,  sx,sy,sz, tx,ty,tz)
    sx = sx or 1
    sy = sy or sx
    sz = sz or sx

    tx = tx or 0
    ty = ty or 0
    tz = tz or 0

    self[1],  self[2],  self[3],  self[4], 
    self[5],  self[6],  self[7],  self[8],  
    self[9],  self[10], self[11], self[12], 
    self[13], self[14], self[15], self[16]
    =
    sx*ax, sy*bx, sz*cx,  tx,
    sx*ay, sy*by, sz*cy,  ty,
    sx*az, sy*bz, sz*cz,  tz,
    0    , 0    , 0    , 1

    return self
end

-- camera view matrix math, applies rotation to columns --
-- returns a transform matrix
-- q is a quaternion (real, i,j,k) is a scale, x,y,z is translation
-- applies in order rotate -> scale -> translate 
function matrix:setViewQST(qr,qi,qj,qk, sx,sy,sz, tx,ty,tz)
    tx = tx or 0
    ty = ty or 0
    tz = tz or 0
    
    sx = sx or 1
    sy = sy or 1
    sz = sz or 1
    
    qr = qr or 1
    qi = qi or 0
    qj = qj or 0
    qk = qk or 0
    qr,qi,qj,qk = q_inverse(qr,qi,qj,qk)

    local i2 = qi*qi
    local j2 = qj*qj
    local k2 = qk*qk
    local ri = qi*qr
    local rj = qj*qr
    local rk = qk*qr
    local ij = qi*qj
    local ik = qi*qk
    local jk = qj*qk

    tx,ty,tz = q_rotate(tx,ty,tz, qr,qi,qj,qk)

    local 
    m00, m01, m02, 
    m10, m11, m12,
    m20, m21, m22
    =
    sx*(1 - 2*j2 - 2*k2 ), sy*(2*ij - 2*rk),     sz*(2*ik + 2*rj),
    sx*(2*ij + 2*rk) ,     sy*(1 - 2*i2 - 2*k2), sz*(2*jk - 2*ri),
    sx*(2*ik - 2*rj) ,     sy*(2*jk + 2*ri) ,    sz*(1- 2*i2 - 2*j2)
    self[1],  self[2],  self[3],  self[4], 
    self[5],  self[6],  self[7],  self[8],  
    self[9],  self[10], self[11], self[12], 
    self[13], self[14], self[15], self[16]
    =
    m00, m01, m02, -sx*tx,
    m10, m11, m12, -sy*ty,
    m20, m21, m22, -sz*tz,
    0  , 0  , 0  , 1
    
    return self
end

-- returns a view matrix from basis vectors a,b,c
-- makes a 4x4 with matrix values:
-- ax bx cx
-- ay by cy
-- az bz cz
-- scale sx, sy, sz
-- translation x,y,z
function matrix:setViewBST(ax,ay,az, bx,by,bz, cx,cy,cz,  sx,sy,sz, tx,ty,tz)
    sx = sx or 1
    sy = sy or sx
    sz = sz or sx

    tx = tx or 0
    ty = ty or 0
    tz = tz or 0

    local 
    m00, m01, m02, 
    m10, m11, m12,
    m20, m21, m22
    =
    sx*ax, sy*bx, sz*cx,
    sx*ay, sy*by, sz*cy,
    sx*az, sy*bz, sz*cz

    self[1],  self[2],  self[3],  self[4], 
    self[5],  self[6],  self[7],  self[8],  
    self[9],  self[10], self[11], self[12], 
    self[13], self[14], self[15], self[16]
    =
    m00, m01, m02, -sx*(m00*tx + m01*ty + m02*tz),
    m10, m11, m12, -sy*(m10*tx + m11*ty + m12*tz),
    m20, m21, m22, -sz*(m20*tx + m21*ty + m22*tz),
    0  , 0  , 0  , 1

    return self
end

--returns the rotation quaternion. assumes rotation matrix has determinant 1
function matrix:getRotationQuaternion()
    --use rotation transpose because function expects 3 basis vectors, not rotation matricies
    return q_from_basis_vectors(
        self[1], self[5], self[9],
        self[2], self[6], self[10],
        self[3], self[7], self[11]
    )
end
--updates the matrix with set values, covienence method
function matrix:set(a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p)
    if(type(a) == "table") then
        for i=1, 16 do
            self[i] = a[i]
        end
    else
        self[1],  self[2],  self[3],  self[4]  = a, b, c, d
        self[5],  self[6],  self[7],  self[8]  = e, f, g, h
        self[9],  self[10], self[11], self[12] = i, j, k, l
        self[13], self[14], self[15], self[16] = m, n, o, p
    end
    return self
end

--self = other * self, returns (modified) self
function matrix:mat_multiply(other)
    self[1],  self[2],  self[3],  self[4], 
    self[5],  self[6],  self[7],  self[8],  
    self[9],  self[10], self[11], self[12], 
    self[13], self[14], self[15], self[16]
    =
    other[1]*self[1] + other[2]*self[5] + other[3]*self[9] + other[4]*self[13], 	other[1]*self[2] + other[2]*self[6] + other[3]*self[10] + other[4]*self[14], 	other[1]*self[3] + other[2]*self[7] + other[3]*self[11] + other[4]*self[15], 	other[1]*self[4] + other[2]*self[8] + other[3]*self[12] + other[4]*self[16],
    other[5]*self[1] + other[6]*self[5] + other[7]*self[9] + other[8]*self[13], 	other[5]*self[2] + other[6]*self[6] + other[7]*self[10] + other[8]*self[14], 	other[5]*self[3] + other[6]*self[7] + other[7]*self[11] + other[8]*self[15], 	other[5]*self[4] + other[6]*self[8] + other[7]*self[12] + other[8]*self[16],
    other[9]*self[1] + other[10]*self[5] + other[11]*self[9] + other[12]*self[13], 	other[9]*self[2] + other[10]*self[6] + other[11]*self[10] + other[12]*self[14], 	other[9]*self[3] + other[10]*self[7] + other[11]*self[11] + other[12]*self[15], 	other[9]*self[4] + other[10]*self[8] + other[11]*self[12] + other[12]*self[16],
    other[13]*self[1] + other[14]*self[5] + other[15]*self[9] + other[16]*self[13],	other[13]*self[2] + other[14]*self[6] + other[15]*self[10] + other[16]*self[14], 	other[13]*self[3] + other[14]*self[7] + other[15]*self[11] + other[16]*self[15], 	other[13]*self[4] + other[14]*self[8] + other[15]*self[12] + other[16]*self[16]
    return self
end

--stores the result of a*b into the calling matrix
function matrix:store_multiply(a,b)
    self[1],  self[2],  self[3],  self[4], 
    self[5],  self[6],  self[7],  self[8],  
    self[9],  self[10], self[11], self[12], 
    self[13], self[14], self[15], self[16]
    =
    a[1]*b[1] + a[2]*b[5] + a[3]*b[9] + a[4]*b[13], 	a[1]*b[2] + a[2]*b[6] + a[3]*b[10] + a[4]*b[14], 	a[1]*b[3] + a[2]*b[7] + a[3]*b[11] + a[4]*b[15], 	a[1]*b[4] + a[2]*b[8] + a[3]*b[12] + a[4]*b[16],
    a[5]*b[1] + a[6]*b[5] + a[7]*b[9] + a[8]*b[13], 	a[5]*b[2] + a[6]*b[6] + a[7]*b[10] + a[8]*b[14], 	a[5]*b[3] + a[6]*b[7] + a[7]*b[11] + a[8]*b[15], 	a[5]*b[4] + a[6]*b[8] + a[7]*b[12] + a[8]*b[16],
    a[9]*b[1] + a[10]*b[5] + a[11]*b[9] + a[12]*b[13], 	a[9]*b[2] + a[10]*b[6] + a[11]*b[10] + a[12]*b[14], 	a[9]*b[3] + a[10]*b[7] + a[11]*b[11] + a[12]*b[15], 	a[9]*b[4] + a[10]*b[8] + a[11]*b[12] + a[12]*b[16],
    a[13]*b[1] + a[14]*b[5] + a[15]*b[9] + a[16]*b[13],	a[13]*b[2] + a[14]*b[6] + a[15]*b[10] + a[16]*b[14], 	a[13]*b[3] + a[14]*b[7] + a[15]*b[11] + a[16]*b[15], 	a[13]*b[4] + a[14]*b[8] + a[15]*b[12] + a[16]*b[16]
    return self
end
    --sets matrix to its inverse
function matrix:invert()
    local idet = 1/self:determinant()
    local 
    m00, m01, m02, m03, 
    m10, m11, m12, m13, 
    m20, m21, m22, m23, 
    m30, m31, m32, m33 = 
    self[1],  self[2],  self[3],  self[4], 
    self[5],  self[6],  self[7],  self[8],  
    self[9],  self[10], self[11], self[12], 
    self[13], self[14], self[15], self[16]

    self[1],  self[2],  self[3],  self[4], 
    self[5],  self[6],  self[7],  self[8],  
    self[9],  self[10], self[11], self[12], 
    self[13], self[14], self[15], self[16]
    =
    m12*m23*m31 - m13*m22*m31 + m13*m21*m32 - m11*m23*m32 - m12*m21*m33 + m11*m22*m33,
    m03*m22*m31 - m02*m23*m31 - m03*m21*m32 + m01*m23*m32 + m02*m21*m33 - m01*m22*m33,
    m02*m13*m31 - m03*m12*m31 + m03*m11*m32 - m01*m13*m32 - m02*m11*m33 + m01*m12*m33,
    m03*m12*m21 - m02*m13*m21 - m03*m11*m22 + m01*m13*m22 + m02*m11*m23 - m01*m12*m23,
    m13*m22*m30 - m12*m23*m30 - m13*m20*m32 + m10*m23*m32 + m12*m20*m33 - m10*m22*m33,
    m02*m23*m30 - m03*m22*m30 + m03*m20*m32 - m00*m23*m32 - m02*m20*m33 + m00*m22*m33,
    m03*m12*m30 - m02*m13*m30 - m03*m10*m32 + m00*m13*m32 + m02*m10*m33 - m00*m12*m33,
    m02*m13*m20 - m03*m12*m20 + m03*m10*m22 - m00*m13*m22 - m02*m10*m23 + m00*m12*m23,
    m11*m23*m30 - m13*m21*m30 + m13*m20*m31 - m10*m23*m31 - m11*m20*m33 + m10*m21*m33,
    m03*m21*m30 - m01*m23*m30 - m03*m20*m31 + m00*m23*m31 + m01*m20*m33 - m00*m21*m33,
    m01*m13*m30 - m03*m11*m30 + m03*m10*m31 - m00*m13*m31 - m01*m10*m33 + m00*m11*m33,
    m03*m11*m20 - m01*m13*m20 - m03*m10*m21 + m00*m13*m21 + m01*m10*m23 - m00*m11*m23,
    m12*m21*m30 - m11*m22*m30 - m12*m20*m31 + m10*m22*m31 + m11*m20*m32 - m10*m21*m32,
    m01*m22*m30 - m02*m21*m30 + m02*m20*m31 - m00*m22*m31 - m01*m20*m32 + m00*m21*m32,
    m02*m11*m30 - m01*m12*m30 - m02*m10*m31 + m00*m12*m31 + m01*m10*m32 - m00*m11*m32,
    m01*m12*m20 - m02*m11*m20 + m02*m10*m21 - m00*m12*m21 - m01*m10*m22 + m00*m11*m22

    -- scale
    self[1],  self[2],  self[3],  self[4], 
    self[5],  self[6],  self[7],  self[8],  
    self[9],  self[10], self[11], self[12], 
    self[13], self[14], self[15], self[16]
    =
    idet*self[1],  idet*self[2],  idet*self[3],  idet*self[4], 
    idet*self[5],  idet*self[6],  idet*self[7],  idet*self[8],  
    idet*self[9],  idet*self[10], idet*self[11], idet*self[12], 
    idet*self[13], idet*self[14], idet*self[15], idet*self[16]
    return self
end

--computes the determinant
function matrix:determinant()
    return
        self[4]*self[7]*self[10]*self[13] - self[3]*self[8]*self[10]*self[13] - self[4]*self[6]*self[11]*self[13] + self[2]*self[8]*self[11]*self[13]+
        self[3]*self[6]*self[12]*self[13] - self[2]*self[7]*self[12]*self[13] - self[4]*self[7]*self[9]*self[14] + self[3]*self[8]*self[9]*self[14]+
        self[4]*self[5]*self[11]*self[14] - self[1]*self[8]*self[11]*self[14] - self[3]*self[5]*self[12]*self[14] + self[1]*self[7]*self[12]*self[14]+
        self[4]*self[6]*self[9]*self[15] - self[2]*self[8]*self[9]*self[15] - self[4]*self[5]*self[10]*self[15] + self[1]*self[8]*self[10]*self[15]+
        self[2]*self[5]*self[12]*self[15] - self[1]*self[6]*self[12]*self[15] - self[3]*self[6]*self[9]*self[16] + self[2]*self[7]*self[9]*self[16]+
        self[3]*self[5]*self[10]*self[16] - self[1]*self[7]*self[10]*self[16] - self[2]*self[5]*self[11]*self[16] + self[1]*self[6]*self[11]*self[16]
end

--interpolate self -> other by t
function matrix:interpolate(other,t)
    local tt = 1-t
    self[1],  self[2],  self[3],  self[4], 
    self[5],  self[6],  self[7],  self[8],  
    self[9],  self[10], self[11], self[12], 
    self[13], self[14], self[15], self[16]
    =
    tt*self[1] + t*other[1],  tt*self[2] + t*other[2],  tt*self[3] + t*other[3],  tt*self[4] + t*other[4], 
    tt*self[5] + t*other[5],  tt*self[6] + t*other[6],  tt*self[7] + t*other[7],  tt*self[8] + t*other[8],  
    tt*self[9] + t*other[9],  tt*self[10] + t*other[10], tt*self[11] + t*other[11], tt*self[12] + t*other[12], 
    tt*self[13] + t*other[13], tt*self[13] + t*other[14], tt*self[15] + t*other[15], tt*self[16] + t*other[16]
    return self
end

function matrix:store_interpolation(a,b,t)
    local tt = 1-t
    self[1],  self[2],  self[3],  self[4], 
    self[5],  self[6],  self[7],  self[8],  
    self[9],  self[10], self[11], self[12], 
    self[13], self[14], self[15], self[16]
    =
    tt*a[1] + t*b[1],  tt*a[2] + t*b[2],  tt*a[3] + t*b[3],  tt*a[4] + t*b[4], 
    tt*a[5] + t*b[5],  tt*a[6] + t*b[6],  tt*a[7] + t*b[7],  tt*a[8] + t*b[8],  
    tt*a[9] + t*b[9],  tt*a[10] + t*b[10], tt*a[11] + t*b[11], tt*a[12] + t*b[12], 
    tt*a[13] + t*b[13], tt*a[13] + t*b[14], tt*a[15] + t*b[15], tt*a[16] + t*b[16]
    return self
end

--multiples by the interpolation of a->b by t
function matrix:multiply_interpolation(a,b,t)
    local tt = 1-t
    local 
    m00, m01, m02, m03, 
    m10, m11, m12, m13, 
    m20, m21, m22, m23, 
    m30, m31, m32, m33
    =
    tt*a[1] + t*b[1],  tt*a[2] + t*b[2],  tt*a[3] + t*b[3],  tt*a[4] + t*b[4], 
    tt*a[5] + t*b[5],  tt*a[6] + t*b[6],  tt*a[7] + t*b[7],  tt*a[8] + t*b[8],  
    tt*a[9] + t*b[9],  tt*a[10] + t*b[10], tt*a[11] + t*b[11], tt*a[12] + t*b[12], 
    tt*a[13] + t*b[13], tt*a[13] + t*b[14], tt*a[15] + t*b[15], tt*a[16] + t*b[16]

    self[1],  self[2],  self[3],  self[4], 
    self[5],  self[6],  self[7],  self[8],  
    self[9],  self[10], self[11], self[12], 
    self[13], self[14], self[15], self[16]
    =
    m00*self[1] + m01*self[5] + m02*self[9] + m03*self[13], 	m00*self[2] + m01*self[6] + m02*self[10] + m03*self[14], 	m00*self[3] + m01*self[7] + m02*self[11] + m03*self[15], 	m00*self[4] + m01*self[8] + m02*self[12] + m03*self[16],
    m10*self[1] + m11*self[5] + m12*self[9] + m13*self[13], 	m10*self[2] + m11*self[6] + m12*self[10] + m13*self[14], 	m10*self[3] + m11*self[7] + m12*self[11] + m13*self[15], 	m10*self[4] + m11*self[8] + m12*self[12] + m13*self[16],
    m20*self[1] + m21*self[5] + m22*self[9] + m23*self[13], 	m20*self[2] + m21*self[6] + m22*self[10] + m23*self[14], 	m20*self[3] + m21*self[7] + m22*self[11] + m23*self[15], 	m20*self[4] + m21*self[8] + m22*self[12] + m23*self[16],
    m30*self[1] + m31*self[5] + m32*self[9] + m33*self[13],     m30*self[2] + m31*self[6] + m32*self[10] + m33*self[14], 	m30*self[3] + m31*self[7] + m32*self[11] + m33*self[15], 	m30*self[4] + m31*self[8] + m32*self[12] + m33*self[16]
    return self
end

--transforms vector v with self
--returns vector
function matrix:transform_vector(a,b,c,d)
    return
        a*self[1] + b*self[2] + c*self[3] + d*self[4], 
        a*self[5] + b*self[6] + c*self[7] + d*self[8], 
        a*self[9] + b*self[10] + c*self[11] + d*self[12], 
        a*self[13] + b*self[14] + d*self[15] + d*self[16]
end

function matrix.__eq(a,b)
    return a[1]==b[1] and a[2]==b[2] and a[3]==b[3] and a[4]==b[4] and a[5]==b[5] and a[6]==b[6] and a[7]==b[7] and a[8]==b[8] and a[9]==b[9] and a[10]==b[10] and a[11]==b[11] and a[12]==b[12] and a[13]==b[13] and a[14]==b[14] and a[15]==b[15] and a[16]==b[16];
end

return newMatrix
