--[[
    Camera3d.lua
    represents a camera object obersving a 3d scene
    models in the table .draw_models are rendered to the screen, managed by :removeModel(model) and :pushModel(model)
]]
printt("Loading Camera3d")
--dependencies
local newMatrix = libRequire("k3d", "scripts.globals.Matrix4x4")

local Vector3 = libRequire("k3d", "scripts.globals.Vector3")
local v_sub = Vector3.sub
local v_normalize = Vector3.normalize
local v_cross = Vector3.cross

local Quaternion = libRequire("k3d", "scripts.globals.Quaternion")
local q_rotate = Quaternion.rotate
local Camera3d, super = Class("Object3d") --TODO: change to ThreeDee, fix canvas to have models render directly?

--self, path,texture, tx,ty,tz, sx,sy,sz, qr,qi,qj,qk, width, height, depth
function Camera3d.init(self, layer,  tx,ty,tz, sx,sy,sz, qr,qi,qj,qk, fov, nearClip, farClip, aspectRatio, width, height, depth)
    --unpack data
    width = width or SCREEN_WIDTH
    height = height or SCREEN_HEIGHT
    if(type(layer) == "table") then

        local data, world = layer, tx
        tx, ty, tz  = data.properties.x or 0, data.properties.y or 0, data.properties.z or 0
        sx = data.properties.scale or data.properties.sx
        sy = data.properties.scale or data.properties.sy
        sz = data.properties.scale or data.properties.sx
        if(data.properties.cam_focus_x) then
            local cux, cuy, cuz = data.properties.cam_up_x or 0, data.properties.cam_up_y or 1, data.properties.cam_up_z or 0
            local ctx, cty, ctz = data.properties.cam_focus_x or 0, data.properties.cam_focus_y or 0, data.properties.cam_focus_z or 0
            self:lookAt(tx,ty,tz, ctx,cty,ctz, cux,cuy,cuz)
        else
            qr,qi,qj,qk = 
                data.properties.qr or 1,
                data.properties.qi or 0,
                data.properties.qj or 0,
                data.properties.qk or 0
        end
        printt(tx, ty, tz)
    end
    super.init(self, tx, ty, tz, sx, sy, sz, qr, qi, qj, qk, width, height, depth)

    self:setLayer(layer or 0.2)--WORLD_LAYERS.bottom)
    
    self.fov = fov or math.pi/2

    self.nearClip = nearClip or 0.01
    self.farClip = farClip or 1000
    self.aspectRatio = aspectRatio or width/height
    
    --squash camera space to fit with kristal-screenspace
    self.scale_x, self.scale_y, self.scale_z = 1,1,1--1/32, 1/32, 1/32 --TODO: figure out why this works

    self.canvas = love.graphics.newCanvas(width,height)--, {format="depth24", readable=true})--this breaks?
    --self.canvas_setup = {self.canvas, depth = true} --used by love.graphics.setCanvas
    
    self.draw_models = {}

    self.projectionMatrix = newMatrix()
    self:projective()
    --self:updateMatrix()

    -- the camera3d is the last to update, after the regular camera (since it might grab some information from it)
    -- update is called manually
    -- TODO fix this, maybe?
    self.active = false 
    -- however it does draw its canvas to the screen at the normal time
    self.visible = true

    --whether or not the camera should pan on left click and drag, and rotate on rightclick and drag
    self.mouse_control = Kristal.getLibConfig("k3d", "debug")
    --dumb mouse control workaround. store it in object
    self.mouse_pan = false
    self.mouse_rotate = false
    self.mouse_rotspeed = 3 --[[<-- dgree/second]] * 2 * math.pi / 360
    self.mouse_panspeed = 1
    self.mouse_dx = 0
    self.mouse_dy = 0
    self.mouse_dz = 0

    --if set, tracks this Object with displacement vector track_dx,dy,dz
    self.track_cam = false
    --displacement for tracking, sent to lookAt
    self.track_dx = 0
    self.track_dy = 0
    self.track_dz = 0
    return self
end

function Camera3d:pushModel(model)
    model.camera3d = self
    table.insert(self.draw_models,model)
end

function Camera3d:removeModel(model)
    local removed = nil
    for i, m in ipairs(self.draw_models) do
        if(m == model) then
            model.camera3d = nil
            return table.remove(self.draw_models,i)
        end
    end
end

--[[
function Camera3d:screenToRay(x,y) --take screen coordinate to ray in 3d world from camera
    --screen to NDC space
    local Hx = 2*(x/self.width)-1;
    local Hy = 2*(y/self.height)-1;
    local Hz = 1.0;
    local Hw = 1.0;
    --NDC to camera space constantss
    local w = math.tan(0.5*self.fov);
    local h = w/self.aspectRatio;
    local B = 2.0*self.farClip*self.nearClip / (self.farClip - self.nearClip);
    --NDC space to world
    local x,y,z = w*Hx*B,h*Hy*B,1.0
    return v_normalize(x,y,z);--normalize & return
end
]]
--[[
    Game.world.camera3d:setFov(math.pi/4)
    Game.world.camera3d.track_dz = 175
]]
--starts tracking a camera at displacement in world space x,y,z
function Camera3d:trackCamera(cam, x,y,z)
        --if set, tracks this Object with displacement vector track_dx,dy,dz
        self.track_cam = cam

        --camera always looks down
        self:setRotationQuaternion(1,0,0,0)
        --displacement for tracking, sent to lookAt
        self.track_dx = x
        self.track_dy = y
        self.track_dz = z
