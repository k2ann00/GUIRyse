local State = require "state"
local Console = require "modules.console"
local Shaders = require "modules.shaders"
local Inspector = {
    showWindow = true,
    componentTypes = {
        "Transform",
        "Sprite",
        "Collider",
        "Script",
        "Animation",
        "Tilemap"
    }
}

function Inspector:init()
    State.showWindows.inspector = true
    State.windowSizes.inspector = {width = 300, height = 400}
end

function Inspector:drawTransformComponent(entity)
    if imgui.CollapsingHeader("Transform", imgui.TreeNodeFlags_DefaultOpen) then
        -- Position
        local x = imgui.DragFloat("X##Transform", entity.x, 0.1, -1000, 1000)
        if x ~= entity.x then entity.x = x end
        
        local y = imgui.DragFloat("Y##Transform", entity.y, 0.1, -1000, 1000)
        if y ~= entity.y then entity.y = y end
        
        -- Scale
        local width = imgui.DragFloat("Scale X##Transform", entity.width, 0.1, 1, 1000)
        if width ~= entity.width then entity.width = width end
        
        local height = imgui.DragFloat("Scale Y##Transform", entity.height, 0.1, 1, 1000)
        if height ~= entity.height then entity.height = height end
        
        -- Rotation
        local rotation = imgui.DragFloat("Rotation##Transform", entity.rotation or 0, 0.1, -360, 360)
        if rotation ~= (entity.rotation or 0) then entity.rotation = rotation end      
        
        -- Player Check
        entity.isPlayer = imgui.Checkbox("Is Player : ", entity.isPlayer)
        if entity.isPlayer then 
            State.player = entity 
            State.playerX = entity.x
            State.playerY = entity.y
        end
        local speed = imgui.SliderFloat("Speed : ", entity.playerSpeed or 1, 0, 250)
      -- TODO: SLIDER FLOAT KULLANARAK SPEED AL
      
        entity.playerSpeed = speed
            if entity.isPlayer then
                if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
                    entity.x = entity.x - entity.playerSpeed
                end
                if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
                    entity.x = entity.x + entity.playerSpeed
                end
                if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
                    entity.y = entity.y - entity.playerSpeed
                end
                if love.keyboard.isDown("down") or love.keyboard.isDown("s") then
                    entity.y = entity.y + entity.playerSpeed
                end
            end
        
    end
end
-- FIXME:
function Inspector:drawShaderComponent(entity)
    local Shaders = require "modules.shaders"
    
    -- Eğer Shader yoksa ve entity'nin sprite veya animator componenti varsa "Add Shader" butonu göster
    if not entity.components.shader then
        if entity.components.sprite or (entity.components.animator and entity.components.animator.currentAnimation) then
            if imgui.Button("Add Shader Component") then
                -- Boş shader component'i oluştur
                Shaders:createComponent(entity, "none")
            end
        end
        return
    end

    -- Shader Component UI
    if imgui.CollapsingHeader("Shader") then
        local component = entity.components.shader
        
        -- Shader aktiflik durumu
        local enabled = imgui.Checkbox("Enabled##ShaderEnabled", component.enabled or false)
        if enabled ~= component.enabled then
            component.enabled = enabled
        end
        
        -- Shader seçim menüsü
        local currentShader = component.shaderName or "none"
        if imgui.Button((Shaders.registry[currentShader] and Shaders.registry[currentShader].displayName or "Select Shader") .. "##ShaderSelect") then
            imgui.OpenPopup("ShaderSelectPopup")
        end
        
        -- Shader seçim popup'ı
        if imgui.BeginPopup("ShaderSelectPopup") then
            imgui.Text("Built-in Shaders")
            imgui.Separator()
            
            -- Built-in shaders
            for name, shader in pairs(Shaders.registry) do
                if imgui.Selectable(shader.displayName or name, currentShader == name) then
                    Shaders:setShader(component, name)
                end
            end
            
            imgui.Separator()
            imgui.Text("Custom Shaders")
            imgui.Separator()
            
            -- Asset listesinden shader'ları göster
            for _, asset in ipairs(State.assets) do
                if asset.type == "shader" then
                    if imgui.Selectable(asset.name, false) then
                        -- Önce shader'ı kayıtlara ekle (eğer daha önce eklenmemişse)
                        local shaderName = asset.name:match("(.+)%..+$") or asset.name
                        if not Shaders.registry[shaderName] and asset.source then
                            Shaders:registerShader(shaderName, asset.name, asset.source, {})
                        end
                        
                        -- Shader'ı component'e ayarla
                        Shaders:setShader(component, shaderName)
                    end
                end
            end
            
            imgui.EndPopup()
        end
        
        -- Eğer şu anki shader "none" değilse parametre UI'larını göster
        if currentShader ~= "none" and Shaders.registry[currentShader] then
            local shader = Shaders.registry[currentShader]
            
            imgui.Separator()
            imgui.Text("Shader Parameters")
            
            -- Her bir uniform değişkenin UI'ını oluştur
            for name, uniform in pairs(shader.uniforms) do
                local param = component.parameters[name] or { value = uniform.default, type = uniform.type }
                
                -- Parametre tipine göre UI oluştur
                if param.type == "float" then
                    -- Float değerler için slider
                    local min = uniform.min or 0.0
                    local max = uniform.max or 1.0
                    
                    local newValue = imgui.SliderFloat(uniform.displayName or name, param.value, min, max)
                    if newValue ~= param.value then
                        param.value = newValue
                    end
                    
                elseif param.type == "vec2" then
                    -- Vec2 değerler için iki slider
                    imgui.Text(uniform.displayName or name)
                    
                    local x = imgui.SliderFloat("X##" .. name, param.value[1], -1000, 1500)
                    local y = imgui.SliderFloat("Y##" .. name, param.value[2], -1000, 1500)
                    
                    if x ~= param.value[1] or y ~= param.value[2] then
                        param.value = {x, y}
                    end
                    
                elseif param.type == "vec3" then
                    -- Vec3 değerler için ColorEdit3
                    imgui.Text(uniform.displayName or name)
                    
                    -- Renk değerleri için özel işleme
                    if name:lower():find("color") then
                        local r, g, b = imgui.ColorEdit3("##" .. name, param.value[1], param.value[2], param.value[3])
                        if r ~= param.value[1] or g ~= param.value[2] or b ~= param.value[3] then
                            param.value = {r, g, b}
                        end
                    else
                        -- Renk değilse normal sliderlar
                        local x = imgui.SliderFloat("X##" .. name, param.value[1], 0, 1)
                        local y = imgui.SliderFloat("Y##" .. name, param.value[2], 0, 1) 
                        local z = imgui.SliderFloat("Z##" .. name, param.value[3], 0, 1)
                        
                        if x ~= param.value[1] or y ~= param.value[2] or z ~= param.value[3] then
                            param.value = {x, y, z}
                        end
                    end
                end
                
                -- Parametre değerini güncelle
                component.parameters[name] = param
            end
        end
        
        imgui.Separator()
        
        -- Component'i silme butonu
        if imgui.Button("Remove Shader Component") then
            entity.components.shader = nil
            Console:log("Removed shader component from entity: " .. (entity.name or "unnamed"))
        end
    end
