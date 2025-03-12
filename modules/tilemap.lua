local State = require "state"
local Console = require "modules.console"
local SceneManager = require "modules.scene_manager"
local Camera = require "modules.camera"
local imgui = require "imgui"

local Tilemap = {
    showTilesetWindow = false,
    tilesetWindow = {
        animationName = "New Tilemap",
        colCount = 1,
        rowCount = 1,
        selectedTile = nil,
        hoveredTile = nil,
        asset = nil,
        entity = nil,
        tileWidth = 32,
        tileHeight = 32,
        mapWidth = 10,
        mapHeight = 10,
        currentLayer = 1,
        layers = {},
        lastMouseDown = false
    },
    active = false,
    selectedImage = nil,
    tileSize = 32,
    gridWidth = 0,
    gridHeight = 0,
    selectedTile = {x = 0, y = 0, width = 1, height = 1},
    maps = {},
    currentMap = nil,
    showWindow = false,
    previewScale = 1,
    drawMode = false
}

function Tilemap:init()
    Console:log("Tilemap module initialized")
    self.showTilesetWindow = false
end

function Tilemap:createComponent(entity, asset)
    -- Create a new tilemap component for an entity
    if not entity.components then
        entity.components = {}
    end
    
    entity.components.tilemap = {
        asset = asset,
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
    return entity.components.tilemap
end

function Tilemap:openTilesetWindow(entity, asset)
    self.showTilesetWindow = true
    self.tilesetWindow.entity = entity
    self.tilesetWindow.asset = asset
    
    -- Initialize from existing component or create new defaults
    local component = entity.components.tilemap
    if component then
        self.tilesetWindow.tileWidth = component.tileWidth
        self.tilesetWindow.tileHeight = component.tileHeight
        self.tilesetWindow.mapWidth = component.mapWidth
        self.tilesetWindow.mapHeight = component.mapHeight
        self.tilesetWindow.layers = component.layers
        self.tilesetWindow.currentLayer = component.currentLayer
    else
        -- Create a default layer
        self.tilesetWindow.layers = {
            {
                name = "Layer 1",
                visible = true,
                tiles = {}
            }
        }
    end
    
    -- Otomatik olarak grid boyutlarını hesapla
    if asset and asset.data then
        local imgWidth, imgHeight = asset.data:getDimensions()
        self.tilesetWindow.colCount = math.floor(imgWidth / self.tilesetWindow.tileWidth)
        self.tilesetWindow.rowCount = math.floor(imgHeight / self.tilesetWindow.tileHeight)
        
        -- Sıfır bölme hatasını önle
        if self.tilesetWindow.colCount < 1 then self.tilesetWindow.colCount = 1 end
        if self.tilesetWindow.rowCount < 1 then self.tilesetWindow.rowCount = 1 end
        
        Console:log(string.format("Tileset grid: %dx%d (col x row)", 
            self.tilesetWindow.colCount, self.tilesetWindow.rowCount))
    end
    
    Console:log("Opened tileset window for asset: " .. asset.name)
end

function Tilemap:addLayer()
    local layerCount = #self.tilesetWindow.layers + 1
    table.insert(self.tilesetWindow.layers, {
        name = "Layer " .. layerCount,
        visible = true,
        tiles = {}
    })
    Console:log("Added new layer: Layer " .. layerCount)
end

function Tilemap:removeLayer(index)
    if #self.tilesetWindow.layers > 1 then
        table.remove(self.tilesetWindow.layers, index)
        
        -- Adjust current layer if needed
        if self.tilesetWindow.currentLayer >= index then
            self.tilesetWindow.currentLayer = math.max(1, self.tilesetWindow.currentLayer - 1)
        end
        
        Console:log("Removed layer at index: " .. index)
    else
        Console:log("Cannot remove the last remaining layer", "warning")
    end
end

function Tilemap:placeTile(x, y, tile)
    if not self.tilesetWindow.layers[self.tilesetWindow.currentLayer] then return end
    
    -- Get current layer
    local layer = self.tilesetWindow.layers[self.tilesetWindow.currentLayer]
    
    -- Create a unique key for this position
    local key = x .. "," .. y
    
    -- Add or update tile
    layer.tiles[key] = {
        x = x,
        y = y,
        tileX = tile.x,
        tileY = tile.y
    }
end

function Tilemap:removeTile(x, y)
    if not self.tilesetWindow.layers[self.tilesetWindow.currentLayer] then return end
    
    -- Get current layer
    local layer = self.tilesetWindow.layers[self.tilesetWindow.currentLayer]
    
    -- Create a unique key for this position
    local key = x .. "," .. y
    
    -- Remove tile
    layer.tiles[key] = nil
end

function Tilemap:getTile(x, y, layerIndex)
    layerIndex = layerIndex or self.tilesetWindow.currentLayer
    if not self.tilesetWindow.layers[layerIndex] then return nil end
    
    -- Get layer
    local layer = self.tilesetWindow.layers[layerIndex]
    
    -- Create a unique key for this position
    local key = x .. "," .. y
    
    -- Return tile
    return layer.tiles[key]
end

function Tilemap:saveTilemap()
    if not self.tilesetWindow.entity then return end
    
    -- Get or create component
    if not self.tilesetWindow.entity.components.tilemap then
        self:createComponent(self.tilesetWindow.entity, self.tilesetWindow.asset)
    end
    
    local component = self.tilesetWindow.entity.components.tilemap
    
    -- Update component with window values
    component.asset = self.tilesetWindow.asset
    component.tileWidth = self.tilesetWindow.tileWidth
    component.tileHeight = self.tilesetWindow.tileHeight
    component.mapWidth = self.tilesetWindow.mapWidth
    component.mapHeight = self.tilesetWindow.mapHeight
    component.layers = self.tilesetWindow.layers
    component.currentLayer = self.tilesetWindow.currentLayer
    
    Console:log("Saved tilemap settings")
    self.showTilesetWindow = false
end

function Tilemap:draw()
    if not self.showWindow then return end
    
    local windowFlags = imgui.WindowFlags_NoCollapse
    
    imgui.SetNextWindowSize(600, 500, imgui.Cond_FirstUseEver)
    self.showWindow = imgui.Begin("Tilemap Düzenleyici", true, windowFlags)
    
    if self.selectedImage then
        -- Tileset önizleme
        imgui.Text("Tileset Önizleme")
        
        -- Tile boyutu ayarları
        if imgui.SliderInt("Tile Boyutu", self.tileSize, 8, 128) then
            self.gridWidth = math.floor(self.selectedImage:getWidth() / self.tileSize)
            self.gridHeight = math.floor(self.selectedImage:getHeight() / self.tileSize)
        end
        
        -- Önizleme ölçeği
        imgui.SliderFloat("Önizleme Ölçeği", self.previewScale, 0.1, 3.0)
        
        -- Çizim modu
        if imgui.Button(self.drawMode and "Çizim Modunu Kapat" or "Çizim Modunu Aç") then
            self.drawMode = not self.drawMode
        end
        
        imgui.Text("Seçili Tile: " .. self.selectedTile.x .. "," .. self.selectedTile.y)
        
        -- Tileset önizleme alanı
        local availWidth = imgui.GetContentRegionAvail()
        local imageWidth = self.selectedImage:getWidth() * self.previewScale
        local imageHeight = self.selectedImage:getHeight() * self.previewScale
        
        -- Önizleme alanı
        local cursorPosX, cursorPosY = imgui.GetCursorScreenPos()
        imgui.Image(self.selectedImage, imageWidth, imageHeight)
        
        -- Grid çizgileri ve tile seçimi
        imgui.SetCursorScreenPos(cursorPosX, cursorPosY)
        local drawList = imgui.GetWindowDrawList()
        
        -- Grid çizgileri
        for x = 0, self.gridWidth do
            local lineX = cursorPosX + x * self.tileSize * self.previewScale
            drawList:AddLine(
                lineX, cursorPosY,
                lineX, cursorPosY + imageHeight,
                imgui.GetColorU32(1, 1, 1, 0.5)
            )
        end
        
        for y = 0, self.gridHeight do
            local lineY = cursorPosY + y * self.tileSize * self.previewScale
            drawList:AddLine(
                cursorPosX, lineY,
                cursorPosX + imageWidth, lineY,
                imgui.GetColorU32(1, 1, 1, 0.5)
            )
        end
        
        -- Seçili tile'ı vurgula
        local selectedX = cursorPosX + self.selectedTile.x * self.tileSize * self.previewScale
        local selectedY = cursorPosY + self.selectedTile.y * self.tileSize * self.previewScale
        local selectedWidth = self.selectedTile.width * self.tileSize * self.previewScale
        local selectedHeight = self.selectedTile.height * self.tileSize * self.previewScale
        
        drawList:AddRect(
            selectedX, selectedY,
            selectedX + selectedWidth, selectedY + selectedHeight,
            imgui.GetColorU32(1, 0.5, 0, 1),
            0, 0, 2
        )
        
        -- Tile seçimi için mouse tıklama kontrolü
        if imgui.IsItemHovered() and imgui.IsMouseClicked(0) then
            local mouseX, mouseY = imgui.GetMousePos()
            local tileX = math.floor((mouseX - cursorPosX) / (self.tileSize * self.previewScale))
            local tileY = math.floor((mouseY - cursorPosY) / (self.tileSize * self.previewScale))
            
            if tileX >= 0 and tileX < self.gridWidth and tileY >= 0 and tileY < self.gridHeight then
                self.selectedTile.x = tileX
                self.selectedTile.y = tileY
            end
        end
    else
        imgui.Text("Lütfen bir tileset görüntüsü seçin")
        
        if imgui.Button("Görüntü Seç") then
            -- Burada görüntü seçme işlemi yapılabilir
            -- Örnek olarak, asset manager'dan seçilen bir görüntüyü kullanabilirsiniz
        end
    end
    
    imgui.End()
end

-- Sahneye tilemap çizme
function Tilemap:drawOnScene()
    if not self.currentMap or not self.selectedImage then return end
    
    love.graphics.setColor(1, 1, 1, 1)
    
    for i, tile in ipairs(self.currentMap.tiles) do
        local quad = love.graphics.newQuad(
            tile.srcX * self.tileSize,
            tile.srcY * self.tileSize,
            self.tileSize,
            self.tileSize,
            self.selectedImage:getDimensions()
        )
        
        love.graphics.draw(
            self.selectedImage,
            quad,
            tile.x * self.tileSize,
            tile.y * self.tileSize
        )
    end
    
    -- Çizim modunda iken grid göster
    if self.drawMode then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.3)
        
        -- Yatay çizgiler
        for y = 0, 30 do
            love.graphics.line(0, y * self.tileSize, 30 * self.tileSize, y * self.tileSize)
        end
        
        -- Dikey çizgiler
        for x = 0, 30 do
            love.graphics.line(x * self.tileSize, 0, x * self.tileSize, 30 * self.tileSize)
        end
        
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Sahne üzerinde tile yerleştirme
function Tilemap:placeOnScene(x, y)
    if not self.active or not self.selectedImage or not self.currentMap or not self.drawMode then return end
    
    -- Kamera pozisyonunu hesaba kat
    local worldX, worldY = State.camera:screenToWorld(x, y)
    
    local tileX = math.floor(worldX / self.tileSize)
    local tileY = math.floor(worldY / self.tileSize)
    
    -- Var olan tile'ı kontrol et ve güncelle veya yeni ekle
    local existingTile = false
    for i, tile in ipairs(self.currentMap.tiles) do
        if tile.x == tileX and tile.y == tileY then
            tile.srcX = self.selectedTile.x
            tile.srcY = self.selectedTile.y
            existingTile = true
            break
        end
    end
    
    if not existingTile then
        table.insert(self.currentMap.tiles, {
            x = tileX,
            y = tileY,
            srcX = self.selectedTile.x,
            srcY = self.selectedTile.y
        })
    end
