local State = require "state"
local Console = require "modules.console"
local SceneManager = require "modules.scene_manager"

local Hierarchy = {
showWindow = true,
selectedEntity = nil,
draggedEntity = nil,
dragSource = nil,
dragTarget = nil,
isDragging = false,
dragStartX = 0,
dragStartY = 0,
dragThreshold = 5, -- Minimum drag distance to start dragging
dropIndicatorPosition = nil,
-- Debug information
debug = {
enabled = false,
messages = {},
maxMessages = 20,
lastUpdate = 0
}
}

-- ImGui flag'lerini tanımla
local TreeNodeFlags = {
Selected = 1,
OpenOnArrow = 32,
SpanAvailWidth = 2048,
DefaultOpen = 64
}

function Hierarchy:init()
State.showWindows.hierarchy = true
State.windowSizes.hierarchy = {width = 250, height = 400}
State.showWindows.hierarchyDebug = self.debug.enabled
self:addDebugMessage("Hierarchy initialized")
end

function Hierarchy:addDebugMessage(message)
if not self.debug.enabled then return end

-- Add timestamp
local timestamp = love.timer.getTime()
local formattedMessage = string.format("[%.2f] %s", timestamp, message)

-- Add to messages table
table.insert(self.debug.messages, formattedMessage)

-- Keep only the last N messages
while #self.debug.messages > self.debug.maxMessages do
table.remove(self.debug.messages, 1)
end

-- Also log to console for convenience
Console:log("HIERARCHY: " .. message, "info")
end

function Hierarchy:startDrag(entity, x, y)
self.draggedEntity = entity
self.dragSource = entity
self.isDragging = true
self.dragStartX = x
self.dragStartY = y

-- Set initial target as self to avoid "no target" errors
self.dragTarget = entity
self.dropIndicatorPosition = self:getEntityIndex(entity) or 1

local debug_info = string.format("Started dragging entity: %s (ID: %d) at x=%d, y=%d", 
(entity.name or "unnamed"), 
entity.id or 0,
math.floor(x), 
math.floor(y))
self:addDebugMessage(debug_info)

-- Log initial indices
self:addDebugMessage(string.format("Initial position: index %d of %d entities", 
self:getEntityIndex(entity) or -1, 
#SceneManager.entities
))
end

function Hierarchy:endDrag()
if not self.isDragging then
self:addDebugMessage("Warning: endDrag() called but not dragging")
return
end

if not self.draggedEntity then
self:addDebugMessage("ERROR: No dragged entity when ending drag")
self.isDragging = false
return
end

if not self.dragTarget then
self:addDebugMessage("ERROR: No drag target when ending drag")
self.isDragging = false
return
end

if self.draggedEntity ~= self.dragTarget then 
local sourceEntityInfo = string.format("%s (ID: %d)", 
    (self.draggedEntity.name or "unnamed"), 
    self.draggedEntity.id or 0)
    
local targetEntityInfo = string.format("%s (ID: %d)", 
    (self.dragTarget.name or "unnamed"), 
    self.dragTarget.id or 0)
    
self:addDebugMessage("ATTEMPT MOVE: " .. sourceEntityInfo .. " -> after " .. targetEntityInfo)

-- Get original positions
local originalSourceIndex = self:getEntityIndex(self.draggedEntity)
local originalTargetIndex = self:getEntityIndex(self.dragTarget)

self:addDebugMessage(string.format("Before move: Source at index %d, Target at index %d", 
    originalSourceIndex or -1, originalTargetIndex or -1))
    
-- Perform the reordering
self:moveEntity(self.draggedEntity, self.dragTarget)

-- Get new positions
local newSourceIndex = self:getEntityIndex(self.draggedEntity)
self:addDebugMessage(string.format("After move: Source now at index %d", newSourceIndex or -1))

self:addDebugMessage("MOVED: " .. sourceEntityInfo .. " -> after " .. targetEntityInfo)
else
self:addDebugMessage("No move needed: Source and target are the same entity")
end

self.isDragging = false
self.draggedEntity = nil
self.dragTarget = nil
self.dropIndicatorPosition = nil
self:addDebugMessage("Drag operation ended")
end

function Hierarchy:getEntityIndex(entity)
for i, e in ipairs(SceneManager.entities) do
if e == entity then
    return i
end
end
return nil
end

