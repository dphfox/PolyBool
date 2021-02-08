--[[
	Adapted from PolyBool (github.com/voidqk/polybooljs) under the MIT license.
	(c) 2016 Sean Connelly (@voidqk)
	
	Original Lua port by EgoMoose.
	Refactor and optimisations by Elttob.
]]

--[[
	Provides the raw computation functions that take epsilon into account.
	Zero is defined to be between (-epsilon, epsilon), exclusive.
]]

local Epsilon = {}

local epsilon = 0.0000000001

function Epsilon.epsilon(newEpsilon)
	if typeof(newEpsilon) == "number" then
		epsilon = newEpsilon
	end
	return epsilon
end

function Epsilon.pointAboveOrOnLine(pt, left, right)
	local Ax = left[1]
	local Ay = left[2]
	local Bx = right[1]
	local By = right[2]
	local Cx = pt[1]
	local Cy = pt[2]
	return (Bx - Ax) * (Cy - Ay) - (By - Ay) * (Cx - Ax) >= -epsilon
end

function Epsilon.pointBetween(p, left, right)
	-- p must be collinear with left->right
	-- returns false if p == left, p == right, or left == right
	local d_py_ly = p[2] - left[2]
	local d_rx_lx = right[1] - left[1]
	local d_px_lx = p[1] - left[1]
	local d_ry_ly = right[2] - left[2]

	local dot = d_px_lx * d_rx_lx + d_py_ly * d_ry_ly
	-- if `dot` is 0, then `p` == `left` or `left` == `right` (reject)
	-- if `dot` is less than 0, then `p` is to the left of `left` (reject)
	if (dot < epsilon) then
		return false
	end

	local sqlen = d_rx_lx * d_rx_lx + d_ry_ly * d_ry_ly
	-- if `dot` > `sqlen`, then `p` is to the right of `right` (reject)
	-- therefore, if `dot - sqlen` is greater than 0, then `p` is to the right of `right` (reject)
	if (dot - sqlen > -epsilon) then
		return false
	end

	return true
end

function Epsilon.pointsSameX(p1, p2)
	return math.abs(p1[1] - p2[1]) < epsilon
end

function Epsilon.pointsSameY(p1, p2)
	return math.abs(p1[2] - p2[2]) < epsilon
end

function Epsilon.pointsSame(p1, p2)
	return math.abs(p1[1] - p2[1]) < epsilon and math.abs(p1[2] - p2[2]) < epsilon
end
	
function Epsilon.pointsCompare(p1, p2)
	-- returns -1 if p1 is smaller, 1 if p2 is smaller, 0 if equal
	if math.abs(p1[1] - p2[1]) < epsilon then
		if math.abs(p1[2] - p2[2]) < epsilon then
			return 0
		elseif p1[2] < p2[2] then
			return -1
		else
			return 1
		end
	elseif p1[1] < p2[1] then
		return -1
	else
		return 1
	end
end

function Epsilon.pointsCollinear(pt1, pt2, pt3)
	-- does pt1->pt2->pt3 make a straight line?
	-- essentially this is just checking to see if the slope(pt1->pt2) === slope(pt2->pt3)
	-- if slopes are equal, then they must be collinear, because they share pt2
	local dx1 = pt1[1] - pt2[1]
	local dy1 = pt1[2] - pt2[2]
	local dx2 = pt2[1] - pt3[1]
	local dy2 = pt2[2] - pt3[2]
	return math.abs(dx1 * dy2 - dx2 * dy1) < epsilon
end

function Epsilon.linesIntersect(a0, a1, b0, b1)
	-- returns false if the lines are coincident (e.g., parallel or on top of each other)
	--
	-- returns an object if the lines intersect:
	--   {
	--     pt: [x, y],    where the intersection point is at
	--     alongA: where intersection point is along A,
	--     alongB: where intersection point is along B
	--   }
	--
	--  alongA and alongB will each be one of: -2, -1, 0, 1, 2
	--
	--  with the following meaning:
	--
	--    -2   intersection point is before segment's first point
	--    -1   intersection point is directly on segment's first point
	--     0   intersection point is between segment's first and second points (exclusive)
	--     1   intersection point is directly on segment's second point
	--     2   intersection point is after segment's second point
	local adx = a1[1] - a0[1]
	local ady = a1[2] - a0[2]
	local bdx = b1[1] - b0[1]
	local bdy = b1[2] - b0[2]

	local axb = adx * bdy - ady * bdx
	if math.abs(axb) < epsilon then
		return false -- lines are coincident
	end

	local dx = a0[1] - b0[1]
	local dy = a0[2] - b0[2]

	local A = (bdx * dy - bdy * dx) / axb
	local B = (adx * dy - ady * dx) / axb

	local ret = {
		alongA = 0,
		alongB = 0,
		pt = {
			a0[1] + A * adx,
			a0[2] + A * ady
		}
	};

	-- categorize where intersection point is along A and B

	if A <= -epsilon then
		ret.alongA = -2
	elseif A < epsilon then
		ret.alongA = -1
	elseif A - 1 <= -epsilon then
		ret.alongA = 0
	elseif A - 1 < epsilon then
		ret.alongA = 1
	else
		ret.alongA = 2
	end

	if B <= -epsilon then
		ret.alongB = -2
	elseif B < epsilon then
		ret.alongB = -1
	elseif B - 1 <= -epsilon then
		ret.alongB = 0
	elseif B - 1 < epsilon then
		ret.alongB = 1
	else
		ret.alongB = 2
	end

	return ret
end

function Epsilon.pointInsideRegion(pt, region)
	local x = pt[1]
	local y = pt[2]
	local lastPoint = region[#region]
	local last_x = lastPoint[1]
	local last_y = lastPoint[2]
	local inside = false
	
	for index, currPoint in ipairs(region) do
		local curr_x = currPoint[1]
		local curr_y = currPoint[2]

		-- if y is between curr_y and last_y, and
		-- x is to the right of the boundary created by the line
		if index ~= 1 and (curr_y - y > epsilon) ~= (last_y - y > epsilon) and (last_x - curr_x) * (y - curr_y) / (last_y - curr_y) + curr_x - x > epsilon then
			inside = not inside
		end

		last_x = curr_x
		last_y = curr_y
	end
	return inside
end

return Epsilon