--!strict
-- Builds the placeholder world from Config/Map + Config/Castles at server start and exposes its
-- anchors (zone pads/spawns, castle sites). Other services only use the anchors, never the
-- visuals, so the art can be replaced later without touching gameplay code.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local MapConfig = require(Shared.Config.Map)
local CastleConfig = require(Shared.Config.Castles)

export type Zone = {
	index: number,
	folder: Folder,
	pad: BasePart, -- enemies spawn and items drop on this
	spawn: SpawnLocation,
	ownerLabel: TextLabel,
}

export type CastleSite = {
	def: CastleConfig.CastleDef,
	model: Model,
	capturePoint: BasePart, -- the hero stands here to start a battle
	statusLabel: TextLabel,
}

local MapService = {}

local zones: { Zone } = {}
local castleSites: { [string]: CastleSite } = {}

local function makePart(parent: Instance, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

-- Flat disc whose top face sits at topY.
local function makeDisc(parent: Instance, name: string, radius: number, thickness: number, topY: number, color: Color3)
	return makePart(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(0, topY - thickness / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	})
end

local function makeBillboard(adornee: BasePart, text: string, studsOffsetY: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 60)
	gui.StudsOffset = Vector3.new(0, studsOffsetY, 0)
	gui.MaxDistance = 250
	gui.AlwaysOnTop = false

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui

	gui.Parent = adornee
	return label
end

local function polar(angleDeg: number, radius: number): Vector3
	local a = math.rad(angleDeg)
	return Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
end

local function buildZone(parent: Instance, index: number, angle: number): Zone
	local size = MapConfig.ZoneSize
	local center = polar(angle, MapConfig.ZoneDistance)
	-- Local -Z of `facing` points at the plaza.
	local facing = CFrame.lookAt(center, Vector3.zero)

	local folder = Instance.new("Folder")
	folder.Name = `Zone{index}`
	folder:SetAttribute("ZoneIndex", index)

	local pad = makePart(folder, {
		Name = "Pad",
		Size = Vector3.new(size, 1, size),
		CFrame = facing * CFrame.new(0, -0.4, 0), -- top face at y = 0.1, just above the ground
		Color = MapConfig.ZoneColors[(index - 1) % #MapConfig.ZoneColors + 1],
		Material = Enum.Material.Grass,
	})

	-- Spawn near the plaza-facing edge so the path out of the zone is right in front of the player.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 3
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = facing * CFrame.new(0, 0.1, -(size / 2 - 15))
	spawn.Color = Color3.fromRGB(240, 240, 240)
	spawn.Parent = folder

	local signPost = makePart(folder, {
		Name = "Sign",
		Size = Vector3.new(1, 10, 1),
		CFrame = spawn.CFrame * CFrame.new(10, 5, 0),
		Color = Color3.fromRGB(110, 80, 50),
		Material = Enum.Material.Wood,
	})
	local ownerLabel = makeBillboard(signPost, "Unclaimed", 7)

	folder.Parent = parent
	return { index = index, folder = folder, pad = pad, spawn = spawn, ownerLabel = ownerLabel }
end

local function buildPath(parent: Instance, angle: number)
	local from = MapConfig.ZoneDistance - MapConfig.ZoneSize / 2
	local to = MapConfig.PlazaRadius
	local length = from - to
	local mid = polar(angle, (from + to) / 2)
	makePart(parent, {
		Name = "Path",
		Size = Vector3.new(MapConfig.PathWidth, 0.2, length),
		CFrame = CFrame.lookAt(mid, Vector3.zero) * CFrame.new(0, 0.1, 0),
		Color = Color3.fromRGB(150, 140, 120),
		Material = Enum.Material.Slate,
	})
end

local function buildCastle(parent: Instance, def: CastleConfig.CastleDef, angle: number): CastleSite
	local tier = CastleConfig.Tiers[def.tier]
	local footprint = MapConfig.CastleFootprint
	local color = MapConfig.TierColors[def.tier]
	local origin = CFrame.lookAt(polar(angle, MapConfig.CastleRingRadius), Vector3.zero)

	local model = Instance.new("Model")
	model.Name = def.id
	model:SetAttribute("CastleId", def.id)
	model:SetAttribute("Tier", def.tier)

	local base = makePart(model, {
		Name = "Base",
		Size = Vector3.new(footprint, 2, footprint),
		CFrame = origin * CFrame.new(0, 1, 0),
		Color = Color3.fromRGB(120, 115, 110),
		Material = Enum.Material.Cobblestone,
	})
	local keep = makePart(model, {
		Name = "Keep",
		Size = Vector3.new(footprint * 0.5, 14, footprint * 0.5),
		CFrame = origin * CFrame.new(0, 9, 0),
		Color = color,
		Material = Enum.Material.Brick,
	})
	local corner = footprint / 2 - 2.5
	for _, offset in { Vector2.new(1, 1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(-1, -1) } do
		makePart(model, {
			Name = "Tower",
			Size = Vector3.new(5, 20, 5),
			CFrame = origin * CFrame.new(offset.X * corner, 12, offset.Y * corner),
			Color = color,
			Material = Enum.Material.Brick,
		})
	end
	-- Flag: CastleService recolors it to show the owner.
	makePart(model, {
		Name = "Flag",
		Size = Vector3.new(0.2, 3, 5),
		CFrame = origin * CFrame.new(0, 19, 0),
		Color = Color3.fromRGB(230, 230, 230),
		Material = Enum.Material.Fabric,
	})
	-- On the plaza-facing side (-Z), in front of the castle.
	local capturePoint = makePart(model, {
		Name = "CapturePoint",
		Size = Vector3.new(10, 0.4, 10),
		CFrame = origin * CFrame.new(0, 0.2, -(footprint / 2 + 8)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.4,
	})

	local statusLabel = makeBillboard(
		keep,
		`{def.name} (Tier {def.tier})\nPower {tier.requiredPower} · {tier.goldPerSecond} gold/s\nUnclaimed`,
		14
	)

	model.PrimaryPart = base
	model.Parent = parent
	return { def = def, model = model, capturePoint = capturePoint, statusLabel = statusLabel }
end

local function build()
	local map = Instance.new("Folder")
	map.Name = "Map"

	makeDisc(map, "Ground", MapConfig.GroundRadius, 2, 0, Color3.fromRGB(95, 140, 80))
	makeDisc(map, "Plaza", MapConfig.PlazaRadius, 0.2, 0.2, Color3.fromRGB(165, 160, 150))
	local arenaPad = makeDisc(map, "ArenaPad", MapConfig.ArenaPadRadius, 0.2, 0.3, Color3.fromRGB(90, 90, 110))
	arenaPad:SetAttribute("Placeholder", "Phase 2 PvP queue pad")

	local lobby = Instance.new("SpawnLocation")
	lobby.Name = "LobbySpawn" -- used only by players who don't get a zone
	lobby.Anchored = true
	lobby.Neutral = true
	lobby.Size = Vector3.new(8, 1, 8)
	lobby.CFrame = CFrame.new(0, 0.3, -(MapConfig.ArenaPadRadius + 10))
	lobby.Parent = map

	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = "Zones"
	local zoneStep = 360 / MapConfig.ZoneCount
	for i = 1, MapConfig.ZoneCount do
		local angle = (i - 1) * zoneStep
		zones[i] = buildZone(zoneFolder, i, angle)
		buildPath(map, angle)
	end
	zoneFolder.Parent = map

	local castleFolder = Instance.new("Folder")
	castleFolder.Name = "Castles"
	local castleStep = 360 / #CastleConfig.Castles
	for i, def in CastleConfig.Castles do
		-- Offset by half a zone step so castles sit in the gaps between zone paths.
		castleSites[def.id] = buildCastle(castleFolder, def, (i - 1) * castleStep + zoneStep / 2)
	end
	castleFolder.Parent = map

	map.Parent = workspace
end

function MapService:GetZones(): { Zone }
	return zones
end

function MapService:GetCastleSites(): { [string]: CastleSite }
	return castleSites
end

function MapService:Init()
	build()
end

return MapService
