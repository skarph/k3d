printt("Loading Object3d")
--dependencies
local ThreeDee = libRequire("k3d", "scripts.objects.ThreeDee") --load the class manually until multi inheriance fix

local Object3d, super_ThreeDee= Class({ThreeDee,Object}, "Object3d") --FIXJANK, technically is not a "ThreeDee". but an exacty copy of "ThreeDee"

function Object3d:init(tx, ty, tz, sx, sy, sz, qr, qi, qj, qk, width, height, depth, layer)
    Object.init(self)--x, y, width, height)
    super_ThreeDee.init(self, tx, ty, tz, sx, sy, sz, qr, qi, qj, qk, width, height, depth)

    self.debug_select = false
    self.collidable = false

    self.layer = layer or 0 --doesnt matter, only Camera3d gets its draw() called
    self.active = true
    self.visible = false --used by Camera3d, but not kristal because of ^
end

return Object3d