// Where a widget was last drawn, in viewport units (what a canvas slot position takes).
// FGeometry has no reflected members, so it cannot cross into Lua: it stays in native
// parameter storage between UWidget::GetCachedGeometry and the SlateBlueprintLibrary calls.
public:
int widget_rect(Stack& s,UObject* widget) {
 using namespace RC::Unreal;
 require(enabled_ && IsInGameThreadRaw());pin(widget);
 auto* cached=function(widget,L"GetCachedGeometry",L"/Script/UMG.Widget:GetCachedGeometry");
 native::Parameters g(cached);
 auto* geometry=CastField<FStructProperty>(field(cached,L"ReturnValue",cached->GetParmsSize()));
 require(geometry && geometry->GetStruct()->GetPathName()==L"/Script/SlateCore.Geometry","widget geometry schema differs");
 widget->ProcessEvent(cached,g.data());
 auto* library=UObjectGlobals::StaticFindObject<UObject*>(nullptr,nullptr,L"/Script/UMG.Default__SlateBlueprintLibrary");require(library);
 auto vector2=[](UFunction* fn,void* data,const wchar_t* name)->FStructProperty* {
  auto* p=CastField<FStructProperty>(field(fn,name,fn->GetParmsSize()));
  require(p && p->GetStruct()->GetPathName()==L"/Script/CoreUObject.Vector2D","Vector2D schema differs");return p;
 };
 auto read2=[](FStructProperty* p,void* value)->std::array<double,2> {
  auto* t=p->GetStruct().Get();const auto n=t->GetStructureSize();
  return {audit_number(t,value,n,L"X"),audit_number(t,value,n,L"Y")};
 };
 auto* size_fn=function(library,L"GetLocalSize",L"/Script/UMG.SlateBlueprintLibrary:GetLocalSize");
 native::Parameters z(size_fn);
 auto* size_in=CastField<FStructProperty>(field(size_fn,L"Geometry",size_fn->GetParmsSize()));require(size_in && size_in->GetStruct()==geometry->GetStruct());
 size_in->CopyCompleteValue(z.value(size_in),g.value(geometry));
 library->ProcessEvent(size_fn,z.data());
 auto* size_out=vector2(size_fn,z.data(),L"ReturnValue");const auto size=read2(size_out,z.value(size_out));
 auto* view=function(library,L"LocalToViewport",L"/Script/UMG.SlateBlueprintLibrary:LocalToViewport");
 const auto n=view->GetParmsSize();
 for(const auto& corner:{std::array<double,2>{0,0},size}) {
  native::Parameters v(view);
  auto* ctx=CastField<FObjectProperty>(field(view,L"WorldContextObject",n));require(ctx && ctx->GetSize()==sizeof(UObject*));
  *static_cast<UObject**>(v.value(ctx))=widget;
  auto* in=CastField<FStructProperty>(field(view,L"Geometry",n));require(in && in->GetStruct()==geometry->GetStruct());
  in->CopyCompleteValue(v.value(in),g.value(geometry));
  auto* local=vector2(view,v.data(),L"LocalCoordinate");auto* t=local->GetStruct().Get();
  scalar_value(t,v.value(local),t->GetStructureSize(),L"X",corner[0]);scalar_value(t,v.value(local),t->GetStructureSize(),L"Y",corner[1]);
  library->ProcessEvent(view,v.data());
  auto* out=vector2(view,v.data(),L"ViewportPosition");
  for(double value:read2(out,v.value(out))){require(std::isfinite(value));s.number(value);}
 }
 return 4;
}
