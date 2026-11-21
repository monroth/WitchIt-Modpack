-- A mid-match row must be selectable for details without calling native Join.
local posts,pres={},{ }
local R={log=function() end,post=function(p,fn)posts[p]=fn end,pre=function(p,fn)pres[p]=fn end,valid=function(x) return x and not x.dead and x or nil end}
dofile('candidate/runtime-source/Core/tests/lib/mods.lua')(R)
R.json=dofile('candidate/runtime-source/WitchItRuntime/Scripts/json.lua')
local serial=0
local function object()
 serial=serial+1
 local o={id=serial}
 function o:GetAddress()return self.id end
 function o:SetIsEnabled(value)self.enabled=value end
 function o:SetVisibility(value)self.visibility=value end
 function o:SetActiveState(value)self.active=value end
 return o
end
FName=function(v)return v end
local data=object()
local host={protocol=3,packages={core='5.0.0'},required={},require_modpack=false,vanilla=false}
data.ExtraSettings={ForEach=function() end,Contains=function(_,key)return key=='WitchItModpack'end,
 Find=function()return {get=function()return {Data={AsString=R.json.encode(host)}}end}end}
function data:GetServerName()return 'Server'end
local screen=object();screen.FoundServers={data};screen.ServerListView=object()
local info
local state={screen=screen,modded=true,panel=object(),tab=object(),body={Slot={SetOffsets=function(self,value)self.offsets=value end}},
 wide={},join=object(),info=function(rows)local t={};for _,r in ipairs(rows) do t[#t+1]=(r.red and '!' or '')..r.text end;info=table.concat(t,'\n') end}
local I={play='/Game/UserInterface/Play/',screens={[screen.id]={browser=state}},resets={},destructors={},
 id=function(v)return v.id end,values=function(v)return v end,string=function(v)return v end}
local kept={}
local C={state=function() end,mods=dofile('candidate/runtime-source/Core/modpack.lua')(R.json,R.manifests),memory={keep=function(k,v) kept[k]=v end,kept=function(k) return kept[k] end}}
C.mods.status=function() return {packages={{id='Core',enabled=true,version='5.0.0'}}} end
dofile('candidate/runtime-source/UIKit/browser.lua')(R,C,{},I)
local listpath=I.play..'WB_ServerList.WB_ServerList_C:'
local function filtered(item,native)
 local value=native
 posts[listpath..'ServerPassesCurrentFilter'](screen,item,{get=function()return value end,set=function(_,v)value=v end})
 return value
end
assert(filtered(data,true),'Modded keeps advertised native rows')
local vanilla=object();vanilla.ExtraSettings={ForEach=function() end,Contains=function()return false end}
assert(not filtered(vanilla,true),'Modded excludes vanilla rows at the native filter boundary')
assert(not filtered(data,false),'Modded preserves native filter refusals')
-- (user) Console-only servers come back in Core's searches (to find modded servers, which say
-- they are): unmodded ones never show, modded ones do.
local ps5=object();ps5.ExtraSettings={ForEach=function() end,Contains=function(_,k) return k=='PS5Exclusive' end,Find=function() return {get=function() return {Data={AsBool=true}} end} end}
assert(not filtered(ps5,true),'a real PS5-only server is left out')
local cross=object();cross.ExtraSettings={ForEach=function() end,Contains=function(_,k) return k=='PS5Exclusive' end,Find=function() return {get=function() return {Data={AsBool=false}} end} end}
state.modded=false
assert(filtered(cross,true),'an ordinary server stays in the game tabs')
state.modded=true
state.selected=data
posts[listpath..'RemoveAllServers'](screen)
assert(state.selected==nil and not state.join.enabled,'native refresh clears selection without repopulating stale results')
-- A native refresh can retire FoundServers immediately after clearing its rows.
-- The view must never own ClearListItems/AddItem during that native lifetime.
local gone=object();gone.ServerRowDataObject=data;gone.SelectServer=object()
function gone:Get_SelectServer_bIsEnabled_0()return false end
posts[I.play..'WB_ServerRow.WB_ServerRow_C:SetWidgetValues'](gone)
gone.dead=true;gone.ServerRowDataObject=nil
setmetatable(gone,{__index=function() error('Native object expired') end})
screen.FoundServers={vanilla,data}
posts[listpath..'AddServersSorted'](screen)
local path=I.play..'WB_ServerRow.WB_ServerRow_C:'
local row=object();row.ServerRowDataObject=data;row.SelectServer=object()
function row:Get_SelectServer_bIsEnabled_0()return false end
posts[path..'SetWidgetValues'](row)
assert(row.SelectServer.enabled,'mid-match rows activate the details selector')
assert(pres[path..'ClickedServer'](row)==true and state.compatible and not info:find(': host ',1,true) and state.join.enabled,
 'row activation selects compatibility details and consumes the native join route')
posts[I.play..'WB_ServerList.WB_ServerList_C:ChangeFilter'](screen)
assert(not row.SelectServer.enabled and not state.modded,'native tab exit restores the original disabled decision')
assert(kept.servers and kept.servers.modded==false,'the servers looked for are remembered')
state.modded=true;posts[path..'SetWidgetValues'](row)
posts[path..'BP_OnEntryReleased'](row)
assert(not row.SelectServer.enabled,'pooled row release restores the native decision')
row.SelectServer:SetIsEnabled(true)
for _,reset in ipairs(I.resets)do reset()end
posts[I.play..'WB_ServerList.WB_ServerList_C:ChangeFilter'](screen)
assert(row.SelectServer.enabled,'world reset forgets rows without touching expired objects')
print('PASS mid-match native browser row details, compatibility, tab exit, pooled release and world reset')
