Utils.hook(Battle,"init", function(orig, self)
    orig(self)
    --TODO: optional battle camera3d
    self.camera3d = Class("Camera3d")(100)
    self.camera3d.persistent = true
    self:addChild(self.camera3d)
    self.camera3d:trackCamera(self.camera, 0, 0, 0)
    self.camera3d:setFocus(3)
end)

return Battle