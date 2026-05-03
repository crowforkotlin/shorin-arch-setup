float luminance(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float inkMask(vec3 color) {
    vec3 bg = iBackgroundColor;
    float colorDelta = length(color - bg);
    float luminanceDelta = abs(luminance(color) - luminance(bg));
    return smoothstep(0.08, 0.34, colorDelta + luminanceDelta * 0.8);
}

vec3 glowTap(vec2 uv, vec2 offset, float weight) {
    vec3 sampleColor = texture(iChannel0, uv + offset).rgb;
    float sampleInk = inkMask(sampleColor);
    vec3 accent = mix(iPalette[14], iPalette[13], clamp(luminance(sampleColor) * 1.15, 0.0, 1.0));
    vec3 neonTint = mix(sampleColor, accent, 0.44);
    return neonTint * sampleInk * weight;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    vec2 px = 1.0 / iResolution.xy;

    vec3 glow = vec3(0.0);
    glow += glowTap(uv, vec2( 1.40,  0.00) * px, 0.125);
    glow += glowTap(uv, vec2(-1.40,  0.00) * px, 0.125);
    glow += glowTap(uv, vec2( 0.00,  1.40) * px, 0.125);
    glow += glowTap(uv, vec2( 0.00, -1.40) * px, 0.125);
    glow += glowTap(uv, vec2( 1.00,  1.00) * px, 0.10);
    glow += glowTap(uv, vec2(-1.00,  1.00) * px, 0.10);
    glow += glowTap(uv, vec2( 1.00, -1.00) * px, 0.10);
    glow += glowTap(uv, vec2(-1.00, -1.00) * px, 0.10);

    glow += glowTap(uv, vec2( 2.70,  0.00) * px, 0.060);
    glow += glowTap(uv, vec2(-2.70,  0.00) * px, 0.060);
    glow += glowTap(uv, vec2( 0.00,  2.70) * px, 0.060);
    glow += glowTap(uv, vec2( 0.00, -2.70) * px, 0.060);
    glow += glowTap(uv, vec2( 2.10,  2.10) * px, 0.045);
    glow += glowTap(uv, vec2(-2.10,  2.10) * px, 0.045);
    glow += glowTap(uv, vec2( 2.10, -2.10) * px, 0.045);
    glow += glowTap(uv, vec2(-2.10, -2.10) * px, 0.045);

    float baseInk = inkMask(base.rgb);
    float focus = clamp(float(iFocus), 0.0, 1.0);
    float glowStrength = mix(0.155, 0.215, focus);
    float softness = 0.10 * baseInk;

    vec3 softenedBase = mix(base.rgb, mix(base.rgb, glow, 0.16), softness);
    vec3 neon = 1.0 - (1.0 - softenedBase) * (1.0 - glow * glowStrength);

    fragColor = vec4(neon, base.a);
}
