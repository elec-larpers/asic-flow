#!/usr/bin/env python3

import argparse
import json
import math
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path


INSTANCE_RE = re.compile(
    r"yolo26n_sram_2r2w\s*#\(\.ADDR_WIDTH\((\d+)\),\s*\.DEPTH\((\d+)\)\)\s+(\w+)\s*\(",
)
SIZE_RE = re.compile(r"^\s*SIZE\s+([0-9.]+)\s+BY\s+([0-9.]+)\s*;")


@dataclass
class MacroInfo:
    name: str
    depth: int
    width_um: float
    height_um: float

    @property
    def area_um2(self) -> float:
        return self.width_um * self.height_um


def find_pdk_root(repo_root: Path) -> Path:
    env = os.environ.get("PDK_ROOT")
    if env:
        return Path(env)

    for candidate in sorted(repo_root.glob("runs/*/resolved.json"), reverse=True):
        data = json.loads(candidate.read_text())
        pdk_root = data.get("PDK_ROOT")
        if pdk_root:
            return Path(pdk_root)

    raise FileNotFoundError(
        "PDK_ROOT is not set and no LibreLane resolved.json was found under runs/."
    )


def parse_macro_size(lef_path: Path) -> tuple[float, float]:
    for line in lef_path.read_text().splitlines():
        match = SIZE_RE.match(line)
        if match:
            return float(match.group(1)), float(match.group(2))
    raise ValueError(f"Could not parse SIZE from {lef_path}")


def load_macros(pdk_root: Path, pdk: str) -> list[MacroInfo]:
    base = pdk_root / pdk / "libs.ref" / "sky130_sram_macros" / "lef"
    specs = [
        ("sky130_sram_1kbyte_1rw1r_32x256_8", 256),
        ("sky130_sram_2kbyte_1rw1r_32x512_8", 512),
    ]
    macros = []
    for name, depth in specs:
        width_um, height_um = parse_macro_size(base / f"{name}.lef")
        macros.append(MacroInfo(name=name, depth=depth, width_um=width_um, height_um=height_um))
    return macros


def choose_best_macro(depth: int, macros: list[MacroInfo]) -> tuple[MacroInfo, int]:
    candidates = []
    for macro in macros:
        count = math.ceil(depth / macro.depth)
        candidates.append((count * macro.area_um2, macro, count))
    _, macro, count = min(candidates, key=lambda item: item[0])
    return macro, count


def load_instances(top_path: Path) -> list[tuple[str, int, int]]:
    instances = []
    for line in top_path.read_text().splitlines():
        match = INSTANCE_RE.search(line)
        if match:
            addr_width = int(match.group(1))
            depth = int(match.group(2))
            name = match.group(3)
            instances.append((name, addr_width, depth))
    if not instances:
        raise ValueError(f"No yolo26n_sram_2r2w instances found in {top_path}")
    return instances


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Estimate Sky130 SRAM macro counts and area for yolo26n_top."
    )
    parser.add_argument(
        "--top",
        default="../ModelToRTL/librelane_handoff/rtl/yolo26n_top.v",
        help="Path to the generated top-level RTL.",
    )
    parser.add_argument(
        "--pdk",
        default="sky130A",
        help="PDK variant to inspect under PDK_ROOT.",
    )
    args = parser.parse_args()

    repo_root = Path.cwd()
    top_path = (repo_root / args.top).resolve()
    pdk_root = find_pdk_root(repo_root)
    macros = load_macros(pdk_root, args.pdk)
    instances = load_instances(top_path)

    total_words = 0
    total_macros = 0
    total_area_um2 = 0.0

    print(f"Top RTL: {top_path}")
    print(f"PDK_ROOT: {pdk_root}")
    print(f"PDK: {args.pdk}")
    print()
    print(
        "instance,depth,storage_bits,best_macro,macro_depth,macro_count,macro_area_mm2"
    )

    for name, _, depth in instances:
        macro, macro_count = choose_best_macro(depth, macros)
        area_mm2 = (macro_count * macro.area_um2) / 1_000_000.0
        storage_bits = depth * 32
        total_words += depth
        total_macros += macro_count
        total_area_um2 += macro_count * macro.area_um2
        print(
            f"{name},{depth},{storage_bits},{macro.name},{macro.depth},{macro_count},{area_mm2:.3f}"
        )

    total_area_mm2 = total_area_um2 / 1_000_000.0
    square_mm = math.sqrt(total_area_mm2)
    print()
    print(f"Total logical words: {total_words}")
    print(f"Total logical bits: {total_words * 32}")
    print(f"Best-fit macro count (storage only): {total_macros}")
    print(f"Best-fit macro area (storage only): {total_area_mm2:.3f} mm^2")
    print(f"Square-equivalent side length: {square_mm:.3f} mm")
    print()
    print(
        "Note: this is a storage-only lower bound using available 32-bit 1rw1r macros."
    )
    print(
        "A true 2r2w implementation would require extra architecture work and likely more area."
    )

    return 0


if __name__ == "__main__":
    sys.exit(main())
