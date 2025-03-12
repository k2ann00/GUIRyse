local State = require "state"
local Console = require "modules.console"

local Camera = {}

function Camera:init()
    self.x = 0
    self.y = 0
    self.scaleX = 1
    self.scaleY = 1
    self.rotation = 0  -- Derece cinsinden
    self.target = nil
    self.speed = 5
    self.zoomSpeed = 0.1
    self.rotationSpeed = 1  -- Derece cinsinden
    self.bounds = {
        min = {x = -1000, y = -1000},
        max = {x = 1000, y = 1000}
    }
end

function Camera:set()
    love.graphics.push()
    love.graphics.translate(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)
    love.graphics.scale(self.scaleX, self.scaleY)
    love.graphics.rotate(math.rad(self.rotation))  -- Dereceyi radyana çevir
    love.graphics.translate(-self.x, -self.y)
end

function Camera:unset()
    love.graphics.pop()
end

function Camera:move(dx, dy)
    self.x = self.x + dx
    self.y = self.y + dy
    
    -- Apply bounds
    self.x = math.max(self.bounds.min.x, math.min(self.bounds.max.x, self.x))
    self.y = math.max(self.bounds.min.y, math.min(self.bounds.max.y, self.y))
end

function Camera:zoom(factor)
    if type(factor) == "number" then
        -- Tek bir faktör verilmişse her iki eksene de uygula
        local newScaleX = math.max(-10, math.min(10, self.scaleX * factor))
        local newScaleY = math.max(-10, math.min(10, self.scaleY * factor))
        
        -- 0'a yaklaşırken zıt işaretli minimum değere atla
        if math.abs(newScaleX) < 0.1 then
            newScaleX = self.scaleX > 0 and -0.1 or 0.1
        end
        if math.abs(newScaleY) < 0.1 then
            newScaleY = self.scaleY > 0 and -0.1 or 0.1
        end
        
        self.scaleX = newScaleX
        self.scaleY = newScaleY
    else
        -- İki ayrı faktör verilmişse ayrı ayrı uygula
        local newScaleX = math.max(-10, math.min(10, self.scaleX * factor.x))
        local newScaleY = math.max(-10, math.min(10, self.scaleY * factor.y))
        
        if math.abs(newScaleX) < 0.1 then
            newScaleX = self.scaleX > 0 and -0.1 or 0.1
        end
        if math.abs(newScaleY) < 0.1 then
            newScaleY = self.scaleY > 0 and -0.1 or 0.1
        end
        
        self.scaleX = newScaleX
        self.scaleY = newScaleY
    end
end

function Camera:rotate(angle)
    self.rotation = self.rotation + angle
    -- 360 derece döngüsünü sağla
    self.rotation = self.rotation % 360
end

function Camera:setTarget(entity)
    self.target = entity
end

function Camera:update(dt)
    if self.target then
        local targetX, targetY = self.target.x, self.target.y
        self.x = self.x + (targetX - self.x) * self.speed * dt
        self.y = self.y + (targetY - self.y) * self.speed * dt
    end
    
    -- Update camera settings in state
    State.cameraSettings.x = self.x
    State.cameraSettings.y = self.y
    State.cameraSettings.scaleX = self.scaleX
    State.cameraSettings.scaleY = self.scaleY
    State.cameraSettings.rotation = self.rotation
end


function Camera:draw()
    if not State.showWindows.properties then return end
    
    if imgui.Begin("Camera Properties", State.showWindows.properties) then
        local changed = false
        
        imgui.Text("Position")
        local x = imgui.DragFloat("X##Camera", self.x, 1, -1000, 1000)
        if x ~= self.x then
            self.x = x
            changed = true
        end
        
        local y = imgui.DragFloat("Y##Camera", self.y, 1, -1000, 1000)
        if y ~= self.y then
            self.y = y
            changed = true
        end
        
        imgui.Separator()
        
        imgui.Text("Scale")
        local scaleX = imgui.DragFloat("X Scale##Camera", self.scaleX, 0.01, -10, 10)
        if scaleX ~= self.scaleX then
            -- 0'a yaklaşırken zıt işaretli minimum değere atla
            if math.abs(scaleX) < 0.1 then
                if self.scaleX > 0 then
                    scaleX = -0.1
                else
                    scaleX = 0.1
                end
            end
            self.scaleX = scaleX
            changed = true
        end
        
        local scaleY = imgui.DragFloat("Y Scale##Camera", self.scaleY, 0.01, -10, 10)
        if scaleY ~= self.scaleY then
            -- 0'a yaklaşırken zıt işaretli minimum değere atla
            if math.abs(scaleY) < 0.1 then
                if self.scaleY > 0 then
                    scaleY = -0.1
                else
                    scaleY = 0.1
                end
            end
            self.scaleY = scaleY
            changed = true
        end
        
        imgui.Separator()
        
        imgui.Text("Rotation (degrees)")
        local rotation = imgui.DragFloat("##CameraRotation", self.rotation, 1, -360, 360)
        if rotation ~= self.rotation then
            self.rotation = rotation % 360
            changed = true
        end
        
        if changed then
            Console:log("Camera settings updated", "info")
        end
        
        imgui.Separator()
        
        if imgui.Button("Reset Camera") then
            self.x = 0
            self.y = 0
            self.scaleX = 1
            self.scaleY = 1
            self.rotation = 0
            Console:log("Camera reset to default values", "info")
        end
    end
    imgui.End()
end

return Camera
