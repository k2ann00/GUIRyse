local State = require "state"
local Console = require "modules.console"
local Camera = require "modules.camera"
local SceneManager = require "modules.scene_manager"

-- GUID Oluşturma Fonksiyonu
local function generateGUID()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format("%x", v)
    end)
end

local SceneView = {
    guid = generateGUID(), -- SceneView bileşeninin benzersiz GUID'si
    showWindow = true,
    isPlaying = false,
    isPaused = false,
    windowFlags = 0,
    viewType = "Scene", -- "Scene" or "Game"
    lastPauseState = false,
    gameTime = 0,
    playButtonSize = 30,
    editorCamera = { -- Store editor camera state
        guid = generateGUID(),
        x = 0,
        y = 0,
        scaleX = 1,
        scaleY = 1,
        rotation = 0
    },
    gameCamera = { -- Store game camera state
        guid = generateGUID(),
        x = 0,
        y = 0,
        scaleX = 1,
        scaleY = 1,
        rotation = 0
    },
    entityStates = {}, -- Store the original states of entities for reset
    renderCanvas = nil,  -- Canvas for rendering scene
    wantCaptureMouse = false  -- Mouse capture flag
}

function SceneView:init()
    -- Increase default window size
    State.showWindows.sceneView = true
    State.windowSizes.sceneView = {width = 1024, height = 768} -- Increased from 800x600
    self.windowFlags = 0
    if imgui.WindowFlags_NoScrollbar then
        self.windowFlags = self.windowFlags + imgui.WindowFlags_NoScrollbar
    end
    if imgui.WindowFlags_NoScrollWithMouse then
        self.windowFlags = self.windowFlags + imgui.WindowFlags_NoScrollWithMouse
    end
    if imgui.WindowFlags_NoCollapse then
        self.windowFlags = self.windowFlags + imgui.WindowFlags_NoCollapse
    end
    
    -- Render canvas oluştur - match the new larger size
    self.renderCanvas = love.graphics.newCanvas(1024, 768)
    
    Console:log("Scene View initialized with GUID: " .. self.guid)
end


function SceneView:saveEntityStates()
    self.entityStates = {}
    for _, entity in ipairs(SceneManager.entities) do
        -- Save the entity's state
        local stateCopy = {
            guid = entity.guid,
            x = entity.x,
            y = entity.y,
            rotation = entity.rotation,
            width = entity.width,
            height = entity.height,
            components = {}
        }
        
        -- Save component states (e.g., animator)
        if entity.components then
            if entity.components.animator then
                stateCopy.components.animator = {
                    currentFrame = entity.components.animator.currentFrame,
                    playing = entity.components.animator.playing,
                    timer = entity.components.animator.timer
                }
            end
        end
        
        self.entityStates[entity.guid] = stateCopy
    end
    
    -- Save camera state
    self.editorCamera = {
        x = Camera.x,
        y = Camera.y,
        scaleX = Camera.scaleX,
        scaleY = Camera.scaleY,
        rotation = Camera.rotation
    }
    
    Console:log("Saved entity states for play mode")
end


function SceneView:restoreEntityStates()
    for _, entity in ipairs(SceneManager.entities) do
        local savedState = self.entityStates[entity.guid]
        if savedState then
            entity.x = savedState.x
            entity.y = savedState.y
            entity.rotation = savedState.rotation
            entity.width = savedState.width
            entity.height = savedState.height
            
            -- Restore component states
            if entity.components and savedState.components then
                if entity.components.animator and savedState.components.animator then
                    entity.components.animator.currentFrame = savedState.components.animator.currentFrame
                    entity.components.animator.playing = savedState.components.animator.playing
                    entity.components.animator.timer = savedState.components.animator.timer
                end
            end
        end
    end
    
    -- Restore camera state
    Camera.x = self.editorCamera.x
    Camera.y = self.editorCamera.y
    Camera.scaleX = self.editorCamera.scaleX
    Camera.scaleY = self.editorCamera.scaleY
    Camera.rotation = self.editorCamera.rotation
    
    Console:log("Restored entity states from play mode")
