# Dev Launcher

Press **F5 / Run Project** with Main Run Args empty. The launcher is the project's startup scene; gameplay is not instantiated until a mode is selected. Running Reef.tscn directly with F6 still runs that scene directly.

| Button | Existing mode arguments |
| --- | --- |
| Play Fish | `--play-fish` (normal single-player path) |
| Fish vs AI Fisher | `--host --role=fish --ai=fisher` |
| Fisher vs AI Fish | `--host --role=fisher --ai=fish` |
| AI vs AI | `--ai-vs-ai` |
| AI vs AI Director Preview | `--ai-vs-ai --capture --director` (realtime; no movie) |
| Record Director Fight | `--ai-vs-ai --capture --director`, with Movie Maker engine arguments |

Seed and Fish/Fisher skill fields apply as optional existing command arguments. Seed accepts 0–2147483646; skill accepts 0.6–1.0, matching the existing fight configuration. Leave fields blank for existing defaults. Filename, seed and both skill fields are remembered in `user://dev-launcher.cfg`, separate from player save data.

All buttons start a fresh standalone Godot process using `OS.get_executable_path()` and `OS.create_process()`, then quit the launcher only if process creation succeeds. This keeps existing OS-argument-based systems unchanged. Close the standalone game window normally when finished; the original editor run/debug session has ended. Mode flags prevent the child from reopening the launcher.

Record creates `user://captures/` and passes:

```text
--path <absolute project folder> --resolution 1920x1080 --write-movie <absolute output.avi> --fixed-fps 60 -- --ai-vs-ai --capture --director [--seed=N] [--fish-skill=N] [--fisher-skill=N]
```

Each token/path is a separate process argument, never a shell command or manually quoted string. The current project path is resolved from `res://`. Filename input is sanitized for Windows, reserved device names are prefixed, `.avi` is appended, and collisions receive `_002`, `_003`, etc. Existing files are not overwritten. Movie Maker is enabled only in the child process; there is no encoder or recording implementation in the launcher. The capture-event CSV continues independently under `user://capture-events/`.

The menu displays the resolved movie folder. From Godot use **Project > Open User Data Folder**, then `captures`. Launch.ps1 redirects user data into the workspace's `work/app-data/Godot/app_userdata/PELAGIC — Fish Controller/`; ordinary editor runs use normal Godot user data.

Explicit mode/test/batch/preview/network arguments skip the menu and load Reef directly. Seed, skill and shot options by themselves are modifiers, so do not suppress the menu. A direct engine `--write-movie` launch also skips it. Existing command-line examples remain valid.

The previously saved editor movie arguments were checkpointed in local commit `531daff` before clearing Main Run Args. The existing fight_test.avi was left untouched.

Validation: import/parse plus one headless menu initialization/argument check. No movie, child gameplay process or fight batch was run.


## Unattended one-fight recording

The launcher's Record button now adds `--capture-one-fight` and `--capture-max-seconds=300` (adjustable 30–3600 seconds). After a 3-second lead-in, it enables the existing AI test-bait priority, without teleporting bait or changing combat. A missed hook set may retry. Landing, thrown hook, line break, spool-out or disconnect schedules a normal Godot shutdown 3 seconds later so Movie Maker finishes its file. The total simulation-time cap stops a take even if no hook-up or fight outcome occurs. Timeout is logged without inventing a gameplay result. Movie Maker may take longer in wall-clock time than the footage duration.

A blank recording seed is generated, displayed and saved as the launcher's last seed; clear it for another random take. Ordinary Director Preview remains unlimited and keeps normal targeting. For a bounded preview or manual Movie Maker invocation use these user arguments:

```text
-- --ai-vs-ai --capture --director --seed=12345 --capture-one-fight --capture-max-seconds=300
```

The recording launcher additionally supplies an engine `--quit-after` frame cap at (limit + 5) * 60 as a startup safeguard. Capture CSVs include `test-bait-priority`, the normal outcome, and `capture-complete` or `capture-timeout`. Movies and event logs retain their existing folders. No fight mechanics or normal AI modes are changed.
