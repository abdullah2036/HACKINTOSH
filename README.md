# Ryzen 3200G Hackintosh: macOS Sequoia dual boot with Windows

An OpenCore 1.0.8 setup that boots macOS Sequoia 15.6 next to Windows 11 on an
AMD APU desktop, plus the scripts and workarounds used to get there.

This repository holds configs and scripts only. No OpenCore binaries, kexts,
Apple images or personal identifiers are included; see [What's not here](#whats-not-here).

## Hardware

| Part | Model | macOS status |
|---|---|---|
| CPU | AMD Ryzen 3 3200G (Zen+, 4 cores) | Works with AMD_Vanilla patches |
| Board | ASUS TUF B450M-PRO GAMING | Works |
| iGPU | Radeon Vega 8 (Picasso) | Accelerated with NootedRed (experimental) |
| dGPU | NVIDIA RTX 3070 | Unsupported; hidden from macOS, used by Windows |
| SSD | Kingston A2000 1 TB NVMe | Works (Windows + macOS partitions) |
| Ethernet | Realtek RTL8111H | Works with RealtekRTL8111 |
| Wi-Fi | TP-Link Archer T3U (RTL8812BU, USB `2357:012D`) | chris1111's USB driver (closed source, SIP off, menu-bar app) |

## Repository layout

```
EFI-configs/
  daily/       config.plist on the SSD (EFI\OC): release build, quiet boot, NootedRed
  safe-mode/   config.plist on the SSD (EFI\OCSAFE): no NootedRed, text picker
  usb-debug/   config.plist on the USB: DEBUG build, verbose, file logging
ACPI/          SSDT-EC-USBX (fake EC under \_SB.PCI0.SBRG + USBX), source and compiled
scripts/
  build/       amd_config.py (generates config.plist from Sample.plist), oc_snapshot.py
  windows/     esp_check.bat, boot_fix.bat, ssd_update.bat (EFI partition + boot entries)
  tools/       split_pkg.py, xar_list.py, extents.ps1, usbmap.ps1
  macos/       offline_install_from_usb.sh, install_iphone_support.sh, wifi_setup.sh
```

## Key settings

- **Kexts:** Lilu 1.7.2, VirtualSMC 1.3.8, RealtekRTL8111 3.0.x, NootedRed 0.8.10 (added manually; not included), RtWlanU + RtWlanU1827 (from [Wireless-USB-OC-Big-Sur-Adapter](https://github.com/chris1111/Wireless-USB-OC-Big-Sur-Adapter) V17; not included)
- **SIP:** fully disabled, `csr-active-config = FF0F0000`, also listed in `NVRAM > Delete` so it replaces the value already stored in NVRAM
- **Kernel patches:** [AMD_Vanilla](https://github.com/AMD-OSX/AMD_Vanilla), `cpuid_cores_per_package` set to `04`
- **Quirks:** Dortania Zen settings; `ProvideCurrentCpuInfo` and `DummyPowerManagement` on
- **SMBIOS:** MacBookPro16,3 (generate your own with GenSMBIOS; never reuse one)
- **SecureBootModel:** `Disabled` (see lesson 10)
- **RTX 3070:** hidden via DeviceProperties at `PciRoot(0x0)/Pci(0x1,0x1)/Pci(0x0,0x0)`
- **BIOS:** IGFX Multi-Monitor on, Primary Video Device = IGFX, CSM off, Above 4G on, Secure Boot off

## Lessons learned

1. **Check what macrecovery actually downloads.** The board ID / MLB pair `Mac-7BA5B2D9E42DDD94` / `00000000000J80300` is listed under High Sierra in `recovery_urls.txt`. Sequoia needs MLB `00000000000000000`.
2. **The OpenCorePkg git repo has no binaries.** `X64/EFI` and `ocvalidate` come from the release zip.
3. **An HFS+ driver is required** (`OpenHfsPlus.efi`), or OpenCore can't open the recovery DMG.
4. **`HideAuxiliary` hides `com.apple.recovery.boot` completely**, not just visually (`BootEntryManagement.c`). Press Space, or leave it off while installing.
5. **The plain "EFI" picker entry was OpenCore itself.** Picking it logged `Found previous image, aborting`. The installer entry is "EFI (dmg)".
6. **Safe file logging (`Target 67`) is very slow.** The boot looked frozen at `BootKernelExtensions.kc` but was only crawling; it continued when left alone.
7. **NootedRed moves the picture to the motherboard port** when graphics start, so a monitor left on the GPU input goes to "no signal".
8. **This recovery couldn't mount NTFS, FAT32 or exFAT.** The fix was reading raw bytes: on Windows, `FSCTL_GET_RETRIEVAL_POINTERS` gave the installer's cluster runs on the FAT32 USB. With the data-region offset, two `dd` commands copied it onto the APFS volume, checked with MD5 per block (`scripts/tools`).
9. **`installer -pkg InstallAssistant.pkg` failed in recovery,** and a manually unpacked app asked for internet. The package's only postinstall action hard-links the `.pkg` itself into the app as `SharedSupport.dmg` (the pkg is also a valid UDIF image). Recreating that link made the offline install work.
10. **Stage 2 reboot loop:** with `SecureBootModel=Default` and a T2 SMBIOS, the installer's restore phase shut down and restarted cleanly (no panic) on every boot. `SecureBootModel=Disabled` fixed it.
11. **NootedRed is mostly fine, but dynamic/Aerial wallpapers freeze it.** Use still wallpapers and Reduce Motion. A second OpenCore copy in `EFI\OCSAFE` without NootedRed has its own firmware entry for recovering from bad settings (OpenCore reads its config from the folder it was launched from, `OpenCore.c`).
12. **A firmware entry for OpenCore** was made with `bcdedit /copy {bootmgr}` then `path \EFI\OC\OpenCore.efi` (`scripts/windows/boot_fix.bat`).
13. **iPhone USB tethering needs Apple's Mobile Device update.** It's in Apple's software update catalog (product `142-23719`, three packages) and installs offline with `installer -pkg`.
14. **USB Wi-Fi does exist for Sequoia, with trade-offs.** chris1111's OpenCore package supports the Archer T3U (`RtWlanU.kext` has a `TPLink_012D_8812BU` personality), but needs SIP and Gatekeeper off and doesn't support WPA3. Its postinstall mounts the ESP, copies both kexts to `EFI/OC/Kexts` and merges them into `Kernel > Add` with PlistBuddy. It also unmounts any volume named `EFI`, so `wifi_setup.sh` copies itself off the USB before running. The kexts are also in the build folders, so `ssd_update.bat`'s mirror doesn't delete them.
15. **OpenCore won't overwrite existing NVRAM values.** The log showed `csr-active-config - ignored, exists` until the key was added to `NVRAM > Delete`.

## What's not here

- OpenCore, drivers and resources: [acidanthera/OpenCorePkg releases](https://github.com/acidanthera/OpenCorePkg/releases), [OcBinaryData](https://github.com/acidanthera/OcBinaryData)
- Kexts: [Lilu](https://github.com/acidanthera/Lilu), [VirtualSMC](https://github.com/acidanthera/VirtualSMC), [RealtekRTL8111](https://github.com/Mieze/RTL8111_driver_for_OS_X), NootedRed from its [official releases](https://github.com/ChefKissInc/NootedRed/releases) under its own license, RtWlanU from [chris1111's releases](https://github.com/chris1111/Wireless-USB-OC-Big-Sur-Adapter/releases)
- macOS recovery and installer images: download from Apple (`macrecovery.py`, `gibMacOS`)
- SMBIOS serial, MLB, UUID and ROM: replaced with placeholders; generate your own

## Credits

[Dortania OpenCore Install Guide](https://dortania.github.io/OpenCore-Install-Guide/), Acidanthera, AMD-OSX (AMD_Vanilla), Mieze, ChefKiss (NootedRed), CorpNewt (ProperTree, SSDTTime, gibMacOS, GenSMBIOS).

macOS's license permits installation only on Apple-branded hardware. This is a personal, non-commercial project shared for documentation.
