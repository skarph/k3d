-- originally written by groverbuger for g3d, see LICENSE
-- september 2021, groveburger; oct 2023 skarph
-- MIT license
----------------------------------------------------------------------------------------------------
-- simple obj loader
-- also slightly more complicated collada loader
-- generates model data, love2d mesh info
----------------------------------------------------------------------------------------------------
if(LoadModel) then Kristal.Console:error("Attempted to redfine LoadModel, sticking with initial definition...") return LoadModel end --why do we already exist????
--dependencies

printt("Loading: LoadModel.lua")
local Xml2lua = libRequire("k3d", "xml2lua.xml2lua")
local TREE_HANDLER = libRequire("k3d", "xml2lua.xmlhandler.tree")
local newMatrix = libRequire("k3d", "scripts.globals.Matrix4x4")

local loadModel = {} 
setmetatable(loadModel, loadModel)

--todo: unhardcode these *fully* 
--default vertex format
local VERTEX_FORMAT = Kristal.getLibConfig("k3d", "VERTEX_FORMAT")

--used to construct vertex cdef. should list out VERTEclX_FORMAT with a string being this field's name
-- and a function returnin values. data is the vertex data at this value, index is the vextex's index in load order
local VERTEX_DATAMAP = Kristal.getLibConfig("k3d", "VERTEX_DATAMAP")
--load functions from string

for i, datamap in ipairs(VERTEX_DATAMAP) do
    assert(type(datamap[2]=="string"), "[k3d] Non-function in config: (VERTEX_DATAMAP # "..i.."): "..tostring(datamap[2]))
    local chunk, err = loadstring("return "..datamap[2])
    assert(not err, "[k3d.config] bad value (VERTEX_DATAMAP # "..i.."): "..tostring(err))
    assert(type(chunk()) == "function", "[k3d.config] not a func (VERTEX_DATAMAP # "..i.."): "..tostring(chunk()))
    datamap[2] = chunk()
end

