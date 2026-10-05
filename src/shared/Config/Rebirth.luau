--!strict
-- Rebirth: reset gear, gold and upgrades for permanent multipliers.
-- Kept through rebirth: rebirths, index, stats.
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	-- Rebirth #n (n = rebirths so far) needs any item at plus >= firstRequiredPlus + n * requiredPlusStep.
	firstRequiredPlus = 10,
	requiredPlusStep = 2,

	goldMultiplierPerRebirth = 0.5, -- gold x (1 + 0.5 * rebirths)
	bonusPlusChancePerRebirth = 0.05, -- chance a drop arrives one plus higher
	bonusPlusChanceMax = 0.5,
})
