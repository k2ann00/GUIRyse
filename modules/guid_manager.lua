-- guid_manager.lua
-- A UI module for managing and saving GUIDs in the engine

local State = require "state"
local Console = require "modules.console"
local GUIDSaver = require "modules.guid_saver"

local GUIDManager = {
    showWindow = false,
    windowSizes = {width = 300, height = 200}
}

function GUIDManager:init()
    State.showWindows.guidManager = false
    State.windowSizes.guidManager = self.windowSizes
    Console:log("GUID Manager initialized")
end

function GUIDManager:draw()
    if not State.showWindows.guidManager then return end
    
    imgui.SetNextWindowSize(State.windowSizes.guidManager.width, State.windowSizes.guidManager.height, imgui.Cond_FirstUseEver)
    if imgui.Begin("GUID Manager", State.showWindows.guidManager) then
        imgui.Text("Asset and Entity GUID Management")
        imgui.Separator()
        
        -- Asset GUIDs
        if imgui.CollapsingHeader("Asset GUIDs", imgui.TreeNodeFlags_DefaultOpen) then
            local assetCount = 0
            for _, asset in ipairs(State.assets) do
                if asset.guid then
                    assetCount = assetCount + 1
                end
            end
            
            imgui.Text("Total assets with GUIDs: " .. assetCount)
            
            if imgui.Button("Save Asset GUIDs to File") then
                GUIDSaver:saveAssetGUIDs()
            end
            
            -- Show some sample GUIDs if available
            if assetCount > 0 then
                imgui.Separator()
                imgui.Text("Sample Asset GUIDs:")
                
                local sampleSize = math.min(5, assetCount)
                for i = 1, sampleSize do
                    local asset = State.assets[i]
                    if asset and asset.guid then
                        if imgui.Selectable(asset.name .. " = " .. asset.guid) then
                            -- Copy to clipboard functionality could be added here
                            Console:log("Selected GUID: " .. asset.guid)
                        end
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
            
            imgui.Text("Total entities with GUIDs: " .. entityCount)
            
            if imgui.Button("Save Entity GUIDs to File") then
                GUIDSaver:saveEntityGUIDs()
            end
            
            -- Show some sample GUIDs if available
            if entityCount > 0 then
                imgui.Separator()
                imgui.Text("Sample Entity GUIDs:")
                
                local sampleSize = math.min(5, entityCount)
                for i = 1, sampleSize do
                    local entity = SceneManager.entities[i]
                    if entity and entity.guid then
                        if imgui.Selectable((entity.name or "Unnamed") .. " = " .. entity.guid) then
                            -- Copy to clipboard functionality could be added here
                            Console:log("Selected GUID: " .. entity.guid)
                        end
                    end
                end
            end
        end
        
        imgui.Separator()
        
        -- Save All GUIDs button
        if imgui.Button("Save All GUIDs") then
            GUIDSaver:saveAllGUIDs()
        end
    end
    imgui.End()
end

return GUIDManager