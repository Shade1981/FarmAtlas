dofile("/tmp/harness/mock.lua")
local function Load()
  local ns, first = {}, #MOCK_FRAMES + 1
  for line in io.lines("FarmAtlas.toc") do
    if not line:match("^#") and line:match("%.lua%s*$") then
      local f = line:gsub("\\", "/"):gsub("%s+$", ""); assert(loadfile(f))("FarmAtlas", ns)
    end
  end
  return ns, first, #MOCK_FRAMES
end
local function Fire(a, b, ev, ...)
  for i = a, b do local fr = MOCK_FRAMES[i]; if fr.events[ev] and fr.scripts.OnEvent then fr.scripts.OnEvent(fr, ev, ...) end end
end
local E = 0
local function check(c, ...) if not c then E = E + 1 print("ERROR", ...) end end
local NOW = 1000
GetTime = function() return NOW end
GetRealmName = function() return "CAMWOW EU5 Realm 1 PvE" end
IsInGuild = function() return false end
IsInInstance = function() return false end
local chans = {}
JoinTemporaryChannel = function(n) chans[n] = 7 end
GetChannelName = function(n) return chans[n] or 0 end
LeaveChannelByName = function(n) chans[n] = nil end
local OUT = {}
C_ChatInfo.SendAddonMessage = function(p, m, c, t) OUT[#OUT + 1] = { m = m, c = c, t = t } end
local filters = {}
ChatFrame_AddMessageEventFilter = function(ev, fn) filters[ev] = fn end
local PRINTS = {}
local ME = "Shade"
UnitName = function(u) if u == "player" then return ME end return "Boar" end
local function RunTimers() for _ = 1, 3 do local t = PENDING_TIMERS or {}; PENDING_TIMERS = {}; for _, fn in ipairs(t) do fn() end end end

-- collector client (Shade)
FarmAtlasDB = nil
local A, a1, a2 = Load(); Fire(a1, a2, "ADDON_LOADED", "FarmAtlas"); Fire(a1, a2, "PLAYER_LOGIN")
local dbA = FarmAtlasDB
local pA = A.Print; A.Print = function(self, m) PRINTS[#PRINTS + 1] = m end
-- contributor client (Buddy)
FarmAtlasDB = nil; ME = "Buddy"
local B, b1, b2 = Load(); Fire(b1, b2, "ADDON_LOADED", "FarmAtlas"); Fire(b1, b2, "PLAYER_LOGIN")
local dbB = FarmAtlasDB
B.Print = function(self, m) PRINTS[#PRINTS + 1] = "B:" .. m end
check(dbB.settings.sync and dbB.settings.devShare ~= false, "default on")
check(not B.SyncDev.IsCollector() , "Buddy not collector")
ME = "Shade"; check(A.SyncDev.IsCollector(), "Shade is collector")
-- Buddy data
local K1 = B:CellKey(50.2, 50.4)
dbB.learned[2447] = { zones = { [1411] = { [K1] = { x = 50.2, y = 50.4, n = 9 } } }, mobs = { [3100] = { n = 4, lvl = 5, name = "Mottled Boar" } }, total = 9, own = true, cat = "herbalism" }
dbB.kills[3100] = 7
dbB.pools = { [180582] = { fish = { [6358] = true }, zones = { [1413] = { [B:CellKey(63.2, 50)] = { x = 63.2, y = 50, n = 5 } } } } }
dbB.trainerPos = { Kania = { mapID = 1451, x = 52.0, y = 39.7 } }
-- B joins the channel, note shown once
ME = "Buddy"; B.SyncDev.Join(); RunTimers()
check(chans.FarmAtlasData == 7, "joined channel")
-- B with nobody: nothing whispered
OUT = {}
for i = 1, 5 do B.SyncDev.Send() end
check(#OUT == 0, "nothing sent without collector")
-- fake collector on another realm is ignored
ME = "Buddy"; Fire(b1, b2, "CHAT_MSG_ADDON", "FarmAtlas", "1^CH", "CHANNEL", "Shade Tide-OtherRealm")
check(B.SyncDev.State() == nil, "other realm Shade ignored")
Fire(b1, b2, "CHAT_MSG_ADDON", "FarmAtlas", "1^CH", "CHANNEL", "Faker")
Fire(b1, b2, "CHAT_MSG_ADDON", "FarmAtlas", "1^CH", "CHANNEL", "Shade Hun")
check(B.SyncDev.State() == nil, "faker ignored")
-- data on channel from someone is ignored
Fire(b1, b2, "CHAT_MSG_ADDON", "FarmAtlas", "1^K^3100^999", "CHANNEL", "Evil")
check(not (dbB.shared.Evil), "channel data ignored")
-- collector A sends hello
ME = "Shade"; OUT = {}; A.SyncDev.Hello()
check(#OUT == 1 and OUT[1].m:match("^1%^CH") and OUT[1].c == "CHANNEL", "collector hello", OUT[1] and OUT[1].m)
-- B receives (same realm -> sender without realm)
ME = "Buddy"; Fire(b1, b2, "CHAT_MSG_ADDON", "FarmAtlas", "1^CH", "CHANNEL", "Shade Tide")
local tgt, q = B.SyncDev.State()
check(tgt == "Shade Tide" and #q > 0, "dump queued", tgt, #q)
OUT = {}
for i = 1, 200 do B.SyncDev.Send() end
check(#OUT > 0, "dump sent")
local kinds = {}
for _, o in ipairs(OUT) do check(o.c == "WHISPER" and o.t == "Shade Tide", "only to Shade Tide"); local k = o.m:match("^1%^(%u)%^"); kinds[k or "?"] = (kinds[k or "?"] or 0) + 1 end
check(kinds.C and kinds.M and kinds.K and kinds.P and kinds.T, "kinds", kinds.C, kinds.M, kinds.K, kinds.P, kinds.T)
-- A receives the whispers
ME = "Shade"
for _, o in ipairs(OUT) do Fire(a1, a2, "CHAT_MSG_ADDON", "FarmAtlas", o.m, "WHISPER", "Buddy") end
local s = dbA.shared.Buddy
check(s and s.items[2447] and s.kills[3100] == 7 and s.pools and s.pools[180582] and s.trainerPos.Kania, "collector stored Buddy data")
local got = 0 for _, p in ipairs(PRINTS) do if p:find("Buddy") then got = got + 1 end end
check(got == 1, "collector notified once", got)
-- second hello shortly after: no re-dump
ME = "Buddy"; NOW = NOW + 60; Fire(b1, b2, "CHAT_MSG_ADDON", "FarmAtlas", "1^CH", "CHANNEL", "Shade Tide")
local _, q2 = B.SyncDev.State(); check(#q2 == 0, "no redump", #q2)
-- live loot is forwarded
B:Fire("LOOT_RECORDED", 2447, 1411, K1, nil); OUT = {}
for i = 1, 5 do for _, fn in ipairs(TICKERS or {}) do pcall(fn) end end
local wh = {} for _, o in ipairs(OUT) do if o.c == "WHISPER" then wh[#wh + 1] = o end end
check(#wh >= 1 and wh[1].t == "Shade Tide", "live forwarded", #OUT, #wh)
-- collector logs off: system message hidden and queue stopped
local f = filters.CHAT_MSG_SYSTEM
check(f and f(nil, "CHAT_MSG_SYSTEM", "No player named 'Shade Tide' is currently playing.") == true, "offline msg hidden")
B:Fire("LOOT_RECORDED", 2447, 1411, K1, nil); OUT = {}
for i = 1, 5 do B.SyncDev.Send() end
check(#OUT == 0, "nothing after offline")
check(f(nil, "CHAT_MSG_SYSTEM", "No player named 'Other' is currently playing.") == false, "other msg kept")
-- collector stale -> nothing
ME = "Buddy"; NOW = NOW + 1000; Fire(b1, b2, "CHAT_MSG_ADDON", "FarmAtlas", "1^CH", "CHANNEL", "Shade Tide")
local _, q3 = B.SyncDev.State(); check(#q3 > 0, "redump after away")
NOW = NOW + 400; OUT = {}; B.SyncDev.Send(); check(#OUT == 0, "stale collector: stop")
-- switched off: nothing
dbB.settings.devShare = false; NOW = NOW + 1000
Fire(b1, b2, "CHAT_MSG_ADDON", "FarmAtlas", "1^CH", "CHANNEL", "Shade Tide")
OUT = {}; for i = 1, 5 do B.SyncDev.Send() end; check(#OUT == 0, "off: nothing")
-- note printed once
local notes = 0 for _, p in ipairs(PRINTS) do if p:find("B:") and p:find("community") then notes = notes + 1 end end
print("notes", notes)
-- echo: collector's own guild message comes back as "Shade Tide" -> not stored, full name learned
ME = "Shade"; dbA.shared["Shade Tide"] = nil
SENT_OUT = {}
OUT = {}; A.SyncDev.Hello()
Fire(a1, a2, "CHAT_MSG_ADDON", "FarmAtlas", OUT[#OUT].m, "CHANNEL", "Shade Tide")
check(A.SyncDev.IsCollector(), "Shade Tide still collector after echo")
-- another "Shade ..." (same first name) sends the same CH text: must not be taken as our echo
OUT = {}; A.SyncDev.Hello()
local mine = OUT[#OUT].m
local theirs = mine:gsub("%^[^%^]*$", "^424242")
Fire(a1, a2, "CHAT_MSG_ADDON", "FarmAtlas", theirs, "CHANNEL", "Shade Hun")
Fire(a1, a2, "CHAT_MSG_ADDON", "FarmAtlas", "1^CH^" .. tostring(A.version), "CHANNEL", "Shade Hun")
check(A.SyncDev.IsCollector(), "other Shade's CH does not disable the collector")
Fire(a1, a2, "CHAT_MSG_ADDON", "FarmAtlas", "1^K^3100^5", "GUILD", "Shade Walker")
check(A.SyncDev.IsCollector(), "other Shade's data does not disable the collector")
Fire(a1, a2, "CHAT_MSG_ADDON", "FarmAtlas", "1^K^3100^5", "GUILD", "Shade Tide")
check(not dbA.shared["Shade Tide"], "own echo not stored")
-- the other character "Shade Hun": after its echo it is not a collector
FarmAtlasDB = nil; ME = "Shade"
local C, c1, c2 = Load(); Fire(c1, c2, "ADDON_LOADED", "FarmAtlas"); Fire(c1, c2, "PLAYER_LOGIN")
C.SyncDev.Join(); RunTimers(); OUT = {}; C.SyncDev.Hello()
Fire(c1, c2, "CHAT_MSG_ADDON", "FarmAtlas", OUT[#OUT].m, "CHANNEL", "Shade Hun")
check(not C.SyncDev.IsCollector(), "Shade Hun not collector")
print("DEV ERRORS:", E)
-- collector status
ME = "Shade"; PRINTS = {}
A.SyncDev.Status()
local st = table.concat(PRINTS, "\n")
check(st:find("Buddy") and st:find("farmhely"), "status lists Buddy", st)
NOW = NOW + 100; PRINTS = {}
for _, fn in ipairs(TICKERS or {}) do pcall(fn) end
local done = table.concat(PRINTS, "\n")
check(done:find("csomagja megj"), "done line", done)
SlashCmdList.FARMATLAS("gyujtes")
print("STATUS DEMO:\n" .. table.concat(PRINTS, "\n"))
-- version notice
ME = "Buddy"; PRINTS = {}
Fire(b1, b2, "CHAT_MSG_ADDON", "FarmAtlas", "1^CH^1.6.0", "CHANNEL", "Shade Tide"); RunTimers()
check(#PRINTS == 0, "older version: no notice")
Fire(b1, b2, "CHAT_MSG_ADDON", "FarmAtlas", "1^CH^9.9.9", "CHANNEL", "Shade Tide"); RunTimers()
check(#PRINTS == 0, "absurd version ignored")
Fire(b1, b2, "CHAT_MSG_ADDON", "FarmAtlas", "1^CH^9.7.0", "CHANNEL", "Faker"); RunTimers()
check(#PRINTS == 0, "faker version ignored")
Fire(b1, b2, "CHAT_MSG_ADDON", "FarmAtlas", "1^CH^1.8.0", "CHANNEL", "Shade Tide"); RunTimers()
check(#PRINTS == 1 and PRINTS[1]:find("1.8.0"), "update notice", PRINTS[1])
Fire(b1, b2, "CHAT_MSG_ADDON", "FarmAtlas", "1^H^1^0^Pal^1.9.0", "GUILD", "Pal"); RunTimers()
check(#PRINTS == 1, "only once per session")
print(PRINTS[1])
print("DEV2 ERRORS:", E)
-- relay: Buddy has guild data from "Pál Kovács" and passes it on with the finder's name
ME = "Buddy"
dbB.settings.devShare = true
dbB.shared["Pál Kovács"] = { seen = 1, nItems = 1, kills = { [3101] = 12 },
  items = { [2447] = { zones = { [1411] = { [B:CellKey(10.2, 20.4)] = { x = 10.2, y = 20.4, n = 4 } } }, mobs = { [3101] = { n = 3, lvl = 6, name = "Bristleback" } } } },
  trainerPos = { Kania = { mapID = 1451, x = 52.0, y = 39.7 } } }
dbB.shared["Shade Tide"] = { seen = 1, nItems = 0, kills = { [9] = 99 }, items = {} }
NOW = NOW + 5000
Fire(b1, b2, "CHAT_MSG_ADDON", "FarmAtlas", "1^CH^1.6.1", "CHANNEL", "Shade Tide")
OUT = {}
for i = 1, 400 do B.SyncDev.Send() end
local F, own = 0, 0
for _, o in ipairs(OUT) do if o.m:match("^1%^F%^") then F = F + 1; check(#o.m <= 255, "relay msg length", #o.m) else own = own + 1 end
  check(not o.m:find("Shade Tide"), "collector's own data not relayed") end
check(F >= 3 and own > 0, "relay sent", F, own)
ME = "Shade"; PRINTS = {}
dbA.shared["Pál Kovács"] = { seen = 1, nItems = 1, kills = { [3101] = 50 }, items = {} }
for _, o in ipairs(OUT) do Fire(a1, a2, "CHAT_MSG_ADDON", "FarmAtlas", o.m, "WHISPER", "Buddy") end
local pk = dbA.shared["Pál Kovács"]
check(pk and pk.items[2447] and next(pk.items[2447].zones[1411]) and pk.items[2447].mobs[3101], "relayed into finder's bucket")
check(pk.kills[3101] == 50, "relayed older value does not lower", pk.kills[3101])
check(pk.trainerPos and pk.trainerPos.Kania, "relayed trainer")
-- relayed F from a non-collector is ignored
ME = "Buddy"; local before = dbB.shared["Zed"]
Fire(b1, b2, "CHAT_MSG_ADDON", "FarmAtlas", "1^F^Zed^K^3100^5", "WHISPER", "Evil")
check(not dbB.shared["Zed"], "non-collector ignores F")
-- live relay: Buddy gets a guild message while Shade is active -> forwarded
OUT = {}
Fire(b1, b2, "CHAT_MSG_ADDON", "FarmAtlas", "1^K^3200^7", "GUILD", "Guildie")
for i = 1, 400 do B.SyncDev.Send() end
local live = false for _, o in ipairs(OUT) do if o.m == "1^F^Guildie^K^3200^7" then live = true end end
check(live, "live relay")
-- real db tables are back after a relay build
check(dbB.learned[2447] and dbB.kills[3100] == 7, "own tables restored")
print("RELAY ERRORS:", E)
-- restore with WoW Forever full names: holder B keeps "Shade Tide"; hello from "Shade Tide" lists "Shade"
ME = "Buddy"; OUT = {}
dbB.shared["Shade Tide"] = { seen = 1, nItems = 5, nRecipes = 0, kills = { [3100] = 9 },
  items = { [2447] = { zones = { [1411] = { [B:CellKey(30, 30)] = { x = 30, y = 30, n = 3 } } }, mobs = {} } } }
Fire(b1, b2, "CHAT_MSG_ADDON", "FarmAtlas", "1^H^0^0^Shade^1.6.2", "GUILD", "Shade Tide")
RunTimers(); for i = 1, 30 do for _, fn in ipairs(TICKERS or {}) do pcall(fn) end end
local rs = false for _, o in ipairs(OUT) do if o.m:match("^1%^S%^") or o.m:match("^1%^X") then rs = true end end
check(rs, "restore starts for full name", #OUT)
print("RESTORE-NAME ERRORS:", E)
-- realm name missing on this login: the collector is still recognised by its GUID realm
local saveR, saveG = GetRealmName, UnitGUID
GetRealmName = function() return "" end
UnitGUID = function(u) return "Player-6855-001B5338" end
dbA.lastRealm = nil
ME = "Shade"
-- a fresh selfFull-free client
FarmAtlasDB = nil
local D, d1, d2 = Load(); Fire(d1, d2, "ADDON_LOADED", "FarmAtlas"); Fire(d1, d2, "PLAYER_LOGIN")
check(D.SyncDev.IsCollector(), "collector by GUID realm when the realm name is empty")
UnitGUID = function(u) return "Player-1-001B5338" end
check(not D.SyncDev.IsCollector(), "other realm id: not collector")
GetRealmName, UnitGUID = saveR, saveG
print("REALM ERRORS:", E)
