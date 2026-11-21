dofile("/tmp/harness/mock.lua")
local function Load() local ns={} local first=#MOCK_FRAMES+1
 for line in io.lines("FarmAtlas.toc") do if not line:match("^#") and line:match("%.lua%s*$") then local f=line:gsub("\\","/"):gsub("%s+$",""); assert(loadfile(f))("FarmAtlas",ns) end end
 for i=first,#MOCK_FRAMES do local fr=MOCK_FRAMES[i]; if fr.events.ADDON_LOADED and fr.scripts.OnEvent then fr.scripts.OnEvent(fr,"ADDON_LOADED","FarmAtlas") end end
 return ns end
local E=0
UnitName=function(u) if u=="player" then return "Shade" end return "x" end
FarmAtlasDB={ chars={ ["Forever-Shade"]={ recipes={ Old=true }, bags={}, bank={}, goals={} } } }
UnitGUID=function(u) return "Player-1-AAAA" end
local A=Load(); A:CharData().recipes.Tide=true
local db=FarmAtlasDB
UnitGUID=function(u) return "Player-1-BBBB" end
local B=Load(); B:CharData().recipes.Hun=true
local ka, kb = "Forever-Shade@Player-1-AAAA", "Forever-Shade@Player-1-BBBB"
if not (db.chars[ka] and db.chars[ka].recipes.Old and db.chars[ka].recipes.Tide and not db.chars[ka].recipes.Hun) then E=E+1 print("A wrong") end
if not (db.chars[kb] and db.chars[kb].recipes.Hun and not db.chars[kb].recipes.Tide) then E=E+1 print("B wrong") end
if db.chars["Forever-Shade"] then E=E+1 print("old key left") end
local mine, alts = B:RecipeKnown("Tide"); if mine or alts[1] ~= "Shade" then E=E+1 print("alts", mine, alts[1]) end
print("CHAR ERRORS", E)