end


function SceneView:startPlaying()
    if not self.isPlaying then
        self:saveEntityStates()
        self.isPlaying = true
        self.isPaused = false
        self.gameTime = 0
        self.viewType = "Game"
        
        -- Start animations for entities with animator components
        for _, entity in ipairs(SceneManager.entities) do
            if entity.components and entity.components.animator then
                entity.components.animator.playing = true
                entity.components.animator.timer = 0
            end
        end
        
        Console:log("Started play mode")
    end
end

function SceneView:stopPlaying()
    if self.isPlaying then
        self.isPlaying = false
        self.isPaused = false
        self.viewType = "Scene"
        self:restoreEntityStates()
        
        -- Stop animations
        for _, entity in ipairs(SceneManager.entities) do
            if entity.components and entity.components.animator then
                entity.components.animator.playing = false
            end
        end
        
        Console:log("Stopped play mode")
    end
end

function SceneView:togglePlaying()
    if self.isPlaying then
        self:stopPlaying()
    else
        self:startPlaying()
    end
end

function SceneView:pausePlaying()
    self.isPaused = not self.isPaused
    
    -- Pause/resume animations and physics
    for _, entity in ipairs(SceneManager.entities) do
        if entity.components and entity.components.animator then
            if self.isPaused then
                self.lastPauseState = entity.components.animator.playing
                entity.components.animator.playing = false
            else
                entity.components.animator.playing = self.lastPauseState
            end
        end
    end
    
    Console:log(self.isPaused and "Paused game" or "Resumed game")
end

function SceneView:handleCameraInput(dt)
    if not self.isHovered or self.isPlaying then return end
    
    -- Handle keyboard camera controls when SceneView is focused
    local moveSpeed = 500 * dt / Camera.scaleX  -- Base speed adjusted by zoom level
    
    -- Arrow keys and WASD for camera panning when holding Shift
    if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
        if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
            Camera:move(-moveSpeed, 0)
        end
        if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
            Camera:move(moveSpeed, 0) 
        end
        if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
            Camera:move(0, -moveSpeed)
        end
        if love.keyboard.isDown("down") or love.keyboard.isDown("s") then
            Camera:move(0, moveSpeed)
        end
    end
    
    -- Additional camera controls
    if love.keyboard.isDown("=") or love.keyboard.isDown("+") then
        Camera:zoom(1 + (0.5 * dt)) -- Zoom in
    end
    if love.keyboard.isDown("-") then
        Camera:zoom(1 - (0.5 * dt)) -- Zoom out
    end
end

function SceneView:update(dt)
    -- Handle camera input
    self:handleCameraInput(dt)
    
    -- Update game logic if in play mode
    if self.isPlaying and not self.isPaused then
        -- Update game time
        self.gameTime = self.gameTime + dt
        
        -- Update player entities
        for _, entity in ipairs(SceneManager.entities) do
            if entity.isPlayer and entity.playerSpeed then
                -- Handle player movement
                local speed = entity.playerSpeed * dt
                
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
                
                -- Update player position in State for other modules
                if entity == State.player then
                    State.playerX = entity.x
                    State.playerY = entity.y
                end
            end
        end
    end
    
    -- Make sure the render canvas matches the window size
    local w, h = love.graphics.getDimensions()
    if w > 0 and h > 0 and (
       self.renderCanvas:getWidth() ~= w or 
       self.renderCanvas:getHeight() ~= h) then
        -- Create a new canvas with the correct dimensions
        self.renderCanvas = love.graphics.newCanvas(w, h)
        Console:log("Resized render canvas to " .. w .. "x" .. h)
    end
end


