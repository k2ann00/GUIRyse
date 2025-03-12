local State = require "state"
local Console = require "modules.console"

-- GUID Üreticisi
local GUID = {}

-- UUID v4 formatında (rasgele) benzersiz bir tanımlayıcı oluşturur
function GUID.generate()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format("%x", v)
    end)
end

-- Bir GUID'in geçerli olup olmadığını kontrol eder
function GUID.isValid(guid)
    if type(guid) ~= "string" then return false end
    return guid:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

-- GUID'leri depolamak için yardımcı tablo
local GUIDRegistry = {
    guidToAsset = {}, -- GUID -> Asset mapping
    pathToGuid = {},  -- Path -> GUID mapping
    metaCache = {}    -- Meta dosyaları için önbellek
}

local AssetManager = {
    currentPath = "assets",
    filter = "",
    supportedTypes = {
        image = {"png", "jpg", "jpeg", "bmp"},
        sound = {"mp3", "wav", "ogg"},
        font = {"ttf", "otf"},
        script = {"lua"},
        shader = {"glsl"}
    }
}

function AssetManager:init()
    -- Math.random kullanımı için seed oluştur
    math.randomseed(os.time())
    
    State.showWindows.assetManager = true
    State.windowSizes.assetManager = {width = 300, height = 300}
    
    -- Meta dosyaları klasörü oluştur
    if not love.filesystem.getInfo(".meta") then
        love.filesystem.createDirectory(".meta")
        Console:log("Created .meta directory for GUID storage")
    end
    
    -- Eğer assets klasörü yoksa oluştur
    if not love.filesystem.getInfo("assets") then
        love.filesystem.createDirectory("assets")
        Console:log("Created assets directory")
    end
    
    -- Meta dosyalarını yükle
    self:loadAllMetaFiles()
    
    -- Başlangıçta assets klasöründeki dosyaları yükle
    self:scanDirectory("assets")
end

function getMetaFilePath(assetPath)
    -- LÖVE2D'nin . ile başlayan dosyaları saklaması için özel dizin kullan
    return ".meta/" .. string.gsub(assetPath, "[/\\]", "_") .. ".meta"
end

-- GUID değerini meta dosyasına kaydetme
function AssetManager:saveMetaFile(assetPath, guid)
    local metaPath = getMetaFilePath(assetPath)
    local metaContent = {
        guid = guid,
        assetPath = assetPath,
        lastModified = os.time()
    }
    
    -- Meta verisini JSON olarak kaydet
    local success, metaJson = pcall(function()
        -- Basit JSON dönüşümü (tam JSON kütüphanesi olmadan)
        return string.format('{"guid":"%s","assetPath":"%s","lastModified":%d}',
            metaContent.guid, 
            metaContent.assetPath:gsub([[\]], [[\\]]):gsub('"', '\\"'), 
            metaContent.lastModified)
    end)
    
    if success then
        -- Meta dosyasını kaydet
        local success, err = love.filesystem.write(metaPath, metaJson)
        if not success then
            Console:log("Failed to save meta file: " .. metaPath .. " - " .. tostring(err), "error")
        else
            -- Önbelleğe ekle
            GUIDRegistry.metaCache[assetPath] = metaContent
        end
    else
        Console:log("Failed to create meta content for: " .. assetPath, "error")
    end
end

-- Meta dosyasını okuma
function AssetManager:loadMetaFile(assetPath)
    -- Önce önbellekte kontrol et
    if GUIDRegistry.metaCache[assetPath] then
        return GUIDRegistry.metaCache[assetPath]
    end
    
    local metaPath = getMetaFilePath(assetPath)
    
    --TODO: Modüler yap ve kaydet 
    -- Meta dosyası var mı kontrol et
    if love.filesystem.getInfo(metaPath) then
        local content, size = love.filesystem.read(metaPath)
        
        if content and size > 0 then
            -- Basit JSON ayrıştırma (tam JSON kütüphanesi olmadan)
            local guid = content:match('"guid":"([^"]+)"')
            
            if guid and GUID.isValid(guid) then
                local metaData = {
                    guid = guid,
                    assetPath = assetPath,
                    lastModified = tonumber(content:match('"lastModified":(%d+)')) or os.time()
                }
                
                -- Önbelleğe ekle
                GUIDRegistry.metaCache[assetPath] = metaData
                return metaData
            end
        end
    end
    
    -- Meta dosyası yoksa ya da okunamadıysa yeni bir GUID oluştur
    local newGuid = GUID.generate()
    local metaData = {
        guid = newGuid,
        assetPath = assetPath,
        lastModified = os.time()
    }
    
    -- Yeni meta dosyasını kaydet
    self:saveMetaFile(assetPath, newGuid)
    
    -- Önbelleğe ekle
    GUIDRegistry.metaCache[assetPath] = metaData
    return metaData
