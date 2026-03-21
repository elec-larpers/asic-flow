# Current Errors and Problems

This file summarizes the current technical blockers and repo state for the YOLO-to-ASIC flow.

## 1. The full YOLO design is not physically tapeout-ready

The generated top-level YOLO RTL in `../ModelToRTL/librelane_handoff/rtl/yolo26n_top.v` is not currently hardenable as a realistic Sky130 macro.

Main reasons:

- The design uses approximately `396.55 Mbits` of logical storage.
- The locally available hardened Sky130 SRAMs are `1rw1r`, not `2r2w`.
- The current top-level wrapper expects `2r2w` behavior via `yolo26n_sram_2r2w`.
- A storage-only lower bound using the available `sky130_sram_2kbyte_1rw1r_32x512_8` macros is:
  - `24,204` SRAM macros
  - about `6886.969 mm^2` of SRAM macro area
- That estimate does not include the extra cost needed to emulate the current `2r2w` interface.

Conclusion:

- This is not a configuration problem.
- This is an architecture and physical-feasibility problem.

## 2. The original generated RTL had stale `.mem` default filenames

The generated stage RTL referenced stale default filenames such as:

- `stage0__array_a.mem`
- `stage0__array.mem`

while the actual handoff contained files named like:

- `stage0__array_ref_428677.mem`
- `stage0__array_ref_429446.mem`

Compatibility symlinks were created in `../ModelToRTL/librelane_handoff/rtl/` so those stale default names now resolve.

Important nuance:

- This appears to be mostly a naming mismatch between stale default parameter values and the actual generated `*_ref_*` memory files.
- Even if the instantiated design used the `*_ref_*` files, some tools still tripped over the stale defaults.

## 3. The YOLO RTL still produces substantial front-end warnings

Even after the `.mem` naming issue was addressed, the generated stage RTL still produces significant warnings in front-end tools.

Examples already observed:

- missing-pin lint warnings in Verilator for generated stage logic
- out-of-bounds/range warnings in Yosys on generated stage RTL
- a large amount of generated-memory and generated-control noise that would need cleanup before treating the RTL as production quality

Conclusion:

- The full YOLO RTL is still not in a production-signoff state.

## 4. An emergency placeholder path was started, but not adopted

A minimal emergency placeholder `yolo26n_top` was introduced in the worktree to get LibreLane moving quickly.

That path was only meant as an emergency “something that hardens fast” fallback and should not be confused with a real YOLO tapeout.

The user explicitly rejected that direction in favor of the real YOLO RTL.

## 5. The repo worktree is currently dirty

At the time of writing, the repo contains multiple uncommitted changes and generated artifacts outside this file, including:

- modified `README.md`
- added `flake.lock`
- untracked `Makefile`
- untracked `config.json`
- untracked `rtl/`
- untracked `tools/`
- untracked `runs/`
- untracked `spm-user_project_wrapper/`

This markdown file is being committed by itself on purpose.

## 6. What would actually need to happen next

The full YOLO tapeout path would require at least:

1. Reducing or restructuring the memory architecture to something physically credible on Sky130.
2. Replacing the behavioral `2r2w` SRAM wrapper with a real macro integration strategy compatible with available hardened SRAMs.
3. Cleaning the generated RTL until lint and synthesis warnings are actionable rather than overwhelming.
4. Re-running the full flow only after the above design issues are resolved.

## Bottom line

The current blocker is not that LibreLane is misconfigured.

The current blocker is that the actual YOLO design, as generated today, is too memory-heavy and mismatched to the available hardened SRAM interfaces to be tapeout-ready on the current Sky130 setup.
