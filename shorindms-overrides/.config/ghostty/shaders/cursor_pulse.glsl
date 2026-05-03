float rectSdf(vec2 point, vec2 center, vec2 halfSize) {
    vec2 delta = abs(point - center) - halfSize;
    return length(max(delta, 0.0)) + min(max(delta.x, delta.y), 0.0);
}

float easeOutCubic(float value) {
    return 1.0 - pow(1.0 - value, 3.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    if (iCurrentCursor.z <= 0.0 || iCurrentCursor.w <= 0.0) {
        fragColor = base;
        return;
    }

    float elapsed = max(iTime - iTimeCursorChange, 0.0);
    const float DURATION = 0.42;
    float t = clamp(elapsed / DURATION, 0.0, 1.0);
    float fade = pow(1.0 - t, 1.85);

    vec2 cursorCenter = vec2(
        iCurrentCursor.x + iCurrentCursor.z * 0.5,
        iCurrentCursor.y - iCurrentCursor.w * 0.5
    );
    vec2 cursorHalf = max(iCurrentCursor.zw * 0.5, vec2(1.0));
    float sdf = rectSdf(fragCoord.xy, cursorCenter, cursorHalf);
    float distanceOutside = max(sdf, 0.0);

    float expansion = mix(2.0, 11.0, easeOutCubic(t));
    float ring = 1.0 - smoothstep(0.0, 4.0, abs(distanceOutside - expansion));
    float halo = 1.0 - smoothstep(expansion, expansion + 14.0, distanceOutside);
    float cursorLift = 1.0 - smoothstep(-1.0, 2.0, sdf);

    float hueMix = 0.5 + 0.5 * sin((1.0 - t) * 7.0);
    vec3 accent = mix(iPalette[14], iPalette[13], 0.25 + 0.5 * hueMix);
    vec3 pulseColor = mix(iCurrentCursorColor.rgb, accent, 0.58);

    float pulseStrength = ring * 0.34 * fade + halo * 0.16 * fade + cursorLift * 0.06 * fade;
    vec3 pulse = pulseColor * pulseStrength;
    vec3 finalColor = 1.0 - (1.0 - base.rgb) * (1.0 - pulse);

    fragColor = vec4(finalColor, base.a);
}
