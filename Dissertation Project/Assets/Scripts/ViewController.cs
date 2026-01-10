using UnityEngine;
using UnityEditor.SceneManagement;
using UnityEngine.SceneManagement;

public class ViewController : MonoBehaviour
{
    [SerializeField]
    private Vector3 position1, position2;
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
    }
}
