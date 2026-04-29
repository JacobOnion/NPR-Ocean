using System.IO;
using UnityEngine;
[System.Serializable] 
public class ShaderParams
{
    // 0.21
    public float waveCount = 16;
    public float ssrStepCount = 32;
    public float rippleCount = 64;
    // etc.
}


public class ParameterManager : MonoBehaviour
{
        private string path;
        public Material waterMat;

        void Start()
        {
            path = Path.Combine(Application.persistentDataPath, "params.json");
            
            if (!File.Exists(path))
                File.WriteAllText(path, JsonUtility.ToJson(new ShaderParams(), true));
            else
            {
                Debug.Log("Doesnt exist");
            }
            //Apply();
        }

        void Update()
        {
            //if (Input.GetKeyDown(KeyCode.R)) Apply();
        }

        void Apply()
        {
            var p = JsonUtility.FromJson<ShaderParams>(File.ReadAllText(path));
            waterMat.SetFloat("_Wave_Count", p.waveCount);
            waterMat.SetFloat("_max_steps", p.ssrStepCount);

            Debug.Log("[Params] Reloaded");
        }
}
