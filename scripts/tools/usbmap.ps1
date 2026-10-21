param([string]$Drive = 'D:', [string]$Dir = 'D:\macos')
# For each part file: extents (LCN, clusters). Plus the volume's retrieval-pointer base
# (sector offset of LCN 0 from the start of the partition) and cluster size.
. (Join-Path $PSScriptRoot 'extents.ps1') -Path (Join-Path $Dir 'go.sh') | Out-Null
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class VolBase {
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  static extern SafeFileHandle CreateFile(string n, uint access, uint share, IntPtr sa, uint disp, uint flags, IntPtr t);
  [DllImport("kernel32.dll", SetLastError=true)]
  static extern bool DeviceIoControl(SafeFileHandle h, uint code, IntPtr inBuf, int inSize,
                                     out long outBuf, int outSize, out int ret, IntPtr ov);
  public static long Get(string vol) {
    using (var h = CreateFile(@"\\.\" + vol, 0, 3, IntPtr.Zero, 3, 0, IntPtr.Zero)) {
      if (h.IsInvalid) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
      long b; int r;
      if (!DeviceIoControl(h, 0x00090234, IntPtr.Zero, 0, out b, 8, out r, IntPtr.Zero))
        throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
      return b;
    }
  }
}
"@
$v = Get-CimInstance Win32_Volume -Filter "DriveLetter='$Drive'"
"cluster size: $($v.BlockSize) | fs: $($v.FileSystem)"
try { "retrieval pointer base (sectors): " + [VolBase]::Get($Drive) } catch { "retrieval pointer base: FAILED - $($_.Exception.Message)" }
Get-ChildItem $Dir -Filter 'InstallAssistant.pkg.part*' | Sort-Object Name | ForEach-Object {
  $e = [Ext]::Get($_.FullName)
  "{0}: size={1} extents={2} first_lcn={3} last_lcn_end={4}" -f $_.Name, $_.Length, $e.Count, $e[0][1], ($e[-1][1] + $e[-1][2])
}
