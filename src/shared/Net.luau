--!strict
-- Single registry of every remote. The server creates them all once (Net.setup, called from the
-- server entry script before any service loads); clients look them up lazily.
-- To add a remote: add its name to the type AND the list. The type turns typos into type errors.
-- Naming: Request* = client -> server intent (always validated); *Changed/*Snapshot = server -> client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type EventName =
	"DataSnapshot" -- S->C: full PlayerData once, after the profile loads
	| "DataChanged" -- S->C: { [topLevelKey]: newValue }, batched once per frame
	| "ItemGained" -- S->C: (kind, quality, plus, fromPosition: Vector3?) cosmetic loot-fly effect
	| "Notify" -- S->C: (message, tone: "info" | "good" | "bad") toast
	| "RequestMergeStack" -- C->S: (kind, quality, plus) merge every pair in that stack, no cascade
	| "RequestMergeAll" -- C->S: () cascade-merge everything, equipped items included
	| "RequestUpgradeEquipped" -- C->S: (slot) merge a stored copy into the equipped item
	| "RequestEquipFromStorage" -- C->S: (kind, quality, plus) old item in that slot -> storage
	| "RequestEquipBest" -- C->S: () equip the highest-plus stored item per slot if it beats the current
	| "RequestUnequip" -- C->S: (slot) equipped item -> storage

local EVENTS: { EventName } = {
	"DataSnapshot",
	"DataChanged",
	"ItemGained",
	"Notify",
	"RequestMergeStack",
	"RequestMergeAll",
	"RequestUpgradeEquipped",
	"RequestEquipFromStorage",
	"RequestEquipBest",
	"RequestUnequip",
}

local FOLDER_NAME = "Remotes"
local cache: { [string]: RemoteEvent } = {}

local Net = {}

function Net.setup()
	assert(RunService:IsServer(), "Net.setup is server-only")
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		cache[name] = remote
	end
	folder.Parent = ReplicatedStorage
end

function Net.event(name: EventName): RemoteEvent
	local remote = cache[name]
	if not remote then
		-- Typed callers can't hit this; untyped or stale scripts (e.g. an out-of-sync copy in
		-- Studio) can, and on the client they'd otherwise hang forever in WaitForChild.
		if not table.find(EVENTS, name) then
			error(`Net: unknown remote "{name}". It isn't in Net's EVENTS list; is this script stale?`, 2)
		end
		assert(RunService:IsClient(), `Net.event("{name}") called on the server before Net.setup()`)
		remote = ReplicatedStorage:WaitForChild(FOLDER_NAME):WaitForChild(name) :: RemoteEvent
		cache[name] = remote
	end
	return remote
end

return Net
