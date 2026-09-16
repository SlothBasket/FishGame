# Project workflow

- Use GDScript for gameplay and keep CODE_GUIDE.md aligned with movement rules, defaults, formulas, and tuning locations.
- After a substantial validated feature batch, create a descriptive local Git commit. The user wants these milestones for a future devlog/version browser. Do not push unless explicitly asked.
- Preserve milestone history; do not amend or rewrite old checkpoints. Keep MILESTONES.md as a readable index by commit hash or unique commit subject.
- Validate relevant movement with Launch.ps1 -Test, import with -Check, and use graphical performance runs for population/rendering changes. Run benchmarks without concurrent engine tests so timings are comparable.
- F9 saves timestamped CSV/JSON diagnostics to user://hitch-reports. Keep this available and documented.
