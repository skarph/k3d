Utils.hook(Stage,"init", function(orig, self)
    orig(self)
    --TODO: optional battle camera3d
    self.camera3d = Class("Camera3d")()
    self.camera3d.persistent = true
    self:addChild(self.camera3d)
    self.camera3d:setPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2, 0)
    self.camera3d:setFocus(3)
end)

return Stage