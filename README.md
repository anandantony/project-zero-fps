# Project 0 — Zero FPS 🔫

**Project 0** is a lightweight Godot 4.5 first-person shooter prototype focused on fast iteration, modular gameplay components, and simple arena-style maps. This repository contains scenes, scripts, and assets to run and extend a basic FPS experience.

---

## ✅ Quick start

**Requirements**
- Godot Engine 4.5 (or compatible 4.x builds)
- Optional: Godot export templates to build standalone binaries

Run locally:
1. Open the project folder in Godot (open `project.godot`).
2. Press **Play** (F5) to run the current main scene or open `maps/training/dm_map_1.tscn` and run it.

> **Tip:** Autoloads `GameManager` and `InputRouter` are configured in `project.godot` for quick iteration.

---

## 🎮 Gameplay & Controls

- Move: **W A S D / Gamepad left stick**
- Jump: **Space / Gamepad face down**
- Sprint: **Shift / Gamepad left stick press**
- Look: **Mouse / Gamepad right stick**

The input map lives in `project.godot` and can be modified via Project Settings → Input Map.

---

## 🔧 Project structure (high-level)

- `maps/` — level scenes (e.g., `maps/training/dm_map_1.tscn`)
- `assets/models/` — 3D models and GLTF/GLB imports
- `prefabs/` — reusable scene assets (e.g., `world_env.tres`)
- `characters/` — `player_controller.tscn`
- `scripts/` — core GDScript files (e.g., `player_controller.gd`, `game_manager.gd`)
- `addons/proto-csgs/` — CSG helper addon used for quick prototyping

---

## 🛠 Development notes

- Use the included `scripts/` as starting points for player movement, spawners (`spawner.tscn`), and game state (autoload `GameManager`).
- Keep physics and rendering settings in `project.godot` in sync when editing core behavior.

---

## Contributing

Contributions are welcome. Recommended workflow:
1. Create a feature branch: `git checkout -b feat/my-feature`
2. Add scenes / scripts and test in the editor
3. Open a PR with a short description of changes

Please follow simple, self-explanatory commits and include small, focused PRs.

---

## License

This project is distributed under the **GNU General Public License v3.0 (GPL-3.0)**. See `LICENSE` for details.

---

## Acknowledgements

- Built using Godot Engine 4.5
- proto-csgs for rapid prototyping
