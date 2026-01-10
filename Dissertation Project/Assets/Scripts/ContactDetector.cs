using System;
using Unity.Mathematics;
using UnityEngine;

public class ContactDetector : MonoBehaviour
{
    public const int MAX_RIPPLES = 16;
    [SerializeField] private Material oceanMat;
    //public Vector4[] ripples = new Vector4[MAX_RIPPLES];
    // X, Y: pos, Z: radius, W: mass
    private int currentRipple = 0;

    struct Ripple
    {
        public Vector2 center;
        public float radius;
        public float objectMass;
        public float startTime;
    }

    Ripple[] ripples = new Ripple[MAX_RIPPLES];
    
    private void OnTriggerEnter(Collider other)
    {
        Debug.Log("ocean collision");
        
        Rigidbody object_rb = other.GetComponent<Rigidbody>();
        float2 position = new float2(object_rb.position.x, object_rb.position.z);
        float mass = object_rb.mass;
        float radius = object_rb.GetComponent<Renderer>().bounds.extents.magnitude;
        int index = currentRipple % MAX_RIPPLES;
        ripples[index] = new Ripple{center = position, radius = radius, objectMass = mass, startTime = Time.time};
        //oceanMat.SetVectorArray("RippleData", ripples);
        //oceanMat.SetVectorArray("pos", ripples);
    }
}
