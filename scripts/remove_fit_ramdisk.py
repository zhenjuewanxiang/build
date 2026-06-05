#!/usr/bin/env python3
import sys
from pathlib import Path


def remove_ramdisk_node(text):
    lines = text.splitlines(True)
    out = []
    i = 0
    while i < len(lines):
        if 'ramdisk-1 {' in lines[i]:
            depth = 0
            while i < len(lines):
                depth += lines[i].count('{') - lines[i].count('}')
                i += 1
                if depth == 0:
                    break
            continue
        if 'ramdisk = "ramdisk-1";' in lines[i]:
            i += 1
            continue
        out.append(lines[i])
        i += 1
    return ''.join(out)


def main():
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <multi.its>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    path.write_text(remove_ramdisk_node(path.read_text()))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
