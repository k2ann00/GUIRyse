-- guid_manager_direct.lua
-- A UI module for managing and saving GUIDs in the engine using direct IO

local State = require "state"
local Console = require "modules.console"
local GUIDSaverDirect = require "modules.guid_saver"

local GUIDManagerDirect = {
    showWindow = false,
    windowSizes = {width = 300, height = 200}
}

function GUIDManagerDirect:init()
    -- State değişkeni burada hata veriyor, daha güvenli yaklaşım kullanalım
    self.showWindow = false
    self.windowSizes = {width = 300, height = 200}
    
    -- State değişkenini güvenli şekilde başlatmak için kontrol
    if _G.State then
        _G.State.showWindows = _G.State.showWindows or {}
        _G.State.showWindows.guidManagerDirect = false
        
        _G.State.windowSizes = _G.State.windowSizes or {}
        _G.State.windowSizes.guidManagerDirect = self.windowSizes
    end
    
    -- Console'u güvenli bir şekilde kullan
    if Console and Console.log then
        Console:log("GUID Manager Direct initialized")
    end
    
    -- Test konsol çalışıyor mu
    if GUIDSaverDirect and GUIDSaverDirect.testConsole then
        GUIDSaverDirect:testConsole()
    end
end

function GUIDManagerDirect:draw()
    -- Güvenli kontrol - eğer State veya gerekli alanlar yoksa kendi değerlerimizi kullan
    local showWindow = (_G.State and _G.State.showWindows and _G.State.showWindows.guidManagerDirect) or self.showWindow
    
    if not showWindow then return end
    
    -- Güvenli şekilde pencere boyutunu ayarla
    local width = 300
    local height = 200
    
    if _G.State and _G.State.windowSizes and _G.State.windowSizes.guidManagerDirect then
        width = _G.State.windowSizes.guidManagerDirect.width
        height = _G.State.windowSizes.guidManagerDirect.height
    else
        width = self.windowSizes.width
        height = self.windowSizes.height
    end
    
    imgui.SetNextWindowSize(width, height, imgui.Cond_FirstUseEver)
    if imgui.Begin("GUID Manager (Direct IO)", true) then
        imgui.Text("Asset ve Entity GUID Yönetimi")
        imgui.Separator()
        
        -- Asset GUIDs
        if imgui.CollapsingHeader("Asset GUIDs", imgui.TreeNodeFlags_DefaultOpen) then
            local assetCount = 0
            for _, asset in ipairs(State.assets) do
                if asset.guid then
                    assetCount = assetCount + 1
                end
            end
            
            imgui.Text("Toplam GUID'li asset: " .. assetCount)
            
            if imgui.Button("Asset GUID'leri Dosyaya Kaydet") then
                GUIDSaverDirect:saveAssetGUIDs()
                Console:log("GUID'ler kaydedilmeye çalışıldı", "info")
            end
            
            -- Show some sample GUIDs if available
            if assetCount > 0 then
                imgui.Separator()
                imgui.Text("Örnek Asset GUID'leri:")
                
                local sampleSize = math.min(5, assetCount)
                for i = 1, sampleSize do
                    local asset = State.assets[i]
                    if asset and asset.guid then
                        imgui.Text(asset.name .. " = " .. asset.guid)
                    end
                end
            end
        end
        
        -- Entity GUIDs
        local SceneManager = require "modules.scene_manager"
        if imgui.CollapsingHeader("Entity GUIDs", imgui.TreeNodeFlags_DefaultOpen) then
            local entityCount = 0
            for _, entity in ipairs(SceneManager.entities) do
                if entity.guid then
                    entityCount = entityCount + 1
                end
            end
            
            imgui.Text("Toplam GUID'li entity: " .. entityCount)
            
            if imgui.Button("Entity GUID'leri Dosyaya Kaydet") then
                GUIDSaverDirect:saveEntityGUIDs()
                Console:log("GUID'ler kaydedilmeye çalışıldı", "info")
            end
            
            -- Show some sample GUIDs if available
            if entityCount > 0 then
                imgui.Separator()
                imgui.Text("Örnek Entity GUID'leri:")
                
                local sampleSize = math.min(5, entityCount)
                for i = 1, sampleSize do
                    local entity = SceneManager.entities[i]
                    if entity and entity.guid then
                        imgui.Text((entity.name or "Unnamed") .. " = " .. entity.guid)
                    end
                end
            end
        end
        
        imgui.Separator()
        
        -- Konsol test butonu
        if imgui.Button("Konsolu Test Et") then
            GUIDSaverDirect:testConsole()
        end
        
        -- Tüm GUID'leri kaydet
        if imgui.Button("Tüm GUID'leri Kaydet") then
            GUIDSaverDirect:saveAllGUIDs()
        end
    end
    imgui.End()
end

return GUIDManagerDirect