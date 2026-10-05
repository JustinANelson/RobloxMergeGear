--!strict
-- The hero side of combat: applies gear stats to the character, auto-attacks the nearest enemy
-- in range, and applies damage from enemies. Fully server-decided; no remotes. Clients render
-- hits from replicated enemy Humanoid health (see CombatFxController).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Formulas = require(Shared.Formulas)
local GearConfig = require(Shared.Config.Gear)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)

type Hero = { stats: Types.HeroStats, nextAttackAt: number }

local HERO = GearConfig.Hero

local CombatService = {}

local heroes: { [Player]: Hero } = {}

local function aliveParts(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

local function applyToCharacter(player: Player)
	local hero = heroes[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (hero and humanoid) then
		return
	end
	local stats = hero.stats
	if humanoid.Health > 0 then
		-- Keep the same health fraction so equipping armor mid-fight doesn't fully heal.
		local fraction = humanoid.Health / humanoid.MaxHealth
		humanoid.MaxHealth = stats.maxHealth
		humanoid.Health = fraction * stats.maxHealth
	end
	humanoid.WalkSpeed = stats.walkSpeed
end

-- Recompute stats from the save (on load and whenever "equipped" changes).
local function refresh(player: Player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	local hero = heroes[player]
	if not hero then
		hero = { stats = Formulas.heroStats(data.equipped), nextAttackAt = 0 }
		heroes[player] = hero
	else
		hero.stats = Formulas.heroStats(data.equipped)
	end
	player:SetAttribute("GearScore", Formulas.gearScore(data.equipped))
	applyToCharacter(player)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local hero = heroes[player]
	if humanoid and hero then
		humanoid.MaxHealth = hero.stats.maxHealth
		humanoid.Health = hero.stats.maxHealth
		humanoid.WalkSpeed = hero.stats.walkSpeed
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end

local function damageHero(player: Player, raw: number)
	local hero = heroes[player]
	local humanoid = aliveParts(player)
	if hero and humanoid then
		-- TakeDamage respects the spawn ForceField.
		humanoid:TakeDamage(Formulas.damageTaken(raw, hero.stats.defense))
	end
end

local function tryAttack(player: Player, hero: Hero, now: number)
	if now < hero.nextAttackAt then
		return
	end
	local _, root = aliveParts(player)
	if not root then
		return
	end
	local origin = root.Position
	local nearest, nearestDistance = nil, HERO.attackRange
	for _, enemy in EnemyService:GetEnemies(player) do
		local offset = enemy.root.Position - origin
		local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if distance <= nearestDistance then
			nearest, nearestDistance = enemy, distance
		end
	end
	if nearest then
		hero.nextAttackAt = now + HERO.attackInterval
		EnemyService:Damage(nearest, hero.stats.damage)
	end
end

function CombatService:Init()
	Players.RespawnTime = HERO.respawnSeconds
end

function CombatService:Start()
	DataService.ProfileLoaded:Connect(refresh)
	DataService.Changed:Connect(function(player, key)
		if key == "equipped" then
			refresh(player)
		end
	end)
	EnemyService.EnemyAttacked:Connect(function(enemy, player)
		damageHero(player, enemy.damage)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		heroes[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
		refresh(player)
	end

	-- Per-frame check so attack timing isn't quantized to a slower tick. Cheap: a clock compare
	-- per player, plus a scan of at most one zone's enemies when an attack is ready.
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for player, hero in heroes do
			tryAttack(player, hero, now)
		end
	end)
end

return CombatService
