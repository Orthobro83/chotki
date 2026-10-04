param([ValidateSet('debug','release')][string]$Configuration='debug',[switch]$VisualOnly)
# Run on the logged-in VM desktop, using only synthetic data.
. $PSScriptRoot\windows-env.ps1
if($VisualOnly){$env:CHOTKI_VISUAL_REVIEW='1'}else{Remove-Item Env:CHOTKI_VISUAL_REVIEW -ErrorAction SilentlyContinue}
$exe = Get-ChotkiExecutable $Configuration
$OutputDir = $exe.DirectoryName
$env:PATH = "$OutputDir;C:\Windows\system32;C:\Windows"
$env:CHOTKI_REVIEW_CAPTURE = 'C:\workspace-build\review.bmp'
Get-ChildItem 'C:\workspace-build' -Filter 'review*.bmp' -File | Remove-Item -Force
Set-Location $OutputDir
# Retain the child PID so a timed-out scheduled task can clean up only its own
# synthetic process and release the executable before the next build.
$app = Start-Process -FilePath $exe.FullName -ArgumentList '--ui-smoke' -NoNewWindow -PassThru -RedirectStandardOutput 'C:\workspace-build\review.log' -RedirectStandardError 'C:\workspace-build\review-error.log'
$null = $app.Handle
$app.Id | Set-Content 'C:\workspace-build\review.pid'
# SetForegroundWindow requires user input ownership. A scheduled review is
# not an Explorer tray click; supply one physical click on this synthetic
# window's title bar before testing foreground restoration.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ChotkiReviewFocus {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int left,top,right,bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct Input { public uint type; public Mouse mouse; }
    [StructLayout(LayoutKind.Sequential)] public struct Mouse { public int x,y; public uint data,flags,time; public UIntPtr extra; }
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string cls,string title);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd,out Rect rect);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
    [DllImport("user32.dll")] public static extern uint SendInput(uint count,Input[] events,int size);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    public static bool ClickTitle(int process) {
        IntPtr window=FindWindow("ChotkiWindows",null); uint owner;
        if(window==IntPtr.Zero || !IsWindowVisible(window))return false;
        GetWindowThreadProcessId(window,out owner); if(owner!=process)return false;
        SetThreadDpiAwarenessContext(new IntPtr(-4)); Rect r; GetWindowRect(window,out r);
        Input[] input=new Input[3];
        input[0].mouse.x=(r.left+100-GetSystemMetrics(76))*65535/(GetSystemMetrics(78)-1);
        input[0].mouse.y=(r.top+12-GetSystemMetrics(77))*65535/(GetSystemMetrics(79)-1);
        input[0].mouse.flags=0xC001;input[1].mouse.flags=2;input[2].mouse.flags=4;
        return SendInput(3,input,Marshal.SizeOf(typeof(Input)))==3;
    }
}
'@
for($attempt=0;$attempt -lt 50 -and !$app.HasExited;$attempt++) {
    if([ChotkiReviewFocus]::ClickTitle($app.Id)){break}
    Start-Sleep -Milliseconds 100
}
$app.WaitForExit()
$code = $app.ExitCode
if ($null -eq $code) { throw 'Synthetic review did not report an exit code.' }
if (Test-Path 'C:\workspace-build\review-error.log') { Get-Content 'C:\workspace-build\review-error.log' | Add-Content 'C:\workspace-build\review.log' }
Add-Content 'C:\workspace-build\review.log' "UI review exit: $code"
exit $code
