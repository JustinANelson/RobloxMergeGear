--!strict
-- Per-player, per-key cooldown for remote handlers. Call first in every OnServerEvent handler.
local Players = game:GetService("Players")

local RateLimit = {}

local lastCall: { [Player]: { [string]: number } } = {}

-- True if allowed: at most one call per `cooldown` seconds for this player and key.
function RateLimit.check(player: Player, key: string, cooldown: number): boolean
	local now = os.clock()
	local calls = lastCall[player]
	if not calls then
		calls = {}
		lastCall[player] = calls
	end
	local last = calls[key]
	if last and now - last < cooldown then
		return false
	end
	calls[key] = now
	return true
end

Players.PlayerRemoving:Connect(function(player)
	lastCall[player] = nil
end)

return RateLimit
