# Engine gotchas

## Replication
- Server → client replicates Instances/properties; client changes do NOT replicate (except own character physics & animations).
- `ServerStorage`/`ServerScriptService` are invisible to clients. Client-needed assets go in `ReplicatedStorage`.
- Attributes replicate and are cheaper than ValueObjects; listen with `:GetAttributeChangedSignal(name)`.
- Remote payloads: Instances arrive only if the receiver can see them; mixed/non-string-keyed tables get mangled; functions/metatables are dropped.
- Per-player remote bandwidth is limited — batch updates and send deltas.
- `UnreliableRemoteEvent` for high-frequency cosmetic data (small payloads, may drop/reorder).

## StreamingEnabled (default on for new places)
- Client cannot assume distant parts exist; `WaitForChild` with timeout, or `Model.ModelStreamingMode = Persistent` for always-needed models.
- `player:RequestStreamAroundAsync(pos)` before teleporting a player.

## Physics
- Network ownership auto-assigns to nearby clients → exploiters can move those parts. For server-authoritative unanchored parts: `part:SetNetworkOwner(nil)`.
- Collision groups: `PhysicsService:RegisterCollisionGroup` + `part.CollisionGroup = "Name"`.

## Characters
- `CharacterAdded` may fire before you connect → also handle an existing `player.Character`.
- Respawn creates a new character — reconnect per-character listeners. Animate via `Animator`.

## UI
- `ScreenGui.ResetOnSpawn = false` for persistent UI; `IgnoreGuiInset` for full-screen.
- Scale sizing + `UIAspectRatioConstraint`/`UIScale` for mobile; test with Device Emulator.
- `GuiButton.Activated` (touch + mouse + gamepad) over `MouseButton1Click`.

## DataStores
- Budgets: ~60 + players×10 requests/min per type per server; 4 MB per key; key ≤ 50 chars.
- `UpdateAsync` over `SetAsync` for anything concurrent; session-lock player data (ProfileStore).
- `game:BindToClose` → save all. Studio needs "Enable Studio Access to API Services".

## Monetization
- `ProcessReceipt`: return `PurchaseGranted` only after the grant is persisted; idempotent by `PurchaseId`.
- Cache `UserOwnsGamePassAsync`; also handle `PromptGamePassPurchaseFinished`.