end

function Inspector:drawSpriteComponent(entity)
    if not entity.components.sprite then
        if imgui.Button("Add Sprite Component") then
            entity.components.sprite = {
                image = nil,
                color = {1, 1, 1, 1},
                flip_h = false,
                flip_v = false
            }

        end
        return
    end

    if imgui.CollapsingHeader("Sprite") then
        -- Sprite seçimi
        imgui.Text("Image:")

        -- Flip
        entity.components.sprite.flip_h = imgui.Checkbox("Flip Horizontally##Sprite", entity.components.sprite.flip_h)
        entity.components.sprite.flip_v = imgui.Checkbox("Flip Vertically##Sprite", entity.components.sprite.flip_v)
        
        -- Mevcut resmi göster
        local currentImage = entity.components.sprite.image and entity.components.sprite.image.name or "None"
        if imgui.Button(currentImage .. "##SpriteSelect") then
            imgui.OpenPopup("SpriteSelectPopup")
        end
        
        -- Resim seçme popup'ı
        if imgui.BeginPopup("SpriteSelectPopup") then
            imgui.Text("Select an Image")
            imgui.Separator()
            local sprite = entity.components.sprite
            

            
            -- Asset listesinden sadece resimleri göster
            for _, asset in ipairs(State.assets) do
                if asset.type == "image" then
                    if imgui.Selectable(asset.name) then
                        entity.components.sprite.image = asset
                        Console:log("Selected image: " .. asset.name .. " for entity: " .. (entity.name or "unnamed"))
                    end
                end
            end
            imgui.EndPopup()
        end
        
        -- Clear image button
        imgui.SameLine()
        if imgui.Button("X##ClearSprite") then
            entity.components.sprite.image = nil
            Console:log("Cleared sprite image for entity: " .. (entity.name or "unnamed"))
        end
        
        -- Color picker
        local color = entity.components.sprite.color
        color[1], color[2], color[3] = imgui.ColorEdit3("Color##Sprite", color[1], color[2], color[3])
        
        -- Alpha slider
        imgui.SliderFloat("Alpha##Sprite", color[4], 0, 1)
        
        -- Component'i silme butonu
        if imgui.Button("Remove Sprite Component") then
            entity.components.sprite = nil
            Console:log("Removed sprite component from entity: " .. (entity.name or "unnamed"))
        end
    end
end

