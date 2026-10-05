--!strict
-- The only writer of data.gold. Also owns gold coins dropped by enemies and the loot magnet.
-- Coins are owner-only; one coin carries the whole drop's value. Uncollected coins are
-- credited automatically after despawnSeconds. Coins still on the ground when the owner
-- leaves are lost (small by design; crediting them would need a leave hook, see D7).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local DropConfig = require(Shared.Config.Drops)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)

type Coin = { part: BasePart, amount: number, expiresAt: number }

local GOLD = DropConfig.Gold

local EconomyService = {}

local coinsByOwner: { [Player]: { Coin } } = {}
local coinsFolder: Folder

-- Adds gold with the rebirth multiplier applied. Returns the amount actually added.
-- `source` is for future analytics/logging ("Coin", "Castle", "Offline", ...).
function EconomyService:AddGold(player: Player, amount: number, _source: string): number
	local data = DataService:GetData(player)
	if not data or amount <= 0 then
		return 0
	end
	local gained = math.floor(amount * Formulas.goldMultiplier(data.rebirths) + 0.5)
	data.gold += gained
	data.stats.goldEarned += gained
	DataService:MarkDirty(player, "gold")
	DataService:MarkDirty(player, "stats")
	return gained
end

-- Deducts gold if affordable. Returns false (and changes nothing) otherwise.
function EconomyService:SpendGold(player: Player, amount: number): boolean
	local data = DataService:GetData(player)
	if not data or amount < 0 or data.gold < amount then
		return false
	end
	data.gold -= amount
	DataService:MarkDirty(player, "gold")
	return true
end

local function spawnCoin(owner: Player, position: Vector3, amount: number)
	local part = Instance.new("Part")
	part.Name = "Coin"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.35, 1.6, 1.6)
	part.Color = Color3.fromRGB(255, 200, 40)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	-- Cylinder axis is X; yaw randomly so a pile of coins doesn't look stamped.
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	part:SetAttribute("OwnerUserId", owner.UserId)
	part:SetAttribute("Amount", amount)
	part.Parent = coinsFolder

	local coins = coinsByOwner[owner]
	if not coins then
		coins = {}
		coinsByOwner[owner] = coins
	end
	table.insert(coins, { part = part :: BasePart, amount = amount, expiresAt = os.clock() + GOLD.despawnSeconds })
end

local function magnetStep(owner: Player, coins: { Coin }, now: number)
	local data = DataService:GetData(owner)
	if not data then
		return
	end
	local character = owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local range = Formulas.magnetRange(data.upgrades.MagnetRange)
	-- Backwards so swap-removal doesn't skip anything.
	for i = #coins, 1, -1 do
		local coin = coins[i]
		local inRange = root ~= nil and (root.Position - coin.part.Position).Magnitude <= range
		if inRange or now >= coin.expiresAt then
			EconomyService:AddGold(owner, coin.amount, "Coin")
			coin.part:Destroy()
			coins[i] = coins[#coins]
			coins[#coins] = nil
		end
	end
end

function EconomyService:Init()
	coinsFolder = Instance.new("Folder")
	coinsFolder.Name = "Coins"
	coinsFolder.Parent = workspace
end

function EconomyService:Start()
	EnemyService.EnemyKilled:Connect(function(owner, enemy)
		-- Root hovers ~2.5 studs up; drop the coin near the floor.
		spawnCoin(owner, enemy.root.Position - Vector3.new(0, 1.5, 0), enemy.gold)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local coins = coinsByOwner[player]
		coinsByOwner[player] = nil
		if coins then
			for _, coin in coins do
				coin.part:Destroy()
			end
		end
	end)

	while true do
		local now = os.clock()
		for owner, coins in coinsByOwner do
			magnetStep(owner, coins, now)
		end
		task.wait(GOLD.magnetTickSeconds)
	end
end

return EconomyService
