--[[
local World_init_orig = World.init
function World:init(map)
    World_init_orig(self, map)

    self.camera3d = Class("Camera3d")()
    self.camera3d.persistent = true
    self:addChild(self.camera3d)
end
]]
--is the same function as

Utils.hook(World,"init", function(orig,self,map)
    orig(self,map)
    
    self.camera3d = Class("Camera3d")()
    self.camera3d.persistent = true
    self:addChild(self.camera3d)
    
end)

return World