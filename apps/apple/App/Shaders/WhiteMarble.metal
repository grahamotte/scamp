#include <metal_stdlib>
using namespace metal;

float marbleHash(float2 point) {
    point = fract(point * float2(123.34, 456.21));
    point += dot(point, point + 45.32);
    return fract(point.x * point.y);
}

float marbleNoise(float2 point) {
    float2 cell = floor(point);
    float2 local = fract(point);
    local = local * local * (3.0 - 2.0 * local);

    float bottomLeft = marbleHash(cell);
    float bottomRight = marbleHash(cell + float2(1.0, 0.0));
    float topLeft = marbleHash(cell + float2(0.0, 1.0));
    float topRight = marbleHash(cell + float2(1.0, 1.0));
    return mix(
        mix(bottomLeft, bottomRight, local.x),
        mix(topLeft, topRight, local.x),
        local.y
    );
}

float marbleFbm(float2 point) {
    float value = 0.0;
    float amplitude = 0.52;
    float2x2 rotation = float2x2(0.80, 0.60, -0.60, 0.80);

    for (int octave = 0; octave < 6; octave++) {
        value += amplitude * marbleNoise(point);
        point = rotation * point * 2.03 + float2(17.13, 9.71);
        amplitude *= 0.49;
    }
    return value;
}

[[ stitchable ]] half4 whiteMarble(
    float2 position,
    half4 source,
    float2 size
) {
    float scale = max(max(size.x, size.y), 1.0);
    float2 point = (position - size * 0.5) / scale;
    float2x2 stoneRotation = float2x2(0.84, -0.54, 0.54, 0.84);
    point = stoneRotation * point;

    float2 firstWarp = float2(
        marbleFbm(point * 2.05 + float2(1.7, 5.2)),
        marbleFbm(point * 2.05 + float2(8.3, 2.8))
    );
    float2 secondWarp = float2(
        marbleFbm(point * 3.1 + firstWarp * 2.3 + float2(4.4, 9.1)),
        marbleFbm(point * 3.1 + firstWarp * 2.3 + float2(7.8, 1.3))
    );
    float2 warpedPoint = point + (firstWarp - 0.5) * 0.46 + (secondWarp - 0.5) * 0.18;

    float bodyNoise = marbleFbm(warpedPoint * 1.35 + float2(2.1, 6.4));
    float detailNoise = marbleFbm(warpedPoint * 4.8 + firstWarp * 1.7);
    float fineNoise = marbleFbm(warpedPoint * 13.0 + secondWarp * 2.1);
    float mineralField = dot(warpedPoint, float2(5.7, 2.0))
        + (bodyNoise - 0.5) * 8.4
        + (detailNoise - 0.5) * 2.35;
    float bandDistance = abs(sin(mineralField));

    float cloud = 1.0 - smoothstep(0.24, 0.92, bandDistance);
    float veinBody = 1.0 - smoothstep(0.07, 0.48, bandDistance);
    float veinCore = 1.0 - smoothstep(0.008, 0.075, bandDistance);

    float featherField = mineralField * 2.8
        + (fineNoise - 0.5) * 5.2
        + marbleFbm(warpedPoint * 8.0 + float2(3.0, 8.0)) * 1.7;
    float featherDistance = abs(sin(featherField));
    float feather = (1.0 - smoothstep(0.025, 0.18, featherDistance))
        * smoothstep(0.08, 0.72, cloud);

    float stoneCloud = marbleFbm(point * 2.2 + secondWarp * 1.25);
    float pores = marbleNoise(point * scale * 0.22) - 0.5;
    float warmth = marbleFbm(warpedPoint * 1.8 + float2(11.2, 3.6));

    float3 warmWhite = float3(0.965, 0.955, 0.925);
    float3 coolWhite = float3(0.925, 0.945, 0.948);
    float3 stone = mix(coolWhite, warmWhite, warmth);
    stone -= (stoneCloud - 0.42) * 0.045;
    stone -= pores * 0.012;

    float3 cloudColor = float3(0.64, 0.68, 0.69);
    float3 veinColor = mix(
        float3(0.43, 0.47, 0.48),
        float3(0.50, 0.47, 0.43),
        warmth
    );
    float3 coreColor = float3(0.31, 0.34, 0.35);
    stone = mix(stone, cloudColor, cloud * (0.08 + detailNoise * 0.055));
    stone = mix(stone, veinColor, veinBody * (0.08 + fineNoise * 0.075));
    stone = mix(stone, coreColor, veinCore * (0.20 + fineNoise * 0.12));
    stone = mix(stone, veinColor, feather * (0.09 + fineNoise * 0.09));

    float calciteEdge = smoothstep(0.075, 0.045, bandDistance)
        * smoothstep(0.008, 0.025, bandDistance);
    stone = mix(stone, float3(0.99), calciteEdge * 0.18);
    stone = clamp(stone, 0.0, 1.0);
    return half4(half3(stone), source.a);
}
