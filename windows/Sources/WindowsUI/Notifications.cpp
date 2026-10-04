#define UNICODE
#define _UNICODE
#include "WindowsUI.h"
#include "Notifications/DesktopNotificationManagerCompat.h"
#include <NotificationActivationCallback.h>
#include <shobjidl.h>
#include <shlobj.h>
#include <propkey.h>
#include <propvarutil.h>
#include <wrl/wrappers/corewrappers.h>
#include <map>
#include <mutex>
#include <string>

using namespace ABI::Windows::Data::Xml::Dom;
using namespace ABI::Windows::UI::Notifications;
using namespace Microsoft::WRL;
using namespace Microsoft::WRL::Wrappers;

namespace {
constexpr wchar_t appID[]=L"Chotki.Windows";
constexpr wchar_t reviewID[]=L"Chotki.Windows.NotificationReview";
std::mutex actionsLock;
std::map<int,std::wstring> actions;
std::map<std::wstring,std::wstring> deliveredTags;
ComPtr<IToastNotifier> notifier;
std::unique_ptr<DesktopNotificationHistoryCompat> history;
bool silentReview=false, temporaryIdentity=false, initialized=false, roInitialized=false;
int nextAction=0, nextTag=0;
std::wstring shortcutPath;

std::wstring wide(const char *text) {
    if(!text) return {};
    int length=MultiByteToWideChar(CP_UTF8,0,text,-1,nullptr,0);
    if(length<=0) return {};
    std::wstring result(length,L'\0'); MultiByteToWideChar(CP_UTF8,0,text,-1,result.data(),length); result.resize(length-1); return result;
}
std::string utf8(const std::wstring &text) {
    int length=WideCharToMultiByte(CP_UTF8,0,text.data(),int(text.size()),nullptr,0,nullptr,nullptr);
    std::string result(length,'\0'); if(length) WideCharToMultiByte(CP_UTF8,0,text.data(),int(text.size()),result.data(),length,nullptr,nullptr); return result;
}
std::wstring escaped(const std::wstring &text) {
    std::wstring result;
    for(wchar_t c:text) switch(c) {
    case L'&': result+=L"&amp;"; break; case L'<': result+=L"&lt;"; break; case L'>': result+=L"&gt;"; break;
    case L'\"': result+=L"&quot;"; break; case L'\'': result+=L"&apos;"; break;
    default: if(c>=32 || c==L'\n' || c==L'\t') result+=c; break;
    }
    return result;
}
HRESULT queueAction(LPCWSTR argument) {
    if(!argument) return E_INVALIDARG;
    std::wstring value(argument); if(value.size()>1024 || value.find(L'|')==std::wstring::npos) return E_INVALIDARG;
    int ticket;
    { std::lock_guard<std::mutex> lock(actionsLock); ticket=++nextAction; actions[ticket]=value; }
    ch_post(-8,ticket); return S_OK;
}
}

class DECLSPEC_UUID("1512AA6B-C6C5-4D18-AE0B-39E168943CA7") ChotkiNotificationActivator final : public RuntimeClass<RuntimeClassFlags<ClassicCom>,INotificationActivationCallback> {
public:
    HRESULT STDMETHODCALLTYPE Activate(LPCWSTR,LPCWSTR arguments,const NOTIFICATION_USER_INPUT_DATA*,ULONG) override { return queueAction(arguments); }
};
class DECLSPEC_UUID("F5B98871-0C8C-451E-9BCD-CA54B93B6530") ChotkiReviewNotificationActivator final : public RuntimeClass<RuntimeClassFlags<ClassicCom>,INotificationActivationCallback> {
public:
    HRESULT STDMETHODCALLTYPE Activate(LPCWSTR,LPCWSTR arguments,const NOTIFICATION_USER_INPUT_DATA*,ULONG) override { return queueAction(arguments); }
};
CoCreatableClass(ChotkiNotificationActivator);
CoCreatableClass(ChotkiReviewNotificationActivator);

