-- outline.glsl - Sabit değerli outline shader
-- Bu shader, her nesnenin çevresine düz bir kontur çizer

return [[
extern vec2 textureSize;

// Sabit değerler
const float outlineWidth = 3.0; // Kontur genişliği piksel cinsinden
const vec4 outlineColor = vec4(1.0, 0.2, 0.2, 1.0); // Kırmızımsı kontur rengi
const float outlineThreshold = 0.1; // Alpha eşik değeri

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    // Ana piksel rengi
    vec4 texcolor = Texel(tex, texture_coords);
    
    // Eğer piksel tamamen şeffafsa, kontur kontrolü yap
    if (texcolor.a < outlineThreshold) {
        // Komşu piksellerin adımı (1 piksel)
        vec2 unitStep = 1.0 / textureSize;
        
        // Komşu pikselleri kontrol et
        float alpha = 0.0;
        
        for (float x = -outlineWidth; x <= outlineWidth; x += 1.0) {
            for (float y = -outlineWidth; y <= outlineWidth; y += 1.0) {
                // Piksel mesafesinin karesini hesapla
                float dist = (x * x + y * y);
                
                // Outline alanı içinde mi kontrol et
                if (dist <= outlineWidth * outlineWidth && dist > 0.0) {
                    vec2 checkCoord = texture_coords + vec2(x, y) * unitStep;
                    alpha = max(alpha, Texel(tex, checkCoord).a);
                }
            }
        }
        
        // Eğer komşu piksellerden biri opaksa, kontur rengini kullan
        if (alpha > outlineThreshold) {
            return outlineColor;
        }
        
        return vec4(0.0);
    }
    
    // Normal piksel, olduğu gibi döndür
    return texcolor * color;
}
]]