function Hierarchy:moveEntity(sourceEntity, targetEntity)
-- Find source and target indexes
local sourceIndex = nil
local targetIndex = nil

for i, entity in ipairs(SceneManager.entities) do
if entity == sourceEntity then
    sourceIndex = i
end
if entity == targetEntity then
    targetIndex = i
end
end

if sourceIndex and targetIndex then
self:addDebugMessage(string.format("MOVE OPERATION: source idx=%d, target idx=%d", sourceIndex, targetIndex))

-- Log entity state before move
local entityCount = #SceneManager.entities
if entityCount < 10 then -- Only log if not too many entities
    local entityNames = {}
    for i, entity in ipairs(SceneManager.entities) do
        table.insert(entityNames, (i == sourceIndex and ">" or "") .. i .. ":" .. (entity.name or "unnamed"))
    end
    self:addDebugMessage("Entities BEFORE: " .. table.concat(entityNames, ", "))
end

-- Remove source entity
local removedEntity = table.remove(SceneManager.entities, sourceIndex)
self:addDebugMessage("Removed entity at index " .. sourceIndex)

-- Adjust target index if necessary (if source was before target)
if sourceIndex < targetIndex then
    targetIndex = targetIndex - 1
    self:addDebugMessage("Adjusted target index to " .. targetIndex .. " because source was before target")
end

-- Insert source entity after target
table.insert(SceneManager.entities, targetIndex + 1, sourceEntity)
self:addDebugMessage("Inserted entity at index " .. (targetIndex + 1))

-- Log entity state after move
if entityCount < 10 then -- Only log if not too many entities
    local entityNames = {}
    for i, entity in ipairs(SceneManager.entities) do
        table.insert(entityNames, (i == (targetIndex + 1) and ">" or "") .. i .. ":" .. (entity.name or "unnamed"))
    end
    self:addDebugMessage("Entities AFTER: " .. table.concat(entityNames, ", "))
end
else
self:addDebugMessage("ERROR: Could not find source or target index")
end
end

function Hierarchy:updateDrag(x, y)
if not self.isDragging then return end

-- Update debug info no more than 5 times per second
local currentTime = love.timer.getTime()
local shouldUpdateDebug = (currentTime - self.debug.lastUpdate) > 0.2

-- Check if mouse has moved beyond threshold
local dx = x - self.dragStartX
local dy = y - self.dragStartY
local distance = math.sqrt(dx*dx + dy*dy)

if distance < self.dragThreshold then 
if shouldUpdateDebug then
    self:addDebugMessage(string.format("Waiting for threshold: current distance = %.1f, required = %d", 
        distance, self.dragThreshold))
    self.debug.lastUpdate = currentTime
end
return 
end

-- Find entity under cursor for potential drop target
local windowX, windowY = 0, 0
if imgui.GetWindowPos then
windowX, windowY = imgui.GetWindowPos()
end

local cursorY = y - windowY

-- Debug all values regardless of update frequency
self:addDebugMessage(string.format(
"Mouse position: x=%d, y=%d, windowPos: x=%d, y=%d", 
math.floor(x), math.floor(y), 
math.floor(windowX), math.floor(windowY)
))

-- Calculate approximate entity position in the list
local itemHeight = 20 -- Default item height
if imgui.GetTextLineHeightWithSpacing then
itemHeight = imgui.GetTextLineHeightWithSpacing()
end

local headerHeight = 40 -- Default header height
if imgui.GetFrameHeight then
headerHeight = imgui.GetFrameHeight() * 2
end

local scrollY = 0 -- Default scroll position
if imgui.GetScrollY then
scrollY = imgui.GetScrollY()
end

-- Calculate index with additional safety checks
local index = 1
if cursorY > 0 and itemHeight > 0 then
index = math.floor((cursorY + scrollY - headerHeight) / itemHeight) + 1
end

self:addDebugMessage(string.format(
"Index calculation: cursorY=%.1f, scrollY=%.1f, headerH=%.1f, itemH=%.1f, result=%d", 
cursorY, scrollY, headerHeight, itemHeight, index
))

-- IMPORTANT: Directly access entity count
local entityCount = #SceneManager.entities
self:addDebugMessage("Entity count: " .. entityCount)

