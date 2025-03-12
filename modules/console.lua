local State = require "state"
local imgui = require "imgui"

local Console = {}

local showErrorWindow = true
local canUwuPlay = false 


function Console:init()
    self.commandHistory = {}
    self.historyIndex = 0
    self.commandBuffer = ""
end

function Console:log(message, level)
    level = level or "info"
    
    local logEntry = {
        message = message,
        level = level,
        timestamp = os.date("%H:%M:%S")
    }
    
    table.insert(State.consoleLog, logEntry)
    
    -- Keep log from getting too large
    if #State.consoleLog > 100 then
        table.remove(State.consoleLog, 1)
    end
end

function Console:executeCommand(command)
    self:log("> " .. command, "command")
    
    -- Add command to history
    table.insert(self.commandHistory, command)
    if #self.commandHistory > 30 then
        table.remove(self.commandHistory, 1)
    end
    
    -- Reset history navigation
    self.historyIndex = 0
    
    -- Simple command processing
    if command == "clear" then
        State.consoleLog = {}
        return
    elseif command == "help" then
        self:log("Available commands: clear, help, list assets, quit", "info")
        return
    elseif command == "list assets" then
        if #State.assets == 0 then
            self:log("No assets loaded.", "info")
        else
            self:log("Loaded assets:", "info")
            for _, asset in ipairs(State.assets) do
                self:log("- " .. asset.name .. " (" .. asset.type .. ")", "info")
            end
        end
        return
    elseif command == "uwu" then
        UwU()
        return
    elseif command == "quit" then
        love.event.quit()
        return
    end
    
    self:log("Unknown command: " .. command, "error")
end

function Console:update()
   
end
function UwU()
    --if canUwuPlay then
        local source = love.audio.newSource("assets/sounds/uwu.mp3", "stream")
        source:play()
        love.timer.sleep(1)
        canUwuPlay = false
    --end
end
function Console:draw()
    if not State.showWindows.console then return end

   
    
    imgui.SetNextWindowSize(State.windowSizes.console.width, State.windowSizes.console.height, imgui.Cond_FirstUseEver)
    if imgui.Begin("Console", State.showWindows.console) then
        -- Command output area
        if imgui.BeginChild("ConsoleScrollRegion", 0, -imgui.GetFrameHeightWithSpacing(), true) then
            for _, entry in ipairs(State.consoleLog) do
                local color = {1, 1, 1, 1}  -- Default white for info
                
                if entry.level == "error" then
                    color = {1, 0.4, 0.4, 1}  -- Red for errors
                elseif entry.level == "warning" then
                    color = {1, 1, 0.4, 1}    -- Yellow for warnings
                elseif entry.level == "command" then
                    color = {0.4, 0.8, 1, 1}  -- Blue for commands
                end
                
                imgui.PushStyleColor(imgui.Col_Text, color[1], color[2], color[3], color[4])
                imgui.TextWrapped(entry.timestamp .. " " .. entry.message)
                imgui.PopStyleColor()
            end
            
            -- Auto-scroll to bottom
           
        end
        imgui.EndChild()
        
        -- Command input
        local entered = false
        imgui.PushItemWidth(-1)
        self.commandBuffer, entered = imgui.InputText("##ConsoleInput", self.commandBuffer, 256, imgui.InputTextFlags_EnterReturnsTrue)
        imgui.PopItemWidth()
        
        -- Set focus on the input box if this window is newly focused
      
        
        -- Execute command on Enter
        if entered and self.commandBuffer ~= "" then
            self:executeCommand(self.commandBuffer)
            self.commandBuffer = ""
        end
    end
    imgui.End()
end

function Console:error(message)
    if showErrorWindow then
        --imgui.SetNextWindowSize(State.windowSizes.error.width, State.windowSizes.error.height, imgui.Cond_FirstUseEver)
        if imgui.Begin("ERROR") then
            
            love.graphics.setColor(1, 0.4, 0.4, 1)
            imgui.Text("ERROR : " .. message)
            love.graphics.setColor(1, 0, 1, 1)
            if imgui.Button("OK") then
                showErrorWindow = false
            end
        end
        imgui.End()
    end
end

return Console
