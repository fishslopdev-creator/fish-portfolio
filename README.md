# Fish Portfolio

Scripts from my Roblox fish-pushing simulator, written in Luau.

**Game:** [Play on Roblox](https://www.roblox.com/games/103658829114616/Collect-Every-Fish)

Fish rain onto a sky island, and players push them into a ring-shaped hole with scooper tools to earn money. Players can buy upgrades, unlock better scoopers, rebirth, and take part in server-wide boss events.

## Scripts

### FishGameServer.server.lua
The main server script that runs the game loop.

- **Fish spawning** – weighted rarity rolls affected by each player's luck, with per-player fish limits, a server-wide cap, and spawn speed upgrades
- **Physics** – fish are locked flat onto the floor with `PlaneConstraint` and `AlignOrientation` once they land, so they can't pile up or climb over scoopers, and are released again when pushed over the hole or an edge
- **Collision groups** – fish fall through bridges, players walk through fish, and only scoopers push them
- **Collecting and payouts** – tracks who last pushed each fish and batches fish collected in the same moment into one payout, with multipliers and event boosts
- **Upgrades** – server-validated purchases with a debounce to prevent double-buying
- **Scooper progression** – automatically gives players the right scooper tier as they collect more fish
- **Boss event** – a giant animated fish that makes fish rain down for everyone for a limited time
- **Admin tools** – spawn fish, fling, swirl, storm and boss commands through a `BindableFunction`

### UIController.client.lua
The client-side UI controller.

- Animated stat counters with number abbreviation (K, M, B, T...)
- Shop, upgrade, rebirth, trail and settings menus
- Toast notifications, combo display and visual effects
- Sound effects with pitch variation and spam protection
- Built with `TweenService` and a shared config module

## Notes
Both scripts read from a shared `Config` module and remotes in `ReplicatedStorage`, which aren't included here.
