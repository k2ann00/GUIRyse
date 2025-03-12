local State = require "state"
local Console = require "modules.console"
local SceneManager = require "modules.scene_manager"
local Camera = require "modules.camera"

local Animator = {
    currentFrame = 1,
    previewScale = 1,
    playing = false,
    timer = 0,
    showGridSystem = false,
    gridWindow = {
        animationName = "New Animation",
        colCount = 1,
        rowCount = 1,
        selectedFrames = {},
        asset = nil,
        entity = nil
    },
    renamingAnimation = {
        isRenaming = false,
        newName = "",
        animationToRename = nil
    },
    animations = {},  -- Store the animations
    wX = 0,
    wY = 0
}
Animator.__index = Animator

function Animator:init()
    self.animations = {}
    self.currentFrame = 1
    self.playing = false
    self.looping = true
    self.frameTime = 0.1
    self.timer = 0
    self.previewScale = 1
    self.framesPerRow = 1
    self.numRows = 1
    State.showWindows.animator = false -- Başlangıçta pencere kapalı olsun
end

-- Animation rename functions
function Animator:startRenameAnimation(animation)
    self.renamingAnimation.isRenaming = true
    self.renamingAnimation.newName = animation.name
    self.renamingAnimation.animationToRename = animation
end

function Animator:finishRenameAnimation()
    if self.renamingAnimation.animationToRename and self.renamingAnimation.newName ~= "" then
        self.renamingAnimation.animationToRename.name = self.renamingAnimation.newName
        Console:log("Renamed animation to: " .. self.renamingAnimation.newName)
    end
    self.renamingAnimation.isRenaming = false
    self.renamingAnimation.newName = ""
    self.renamingAnimation.animationToRename = nil
end

-- Initialize the grid system for the sprite sheet
function Animator:GridSystem(asset, entity)
    self.showGridSystem = true
    self.gridWindow.asset = asset
    self.gridWindow.entity = entity
    self.gridWindow.selectedFrames = {}
end

-- Create an animation from the selected frames
function Animator:createFromImage(imageAsset, name)
    local animation = {
        name = name,  -- Kullanıcının girdiği ismi kullan
        source = imageAsset,
        frames = {},
        frameDuration = 0.1,
        loop = true
    }
    
    if self.gridWindow.selectedFrames then
        local frameWidth = imageAsset.data:getWidth() / self.gridWindow.colCount
        local frameHeight = imageAsset.data:getHeight() / self.gridWindow.rowCount
        
        -- Sadece seçili frame'leri ekle
        for frameIndex, isSelected in pairs(self.gridWindow.selectedFrames) do
            if isSelected then
                local row = math.floor((frameIndex - 1) / self.gridWindow.colCount)
                local col = (frameIndex - 1) % self.gridWindow.colCount
                
                local frame = {
                    quad = love.graphics.newQuad(
                        col * frameWidth,
                        row * frameHeight,
                        frameWidth,
                        frameHeight,
                        imageAsset.data:getDimensions()
                    ),
                    duration = 0.1
                }
                table.insert(animation.frames, frame)
            end
        end
    end
    
    -- Add the animation to the list
    table.insert(self.animations, animation)
    State.currentAnimation = animation
    Console:log("Created animation: " .. animation.name, "info")
    return animation
end

-- Update the animator state
function Animator:update(dt)
    if not State.showWindows.animator then return end
    if imgui.IsWindowHovered() then return end

    local entity = State.selectedEntity
    if not entity or not entity.components.animator then return end

    local animator = entity.components.animator
    
    -- Eğer animator playing durumunda ise, animasyonu oynat
    if animator.playing and animator.currentAnimation then
        animator.timer = animator.timer + dt
        local currentFrame = animator.currentAnimation.frames[animator.currentFrame]
        
        -- Frame değiştirme kontrolü
        if currentFrame and animator.timer >= currentFrame.duration then
            animator.timer = animator.timer - currentFrame.duration
            animator.currentFrame = animator.currentFrame + 1
            if animator.currentFrame > #animator.currentAnimation.frames then
                animator.currentFrame = 1  -- Eğer son frame'e gelindiyse, tekrar başa dön
            end
        end
    end