-- Get all entity names for debugging
local entityNames = {}
for i, entity in ipairs(SceneManager.entities) do
table.insert(entityNames, i .. ":" .. (entity.name or "Entity " .. i))
end
self:addDebugMessage("Entities: " .. table.concat(entityNames, ", "))

-- Fallback to simple index if calculation isn't working well
if index < 1 or index > entityCount then
-- Alternative approach: divide window height by entity count
local windowHeight = love.graphics.getHeight()
if imgui.GetWindowHeight then
    windowHeight = imgui.GetWindowHeight() 
end

-- Calculate relative position in window
local relativePos = (y - windowY) / windowHeight
index = math.floor(relativePos * entityCount) + 1

self:addDebugMessage(string.format(
    "Fallback calculation: windowH=%.1f, relativePos=%.2f, new index=%d",
    windowHeight, relativePos, index
))
end

-- Ensure index is valid (with multiple safety checks)
index = math.max(1, math.min(entityCount, index))

-- Extra check to ensure entities actually exist
if entityCount > 0 then
self.dragTarget = SceneManager.entities[index]
self.dropIndicatorPosition = index

self:addDebugMessage(string.format("Target set to: %s at position %d", 
    (self.dragTarget and self.dragTarget.name) or "unknown", 
    self.dropIndicatorPosition or 0))
else
self:addDebugMessage("ERROR: No entities found to use as target")
end

self.debug.lastUpdate = currentTime
end

function Hierarchy:drawDebugWindow()
if not State.showWindows.hierarchyDebug then return end

imgui.SetNextWindowSize(400, 300, imgui.Cond_FirstUseEver)
if imgui.Begin("Hierarchy Debug", State.showWindows.hierarchyDebug) then
-- Show drag state
if self.isDragging then
    imgui.Text("DRAGGING: " .. (self.draggedEntity and (self.draggedEntity.name or "unnamed") or "none"))
    imgui.Text("TARGET: " .. (self.dragTarget and (self.dragTarget.name or "unnamed") or "none"))
    imgui.Text(string.format("Mouse: (%d, %d), Start: (%d, %d)", 
        math.floor(love.mouse.getX()), math.floor(love.mouse.getY()),
        math.floor(self.dragStartX), math.floor(self.dragStartY)))
        
    local dx = love.mouse.getX() - self.dragStartX
    local dy = love.mouse.getY() - self.dragStartY
    local distance = math.sqrt(dx*dx + dy*dy)
    imgui.Text(string.format("Distance: %.1f (threshold: %d)", distance, self.dragThreshold))
else
    imgui.Text("NOT DRAGGING")
end

if imgui.Button("Clear Log") then
    self.debug.messages = {}
end

imgui.Separator()

-- Show debug log
if imgui.BeginChild("DebugLog", 0, 0, true) then
    for i = #self.debug.messages, 1, -1 do -- Show newest first
        imgui.Text(self.debug.messages[i])
    end
    imgui.EndChild()
end

imgui.End()
end
end

function Hierarchy:draw()
-- Draw debug window first
self:drawDebugWindow()

if not State.showWindows.hierarchy then return end

imgui.SetNextWindowSize(State.windowSizes.hierarchy.width, State.windowSizes.hierarchy.height, imgui.Cond_FirstUseEver)
if imgui.Begin("Hierarchy", State.showWindows.hierarchy) then
-- Get mouse position for drag and drop
local mouseX, mouseY = love.mouse.getPosition()

-- Update drag status if already dragging
if self.isDragging then
    self:updateDrag(mouseX, mouseY)
    
    -- End drag if mouse button released
    if not love.mouse.isDown(1) then
        self:endDrag()
    end
end

-- Yeni entity oluşturma butonu
if imgui.Button("Create Entity") then
    SceneManager:createEntity(0, 0)
end

-- imgui.SameLine()
-- if imgui.Button("Debug") then
--     State.showWindows.hierarchyDebug = not State.showWindows.hierarchyDebug
--     self:addDebugMessage("Debug window " .. (State.showWindows.hierarchyDebug and "opened" or "closed"))
-- end

imgui.Separator()

-- Update drag status
if self.isDragging then
    self:updateDrag(mouseX, mouseY)
    
    -- End drag if mouse button released
    if not love.mouse.isDown(1) then
        self:endDrag()
    end
end

