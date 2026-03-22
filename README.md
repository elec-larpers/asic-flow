# ASIC Flow

This repo provides a Nix-based LibreLane environment and project config for the YOLO RTL handoff in `../ModelToRTL/librelane_handoff`.

The current `config.json` targets the generated `yolo26n_top` design as a standalone Sky130 macro bring-up. It is useful for validating the flow setup and the RTL handoff shape, but it is not a production-ready ASIC memory implementation.

## Design Inputs

- Top module: `yolo26n_top`
- RTL: `../ModelToRTL/librelane_handoff/rtl/`
- Compile-order list: `../ModelToRTL/librelane_handoff/sources.f`
- Simulation script: `../ModelToRTL/librelane_handoff/run_top_sim.sh`
- LibreLane config: `./config.json`

## Environment Setup

If you use `direnv`, run:

```bash
direnv allow
```

Otherwise, enter the environment manually:

```bash
nix develop --accept-flake-config
```

Inside the development shell you should have:

- `librelane`
- `magic`

## Reproduce The Current Bring-Up

1. Enter the Nix shell.
2. Run the existing top-level simulation:

```bash
bash ../ModelToRTL/librelane_handoff/run_top_sim.sh
```

Or from the repo root:

```bash
make sim
```

3. Run LibreLane from this repo root:

```bash
librelane --design-dir . --pdk sky130A config.json
```

Or:

```bash
make flow
```

To run the production blocker checks from the repo root:

```bash
make production-check
```

To open the newest available ODB snapshot from the latest LibreLane run in the OpenROAD GUI:

```bash
make view ods
```

The legacy alias still works:

```bash
make view-odb
```

To open the Sky130 standard-cell GDS in Magic:

```bash
make view-stdcell-gds
```

The expected top-level flow input is the generated Verilog in `../ModelToRTL/librelane_handoff/rtl/` plus the local `config.json`.

For this generated design, both simulation compilation and LibreLane front-end lint can take a while. Expect a noisy warning stream before you know whether the handoff will make it past the earliest stages.

## What This Config Is For

The checked-in `config.json` is a first-pass macro-flow config with conservative settings:

- `CLOCK_PORT` is `clock`
- `CLOCK_PERIOD` is `50` ns
- `DIE_AREA` starts at `3000um x 3000um`
- `CORE_AREA` leaves a `100um` margin on all sides
- `PL_TARGET_DENSITY_PCT` is relaxed to `35`

This is intended to:

- verify that LibreLane sees the design correctly
- provide a documented starting point for floorplan and synthesis exploration
- keep the reproduction steps for this repo concrete

This is not intended to:

- claim that the current memory implementation is physically realistic
- serve as a signoff-quality tapeout config

## Known Limitations

The current handoff has two major issues that affect physical implementation:

1. `yolo26n_top` instantiates `25` behavioral `yolo26n_sram_2r2w` memories totaling about `396.55 Mbits`.
2. Some generated stage RTL still references `.mem` filenames such as `stage0__array_a.mem` / `stage0__array.mem`, while the handoff directory currently contains `stage*_array_ref_*.mem` files.

Because of this, a flow failure during elaboration or synthesis is currently possible and should be treated as a handoff issue to fix in the generated RTL or memory file naming, not as a problem with the basic LibreLane invocation documented here.

This repo now includes two concrete checks for those blockers:

- `make mem-init-check` verifies that `MEMORY_INIT_file` references in the generated stage RTL actually exist in the handoff directory.
- `make sram-feasibility` estimates how many local Sky130 SRAM macros would be required for the current memory footprint.

On the current handoff, those checks show two hard blockers:

- the generated stage RTL references many missing files such as `stage0__array_a.mem` and `stage0__array.mem`
- even the storage-only lower bound for the available `sky130_sram_2kbyte_1rw1r_32x512_8` macros is `24,204` SRAM macros, about `6886.969 mm^2` of macro area before accounting for the extra cost of implementing the current `2r2w` interface

## Real SRAM Production Path

If the goal is a credible ASIC implementation rather than a bring-up run, the current behavioral SRAM wrapper must be replaced.

The practical next steps are:

1. Replace `yolo26n_sram_2r2w` with a real SRAM integration strategy supported by the Sky130 collateral you plan to use.
2. Rework the memory architecture if needed, since a native `2r2w` macro is unlikely to exist as a drop-in replacement.
3. Add the SRAM collateral to LibreLane using `MACROS` and `EXTRA_VERILOG_MODELS`.
4. Re-size the die and core around the real macro footprint instead of the provisional `3000 x 3000` bring-up floorplan.
5. Tighten timing and restore strict synthesis/signoff checks only after macro integration is stable.

## Notes

- The flake uses the FOSSi binary cache to avoid rebuilding the LibreLane toolchain locally.
- The `.envrc` file assumes a `direnv` setup with `use flake` support.
- `flake.lock` should be committed once you are ready to pin the exact LibreLane revision for the repo.
