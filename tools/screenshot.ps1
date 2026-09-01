# Capture the live window by copying from the screen: PrintWindow returns white
# for a D3D12 swapchain (the swapchain never renders into the GDI DC).
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public class Win {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  public struct Rect { public int Left, Top, Right, Bottom; }
}
"@
$p = Get-Process vf5 -ErrorAction SilentlyContinue
if (-not $p) { Write-Host "no process"; exit 1 }
$h = $p.MainWindowHandle
if ($h -eq 0) { Write-Host "no window handle"; exit 1 }
[Win]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 700
$r = New-Object Win+Rect
[Win]::GetWindowRect($h, [ref]$r) | Out-Null
$w = $r.Right - $r.Left; $ht = $r.Bottom - $r.Top
Write-Host "window ${w}x${ht} at ($($r.Left),$($r.Top))"
$bmp = New-Object System.Drawing.Bitmap $w, $ht
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size($w, $ht)))
$out = $args[0]; if (-not $out) { $out = "screen.png" }
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "saved $out"
$g.Dispose(); $bmp.Dispose()