-- Scene içeriğini canvas'a çizme fonksiyonu
function SceneView:renderScene()
    -- Canvas'a çizmeye başla
    love.graphics.setCanvas(self.renderCanvas)
    love.graphics.clear(0.1, 0.1, 0.1, 1) -- Koyu gri arka plan
    
    -- Kamera transformasyonlarını uygula
    Camera:set()
    
    -- Oyun modunda değilsek grid çiz
    if not self.isPlaying then
        SceneManager:drawGrid()
    end
    
    -- Entityleri çiz
    SceneManager:drawEntities()
    
    -- Tilemap çiz
    local Tilemap = require "modules.tilemap"
    Tilemap:drawOnScene()
    
    -- Kamera transformasyonlarını sıfırla
    Camera:unset()
    
    -- Normal canvas'a dön
    love.graphics.setCanvas()
end

function SceneView:draw()
    if not State.showWindows.sceneView then return end
    
    -- Sahneyi renderCanvas'a çiz
    self:renderScene()
    
    -- Scene View penceresini göster
    imgui.SetNextWindowSize(State.windowSizes.sceneView.width, State.windowSizes.sceneView.height, imgui.Cond_FirstUseEver)
    
    if imgui.Begin(self.viewType .. " View", State.showWindows.sceneView, self.windowFlags) then
        -- Get content region for the view
        local windowWidth = imgui.GetWindowWidth()
        local windowHeight = imgui.GetWindowHeight() - self.playButtonSize * 1.5
        
        -- Draw play control toolbar
        self:drawToolbar(windowWidth)
        
        -- Draw border line below toolbar
        imgui.Separator()
        
        -- Draw the view content in a child window
        if imgui.BeginChild("SceneContent", 0, 0, false, imgui.WindowFlags_NoScrollbar) then
            -- Get viewport dimensions
            local viewportWidth = imgui.GetWindowWidth()
            local viewportHeight = imgui.GetWindowHeight()
            
            -- Show a different border color in Game mode
            if self.viewType == "Game" then
                -- Blue border for Game mode
                imgui.PushStyleColor(imgui.Col_Border, 0, 0.5, 1.0, 1.0)
                imgui.PushStyleVar(imgui.StyleVar_FrameBorderSize, 2.0)
            else
                -- Gray border for Scene mode
                imgui.PushStyleColor(imgui.Col_Border, 0.5, 0.5, 0.5, 1.0)
                imgui.PushStyleVar(imgui.StyleVar_FrameBorderSize, 1.0)
            end
            
            -- Render canvas'ı viewport içine çiz
            imgui.Image(self.renderCanvas, viewportWidth, viewportHeight)
            
            -- Track if SceneView is hovered for input handling
            self.isHovered = imgui.IsItemHovered()
            self.wantCaptureMouse = imgui.GetWantCaptureMouse()
            
            -- Stil ayarlarını geri al
            imgui.PopStyleColor()
            imgui.PopStyleVar()
            
            imgui.EndChild()
        end
    end
    imgui.End()
end

