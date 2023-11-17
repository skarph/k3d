-- originally written by groverbuger for g3d, see LICENSE
-- september 2021, groveburger; oct 2023 skarph
-- MIT license
----------------------------------------------------------------------------------------------------
-- simple obj loader
-- also slightly more complicated collada loader
-- generates model data, love2d mesh info
----------------------------------------------------------------------------------------------------
if(LoadModel) then printt(debug.traceback()) Kristal.Console:error("Attempted to redfine LoadModel, sticking with initial definition...") return LoadModel end --why do we already exist????
printt("Loading: LoadModel.lua")
--dependencies
require("table.new")
local Xml2lua = libRequire("k3d", "xml2lua.xml2lua")
local TREE_HANDLER = libRequire("k3d", "xml2lua.xmlhandler.tree")
local newMatrix = libRequire("k3d", "scripts.globals.Matrix4x4") --loading order prescedence :/

local Virtual_Mesh = love.graphics.newMesh(1) -- mesh object used to grab mesh functions
    local lg_newMesh = love.graphics.newMesh
    local m_getVertex = Virtual_Mesh.getVertex
    local m_setVertex = Virtual_Mesh.setVertex
    local m_getVertexFormat = Virtual_Mesh.getVertexFormat
    local m_getVertexCount = Virtual_Mesh.getVertexCount
    local m_setTexture = Virtual_Mesh.setTexture
    local m_typeOf = Virtual_Mesh.typeOf
    local m_setVertexAttribute = Virtual_Mesh.setVertexAttribute

local loadModel = {} 
setmetatable(loadModel, loadModel)

--used to construct vertex cdef. should list out VERTEclX_FORMAT with a string being this field's name
-- and a function returnin values. data is the vertex data at this value, index is the vextex's index in load order
local VERTEX_DATAMAP = Kristal.getLibConfig("k3d", "VERTEX_DATAMAP")
--used by love2d
local VERTEX_FORMAT = {}

