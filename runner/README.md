# No-CPU demo runner

This is an application for loading a chip memory image into memory and running it with a well-defined [initial state](../README.md#technical-details). It forms the main demo executable in the distribution of a no-CPU demo.

The memory image is read from a file called `chip.dat` in the current directory. Optionally, it can be compressed using the [ZX0](https://github.com/einar-saukas/ZX0) V2 format and read from `chip.zx0` instead.

The contents of the file are read into chip memory (and optionally decompressed) starting at address 0. If the (decompressed) file is smaller than the size of chip memory, the rest of chip memory is cleared.

The CPU interrupt level is set to 7 while the demo is running, preventing the demo from activating the CPU via an interrupt.

If non-chip memory is available, the original contents of chip memory are preserved while the demo is running, permitting the runner to exit cleanly back to the system.

The runner will exit if the left mouse button is pressed, or if the demo clears the Blitter Nasty flag (bit 10) in DMACON (hardware register `$096`).

If the right mouse button is pressed, the runner will reload the memory image and start over. This can be used for quick testing of new versions during demo development by placing the `chip.dat` file on a network drive (for testing on a real Amiga) or on the host file system (for testing in an emulator).

If the machine has only chip memory, the runner can still load and run the memory image, as long as the file fits in the largest free chunk of chip memory, but it will not be exitable, nor restartable.
