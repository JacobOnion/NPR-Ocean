using System;
using System.Collections;
using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;

public class ContactDetector : MonoBehaviour
{
    public const int MAX_RIPPLES = 16;
    [SerializeField] private Material oceanMat;
    //public Vector4[] ripples = new Vector4[MAX_RIPPLES];
    // X, Y: pos, Z: radius, W: mass
    private int currentRipple = 0;
    [SerializeField] private float ampPerMass;
    [SerializeField] private float minAmplitude;
    [SerializeField] private float maxAmplitude;
    [SerializeField] private float rippleLifetime;
    [SerializeField] private ParticleSystem splashParticles;
    [SerializeField] private float initSplashSize;
    [SerializeField] private float splashSizePerMass;
    [SerializeField] private float maxSplashSize;


    struct Ripple
    {
        public Vector2 center;
        public float radius;
        public float amplitude;
        public float startTime;
        public bool active;
    }

    Ripple[] ripples = new Ripple[MAX_RIPPLES];
    
    //[SerializeField] public List<Vector4> rippleDataList = new List<Vector4>(MAX_RIPPLES);
    //private readonly List<float> rippleStartTimesList = new List<float>(MAX_RIPPLES);

    private readonly Vector4[] rippleDataList = new Vector4[MAX_RIPPLES];
    private readonly float[] rippleStartTimesList = new float[MAX_RIPPLES];
    /*private void Start()
    {
        
            var data = new Vector4[] {
                new Vector4(-3, 0, 1f, 100f),
                new Vector4( 3, 0, 1f, 100f)
            };
            var times = new float[] { Time.time, Time.time };
            oceanMat.SetVectorArray("_RippleData", data);
            oceanMat.SetFloatArray("_RippleStartTimes", times);
            oceanMat.SetFloat("_RippleCount", 2f);

    }*/

    private void OnTriggerEnter(Collider other)
    {
        Debug.Log("ocean collision");

        StartCoroutine(CreateRipple(other));
    }

    IEnumerator CreateRipple(Collider other)
    {
        yield return new WaitForSeconds(0f);
        Rigidbody object_rb = other.GetComponent<Rigidbody>();
        if (object_rb == null) yield break;
        Vector2 position = new Vector2(object_rb.position.x, object_rb.position.z);
        float amp = object_rb.mass * ampPerMass;
        amp = Mathf.Clamp(amp, minAmplitude, maxAmplitude);
        // ADD VELOCITY FOR AMPLITUDE
        float radius = object_rb.GetComponent<Renderer>().bounds.extents.magnitude;
        int index = currentRipple % MAX_RIPPLES;
        ripples[index] = new Ripple{center = position, radius = radius, amplitude = amp, startTime = Time.time, active = true};
        currentRipple++;

        ParticleSystem newSplash = Instantiate(splashParticles, object_rb.position, splashParticles.gameObject.transform.rotation);
        newSplash.startSpeed =  Mathf.Clamp(initSplashSize + object_rb.mass * splashSizePerMass, initSplashSize, maxSplashSize);
    }
    

    private void Update()
    {
        //rippleDataList.Clear();
        //rippleStartTimesList.Clear();

        float now = Time.time;
        int activeCount = 0;

        for (int i = 0; i < MAX_RIPPLES; i++)
        {
            if (!ripples[i].active) continue;
            float age = now - ripples[i].startTime;
            if (age > rippleLifetime)
            {
                ripples[i].active = false;
                continue;
            }
            Debug.Log(i);
            // Pack as: (x, y, radius, amplitude)
            /*rippleDataList.Add(new Vector4(
                ripples[i].center.x,
                ripples[i].center.y,
                ripples[i].radius,
                ripples[i].amplitude
            ));
            rippleStartTimesList.Add(ripples[i].startTime);*/
            
            
            int dst = activeCount++;
            rippleDataList[dst] = new Vector4(
                ripples[i].center.x,
                ripples[i].center.y,
                ripples[i].radius,
                ripples[i].amplitude
            );
            rippleStartTimesList[dst] = ripples[i].startTime;

            if (activeCount >= MAX_RIPPLES) break;
        }

        // Pad the rest deterministically (helps GPU caches & avoids undefined reads)
        for (int i = activeCount; i < MAX_RIPPLES; i++)
        {
            rippleDataList[i] = Vector4.zero;
            rippleStartTimesList[i] = -1f; // negative so shader "continue;"
        }
        Shader.SetGlobalVectorArray("_RippleData", rippleDataList);
        Shader.SetGlobalFloatArray("_RippleStartTimes", rippleStartTimesList);  // Maybe dont need this?
        Shader.SetGlobalInt("_RippleCount", activeCount);
        
    }
    
    
#if UNITY_EDITOR
    private void OnDrawGizmosSelected()
    {
        Gizmos.color = Color.cyan;
        for (int i = 0; i < MAX_RIPPLES; i++)
        {
            if (!ripples[i].active) continue;
            Gizmos.DrawWireSphere(new Vector3(ripples[i].center.x, transform.position.y, ripples[i].center.y), 0.2f);
        }
    }
#endif
}
