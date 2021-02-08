--[[
	Adapted from PolyBool (github.com/voidqk/polybooljs) under the MIT license.
	(c) 2016 Sean Connelly (@voidqk)
	
	Original Lua port by EgoMoose.
	Refactor and optimisations by Elttob.
]]

--[[
	The core workhorse of the module, used for resolving intersecting segments.
]]

local Epsilon = require(script.Parent:WaitForChild("Epsilon"))
local SortedArray = require(script.Parent:WaitForChild("SortedArray"))

local function Intersector(selfIntersection, buildLog)
	-- selfIntersection is true/false depending on the phase of the overall algorithm

	--
	-- segment creation
	--

	local function segmentNew(start, finish)
		return {
			id = buildLog and buildLog.segmentId() or -1,
			start = start,
			finish = finish,
			myFill = {
				above = nil, -- is there fill above us?
				below = nil  -- is there fill below us?
			},
			otherFill = nil
		}
	end

	local function segmentCopy(start, finish, seg)
		return {
			id = buildLog and buildLog.segmentId() or -1,
			start = start,
			finish = finish,
			myFill = {
				above = seg.myFill.above,
				below = seg.myFill.below
			},
			otherFill = nil
		}
	end

	--
	-- event logic
	--

	local event_root = {}

	local function eventCompare(p1_isStart, p1_1, p1_2, p2_isStart, p2_1, p2_2)
		-- compare the selected points first
		local comp = Epsilon.pointsCompare(p1_1, p2_1)
		if comp ~= 0 then
			return comp
		end
		-- the selected points are the same

		if Epsilon.pointsSame(p1_2, p2_2) then -- if the non-selected points are the same too...
			return 0 -- then the segments are equal
		end

		if p1_isStart ~= p2_isStart then -- if one is a start and the other isn't...
			-- favor the one that isn't the start
			if p1_isStart then
				return 1
			else
				return -1
			end
		end

		-- otherwise, we'll have to calculate which one is below the other manually
		if p2_isStart then
			-- order matters
			if Epsilon.pointAboveOrOnLine(p1_2, p2_1, p2_2) then
				return 1
			else
				return -1
			end
		else
			if Epsilon.pointAboveOrOnLine(p1_2, p2_2, p2_1) then
				return 1
			else
				return -1
			end
		end
	end

	local function eventAdd(ev, other_pt)
		SortedArray.insertBefore(event_root, ev, function(here)
			-- should ev be inserted before here?
			local comp = eventCompare(
				ev.isStart, ev.pt, other_pt,
				here.isStart, here.pt, here.other.pt
			)
			return comp < 0
		end)
	end

	local function eventAddSegmentStart(seg, primary)
		local ev_start = {
			isStart = true,
			pt = seg.start,
			seg = seg,
			primary = primary,
			other = nil,
			status = nil
		}
		eventAdd(ev_start, seg.finish)
		return ev_start
	end

	local function eventAddSegmentEnd(ev_start, seg, primary)
		local ev_end = {
			isStart = false,
			pt = seg.finish,
			seg = seg,
			primary = primary,
			other = ev_start,
			status = nil
		}
		ev_start.other = ev_end
		eventAdd(ev_end, ev_start.pt)
	end

	local function eventAddSegment(seg, primary)
		local ev_start = eventAddSegmentStart(seg, primary)
		eventAddSegmentEnd(ev_start, seg, primary)
		return ev_start
	end

	local function eventUpdateEnd(ev, finish)
		-- slides an finish backwards
		--   (start)------------(finish)    to:
		--   (start)---(finish)

		if buildLog then
			buildLog.segmentChop(ev.seg, finish)
		end

		table.remove(event_root, table.find(event_root, ev.other))
		ev.seg.finish = finish
		ev.other.pt = finish
		eventAdd(ev.other, ev.pt)
	end

	local function eventDivide(ev, pt)
		local ns = segmentCopy(pt, ev.seg.finish, ev.seg)
		eventUpdateEnd(ev, pt)
		return eventAddSegment(ns, ev.primary)
	end

	local function calculate(primaryPolyInverted, secondaryPolyInverted)
		-- if selfIntersection is true then there is no secondary polygon, so that isn't used

		--
		-- status logic
		--

		local status_root = {}

		local function statusCompare(ev1, ev2)
			local a1 = ev1.seg.start
			local a2 = ev1.seg.finish
			local b1 = ev2.seg.start
			local b2 = ev2.seg.finish

			if Epsilon.pointsCollinear(a1, b1, b2) then
				if Epsilon.pointsCollinear(a2, b1, b2) then
					return 1 --eventCompare(true, a1, a2, true, b1, b2)
				end
				if Epsilon.pointAboveOrOnLine(a2, b1, b2) then
					return 1
				else
					return -1
				end
			end
			if Epsilon.pointAboveOrOnLine(a1, b1, b2) then
				return 1
			else
				return -1
			end
		end

		local function checkIntersection(ev1, ev2)
			-- returns the segment equal to ev1, or false if nothing equal

			local seg1 = ev1.seg
			local seg2 = ev2.seg
			local a1 = seg1.start
			local a2 = seg1.finish
			local b1 = seg2.start
			local b2 = seg2.finish

			if buildLog then
				buildLog.checkIntersection(seg1, seg2)
			end

			local i = Epsilon.linesIntersect(a1, a2, b1, b2)

			if i == false then
				-- segments are parallel or coincident

				-- if points aren't collinear, then the segments are parallel, so no intersections
				if not Epsilon.pointsCollinear(a1, a2, b1) then
					return false
				end
				-- otherwise, segments are on top of each other somehow (aka coincident)

				if Epsilon.pointsSame(a1, b2) or Epsilon.pointsSame(a2, b1) then
					return false -- segments touch at endpoints... no intersection
				end

				local a1_equ_b1 = Epsilon.pointsSame(a1, b1)
				local a2_equ_b2 = Epsilon.pointsSame(a2, b2)

				if a1_equ_b1 and a2_equ_b2 then
					return ev2 -- segments are exactly equal
				end

				local a1_between = not a1_equ_b1 and Epsilon.pointBetween(a1, b1, b2)
				local a2_between = not a2_equ_b2 and Epsilon.pointBetween(a2, b1, b2)

				-- handy for debugging:
				-- buildLog.log({
				--	a1_equ_b1: a1_equ_b1,
				--	a2_equ_b2: a2_equ_b2,
				--	a1_between: a1_between,
				--	a2_between: a2_between
				-- })

				if a1_equ_b1 then
					if a2_between then
						--  (a1)---(a2)
						--  (b1)----------(b2)
						eventDivide(ev2, a2)
					else
						--  (a1)----------(a2)
						--  (b1)---(b2)
						eventDivide(ev1, b2)
					end
					return ev2
				elseif a1_between then
					if not a2_equ_b2 then
						-- make a2 equal to b2
						if a2_between then
							--         (a1)---(a2)
							--  (b1)-----------------(b2)
							eventDivide(ev2, a2)
						else
							--         (a1)----------(a2)
							--  (b1)----------(b2)
							eventDivide(ev1, b2)
						end
					end

					--         (a1)---(a2)
					--  (b1)----------(b2)
					eventDivide(ev2, a1)
				end
			else
				-- otherwise, lines intersect at i.pt, which may or may not be between the endpoints
				
				-- is A divided between its endpoints? (exclusive)
				if i.alongA == 0 then
					if i.alongB == -1 then -- yes, at exactly b1
						eventDivide(ev1, b1)
					elseif i.alongB == 0 then -- yes, somewhere between B's endpoints
						eventDivide(ev1, i.pt)
					elseif i.alongB == 1 then -- yes, at exactly b2
						eventDivide(ev1, b2)
					end
				end

				-- is B divided between its endpoints? (exclusive)
				if i.alongB == 0 then
					if i.alongA == -1 then -- yes, at exactly a1
						eventDivide(ev2, a1)
					elseif i.alongA == 0 then -- yes, somewhere between A's endpoints (exclusive)
						eventDivide(ev2, i.pt)
					elseif i.alongA == 1 then -- yes, at exactly a2
						eventDivide(ev2, a2)
					end
				end
			end
			return false
		end

		--
		-- main event loop
		--
		local segments = {}
		while event_root[1] ~= nil do
			local ev = event_root[1]

			if buildLog then
				buildLog.vert(ev.pt[1])
			end

			if ev.isStart then

				if buildLog then
					buildLog.segmentNew(ev.seg, ev.primary)
				end

				local transitionIndex = SortedArray.findTransition(status_root, function(here)
					local comp = statusCompare(ev, here.ev)
					return comp > 0
				end)
				
				local transitionBefore = status_root[transitionIndex - 1]
				local transitionAfter = status_root[transitionIndex]

				local above = transitionBefore and transitionBefore.ev or nil
				local below = transitionAfter and transitionAfter.ev or nil

				if buildLog then
					buildLog.tempStatus(
						ev.seg,
						above and above.seg or false,
						below and below.seg or false
					)
				end

				local eve = (above and checkIntersection(ev, above)) or (below and checkIntersection(ev, below))
				if eve then
					-- ev and eve are equal
					-- we'll keep eve and throw away ev

					-- merge ev.seg's fill information into eve.seg

					if selfIntersection then
						local toggle -- are we a toggling edge?
						if ev.seg.myFill.below == nil then
							toggle = true
						else
							toggle = ev.seg.myFill.above ~= ev.seg.myFill.below
						end

						-- merge two segments that belong to the same polygon
						-- think of this as sandwiching two segments together, where `eve.seg` is
						-- the bottom -- this will cause the above fill flag to toggle
						if toggle then
							eve.seg.myFill.above = not eve.seg.myFill.above
						end
					else
						-- merge two segments that belong to different polygons
						-- each segment has distinct knowledge, so no special logic is needed
						-- note that this can only happen once per segment in this phase, because we
						-- are guaranteed that all self-intersections are gone
						eve.seg.otherFill = ev.seg.myFill
					end

					if buildLog then
						buildLog.segmentUpdate(eve.seg)
					end

					table.remove(event_root, table.find(event_root, ev.other))
					table.remove(event_root, table.find(event_root, ev))
				end

				if event_root[1] ~= ev then
					-- something was inserted before us in the event queue, so loop back around and
					-- process it before continuing
					if buildLog then
						buildLog.rewind(ev.seg)
					end
					continue
				end

				--
				-- calculate fill flags
				--
				if selfIntersection then
					local toggle -- are we a toggling edge?
					if ev.seg.myFill.below == nil then -- if we are a new segment...
						toggle = true -- then we toggle
					else -- we are a segment that has previous knowledge from a division
						toggle = ev.seg.myFill.above ~= ev.seg.myFill.below -- calculate toggle
					end

					-- next, calculate whether we are filled below us
					if not below then -- if nothing is below us...
						-- we are filled below us if the polygon is inverted
						ev.seg.myFill.below = primaryPolyInverted
					else
						-- otherwise, we know the answer -- it's the same if whatever is below
						-- us is filled above it
						ev.seg.myFill.below = below.seg.myFill.above
					end

					-- since now we know if we're filled below us, we can calculate whether
					-- we're filled above us by applying toggle to whatever is below us
					if toggle then
						ev.seg.myFill.above = not ev.seg.myFill.below
					else
						ev.seg.myFill.above = ev.seg.myFill.below
					end
				else
					-- now we fill in any missing transition information, since we are all-knowing
					-- at this point

					if ev.seg.otherFill == nil then
						-- if we don't have other information, then we need to figure out if we're
						-- inside the other polygon
						local inside
						if not below then
							-- if nothing is below us, then we're inside if the other polygon is
							-- inverted
							if ev.primary then
								inside = secondaryPolyInverted
							else
								inside = primaryPolyInverted
							end
						else -- otherwise, something is below us
							-- so copy the below segment's other polygon's above
							if ev.primary == below.primary then
								inside = below.seg.otherFill.above
							else
								inside = below.seg.myFill.above
							end
						end
						ev.seg.otherFill = {
							above = inside,
							below = inside
						}
					end
				end

				if buildLog then
					buildLog.status(
						ev.seg,
						above and above.seg or false,
						below and below.seg or false
					)
				end

				-- insert the status and remember it for later removal
				local newStatus = {ev = ev}
				table.insert(status_root, transitionIndex, newStatus)
				ev.other.status = newStatus
			else
				local st = ev.status

				if st == nil then
					error('PolyBool: Zero-length segment detected; your epsilon is probably too small or too large')
				end
				
				local st_index = table.find(status_root, st)

				-- removing the status will create two new adjacent edges, so we'll need to check
				-- for those
				if st_index and st_index > 1 and st_index < #status_root then
					checkIntersection(status_root[st_index - 1].ev, status_root[st_index + 1].ev)
				end

				if buildLog then
					buildLog.statusRemove(st.ev.seg)
				end

				-- remove the status
				table.remove(status_root, st_index)

				-- if we've reached this point, we've calculated everything there is to know, so
				-- save the segment for reporting
				if not ev.primary then
					-- make sure `seg.myFill` actually points to the primary polygon though
					local s = ev.seg.myFill
					ev.seg.myFill = ev.seg.otherFill
					ev.seg.otherFill = s
				end
				table.insert(segments, ev.seg)
			end

			-- remove the event and continue
			table.remove(event_root, 1)
		end

		if buildLog then
			buildLog.done()
		end

		return segments
	end

	-- return the appropriate API depending on what we're doing
	if not selfIntersection then
		-- performing combination of polygons, so only deal with already-processed segments
		return {
			calculate = function(segments1, inverted1, segments2, inverted2)
				-- segmentsX come from the self-intersection API, or this API
				-- invertedX is whether we treat that list of segments as an inverted polygon or not
				-- returns segments that can be used for further operations
				for _, seg in ipairs(segments1) do
					eventAddSegment(segmentCopy(seg.start, seg.finish, seg), true)
				end
				
				for _, seg in ipairs(segments2) do
					eventAddSegment(segmentCopy(seg.start, seg.finish, seg), false)
				end
				
				return calculate(inverted1, inverted2)
			end
		}
	end

	-- otherwise, performing self-intersection, so deal with regions
	return {
		addRegion = function(region)
			-- regions are a list of points:
			--  [ [0, 0], [100, 0], [50, 100] ]
			-- you can add multiple regions before running calculate
			
			local pt1 = nil
			local pt2 = region[#region]
			
			for _, point in ipairs(region) do
				pt1 = pt2
				pt2 = point

				local forward = Epsilon.pointsCompare(pt1, pt2)
				
				if forward == 0 then -- points are equal, so we have a zero-length segment
					continue -- just skip it
					
				elseif forward < 0 then
					eventAddSegment(
						segmentNew(pt1, pt2),
						true
					)
					
				else
					eventAddSegment(
						segmentNew(pt2, pt1),
						true
					)
				end
			end
		end,
		
		calculate = function(inverted)
			-- is the polygon inverted?
			-- returns segments
			return calculate(inverted, false)
		end
	}
end

return Intersector