function SceneView:drawToolbar(windowWidth)
    -- Set toolbar height
    local toolbarHeight = self.playButtonSize
    
    -- Center the toolbar buttons
    local buttonSpacing = 10
    local totalButtonWidth = self.playButtonSize * 3 + buttonSpacing * 2  -- for play, pause, step buttons
    local startX = (windowWidth - totalButtonWidth) / 2
    
    imgui.SetCursorPosX(startX)
    
    -- Play/Stop button
    if self.isPlaying then
        -- Draw stop button (red square)
        if imgui.ColorButton("##Stop", 1, 0.3, 0.3, 1, 0, self.playButtonSize, self.playButtonSize) then
            self:stopPlaying()
        end
        
        -- Draw tooltip on hover
        if imgui.IsItemHovered() then
            imgui.BeginTooltip()
            imgui.Text("Stop (Esc)")
            imgui.EndTooltip()
        end
    else
        -- Draw play button (green triangle using ColorButton)
        if imgui.ColorButton("##Play", 0.3, 1, 0.3, 1, 0, self.playButtonSize, self.playButtonSize) then
            self:startPlaying()
        end
        
        -- Draw tooltip on hover
        if imgui.IsItemHovered() then
            imgui.BeginTooltip()
            imgui.Text("Play")
            imgui.EndTooltip()
        end
    end
    
    -- Pause button
    imgui.SameLine()
    imgui.SetCursorPosX(startX + self.playButtonSize + buttonSpacing)
    
    local pauseButtonColor = self.isPaused and {0.3, 0.7, 1.0, 1.0} or {0.7, 0.7, 0.7, 1.0}
    
    if imgui.ColorButton("##Pause", pauseButtonColor[1], pauseButtonColor[2], pauseButtonColor[3], pauseButtonColor[4], 0, self.playButtonSize, self.playButtonSize) then
        if self.isPlaying then  -- Only allow pause when playing
            self:pausePlaying()
        end
    end
    
    -- Draw tooltip on hover
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.Text(self.isPlaying and (self.isPaused and "Resume" or "Pause") or "Pause (disabled)")
        imgui.EndTooltip()
    end
    
    -- Step button (for single frame advance)
    imgui.SameLine()
    imgui.SetCursorPosX(startX + self.playButtonSize * 2 + buttonSpacing * 2)
    
    if imgui.ColorButton("##Step", 0.7, 0.7, 0.7, 1, 0, self.playButtonSize, self.playButtonSize) then
        if self.isPlaying and self.isPaused then
            -- Execute a single frame
            Console:log("Stepped one frame")
            
            -- Process one frame of animation/physics
            local dt = 1/60 -- Adım başına sabit zaman
            
            -- Entity animasyonlarını bir kare ilerlet
            for _, entity in ipairs(SceneManager.entities) do
                if entity.components and entity.components.animator and 
                   entity.components.animator.currentAnimation then
                    local animator = entity.components.animator
                    animator.timer = animator.timer + dt
                    
                    local currentFrame = animator.currentAnimation.frames[animator.currentFrame]
                    if currentFrame and animator.timer >= currentFrame.duration then
                        animator.timer = animator.timer - currentFrame.duration
                        animator.currentFrame = animator.currentFrame + 1
                        
                        -- Animasyon sonuna gelince başa dön
                        if animator.currentFrame > #animator.currentAnimation.frames then
                            animator.currentFrame = 1
                        end
                    end
                end
            end
            
            -- Fiziği bir kare güncelle
            if State.world then
                State.world:update(dt)
            end
        end
    end
    
    -- Draw tooltip on hover
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.Text("Step Frame (only when paused)")
        imgui.EndTooltip()
    end
    
    -- Draw game time if playing
    if self.isPlaying then
        imgui.SameLine()
        imgui.SetCursorPosX(windowWidth - 150)
        imgui.AlignTextToFramePadding()
        
        local minutes = math.floor(self.gameTime / 60)
        local seconds = math.floor(self.gameTime % 60)
        local milliseconds = math.floor((self.gameTime * 1000) % 1000)
        local timeText = string.format("Time: %02d:%02d.%03d", minutes, seconds, milliseconds)
        
        imgui.Text(timeText)
    end
    
    -- Add separation space below the toolbar
    imgui.Dummy(0, 5)
end

-- Handle keyboard shortcuts
function SceneView:handleKeypress(key)
    if key == "space" then
        self:togglePlaying()
        return true
    elseif key == "escape" and self.isPlaying then
        self:stopPlaying()
        return true
    elseif key == "p" and self.isPlaying then
        self:pausePlaying()
        return true
    -- Add camera-specific shortcuts
    elseif key == "f" and State.selectedEntity and not self.isPlaying then
        -- Focus camera on selected entity
        Camera:focusOnEntity(State.selectedEntity)
        return true
    elseif key == "r" and not self.isPlaying then
        -- Reset camera position
        Camera:reset()
        return true
    elseif key == "0" and not self.isPlaying then
        -- Reset zoom to 1:1
        Camera.scaleX = 1
        Camera.scaleY = 1
        return true
    end
    
    return false
end

-- Fare yakalama durumunu kontrol et
function SceneView:isMouseCaptured()
    return self.wantCaptureMouse
end

return SceneView