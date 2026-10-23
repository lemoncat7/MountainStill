param(
 [ValidateSet('Prepare','Inspect','Key','Click','Capture')][string]$Action,
 [string]$NativeAssembly, [int]$TargetPid, [long]$WindowId,
 [ValidateSet('Space','I','Esc','G')][string]$Key,
 [int]$ClientX=-1, [int]$ClientY=-1,
 [int]$RoiX=-1, [int]$RoiY=-1, [int]$RoiWidth=0, [int]$RoiHeight=0,
 [string]$OutputPath
)
$ErrorActionPreference='Stop'
$old=[IntPtr]::Zero
try {
 if ($env:OS -ne 'Windows_NT' -or $env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted' -or $env:GITHUB_REPOSITORY -ne 'lemoncat7/MountainStill') { throw 'Only disposable official Windows repository runner allowed' }
 if ([string]::IsNullOrWhiteSpace($Action)) { throw 'Action required' }
 if ([string]::IsNullOrWhiteSpace($NativeAssembly) -or -not [IO.Path]::IsPathRooted($NativeAssembly) -or [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { throw 'Absolute owned helper assembly path required' }
 $assemblyFull=[IO.Path]::GetFullPath($NativeAssembly)
 $tempRoot=[IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\')+'\'
 $parent=[IO.Path]::GetDirectoryName($assemblyFull)
 if (-not $assemblyFull.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($assemblyFull) -ne 'input.dll' -or -not [IO.Path]::GetFileName($parent).StartsWith('mountainstill-input-') -or ([IO.Path]::GetDirectoryName($parent).TrimEnd('\')+'\') -ne $tempRoot) { throw 'Helper must be input.dll in immediate job-owned mountainstill-input-* directory' }
 if (((Get-Item -LiteralPath $parent).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Reparse parent refused' }
 Add-Type -AssemblyName System.Drawing
 Add-Type -AssemblyName System.Windows.Forms
 $nativeSource=@'
using System;
using System.Runtime.InteropServices;
public static class NativeInputProbe {
 public struct Point { public int X,Y; }
 public struct Rect { public int Left,Top,Right,Bottom; }
 [StructLayout(LayoutKind.Sequential)] public struct Mouse { public int dx,dy; public uint data,flags,time; public UIntPtr extra; }
 [StructLayout(LayoutKind.Sequential)] public struct Keyboard { public ushort vk,scan; public uint flags,time; public UIntPtr extra; }
 [StructLayout(LayoutKind.Explicit)] public struct Union { [FieldOffset(0)] public Mouse mouse; [FieldOffset(0)] public Keyboard key; }
 [StructLayout(LayoutKind.Sequential)] public struct Input { public uint type; public Union data; }
 public delegate bool Callback(IntPtr h,IntPtr p);
 [DllImport("user32.dll")] public static extern bool EnumWindows(Callback cb,IntPtr p);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out Rect r);
 [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h,out Rect r);
 [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h,ref Point p);
 [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr v);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] static extern short GetAsyncKeyState(int key);
 [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point p);
 [DllImport("user32.dll")] static extern IntPtr GetAncestor(IntPtr h,uint flag);
 [DllImport("user32.dll")] static extern int GetSystemMetrics(int index);
 [DllImport("user32.dll",SetLastError=true)] static extern uint SendInput(uint n,Input[] inputs,int size);
 [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr h);
 [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr h,IntPtr dc);
 [DllImport("gdi32.dll")] public static extern bool BitBlt(IntPtr dst,int x,int y,int w,int height,IntPtr src,int sx,int sy,uint mode);
 public static bool Owns(IntPtr h,uint pid) { uint actual; GetWindowThreadProcessId(h,out actual); return h!=IntPtr.Zero && actual==pid && IsWindowVisible(h) && !IsIconic(h); }
 public static IntPtr Find(uint pid) {
  IntPtr found=IntPtr.Zero; int count=0;
  EnumWindows((h,p)=> { Rect r; if(Owns(h,pid) && GetClientRect(h,out r) && r.Right-r.Left>20 && r.Bottom-r.Top>20) { found=h; count++; } return true; },IntPtr.Zero);
  if(count!=1) throw new Exception("Expected exactly one visible target PID window"); return found;
 }
 public static void Geometry(IntPtr h,uint pid) {
  Rect r; if(!Owns(h,pid) || !GetClientRect(h,out r) || r.Right-r.Left!=960 || r.Bottom-r.Top!=540 || GetDpiForWindow(h)!=96) throw new Exception("Owned visible 960x540 client at exactly 96 DPI required");
 }
 public static void IdleInput() {
  // Never release keys/buttons held by another actor; refuse instead.
  foreach(int key in new[]{0x10,0x11,0x12,0x5B,0x5C,0x01,0x02,0x04,0x05,0x06})
   if((GetAsyncKeyState(key)&0x8000)!=0) throw new Exception("Modifier or mouse button already down");
 }
 static void Foreground(IntPtr h,uint pid) {
  Geometry(h,pid); IdleInput();
  if(GetForegroundWindow()!=h && !SetForegroundWindow(h)) throw new Exception("Ordinary foreground request refused; no workaround attempted");
  if(GetForegroundWindow()!=h || !Owns(GetForegroundWindow(),pid)) throw new Exception("Target foreground ownership unconfirmed");
 }
 static uint Submit(IntPtr h,uint pid,Input[] inputs) {
  // Last check immediately before the single down/up packet; no retry/release workaround.
  Geometry(h,pid); IdleInput();
  if(GetForegroundWindow()!=h || !Owns(GetForegroundWindow(),pid)) throw new Exception("Foreground changed before input");
  uint n=SendInput((uint)inputs.Length,inputs,Marshal.SizeOf(typeof(Input)));
  if(n!=inputs.Length) throw new Exception("Partial/refused SendInput: "+n+"/"+inputs.Length+"; abort, input state may be uncertain"); return n;
 }
 public static uint Key(IntPtr h,uint pid,string action) {
  ushort vk; switch(action) { case "Space":vk=0x20;break;case "I":vk=0x49;break;case "Esc":vk=0x1B;break;case "G":vk=0x47;break;default:throw new Exception("Key not allowlisted"); }
  Foreground(h,pid);
  if((GetAsyncKeyState(vk)&0x8000)!=0) throw new Exception("Requested key already down");
  Input down=new Input();down.type=1;down.data.key.vk=vk;
  Input up=down;up.data.key.flags=2;
  return Submit(h,pid,new[]{down,up});
 }
 public static uint Click(IntPtr h,uint pid,int x,int y) {
  if(x<0||y<0||x>=960||y>=540) throw new Exception("Click outside client");
  Foreground(h,pid);
  Point p=new Point();if(!ClientToScreen(h,ref p))throw new Exception("Client origin unavailable");p.X+=x;p.Y+=y;
  IntPtr hit=WindowFromPoint(p),root=GetAncestor(hit,2);uint owner;GetWindowThreadProcessId(hit,out owner);
  if(root!=h || owner!=pid || !Owns(root,pid)) throw new Exception("Click point does not belong to exact target window");
  int vx=GetSystemMetrics(76),vy=GetSystemMetrics(77),vw=GetSystemMetrics(78),vh=GetSystemMetrics(79);
  if(vw<=1||vh<=1||p.X<vx||p.Y<vy||p.X>=vx+vw||p.Y>=vy+vh)throw new Exception("Click point outside desktop");
  Input move=new Input();move.data.mouse.dx=(int)Math.Floor((p.X-vx+0.5)*65536.0/vw);move.data.mouse.dy=(int)Math.Floor((p.Y-vy+0.5)*65536.0/vh);move.data.mouse.flags=0xC001;
  Input down=new Input();down.data.mouse.flags=2;Input up=new Input();up.data.mouse.flags=4;
  return Submit(h,pid,new[]{move,down,up});
 }
}
'@
 if ($Action -eq 'Prepare') {
  if (Test-Path -LiteralPath $assemblyFull) { throw 'Refusing pre-existing helper assembly' }
  Add-Type -TypeDefinition $nativeSource -OutputAssembly $assemblyFull -OutputType Library
  @{status='HELPER_PREPARED';assembly_bytes=(Get-Item -LiteralPath $assemblyFull).Length} | ConvertTo-Json -Compress; exit 0
 }
 if (-not (Test-Path -LiteralPath $assemblyFull -PathType Leaf) -or ((Get-Item -LiteralPath $assemblyFull).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Prepared non-reparse assembly required' }
 Add-Type -Path $assemblyFull
 $old=[NativeInputProbe]::SetThreadDpiAwarenessContext([IntPtr](-4))
 if ($old -eq [IntPtr]::Zero) { throw 'Physical coordinate DPI context unavailable' }
 if ($TargetPid -le 0 -or $null -eq (Get-Process -Id $TargetPid -ErrorAction SilentlyContinue)) { throw 'Live owned target PID required' }
 if ($Action -eq 'Inspect') { $h=[NativeInputProbe]::Find($TargetPid) } else { if ($WindowId -eq 0) { throw 'Inspected WindowId required' }; $h=[IntPtr]$WindowId }
 [NativeInputProbe]::Geometry($h,$TargetPid)
 $outer=New-Object NativeInputProbe+Rect; $client=New-Object NativeInputProbe+Rect; $origin=New-Object NativeInputProbe+Point
 if (-not [NativeInputProbe]::GetWindowRect($h,[ref]$outer) -or -not [NativeInputProbe]::GetClientRect($h,[ref]$client) -or -not [NativeInputProbe]::ClientToScreen($h,[ref]$origin)) { throw 'Native geometry unavailable' }
 $result=@{status='INSPECT_READY';action=$Action;owner_pid=$TargetPid;window_id=$h.ToInt64();client_frame=@($origin.X,$origin.Y,960,540);client_to_screen=@($origin.X,$origin.Y);outer_frame=@($outer.Left,$outer.Top,($outer.Right-$outer.Left),($outer.Bottom-$outer.Top));dpi=96;coordinate_units='physical_pixels';foreground_owned=([NativeInputProbe]::GetForegroundWindow() -eq $h);input_delivery_does_not_prove_callback=$true}
 if ($Action -eq 'Key') { $result.sent_events=[NativeInputProbe]::Key($h,$TargetPid,$Key); $result.status='INPUT_SENT'; $result.key=$Key }
 if ($Action -eq 'Click') { $result.sent_events=[NativeInputProbe]::Click($h,$TargetPid,$ClientX,$ClientY); $result.status='INPUT_SENT'; $result.click_client=@($ClientX,$ClientY) }
 if ($Action -eq 'Capture') {
  if ($RoiX -lt 0 -or $RoiY -lt 0 -or $RoiWidth -le 0 -or $RoiHeight -le 0 -or ([long]$RoiX+$RoiWidth) -gt 960 -or ([long]$RoiY+$RoiHeight) -gt 540) { throw 'Explicit ROI strictly within client required' }
  if ([string]::IsNullOrWhiteSpace($OutputPath) -or -not [IO.Path]::IsPathRooted($OutputPath)) { throw 'Absolute owned PNG output required' }
  $outputFull=[IO.Path]::GetFullPath($OutputPath)
  if ([IO.Path]::GetDirectoryName($outputFull) -ne $parent -or [IO.Path]::GetExtension($outputFull) -ne '.png' -or (Test-Path -LiteralPath $outputFull)) { throw 'New PNG in same owned directory required' }
  if ([NativeInputProbe]::GetForegroundWindow() -ne $h) { throw 'Target must remain foreground for capture' }
  $area=New-Object System.Drawing.Rectangle(($origin.X+$RoiX),($origin.Y+$RoiY),$RoiWidth,$RoiHeight)
  $bounds=[System.Windows.Forms.Screen]::FromHandle($h).Bounds
  if (-not $bounds.Contains($area)) { throw 'Full ROI must be on target screen' }
  $bitmap=New-Object System.Drawing.Bitmap($RoiWidth,$RoiHeight)
  $graphics=[System.Drawing.Graphics]::FromImage($bitmap)
  $source=[IntPtr]::Zero; $dest=[IntPtr]::Zero
  try {
   [NativeInputProbe]::Geometry($h,$TargetPid)
   $checkOrigin=New-Object NativeInputProbe+Point
   if (-not [NativeInputProbe]::ClientToScreen($h,[ref]$checkOrigin) -or $checkOrigin.X -ne $origin.X -or $checkOrigin.Y -ne $origin.Y -or [NativeInputProbe]::GetForegroundWindow() -ne $h) { throw 'Target geometry or foreground changed before capture' }
   $source=[NativeInputProbe]::GetDC([IntPtr]::Zero);if($source -eq [IntPtr]::Zero){throw 'Desktop DC unavailable'}
   $dest=$graphics.GetHdc()
   if (-not [NativeInputProbe]::BitBlt($dest,0,0,$RoiWidth,$RoiHeight,$source,$area.X,$area.Y,0x40CC0020)) { throw 'Native desktop capture failed' }
   $graphics.ReleaseHdc($dest);$dest=[IntPtr]::Zero
   $bitmap.Save($outputFull,[System.Drawing.Imaging.ImageFormat]::Png)
  } finally { if($dest -ne [IntPtr]::Zero){$graphics.ReleaseHdc($dest)};if($source -ne [IntPtr]::Zero){[void][NativeInputProbe]::ReleaseDC([IntPtr]::Zero,$source)};$graphics.Dispose();$bitmap.Dispose() }
  $result.status='CAPTURE_READY';$result.roi_client=@($RoiX,$RoiY,$RoiWidth,$RoiHeight);$result.roi_screen=@($area.X,$area.Y,$area.Width,$area.Height);$result.pixel_width=$RoiWidth;$result.pixel_height=$RoiHeight;$result.capture='native desktop target ROI; no backdrop, resize, or scaling'
 }
 $result.foreground_owned=([NativeInputProbe]::GetForegroundWindow() -eq $h)
 $result | ConvertTo-Json -Compress -Depth 5
} catch { @{status='INPUT_UNAVAILABLE';action=$Action;reason=$_.Exception.Message;retry_allowed=$false} | ConvertTo-Json -Compress -Depth 5 } finally { if ($old -ne [IntPtr]::Zero) { [void][NativeInputProbe]::SetThreadDpiAwarenessContext($old) } }