end

-- Mouse tıklama işleme
function Tilemap:mousepressed(x, y, button)
    if not self.active or not self.drawMode then return false end
    
    if button == 1 and not imgui.GetWantCaptureMouse() then
        self:placeOnScene(x, y)
        return true
    end
    
    return false
end

-- Mouse sürükleme işleme
function Tilemap:mousemoved(x, y, dx, dy)
    if not self.active or not self.drawMode then return false end
    
    if love.mouse.isDown(1) and not imgui.GetWantCaptureMouse() then
        self:placeOnScene(x, y)
        return true
    end
    
    return false
end

-- Görüntü seçildiğinde tilemap oluşturma
function Tilemap:selectImage(image)
    self:createTilemap(image)
end

function Tilemap:createTilemap(image)
    self.selectedImage = image
    self.gridWidth = math.floor(image:getWidth() / self.tileSize)
    self.gridHeight = math.floor(image:getHeight() / self.tileSize)
    self.showWindow = true
    self.active = true
    
    -- Yeni bir harita oluştur
    self.currentMap = {
        image = image,
        tiles = {},
        width = 20,
        height = 15
    }
    
    table.insert(self.maps, self.currentMap)
end

-- Entity'nin tilemap component'ini çizme
function Tilemap:drawTilemap(entity)
    if not entity.components or not entity.components.tilemap then return end
    
    local component = entity.components.tilemap
    if not component.asset or not component.asset.data then return end
    
    local image = component.asset.data
    
    -- Her katmanı çiz
    for layerIndex, layer in ipairs(component.layers) do
        if layer.visible then
            for key, tile in pairs(layer.tiles) do
                local quad = love.graphics.newQuad(
                    tile.tileX * component.tileWidth,
                    tile.tileY * component.tileHeight,
                    component.tileWidth,
                    component.tileHeight,
                    image:getDimensions()
                )
                
                love.graphics.draw(
                    image,
                    quad,
                    entity.x + tile.x * component.tileWidth,
                    entity.y + tile.y * component.tileHeight
                )
            end
        end
    end
    
    -- Eğer bu entity seçiliyse ve tilemap düzenleme modu aktifse grid çiz
    if entity == State.selectedEntity and self.showTilesetWindow then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.3)
        
        -- Yatay çizgiler
        for y = 0, component.mapHeight do
            love.graphics.line(
                entity.x, 
                entity.y + y * component.tileHeight,
                entity.x + component.mapWidth * component.tileWidth, 
                entity.y + y * component.tileHeight
            )
        end
        
        -- Dikey çizgiler
        for x = 0, component.mapWidth do
            love.graphics.line(
                entity.x + x * component.tileWidth, 
                entity.y,
                entity.x + x * component.tileWidth, 
                entity.y + component.mapHeight * component.tileHeight
            )
        end
        
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Tilemap düzenleme işlemlerini işle
function Tilemap:handleMapEditing(entity)
    if not entity.components or not entity.components.tilemap then return end
    
    local component = entity.components.tilemap
    local mouseX, mouseY = love.mouse.getPosition()
    local worldX, worldY = Camera:screenToWorld(mouseX, mouseY)
    
    -- Fare tilemap sınırları içinde mi kontrol et
    local gridX = math.floor((worldX - entity.x) / component.tileWidth)
    local gridY = math.floor((worldY - entity.y) / component.tileHeight)
    
    if gridX >= 0 and gridX < component.mapWidth and
       gridY >= 0 and gridY < component.mapHeight then
        
        -- Sol tıklama ile tile yerleştir
        if love.mouse.isDown(1) then
            self:placeTile(gridX, gridY, self.tilesetWindow.selectedTile)
        end
        
        -- Sağ tıklama ile tile sil
        if love.mouse.isDown(2) then
            self:removeTile(gridX, gridY)
        end
    end
end

return Tilemap