--!strict
-- Owns player persistence (ProfileStore, session-locked) and replication of the save to its owner.
-- Other services read/mutate data via GetData(), then call MarkDirty(player, topLevelKey);
-- dirty keys are batched into one DataChanged remote per player per frame.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local TableUtil = require(Shared.Util.TableUtil)
local DataTemplate = require(Shared.Config.DataTemplate)
local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore)
local Migrations = require(script.Parent.Parent.Data.Migrations)
local NewPlayer = require(script.Parent.Parent.Data.NewPlayer)

-- Changing the store name starts everyone fresh. Keep it stable once players exist.
local STORE_NAME = "PlayerData"
-- true = Studio sessions never touch real saves (data resets each playtest).
local USE_MOCK_IN_STUDIO = false

type PlayerData = Types.PlayerData

-- How often lastOnline is stamped, so offline time is right even if the server dies.
local STAMP_INTERVAL = 30

-- Design rule: the save must be valid at EVERY moment. There is deliberately no "on leave"
-- hook: on server shutdown ProfileStore saves sessions on its own threads, and leave handlers
-- may never run. So services write state into data as it changes (e.g. ground items are
-- mirrored in data.ground), never "just before save".
local DataService = {
	-- (player, data) after the profile is loaded, migrated and sent to the client.
	ProfileLoaded = Signal.new() :: Signal.Signal<Player, PlayerData>,
	-- (player, topLevelKey) whenever a service marks a key dirty. Lets server systems react to
	-- data changes (e.g. re-apply hero stats when "equipped" changes) without polling.
	Changed = Signal.new() :: Signal.Signal<Player, string>,
}

local profiles: { [Player]: any } = {}
local dirty: { [Player]: { [string]: true } } = {}
local store: any

function DataService:GetData(player: Player): PlayerData?
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService:MarkDirty(player: Player, key: string)
	if not profiles[player] then
		return
	end
	local keys = dirty[player]
	if not keys then
		keys = {}
		dirty[player] = keys
	end
	keys[key] = true
	DataService.Changed:Fire(player, key)
end

-- Studio-only: wipe a player's save back to the template.
function DataService:ResetData(player: Player)
	assert(RunService:IsStudio(), "ResetData is Studio-only")
	local profile = profiles[player]
	if profile then
		profile.Data = TableUtil.deepCopy(DataTemplate)
		NewPlayer.apply(profile.Data)
		dirty[player] = nil
		Net.event("DataSnapshot"):FireClient(player, profile.Data)
		for key in profile.Data do
			DataService.Changed:Fire(player, key)
		end
	end
end

local function flush()
	if next(dirty) == nil then
		return
	end
	local remote = Net.event("DataChanged")
	for player, keys in dirty do
		local profile = profiles[player]
		if profile then
			local changes = {}
			for key in keys do
				changes[key] = profile.Data[key]
			end
			remote:FireClient(player, changes)
		end
	end
	table.clear(dirty)
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		-- Session lock couldn't be acquired (other server didn't release) or the player left.
		player:Kick("Your data couldn't be loaded. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId) -- GDPR erasure support
	if not Migrations.run(profile.Data) then
		profile:EndSession()
		player:Kick("This server is out of date. Please rejoin to get a newer server.")
		return
	end
	profile:Reconcile()
	NewPlayer.apply(profile.Data)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		dirty[player] = nil
		-- Fires on normal leave too (harmless then); otherwise another server took the session.
		player:Kick("Your data was loaded on another server. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	Net.event("DataSnapshot"):FireClient(player, profile.Data)
	player:SetAttribute("DataLoaded", true)
	DataService.ProfileLoaded:Fire(player, profile.Data)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Data.offline.lastOnline = os.time()
	profile:EndSession()
end

function DataService:Init()
	local playerStore = ProfileStore.New(STORE_NAME, DataTemplate)
	store = if USE_MOCK_IN_STUDIO and RunService:IsStudio() then playerStore.Mock else playerStore
end

function DataService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	RunService.Heartbeat:Connect(flush)
	-- ProfileStore saves all active sessions on shutdown itself (BindToClose).

	while true do
		task.wait(STAMP_INTERVAL)
		local now = os.time()
		for _, profile in profiles do
			profile.Data.offline.lastOnline = now
		end
	end
end

return DataService
