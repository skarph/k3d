--[[
    ThreeDee.lua
    Base class for all 3d... things.
    Does NOT extend Object, as Object has spesific callbacks that mess with classes like Camera3d;
    but since Camera3d shares a lot of properties with Objct3d, it makes sense to give them a common class to derive from.
    This is basically a wrapper around a Matrix4x4.
    Used Internally.
]]
--dependencies
printt("Loading ThreeDee")
local newMatrix = libRequire("k3d", "scripts.globals.Matrix4x4")

local Vector3 = libRequire("k3d", "scripts.globals.Vector3")
local v_sub = Vector3.sub
local v_normalize = Vector3.normalize
local v_cross = Vector3.cross

local Quaternion = libRequire("k3d", "scripts.globals.Quaternion")
local q_from_aa = Quaternion.fromaa
local q_from_ea = Quaternion.fromea
local q_mul_C = Quaternion.qmulc
local q_rotate = Quaternion.rotate
local ThreeDee = Class()

function ThreeDee:init(tx, ty, tz, sx, sy, sz, qr, qi, qj, qk, width, height, depth)
    -- Intitialize this object's position (optional args)
    self.x = tx or 0
    self.y = ty or 0
    self.z = tz or 0
    --[[
    -- Save the initial position
    self.init_x = self.x
    self.init_y = self.y
    self.init_z = self.z

    -- Save the previous position
    self.last_x = self.x
    self.last_y = self.y
    self.last_z = self.z
    ]]
    -- Initialize this object's size
    self.width  = width or 0
    self.height = height or 0
    self.depth  = depth or 0

    --[[
    -- Various draw properties
    self.color = {1, 1, 1}
    self.alpha = 1
    ]]
    --scale values
    self.scale_x = sx or 1
    self.scale_y = sy or sx or 1
    self.scale_z = sz or sx or 1
    --rotation properties (quaternionic)
    self.rotation_r = qr or 1
    self.rotation_i = qi or 0
    self.rotation_j = qj or 0
    self.rotation_k = qk or 0 
    --transformation matrix.
    self.matrix = newMatrix()
    self:updateMatrix()
    --[[
    self.flip_x = false
    self.flip_y = false
    
    -- Whether this object's color will be multiplied by its parent's color
    self.inherit_color = false

    --[[
    -- Origin of the object's position
    self.origin_x = 0
    self.origin_y = 0
    self.origin_exact = false
    -- Origin of the object's scaling
    self.scale_origin_x = nil
    self.scale_origin_y = nil
    self.scale_origin_exact = false
    -- Origin of the object's rotation
    self.rotation_origin_x = nil
    self.rotation_origin_y = nil
    self.rotation_origin_exact = nil
    -- Origin where the camera will attach to for this object
    self.camera_origin_x = 0.5
    self.camera_origin_y = 0.5
    self.camera_origin_exact = false

    -- How much this object is moved by the camera (1 = normal, 0 = none)
    self.parallax_x = nil
    self.parallax_y = nil
    -- Parallax origin
    self.parallax_origin_x = nil
    self.parallax_origin_y = nil

    -- Camera associated with this object (updates and transforms automatically)
    self.camera = nil
    
    -- Object scissor, no scissor when nil
    self.cutout_left = nil
    self.cutout_top = nil
    self.cutout_right = nil
    self.cutout_bottom = nil

    -- Post-processing effects
    self.draw_fx = {}
    
    -- Whether this object can be selected using debug selection
    self.debug_select = false
    -- The debug rectangle for this object (defaults to width and height)
    
    self.debug_rect = nil
    
    -- Multiplier for DT for this object's update and draw
    self.timescale = 1

    -- This object's sorting, higher number = renders last (above siblings)
    --[[
    self.layer = 0

    -- Collision hitbox
    self.collider = nil
    
    -- Whether this object can be collided with
    self.collidable = false

    -- Whether this object updates
    self.active = true

    -- Whether this object draws
    self.visible = true

    --[[
    -- If set, children under this layer will be drawn below this object
    self.draw_children_below = nil
    -- If set, children at or above this layer will be drawn above this object
    self.draw_children_above = nil

    -- Ignores child drawing
    self._dont_draw_children = false
    -- Triggers list sort / child removal
    self.update_child_list = false
    self.children_to_remove = {}

    self.parent = nil
    self.children = {}
    ]]
end

-- full transformation --

function ThreeDee:setTransform(tx,ty,tz, qr,qi,qj,qk, sx,sy,sz)
    self.x, self.y, self.z,
    self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k,
    self.scale_x, self.scale_y, self.scale_z
    =
    (tx or self.x), (ty or self.y), (tz or self.z),
    qr or self.rotation_r, qi or self.rotation_i, qj or self.rotation_j, qk or self.rotation_k,
    sx or self.scale_x, sy or self.scale_y, sz or self.scale_z

    self:updateMatrix()
end

function ThreeDee:lookAt(x,y,z, tx,ty,tz, ux,uy,uz, sx,sy,sz)
    --initialize arguments or default values if not specified
    tx,ty,tz = tx or self.x, ty or self.y, tz or self.z
    sx, sy, sz = sx or self.scale_x, sy or sx or self.scale_y, sz or sx or self.scale_z
    if(not ux) then --assume uy and uz are set if ux is set, otherwise
        ux,uy,uz = self:getUp()
    end
    --:( i forgot this function was here the whole time. im SUPER dummy
    --no need to call updateMatrix
    self.matrix:setPointToMatrix(tx,ty,tz, x,y,z, ux,uy,uz, self.scale_x, self.scale_y, self.scale_z)

    --but we do need to decompose it and set update where we are
    self.x, self.y, self.z = tx,ty,tz
    self.scale_x, self.scale_y, self.scale_z = sx,sy,sz
    self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k = self.matrix:getRotationQuaternion()
end

-- translation --
function ThreeDee:move(tx,ty,tz)
    self.x, self.y, self.z = 
    self.x + (tx or 0), self.y + (ty or 0), self.z + (tz or 0)

    self:updateMatrix()
end

function ThreeDee:setPosition(tx,ty,tz)
    self.x, self.y, self.z = 
    tx, ty, tz

    self:updateMatrix()
end

-- rotations --

function ThreeDee:setRotationQuaternion(qr,qi,qj,qk)
    self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k
    =
    qr,qi,qj,qk
    self:updateMatrix()
end

-- create a quaternion from an axis and an angle
-- normalize x,y,z before calling
function ThreeDee:setRotationAxisAngle(angle, ax,ay,az)
    self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k
    =
    q_from_aa(angle, ax,ay,az)

    self:updateMatrix()
end

-- rotate given euler angles
--rotate about the x axis, then the y, then the z
function ThreeDee:setRotationEuler(rotx, roty, rotz)
    self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k
    =
    q_from_ea(rotx, roty, rotz)

    self:updateMatrix()
end

function ThreeDee:rotateQuaternion(qr,qi,qj,qk)
    self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k
    =
    q_mul_C(
        self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k,
        qr,qi,qj,qk
    )
    self:updateMatrix()
end

-- create a quaternion from an axis and an angle
-- normalize x,y,z before calling
function ThreeDee:rotateAxisAngle(angle, ax,ay,az)
    self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k
    =
    q_mul_C(
        self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k,
        q_from_aa(angle, ax,ay,az)
    )
    self:updateMatrix()
end

-- rotate given euler angles
function ThreeDee:rotateEuler(rotx, roty, rotz)
    self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k
    =
    q_mul_C(
        self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k,
        q_from_ea(rotx, roty, rotz)--still dont know, this ient the right order but works fine?
    )
    self:updateMatrix()
end

-- scale --

-- resize model's matrix based on a given 3d vector
function ThreeDee:setScale(sx,sy,sz)
    self.scale_x = sx
    self.scale_y = sy or sx
    self.scale_z = sz or sx

    self:updateMatrix()
end

-- helper methods --

-- update the model's transformation matrix
function ThreeDee:updateMatrix()

    --printt(self.matrix)
    --print("|\n|\nv")
    self.matrix:setQST(
        self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k,
        self.scale_x, self.scale_y, self.scale_z,
        self.x, self.y, --[[flip *]] self.z
    )
    --printt(self.matrix)

end

--returns the vector pointing from this object to the coords xyz or the object xx
function ThreeDee:vetorTo(x,y,z)
    if(type(x)=="table") then --TODO: this crashes on vectorToing non ThreeDee's
        x, y, z = x.x, x.y, x.z
    end
    return  v_sub(x,y,z, self.x,self.y,self.z )
end

--normalized vectorTo
function ThreeDee:directionTo(x,y,z)
    if(type(x)=="table") then --TODO: this crashes on vectorToing non ThreeDee's
        x, y, z = x.x, x.y, x.z
    end
    return  v_normalize( v_sub(x,y,z, self.x,self.y,self.z ) )
end

function ThreeDee:getRight()
    return q_rotate(
        1,0,0,
        self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k
    )
end

function ThreeDee:getUp()
    return q_rotate(
        0,1,0,
        self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k
    )
end

function ThreeDee:getForward()
    return q_rotate(        
        0,0,1,
        self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k
    )
end

-- returns the position
function ThreeDee:getPosition()
    return self.x, self.y, self.z    
end
--returns the rotation quaternion
function ThreeDee:getQuaternion()
    return self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k
end
--returns the scale
function ThreeDee:getScale()
    return self.scale_x, self.scale_y, self.scale_z
end
--this is a hack to bypass `Class.includes` checking because doing so comes up with this class being called <unknown class>
--ive really gotta look into load order and dependencies this is a pain
--all `ThreeDee` objects should have this field but plz dont change it
--cant use a function because trying to test if something isnt a ThreeDee would error (no function to refrence)
ThreeDee.ThreeDee = true

return ThreeDee