--[[
	Adapted from PolyBool (github.com/voidqk/polybooljs) under the MIT license.
	(c) 2016 Sean Connelly (@voidqk)
	
	Original Lua port by EgoMoose.
	Refactor and optimisations by Elttob.
]]

--[[
	Filters a list of segments based on various boolean operations.
]]

local SegmentSelector = {}

local function newSelector(selection)
	return function(segments, buildLog)
		local result = {}
		local resultLen = 0
		
		for _, seg in ipairs(segments) do
			local index = 1
			
			local myFill = seg.myFill
			local otherFill = seg.otherFill
			
			if myFill.above then
				index += 8
			end
			if myFill.below then
				index += 4
			end
			if otherFill then
				if otherFill.above then
					index += 2
				end
				if otherFill.below then
					index += 1
				end
			end
			
			local fillType = selection[index]
			
			if fillType ~= 0 then
				-- copy the segment to the results, while also calculating the fill status
				resultLen += 1
				result[resultLen] = {
					id = buildLog and buildLog.segmentId() or -1,
					start = seg.start,
					finish = seg.finish,
					myFill = {
						above = fillType == 1, -- 1 if filled above
						below = fillType == 2  -- 2 if filled below
					},
					otherFill = nil
				}
			end
		end

		if buildLog then
			buildLog.selected(result)
		end

		return result
	end
end

-- primary | secondary
-- above1 below1 above2 below2    Keep?               Value
--    0      0      0      0   =>   no                  0
--    0      0      0      1   =>   yes filled below    2
--    0      0      1      0   =>   yes filled above    1
--    0      0      1      1   =>   no                  0
--    0      1      0      0   =>   yes filled below    2
--    0      1      0      1   =>   yes filled below    2
--    0      1      1      0   =>   no                  0
--    0      1      1      1   =>   no                  0
--    1      0      0      0   =>   yes filled above    1
--    1      0      0      1   =>   no                  0
--    1      0      1      0   =>   yes filled above    1
--    1      0      1      1   =>   no                  0
--    1      1      0      0   =>   no                  0
--    1      1      0      1   =>   no                  0
--    1      1      1      0   =>   no                  0
--    1      1      1      1   =>   no                  0
SegmentSelector.union = newSelector {
	0, 2, 1, 0,
	2, 2, 0, 0,
	1, 0, 1, 0,
	0, 0, 0, 0
}

-- primary & secondary
-- above1 below1 above2 below2    Keep?               Value
--    0      0      0      0   =>   no                  0
--    0      0      0      1   =>   no                  0
--    0      0      1      0   =>   no                  0
--    0      0      1      1   =>   no                  0
--    0      1      0      0   =>   no                  0
--    0      1      0      1   =>   yes filled below    2
--    0      1      1      0   =>   no                  0
--    0      1      1      1   =>   yes filled below    2
--    1      0      0      0   =>   no                  0
--    1      0      0      1   =>   no                  0
--    1      0      1      0   =>   yes filled above    1
--    1      0      1      1   =>   yes filled above    1
--    1      1      0      0   =>   no                  0
--    1      1      0      1   =>   yes filled below    2
--    1      1      1      0   =>   yes filled above    1
--    1      1      1      1   =>   no                  0
SegmentSelector.intersect = newSelector {
	0, 0, 0, 0,
	0, 2, 0, 2,
	0, 0, 1, 1,
	0, 2, 1, 0
}

-- primary - secondary
-- above1 below1 above2 below2    Keep?               Value
--    0      0      0      0   =>   no                  0
--    0      0      0      1   =>   no                  0
--    0      0      1      0   =>   no                  0
--    0      0      1      1   =>   no                  0
--    0      1      0      0   =>   yes filled below    2
--    0      1      0      1   =>   no                  0
--    0      1      1      0   =>   yes filled below    2
--    0      1      1      1   =>   no                  0
--    1      0      0      0   =>   yes filled above    1
--    1      0      0      1   =>   yes filled above    1
--    1      0      1      0   =>   no                  0
--    1      0      1      1   =>   no                  0
--    1      1      0      0   =>   no                  0
--    1      1      0      1   =>   yes filled above    1
--    1      1      1      0   =>   yes filled below    2
--    1      1      1      1   =>   no                  0
SegmentSelector.difference = newSelector {
	0, 0, 0, 0,
	2, 0, 2, 0,
	1, 1, 0, 0,
	0, 1, 2, 0
}

-- secondary - primary
-- above1 below1 above2 below2    Keep?               Value
--    0      0      0      0   =>   no                  0
--    0      0      0      1   =>   yes filled below    2
--    0      0      1      0   =>   yes filled above    1
--    0      0      1      1   =>   no                  0
--    0      1      0      0   =>   no                  0
--    0      1      0      1   =>   no                  0
--    0      1      1      0   =>   yes filled above    1
--    0      1      1      1   =>   yes filled above    1
--    1      0      0      0   =>   no                  0
--    1      0      0      1   =>   yes filled below    2
--    1      0      1      0   =>   no                  0
--    1      0      1      1   =>   yes filled below    2
--    1      1      0      0   =>   no                  0
--    1      1      0      1   =>   no                  0
--    1      1      1      0   =>   no                  0
--    1      1      1      1   =>   no                  0
SegmentSelector.differenceRev = newSelector {
	0, 2, 1, 0,
	0, 0, 1, 1,
	0, 2, 0, 2,
	0, 0, 0, 0
}

-- primary ^ secondary
-- above1 below1 above2 below2    Keep?               Value
--    0      0      0      0   =>   no                  0
--    0      0      0      1   =>   yes filled below    2
--    0      0      1      0   =>   yes filled above    1
--    0      0      1      1   =>   no                  0
--    0      1      0      0   =>   yes filled below    2
--    0      1      0      1   =>   no                  0
--    0      1      1      0   =>   no                  0
--    0      1      1      1   =>   yes filled above    1
--    1      0      0      0   =>   yes filled above    1
--    1      0      0      1   =>   no                  0
--    1      0      1      0   =>   no                  0
--    1      0      1      1   =>   yes filled below    2
--    1      1      0      0   =>   no                  0
--    1      1      0      1   =>   yes filled above    1
--    1      1      1      0   =>   yes filled below    2
--    1      1      1      1   =>   no                  0
SegmentSelector.xor = newSelector {
	0, 2, 1, 0,
	2, 0, 0, 1,
	1, 0, 0, 2,
	0, 1, 2, 0
}

return SegmentSelector