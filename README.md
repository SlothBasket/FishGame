# Pelagic — feeding grounds milestone

Double-click **Play.cmd** to build and play. **Open Editor.cmd** opens the project in the supplied Godot .NET editor. In Godot, F6 runs the current scene and F5 runs the game.

## Controls

| Input | Action |
|---|---|
| Mouse | Orbit camera; forward swimming follows the view, including depth |
| W / S | Swim forward / reverse along the camera direction |
| A / D | Swim sideways relative to the camera |
| Space / Ctrl | Rise / dive in world space |
| Shift | Hold for faster swimming |
| Hold left mouse | Charge a bite (movement slows while charging) |
| Release left mouse | Lunge toward the crosshair and eat bait along the dash |
| R | Return to spawn and cancel the attack; keep food earned |
| Esc | Release / capture cursor |
| Left click, when cursor is free | Capture cursor; this first click does not bite |

Release movement to coast to a stop. The fish turns toward its velocity with pitch and yaw, keeping roll at zero. The camera moves independently and uses a spring arm to retract at obstacles. The sandy seabed, rocks, hoops, surface ceiling, and outer walls collide. Plants and small coral are decorative. The hoops are practice targets, with no scoring yet.

## Eating

Thirty bait live in six groups around the hoops. Minnows swim in groups (+1 food), shrimp twitch and kick (+2), and squid pulse through the water with animated tentacles (+3). All use original procedural art. Their movement collides with terrain.

Tap left mouse for about a 3 m bite. Hold for up to 1.4 seconds for a 15 m lunge, then release. A ring around the crosshair shows charge and recovery. Aim is locked when released, using the object under the camera crosshair. During the dash, every bait touched by the swept bite volume is eaten; ordinary swimming and post-dash coasting do not eat. Solid terrain stops the dash and blocks bites. There is a 0.45-second recovery; start a fresh press after recovery to charge again. Escape, losing focus, and reset cancel charging without firing.

Eaten bait shrink into the mouth, with a jaw animation, bubble burst, and food notice. The fish grows 1% per food, capped at 1.6× for this prototype; its body collision radius grows too. This is provisional growth tuning. Bait respawn at their group's home after eight seconds. Restart the game for a fresh food total.

## Editing

Godot **4.7.2 .NET**, C#, .NET **10 SDK**. The standard Godot edition cannot run this C# project. A portable .NET editor lives in `../../work/godot-dotnet/`; the launchers use it without changing the installed editor. Local NuGet packages are provided by that runtime. Keep the enclosing workspace together when moving the project, or install Godot .NET and update `NuGet.Config` to its `GodotSharp/Tools/nupkgs` directory (or nuget.org), then import `project.godot`.

Select FishPlayer in `Scenes/FishPlayer.tscn` to tune movement plus FullChargeTime, MinimumLungeDistance, MaximumLungeDistance, LungeSpeed, and BiteCooldown in the Inspector.

- `FishInput.cs`: input command and movement calculation, independent of keyboard and camera.
- `FishPlayer.cs`: local input, collisions, model orientation, and camera controls.
- `FishVisual.cs`: procedural fish and fin/tail animation; replace with a model facing local -Z.
- `FishFeeding.cs`: charge/dash/recovery, swept bite with terrain occlusion, rewards, and growth.
- `BaitMotion.cs`: shared motion commands and interchangeable live/controlled drivers.
- `BaitActor.cs` / `BaitVisual.cs`: shared bait body, animation, and single-consumer bite callback.
- `BaitSchool.cs`: populations and respawns; `FeedingHud.cs` / `FeedingBurst.cs`: feedback.
- `Reef.cs`: deterministic practice environment, HUD, and engine integration checks.

## Fishermen and multiplayer foundation

The intended game is fish players competing to eat and grow, alongside human fishermen imitating live prey with bait and skillful rod control. Hook fights are a later milestone.

`IBaitDriver` produces `BaitCommand(Direction, Effort, Twitch)`. `LiveBaitDriver` generates natural motion; `ControlledBaitDriver.Command` can later be fed by rod inputs or server commands. Both use the same movement motor, species limits, visual mesh, animation, and bite detection. Bait visuals never inspect whether their source is live or a fisherman, so there is no automatic color/label/animation giveaway.

Set `BaitActor.Source = BaitSource.Fisherman` and assign a `ControlledBaitDriver` before adding the actor. Subscribe to `Bitten` to begin a future hook/fight session. Fisherman bait triggers the same consume interaction but awards no nutrition. The bait visual is removed after swallowing, so a future fight session should retain its own player/rod state. The current playground spawns live bait only; rod control, fake bait spawning UI, fight mechanics, and networking are not implemented yet.

`TryBite` gates duplicate rewards in this local prototype. In multiplayer, the server must own movement validation, bite claims, nutrition, growth, respawns, and hook events; clients should send intent and display replicated results. The existing separation is a starting point, not implemented network authority.

## Validation

Run `powershell -ExecutionPolicy Bypass -File .\Launch.ps1 -Test` for the original controller checks plus short/full-charge lunges, cancellation, multiple meals, single-consumer rewards, growth, high-speed sweeps, terrain occlusion, identical live/controlled motion, fisherman bite callbacks, and respawning. `FeedingChecks.cs` runs actual physics in a clear fixture area.

Run the engine with `-- --capture`, `-- --charge-preview`, or `-- --feeding-preview` to save rendered previews beside the project. The latter two temporarily drive the fish and add stationary bait for reproducible visual checks; normal play does not use that setup.

Godot C# setup reference: https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html
