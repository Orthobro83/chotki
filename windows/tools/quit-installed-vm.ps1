param([switch]$Interactive)
$ErrorActionPreference='Stop'
$expected=Join-Path $env:LOCALAPPDATA 'Programs\Chotki\ChotkiWindows.exe'
$log='C:\workspace-build\quit-installed.log'
if($Interactive){
    try {
        $running=@(Get-CimInstance Win32_Process -Filter "Name='ChotkiWindows.exe'" | Where-Object { $_.ExecutablePath -eq $expected })
        if($running.Count -eq 0){'Installed Chotki was already closed.' | Set-Content $log; exit 0}
        if($running.Count -ne 1){throw 'More than one installed Chotki process is running.'}
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ChotkiInstalledQuit {
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
 [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hwnd,uint msg,IntPtr wp,IntPtr lp);
 public delegate bool WindowCallback(IntPtr hwnd,IntPtr data);
 [DllImport("user32.dll")] public static extern bool EnumWindows(WindowCallback callback,IntPtr data);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd,System.Text.StringBuilder name,int length);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hwnd,System.Text.StringBuilder name,int length);
 public static string Describe(uint process) {
   var result=new System.Collections.Generic.List<string>();
   EnumWindows((hwnd,data)=> { uint owner; GetWindowThreadProcessId(hwnd,out owner);
     if(owner==process){var cls=new System.Text.StringBuilder(256);var title=new System.Text.StringBuilder(256);
       GetClassName(hwnd,cls,256);GetWindowText(hwnd,title,256);result.Add(hwnd+" class="+cls+" title="+title);}
     return true; },IntPtr.Zero);
   return String.Join(" | ",result);
 }
 public static IntPtr WindowForProcess(uint process) {
   IntPtr found=IntPtr.Zero;
   EnumWindows((hwnd,data)=> { uint owner; GetWindowThreadProcessId(hwnd,out owner);
     if(owner==process){var cls=new System.Text.StringBuilder(256);GetClassName(hwnd,cls,256);
       if(cls.ToString()=="ChotkiWindows"){found=hwnd;return false;}}
     return true; },IntPtr.Zero);
   return found;
 }
}
'@
        $window=[ChotkiInstalledQuit]::WindowForProcess([uint32]$running[0].ProcessId)
        $owner=[uint32]0
        if($window -ne [IntPtr]::Zero){[ChotkiInstalledQuit]::GetWindowThreadProcessId($window,[ref]$owner) | Out-Null}
        "Task session=$((Get-Process -Id $PID).SessionId); installed session=$((Get-Process -Id $running[0].ProcessId).SessionId); target windows=$([ChotkiInstalledQuit]::Describe([uint32]$running[0].ProcessId)); selected=$window owner=$owner" | Set-Content $log
        if($window -eq [IntPtr]::Zero -or $owner -ne $running[0].ProcessId){throw 'Installed Chotki window identity mismatch; no Quit command was sent.'}
        [ChotkiInstalledQuit]::SendMessage($window,0x0111,[IntPtr]7003,[IntPtr]::Zero) | Out-Null
        for($attempt=0;$attempt -lt 50;$attempt++){
            if(!(Get-Process -Id $owner -ErrorAction SilentlyContinue)){break}
            Start-Sleep -Milliseconds 100
        }
        if(Get-Process -Id $owner -ErrorAction SilentlyContinue){throw 'Chotki remained running after its Quit command.'}
        "Normal Quit completed for installed Chotki process $owner." | Add-Content $log
        exit 0
    } catch { $_.Exception.Message | Add-Content $log; exit 1 }
}

$name='ChotkiInstalledQuit-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$principal=New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value) -LogonType Interactive -RunLevel Limited
$action=New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\workspace-build\tools\quit-installed-vm.ps1 -Interactive'
Register-ScheduledTask -TaskName $name -Action $action -Principal $principal | Out-Null
try {
    Remove-Item $log -ErrorAction SilentlyContinue
    Start-ScheduledTask $name
    $complete=$false
    for($attempt=0;$attempt -lt 30;$attempt++){
        Start-Sleep -Seconds 1
        $info=Get-ScheduledTaskInfo $name
        if($info.LastRunTime.Year -gt 2000 -and (Get-ScheduledTask $name).State -eq 'Ready' -and $info.LastTaskResult -ne 267009){$complete=$true;break}
    }
    if(Test-Path $log){Get-Content $log}
    if(!$complete -or $info.LastTaskResult -ne 0){throw "Normal Quit review failed: $($info.LastTaskResult)"}
} finally {
    Stop-ScheduledTask $name -ErrorAction SilentlyContinue
    Unregister-ScheduledTask $name -Confirm:$false
}
exit 0
