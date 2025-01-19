# The No-CPU Amiga Demo Challenge

This is an open challenge to create demos that run entirely on the Amiga custom chips without involving the CPU.

This repository contains the rules of the challenge, a [runner](runner) application for launching no-CPU demos, and an example [demo framework](demo) (in [Dart](https://dart.dev/)) for making no-CPU demos.

## Introduction

The Amiga custom chips (affectionately named **Alice**, **Lisa** and **Paula** in the AGA version of the chipset) were remarkably powerful for their time, enabling the Amiga computers - with their modestly-powered CPUs - to perform graphical and musical feats that required heavy computation on most contemporary platforms.

This challenge aims to discover how powerful these chips really are by exploring what they can do completely on their own, without the CPU even telling them what to do.

The basic idea is to initialize the contents of chip memory to the demo payload, bring the hardware into a well-defined state (in particular, start the copper from a known address) and let the custom chips take it from there. This is feasible due to a number of crucial mechanisms:

- The copper can control all other relevant hardware components - bitplanes, sprites, audio, and the blitter - and can wait for the blitter to finish.
- The copper can set the start addresses of the copper and can trigger jumps to these addresses.
- The blitter can modify copper instructions.

The result is a Turing-complete system with its own unique (and hopefully fun) set of challenges. Perhaps it will establish itself as a demo platform in its own right that people will continually develop new techniques for and thereby surpass each other in excellence as the years go by.