--namspace refresh hack, generates a unique id that is used for this session and attaches it to the vertex struct name so we never redefine the vertex format, technically.
--TODO: this is a crime. why am i doing this. please dear god come up with something better. is the speed increase even worth it at this point?
local _alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
local SESSION_ID = ""
for i=1, 32 do
    SESSION_ID = SESSION_ID .. _alphabet[ love.math.random(1,#_alphabet) ]
end
local VERTEX_C_IDENTIFIER = "struct vertex"..SESSION_ID
local VERTEX_C_IDENTIFIER_PTR = VERTEX_C_IDENTIFIER.."*"
printt("SESSION_UUID:", SESSION_ID)
Kristal.Console:log( string.format("SESSION_ID: %s", SESSION_ID) )

--load functions from string
for i, data_map in ipairs(VERTEX_DATAMAP) do

    --parse function
    --TODO: very unsafe, runs code from string, look into making it safer?
    assert(type(data_map[4]=="string"), "[k3d] Non-function in config: (VERTEX_DATAMAP # "..i.."): "..tostring(data_map[4]))
    local chunk, err = loadstring("return "..data_map[4])
    assert(not err, "[k3d.config] bad value (VERTEX_DATAMAP # "..i.."): "..tostring(err))
    assert(type(chunk()) == "function", "[k3d.config] not a func (VERTEX_DATAMAP # "..i.."): "..tostring(chunk()))
    data_map[4] = chunk()

    --populate VERTEX_FORMAT
    local found_vertex = false
    for vi, vertex_format in ipairs(VERTEX_FORMAT) do
        if(vertex_format[1] == data_map[1]) then --if names are same
            vertex_format[3] = vertex_format[3] + 1
            found_vertex = true
        end
    end
    if(not found_vertex) then --create the VERTEX_FORMAT entry
        table.insert(VERTEX_FORMAT, {data_map[1], data_map[2], 1})
    end

end

local MODEL_ROOT_DIR = Mod.info.path.."/"..Kristal.getLibConfig("k3d", "model_path") --folder we should look in for all model assets (including textures)
local USAGE = "dynamic" --default usage, "dynamic", "static", "stream"


local CTYPE = {
    float = "float",
    byte = "uint8_t",
    unorm16 = "uint16_t" --TOOD: check this
}
-- the fallback function if ffi was not loaded
local makeMesh = function(verts)
    return verts
end

-- makes models use less memory when loaded in ram
-- by storing the vertex data in an array of vertix structs instead of lua tables
-- requires ffi
-- note: throws away the model's verts table
-- rename due to clashing with an already existing "vertex" symbol???
local success, ffi = pcall(require, "ffi")

if success then
    Kristal.Console:push("[k3d] FFI loaded!")
    --check if we're about to redefine a vertex struct
    local size, err = pcall(ffi.sizeof,VERTEX_C_IDENTIFIER)
    assert(err, "Unlucky Session ID collision. Please reload mod.")
    --define vertex struct with unique identifier
    local cdef = VERTEX_C_IDENTIFIER.." {"
    local vdm_i = 1
    for i, form in ipairs(VERTEX_FORMAT) do
        --defaults
        cdef = cdef .. CTYPE[form[2]]
        for j = 1, form[3] do 
            cdef = cdef .. " ".. VERTEX_DATAMAP[vdm_i][3]..( j~=form[3] and "," or "; ")
            vdm_i = vdm_i + 1
        end
    end
    cdef = cdef.."}"
    ffi.cdef(cdef)
    printt(cdef)
    --error(cdef)
    makeMesh = function(verts, vertexFormat, usage)
        local data = love.data.newByteData(ffi.sizeof(VERTEX_C_IDENTIFIER) * #verts)
        local datapointer = ffi.cast(VERTEX_C_IDENTIFIER_PTR, data:getFFIPointer())

        for i, vert in ipairs(verts) do
            local dataindex = i - 1
            --fill out vertex data
            for j, datamap in ipairs(VERTEX_DATAMAP) do
                datapointer[dataindex][datamap[1]] = datamap[2](vert[j],dataindex)
            end
        end

        --self.mesh:release()
        local mesh = love.graphics.newMesh(vertexFormat, data, "triangles", usage or "dynamic")
        return mesh
    end

else
    error("Unable to load FFI! this should never happen...")
end
--[[------------------------------------------------------------------------------------------------
-- simple COLLADA loader
-- please ignore these notes these were just for me writing
-- triangle syntax
--      <triangles count="1">
--          <input semantic="VERTEX" source="#tail_mesh-mesh-vertices" offset="0"/>
--          <input semantic="NORMAL" source="#tail_mesh-mesh-normals" offset="1"/>
--          <input semantic="COLOR" source="#tail_mesh-mesh-colors-Attribute" offset="2" set="0"/>
--             V N C
--          <p>0 0 0 
--             1 0 1 
--             2 0 2</p>
--      </triangles>
-- nodes of note
-- root node              .root.COLLADA

-- metadata               .root.COLLADA.asset
-- unit scale                 .root.COLLADA.asset.unit_attr.meter
-- up axis                .root.COLLADA.asset.up_axis

-- camera transform data  .root.COLLADA.library_cameras.optics.perspective

--                        .root.COLLADA.library_images

-- root.COLLADA.library_geometries
--  <geometry name>.mesh
--      mesh-positions, mesh-normals, mesh-colors-Attribute,
--  
--xml.root.COLLADA.library_geometries.geometry[i].mesh.source[T].float_array[1] 
--T = position 1, normal 2, color 3
--xml.root.COLLADA.library_geometries.geometry[i].mesh.source[T].float_array._attr.count
--numbers expected ^, seperate " ", acessor count*stride

--xml.root.COLLADA.library_geometries.geometry[i].mesh.source[T].technique_common.accessor._attr.count
--# verts
--xml.root.COLLADA.library_geometries.geometry[i].mesh.source[T].technique_common.accessor._attr.stride
--vert size (3, 4 color)

--input[1,2,3] contain order of vertex data to assemble tri, always in V-N-C format
--_attr.count is the # of triangles, p contains (3 points per tri * 3 vertex data info)*p values
--p contains the indecies into the repsective V-N-T-C tables, multiplied by the stride (3-3-2-4)
--(ex, 3,0,0,3 Vertex @ 3*[3 stride] [+ 1 index by 1] = 10, Normal @0+1=1  and Color @3*[4 stride] + 1 = 13)
--fix this for uv map ^
        
]]----------------------------------------------------------------------------------------------------

--extract the index-th float from a string containing floats at num_list
local FLOAT_PATTERN = "[+-]?[%d%.]+e?[+-]?%d*" --can match bad formats (like 3.9.2), but matches all floats. be careful...
local KEYWORD_PATTERN = "%u+"

local function getNumber(num_list, index)
    local i = 0
    for n_str in num_list:gfind(FLOAT_PATTERN) do
        if(index == i) then
            return tonumber(n_str)
        end
        i = i + 1
    end
    return nil
end

local function parseNumbers(num_list)
    local nums = {}
    for n_str in num_list:gmatch(FLOAT_PATTERN) do
        table.insert(nums, tonumber(n_str))
    end
    return nums
end


local function getNumbers(num_list)
    local nums = {}
    for n_str in num_list:gfind(FLOAT_PATTERN) do
        table.insert(nums, tonumber(n_str))
    end
    return unpack(nums)
end

local function getKeyword(word_list, index)
    local i = 0
    for w_str in word_list:gfind(KEYWORD_PATTERN) do
        if(index == i) then
            return w_str
        end
        i = i + 1
    end
    return nil
end

--reads a collada visaul_scene tree
local function createSceneNodes(xml, scene, mesh_lookup, _parent, _scene_transform)
    --depth first search
    local name = xml._attr.name
    scene[name] =  {
        parent = _parent,
        children = {},
        scene_transform = _scene_transform or newMatrix(),
        local_transform = newMatrix(),
        working_transform = newMatrix(),
        mesh_url = nil
    }
    scene[name].working_transform = newMatrix(scene[name].local_transform):mat_multiply(scene[name].scene_transform)
    if(xml.instance_geometry) then
        scene[name].mesh_url = xml.instance_geometry._attr.url:sub(2)
        mesh_lookup[scene[name].mesh_url] = name
    end
    if(xml.matrix) then
        scene[name].local_transform:set(getNumbers(xml.matrix[1]))
    end
    if(xml.node) then
        --check if node is a supernode that contains multiple nodes
        for _, node in ipairs(xml.node) do
            table.insert(scene[xml._attr.id].children, node._attr.id)
            createSceneNodes(node, scene, mesh_lookup, xml._attr.id,
            newMatrix(scene[name].working_transform))
        end
        --check if node is a singular node
        if(#xml.node == 0) then
            table.insert(scene[xml._attr.id].children, xml.node._attr.id)
            createSceneNodes(xml.node, scene, mesh_lookup, xml._attr.id,
            newMatrix(scene[name].working_transform))
        end
    end
    --temporary, removed by loadDae for mesh lookup
end

-- reads a collada xml from path
-- returns mesh, scene, animation tables
function loadModel.loadcollada(path, texture, uFlip, vFlip, vertexFormat, usage)
    --local file, errorstr = love.filesystem.newFile( path, "r" )

    local xml = Xml2lua.loadFile(path)
    local treehandler = TREE_HANDLER:new()
    local parser = Xml2lua.parser(treehandler)
    parser:parse(xml)
    local root = treehandler.root.COLLADA
 
    --load scene tree
    local scene = {}
    local mesh_lookup = {}
    createSceneNodes(root.library_visual_scenes.visual_scene, scene, mesh_lookup)

    --load meshes without regard for parenting
    local meshes = {}
    --put it in a container if the xml tag has one item (we cant iterate using ipairs without it)
    local geometries = #root.library_geometries.geometry == 0 and {root.library_geometries.geometry} or root.library_geometries.geometry
    
    local geo_num = 1
    
    local ld_newByteData = love.data.newByteData
    local ffi_cast = ffi.cast
    local ffi_sizeof = ffi.sizeof
    for _, node in ipairs(geometries) do
        local id = node._attr.id
        local name = mesh_lookup[id]

        --get locations of vertex data
        local attributes = {}
        for i, source in ipairs(node.mesh.source) do
            attributes[i] = source.float_array and parseNumbers(source.float_array[1])
        end

        local tris_str = node.mesh.triangles.p --list of vertex indexes as string
        local vertex_count = tonumber(node.mesh.triangles._attr.count) * 3 --assume triangles have 3 vertecies
        local data_per_vertex = #node.mesh.triangles.input

        local vertecies = ld_newByteData(ffi_sizeof(VERTEX_C_IDENTIFIER) * vertex_count)
        local vertecies_ptr = ffi_cast(VERTEX_C_IDENTIFIER_PTR, vertecies:getFFIPointer())
        
        local vertex_index = 0

        local asbyte = string.byte
        local t_insert = table.insert
        local data_count = 0
        local v_lookup = {}
        
        local delimiter = asbyte(' ')
        local parsed_number = 0

        for i=1, #tris_str do
            --get the vertex lookup infomration
            local c = asbyte(tris_str, i)
            if(c == delimiter) then
                -- assuming ascii numbers...
                data_count = data_count + 1
                v_lookup[data_count] = parsed_number 
                parsed_number = 0
            else
                parsed_number = (parsed_number * 10) + (c - 48)
                if(i==#tris_str) then --last character, no delimeter
                    data_count = data_count + 1
                    v_lookup[data_count] = parsed_number 
                end
            end

            --we have the lookup values, create the vertex and push it into the mesh
            if(data_count == data_per_vertex) then

                local attribute_index = 1
                assert(vertex_count > vertex_index, "too many vertices from "..path)
                for format_index=1, #VERTEX_FORMAT  do
                    
                    local attribute_length = VERTEX_FORMAT[format_index][3]

                    local lookup = v_lookup[format_index]
                    
                    for attribute_offset=1, attribute_length do

                        local userFunc = VERTEX_DATAMAP[attribute_index][4]
                        local label = VERTEX_DATAMAP[attribute_index][3]

                        if(lookup) then
                            vertecies_ptr[vertex_index][label] = userFunc( attributes[format_index][attribute_length * lookup + attribute_offset] , vertex_index, uFlip, vFlip )
                        else
                            vertecies_ptr[vertex_index][label] = userFunc( nil , vertex_index, uFlip, vFlip )
                        end
                        
                        attribute_index = attribute_index + 1
                    end

                end

                vertex_index = vertex_index + 1
                data_count = 0 --reset vertex data count since we're done with this vertex
            end

        end
        printt(vertex_count)
        --create mesh
        local mesh = lg_newMesh(vertexFormat, vertecies, "triangles", usage or USAGE)
        mesh:setTexture(texture)
        meshes[name] = mesh --makeMesh(verts, vertexFormat, usage)
        geo_num = geo_num + 1
    end

    --load animations
    --start, end, interpolation, source[i]
    local animations = {}
    if(root.library_animations) then
    for _, animation_container in ipairs(root.library_animations.animation) do
        local mesh_target = animation_container._attr.name;
        --this is so annoying. 
        local animation_wrapper = #animation_container.animation == 0 and {animation_container.animation} or animation_container.animation

        for _, animation in ipairs(animation_wrapper) do
            local mesh_name = animation._attr.name
            --<meshname>_<wave>_<number>_transform
            --remove prefix and suffix, and number
            local animation_id = animation._attr.id:sub(#mesh_name+2, -(#"_transform"+1)):gsub("_%d%d%d","")

            animations[animation_id] = animations[animation_id] or {} --instantiate if needed
            local timings = animation.source[1].float_array[1]

            --process keyframes
            local interpolations = animation.source[3].Name_array[1]
            local keyframes = {}
            local i = 0
            local ti = -1 --term index
            animations[animation_id].__duration = animations[animation_id].__duration or 0.0 --length is longest subanimation, in seconds
            for num_str in animation.source[2].float_array[1]:gmatch(FLOAT_PATTERN) do
                local mi = i % 16 + 1 --matrix index
                if mi == 1 then
                    ti = ti + 1
                    --new keyframe

                    local timing = getNumber(timings,ti)
                    --update longest time
                    animations[animation_id].__duration = (timing > animations[animation_id].__duration) and timing or animations[animation_id].__duration
                    table.insert(keyframes, {time = timing, matrix = newMatrix(), interpolation = getKeyword(interpolations,ti)})
                end
                keyframes[#keyframes].matrix[mi] = tonumber(num_str) --fill out top mos matrix
                i = i + 1
            end
            --one unique animation id per mdoel, should never collide
            assert(not animations[animation_id][mesh_name], animation_id.."."..mesh_name..": tried overwriting animation data\n")
            animations[animation_id][mesh_name] = keyframes
            animations[animation_id].__playing = false
            animations[animation_id].__time = 0.0
        end
    end
    end

    return meshes, scene, animations
end

-- give path of file
-- returns a lua table representation
function loadModel.loadobj(path, texture, uFlip, vFlip, vertexFormat, usage)
    local positions, uvs, normals = {}, {}, {}
    local result = {}
    
    -- go line by line through the file
    for line in love.filesystem.lines(path) do
        local words = {}

        -- split the line into words
        for word in line:gmatch "([^%s]+)" do
            table.insert(words, word)
        end

        local firstWord = words[1]

        if firstWord == "v" then
            -- if the first word in this line is a "v", then this defines a vertex's position

            table.insert(positions, {tonumber(words[2]), tonumber(words[3]), tonumber(words[4])})
        elseif firstWord == "vt" then
            -- if the first word in this line is a "vt", then this defines a texture coordinate

            local u, v = tonumber(words[2]), tonumber(words[3])

            -- optionally flip these texture coordinates
            if uFlip then u = 1 - u end
            if vFlip then v = 1 - v end

            table.insert(uvs, {u, v})
        elseif firstWord == "vn" then
            -- if the first word in this line is a "vn", then this defines a vertex normal
            table.insert(normals, {tonumber(words[2]), tonumber(words[3]), tonumber(words[4])})
        elseif firstWord == "f" then

            -- if the first word in this line is a "f", then this is a face
            -- a face takes three point definitions
            -- the arguments a point definition takes are vertex, vertex texture, vertex normal in that order

            local vertices = {}
            for i = 2, #words do

                local v, vt, vn = words[i]:match "(%d*)/(%d*)/(%d*)"
                v, vt, vn = tonumber(v), tonumber(vt), tonumber(vn)
                table.insert(vertices, {
                    v and positions[v][1] or 0,
                    v and positions[v][2] or 0,
                    v and positions[v][3] or 0,
                    vt and uvs[vt][1] or 0,
                    vt and uvs[vt][2] or 0,
                    vn and normals[vn][1] or 0,
                    vn and normals[vn][2] or 0,
                    vn and normals[vn][3] or 0,
                    1,
                    1,
                    1,
                    1,
                    (#vertices%3 == 0) and 1 or 0 ,
                    (#vertices%3 == 1) and 1 or 0 ,
                    (#vertices%3 == 2) and 1 or 0 ,
                })
            end

            -- triangulate the face if it's not already a triangle
            if #vertices > 3 then
                -- choose a central vertex
                local centralVertex = vertices[1]

                -- connect the central vertex to each of the other vertices to create triangles
                for i = 2, #vertices - 1 do
                    table.insert(result, centralVertex)
                    table.insert(result, vertices[i])
                    table.insert(result, vertices[i + 1])
                end
            else
                for i = 1, #vertices do
                    table.insert(result, vertices[i])
                end
            end

        end
    end
    local mesh = makeMesh(result, vertexFormat, usage)
    mesh:setTexture(texture)
    return {mesh}, {}, {} --no scene, no animation
end

--stores models after we load them:
--key = local file path passed in from LoadModel(path)
K3D_MODEL_CACHE = {}

--   Controls the cacheing levels, ordered by speed
--0: No Cacheing. Models re-loaded from local files every time.
--1: Clone Mesh. Model data are retrived from cache, meshes are cloned
--2: Mesh Refrence. Model data are retrived from cache, meshes pointers are copied to model

K3D_CACHE_LEVEL = Kristal.getLibConfig("k3d", "cache")

--Utils.copyInto that handles love2d usserdata properly, optimized for model cacheing
--doesnt copy texture info

local function copyCache(new_tbl, tbl, texture)
    if tbl == nil then return nil end

    for k,v in pairs(tbl) do
        --we're deep copying, and the value is a table, then we need to copy that table as well.
        if type(v) == "table" then
            new_tbl[k] = {}
            copyCache(new_tbl[k], v, texture)
        elseif( type(v) == "userdata" and m_typeOf(v,"Mesh") ) then

            if(false) then --fastcache
                m_setTexture(v, texture)
                new_tbl[k] = v
            else
            -- handle mesh cloning
                local vertex_format, vertex_count, usage = m_getVertexFormat(v), m_getVertexCount(v), "dynamic"
                local mesh = lg_newMesh(vertex_format, vertex_count, "triangles", usage)
                --TODO: figure out how to extract SpriteBatchUsage 
                --local verts = {}
                for i=1, vertex_count do
                    m_setVertex(mesh, i, m_getVertex(v, i) )
                end
                m_setTexture(mesh, texture)
                new_tbl[k] = mesh
            end
        else
            -- The value isn't a table or we're not deep copying, so just use the value.
            new_tbl[k] = v
        end
    end

    setmetatable(new_tbl, getmetatable(tbl))
    --[[
    -- Call the onClone callback on the newly copied table, if it exists.
    if new_tbl.onClone then
        new_tbl:onClone(tbl)
    end
    ]]
end

--caches an entire folder of model/textures into their appropriate global tables
function loadModel.cacheFolder(dir)
    dir = MODEL_ROOT_DIR or dir
    printt("cacheing all models + textures in",dir)

    for i, file_name in ipairs( love.filesystem.getDirectoryItems( dir ) ) do
        local path = dir..file_name
        printt(i,":",path)
        loadModel.cacheFile(path)
    end

end

function loadModel.cacheFile(path)
    local filesuffix = nil
    for w in path:gmatch(".%a+") do
        filesuffix = w
    end
    filesuffix = filesuffix:sub(2) --remove .
    
    if(loadModel.filetypes[filesuffix]) then
        K3D_MODEL_CACHE[path] = {loadModel(path, nil, nil, nil, nil, nil, "")}
    else --assume texture?
        K3D_TEXTURE_CACHE[path] =love.graphics.newImage(path,
            {
                mipmaps = true,
                linear = false
            }
        )
    end
end

loadModel.filetypes = 
{
    obj = loadModel.loadobj,
    dae = loadModel.loadcollada
}

--returns vertex information, scene information, and animation information
function loadModel.__call(_, path, texture, uFlip, vFlip, vertexFormat, usage, root_dir)
    printt("started clock ["..path.."] ["..tostring(texture).."]")
    local t = os.clock()

    assert(type(path) == "string", "<path> is not string")
    path = (root_dir or MODEL_ROOT_DIR)..path

    assert(love.filesystem.getInfo(path), "File does not exist: "..path)
    assert(love.filesystem.getInfo(path).type == "file", "Path does not point to a file: "..path)

    if(texture) then
        if(type(texture) == "userdata" and texture:typeOf("Texture")) then
            --error("IT WORKS :D")
        elseif(type(texture) == "string") then
            assert(type(texture) == "string", "<texture> is not string or Image")
            texture = (root_dir or MODEL_ROOT_DIR)..texture
            assert(
                love.filesystem.getInfo(texture)
                ,"Texture pathdoes not point to a file"
            )
            --check cache first
            if(K3D_CACHE_LEVEL > 0 and K3D_TEXTURE_CACHE[texture]) then
                printt("texcache hit at "..texture.." !")
                texture = K3D_TEXTURE_CACHE[texture]
            else
                printt("texcacheing "..texture)
                texture = love.graphics.newImage(texture,{
                    mipmaps = true,
                    linear = false
                })
            end
        end
    end

    local filesuffix = nil
    for w in path:gmatch(".%a+") do
        filesuffix = w
    end
    filesuffix = filesuffix:sub(2) --remove .
    assert(loadModel.filetypes[filesuffix], "unsupported or unrecognized format: "..(filesuffix or "Please appened a valid model filetype suffix"))
    --TODO: blender seems to export v's wrong?, force them on for now..
    
    local meshes, tree, anim
    if(K3D_CACHE_LEVEL > 0 and K3D_MODEL_CACHE[path]) then
        printt("cache hit at "..path.." !")
        --clone them if in cache
        local data = {}
        copyCache(data, K3D_MODEL_CACHE[path], texture)
        meshes, tree, anim = unpack( data )
    else
        --load them if not in cache
        meshes, tree, anim = loadModel.filetypes[filesuffix](path, texture, uFlip or false, vFlip or true, vertexFormat or VERTEX_FORMAT, usage or USAGE)
        printt("cacheing "..path)
        K3D_MODEL_CACHE[path] = {meshes, tree, anim}
    end
    
    printt( string.format("loaded %s in %f", path, os.clock() - t) )
    return meshes, tree, anim
end

return loadModel
