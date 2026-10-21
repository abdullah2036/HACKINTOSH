param([string]$Path)
# Lists a file's on-disk extents (volume-relative clusters) via FSCTL_GET_RETRIEVAL_POINTERS.
Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class Ext {
  [DllImport("kernel32.dll", SetLastError=true)]
  static extern bool DeviceIoControl(SafeFileHandle h, uint code, ref long inBuf, int inSize,
                                     byte[] outBuf, int outSize, out int ret, IntPtr ov);
  public static long[][] Get(string path) {
    var list = new System.Collections.Generic.List<long[]>();
    using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite)) {
      long startVcn = 0;
      byte[] buf = new byte[1 << 16];
      while (true) {
        int ret;
        bool ok = DeviceIoControl(fs.SafeFileHandle, 0x00090073, ref startVcn, 8, buf, buf.Length, out ret, IntPtr.Zero);
        int err = Marshal.GetLastWin32Error();
        if (!ok && err != 234) throw new System.ComponentModel.Win32Exception(err);
        int count = BitConverter.ToInt32(buf, 0);
        long vcn = BitConverter.ToInt64(buf, 8);
        for (int i = 0; i < count; i++) {
          long nextVcn = BitConverter.ToInt64(buf, 16 + i * 16);
          long lcn = BitConverter.ToInt64(buf, 24 + i * 16);
          list.Add(new long[] { vcn, lcn, nextVcn - vcn });
          vcn = nextVcn;
        }
        if (ok) break;
        startVcn = vcn;
      }
    }
    return list.ToArray();
  }
}
"@
$e = [Ext]::Get($Path)
"extents: " + $e.Count
$e | Select-Object -First 20 | ForEach-Object { "vcn={0} lcn={1} clusters={2}" -f $_[0], $_[1], $_[2] }
