# Bootable kernel

This directory now contains the bootable C kernel used by the project build.

The main entry point is `kernel.c`, which compiles into a 16-bit DOS executable
and is flattened into the boot image as `IO.SYS`.

The original assembly sources remain in `src-asm/` for reference and future
porting work.
