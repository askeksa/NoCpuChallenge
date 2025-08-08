# Foreseeably Asked Questions

## How is it possible to make a demo without using the CPU??

Running a demo only on the Amiga coprocessors is feasible due to a number of crucial mechanisms:

- The copper can control all other relevant hardware components - bitplanes, sprites, audio, and the blitter - and can wait for the blitter to finish.
- The copper can set the start addresses of the copper and can trigger jumps to these addresses.
- The blitter can modify copper instructions.

The result is a Turing-complete system with its own unique (and hopefully fun) set of challenges.

All that is needed for the custom chips to do their thing is that the memory is initialized to the demo payload and the hardware put into a well-defined state, in particular starting the copper from a known address.

A demo can progress through its timeline by having one copperlist per frame, with each setting the address of the next one, though this is by no means the only way to structure a no-CPU demo.

Of course, the CPU is needed to load the demo into memory. This challenge setup abstracts away the loading and regards the machine as having initialized memory and no CPU.

## How does this challenge relate to the Copper Showdown Editor?

TBW

## How does this challenge relate to Bifat's Dogma Demomaking challenge?

TBW

## Why allow the AGA chipset when OCS is all the rage these days?

TBW
