--!strict
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1.23K", 98765432 -> "98.8M"
function Format.abbreviate(n: number): string
	if n < 1000 then
		return tostring(math.floor(n))
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	local pattern = if scaled < 10 then "%.2f%s" elseif scaled < 100 then "%.1f%s" else "%.0f%s"
	return string.format(pattern, scaled, SUFFIXES[tier + 1])
end

return Format
