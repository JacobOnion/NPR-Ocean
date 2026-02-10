#ifndef SSR_INPUTS_INCLUDED
#define SSR_INPUTS_INCLUDED

// Core URP helpers



// Guard for Shader Graph preview / early-include cases in SG
#if defined(SHADERGRAPH_PREVIEW)
    // Unity 6/URP defines MAX_VISIBLE_LIGHT_COUNT_* in a config header,
    // but in some preview paths it isn't available yet.
    #ifndef MAX_VISIBLE_LIGHTS
        #define MAX_VISIBLE_LIGHTS 0
    #endif
#endif

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// If you want to use URP's normal sampling helper:
//#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
// (DeclareNormalsTexture.hlsl provides SampleSceneNormals(uv) which decodes octahedral normals)

// --- Our globals published by the Renderer Feature ---
// Scene color (copied to avoid read/modify hazards by the feature)
TEXTURE2D_X(_SSR_SceneColor);
SAMPLER(sampler_SSR_SceneColor);

// Depth copy (URP _CameraDepthTexture or active depth alias)
// We'll convert to linear01.
TEXTURE2D_X(_SSR_DepthTexture);
SAMPLER(sampler_SSR_DepthTexture);


// Sample scene depth from texture in linear 0-1 form
inline float SampleLinearDepth(TEXTURE2D_X_PARAM( tex, samp),
float2 uv) 
{
    float raw = SAMPLE_TEXTURE2D_X(tex, samp, uv).r;
    return Linear01Depth(raw, _ZBufferParams);
}


inline float SampleRawDepth(TEXTURE2D_X_PARAM(tex, samp), float2 uv)
{
    return SAMPLE_TEXTURE2D_X(tex, samp, uv).r;
}


inline float3 ReconstructVS_FromRawDepth(float2 uv, float rawDepth)
{
    return ComputeViewSpacePosition(uv, rawDepth, UNITY_MATRIX_I_P);
}


inline float3 ReconstructViewPos(float2 uv, float depth_01)
{
    float2 ndc = uv * 2.0f - 1.0f;  // remap from 0-1 to -1-1
    float z_vs = LinearEyeDepth(depth_01, _ZBufferParams);
    return ComputeViewSpacePosition(uv, z_vs, UNITY_MATRIX_I_P);  // Maybe wants to be raw params, not linear?
}


// Project a view-space position to 0..1 UV (no flips/stereo/scale yet)
inline float2 ViewToUV_NoFix(float3 posVS)
{
    float4 clip = mul(UNITY_MATRIX_P, float4(posVS, 1.0));
    float2 ndc  = clip.xy / max(clip.w, 1e-6);
    return ndc * 0.5f + 0.5f;
}

// Bring a 0..1 UV into the same space as URP RG RTHandles:
//   - Y flip (platform dependent)
//   - Stereo transform
//   - RTHandle scale


inline float2 ToRTUV(float2 uv01)
{
    float2 uv_rt = uv01;


    #if UNITY_UV_STARTS_AT_TOP
    uv_rt.y = 1.0 - uv_rt.y;
    #endif

    uv_rt = UnityStereoTransformScreenSpaceTex(uv_rt);

    // Only apply RTHandle scaling when both the define and uniform are valid
    #if defined(_RT_HANDLE_SCALING_FACTORS)
    // In some pipelines/material paths, _RTHandleScale may not be bound; 
    // if you see the same error, comment this block out or ensure the uniform is set.
    uv_rt = ClampAndScaleUVForBilinear(uv_rt, _RTHandleScale.xy);
    #endif

    return uv_rt;
}



