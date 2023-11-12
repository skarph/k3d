Utils.hook(Battle,"init", function(orig, self)
    orig(self)
    --TODO: optional battle camera3d
    self.camera3d = Class("Camera3d")()
    self.camera3d.persistent = true
    self:addChild(self.camera3d)
end)

return Battle