end





-- Handle grid selection logic
function Animator:handleGridSelection(x, y)
    if x == nil or y == nil then
        Console:log("Error: x or y is nil!", "error")
        return
    else
        Console:log("SIKINTI YOK", "error")
    end

    local gridX = math.floor(x / self.gridWindow.tileWidth)
    local gridY = math.floor(y / self.gridWindow.tileHeight)

    local mouseX, mouseY = love.mouse.getPosition()
    local gridWindow = self.gridWindow
    local tileWidth, tileHeight = gridWindow.tileWidth, gridWindow.tileHeight
    local colCount, rowCount = gridWindow.colCount, gridWindow.rowCount

    local selectedCol = math.floor((mouseX - gridWindow.x) / tileWidth)
    local selectedRow = math.floor((mouseY - gridWindow.y) / tileHeight)

    if selectedCol >= 0 and selectedCol < colCount and selectedRow >= 0 and selectedRow < rowCount then
        gridWindow.selectedFrames = {selectedCol, selectedRow}
    end
end

function Animator:drawGrid()
    -- Eğer grid sistemi aktif değilse çık
    if not self.showGridSystem then return end

    -- Grid penceresinde çizim yapacağız
    local windowWidth, windowHeight = imgui.GetWindowSize()

    -- Grid çizgilerini grid sistem penceresinin içine çiz
    love.graphics.setColor(0.5, 0.5, 0.5, 0.3)  -- Hafif gri renk
    for x = 0, windowWidth, self.gridWindow.tileWidth do
        love.graphics.line(x, 0, x, windowHeight)
    end
    for y = 0, windowHeight, self.gridWindow.tileHeight do
        love.graphics.line(0, y, windowWidth, y)
    end
    love.graphics.setColor(1, 1, 1, 1)  -- Rengi sıfırla
end

function Animator:drawSprite(entity)
    -- Eğer sprite component'i yoksa çık
    if entity.components and entity.components.sprite and entity.components.sprite.image then
        local sprite = entity.components.sprite
        local image = sprite.image.data
        
        -- Grid System penceresinin içinde çiz
        local windowWidth, windowHeight = imgui.GetWindowSize()
        local scaleX = windowWidth / image:getWidth()
        local scaleY = windowHeight / image:getHeight()

        -- Flip işlemleri varsa uygula
        if sprite.flip_h then scaleX = -scaleX end
        if sprite.flip_v then scaleY = -scaleY end
        
        love.graphics.setColor(sprite.color or {1, 1, 1, 1})  -- Varsayılan beyaz renk
        love.graphics.draw(image, 0, 0, 0, scaleX, scaleY) -- Ekranın köşesinde çiz
    end
end

