param([int]$TargetPid, [string]$OutputPath, [int]$Palette)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing @'
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
 [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int height, uint flags);
 [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint command);
 [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr h);
 [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr h, IntPtr dc);
 [DllImport("gdi32.dll")] public static extern bool BitBlt(IntPtr dest, int x, int y, int w, int h, IntPtr src, int sx, int sy, uint mode);
 public delegate bool Callback(IntPtr h, IntPtr p);
 [DllImport("user32.dll")] public static extern bool EnumWindows(Callback cb, IntPtr p);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
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
$board = $null
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
 $r = New-Object GuiProbe+Rect
 [void][GuiProbe]::GetWindowRect($h,[ref]$r)
 $client = New-Object GuiProbe+Rect
 $origin = New-Object GuiProbe+Point
 if (-not [GuiProbe]::GetClientRect($h,[ref]$client) -or -not [GuiProbe]::ClientToScreen($h,[ref]$origin)) { throw 'Client geometry unavailable' }
 $full = New-Object System.Drawing.Rectangle($origin.X,$origin.Y,($client.Right-$client.Left),($client.Bottom-$client.Top))
 $screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
 $expanded = New-Object System.Drawing.Rectangle(($r.Left-16),($r.Top-16),($r.Right-$r.Left+32),($r.Bottom-$r.Top+32))
 $background = [System.Drawing.Rectangle]::Intersect($expanded,$screen)
 $board = New-Object CheckerboardForm
 $board.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
 $board.ShowInTaskbar = $false
 $board.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
 $board.Bounds = $background
 $board.Inverted = ($Palette -eq 2)
 $board.Show()
 if (-not [GuiProbe]::SetWindowPos($board.Handle,$h,$background.X,$background.Y,$background.Width,$background.Height,0x0210)) { throw 'Backdrop placement failed' }
 $board.Refresh()
 $wait = [Diagnostics.Stopwatch]::StartNew()
 while ($wait.ElapsedMilliseconds -lt 350) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 20 }
 $behind = [GuiProbe]::GetWindow($h,2)
 if ($behind -ne $board.Handle) { throw 'Backdrop is not directly behind target; inconclusive' }
 $cropWidth = [Math]::Min(720,$background.Width)
 $area = New-Object System.Drawing.Rectangle(($background.X+[int](($background.Width-$cropWidth)/2)),$background.Y,$cropWidth,$background.Height)
 $w = $area.Width; $height = $area.Height
 if ($w -le 0 -or $height -le 0 -or $w*$height -gt 16000000) { throw 'Unsafe or empty capture dimensions' }
 $bitmap = New-Object System.Drawing.Bitmap($w,$height)
 $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
 try {
  # CopyFromScreen rejects combined enum flags. Native BitBlt supports CaptureBlt.
  $source = [GuiProbe]::GetDC([IntPtr]::Zero)
  if ($source -eq [IntPtr]::Zero) { throw 'Desktop DC unavailable' }
  $dest = [IntPtr]::Zero
  try {
   $dest = $graphics.GetHdc()
   if (-not [GuiProbe]::BitBlt($dest,0,0,$w,$height,$source,$area.X,$area.Y,0x40CC0020)) { throw 'Composited desktop BitBlt failed' }
  } finally {
   if ($dest -ne [IntPtr]::Zero) { $graphics.ReleaseHdc($dest) }
   [void][GuiProbe]::ReleaseDC([IntPtr]::Zero,$source)
  }
  $bitmap.Save($OutputPath,[System.Drawing.Imaging.ImageFormat]::Png)
 } finally { $graphics.Dispose(); $bitmap.Dispose() }
 $screens = @([System.Windows.Forms.Screen]::AllScreens | ForEach-Object { @{x=$_.Bounds.X;y=$_.Bounds.Y;width=$_.Bounds.Width;height=$_.Bounds.Height;primary=$_.Primary} })
 @{status='CAPTURE_READY';screens=$screens;owner_pid=$TargetPid;window_id=$h.ToInt64();backdrop_id=$board.Handle.ToInt64();directly_behind_target=$true;palette=$Palette;colors=@('#33CCD6','#DB4DC9');checker_pixels=48;backdrop_frame=@($background.X,$background.Y,$background.Width,$background.Height);crop_frame=@($area.X,$area.Y,$area.Width,$area.Height);top_control_pixels=[Math]::Max(0,$r.Top-$area.Top);bottom_control_pixels=[Math]::Max(0,$area.Bottom-$r.Bottom);client_width=$full.Width;client_height=$full.Height;client_fully_onscreen=([System.Drawing.Rectangle]::Intersect($full,$screen) -eq $full);window_width=($r.Right-$r.Left);window_height=($r.Bottom-$r.Top);dpi=[GuiProbe]::GetDpiForWindow($h);pixel_width=$w;pixel_height=$height;session_id=(Get-Process -Id $TargetPid).SessionId;capture='composited desktop center native pixels full vertical scene plus available checkerboard control strips'} | ConvertTo-Json -Compress
} catch { @{status='CAPTURE_INCONCLUSIVE';reason=$_.Exception.Message} | ConvertTo-Json -Compress } finally { if ($null -ne $board) { $board.Close(); $board.Dispose() } }