end

function Camera3d:getTrackedObject()
    return self.track, self.track_dx, self.track_dy, self.track_dz
end


--TODO: see if we really need this callbacks, fix hack
local mouse_button = 2 -- right click is least intrusive, only opens up context menu
function Camera3d:onMousePressed(win_x, win_y, button, istouch, presses)
    love.mouse.setRelativeMode(true)
    if(button == mouse_button) then
        self.mouse_pan = true
    end
end

function Camera3d:onMouseReleased(win_x, win_y, button, istouch, presses)
    love.mouse.setRelativeMode(false)
    if(button == mouse_button) then
        self.mouse_pan = nil
    end
end

function Camera3d:onMouseMoved(x, y, dx, dy, istouch)
    self.mouse_dx = dx
    self.mouse_dy = dy
end

function Camera3d:onWheelMoved(x,y)
    self.mouse_dz = y
end

function Camera3d:update() 
    --TODO: fix hack
    if(self.mouse_control and self.mouse_pan) then --take prescedence
        if(Input.down("shift")) then --rotate
            --reverse feels more natural
            self:rotateEuler(-DTMULT * self.mouse_rotspeed * self.mouse_dy, -DTMULT * self.mouse_rotspeed * self.mouse_dx, -DTMULT * self.mouse_rotspeed * self.mouse_dz)
        elseif(Input.down("ctrl")) then --pan
            --x ok, reverse y and z feels better
            self:pan(DTMULT * self.mouse_panspeed * self.mouse_dx, -DTMULT * self.mouse_panspeed * self.mouse_dy, -DTMULT * self.mouse_panspeed * self.mouse_dz)
        end
        --clear values once used
        self.mouse_dx, self.mouse_dy, self.mouse_dz = 0,0,0
    else
        if (self.track_cam) then
            local _,_, sx,sy = self.track_cam:getRect()
            local x,y,z = self.track_cam:getPosition()
            --TODO: camera location can be .5 off for some reaosn, figure out why?
            --for now, just floor these values...
            x,y,z=
            (math.floor(x)),--/scale,
            (math.floor(y)),--/scale,
            (z or 0)
            self:setPosition(x + self.track_dx, sy - y + self.track_dy, z + self.track_dz)
        end
    end
end

function Camera3d:draw()
    love.graphics.origin() --camera handles its own transforms
    Draw.draw(self.canvas)
end
--see model.lua note about fixing jank. its 3am and i wanna release this thing in a way that, at minimum, "works"

local function prepareRender(self)
    Draw.pushCanvasLocks()
    local canvas = Draw.pushCanvas(self.canvas, {

    })
    love.graphics.push("all")
    local oldComparemode, oldWrite = love.graphics.getDepthMode() --should always be "always", false, but hey. you never know
    local oldCull = love.graphics.getMeshCullMode()
    
    love.graphics.origin()
    love.graphics.clear()
    love.graphics.setDepthMode("less",true)
    love.graphics.setMeshCullMode("none") --TODO: add backface culling?
    --love.graphics.setDefaultFilter( "linear", "linear", 1 )  --TODO: does nothing, figure out how to set this up later
    love.graphics.setColor(1.0,1.0,1.0,1.0)
    return oldComparemode, oldWrite, oldCull
end

local function cleanupRender(oldComparemode, oldWrite, oldCull)
    Draw.popCanvas(true)
    Draw.popCanvasLocks()
    love.graphics.setShader()
    love.graphics.pop()
    love.graphics.setDepthMode(oldComparemode, oldWrite)
    --love.graphics.setDefaultFilter( "nearest", "nearest", 1 )--TODO: see above
    love.graphics.setMeshCullMode(oldCull)
end

function Camera3d:renderModels()
    local oldComparemode, oldWrite, oldCull = prepareRender(self)
    local ok, msg
    for i,model in ipairs(self.draw_models) do
        if(model.visible) then
            ok, msg  = pcall(model.render, model)
        end
        if not ok then
            cleanupRender(oldComparemode, oldWrite, oldCull) --cleanup on error, if we dont here kristal goes to a bad draw state (you cant see anything forever)
            error("Error in model draw (bad traceback below, see short error) - \n"..msg)
            break
        end
    end
    cleanupRender(oldComparemode, oldWrite, oldCull)
end

