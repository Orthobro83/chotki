param([ValidateSet('debug','release')][string]$Configuration='debug')
$ErrorActionPreference='Stop'
$log='C:\workspace-build\input-review.log'
'Physical input review initializing.' | Set-Content $log
trap { $_.Exception.ToString() | Add-Content $log; exit 1 }
. $PSScriptRoot\windows-env.ps1
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
# The managed UIA proxy loader inspects caller stack frames. PowerShell's
# dynamic call frames have no ReflectedType; initialize from a compiled bridge.
# See dotnet/wpf ProxyManager.LoadDefaultProxies, rather than treating missing
# patterns from its fallback HWND provider as an application control defect.
Add-Type -ReferencedAssemblies @([System.Windows.Automation.AutomationElement].Assembly.Location,[System.Windows.Automation.ControlType].Assembly.Location) @'
using System;
using System.Runtime.InteropServices;
public static class ChotkiReviewInput {
    public static void InitializeProviders() {
        Exception error=null;
        var thread=new System.Threading.Thread(()=>{ try { InitializeWin32Providers(); } catch(Exception exception) { error=exception; } });
        thread.Start(); thread.Join(); if(error!=null) throw new Exception("Win32 provider initialization failed",error);
    }
    [System.Runtime.CompilerServices.MethodImpl(System.Runtime.CompilerServices.MethodImplOptions.NoInlining)]
    private static void InitializeWin32Providers() {
        var assembly=System.Reflection.Assembly.Load("UIAutomationClientsideProviders, Version=4.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35");
        System.Windows.Automation.ClientSettings.RegisterClientSideProviderAssembly(assembly.GetName());
    }
    [StructLayout(LayoutKind.Sequential)] public struct Mouse { public int x,y; public uint data,flags,time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] public struct Key { public ushort vk,scan; public uint flags,time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Explicit)] public struct Data { [FieldOffset(0)] public Mouse mouse; [FieldOffset(0)] public Key key; }
    [StructLayout(LayoutKind.Sequential)] public struct Input { public uint type; public Data data; }
    [DllImport("user32.dll",SetLastError=true)] public static extern uint SendInput(uint count,Input[] input,int size);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr window,int command);
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int x,y; }
    [DllImport("user32.dll")] public static extern bool GetPhysicalCursorPos(out Point point);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(Point point);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int left,top,right,bottom; public int Width { get { return right-left; } } public int Height { get { return bottom-top; } } public override string ToString() { return left+","+top+","+Width+","+Height; } }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd,out Rect rect);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
    public static Rect Bounds(int handle) { Rect r; if(!GetWindowRect(new IntPtr(handle),out r))throw new Exception("Control was replaced before click"); return r; }
    public static string MouseTarget() { Point point; GetPhysicalCursorPos(out point); uint pid; GetWindowThreadProcessId(WindowFromPoint(point),out pid); return point.x+","+point.y+" control "+GetDlgCtrlID(WindowFromPoint(point))+" process "+pid; }
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
    public delegate bool EnumChild(IntPtr hwnd,IntPtr data);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent,EnumChild callback,IntPtr data);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr hwnd);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr hwnd,uint message,UIntPtr wParam,IntPtr lParam);
    public static string Children(IntPtr parent) {
        string result=""; EnumChildWindows(parent,(hwnd,data)=>{ result+=GetDlgCtrlID(hwnd)+"@"+hwnd+" "; return true; },IntPtr.Zero); return result;
    }
    public static void Click(double x,double y) {
        Input[] events=new Input[3];
        events[0].data.mouse.x=(int)((x-GetSystemMetrics(76))*65535/(GetSystemMetrics(78)-1));
        events[0].data.mouse.y=(int)((y-GetSystemMetrics(77))*65535/(GetSystemMetrics(79)-1));
        events[0].data.mouse.flags=0xC001;
        events[1].data.mouse.flags=2; events[2].data.mouse.flags=4;
        if(SendInput(3,events,Marshal.SizeOf(typeof(Input)))!=3) throw new Exception("Mouse input rejected: "+Marshal.GetLastWin32Error());
    }
    public static void KeyEvent(ushort key,bool up) {
        Input e=new Input(); e.type=1; e.data.key.vk=key; e.data.key.flags=up ? 2u : 0u;
        if(SendInput(1,new Input[]{e},Marshal.SizeOf(typeof(Input)))!=1) throw new Exception("Keyboard input rejected");
    }
    public static void Press(ushort key) { KeyEvent(key,false); KeyEvent(key,true); }
    public static void Type(string value) {
        foreach(char c in value) { Input down=new Input(); down.type=1; down.data.key.scan=c; down.data.key.flags=4;
            Input up=down; up.data.key.flags=6;
            if(SendInput(2,new Input[]{down,up},Marshal.SizeOf(typeof(Input)))!=2) throw new Exception("Unicode input rejected"); }
    }
    public static void Wheel(int delta) { Input e=new Input(); e.data.mouse.flags=0x800; e.data.mouse.data=unchecked((uint)delta); if(SendInput(1,new Input[]{e},Marshal.SizeOf(typeof(Input)))!=1) throw new Exception("Mouse wheel input rejected"); }
}
'@
[ChotkiReviewInput]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
[ChotkiReviewInput]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null
[ChotkiReviewInput]::InitializeProviders()
$exe=Get-ChotkiExecutable $Configuration
$OutputDir=$exe.DirectoryName
$env:PATH="$OutputDir;C:\Windows\system32;C:\Windows"
Set-Location $OutputDir
$app=Start-Process $exe.FullName -ArgumentList '--review' -PassThru -RedirectStandardOutput 'C:\workspace-build\input-app.log' -RedirectStandardError 'C:\workspace-build\input-app-error.log'
$app.Id | Set-Content 'C:\workspace-build\input-review.pid'
$log='C:\workspace-build\input-review.log'
'Physical input review started; synthetic record only.' | Set-Content $log
try {
    $script:root=$null
    $processCondition=New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::ProcessIdProperty),([int]$app.Id)
    for ($attempt=0;$attempt -lt 100;$attempt++) {
        $windows=[System.Windows.Automation.AutomationElement]::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children,$processCondition)
        foreach ($candidate in $windows) { if ($candidate.Current.ClassName -eq 'ChotkiWindows') { $script:root=$candidate; break } }
        if ($script:root) { break }
        Start-Sleep -Milliseconds 100
    }
    if (!$script:root) { throw 'The Chotki GUI window did not appear.' }
    ('GUI selected: '+$script:root.Current.ClassName+'; process '+$script:root.Current.ProcessId) | Add-Content $log
    [ChotkiReviewInput]::ShowWindow([IntPtr]$script:root.Current.NativeWindowHandle,3) | Out-Null
    [ChotkiReviewInput]::SetForegroundWindow([IntPtr]$script:root.Current.NativeWindowHandle) | Out-Null
    function Element([int]$id) {
        $condition=New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::AutomationIdProperty),([string]$id)
        $script:root.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$condition)
    }
    function Require([bool]$condition,[string]$message) { if (!$condition) { throw $message } }
    function Wait-For([scriptblock]$condition,[string]$message) {
        for ($attempt=0;$attempt -lt 30;$attempt++) { if (& $condition) { return }; Start-Sleep -Milliseconds 100 }
        throw $message
    }
    function Click-Control([int]$id) {
        $element=Element $id
        if (!$element) { throw "UI Automation control $id missing" }
        for ($attempt=0;$attempt -lt 40;$attempt++) {
            $bounds=[ChotkiReviewInput]::Bounds($element.Current.NativeWindowHandle); $frame=[ChotkiReviewInput]::Bounds($script:root.Current.NativeWindowHandle)
            $pane=Element 9008
            $clip=if($pane){[ChotkiReviewInput]::Bounds($pane.Current.NativeWindowHandle)}else{$frame}
            if ($bounds.Top -ge $clip.Top+4 -and $bounds.Bottom -le $clip.Bottom-24 -or $id -ge 100 -and $id -le 106) { break }
            [ChotkiReviewInput]::Click($clip.Right-35,$clip.Top+70)
            [ChotkiReviewInput]::Wheel($(if($bounds.Top -lt $clip.Top+4){120}else{-120}))
            Start-Sleep -Milliseconds 80; $element=Element $id
        }
        $bounds=[ChotkiReviewInput]::Bounds($element.Current.NativeWindowHandle)
        [ChotkiReviewInput]::Click($bounds.Left+$bounds.Width/2,$bounds.Top+$bounds.Height/2)
        Start-Sleep -Milliseconds 150
        ('Click '+$id+' requested '+$bounds.ToString()+'; actual '+[ChotkiReviewInput]::MouseTarget()) | Add-Content $log
    }
    Wait-For { $null -ne (Element 105) } 'Chotki controls were not exposed after GUI initialization'
    Click-Control 100
    Wait-For { $null -ne (Element 2000) } 'Home completion control missing'
    Click-Control 2000
    Wait-For { (Element 2000).Current.Name.StartsWith('Clear ') } 'Physical card completion did not mark the rule kept'
    Click-Control 2000
    Wait-For { (Element 2000).Current.Name.StartsWith('Mark ') } 'Physical card completion did not clear the record'
    Click-Control 105
    Wait-For { $null -ne (Element 311) } 'Physical Settings navigation'
    $name=Element 311
    ('Name field role: '+$name.Current.ControlType.ProgrammaticName) | Add-Content $log
    Require ($name.Current.ControlType -eq [System.Windows.Automation.ControlType]::Edit) 'Name field accessibility role'
    Click-Control 311
    $name=Element 311
    $name.SetFocus()
    Wait-For { (Element 311).Current.HasKeyboardFocus } 'Name field did not receive keyboard focus' 
    [ChotkiReviewInput]::KeyEvent(17,$false); [ChotkiReviewInput]::Press(65); [ChotkiReviewInput]::KeyEvent(17,$true)
    $vera= -join ([char]0x0412,[char]0x0435,[char]0x0440,[char]0x0430)
    [ChotkiReviewInput]::Type($vera)
    Start-Sleep -Milliseconds 200
    ('Entered name: '+(Element 311).GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value+'; focused control: '+[System.Windows.Automation.AutomationElement]::FocusedElement.Current.AutomationId) | Add-Content $log
    Wait-For { (Element 311).GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value -eq $vera } 'Physical Unicode name entry'
    'PASS: real mouse Settings navigation and keyboard Unicode name entry.' | Add-Content $log
    ('Before notification click: '+(Element 605).GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern).Current.ToggleState+'; lead enabled '+(Element 606).Current.IsEnabled) | Add-Content $log
    Click-Control 605
    $toggle=Element 605
    ('After notification click: '+$toggle.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern).Current.ToggleState+'; lead enabled '+(Element 606).Current.IsEnabled) | Add-Content $log
    Require ($toggle.Current.ControlType -eq [System.Windows.Automation.ControlType]::CheckBox) 'Notification accessibility role'
    Require ([bool]$toggle.GetCurrentPropertyValue([System.Windows.Automation.AutomationElement]::IsTogglePatternAvailableProperty)) 'Notification TogglePattern'
    Wait-For { !(Element 606).Current.IsEnabled } 'Physical notification toggle did not disable its lead picker'
    Click-Control 605
    Wait-For { (Element 606).Current.IsEnabled } 'Physical notification enable did not restore its lead picker'
    'PASS: physical switches, native CheckBox/TogglePattern and dependent enabled state.' | Add-Content $log
    Click-Control 102
    Wait-For { $null -ne (Element 420) } 'Physical Prayers navigation'
    Click-Control 420
    Wait-For { (Element 426).Current.Name.StartsWith('1 of ') } 'Physical Count button'
    Start-Sleep -Milliseconds 1050
    [ChotkiReviewInput]::Press(32)
    Wait-For { (Element 426).Current.Name.StartsWith('2 of ') } 'Physical Space counting'
    Click-Control 421
    Wait-For { (Element 426).Current.Name.StartsWith('0 of ') } 'Physical rope reset'
    'PASS: real Count click, Space key and reset; counter exposed to accessibility.' | Add-Content $log
    Click-Control 321
    $menuCondition=New-Object System.Windows.Automation.AndCondition @($processCondition,(New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::ClassNameProperty),'#32768'))
    $script:menu=$null
    Wait-For { $script:menu=[System.Windows.Automation.AutomationElement]::RootElement.FindFirst([System.Windows.Automation.TreeScope]::Children,$menuCondition); $null -ne $script:menu } 'Native prayer popup was not exposed'
    $items=$script:menu.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
    $items | Select-Object -First 10 | ForEach-Object { ('Menu: '+$_.Current.Name+'; enabled '+$_.Current.IsEnabled) | Add-Content $log }
    [ChotkiReviewInput]::Press(40); Start-Sleep -Milliseconds 100
    ('Menu keyboard focus: '+[System.Windows.Automation.AutomationElement]::FocusedElement.Current.Name) | Add-Content $log
    [ChotkiReviewInput]::Press(27)
    Wait-For { (Element 426).Current.Name.StartsWith('0 of ') } 'Menu keyboard navigation counted a knot'
    Click-Control 321
    $script:menu=[System.Windows.Automation.AutomationElement]::RootElement.FindFirst([System.Windows.Automation.TreeScope]::Children,$menuCondition)
    $morning=$script:menu.FindFirst([System.Windows.Automation.TreeScope]::Descendants,(New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::NameProperty),'Morning prayers'))
    Require ($null -ne $morning) 'Morning prayers menu item missing'
    $bounds=$morning.Current.BoundingRectangle
    [ChotkiReviewInput]::Click($bounds.Left+$bounds.Width/2,$bounds.Top+$bounds.Height/2)
    Wait-For { (Element 321).Current.Name -eq 'Morning prayers' } 'Physical grouped prayer menu mouse selection'
    'PASS: native popup accessibility, real keyboard navigation/Escape and mouse selection without counting.' | Add-Content $log
    $reader=Element 301
    Require ($null -ne $reader) 'Morning prayer reader missing'
    $readerHandle=[IntPtr]$reader.Current.NativeWindowHandle
    $readerBounds=[ChotkiReviewInput]::Bounds($readerHandle)
    $firstLine=[ChotkiReviewInput]::SendMessage($readerHandle,0x00CE,[UIntPtr]::Zero,[IntPtr]::Zero).ToInt32()
    [ChotkiReviewInput]::Click($readerBounds.Left+$readerBounds.Width/2,$readerBounds.Top+[Math]::Min(90,$readerBounds.Height/2))
    [ChotkiReviewInput]::Wheel(-120)
    [ChotkiReviewInput]::Wheel(-120)
    Wait-For { [ChotkiReviewInput]::SendMessage($readerHandle,0x00CE,[UIntPtr]::Zero,[IntPtr]::Zero).ToInt32() -gt $firstLine } 'Physical prayer mouse wheel did not scroll'
    'PASS: physical mouse wheel scrolls the morning prayer reader.' | Add-Content $log
    Click-Control 101
    Wait-For { $null -ne (Element 11000) } 'Physical Library navigation'
    Click-Control 11000
    Wait-For { $null -ne (Element 501) } 'Physical template editor route'
    'PASS: physical Library Take on opens the editor.' | Add-Content $log
    'Physical input/accessibility smoke exit: 0' | Add-Content $log
} catch {
    $_ | Out-String | Add-Content $log
    if ($script:root) {
        ('Native child IDs: '+[ChotkiReviewInput]::Children([IntPtr]$script:root.Current.NativeWindowHandle)) | Add-Content $log
        $nodes=$script:root.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
        $nodes | Select-Object -First 40 | ForEach-Object { ($_.Current.AutomationId+' | '+$_.Current.ClassName+' | '+$_.Current.Name) | Add-Content $log }
    }
    Get-Content 'C:\workspace-build\input-app.log','C:\workspace-build\input-app-error.log' -ErrorAction SilentlyContinue | Add-Content $log
    throw
} finally {
    $child=Get-CimInstance Win32_Process -Filter "ProcessId=$($app.Id)"
    if ($child -and $child.ExecutablePath -eq $exe.FullName -and $child.CommandLine -like '*--review*') { Stop-Process $app.Id -Force -ErrorAction SilentlyContinue }
    Remove-Item 'C:\workspace-build\input-review.pid' -ErrorAction SilentlyContinue
}
exit 0