function Animator:drawGridSystemWindow()
    -- Grid System penceresini çizmek için uygun imgui fonksiyonları
    imgui.SetNextWindowSize(400, 450)
    if imgui.Begin("Grid System##popup", self.showGridSystem) then
        -- Animasyon ismini al
        self.gridWindow.animationName = imgui.InputText("Animation Name", self.gridWindow.animationName, 100)
        
        imgui.Separator()
        
        -- Grid boyutlarını seç
        self.gridWindow.colCount = imgui.SliderInt("Columns", self.gridWindow.colCount, 1, 10)
        self.gridWindow.rowCount = imgui.SliderInt("Rows", self.gridWindow.rowCount, 1, 10)
        
        -- Grid önizleme alanı (sprite sheet için)
        local previewSize = 300
        imgui.BeginChild("GridPreview", previewSize, previewSize, true)
        
        -- Get window position (Grid System popup penceresinin koordinatlarını al)
        local wx, wy = imgui.GetWindowPos()
        local cx, cy = imgui.GetCursorScreenPos()
        
        -- Convert to world coordinates
        local worldX, worldY = SceneManager:screenToWorld(wx, wy)
        
        love.graphics.push("all")
        
        -- Draw sprite sheet
        love.graphics.setColor(1, 1, 1, 1)
        self.gridWindow.asset.data:setFilter("nearest", "nearest")
        love.graphics.draw(self.gridWindow.asset.data, worldX, worldY, 0, 
            previewSize / self.gridWindow.asset.data:getWidth() / Camera.scaleX,
            previewSize / self.gridWindow.asset.data:getHeight() / Camera.scaleY)

        -- Draw grid lines
        local cellWidth = (previewSize / self.gridWindow.colCount) / Camera.scaleX
        local cellHeight = (previewSize / self.gridWindow.rowCount) / Camera.scaleY
        
        love.graphics.setColor(1, 1, 0, 0.3)
        for i = 1, self.gridWindow.colCount do
            love.graphics.line(
                wX + i * cellWidth, wY,
                wX + i * cellWidth, wY + (previewSize / Camera.scaleY)
            )
        end
        
        for i = 1, self.gridWindow.rowCount do
            love.graphics.line(
                wX, wY + i * cellHeight,
                wX + (previewSize / Camera.scaleX), wY + i * cellHeight
            )
        end
        
        -- Mouse position and selection
        local mx, my = love.mouse.getPosition()
        local worldMX, worldMY = SceneManager:screenToWorld(mx, my)
        
        -- Check if mouse is within the sprite sheet area
        if worldMX >= worldX and worldMX < worldX + (previewSize / Camera.scaleX) and
           worldMY >= worldY and worldMY < worldY + (previewSize / Camera.scaleY) then
            
            -- Calculate grid cell coordinates
            local gridX = math.floor((worldMX - worldX) / cellWidth)
            local gridY = math.floor((worldMY - worldY) / cellHeight)
            
            -- Check if the selected cell is within bounds
            if gridX >= 0 and gridX < self.gridWindow.colCount and
               gridY >= 0 and gridY < self.gridWindow.rowCount then
                
                -- Highlight the selected cell
                love.graphics.setColor(1, 1, 0, 0.2)
                love.graphics.rectangle("fill", 
                    worldX + gridX * cellWidth, 
                    worldY + gridY * cellHeight, 
                    cellWidth, 
                    cellHeight
                )
                
                -- Select frame with click
                if love.mouse.isDown(1) and not self.lastMouseDown then
                    local frameIndex = gridY * self.gridWindow.colCount + gridX + 1
                    if not self.gridWindow.selectedFrames[frameIndex] then
                        self.gridWindow.selectedFrames[frameIndex] = {
                            quad = love.graphics.newQuad(
                                gridX * (self.gridWindow.asset.data:getWidth() / self.gridWindow.colCount),
                                gridY * (self.gridWindow.asset.data:getHeight() / self.gridWindow.rowCount),
                                self.gridWindow.asset.data:getWidth() / self.gridWindow.colCount,
                                self.gridWindow.asset.data:getHeight() / self.gridWindow.rowCount,
                                self.gridWindow.asset.data:getDimensions()
                            ),
                            duration = 0.1,
                            x = gridX,
                            y = gridY
                        }
                        Console:log("Selected frame " .. frameIndex)
                    else
                        self.gridWindow.selectedFrames[frameIndex] = nil
                        Console:log("Deselected frame " .. frameIndex)
                    end
                    self.lastMouseDown = true
                end
            end
        end
        
        -- Update mouse state (every frame)
        if not love.mouse.isDown(1) then
            self.lastMouseDown = false
        end

        -- Show selected frames
        love.graphics.setColor(0, 1, 0, 0.3)
        for i, frame in pairs(self.gridWindow.selectedFrames) do
            local fx = frame.x
            local fy = frame.y
            love.graphics.rectangle("fill", 
                wX + fx * cellWidth, 
                wY + fy * cellHeight, 
                cellWidth, 
                cellHeight
            )
        end
        
        love.graphics.pop()
        
        imgui.EndChild()
        
        -- Mouse state update
        self.lastMouseDown = love.mouse.isDown(1)
        
        -- Create Animation button
        if imgui.Button("Create Animation") then
            -- Sort frames
            local sortedFrames = {}
            for i = 1, self.gridWindow.colCount * self.gridWindow.rowCount do
                if self.gridWindow.selectedFrames[i] then
                    table.insert(sortedFrames, self.gridWindow.selectedFrames[i])
                end
            end
            
            if #sortedFrames > 0 then
                -- Check if the entity has an animator component
                if not self.gridWindow.entity.components.animator.animations then
                    self.gridWindow.entity.components.animator.animations = {}
                end
                
                local animation = {
                    name = self.gridWindow.animationName,
                    source = self.gridWindow.asset,
                    frames = sortedFrames,
                    frameWidth = self.gridWindow.asset.data:getWidth() / self.gridWindow.colCount,
                    frameHeight = self.gridWindow.asset.data:getHeight() / self.gridWindow.rowCount
                }
                
                -- Add animation to entity's animator
                table.insert(self.gridWindow.entity.components.animator.animations, animation)
                self.gridWindow.entity.components.animator.currentAnimation = animation
                self.gridWindow.entity.components.animator.currentFrame = 1
                self.gridWindow.entity.components.animator.timer = 0
                
                Console:log("Created animation: " .. self.gridWindow.animationName)
                self.showGridSystem = false  -- Close the grid system window
                
                -- Reset grid window
                self.gridWindow.selectedFrames = {}
                self.gridWindow.animationName = "New Animation"
            else
                Console:log("Please select at least one frame!")
            end
        end
        
        imgui.SameLine()
        
        if imgui.Button("Cancel") then
            self.showGridSystem = false  -- Close the grid system window
        end

        imgui.End()
    end