bool RayMarch(float3 pos_vs, float3 ray_vs, float2 startUV, float step,
    float stepScale, int maxSteps, float thickness, out float2 hitsUV)
{
   const int MAX_STEPS = 64;
    
    half stepSize = step;
    half accumulatedStep = 0.0;
    float3 pos = pos_vs;
    float2 uv = startUV;
    hitsUV = startUV;

    bool binarySearch = false;
    pos += ray_vs * 0.02;
    // Performance note: consider changing to conditional assignments ( : ? ) over conditional branch 
    for (int i = 0; i < MAX_STEPS; i++)
    {
        if (i > maxSteps) break;
        accumulatedStep += stepSize;
        //float stepDist = max(length(pos_vs) * stepScale / maxSteps, 0.001);
        float stepDist = max(step, 0.001);
        pos += ray_vs * stepDist;

        // convert vs back to screen uv
        float4 clip = mul(UNITY_MATRIX_P, float4(pos, 1.0));
        
        if (clip.w <= 0.0)
            break;

        
        float2 ndc = clip.xy / max(clip.w, 1e-6);
        uv = ndc * 0.5 + 0.5;
        //uv = ToRTUV(uv);
        uv.y = 1 - uv.y;
        // check screen boundaries
        if (uv.x > 1 || uv.x < 0 || uv.y > 1 || uv.y < 0)
            break;

        float rawDepth = SampleRawDepth(
            TEXTURE2D_X_ARGS(_SSR_DepthTexture, sampler_SSR_DepthTexture), uv);
        float sceneEyeZ = LinearEyeDepth(rawDepth, _ZBufferParams);
        //float sceneVS_Z = -ComputeViewSpacePosition(uv, rawDepth, UNITY_MATRIX_I_P).z;
        float rayEyeZ = -pos.z;
        // Compare ray depth to depth of pixel in depth buffer
        float dz = rayEyeZ - sceneEyeZ;
        
        half sign = FastSign(dz);
        binarySearch = binarySearch || (sign == 1) ? true : false; // Begin search if ray depth > scene depth
        if (binarySearch && FastSign(stepSize) != sign)
        {
            stepSize = stepSize * sign * 0.5;
            thickness *= 0.5;
        }

        dz = abs(dz);
        if (rayEyeZ >= sceneEyeZ - thickness && dz <= thickness)
        {
            hitsUV = uv;
            return true;
        }
        
    }
    hitsUV = startUV;
    return false;
}


void SSR_float(float2 screenPos, float3 pos_ws, float3 normal_ws, float3 viewDir_ws,
    float step, float stepScale, int maxSteps, float thickness, out float4 outColor, out float reflectionMask)
{
    float2 st = screenPos;  // test w -wo
    //float2 st = ToRTUV(screenPos);
    float4 sceneCol = SAMPLE_TEXTURE2D_X(_SSR_SceneColor, sampler_SSR_SceneColor, st);  // Get scene color at current pixel
    
    float3 ray_ws = reflect(-normalize(viewDir_ws), normalize(normal_ws));
    
    //float3 ray_vs = mul((float3x3) unity_WorldToCamera, ray_ws);

    
    float3 normal_vs = mul((float3x3)UNITY_MATRIX_V, normal_ws);
    float3 viewDir_vs = mul((float3x3)UNITY_MATRIX_V, viewDir_ws);
    float3 ray_vs = reflect(-normalize(viewDir_vs), normalize(normal_vs));

    
    //float depth_01 = SampleLinearDepth(TEXTURE2D_X_ARGS(_SSR_DepthTexture, sampler_SSR_DepthTexture), st);
    
    //float3 pos_vs = ReconstructViewPos(st, depth_01);

    float3 pos_vs = mul(UNITY_MATRIX_V, float4(pos_ws, 1.0)).xyz;

    float2 hitsUV = st;
    float4 reflColor;
    bool hit = RayMarch(pos_vs, ray_vs, st, step, stepScale, maxSteps, thickness, hitsUV);
    if (hit)
    {
        //Apply fresnel
        float F0 = 0.02; // dielectric ~2%
        float VoH = saturate(dot(-normalize(viewDir_ws), normalize(normal_ws)));
        float fresnel = F0 + (1.0 - F0) * pow(1.0 - VoH, 5.0);
        //hitsUV = ToRTUV(hitsUV);
        //hitsUV.y = 1 - hitsUV.y;
        reflColor = SAMPLE_TEXTURE2D_X(_SSR_SceneColor, sampler_SSR_SceneColor, hitsUV);
        reflColor = lerp(sceneCol, reflColor, fresnel);
        //reflColor = sceneCol;
        reflectionMask = 1.0;
    }
    else
    {
        reflColor = (0,0,0,0);
        reflectionMask = 0.0;
    }

    outColor = reflColor; // Just output the scene color for now, replace with actual SSR logic later
}
    

#endif // SSR_INPUTS_INCLUDED