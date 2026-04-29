# Stylised Water Renderer

A real-time stylised water renderer combining ocean simulation with non-photorealistic rendering techniques to recreate a 2D animation aesthetic.

<!-- TODO: replace with a screenshot or short GIF of the renderer in action -->
![Screenshot](Docs/screenshot.png)

This project accompanies the BSc Computer Science dissertation *"Using Non-Photorealistic Rendering Techniques to Create Efficient Real-Time Stylised Oceans"* (University of Leeds, School of Computing, 2026). The full write-up is included as [`dissertation.pdf`](Docs/dissertation.pdf).

## Overview

The renderer is implemented in Unity as a shader graph, and implements the techniques discussed in the dissertation methodology.

## Requirements

- **Unity** VERSION: 6000.3.1f1
- **Render pipeline:** URP
- **Platform:** Tested on Windows 11

## Running

There are two ways to run the project, depending on your needs.

### Quick demo (pre-built)

A standalone Windows build is included under [`../Build/`](../Build/). Run [`../Build/Dissertation_Project.exe`](../Build/Dissertation_Project.exe) to see the renderer running with the default scene and parameters.

> **Note:** the standalone build runs with fixed parameters and does not expose runtime tweaking. To adjust wave, foam, reflection, or stylisation settings, use the Unity editor (below). The build can also be unstable with SSR enabled for currently unknown reasons

### Full version (Unity editor)

1. Install Unity Hub and Unity 6000.3.1f1.
2. Clone or download this repository.
3. In Unity Hub, click **Add → Add project from disk** and select the project folder.
4. Open the project, then open [`Demo/Demo Scene.unity`](Demo/Demo%20Scene.unity).
5. Press **Play**.

Parameter tweaking is exposed via the Inspector on the water material and the `WaterController` component on the water object in the scene.

> **Note:** This project had issues with flickering in past versions. This is believed to have been fixed now, but if the problem appears, moving the position of the Main Camera a little should resolve it.

## Project structure

```
.
├── Assets/
│   ├── Scenes/          # Main demo scene
│   ├── Scripts/         # C# — wave update, parameter binding, camera
│   ├── Shaders/         # HLSL / ShaderLab — water surface, SSR, post
│   ├── Materials/
│   ├── Models/
│   ├── Textures/
│   ├── Sprites/
│   ├── Prefabs/
│   ├── Settings/        # Render pipeline settings
│   ├── Plugins/         # Third-party plugins
│   └── _Recovery/       # Unity auto-recovery (can be ignored)
├── Packages/            # Unity package manifest
├── ProjectSettings/     # Unity project settings
├── Build/               # Pre-built standalone demo
└── docs/                # Dissertation PDF, screenshots
```


## Author

Jacob Onion — sc23j2o@leeds.ac.uk
BSc Computer Science, University of Leeds, 2026
