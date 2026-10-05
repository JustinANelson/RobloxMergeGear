--!strict
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	Offline = {
		-- Paid on rejoin: incomeRate * min(secondsAway, maxHours) * efficiency.
		-- incomeRate is saved on leave = castle gold/s held at that moment
		--   + farmFactor * (estimated zone gold/s from the current Drop Tier and spawn rate).
		maxHours = 8,
		efficiency = 0.5,
		farmFactor = 0.25,
		minSecondsAway = 60, -- ignore quick reconnects
	},
})
