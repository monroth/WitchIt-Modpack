#pragma once
#include "NativeUpdateFiles.hpp"
#include <fstream>
#include <functional>
#include <mutex>
#include "NativeUpdaterWait.hpp"
namespace witchit::updater {
inline HANDLE launch_process(const wchar_t* operation,const std::wstring& argument=L"") {
 const auto file=update_files::directory()/L"WitchItUpdater.exe";
 auto command=L"\""+file.wstring()+L"\" "+operation+L" "+argument;
 STARTUPINFOW si{sizeof(si)};PROCESS_INFORMATION pi{};
 if(!CreateProcessW(file.c_str(),command.data(),nullptr,nullptr,FALSE,CREATE_NO_WINDOW,nullptr,file.parent_path().c_str(),&si,&pi))throw update_files::error("start updater");
 CloseHandle(pi.hThread);return pi.hProcess;
}
inline void launch(const wchar_t* operation,const std::wstring& argument=L"") {CloseHandle(launch_process(operation,argument));}
inline CheckCompletion check_completion;
inline void when_complete(std::function<void()> fn){check_completion.subscribe(std::move(fn));}
inline void stop()noexcept{check_completion.stop();}
inline std::optional<std::string> operation(const std::string& op) {
 const auto root=update_files::directory()/L".witchit-updater";
 std::filesystem::create_directories(root);
 if(op=="check"){
  return check_completion.start()?"started":"already checked";
 }
 if(op=="status"){
  const auto p=root/L"notice.json";
  if(!std::filesystem::exists(p)){
   const auto done=root/L"check.done";if(!std::filesystem::exists(done))return std::nullopt;
   if(std::filesystem::file_size(done)>64)throw std::runtime_error("updater completion too large");
   std::ifstream f(done,std::ios::binary);std::string value;std::getline(f,value);
   return value=="network-unavailable"?"{\"kind\":\"unavailable\"}":"{}";
  }
  if(std::filesystem::file_size(p)>1024)throw std::runtime_error("updater notice too large");std::ifstream f(p,std::ios::binary);std::string b((std::istreambuf_iterator<char>(f)),{});if(f.bad()||b.size()>1024)throw std::runtime_error("updater notice invalid");return b;
 }
 if(op=="progress"){
  // While an apply request downloads: {"done":n,"total":n,"mod":id} (none once it has finished).
  const auto p=root/L"progress.json";if(!std::filesystem::exists(p)||std::filesystem::file_size(p)>256)return std::nullopt;
  std::ifstream f(p,std::ios::binary);std::string b((std::istreambuf_iterator<char>(f)),{});return b;
 }
 if(op=="ack") {DeleteFileW((root/L"notice.json").c_str());return "ok";}
 if(op=="relaunch"){
  // The updater waits for this process to exit, then starts the game again with its command line.
  const std::wstring line=GetCommandLineW();
  std::ofstream(root/L"relaunch.line",std::ios::binary|std::ios::trunc).write(reinterpret_cast<const char*>(line.data()),std::streamsize(line.size()*sizeof(wchar_t)));
  launch(L"--relaunch",std::to_wstring(GetCurrentProcessId()));
  return "started";
 }
 if(op=="relaunch-after-update"){
  // A handed-off update is being applied once this process exits; that updater starts the game again.
  const std::wstring line=GetCommandLineW();
  std::ofstream(root/L"relaunch.line",std::ios::binary|std::ios::trunc).write(reinterpret_cast<const char*>(line.data()),std::streamsize(line.size()*sizeof(wchar_t)));
  return "requested";
 }
 throw std::runtime_error("unknown updater operation");
}

}
