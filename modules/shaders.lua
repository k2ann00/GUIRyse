local State = require "state"
local Console = require "modules.console"

local Shaders = {
    registry = {}, -- Stores all shader definitions with their metadata
    currentShader = nil
}

-- Built-in shader definitions
local BUILT_IN_SHADERS = {
    {
        name = "spotlight",
        displayName = "Spotlight Effect",
        source = [[
            extern vec2 screen;
            extern vec2 playerPos;
            extern float lightRadius;
            extern vec3 lightColor;

            vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
                // Normal texture color
                vec4 pixel = Texel(tex, texture_coords);
                
                // Normalize coordinates
                vec2 normalizedCoords = screen_coords / screen;
                vec2 normalizedPlayerPos = playerPos / screen;
                
                // Calculate distance from player (light) center
                float distance = length(normalizedCoords - normalizedPlayerPos);
                
                // Create soft-edged light effect
                float lightIntensity = smoothstep(lightRadius, 0.0, distance);
                
                // Dark outside of light radius
                vec3 darkColor = vec3(0.1, 0.1, 0.2);  // Dark bluish-green background
                
                // Blend the pixel with light effect
                vec3 finalColor = mix(darkColor, lightColor, lightIntensity);
                
                return vec4(finalColor * pixel.rgb, pixel.a);
            }
        ]],
        uniforms = {
            screen = { type = "vec2", default = {800, 600}, displayName = "Screen Size" },
            playerPos = { type = "vec2", default = {400, 300}, displayName = "Light Position" },
            lightRadius = { type = "float", default = 0.3, min = 0.1, max = 1.0, displayName = "Light Radius" },
            lightColor = { type = "vec3", default = {0.7, 1.0, 0.7}, displayName = "Light Color" }
        }
    },
    {
        name = "grayscale",
        displayName = "Grayscale Filter",
        source = [[
            vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
                vec4 pixel = Texel(tex, texture_coords);
                float gray = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
                return vec4(gray, gray, gray, pixel.a) * color;
            }
        ]],
        uniforms = {}
    },
    {
        name = "pixelate",
        displayName = "Pixelate Effect",
        source = [[
            extern float pixelSize;
            
            vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
                vec2 pixelated = floor(texture_coords / pixelSize) * pixelSize + pixelSize/2.0;
                return Texel(tex, pixelated) * color;
            }
        ]],
        uniforms = {
            pixelSize = { type = "float", default = 0.05, min = 0.01, max = 0.2, displayName = "Pixel Size" }
        }
    },
    {
        name = "outline",
        displayName = "Outline Effect",
        source = [[
            extern vec2 textureSize;
            extern float outlineThickness;
            extern vec3 outlineColor;
            
            vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
                vec4 pixel = Texel(tex, texture_coords);
                
                // Skip if pixel is already opaque
                if (pixel.a >= 0.9) {
                    return pixel * color;
                }
                
                // Check surrounding pixels
                float thickness = outlineThickness / 100.0;
                vec2 offset = thickness / textureSize;
                
                // Check the 4 adjacent pixels
                float alpha = 0.0;
                alpha += step(0.9, Texel(tex, texture_coords + vec2(offset.x, 0)).a);
                alpha += step(0.9, Texel(tex, texture_coords + vec2(-offset.x, 0)).a);
                alpha += step(0.9, Texel(tex, texture_coords + vec2(0, offset.y)).a);
                alpha += step(0.9, Texel(tex, texture_coords + vec2(0, -offset.y)).a);
                
                // If any adjacent pixel is solid, draw outline
                if (alpha > 0.0) {
                    return vec4(outlineColor, 1.0) * color;
                }
                
                return pixel * color;
            }
        ]],
        uniforms = {
            textureSize = { type = "vec2", default = {128, 128}, displayName = "Texture Size" },
            outlineThickness = { type = "float", default = 1.0, min = 0.5, max = 5.0, displayName = "Outline Thickness" },
            outlineColor = { type = "vec3", default = {1.0, 0.0, 0.0}, displayName = "Outline Color" }
        }
    },
    {
        name = "waterReflection",
        displayName = "Water Reflection Effect",
        source = [[
            extern vec2 screen;
            extern float time;
            extern float waveHeight;
            extern float waveFrequency;
            extern float reflectionOpacity;
            extern float waterLevel;
            
            vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
                vec4 pixel = Texel(tex, texture_coords);
                
                // Normalize coordinates
                vec2 normalizedCoords = screen_coords / screen;
                
                // Determine if we're in the water section (below waterLevel)
                bool inWater = normalizedCoords.y > waterLevel;
                
                if (inWater) {
                    // Calculate reflection coordinates (mirror vertically)
                    float distanceFromWaterLevel = normalizedCoords.y - waterLevel;
                    float reflectionY = waterLevel - distanceFromWaterLevel;
                    
                    // Add wave distortion
                    float waveOffset = sin((normalizedCoords.x + time) * waveFrequency) * waveHeight;
                    reflectionY += waveOffset * 0.01;
                    
                    // Keep X the same, only reflect Y
                    vec2 reflectionCoords = vec2(texture_coords.x, reflectionY * screen.y / screen.x);
                    
                    // Sample from the reflection position
                    vec4 reflectionPixel = Texel(tex, reflectionCoords);
                    
                    // Add a blue tint to the water
                    vec3 waterColor = vec3(0.2, 0.5, 0.7);
                    
                    // Blend the original pixel with the reflection and water color
                    return vec4(
                        mix(pixel.rgb, 
                            mix(waterColor, reflectionPixel.rgb, reflectionOpacity), 
                            0.7), 
                        pixel.a
                    ) * color;
                }
                
                // Return the original pixel for areas above water
                return pixel * color;
            }
        ]],
        uniforms = {
            screen = { type = "vec2", default = {800, 600}, displayName = "Screen Size" },
            time = { type = "float", default = 0.0, displayName = "Time" },
            waveHeight = { type = "float", default = 0.05, min = 0.0, max = 0.2, displayName = "Wave Height" },
            waveFrequency = { type = "float", default = 10.0, min = 1.0, max = 30.0, displayName = "Wave Frequency" },
            reflectionOpacity = { type = "float", default = 0.6, min = 0.0, max = 1.0, displayName = "Reflection Opacity" },
            waterLevel = { type = "float", default = 0.6, min = 0.0, max = 1.0, displayName = "Water Level" }
        }
    },
    {
        name = "mirrorReflection",
        displayName = "Mirror Surface Reflection",
        source = [[
            extern vec2 screen;
            extern vec3 mirrorColor;
            extern float mirrorY;
            extern float reflectionOpacity;
            extern float reflectionBlur;
            
            vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
                vec4 pixel = Texel(tex, texture_coords);
                
                // Normalize coordinates
                vec2 normalizedCoords = screen_coords / screen;
                
                // Determine if we're below the mirror line
                bool belowMirror = normalizedCoords.y > mirrorY;
                
                if (belowMirror) {
                    // Calculate reflection coordinates (mirror vertically)
                    float distanceFromMirror = normalizedCoords.y - mirrorY;
                    float reflectionY = mirrorY - distanceFromMirror;
                    
                    // Convert back to texture coordinates
                    vec2 reflectionTexCoord = vec2(texture_coords.x, reflectionY * screen.y / screen.x);
                    
                    // Sample from the reflection position
                    vec4 reflectionPixel = Texel(tex, reflectionTexCoord);
                    
                    // Add simple blur by sampling nearby pixels if blur is enabled
                    if (reflectionBlur > 0.0) {
                        float blurAmount = reflectionBlur / 1000.0;
                        vec4 blurPixel = vec4(0.0);
                        float totalWeight = 0.0;
                        
                        for (float i = -2.0; i <= 2.0; i += 1.0) {
                            float weight = exp(-0.5 * i * i);
                            totalWeight += weight;
                            blurPixel += weight * Texel(tex, reflectionTexCoord + vec2(i * blurAmount, 0.0));
                        }
                        
                        reflectionPixel = blurPixel / totalWeight;
                    }
                    
                    // Calculate fade based on distance from mirror
                    float fade = 1.0 - (distanceFromMirror / 0.2);
                    fade = clamp(fade, 0.0, 1.0);
                    
                    // Blend mirror color with reflection
                    vec3 finalColor = mix(mirrorColor, reflectionPixel.rgb, reflectionOpacity * fade);
                    
                    return vec4(finalColor, pixel.a) * color;
                }
                
                // Return the original pixel for areas above mirror
                return pixel * color;
            }
        ]],
        uniforms = {
            screen = { type = "vec2", default = {800, 600}, displayName = "Screen Size" },
            mirrorColor = { type = "vec3", default = {0.8, 0.8, 0.9}, displayName = "Mirror Color" },
            mirrorY = { type = "float", default = 0.5, min = 0.0, max = 1.0, displayName = "Mirror Y Position" },
            reflectionOpacity = { type = "float", default = 0.7, min = 0.0, max = 1.0, displayName = "Reflection Opacity" },
            reflectionBlur = { type = "float", default = 1.0, min = 0.0, max = 5.0, displayName = "Reflection Blur" }
        }
    },
    {
        name = "dynamicLighting",
        displayName = "Dynamic 2D Lighting",
        source = [[
            extern vec2 screen;
            extern vec2 lightPositions[5];
            extern vec3 lightColors[5];
            extern float lightRadii[5];
            extern float lightCount;
            extern float ambientIntensity;
            extern vec3 ambientColor;
            
            vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
                vec4 pixel = Texel(tex, texture_coords);
                
                if (pixel.a < 0.01)
                    return pixel * color; // Don't process transparent pixels
                
                // Normalize screen coordinates
                vec2 normalizedCoords = screen_coords / screen;
                
                // Start with ambient lighting
                vec3 finalColor = pixel.rgb * ambientColor * ambientIntensity;
                
                // Calculate contribution from each light
                for (int i = 0; i < 5; i++) {
                    if (i >= int(lightCount))
                        break;
                    
                    vec2 normalizedLightPos = lightPositions[i] / screen;
                    float distance = length(normalizedCoords - normalizedLightPos);
                    
                    // Attenuate light based on distance and radius
                    float attenuation = 1.0 - smoothstep(0.0, lightRadii[i], distance);
                    
                    // Add this light's contribution
                    finalColor += pixel.rgb * lightColors[i] * attenuation;
                }
                
                // Clamp final color to prevent overexposure
                finalColor = min(finalColor, vec3(1.0));
                
                return vec4(finalColor, pixel.a) * color;
            }
        ]],
        uniforms = {
            screen = { type = "vec2", default = {800, 600}, displayName = "Screen Size" },
            lightPositions = { type = "vec2", default = {{400, 300}, {200, 200}, {600, 200}, {200, 400}, {600, 400}}, displayName = "Light Positions" },
            lightColors = { type = "vec3", default = {{1.0, 0.8, 0.6}, {0.6, 0.8, 1.0}, {0.8, 1.0, 0.6}, {1.0, 0.6, 0.8}, {0.6, 1.0, 0.8}}, displayName = "Light Colors" },
            lightRadii = { type = "float", default = {0.3, 0.25, 0.25, 0.25, 0.25}, displayName = "Light Radii" },
            lightCount = { type = "float", default = 1.0, min = 1.0, max = 5.0, displayName = "Light Count" },
            ambientIntensity = { type = "float", default = 0.2, min = 0.0, max = 1.0, displayName = "Ambient Intensity" },
            ambientColor = { type = "vec3", default = {0.2, 0.3, 0.5}, displayName = "Ambient Color" }
        }
    },
    {
        name = "metalReflection",
        displayName = "Metallic Surface Reflection",
        source = [[
            extern vec2 screen;
            extern vec3 metalColor;
            extern float reflectionStrength;
            extern float bumpIntensity;
            extern float time;
            
            // Simple 2D noise function for bump mapping effect
            float noise(vec2 p) {
                return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
            }
            
            vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
                // Sample the texture
                vec4 pixel = Texel(tex, texture_coords);
                
                // Create a simple bump map using noise
                float bump = 0.0;
                for (float i = 1.0; i < 5.0; i++) {
                    vec2 p = texture_coords * i * 10.0 + time * 0.1;
                    bump += noise(p) / i;
                }
                
                // Use bump map to create distorted texture coordinates for reflection
                vec2 bumpedCoords = texture_coords;
                bumpedCoords.x += bump * bumpIntensity * 0.01;
                
                // Sample the texture again with bumped coordinates for reflection
                vec4 reflectionPixel = Texel(tex, bumpedCoords);
                
                // Create metallic effect by mixing the original color with the reflection
                // and applying the metal color
                vec3 metallic = mix(pixel.rgb, reflectionPixel.rgb, reflectionStrength);
                metallic = metallic * metalColor;
                
                // Add highlighting based on bump map
                float highlight = pow(bump, 3.0) * 0.5;
                metallic += vec3(highlight);
                
                return vec4(metallic, pixel.a) * color;
            }
        ]],
        uniforms = {
            screen = { type = "vec2", default = {800, 600}, displayName = "Screen Size" },
            metalColor = { type = "vec3", default = {0.8, 0.8, 0.9}, displayName = "Metal Color" },
            reflectionStrength = { type = "float", default = 0.5, min = 0.0, max = 1.0, displayName = "Reflection Strength" },
            bumpIntensity = { type = "float", default = 1.0, min = 0.0, max = 5.0, displayName = "Bump Intensity" },
            time = { type = "float", default = 0.0, displayName = "Time" }
        }
    },
    {
        name = "glassSurface",
        displayName = "Glass Surface Effect",
        source = [[
            extern vec2 screen;
            extern float refractionStrength;
            extern float glossiness;
            extern vec3 glassColor;
            extern float glassOpacity;
            extern float time;
            
            vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
                // Normalize screen coordinates
                vec2 normalizedCoords = screen_coords / screen;
                
                // Create distortion effect based on a simple sine wave
                float distortionX = sin(normalizedCoords.y * 10.0 + time) * refractionStrength * 0.01;
                float distortionY = cos(normalizedCoords.x * 10.0 + time) * refractionStrength * 0.01;
                
                // Apply distortion to texture coordinates
                vec2 distortedCoords = texture_coords + vec2(distortionX, distortionY);
                
                // Sample the texture with distorted coordinates
                vec4 distortedPixel = Texel(tex, distortedCoords);
                
                // Create a highlight effect based on glossiness
                float highlight = pow(sin(normalizedCoords.x * 3.14159) * sin(normalizedCoords.y * 3.14159), glossiness * 10.0);
                vec3 highlightColor = vec3(highlight);
                
                // Mix the distorted pixel with glass color
                vec3 finalColor = mix(distortedPixel.rgb, glassColor, 1.0 - glassOpacity);
                
                // Add highlight
                finalColor += highlightColor * 0.2;
                
                return vec4(finalColor, distortedPixel.a) * color;
            }
        ]],
        uniforms = {
            screen = { type = "vec2", default = {800, 600}, displayName = "Screen Size" },
            refractionStrength = { type = "float", default = 1.0, min = 0.0, max = 5.0, displayName = "Refraction Strength" },
            glossiness = { type = "float", default = 0.8, min = 0.0, max = 1.0, displayName = "Glossiness" },
            glassColor = { type = "vec3", default = {0.9, 0.9, 1.0}, displayName = "Glass Color" },
            glassOpacity = { type = "float", default = 0.7, min = 0.0, max = 1.0, displayName = "Glass Opacity" },
            time = { type = "float", default = 0.0, displayName = "Time" }
        }
    }
}

