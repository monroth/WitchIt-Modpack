#pragma once
// Mod paks: once the game has a pak signing key it reads only signed paks, and a mod's pak cannot be
// signed (no private key). Three places of the engine's code are changed before it mounts paks
// (UE4SS holds the main thread until the C++ mods are loaded):
// - the pak platform file's "paks are signed" flag (a .pak then needs no .sig);
// - the pak precacher's signature checks of .pak blocks (same flag of its own);
// - the IoStore reader's refusal of an unsigned container ("Missing signature"): sent the way the game
//   reads one without a key. The game's signed IoStore containers (all its content) are still verified.
// Each change needs its exact code shape; without all three the game is left as it is (mod paks off).
// Mod paks live in their mods' folders: the engine's list of pak folders (GetPakFolders: Content/Paks,
// Saved/Paks, Engine/Content/Paks) also gets the Paks/ folder of every mod that is on (its manifest.lua
// does not say enabled=false): a mod switched off brings none of its content.
#include <windows.h>
#include <cstdint>
#include <cstring>
#include <vector>
#include <cwchar>
#include <string>
#include <filesystem>
#include <fstream>
#include <iterator>
namespace witchit::mod_paks {
struct Code {std::uint8_t* at{};int count{};};
// -1 in a pattern: any byte.
inline Code find(const std::vector<int>& pattern) noexcept {
    auto* base=reinterpret_cast<std::uint8_t*>(GetModuleHandleW(nullptr));
    auto* nt=reinterpret_cast<IMAGE_NT_HEADERS*>(base+reinterpret_cast<IMAGE_DOS_HEADER*>(base)->e_lfanew);
    auto* section=IMAGE_FIRST_SECTION(nt);Code code;
    for(unsigned s=0;s<nt->FileHeader.NumberOfSections;++s,++section){
        if(!(section->Characteristics&IMAGE_SCN_MEM_EXECUTE))continue;
        std::uint8_t* p=base+section->VirtualAddress;const std::size_t n=section->Misc.VirtualSize;
        for(std::size_t i=0;i+pattern.size()<=n;++i){
            std::size_t k=0;
            while(k<pattern.size()&&(pattern[k]<0||p[i+k]==pattern[k]))++k;
            if(k==pattern.size()){code.at=p+i;++code.count;}
        }
    }
    return code;
}
inline bool write(std::uint8_t* at,const std::uint8_t* bytes,std::size_t n) noexcept {
    DWORD old;if(!VirtualProtect(at,n,PAGE_EXECUTE_READWRITE,&old))return false;
    std::memcpy(at,bytes,n);VirtualProtect(at,n,old,&old);FlushInstructionCache(GetCurrentProcess(),at,n);return true;
}
// Wide text in the image's data, for its exact characters with its terminator.
inline std::uint8_t* text(const wchar_t* value) noexcept {
    auto* base=reinterpret_cast<std::uint8_t*>(GetModuleHandleW(nullptr));
    auto* nt=reinterpret_cast<IMAGE_NT_HEADERS*>(base+reinterpret_cast<IMAGE_DOS_HEADER*>(base)->e_lfanew);
    auto* section=IMAGE_FIRST_SECTION(nt);const std::size_t n=(wcslen(value)+1)*sizeof(wchar_t);
    for(unsigned s=0;s<nt->FileHeader.NumberOfSections;++s,++section){
        if(section->Characteristics&IMAGE_SCN_MEM_EXECUTE)continue;
        std::uint8_t* p=base+section->VirtualAddress;const std::size_t size=section->Misc.VirtualSize;
        for(std::size_t i=0;i+n<=size;i+=2)if(std::memcmp(p+i,value,n)==0)return p+i;
    }
    return nullptr;
}
inline std::uint8_t* relative(std::uint8_t* at,int offset,int length) noexcept {std::int32_t d;std::memcpy(&d,at+offset,4);return at+length+d;}

struct FString {wchar_t* data;std::int32_t num,max;};
struct Folders {FString* data;std::int32_t num,max;};
using GetPakFolders=void(*)(const wchar_t*,Folders*);
using Printf=void(*)(FString*,const wchar_t*,...);
using Grow=void(*)(std::uint32_t,Folders*,std::int32_t*);
inline GetPakFolders original_folders;
inline Printf printf_;
inline Grow grow;
inline std::vector<std::wstring> mod_folders;
inline void folders(const wchar_t* command_line,Folders* out) {
    original_folders(command_line,out);
    for(const auto& path:mod_folders){
        FString folder{};printf_(&folder,L"%s",path.c_str());
        const std::int32_t index=out->num;
        if(out->num==out->max)grow(0x810,out,&out->max);   // as the engine's own adds: 16-byte elements, 8-aligned
        out->num=index+1;out->data[index]=folder;
    }
}
// The Paks/ folders of the mods that are on, under the mods' folder.
inline std::vector<std::wstring> enabled_paks(const std::filesystem::path& mods) {
    std::vector<std::wstring> out;std::error_code ec;
    for(const auto& entry:std::filesystem::directory_iterator(mods,ec)){
        const auto paks=entry.path()/L"Paks";
        if(!std::filesystem::is_directory(paks,ec))continue;
        std::ifstream manifest(entry.path()/L"manifest.lua",std::ios::binary);
        const std::string text{std::istreambuf_iterator<char>(manifest),std::istreambuf_iterator<char>()};
        if(text.find("enabled=false")!=std::string::npos||text.find("enabled = false")!=std::string::npos)continue;
        out.push_back(paks.generic_wstring()+L"/");
    }
    return out;
}
// The function that formats "%sPaks/": its first 15 bytes (three stores) move to a trampoline.
inline const char* add_mod_paks(const std::filesystem::path& mods) noexcept {
    std::uint8_t* format=text(L"%sPaks/");
    if(!format)return "pak folder text not found";
    const Code lea=[&]{Code c;auto* base=reinterpret_cast<std::uint8_t*>(GetModuleHandleW(nullptr));
        auto* nt=reinterpret_cast<IMAGE_NT_HEADERS*>(base+reinterpret_cast<IMAGE_DOS_HEADER*>(base)->e_lfanew);auto* section=IMAGE_FIRST_SECTION(nt);
        for(unsigned s=0;s<nt->FileHeader.NumberOfSections;++s,++section){
            if(!(section->Characteristics&IMAGE_SCN_MEM_EXECUTE))continue;
            std::uint8_t* p=base+section->VirtualAddress;const std::size_t n=section->Misc.VirtualSize;
            for(std::size_t i=0;i+7<=n;++i)if(p[i]==0x48&&p[i+1]==0x8d&&p[i+2]==0x15&&relative(p+i,3,7)==format){if(!c.at)c.at=p+i;++c.count;}
        }return c;}();
    if(lea.count!=3)return "pak folders code not found";
    std::uint8_t* start=lea.at;while(start[-1]!=0xcc)--start;
    static const std::uint8_t prologue[15]={0x48,0x89,0x5c,0x24,0x08,0x48,0x89,0x74,0x24,0x10,0x48,0x89,0x7c,0x24,0x18};
    if(std::memcmp(start,prologue,15)!=0)return "pak folders code shape differs";
    // lea rdx,[fmt] / lea rcx,[rbp-0x20] / call Printf
    if(lea.at[7]!=0x48||lea.at[8]!=0x8d||lea.at[9]!=0x4d||lea.at[11]!=0xe8)return "pak folder format call differs";
    printf_=reinterpret_cast<Printf>(relative(lea.at+11,1,5));
    std::uint8_t* g=lea.at;while(g<lea.at+64&&!(g[0]==0xb9&&g[1]==0x10&&g[2]==0x08&&g[3]==0&&g[4]==0))++g;
    if(g>=lea.at+64||g[12]!=0xe8)return "pak folder array growth differs";   // mov ecx,0x810 / lea r8,[rbx+0xc] / mov rdx,rbx / call
    grow=reinterpret_cast<Grow>(relative(g+12,1,5));
    mod_folders=enabled_paks(mods);
    auto* trampoline=static_cast<std::uint8_t*>(VirtualAlloc(nullptr,64,MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE));
    if(!trampoline)return "no memory for the pak folders trampoline";
    std::memcpy(trampoline,start,15);
    const std::uint8_t back[6]={0xff,0x25,0,0,0,0};std::memcpy(trampoline+15,back,6);
    std::uint8_t* resume=start+15;std::memcpy(trampoline+21,&resume,8);
    original_folders=reinterpret_cast<GetPakFolders>(trampoline);
    std::uint8_t jump[15]={0xff,0x25,0,0,0,0,0,0,0,0,0,0,0,0,0x90};
    void* hook=reinterpret_cast<void*>(&folders);std::memcpy(jump+6,&hook,8);
    if(!write(start,jump,sizeof jump))return "memory not writable";
    return nullptr;
}
inline const char* allow_unsigned() noexcept {
    // bSigned = keys valid: "mov al,1" of the valid branch
    const Code pak=find({0x74,0x16,0x48,0x8b,0x08,0x48,0x85,0xc9,0x74,0x0e,0x48,0x8b,0x01,0xff,0x50,0x30,0x84,0xc0,0x74,0x04,0xb0,0x01,0xeb,0x02,0x32,0xc0,0x88,0x47,0x30});
    // precacher signature checks = keys valid: "mov bl,1"
    const Code precacher=find({0x83,0x78,0x08,0x00,0x74,0x16,0x48,0x8b,0x08,0x48,0x85,0xc9,0x74,0x0e,0x48,0x8b,0x01,0xff,0x50,0x30,0x84,0xc0,0x74,0x04,0xb3,0x01,0xeb,0x02,0x32,0xdb,0x48,0x83,0x3d});
    // test bl,4 / je <no check> / test bl,4 / jne <verify> / lea rax,["Missing signature"]
    const Code store=find({0xf6,0xc3,0x04,0x0f,0x84,-1,-1,-1,-1,0xf6,0xc3,0x04,0x75,-1,0x48,0x8d,0x05});
    if(pak.count!=1)return "pak flag code not found once";
    if(precacher.count!=1)return "precacher flag code not found once";
    if(store.count!=1)return "IoStore refusal code not found once";
    const std::uint8_t zero=0;
    if(!write(pak.at+21,&zero,1)||!write(precacher.at+25,&zero,1))return "memory not writable";
    std::int32_t skip;std::memcpy(&skip,store.at+5,4);
    std::uint8_t* target=store.at+9+skip;std::uint8_t* at=store.at+14;
    const std::int32_t rel=static_cast<std::int32_t>(target-(at+5));
    std::uint8_t jump[7]={0xe9,0,0,0,0,0x90,0x90};std::memcpy(jump+1,&rel,4);
    if(!write(at,jump,sizeof jump))return "memory not writable";
    return nullptr;
}
}
