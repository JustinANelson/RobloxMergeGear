--!strict
-- Ground items: enemy drops, the per-player ground cap, server-validated merge and move,
-- and restoring a player's ground items when they rejoin.
--
-- Invariant (see DESIGN D7): every physical item owned by a player is counted exactly once in
-- data.ground, and every data change happens in the same step as the world change. So the save
-- matches the world at every moment, and a crash or shutdown loses nothing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Gear = require(Shared.Gear)
local Formulas = require(Shared.Formulas)
local DropConfig = require(Shared.Config.Drops)
local MapConfig = require(Shared.Config.Map)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local ItemPool = require(script.Parent.Parent.Loot.ItemPool)
local DataService = require(script.Parent.DataService)
local ZoneService = require(script.Parent.ZoneService)
local EnemyService = require(script.Parent.EnemyService)
local MapService = require(script.Parent.MapService)

type Zone = MapService.Zone
type Item = Types.Item
type Entry = { id: number, owner: Player, item: Item, part: BasePart }

local LootService = {}

local entries: { [number]: Entry } = {}
local byOwner: { [Player]: { [number]: Entry } } = {}
local populated: { [Player]: true } = {}
local nextId = 0
local rng = Random.new()

-- Zone geometry ------------------------------------------------------------------

local function padTop(zone: Zone): number
	return zone.pad.Position.Y + zone.pad.Size.Y / 2
end

-- Half-extent of the usable pad area, in pad-local studs.
local function padHalf(): number
	return MapConfig.ZoneSize / 2 - DropConfig.PadInset
end

-- Projects a world point onto the pad's top surface, clamped inside the pad.
local function clampToPad(zone: Zone, point: Vector3): Vector3
	local half = padHalf()
	local localPoint = zone.pad.CFrame:PointToObjectSpace(point)
	local clamped = Vector3.new(math.clamp(localPoint.X, -half, half), 0, math.clamp(localPoint.Z, -half, half))
	local world = zone.pad.CFrame:PointToWorldSpace(clamped)
	return Vector3.new(world.X, padTop(zone), world.Z)
end

local function isOnPad(zone: Zone, point: Vector3): boolean
	local half = padHalf()
	local localPoint = zone.pad.CFrame:PointToObjectSpace(point)
	return math.abs(localPoint.X) <= half and math.abs(localPoint.Z) <= half
end

local function randomPadPoint(zone: Zone): Vector3
	local half = padHalf()
	local point = zone.pad.Position
	for _ = 1, 10 do
		point =
			zone.pad.CFrame:PointToWorldSpace(Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half)))
		local fromSpawn = Vector3.new(point.X - zone.spawn.Position.X, 0, point.Z - zone.spawn.Position.Z)
		if fromSpawn.Magnitude > MapConfig.ZoneSafeRadius then
			break
		end
	end
	return Vector3.new(point.X, padTop(zone), point.Z)
end

-- Physical items (no data changes) -------------------------------------------------

local function groundCount(player: Player): number
	local count = 0
	local owned = byOwner[player]
	if owned then
		for _ in owned do
			count += 1
		end
	end
	return count
end

local function spawnPhysical(owner: Player, item: Item, groundPoint: Vector3): Entry
	nextId += 1
	local entry = {
		id = nextId,
		owner = owner,
		item = item,
		part = ItemPool.acquire(item, nextId, owner.UserId, groundPoint),
	}
	entries[entry.id] = entry
	local owned = byOwner[owner]
	if not owned then
		owned = {}
		byOwner[owner] = owned
	end
	owned[entry.id] = entry
	return entry
end

local function removePhysical(entry: Entry)
	entries[entry.id] = nil
	local owned = byOwner[entry.owner]
	if owned then
		owned[entry.id] = nil
	end
	ItemPool.release(entry.part, entry.item.kind)
end

-- Data helpers -----------------------------------------------------------------------

local function recordIndex(player: Player, data: Types.PlayerData, item: Item)
	local slot = Gear.slotOf(item.kind)
	local index: { [string]: number } = data.index :: any -- union-key typing quirk, see Formulas
	if item.plus > (index[slot] or 0) then
		index[slot] = item.plus
		DataService:MarkDirty(player, "index")
	end
end

local function changeCount(inventory: Types.Inventory, item: Item, delta: number)
	if not Gear.addCount(inventory, item, delta) then
		-- Only possible if the world/data invariant was broken somewhere. Loud, but non-fatal.
		warn(`[LootService] count would go negative for {item.kind} +{item.plus}`)
	end
end

local function withinReach(player: Player, point: Vector3): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - point).Magnitude <= DropConfig.MaxInteractDistance
end

local function isItemId(value: unknown): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value > 0
end

-- Public API ----------------------------------------------------------------------------

-- Gives a player an item: onto their zone's ground if there's room (at groundPoint, or a random
-- spot), otherwise straight into storage. Returns where it went, or nil if data isn't loaded.
function LootService:GiveItem(player: Player, item: Item, groundPoint: Vector3?): ("ground" | "storage")?
	local data = DataService:GetData(player)
	if not data then
		return nil
	end
	recordIndex(player, data, item)

	local zone = ZoneService:GetZone(player)
	if zone and populated[player] and groundCount(player) < DropConfig.GroundCap then
		local point = if groundPoint then clampToPad(zone, groundPoint) else randomPadPoint(zone)
		changeCount(data.ground, item, 1)
		DataService:MarkDirty(player, "ground")
		spawnPhysical(player, item, point)
		return "ground"
	end
	changeCount(data.inventory, item, 1)
	DataService:MarkDirty(player, "inventory")
	return "storage"
