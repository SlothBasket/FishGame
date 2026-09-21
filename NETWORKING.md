# Local multiplayer foundation

Single-player still starts with `Launch.ps1` or `Play.cmd`. Multiplayer starts a separate session; it does not convert an in-progress single-player world.

From PowerShell in this folder:

```powershell
.\Launch.ps1 -HostGame
.\Launch.ps1 -JoinIP 127.0.0.1
```

Use the host's LAN IP instead of `127.0.0.1` on another computer. Both copies must use the same project revision. Optional `-Port 24567` selects the UDP port on both instances. Allow the host's Godot application through Windows Firewall for LAN testing. Internet direct-IP additionally requires UDP forwarding/reachability; no NAT traversal or matchmaking is included. Godot's [high-level multiplayer documentation](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html) describes the transport requirements.

The engine arguments are `-- --host --port=24567` and `-- --join=127.0.0.1 --port=24567`. These work when launching Godot directly. F10 disconnects; a departing client only removes its owned fish. The disconnected window freezes with a status message; close/relaunch it to join again or play offline. Closing the host ends the listen-server session. No host migration. The host accepts up to seven clients.

## Ownership and authority

`NetworkSession` lives at the same `/root/Reef/NetworkSession` path on both peers (the scene root's existing name is retained). `players[peer_id]` is the authoritative assignment of role and fish entity. Peer 1 is the host. Every joined peer receives a separate fish, independent food and growth. Peer IDs are stable during a connection; reconnecting creates a new identity/fish. Node/RPC authority always remains with the server; owning input does not grant transform authority.

The current network role is **Fish + Fish**. No multiplayer fisherman test mode is exposed. The single-player `LureTestController` still combines local input/cameras with spawning/boat operations; adding the fisher role next requires splitting those operations into a server-owned driver and local camera adapter. The explicit role field provides the ownership slot, but Fish + Fisher is not ready yet. Existing `ReelSpeed`, `PlayerLiveDriver`, bait motors and cast behavior remain available for that next step. No fight system is implemented.

Host-only work includes fish motor/feeding collision, food/growth, BaitSchool, AI, anchor migration, mortality, arrivals, random size/behavior, gull catches and despawning. Clients instantiate fixed local visual replicas, never a BaitSchool. Bait replicas disable physics/process and never construct an AI driver. Fish replicas retain local camera updates but return before simulation/feeding. Terrain remains the existing fixed-seed local level on both peers so camera collision has matching geometry.

`FishPlayer` adds `networked`, `locally_owned` and `replica` flags. Unowned fish never read local events or activate a camera. Network fish use the same authoritative `FishInput`/FishFeeding motor. Network reset/boat test shortcuts are deliberately unavailable. Device bindings remain in GameControls; the network carries no key/button identities. Surface effects and appendage animation stay local.

## Protocol and tuning

Only ENet construction in `NetworkSession.start()` is transport-specific. Other logic uses SceneMultiplayer RPCs and sender identity; a future MultiplayerPeer adapter can replace connection setup without changing motors/ownership.

| Setting | Default | Meaning |
|---|---:|---|
| `input_hz` | 30 | Client input submissions per second |
| `fish_snapshot_hz` | 20 | Authoritative fish updates per second |
| `bait_snapshot_hz` | 10 | Moving world-actor updates per second |
| `input_timeout` | 0.35 s | Cancel held attack and neutralize stale remote controls |

Fish snapshots contain position, heading, velocity, food, eaten count, charge/dash/cooldown/flash/grace state, boost and airborne flags. Cameras are never serialized. Growth is reconstructed from server food using the unchanged curve. Client replicas, including the locally owned fish, interpolate toward successive server positions over one snapshot interval; there is no client prediction, rollback or lag compensation. Higher latency is therefore noticeable. Tune rates/interpolation deliberately during manual playtests.

Bait snapshots use packed floats in batches of at most 12 actors (17 floats per actor, 816 payload bytes). Each record has server-assigned monotonic actor ID, position, visual rotation, velocity, current visual scale, animation speed/twitch, wing pose/power, action and server timestamp. Out-of-order records are discarded per actor. This avoids treating different unreliable batches as one ordered stream. Settled carcasses stop sending transforms after their reliable final pose. Current population remains approximately 142 live bait, with the existing bounded carcasses; no dense benchmark increase.

Reliable channel 0 announces player addition/removal and bait creation/lifecycle/removal. New clients receive the current catalog, including carcasses and currently carried/claimed prey. Unknown-ID motion snapshots are ignored until reliable creation arrives. `actor_spawned` and `tree_exiting` hook registration/removal; `bitten` immediately sends claimed state. Other lifecycle changes are detected on the 10 Hz world update. The client never independently frees a swallowed/caught replica; it waits for server removal. Two feeding sweeps still resolve through the server's existing single-claim guard.

## RPC security boundary

`fish_intent(sequence, PackedFloat32Array axes, flags)` is the **only any_peer RPC**. It is host-only at execution and obtains `multiplayer.get_remote_sender_id()`. It accepts no target entity identifier. The sender must exist in the server role registry as a fish. Sequence numbers must increase within signed 32-bit range; duplicate/out-of-order input is ignored. The payload must contain exactly six finite floats and a three-bit flag mask. Throttle/steering/vertical are clamped by FishInput; aim components are clamped, nonzero and normalized. A per-peer token bucket accepts at most 60 requests/s with a four-request burst. Stale input cancels charging instead of firing an attack on disconnect.

All other RPCs are authority-only: `player_event`, `fish_snapshot`, `bait_event`, `bait_snapshot`. No client can submit position, food, spawn/despawn, arbitrary properties, NodePaths, resource paths, method names or executable data. Object decoding is explicitly disabled and server relay is disabled. Fixed scenes/classes are selected locally. Packet parsing/transport flood protection still depends on Godot/ENet; this is not Internet account authentication or a denial-of-service protection service. An IP-reachable development host allows connections without accounts.

## Focused validation and remaining manual checks

`Launch.ps1 -Check` imports scripts. A bounded optional `--network-smoke` argument on **both** host and client instances supplies different fish intents, verifies both fish move with replicas present, then disconnects the client and confirms the host continues. It exits within 12 seconds and cannot be invoked by an RPC. It does not populate a stress world or run a performance tour.

Manual checks: controller input, delayed/lossy LAN behavior, feeding competition and growth display, late joins after mortality/gull catches, surface breaches, interpolation feel, and long-running actor turnover. Cosmetic meal text/bubble events are not explicitly replicated; authoritative food, feeding animation, prey state and surface effects are. No session persistence or reconnect resume. Do not begin fight work until the fish foundation is stable and fisherman intent/camera separation is completed.