function Inspector:drawColliderComponent(entity)
    if not entity.components.collider then
        if imgui.Button("Add Collider Component") then
            entity.components.collider = {
                body = nil,
                shape = nil,
                fixture = nil,
                type = "box",
                width = entity.width,
                height = entity.height,
                offset = {x = 0, y = 0},
                isTrigger = false
            }
        end
        return
    end

    if imgui.CollapsingHeader("Collider") then
        -- Collider tipi seçimi
        local colliderTypes = "box\0circle\0\0"  -- ImGui için null-terminated string
        local currentTypeIndex = entity.components.collider.type == "box" and 0 or 1
        
        -- Combo box
        local newIndex = imgui.Combo("Type##Collider", currentTypeIndex, colliderTypes)
        if newIndex ~= currentTypeIndex then
            entity.components.collider.type = newIndex == 0 and "box" or "circle"
            Console:log("Changed collider type to: " .. entity.components.collider.type)
        end
        
        -- Size
        local width = imgui.DragFloat("Width##Collider", entity.components.collider.width or 64, 0.1, 1, 1000)
        if width ~= entity.components.collider.width then 
            entity.components.collider.width = width 
        end
        
        local height = imgui.DragFloat("Height##Collider", entity.components.collider.height or 64, 0.1, 1, 1000)
        if height ~= entity.components.collider.height then 
            entity.components.collider.height = height 
        end
        
        -- Offset
        local offsetX = imgui.DragFloat("Offset X##Collider", 0 or entity.components.collider.offset.x, 0.1, -100, 100)
        if offsetX ~= 0 or entity.components.collider.offset.x then 
            entity.components.collider.offset.x = offsetX 
        end
        
        local offsetY = imgui.DragFloat("Offset Y##Collider", 0 or entity.components.collider.offset.y, 0.1, -100, 100)
        if offsetY ~= 0 or entity.components.collider.offset.y then 
            entity.components.collider.offset.y = offsetY 
        end
        
        -- Is Trigger
        local isTrigger = imgui.Checkbox("Is Trigger##Collider", entity.components.collider.isTrigger)
        if isTrigger ~= entity.components.collider.isTrigger then 
            entity.components.collider.isTrigger = isTrigger 
        end

        if entity.components.collider.type == "box" then
            entity.components.collider.body = love.physics.newBody(State.world, 
            entity.components.collider.width,
            entity.components.collider.height,
            "dynamic")

            entity.components.collider.shape = love.physics.newRectangleShape(
            entity.components.collider.width,
            entity.components.collider.height,
            entity.width, entity.height)

            entity.components.collider.fixture = love.physics.newFixture(entity.components.collider.body, entity.components.collider.shape, 2)

        end

        if entity.components.collider.type == "circle" then
            entity.components.collider.body = love.physics.newBody(State.world, 
            entity.components.collider.width,
            entity.components.collider.height,
            "dynamic")

            entity.components.collider.shape = love.physics.newCircleShape(entity.components.collider.width)

            entity.components.collider.fixture = love.physics.newFixture(entity.components.collider.body, entity.components.collider.shape, 2)

        end
        
        -- Component'i silme butonu
        if imgui.Button("Remove Collider Component") then
            entity.components.collider = nil
            Console:log("Removed collider component from entity: " .. (entity.name or "unnamed"))
        end
    end
end

