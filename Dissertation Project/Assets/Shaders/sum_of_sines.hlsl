#ifndef WAVES_INCLUDED
#define WAVES_INCLUDED

float2 hash2_11(float n)
{
    float2 p;
    p.x = frac(sin(n * 127.1) * 43758.5453);
    p.y = frac(sin((n + 1.0) * 311.7) * 43758.5453);
    return p * 2.0 - 1.0;
}

void Sum_of_Sines_float(
    float2 pos,
    float time,
    float amplitude,
    float wavelength,
    float amp_scale,
    float freq_scale,
    float num_waves,
    out float height,
    out float3 normal
)
{
    height = 0.0;
    float x_normal = 0.0;
    float z_normal = 0.0;
    #define PI 3.1415926535f


    /*const int WAVE_COUNT = 5;

    float2 dirs[WAVE_COUNT] = {
        normalize(float2( 1,  0)),
        normalize(float2( 0,  1)),
        normalize(float2( 1,  1)),
        normalize(float2(-1,  1)),
        normalize(float2(0.7, 0.7))
    };*/
    /*float2 dirs[num_waves];
    for (int i = 0; i < num_waves; i++)
    {
        dirs[i] = normalize(hash2_11(i));
    }*/

    //float freqs[WAVE_COUNT]  = { 0.6, 0.8, 1.1, 0.4, 10.0 };
    //float speeds[WAVE_COUNT] = { 0.5, 0.7, 0.6, 0.4, 1.0 };

    float freq = 2.0 * PI / wavelength; // Freq i guess?
    float ds = 0;

    for (int i = 0; i < num_waves; i++)
    {
        float2 dir = normalize(hash2_11(i));
        
        float phase = (dot(dir, pos) + ds) * freq  // Add previous wave's derivative for domain warping
                    + time;
        
        // Wave shaping formula
        float s = exp(sin(phase)) - 1.0;

        height += s * amplitude;

        ds = exp(sin(phase));
        float dx =  freq * dir.x * cos(phase) * ds;
        x_normal += dx * amplitude;

        float dz =  freq * dir.y *  cos(phase) * ds;
        z_normal += dz * amplitude;

        // Fractional brownian motion
        amplitude *= amp_scale;
        freq *= freq_scale;
    }
    normal = normalize(float3(-x_normal, 1, -z_normal));
}


#endif
