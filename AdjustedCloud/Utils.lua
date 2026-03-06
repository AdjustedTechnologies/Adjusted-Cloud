local Utils = {}

function Utils.shallowCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		copy[k] = v
	end
	return copy
end

function Utils.isEmpty(t)
	return next(t) == nil
end

function Utils.formatMessage(prefix, ...)
	local parts = {prefix}
	for i = 1, select("#", ...) do
		parts[i+1] = tostring(select(i, ...))
	end
	return table.concat(parts, " ")
end

return Utils