"""Split a large file into FAT32-safe parts (<4 GiB) and print a SHA-256 of the whole.

Usage: python split_pkg.py <source> <dest_dir>
"""
import hashlib
import os
import sys

PART_SIZE = 3 * 1024**3 + 768 * 1024**2  # 3.75 GiB, below the FAT32 4 GiB limit
BUF = 8 * 1024**2

src, dest = sys.argv[1], sys.argv[2]
os.makedirs(dest, exist_ok=True)
name = os.path.basename(src)
sha = hashlib.sha256()
total = os.path.getsize(src)
done = 0
part = 0

with open(src, "rb") as f:
    while done < total:
        path = os.path.join(dest, f"{name}.part{part:02d}")
        written = 0
        with open(path, "wb") as out:
            while written < PART_SIZE:
                chunk = f.read(min(BUF, PART_SIZE - written))
                if not chunk:
                    break
                out.write(chunk)
                sha.update(chunk)
                written += len(chunk)
            out.flush()
            os.fsync(out.fileno())
        done += written
        print(f"{path}: {written} bytes ({done / total:.0%})", flush=True)
        part += 1

print("parts:", part)
print("sha256:", sha.hexdigest())
