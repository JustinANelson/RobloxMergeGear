---
name: merge-game-design
description: Game-design and economy guidance for merge games (merge board, tier chains, generators, income, offline earnings, rebirth, pacing, Roblox-policy-safe monetization, retention). Use when designing or tuning merge mechanics, items, rewards, or prices — not for plain coding tasks.
---
# Merge game design

## Core loop
Spawn/buy low-tier item → merge identical items → higher tier → higher tier earns more / unlocks content → spend to spawn more → expand space.

## Systems (server-authoritative)
- **Board:** fixed slots (`MaxSlots`); slot expansion is a key sink. Server stores `{ [slot]: { id, tier } }`.
- **Merge:** `canMerge(a, b)` = same chain, same tier, tier < maxTier → tier + 1. Pure function in `src/shared`; server re-runs it.
- **Spawners:** cooldown- or energy-based; cost `base * growth^n` (growth ≈ 1.07–1.15).
- **Income:** per-tier income should grow faster than spawn cost (≈ ×2–3 per tier) so merging beats buying.
- **Offline earnings:** capped hours, computed from `os.time()` delta on join, server-side only.
- **Rebirth:** reset board for a permanent multiplier once progress slows (first one ≈ 30–60 min).

## Tuning
- All numbers in `src/shared/Config/` (`Items.luau`, `Economy.luau`); generate tier tables from formulas.
- Pacing targets: first merge < 10 s, new chain < 5 min, first rebirth 30–60 min.
- Before changing curves, simulate with a pure Luau function (time → expected currency).

## Monetization (Roblox-policy-safe)
- Gamepasses: 2× income, auto-merge, extra slots, VIP. Dev products: currency packs, instant spawns, timer skips.
- Paid random items must show odds; prefer direct purchases.
- `ProcessReceipt` idempotent and persisted before returning `PurchaseGranted`.

## Retention
Daily streak rewards, timed free gifts, quests and a collection index, leaderboards (OrderedDataStore, refresh ≥ 60 s), group-join reward, friends multiplier.