-- Draw drop indicator if we're dragging
if self.isDragging and self.dropIndicatorPosition then
    local startY = 0
    local startX = 0
    local width = 0
    
    -- Get cursor position safely
    if imgui.GetCursorScreenPos then
        local cursorX, cursorY = imgui.GetCursorScreenPos()
        startY = cursorY or 0
    else
        startY = love.mouse.getY() -- Fallback
    end
    
    -- Get window position safely
    if imgui.GetWindowPos then
        local windowX, windowY = imgui.GetWindowPos()
        startX = windowX or 0
    end
    
    -- Get window width safely
    width = imgui.GetWindowWidth() or 200 -- Default width if function not available
    
    -- Calculate position based on item index
    local itemHeight = imgui.GetTextLineHeightWithSpacing() or 20 -- Default to 20 if not available
    local indicatorY = startY + (self.dropIndicatorPosition - 1) * itemHeight
    
    -- Draw the indicator line
    -- Draw a simple line instead of using DrawList which might not be available
    love.graphics.push("all")
    love.graphics.setColor(1, 0.5, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(
        startX + 5, indicatorY,
        startX + width - 5, indicatorY
    )
    
    -- Add drop position text for better visibility
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(
        "DROP HERE - Position: " .. self.dropIndicatorPosition,
        startX + 20, indicatorY - 15
    )
    
    love.graphics.pop()
end

-- Entityleri listele
for i, entity in ipairs(SceneManager.entities) do
    local flags = TreeNodeFlags.OpenOnArrow
    
    -- Seçili entity'yi vurgula
    if State.selectedEntity == entity then
        flags = flags + TreeNodeFlags.Selected
    end
    
    -- Dragged entity'yi vurgula
    if self.isDragging and self.draggedEntity == entity then
        imgui.PushStyleColor(imgui.Col_Text, 0.5, 0.5, 1.0, 0.5) -- Semi-transparent blue
    end
    
    -- Entity'nin alt öğeleri varsa TreeNode, yoksa Selectable olarak göster
    local isOpen = false
    if #(entity.children or {}) > 0 then
        isOpen = imgui.TreeNodeEx(entity.name or "Entity " .. i, flags)
    else
        local selected = imgui.Selectable(entity.name or "Entity " .. i, State.selectedEntity == entity)
        if selected and not self.isDragging then
            State.selectedEntity = entity
        end
    end
    
    -- Restore color if this was the dragged entity
    if self.isDragging and self.draggedEntity == entity then
        imgui.PopStyleColor()
    end
    
    -- Handle mouse interactions for drag & drop
    if not self.isDragging and love.mouse.isDown(1) then
        -- Using isItemHovered safely
        local isHovered = false
        if imgui.IsItemHovered then 
            isHovered = imgui.IsItemHovered()
        else
            -- Fallback to assume hover from current selection
            isHovered = (State.selectedEntity == entity)
        end
        
        if isHovered then
            self:startDrag(entity, mouseX, mouseY)
        end
    end
    
    -- Debug click check
    if self.debug.enabled and love.mouse.isDown(1) then
        local isHovered = false
        if imgui.IsItemHovered then 
            isHovered = imgui.IsItemHovered()
        end
        
        if isHovered then
            self:addDebugMessage("LEFT CLICK on entity: " .. (entity.name or "unnamed"))
        end
    end
    
    -- Sağ tık menüsü
    if imgui.BeginPopupContextItem() then
        if imgui.MenuItem("Delete") then
            SceneManager:deleteEntity(entity)
        end
        if imgui.MenuItem("Rename") then
            -- TODO: Yeniden adlandırma işlevi eklenecek
        end
        if imgui.MenuItem("Duplicate") then
            local newEntity = SceneManager:createEntity(entity.x + 32, entity.y + 32)
            for k, v in pairs(entity) do
                if k ~= "name" then
                    newEntity[k] = v
                end
            end
            newEntity.name = entity.name .. " (Copy)"
        end
        imgui.EndPopup()
    end
    
    if isOpen then
        if entity.children then
            for _, child in ipairs(entity.children) do
                imgui.Indent()
                -- Recursive olarak alt öğeleri göster
                -- TODO: Alt öğeleri gösterme fonksiyonu eklenecek
                imgui.Unindent()
            end
        end
        imgui.TreePop()
    end
end
end
imgui.End()
end

return Hierarchy