-- Initialize shaders module
function Shaders:init()
    -- Register all built-in shaders
    for _, shader in ipairs(BUILT_IN_SHADERS) do
        self:registerShader(shader.name, shader.displayName, shader.source, shader.uniforms)
    end
    
    -- Create a default empty entry in the shaders registry (no effect)
    self:registerShader("none", "No Shader", "", {})
    
    Console:log("Shaders module initialized with " .. #BUILT_IN_SHADERS .. " built-in shaders")
end

-- Register a new shader definition
function Shaders:registerShader(name, displayName, source, uniforms)
    local shader = {
        name = name,
        displayName = displayName or name,
        source = source,
        uniforms = uniforms or {},
        compiled = nil -- Will store the compiled shader when needed
    }
    
    -- Only compile non-empty shaders
    if source and source ~= "" then
        local success, result = pcall(function()
            return love.graphics.newShader(source)
        end)
        
        if success then
            shader.compiled = result
            Console:log("Registered shader: " .. name)
        else
            Console:log("Failed to compile shader [" .. name .. "]: " .. tostring(result), "error")
        end
    end
    
    self.registry[name] = shader
    return shader
end

-- Create a shader component for an entity
function Shaders:createComponent(entity, shaderName)
    if not entity.components then
        entity.components = {}
    end
    
    -- Default to "none" if shader not specified or not found
    if not shaderName or not self.registry[shaderName] then
        shaderName = "none"
    end
    
    local shader = self.registry[shaderName]
    
    -- Create component with default values
    local component = {
        shaderName = shaderName,
        enabled = true,
        parameters = {}
    }
    
    -- Initialize parameters with default values
    for name, uniform in pairs(shader.uniforms) do
        component.parameters[name] = {
            value = uniform.default,
            type = uniform.type
        }
    end
    
    entity.components.shader = component
    Console:log("Added shader component to entity: " .. (entity.name or "unnamed"))
    return component
end

-- Change the shader of an existing component
function Shaders:setShader(component, shaderName)
    if not self.registry[shaderName] then
        Console:log("Shader not found: " .. shaderName, "error")
        return
    end
    
    local oldShaderName = component.shaderName
    component.shaderName = shaderName
    local shader = self.registry[shaderName]
    
    -- Reset parameters
    component.parameters = {}
    
    -- Initialize parameters with default values
    for name, uniform in pairs(shader.uniforms) do
        component.parameters[name] = {
            value = uniform.default,
            type = uniform.type
        }
    end
    
    Console:log("Changed shader from " .. oldShaderName .. " to " .. shaderName)
    return component
end

-- Apply shader parameters before rendering
function Shaders:applyShader(component)
    if not component or not component.shaderName or not component.enabled then
        love.graphics.setShader()
        return false
    end
    
    local shader = self.registry[component.shaderName]
    if not shader or not shader.compiled then
        love.graphics.setShader()
        return false
    end
    
    love.graphics.setShader(shader.compiled)
    
    -- Set all uniform values
    for name, param in pairs(component.parameters) do
        -- Skip if the uniform doesn't exist in the shader
        if not shader.compiled:hasUniform(name) then
            goto continue
        end
        
        if param.type == "float" then
            if type(param.value) == "number" then
                shader.compiled:send(name, param.value)
            else
                Console:log("Warning: Invalid float parameter for " .. name, "warning")
            end
        elseif param.type == "vec2" then
            -- Handle vec2 parameters
            if type(param.value) == "table" and #param.value >= 2 then
                -- Send as a table as LÖVE expects for vec2 uniforms
                shader.compiled:send(name, param.value)
            else
                Console:log("Warning: Invalid vec2 parameter for " .. name, "warning")
            end
        elseif param.type == "vec3" then
            -- Handle vec3 parameters
            if type(param.value) == "table" and #param.value >= 3 then
                -- Send as a table as LÖVE expects for vec3 uniforms
                shader.compiled:send(name, param.value)
            else
                Console:log("Warning: Invalid vec3 parameter for " .. name, "warning")
            end
        elseif param.type == "vec4" then
            -- Handle vec4 parameters
            if type(param.value) == "table" and #param.value >= 4 then
                -- Send as a table as LÖVE expects for vec4 uniforms
                shader.compiled:send(name, param.value)
            else
                Console:log("Warning: Invalid vec4 parameter for " .. name, "warning")
            end
        end
        
        ::continue::
    end
    
    return true
end

-- Load a shader from a file
function Shaders:loadFromFile(path)
    local name = path:match("([^/\\]+)%.%w+$") -- Extract filename without extension
    
    -- Read the shader source
    local success, source = pcall(function()
        return love.filesystem.read(path)
    end)
    
    if not success then
        Console:log("Failed to load shader from file: " .. path, "error")
        return nil
    end
    
    -- Register the shader
    local shader = self:registerShader(name, name, source, {})
    Console:log("Loaded shader from file: " .. name)
    
    return shader
end


-- Update time-based shader parameters
function Shaders:updateTime(dt)
    local SceneManager = require "modules.scene_manager"
    
    -- Find all entities with time-based shaders
    for _, entity in ipairs(SceneManager.entities) do
        if entity.components and entity.components.shader and entity.components.shader.enabled then
            local component = entity.components.shader
            local shader = self.registry[component.shaderName]
            
            if shader and component.parameters.time then
                -- Update the time parameter for animation
                component.parameters.time.value = (component.parameters.time.value or 0) + dt
                
                -- Reset time if it gets too large to avoid floating-point issues
                if component.parameters.time.value > 1 then
                    component.parameters.time.value = 0
                end
            end
        end
    end
end


return Shaders