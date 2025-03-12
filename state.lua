local State = {
    world = nil,
    assets = {},
    shaders = {},
    player = nil,
    playerX = 0,
    playerY = 0,
    consoleLog = {},
    selectedAsset = nil,
    selectedAssetType = nil,
    selectedAssetName = nil,
    selectedShaderAsset = nil,
    selectedShaderData = nil,
    draggedAsset = nil,
    dragStarted = false,
    scenes = {},
    currentScene = nil,
    animations = {},
    currentAnimation = nil,
    cameraSettings = {
        x = 0,
        y = 0,
        scaleX = 1,
        scaleY = 1,
        rotation = 0,
        target = nil
    },
    -- Game state for play mode
    playMode = {
        isPlaying = false,
        isPaused = false,
        gameTime = 0,
        startTime = 0
    },
    windowSizes = {
        assetManager = {width = 300, height = 300},
        console = {width = 300, height = 200},
        animator = {width = 400, height = 300},
        sceneView = {width = 800, height = 600},
        hierarchy = {width = 250, height = 400},
        inspector = {width = 300, height = 400},
        error = {width = 300, height = 200},
        shader = {width = 400, height = 300}
    },
    showWindows = {
        assetManager = true,
        console = true,
        animator = true,
        sceneEditor = true,
        properties = true,
        hierarchy = true,
        inspector = true,
        shaderEditor = false,
        guidManagerDirect = false,
        sceneView = true
    }
}

return State
