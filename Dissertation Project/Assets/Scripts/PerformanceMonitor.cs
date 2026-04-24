using System.Collections.Generic;
using System.IO;
using UnityEngine;

public class FrameTimeMonitor : MonoBehaviour
{
    [SerializeField] private int framesToCapture = 3000;
    [SerializeField] private int warmupFrames = 250;
    [SerializeField] private string label = "test";

    private int frameCount = 0;
    private bool warming = true;
    private bool done = false;

    private double totalFrameTime = 0;
    private double totalGpuTime = 0;
    private double totalCpuTime = 0;

    private readonly List<double> frameTimeSamples = new List<double>();
    private readonly List<double> gpuTimeSamples   = new List<double>();

    private readonly FrameTiming[] timings = new FrameTiming[1];

    private void Start()
    {
        FrameTimingManager.CaptureFrameTimings();
        Debug.Log($"[FrameMonitor] Warming up for {warmupFrames} frames...");
    }

    private void Update()
    {
        if (done) return;

        FrameTimingManager.CaptureFrameTimings();
        uint available = FrameTimingManager.GetLatestTimings(1, timings);

        if (warming)
        {
            frameCount++;
            if (frameCount >= warmupFrames)
            {
                warming = false;
                frameCount = 0;
                Debug.Log("[FrameMonitor] Warmup complete. Capturing...");
            }
            return;
        }

        if (available == 0) return;

        double ft = timings[0].cpuFrameTime;
        double gt = timings[0].gpuFrameTime;

        totalFrameTime += ft;
        totalGpuTime   += gt;
        totalCpuTime   += ft;

        frameTimeSamples.Add(ft);
        gpuTimeSamples.Add(gt);

        frameCount++;

        if (frameCount >= framesToCapture)
        {
            done = true;
            OutputResults();
        }
    }

    private static double Percentile(List<double> samples, double p)
    {
        var sorted = new List<double>(samples);
        sorted.Sort();
        // Nearest-rank method
        int rank = Mathf.CeilToInt((float)(p / 100.0 * sorted.Count));
        rank = Mathf.Clamp(rank, 1, sorted.Count);
        return sorted[rank - 1];
    }

    private void OutputResults()
    {
        double avgFrameTime = totalFrameTime / framesToCapture;
        double avgFps       = 1000.0 / avgFrameTime;
        double avgGpu       = totalGpuTime / framesToCapture;
        double avgCpu       = totalCpuTime / framesToCapture;

        double p95Frame = Percentile(frameTimeSamples, 95);
        double p99Frame = Percentile(frameTimeSamples, 99);
        double p95Gpu   = Percentile(gpuTimeSamples,   95);
        double p99Gpu   = Percentile(gpuTimeSamples,   99);

        string result =
            $"Label:            {label}\n" +
            $"Frames captured:  {framesToCapture}\n" +
            $"\n--- Frame Time (ms) ---\n" +
            $"Avg:  {avgFrameTime:F3}\n" +
            $"P95:  {p95Frame:F3}\n" +
            $"P99:  {p99Frame:F3}\n" +
            $"\n--- FPS ---\n" +
            $"Avg:  {avgFps:F1}\n" +
            $"\n--- GPU Time (ms) ---\n" +
            $"Avg:  {avgGpu:F3}\n" +
            $"P95:  {p95Gpu:F3}\n" +
            $"P99:  {p99Gpu:F3}\n";

        Debug.Log("[FrameMonitor] Results:\n" + result);

        string path = Path.Combine(Application.persistentDataPath, $"frametimes_{label}.txt");
        File.WriteAllText(path, result);
        Debug.Log($"[FrameMonitor] Saved to {path}");
    }
}