# Foreseeably Asked Questions

## How is it possible to make a demo without using the CPU??

Running a demo only on the Amiga coprocessors is feasible due to a number of crucial mechanisms:

- The copper can control all other relevant hardware components &mdash; bitplanes, sprites, audio, and the blitter &mdash; and can wait for the blitter to finish.
- The copper can set the start addresses of the copper and can trigger jumps to these addresses.
- The blitter can modify copper instructions.

The result is a Turing-complete system with its own unique (and hopefully fun) set of challenges.

All that is needed for the custom chips to do their thing is that the memory is initialized to the demo payload and the hardware put into a well-defined state, in particular starting the copper from a known address.

A demo can progress through its timeline by having one copperlist per frame, with each setting the address of the next one, though this is by no means the only way to structure a no-CPU demo.

Of course, the CPU is needed to load the demo into memory. This challenge setup abstracts away the loading and regards the machine as having initialized memory and no CPU.

## Why allow the AGA chipset when OCS is all the rage these days?

TBW

## How does this challenge relate to Bifat's [Dogma Demomaking](https://www.pouet.net/topic.php?which=12670&page=1) challenge?

The two challenges are unrelated, but compatible. It is absolutely possible to make a no-CPU demo on an Amiga. This might even be a rather pleasant experience, since the demo is unlikely to crash the system during development, due to the sandboxing of the runner.

## How does this challenge relate to [Copper Showdown](https://gitlab.com/akronyme-analogiker/copper-showdown/copper-showdown-editor)?

Copper Showdown is based on a similar idea &mdash; making demo effects that run without using the CPU &mdash; but in the context of live coding rather than ordinary demo competitions.

The two projects were conceived independently at almost the same time, in February/March 2024.

Demos made using Copper Showdown are compatible with the [runner](runner), meaning that the Copper Showdown Editor can be used as a tool to create demos for this challenge. At the time of this writing, exporting a memory image has to be done manually in the Lua code, but an export feature in the editor is planned.

## Is this a new idea, or have no-CPU demos been made in the past?

I have had the idea of a no-CPU Amiga demo competition for several years and mentioned it publicly for the first time [in 2021](https://www.pouet.net/topic.php?which=12123&page=2#c570253).

[A](https://www.pouet.net/prod.php?which=104004) [few](https://www.pouet.net/prod.php?which=104025) demos made using Copper Showdown have been released in 2025, independently of this challenge.

I am not aware of any no-CPU demos being released before 2025.
