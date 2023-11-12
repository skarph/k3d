--dependencies
local loadModel = libRequire("k3d", "scripts.globals.LoadModel")
local Quaternion = libRequire("k3d", "scripts.globals.Quaternion")
local qfromea = Quaternion.fromea

local Model, super = Class("Object3d")

function Model.init(self, path,texture, tx,ty,tz, sx,sy,sz, qr,qi,qj,qk, width, height, depth)
    --unpack data
    if(type(path) == "table") then
        printt("Model data from tiled, assume camera3d")
        local data, world = path, texture
        --printt(data)
        for k, v in pairs(data) do
            printt(k,v)
        end
        printt("--------------")
        for k, v in pairs(data.properties) do
            printt(k, v)
        end
        path = data.properties.path
        tx, ty, tz  = data.properties.x or data.x or 0, data.properties.y or data.y or 0, data.properties.z or 0
        printt(tx, ty, tz)
        texture = assert(data.properties.texture, "No texture provided!\nSet the model's texture property.")
        if(data.properties.rx) then
            qr,qi,qj,qk = qfromea(
                (data.properties.rx or 0) * math.pi/180,
                (data.properties.ry or 0) * math.pi/180,
                (data.properties.rz or 0)  * math.pi/180
            )
        else
            qr,qi,qj,qk =
                data.properties.qr or 1,
                data.properties.qi or 0,
                data.properties.qj or 0,
                data.properties.qk or 0
        end
        sx = data.properties.scale or data.properties.sx
        sy = data.properties.scale or data.properties.sy
        sz = data.properties.scale or data.properties.sx

        printt(isClass(world.camera3d) and Utils.getClassName(world.camera3d))
        super.init(self, tx, ty, tz, sx, sy, sz, qr, qi, qj, qk, width, height, depth)
        
        self.camera3d = Game.world.camera3d
        if(self.camera3d) then
            if(self.camera3d.track_cam) then
                assert(self.camera3d.matrix)
                printt("AAA",tx,ty,tz)
                self:setPixelPosition(tx,ty,tz)
            else
                printt("Couldn't set model pixel position, parent camera has no track_cam!")
            end
        end
        --
        --world.camera3d:pushModel(self)
    else
        super.init(self, tx, ty, tz, sx, sy, sz, qr, qi, qj, qk, width, height, depth)
    end

    self.visible = true

    self.meshes, self.tree, self.animations = loadModel(path, texture)

    self.vertexFormat = loadModel.VERTEX_FORMAT

    self.shader = SHADER_3D --SIMPLE_SHADER
    --printt(self)
    return self
end

    --[[note on mesh, tree, animation
        mesh is a list of mesh_name - love.graphics.mesh > 
        tree is a list of mesh_name -
                                {
                                    parent > string of parent mesh_name
                                    children
                                        {
                                            array of child mesh_name s
                                        }
                                    scene_transform > 4x4 matrix associated with parent transforms
                                    local_transform > 4x4 matrix asociated with this meshs local transform
                                    working_transform > 4x4 scratch matrix, may be removed, used for matrix operations
                                    mesh_url
                                }
                            also includes Scene, which is the highest parent
        animation is a list of animation_name -
                                {   
                                    list of mesh_name -
                                    {
                                        keyframe array - {
                                            matrix > 4x4 matrix associated with keyframe transform
                                            time > time offset of keyframe
                                            interpolation > interpolation to next keyframe
                                        }
                                    }
                                    __playing > boolean if this animation is playing
                                    __time > local time this animation has been playing for. increments by DT every frame
                                    __duration > the length of the animation, largest value of [keyframe array].time
                                }
    ]]

--stops all other animations and plays anim_name
--call with anim_name = nil to stop all animations
--if once then model will stop animation after its finished
--todo: implement nonlooping
function Model:setAnimation(anim_name, once)
    assert(self.animations[anim_name], "No animation \""..tostring(anim_name).."\"")
    self:stopAnimations()
    self.animations[anim_name].__playing = true
    self.animations[anim_name].__time = 0
