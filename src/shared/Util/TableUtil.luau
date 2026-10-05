--!strict
local TableUtil = {}

function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = TableUtil.deepCopy(v)
	end
	return copy :: any
end

-- Freezes a config table and everything inside it, so balancing data can't be mutated at runtime.
function TableUtil.deepFreeze<T>(value: T): T
	if type(value) == "table" and not table.isfrozen(value :: any) then
		for _, v in value :: any do
			TableUtil.deepFreeze(v)
		end
		table.freeze(value :: any)
	end
	return value
end

return TableUtil