namespace {
HRESULT ensureShortcut(const wchar_t *aumid,REFCLSID activator) {
    PWSTR programs=nullptr; HRESULT hr=SHGetKnownFolderPath(FOLDERID_Programs,KF_FLAG_CREATE,nullptr,&programs);
    if(FAILED(hr)) return hr;
    shortcutPath=std::wstring(programs)+(temporaryIdentity ? L"\\Chotki notification review.lnk" : L"\\Chotki.lnk"); CoTaskMemFree(programs);
    wchar_t executable[32768]; DWORD length=GetModuleFileNameW(nullptr,executable,32768);
    if(!length || length>=32768) return HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER);
    ComPtr<IShellLinkW> link; hr=CoCreateInstance(CLSID_ShellLink,nullptr,CLSCTX_INPROC_SERVER,IID_PPV_ARGS(&link)); if(FAILED(hr)) return hr;
    hr=link->SetPath(executable); if(FAILED(hr)) return hr;
    std::wstring directory(executable); directory.resize(directory.find_last_of(L"\\/"));
    // Installed shortcuts keep the runtime path isolated on the ARM64 build VM.
    // Development/review outputs retain their directly runnable executable link.
    std::wstring launcher=directory+L"\\launch-windows.ps1";
    if(GetFileAttributesW(launcher.c_str())!=INVALID_FILE_ATTRIBUTES) {
        wchar_t system[MAX_PATH]; GetSystemDirectoryW(system,MAX_PATH);
        std::wstring powershell=std::wstring(system)+L"\\WindowsPowerShell\\v1.0\\powershell.exe";
        hr=link->SetPath(powershell.c_str()); if(FAILED(hr)) return hr;
        std::wstring arguments=L"-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File \""+launcher+L"\"";
        hr=link->SetArguments(arguments.c_str()); if(FAILED(hr)) return hr;
        hr=link->SetIconLocation(executable,0); if(FAILED(hr)) return hr;
    }
    hr=link->SetWorkingDirectory(directory.c_str()); if(FAILED(hr)) return hr;
    hr=link->SetDescription(L"Chotki"); if(FAILED(hr)) return hr;
    ComPtr<IPropertyStore> properties; hr=link.As(&properties); if(FAILED(hr)) return hr;
    PROPVARIANT value; PropVariantInit(&value); hr=InitPropVariantFromString(aumid,&value);
    if(SUCCEEDED(hr)) hr=properties->SetValue(PKEY_AppUserModel_ID,value); PropVariantClear(&value); if(FAILED(hr)) return hr;
    hr=InitPropVariantFromCLSID(activator,&value);
    if(SUCCEEDED(hr)) hr=properties->SetValue(PKEY_AppUserModel_ToastActivatorCLSID,value); PropVariantClear(&value); if(FAILED(hr)) return hr;
    hr=properties->Commit(); if(FAILED(hr)) return hr;
    ComPtr<IPersistFile> file; hr=link.As(&file); return FAILED(hr) ? hr : file->Save(shortcutPath.c_str(),TRUE);
}
}

