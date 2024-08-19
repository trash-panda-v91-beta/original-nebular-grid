{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
in
{
  mkNixosSystem = system: hostname: hostid:
    lib.nixosSystem {
      inherit system;
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (import ../packages/overlay.nix { inherit inputs system; })
        ];
      };
      modules = [
        {
          _module.args = {
            inherit inputs system;
            host = { name = hostname; id = hostid; };
            pkgs-unstable = import inputs.nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
              overlays = [ (import ../packages/overlay.nix { inherit inputs system; }) ];
            };
          };
        }
        inputs.home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
        ./configuration.nix
        ./hardware-configuration.nix
      ];
    };
}
