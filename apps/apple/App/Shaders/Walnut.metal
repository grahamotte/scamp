#include <metal_stdlib>
using namespace metal;

float walnutHash(float2 point) {
    point = fract(point * float2(127.17, 311.73));
    point += dot(point, point + 37.91);
    return fract(point.x * point.y);
}

float walnutNoise(float2 point) {
    float2 cell = floor(point);
    float2 local = fract(point);
    local = local * local * local * (local * (local * 6.0 - 15.0) + 10.0);

    float bottomLeft = walnutHash(cell);
    float bottomRight = walnutHash(cell + float2(1.0, 0.0));
    float topLeft = walnutHash(cell + float2(0.0, 1.0));
    float topRight = walnutHash(cell + float2(1.0, 1.0));
    return mix(
        mix(bottomLeft, bottomRight, local.x),
        mix(topLeft, topRight, local.x),
        local.y
    );
}

float walnutFbm(float2 point) {
    float value = 0.0;
    float amplitude = 0.54;
    float2x2 rotation = float2x2(0.997, 0.077, -0.077, 0.997);

    for (int octave = 0; octave < 6; octave++) {
        value += amplitude * walnutNoise(point);
        point = rotation * point * 2.03 + float2(13.7, 7.9);
        amplitude *= 0.48;
    }
    return value;
}

[[ stitchable ]] half4 walnut(
    float2 position,
    half4 source,
    float2 size,
    float2 lightDirection
) {
    float scale = max(max(size.x, size.y), 1.0);
    float2 uv = position / max(size, float2(1.0));
    float boardCoordinate = uv.y * 4.0;
    float boardIndex = min(floor(boardCoordinate), 3.0);
    float boardFraction = fract(boardCoordinate);
    float boardHeight = size.y * 0.25;
    float boardSeed = walnutHash(float2(boardIndex + 2.7, 19.3));
    float figureSeed = walnutHash(float2(boardIndex + 11.8, 4.1));
    float toneSeed = walnutHash(float2(boardIndex + 7.4, 31.6));

    float x = position.x / scale;
    float localY = (position.y - (boardIndex + 0.5) * boardHeight) / scale;
    float grainSlope = (boardSeed - 0.5) * 0.022;
    localY += (x - 0.5) * grainSlope;

    float broadFigure = walnutFbm(
        float2(x * 0.78, localY * 5.2) + float2(boardSeed * 23.0, boardIndex * 8.7)
    );
    float curlFigure = walnutFbm(
        float2(x * 1.9, localY * 14.0) + float2(figureSeed * 31.0, boardIndex * 12.9)
    );
    float fiberDrift = walnutFbm(
        float2(x * 4.8, localY * 33.0) + float2(boardSeed * 47.0, figureSeed * 29.0)
    );
    float warpedY = localY
        + (broadFigure - 0.5) * 0.040
        + (curlFigure - 0.5) * 0.012;

    float ringCenter = mix(-0.28, 1.42, figureSeed);
    float ringX = (x - ringCenter) * mix(0.13, 0.22, boardSeed);
    float ringY = warpedY * mix(1.05, 1.42, toneSeed);
    float growthDistance = sqrt((ringX * ringX) + (ringY * ringY));
    float ringPhase = growthDistance * mix(39.0, 52.0, boardSeed)
        + (curlFigure - 0.5) * 4.6
        + (fiberDrift - 0.5) * 1.4;
    float ringWave = 0.5 + 0.5 * sin(ringPhase * 6.2831853);
    float latewood = smoothstep(0.88, 0.998, ringWave);
    float ringCore = smoothstep(0.978, 0.9995, ringWave);

    float fiberPhase = warpedY * 455.0
        + (fiberDrift - 0.5) * 11.0
        + sin(x * 13.0 + boardSeed * 9.0) * 1.2;
    float fiberWave = 0.5 + 0.5 * sin(fiberPhase);
    float fineFiber = smoothstep(0.87, 0.997, fiberWave);
    float fiberCore = smoothstep(0.975, 0.9995, fiberWave);

    float poreField = walnutNoise(
        float2(position.x * 0.071, position.y * 0.37) + float2(boardSeed * 43.0, boardIndex * 17.0)
    );
    float poreGate = walnutNoise(
        float2(x * 14.0, warpedY * 83.0) + float2(figureSeed * 21.0, toneSeed * 37.0)
    );
    float pores = smoothstep(0.975, 0.998, poreField) * smoothstep(0.62, 0.88, poreGate);

    float rayField = walnutNoise(
        float2(position.x * 0.16, position.y * 0.022) + float2(toneSeed * 63.0, boardSeed * 17.0)
    );
    float rays = smoothstep(0.987, 0.999, rayField) * smoothstep(0.42, 0.86, broadFigure);

    float colorCloud = walnutFbm(
        float2(x * 1.25, warpedY * 8.2) + float2(toneSeed * 34.0, boardIndex * 18.0)
    );
    float depthFigure = walnutFbm(
        float2(x * 3.3, warpedY * 19.0) + float2(figureSeed * 41.0, boardSeed * 27.0)
    );

    float3 deepWalnut = float3(0.255, 0.098, 0.040);
    float3 heartwood = float3(0.325, 0.128, 0.050);
    float3 honeyWalnut = float3(0.490, 0.238, 0.098);
    float3 wood = mix(deepWalnut, heartwood, smoothstep(0.10, 0.88, colorCloud));
    wood = mix(wood, honeyWalnut, smoothstep(0.62, 0.96, broadFigure) * 0.05);

    float boardTone = mix(0.995, 1.025, toneSeed);
    float boardWarmth = (boardSeed - 0.5) * 0.006;
    wood *= boardTone * (0.99 + depthFigure * 0.025);
    wood += float3(boardWarmth, boardWarmth * 0.35, 0.0);
    wood *= 0.985 + ringWave * 0.025;

    float3 latewoodColor = float3(0.061, 0.018, 0.008);
    wood = mix(wood, latewoodColor, latewood * (0.07 + curlFigure * 0.04));
    wood = mix(wood, float3(0.027, 0.008, 0.004), ringCore * 0.06);
    wood = mix(wood, float3(0.056, 0.017, 0.008), fineFiber * 0.04);
    wood = mix(wood, float3(0.022, 0.006, 0.003), fiberCore * 0.05);
    wood = mix(wood, float3(0.012, 0.004, 0.002), pores * 0.35);
    wood = mix(wood, float3(0.62, 0.29, 0.10), rays * 0.10);

    float lightAcrossGrain = 0.5 + 0.5 * clamp(-lightDirection.y, -1.0, 1.0);
    float chatoyance = smoothstep(0.58, 0.96, depthFigure)
        * smoothstep(0.66, 0.998, fiberWave)
        * (0.38 + lightAcrossGrain * 0.62);
    wood += float3(0.13, 0.055, 0.014) * chatoyance * 0.17;

    float edgePixels = min(boardFraction, 1.0 - boardFraction) * boardHeight;
    float seamCore = 1.0 - smoothstep(0.25, 0.85, edgePixels);
    float seamShadow = 1.0 - smoothstep(0.8, 3.8, edgePixels);
    float seamHighlight = smoothstep(0.7, 1.8, edgePixels)
        * (1.0 - smoothstep(1.8, 4.5, edgePixels));
    wood *= 1.0 - seamShadow * 0.10;
    wood = mix(wood, float3(0.012, 0.004, 0.002), seamCore * 0.62);
    wood += float3(0.24, 0.095, 0.025) * seamHighlight * 0.075;

    wood = clamp(wood, 0.0, 1.0);
    return half4(half3(wood), source.a);
}