-- recreate the camera's projection matrix from its current values
function Camera3d.projective(self)
    self.projectionMatrix:setProjectionMatrix(self.fov, self.nearClip, self.farClip, self.aspectRatio)
end

function Camera3d:setPerspective(fov, nearClip, farClip, aspectRatio)
    self.fov = fov
    self.nearClip = nearClip
    self.farClip = farClip
    self.aspectRatio = aspectRatio
    self:projective()
end

--TODO: this is horrible. horrednous. only works for n[2-4], ish. but hopefully that's all people need?
--this needs to be fixed soon but im too stupid rn and really need to dig into a projective geometry textbook...
function Camera3d:setFocus(n)
    self:setFov(math.pi/n)
    self.track_dz = 175*(n-2)+250.0
end

function Camera3d:setFov(fov)
    self.fov = fov
    self:projective()
end

function Camera3d:setNearClip(nearClip)
    self.nearClip = nearClip
    self:projective()
end

function Camera3d:setFarClip(farClip)
    self.farClip = farClip
    self:projective()
end

function Camera3d:setClip(nearClip, farClip)
    self.nearClip = nearClip
    self.farClip = farClip
    self:projective()
end

function Camera3d:setAspectRatio(aspectRatio)
    self.aspectRatio = aspectRatio
    self:projective()
end
--camera matrix updates differently, uses rotation to transform its position
function Camera3d:updateMatrix()
    self.matrix:setViewQST(
        self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k,
        self.scale_x, self.scale_y, self.scale_z,
        self.x, self.y, self.z
    )
    --printt(self.matrix)

end
--[[
    
Game.world.timer:every(DT, function()
    Game.world.camera3d:lookAt(
        0,1,0, --world center
        5*math.sin(RUNTIME/3),0,5*math.cos(RUNTIME/3)--speen
    )   
end)
    ]]
--TODO: make this call updateMatrix so we dont have to override it here?
-- x,y,z: target location coordinates in world space
-- ? tx,ty,tz: optional camera position value, camera will move here if set
-- ? ux,uy,uz: optional up vector, if not provided, an appropriate one will be used
-- ? sx,sy,sz: optional scale factor
function Camera3d:lookAt(x,y,z, tx,ty,tz, ux,uy,uz, sx,sy,sz)
    --[[
        https://learnopengl.com/Getting-started/Camera
        psuedocode because i spent 3 days figuring this out like a dummy
        
        ; camera position in worldspace
        P = getCameraPosition()
        ; can be changed, represents the arbitrary up vector
        WORLD_UP = 0,1,0

        ; direction vector from target to camera
        D = normalize( P - target )
        ; right direction, normalize for rounding errors
        R = normalize( WORLD_UP x toCam)
        ; up direction, normalize for rounding errors
        U = normalize( toCam x right )

        ; inverse these matricies because cam movement is opposite world movement
        ;since we're making an orthogonal rotation matrix, inverse is transpose
                
                    | R_x  R_y  R_z  0 |
        rotmat =    | U_x  U_y  U_z  0 |
                    | D_x  D_y  D_z  0 |
                    | 0    0    0    1 |
        ;the translation matrix's inverse, bc it's a vector, is the vector negation

                    | 1    0    0    0 |
        transmat =  | 0    1    0    0 |
                    | 0    0    1    0 |
                    | 1    1    1    0 |
        ; finally set the camera's view matrix, apply the rotation matrix to the translation matrix
        
        setCameraMatrix( rotmat * transmat )
    ]]
    --initialize arguments or default values if not specified
    tx,ty,tz = tx or self.x, ty or self.y, tz or self.z
    sx, sy, sz = sx or self.scale_x, sy or sx or self.scale_y, sz or sx or self.scale_z
    if(not ux) then --assume uy and uz are set if ux is set, otherwise
        ux,uy,uz = self:getUp()
    end
    --:( i forgot this function was here the whole time. im SUPER dummy
    --no need to call updateMatrix
    self.matrix:setLookAtMatrix(tx,ty,tz, x,y,z, ux,uy,uz, self.scale_x, self.scale_y, self.scale_z)

    --but we do need to decompose it and set update where we are
    self.x, self.y, self.z = tx,ty,tz
    self.scale_x, self.scale_y, self.scale_z = sx,sy,sz
    self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k = self.matrix:getRotationQuaternion()
end

--Camera3d:move that uses local transform isntead of world coordinates
function Camera3d:pan(dx,dy,dz)
    self:move( q_rotate(
        dx,dy,dz, 
        self.rotation_r, self.rotation_i, self.rotation_j, self.rotation_k
    ))
end
-- recreate the camera's orthographic projection matrix from its current values
--TODO: fix this
function Camera3d.orthographic(self,size)
    --TODO: 7.5 is the magic number (emperical, figure out why) where 1 model space unit lines up with 1 tile unit
    self.projectionMatrix:setOrthographicMatrix(self.fov, size or 7.5, self.nearClip, self.farClip, self.aspectRatio)
end

return Camera3d