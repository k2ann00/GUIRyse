-- TODO: animasyon hızını düzenle
local world
_G.State = require "state"

local function loadModules()
    -- Load state first as it's required by all modules
    
    -- Load modules
    local AssetManager = require "modules.asset_manager"
    local Console = require "modules.console"
    local Camera = require "modules.camera"
    local Animator = require "modules.animator"
    local SceneManager = require "modules.scene_manager"
    local Hierarchy = require "modules.hierarchy"
    local Inspector = require "modules.inspector"
    local Shader = require "modules.shaders"
    local Tilemap = require "modules.tilemap"
    local GUIDManagerDirect = require "modules.guid_manager_direct"
    local SceneView = require "modules.scene_view"  -- Yeni SceneView modülü
    local PlayModeHelp = require "modules.play_mode_help"  -- Yeni PlayModeHelp modülü
    
    -- Initialize modules
    AssetManager:init()
    Console:init()
    Camera:init()
    Animator:init()
    SceneManager:init()
    Hierarchy:init()
    Inspector:init()
    Shader:init()
    Tilemap:init()
    GUIDManagerDirect:init()
    SceneView:init()  -- SceneView başlat
    PlayModeHelp:init()  -- PlayModeHelp başlat
    
    -- Log initialization
    Console:log("Engine initialized")
    _G.State.world = love.physics.newWorld(0, 9.81*64, true)
    world = _G.State.world

    return {
        state = _G.State,
        assetManager = AssetManager,
        console = Console,
        camera = Camera,
        animator = Animator,
        sceneManager = SceneManager,
        hierarchy = Hierarchy,
        inspector = Inspector,
        shader = Shader,
        tilemap = Tilemap,
        guidManagerDirect = GUIDManagerDirect,
        sceneView = SceneView,  -- Engine tablosuna ekle
        playModeHelp = PlayModeHelp  -- Engine tablosuna ekle
    }
end

function love.load()
    -- Initialize ImGui
    imgui = require "imgui"
    
    -- Load modules
    engine = loadModules()
    
    -- Engine title
    love.window.setTitle("RyseEngine Editor - v0.1")
    love.window.maximize = true
    love.graphics.setDefaultFilter("nearest", "nearest")
end

function love.update(dt)
    imgui.NewFrame()

    -- Update world physics (only when playing)
    if engine.sceneView.isPlaying and not engine.sceneView.isPaused then
        world:update(dt)
    end
    
    -- Always update components
    engine.camera:update(dt)
    engine.animator:update(dt)
    engine.sceneManager:update(dt)
    engine.shader:updateTime(dt)
    engine.sceneView:update(dt)  -- SceneView'ı güncelle

    engine.console:update()
    
    -- Draw ImGui windows
    engine.assetManager:draw()
    engine.console:draw()
    engine.camera:draw()
    engine.hierarchy:draw()
    engine.inspector:draw()
    engine.sceneView:draw()  -- SceneView'ı çiz
    engine.playModeHelp:draw()  -- PlayModeHelp'i çiz
    engine.tilemap:draw()
    engine.guidManagerDirect:draw()
    
    -- Only handle editor input when not in play mode
    if not engine.sceneView.isPlaying then
        engine.sceneManager:handleInput()
    end
end

function love.draw()
    -- Draw scene - Artık doğrudan burada çizmiyoruz, SceneView içinde çiziyoruz
    -- Eski kodlar yorum satırına alındı:
    --[[
    engine.camera:set()
    
    -- Draw grid only in Scene view (not in Game view)
    if not engine.sceneView.isPlaying then
        engine.sceneManager:drawGrid()
    end
    
    -- Always draw entities
    engine.sceneManager:drawEntities()
    
    -- Draw tilemap on scene
    engine.tilemap:drawOnScene()

    engine.camera:unset()
    ]]--
    
    -- Animator window hala normal akışta çizilmeli
    engine.animator:draw()
    
    -- Render ImGui
    imgui.Render()
end

function love.keypressed(key, scancode, isrepeat)
    imgui.KeyPressed(key)
    
    -- Check if SceneView wants to handle this key press
    if engine.sceneView:handleKeypress(key) then
        return -- Key was handled by SceneView
    end
    
    -- Global shortcuts
    if key == "escape" and not engine.sceneView.isPlaying then
        love.event.quit()
    elseif key == "g" and love.keyboard.isDown("lctrl") then
        -- Toggle GUID Manager with Ctrl+G
        _G.State.showWindows = _G.State.showWindows or {}
        _G.State.showWindows.guidManagerDirect = not (_G.State.showWindows.guidManagerDirect or false)
    end
end

function love.keyreleased(key, scancode)
    imgui.KeyReleased(key)
end

function love.mousemoved(x, y, dx, dy)
    imgui.MouseMoved(x, y)
    
    -- Tilemap mouse sürükleme işleme
    if engine.tilemap:mousemoved(x, y, dx, dy) then
        return
    end
    
    -- Camera pan with middle mouse button (only in Scene view)
    if love.mouse.isDown(3) and not engine.sceneView.isPlaying then  -- Middle mouse button
        engine.camera:move(
            -dx / engine.camera.scaleX,  -- scaleX kullan
            -dy / engine.camera.scaleY   -- scaleY kullan
        )
    end
end

function love.mousepressed(x, y, button)
    imgui.MousePressed(button)
    
    -- Tilemap mouse tıklama işleme
    if engine.tilemap:mousepressed(x, y, button) then
        return
    end
end

function love.mousereleased(x, y, button)
    imgui.MouseReleased(button)
end

function love.wheelmoved(x, y)
    imgui.WheelMoved(y)
    
    -- Zoom camera with mouse wheel (only in Scene view)
    if not imgui.GetWantCaptureMouse() and not engine.sceneView.isPlaying then
        if y > 0 then
            engine.camera:zoom(1.1)
        elseif y < 0 then
            engine.camera:zoom(0.9)
        end
    end
end

function love.textinput(text)
    imgui.TextInput(text)
end

function love.quit()
    imgui.ShutdownDock()
end