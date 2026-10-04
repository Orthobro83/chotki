param([string]$Application='C:\workspace-build\.build\package\Chotki-Windows-x64\ChotkiWindows.exe')
# Exercise real startup/instance/window/animation adapters with private identity and data.
. $PSScriptRoot\windows-env.ps1
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class ChotkiLifecycle {
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string cls,string title);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent,IntPtr after,string cls,string title);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr hwnd,int id);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hwnd,StringBuilder text,int size);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hwnd,uint message,IntPtr wp,IntPtr lp);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd,uint message,IntPtr wp,IntPtr lp);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
    [DllImport("user32.dll")] public static extern bool SystemParametersInfo(uint action,uint param,out bool value,uint flags);
    public delegate bool ChildCallback(IntPtr hwnd,IntPtr data);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent,ChildCallback callback,IntPtr data);
    public static IntPtr Control(IntPtr parent,int id) { IntPtr result=IntPtr.Zero; EnumChildWindows(parent,(child,data)=>{ if(GetDlgCtrlID(child)==id){result=child;return false;}return true; },IntPtr.Zero); return result; }
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr hwnd);
    public static string Text(IntPtr hwnd,int id) { var s=new StringBuilder(1024); GetWindowText(Control(hwnd,id),s,s.Capacity); return s.ToString(); }
}
'@
$exe=Get-Item $Application
if(!(Test-IsX64 $exe.FullName)){throw 'Draft payload executable is not x64.'}
$env:PATH="$($exe.DirectoryName);C:\Windows\system32;C:\Windows"
Set-Location $exe.DirectoryName
$log='C:\workspace-build\lifecycle-review.log'
'Installed-adapter lifecycle review; private namespace and in-memory practice.' | Set-Content $log
function Require([bool]$condition,[string]$message) { if(!$condition){throw $message}; $message | Add-Content $log }
function Await([scriptblock]$condition,[string]$message,[int]$Attempts=70) { for($i=0;$i -lt $Attempts;$i++){if(& $condition){return};Start-Sleep -Milliseconds 100};throw $message }
$registration='HKCU:\Software\Chotki\LifecycleReview'
if(Test-Path $registration){throw 'Private lifecycle registration already exists; preserve it for investigation.'}
$app=$null
try {
    Require ([ChotkiLifecycle]::FindWindow('ChotkiWindowsLifecycleReview','Chotki') -eq [IntPtr]::Zero) 'Private lifecycle namespace is available'
    $app=Start-Process $exe.FullName -ArgumentList '--lifecycle-smoke','--startup' -PassThru
    $app.Id | Set-Content 'C:\workspace-build\lifecycle-review.pid'
    $script:hwnd=[IntPtr]::Zero
    Await { $script:hwnd=[ChotkiLifecycle]::FindWindow('ChotkiWindowsLifecycleReview','Chotki'); $script:hwnd -ne [IntPtr]::Zero } 'Hidden startup window did not initialize'
    [uint32]$owner=0; [ChotkiLifecycle]::GetWindowThreadProcessId($hwnd,[ref]$owner) | Out-Null
    Require ($owner -eq $app.Id) 'Startup HWND belongs to this synthetic process'
    Await { [ChotkiLifecycle]::GetDlgItem($hwnd,105) -ne [IntPtr]::Zero } 'Startup controls did not initialize'
    Require (![ChotkiLifecycle]::IsWindowVisible($hwnd)) 'Login startup stays hidden with the tray resident'
    $second=Start-Process $exe.FullName -ArgumentList '--lifecycle-smoke' -PassThru
    Require ($second.WaitForExit(10000)) 'Second launch finishes without creating another resident process'
    Require ($second.ExitCode -eq 0) 'Second launch exits successfully'
    Await { [ChotkiLifecycle]::IsWindowVisible($hwnd) } 'Second launch failed to reveal the first instance'
    Await { [ChotkiLifecycle]::Text($hwnd,200).StartsWith('Good ') } 'Second launch did not finish rendering Home'
    'Second launch brings the existing app to Home.' | Add-Content $log
    [bool]$animate=$false; [ChotkiLifecycle]::SystemParametersInfo(0x1042,0,[ref]$animate,0) | Out-Null
    ('Opening state: '+[ChotkiLifecycle]::SendMessage($hwnd,0x8032,[IntPtr]::Zero,[IntPtr]::Zero).ToInt32()) | Add-Content $log
    if($animate) {
        Await { [ChotkiLifecycle]::FindWindowEx($hwnd,[IntPtr]::Zero,'ChotkiOpening','The opening') -ne [IntPtr]::Zero } 'Opening animation did not begin'
        Await { [ChotkiLifecycle]::FindWindowEx($hwnd,[IntPtr]::Zero,'ChotkiOpening','The opening') -eq [IntPtr]::Zero } 'Opening animation did not finish'
        'Actual timed opening animation completed.' | Add-Content $log
    }
    [ChotkiLifecycle]::PostMessage($hwnd,0x111,[IntPtr]105,[IntPtr]::Zero) | Out-Null
    Await { [ChotkiLifecycle]::Control($hwnd,311) -ne [IntPtr]::Zero } 'Settings route failed after opening animation'
    Await { [ChotkiLifecycle]::Control($hwnd,625) -ne [IntPtr]::Zero } 'Login preference did not finish rendering'
    [ChotkiLifecycle]::SendMessage($hwnd,0,[IntPtr]::Zero,[IntPtr]::Zero) | Out-Null
    $login=[ChotkiLifecycle]::Control($hwnd,625)
    Require ($login -ne [IntPtr]::Zero) 'Login preference is available in the packaged UI'
    [ChotkiLifecycle]::PostMessage($login,0xF5,[IntPtr]::Zero,[IntPtr]::Zero) | Out-Null
    Await { Test-Path ($registration+'\Run') } 'Native login adapter did not create its private registration'
    Await { $null -ne (Get-ItemProperty ($registration+'\Run') -Name Chotki -ErrorAction SilentlyContinue) } 'Native login command did not persist'
    $command=(Get-ItemProperty ($registration+'\Run')).Chotki
    ('Private login command: '+$command) | Add-Content $log
    Require ($command.Contains('launch-windows.ps1" -Startup') -and $command.StartsWith('"C:\Windows\System32\WindowsPowerShell',[StringComparison]::OrdinalIgnoreCase)) 'Packaged login registration uses the isolated launcher with correctly quoted paths'
    $oldLogin=$login
    Await { $current=[ChotkiLifecycle]::Control($hwnd,625); $current -ne [IntPtr]::Zero -and $current -ne $oldLogin } 'Login form did not finish rebuilding'
    $login=[ChotkiLifecycle]::Control($hwnd,625)
    [ChotkiLifecycle]::PostMessage($login,0xF5,[IntPtr]::Zero,[IntPtr]::Zero) | Out-Null
    Await { (Get-Item ($registration+'\Run')).GetValue('Chotki',$null) -eq $null } 'Disabling login did not remove the private Run value'
    [ChotkiLifecycle]::PostMessage($hwnd,0x10,[IntPtr]::Zero,[IntPtr]::Zero) | Out-Null
    Await { ![ChotkiLifecycle]::IsWindowVisible($hwnd) } 'Close did not hide the resident app'
    $third=Start-Process $exe.FullName -ArgumentList '--lifecycle-smoke' -PassThru
    Require ($third.WaitForExit(10000) -and $third.ExitCode -eq 0) 'Reopening a hidden instance returns successfully'
    Await { [ChotkiLifecycle]::IsWindowVisible($hwnd) -and [ChotkiLifecycle]::Text($hwnd,200).StartsWith('Good ') } 'Hidden instance did not return to Home'
    [ChotkiLifecycle]::PostMessage($hwnd,0x111,[IntPtr]7003,[IntPtr]::Zero) | Out-Null
    Require ($app.WaitForExit(5000)) 'Tray Quit exits the resident process'
    Require ($app.ExitCode -eq 0) 'Lifecycle process exits with code 0'
    'Lifecycle review passed: hidden login, second launch, timed opening, Settings, close-to-tray, Home restore and Quit.' | Add-Content $log
} catch { $_ | Out-String | Add-Content $log; exit 1 } finally {
    if($app -and !$app.HasExited){Stop-Process $app.Id -Force}
    if(Test-Path $registration){Remove-Item $registration -Recurse -Force}
    Remove-Item 'C:\workspace-build\lifecycle-review.pid' -ErrorAction SilentlyContinue
}
exit 0
