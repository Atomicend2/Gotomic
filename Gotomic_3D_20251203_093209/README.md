# PhysicsSimPrototype

This project is a Godot 4.5 prototype demonstrating dynamic physics simulation within a mobile-optimized framework, adhering strictly to the FLEX-100 generation protocol.

## Project Structure

The project follows a standard Godot folder hierarchy:

*   **scenes/**: Contains all `.tscn` files for game levels, UI, player, etc.
    *   `Main.tscn`: The primary entry point for the game.
    *   `Player.tscn`: The player character's scene.
    *   `ui/UIManager.tscn`: Contains the user interface elements.
    *   `prefabs/PhysicsObject.tscn`: Reusable physics objects.
*   **scripts/**: Holds all `.gd` GDScript files.
    *   `global/game_manager.gd`: Autoloaded global script for managing game state.
    *   `player_controller.gd`: Handles player movement and interaction.
    *   `physics_object.gd`: Script for dynamic rigid bodies.
    *   `ui_manager.gd`: Manages UI logic.
*   **models/**: Placeholder `.obj` files for basic meshes.
    *   `cube.obj`: Simple cube mesh.
    *   `plane.obj`: Simple plane mesh.
*   **audio/**: Intended for audio resources (currently empty due to generation constraints).
*   **textures/**: Intended for texture resources (currently empty due to generation constraints, uses procedural colors).

## Entry Point

The main scene for the project is `res://scenes/Main.tscn`. This scene loads the player, UI, and several physics objects.

## Core Features Implemented

*   **Player Controller**: A basic first-person controller (`CharacterBody3D`) with movement (WASD), jumping (Space), and camera look.
*   **Dynamic Physics**: Multiple `RigidBody3D` instances configured to interact with each other and the environment, demonstrating dynamic physics.
*   **Interaction/Shooting**: The player can "shoot" a raycast that applies an impulse to physics objects.
*   **Mobile Optimization**: Project settings are configured for mobile rendering (Mobile renderer preset, limited lights, no heavy post-processing).
*   **Autoloaded GameManager**: A global script accessible from anywhere to manage game-wide state.
*   **Clean Code**: Adheres to GDScript 2.0 best practices, including type annotations, `@onready`, and signal-based communication.

## Manual Asset Replacement / Achieving "High-Fidelity"

Due to strict generation constraints (FLEX-100 protocol rules F22/F23 prohibiting images/sounds/complex models), this project uses simple placeholder assets and colors. To achieve a "high-fidelity" look and feel:

1.  **3D Models**: Replace `models/cube.obj` and `models/plane.obj` with your own detailed `.glb` or `.obj` models. Update the `MeshInstance3D` nodes in `Player.tscn`, `PhysicsObject.tscn`, and `Main.tscn` to use your custom `ArrayMesh` or `BoxMesh` with `Mesh` set to your imported model.
2.  **Textures & Materials**: Create `StandardMaterial3D` resources with `albedo_texture`, `metallic_texture`, `roughness_texture`, and `normal_texture` for your models. Assign these materials to the `MeshInstance3D` nodes.
3.  **Complex Rendering Effects (Manual Steps)**:
    *   **PBR Materials**: Once you have textures, enable PBR properties (metallic, roughness) in your `StandardMaterial3D`.
    *   **Advanced Lighting**: Add more `DirectionalLight3D`, `OmniLight3D`, or `SpotLight3D` nodes as needed, but be mindful of mobile performance (Godot's mobile renderer has limitations on real-time lights). Consider baking lightmaps for static geometry for optimal performance.
    *   **Post-Processing**: In `Main.tscn`, select the `WorldEnvironment` node. You can enable more effects like Bloom, Screen Space Reflection (SSR), or Ambient Occlusion (SAO) under the `Environment` settings. **CAUTION**: These effects are very performance-intensive on mobile devices. Use them sparingly or only for high-end targets.
    *   **Custom Shaders**: For truly complex effects (water, fire, specific visual styles), you'll need to write custom `ShaderMaterial` resources.
4.  **Audio**: Import your `.ogg` or `.wav` sound files into the `audio/` folder. Assign these `AudioStream` resources to the `stream` property of the `AudioStreamPlayer3D` node in `Player.tscn` (e.g., for gunshots).

This prototype provides a solid, performant foundation. By replacing the placeholder assets and carefully introducing more complex rendering features, you can evolve it into a high-fidelity experience.