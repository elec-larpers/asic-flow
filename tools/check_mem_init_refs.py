#!/usr/bin/env python3

import argparse
import re
import sys
from pathlib import Path


INIT_RE = re.compile(r'MEMORY_INIT_file="([^"]+)"')


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check that MEMORY_INIT_file references resolve in the RTL handoff."
    )
    parser.add_argument(
        "--rtl-dir",
        default="../ModelToRTL/librelane_handoff/rtl",
        help="Directory containing generated stage RTL and .mem files.",
    )
    args = parser.parse_args()

    rtl_dir = Path(args.rtl_dir).resolve()
    stage_files = sorted(rtl_dir.glob("yolo26n_stage*.v"))
    missing = []

    for stage_file in stage_files:
        text = stage_file.read_text()
        for match in INIT_RE.finditer(text):
            candidate = match.group(1)
            if candidate and not (rtl_dir / candidate).exists():
                missing.append((stage_file.name, candidate))

    if not missing:
        print(f"All MEMORY_INIT_file references resolve under {rtl_dir}")
        return 0

    print(f"Missing MEMORY_INIT_file targets under {rtl_dir}:")
    for stage_file, candidate in missing:
        print(f"{stage_file}: {candidate}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
