#ifndef RIPPLES_INCLUDED
#define RIPPLES_INCLUDED
//#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"

#define RIPPLE_COUNT 64
float4 _RippleData[RIPPLE_COUNT]; // X, Y: pos, Z: radius, W: mass
float _RippleStartTimes[RIPPLE_COUNT];


void CalculateHeight(float2 pos, float time, float ripple_speed,
    float ripple_wavelength,
    float ripple_width,
    float ripple_amplitude_scale,
    float ripple_growth,
    float ripple_time_decay,
    float ripple_dist_decay,
    out float h,
    out float2 normalXZ)
{
    #define PI 3.1415926535f
    h = 0;
    normalXZ = float2(0.0, 0.0);
    float freq = 2.0 * PI / max(ripple_wavelength, 1e-4);
    float invW2 = 1.0f / max(ripple_width * ripple_width, 1e-6f);
    
    ///int rippleCount = (int)round(_RippleCount);
    for (int i = 0; i < RIPPLE_COUNT; i++)
    {
        //if (i >= rippleCount) break; //UNCOMMENT
        // Unpack array
        float2 center = _RippleData[i].xy;
        float initRadius = _RippleData[i].z;
        float baseAmp = _RippleData[i].w;

        float t = time - _RippleStartTimes[i];  // may have issues with time not matching on CPU and GPU
        if (t < 0.0) continue;  // Skip inactive ripples
        
        //float d = distance(pos, center);  // Distance from water vertex to ripple origin
        float2 dp = pos - center;
        float d2 = dot(dp, dp);
        float d = sqrt(d2);
        
        float invd = (d > 1e-5f) ? rsqrt(d2) : 0.0f;
        float2 u   = dp * invd;

        
        float r = ripple_speed * t + initRadius;

        float radDist = d - r;

        float phase = radDist * freq;
        float s, c;
        sincos(phase, s, c);
        
        float ring = exp(- (radDist * radDist) / (2.0 * ripple_width * ripple_width)); // gaussian ring (look into it)
            
        float distDecay = exp(-ripple_dist_decay * d);
        float timeDecay = exp(-ripple_time_decay * t);
        
        float amp = baseAmp * ripple_amplitude_scale * ring * distDecay * timeDecay;

        float growth = 1 - exp(-t * ripple_growth);
        amp *= growth;
        //if (abs(s * amp) < 1e-5)
        //    continue;
        h += s * amp;

        float g_rad = freq * c + s * (-radDist * invW2 - ripple_dist_decay);
        float contrib = amp * g_rad;
        normalXZ += contrib * u;
    }
    //return h;
}

void Ripples_float(
    float2 pos,
    float height,
    float3 normal,
    float time,
    float ripple_speed,
    float ripple_wavelength,
    float ripple_width,
    float ripple_amplitude_scale,
    float ripple_growth,
    float ripple_time_decay,
    float ripple_dist_decay,
    out float out_height,
    out float3 out_normal
)
{
    float2 normalXZ;
    float rippleHeight = 0;
    
    CalculateHeight(pos, time, ripple_speed, ripple_wavelength,
        ripple_width, ripple_amplitude_scale, ripple_growth, ripple_time_decay,
        ripple_dist_decay, rippleHeight, normalXZ);
    
    out_height = height + rippleHeight;
    
    // Approximate gradient for normal via central differences
    // (small step in world units; tune as needed)
    /*float dx = 0.04;
    float dz = 0.04;

    float hL = CalculateHeight(pos + float2(-dx, 0.0), time, ripple_speed, ripple_wavelength,
        ripple_width, ripple_amplitude_scale, ripple_time_decay, ripple_dist_decay);
    float hR = CalculateHeight(pos + float2( dx, 0.0), time, ripple_speed, ripple_wavelength,
        ripple_width, ripple_amplitude_scale, ripple_time_decay, ripple_dist_decay);
    float hD = CalculateHeight(pos + float2(0.0, -dz), time, ripple_speed, ripple_wavelength,
        ripple_width, ripple_amplitude_scale, ripple_time_decay, ripple_dist_decay);
    float hU = CalculateHeight(pos + float2(0.0,  dz), time, ripple_speed, ripple_wavelength,
        ripple_width, ripple_amplitude_scale, ripple_time_decay, ripple_dist_decay);
    float dHx = (hR - hL) / (2.0 * dx);
    float dHz = (hU - hD) / (2.0 * dz);*/

    // Build a geometric normal from height field (assumes Y-up)
    float3 n = normalize(float3(-normalXZ.x, 1.0, -normalXZ.y));

    out_normal = normal;
    // Blend with base normal if you have other normal sources
    if (abs(rippleHeight) > 1e-3)
        out_normal = normalize(lerp(normal, n, 1.0));
    //out_normal = normal + n;
}

#endif
