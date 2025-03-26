# The No-CPU Amiga Demo Challenge

This is an open challenge to create demos that run entirely on the Amiga custom chips without involving the CPU.

This repository contains the rules of the challenge, a [runner](runner) application for launching no-CPU demos, and an example [demo framework](demo) (in [Dart](https://dart.dev/)) for making no-CPU demos.

## Introduction

The Amiga custom chips (affectionately named **Alice**, **Lisa** and **Paula** in the AGA version of the chipset) were remarkably powerful for their time, enabling the Amiga computers - with their modestly-powered CPUs - to perform graphical and musical feats that required heavy computation on most contemporary platforms.

This challenge aims to discover how just powerful these chips really are by exploring what they can do completely on their own, without the CPU even telling them what to do.

The basic idea is to initialize the contents of chip memory to the demo payload, bring the hardware into a well-defined state (in particular, start the copper from a known address) and let the custom chips take it from there. This is feasible due to a number of crucial mechanisms:

- The copper can control all other relevant hardware components - bitplanes, sprites, audio, and the blitter - and can wait for the blitter to finish.
- The copper can set the start addresses of the copper and can trigger jumps to these addresses.
- The blitter can modify copper instructions.

The result is a Turing-complete system with its own unique (and hopefully fun) set of challenges. You are hereby invited to uncover its merits as a demo platform.

## Participation

To take part in the challenge, do the following:

- Make a no-CPU demo in the form of a chip memory image that works with the [official runner](runner). See the [detailed rules](rules.md) for further instructions.
- Enter the demo into a suitable demo competition, or just release it out of compo if you wish. There will be a dedicated no-CPU Amiga demo compo at **[Gerp](https://gerp.traktor.group/) 2026**, where you can compete against similarly restricted demos.
- Write a comment on the [demo announcement issue](https://github.com/askeksa/NoCpuChallenge/issues/1) about your demo.

## Feedback

TBW
