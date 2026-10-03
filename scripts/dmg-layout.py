#!/usr/bin/env python3
"""Writes a Finder window layout into a folder's .DS_Store, for DMG packaging.

No dependencies: the file format is written directly, so no Finder automation
permission is needed (AppleScript would require the user to approve access to
Finder, and it fails in sandboxed build environments).

Usage:
    python3 dmg-layout.py <folder> \
        --window 200 200 560 380 \
        --icon "MouseScrollFix.app" 140 170 \
        --icon "Applications" 400 170 \
        --icon "Read me.txt" 270 300 \
        [--background-color 0.98 0.98 0.98] [--icon-size 128] \
        [--dump]

The .DS_Store format is an Apple B-tree file rather than a plist:

    "Bud1" header -> allocator root block (offsets table, TOC, free lists)
                  -> TOC["DSDB"] = superblock (root node, levels, records, page size)
                  -> nodes holding records

Each record is: <name length><UTF-16BE name><4-byte code><4-byte type><value>.
`Iloc` values are 16 bytes (x, y, 0xFFFFFFFF, 0xFFFF0000); `bwsp` (window) and
`icvp` (icon view) values are binary plists.

The buddy allocator below is a trimmed copy of `ds_store` by Alastair Houghton
(MIT licensed, https://github.com/al45tair/ds_store). Keeping its exact
allocation semantics matters: the free lists have to stay internally consistent
or Finder ignores the layout.
"""

import argparse
import os
import plistlib
import struct
import sys


class BuddyError(Exception):
    pass


class Block:
    """A fixed-size view over a region of the file."""

    def __init__(self, allocator, offset, size):
        self._allocator = allocator
        self._offset = offset
        self._size = size
        self._value = bytearray(allocator.read(offset, size))
        self._pos = 0
        self._dirty = False

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.close()

    def close(self):
        if self._dirty:
            self.flush()

    def flush(self):
        if self._dirty:
            self._dirty = False
            self._allocator.write(self._offset, self._value)

    def zero_fill(self):
        length = self._size - self._pos
        self._value[self._pos : self._size] = b"\0" * length
        self._dirty = True

    def tell(self):
        return self._pos

    def seek(self, pos):
        if pos < 0 or pos > self._size:
            raise ValueError("seek out of range")
        self._pos = pos

    def read(self, size_or_format):
        if isinstance(size_or_format, (str, bytes)):
            size = struct.calcsize(size_or_format)
            fmt = size_or_format
        else:
            size = size_or_format
            fmt = None

        if self._size - self._pos < size:
            raise BuddyError("unable to read %d bytes in block" % size)

        data = self._value[self._pos : self._pos + size]
        self._pos += size

        if fmt is not None:
            if isinstance(data, bytearray):
                return struct.unpack_from(fmt, bytes(data))
            return struct.unpack(fmt, data)
        return bytes(data)

    def write(self, data_or_format, *args):
        data = struct.pack(data_or_format, *args) if args else data_or_format
        if self._pos + len(data) > self._size:
            raise ValueError("attempt to write past end of block")
        self._value[self._pos : self._pos + len(data)] = data
        self._pos += len(data)
        self._dirty = True


