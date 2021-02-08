--[[
	Adapted from PolyBool (github.com/voidqk/polybooljs) under the MIT license.
	(c) 2016 Sean Connelly (@voidqk)
	
	Original Lua port by EgoMoose.
	Refactor and optimisations by Elttob.
]]

--[[
	Provides helper functions for common array operations.
]]

local Array = {}

function Array.reverse(array)
	local j = #array
	local i = 1
	while i < j do
		array[i], array[j] = array[j], array[i]
		i += 1
		j -= 1
	end
end

function Array.concat(array1, array2)	
	local length1 = #array1
	local length2 = #array2
	
	local result = table.create(length1 + length2)
	
	table.move(array1, 1, length1, 1, result)
	table.move(array2, 1, length2, length1 + 1, result)
	
	return result
end

return Array