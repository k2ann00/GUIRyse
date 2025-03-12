local State = require "state"
local Console = require "modules.console"
local Camera = require "modules.camera"
local imgui = require "imgui"

local SceneManager = {}

function SceneManager:init()
    self.scenes = {}
    self.entities = {}
    self.selectedEntity = nil
    self.gridSize = 32
    self.showGrid = true
    self.lastMouseX = 0
    self.lastMouseY = 0
    self.handleSize = 4
    
    -- Create a default scene
    self:createNewScene("Default Scene")
end

function SceneManager:createNewScene(name)
    local scene = {
        name = name,
        entities = {},
        background = {r = 0.1, g = 0.1, b = 0.1}
    }
    
    table.insert(self.scenes, scene)
    State.currentScene = scene
    Console:log("Created new scene: " .. name)
    return scene
end

local GUID = {}
-- UUID v4 formatında benzersiz bir tanımlayıcı oluşturur
function GUID.generate()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format("%x", v)
    end)
end


-- Entity GUID ekleme
function SceneManager:createEntity(x, y)
    -- Mevcut createEntity fonksiyonunuzu genişletin
    local entity = {
        name = "Entity " .. (#self.entities + 1),
        guid = GUID.generate(), -- Her entity için benzersiz GUID oluştur
        x = x or 0,
        y = y or 0,
        width = 32,
        height = 32,
        rotation = 0,
        sprite = nil,
        animation = nil,
        isPlayer = false,
        playerSpeed = 0,
        components = {}
    }
    
    table.insert(self.entities, entity)
    State.selectedEntity = entity
    Console:log("Created entity: " .. entity.name .. " (GUID: " .. entity.guid .. ")")
    return entity
end


function SceneManager:deleteEntity(entity)
    for i, e in ipairs(self.entities) do
        if e == entity then
            table.remove(self.entities, i)
            if State.selectedEntity == entity then
                State.selectedEntity = nil
            end
            Console:log("Deleted entity: " .. entity.name)
            print("Deleted entity: " .. entity.name)
            return true
        end
    end
    return false
end

-- GUID ile entity bulma
function SceneManager:getEntityByGUID(guid)
    for _, entity in ipairs(self.entities) do
        if entity.guid == guid then
            return entity
        end
    end
    return nil
end

-- Entity referanslarını GUID ile kaydetme
function SceneManager:serializeEntities()
    local serialized = {}
    
    for _, entity in ipairs(self.entities) do
        local entityData = {
            guid = entity.guid,
            name = entity.name,
            x = entity.x,
            y = entity.y,
            width = entity.width,
            height = entity.height,
            rotation = entity.rotation,
            isPlayer = entity.isPlayer,
            playerSpeed = entity.playerSpeed,
            components = {}
        }
        
        -- Serialize components
        for compType, comp in pairs(entity.components) do
            entityData.components[compType] = self:serializeComponent(compType, comp, entity)
        end
        
        table.insert(serialized, entityData)
    end
    
    return serialized
end

-- Serileştirilmiş entity'leri geri yükleme
function SceneManager:deserializeEntities(data)
    self.entities = {} -- Clear current entities
    
    for _, entityData in ipairs(data) do
        local entity = {
            guid = entityData.guid,
            name = entityData.name,
            x = entityData.x,
            y = entityData.y,
            width = entityData.width,
            height = entityData.height,
            rotation = entityData.rotation,
            isPlayer = entityData.isPlayer,
            playerSpeed = entityData.playerSpeed,
            components = {}
        }
        
        -- Deserialize components
        for compType, compData in pairs(entityData.components) do
            entity.components[compType] = self:deserializeComponent(compType, compData, entity)
        end
        
        table.insert(self.entities, entity)
        
        -- Update State.player if it's the player entity
        if entity.isPlayer then
            State.player = entity
            State.playerX = entity.x
            State.playerY = entity.y
        end
    end
    
    Console:log("Deserialized " .. #self.entities .. " entities")
end


function SceneManager:drawGrid()
    if not self.showGrid then return end
    
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    
    local w, h = love.graphics.getDimensions()
    local startX = math.floor(-Camera.x / self.gridSize) * self.gridSize
    local startY = math.floor(-Camera.y / self.gridSize) * self.gridSize
    local endX = startX + w / Camera.scaleX + self.gridSize * 2
    local endY = startY + h / Camera.scaleY + self.gridSize * 2
    
    for x = startX, endX, self.gridSize do
        love.graphics.line(x, startY, x, endY)
    end
    
    for y = startY, endY, self.gridSize do
        love.graphics.line(startX, y, endX, y)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end


function SceneManager:drawEntities()
    local Shaders = require "modules.shaders"
    local Tilemap = require "modules.tilemap"  -- Tilemap modülünü ekle
    
    for _, entity in ipairs(self.entities) do
        -- Tilemap component varsa, placeholder çizmeden önce çiz
        if entity.components and entity.components.tilemap then
            Tilemap:drawTilemap(entity)
        end
        
        -- Sprite veya Animator component'i varsa
        if entity.components then
            -- Önce shader desteğini kontrol et
            local hasShader = entity.components.shader and entity.components.shader.enabled
            
            if entity.components.animator and entity.components.animator.currentAnimation then
                -- Animasyon çiz (playing olsun veya olmasın)
                local animator = entity.components.animator
                local anim = animator.currentAnimation
                
                if anim and anim.frames and #anim.frames > 0 then
                    local frame = anim.frames[animator.currentFrame]
                    if frame and frame.quad then
                        love.graphics.setColor(1, 1, 1, 1)
                        anim.source.data:setFilter("nearest", "nearest")
                        
                        -- Shader'ı uygula (eğer varsa)
                        if hasShader then
                            Shaders:applyShader(entity.components.shader)
                            
                            -- Eğer shader screen veya playerPos parametresi kullanıyorsa otomatik olarak ayarla
                            local shader = Shaders.registry[entity.components.shader.shaderName]
                            if shader and shader.compiled then
                                -- Screen boyutunu otomatik olarak ayarla
                                if shader.compiled:hasUniform("screen") then
                                    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
                                    shader.compiled:send("screen", {w, h})
                                end
                                
                                -- Player pozisyonunu otomatik olarak ayarla
                                if shader.compiled:hasUniform("playerPos") and State.player then
                                    shader.compiled:send("playerPos", {State.playerX, State.playerY})
                                end
                                
                                -- Texture boyutunu otomatik olarak ayarla
                                if shader.compiled:hasUniform("textureSize") then
                                    shader.compiled:send("textureSize", {anim.frameWidth, anim.frameHeight})
                                end
                            end
                        end
                        
                        -- Animasyon frame'ini çiz
                        love.graphics.draw(
                            anim.source.data,
                            frame.quad,
                            entity.x + entity.width/2,
                            entity.y + entity.height/2,
                            entity.rotation or 0,
                            entity.width / anim.frameWidth,
                            entity.height / anim.frameHeight,
                            anim.frameWidth/2,
                            anim.frameHeight/2
                        )
                        
                        -- Shader'ı kapat
                        if hasShader then
                            love.graphics.setShader()
                        end
                    end
                end
            elseif entity.components.sprite and entity.components.sprite.image then
                -- Normal sprite çiz
                local sprite = entity.components.sprite
                local color = sprite.color or {1, 1, 1, 1}
                
                love.graphics.setColor(color[1], color[2], color[3], color[4])
                
                local img = sprite.image.data
                local w, h = img:getDimensions()
                img:setFilter("nearest", "nearest")
                
                -- Hesapla scale ve flip değerleri
                local scaleX = entity.width / w
                local scaleY = entity.height / h
                
                -- Flip kontrolü
                if sprite.flip_h then scaleX = -scaleX end
                if sprite.flip_v then scaleY = -scaleY end
                
                -- Shader'ı uygula (eğer varsa)
                if hasShader then
                    Shaders:applyShader(entity.components.shader)
                    
                    -- Eğer shader screen veya playerPos parametresi kullanıyorsa otomatik olarak ayarla
                    local shader = Shaders.registry[entity.components.shader.shaderName]
                    if shader and shader.compiled then
                        -- Screen boyutunu otomatik olarak ayarla
                        if shader.compiled:hasUniform("screen") then
                            local w, h = love.graphics.getWidth(), love.graphics.getHeight()
                            shader.compiled:send("screen", {w, h})
                        end
                        
                        -- Player pozisyonunu otomatik olarak ayarla
                        if shader.compiled:hasUniform("playerPos") and State.player then
                            shader.compiled:send("playerPos", {State.playerX, State.playerY})
                        end
                        
                        -- Texture boyutunu otomatik olarak ayarla
                        if shader.compiled:hasUniform("textureSize") then
                            shader.compiled:send("textureSize", {w, h})
                        end                        
                    end
                end
                
                -- Sprite'ı çiz
                love.graphics.draw(
                    img,
                    entity.x + entity.width/2,
                    entity.y + entity.height/2,
                    entity.rotation or 0,
                    scaleX,
                    scaleY,
                    w/2, h/2
                )
                
                -- Shader'ı kapat
                if hasShader then
                    love.graphics.setShader()
                end
            elseif not entity.components.tilemap then
                -- Tilemap component yoksa placeholder çiz (bu koşulu ekledik)
                love.graphics.setColor(0.5, 0.5, 0.5, 1)
                love.graphics.rectangle("fill", entity.x, entity.y, entity.width, entity.height)
                love.graphics.setColor(0.8, 0.8, 0.8, 1)
                love.graphics.rectangle("line", entity.x, entity.y, entity.width, entity.height)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print(entity.name or "Entity", entity.x + 2, entity.y + 2)
            end
            
            -- Seçili entity'nin etrafına çizgi çiz
            if entity == State.selectedEntity then
                self:drawSelectionOutline(entity)

                if love.keyboard.isDown("delete") then
                    self:deleteEntity(State.selectedEntity)
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)  -- Rengi resetle
end
    
-- Add or modify update function to check play mode
function SceneManager:update(dt)
    local Tilemap = require "modules.tilemap"
    local SceneView = require "modules.scene_view"
    
    -- Entity'lerin animasyonlarını güncelle - only in play mode or if manually animated
    for _, entity in ipairs(self.entities) do
        if entity.components and entity.components.animator then
            local animator = entity.components.animator
            -- Only update animations if playing is enabled or we're in play mode
            if (animator.playing or SceneView.isPlaying) and animator.currentAnimation then
                animator.timer = animator.timer + dt
                
                local currentFrame = animator.currentAnimation.frames[animator.currentFrame]
                if currentFrame and animator.timer >= currentFrame.duration then
                    animator.timer = animator.timer - currentFrame.duration
                    animator.currentFrame = animator.currentFrame + 1
                    
                    -- Animasyon bittiğinde başa dön
                    if animator.currentFrame > #animator.currentAnimation.frames then
                        animator.currentFrame = 1
                    end
                end
            end
        end
        
        -- Update physics components if we're in play mode
        if SceneView.isPlaying and not SceneView.isPaused then
            if entity.components and entity.components.collider then
                -- Update physics positions from collider components
                -- ...
            end
            
            -- Handle player movement in play mode
            if entity.isPlayer then
                self:updatePlayerInPlayMode(entity, dt)
            end
        end
        
        -- Seçili entity tilemap component'ine sahipse düzenlemeyi işle
        -- (only in edit mode)
        if not SceneView.isPlaying and 
           entity == State.selectedEntity and 
           entity.components and 
           entity.components.tilemap and
           Tilemap.tilesetWindow.selectedTile and
           not imgui.GetWantCaptureMouse() then
            
            Tilemap:handleMapEditing(entity)
        end
    end
end

-- New function to handle player movement in play mode
function SceneManager:updatePlayerInPlayMode(entity, dt)
    if not entity.isPlayer or not entity.playerSpeed then return end
    
    local speed = entity.playerSpeed * dt
    
    -- Handle player movement with arrow keys or WASD
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        entity.x = entity.x - speed
    end
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        entity.x = entity.x + speed
    end
    if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
        entity.y = entity.y - speed
    end
    if love.keyboard.isDown("down") or love.keyboard.isDown("s") then
        entity.y = entity.y + speed
    end
    
    -- Update State.playerX and State.playerY which some shaders might use
    if entity == State.player then
        State.playerX = entity.x
        State.playerY = entity.y
    end
end


-- Seçili entity'nin etrafına çizgi çizme fonksiyonu
function SceneManager:drawSelectionOutline(entity)
    -- Seçim çizgisinin rengi ve kalınlığı
    love.graphics.setColor(0, 1, 1, 1)  -- Turkuaz renk
    love.graphics.setLineWidth(2)
    
    -- Entity'nin dönüşünü hesaba katarak çizgi çiz
    if entity.rotation and entity.rotation ~= 0 then
        -- Dönüşlü çizim için merkez noktayı hesapla
        local centerX = entity.x + entity.width/2
        local centerY = entity.y + entity.height/2
        
        -- Dönüşü uygula
        love.graphics.push()
        love.graphics.translate(centerX, centerY)
        love.graphics.rotate(entity.rotation)
        
        -- Dikdörtgen çiz (merkez etrafında)
        love.graphics.rectangle("line", -entity.width/2, -entity.height/2, entity.width, entity.height)
        
        -- Köşe tutamaçları çiz
        local handleSize = 1
        -- Sol üst
        love.graphics.rectangle("fill", -entity.width/2 - handleSize/2, -entity.height/2 - handleSize/2, handleSize, handleSize)
        -- Sağ üst
        love.graphics.rectangle("fill", entity.width/2 - handleSize/2, -entity.height/2 - handleSize/2, handleSize, handleSize)
        -- Sol alt
        love.graphics.rectangle("fill", -entity.width/2 - handleSize/2, entity.height/2 - handleSize/2, handleSize, handleSize)
        -- Sağ alt
        love.graphics.rectangle("fill", entity.width/2 - handleSize/2, entity.height/2 - handleSize/2, handleSize, handleSize)
        
        -- Orta tutamaçlar
        -- Üst
        love.graphics.rectangle("fill", -handleSize/2, -entity.height/2 - handleSize/2, handleSize, handleSize)
        -- Alt
        love.graphics.rectangle("fill", -handleSize/2, entity.height/2 - handleSize/2, handleSize, handleSize)
        -- Sol
        love.graphics.rectangle("fill", -entity.width/2 - handleSize/2, -handleSize/2, handleSize, handleSize)
        -- Sağ
        love.graphics.rectangle("fill", entity.width/2 - handleSize/2, -handleSize/2, handleSize, handleSize)
        
        love.graphics.pop()
    else
        -- Dönüşsüz normal çizim
        love.graphics.rectangle("line", entity.x, entity.y, entity.width, entity.height)
        
        -- Köşe tutamaçları çiz
        local handleSize = 8
        -- Sol üst
        love.graphics.rectangle("fill", entity.x - handleSize/2, entity.y - handleSize/2, handleSize, handleSize)
        -- Sağ üst
        love.graphics.rectangle("fill", entity.x + entity.width - handleSize/2, entity.y - handleSize/2, handleSize, handleSize)
        -- Sol alt
        love.graphics.rectangle("fill", entity.x - handleSize/2, entity.y + entity.height - handleSize/2, handleSize, handleSize)
        -- Sağ alt
        love.graphics.rectangle("fill", entity.x + entity.width - handleSize/2, entity.y + entity.height - handleSize/2, handleSize, handleSize)
        
        -- Orta tutamaçlar
        -- Üst
        love.graphics.rectangle("fill", entity.x + entity.width/2 - handleSize/2, entity.y - handleSize/2, handleSize, handleSize)
        -- Alt
        love.graphics.rectangle("fill", entity.x + entity.width/2 - handleSize/2, entity.y + entity.height - handleSize/2, handleSize, handleSize)
        -- Sol
        love.graphics.rectangle("fill", entity.x - handleSize/2, entity.y + entity.height/2 - handleSize/2, handleSize, handleSize)
        -- Sağ
        love.graphics.rectangle("fill", entity.x + entity.width - handleSize/2, entity.y + entity.height/2 - handleSize/2, handleSize, handleSize)
    end
    
    -- Çizgi kalınlığını resetle
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function SceneManager:handleInput()
    local mouseX, mouseY = love.mouse.getPosition()
    local worldX, worldY = self:screenToWorld(mouseX, mouseY)
    
    -- Get SceneView module to check play state and hover state
    local SceneView = require "modules.scene_view"
    
    -- Skip input handling if in play mode
    if SceneView.isPlaying then return end
    
    -- Skip if not hovering over SceneView
    if not SceneView.isHovered then return end
    
    -- Eğer bir asset sürükleniyorsa ve ImGui mouse'u kapsamıyorsa
    if not imgui.GetWantCaptureMouse() and State.draggedAsset and State.dragStarted then
        -- Mouse bırakıldığında yeni entity oluştur
        if not love.mouse.isDown(1) then
            -- Sadece sahne üzerinde fare bırakılırsa entity oluştur
            if SceneView.isHovered then
                self:handleDraggedAsset(State.draggedAsset, worldX, worldY)
            end
            
            -- Sürükleme durumunu sıfırla
            State.draggedAsset = nil
            State.dragStarted = false
        end
    end
    
    -- Seçili entity'de tile map component'i varsa ve tilemap'in bir seçili tile'ı varsa
    -- handleInput'u bypass et
    local Tilemap = require "modules.tilemap"
    if State.selectedEntity and 
       State.selectedEntity.components and 
       State.selectedEntity.components.tilemap and
       Tilemap.tilesetWindow.selectedTile and
       SceneView.isHovered and 
       not imgui.GetWantCaptureMouse() then
        
        -- Tile Map içinde fare konumu
        local entity = State.selectedEntity
        local component = entity.components.tilemap
        
        local gridX = math.floor((worldX - entity.x) / component.tileWidth)
        local gridY = math.floor((worldY - entity.y) / component.tileHeight)
        
        if gridX >= 0 and gridX < component.mapWidth and
           gridY >= 0 and gridY < component.mapHeight then
            -- Fare tilemap sınırları içinde, diğer fare işlemlerini bypass et
            -- Mouse delta güncelle
            self.lastMouseX = mouseX
            self.lastMouseY = mouseY
            return
        end
    end
    
    -- Mouse tıklaması - only process if SceneView is hovered
    if love.mouse.isDown(1) and not imgui.GetWantCaptureMouse() and SceneView.isHovered then
        -- Mouse delta hesapla
        local dx = (mouseX - self.lastMouseX) / Camera.scaleX
        local dy = (mouseY - self.lastMouseY) / Camera.scaleY
        
        -- Eğer bir tutamaç sürüklüyorsak
        if self.isDragging and self.draggedHandle and State.selectedEntity then
            local entity = State.selectedEntity
            
            -- Tutamaç tipine göre transform değiştir
            if self.draggedHandle == "topLeft" then
                entity.x = entity.x + dx
                entity.y = entity.y + dy
                entity.width = entity.width - dx
                entity.height = entity.height - dy
            elseif self.draggedHandle == "topRight" then
                entity.y = entity.y + dy
                entity.width = entity.width + dx
                entity.height = entity.height - dy
            elseif self.draggedHandle == "bottomLeft" then
                entity.x = entity.x + dx
                entity.width = entity.width - dx
                entity.height = entity.height + dy
            elseif self.draggedHandle == "bottomRight" then
                entity.width = entity.width + dx
                entity.height = entity.height + dy
            elseif self.draggedHandle == "top" then
                entity.y = entity.y + dy
                entity.height = entity.height - dy
            elseif self.draggedHandle == "bottom" then
                entity.height = entity.height + dy
            elseif self.draggedHandle == "left" then
                entity.x = entity.x + dx
                entity.width = entity.width - dx
            elseif self.draggedHandle == "right" then
                entity.width = entity.width + dx
            elseif self.draggedHandle == "move" then
                entity.x = entity.x + dx
                entity.y = entity.y + dy
            end
            
            -- Minimum boyut kontrolü
            if entity.width < 10 then entity.width = 10 end
            if entity.height < 10 then entity.height = 10 end
        elseif not self.isDragging then
            -- Tutamaç kontrolü
            if State.selectedEntity then
                local handle = self:checkHandles(worldX, worldY, State.selectedEntity)
                if handle then
                    self.isDragging = true
                    self.draggedHandle = handle
                else
                    -- Entity içine tıklama kontrolü
                    local clickedEntity = self:getEntityAtPosition(worldX, worldY)
                    if clickedEntity then
                        State.selectedEntity = clickedEntity
                        self.isDragging = true
                        self.draggedHandle = "move"
                    else
                        -- Boş alana tıklama
                        if love.keyboard.isDown("lctrl") then
                            self:createEntity(worldX, worldY)
                        else
                            State.selectedEntity = nil
                        end
                    end
                end
            else
                -- Entity seçimi
                local clickedEntity = self:getEntityAtPosition(worldX, worldY)
                if clickedEntity then
                    State.selectedEntity = clickedEntity
                    self.isDragging = true
                    self.draggedHandle = "move"
                else
                    -- Yeni entity oluştur
                    if love.keyboard.isDown("lctrl") then
                        self:createEntity(worldX, worldY)
                    end
                end
            end
        end
    else
        -- Mouse bırakıldığında
        self.isDragging = false
        self.draggedHandle = nil
    end  -- Fixed: replaced the curly brace with a proper parenthesis
    
    -- Son mouse pozisyonunu güncelle
    self.lastMouseX = mouseX
    self.lastMouseY = mouseY
end


function SceneManager:getEntityAtPosition(x, y)
    for i = #self.entities, 1, -1 do  -- Üstteki entity'leri önce kontrol et
        local entity = self.entities[i]
        if x >= entity.x and x <= entity.x + entity.width and
           y >= entity.y and y <= entity.y + entity.height then
            return entity
        end
    end
    return nil
end

function SceneManager:checkHandles(x, y, entity)
    local handleSize = self.handleSize / Camera.scaleX  -- Kamera ölçeğine göre ayarla
    
    -- Köşe tutamaçları
    -- Sol üst
    if x >= entity.x - handleSize/2 and x <= entity.x + handleSize/2 and
       y >= entity.y - handleSize/2 and y <= entity.y + handleSize/2 then
        return "topLeft"
    end
    
    -- Sağ üst
    if x >= entity.x + entity.width - handleSize/2 and x <= entity.x + entity.width + handleSize/2 and
       y >= entity.y - handleSize/2 and y <= entity.y + handleSize/2 then
        return "topRight"
    end
    
    -- Sol alt
    if x >= entity.x - handleSize/2 and x <= entity.x + handleSize/2 and
       y >= entity.y + entity.height - handleSize/2 and y <= entity.y + entity.height + handleSize/2 then
        return "bottomLeft"
    end
    
    -- Sağ alt
    if x >= entity.x + entity.width - handleSize/2 and x <= entity.x + entity.width + handleSize/2 and
       y >= entity.y + entity.height - handleSize/2 and y <= entity.y + entity.height + handleSize/2 then
        return "bottomRight"
    end
    
    -- Kenar tutamaçları
    -- Üst
    if x >= entity.x + entity.width/2 - handleSize/2 and x <= entity.x + entity.width/2 + handleSize/2 and
       y >= entity.y - handleSize/2 and y <= entity.y + handleSize/2 then
        return "top"
    end
    
    -- Alt
    if x >= entity.x + entity.width/2 - handleSize/2 and x <= entity.x + entity.width/2 + handleSize/2 and
       y >= entity.y + entity.height - handleSize/2 and y <= entity.y + entity.height + handleSize/2 then
        return "bottom"
    end
    
    -- Sol
    if x >= entity.x - handleSize/2 and x <= entity.x + handleSize/2 and
       y >= entity.y + entity.height/2 - handleSize/2 and y <= entity.y + entity.height/2 + handleSize/2 then
        return "left"
    end
    
    -- Sağ
    if x >= entity.x + entity.width - handleSize/2 and x <= entity.x + entity.width + handleSize/2 and
       y >= entity.y + entity.height/2 - handleSize/2 and y <= entity.y + entity.height/2 + handleSize/2 then
        return "right"
    end
    
    return nil
end

function SceneManager:screenToWorld(x, y)
    -- Get the window position of the SceneView
    local SceneView = require "modules.scene_view"
    local windowPos = {x = 0, y = 0}
    
    if imgui.GetWindowPos then
        local wx, wy = imgui.GetWindowPos()
        windowPos.x = wx
        windowPos.y = wy
    end
    
    -- Calculate the toolbar offset
    local toolbarOffset = SceneView.playButtonSize * 1.5
    
    -- Adjust mouse position relative to the Scene View window position
    -- and account for ImGui's toolbar
    local relativeX = x - windowPos.x
    local relativeY = y - windowPos.y - toolbarOffset
    
    -- Convert screen coordinates to world coordinates using the camera
    local scaleX = Camera.scaleX
    local scaleY = Camera.scaleY
    local offsetX = Camera.x
    local offsetY = Camera.y
    
    -- Calculate world position
    local worldX = (relativeX - love.graphics.getWidth() / 2) / scaleX + offsetX
    local worldY = (relativeY - love.graphics.getHeight() / 2) / scaleY + offsetY
    
    return worldX, worldY
end


function SceneManager:selectEntityAt(mouseX, mouseY)
    -- Select entity based on mouse click position
    local worldX, worldY = self:screenToWorld(mouseX, mouseY)
    
    -- Check for entity collision with mouse click
    for _, entity in ipairs(self.entities) do
        if worldX >= entity.x and worldX <= entity.x + entity.width and
           worldY >= entity.y and worldY <= entity.y + entity.height then
            State.selectedEntity = entity
            Console:log("Selected entity: " .. entity.name)
            return
        end
    end
end

function SceneManager:drawSceneEditor()
    -- Draw grid and entities in the scene editor window
    self:drawGrid()
    self:drawEntities()
end

function SceneManager:update(dt)
    -- Entity'lerin animasyonlarını güncelle
    for _, entity in ipairs(self.entities) do
        if entity.components and entity.components.animator then
            local animator = entity.components.animator
            if animator.playing and animator.currentAnimation then
                --animator.timer = animator.timer + dt
                
                local currentFrame = animator.currentAnimation.frames[animator.currentFrame]
                if currentFrame and animator.timer >= currentFrame.duration then
                    animator.timer = animator.timer - currentFrame.duration
                    animator.currentFrame = animator.currentFrame + 1
                    
                    -- Animasyon bittiğinde başa dön
                    if animator.currentFrame > #animator.currentAnimation.frames then
                        animator.currentFrame = 1
                    end
                end
            end
        end
    end
end

function SceneManager:handleDraggedAsset(asset, worldX, worldY)
    -- Eğer sürüklenen asset bir görsel ise
    if asset and asset.type == "image" then
        -- Yeni bir entity oluştur
        local newEntity = self:createEntity(worldX, worldY)
        
        -- Entity'e sprite component ekle
        newEntity.components.sprite = {
            image = asset,
            color = {1, 1, 1, 1}
        }
        
        -- Entitynin boyutunu resmin orijinal boyutuna ayarla
        local img = asset.data
        local w, h = img:getDimensions()
        newEntity.width = w
        newEntity.height = h
        
        Console:log("Created entity with dragged image: " .. asset.name)
    end
end


return SceneManager
