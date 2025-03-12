local State = require "state"
local Console = require "modules.console"

-- GUID Oluşturma Fonksiyonu
local function generateGUID()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format("%x", v)
    end)
end

local PlayModeHelp = {
    guid = generateGUID(), -- Benzersiz GUID
    showWindow = false,
    hasShownFirstTime = false,
    windowElements = {}, -- GUID'li pencere elemanları
    registeredComponents = {} -- GUID ile bileşen referanslarını tut
}

function PlayModeHelp:init()
    -- GUID kayıt sistemi kontrolü
    if State.registeredModules then
        State.registeredModules[self.guid] = {
            type = "PlayModeHelp",
            name = "Play Mode Help",
            instance = self
        }
    else
        State.registeredModules = {}
        State.registeredModules[self.guid] = {
            type = "PlayModeHelp",
            name = "Play Mode Help",
            instance = self
        }
    end
    
    State.showWindows.playModeHelp = false
    Console:log("Play Mode Help initialized with GUID: " .. self.guid)
    
    -- Pencere elemanları için GUID'ler oluştur
    self:registerComponents()
end

function PlayModeHelp:registerComponents()
    -- Metin ve bölümler için GUID'ler oluştur
    self.registeredComponents.titleText = {
        guid = generateGUID(),
        type = "Text",
        name = "TitleText"
    }
    
    self.registeredComponents.controlsSection = {
        guid = generateGUID(),
        type = "Section",
        name = "ControlsSection"
    }
    
    self.registeredComponents.featuresSection = {
        guid = generateGUID(),
        type = "Section",
        name = "FeaturesSection"
    }
    
    self.registeredComponents.modesSection = {
        guid = generateGUID(),
        type = "Section",
        name = "ModesSection"
    }
    
    self.registeredComponents.tipsSection = {
        guid = generateGUID(),
        type = "Section",
        name = "TipsSection"
    }
    
    self.registeredComponents.closeButton = {
        guid = generateGUID(),
        type = "Button",
        name = "CloseButton"
    }
    
    Console:log("Play Mode Help components registered with GUIDs")
end

function PlayModeHelp:showHelp()
    if not self.hasShownFirstTime then
        self.showWindow = true
        self.hasShownFirstTime = true
        State.showWindows.playModeHelp = true
        Console:log("Showing Play Mode Help (GUID: " .. self.guid .. ")")
    end
end

