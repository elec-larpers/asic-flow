{
  description = "ASIC flow development environment with LibreLane and Magic VLSI";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-cache.fossi-foundation.org"
    ];
    extra-trusted-public-keys = [
      "nix-cache.fossi-foundation.org:3+K59iFwXqKsL7BNu6Guy0v+uTlwsxYQxjspXzqLYQs="
    ];
  };

  inputs = {
    librelane.url = "github:librelane/librelane";
  };

  outputs = { librelane, ... }: {
    devShells = librelane.inputs.nix-eda.forAllSystems (
      system:
      let
        pkgs = librelane.legacyPackages.${system};
        callPackage = pkgs.lib.callPackageWith pkgs;
      in
      {
        default = callPackage (librelane.createOpenLaneShell {
          extra-packages = with pkgs; [
            magic-vlsi
          ];
        }) {};
      }
    );
  };
}