function Inspector:drawTilemapComponent(entity)
    local Tilemap = require "modules.tilemap" -- Import the tilemap module
    
    if not entity.components.tilemap then
        if imgui.Button("Add Tilemap Component") then
            -- Initialize an empty tilemap component
            entity.components.tilemap = {
                asset = nil,
                tileWidth = 32,
                tileHeight = 32,
                mapWidth = 10,
                mapHeight = 10,
                layers = {
                    {
                        name = "Layer 1",
                        visible = true,
                        tiles = {}
                    }
                },
                currentLayer = 1
            }
            Console:log("Added tilemap component to entity: " .. (entity.name or "unnamed"))
        end
        return
    end

    if imgui.CollapsingHeader("Tilemap") then
        local component = entity.components.tilemap
        
        -- Display tileset image
        imgui.Text("Tileset Image:")
        local currentImage = component.asset and component.asset.name or "None"
        
        if imgui.Button(currentImage .. "##TilesetSelect") then
            imgui.OpenPopup("TilesetSelectPopup")
        end
        
        -- Image selection popup
        if imgui.BeginPopup("TilesetSelectPopup") then
            imgui.Text("Select a Tileset Image")
            imgui.Separator()
            
            -- Show image assets
            for _, asset in ipairs(State.assets) do
                if asset.type == "image" then
                    if imgui.Selectable(asset.name) then
                        component.asset = asset
                        Console:log("Selected tileset: " .. asset.name)
                    end
                end
            end
            imgui.EndPopup()
        end
        
        -- Clear image button
        imgui.SameLine()
        if imgui.Button("X##ClearTileset") then
            component.asset = nil
            Console:log("Cleared tileset image")
        end
        
        -- Tile dimensions
        local tileWidth = imgui.InputInt("Tile Width##Tilemap", component.tileWidth or 32, 1)
        if tileWidth ~= component.tileWidth then
            component.tileWidth = math.max(1, tileWidth)
        end
        
        local tileHeight = imgui.InputInt("Tile Height##Tilemap", component.tileHeight or 32, 1)
        if tileHeight ~= component.tileHeight then
            component.tileHeight = math.max(1, tileHeight)
        end
        
        -- Map dimensions
        local mapWidth = imgui.InputInt("Map Width##Tilemap", component.mapWidth or 10, 1)
        if mapWidth ~= component.mapWidth then
            component.mapWidth = math.max(1, mapWidth)
        end
        
        local mapHeight = imgui.InputInt("Map Height##Tilemap", component.mapHeight or 10, 1)
        if mapHeight ~= component.mapHeight then
            component.mapHeight = math.max(1, mapHeight)
        end
        
        imgui.Separator()
        
        -- Current layer info
        if component.layers and #component.layers > 0 then
            imgui.Text("Layers: " .. #component.layers)
            
            -- Display current layer
            local currentLayerIndex = component.currentLayer or 1
            local currentLayer = component.layers[currentLayerIndex]
            
            if currentLayer then
                imgui.Text("Current Layer: " .. currentLayer.name)
                
                -- Count tiles in current layer
                local tileCount = 0
                for _ in pairs(currentLayer.tiles or {}) do
                    tileCount = tileCount + 1
                end
                
                imgui.Text("Tiles in layer: " .. tileCount)
            end
        else
            imgui.Text("No layers defined")
        end
        
        imgui.Separator()
        
        -- Tileset window button
        if component.asset then
            if imgui.Button("Open Tileset Editor") then
                local Tilemap = require "modules.tilemap"
                Tilemap:openTilesetWindow(entity, component.asset)
            end
        else
            imgui.TextColored(1, 0.5, 0.5, 1, "Select a tileset image first")
        end
        
        -- Component removal button
        if imgui.Button("Remove Tilemap Component") then
            entity.components.tilemap = nil
            Console:log("Removed tilemap component from entity: " .. (entity.name or "unnamed"))
        end
    end
end




function Inspector:drawAnimatorComponent(entity)
    if not entity.components.animator then
        if imgui.Button("Add Animator Component") then
            entity.components.animator = {
                currentAnimation = nil,
                animations = {},
                playing = false,
                timer = 0,
                currentFrame = 1
            }
            -- Animator penceresini aç
            State.showWindows.animator = true
            Console:log("Added animator component to: " .. (entity.name or "unnamed"))
        end
        return
    end

    if imgui.CollapsingHeader("Animator") then
        -- Animator penceresini açma butonu
        if imgui.Button("Open Animator Window##AnimatorOpen") then
            State.showWindows.animator = true
        end
        
        -- Component'i silme butonu
        if imgui.Button("Remove Animator Component") then
            entity.components.animator = nil
            -- Animator penceresini kapat
            State.showWindows.animator = false
            Console:log("Removed animator component from: " .. (entity.name or "unnamed"))
        end
    end
end

function Inspector:draw()
    if not State.showWindows.inspector then return end
    
    imgui.SetNextWindowSize(State.windowSizes.inspector.width, State.windowSizes.inspector.height, imgui.Cond_FirstUseEver)
    if imgui.Begin("Inspector", State.showWindows.inspector) then
        local entity = State.selectedEntity
        
        if entity then
            -- Entity name
            local name = imgui.InputText("Name", entity.name or "", 100)
            if name ~= entity.name then entity.name = name end
            
            imgui.Separator()
            
            -- Initialize components table if it doesn't exist
            entity.components = entity.components or {}
            
            -- Draw components
            self:drawTransformComponent(entity)
            self:drawSpriteComponent(entity)
            self:drawColliderComponent(entity)
            self:drawAnimatorComponent(entity)
            self:drawShaderComponent(entity)
            self:drawTilemapComponent(entity)
            
            -- Add Component Button
            if imgui.Button("Add Component") then
                imgui.OpenPopup("AddComponentPopup")
            end
            
            if imgui.BeginPopup("AddComponentPopup") then
                for _, componentType in ipairs(self.componentTypes) do
                    if not entity.components[string.lower(componentType)] then
                        if imgui.MenuItem(componentType) then
                            entity.components[string.lower(componentType)] = {}
                            Console:log("Added " .. componentType .. " component to " .. entity.name)
                        end
                    end
                end
                imgui.EndPopup()
            end
        else
            imgui.Text("No entity selected")
        end
    end
    imgui.End()
end

return Inspector 