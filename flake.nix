{
  description = "NixTV: a private, ad-free TV box on NixOS and Plasma Bigscreen";

  inputs = {
    # Plasma Bigscreen ships with Plasma >= 6.7, which only nixos-unstable has
    # (NixOS 26.05 is frozen on Plasma 6.6). flake.lock pins the exact commit,
    # so builds stay reproducible; `nix flake update` moves you forward.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Declarative Flatpak management.
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.8.0";
  };

  outputs =
    { self, nixpkgs, nix-flatpak, ... }:
    let
      # Every host gets the same TV setup (config.nix: what's installed and
      # who it's for); only the hardware module differs.
      mkHost =
        hostModule:
        nixpkgs.lib.nixosSystem {
          modules = [
            nix-flatpak.nixosModules.nix-flatpak
            ./modules
            ./config.nix
            hostModule
          ];
        };

      # The installer ISO (iso/), for each CPU architecture.
      mkIso =
        system:
        (nixpkgs.lib.nixosSystem {
          specialArgs = { inherit self; };
          modules = [
            ./iso
            { nixpkgs.hostPlatform = system; }
          ];
        }).config.system.build.isoImage;
    in
    {
      nixosConfigurations = {
        nixtv = mkHost ./hosts/nixtv; # any box, set up by nixtv-install
        utm = mkHost ./hosts/utm; # aarch64 UTM virtual machine, for trying NixTV out
      };

      # nix build .#iso (the ISO ends up in result/iso/)
      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: {
        iso = mkIso system;
      });
    };
}
