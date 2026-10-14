# Halloween compatibility patch — 2026-10-14

Main entry remains `HzReyzn Hub.lua`; the extensionless compatibility entry also uses it.

- The previous embedded red intro and `HzReyzn_Loading.client.lua` were removed. The Hub starts `HzReyzn_Halloween.client.lua`, with an owner tied to the current Hub instance. Re-execution cancels the previous intro and its sound. A failed intro download opens the Hub after a bounded wait.
- The Halloween intro keeps its embedded title, background, fog and looping audio. The progress rail is 16 design pixels high, with a traveling reflection, a light at its leading edge, restrained embers and inward neon fades. The percentage is a single unboxed text label. Completion still waits for a click/tap, then fades the screen and audio.
- Halloween is the initial theme on every execution and the first Settings option. All six themes remain available. HZ monograms, buttons, borders, panel lights, launcher, FPS display and the managed Fly window follow the chosen palette. Minimize, restore and close use a short local neon bloom.
- The Hub and Fly share one owner-counted NoFall controller. It masks only downward Y velocity after simulation and restores it before the next simulation, preserving normal falling motion and horizontal movement. It never yields in a physics callback, never restores a sample onto a different character, and yields to seated characters, PlatformStand and the flight controller. Changes made by another controller to Y take priority over restoration.
- Flight remembers an enabled flight across respawns, binds late or replaced roots, and cancels stale animation work by generation. R6 uses the character's native animations as a fallback. Missing/restricted animation assets do not prevent flight controls from operating.
- Opening Fly again from the Hub focuses the existing controller. Closing/re-executing the Hub closes the Fly instance it owns. The standalone Fly entry continues to work independently.
- Antifling retains collision protection but suspends velocity recovery during flight. Float, water platforms and infinite jump yield to flight; wall-only noclip can coexist. Feature choices remain selected for when normal movement resumes. Speed and Gravity restore their previous values only when those properties still match the value applied by this Hub.

## Validation

Compiled the Hub, Flight, standalone Halloween loader and shared controller with the upstream Luau compiler. Six deterministic mock-engine scenarios passed:

1. NoFall shared owners, physical velocity restoration, respawn and competing movement.
2. Flight death/respawn, late root replacement, duplicate execution and owner cleanup.
3. Theme selection, minimize/restore bloom, simultaneous features and close cleanup.
4. Loader reaches 100%, percentage has no box, audio fades with dismissal.
5. Closing the owner cancels an unfinished loader and cleans up its sound.
6. The actual Hub and actual loader work together; re-execution retires the previous owner.

Run `python tests/run.py /path/to/luau`. These tests check script behavior with mocked engine services. They do not reproduce Roblox rendering, network ownership or game damage rules.

## In-game acceptance checks

- On mobile and PC, verify the supplied artwork/audio load, progress reaches 100%, and a later tap opens the Hub once.
- Switch each theme and minimize/restore/close. Confirm the palette matches and no old intro reappears.
- Enable Fly plus No FallDamage, Antifling, Float and WalkOnWater; die twice, then disable/re-enable Flight. Confirm the new character moves and the retained options resume.
- Verify fall protection against the current Natural Disaster Survival damage implementation. It is client-side and cannot guarantee protection against server-enforced damage.

External scripts under NOT MINE are still fetched from their authors. Their internals are not isolated or patched by this change. At validation time their URLs returned HTTP 200 except the Telekinesis Pastebin URL, which returned HTTP 403 from the verification environment. That access problem is separate from the maintained Hub/Fly lifecycle fixes.

The loader's artwork/audio require `writefile` and `getcustomasset`/`getsynasset`, as before. In Studio, configure Roblox asset IDs. No Roblox client or Studio was available for a real gameplay or visual test.

Engine references: [RunService](https://create.roblox.com/docs/reference/engine/classes/RunService), [Humanoid](https://create.roblox.com/docs/reference/engine/classes/Humanoid).
