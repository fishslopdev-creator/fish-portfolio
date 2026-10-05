# How it works

Design notes on the trickier parts of the code: what each system does and why it was built that way.

- [Fish physics: why `PlaneConstraint`](#fish-physics-why-planeconstraint)
- [The luck formula](#the-luck-formula)
- [Who gets paid, and batched payouts](#who-gets-paid-and-batched-payouts)
- [Collision groups](#collision-groups)
- [Network ownership](#network-ownership)
- [Upgrades and the debounce bug](#upgrades-and-the-debounce-bug)
- [Data saving](#data-saving)
- [Client UI structure](#client-ui-structure)
- [Performance notes](#performance-notes)

---

## Fish physics: why `PlaneConstraint`

Hundreds of unanchored fish on one floor cause problems. They stack into piles, climb on top of each other, and ride up and over the scooper wall the player pushes them with.

Anchoring them isn't an option, because then they can't be pushed. So once a fish **lands**, it gets two constraints (`spawnFish` / `settle` in `FishGameServer`):

| Constraint | Attached between | Effect |
|---|---|---|
| `PlaneConstraint` | a world attachment at floor height (`FLOOR_Y`), and an attachment at the bottom of the fish | The bottom of the fish can only move **within the floor plane**. It can slide in any direction but can never lift off, so it can't climb a pile or a scooper. |
| `AlignOrientation` (`PrimaryAxisParallel`, rigid) | the fish's up axis | Keeps the fish lying flat. It can still turn (yaw) but can't tip over. |

A `PlaneConstraint`'s plane normal is the attachment's *primary axis* (its X axis), not its Y axis. That's why the floor attachment is built with `CFrame.fromMatrix(pos, Vector3.yAxis, Vector3.zAxis)`, which makes world-up its X axis.

Before a fish is locked down, `clearOfScoopers` checks that it isn't landing inside a scooper wall. If it is, the fish is slid out to the closer side; otherwise it would get locked underneath the wall.

**Letting go:** every 0.15s a settled fish raycasts straight down (`groundBelow`). When there's no ground under it (it was pushed over the hole or off the edge), `release` turns both constraints off and gives it a downward kick. A fish that has been lying still is *asleep* in the physics engine and won't start falling by itself.

The client does the same check for fish it's simulating (`FishEffects.lua`, `dropFishOverHole`). Without it, a pushed fish would slide across the hole until the server noticed, a round trip later.

## The luck formula

```lua
weight = fish.Weight * luck ^ (step * LuckPower)
step   = min(rarityIndex - 1, MaxLuckStep)   -- Common = 0, Uncommon = 1, Rare = 2, ...
```

- Every fish has a base `Weight`, so with luck = 1 the odds are just the base weights.
- Luck multiplies each fish's weight by `luck ^ (step * LuckPower)`. **Common fish (step 0) are never boosted**, and every rarity tier above that gets a bigger boost than the one below. Because the roll is weighted, boosting the rare fish also makes the commons *relatively* less likely, without ever rewriting the base table.
- `LuckPower` controls how strong luck feels. `MaxLuckStep` caps the exponent, so the rarest tiers don't explode at very high luck.

Example with `LuckPower = 0.5` and luck = 4: each tier step multiplies by `4 ^ 0.5 = 2`. Uncommon weights are ×2, Rare ×4, Epic ×8, and so on. The roll is then a standard weighted pick: take a random number in `[0, total)` and subtract each weight until it drops to 0 or below.

The luck that goes into the roll is `Stats.Luck` (raised by rebirths and upgrades) × the event boost × the boss multiplier × the chaos-command multiplier.

## Who gets paid, and batched payouts

Every fish part's `Touched` records the **last player to touch it** and when. When a fish lands in the hole, the money goes to:

1. the last player who touched it, if that was in the last 20 seconds, otherwise
2. the nearest player within 60 studs, otherwise
3. the player it spawned for.

The ring is square, so "is it in the hole" uses the larger of the X and Z distances from the centre (`inHole`), not the straight-line distance.

Collected fish aren't paid out one by one. They go into `pending[collector]`, and `payOut()` runs once per tick. So 30 fish pushed in together become **one** money change and **one** `FishCollected` remote, and the client shows one big "+$" and combo instead of 30 small ones. The same pass marks first-time catches (`Discovered`) so the client can show the "NEW FISH!" popup.

## Collision groups

| Group | Used for | Collides with |
|---|---|---|
| `FallingFish` | fish while they drop | the floor, but not other fish or scoopers, so they can't land on top of something |
| `PushItems` | fish lying on the floor | other fish and scoopers |
| `Scoopers` | the scooper tools | fish only |
| `Characters` | player characters | not fish, so players can't climb piles; only the scooper pushes |
| `Bridges` | bridge parts | players, but fish fall straight through |

## Network ownership

- **While falling**, the server owns the fish (`SetNetworkOwner(nil)`), so the landing and the floor lock happen in one place.
- **Once settled**, ownership goes back to automatic (`SetNetworkOwnershipAuto`). The player pushing a fish then simulates it on their own machine, so pushing feels instant instead of lagging a round trip behind.

## Upgrades and the debounce bug

`BuyUpgrade` is a `RemoteFunction`, and the client can fire it many times a second (holding the button buys repeatedly). Every purchase is validated on the server: the id must be a string, the upgrade must exist, the player must have enough money and the upgrade can't be maxed. A per-player `buying` flag stops two purchases running at once.

**The bug:** the original code set `buying[player] = true` and *then* did `upgrades[id]`. Indexing a missing child throws, so if that value hadn't loaded yet the function errored part-way, `buying[player]` was never cleared, and that player could never buy another upgrade for the rest of the session.

**The fix:** look the value up with `upgrades:FindFirstChild(id)` and return early if it's missing, *before* taking the debounce. Nothing between setting and clearing the flag can throw any more.

## Data saving

`PlayerData.server.lua` owns everything that persists. It builds the `Stats`, `Upgrades` and `Discovered` folders the other scripts use, and saves them back.

- **One table, filled from defaults.** A save is one table per player (`Player_<UserId>`). On load it's merged over `DEFAULT`, so older saves get any newly added fields automatically.
- **`Stats` is parented last.** Other scripts `WaitForChild("Stats")` and treat it as "the save has loaded", so the upgrades, discoveries and attributes are all in place first.
- **Never overwrite a failed load.** If the DataStore can't be read after 5 tries (with 1, 2, 4 and 8 second backoff), the player is kicked rather than given an empty profile. Otherwise the next autosave would wipe their real progress. In Studio it falls back to default data that is never saved.
- **Session lock.** The save records which server (`game.JobId`) has the player open. If they leave and instantly join another server, the new server waits for the old one to finish saving. A server that no longer owns the lock can't write over newer data. A lock older than 10 minutes counts as stale (that server crashed).
- **`UpdateAsync`, not `SetAsync`.** Saves read the current value first, which is what makes the lock check possible.
- **When it saves:** every 2 minutes, when the player leaves, and on shutdown (`BindToClose` saves everyone in parallel and waits). Saves for one player never overlap, so a late autosave can't re-take the lock after the final save released it.
- **Remotes are validated.** `SaveSettings` checks that both volumes are numbers (and not NaN) and clamps them to 0–1.

## Client UI structure

The UI used to be one 2,570-line LocalScript. It even had to be wrapped in `(function() ... end)()` blocks in places, because a single Luau function can only hold 200 local variables. It's now split into modules:

```
UIController/
  init.client.lua   starts everything in order, then slides the HUD in
  Core/             building blocks shared by every feature
    Context         player, stat values, ScreenGui, Config, Remotes
    Util            tween, colour sequences, number formatting (1.2K, 3.4M ...)
    Screen          scales the UI to the screen size
    Sound           UI + 3D sounds with pitch variation and spam protection
    Buttons         hover / press bounce for every button
    Toasts          the short message at the top of the screen
    Menus           one-menu-at-a-time open/close, dim + blur, staggered intros
    VFX             sparkles, pop-up text, camera shake, animated decorations
    Celebration     the full-screen "PURCHASED!" / "NEW FISH!" popup (queued)
    ModelPreview    spinning 3D models in ViewportFrames
    WorldFX         stud debris, ring blasts, floating world text
    Rarity          rarity colour / order lookups
  Features/         one module per part of the game's UI, each with start()
```

Shared state lives on the module that owns it (`Menus.Open`, `Screen.Scale`, `Sound.Volume`, `WorldFX.GrassColor`), so there are no hidden globals. Feature modules don't depend on each other, only on `Core`.

## Performance notes

- The server's main loop runs at 20 Hz, not every frame.
- Settled fish only raycast for ground every 0.15s.
- The number of fish is capped per player (the `MaxFish` upgrade) and per server (`ServerCap`). At high spawn speeds, at most 6 fish spawn per player per tick, and the spawn timer can't build up a backlog.
- **One `Highlight` outlines every fish.** Roblox only renders about 31 Highlights at once, so one per fish wouldn't work. A single Highlight on the `Fish` model covers all of them.
- Client effects are capped: 220 weather particles at most, small collect bursts only for the first 25 fish in a batch, and repeated sounds are throttled.
