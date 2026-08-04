{
        description = "Master flake, providing all outputs";

        inputs = {
                nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
                home-manager.url = "github:nix-community/home-manager";
                home-manager.inputs.nixpkgs.follows = "nixpkgs";
        };


        outputs = {self, nixpkgs, ...}:
        let
                allSystems = [
                        "x86_64-linux" # 64-bit Intel/AMD Linux
                        "aarch64-linux" # 64-bit ARM Linux
                        "x86_64-darwin" # 64-bit Intel macOS
                        "aarch64-darwin" # 64-bit ARM macOS
                ];
                forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
                        pkgs = import nixpkgs {inherit system; };
                        });

                swayimgVersion = "v5.5";
        in
        {
                packages = forAllSystems ({pkgs}: {
                        swayimg-lock = pkgs.callPackage ./swayimg/package.nix {};

                        lintree = pkgs.buildGoModule rec {
                                pname = "lintree";
                                version = "v0.1.3";
                                src = pkgs.fetchFromGitHub {
                                        owner = "PatchMon";
                                        repo = "lintree";
                                        rev = version;
                                        hash = "sha256-oaxLbwDCKuIvSoLVc3TZING3cY3hZ8ZzQV7+9skFiX0=";
                                };
                                vendorHash = "sha256-i/TXh6m+227qcL4hpNuvgs5grRzjfFRW3z3BVPYhmnE=";
                        };
                });

                homeModules = {
                        "swayimg_${swayimgVersion}" = ./swayimg/hm-module.nix;
                };

                luaUtils = import ./luaUtils/lib.nix;
        };
}