// mode 1 is quiet synthetic delivery. Mode 2 exercises Windows with a temporary
// identity; it is reserved for the explicit native-notification smoke test.
extern "C" int32_t ch_notifications_start(int32_t mode) {
    if(initialized) return 0;
    silentReview=mode==1; temporaryIdentity=mode==2;
    HRESULT hr=RoInitialize(RO_INIT_SINGLETHREADED); roInitialized=SUCCEEDED(hr);
    if(FAILED(hr) && hr!=RPC_E_CHANGED_MODE) return hr;
    if(silentReview) { initialized=true; return 0; }
    const wchar_t *aumid=temporaryIdentity ? reviewID : appID;
    GUID activator=temporaryIdentity ? __uuidof(ChotkiReviewNotificationActivator) : __uuidof(ChotkiNotificationActivator);
    hr=ensureShortcut(aumid,activator); if(FAILED(hr)) return hr;
    hr=SetCurrentProcessExplicitAppUserModelID(aumid); if(FAILED(hr)) return hr;
    hr=DesktopNotificationManagerCompat::RegisterAumidAndComServer(aumid,activator); if(FAILED(hr)) return hr;
    hr=DesktopNotificationManagerCompat::RegisterActivator(); if(FAILED(hr)) return hr;
    hr=DesktopNotificationManagerCompat::CreateToastNotifier(&notifier); if(FAILED(hr)) return hr;
    hr=DesktopNotificationManagerCompat::get_History(&history); if(FAILED(hr)) return hr;
    initialized=true; return 0;
}
extern "C" int32_t ch_notification_show(const char *identifier,const char *title,const char *body) {
    if(!initialized) return E_UNEXPECTED;
    auto id=wide(identifier);
    std::wstring tag=std::to_wstring(++nextTag);
    // Tags are short native identifiers; the full core ID lives in the action.
    std::wstring xml=L"<toast launch=\"open|"+escaped(id)+L"\"><visual><binding template=\"ToastGeneric\"><text>"+escaped(wide(title))+L"</text><text>"+escaped(wide(body))+L"</text></binding></visual><actions><action content=\"Mark complete\" arguments=\"complete|"+escaped(id)+L"\" activationType=\"background\"/><action content=\"Snooze an hour\" arguments=\"snooze|"+escaped(id)+L"\" activationType=\"background\"/></actions><audio silent=\"true\"/></toast>";
    ComPtr<IXmlDocument> document; HRESULT hr=DesktopNotificationManagerCompat::CreateXmlDocumentFromString(xml.c_str(),&document);
    if(FAILED(hr)) return hr;
    if(silentReview) { deliveredTags[id]=tag; return 0; }
    ComPtr<IToastNotification> notification; hr=DesktopNotificationManagerCompat::CreateToastNotification(document.Get(),&notification); if(FAILED(hr)) return hr;
    ComPtr<IToastNotification2> labels; hr=notification.As(&labels); if(FAILED(hr)) return hr;
    hr=labels->put_Tag(HStringReference(tag.c_str()).Get()); if(FAILED(hr)) return hr;
    hr=labels->put_Group(HStringReference(L"chotki").Get()); if(FAILED(hr)) return hr;
    hr=notifier->Show(notification.Get()); if(SUCCEEDED(hr)) deliveredTags[id]=tag; return hr;
}
extern "C" int32_t ch_notification_cancel(const char *identifier) {
    auto found=deliveredTags.find(wide(identifier)); if(found==deliveredTags.end()) return 0;
    HRESULT hr=silentReview ? S_OK : history->RemoveGroupedTag(found->second.c_str(),L"chotki");
    if(SUCCEEDED(hr)) deliveredTags.erase(found); return hr;
}
extern "C" int32_t ch_notification_take(int32_t ticket,char *identifier,int32_t length,char *action,int32_t actionLength) {
    std::wstring value;
    { std::lock_guard<std::mutex> lock(actionsLock); auto found=actions.find(ticket); if(found==actions.end()) return 0; value=found->second; actions.erase(found); }
    auto split=value.find(L'|'); auto id=utf8(value.substr(split+1)),verb=utf8(value.substr(0,split));
    if(int(id.size())+1>length || int(verb.size())+1>actionLength) return -1;
    memcpy(identifier,id.c_str(),id.size()+1); memcpy(action,verb.c_str(),verb.size()+1); return 1;
}
extern "C" int32_t ch_test_notification(const char *identifier,const char *action) {
    if(!silentReview && !temporaryIdentity) return -1;
    if(!action) return deliveredTags.count(wide(identifier)) ? 1 : 0;
    // Use the same COM activation method that the notification buttons call.
    auto callback=Make<ChotkiReviewNotificationActivator>(); std::wstring argument=wide(action)+L"|"+wide(identifier);
    HRESULT hr=callback->Activate(reviewID,argument.c_str(),nullptr,0); ch_pump(); return hr;
}
extern "C" int32_t ch_notification_history_count(void) {
    if(silentReview) return int(deliveredTags.size());
    if(!history) return -1;
    ComPtr<ABI::Windows::Foundation::Collections::IVectorView<ToastNotification*>> items;
    HRESULT hr=history->GetHistory(&items); if(FAILED(hr)) return hr;
    unsigned int size=0; hr=items->get_Size(&size); return FAILED(hr) ? hr : int(size);
}
extern "C" void ch_notifications_close(void) {
    if(history) history->Clear();
    notifier.Reset(); history.reset(); deliveredTags.clear();
    if(!silentReview && initialized) Module<OutOfProc>::GetModule().UnregisterObjects();
    if(temporaryIdentity) {
        if(!shortcutPath.empty()) DeleteFileW(shortcutPath.c_str());
        RegDeleteTreeW(HKEY_CURRENT_USER,L"Software\\Classes\\CLSID\\{F5B98871-0C8C-451E-9BCD-CA54B93B6530}");
    }
    initialized=false; if(roInitialized) { RoUninitialize(); roInitialized=false; }
    std::lock_guard<std::mutex> lock(actionsLock); actions.clear();
}
