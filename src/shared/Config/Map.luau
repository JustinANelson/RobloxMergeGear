--!strict
-- Placeholder map layout, generated at server start by MapService.
-- Top-down: a central plaza (future PvP arena pad), castles on an inner ring,
-- personal zones on an outer ring, with a path from each zone to the plaza.
-- To swap in art later, keep the same anchors (zone pads, castle sites) and replace the visuals.
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	GroundRadius = 450,
	PlazaRadius = 90,
	ArenaPadRadius = 20, -- Phase 2 PvP queue pad; placeholder only

	ZoneCount = 6, -- set the place's Max Players to this in Game Settings
	ZoneDistance = 300, -- plaza center -> zone center
	ZoneSize = 140, -- square pad, studs
	ZoneSafeRadius = 20, -- enemies don't spawn this close to the zone's spawn point
	PathWidth = 16,

	CastleRingRadius = 190, -- castles sit between zones, at angle offsets of half a zone step
	CastleFootprint = 30,

	ZoneColors = {
		Color3.fromRGB(120, 170, 110),
		Color3.fromRGB(110, 150, 185),
		Color3.fromRGB(190, 160, 105),
		Color3.fromRGB(165, 120, 175),
		Color3.fromRGB(185, 115, 110),
		Color3.fromRGB(110, 175, 165),
	},
	TierColors = {
		Color3.fromRGB(150, 150, 150),
		Color3.fromRGB(90, 140, 210),
		Color3.fromRGB(160, 90, 210),
		Color3.fromRGB(230, 170, 50),
	},
})
