using UnityEngine;
using UnityEngine.SceneManagement;

public class ViewController : MonoBehaviour
{
    [SerializeField] private int pos = 0;
    [SerializeField]
    private Vector3[] positions;
    [SerializeField]
    private Vector3[] rotations;
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (Input.GetKeyDown("1"))
        {
            SceneManager.LoadScene(0);
        }

        if (Input.GetKeyDown("2"))
        {
            SceneManager.LoadScene(1);
        }
        if (Input.GetKeyDown("3"))
        {
            SceneManager.LoadScene(2);
        }

        if (Input.GetMouseButtonDown(1))
        {
            pos += 1;
            if (pos == positions.Length)
                pos = 0;
            transform.position = positions[pos];
            transform.rotation = Quaternion.Euler(rotations[pos]);
        }
    }
}
