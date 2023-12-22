{
  description = "aka-raccoon Nix Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };
  };

  outputs = { flake-parts, ... }@inputs:
    let
      myLib = import ./lib/default.nix { inherit inputs; };
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      perSystem = { inputs', pkgs, ... }: { };

      flake.nixosConfigurations = {
        asc = myLib.mkNixosSystem "x86_64-linux" "asc" "b202b49b";
      };
    };
}
