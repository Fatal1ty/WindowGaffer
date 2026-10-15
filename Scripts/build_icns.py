#!/usr/bin/env python3
"""Package prepared PNG icon sizes into an Apple ICNS container."""

from __future__ import annotations

import struct
import argparse
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_APP_ICON_SET = (
    ROOT / "Assets" / "WindowGafferAssets.xcassets" / "AppIcon.appiconset"
)
DEFAULT_OUTPUT = ROOT / "Assets" / "WindowGaffer.icns"

# Modern ICNS chunks store complete PNG payloads. Duplicate pixel dimensions are
# intentional: the chunk identifier also records the logical point size/scale.
CHUNKS = (
    (b"icp4", "AppIcon-16.png"),
    (b"icp5", "AppIcon-32.png"),
    (b"icp6", "AppIcon-64.png"),
    (b"ic07", "AppIcon-128.png"),
    (b"ic08", "AppIcon-256.png"),
    (b"ic09", "AppIcon-512.png"),
    (b"ic10", "AppIcon-1024.png"),
    (b"ic11", "AppIcon-32.png"),
    (b"ic12", "AppIcon-64.png"),
    (b"ic13", "AppIcon-256.png"),
    (b"ic14", "AppIcon-512.png"),
)


def pack_chunk(app_icon_set: Path, kind: bytes, filename: str) -> bytes:
    payload = (app_icon_set / filename).read_bytes()
    return struct.pack(">4sI", kind, len(payload) + 8) + payload


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--app-icon-set",
        type=Path,
        default=DEFAULT_APP_ICON_SET,
        help="directory containing AppIcon-16.png through AppIcon-1024.png",
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    body = b"".join(
        pack_chunk(args.app_icon_set, kind, filename)
        for kind, filename in CHUNKS
    )
    args.output.write_bytes(
        struct.pack(">4sI", b"icns", len(body) + 8) + body
    )
    print(args.output)


if __name__ == "__main__":
    main()
