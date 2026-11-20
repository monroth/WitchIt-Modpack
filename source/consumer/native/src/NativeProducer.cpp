// Staged native producer for UE4SS e3ba1016 + UEPseudo 38e7171e.
// Optional carrier input copying starts after GT attach; vanilla writers stay native.
#include <Mod/CppUserModBase.hpp>
#include <DynamicOutput/Output.hpp>
#include <LuaMadeSimple/LuaMadeSimple.hpp>
#include <Unreal/FField.hpp>
#include <Unreal/CoreUObject/UObject/UnrealType.hpp>
#include <Unreal/CoreUObject/UObject/FStrProperty.hpp>
#include <Unreal/Property/FTextProperty.hpp>
#include <Unreal/Hooks/Hooks.hpp>
#include <Unreal/UObjectGlobals.hpp>
#include <Unreal/UnrealInitializer.hpp>
#include <Unreal/FURL.hpp>
#include <windows.h>
#include <atomic>
#include <mutex>
#include <stdexcept>
#include <string>
#include <vector>
#include "NativeUpdateFiles.hpp"
#include "NativeUpdater.hpp"
#include "NativeDebug.hpp"
#include "NativeBootControls.hpp"
#include <fstream>
#include <filesystem>
#include "NativeClipboard.hpp"
#include "NativeModPaks.hpp"
#include "ScopedGameplay.hpp"
#include "NativeBoundarySinks.hpp"
#include <cstring>
#include <map>
#include <optional>
#include "OwnedLocalWorld.hpp"
#include "ShipUE4SSEngine.hpp"
#include "ShipNativeBinding.hpp"
#include <Unreal/FWeakObjectPtr.hpp>
#include <Unreal/World.hpp>

