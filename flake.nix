{
  description = "Kernel development environments";

  inputs = {
    systems.url = "github:nix-systems/default-linux";

    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
      fenix,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";

        # A set of scripts to simplify kernel development.
        kernelDevTools = pkgs.callPackage ./tools.nix {
          flakeSelf = self;
        };

        linuxCommonDependencies =
          [
            kernelDevTools
          ]
          ++ (with pkgs; [
            bc
            bison
            cpio
            elfutils
            flex
            gmp
            gnumake
            kmod
            libmpc
            mpfr
            nettools
            openssl
            pahole
            perl
            python3Minimal
            rsync
            ubootTools
            zlib
            zstd

            # For make menuconfig
            ncurses

            # For make gtags
            global

            # For git send-email 🫠
            gitFull
          ]);

        rust-analyzer = fenix.packages."${system}".rust-analyzer;

        linuxRustDependencies =
          { clang, rustVersion }:
          let
            rustc = rust-overlay.packages."${system}"."${rustVersion}".override {
              extensions = [
                "rust-src"
                "rustfmt"
                "clippy"
              ];
            };

            rustPlatform = pkgs.makeRustPlatform {
              cargo = rustc;
              rustc = rustc;
            };

            bindgenUnwrapped = pkgs.callPackage ./bindgen/0.65.1.nix {
              inherit rustPlatform clang;
            };

            bindgen = pkgs.rust-bindgen.override {
              rust-bindgen-unwrapped = bindgenUnwrapped;
            };
          in
          [
            bindgen
            rust-analyzer
            rustc
          ];

        mkGccShell =
          { gccVersion }:
          pkgs.mkShell {
            packages = linuxCommonDependencies ++ [ pkgs."gcc${gccVersion}" ];

            # Disable all automatically applied hardening. The Linux
            # kernel will take care of itself.
            NIX_HARDENING_ENABLE = "";
          };

        mkClangShell =
          { clangVersion, rustcVersion }:
          let
            llvmPackages = pkgs."llvmPackages_${clangVersion}";
          in
          pkgs.mkShell {
            packages =
              (with llvmPackages; [
                bintools
                clang
                llvm
              ])
              ++ (linuxRustDependencies {
                inherit (llvmPackages) clang;
                rustVersion = "rust_${rustcVersion}";
              })
              ++ linuxCommonDependencies;

            # To force LLVM build mode. This should create less problems
            # with Rust interop.
            LLVM = "1";

            # Disable all automatically applied hardening. The Linux
            # kernel will take care of itself.
            NIX_HARDENING_ENABLE = "";
          };

        # A cross-compilation shell. `crossPkgs` is a cross-compiled
        # package set (e.g. `pkgs.pkgsCross.aarch64-multiplatform`)
        # that provides the target toolchain (gcc + bintools) with the
        # correct `targetPrefix`. All build-side tools (bc, bison,
        # flex, pahole, make, ...) stay native, and a native gcc is
        # kept around as HOSTCC for the host-side helpers the kernel
        # builds out of scripts/.
        mkCrossShell =
          { crossPkgs, arch, gccVersion ? null }:
          let
            crossCc =
              if gccVersion == null then
                crossPkgs.stdenv.cc
              else
                crossPkgs."gcc${gccVersion}".cc or crossPkgs.stdenv.cc;
          in
          pkgs.mkShell {
            packages =
              linuxCommonDependencies
              ++ [
                # Native compiler for host-side tools (HOSTCC).
                pkgs.gcc
                # Target cross toolchain: <prefix>-gcc, <prefix>-ld,
                # <prefix>-objcopy, ...
                crossCc
                crossCc.bintools
              ];

            # Pre-set these so `make defconfig` just works. Users can
            # still override them on the command line.
            ARCH = arch;
            CROSS_COMPILE = crossCc.targetPrefix;

            # Disable all automatically applied hardening. The Linux
            # kernel will take care of itself.
            NIX_HARDENING_ENABLE = "";
          };
      in
      {
        packages = {
          inherit kernelDevTools;
          default = kernelDevTools;
        };

        devShells = {
          default = self.devShells."${system}".linux_6_12;

          linux_6_6 = mkClangShell {
            clangVersion = "19";
            rustcVersion = "1_78_0";
          };
          linux_6_6_gcc = mkGccShell { gccVersion = "14"; };

          linux_6_11 = mkClangShell {
            clangVersion = "19";
            rustcVersion = "1_78_0";
          };
          linux_6_11_gcc = mkGccShell { gccVersion = "14"; };

          linux_6_12 = mkClangShell {
            clangVersion = "19";
            rustcVersion = "1_82_0";
          };
          linux_6_12_gcc = mkGccShell { gccVersion = "14"; };

          # Cross-compilation shells. Build on the host (native) but
          # produce target-arch kernel images. ARCH/CROSS_COMPILE are
          # pre-set, so `make defconfig && make -j$(nproc) Image` is
          # enough. arm64 target image is `Image` (not `bzImage`).
          linux_6_6_cross_aarch64 = mkCrossShell {
            crossPkgs = pkgs.pkgsCross.aarch64-multiplatform;
            arch = "arm64";
          };
          linux_6_11_cross_aarch64 = mkCrossShell {
            crossPkgs = pkgs.pkgsCross.aarch64-multiplatform;
            arch = "arm64";
          };
          linux_6_12_cross_aarch64 = mkCrossShell {
            crossPkgs = pkgs.pkgsCross.aarch64-multiplatform;
            arch = "arm64";
          };
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
