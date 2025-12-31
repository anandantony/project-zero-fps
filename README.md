# Project Zero FPS 🎯

A minimal, modular first-person controller and small FPS project built with Godot Engine (4.5). This repository contains a playable prototype with input mapping, camera and player controllers, a spawn system, simple AI/objects, and useful editor prefabs and addons to accelerate FPS development.

---

## Quick demo ✅

- Open this project in Godot **4.5** and press Play (F5) to run the current main scene.

> NOTE: The project uses the **Jolt Physics** backend and the included `proto-csgs` addon for quick geometry prefabs.

---

## Features ⚙️

- First-person movement (walk, sprint, jump) and mouse/gamepad look
- Camera controller with smooth motion and interpolation
- Spawn system for reusable spawn points
- Modular `scripts/` and `prefabs/` for rapid prototyping
- Input mapped for keyboard + mouse and gamepad

---

## Requirements 🧩

- Godot Engine **4.5** (project configured for 4.5 features)
- Export templates for your target platform (if exporting builds)

---

## Getting started 🔧

1. Clone the repo:

   ```bash
   git clone https://github.com/anandantony/project-zero-fps.git
   cd project-zero-fps
   ```

2. Open the folder in Godot 4.5.
3. Run the project (F5) or open a scene from `prefabs/` or `maps/` to test specific levels.

Tips:
- Autoloads: `GameManager` and `InputRouter` are defined in the project settings (see `project.godot`).
- If you add new scenes or scripts, save them under `prefabs/`, `maps/`, or `scripts/` to keep structure consistent.

---

## Controls 🎮

- Move: **W / A / S / D**
- Jump: **Space**
- Sprint: **Shift**
- Look: **Mouse**
- Gamepad: left stick to move, right stick to look, bottom face button to jump, left stick press for sprint

---

## Project structure 🔍

- `addons/` — third-party or custom editor tools (includes `proto-csgs`)
- `assets/` — static content used in scenes
- `maps/` — example levels (e.g., `training/dm_map_1.tscn`)
- `prefabs/` — reusable scene assets (spawn points, world env, characters)
- `scripts/` — gameplay scripts (player_controller, camera_controller, game_manager, spawner, etc.)

---

## Contributing 🤝

Contributions are welcome! Please:
- Open an issue to discuss bigger changes
- Create focused pull requests with a clear description
- Follow existing coding style in `scripts/`

---

## License & Credits 📄

This project is available under the terms of the repository `LICENSE` file.

- `proto-csgs` addon included under its own `LICENSE.txt` (see `addons/proto-csgs/`)

---

## Contact / Notes ✉️

If you have questions or want to collaborate, open an issue or reach out in the repo.

Enjoy building! 🚀
