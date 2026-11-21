local src = io.open("/tmp/proftest.lua"):read("a")
local loader = src:match("^(.-)local P = ns.Prof")
local ns, check, getE = assert(load(loader .. "\nreturn ns, check, function() return E end"))()
local shots = 0
Screenshot = function() shots = shots + 1 end
UIParent.GetLeft = nil
ns.ProfUI:Shots()
for i = 1, 20 do local t = PENDING_TIMERS or {}; PENDING_TIMERS = {}; for _, fn in ipairs(t) do fn() end end
print("shots", shots, #ns.db.shotRects)
