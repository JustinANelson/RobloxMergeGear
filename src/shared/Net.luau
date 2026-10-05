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
	| "RequestMerge" -- C->S: (sourceItemId, targetItemId) drop one ground item onto another
	| "RequestMove" -- C->S: (itemId, groundPoint: Vector3) drop a ground item on empty ground
	| "RequestStore" -- C->S: (itemId) ground item -> storage
	| "RequestWithdraw" -- C->S: (kind, quality, plus) storage -> ground near the hero
	| "RequestEquipFromStorage" -- C->S: (kind, quality, plus) old item in that slot -> storage
	| "RequestEquipFromGround" -- C->S: (itemId) old item in that slot -> storage
	| "RequestUnequip" -- C->S: (slot) equipped item -> storage

local EVENTS: { EventName } = {
	"DataSnapshot",
	"DataChanged",
	"RequestMerge",
	"RequestMove",
	"RequestStore",
	"RequestWithdraw",
	"RequestEquipFromStorage",
	"RequestEquipFromGround",
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
		assert(RunService:IsClient(), `Net.event("{name}") called on the server before Net.setup()`)
		remote = ReplicatedStorage:WaitForChild(FOLDER_NAME):WaitForChild(name) :: RemoteEvent
		cache[name] = remote
	end
	return remote
end

return Net
