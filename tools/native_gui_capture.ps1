param([int]$TargetPid, [string]$OutputPath, [int]$Palette, [switch]$RequestClose, [switch]$GeometryOnly, [switch]$PrepareAssembly, [string]$NativeAssembly)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
$nativeSource = @'
using System;
using System.Runtime.InteropServices;
public class CheckerboardForm : System.Windows.Forms.Form {
 public bool Inverted;
 protected override bool ShowWithoutActivation { get { return true; } }
 protected override void OnPaint(System.Windows.Forms.PaintEventArgs e) {
  var colors = new[]{System.Drawing.Color.FromArgb(51,204,214),System.Drawing.Color.FromArgb(219,77,201)};
  for(int y=0;y<Height;y+=48) for(int x=0;x<Width;x+=48)
   using(var b=new System.Drawing.SolidBrush(colors[((x/48)+(y/48)+(Inverted?1:0))%2])) e.Graphics.FillRectangle(b,x,y,48,48);
 }
}
public class GuiProbe {
 [DllImport("user32.dll", SetLastError=true)] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
 [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int height, uint flags);
 [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint command);
 [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr h);
 [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr h, IntPtr dc);
 [DllImport("gdi32.dll")] public static extern bool BitBlt(IntPtr dest, int x, int y, int w, int h, IntPtr src, int sx, int sy, uint mode);
 public delegate bool Callback(IntPtr h, IntPtr p);
 [DllImport("user32.dll")] public static extern bool EnumWindows(Callback cb, IntPtr p);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, System.Text.StringBuilder name, int size);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
 [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr OpenInputDesktop(uint flags, bool inherit, uint access);
 [DllImport("user32.dll")] public static extern bool CloseDesktop(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr value);
 [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out Rect r);
 [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref Point p);
 public struct Point { public int X, Y; }
 public struct Rect { public int Left, Top, Right, Bottom; }
 public static IntPtr Find(uint wanted) {
  IntPtr found = IntPtr.Zero;
  EnumWindows((h,p)=> { uint id; GetWindowThreadProcessId(h,out id);
   Rect r; if(id==wanted && IsWindowVisible(h) && GetWindowRect(h,out r) && r.Right-r.Left>20 && r.Bottom-r.Top>20) {found=h;return false;} return true; },IntPtr.Zero); return found;
 }
}
'@
# Compile once BEFORE any game starts, rather than paying C# compilation inside
# every short geometry/capture/close deadline. Only the job-owned temp DLL is used.
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted' -or $env:GITHUB_REPOSITORY -ne 'lemoncat7/MountainStill') { throw 'Only disposable official repository runner helper allowed' }
if ([string]::IsNullOrWhiteSpace($NativeAssembly) -or -not [IO.Path]::IsPathRooted($NativeAssembly)) { throw 'Absolute job-owned helper assembly path required' }
$assemblyFull = [IO.Path]::GetFullPath($NativeAssembly)
$tempRoot = [IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\') + '\'
$assemblyParent = [IO.Path]::GetDirectoryName($assemblyFull)
if (-not $assemblyFull.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($assemblyFull) -ne 'capture.dll' -or -not [IO.Path]::GetFileName($assemblyParent).StartsWith('mountainstill-gui-')) { throw 'Helper DLL must be in this driver job-owned temp directory' }
$parentItem = Get-Item -LiteralPath $assemblyParent
if (($parentItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Helper parent directory cannot be a reparse point' }
if (([IO.Path]::GetDirectoryName($assemblyParent).TrimEnd('\') + '\') -ne $tempRoot) { throw 'Helper directory must be immediate child of RUNNER_TEMP' }
$NativeAssembly = $assemblyFull
if ($PrepareAssembly) {
 if (Test-Path -LiteralPath $NativeAssembly) { throw 'Refusing to overwrite a pre-existing helper assembly' }
 Add-Type -TypeDefinition $nativeSource -ReferencedAssemblies System.Windows.Forms,System.Drawing -OutputAssembly $NativeAssembly -OutputType Library
 @{status='HELPER_PREPARED';assembly_bytes=(Get-Item -LiteralPath $NativeAssembly).Length} | ConvertTo-Json -Compress
 exit 0
}
if (-not (Test-Path -LiteralPath $NativeAssembly -PathType Leaf)) { throw 'Prepared job-owned helper assembly missing' }
if (((Get-Item -LiteralPath $NativeAssembly).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Helper DLL cannot be a reparse point' }
Add-Type -Path $NativeAssembly
$board = $null
$placementAttempts = @()
try {
 # Thread-local coordinate awareness only; no OS/user display setting changed.
 $old = [GuiProbe]::SetThreadDpiAwarenessContext([IntPtr](-4))
 $desktop = [GuiProbe]::OpenInputDesktop(0,$false,1)
 if ($desktop -eq [IntPtr]::Zero) {
  @{status='ENVIRONMENT_UNAVAILABLE';reason='no_accessible_input_desktop'} | ConvertTo-Json -Compress; exit 0
 }
 [void][GuiProbe]::CloseDesktop($desktop)
 $h = [GuiProbe]::Find($TargetPid)
 if ($h -eq [IntPtr]::Zero) { @{status='CAPTURE_INCONCLUSIVE';reason='no_visible_pid_window'} | ConvertTo-Json -Compress; exit 0 }
 if ($RequestClose) {
  [uint32]$actualPid = 0
  [void][GuiProbe]::GetWindowThreadProcessId($h,[ref]$actualPid)
  if ($actualPid -ne $TargetPid -or $null -eq (Get-Process -Id $TargetPid -ErrorAction SilentlyContinue)) { throw 'Owned PID/window no longer matches' }
  $sent = [GuiProbe]::PostMessageW($h,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)
  $errorCode = if ($sent) { 0 } else { [Runtime.InteropServices.Marshal]::GetLastWin32Error() }
  @{status=$(if ($sent) {'CLOSE_REQUEST_SENT'} else {'CLOSE_REQUEST_REFUSED'});owner_pid=$TargetPid;window_id=$h.ToInt64();method='PostMessage WM_CLOSE';win32_error=$errorCode;handler_handled='unknown';request_return_does_not_prove_exit=$true;physical_mouse_test=$false} | ConvertTo-Json -Compress
  exit 0
 }
 $r = New-Object GuiProbe+Rect
 if (-not [GuiProbe]::GetWindowRect($h,[ref]$r)) { throw 'Outer geometry unavailable' }
 $client = New-Object GuiProbe+Rect
 $origin = New-Object GuiProbe+Point
 if (-not [GuiProbe]::GetClientRect($h,[ref]$client) -or -not [GuiProbe]::ClientToScreen($h,[ref]$origin)) { throw 'Client geometry unavailable' }
 $full = New-Object System.Drawing.Rectangle($origin.X,$origin.Y,($client.Right-$client.Left),($client.Bottom-$client.Top))
 $screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
 $targetScreen = [System.Windows.Forms.Screen]::FromHandle($h)
 $bounds = $targetScreen.Bounds
 $work = $targetScreen.WorkingArea
 $dpi = [GuiProbe]::GetDpiForWindow($h)
 $outer = New-Object System.Drawing.Rectangle($r.Left,$r.Top,($r.Right-$r.Left),($r.Bottom-$r.Top))
 $screens = @([System.Windows.Forms.Screen]::AllScreens | ForEach-Object { @{x=$_.Bounds.X;y=$_.Bounds.Y;width=$_.Bounds.Width;height=$_.Bounds.Height;primary=$_.Primary} })
 $metadata = @{screens=$screens;owner_pid=$TargetPid;window_id=$h.ToInt64();outer_frame=@($r.Left,$r.Top,$outer.Width,$outer.Height);client_frame=@($full.X,$full.Y,$full.Width,$full.Height);screen_frame=@($bounds.X,$bounds.Y,$bounds.Width,$bounds.Height);work_area=@($work.X,$work.Y,$work.Width,$work.Height);coordinate_units='physical_pixels';coordinate_origin='global_top_left';outer_geometry_source='GetWindowRect';client_geometry_source='GetClientRect+ClientToScreen';backing_scale=($dpi/96.0);dpi=$dpi;client_width=$full.Width;client_height=$full.Height;window_width=$outer.Width;window_height=$outer.Height;client_fully_onscreen=([System.Drawing.Rectangle]::Intersect($full,$screen) -eq $full);window_fully_onscreen=([System.Drawing.Rectangle]::Intersect($outer,$screen) -eq $outer);session_id=(Get-Process -Id $TargetPid).SessionId}
 if ($GeometryOnly) { $metadata.status='GEOMETRY_READY'; $metadata | ConvertTo-Json -Compress -Depth 5; exit 0 }
 if (-not $metadata.window_fully_onscreen) { throw 'Full target window is not onscreen' }
 $expanded = New-Object System.Drawing.Rectangle(($r.Left-16),($r.Top-16),($r.Right-$r.Left+32),($r.Bottom-$r.Top+32))
 $background = [System.Drawing.Rectangle]::Intersect($expanded,$screen)
 $area = $background
 $w = $area.Width; $height = $area.Height
 if ($w -le 0 -or $height -le 0 -or [long]$w*$height -gt 16000000) { throw 'Unsafe or empty capture dimensions' }
 $board = New-Object CheckerboardForm
 $board.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
 $board.ShowInTaskbar = $false
 $board.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
 $board.Bounds = $background
 $board.Inverted = ($Palette -eq 2)
 # Only our own board may be reordered. A changed target invalidates this sample.
 function Assert-OwnedCaptureGeometry {
  [uint32]$actualPid = 0
  [void][GuiProbe]::GetWindowThreadProcessId($h,[ref]$actualPid)
  if ($actualPid -ne $TargetPid -or $null -eq (Get-Process -Id $TargetPid -ErrorAction SilentlyContinue) -or -not [GuiProbe]::IsWindowVisible($h)) { throw 'Capture target ownership/visibility changed' }
  [uint32]$boardPid = 0
  [void][GuiProbe]::GetWindowThreadProcessId($board.Handle,[ref]$boardPid)
  if ($boardPid -ne $PID) { throw 'Backdrop ownership changed' }
  $nowOuter = New-Object GuiProbe+Rect
  $nowClient = New-Object GuiProbe+Rect
  $nowOrigin = New-Object GuiProbe+Point
  if (-not [GuiProbe]::GetWindowRect($h,[ref]$nowOuter) -or -not [GuiProbe]::GetClientRect($h,[ref]$nowClient) -or -not [GuiProbe]::ClientToScreen($h,[ref]$nowOrigin)) { throw 'Capture geometry revalidation unavailable' }
  if ($nowOuter.Left -ne $r.Left -or $nowOuter.Top -ne $r.Top -or $nowOuter.Right -ne $r.Right -or $nowOuter.Bottom -ne $r.Bottom -or $nowClient.Left -ne $client.Left -or $nowClient.Top -ne $client.Top -or $nowClient.Right -ne $client.Right -or $nowClient.Bottom -ne $client.Bottom -or $nowOrigin.X -ne $origin.X -or $nowOrigin.Y -ne $origin.Y -or [GuiProbe]::GetDpiForWindow($h) -ne $dpi) { throw 'Capture geometry changed' }
 }
 $wait = [Diagnostics.Stopwatch]::StartNew()
 $board.Show()
 $adjacent = $false
 for ($attempt=1; $attempt -le 3 -and $wait.ElapsedMilliseconds -lt 350; $attempt++) {
  Assert-OwnedCaptureGeometry
  if ($wait.ElapsedMilliseconds -ge 350) { break }
  $placed = [GuiProbe]::SetWindowPos($board.Handle,$h,$background.X,$background.Y,$background.Width,$background.Height,0x0210)
  $board.Refresh()
  $settleUntil = [Math]::Min(350,$wait.ElapsedMilliseconds+100)
  while ($wait.ElapsedMilliseconds -lt $settleUntil) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds ([Math]::Max(1,[Math]::Min(10,$settleUntil-$wait.ElapsedMilliseconds))) }
  Assert-OwnedCaptureGeometry
  $behind = [GuiProbe]::GetWindow($h,2)
  [uint32]$behindPid = 0
  [void][GuiProbe]::GetWindowThreadProcessId($behind,[ref]$behindPid)
  $className = New-Object System.Text.StringBuilder 256
  [void][GuiProbe]::GetClassNameW($behind,$className,$className.Capacity)
  $placementAttempts += @{attempt=$attempt;placed=$placed;elapsed_ms=$wait.ElapsedMilliseconds;behind_hwnd=$behind.ToInt64();behind_pid=$behindPid;behind_class=$className.ToString();behind_visible=[GuiProbe]::IsWindowVisible($behind)}
  if (-not $placed) { throw 'Backdrop placement failed' }
  if ($behind -eq $board.Handle) { $adjacent=$true; break }
 }
 $metadata.backdrop_placement_attempts = $placementAttempts
 Assert-OwnedCaptureGeometry
 if (-not $adjacent -or [GuiProbe]::GetWindow($h,2) -ne $board.Handle) { throw 'Backdrop is not directly behind target; inconclusive' }
 $bitmap = New-Object System.Drawing.Bitmap($w,$height)
 $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
 try {
  # CopyFromScreen rejects combined enum flags. Native BitBlt supports CaptureBlt.
  $source = [GuiProbe]::GetDC([IntPtr]::Zero)
  if ($source -eq [IntPtr]::Zero) { throw 'Desktop DC unavailable' }
  $dest = [IntPtr]::Zero
  try {
   $dest = $graphics.GetHdc()
   Assert-OwnedCaptureGeometry
   if ([GuiProbe]::GetWindow($h,2) -ne $board.Handle) { throw 'Backdrop adjacency lost before BitBlt; inconclusive' }
   if (-not [GuiProbe]::BitBlt($dest,0,0,$w,$height,$source,$area.X,$area.Y,0x40CC0020)) { throw 'Composited desktop BitBlt failed' }
  } finally {
   if ($dest -ne [IntPtr]::Zero) { $graphics.ReleaseHdc($dest) }
   [void][GuiProbe]::ReleaseDC([IntPtr]::Zero,$source)
  }
  $bitmap.Save($OutputPath,[System.Drawing.Imaging.ImageFormat]::Png)
 } finally { $graphics.Dispose(); $bitmap.Dispose() }
 $metadata.status='CAPTURE_READY'
 $captureMetadata = @{backdrop_id=$board.Handle.ToInt64();directly_behind_target=$true;palette=$Palette;colors=@('#33CCD6','#DB4DC9');checker_pixels=48;backdrop_frame=@($background.X,$background.Y,$background.Width,$background.Height);crop_frame=@($area.X,$area.Y,$area.Width,$area.Height);top_control_pixels=[Math]::Max(0,$r.Top-$area.Top);bottom_control_pixels=[Math]::Max(0,$area.Bottom-$r.Bottom);left_control_pixels=[Math]::Max(0,$r.Left-$area.Left);right_control_pixels=[Math]::Max(0,$area.Right-$r.Right);pixel_width=$w;pixel_height=$height;capture='composited desktop full target window native pixels plus available 16px checkerboard controls; no scaling'}
 foreach ($key in $captureMetadata.Keys) { $metadata[$key] = $captureMetadata[$key] }
 $metadata | ConvertTo-Json -Compress -Depth 5
} catch { @{status='CAPTURE_INCONCLUSIVE';reason=$_.Exception.Message;backdrop_placement_attempts=$placementAttempts} | ConvertTo-Json -Compress -Depth 5 } finally { if ($null -ne $board) { $board.Close(); $board.Dispose() }; if ($null -ne $old -and $old -ne [IntPtr]::Zero) { [void][GuiProbe]::SetThreadDpiAwarenessContext($old) } }
