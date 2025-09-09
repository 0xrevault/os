# Firmware-monorepo

A monorepo containing everything needed to build a complete embedded Linux platform: kernel, bootloader, root-fs helpers and QT-based UI.


### Building locally

```bash
# fetch submodules
$ git submodule update --init --recursive

# apply patches & build kernel (requires cross-compiler in PATH)
$ chmod +x system/toolchain/*.sh
$ system/toolchain/apply_linux_patches.sh submodules/linux patches/linux
$ system/toolchain/build_linux_ci.sh submodules/linux $(nproc)
```

Kernel build outputs land in `out/`.