class Allocator:
    """Buddy allocator for the .DS_Store container format."""

    # The 16 opaque bytes a freshly created file carries in its header.
    _INITIAL_UNKNOWN = b"\x00\x00\x10\x0c\x00\x00\x00\x87\x00\x00\x20\x0b\x00\x00\x00\x00"

    def __init__(self, the_file):
        self._file = the_file
        self._dirty = False
        self._file.seek(0)

        magic1, magic2, offset, size, offset2, self._unknown1 = self.read(
            -4, ">I4sIII16s"
        )
        if magic2 != b"Bud1" or magic1 != 1:
            raise BuddyError("not a buddy file")
        if offset != offset2:
            raise BuddyError("root addresses differ")

        self._root = Block(self, offset, size)

        count, self._unknown2 = self._root.read(">II")
        self._offsets = []
        c = (count + 255) & ~255
        while c:
            self._offsets += self._root.read(">256I")
            c -= 256
        self._offsets = self._offsets[:count]

        self._toc = {}
        count = self._root.read(">I")[0]
        for _ in range(count):
            nlen = self._root.read("B")[0]
            name = bytes(self._root.read(nlen))
            value = self._root.read(">I")[0]
            self._toc[name] = value

        self._free = []
        for _ in range(32):
            count = self._root.read(">I")
            self._free.append(list(self._root.read(">%dI" % count[0])))

    @classmethod
    def open(cls, path, mode="r+"):
        if "b" not in mode:
            mode = mode[:1] + "b" + mode[1:]
        f = open(path, mode)

        if "w" in mode:
            f.truncate()
            f.write(
                struct.pack(
                    b">I4sIII16s", 1, b"Bud1", 2048, 1264, 2048, cls._INITIAL_UNKNOWN
                )
            )
            f.write(b"\0" * 2016)

            # Free lists for a virgin 2GB address space: one block per width, and
            # nothing below width 5 (that region is the header).
            free_list = [struct.pack(b">5I", 0, 0, 0, 0, 0)]
            for n in range(5, 11):
                free_list.append(struct.pack(b">II", 1, 2**n))
            free_list.append(struct.pack(b">I", 0))  # width 11 holds the root block
            for n in range(12, 31):
                free_list.append(struct.pack(b">II", 1, 2**n))
            free_list.append(struct.pack(b">I", 0))

            root = b"".join(
                [
                    struct.pack(b">III", 1, 0, 2048 | 5),
                    struct.pack(b">I", 0) * 255,
                    struct.pack(b">I", 0),
                ]
                + free_list
            )
            f.write(root)

        return cls(f)

    def close(self):
        self.flush()
        self._file.close()

    def flush(self):
        if self._dirty:
            size = self._root_block_size()
            self.allocate(size, 0)
            with self.get_block(0) as rblk:
                self._write_root_block_into(rblk)

            addr = self._offsets[0]
            offset = addr & ~0x1F
            size = 1 << (addr & 0x1F)

            self._file.seek(0, os.SEEK_SET)
            self._file.write(
                struct.pack(
                    b">I4sIII16s", 1, b"Bud1", offset, size, offset, self._unknown1
                )
            )
            self._dirty = False

        self._file.flush()

    def read(self, offset, size_or_format):
        # Note the fixed four-byte offset: block addresses are relative to it.
        self._file.seek(offset + 4, os.SEEK_SET)

        if isinstance(size_or_format, str):
            size = struct.calcsize(size_or_format)
            fmt = size_or_format
        else:
            size = size_or_format
            fmt = None

        ret = self._file.read(size)
        if len(ret) < size:
            ret += b"\0" * (size - len(ret))

        if fmt is not None:
            return struct.unpack_from(fmt, bytes(ret))
        return ret

    def write(self, offset, data_or_format, *args):
        self._file.seek(offset + 4, os.SEEK_SET)
        data = struct.pack(data_or_format, *args) if args else data_or_format
        self._file.write(data)

    def get_block(self, block):
        try:
            addr = self._offsets[block]
        except IndexError:
            return None
        offset = addr & ~0x1F
        size = 1 << (addr & 0x1F)
        return Block(self, offset, size)

    def _root_block_size(self):
        size = 8
        size += 4 * ((len(self._offsets) + 255) & ~255)
        size += 4
        size += sum(5 + len(s) for s in self._toc)
        size += sum(4 + 4 * len(fl) for fl in self._free)
        return size

    def _write_root_block_into(self, block):
        block.write(">II", len(self._offsets), self._unknown2)
        block.write(">%dI" % len(self._offsets), *self._offsets)
        extra = len(self._offsets) & 255
        if extra:
            block.write(b"\0\0\0\0" * (256 - extra))

        keys = sorted(self._toc.keys())
        block.write(">I", len(keys))
        for k in keys:
            block.write("B", len(k))
            block.write(k)
            block.write(">I", self._toc[k])

        for f in self._free:
            block.write(">I", len(f))
            if len(f):
                block.write(">%dI" % len(f), *f)

    def _buddy(self, offset, width):
        f = self._free[width]
        b = offset ^ (1 << width)
        try:
            ndx = f.index(b)
        except ValueError:
            ndx = None
        return (f, b, ndx)

    def _release(self, offset, width):
        while True:
            f, b, ndx = self._buddy(offset, width)
            if ndx is None:
                break
            offset &= b
            width += 1
            del f[ndx]
        f.insert(0, offset)
        f.sort()
        self._dirty = True

    def _alloc(self, width):
        w = width
        while not self._free[w]:
            w += 1
        while w > width:
            offset = self._free[w].pop(0)
            w -= 1
            self._free[w] = [offset, offset ^ (1 << w)]
        self._dirty = True
        return self._free[width].pop(0)

    def allocate(self, num_bytes, block=None):
        if block is None:
            try:
                block = self._offsets.index(0)
            except ValueError:
                block = len(self._offsets)
                self._offsets.append(0)

        width = max(num_bytes.bit_length(), 5)
        addr = self._offsets[block]
        offset = addr & ~0x1F

        if addr:
            blkwidth = addr & 0x1F
            if blkwidth == width:
                return block
            self._release(offset, width)
            self._offsets[block] = 0

        offset = self._alloc(width)
        self._offsets[block] = offset | width
        return block

    def __setitem__(self, key, value):
        if not isinstance(key, bytes):
            key = key.encode("latin_1")
        self._toc[key] = value
        self._dirty = True


