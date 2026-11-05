# Bunny Guardian: Rise of the Rabbit — Prototype

A first playable Roblox prototype. Built with simple parts and placeholder models.

## Open it
- **Quickest:** open `Bunny Guardian Prototype.rbxlx` in Roblox Studio, press **Play**.
- **With Rojo (live sync):** `rojo serve` in this folder, then connect from the Rojo Studio plugin.
- Rebuild the place file after editing code: `rojo build -o "Bunny Guardian Prototype.rbxlx"`.

## Controls
| Input | Ability |
|---|---|
| Left click / F | **Carrot Throw**: fast single-target carrot (free) |
| Q | **Hurricane Kick**: spin kick that launches a piercing green wind blade (30 mana) |
| E | **Ear Cyclone**: wind cyclone around you that slows and chips nearby enemies |
| On-screen buttons | Same abilities, fired where the rabbit faces (touch friendly) |

## Gameplay
- Foxes come from the dens at the garden edges and attack the **burrow** in the middle.
- 10 waves. On **wave 10**, **the Great Eagle** boss circles the burrow, dive-bombs it and calls in fox minions.
- Kills give coins; every cleared wave gives a bonus to all players.
- Upgrades (right panel): Carrot Power, Kick Power, Mana Pool, Repair Burrow.
- If the burrow reaches 0 HP it's game over. Win or lose, the game restarts after 10 s.

## Layout
```
ReplicatedStorage/BunnyGuardian
  Shared/Config            -- all tuning numbers (waves, abilities, upgrades, enemies)
  Remotes/UseAbility, BuyUpgrade, Notify
  GameState (Configuration) -- replicated attributes: Wave, Status, BurrowHealth, Boss…
ServerScriptService/BunnyGuardian
  GameServer (Script)       -- wave loop and wiring
  Modules/MapBuilder        -- garden, burrow, fence, fox dens (Workspace.BunnyGuardianMap)
  Modules/EnemyService      -- fox and eagle models, movement, damage, slow
  Modules/AbilityService    -- carrot, hurricane kick, ear cyclone (server authoritative)
  Modules/PlayerDataService -- coins, mana and regen, upgrade levels (player attributes)
  Modules/UpgradeService    -- validated upgrade purchases
  Modules/CharacterService  -- turns players into heroic bunnies (ears, tail, scarf, cape)
StarterPlayer/StarterPlayerScripts/BunnyGuardianClient
  ClientMain (LocalScript)
  Modules/HUD               -- wave counter, burrow and boss bars, mana, coins, buttons
  Modules/AbilityInput      -- keybinds and mouse aiming
Workspace
  BunnyGuardianGround, BunnyGuardianSpawn
  BunnyGuardianMap          -- generated at runtime
```
Tuning tip: to test the boss quickly, set `Config.Waves.BossWave` and `Total` to 1–2.
