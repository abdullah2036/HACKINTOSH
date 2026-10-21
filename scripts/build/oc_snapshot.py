#!/usr/bin/env python3
"""Headless OpenCore snapshot (clean), equivalent to ProperTree's OC Snapshot.

Rebuilds ACPI->Add, Kernel->Add, Misc->Tools and UEFI->Drivers in config.plist
from the files actually present in the EFI/OC folder. Kexts are ordered so that
dependencies (e.g. Lilu) load before the kexts that link against them.

Usage: python oc_snapshot.py EFI/OC
"""
import os
import plistlib
import sys


def kext_entries(kexts_dir):
    infos = {}
    for root, dirs, _ in os.walk(kexts_dir):
        for d in sorted(dirs):
            if not d.lower().endswith(".kext"):
                continue
            full = os.path.join(root, d)
            rel = os.path.relpath(full, kexts_dir).replace(os.sep, "/")
            info_path = os.path.join(full, "Contents", "Info.plist")
            if not os.path.isfile(info_path):
                continue
            with open(info_path, "rb") as f:
                info = plistlib.load(f)
            exe = info.get("CFBundleExecutable")
            exe_path = "Contents/MacOS/" + exe if exe and os.path.isfile(os.path.join(full, "Contents", "MacOS", exe)) else ""
            infos[rel] = {
                "id": info.get("CFBundleIdentifier", ""),
                "libs": list(info.get("OSBundleLibraries", {}).keys()),
                "exe": exe_path,
            }

    # Topological order: a kext comes after any kext in the folder it depends on.
    by_id = {v["id"]: k for k, v in infos.items()}
    ordered, seen = [], set()

    def visit(rel):
        if rel in seen:
            return
        seen.add(rel)
        for lib in infos[rel]["libs"]:
            if lib in by_id:
                visit(by_id[lib])
        # Plugins nested in a kext load after their parent.
        parent = rel.rsplit("/Contents/PlugIns/", 1)[0] if "/Contents/PlugIns/" in rel else None
        if parent in infos:
            visit(parent)
        ordered.append(rel)

    for rel in sorted(infos, key=lambda r: (r.count("/"), r.lower())):
        visit(rel)

    return [{
        "Arch": "Any",
        "BundlePath": rel,
        "Comment": "",
        "Enabled": True,
        "ExecutablePath": infos[rel]["exe"],
        "MaxKernel": "",
        "MinKernel": "",
        "PlistPath": "Contents/Info.plist",
    } for rel in ordered]


def files_with_ext(folder, ext):
    if not os.path.isdir(folder):
        return []
    out = []
    for root, _, files in os.walk(folder):
        for f in files:
            if f.lower().endswith(ext) and not f.startswith("."):
                out.append(os.path.relpath(os.path.join(root, f), folder).replace(os.sep, "/"))
    return sorted(out, key=str.lower)


def main():
    oc = sys.argv[1]
    cfg_path = os.path.join(oc, "config.plist")
    with open(cfg_path, "rb") as f:
        cfg = plistlib.load(f)

    cfg["ACPI"]["Add"] = [{"Comment": "", "Enabled": True, "Path": p}
                          for p in files_with_ext(os.path.join(oc, "ACPI"), ".aml")]

    cfg["Kernel"]["Add"] = kext_entries(os.path.join(oc, "Kexts"))

    cfg["Misc"]["Tools"] = [{
        "Arguments": "", "Auxiliary": True, "Comment": "", "Enabled": True,
        "Flavour": "Auto", "FullNvramAccess": False, "Name": os.path.splitext(os.path.basename(p))[0],
        "Path": p, "RealPath": False, "TextMode": False,
    } for p in files_with_ext(os.path.join(oc, "Tools"), ".efi")]

    cfg["UEFI"]["Drivers"] = [{
        "Arguments": "", "Comment": "", "Enabled": True, "HideVerbose": False, "LoadEarly": False, "Path": p,
    } for p in files_with_ext(os.path.join(oc, "Drivers"), ".efi")]

    with open(cfg_path, "wb") as f:
        plistlib.dump(cfg, f, sort_keys=False)

    print("Kernel->Add:", [k["BundlePath"] for k in cfg["Kernel"]["Add"]])
    print("UEFI->Drivers:", [d["Path"] for d in cfg["UEFI"]["Drivers"]])
    print("ACPI->Add:", [a["Path"] for a in cfg["ACPI"]["Add"]])
    print("Misc->Tools:", [t["Path"] for t in cfg["Misc"]["Tools"]])


if __name__ == "__main__":
    main()
