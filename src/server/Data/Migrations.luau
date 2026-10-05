--!strict
-- Ordered, append-only save migrations. STEPS[n] upgrades a save from version n to n + 1.
-- Rules:
--   * Never edit or remove a step that has shipped; add a new one.
--   * When adding STEPS[n], bump DataTemplate.schemaVersion to n + 1.
--   * New top-level fields don't need a step: Reconcile() fills them from the template.
--     Use a step only to rename, move, retype or recompute existing data.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataTemplate = require(ReplicatedStorage.Shared.Config.DataTemplate)

local CURRENT = DataTemplate.schemaVersion

local STEPS: { [number]: (data: any) -> () } = {
	-- Example for when Phase 3 quality tiers ship: nothing to do, because the inventory is already
	-- bucketed by quality. Example of a real step:
	-- [1] = function(data) -- v1 -> v2: rename stats.merges to stats.mergeCount
	-- 	data.stats.mergeCount = data.stats.merges
	-- 	data.stats.merges = nil
	-- end,
}

assert(#STEPS == CURRENT - 1, `Migrations: schemaVersion is {CURRENT} but there are {#STEPS} steps`)

local Migrations = {}

-- Returns false if the save comes from a NEWER build than this server (e.g. mid-rollout).
-- The caller must then refuse to load it so old code can't corrupt new data.
function Migrations.run(data: any): boolean
	local version = data.schemaVersion or 1
	if version > CURRENT then
		return false
	end
	for v = version, CURRENT - 1 do
		STEPS[v](data)
	end
	data.schemaVersion = CURRENT
	return true
end

return Migrations
