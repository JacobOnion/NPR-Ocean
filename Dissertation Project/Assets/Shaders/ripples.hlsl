#ifndef RIPPLES_INCLUDED
#define RIPPLES_INCLUDED
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"

#define RIPPLE_COUNT 16
float4 RippleData[RIPPLE_COUNT]; // X, Y: pos, Z: radius, W: mass
float time_elapsed = 0;


void Ripples_float(
    float2 pos,
    float height,
    float3 normal,
    float time,
    float ripple_speed,
    float ripple_width,
    float ripple_amplitude,
    out float out_height,
    out float3 out_normal
)
{
    out_height = height;
    out_normal = normal;
    float x_normal = 0.0;
    float z_normal = 0.0;
    #define PI 3.1415926535f

    time_elapsed += unity_DeltaTime;
    
    for (int i = 0; i < RIPPLE_COUNT; i++)
    {
        float wavelength = RippleData[i].z * ripple_width;
        float freq = 2.0 * PI / wavelength;
        
        float radius = RippleData[i].z;

        float dist = distance(pos,  float2(RippleData[i].x, RippleData[i].y));

        float amplitude = RippleData[i].w * ripple_amplitude / (dist + 1);

        float phase = dist * freq + time * ripple_speed;
        
        // Wave shaping formula
        float s = exp(sin(phase)) - 1.0;

        out_height += s * amplitude;
        
        
    }
    
    

   
}


#endif
