#ifndef COLOR_TEST_INCLUDED
#define COLOR_TEST_INCLUDED

// Core URP helpers



#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

inline float2 ViewToUV_NoStereo(float3 posVS)
{
    float4 clip = mul(UNITY_MATRIX_P, float4(posVS, 1.0));
    float2 ndc  = clip.xy / max(clip.w, 1e-6);
    float2 uv   = ndc * 0.5f + 0.5f;
    #if UNITY_UV_STARTS_AT_TOP
    uv.y = 1.0 - uv.y;
    #endif
    return uv;
}


void SSR_Debug_ProjectRay_float(
    float2 screenPos,
    float3 posWS,
    float3 normalWS,
    float3 viewDirWS,
    float  baseStep,
    int    steps,
    out float4 color)
{
    // Build ray from water surface in view space
    float3 V = normalize(viewDirWS);
    float3 N = normalize(normalWS);
    float3 Rws = reflect(-V, N);
    float3 Rvs = normalize(mul((float3x3)UNITY_MATRIX_V, Rws));

    float3 originVS = mul(UNITY_MATRIX_V, float4(posWS, 1)).xyz;

    // March a few steps and draw a white dot at the projected point
    float3 p = originVS + Rvs * (0.02 + baseStep * steps); // bias + steps
    float2 uv = ViewToUV_NoStereo(p);

    // If within screen, show white; else black
    bool onScreen = (uv.x >= 0 && uv.x <= 1 && uv.y >= 0 && uv.y <= 1);
    color = onScreen ? float4(1,1,1,1) : float4(0,0,0,1);
    
    //float2 uv_dbg = saturate(uv);
    //color = float4(uv_dbg, 0, 1); // shows UV as color over the water

}

#endif