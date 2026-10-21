#!/usr/bin/env python3
"""Build config.plist for Ryzen 3 3200G / ASUS TUF B450M-PRO GAMING (macOS Sequoia).

Starts from OpenCore's Sample.plist and applies the Dortania AMD Zen settings,
AMD_Vanilla kernel patches (core count 4), the fake EC SSDT, and a property
spoof that keeps macOS away from the unsupported RTX 3070.
Kexts/drivers/SSDTs themselves are linked afterwards by oc_snapshot.py.

Usage: python amd_config.py Sample.plist patches.plist smbios.txt EFI/OC/config.plist
"""
import plistlib
import sys

CORE_COUNT = 4
RTX3070_PATH = "PciRoot(0x0)/Pci(0x1,0x1)/Pci(0x0,0x0)"


def set_keys(d, values, where):
    for k, v in values.items():
        if k not in d:
            sys.exit(f"Unknown key {where}->{k} for this OpenCore version")
        d[k] = v


def main():
    sample_path, patches_path, smbios_path, out_path = sys.argv[1:5]
    with open(sample_path, "rb") as f:
        cfg = plistlib.load(f)
    with open(patches_path, "rb") as f:
        amd_patches = plistlib.load(f)["Kernel"]["Patch"]
    smbios = dict(line.strip().split("=", 1) for line in open(smbios_path) if "=" in line)

    # ACPI: only our own SSDT (added by snapshot); drop all sample patches.
    cfg["ACPI"]["Delete"] = []
    cfg["ACPI"]["Patch"] = []
    for k in cfg["ACPI"]["Quirks"]:
        cfg["ACPI"]["Quirks"][k] = False

    # Booter (Dortania Zen).
    cfg["Booter"]["MmioWhitelist"] = []
    cfg["Booter"]["Patch"] = []
    set_keys(cfg["Booter"]["Quirks"], {
        "AvoidRuntimeDefrag": True,
        "DevirtualiseMmio": False,
        "EnableSafeModeSlide": True,
        "EnableWriteUnprotector": False,
        "ProvideCustomSlide": True,
        "RebuildAppleMemoryMap": True,
        "SetupVirtualMap": True,
        "SyncRuntimePermissions": True,
        "ResizeAppleGpuBars": -1,
    }, "Booter->Quirks")

    # DeviceProperties: no Intel sample entries; hide the RTX 3070 from macOS
    # (no driver exists for it) so it cannot interfere with the iGPU.
    cfg["DeviceProperties"]["Delete"] = {}
    cfg["DeviceProperties"]["Add"] = {
        RTX3070_PATH: {
            "name": b"#display\x00",
            "IOName": "#display",
            "class-code": bytes.fromhex("FFFFFFFF"),
            "vendor-id": bytes.fromhex("FFFF0000"),
            "device-id": bytes.fromhex("FFFF0000"),
        },
    }

    # Kernel.
    cfg["Kernel"]["Block"] = []
    cfg["Kernel"]["Force"] = []
    set_keys(cfg["Kernel"]["Emulate"], {"DummyPowerManagement": True}, "Kernel->Emulate")
    for p in amd_patches:
        if "cpuid_cores_per_package" in p["Comment"]:
            r = bytearray(p["Replace"])
            r[1] = CORE_COUNT
            p["Replace"] = bytes(r)
    cfg["Kernel"]["Patch"] = amd_patches
    set_keys(cfg["Kernel"]["Quirks"], {
        "AppleCpuPmCfgLock": False,
        "AppleXcpmCfgLock": False,
        "AppleXcpmExtraMsrs": False,
        "CustomSMBIOSGuid": False,
        "DisableIoMapper": False,
        "DisableLinkeditJettison": True,
        "LapicKernelPanic": False,
        "PanicNoKextDump": True,
        "PowerTimeoutKernelPanic": True,
        "ProvideCurrentCpuInfo": True,
        "XhciPortLimit": False,
    }, "Kernel->Quirks")

    # Misc.
    set_keys(cfg["Misc"]["Boot"], {
        # Must stay False: with it on, OpenCore never scans com.apple.recovery.boot.
        "HideAuxiliary": False,
        "PickerMode": "External",
        "ShowPicker": True,
        "Timeout": 5,
    }, "Misc->Boot")
    set_keys(cfg["Misc"]["Debug"], {
        "AppleDebug": True,
        "ApplePanic": True,
        "DisableWatchDog": True,
    }, "Misc->Debug")
    set_keys(cfg["Misc"]["Security"], {
        "AllowSetDefault": True,
        "BlacklistAppleUpdate": True,
        "ScanPolicy": 0,
        # Disabled: with a T2 model the installer's restore phase reboot-looped here.
        "SecureBootModel": "Disabled",
        "Vault": "Optional",
    }, "Misc->Security")
    cfg["Misc"]["Entries"] = []

    # NVRAM: verbose boot while installing.
    apple_nvram = cfg["NVRAM"]["Add"]["7C436110-AB2A-4BBB-A880-FE41995C9F82"]
    apple_nvram["boot-args"] = "-v keepsyms=1 debug=0x100"
    apple_nvram["prev-lang:kbd"] = b"en-US:0"
    # SIP fully disabled (needed by the USB Wi-Fi driver); listed in Delete so it overrides NVRAM.
    apple_nvram["csr-active-config"] = bytes.fromhex("FF0F0000")
    apple_delete = cfg["NVRAM"]["Delete"]["7C436110-AB2A-4BBB-A880-FE41995C9F82"]
    if "csr-active-config" not in apple_delete:
        apple_delete.append("csr-active-config")

    # PlatformInfo.
    set_keys(cfg["PlatformInfo"]["Generic"], {
        "SystemProductName": "MacBookPro16,3",
        "SystemSerialNumber": smbios["serial"],
        "MLB": smbios["mlb"],
        "SystemUUID": smbios["uuid"],
        "ROM": bytes.fromhex(smbios["rom"]),
    }, "PlatformInfo->Generic")
    set_keys(cfg["PlatformInfo"], {"UpdateSMBIOSMode": "Create", "Automatic": True}, "PlatformInfo")

    # UEFI.
    set_keys(cfg["UEFI"]["Quirks"], {
        "ReleaseUsbOwnership": False,
        "RequestBootVarRouting": True,
        "UnblockFsConnect": False,
        "ResizeGpuBars": -1,
    }, "UEFI->Quirks")
    set_keys(cfg["UEFI"]["Output"], {"ProvideConsoleGop": True}, "UEFI->Output")

    with open(out_path, "wb") as f:
        plistlib.dump(cfg, f, sort_keys=False)
    print("Wrote", out_path)


if __name__ == "__main__":
    main()
