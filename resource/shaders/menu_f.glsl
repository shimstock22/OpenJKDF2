uniform sampler2D tex;
uniform sampler2D worldPalette;
uniform sampler2D displayPalette;

// Added: Menu text antialiasing - captured glyph texture and toggle.
uniform sampler2D menuTextAATexture;
uniform int useMenuTextAA;
// Added: Menu text antialiasing - signed distance field texture.
uniform sampler2D menuTextSDFTexture;

// Added: Menu text antialiasing - 2x reconstructed glyph coverage texture.
uniform sampler2D menuTextReconstructedTexture;

// Added: Menu text antialiasing - 2x reconstructed glyph palette colors.
uniform sampler2D menuTextReconstructedColorTexture;

// Added: PNG menu background support
uniform sampler2D pngMenuBackground;
uniform sampler2D pngMenuMask;
uniform int usePngMenuBackground;
uniform vec2 pngMenuUvScale;

// Added: PNG menu background support
uniform int pngMenuFullscreen;
uniform vec2 pngMenuCropScale;
// Added: PNG menu background support - multiplayer character compositing.
uniform int pngMenuCharacterPreview;

in vec4 f_color;
in vec2 f_uv;
out vec4 fragColor;

void main(void)
{
    // Added: PNG menu background support
    // Draw a fullscreen PNG with centered, height-based cropping.
    if (pngMenuFullscreen != 0)
    {
        vec2 pngUv = vec2(
            0.5 + (f_uv.x - 0.5) * pngMenuCropScale.x,
            0.5 + (f_uv.y - 0.5) * pngMenuCropScale.y
        );

        // Added: PNG menu background support
        // Display black borders instead of stretching the PNG's edge pixels.
        if (pngUv.x < 0.0 || pngUv.x > 1.0 ||
            pngUv.y < 0.0 || pngUv.y > 1.0)
        {
            fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        }
        else
        {
            fragColor = texture(pngMenuBackground, pngUv);
        }
        return;
    }

    // Added: PNG menu background support - draw the RGBA character preview.
    if (pngMenuCharacterPreview != 0)
    {
        fragColor = texture(tex, vec2(f_uv.x, 1.0 - f_uv.y));
        return;
    }
    vec4 sampled = texture(tex, f_uv);
    float index = sampled.r;

    vec4 palvald = texture(displayPalette, vec2(index, 0.5));

// Added: Menu text antialiasing - reconstruct original text backgrounds.
if (useMenuTextAA != 0)
{
    vec2 guiUv = f_uv * pngMenuUvScale;
    // Added: Menu text antialiasing - preserve exact palette indices.
ivec2 glyphPixel = ivec2(
    clamp(
        floor(guiUv * vec2(640.0, 480.0)),
        vec2(0.0),
        vec2(639.0, 479.0)
    )
);

vec4 textData = texelFetch(menuTextAATexture, glyphPixel, 0);

// Added: Menu text antialiasing - filtered 2x reconstructed glyph coverage.
vec2 reconstructedTexel = vec2(1.0 / 1280.0, 1.0 / 960.0);
vec2 sampleOffset = reconstructedTexel * 0.5;

float filteredCoverage = (
    texture(menuTextReconstructedTexture,
        guiUv + vec2(-sampleOffset.x, -sampleOffset.y)).r +
    texture(menuTextReconstructedTexture,
        guiUv + vec2( sampleOffset.x, -sampleOffset.y)).r +
    texture(menuTextReconstructedTexture,
        guiUv + vec2(-sampleOffset.x,  sampleOffset.y)).r +
    texture(menuTextReconstructedTexture,
        guiUv + vec2( sampleOffset.x,  sampleOffset.y)).r
) * 0.25;

// Added: Menu text antialiasing - tighten the outer glyph edge and dark halo.
filteredCoverage = smoothstep(0.15, 0.85, filteredCoverage);

// Added: Menu text antialiasing - blend captured glyphs with their backgrounds.
// Added: Menu text antialiasing - render glyphs over standard and PNG backgrounds.
if (filteredCoverage > 0.001)
{
    vec2 texel = 1.0 / vec2(640.0, 480.0);

    // Added: Menu text antialiasing - find the nearest captured glyph pixel.
    vec4 glyphData = textData;

    if (glyphData.b < 0.5)
    {
// Added: Menu text antialiasing - sample neighboring glyphs without palette interpolation.
// Added: Menu text antialiasing - clamp neighboring glyph samples.
ivec2 glyphMin = ivec2(0, 0);
ivec2 glyphMax = ivec2(639, 479);

vec4 leftData = texelFetch(
    menuTextAATexture,
    clamp(glyphPixel + ivec2(-1, 0), glyphMin, glyphMax),
    0
);

vec4 rightData = texelFetch(
    menuTextAATexture,
    clamp(glyphPixel + ivec2(1, 0), glyphMin, glyphMax),
    0
);

vec4 upData = texelFetch(
    menuTextAATexture,
    clamp(glyphPixel + ivec2(0, -1), glyphMin, glyphMax),
    0
);

vec4 downData = texelFetch(
    menuTextAATexture,
    clamp(glyphPixel + ivec2(0, 1), glyphMin, glyphMax),
    0
);

        if (leftData.b > 0.5)
            glyphData = leftData;
        else if (rightData.b > 0.5)
            glyphData = rightData;
        else if (upData.b > 0.5)
            glyphData = upData;
        else if (downData.b > 0.5)
            glyphData = downData;
    }

    if (glyphData.b > 0.5)
    {
// Added: Menu text antialiasing - preserve original glyph color.
vec3 glyphColor =
    texture(displayPalette, vec2(glyphData.r, 0.5)).rgb;

    // Added: Menu text antialiasing - sample reconstructed 2x glyph palette index.
float reconstructedColorIndex =
    texture(menuTextReconstructedColorTexture, guiUv).r;

// Added: Menu text antialiasing - convert reconstructed palette index to RGB.
vec3 reconstructedGlyphColor =
    texture(displayPalette, vec2(reconstructedColorIndex, 0.5)).rgb;

    // Added: Menu text antialiasing - test reconstructed glyph colors.
glyphColor = reconstructedGlyphColor;

// Added: Menu text antialiasing - selectively smooth internal color edges.
vec2 glyphPosition = guiUv * vec2(640.0, 480.0) - vec2(0.5);
ivec2 colorBase = ivec2(floor(glyphPosition));
vec2 colorFraction = fract(glyphPosition);

ivec2 colorMin = ivec2(0, 0);
ivec2 colorMax = ivec2(639, 479);

vec4 color00 = texelFetch(
    menuTextAATexture,
    clamp(colorBase, colorMin, colorMax), 0
);
vec4 color10 = texelFetch(
    menuTextAATexture,
    clamp(colorBase + ivec2(1, 0), colorMin, colorMax), 0
);
vec4 color01 = texelFetch(
    menuTextAATexture,
    clamp(colorBase + ivec2(0, 1), colorMin, colorMax), 0
);
vec4 color11 = texelFetch(
    menuTextAATexture,
    clamp(colorBase + ivec2(1, 1), colorMin, colorMax), 0
);

// Added: Menu text antialiasing - avoid blending background pixels into glyphs.
if (color00.b < 0.5) color00 = glyphData;
if (color10.b < 0.5) color10 = glyphData;
if (color01.b < 0.5) color01 = glyphData;
if (color11.b < 0.5) color11 = glyphData;

// Added: Menu text antialiasing - interpolate RGB rather than palette indices.
vec3 rgb00 = texture(displayPalette, vec2(color00.r, 0.5)).rgb;
vec3 rgb10 = texture(displayPalette, vec2(color10.r, 0.5)).rgb;
vec3 rgb01 = texture(displayPalette, vec2(color01.r, 0.5)).rgb;
vec3 rgb11 = texture(displayPalette, vec2(color11.r, 0.5)).rgb;

vec3 interpolatedColor = mix(
    mix(rgb00, rgb10, colorFraction.x),
    mix(rgb01, rgb11, colorFraction.x),
    colorFraction.y
);

// Added: Menu text antialiasing - restrict smoothing to internal color boundaries.
bool internalEdge =
    (color00.r != color10.r) ||
    (color00.r != color01.r) ||
    (color00.r != color11.r);

if (internalEdge)
{
    glyphColor = mix(glyphColor, interpolatedColor, 0.10);
}

        vec3 backgroundColor =
            texture(displayPalette, vec2(glyphData.g, 0.5)).rgb;

// Added: Menu text antialiasing - blend original font colors.
vec3 antialiasedColor = mix(
    backgroundColor,
    glyphColor,
    filteredCoverage
);

// Added: Menu text antialiasing - preserve transparency over PNG artwork.
if (usePngMenuBackground != 0 && glyphData.a < 0.5)
{
    fragColor = vec4(glyphColor * f_color.rgb, filteredCoverage * f_color.a);
}
else
{
    fragColor = vec4(antialiasedColor, 1.0) * f_color;
}
return;
    }
}

}

    // Added: PNG menu background support
    if (usePngMenuBackground != 0)
    {
        // The original menu buffer may be larger than 640x480.
        // Convert its texture coordinates to the 640x480 GUI area.
        vec2 guiUv = f_uv * pngMenuUvScale;

        // Added: PNG menu background support
        // The fullscreen PNG is already drawn behind the original GUI.
        float mask = texture(pngMenuMask, guiUv).r;

        vec4 guiColor = vec4(palvald.rgb, 1.0) * f_color;

        // Preserve GUI pixels while allowing the fullscreen PNG to show through.
        fragColor = vec4(guiColor.rgb, guiColor.a * mask);
        return;
    }

    // Original menu rendering behavior.
    if (index == 0.0)
        discard;

    fragColor = vec4(palvald.rgb, 1.0) * f_color;
}
