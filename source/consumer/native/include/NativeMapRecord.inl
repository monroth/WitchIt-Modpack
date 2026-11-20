// The map record (MAPDATA.md) on its way through the game's layout file functions.
// Core hands the record to write next; the writer puts it on the first block row.
// The reader takes it off every block row, so no live block carries it, and keeps
// it for Core by file name. Block bytes: game bytes | records | u32 tail size | "WIP1".
std::string map_record_;
std::unordered_map<std::string,std::string> read_map_records_;

static std::optional<std::size_t> map_tail_start(const std::uint8_t* b,std::size_t n) {
    if(n<8 || std::memcmp(b+n-4,"WIP1",4)!=0)return {};
    std::uint32_t size{};std::memcpy(&size,b+n-8,4);
    if(size<8 || size>n)throw std::runtime_error("map data tail size out of range");
    return n-size;
}
// Records of one tail: id -> (version, data), in id order.
static std::map<std::string,std::pair<std::uint8_t,std::string>> map_records(const std::uint8_t* b,std::size_t at,std::size_t end) {
    std::map<std::string,std::pair<std::uint8_t,std::string>> out;
    while(at<end) {
        const std::size_t n=b[at];
        if(at+1+n+5>end)throw std::runtime_error("truncated map data record");
        std::string id(reinterpret_cast<const char*>(b+at+1),n);at+=1+n;
        const auto version=b[at];std::uint32_t length{};std::memcpy(&length,b+at+1,4);at+=5;
        if(at+length>end)throw std::runtime_error("truncated map data record");
        out[id]={version,std::string(reinterpret_cast<const char*>(b+at),length)};at+=length;
    }
    return out;
}
static std::string map_tail(const std::map<std::string,std::pair<std::uint8_t,std::string>>& records) {
    if(records.empty())return {};
    std::string body;
    for(const auto& [id,value]:records) {
        body+=char(id.size());body+=id;body+=char(value.first);
        const std::uint32_t length=std::uint32_t(value.second.size());body.append(reinterpret_cast<const char*>(&length),4);
        body+=value.second;
    }
    const std::uint32_t size=std::uint32_t(body.size()+8);body.append(reinterpret_cast<const char*>(&size),4);body+="WIP1";
    return body;
}
// Each block row of a layout file function's statics list, as its MaterialIndices array.
template<class F> void map_rows(FFrame& frame,const wchar_t* name,F&& visit) {
    auto* list=CastField<FArrayProperty>(property(frame.Node(),name));
    auto* row=list?CastField<FStructProperty>(list->GetInner()):nullptr;
    auto* bytes=row && row->GetStruct()?CastField<FArrayProperty>(row->GetStruct()->FindProperty(FName(L"MaterialIndices",FNAME_Find))):nullptr;
    if(!bytes || !CastField<FByteProperty>(bytes->GetInner()))throw std::runtime_error("layout statics schema differs");
    auto* array=static_cast<FScriptArray*>(list->HasAnyPropertyFlags(CPF_OutParm)?FindOutParamValueAddress(frame,list):list->ContainerPtrToValuePtr<void>(frame.Locals()));
    if(!array)throw std::runtime_error("layout statics address missing");
    FScriptArrayHelper rows(list,array);
    for(int i=0;i<rows.Num();++i)visit(i,FScriptArrayHelper(bytes,bytes->ContainerPtrToValuePtr<void>(rows.GetRawPtr(i))));
}
static void set_bytes(FScriptArrayHelper& to,const std::string& game,const std::string& tail) {
    to.Resize(int(game.size()+tail.size()));
    if(!game.empty())std::memcpy(to.GetRawPtr(0),game.data(),game.size());
    if(!tail.empty())std::memcpy(to.GetRawPtr(0)+game.size(),tail.data(),tail.size());
}
// Writer PRE: the record Core handed over goes onto the first block row, and only there.
void write_map_record(FFrame& frame) {
    auto record=std::exchange(map_record_,std::string{});
    map_rows(frame,L"PlaceableStaticsToSave",[&](int i,FScriptArrayHelper bytes) {
        const auto* b=bytes.Num()?bytes.GetRawPtr(0):nullptr;const std::size_t n=bytes.Num();
        const auto start=map_tail_start(b,n);
        auto records=start?map_records(b,*start,n-8):decltype(map_records(b,0,0)){};
        const bool had=records.erase("map")>0;
        if(i==0 && !record.empty())records["map"]={1,record};
        else if(!had)return;
        std::string game(reinterpret_cast<const char*>(b),start.value_or(n));
        set_bytes(bytes,game,map_tail(records));
    });
}
// Reader POST: the record comes off every row and waits for Core under the file's name.
void read_map_record(FFrame& frame,const std::string& file) {
    read_map_records_.erase(file);
    map_rows(frame,L"PlaceableStaticsToLoad",[&](int,FScriptArrayHelper bytes) {
        const auto* b=bytes.Num()?bytes.GetRawPtr(0):nullptr;const std::size_t n=bytes.Num();
        const auto start=map_tail_start(b,n);if(!start)return;
        auto records=map_records(b,*start,n-8);
        auto found=records.find("map");if(found==records.end())return;
        read_map_records_[file]=found->second.second;records.erase(found);
        std::string game(reinterpret_cast<const char*>(b),*start);
        set_bytes(bytes,game,map_tail(records));
    });
}
static int map_record_lua(const Lua&) {
    witchit::uikit::HostStack s(witchit::uikit::resolve_host_values(UE4SS_LUA_HOST_CAP_SCALARS_V1),UE4SS_LUA_HOST_CAP_SCALARS_V1);
    if(!instance || !IsInGameThreadRaw())throw std::runtime_error("map record: game thread only");
    std::lock_guard lock(instance->mutex_);
    auto op=s.get_string(1);if(!op)throw std::runtime_error("map record: operation required");
    if(*op=="set"){auto bytes=s.get_string(2,16777216);instance->map_record_=bytes.value_or("");s.boolean(true);return 1;}
    if(*op=="take"){
        auto file=s.get_string(2);if(!file)throw std::runtime_error("map record: file required");
        auto found=instance->read_map_records_.find(*file);
        if(found==instance->read_map_records_.end()){s.nil();return 1;}
        s.string(found->second);instance->read_map_records_.erase(found);return 1;
    }
    throw std::runtime_error("map record: unknown operation");
}
