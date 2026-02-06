#ifndef SSR_INPUTS_INCLUDED
#define SSR_INPUTS_INCLUDED

// Core URP helpers
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// If you want to use URP's normal sampling helper:
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
// (DeclareNormalsTexture.hlsl provides SampleSceneNormals(uv) which decodes octahedral normals)

// --- Our globals published by the Renderer Feature ---
// Scene color (copied to avoid read/modify hazards by the feature)
TEXTURE2D_X(_SSR_SceneColor);
SAMPLER(sampler_SSR_SceneColor);

// Depth copy (URP _CameraDepthTexture or active depth alias)
// We'll convert to linear01.
TEXTURE2D_X(_SSR_DepthTexture);
SAMPLER(sampler_SSR_DepthTexture);

void SSR_float(float2 pos, float3 normal_ws, float3 viewDir_ws, out float4 outColor)
{
    float2 st = UnityStereoTransformScreenSpaceTex(pos);  // test w -wo
    float4 sceneCol = SAMPLE_TEXTURE2D_X(_SSR_Scene_color, sampler_SSR_SceneColor, st);  // Get scene color at current pixel
    
    float3 reflectedPos_ws = reflect(-viewDir_ws, normal_ws);
    
    float3 reflectedPos_vs = mul(unity_WorldToCamera, reflectedPos_ws);
    
    
}

#endif // SSR_INPUTS_INCLUDED