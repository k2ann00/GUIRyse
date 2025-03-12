-- guid_saver_direct.lua
-- GUID'leri doğrudan IO kullanarak kaydeden bir modül

local State = require "state"
local Console = require "modules.console"

local GUIDSaverDirect = {}

-- Dosya yazmak için yardımcı fonksiyon
function GUIDSaverDirect:writeFile(path, content)
    local file, err = io.open(path, "w")
    if not file then
        Console:log("Dosya açılamadı: " .. path .. " - " .. tostring(err), "error")
        return false
    end
    
    file:write(content)
    file:close()
    
    Console:log("Dosya başarıyla kaydedildi: " .. path, "info")
    return true
end

-- Klasör oluşturmak için yardımcı fonksiyon
function GUIDSaverDirect:createDir(path)
    -- Bu fonksiyon Windows veya Unix sistemlerde klasör oluşturur
    local success, result, code
    
    if package.config:sub(1,1) == '\\' then -- Windows
        success, result, code = os.execute('mkdir "' .. path .. '"')
    else -- Unix/Linux/Mac
        success, result, code = os.execute('mkdir -p "' .. path .. '"')
    end
    
    if success then
        Console:log("Klasör oluşturuldu: " .. path, "info")
        return true
    else
        Console:log("Klasör oluşturulamadı: " .. path .. " - " .. tostring(result), "error")
        return false
    end
end

-- Asset GUID'lerini kaydet
function GUIDSaverDirect:saveAssetGUIDs()
    local fileContent = "-- Asset GUIDs\n-- Format: name = GUID\n\n"
    local assetCount = 0
    
    for _, asset in ipairs(State.assets) do
        if asset.guid then
            -- Format "name = GUID"
            local line = string.format("%s = \"%s\"\n", asset.name, asset.guid)
            fileContent = fileContent .. line
            assetCount = assetCount + 1
        end
    end
    
    fileContent = fileContent .. "\n-- Total assets: " .. assetCount
    
    -- Meta klasörünü oluştur (yoksa)
    self:createDir("meta")
    
    -- Dosyayı kaydet
    local success = self:writeFile("meta/asset_guids.txt", fileContent)
    
    if success then
        Console:log("Kaydedildi: " .. assetCount .. " asset GUID - meta/asset_guids.txt", "info")
        return true
    else
        return false
    end
end

-- Entity GUID'lerini kaydet
function GUIDSaverDirect:saveEntityGUIDs()
    local SceneManager = require "modules.scene_manager"
    local fileContent = "-- Entity GUIDs\n-- Format: name = GUID\n\n"
    local entityCount = 0
    
    for _, entity in ipairs(SceneManager.entities) do
        if entity.guid then
            -- Format "name = GUID"
            local line = string.format("%s = \"%s\"\n", entity.name or "Unnamed Entity", entity.guid)
            fileContent = fileContent .. line
            entityCount = entityCount + 1
        end
    end
    
    fileContent = fileContent .. "\n-- Total entities: " .. entityCount
    
    -- Meta klasörünü oluştur (yoksa)
    self:createDir("meta")
    
    -- Dosyayı kaydet
    local success = self:writeFile("meta/entity_guids.txt", fileContent)
    
    if success then
        Console:log("Kaydedildi: " .. entityCount .. " entity GUID - meta/entity_guids.txt", "info")
        return true
    else
        return false
    end
end

-- Tüm GUID'leri kaydet
function GUIDSaverDirect:saveAllGUIDs()
    local assetSuccess = self:saveAssetGUIDs()
    local entitySuccess = self:saveEntityGUIDs()
    
    if assetSuccess and entitySuccess then
        Console:log("Tüm GUID'ler başarıyla kaydedildi", "info")
    else
        Console:log("Bazı GUID'ler kaydedilemedi", "warning")
    end
end

-- Konsolun çalışıp çalışmadığını test et
function GUIDSaverDirect:testConsole()
    Console:log("Bu bir test mesajıdır. Konsol çalışıyor mu?", "info")
    Console:log("Bu bir hata test mesajıdır.", "error")
    Console:log("Bu bir uyarı test mesajıdır.", "warning")
    return true
end

return GUIDSaverDirect