namespace {
using namespace RC;
using namespace RC::Unreal;
using Lua=LuaMadeSimple::Lua;
constexpr auto save_path=L"/Game/Blueprints/Gamemodes/CreativeMode/B_CreativeGameMode.B_CreativeGameMode_C:SaveLayout";
constexpr auto writer_path=L"/Script/PropWitchHuntModule.ProjectVersionBlueprint:SavePropLayoutToFile";
constexpr auto compressed_writer_path=L"/Script/PropWitchHuntModule.ProjectVersionBlueprint:SavePropLayoutToFileCompressed";
constexpr auto load_path=L"/Game/Blueprints/Core/B_GameMode.B_GameMode_C:LoadPropLayout";
constexpr auto creative_load_path=L"/Game/Blueprints/Gamemodes/CreativeMode/B_CreativeGameMode.B_CreativeGameMode_C:LoadLayout";
constexpr auto base_apply_path=L"/Game/Blueprints/Core/B_GameMode.B_GameMode_C:LoadPropLayoutFromSaveGame";
constexpr auto creative_apply_path=L"/Game/Blueprints/Gamemodes/CreativeMode/B_CreativeGameMode.B_CreativeGameMode_C:LoadPropLayoutFromSaveGame";
constexpr auto reader_path=L"/Script/PropWitchHuntModule.ProjectVersionBlueprint:LoadPropLayoutFromFile";
constexpr auto compressed_reader_path=L"/Script/PropWitchHuntModule.ProjectVersionBlueprint:LoadPropLayoutFromFileCompressed";

std::string utf8(const StringType& value) {
    if(value.empty())return {};
    int count=WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,value.data(),int(value.size()),nullptr,0,nullptr,nullptr);
    if(!count)throw std::runtime_error("invalid native string");
    std::string out(count,'\0');
    if(WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,value.data(),int(value.size()),out.data(),count,nullptr,nullptr)!=count)
        throw std::runtime_error("native string conversion failed");
    return out;
}
FProperty* property(UFunction* node,const wchar_t* name) {
    auto p=node->FindProperty(FName(name,FNAME_Find));
    if(!p)throw std::runtime_error("required reflected property missing");
    return p;
}
bool boolean(FFrame& frame,const wchar_t* name) {
    auto p=CastField<FBoolProperty>(property(frame.Node(),name));
    if(!p || !frame.Locals())throw std::runtime_error("required reflected bool missing");
    if(p->HasAnyPropertyFlags(CPF_OutParm)) {
        auto address=FindOutParamValueAddress(frame,p);
        if(!address)throw std::runtime_error("required bool OUT address missing");
        return p->GetPropertyValue(address);
    }
    return p->GetPropertyValueInContainer(frame.Locals());
}
std::string string(FFrame& frame,const wchar_t* name) {
    auto p=CastField<FStrProperty>(property(frame.Node(),name));
    if(!p || !frame.Locals())throw std::runtime_error("required reflected string missing");
    const auto data=p->HasAnyPropertyFlags(CPF_OutParm) ? FindOutParamValueAddress(frame,p)
        : p->ContainerPtrToValuePtr<void>(frame.Locals());
    if(!data)throw std::runtime_error("required string address missing");
    const auto value=static_cast<FString*>(data);
    if(value->Len()<0 || value->Len()>4096 || (value->Len() && !**value))
        throw std::runtime_error("native string outside bounded contract");
    return utf8(StringType(**value,value->Len()));
}
std::string layout_string(FFrame& frame,const wchar_t* member) {
    auto layout=CastField<FStructProperty>(property(frame.Node(),L"Layout"));
    if(!layout || !frame.Locals() || !layout->GetStruct())throw std::runtime_error("exact Layout struct missing");
    auto field=CastField<FStrProperty>(layout->GetStruct()->FindProperty(FName(member,FNAME_Find)));
    if(!field)throw std::runtime_error("exact Layout string field missing");
    const auto container=layout->HasAnyPropertyFlags(CPF_OutParm) ? FindOutParamValueAddress(frame,layout)
        : layout->ContainerPtrToValuePtr<void>(frame.Locals());
    if(!container)throw std::runtime_error("exact Layout address missing");
    const auto value=field->ContainerPtrToValuePtr<FString>(container);
    if(value->Len()<0 || value->Len()>4096 || (value->Len() && !**value))throw std::runtime_error("Layout string outside bounded contract");
    return utf8(StringType(**value,value->Len()));
}
using FrameKey=std::uintptr_t;
FrameKey key(FFrame& frame){return reinterpret_cast<FrameKey>(&frame);}

class NativeProducer;
NativeProducer* instance{};
class NativeProducer final: public CppUserModBase {
    witchit::boot::Controls boot_;
    std::recursive_mutex mutex_; // stop/loader thread cannot race Lua dereference
    witchit::NativeBoundarySinks sinks_;
    bool attached_{},registered_{},save_load_started_{},startup_callback_registered_{},unreal_initialized_{};
    std::shared_ptr<witchit::ScopedGameplay> gameplay_;
    witchit::OwnedLocalWorld local_world_;
    using ShipBinding=ship_parts::NativeBinding<ship_parts::UE4SSEngine>;
    std::atomic<std::shared_ptr<ShipBinding>> ship_parts_;
    void retire_ship_parts() noexcept {if(auto held=ship_parts_.exchange({}))held->retire();}
    void ship_parts_before_world() noexcept {if(auto held=ship_parts_.load())held->before_world();}
    std::vector<Hook::GlobalCallbackId> global_ids_;
    struct NativeHook {UFunction* function;std::pair<int,int> ids;};
    std::vector<NativeHook> native_hooks_;
    FName save_name_,load_name_;
    // Saves and loads in progress, by their Blueprint frame; the game's reader result by file.
    struct Save {bool autosave;std::string name;};
    struct Load {std::string path,name,world;};
    std::unordered_map<FrameKey,Save> saves_;
    std::unordered_map<FrameKey,Load> loads_;
    std::unordered_map<std::string,bool> read_ok_;

    #include "NativeMapRecord.inl"