end

--adds an animation to be played simultaneously with all others
--if once then model will stop animation after its finished
function Model:playAnimation(anim_name, once)
    assert(self.animations[anim_name], "No animation \""..tostring(anim_name).."\"")
    self.animations[anim_name].__playing = true
end

--stops all animation
function Model:stopAnimations()
    for name, anim in pairs(self.animations) do
        anim.__playing = false
        anim.__time = 0
    end
end

function Model:stopAnimation(anim_name)
    assert(self.animations[anim_name], "No animation \""..tostring(anim_name).."\"")
    self.animations[anim_name].__playing = false
    self.animations[anim_name].__time = 0
end

--pauses a spesific animation, if playing
function Model:pauseAnimation(anim_name)
    assert(self.animations[anim_name], "No animation \""..tostring(anim_name).."\"")
    self.animations[anim_name].__playing = false
end

function Model:update()
    super.update(self)
    for name, anim in pairs(self.animations) do
        if(anim.__playing) then
            anim.__time = (anim.__time + DT) % anim.__duration
        end
    end 
end

--expensive to redefine this in function iirc? maybe jit optimizes this but this will be called *alot*
local function recurseRender(model, obj, camera, shader, name, parent_transform)
    --top of tree
    --working_transform = scene_transform * local_transform
    local mat
    if(name) then
        mat = obj.working_transform:set(obj.local_transform) --mutates obj.working_transform
        --local isAnimating = false
        for _, anim in pairs(model.animations) do
            if(anim.__playing and anim[name]) then
                --isAnimating = true
                for i, keyframe in ipairs(anim[name]) do
                    if (keyframe.time >= anim.__time) then --should be the current frame, plus interpolation if possible
                        --fuck it, we ball.
                        mat:set(keyframe.matrix)
                        break;
                        --TODO: FIX ANIMATION INTERPOLATION
                        --[[
                        local next = anim[name][( i+1 > #anim[name] ) and 1 or i+1] --next keyframe, for interpolation
                        local dt = next.time - keyframe.time --current minus previous (looped if 0 or less)
                        local t  =  (anim.__time - keyframe.time) / dt--interpolation value
                        mat:store_interpolation(keyframe.matrix, next.matrix, t) --overrides local transform
                        break;
                        ]]
                        --none of this works lmao just feed it more animation data
                        --[[
                        local ni = ( i+1 > #anim[name] ) and 1 or i+1
                        local next = anim[name][ni] --next keyframe, for interpolation
                        local keyframe_span = next.time - keyframe.time --time between this key and next key
                        if(keyframe_span < SMALL_BUT_NOT_TINY) then
                            --try again dumbass
                            i = ( i+1 > #anim[name] ) and 1 or i+1 --ok because iterator state not tied to control variables
                            keyframe = anim[name][i] 
                            ni = ( i+1 > #anim[name] ) and 1 or i+1
                            next = anim[name][ni] --next keyframe, for interpolation
                            
                            keyframe_span = next.time - keyframe.time --time between this key and next key
                        end
                        local keyframe_time = keyframe.time - anim.__time --time in this
                        local t = keyframe_time / keyframe_span--interpolation
                        --for instantaneous animation, happens with loops...
                        if(keyframe_span < SMALL_BUT_NOT_TINY) then
                            print("goteem",keyframe.time , next.time, anim.__time)
                            t = 1
                        end
                        if(t < 0 or t > 1) then
                            print("!BAD! T:",keyframe_time, keyframe_span, t)
                            print(i, keyframe.time, ni,next.time)
                                if(keyframe_span < SMALL_BUT_NOT_TINY) then
                                    print("goteem")
                                end
                            print()
                        else
                            --print("ok T:",keyframe_time, keyframe_span, t)
                            --print(i, ni)
                            --print()
                        end
                        mat:store_interpolation(keyframe.matrix, next.matrix, t) --overrides local transform
                        break;
                        ]]
                    end
                end
            end
        end
        mat:mat_multiply(parent_transform)
    else
        mat = model.matrix
    end
    
    --obj.working_transform:mat_multiply(parent_transfor)
    if(obj) then
        for _ , next_name in ipairs(obj.children) do
            recurseRender(model, model.tree[next_name], camera, shader, next_name, mat)
        end
    end
    --bottom of tree
    if(name) then
        shader:send("modelMatrix", mat) --mutates obj.working_transform
        Draw.draw(model.meshes[name])
    end
    
end

-- draw the model
-- called by the Model with the Camera3d
--assumes love.graphics.setDepthMode("lequal", true) and canvas is camera.canvas, set by Camera3d
function Model:render()
    local camera = self.camera3d
    local shader = camera.shader or self.shader  --SIMPLE_SHADER

    love.graphics.setShader(shader)
    shader:send("modelMatrix", self.matrix)

    shader:send("viewMatrix", camera.matrix)
    shader:send("projectionMatrix", camera.projectionMatrix)
    if shader:hasUniform "isCanvasEnabled" then
        shader:send("isCanvasEnabled", love.graphics.getCanvas() ~= nil)
    end
    
    recurseRender(self, self.tree.Scene, camera, shader)
    love.graphics.setShader()
end

--sets model position relative to the screens's origin, in pixels(?)(kristal-pixels. not sure of a good name for that. krixals?)
function Model:setPixelPosition(x,y,z)
    --3d worldspace is NDC, negative y and negative x are visible.
    --this also means positive y is up, unlike screen space where it's down
    --the scale factor is 1/32 for kristal-pixels, no matter our actual window size. this is stored in the camera object just in case it needs to change for some reason
    assert(self.camera3d.track_cam, "Parent camera3d is not tracking a regular camera!")
    local _,_,_,sy = self.camera3d.track_cam:getRect()
    self:setPosition(
        self.camera3d.scale_x * x,
        self.camera3d.scale_y * (sy - y),
        self.camera3d.scale_z * z
    )
end

function Model:movePixel(x,y,z) 
    --3d worldspace is NDC, negative y and negative x are visible.
    --this also means positive y is up, unlike screen space where it's down
    --the scale factor is 1/32 for kristal-pixels, no matter our actual window size. this is stored in the camera object just in case it needs to change for some reason
    --assert(self.camera3d.track_cam, "Parent camera3d is not tracking a regular camera!")
    self:move(
        self.camera3d.scale_x * x,
        -self.camera3d.scale_y * y,
        self.camera3d.scale_z * z
    )
end

function Model:getPixelPosition()
    --3d worldspace is NDC, negative y and negative x are visible.
    --this also means positive y is up, unlike screen space where it's down
    --the scale factor is 1/32 for kristal-pixels, no matter our actual window size. this is stored in the camera object just in case it needs to change for some reason
    assert(self.camera3d.track_cam, "Parent camera3d is not tracking a regular camera!")
    local _,_,_,sy = self.camera3d.track_cam:getRect()
    return
        self.x / self.camera3d.scale_x,
        (-self.y / self.camera3d.scale_y) + sy,
        self.z / self.camera3d.scale_z
end


local function recurseToCamera3d(func, base, ...)
    if(not base) then
        error("Couldnt find a Camera3d in any parents!")
    end
    if(base.camera3d) then
        return base, base.camera3d[func](base.camera3d, ...)
    end
    if(base.parent) then
        recurseToCamera3d(base.parent)
    end
end

--this is very hacky and we need to fix this; ideally the multiple cameras should be able to draw the same model, buuuuuuuut
function Model:onAdd(parent)
    recurseToCamera3d("pushModel", parent, self)
end
function Model:onRemove(parent)
    recurseToCamera3d("removeModel", parent, self)
end
return Model