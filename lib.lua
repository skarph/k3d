--[[
    k3d by skarph
]]
local lib = {}

--TODO: find better way to maintain this list...
local k3dObjects = {
    Object3d = function() return _G["Object3d"] end,
    Model = function() return _G["Model"] end,
    Camera3d = function() return _G["Camera3d"] end,
}
--this is basically a switch statement that executes the function to look up the classes, defaults to a null constructor if it doesnt exist
setmetatable(k3dObjects, {__index =
    function(table, key) 
        return rawget(table, key) or function() return function() end end
    end})

function lib:init()
    print("-====Loading k3d====-")
end

function lib:unload()
    print("-===Unloading k3d===-")
end

function lib:loadObject(world, name, data)
    return k3dObjects[name]()(data, world)
end

-- debug setup --
function logAssert(input,msg)
    if(not input) then
        print("[ERROR][k3d] "..tostring(msg))
        Kristal.Console:error(msg)
        return nil
    end
    return input
end

printt = printt or function() end --does nothing by default for preformance/shutting up the console reasons
rawgetclassname = rawgetclassname or function() end --nothing again, but need toexpose it
rawtostring = rawtostring or function() end --same here, in case
if(Kristal.getLibConfig("k3d", "debug")) then

    function lib:onMousePressed(win_x, win_y, button, istouch, presses)
        if(Game.world and Game.world.camera3d) then
            Game.world.camera3d:onMousePressed(win_x, win_y, button, istouch, presses)
        end
        if(Game.battle and Game.battle.camera3d) then
            Game.battle.camera3d:onMousePressed(win_x, win_y, button, istouch, presses)
        end
    end

    function lib:onMouseReleased(win_x, win_y, button, istouch, presses)
        if(Game.world and Game.world.camera3d) then
            Game.world.camera3d:onMouseReleased(win_x, win_y, button, istouch, presses)
        end
        if(Game.battle and Game.battle.camera3d) then
            Game.battle.camera3d:onMouseReleased(win_x, win_y, button, istouch, presses)
        end
    end

    function lib:onMouseMoved(x, y, dx, dy, istouch)
        if(Game.world and Game.world.camera3d) then
            Game.world.camera3d:onMouseMoved(x, y, dx, dy, istouch)
        end
        if(Game.battle and Game.battle.camera) then
            Game.battle.camera3d:onMouseMoved(x, y, dx, dy, istouch)
        end
    end

    Utils.hook(DebugSystem, "onWheelMoved", function(orig, self, x, y) 
        orig(self, x ,y)
        if(Game.world and Game.world.camera3d) then
            Game.world.camera3d:onWheelMoved(x,y)
        end
        if(Game.battle and Game.battle.camera) then
            Game.battle.camera3d:onWheelMoved(x,y)
        end
        
    end)

    Utils.hook(Console, "unsafeRun", function(orig, self, str)
        local chunk, err = loadstring(str)
        if chunk then
            self.env.selected = Kristal.DebugSystem.object
            self.env["_"] = Kristal.DebugSystem.object
            setfenv(chunk,self.env)
            self:push(chunk())
        else
            --try to print as variable
            local pchunk, perr = loadstring("print(tostring("..str.."))" )
            if(pchunk) then
                self.env.selected = Kristal.DebugSystem.object
                self.env["_"] = Kristal.DebugSystem.object
                setfenv(pchunk,self.env)
                self:push(pchunk())
            else
                self:error(self:stripError(err)) --print failed, propogate original error
            end
        end
    end)

    SHORT_SERIALIZE = false

    --https://stackoverflow.com/questions/43285679/is-it-possible-to-bypass-tostring-the-way-rawget-set-bypasses-index-newind
    local function reallygetmetatable(t)
        return debug and debug.getmetatable(t) or getmetatable(t)
    end
    function rawtostring(t)
        local m=reallygetmetatable(t) or t
        local f=m.__tostring
        m.__tostring=nil
        local s=tostring(t)
        m.__tostring=f
        return s
    end
    --Utils .getclass that uses rawget 
    function rawgetclassname(class, parent_check)
        -- If the class is a global variable, return its name.
        for k,v in pairs(_G) do
            if rawget(class,"__includes") == v then
                return k
            end
        end
        -- If the class doesn't have a global variable, find the name of the highest class it extends.
        for i,v in ipairs(rawget(class,"__includes") or {}) do
            local name = rawgetclassname(v, true)
            if name then
                if not parent_check and rawget(class,"id") then
                    -- If the class has an ID, append it to the name of its parent class.
                    return name .. "(" .. rawget(class,"id") .. ")"
                else
                    return name
                end
            end
        end
    end
    --Utils.dump but with table pointers, class name/metatable. regress safe and sparse array friendly. for when you REALLY want everything dumped
    local MAX_DEPTH = 100
    local function fulldump(o,stop_objects,_parents,_depth)
        if(not _parents) then _parents = {} end
        if(not _depth) then _depth = 0 end
        _depth = _depth + 1
        if type(o) == 'table' then
            if(Utils.containsValue(_parents, o) or _depth >= MAX_DEPTH) then return rawtostring(o) end --infinte cycle break
            table.insert(_parents, o)
            local s = "--[["
            local cn = 1
            if isClass(o) then
                -- If the table is a class, return the
                -- name of the class instead of its contents.
                -- isCLass(o) does not garuntee that o is a class. go figure.
                    s = s..( rawgetclassname(o) or ("MT" .. rawtostring(getmetatable(o))) ).."|"
                    if((getmetatable(o) and getmetatable(o).__tostring)) then
                        --tostring probably pretty prints and breaks lua conventions, so wrap it in a comment too
                        return s..rawtostring(o).."]]--[["..tostring(o).."]]{}"
                    end
                    if(stop_objects and _depth > 1) then --if it's a regular table with metatable, display values
                        return s..rawtostring(o).."]]--[[".."...".."]]{}"
                    end
            end
            s = s..rawtostring(o).."]]{"
            local function dumpKey(key, _parent)
                if type(key) == 'table' then
                    return '('..tostring(key)..')'
                elseif type(key) == 'string' and (not key:find("[^%w_]") and not tonumber(key:sub(1,1)) and key ~= "") then
                    return key
                else
                    return '['..fulldump(key,stop_objects,_parents,_depth)..']'
                end
            end
            for k,v in pairs(o) do
                if cn > 1 then s = s .. ', ' end
                s = s .. dumpKey(k,o) .. ' = ' .. fulldump(v,stop_objects,_parents,_depth)
                cn = cn + 1
            end
            return s .. '}'
        elseif type(o) == 'string' then
            return '"' .. o .. '"'
        else
            return tostring(o)
        end
    end

    --serializes arbitrary number of values using dump ^. respects metatable __tostring
    function serialize(...)
        local print_string = ""
        local arg = {...} --for some reason lua's arg doesnt work???
        for i, str in ipairs(arg) do
            if type(str) == "table" then
                str = (getmetatable(str) and getmetatable(str).__tostring) and str or fulldump(str,SHORT_SERIALIZE) -- use metatable __tostring if applicable
            end
            print_string = print_string .. tostring(str)
            if i ~= #arg then
                print_string = print_string  .. "    "
            end
        end

        return print_string
    end
    --print with line info
    printt = function(...)
        local location = debug.getinfo(2,"lS")
        print(string.format("[%s:%d]",location.source:gsub("@",""),location.currentline), serialize(...))
    end 

    dwarn = dwarn or function(...)

    end
    --DebugSystem
    Utils.hook(DebugSystem, "printShadow", function(orig, self, text, x, y, color, align, limit, size)
        local color = color or {1, 1, 1, 1}
        -- Draw the shadow, offset by two pixels to the bottom right
        love.graphics.setFont(self.font)
        Draw.setColor({0, 0, 0, color[4]})
        love.graphics.printf(text, x + 2, y + 2, limit or self.font:getWidth(text), align or "left", 0, size)

        -- Draw the main text
        Draw.setColor(color)
        love.graphics.printf(text, x, y, limit or self.font:getWidth(text), align or "left", 0, size)
    end)
    
    --Debug Object Selection side draw stuff--
    local menu_x = 0
    local menu_y = 0
    local menu_alpha = 0
    local circle_alpha = 1
    local debug_line = 1

    local function debug_print(str, x, y, size, clr, debugsystem)
        local debugsystem = debugsystem or Kristal.DebugSystem
        if(not (x or y) ) then
            local _, count = string.gsub(str, "\n", "")
            debug_line = debug_line + count*(size or 1) + 1
        end
        debugsystem:printShadow(str, x or 12, y or (480 - 32*debug_line) + Utils.lerp(16, 0, menu_alpha), clr or {1, 1, 1, menu_alpha}, nil, size)
    end

    Utils.hook(DebugSystem, "draw", function(orig, self) 
        orig(self)
        debug_line = 1
        if self.state ~= "IDLE" then
            menu_y = Utils.ease(-32, 0, self.menu_anim_timer, "outExpo")
            menu_alpha = Utils.ease(0, 1, self.menu_anim_timer, "outExpo")
        else
            menu_y = Utils.ease(0, -32, self.menu_anim_timer, "outExpo")
            menu_alpha = Utils.ease(1, 0, self.menu_anim_timer, "outExpo")
            circle_alpha = Utils.lerp(1, 0, self.menu_anim_timer/1.4, true)
        end

        if self.state == "SELECTION" or (self.old_state == "SELECTION" and self.state == "IDLE" and (menu_alpha > 0)) then
            local mx, my = Input.getCurrentCursorPosition()
            if(Game.battle and Game.battle.camera3d) then
                --local vx, vy, vz = Game.battle.camera3d:screenToRay(mx, my)
                --debug_print(string.format("Mouse3dBtl: (%f, %f, %f)", vx, vy, vz))
                local det = 0
                if(Input.down("ctrl")) then
                    debug_print(tostring(Game.battle.camera3d.projectionMatrix))
                    det = Game.battle.camera3d.projectionMatrix:determinant()
                else
                    debug_print(tostring(Game.battle.camera3d.matrix))
                    det = Game.battle.camera3d.matrix:determinant()
                end
                debug_print(string.format("BattleCam3d\nX:%.3f Y:%.3f Z:%.3f DET:%f\nQ:%s",
                    Game.battle.camera3d.x, Game.battle.camera3d.y, Game.battle.camera3d.z, det,
                    Quaternion.tostring(Game.battle.camera3d:getQuaternion())
                ))
            end
            if(Game.world and Game.world.camera3d) then
                --local vx, vy, vz = Game.world.camera3d:screenToRay(mx, my)
                --debug_print(string.format("Mouse3d: (%f, %f, %f)", vx, vy, vz))
                local det = 0
                if(Input.down("ctrl")) then
                    debug_print(tostring(Game.world.camera3d.projectionMatrix))
                    det = Game.world.camera3d.projectionMatrix:determinant()
                else
                    debug_print(tostring(Game.world.camera3d.matrix))
                    det = Game.world.camera3d.matrix:determinant()
                end
                debug_print(string.format("WorldCam3d\nX:%.3f Y:%.3f Z:%.3f DET:%f\nQ:%s",
                    Game.world.camera3d.x, Game.world.camera3d.y, Game.world.camera3d.z, det,
                    Quaternion.tostring(Game.world.camera3d:getQuaternion())
                ))
            end
        end
    end)

end

return lib