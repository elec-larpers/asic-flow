# ASIC Flow

This repo provides a Nix-based ASIC flow for turning RTL into GDSII with LibreLane.

The environment is set up for the SkyWater `sky130` PDK and includes Magic VLSI for layout viewing.

## Getting Started

If you use `direnv`, run:

```bash
direnv allow
```

Otherwise, enter the environment manually:

```bash
nix develop --accept-flake-config
```

## Tools

Inside the development shell you should have:

- `librelane` for the implementation flow
- `magic` for viewing and inspecting layout output

## Notes

- The flake uses the FOSSi binary cache to avoid rebuilding the LibreLane toolchain locally.
- The `.envrc` file assumes a `direnv` setup with `use flake` support.
- `flake.lock` should be committed once you are ready to pin the exact LibreLane revision for the repo.
