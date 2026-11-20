local hooks,events,timers,receive,preHooks={},{},{},nil,{}
FText=function(v)return v end
local R={native={}}
function R.post(path,fn) hooks[path]=fn end
function R.pre(path,fn)preHooks[path]=fn end
function R.on(event,fn)events[event]=fn end
function R.valid(v)return v end
function R.after(ms,fn)
 local t={ms=ms,fn=fn};timers[#timers+1]=t
 return function()t.cancelled=true end
end
local parent={children={},Slot={LayoutData={Alignment={Y=.5}},bAutoSize=true}}
function parent:AddChild(row)self.children[#self.children+1]=row end
function parent:GetAllChildren()return self.children end
function parent.Slot:GetOffsets()return {Left=0,Top=0,Right=800,Bottom=240}end
function parent.Slot:SetOffsets(value)self.offsets=value end
function parent.Slot:SetAutoSize(value)self.bAutoSize=value end
local function line()
 local row={visibility=0,TeamAText={ColorAndOpacity={}},TeamBText={ColorAndOpacity={}},FadeIn={}}
 for _,text in ipairs({row.TeamAText,row.TeamBText})do function text:SetColorAndOpacity(value)self.colour=value end end
 function row:GetParent()return parent end
 function row:GetClass()return 'native-line' end
 function row:GetVisibility()return self.visibility end
 function row:SetVisibility(v)self.visibility=v end
 function row:SetRenderOpacity(v)self.opacity=v end
 function row:RemoveFromParent()self.removed=true;for i,child in ipairs(parent.children)do if child==self then table.remove(parent.children,i);break end end end
 function row:PlayAnimation()self.animated=true end
 return row
end
local original=line();parent:AddChild(original)
local w={WB_ObjectiveResultLine1=original,Victory={SetToolTipText=function(self,text)self.tooltip=text end}}
function w:GetOwningPlayer()return {}end
function w:InitializeResultLine(row)row.initialized=true end
function w:GetAddress()return 12 end
StaticFindObject=function()return {Create=function(_,owner,class)assert(owner==w and class=='native-line');return line()end}end
local session={gs={WinningReasonIndex=7},mode='monroth.fap',role='client'}
local S={CRITERIA={{key='wins',reason=1},{key='pots',reason=7},{key='lives',reason=4},{key='kills',reason=6},{key='time',reason=2},{key='props',reason=5}},R=R,C={session=function()return session end,net={watch=function(_,fn)receive=fn end}},O='O/'}
function S.path(folder,name,event)return folder..name..(event and ':'..event or '')end
dofile('candidate/runtime-source/FillAPotPlus/tests/lib/scope.lua')(S)
function S.values(v)return v end
function S.order()return {'wins','pots','lives','kills','time','props'}end
S.criteria={wins='Halves won',pots='Full cauldrons',lives='Witch lives remaining',kills='Hunter kills',time='Time',props='Delivered props'}
dofile('candidate/runtime-source/FillAPotPlus/results.lua')(S)
local fact={normal=true,order='',used={'wins','pots','lives','kills','time','props'},team=1,reason='pots',infinite=false,
 a={wins=1,pots=3,lives=7,kills=2,time=85,props=5,finished=false},b={wins=1,pots=2,lives=3,kills=1,time=80,props=4,finished=false}}
local construct=hooks['/Game/UserInterface/MatchResult/ObjectivemodeResult/WB_ObjectiveResultScreen.WB_ObjectiveResultScreen_C:Construct']
local show=hooks['/Game/Blueprints/UserInterface/B_IngameUIManager.B_IngameUIManager_C:ShowObjectiveResult']
construct(w)
assert(#parent.children==1,'Early native construction precedes the result fact')
receive(fact)
original.visibility=0 -- Native display resets its own rows after the early fact.
local earlyTimers=timers;timers={}
show({ObjectiveResultWidget=w})
assert(earlyTimers[1].cancelled,'The early fact reveal is replaced after the native display body')
assert(#parent.children==7 and original.visibility==1 and parent.Slot.offsets.Bottom==360)
assert(parent.Slot.offsets.Top==60 and not parent.Slot.bAutoSize,'allocation keeps the original top edge with centred alignment')
assert(parent.children[6].TeamAScore=='1:25' and parent.children[6].TeamBScore=='1:20')
assert(parent.children[3].TeamATeam==0 and parent.children[3].TeamBTeam==1)
assert(parent.children[3].TeamAText.colour.SpecifiedColor.G==1 and parent.children[3].TeamBText.colour.SpecifiedColor.G==0)
assert(#timers==3 and timers[1].ms==750 and timers[2].ms==1500)
timers[1].fn();assert(parent.children[2].visibility==0 and parent.children[3].visibility==2)
timers[2].fn();assert(parent.children[7].visibility==0 and parent.children[7].opacity==.4)
timers[3].fn();assert(w.PlayVictoryLogo)
local priorTimers=timers;timers={}
original.visibility=0
show({ObjectiveResultWidget=w})
assert(#parent.children==7 and original.visibility==1,'Native cached display repaints six rows after native initialization')
assert(priorTimers[1].cancelled,'Native display cancels the previous finite reveal')
preHooks['/Script/UMG.UserWidget:Destruct'](w)
assert(#parent.children==1 and original.visibility==0 and parent.Slot.offsets.Bottom==240 and parent.Slot.bAutoSize,'native cached close restores the original allocation and removes owned rows')
hooks['/Game/UserInterface/MatchResult/ObjectivemodeResult/WB_ObjectiveResultScreen.WB_ObjectiveResultScreen_C:Construct'](w)
assert(#parent.children==7,'reopening the same native screen cannot accumulate rows')
events.world_end();assert(timers[1].cancelled)
print('PASS native result rows, roles, m:ss, deciding colours, finite reveal and native cached display ordering')