function PlayModeHelp:draw()
    if not self.showWindow and not State.showWindows.playModeHelp then return end
    
    imgui.SetNextWindowSize(600, 400, imgui.Cond_FirstUseEver)
    
    -- GUID'li pencere ID'si kullan
    local windowID = "Play Mode Instructions##" .. self.guid
    self.showWindow = imgui.Begin(windowID, self.showWindow)
    State.showWindows.playModeHelp = self.showWindow
    
    -- Başlık (GUID'li)
    imgui.PushStyleColor(imgui.Col_Text, 1, 0.7, 0.2, 1) -- Turuncu başlık
    imgui.Text("Welcome to Play Mode!")
    imgui.PopStyleColor()
    
    imgui.Separator()
    
    imgui.Text("Play Mode lets you test your game directly in the editor. Here's how it works:")
    imgui.Dummy(0, 10)
    
    -- Kontroller Bölümü (GUID'li)
    local controlsSectionID = "##ControlsSection" .. self.registeredComponents.controlsSection.guid
    imgui.PushStyleColor(imgui.Col_Text, 0.3, 0.8, 1.0, 1) -- Mavi bölüm başlıkları
    imgui.Text("Controls:" .. controlsSectionID)
    imgui.PopStyleColor()
    
    imgui.Columns(2, "ControlsColumns" .. generateGUID(), true)
    imgui.Text("Play/Stop"); imgui.NextColumn(); imgui.Text("Green/Red button or Space key"); imgui.NextColumn()
    imgui.Text("Pause"); imgui.NextColumn(); imgui.Text("Blue button or P key"); imgui.NextColumn()
    imgui.Text("Step Frame"); imgui.NextColumn(); imgui.Text("Forward button (only when paused)"); imgui.NextColumn()
    imgui.Text("Stop Play Mode"); imgui.NextColumn(); imgui.Text("Stop button or Escape key"); imgui.NextColumn()
    imgui.Columns(1)
    
    imgui.Dummy(0, 10)
    
    -- Özellikler Bölümü (GUID'li)
    local featuresSectionID = "##FeaturesSection" .. self.registeredComponents.featuresSection.guid
    imgui.PushStyleColor(imgui.Col_Text, 0.3, 0.8, 1.0, 1)
    imgui.Text("Features:" .. featuresSectionID)
    imgui.PopStyleColor()
    imgui.Dummy(0, 5)
    
    imgui.BulletText("Physics simulation is active")
    imgui.BulletText("Animations play automatically")
    imgui.BulletText("Player entities respond to keyboard input")
    imgui.BulletText("Changes made in Play Mode are reverted when you stop")
    imgui.BulletText("Game timer shows elapsed time since play started")
    
    imgui.Dummy(0, 10)
    
    -- Editor ve Oyun Modu Karşılaştırma Bölümü (GUID'li)
    local modesSectionID = "##ModesSection" .. self.registeredComponents.modesSection.guid
    imgui.PushStyleColor(imgui.Col_Text, 0.3, 0.8, 1.0, 1)
    imgui.Text("Editor vs Play Mode:" .. modesSectionID)
    imgui.PopStyleColor()
    imgui.Dummy(0, 5)
    
    imgui.Columns(2, "ModeColumns" .. generateGUID(), true)
    
    imgui.PushStyleColor(imgui.Col_Text, 0.3, 1.0, 0.3, 1) -- Sahne/Editör için yeşil
    imgui.Text("Scene View (Edit Mode)"); 
    imgui.PopStyleColor()
    
    imgui.NextColumn()
    
    imgui.PushStyleColor(imgui.Col_Text, 0.3, 0.7, 1.0, 1) -- Oyun için mavi
    imgui.Text("Game View (Play Mode)"); 
    imgui.PopStyleColor()
    
    imgui.NextColumn()
    
    imgui.BulletText("Edit entities and components")
    imgui.BulletText("Place and arrange objects")
    imgui.BulletText("Create and adjust animations")
    imgui.BulletText("Set up physics properties")
    imgui.BulletText("Grid visible for alignment")
    
    imgui.NextColumn()
    
    imgui.BulletText("See the game as players will")
    imgui.BulletText("Test gameplay and interactions")
    imgui.BulletText("Animations play automatically")
    imgui.BulletText("Physics simulates realistically")
    imgui.BulletText("Camera follows player (if set)")
    
    imgui.Columns(1)
    
    imgui.Dummy(0, 15)
    
    -- İpuçları Bölümü (GUID'li)
    local tipsSectionID = "##TipsSection" .. self.registeredComponents.tipsSection.guid
    imgui.PushStyleColor(imgui.Col_Text, 0.3, 0.8, 1.0, 1)
    imgui.Text("Tips:" .. tipsSectionID)
    imgui.PopStyleColor()
    imgui.Dummy(0, 5)
    
    imgui.BulletText("To make an entity controllable, enable the 'Is Player' checkbox in Transform component")
    imgui.BulletText("Animations need an Animator component to play during game mode")
    imgui.BulletText("Colliders will automatically interact with physics in play mode")
    imgui.BulletText("Camera will follow entities marked as the player if camera target is set")
    imgui.BulletText("Press Step Frame when paused to advance the simulation one frame at a time")
    
    imgui.Dummy(0, 15)
    
    -- Merkezi Kapat butonu (GUID'li)
    local windowWidth = imgui.GetWindowWidth()
    local buttonWidth = 120
    imgui.SetCursorPosX((windowWidth - buttonWidth) / 2)
    
    local closeButtonID = "Got it!##" .. self.registeredComponents.closeButton.guid
    if imgui.Button(closeButtonID, buttonWidth, 30) then
        self.showWindow = false
        State.showWindows.playModeHelp = false
    end
    
    -- Don't show automatically again after first view
    self.hasShownFirstTime = true
    
    imgui.End()
end

-- GUID ile bileşenlere referans alma
function PlayModeHelp:getComponentByGUID(guid)
    for _, component in pairs(self.registeredComponents) do
        if component.guid == guid then
            return component
        end
    end
    return nil
end

-- Temizlik ve sonlandırma
function PlayModeHelp:cleanup()
    -- GUID kayıtlarından sil
    if State.registeredModules and State.registeredModules[self.guid] then
        State.registeredModules[self.guid] = nil
        Console:log("Play Mode Help unregistered (GUID: " .. self.guid .. ")")
    end
end

return PlayModeHelp