# ---------------------------------------------------------------------------
# Records
# ---------------------------------------------------------------------------

PAGE_SIZE = 4096


def encode_iloc(x, y):
    """Icon location: x, y, then two fixed sentinel words."""
    return struct.pack(b">IIII", x, y, 0xFFFFFFFF, 0xFFFF0000)


def encode_plist(value):
    return plistlib.dumps(value, fmt=plistlib.FMT_BINARY)


def write_record(block, name, code, value):
    """Writes one B-tree record. `value` is raw bytes, always stored as a blob."""
    utf16 = name.encode("utf-16be")
    block.write(b">I", len(utf16) // 2)
    block.write(utf16)
    block.write(b">4s4s", code, b"blob")
    block.write(b">I", len(value))
    block.write(value)


def build_store(path, entries):
    """Creates a .DS_Store holding all `entries` in a single leaf node.

    `entries` is a list of (name, code, bytes) tuples. Sorting is significant:
    the B-tree is searched by (lowercased name, code).
    """
    if os.path.exists(path):
        os.remove(path)

    ordered = sorted(entries, key=lambda item: (item[0].lower(), item[1]))

    allocator = Allocator.open(path, "w+")
    try:
        # The superblock is allocated first, so it always lands in block 1.
        superblock = allocator.allocate(20)
        allocator["DSDB"] = superblock

        root = allocator.allocate(PAGE_SIZE)
        with allocator.get_block(root) as block:
            block.zero_fill()
            block.seek(0)
            block.write(b">II", 0, len(ordered))  # next node, record count
            for name, code, value in ordered:
                write_record(block, name, code, value)

        with allocator.get_block(superblock) as block:
            # `levels` counts *internal* levels: a single leaf node means 0. Writing 1
            # here makes Finder treat the leaf as an internal node, fail to parse it, and
            # silently replace the whole .DS_Store (verified against Finder's own files).
            block.write(b">IIIII", root, 0, len(ordered), 1, PAGE_SIZE)
    finally:
        allocator.close()

    if len(ordered) > 255:
        raise SystemExit("dmg-layout: too many records for a single node")


# ---------------------------------------------------------------------------
# Reading back (used by --dump to sanity-check what we wrote)
# ---------------------------------------------------------------------------


def read_record(block):
    nlen = block.read(">I")[0]
    name = block.read(2 * nlen).decode("utf-16be")
    code, typecode = block.read(">4s4s")
    if typecode == b"blob":
        vlen = block.read(">I")[0]
        value = block.read(vlen)
    elif typecode == b"bool":
        value = block.read(">?")[0]
    elif typecode in (b"long", b"shor"):
        value = block.read(">I")[0]
    elif typecode == b"ustr":
        vlen = block.read(">I")[0]
        value = block.read(2 * vlen).decode("utf-16be")
    elif typecode == b"comp" or typecode == b"dutc":
        value = block.read(">Q")[0]
    else:
        raise BuddyError("unknown type code %r" % typecode)
    return name, code, typecode, value


def dump_store(path, verbose=False):
    with open(path, "rb") as handle:
        allocator = Allocator(handle)
        dsdb = allocator._toc[b"DSDB"]
        with allocator.get_block(dsdb) as superblock:
            root, levels, records, nodes, page_size = superblock.read(">IIIII")
        print(
            "root=%d levels=%d records=%d nodes=%d page_size=%d"
            % (root, levels, records, nodes, page_size)
        )

        def walk(node_index, depth=0):
            with allocator.get_block(node_index) as node:
                next_node, count = node.read(">II")
                indent = "  " * (depth + 1)
                if next_node:
                    for _ in range(count):
                        child = node.read(">I")[0]
                        name, code, typecode, value = read_record(node)
                        print("%s%s %s [internal]" % (indent, name, code.decode("latin_1")))
                        _ = (code, typecode, value)
                        walk(child, depth + 1)
                    walk(next_node, depth)
                else:
                    for _ in range(count):
                        name, code, typecode, value = read_record(node)
                        code_text = code.decode("latin_1")
                        if code == b"Iloc" and isinstance(value, bytes) and len(value) >= 8:
                            x, y = struct.unpack(b">II", value[:8])
                            print("%s%-26s Iloc  x=%d y=%d" % (indent, name, x, y))
                        elif typecode == b"blob":
                            print(
                                "%s%-26s %s blob (%d bytes)%s"
                                % (indent, name, code_text, len(value), "" if verbose else "")
                            )
                            if verbose and code in (b"icvp", b"bwsp"):
                                for key, item in sorted(plistlib.loads(value).items()):
                                    print("%s    %s = %r" % (indent, key, item))
                        else:
                            print(
                                "%s%-26s %s %s = %r"
                                % (indent, name, code_text, typecode.decode("latin_1"), value)
                            )

        walk(root)
        handle.close()


# ---------------------------------------------------------------------------
# Command line
# ---------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description="Write a Finder layout into .DS_Store")
    parser.add_argument("folder")
    parser.add_argument("--window", nargs=4, type=int, metavar=("X", "Y", "W", "H"))
    parser.add_argument(
        "--icon",
        nargs=3,
        action="append",
        default=[],
        metavar=("NAME", "X", "Y"),
        help="icon position; repeat for every item in the window",
    )
    parser.add_argument("--background-color", nargs=3, type=float, default=[1.0, 1.0, 1.0])
    parser.add_argument("--icon-size", type=float, default=128.0)
    parser.add_argument("--dump", action="store_true", help="print the layout instead of writing it")
    args = parser.parse_args()

    store_path = os.path.join(args.folder, ".DS_Store")

    if args.dump:
        dump_store(store_path)
        return

    entries = []

    if args.window:
        x, y, width, height = args.window
        entries.append(
            (
                ".",
                b"bwsp",
                encode_plist(
                    {
                        "WindowBounds": "{{%d, %d}, {%d, %d}}" % (x, y, width, height),
                        # Without an explicit view style Finder opens the volume in
                        # whatever view the user last used, and then discards the
                        # icon-view record (icvp) because it does not apply.
                        "ViewStyle": b"icnv",
                        "ShowToolbar": False,
                        "ShowStatusBar": False,
                        "ShowPathbar": False,
                        "ShowTabView": False,
                        "ContainerShowSidebar": False,
                        "SidebarWidth": 0,
                        "PreviewPaneVisibility": False,
                    }
                ),
            )
        )

    red, green, blue = args.background_color
    entries.append(
        (
            ".",
            b"icvp",
            encode_plist(
                {
                    "viewOptionsVersion": 1,
                    # 0 = Finder's default (white) background, with the colour fields
                    # still present, exactly as Finder writes them itself. A value of 1
                    # ("solid colour") makes Finder discard the whole icvp record, which
                    # then resets the icon size as well — verified by round-tripping
                    # through a mounted image.
                    "backgroundType": 0,
                    "backgroundColorRed": red,
                    "backgroundColorGreen": green,
                    "backgroundColorBlue": blue,
                    "iconSize": args.icon_size,
                    "textSize": 14.0,
                    "labelOnBottom": True,
                    "showItemInfo": False,
                    "showIconPreview": False,
                    "arrangeBy": "none",
                    "gridSpacing": args.icon_size + 40.0,
                    "gridOffsetX": 0.0,
                    "gridOffsetY": 0.0,
                    "scrollPositionX": 0.0,
                    "scrollPositionY": 0.0,
                }
            ),
        )
    )

    for name, x, y in args.icon:
        entries.append((name, b"Iloc", encode_iloc(int(x), int(y))))

    build_store(store_path, entries)
    print("dmg-layout: wrote %s (%d records)" % (store_path, len(entries)))


if __name__ == "__main__":
    try:
        main()
    except BuddyError as error:
        sys.exit("dmg-layout: %s" % error)
