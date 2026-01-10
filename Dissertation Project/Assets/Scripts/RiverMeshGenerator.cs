using System.Collections.Generic;
using BezierSolution;
using Unity.Mathematics;
using Unity.VisualScripting;
using UnityEngine;
using Plane = Unity.Mathematics.Geometry.Plane;

public class RiverMeshGenerator : MonoBehaviour
{
    public Material waterMaterial;
    [SerializeField] private GameObject surface_prefab;
    [SerializeField] private float border_precision;
    private BezierSpline riverSpline;
    private MeshFilter meshTarget;
    private MeshRenderer meshRenderer;

    private MeshFilter bedTarget;
    void Start()
    {
        Transform riverTransform = transform;
        riverSpline = riverTransform.Find("River Spline").GetComponent<BezierSpline>();
        Transform meshTransform = riverTransform.Find("Water Body");
        meshTarget = meshTransform.GetComponent<MeshFilter>();
        meshRenderer = meshTransform.GetComponent<MeshRenderer>();

        Transform bedTransform = riverTransform.Find("Riverbed");
        bedTarget = bedTransform.GetComponent<MeshFilter>();
        
        BuildMesh();
    }
    
    void BuildMesh()
    {
        List<Vector3> riverVertices = new List<Vector3>();
        List<Vector2> riverUVs = new List<Vector2>();
        List<int> riverTriangles = new List<int>();
        
        List<Vector3> bedVertices = new List<Vector3>();
        List<Vector2> bedUVs = new List<Vector2>();
        List<int> bedTriangles = new List<int>();
        
        Vector3 worldUp = Vector3.up;
        
        // Calculate initial river direction
        Vector3 initForward = riverSpline.GetTangent(0f);
        Vector3 initRight = Vector3.Normalize(Vector3.Cross(initForward, worldUp));
        Vector3 initUp = Vector3.Normalize(Vector3.Cross(initForward, initRight));
        Quaternion initRot = Quaternion.LookRotation(initForward, initUp);

        Vector3 initPoint = riverSpline.GetPoint(0f);
            
        riverVertices.Add(initPoint + (initRight * 3));
        riverVertices.Add(initPoint - (initRight * 3));
        
        riverUVs.Add(new Vector2(0f, 0f));
        riverUVs.Add(new Vector2(1f, 0f));
        
        // Find number of vertices needed in mesh, should be constant distance apart for any length spline
        //float riverLength = riverSpline.GetLengthApproximately(0f, 1f, 50f) * border_precision;
        //float  vertexIntervals = 1 / riverLength;
        float t = 0;
        float step = 1f / border_precision;
        float distance = 0;

        while (t < 1)
        {
            distance += step;
            //float currentDistance = vertexIntervals * i;
            Vector3 currentPos = riverSpline.MoveAlongSpline(ref t, step, 8);
            Vector3 forward = riverSpline.GetTangent(t).normalized;
            Vector3 right = Vector3.Cross(forward, worldUp).normalized;
            //Vector3 up = Vector3.Cross(forward, right).normalized;
            //Quaternion riverRot = Quaternion.LookRotation(forward, up);
            
            
            //Vector3 nextPoint = riverSpline.GetPoint(vertexIntervals * i);
            //Quaternion riverRot = GetRotationAtPoint(i * vertexIntervals);
            //Vector3 riverDir = riverRot * nextPoint; // Iffy line
            //Vector3 leftBorderDir = Vector3.Normalize(Vector3.Cross(riverDir, up));
            
            
            // Fill out VBOs
            riverVertices.Add(currentPos + (right * 3));
            riverVertices.Add(currentPos - (right * 3));
            
            riverUVs.Add(new Vector2(0f, distance));
            riverUVs.Add(new Vector2(4f, distance));
            
            riverTriangles.Add(riverVertices.Count - 4);
            riverTriangles.Add(riverVertices.Count - 2);
            riverTriangles.Add(riverVertices.Count - 1);
            
            riverTriangles.Add(riverVertices.Count - 4);
            riverTriangles.Add(riverVertices.Count - 1);
            riverTriangles.Add(riverVertices.Count - 3);

        }

        Transform meshContainer = meshTarget.transform; 
        
        // Convert vertices to local space
        for (int i = 0; i < riverVertices.Count; i++)
        {
            riverVertices[i] = meshContainer.InverseTransformPoint(riverVertices[i]);
        }
        
        Mesh riverMesh = new Mesh
        {
            vertices = riverVertices.ToArray(),
            uv = riverUVs.ToArray(),
            triangles = riverTriangles.ToArray()
        };
        riverMesh.RecalculateNormals();
        meshTarget.mesh = riverMesh;
        meshRenderer.material = waterMaterial;

        bedTarget.mesh = riverMesh;
        bedTarget.transform.Translate(0f, -0.6f, 0f);
    }

    Quaternion GetRotationAtPoint(float t)
    {
        Vector3 worldUp = Vector3.up;
        Vector3 forward = riverSpline.GetTangent(t);
        Vector3 right = Vector3.Normalize(Vector3.Cross(forward, worldUp));
        Vector3 up = Vector3.Normalize(Vector3.Cross(forward, right));
        Quaternion rot = Quaternion.LookRotation(forward, up);
        return rot;
    }
    
    void Update()
    {
        
    }
}