end

-- Removes a player's physical items WITHOUT touching data (leaving, or a debug data reset).
function LootService:ClearPlayer(player: Player)
	local owned = byOwner[player]
	if owned then
		for _, entry in owned do
			removePhysical(entry)
		end
	end
	byOwner[player] = nil
	populated[player] = nil
end

-- Rebuilds physical items from data.ground once both the save and the zone are ready.
-- Anything beyond the ground cap (e.g. the cap was lowered) moves to storage.
function LootService:Populate(player: Player)
	local data = DataService:GetData(player)
	local zone = ZoneService:GetZone(player)
	if populated[player] or not (data and zone) then
		return
	end
	populated[player] = true

	local saved: { Item } = {}
	for kind, byQuality in data.ground :: any do
		for quality, counts in byQuality do
			for key, count in counts do
				for _ = 1, count do
					table.insert(saved, { kind = kind, quality = quality, plus = tonumber(key) :: number })
				end
			end
		end
	end

	local overflowed = false
	for i, item in saved do
		if i <= DropConfig.GroundCap then
			spawnPhysical(player, item, randomPadPoint(zone))
		else
			changeCount(data.ground, item, -1)
			changeCount(data.inventory, item, 1)
			overflowed = true
		end
	end
	if overflowed then
		DataService:MarkDirty(player, "ground")
		DataService:MarkDirty(player, "inventory")
	end
end

-- Remote handlers -------------------------------------------------------------------------

local function onRequestMerge(player: Player, sourceId: unknown, targetId: unknown)
	if not RateLimit.check(player, "LootRequest", DropConfig.RequestCooldown) then
		return
	end
	if not (isItemId(sourceId) and isItemId(targetId)) or sourceId == targetId then
		return
	end
	local source = entries[sourceId :: number]
	local target = entries[targetId :: number]
	if not (source and target and source.owner == player and target.owner == player) then
		return
	end
	if not Gear.canMerge(source.item, target.item) or not withinReach(player, target.part.Position) then
		return
	end
	local data = DataService:GetData(player)
	if not data then
		return
	end

	-- The merged item takes the target's place; the source disappears.
	local result = Gear.mergeResult(target.item)
	changeCount(data.ground, source.item, -1)
	changeCount(data.ground, target.item, -1)
	changeCount(data.ground, result, 1)
	removePhysical(source)
	target.item = result
	ItemPool.dress(target.part, result)

	data.stats.merges += 1
	DataService:MarkDirty(player, "ground")
	DataService:MarkDirty(player, "stats")
	recordIndex(player, data, result)
end

local function onRequestMove(player: Player, itemId: unknown, point: unknown)
	if not RateLimit.check(player, "LootRequest", DropConfig.RequestCooldown) then
		return
	end
	if not isItemId(itemId) or typeof(point) ~= "Vector3" then
		return
	end
	local target = point :: Vector3
	if target.X ~= target.X or target.Y ~= target.Y or target.Z ~= target.Z then
		return -- NaN
	end
	local entry = entries[itemId :: number]
	local zone = ZoneService:GetZone(player)
	if not (entry and zone and entry.owner == player) then
		return
	end
	if not isOnPad(zone, target) or not withinReach(player, target) then
		return -- client snaps the item back
	end
	ItemPool.place(entry.part, clampToPad(zone, target))
end

-- Lifecycle ---------------------------------------------------------------------------------

function LootService:Init()
	local folder = Instance.new("Folder")
	folder.Name = "Items"
	folder.Parent = workspace
	ItemPool.init(folder)

	Net.event("RequestMerge").OnServerEvent:Connect(onRequestMerge)
	Net.event("RequestMove").OnServerEvent:Connect(onRequestMove)
end

function LootService:Start()
	EnemyService.EnemyKilled:Connect(function(owner, enemy)
		local data = DataService:GetData(owner)
		if not data then
			return
		end
		local item: Item = {
			kind = Formulas.rollDropKind(rng:NextNumber()),
			quality = "Normal",
			plus = Formulas.rollDropPlus(data.upgrades.DropTier, data.rebirths, enemy.isBoss, rng:NextNumber()),
		}
		local scatter = DropConfig.DropScatter
		local offset = Vector3.new(rng:NextNumber(-scatter, scatter), 0, rng:NextNumber(-scatter, scatter))
		LootService:GiveItem(owner, item, enemy.root.Position + offset)
	end)

	-- Populate needs both the save and the zone; whichever arrives second triggers it.
	DataService.ProfileLoaded:Connect(function(player)
		LootService:Populate(player)
	end)
	ZoneService.ZoneAssigned:Connect(function(player)
		LootService:Populate(player)
	end)
	ZoneService.ZoneReleased:Connect(function(player)
		LootService:ClearPlayer(player)
	end)
	for _, player in Players:GetPlayers() do
		LootService:Populate(player)
	end
end

return LootService
