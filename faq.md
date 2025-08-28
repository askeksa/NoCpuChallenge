# Frequently Asked Questions

## How is it possible to make a demo without using the CPU??

Running a demo only on the Amiga coprocessors is feasible due to a number of crucial mechanisms:

- The copper can control all other relevant hardware components &mdash; bitplanes, sprites, audio, and the blitter &mdash; and can wait for the blitter to finish.
- The copper can set the start addresses of the copper and can trigger jumps to these addresses.
- The blitter can modify copper instructions.

The result is a Turing-complete system with its own unique (and hopefully fun) set of challenges.

All that is needed for the custom chips to do their thing is that the memory is initialized to the demo payload and the hardware put into a well-defined state, in particular starting the copper from a known address.

A demo can progress through its timeline by having one copperlist per frame, with each setting the address of the next one, though this is by no means the only way to structure a no-CPU demo.

Of course, the CPU is needed to load the demo into memory. This challenge setup abstracts away the loading and regards the machine as having initialized memory and no CPU.

## Is the challenge for OCS or AGA?

Both. You decide which Amiga model to target.

I chose to focus on AGA in the narrative of the challenge demo for several reasons:

- I find that AGA is grossly underutilized in demos. The period from when the AGA chipset was introduced until the "chunky era," when faster CPUs became mainstream, was only a few years; as a consequence, few demos were made that really take advantage of AGA features in a hardware-centric way. The no-CPU approach is an opportunity to rectify this.

- With the CPU out of the picture, OCS doesn’t really provide any interesting challenges compared to AGA. It is no easier or simpler to make no-CPU effects on AGA, as the basic copper/blitter dance is the same. You can just do more with it, due to the additional memory, more bitplanes, less DMA load, wider sprites, and flexible color assignment.

- An Amiga with the CPU turned off is a new platform and thus not bound by any traditions or a fixed reference. Let’s uncover everything it has to offer.

## How does this challenge relate to Bifat's [Dogma Demomaking](https://www.pouet.net/topic.php?which=12670&page=1) challenge?

The two challenges are unrelated, but compatible. It is absolutely possible to make a no-CPU demo on an Amiga. This might even be a rather pleasant experience, since the demo is unlikely to crash the system during development, due to the sandboxing of the runner.

## How does this challenge relate to [Copper Showdown](https://gitlab.com/akronyme-analogiker/copper-showdown/copper-showdown-editor)?

Copper Showdown is based on a similar idea &mdash; making demo effects that run without using the CPU &mdash; but in the context of live coding rather than ordinary demo competitions.

The two projects were conceived independently at almost the same time, in February/March 2024.

Demos made using Copper Showdown are compatible with the [runner](runner), meaning that the Copper Showdown Editor can be used as a tool to create demos for this challenge. At the time of this writing, exporting a memory image has to be done manually in the Lua code, but an export feature in the editor is planned.

## Is this a new idea, or have no-CPU demos been made in the past?

I have had the idea of a no-CPU Amiga demo competition for several years and mentioned it publicly for the first time [in 2021](https://www.pouet.net/topic.php?which=12123&page=2#c570253).

[A](https://www.pouet.net/prod.php?which=104004) [few](https://www.pouet.net/prod.php?which=104025) [demos](https://www.pouet.net/prod.php?which=104792) made using Copper Showdown have been released in 2025, independently of this challenge.

A blitter implementation of Game of Life was made by Tomas Rokicki [in 1986](https://usenet.trashworldnews.com/?thread=245812). In 2024, [Piru](https://github.com/piruhttps://github.com/piru) released a [proof-of-concept implementation](https://infosec.exchange/@harrysintonen/112627238742582618) driven by the copper without CPU involvement, demonstrating the Turing completeness of the copper/blitter system.

I am not aware of any no-CPU demos being released before 2024.
