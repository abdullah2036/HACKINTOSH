"""List entries of a xar archive (.pkg) and optionally dump one entry's raw data.

Usage: python xar_list.py <pkg> [entry_name out_path]
"""
import struct
import sys
import zlib
import xml.etree.ElementTree as ET

pkg = sys.argv[1]
with open(pkg, "rb") as f:
    magic, hsize, ver, toc_c, toc_u, ck = struct.unpack(">4sHHQQI", f.read(28))
    assert magic == b"xar!", magic
    f.seek(hsize)
    toc = zlib.decompress(f.read(toc_c))
    heap = hsize + toc_c
    root = ET.fromstring(toc)

    def walk(node, prefix=""):
        for fe in node.findall("file"):
            name = fe.findtext("name")
            typ = fe.findtext("type")
            data = fe.find("data")
            info = ""
            if data is not None:
                info = "off=%s len=%s size=%s enc=%s" % (
                    data.findtext("offset"), data.findtext("length"), data.findtext("size"),
                    data.find("encoding").get("style") if data.find("encoding") is not None else "?")
            print(f"{prefix}{name} [{typ}] {info}")
            yield prefix + name, data
            yield from walk(fe, prefix + name + "/")

    entries = dict(walk(root.find("toc")))

    if len(sys.argv) == 4:
        data = entries[sys.argv[2]]
        f.seek(heap + int(data.findtext("offset")))
        raw = f.read(int(data.findtext("length")))
        with open(sys.argv[3], "wb") as out:
            out.write(raw)
        print("dumped", sys.argv[2], len(raw), "bytes")
