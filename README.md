# The No-CPU Amiga Demo Challenge

This is an open challenge to create demos that run entirely on the Amiga custom chips without involving the CPU.

This repository contains the rules of the challenge and a [runner](runner) application for launching no-CPU demos. This is intended as a standard specification of the no-CPU platform for demo competitions.

There will be a dedicated no-CPU Amiga demo competition at [**Gerp 2026**](https://gerp.nu/), January 23-25, 2026. In addition, this is an ongoing challenge &mdash; an invitation to explore a different kind of demo platform.

An [invitation demo](https://www.pouet.net/prod.php?which=104753) &mdash; itself a no-CPU demo &mdash; was released at **Evoke 2025**. The full source code for the demo is available [here](https://github.com/askeksa/NoCpuDemo). I also guested [h0ffman's weekly live stream](https://www.twitch.tv/djh0ffman) to talk about the demo and the challenge. You can watch the recording of our conversation [on YouTube](https://youtu.be/M5olYsUhPqg).

Whenever you release a no-CPU demo, you are encouraged to write a comment about it on the [demo announcement issue](https://github.com/askeksa/NoCpuChallenge/issues/1).

There's also a [FAQ](faq.md).

## Background

The Amiga custom chips (affectionately named **Alice**, **Lisa** and **Paula** in the AGA version of the chipset) were remarkably powerful for their time, enabling the Amiga computers &mdash; with their modestly-powered CPUs &mdash; to perform graphical and musical feats that required heavy computation on most contemporary platforms.

This challenge aims to discover just how powerful these chips really are by exploring what they can do completely on their own, without the CPU even telling them what to do.

There have been several demo competitions in the past with a technical theme. Examples include [Atari zero bitplane](https://sommarhack.se/2024/compo.php#themed1), [Atari mixed-resolution](https://sommarhack.se/2025/compo.php#themed), [C64 only sprites](https://csdb.dk/event/?id=3003) and [C64 border only](https://csdb.dk/event/?id=3021). This is a similar idea for the Amiga &mdash; no CPU, custom chips only.

## Technical details

A no-CPU demo takes the form of a raw memory image that specifies the initial contents of chip memory. Together with the initial state of the hardware registers (specified below) this memory image fully defines the demo.

The memory image is loaded into memory by a [runner](runner) application, which serves as the demo executable. You can use the runner as is or modify it to your liking, but in order to qualify as a no-CPU demo according to this challenge, your chip memory image has to work with the official runner (with the same behavior).

The maximum size of the chip memory image depends on the targeted Amiga chipset: 512k for OCS, 1MB for ECS (or OCS with ECS Agnus and 512k expansion, [likely](https://eab.abime.net/showthread.php?t=120351&page=2) the most common Amiga 500 configuration), and 2MB for AGA.

The audio filter is disabled. Since the filter is controlled via the CIA registers, which the copper does not have access to, the demo does not have the option of enabling the filter.

The initial hardware register contents are as follows. Registers with ECS/AGA specific bits are generally initialized to their OCS defaults. This makes it easier to make a demo targeting OCS without worrying about AGA compatibility (as long as you are not using incompatible features, such as the 7 bitplane trick).

| Register | Address   | Value   | Comment |
|----------|-----------|--------:|---------|
| VPOSW    | `$dff02a` | `$8000` | Long frames |
| COPCON   | `$dff02e` | `$0002` | Copper danger flag set |
| COP1LC   | `$dff080` | `$000000` | Copper initially starts at address 0 |
| DMACON   | `$dff096` | `$87c0` | Bitplane, copper and blitter DMA enabled, sprite DMA disabled, Blitter Nasty set |
| ADKCON   | `$dff09e` | `$xx00` | All modulation disabled |
| BPLCON0  | `$dff100` | `$0200` | OCS default |
| BPLCON1  | `$dff102` | `$0000` | OCS default |
| BPLCON2  | `$dff104` | `$0024` | OCS default |
| BPLCON3  | `$dff106` | `$0c00` | OCS default |
| BPLCON4  | `$dff10c` | `$0011` | OCS default |
| COLOR00  | `$dff180` | `$000`  | Black background |
| BEAMCON0 | `$dff1dc` | `$0020` | PAL |
| FMODE    | `$dff1fc` | `$0000` | OCS default |

The values of all other registers are undefined.

The demo can signal that it has ended by clearing the Blitter Nasty flag (i.e. by executing the copper instruction $0096,$0400). Depending on the hardware configuration, the runner may not actually be able to exit back to the OS, so the demo should still maintain a valid display.

## Feedback

If you have questions or comments, you are welcome to [open an issue](https://github.com/askeksa/NoCpuChallenge/issues/new). I am particularly interested in feedback in these areas:

- If there are any bugs or missing features in the runner that makes it unsuitable as the main executable for your demo.
- If there is something in the rules or the runner that you think puts undue limits on what no-CPU demos can do under this formalism.
- If you find a security hole in the runner sandbox, enabling a demo to reactivate the CPU.