end

-- Tüm meta dosyalarını yükle ve GUID kayıtlarını oluştur
function AssetManager:loadAllMetaFiles()
    if not love.filesystem.getInfo(".meta") then return end
    
    local items = love.filesystem.getDirectoryItems(".meta")
    
    for _, item in ipairs(items) do
        if item:match("%.meta$") then
            local metaPath = ".meta/" .. item
            local content, size = love.filesystem.read(metaPath)
            
            if content and size > 0 then
                -- Basit JSON ayrıştırma
                local guid = content:match('"guid":"([^"]+)"')
                local assetPath = content:match('"assetPath":"([^"]+)"')
                
                if guid and assetPath and GUID.isValid(guid) then
                    -- Path içindeki kaçış karakterlerini düzelt
                    assetPath = assetPath:gsub([[\\]], [[\]])
                    
                    -- GUID kayıtlarına ekle
                    GUIDRegistry.guidToAsset[guid] = assetPath
                    GUIDRegistry.pathToGuid[assetPath] = guid
                    
                    -- Önbelleğe ekle
                    GUIDRegistry.metaCache[assetPath] = {
                        guid = guid,
                        assetPath = assetPath,
                        lastModified = tonumber(content:match('"lastModified":(%d+)')) or os.time()
                    }
                end
            end
        end
    end
    
    Console:log("Loaded " .. table.nkeys(GUIDRegistry.guidToAsset) .. " asset GUIDs")
end

