local Object = Object

--this is a mess im so tired
Utils.hook(Object, "update", function(orig, self)
        self:updatePhysicsTransform()
        self:updateGraphicsTransform()
    
        self:updateChildren()
    
        if self.camera then
            self.camera:update()
        end

        --update camera3d after regular camera updates since we might grab some information from it
        if(self.camera3d) then
            self.camera3d:update()
        end
end)
Utils.hook(Object, "drawChildren",function(orig, self, min_layer, max_layer) -- src/engine/object.lua:1547
    if self.update_child_list then
        self:updateChildList()
        self.update_child_list = false
    end
    if self._dont_draw_children then
        return
    end
    if not min_layer and not max_layer then
        min_layer = self.draw_children_below
        max_layer = self.draw_children_above
    end
    local oldr, oldg, oldb, olda = love.graphics.getColor()
    --k3d render models to camera3d first
    if(self.camera3d) then
        self.camera3d:renderModels()
    end
    for _,v in ipairs(self.children) do
        if 
            v.visible and
            (not min_layer or v.layer >= min_layer) and
            (not max_layer or v.layer < max_layer) and
            (v == self.camera3d or not v.ThreeDee)
        then
            v:fullDraw()
        end
    end
    Draw.setColor(oldr, oldg, oldb, olda)
end)

return Object