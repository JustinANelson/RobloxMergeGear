--!strict
-- Spawns enemies in each owned zone and runs their AI (chase the zone owner, hit when in range).
-- Enemies belong to exactly one zone owner: only that player can damage them or be hurt by them.
-- Damage TO enemies goes through EnemyService:Damage; damage FROM enemies is announced via
-- EnemyAttacked and applied by CombatService (keeps requires one-directional).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Signal = require(Shared.Util.Signal)
local Formulas = require(Shared.Formulas)
local EnemyConfig = require(Shared.Config.Enemies)
local MapConfig = require(Shared.Config.Map)
local DataService = require(script.Parent.DataService)
local ZoneService = require(script.Parent.ZoneService)
local MapService = require(script.Parent.MapService)

type Zone = MapService.Zone

export type Enemy = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	owner: Player,
	tier: number,
	isBoss: boolean,
	damage: number,
	gold: number,
	home: Vector3, -- where it spawned; it walks back here when it has no target
	nextAttackAt: number,
	dead: boolean,
}

type ZoneState = {
	owner: Player,
	zone: Zone,
	enemies: { Enemy },
	nextSpawnAt: number,
}

local EnemyService = {
	-- (owner, enemy) right before the model is destroyed; enemy.root.Position is still valid.
	EnemyKilled = Signal.new() :: Signal.Signal<Player, Enemy>,
	-- (enemy, target) when an enemy lands a hit. CombatService applies the damage.
	EnemyAttacked = Signal.new() :: Signal.Signal<Enemy, Player>,
}

local GRUNT = EnemyConfig.Grunt
local AI = EnemyConfig.Ai

local states: { [Player]: ZoneState } = {}
local enemiesFolder: Folder
local template: Model
local rng = Random.new()

local function buildTemplate(): Model
	local model = Instance.new("Model")
	model.Name = "Grunt"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Parent = model

	local function visual(name: string, size: Vector3, offsetY: number, color: Color3)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.Massless = true
		part.CFrame = root.CFrame * CFrame.new(0, offsetY, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
	visual("Body", Vector3.new(2.2, 2.4, 1.4), 0, Color3.fromRGB(150, 60, 60))
	-- A part named "Head" turns on the Humanoid's built-in name + health bar.
	visual("Head", Vector3.new(1.4, 1.4, 1.4), 1.9, Color3.fromRGB(110, 40, 40))

	local humanoid = Instance.new("Humanoid")
	-- Legless rig: R15 mode hovers the root HipHeight studs above the floor.
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 1.5
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = 60
	humanoid.HealthDisplayDistance = 60
	for _, state in
		{
			Enum.HumanoidStateType.Climbing,
			Enum.HumanoidStateType.Swimming,
			Enum.HumanoidStateType.Seated,
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.GettingUp,
		}
	do
		humanoid:SetStateEnabled(state, false)
	end
	humanoid.Parent = model

	model.PrimaryPart = root
	return model
end

-- Random point on the zone pad, away from the edges and from the player's spawn.
local function pickSpawnPoint(zone: Zone): Vector3
	local half = MapConfig.ZoneSize / 2 - EnemyConfig.Spawning.edgeInset
	local padTop = zone.pad.Position.Y + zone.pad.Size.Y / 2
	local point = zone.pad.Position
	for _ = 1, 10 do
		point =
			zone.pad.CFrame:PointToWorldSpace(Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half)))
		local flat = Vector3.new(point.X - zone.spawn.Position.X, 0, point.Z - zone.spawn.Position.Z)
		if flat.Magnitude > MapConfig.ZoneSafeRadius then
			break
		end
	end
	return Vector3.new(point.X, padTop + 3, point.Z)
end

