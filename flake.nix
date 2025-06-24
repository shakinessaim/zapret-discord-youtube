{
  description = "Zapret - DPI bypass tool for Discord and YouTube";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zapret-src = {
      url = "github:bol-van/zapret";
      flake = false; # Используем как обычный исходник
    };
  };

  outputs = { self, nixpkgs, flake-utils, zapret-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          zapret = pkgs.callPackage ./nixos/packages/zapret.nix { 
            src = zapret-src; 
          };
          default = self.packages.${system}.zapret;
        };
      }
    ) // {
      nixosModules = {
        zapret = import ./nixos/modules/zapret.nix;
        default = self.nixosModules.zapret;
      };
    };
} 