-- Tablo eleman sayısını alan yardımcı fonksiyon
function table.nkeys(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

function AssetManager:getFileType(filename)
    local extension = filename:match("%.(%w+)$")
    if not extension then return "unknown" end
    
    extension = extension:lower()
    
    for type, extensions in pairs(self.supportedTypes) do
        for _, ext in ipairs(extensions) do
            if extension == ext then
                return type
            end
        end
    end
    
    return "unknown"
end

function AssetManager:scanDirectory(path)
    local items = love.filesystem.getDirectoryItems(path)
    local directories = {}
    local files = {}
    
    -- Önce klasörleri ve dosyaları ayır
    for _, item in ipairs(items) do
        local fullPath = path .. "/" .. item
        local info = love.filesystem.getInfo(fullPath)
        
        if info and info.type == "directory" then
            table.insert(directories, {name = item, path = fullPath, type = "directory"})
        elseif info then
            local fileType = self:getFileType(item)
            if fileType ~= "unknown" then
                -- Her dosya için GUID oluştur veya mevcut olanı al
                local metaData = self:loadMetaFile(fullPath)
                
                table.insert(files, {
                    name = item, 
                    path = fullPath, 
                    type = fileType,
                    guid = metaData.guid
                })
            end
        end
    end
    
    -- Klasörleri ve dosyaları birleştir (klasörler önce)
    local result = {}
    for _, dir in ipairs(directories) do
        table.insert(result, dir)
    end
    for _, file in ipairs(files) do
        table.insert(result, file)
    end
    
    return result
end

function AssetManager:loadAsset(assetType, path)
    -- GUID al veya oluştur
    local metaData = self:loadMetaFile(path)
    local guid = metaData.guid
    
    -- Daha önce yüklenmiş mi kontrol et (GUID tabanlı)
    for _, asset in ipairs(State.assets) do
        if asset.guid == guid then
            return asset
        end
    end
    
    -- Daha önce yüklenmiş mi kontrol et (yol tabanlı - eski yöntem)
    for _, asset in ipairs(State.assets) do
        if asset.path == path then
            -- Varolan asset'e GUID ekle
            asset.guid = guid
            GUIDRegistry.guidToAsset[guid] = path
            GUIDRegistry.pathToGuid[path] = guid
            return asset
        end
    end
    
    local asset = {
        type = assetType,
        path = path,
        name = path:match("([^/\\]+)$"),
        guid = guid,
        data = nil
    }
    
    if assetType == "image" then
        asset.data = love.graphics.newImage(path)
    elseif assetType == "sound" then
        asset.data = love.audio.newSource(path, "static")
    elseif assetType == "font" then
        asset.data = love.graphics.newFont(path, 12)
    elseif assetType == "script" then
        asset.data = love.filesystem.read(path)
    elseif assetType == "shader" then
        -- Read shader source
        local source = love.filesystem.read(path)
        if source then
            -- First try to load it as a complete shader
            local success, shader = pcall(function() 
                return love.graphics.newShader(source) 
            end)
            
            if success then
                asset.data = shader
                asset.source = source
            else
                Console:log("Error loading shader: " .. path .. ". " .. tostring(shader), "error")
                asset.data = nil
                asset.source = source
            end
        end
    end
    
    -- GUID kayıtlarını güncelle
    GUIDRegistry.guidToAsset[guid] = path
    GUIDRegistry.pathToGuid[path] = guid
    
    table.insert(State.assets, asset)
    Console:log("Loaded asset: " .. asset.name .. " (GUID: " .. asset.guid .. ")")
    return asset
end

-- GUID ile asset bulma
function AssetManager:getAssetByGUID(guid)
    if not guid or not GUID.isValid(guid) then
        return nil
    end
    
    -- GUID'e ait path kontrolü
    local path = GUIDRegistry.guidToAsset[guid]
    if not path then
        return nil
    end
    
    -- Zaten yüklenmiş mi kontrol et
    for _, asset in ipairs(State.assets) do
        if asset.guid == guid then
            return asset
        end
    end
    
    -- Yüklenmemişse, dosya tipini belirle ve yükle
    local fileType = self:getFileType(path)
    if fileType ~= "unknown" then
        return self:loadAsset(fileType, path)
    end
    
    return nil
end

-- Asset silme (GUID kaydını da sil)
function AssetManager:deleteAsset(path)
    -- Asset'i State.assets'ten sil
    for i, asset in ipairs(State.assets) do
        if asset.path == path then
            local guid = asset.guid
            
            -- GUID kayıtlarını temizle
            if guid then
                GUIDRegistry.guidToAsset[guid] = nil
                GUIDRegistry.pathToGuid[path] = nil
                GUIDRegistry.metaCache[path] = nil
                
                -- Meta dosyasını sil
                local metaPath = getMetaFilePath(path)
                if love.filesystem.getInfo(metaPath) then
                    love.filesystem.remove(metaPath)
                end
            end
            
            -- Asset'i listeden sil
            table.remove(State.assets, i)
            
            -- Seçili asset kontrol et
            if State.selectedAsset == asset then
                State.selectedAsset = nil
            end
            
            Console:log("Deleted asset: " .. asset.name .. (guid and " (GUID: " .. guid .. ")" or ""))
            return true
        end
    end
    
    return false
end

function AssetManager:draw()
    if not State.showWindows.assetManager then return end
    
    imgui.SetNextWindowSize(State.windowSizes.assetManager.width, State.windowSizes.assetManager.height, imgui.Cond_FirstUseEver)
    if imgui.Begin("Asset Manager", State.showWindows.assetManager) then
        -- Üst toolbar
        if imgui.Button("Import Asset") then
            -- Gerçek bir uygulamada dosya seçici kullanılır
            -- Bu örnek için simüle ediyoruz
            Console:log("Import Asset clicked - would open file picker")
        end
        
        imgui.SameLine()
        if imgui.Button("Create Folder") then
            local newFileName = ""
            newFileName = imgui.InputText("##NewFileName", newFileName, 128)
            local newFolderPath = self.currentPath .. "/" .. newFileName
            love.filesystem.createDirectory(newFolderPath)
            Console:log("Created new folder: " .. newFolderPath)
        end
        
        imgui.SameLine()
        if imgui.Button("Refresh") then
            self:scanDirectory(self.currentPath) -- Dosyaları yeniden tara
            Console:log("Refreshed asset directory")
        end
        
        -- Mevcut klasör yolu
        imgui.Text("Current Path: " .. self.currentPath)
        
        -- Üst klasöre gitme butonu
        if self.currentPath ~= "assets" then
            if imgui.Button("..") then
                self.currentPath = self.currentPath:match("(.+)/[^/]+$") or "assets"
                Console:log("Navigated to: " .. self.currentPath)
            end
        end
        
        imgui.Separator()
        
        -- Filtre
        imgui.Text("Filter:")
        imgui.SameLine()
        self.filter = imgui.InputText("##AssetFilter", self.filter, 128)
        
        -- Dosya ve klasör listesi
        if imgui.BeginChild("AssetList", 0, 0, true) then
            local items = self:scanDirectory(self.currentPath)
            
            for _, item in ipairs(items) do
                local isVisible = self.filter == "" or item.name:lower():find(self.filter:lower(), 1, true)
                
                if isVisible then
                    -- Dosya tipine göre renk
                    if item.type == "directory" then
                        imgui.PushStyleColor(imgui.Col_Text, 1, 1, 0, 1)
                    elseif item.type == "image" then
                        imgui.PushStyleColor(imgui.Col_Text, 0.5, 1, 0.5, 1)
                    elseif item.type == "sound" then
                        imgui.PushStyleColor(imgui.Col_Text, 0.5, 0.5, 1, 1)
                    elseif item.type == "font" then
                        imgui.PushStyleColor(imgui.Col_Text, 1, 0.5, 0.5, 1)
                    elseif item.type == "shader" then
                        imgui.PushStyleColor(imgui.Col_Text, 1, 0.2, 0.4, 1)
                    else
                        imgui.PushStyleColor(imgui.Col_Text, 1, 1, 1, 1)
                    end
                    
                    -- Klasör veya dosya tıklama
                    if imgui.Selectable(item.name, State.selectedAsset and State.selectedAsset.path == item.path) then
                        if item.type == "directory" then
                            self.currentPath = item.path
                            Console:log("Navigated to: " .. item.path)
                        else
                            -- Dosyayı yükle ve seç
                            local asset = self:loadAsset(item.type, item.path)
                            State.selectedAsset = asset
                            State.selectedAssetType = asset.type
                            State.selectedAssetName = asset.name
                            Console:log("Selected asset: " .. asset.name)
                            
                            -- GUID'i logla
                            if asset.guid then
                                Console:log("Asset GUID: " .. asset.guid)
                            end
                            
                            if asset.type == "shader" then 
                                State.selectedShaderAsset = asset 
                                State.selectedShaderData = asset.data 
                            end
                        end
                    end
                    
                    -- GUID tooltip'i (mouse imleciyle üzerine gelindiğinde)
                    -- ÖNEMLİ: Selectable'dan sonra kontrol edilmeli
                    if item.type ~= "directory" and imgui.IsItemHovered() then
                        -- Eğer item.guid yoksa meta dosyasını kontrol et
                        local guid = item.guid
                        if not guid then
                            -- Meta dosyasını yükle
                            local metaData = self:loadMetaFile(item.path)
                            guid = metaData and metaData.guid
                        end
                        
                        if guid then
                            imgui.BeginTooltip()
                            imgui.Text("GUID: " .. guid)
                            imgui.EndTooltip()
                        end
                    end
                    
                    -- Sağ tık menüsü
                    if imgui.BeginPopupContextItem() then
                        if item.type ~= "directory" and imgui.MenuItem("Copy GUID") then
                            -- GUID'i meta dosyasından al
                            local metaData = self:loadMetaFile(item.path)
                            if metaData and metaData.guid then
                                -- Gerçek uygulamada panoya kopyala
                                Console:log("Copied GUID: " .. metaData.guid)
                            else
                                Console:log("No GUID found for this asset", "warning")
                            end
                        end
                        
                        if imgui.MenuItem("Delete") then
                            if item.type == "directory" then
                                -- Klasör silme işlemi
                                love.filesystem.remove(item.path)
                                Console:log("Deleted directory: " .. item.name)
                            else
                                -- Dosya silme işlemi
                                love.filesystem.remove(item.path)
                                Console:log("Deleted file: " .. item.name)
                                
                                -- Yüklü asset'i de sil
                                for i, asset in ipairs(State.assets) do
                                    if asset.path == item.path then
                                        -- Meta dosyasını da sil
                                        local metaPath = getMetaFilePath(item.path)
                                        if love.filesystem.getInfo(metaPath) then
                                            love.filesystem.remove(metaPath)
                                            Console:log("Deleted meta file: " .. metaPath)
                                        end
                                        
                                        table.remove(State.assets, i)
                                        if State.selectedAsset == asset then
                                            State.selectedAsset = nil
                                        end
                                        break
                                    end
                                end
                            end
                        end
                        
                        if imgui.MenuItem("Rename") then
                            Console:log("Rename option clicked for: " .. item.name)
                        end
                        
                        if item.type == "image" and imgui.MenuItem("Create Animation") then
                            -- Önce asset'i yükle
                            local asset = self:loadAsset(item.type, item.path)
                            
                            -- Seçili entity'yi kontrol et
                            if State.selectedEntity and State.selectedEntity.components.animator then
                                engine.animator:GridSystem(asset, State.selectedEntity)
                            else
                                Console:log("Please select an entity with Animator component!")
                            end
                        end
                        
                        -- Tilemap için sağ tık menüsü seçeneği
                        if item.type == "image" and imgui.MenuItem("Tilemap Olarak Kullan") then
                            local asset = self:loadAsset(item.type, item.path)
                            if asset and asset.data then
                                local Tilemap = require "modules.tilemap"
                                Tilemap:selectImage(asset.data)
                                Console:log("Görüntü tilemap olarak ayarlandı: " .. asset.name)
                            end
                        end
                        
                        -- Özel menü ekleme
                        if item.type ~= "directory" and imgui.MenuItem("Show Asset Info") then
                            -- Asset'in detaylı bilgilerini göster
                            local asset = nil
                            
                            -- Zaten yüklenmiş mi kontrol et
                            for _, a in ipairs(State.assets) do
                                if a.path == item.path then
                                    asset = a
                                    break
                                end
                            end
                            
                            -- Yüklenmemişse yükle
                            if not asset then
                                asset = self:loadAsset(item.type, item.path)
                            end
                            
                            local metaData = self:loadMetaFile(item.path)
                            local guid = metaData and metaData.guid or "Unknown"
                            
                            -- Bilgileri logla
                            Console:log("Asset Info:")
                            Console:log("- Name: " .. asset.name)
                            Console:log("- Path: " .. asset.path)
                            Console:log("- Type: " .. asset.type)
                            Console:log("- GUID: " .. guid)
                            
                            if asset.type == "image" and asset.data then
                                local w, h = asset.data:getDimensions()
                                Console:log("- Dimensions: " .. w .. "x" .. h)
                            end
                        end
                        
                        imgui.EndPopup()
                    end
                    
                    -- Sadece image asset'ler için Drag & Drop desteği
                    if item.type == "image" then
                        local asset = self:loadAsset(item.type, item.path)
                        
                        -- Drag başlangıcı
                        if imgui.IsItemHovered() and love.mouse.isDown(1) then
                            State.draggedAsset = asset
                            State.dragStarted = true
                        end
                        
                        -- Drag sırasında text gösterimi
                        if State.draggedAsset == asset and State.dragStarted then
                            local mouseX, mouseY = love.mouse.getPosition()
                            love.graphics.setColor(1, 1, 1, 0.7)
                            love.graphics.rectangle("fill", mouseX + 10, mouseY + 10, 200, 30)
                            love.graphics.setColor(0, 0, 0, 1)
                            love.graphics.print("Dragging: " .. asset.name, mouseX + 15, mouseY + 15)
                            love.graphics.setColor(1, 1, 1, 1)
                        end
                    end
                    
                    imgui.PopStyleColor()
                end
            end
            
            imgui.EndChild()
        end
    end
    imgui.End()
end

-- Görüntü alma yardımcı fonksiyonu
function AssetManager:getImage(path)
    for _, asset in ipairs(State.assets) do
        if asset.path == path and asset.type == "image" then
            return asset.data
        end
    end
    return nil
end

-- GUID ile görüntü alma
function AssetManager:getImageByGUID(guid)
    local asset = self:getAssetByGUID(guid)
    if asset and asset.type == "image" then
        return asset.data
    end
    return nil
end

return AssetManager