--[[
	Adapted from PolyBool (github.com/voidqk/polybooljs) under the MIT license.
	(c) 2016 Sean Connelly (@voidqk)
	
	Original Lua port by EgoMoose.
	Refactor and optimisations by Elttob.
]]

--[[
	The public API for the PolyBool module.
]]

local Epsilon = require(script:WaitForChild("Epsilon"))
local Intersector = require(script:WaitForChild("Intersector"))
local SegmentChainer = require(script:WaitForChild("SegmentChainer"))
local SegmentSelector = require(script:WaitForChild("SegmentSelector"))

local buildLog = nil

local PolyBool = {}

function PolyBool.epsilon(v)
	return Epsilon.epsilon(v)
end

-- core api
function PolyBool.segments(poly)
	local intersector = Intersector(true, buildLog)
	for _, reg in ipairs(poly.regions) do
		intersector.addRegion(reg)
	end
	return {
		segments = intersector.calculate(poly.inverted),
		inverted = poly.inverted
	}
end

function PolyBool.combine(segments1, segments2)
	local intersector = Intersector(false, buildLog)
	return {
		combined = intersector.calculate(
			segments1.segments, segments1.inverted,
			segments2.segments, segments2.inverted
		),
		inverted1 = segments1.inverted,
		inverted2 = segments2.inverted
	}
end

function PolyBool.selectUnion(combined)
	return {
		segments = SegmentSelector.union(combined.combined, buildLog),
		inverted = combined.inverted1 or combined.inverted2
	}
end

function PolyBool.selectIntersect(combined)
	return {
		segments = SegmentSelector.intersect(combined.combined, buildLog),
		inverted = combined.inverted1 and combined.inverted2
	}
end

function PolyBool.selectDifference(combined)
	return {
		segments = SegmentSelector.difference(combined.combined, buildLog),
		inverted = combined.inverted1 and not combined.inverted2
	}
end

function PolyBool.selectDifferenceRev(combined)
	return {
		segments = SegmentSelector.differenceRev(combined.combined, buildLog),
		inverted = not combined.inverted1 and combined.inverted2
	}
end

function PolyBool.selectXor(combined)
	return {
		segments = SegmentSelector.xor(combined.combined, buildLog),
		inverted = combined.inverted1 ~= combined.inverted2
	}
end

function PolyBool.polygon(segments)
	return {
		regions = SegmentChainer(segments.segments, buildLog),
		inverted = segments.inverted
	}
end

-- helper functions for common operations
local function newHelperFunction(selector)
	return function(poly1, poly2)
		local seg1 = PolyBool.segments(poly1)
		local seg2 = PolyBool.segments(poly2)
		local comb = PolyBool.combine(seg1, seg2)
		local seg3 = selector(comb)
		return PolyBool.polygon(seg3)
	end
end

PolyBool.union = newHelperFunction(PolyBool.selectUnion)
PolyBool.intersect = newHelperFunction(PolyBool.selectIntersect)
PolyBool.difference = newHelperFunction(PolyBool.selectDifference)
PolyBool.differenceRev = newHelperFunction(PolyBool.selectDifferenceRev)
PolyBool.xor = newHelperFunction(PolyBool.selectXor)

return PolyBool