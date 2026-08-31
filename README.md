# Linux Kernel Development Environment via Nix

Welcome to a streamlined Linux kernel development setup using Nix
flakes. This project simplifies the process of setting up a
development environment for the Linux kernel, ensuring that you have
all the necessary dependencies, including specific versions of Rust
and bindgen, preinstalled in a devShell.

## Quick Start

Getting started with your kernel development environment is incredibly
simple. If you're aiming to develop for Linux version 6.12, all you
need is a single command:

```shell
linux$ nix develop github:blitz/kernel-dev#linux_6_12
```

This will drop you into a shell with all the dependencies required for
working on the Linux 6.12 kernel preinstalled. Check the `devShells` attribute
in `flake.nix` to find all available shells.

### Features

- **Simplicity**: Forget about the hassle of managing multiple
  dependencies and their versions. One command is all it takes.
- **Reproducibility**: With Nix flakes, your development environment
  is reproducible, ensuring that your setup is always consistent and
  predictable.
- **Version-specific environments**: Tailored development environments
  for specific Linux kernel versions, starting with Linux 6.8.
- **Rust and LLVM-enabled**: Ready for the future of kernel development!

### Requirements

- Nix package manager with flake support enabled.

## Usage

To start developing for a different version of the Linux kernel, use
the following pattern, replacing linux_6_8 with the target version
(note: versions are added based on community contributions and
demand):

```shell
$ nix develop github:blitz/kernel-dev#linux_<major_version>_<minor_version>
```

This will drop you in a shell with `clang` and `rustc` matching the
kernel version. If you need a `gcc`-based environment, use:

```shell
$ nix develop github:blitz/kernel-dev#linux_<major_version>_<minor_version>_gcc
```

If you don't find the exact version that you need, one that is close
_might_ work as well.

## Cross-Compilation

In addition to native environments, this flake provides
cross-compilation shells. They build on your host (native) machine but
produce kernel images for a different architecture. Right now
`aarch64` (arm64) is supported, via nixpkgs'
`pkgsCross.aarch64-multiplatform` toolchain:

```shell
linux$ nix develop github:blitz/kernel-dev#linux_6_12_cross_aarch64
```

Inside the shell, `ARCH` and `CROSS_COMPILE` are already pre-set, so
the usual commands just work:

```shell
make defconfig
make -j$(nproc) Image      # arm64 target image is `Image`, not `bzImage`
```

`HOSTCC` is also taken care of: a native `gcc` is provided for the
host-side helpers the kernel builds out of `scripts/`.

If you use the `enter-kernel-dev` helper, add `--arch`:

```shell
$ enter-kernel-dev --arch aarch64 v6.12
```

### Notes

- Only the pure-C cross toolchain is provided in these shells; Rust
  for the kernel is not wired up for cross targets yet. Use the native
  clang shells (`linux_<ver>`) for Rust kernel work.
- Other architectures can be added by pointing `mkCrossShell` at a
  different `pkgs.pkgsCross.*` set in `flake.nix`.

## Contributing

Contributions are welcome! Whether it's adding support for new kernel
versions, improving the setup process, or documentation - feel free to
fork the project and submit a pull request.

## License

This project is open source and available under the MIT License.
