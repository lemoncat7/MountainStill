param([int]$TargetPid, [string]$OutputPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class GuiProbe {
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
 public struct Rect { public int Left, Top, Right, Bottom; }
 public static IntPtr Find(uint wanted) {
  IntPtr found = IntPtr.Zero;
  EnumWindows((h,p)=> { uint id; GetWindowThreadProcessId(h,out id);
   Rect r; if(id==wanted && IsWindowVisible(h) && GetWindowRect(h,out r) && r.Right-r.Left>20 && r.Bottom-r.Top>20) {found=h;return false;} return true; },IntPtr.Zero); return found;
 }
}
'@
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
 $w = [Math]::Min(720,$r.Right-$r.Left); $height = [Math]::Min(480,$r.Bottom-$r.Top)
 $bitmap = New-Object System.Drawing.Bitmap($w,$height)
 $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
 try {
  # CopyFromScreen rejects combined enum flags. Native BitBlt supports CaptureBlt.
  $source = [GuiProbe]::GetDC([IntPtr]::Zero)
  if ($source -eq [IntPtr]::Zero) { throw 'Desktop DC unavailable' }
  $dest = [IntPtr]::Zero
  try {
   $dest = $graphics.GetHdc()
   if (-not [GuiProbe]::BitBlt($dest,0,0,$w,$height,$source,$r.Left,$r.Top,0x40CC0020)) { throw 'Composited desktop BitBlt failed' }
  } finally {
   if ($dest -ne [IntPtr]::Zero) { $graphics.ReleaseHdc($dest) }
   [void][GuiProbe]::ReleaseDC([IntPtr]::Zero,$source)
  }
  $bitmap.Save($OutputPath,[System.Drawing.Imaging.ImageFormat]::Png)
 } finally { $graphics.Dispose(); $bitmap.Dispose() }
 $screens = @([System.Windows.Forms.Screen]::AllScreens | ForEach-Object { @{x=$_.Bounds.X;y=$_.Bounds.Y;width=$_.Bounds.Width;height=$_.Bounds.Height;primary=$_.Primary} })
 @{status='CAPTURE_READY';screens=$screens;window_width=($r.Right-$r.Left);window_height=($r.Bottom-$r.Top);dpi=[GuiProbe]::GetDpiForWindow($h);pixel_width=$w;pixel_height=$height;session_id=(Get-Process -Id $TargetPid).SessionId;capture='composited desktop native-pixel top-left application crop'} | ConvertTo-Json -Compress
} catch { @{status='CAPTURE_INCONCLUSIVE';reason=$_.Exception.Message} | ConvertTo-Json -Compress }