local function spawnEnemy(state: ZoneState, tier: number)
	local stats = Formulas.enemyStats(tier, false)
	local model = template:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model.PrimaryPart :: BasePart
	local home = pickSpawnPoint(state.zone)

	humanoid.MaxHealth = stats.health
	humanoid.Health = stats.health
	humanoid.WalkSpeed = stats.walkSpeed
	humanoid.DisplayName = `Grunt +{tier}`
	model:SetAttribute("OwnerUserId", state.owner.UserId)
	model:SetAttribute("Tier", tier)
	model:PivotTo(CFrame.new(home) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = enemiesFolder
	root:SetNetworkOwner(nil) -- server-simulated, so clients can't teleport enemies

	table.insert(state.enemies, {
		model = model,
		humanoid = humanoid,
		root = root,
		owner = state.owner,
		tier = tier,
		isBoss = false,
		damage = stats.damage,
		gold = stats.gold,
		home = home,
		nextAttackAt = 0,
		dead = false,
	})
end

local function removeFromState(enemy: Enemy)
	local state = states[enemy.owner]
	if state then
		local i = table.find(state.enemies, enemy)
		if i then
			-- Swap-remove: order doesn't matter.
			state.enemies[i] = state.enemies[#state.enemies]
			state.enemies[#state.enemies] = nil
		end
	end
end

-- The owner's root part if they're alive and inside their zone (+ leash margin), else nil.
local function findTarget(state: ZoneState): BasePart?
	local character = state.owner.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and root and humanoid.Health > 0) then
		return nil
	end
	local inPad = state.zone.pad.CFrame:PointToObjectSpace(root.Position)
	local limit = MapConfig.ZoneSize / 2 + AI.leashMargin
	if math.abs(inPad.X) > limit or math.abs(inPad.Z) > limit then
		return nil
	end
	return root
end

local function think(enemy: Enemy, state: ZoneState, target: BasePart?, now: number)
	local position = enemy.root.Position
	if not target then
		if (position - enemy.home).Magnitude > 4 then
			enemy.humanoid:MoveTo(enemy.home)
		end
		return
	end
	local offset = target.Position - position
	local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	if distance > GRUNT.attackRange then
		enemy.humanoid:MoveTo(target.Position)
	else
		enemy.humanoid:MoveTo(position) -- stop and swing
		if now >= enemy.nextAttackAt then
			enemy.nextAttackAt = now + GRUNT.attackInterval
			EnemyService.EnemyAttacked:Fire(enemy, state.owner)
		end
	end
end

local function step(state: ZoneState, now: number)
	local data = DataService:GetData(state.owner)
	if not data then
		return -- profile still loading
	end
	local interval = Formulas.spawnInterval(data.upgrades.SpawnRate)
	if #state.enemies >= Formulas.enemyCap(data.upgrades.EnemyCap) then
		-- At cap: a replacement arrives one interval after the next death.
		state.nextSpawnAt = now + interval
	elseif now >= state.nextSpawnAt then
		state.nextSpawnAt = now + interval
		spawnEnemy(state, Formulas.dropPlus(data.upgrades.DropTier))
	end

	local target = findTarget(state)
	for _, enemy in state.enemies do
		think(enemy, state, target, now)
	end
end

local function onZoneAssigned(player: Player, zone: Zone)
	if not states[player] then
		states[player] = { owner = player, zone = zone, enemies = {}, nextSpawnAt = 0 }
	end
end

local function onZoneReleased(player: Player)
	local state = states[player]
	if not state then
		return
	end
	states[player] = nil
	for _, enemy in state.enemies do
		enemy.dead = true
		enemy.model:Destroy()
	end
end

-- Alive enemies in the player's zone. Read-only: don't mutate the returned array.
function EnemyService:GetEnemies(player: Player): { Enemy }
	local state = states[player]
	return if state then state.enemies else {}
end

-- Applies damage; returns true if this killed the enemy.
function EnemyService:Damage(enemy: Enemy, amount: number): boolean
	if enemy.dead then
		return false
	end
	local humanoid = enemy.humanoid
	humanoid.Health = math.max(humanoid.Health - amount, 0)
	if humanoid.Health > 0 then
		return false
	end

	enemy.dead = true
	removeFromState(enemy)
	local data = DataService:GetData(enemy.owner)
	if data then
		data.stats.kills += 1
		if enemy.isBoss then
			data.stats.bossKills += 1
		end
		DataService:MarkDirty(enemy.owner, "stats")
	end
	EnemyService.EnemyKilled:Fire(enemy.owner, enemy)
	enemy.model:Destroy()
	return true
end

function EnemyService:Init()
	template = buildTemplate()
	enemiesFolder = Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = workspace
end

function EnemyService:Start()
	ZoneService.ZoneAssigned:Connect(onZoneAssigned)
	ZoneService.ZoneReleased:Connect(onZoneReleased)
	-- Players whose zone was assigned before this Start ran.
	for _, player in Players:GetPlayers() do
		local zone = ZoneService:GetZone(player)
		if zone then
			onZoneAssigned(player, zone)
		end
	end

	while true do
		local now = os.clock()
		for _, state in states do
			step(state, now)
		end
		task.wait(AI.tickSeconds)
	end
end

return EnemyService
