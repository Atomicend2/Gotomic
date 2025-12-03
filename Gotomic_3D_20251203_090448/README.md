# FPS Resource Manager Prototype

This is a prototype Godot 4.5 project demonstrating a mobile-optimized 3D FPS game with integrated resource management.

## Project Structure

The project follows a standard Godot folder hierarchy for clarity and maintainability:

*   **scenes/**: Contains all game scenes (`.tscn` files).
    *   `Main.tscn`: The primary entry point of the game.
    *   `Player.tscn`: Player character setup.
    *   `Enemy.tscn`: Enemy character setup.
    *   `Gun.tscn`: Player's weapon.
    *   `ResourceNode.tscn`: Interactive nodes for resource collection.
    *   `PlayerUI.tscn`: User interface elements (HUD, inventory).
    *   `ExplosionEffect.tscn`: Simple particle effect for feedback.
*   **scripts/**: All GDScript files (`.gd`). Organized into subfolders:
    *   `core/`: Global autoload singletons (GameManager, ResourceManager, InventoryManager).
    *   `player/`: Player-related scripts.
    *   `enemy/`: Enemy AI scripts.
    *   `world/`: Scripts for world objects (resource nodes).
    *   `ui/`: Scripts for managing UI elements.
*   **models/**: Placeholder `.obj` models. These are procedurally generated simple shapes.
    *   `player.obj`
    *   `enemy.obj`
    *   `gun.obj`
    *   `resourcenode.obj`
    *   `floor.obj`
*   **textures/**: Placeholder textures. Currently uses `GradientTexture2D` for mobile optimization.
    *   `placeholder_albedo.tres`
*   **ui/**: UI-specific resources (e.g., custom themes, textures for UI elements if any).
*   **audio/**: Placeholder `.ogg` audio files.
    *   `shoot_sound.ogg`
    *   `hit_sound.ogg`
    *   `pickup_sound.ogg`
*   **prefabs/**: Reusable scene components (e.g., specific enemy variants, weapon types). (Not extensively used in this basic prototype but the folder is present).

## Entry Points and Key Components

*   **`Main.tscn`**: This is the scene that the game starts with. It instantiates the player, environment, and UI.
*   **Autoloads (Singletons)**:
    *   `GameManager.gd`: Manages overall game state, score, game over conditions, and global events.
    *   `ResourceManager.gd`: Handles the player's resource counts and provides methods for adding/removing resources.
    *   `InventoryManager.gd`: Manages the player's inventory items.
*   **Player Interaction**:
    *   `PlayerController.gd`: Handles character movement and input processing.
    *   `CameraLook.gd`: Manages camera rotation based on touch/mouse input.
    *   `GunSystem.gd`: Implements the shooting mechanics using `RayCast3D`.
    *   `ResourceNode.gd`: Defines how resources are collected via player interaction.
*   **Enemy AI**:
    *   `EnemyAI.gd`: Implements a basic state machine for enemy behavior (Idle, Patrol, Chase, Attack).

## Mobile Optimization Considerations

*   **Low-Poly Models**: All generated `.obj` models are extremely simple with low polygon counts.
*   **Baked Lighting**: The prototype uses a single `DirectionalLight3D` and a `WorldEnvironment` for global illumination, simulating baked lighting by avoiding complex real-time lights.
*   **Texture Compression**: `GradientTexture2D` is used as a placeholder, which is highly efficient. `project.godot` is configured to import ETC2/ASTC for mobile.
*   **Mobile Renderer Preset**: The `project.godot` file specifies the "mobile" rendering method.
*   **Limited Post-Processing**: No heavy post-processing effects are enabled.
*   **Performance-focused GDScript**: Scripts avoid heavy operations in `_process` and prioritize efficient node access.

## How to Run

1.  Open the project in Godot Engine 4.5.
2.  Run `Main.tscn` (usually by pressing F5).
3.  Use W,A,S,D or joystick (if connected/mobile) to move.
4.  Mouse or touch input to look around.
5.  Left-click or touch the screen to shoot.
6.  Press 'E' to interact with `ResourceNode` objects.

## Manual Asset Replacement

*   **Models**: Replace `.obj` files in `models/` with your own `.glb`, `.obj`, or `.gltf` models. Ensure they are low-poly for mobile. Update scenes to use your new `Mesh` resources.
*   **Textures**: Replace `textures/placeholder_albedo.tres` with actual image textures (e.g., `.png`, `.webp`). Ensure they are compressed and resolution-appropriate for mobile.
*   **Audio**: Replace `.ogg` files in `audio/` with your sound effects.
*   **Animations**: For player/enemy characters, add `AnimationPlayer` nodes and link your custom animations. Update scripts (`PlayerController.gd`, `EnemyAI.gd`) to play these animations.