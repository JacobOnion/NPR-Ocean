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


inline float3 ReconstructViewPos(float2 uv, float depth_01)
{
    float2 ndc = uv * 2.0f - 1.0f;  // remap from 0-1 to -1-1
    float z_vs = LinearEyeDepth(depth_01, _ZBufferParams);
    return ComputeViewSpacePosition(uv, z_vs, UNITY_MATRIX_I_P);  // Maybe wants to be raw params, not linear?
}


bool RayMarch(float3 pos_vs, float3 ray_vs, float2 startUV, float step,
    float stepScale, int maxSteps, float maxDist, float thickness, out float2 hitsUV)
{
   const int MAX_STEPS = 64;
    const int STEP_DIST = step;
    
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
        // Don't return sky hits
        //if (rawDepth <= maxDist)
        //    return false;
        //float sceneVS_Z = -ComputeViewSpacePosition(uv, rawDepth, UNITY_MATRIX_I_P).z;
        float rayEyeZ = -pos.z;
        // Compare ray depth to depth of pixel in depth buffer
        float dz = rayEyeZ - sceneEyeZ;
        
        half sign = FastSign(dz);
        binarySearch = binarySearch || (sign == -1) ? true : false; // Begin search if ray depth > scene depth
        if (binarySearch && FastSign(stepSize) != sign)
        {
            stepSize = stepSize * sign * 0.5;
            //thickness *= 0.5;
        }
        /*else if (!binarySearch)
        {
            stepSize = stepSize < STEP_DIST ? stepSize * stepScale + STEP_DIST * stepScale * 0.1 : stepSize * stepScale;
            thickness = thickness * stepScale;
        }*/
        
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

//bool BinaryRefinement(


void SSR_float(float2 screenPos, float3 pos_ws, float3 normal_ws, float3 viewDir_ws,
    float step, float stepScale, int maxSteps, float maxDist, float thickness, out float4 outColor, out float reflectionMask)
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
    bool hit = RayMarch(pos_vs, ray_vs, st, step, stepScale, maxSteps, maxDist, thickness, hitsUV);
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