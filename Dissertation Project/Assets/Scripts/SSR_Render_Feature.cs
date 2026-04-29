using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class SSRInputsRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        // BeforeRenderingTransparents runs after the skybox and after URP's own
        // CopyColor pass, so _CameraOpaqueTexture and _CameraDepthTexture are
        // both guaranteed to be valid by the time we run.
        public RenderPassEvent injectionPoint = RenderPassEvent.BeforeRenderingTransparents;
        public string normalsId = "_SSR_NormalsTexture";
    }

    class SSRInputsPass : ScriptableRenderPass
    {
        readonly Settings settings;
        readonly int normalsNameId;
        readonly int cameraNormalsNameId;

        public SSRInputsPass(Settings s)
        {
            settings = s;
            renderPassEvent = s.injectionPoint;

            // Ask URP to produce depth and normals. In deferred this is a no-op
            // for normals (gBuffer[2] already exists), but it keeps the feature
            // safe if you ever switch to forward.
            ConfigureInput(ScriptableRenderPassInput.Depth | ScriptableRenderPassInput.Normal);

            normalsNameId = Shader.PropertyToID(settings.normalsId);
            cameraNormalsNameId = Shader.PropertyToID("_CameraNormalsTexture");
        }

        class PassData { }

        public override void RecordRenderGraph(RenderGraph rg, ContextContainer frameData)
        {
            var res = frameData.Get<UniversalResourceData>();

            using (var builder = rg.AddRasterRenderPass<PassData>("SSR Expose Normals", out var passData))
            {
                builder.AllowPassCulling(false);

                // In deferred, gBuffer[2] is normals + smoothness. Alias it to
                // both _CameraNormalsTexture (so standard URP shaders work) and
                // our own _SSR_NormalsTexture (for the water shader).
                var g = res.gBuffer;
                if (g != null && g.Length > 2 && g[2].IsValid())
                {
                    builder.SetGlobalTextureAfterPass(g[2], cameraNormalsNameId);
                    builder.SetGlobalTextureAfterPass(g[2], normalsNameId);
                }
                else if (res.cameraNormalsTexture.IsValid())
                {
                    // Forward fallback — URP produces this when ConfigureInput
                    // requests Normal.
                    builder.SetGlobalTextureAfterPass(res.cameraNormalsTexture, normalsNameId);
                }

                builder.SetRenderFunc((PassData d, RasterGraphContext ctx) => { /* no draw; just globals */ });
            }
        }
    }

    public Settings settings = new Settings();
    SSRInputsPass pass;

    public override void Create() => pass = new SSRInputsPass(settings);

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        => renderer.EnqueuePass(pass);
}






/*using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

public class SSRInputsRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent injectionPoint = RenderPassEvent.BeforeRenderingTransparents; // run after GBuffer in deferred or after forward opaques
        public bool copySceneColor = true;               // copy to avoid read-while-write hazards
        public string sceneColorId = "_SSR_SceneColor";  // global name for Shader Graph
        public string depthId = "_SSR_DepthTexture";
        public string normalsId = "_SSR_NormalsTexture";
    }

    class SSRInputsPass : ScriptableRenderPass
    {
        readonly Settings settings;
        readonly int sceneColorNameId, depthNameId, normalsNameId;

        public SSRInputsPass(Settings s)
        {
            settings = s;
            renderPassEvent = s.injectionPoint;

            // Request depth & normals so URP produces them in forward (depth prepass / depth-normal prepass).
            ConfigureInput(ScriptableRenderPassInput.Depth | ScriptableRenderPassInput.Normal);  // URP still honors this in RG mode. [3](https://docs.unity3d.com/6000.0/Documentation/Manual/urp/accessing-frame-data.html)[4](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@15.0/api/UnityEngine.Rendering.Universal.ScriptableRenderPass.ConfigureInput.html)

            sceneColorNameId = Shader.PropertyToID(settings.sceneColorId);
            depthNameId = Shader.PropertyToID(settings.depthId);
            normalsNameId = Shader.PropertyToID(settings.normalsId);
        }

        class PassData { }

        public override void RecordRenderGraph(RenderGraph rg, ContextContainer frameData)
        {
            var ur = frameData.Get<UniversalRenderingData>();
            var res = frameData.Get<UniversalResourceData>(); // frame textures like active color/depth, gbuffer, etc. [3](https://docs.unity3d.com/6000.0/Documentation/Manual/urp/accessing-frame-data.html)[5](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@17.0/api/UnityEngine.Rendering.Universal.UniversalResourceData.html)

            // --- Scene Color ---
            TextureHandle colorSrc = res.activeColorTexture; // whatever the camera is currently rendering into. [3](https://docs.unity3d.com/6000.0/Documentation/Manual/urp/accessing-frame-data.html)
            TextureHandle colorForSampling = colorSrc;

            if (settings.copySceneColor)
            {
                // Copy active color to a temporary texture (safe to sample later).
                var desc = rg.GetTextureDesc(colorSrc);       // get a correct descriptor from the source handle. [6](https://discussions.unity.com/t/introduction-of-render-graph-in-the-universal-render-pipeline-urp/930355/602)
                desc.name = "SSR_SceneColorCopy";
                desc.clearBuffer = false;
                var copy = rg.CreateTexture(desc);

                rg.AddCopyPass(colorSrc, copy, passName: "SSR Copy SceneColor"); // RenderGraph copy pass. [1](https://discussions.unity.com/t/introduction-of-render-graph-in-the-universal-render-pipeline-urp/930355/113)
                colorForSampling = copy;
            }

            using (var builder = rg.AddRasterRenderPass<PassData>("SSR Expose Buffers", out var passData))
            {
                builder.AllowPassCulling(false);  //testing this
                // Make scene color globally accessible to shaders after this pass. [2](https://docs.unity3d.com/6000.3/Documentation/Manual/urp/render-graph-create-global-texture.html)
                builder.SetGlobalTextureAfterPass(colorForSampling, sceneColorNameId);

                // --- Depth ---
                // Prefer the resolved _CameraDepthTexture if it exists; fall back to the active depth attachment. [5](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@17.0/api/UnityEngine.Rendering.Universal.UniversalResourceData.html)
                var depthTex = res.cameraDepthTexture.IsValid() ? res.cameraDepthTexture : res.activeDepthTexture;
                if (depthTex.IsValid())
                    builder.SetGlobalTextureAfterPass(depthTex, depthNameId);

                // In URP deferred, GBuffer[2] = normals + smoothness; map to _CameraNormalsTexture + our alias. [7](https://docs.unity3d.com/6000.0/Documentation/Manual/urp/rendering/g-buffer-layout.html)[8](https://github.com/Unity-Technologies/Graphics/blob/master/Packages/com.unity.render-pipelines.universal/Samples~/URPRenderGraphSamples/GlobalGbuffers/GlobalGbuffersRendererFeature.cs)
                var g = res.gBuffer;
                if (g != null && g.Length > 2 && g[2].IsValid())
                {
                    builder.SetGlobalTextureAfterPass(g[2], Shader.PropertyToID("_CameraNormalsTexture"));
                    builder.SetGlobalTextureAfterPass(g[2], normalsNameId);
                }
                
                builder.SetRenderFunc((PassData d, RasterGraphContext ctx) => { /* no draw; just globals */// });
/*            }
        }
    }

    public Settings settings = new Settings();
    SSRInputsPass pass;

    public override void Create() => pass = new SSRInputsPass(settings);

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        => renderer.EnqueuePass(pass);
}*/