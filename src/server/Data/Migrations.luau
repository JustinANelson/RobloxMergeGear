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

-- Steps use raw table operations only (no Gear/Formulas): shared code may change later, but a
-- shipped step must keep doing exactly what it did.
local STEPS: { [number]: (data: any) -> () } = {
	-- v1 -> v2 (Forge rework, DESIGN D21): items no longer lie on the ground. Fold the old
	-- `ground` counts into storage, then drop the field.
	[1] = function(data)
		local ground = data.ground
		if type(ground) == "table" then
			data.inventory = data.inventory or {}
			for kind, byQuality in ground do
				data.inventory[kind] = data.inventory[kind] or {}
				for quality, counts in byQuality do
					local target = data.inventory[kind][quality] or {}
					data.inventory[kind][quality] = target
					for plusKey, count in counts do
						target[plusKey] = (target[plusKey] or 0) + count
					end
				end
			end
		end
		data.ground = nil
	end,
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
