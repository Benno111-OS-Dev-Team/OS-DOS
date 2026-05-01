
# OS-DOS

This repository now builds a bootable floppy image containing a small C kernel.

The boot path is:

1. `src/kernel.c` is compiled as a 16-bit DOS executable with Open Watcom.
2. The executable is flattened into `IO.SYS`.
3. The boot image builder writes a FAT12 floppy image that boots into that
   kernel.

The original assembly sources are still available in `src-asm/`.
