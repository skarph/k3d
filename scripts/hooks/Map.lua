local Map = Map

Utils.hook(Map,"init", function(orig, self, world, data)
    orig(self, world, data)
    
    if(world and data) then
        if(not world.camera3d) then
            print("making new camera3d")
            world.camera3d = Camera3d()
        end
        local prop = data.properties
        local cam_x, cam_y, cam_z = prop.cam_x or 0, prop.cam_y or 0, prop.cam_z or 0
        local up_x, up_y, up_z = prop.cam_up_x or 0, prop.cam_up_y or 0, prop.cam_up_z or 0
        local look_x, look_y, look_z = prop.cam_focus_x or 0, prop.cam_focus_y or 0, prop.cam_focus_z or 0

        printt("MapCamData", look_x,look_y,look_z, cam_x,cam_y,cam_z, up_x,up_y,up_z, prop.cam_layer, prop.follow_camera)
        world.camera3d:setLayer(prop.cam_layer or 0.2)
        if(prop.free_camera) then --manual camera control
            printt("camera is free")
            ame.world.camera3d:updateProjectionMatrix() --put in projective mode
            world.camera3d:lookAt(look_x,look_y,look_z, cam_x,cam_y,cam_z, up_x,up_y,up_z)
        else --follow world.camera
            
            printt("tracking world camera", tostring(world.camera))
            --Game.world.camera3d:updateOrthographicMatrix() --put in orthographic mode
            --Game.world.camera3d:updateProjectionMatrix()
            world.camera3d:trackCamera(world.camera, cam_x, cam_y, cam_z)
            Game.world.camera3d:setFocus(3)
        end
    end
end)

return Map