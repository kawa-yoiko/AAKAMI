local segIntscLen = function (l1, r1, l2, r2)
    return math.max(0, math.min(r1, r2) - math.max(l1, l2))
end

local D = 4 -- Maximum push-away distance

local inSegFuzzy = function (x, l, r)
    return x >= l - D and x < r + D
end

-- Returns bitmask of b's intersection on a
-- 1, 2, 4, 8: L, R, U, D
-- 16, 32, 64, 128: UL, UR, DL, DR
-- Requires bit module by LuaJIT
local rectIntsc = function (a, b)
    local xIntsc = segIntscLen(a[1], a[1] + a[3], b[1], b[1] + b[3])
    local yIntsc = segIntscLen(a[2], a[2] + a[4], b[2], b[2] + b[4])
    if xIntsc == 0 or yIntsc == 0 then return nil end

    local r = 0
    if inSegFuzzy(a[1], b[1], b[1] + b[3]) then r = bit.bor(r, 1) end
    if inSegFuzzy(a[1] + a[3], b[1], b[1] + b[3]) then r = bit.bor(r, 2) end
    if inSegFuzzy(a[2], b[2], b[2] + b[4]) then r = bit.bor(r, 4) end
    if inSegFuzzy(a[2] + a[4], b[2], b[2] + b[4]) then r = bit.bor(r, 8) end
    if bit.band(r, 5) == 5 then r = bit.bor(r, 16) end
    if bit.band(r, 6) == 6 then r = bit.bor(r, 32) end
    if bit.band(r, 9) == 9 then r = bit.bor(r, 64) end
    if bit.band(r, 10) == 10 then r = bit.bor(r, 128) end
    return r, xIntsc, yIntsc
end
--[[
print(rectIntsc({0, 0, 1, 1}, {0.5, 0.5, 0.2, 1}))  -- 8
print(rectIntsc({0, 0, 1, 1}, {0.5, 0.5, 1, 1}))    -- 138
print(rectIntsc({0, 0, 1, 1}, {-0.5, 0.5, 1, 1}))   -- 73
print(rectIntsc({0, 0, 1, 1}, {0.5, -0.5, 1, 1}))   -- 38
]]

return function () return {

component = 'dim',
update = function (self, es)
    -- TODO: Optimize if this becomes the bottleneck

    -- Checks whether e1 collides with any other entity
    -- Returns (delta X, delta Y)
    local check = function (e1)
        local intsc = 0
        local x0, y0, xy0 = 0, 0, 0
        for _, e2 in pairs(es) do if e2 ~= e1 and e2.block then
            local r, x1, y1 = rectIntsc(e1.dim, e2.dim)
            if r ~= nil then
                intsc = bit.bor(intsc, r)
                x0 = math.max(x0, x1)
                y0 = math.max(y0, y1)
                xy0 = math.max(xy0, math.min(x1, y1))
            end
        end end
        if intsc == 0 then return nil end
        local x, y, d = 1e10, 1e10, 1e10
        if x0 < D then
            if bit.band(intsc, 1) == 0 then x, y, d = -x0, 0, x0 end
            if bit.band(intsc, 2) == 0 then x, y, d = x0, 0, x0 end
        end
        if y0 < D and y0 < d then
            if bit.band(intsc, 4) == 0 then x, y, d = 0, -y0, y0 end
            if bit.band(intsc, 8) == 0 then x, y, d = 0, y0, y0 end
        end
        if xy0 * 2 < D and xy0 * 2 < d then
            if bit.band(intsc, 16) == 0 then x, y, d = -xy0, -xy0, xy0 * 2 end
            if bit.band(intsc, 32) == 0 then x, y, d = xy0, -xy0, xy0 * 2 end
            if bit.band(intsc, 64) == 0 then x, y, d = -xy0, xy0, xy0 * 2 end
            if bit.band(intsc, 128) == 0 then x, y, d = xy0, xy0, xy0 * 2 end
        end
        return x, y
    end

    for _, e1 in pairs(es) do if e1.passiveCollide then
        local x, y = check(e1)
        if x ~= nil then
            e1.dim[1] = e1.dim[1] + x
            e1.dim[2] = e1.dim[2] + y
            if x ~= 0 then e1.vel[1] = 0 end
            if y ~= 0 then e1.vel[2] = 0 end
        end
    end end
end

} end