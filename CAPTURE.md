# Cinematic capture

Use Godot Movie Maker with the existing AI-vs-AI spectator. The project viewport and window remain 1920x1080. Capture hides HUD/help, debug statistics, result/counter notices, test-bait markers, and spectator gesture labels. World visuals, particles, stun stars, boat, rod, line and audio remain. There are no automatic cuts or gameplay changes.

From Windows Command Prompt (create the output folder first):

```bat
"C:\Users\Sloth\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "C:\Users\Sloth\Documents\Codex\2026-09-13\make\outputs\FishGame" --resolution 1920x1080 --write-movie "C:\Users\Sloth\Documents\Codex\capture.avi" --fixed-fps 60 --quit-after 3600 -- --ai-vs-ai --capture --seed=12345 --shot=fisher
```

This records 3600 frames (60 seconds at 60 fps). Remove `--quit-after 3600` for manual duration; close the game normally to finish writing. Movie Maker writes AVI directly; no custom encoder is used. Do not use headless mode for filming. Use distinct output names for each take.

For an editor-launched clean preview, use these Main Run Args (no movie is written):

```text
-- --ai-vs-ai --capture --seed=12345 --shot=fish-side
```

## Shots and filming controls

| Key | Shot | View |
| --- | --- | --- |
| 1 | fisher | Existing boat/rod view |
| 2 | fish | Existing following fish view |
| 3 | free | Existing free camera; WASD move, Q/E down/up, hold RMB and move mouse to look |
| 4 | wide | Tracks the midpoint and separation of Fish and boat |
| 5 | fish-side | Broadside tracking view |
| 6 | fish-rear | Wider, higher rear tracking view |

Capture defaults to fisher; normal spectator defaults to free. Shots are also available without capture. `FightSpectator.set_shot(name, instant=true)` selects presets programmatically and returns false for an unknown name. `instant=false` eases the camera position toward the new shot. Free preserves its current position on selection. No preset sends actor input or consumes simulation randomness.

Use the same seed, game revision, 60 fps and launch options for another angle of the same seeded session; change only shot/output filename. `--fight-seed=N` is accepted as an alias in spectator sessions, but the ambient spectator setup is different from an isolated batch encounter, so a batch seed alone does not reproduce that batch's opening state. Seeding covers encounter RNG, both AI drivers and bait population; cross-version/platform bit-exact physics is not promised. Without a seed, normal randomized play is preserved.

The old screenshot-and-exit option is now `--preview-capture`; feeding/charge preview flags retain their existing behavior. `--capture` itself no longer saves a PNG or quits after two seconds.

Validation for this first pass is import/parse only; no movie or fight was run.
