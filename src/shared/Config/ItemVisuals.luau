--!strict
-- Placeholder look of items: the loot-fly effect shapes and the color of each plus band.
-- Swap shapes for meshes later without touching gameplay code.
local Types = require(script.Parent.Parent.Types)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type KindVisual = { shape: Enum.PartType, size: Vector3 }

return TableUtil.deepFreeze({
	Kinds = {
		Sword = { shape = Enum.PartType.Block, size = Vector3.new(0.5, 0.4, 3.2) },
		Helmet = { shape = Enum.PartType.Ball, size = Vector3.new(1.6, 1.6, 1.6) },
		Armor = { shape = Enum.PartType.Block, size = Vector3.new(2, 1.6, 0.8) },
		Boots = { shape = Enum.PartType.Block, size = Vector3.new(1.2, 0.9, 1.8) },
	} :: { [Types.ItemKind]: KindVisual },

	-- Color by plus: the first band whose maxPlus >= plus.
	PlusBands = {
		{ maxPlus = 3, color = Color3.fromRGB(200, 200, 200) },
		{ maxPlus = 6, color = Color3.fromRGB(110, 220, 110) },
		{ maxPlus = 9, color = Color3.fromRGB(90, 160, 255) },
		{ maxPlus = 12, color = Color3.fromRGB(190, 110, 255) },
		{ maxPlus = 15, color = Color3.fromRGB(255, 160, 50) },
		{ maxPlus = math.huge, color = Color3.fromRGB(255, 70, 70) },
	} :: { { maxPlus: number, color: Color3 } },
})
