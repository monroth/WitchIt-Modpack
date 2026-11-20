local Layout=dofile('candidate/runtime-source/FillAPotPlus/bar_layout.lua')
for n=1,10 do
 local plan,width=Layout.layout(n);assert(#plan==n*4 and width>0)
 local previous=0
 for _,piece in ipairs(plan)do
  assert(piece.dst==previous and piece.w>0 and piece.src[2]>piece.src[1])
  previous=previous+piece.w
 end
 assert(previous==width)
 if n==3 then assert(width==512)end
end
local created=0
local function slot()
 return {Size={},Padding={Left=0,Top=0,Right=0,Bottom=0},HorizontalAlignment=2,VerticalAlignment=2,
  LayoutData={Offsets={Left=1,Top=2,Right=512,Bottom=64}},
  SetHorizontalAlignment=function(self,v)self.HorizontalAlignment=v end,
  SetVerticalAlignment=function(self,v)self.VerticalAlignment=v end,
  SetPadding=function(self,v)self.Padding=v end,SetSize=function()end,
  SetOffsets=function(self,v)self.LayoutData.Offsets=v end,SetZOrder=function()end}
end
local function node(name)
 local o={name=name,children={},Slot=slot(),Clipping=1,visibility=4,Brush={ResourceObject=name,ImageSize={X=512,Y=64}},ColorAndOpacity={}}
 function o:AddChild(child)
  self.children[#self.children+1]=child;child.parent=self;child.Slot=slot();return child.Slot
 end
 function o:RemoveFromParent()
  for i,v in ipairs(self.parent.children)do if v==self then table.remove(self.parent.children,i);break end end
  self.parent=nil
 end
 function o:GetAddress()return self.name end
 function o:GetParent()return self.parent end
 function o:GetAllChildren()return self.children end
 function o:GetFName()return {ToString=function()return self.name end}end
 function o:GetVisibility()return self.visibility end
 function o:SetVisibility(v)self.visibility=v end
 function o:SetClipping(v)self.Clipping=v end
 function o:SetWidthOverride(v)self.width=v end
 function o:SetHeightOverride(v)self.height=v end
 function o:SetBrushFromTexture(v)self.Brush.ResourceObject=v end
 function o:SetColorAndOpacity(v)self.colour=v;self.ColorAndOpacity=v end
 function o:SetRenderTransformPivot()end
 function o:SetRenderScale()end
 function o:GetDesiredSize()return {X=512,Y=64}end
 function o:ForceLayoutPrepass()end
 return o
end
local outside,parent,widget=node('outside'),node('art'),node('progress')
outside:AddChild(widget);widget:AddChild(parent)
for _,name in ipairs({'Back','Galss','Cauldron1','Cauldron2','Cauldron3'})do
 local image=node(name);parent:AddChild(image);widget[name]=image
end
local gs={CauldronTarget=3,FilledCauldronColors={{R=0,G=0,B=0},{R=1,G=0,B=0},{R=1,G=0,B=0}}}
local events,hooks,refreshes={},{},0
local policy={ceiling=3}
local session={gs=gs,mode='monroth.fap',role='host'}
local S={C={session=function()return session end},R={native={},valid=function(v)return v end,
 on=function(e,fn)events[e]=fn end,post=function(path,fn)hooks[path]=fn end},values=function(a)return a end,
 new=function(path)created=created+1;return node(path:match('%.(.+)$'))end,
 path=function()return ''end,refreshHUD=function()refreshes=refreshes+1 end}
S.hudPolicy=function()return policy end
dofile('candidate/runtime-source/FillAPotPlus/tests/lib/scope.lua')(S)
dofile('candidate/runtime-source/FillAPotPlus/progress.lua')(S)
S.progressBar(widget)
assert(widget.Cauldron1:GetParent()==nil,'native Tick must keep its own detached fills')
local root=parent.children[#parent.children]
local row=root.children[1]
assert(#row.children==12)
for i,box in ipairs(row.children)do
 local fill=box.children[1].children[2]
 assert(fill.visibility==4 and fill.colour.R==(i<=4 and 0 or 1),'black and repeated deliveries each occupy a distinct section')
end
local built=created;gs.FilledCauldronColors={};S.progressBar(widget);assert(created==built)
for _,box in ipairs(row.children)do assert(box.children[1].children[2].visibility==2)end
policy.ceiling=3;gs.CauldronTarget=2;S.progressBar(widget)
assert(created==built,'second-half target preserves the full bar width')
for i,box in ipairs(row.children)do
 local fill=box.children[1].children[2]
 assert(fill.visibility==(i>8 and 4 or 2))
 if i>8 then assert(fill.colour.R==.2961379885673523)end
end
-- A guest's GameState can still hold the native 3 when the host's target arrives (user 11-05).
policy.target=3;gs.CauldronTarget=1;S.progressBar(widget)
assert(row.children[1].children[1].children[2].visibility==2,'the host target wins over a stale native value')
policy.target=nil
-- A guest's game calls nothing when FilledCauldronColors replicates: the host's message
-- carries the filled colours, and the bar shows them even while the replicated list is stale.
gs.CauldronTarget=3;gs.FilledCauldronColors={};policy.filled={{R=1,G=0,B=0},{R=1,G=0,B=0}}
S.progressBar(widget)
for i,box in ipairs(row.children)do
 assert(box.children[1].children[2].visibility==(i<=8 and 4 or 2),'filled cauldrons come from the host message')
end
policy.filled=nil
gs.CauldronTarget=5;S.progressBar(widget);assert(created>built)
events.world_end();assert(widget.Cauldron1:GetParent()==parent and widget.Cauldron1.visibility==4)
assert(widget.Slot.LayoutData.Offsets.Right==512 and parent.Clipping==1)
print('PASS native-texture segmented progress for 1-10 targets, ordered repeated/black deliveries, event repaint and teardown')
