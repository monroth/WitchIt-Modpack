-- The load order of packages: a package loads after the packages it needs (manifest `needs`) and
-- after those it wants to see when they are there (`after`); among those ready, by name.
-- found: id -> manifest. Core and UIKit load before all of them (ready = given).
-- Returns the ids in order, and why each other enabled package cannot load.
return function(found, ready)
    local loaded, order, skipped = {}, {}, {}
    for _, id in ipairs(ready or {}) do loaded[id] = true end
    local waiting = {}
    for id, m in pairs(found) do
        if not loaded[id] and m.enabled ~= false then waiting[id] = m end
    end
    local function fits(id, m)
        for _, need in ipairs(m.needs or {}) do if not loaded[need] then return false end end
        for _, other in ipairs(m.after or {}) do if waiting[other] then return false end end
        return true
    end
    while true do
        local best
        for id, m in pairs(waiting) do
            if fits(id, m) and (not best or id < best) then best = id end
        end
        if not best then break end
        order[#order + 1] = best; loaded[best] = true; waiting[best] = nil
    end
    for id, m in pairs(waiting) do
        local missing = {}
        for _, need in ipairs(m.needs or {}) do if not loaded[need] then missing[#missing + 1] = need end end
        skipped[id] = 'needs '..table.concat(missing, ', ')
    end
    return order, skipped
end
