# BLINGO — Godot 4 Migration

A native cross-platform zombie squad shooter built with [Godot 4](https://godotengine.org/).

This is a ground-up migration of [BLINGO](https://blingo.pages.dev) from JavaScript/Three.js to Godot 4 using GDScript.

## Why Godot

| | Old (Electron/Web) | New (Godot 4) |
|---|---|---|
| Windows | ~150MB Chromium wrapper | ~40MB native binary |
| Android | WebView APK | Native ARM APK |
| iOS | Unsigned IPA | Native signed IPA |
| Linux | None | Native binary |
| Web | Cloudflare Pages | WebAssembly export |
| GPU | ANGLE/WebGL | Vulkan / OpenGL ES 3 |
| Audio | Web Audio API | Godot AudioServer |
| Multiplayer | PeerJS WebRTC | ENet UDP (lower latency) |

## Structure

```
blingo-godot/
├── scenes/         # .tscn scene files
├── scripts/        # .gd GDScript files
├── assets/         # models, textures, audio
├── shaders/        # .gdshader files
├── project.godot   # project config
└── export_presets.cfg
```

## Building Locally

1. Install [Godot 4.3+](https://godotengine.org/download)
2. Open `project.godot`
3. Run from the editor, or export via **Project → Export**

## CI/CD

Every push to `main` builds Windows, Linux, Android, and Web in GitHub Actions and attaches them to a release.
