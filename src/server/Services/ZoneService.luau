--!strict
-- Assigns each player a personal zone for their session and keeps them spawning in it.
-- Zone index is also exposed as the player attribute "ZoneIndex" for clients.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local MapService = require(script.Parent.MapService)

type Zone = MapService.Zone

local ZoneService = {
	ZoneAssigned = Signal.new() :: Signal.Signal<Player, Zone>,
	ZoneReleased = Signal.new() :: Signal.Signal<Player, Zone>,
}

local zones: { Zone } = {}
local owners: { [number]: Player } = {}
local zoneOf: { [Player]: number } = {}

function ZoneService:GetZone(player: Player): Zone?
	local index = zoneOf[player]
	return index and zones[index]
end

function ZoneService:GetOwner(zoneIndex: number): Player?
	return owners[zoneIndex]
end

-- RespawnLocation normally handles this; the pivot is a fallback for the first spawn,
-- which can happen before the zone was assigned.
local function moveToZone(character: Model, zone: Zone)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root or not character.Parent then
		return
	end
	local target = zone.spawn.CFrame + Vector3.new(0, 4, 0)
	if (root.Position - target.Position).Magnitude > 30 then
		character:PivotTo(target)
	end
end

local function assign(player: Player)
	for index, zone in zones do
		if not owners[index] then
			owners[index] = player
			zoneOf[player] = index
			player.RespawnLocation = zone.spawn
			player:SetAttribute("ZoneIndex", index)
			zone.folder:SetAttribute("OwnerUserId", player.UserId)
			zone.ownerLabel.Text = `{player.DisplayName}'s Zone`

			player.CharacterAdded:Connect(function(character)
				moveToZone(character, zone)
			end)
			if player.Character then
				task.spawn(moveToZone, player.Character, zone)
			end

			ZoneService.ZoneAssigned:Fire(player, zone)
			return
		end
	end
	warn(`[ZoneService] No free zone for {player.Name}. Set the place's Max Players to {#zones}.`)
end

local function release(player: Player)
	local index = zoneOf[player]
	if not index then
		return
	end
	local zone = zones[index]
	owners[index] = nil
	zoneOf[player] = nil
	zone.folder:SetAttribute("OwnerUserId", nil)
	zone.ownerLabel.Text = "Unclaimed"
	ZoneService.ZoneReleased:Fire(player, zone)
end

function ZoneService:Start()
	zones = MapService:GetZones()
	Players.PlayerAdded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		assign(player)
	end
end

return ZoneService