local MODEL_ROOT_DIR = Mod.info.path..Kristal.getLibConfig("k3d", "model_path") --folder we should look in for all model assets (including textures)
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
    local vertex_format_loaded, err = pcall(ffi.sizeof,"struct vertex")
    if vertex_format_loaded then
        Kristal.Console:warn("[k3d] vertex format already in memory, but why? skipping loading...")
    else
        --construct cstruct
        local cdef = "struct vertex {"
        local vdm_i = 1
        for i, form in ipairs(VERTEX_FORMAT) do
            --defaults
            cdef = cdef .. CTYPE[form[2]]
            for j = 1, form[3] do 
                cdef = cdef .. " ".. VERTEX_DATAMAP[vdm_i][1]..( j~=form[3] and "," or "; ")
                vdm_i = vdm_i + 1
            end
        end
        cdef = cdef.."}"

    ffi.cdef(cdef)
    end

    makeMesh = function(verts, vertexFormat, usage)
        local data = love.data.newByteData(ffi.sizeof("struct vertex") * #verts)
        local datapointer = ffi.cast("struct vertex*", data:getFFIPointer())

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
    Kristal.Console:warn("[k3d] Unable to load FFI, using tables-as-vertex...")
end

--stores models after we load them:
--key = local file path passed in from LoadModel(path)
K3D_MODEL_CACHE = {}
--Utils.copyInto that handles love2d usserdata properly, optimized for model cacheing
--doesnt copy texture info
local function copyCache(new_tbl, tbl, texture, deep, seen)
    if tbl == nil then return nil end

    -- Remember the current table we're copying, so we can avoid
    -- infinite loops when deep copying tables that reference themselves.
    seen = seen or {}
    seen[tbl] = new_tbl
    local t_insert = table.insert
    for k,v in pairs(tbl) do
        -- If we're deep copying, and the value is a table, then we need to copy that table as well.
        if type(v) == "table" and deep then
            if seen[v] then
                -- If we've already seen this table, use the same copy.
                
                new_tbl[k] = {}
                copyCache(new_tbl[k], v, texture, true, seen)
            else
                -- Otherwise, just copy the reference.
                new_tbl[k] = v
            end
        elseif( type(v) == "userdata" and v:typeOf("Mesh")) then
            -- handle mesh cloning
            --TODO: figure out how to extract SpriteBatchUsage 
            local vertexFormat, usage = v:getVertexFormat(), "dynamic"
            local verts = {}
            for i=1, v:getVertexCount() do
                t_insert( verts, {v:getVertex(i)} )
            end
            local mesh = makeMesh(verts, vertexFormat, usage)
            mesh:setTexture(texture)
            new_tbl[k] = mesh
        else
            -- The value isn't a table or we're not deep copying, so just use the value.
            new_tbl[k] = v
        end
    end
    --[[
    -- Copy the metatable too.
    setmetatable(new_tbl, getmetatable(tbl))

    -- Call the onClone callback on the newly copied table, if it exists.
    if new_tbl.onClone then
        new_tbl:onClone(tbl)
    end
    ]]
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

    for _, node in ipairs(geometries) do
        local id = node._attr.id
        local name = mesh_lookup[id]

        --get locations of vertex data
        --TODO: check if this always holds true? there's url pointers for a reason
        local positions = node.mesh.source[1].float_array[1]
        local normals = node.mesh.source[2].float_array[1]
        local texmaps = node.mesh.source[3].float_array[1]
        --TODO: proper handeling of missing vertex info/ different vertex formats
        local colors = node.mesh.source[4] and node.mesh.source[4].float_array[1]

        -- pre-parse positions, normals, texmaps, and colors from strings into tables of numbers.
        local positions_table = parseNumbers(positions)
        local normals_table = parseNumbers(normals)
        local texmaps_table = parseNumbers(texmaps)
        local colors_table = parseNumbers(colors)


        local tris_str = node.mesh.triangles.p --list of vertex indexes as string
        local verts = {}


        ---testing
        local loops = 1

        local asbyte = string.byte
        local t_insert = table.insert
        local data_per_vertex = 4
        local data_count = 1
        local v_lookup = {0,0,0,0}
        --
        -- estop
        
        local delimiter = asbyte(' ')
        local parsed_number = 0
        local parsed_position = 0

        for i=1, #tris_str do
            --get the vertex lookup infomration
            local c = asbyte(tris_str, i)
            if(c == delimiter) then
                -- assuming ascii numbers...
                v_lookup[data_count] = parsed_number
                parsed_number = 0
                data_count = data_count + 1
            else
                parsed_number = (parsed_number * 10) + (c - 48)
            end

            if(data_count == data_per_vertex) then
                --handle the verex data
                --printt(v_lookup[1], v_lookup[2], v_lookup[3], v_lookup[4])

                local pos, nrm, tex, clr =  
                    3 * v_lookup[1], 
                    3 * v_lookup[2], 
                    2 * v_lookup[3], 
                    4 * v_lookup[4] 
                --should always these 4, in this order, with these strides. if it isnt, rewrite code
                --build triangle
                local vert = {}
                table.insert( verts, 
                    {
                    logAssert(positions_table[pos + 1],path..": could not find mesh id ["..id.."] vertex position x value at index ["..pos.."]") or 0,--v and positions[v][1] or 0,
                    logAssert(positions_table[pos + 2],path..": could not find mesh id ["..id.."] vertex position y value at index ["..pos.."]") or 0,--v and positions[v][2] or 0,
                    logAssert(positions_table[pos + 3],path..": could not find mesh id ["..id.."] vertex position z value at index ["..pos.."]") or 0,--v and positions[v][3] or 0,

                    logAssert((uFlip and ( 1 - texmaps_table[tex + 1] ) or texmaps_table[tex + 1]),path..": could not find mesh id ["..id.."] vertex texmap S value at index ["..pos.."]") or 0,--do u flip; vt and uvs[vt][1] or 0,
                    logAssert((vFlip and ( 1 - texmaps_table[tex + 2] ) or texmaps_table[tex + 2]),path..": could not find mesh id ["..id.."] vertex texmap T value at index ["..pos.."]") or 0,--do v flip; vt and uvs[vt][2] or 0,

                    logAssert(normals_table[nrm + 1],path..": could not find mesh id ["..id.."] vertex normal x value at index ["..pos.."]") or 0,--vn and normals[vn][1] or 0,
                    logAssert(normals_table[nrm + 2],path..": could not find mesh id ["..id.."] vertex normal y value at index ["..pos.."]") or 0,--vn and normals[vn][2] or 0,S
                    logAssert(normals_table[nrm + 3],path..": could not find mesh id ["..id.."] vertex normal z value at index ["..pos.."]") or 0,--vn and normals[vn][3] or 0,

                    logAssert(colors_table[clr + 1],path..": could not find mesh id ["..id.."] vertex color r value at index ["..pos.."]") or 0,--R,
                    logAssert(colors_table[clr + 2],path..": could not find mesh id ["..id.."] vertex color b value at index ["..pos.."]") or 0,--G,
                    logAssert(colors_table[clr + 3],path..": could not find mesh id ["..id.."] vertex color g value at index ["..pos.."]") or 0,--B,
                    logAssert(colors_table[clr + 4],path..": could not find mesh id ["..id.."] vertex color a value at index ["..pos.."]") or 0,--A,

                    (#verts % 3 == 0) and 1 or 0,--barycentric alpha(#vertices%3 == 0) and 1 or 0 ,
                    (#verts % 3 == 1) and 1 or 0,--barycentric beta(#vertices%3 == 1) and 1 or 0 ,
                    (#verts % 3 == 2) and 1 or 0--barycentric gamma(#vertices%3 == 2) and 1 or 0 ,
                    }
                )
                --printt(string.format("done loop (%d)#%d in t:%f",geo_num,i,os.clock()-t))
                data_count = 0 --reset vertex data count since we're done with this vertex
                loops = loops + 1

            end
        end
        --]]
        --end testing

        --TODO: This is the culprint!
        -- takes about 20 seocnds to load monkey.dae because it does 2901 matches? it works but still, 
        --[[
        for v_str in tris_str:gfind("%d+ %d+ %d+ %d+") do --parse tristr vertex quadruplets as ints
            local v_itr = v_str:gfind("%d+") --seperate ints
            local pos, nrm, tex, clr =  
                3 * tonumber(v_itr()), 
                3 * tonumber(v_itr()), 
                2 * tonumber(v_itr()), 
                4 * tonumber(v_itr()) 
            --should always these 4, in this order, with these strides. if it isnt, rewrite code
            --build triangle
            local vert = {}
            table.insert( verts, 
                {
                logAssert(getNumber(positions,pos),path..": could not find mesh id ["..id.."] vertex position x value at index ["..pos.."]") or 0,--v and positions[v][1] or 0,
                logAssert(getNumber(positions,pos + 1),path..": could not find mesh id ["..id.."] vertex position y value at index ["..pos.."]") or 0,--v and positions[v][2] or 0,
                logAssert(getNumber(positions,pos + 2),path..": could not find mesh id ["..id.."] vertex position z value at index ["..pos.."]") or 0,--v and positions[v][3] or 0,
                
                logAssert((uFlip and ( 1 - getNumber(texmaps,tex) ) or getNumber(texmaps,tex)),path..": could not find mesh id ["..id.."] vertex texmap S value at index ["..pos.."]") or 0,--do u flip; vt and uvs[vt][1] or 0,
                logAssert((vFlip and ( 1 - getNumber(texmaps,tex + 1) ) or getNumber(texmaps,tex + 1)),path..": could not find mesh id ["..id.."] vertex texmap T value at index ["..pos.."]") or 0,--do v flip; vt and uvs[vt][2] or 0,
                
                logAssert(getNumber(normals, nrm),path..": could not find mesh id ["..id.."] vertex normal x value at index ["..pos.."]") or 0,--vn and normals[vn][1] or 0,
                logAssert(getNumber(normals, nrm + 1),path..": could not find mesh id ["..id.."] vertex normal y value at index ["..pos.."]") or 0,--vn and normals[vn][2] or 0,S
                logAssert(getNumber(normals, nrm + 2),path..": could not find mesh id ["..id.."] vertex normal z value at index ["..pos.."]") or 0,--vn and normals[vn][3] or 0,
                
                logAssert(getNumber(colors, clr),path..": could not find mesh id ["..id.."] vertex color r value at index ["..pos.."]") or 0,--R,
                logAssert(getNumber(colors, clr + 1),path..": could not find mesh id ["..id.."] vertex color b value at index ["..pos.."]") or 0,--G,
                logAssert(getNumber(colors, clr + 2),path..": could not find mesh id ["..id.."] vertex color g value at index ["..pos.."]") or 0,--B,
                logAssert(getNumber(colors, clr + 3),path..": could not find mesh id ["..id.."] vertex color a value at index ["..pos.."]") or 0,--A,
                
                (#verts % 3 == 0) and 1 or 0,--barycentric alpha(#vertices%3 == 0) and 1 or 0 ,
                (#verts % 3 == 1) and 1 or 0,--barycentric beta(#vertices%3 == 1) and 1 or 0 ,
                (#verts % 3 == 2) and 1 or 0--barycentric gamma(#vertices%3 == 2) and 1 or 0 ,
                }
            )
            --printt(string.format("done loop (%d)#%d in t:%f",geo_num,i,os.clock()-t))
            i = i + 1
        end
        --]]
        --printt(string.format("done in %d loops, t:%f", loops,os.clock()-t))   
        --create mesh
        meshes[name] = makeMesh(verts, vertexFormat, usage)
        meshes[name]:setTexture(texture)
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

loadModel.filetypes = 
{
    obj = loadModel.loadobj,
    dae = loadModel.loadcollada
}

--returns vertex information, scene information, and animation information
function loadModel.__call(_, path, texture, uFlip, vFlip, vertexFormat, usage, root_dir)
    printt("started clock... ")
    local t = os.clock()

    assert(type(path) == "string", "<path> is not string")
    local path = (root_dir or MODEL_ROOT_DIR)..path
    local texture = texture
    assert(love.filesystem.getInfo(path), "File does not exist: "..path)
    assert(love.filesystem.getInfo(path).type == "file", "Path does not point to a file: "..path)
    if(texture) then
        if(type(texture.type) == "function" and texture:type() == "Texture") then
            --error("IT WORKS :D")
        else
            assert(type(texture) == "string", "<texture> is not string")
            assert(
                love.filesystem.getInfo((root_dir or MODEL_ROOT_DIR)..texture)
                ,"Texture pathdoes not point to a file"
            )
            texture = love.graphics.newImage(MODEL_ROOT_DIR..texture,{
                mipmaps = true,
                linear = false
            })
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
    if(K3D_MODEL_CACHE[path]) then
        printt("cache hit at "..path.." !")
        --clone them if in cache
        local data = {}
        copyCache(data,K3D_MODEL_CACHE[path], texture)
        meshes, tree, anim = unpack( data )
    else
        --load them if not in cache
        meshes, tree, anim = loadModel.filetypes[filesuffix](path, texture, uFlip or false, vFlip or true, vertexFormat or VERTEX_FORMAT, usage or USAGE)
        printt("cacheing "..path.." and texture")
        K3D_MODEL_CACHE[path] = {meshes, tree, anim}
    end
    
    printt( string.format("loaded %s in %f", path, os.clock() - t) )
    return meshes, tree, anim
end

return loadModel