    // Creative SaveLayout: "entry" before its first instruction, "complete" with the file and the result.
    // B_GameMode LoadPropLayout: "return" once the layout is read and applied.
    void script_pre(UObject*,FFrame& frame) {
        std::lock_guard lock(mutex_);
        if(!attached_ || !frame.Node() || !frame.Locals() || frame.Code()!=frame.Node()->GetScript().GetData())return;
        const auto name=frame.Node()->GetFName();
        if(name==save_name_ && frame.Node()->GetPathName()==save_path) {
            Save held{boolean(frame,L"IsAutoSave"),string(frame,L"LayoutName")};
            saves_[key(frame)]=held;
            sinks_.save("entry",held.autosave,held.name,std::string{},false);
        } else if(name==load_name_ && frame.Node()->GetPathName()==load_path) {
            loads_[key(frame)]={layout_string(frame,L"FileName_6_F3CC8069497D007AD2E96A9AE00D2700"),
                layout_string(frame,L"LayoutName_8_C5C516E347406BABDAF0F59A6150BC5A"),layout_string(frame,L"MapName_10_67B8E5E54A16D786C60266AF5B396E36")};
        }
    }
    void script_post(FFrame& frame) {
        std::lock_guard lock(mutex_);
        if(auto save=saves_.find(key(frame));save!=saves_.end()) {
            const auto held=save->second;saves_.erase(save);
            if(attached_)sinks_.save("complete",held.autosave,held.name,string(frame,L"ItemFileName"),boolean(frame,L"IsSuccess"));
        } else if(auto load=loads_.find(key(frame));load!=loads_.end()) {
            const auto held=load->second;loads_.erase(load);
            const auto read=read_ok_.find(held.path);
            if(attached_)sinks_.load("return",held.path,read!=read_ok_.end() && read->second,held.name,held.world);
        }
    }
    static int attach(const Lua& lua) {
        if(!instance || !IsInGameThreadRaw()){lua.set_bool(false);return 1;}
        std::lock_guard lock(instance->mutex_);
        instance->initialize_save_load_on_game_thread();
        instance->attached_=instance->registered_ && instance->sinks_.attach(witchit::uikit::resolve_host_values());
        instance->saves_.clear();instance->loads_.clear();
        Output::send(STR("[WIR] native SaveLoad attach: callbacks={}\n"),instance->attached_);
        lua.set_bool(instance->attached_);return 1;
    }
    void detach() {attached_=false;saves_.clear();loads_.clear();sinks_.stop();}
public:
    NativeProducer(){instance=this;ModName=STR("WitchItNativeProducer");ModVersion=STR("0.1.0-stage");ModDescription=STR("Exact-frame save boundaries; runtime validation pending");ModAuthors=STR("monroth");
        if(const char* why=witchit::mod_paks::allow_unsigned())Output::send(STR("[WIR] Mod paks stay off: {}\n"),ensure_str(why));
        else Output::send(STR("[WIR] Mod paks: unsigned containers allowed\n"));
        if(const char* why=witchit::mod_paks::add_mod_paks(witchit::update_files::directory()/L"Mods"))Output::send(STR("[WIR] Mod paks in mod folders off: {}\n"),ensure_str(why));
        else for(const auto& folder:witchit::mod_paks::mod_folders)Output::send(STR("[WIR] Mod paks: also in {}\n"),folder);
        const auto path=witchit::update_files::directory()/L"Mods"/L"Core"/L"source-geometry-debug.json";
        try {
            std::error_code ec;const bool exists=std::filesystem::exists(path,ec);
            if(ec)throw std::runtime_error("Producer boot diagnostic availability unknown");
            if(exists){std::ifstream input(path,std::ios::binary);if(!input)throw std::runtime_error("Producer boot diagnostic read failed");
                std::string bytes(16385,'\0');input.read(bytes.data(),static_cast<std::streamsize>(bytes.size()));bytes.resize(static_cast<std::size_t>(input.gcount()));
                if(input.bad())throw std::runtime_error("Producer boot diagnostic read failed");boot_=witchit::boot::Controls::parse(bytes);}
            Output::send(STR("[WIR] Producer boot diagnostics: file={} disabled_count={}\n"),path.wstring(),boot_.disabled.size());
        }catch(const std::exception& e){boot_.disabled={"all"};Output::send(STR("[WIR] Producer boot diagnostics invalid; skip all native activations: {}\n"),ensure_str(e.what()));}
        for(const auto& name:witchit::boot::Controls::names)if(!boot_.enabled(name.c_str()))Output::send(STR("[WIR] Producer boot: skip {}\n"),ensure_str(name));
    }
    bool prepare_uninstall() override {
        if(!gameplay_)return true;
        gameplay_->stop();gameplay_->drain();
        if(!gameplay_->cleanup_complete())return false;
        gameplay_.reset();return true;
    }
    ~NativeProducer() override {
        witchit::updater::stop();
        retire_ship_parts();
        if(gameplay_){gameplay_->stop();gameplay_->drain();gameplay_.reset();}
        local_world_.stop();
        {std::lock_guard lock(mutex_);detach();}
        for(auto id:global_ids_)Hook::UnregisterCallback(id);
        for(const auto& h:native_hooks_)UObjectGlobals::UnregisterHook(h.function,h.ids);
        instance=nullptr;
    }
    void install_writer() {
        // The map record goes onto the first block row before the game writes the file.
        for(auto path:{writer_path,compressed_writer_path}) {
            auto fn=UObjectGlobals::StaticFindObject<UFunction*>(nullptr,nullptr,path);
            if(!fn){Output::send(STR("WIR SaveLoad: missing writer {}\n"),path);continue;}
            auto ids=UObjectGlobals::RegisterHook(fn,[this](auto& c,void*){
                try{std::lock_guard lock(mutex_);write_map_record(c.TheStack);}catch(const std::exception& error){
                    Output::send(STR("[WIR] map record not written: {}\n"),ensure_str(error.what()));
                }
            },[](auto&,void*){},nullptr);
            native_hooks_.push_back({fn,ids});
        }
    }
    void initialize_save_load_on_game_thread() {
        if(!IsInGameThreadRaw())return;
        std::lock_guard lock(mutex_);
        if(save_load_started_)return;
        save_load_started_=true;
        // Blueprint names may not yet be in the pool at Unreal initialization.
        save_name_=FName(STR("SaveLayout"),FNAME_Add);
        load_name_=FName(STR("LoadPropLayout"),FNAME_Add);
        // After the game reads a layout: its result, and its map record taken off the block rows.
        for(auto path:{reader_path,compressed_reader_path}) {
            auto fn=UObjectGlobals::StaticFindObject<UFunction*>(nullptr,nullptr,path);
            if(!fn){Output::send(STR("WIR SaveLoad: missing reader {}\n"),path);continue;}
            auto ids=UObjectGlobals::RegisterHook(fn,[](auto&,void*){},[this](auto& c,void*){
                std::lock_guard lock(mutex_);
                const auto file=string(c.TheStack,L"AbsoluteFileName");
                auto* returned=CastField<FBoolProperty>(property(c.TheStack.Node(),L"ReturnValue"));
                read_ok_[file]=returned && c.RESULT_DECL && returned->GetPropertyValue(c.RESULT_DECL);
                try{read_map_record(c.TheStack,file);}catch(const std::exception& error){
                    Output::send(STR("[WIR] map record not read: {}\n"),ensure_str(error.what()));
                }
            },nullptr);
            native_hooks_.push_back({fn,ids});
        }
        const Hook::FScriptNameFilter names{{static_cast<std::int32_t>(save_name_.GetComparisonIndex().ToUnstableInt()),
            static_cast<std::int32_t>(load_name_.GetComparisonIndex().ToUnstableInt())}};
        global_ids_.push_back(Hook::RegisterProcessLocalScriptFunctionPreCallback(
            [this](auto&,UObject* c,FFrame& f,void*){script_pre(c,f);},
            {false,true,STR("WitchItNativeProducer"),STR("SaveLayout/LoadPropLayout entry"),names}));
        global_ids_.push_back(Hook::RegisterProcessLocalScriptFunctionPostCallback(
            [this](auto&,UObject*,FFrame& f,void*){script_post(f);},
            {false,true,STR("WitchItNativeProducer"),STR("SaveLayout/LoadPropLayout return"),names}));
        registered_=true;
    }
    void on_unreal_init() override {
        std::lock_guard lock(mutex_);
        if(unreal_initialized_)return;
        unreal_initialized_=true;
        install_writer();
        // Unreal-init is the host/control thread. EngineTick PRE establishes GT
        // identity; bOnce removes this POST callback after provisioning the routes.
        // Attach may complete the same phase earlier, but only from verified GT.
        if(boot_.enabled("save_load_startup")){
        const auto startup_id=Hook::RegisterEngineTickPostCallback(
            [this](auto&,UEngine*,float,bool){initialize_save_load_on_game_thread();},
            {true,true,STR("WitchItNativeProducer"),STR("owned SaveLoad game-thread startup")});
        if(startup_id==Hook::ERROR_ID){
            Output::send(STR("WIR SaveLoad: UNAVAILABLE game-thread startup callback\n"));
        }else{
            startup_callback_registered_=true;global_ids_.push_back(startup_id);
        }
        }
        // The Host capabilities are fixed for this process. Do not register
        // global gameplay callbacks when the value bridge cannot start: even an
        // inactive body pays the Native/VM owner dispatch cost on every event.
        if (witchit::uikit::resolve_host_values(UE4SS_LUA_HOST_CAP_SCALARS_V1)) {
            if(boot_.enabled("travel"))global_ids_.push_back(Hook::RegisterLoadMapPreCallback(
                [this](auto&,UEngine*,FWorldContext&,FURL,UPendingNetGame*,FString&){if(gameplay_)gameplay_->before_world();local_world_.before_world();ship_parts_before_world();},
                {false,true,STR("WitchItNativeProducer"),STR("pure Native world retirement for all consumers")}));
        }

    }
    void on_lua_start(StringViewType mod,Lua& lua,Lua&,Lua&,Lua* hook) override {
        if(mod!=STR("WitchItRuntime"))return;
        retire_ship_parts();
        if(gameplay_){
            if(!gameplay_->stop())throw std::runtime_error("native previous generation cleanup incomplete");
            // on_lua_stop_drain already unregistered all external callbacks.
            if(!gameplay_->drained())throw std::runtime_error("native previous generation has not drained");
            gameplay_.reset();
        }
        if(!gameplay_)witchit::debug::configure("");
        local_world_.stop();
        std::lock_guard lock(mutex_);detach();
        if(boot_.enabled("local_world")&&witchit::uikit::resolve_host_values(UE4SS_LUA_HOST_CAP_SCALARS_V1))local_world_.start();
        try {
            if(auto* host=witchit::uikit::resolve_host_values(UE4SS_LUA_HOST_CAP_SCALARS_V1);boot_.enabled("ship_binding")&&host) {
                auto binding=std::make_shared<ShipBinding>(host,local_world_.source());
                binding->activate();ship_parts_.store(std::move(binding));
            }
        }catch(const std::exception&){retire_ship_parts();}
        lua.register_function("WitchItNativeShipPartsBridge",[](const Lua& caller){
            auto held=instance?instance->ship_parts_.load():nullptr;
            if(!held){caller.set_nil();return 1;}
            try{return held->accessor();}catch(const std::exception&){caller.set_nil();return 1;}
        });
        lua.register_function("WitchItNativeProducerAttach",attach);
        lua.register_function("WitchItNativeMapRecord",[](const Lua& caller){
            try{return map_record_lua(caller);}catch(const std::exception& e){caller.throw_error(e.what());return 0;}
        });
        lua.register_function("WitchItNativeDebug",[](const Lua& caller){
            try {
                witchit::uikit::HostStack s(witchit::uikit::resolve_host_values(UE4SS_LUA_HOST_CAP_SCALARS_V1),UE4SS_LUA_HOST_CAP_SCALARS_V1);
                const auto result=witchit::debug::configure_stack(s,instance && bool(instance->gameplay_));
                if(result==1)Output::send(STR("[WIR] Core native diagnostics: disabled={}\n"),ensure_str(s.get_string(1).value_or("")));
                return result;
            }catch(const std::exception& e){caller.set_bool(false);caller.set_string(e.what());return 2;}
        });
        lua.register_function("WitchItNativePrimitives",[](const Lua& caller){
            if(!instance||!instance->boot_.enabled("primitives")){Output::send(STR("[WIR] Producer boot: skip Native primitives accessor\n"));caller.set_nil();return 1;}
            const auto* host=witchit::uikit::resolve_host_values();
            try {
                if(!instance->gameplay_)instance->gameplay_=std::make_shared<witchit::ScopedGameplay>(host,instance->local_world_);
                return instance->gameplay_->push()?1:0;
            }catch(const std::exception& e){caller.throw_error(e.what());return 0;}
        });
        lua.register_function("WitchItNativeClipboard",[](const Lua& caller){
            if(!instance||!instance->boot_.enabled("clipboard")){Output::send(STR("[WIR] Producer boot: skip clipboard accessor\n"));caller.set_nil();return 1;}
            try {
                witchit::uikit::HostStack s(witchit::uikit::resolve_host_values(UE4SS_LUA_HOST_CAP_SCALARS_V1),UE4SS_LUA_HOST_CAP_SCALARS_V1);
                auto op=s.get_string(1);if(!op)throw std::runtime_error("Native.clipboard: operation required");
                auto result=witchit::clipboard::execute(*op,s.get_string(2));
                if(result)s.string(*result);else s.nil();return 1;
            }catch(const std::exception& e){caller.throw_error(e.what());return 0;}
        });
        lua.register_function("WitchItNativeUpdater",[](const Lua& caller){
            try {
                witchit::uikit::HostStack s(witchit::uikit::resolve_host_values(UE4SS_LUA_HOST_CAP_SCALARS_V1),UE4SS_LUA_HOST_CAP_SCALARS_V1);
                auto operation=s.get_string(1);if(!operation)throw std::runtime_error("updater operation required");
                auto value=witchit::updater::operation(*operation);
                if(value)s.string(*value);else s.nil();return 1;
            }catch(const std::exception& e){caller.throw_error(e.what());return 0;}
        });
        lua.register_function("WitchItNativeUpdateFile",[](const Lua& caller){
            if(!instance||!instance->boot_.enabled("update_file")){Output::send(STR("[WIR] Producer boot: skip updater file accessor\n"));caller.set_nil();return 1;}
            try {
                witchit::uikit::HostStack s(witchit::uikit::resolve_host_values(UE4SS_LUA_HOST_CAP_SCALARS_V1),UE4SS_LUA_HOST_CAP_SCALARS_V1);
                auto operation=s.get_string(1);
                if(!operation)throw std::runtime_error("Native.update_file: operation required");
                auto result=witchit::update_files::execute(*operation,s.get_string(2));
                if(result)s.string(*result);else s.nil();return 1;
            }catch(const std::exception& e){caller.throw_error(e.what());return 0;}
        });
        // Folders for the runtime without a shell (a cmd process opens a window on Windows):
        // 'list' -> the names in a folder, one per line ('' when it is missing); 'mkdir' -> true when it exists.
        lua.register_function("WitchItNativeFiles",[](const Lua& caller){
            try {
                witchit::uikit::HostStack s(witchit::uikit::resolve_host_values(UE4SS_LUA_HOST_CAP_SCALARS_V1),UE4SS_LUA_HOST_CAP_SCALARS_V1);
                auto operation=s.get_string(1,16),path=s.get_string(2,4096);
                if(!operation||!path)throw std::runtime_error("Native.files: operation and path required");
                namespace fs=std::filesystem;
                const fs::path folder(std::u8string(path->begin(),path->end()));
                std::error_code ec;
                if(*operation=="list"){
                    std::string out;
                    for(fs::directory_iterator it(folder,ec),end;!ec&&it!=end;it.increment(ec)){
                        auto name=it->path().filename().u8string();
                        out.append(name.begin(),name.end());out.push_back('\n');
                    }
                    s.string(out);return 1;
                }
                if(*operation=="mkdir"){fs::create_directories(folder,ec);s.boolean(fs::is_directory(folder,ec));return 1;}
                throw std::runtime_error("Native.files: unknown operation");
            }catch(const std::exception& e){caller.throw_error(e.what());return 0;}
        });
        // Metadata only: execution and marshaling remain in the existing SDK.
        lua.register_function("WitchItNativeFunctionSchema",[](const Lua& caller){
            if(!instance||!instance->boot_.enabled("schemas")){Output::send(STR("[WIR] Producer boot: skip function schema accessor\n"));caller.set_nil();return 1;}
            try {
                witchit::uikit::HostStack s(witchit::uikit::resolve_host_values());
                auto* object=static_cast<UObject*>(s.object(1));
                auto name=s.get_string(2);
                if(!object || !name)throw std::runtime_error("Native schema requires object and function name");
                std::wstring wide(name->begin(),name->end());
                auto* fn=object->GetFunctionByNameInChain(FName(wide.c_str(),FNAME_Find));
                if(!fn){s.nil();return 1;} // SDK methods are not UFunctions.
                s.table();const int result=s.top();int count=0;
                for(auto* p:TFieldRange<FProperty>(fn,EFieldIterationFlags::IncludeDeprecated)) {
                    if(!p->HasAnyPropertyFlags(CPF_Parm))continue;
                    auto key=utf8(p->GetName());
                    if(p->HasAnyPropertyFlags(CPF_ReturnParm)) {s.string(key);s.set_field(result,"return_name");continue;}
                    auto index=std::to_string(++count);
                    s.string(key);s.set_field(result,index);
                    s.boolean(p->HasAnyPropertyFlags(CPF_OutParm) && !p->HasAnyPropertyFlags(CPF_ConstParm));
                    s.set_field(result,"out:"+index);
                }
                s.integer(count);s.set_field(result,"count");return 1;
            }catch(const std::exception& e){caller.throw_error(e.what());return 0;}
        });

        Output::send(STR("[WIR] NativeProducer ready: runtime=WitchItRuntime host_values={} writer_safety={} startup={} viewport={} travel={} local_world={} ship_binding={} primitives={} file_bridge={} schemas={} clipboard={} update_file={}\n"),
            witchit::uikit::resolve_host_values(UE4SS_LUA_HOST_CAP_SCALARS_V1)!=nullptr,boot_.enabled("writer_safety"),boot_.enabled("save_load_startup"),boot_.enabled("viewport"),boot_.enabled("travel"),boot_.enabled("local_world"),boot_.enabled("ship_binding"),boot_.enabled("primitives"),boot_.enabled("file_bridge"),boot_.enabled("schemas"),boot_.enabled("clipboard"),boot_.enabled("update_file"));
    }
    void on_lua_stop(StringViewType mod,Lua& lua,Lua&,Lua&,Lua*) override {
        if(mod!=STR("WitchItRuntime"))return;
        retire_ship_parts();
        if(gameplay_)gameplay_->stop();
        local_world_.stop();
        std::lock_guard lock(mutex_);detach();
    }
    void on_lua_stop_drain(StringViewType mod) override {
        if(mod!=STR("WitchItRuntime"))return;
        if(gameplay_){
            gameplay_->drain();
            if(gameplay_->cleanup_complete())gameplay_.reset();
            else Output::send(STR("[WIR] Native teardown retains failed actor rollback until cleanup or world retirement\n"));
        }
    }
};
}
extern "C" __declspec(dllexport) RC::CppUserModBase* start_mod(){return new NativeProducer;}
extern "C" __declspec(dllexport) void uninstall_mod(RC::CppUserModBase* mod){delete mod;}
