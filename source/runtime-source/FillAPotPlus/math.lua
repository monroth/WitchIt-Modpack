local M={}
-- Authored saves are distinct maps; stock layout variants share a world identity.
-- Never shuffle caller arrays or retry random picks from an exhausted pool.
local function identity(row)
    local key=row and row.file
    return key and key:gsub('\\','/'):lower()
end
function M.selectOffers(current,pools,random)
    -- The current map, a random official Fill a Pot map, a random modpack map of the Official tab,
    -- a random one of the Featured tab, then any of those; saved (custom) maps are not offered.
    -- A slot whose pool is spent takes any map not offered yet.
    local offers,seen={},{}; random=random or math.random
    local function take(pool)
        local candidates,unique={},{}
        for _,row in ipairs(pool or {})do
            local key=identity(row)
            if key and not seen[key] and not unique[key]then candidates[#candidates+1]=row;unique[key]=true end
        end
        if #candidates==0 then return false end
        local row=candidates[random(#candidates)];offers[#offers+1]=row;seen[identity(row)]=true;return true
    end
    local all={}
    for _,pool in ipairs({pools.vanilla,pools.official,pools.featured})do
        for _,row in ipairs(pool or {})do all[#all+1]=row end
    end
    if not(current and take({current}))then take(all)end
    for _,pool in ipairs({pools.vanilla,pools.official,pools.featured,all})do if not take(pool)then take(all)end end
    return offers
end
-- Mirrors native highest-vote, random-tie behaviour.
function M.winner(counts,count,random)
    random=random or math.random
    local highest,ties=-1,{}
    for i=1,count do local votes=counts[i]
        if votes~=nil then
            if votes>highest then highest=votes;ties={i}elseif votes==highest then ties[#ties+1]=i end
        end
    end
    if #ties>0 then return ties[random(#ties)],highest end
end
function M.closePercent(distanceSq,maxDistanceSq)
    return 1-math.sqrt(math.min(distanceSq or maxDistanceSq,maxDistanceSq))/math.sqrt(maxDistanceSq)
end
function M.quantity(info)
 return tostring(math.max(1,math.min(info.pots,255,info.target or 3)))..'/'..tostring(info.pots)
end
return M
