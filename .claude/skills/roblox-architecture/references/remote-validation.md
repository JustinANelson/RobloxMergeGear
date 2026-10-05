# Remote validation template

```luau
--!strict
local Players = game:GetService("Players")

local RateLimit = {}
local buckets: { [Player]: { [string]: number } } = {}

-- true if allowed; at most one call per `per` seconds per key
function RateLimit.check(player: Player, key: string, per: number): boolean
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = {}
		buckets[player] = b
	end
	local last = b[key]
	if last and now - last < per then
		return false
	end
	b[key] = now
	return true
end

Players.PlayerRemoving:Connect(function(p)
	buckets[p] = nil
end)

return RateLimit
```

Handler usage:
```luau
remote.OnServerEvent:Connect(function(player: Player, slotA: unknown, slotB: unknown)
	if not RateLimit.check(player, "Merge", 0.1) then return end
	if typeof(slotA) ~= "number" or typeof(slotB) ~= "number" then return end
	if slotA ~= slotA or slotA % 1 ~= 0 or slotA < 1 or slotA > Config.MaxSlots then return end
	-- same for slotB, then ownership: both slots exist in player's profile
end)
```
Never trust from the client: prices, rewards, owned item ids, positions for reward claims, timers. Recompute on server.
