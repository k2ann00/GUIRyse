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


