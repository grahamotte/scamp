#include <metal_stdlib>
using namespace metal;

float blackMarbleHash(float2 point) {
    point = fract(point * float2(127.41, 439.73));
    point += dot(point, point + 41.19);
    return fract(point.x * point.y);
}

float blackMarbleNoise(float2 point) {
    float2 cell = floor(point);
    float2 local = fract(point);
    local = local * local * (3.0 - 2.0 * local);

    float bottomLeft = blackMarbleHash(cell);
    float bottomRight = blackMarbleHash(cell + float2(1.0, 0.0));
    float topLeft = blackMarbleHash(cell + float2(0.0, 1.0));
    float topRight = blackMarbleHash(cell + float2(1.0, 1.0));
    return mix(
        mix(bottomLeft, bottomRight, local.x),
        mix(topLeft, topRight, local.x),
        local.y
    );
}

float blackMarbleFbm(float2 point) {
    float value = 0.0;
    float amplitude = 0.52;
    float2x2 rotation = float2x2(0.82, 0.57, -0.57, 0.82);

    for (int octave = 0; octave < 6; octave++) {
        value += amplitude * blackMarbleNoise(point);
        point = rotation * point * 2.07 + float2(15.73, 8.91);
        amplitude *= 0.49;
    }
    return value;
}

[[ stitchable ]] half4 blackMarble(
    float2 position,
    half4 source,
    float2 size
) {
    float scale = max(max(size.x, size.y), 1.0);
    float2 point = (position - size * 0.5) / scale;
    float2x2 stoneRotation = float2x2(0.78, -0.63, 0.63, 0.78);
    point = stoneRotation * point;

    float2 firstWarp = float2(
        blackMarbleFbm(point * 1.9 + float2(2.4, 6.1)),
        blackMarbleFbm(point * 1.9 + float2(9.2, 3.5))
    );
    float2 secondWarp = float2(
        blackMarbleFbm(point * 3.4 + firstWarp * 2.5 + float2(5.1, 8.7)),
        blackMarbleFbm(point * 3.4 + firstWarp * 2.5 + float2(8.6, 1.9))
    );
    float2 warpedPoint = point + (firstWarp - 0.5) * 0.52 + (secondWarp - 0.5) * 0.2;

    float bodyNoise = blackMarbleFbm(warpedPoint * 1.45 + float2(3.2, 5.7));
    float detailNoise = blackMarbleFbm(warpedPoint * 5.2 + firstWarp * 1.8);
    float fineNoise = blackMarbleFbm(warpedPoint * 14.0 + secondWarp * 2.3);
    float mineralField = dot(warpedPoint, float2(6.2, 1.7))
        + (bodyNoise - 0.5) * 9.1
        + (detailNoise - 0.5) * 2.7;
    float bandDistance = abs(sin(mineralField));

    float cloud = 1.0 - smoothstep(0.22, 0.88, bandDistance);
    float veinBody = 1.0 - smoothstep(0.055, 0.42, bandDistance);
    float veinCore = 1.0 - smoothstep(0.006, 0.06, bandDistance);

    float featherField = mineralField * 3.1
        + (fineNoise - 0.5) * 5.8
        + blackMarbleFbm(warpedPoint * 9.0 + float2(4.0, 7.2)) * 1.9;
    float featherDistance = abs(sin(featherField));
    float feather = (1.0 - smoothstep(0.02, 0.16, featherDistance))
        * smoothstep(0.06, 0.68, cloud);

    float stoneCloud = blackMarbleFbm(point * 2.4 + secondWarp * 1.4);
    float pores = blackMarbleNoise(point * scale * 0.24) - 0.5;
    float warmth = blackMarbleFbm(warpedPoint * 1.9 + float2(10.4, 4.2));

    float3 coolBlack = float3(0.025, 0.030, 0.034);
    float3 warmBlack = float3(0.055, 0.047, 0.041);
    float3 stone = mix(coolBlack, warmBlack, warmth);
    stone += (stoneCloud - 0.42) * 0.052;
    stone += pores * 0.01;

    float3 cloudColor = float3(0.11, 0.12, 0.125);
    float3 veinColor = mix(
        float3(0.48, 0.52, 0.53),
        float3(0.58, 0.54, 0.48),
        warmth
    );
    float3 coreColor = float3(0.88, 0.90, 0.89);
    stone = mix(stone, cloudColor, cloud * (0.10 + detailNoise * 0.08));
    stone = mix(stone, veinColor, veinBody * (0.18 + fineNoise * 0.13));
    stone = mix(stone, coreColor, veinCore * (0.34 + fineNoise * 0.18));
    stone = mix(stone, veinColor, feather * (0.16 + fineNoise * 0.12));

    float calciteEdge = smoothstep(0.06, 0.038, bandDistance)
        * smoothstep(0.006, 0.02, bandDistance);
    stone = mix(stone, float3(0.97), calciteEdge * 0.28);
    stone = clamp(stone, 0.0, 1.0);
    return half4(half3(stone), source.a);
}