end





-- Main function to draw the Animator window
function Animator:draw()
    if not State.showWindows.animator then return end
    
    local entity = State.selectedEntity
    if not entity or not entity.components.animator then return end
    
    imgui.SetNextWindowSize(State.windowSizes.animator.width, State.windowSizes.animator.height, imgui.Cond_FirstUseEver)
    if imgui.Begin("Animator", State.showWindows.animator) then
        -- New animation creation button
        if imgui.Button("Create New Animation") then
            if State.selectedAsset and State.selectedAsset.type == "image" then
                self:GridSystem(State.selectedAsset, entity)
            else
                Console:log("Please select an image asset first!")
            end
        end
        
        imgui.Separator()
        
        -- Display the list of animations
        local anim_text_color = {0, 1, 0, 1}
        imgui.PushStyleColor(imgui.Col_Text, anim_text_color[1], anim_text_color[2], anim_text_color[3], anim_text_color[4])
        imgui.Text("Animations:")
        imgui.PopStyleColor()
        
        if entity.components.animator.animations then
            for i, anim in ipairs(entity.components.animator.animations) do
                local isSelected = entity.components.animator.currentAnimation == anim
                
                -- Handle renaming animation
                if self.renamingAnimation.isRenaming and self.renamingAnimation.animationToRename == anim then
                    self.renamingAnimation.newName = imgui.InputText("##RenameAnimation" .. i, self.renamingAnimation.newName, 100)
                    imgui.SameLine()
                    if imgui.Button("Save##" .. i) then
                        self:finishRenameAnimation()
                    end
                    if not imgui.IsItemActive() and imgui.IsMouseClicked(0) then
                        self:finishRenameAnimation()
                    end
                else
                    if imgui.Selectable(anim.name, isSelected) then
                        entity.components.animator.currentAnimation = anim
                        entity.components.animator.currentFrame = 1
                    end
                end
                
                if imgui.BeginPopupContextItem() then
                    if imgui.MenuItem("Delete") then
                        table.remove(entity.components.animator.animations, i)
                        if entity.components.animator.currentAnimation == anim then
                            entity.components.animator.currentAnimation = nil
                        end
                    end
                    if imgui.MenuItem("Rename") then
                        self:startRenameAnimation(anim)
                    end
                    imgui.EndPopup()
                end
            end
        end
        
        imgui.Separator()
        
        -- Animation controls
        local animator = entity.components.animator
        if animator.currentAnimation then
            -- Play/Pause button
            if animator.playing then
                if imgui.Button("Pause") then
                    animator.playing = false
                end
            else
                if imgui.Button("Play") then
                    animator.playing = true
                    animator.timer = 0  -- Reset the timer
                end
            end
            
            -- Frame slider
            if animator.currentAnimation.frames then
                local frameCount = #animator.currentAnimation.frames
                local newFrame = imgui.SliderInt("Frame", animator.currentFrame, 1, frameCount)
                if newFrame ~= animator.currentFrame then
                    animator.currentFrame = newFrame
                    animator.timer = 0  -- Reset the timer when the frame changes
                end
            end
            
            -- Frame duration slider
            if animator.currentAnimation.frames and animator.currentAnimation.frames[animator.currentFrame] then
                local duration = imgui.SliderFloat("Frame Duration", 
                    animator.currentAnimation.frames[animator.currentFrame].duration, 
                    0.01, 1.0)
                if duration ~= animator.currentAnimation.frames[animator.currentFrame].duration then
                    animator.currentAnimation.frames[animator.currentFrame].duration = duration
                end
            end
        end
        
        imgui.End()
    end
    
    -- Grid System window (popup)
    if self.showGridSystem then
        imgui.SetNextWindowSize(400, 450)
        if imgui.Begin("Grid System##popup", self.showGridSystem) then
            -- Animation name input
            self.gridWindow.animationName = imgui.InputText("Animation Name", self.gridWindow.animationName, 100)
            
            imgui.Separator()
            
            -- Grid dimensions
            self.gridWindow.colCount = imgui.SliderInt("Columns", self.gridWindow.colCount, 1, 10)
            self.gridWindow.rowCount = imgui.SliderInt("Rows", self.gridWindow.rowCount, 1, 10)
            
            -- Grid preview area (as a frame)
            local previewSize = 300
            imgui.BeginChild("GridPreview", previewSize, previewSize, true)
            
            -- Get window position
            local wx, wy = imgui.GetWindowPos()
            local cx, cy = imgui.GetCursorScreenPos()
            wX = wx
            wY = wy
            
            -- Convert to world coordinates
            local worldX, worldY = SceneManager:screenToWorld(wx, wy)


            -- Draw sprite sheet in world coordinates
            love.graphics.push("all")
            
            -- Draw sprite sheet
            love.graphics.setColor(1, 1, 1, 1)
            self.gridWindow.asset.data:setFilter("nearest", "nearest")
            love.graphics.draw(self.gridWindow.asset.data, wx, wy, 0, 
                previewSize / self.gridWindow.asset.data:getWidth() / Camera.scaleX,
                previewSize / self.gridWindow.asset.data:getHeight() / Camera.scaleY)

            -- Draw grid lines
            local cellWidth = (previewSize / self.gridWindow.colCount) / Camera.scaleX
            local cellHeight = (previewSize / self.gridWindow.rowCount) / Camera.scaleY
            
            -- Draw grid lines
            love.graphics.setColor(1, 1, 0, 0.3)
            for i = 1, self.gridWindow.colCount do
                love.graphics.line(
                    wX + i * cellWidth, wY,
                    wX + i * cellWidth, wY + (previewSize / Camera.scaleY)
                )
            end
            
            for i = 1, self.gridWindow.rowCount do
                love.graphics.line(
                    wX, wY + i * cellHeight,
                    wX + (previewSize / Camera.scaleX), wY + i * cellHeight
                )
            end
            
            -- Mouse position and selection
            local mx, my = love.mouse.getPosition()
            local worldMX, worldMY = SceneManager:screenToWorld(mx, my)
            
            -- Check if mouse is within the sprite sheet area
            if worldMX >= worldX and worldMX < worldX + (previewSize / Camera.scaleX) and
               worldMY >= worldY and worldMY < worldY + (previewSize / Camera.scaleY) then
                
                -- Calculate grid cell coordinates
                local gridX = math.floor((worldMX - worldX) / cellWidth)
                local gridY = math.floor((worldMY - worldY) / cellHeight)
                
                -- Check if the selected cell is within bounds
                if gridX >= 0 and gridX < self.gridWindow.colCount and
                   gridY >= 0 and gridY < self.gridWindow.rowCount then
                    
                    -- Highlight the selected cell
                    love.graphics.setColor(1, 1, 0, 0.2)
                    love.graphics.rectangle("fill", 
                        wX + gridX * cellWidth, 
                        wY + gridY * cellHeight, 
                        cellWidth, 
                        cellHeight
                    )
                    
                    -- Select frame with click
                    if love.mouse.isDown(1) and not self.lastMouseDown then
                        local frameIndex = gridY * self.gridWindow.colCount + gridX + 1
                        if not self.gridWindow.selectedFrames[frameIndex] then
                            self.gridWindow.selectedFrames[frameIndex] = {
                                quad = love.graphics.newQuad(
                                    gridX * (self.gridWindow.asset.data:getWidth() / self.gridWindow.colCount),
                                    gridY * (self.gridWindow.asset.data:getHeight() / self.gridWindow.rowCount),
                                    self.gridWindow.asset.data:getWidth() / self.gridWindow.colCount,
                                    self.gridWindow.asset.data:getHeight() / self.gridWindow.rowCount,
                                    self.gridWindow.asset.data:getDimensions()
                                ),
                                duration = 0.1,
                                x = gridX,
                                y = gridY
                            }
                            Console:log("Selected frame " .. frameIndex)
                        else
                            self.gridWindow.selectedFrames[frameIndex] = nil
                            Console:log("Deselected frame " .. frameIndex)
                        end
                        self.lastMouseDown = true
                    end
                end
            end
            
            -- Update mouse state (every frame)
            if not love.mouse.isDown(1) then
                self.lastMouseDown = false
            end

            -- Show selected frames
            love.graphics.setColor(0, 1, 0, 0.3)
            for i, frame in pairs(self.gridWindow.selectedFrames) do
                local fx = frame.x
                local fy = frame.y
                love.graphics.rectangle("fill", 
                    wX + fx * cellWidth, 
                    wY + fy * cellHeight, 
                    cellWidth, 
                    cellHeight
                )
            end
            
            love.graphics.pop()
            
            imgui.EndChild()
            
            -- Mouse state update
            self.lastMouseDown = love.mouse.isDown(1)
            
            -- Create Animation button
            if imgui.Button("Create Animation") then
                -- Sort frames
                local sortedFrames = {}
                for i = 1, self.gridWindow.colCount * self.gridWindow.rowCount do
                    if self.gridWindow.selectedFrames[i] then
                        table.insert(sortedFrames, self.gridWindow.selectedFrames[i])
                    end
                end
                
                if #sortedFrames > 0 then
                    -- Check if the entity has an animator component
                    if not self.gridWindow.entity.components.animator.animations then
                        self.gridWindow.entity.components.animator.animations = {}
                    end
                    
                    local animation = {
                        name = self.gridWindow.animationName,
                        source = self.gridWindow.asset,
                        frames = sortedFrames,
                        frameWidth = self.gridWindow.asset.data:getWidth() / self.gridWindow.colCount,
                        frameHeight = self.gridWindow.asset.data:getHeight() / self.gridWindow.rowCount
                    }
                    
                    -- Add animation to entity's animator
                    table.insert(self.gridWindow.entity.components.animator.animations, animation)
                    self.gridWindow.entity.components.animator.currentAnimation = animation
                    self.gridWindow.entity.components.animator.currentFrame = 1
                    self.gridWindow.entity.components.animator.timer = 0
                    
                    Console:log("Created animation: " .. self.gridWindow.animationName)
                    self.showGridSystem = false  -- Close the grid system window
                    
                    -- Reset grid window
                    self.gridWindow.selectedFrames = {}
                    self.gridWindow.animationName = "New Animation"
                else
                    Console:log("Please select at least one frame!")
                end
            end
            
            imgui.SameLine()
            
            if imgui.Button("Cancel") then
                self.showGridSystem = false  -- Close the grid system window
            end

            imgui.End()
        end
    end
end

return Animator
