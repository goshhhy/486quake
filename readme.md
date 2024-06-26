486quake
========

this repository contains 486quake, a fork of the original Quake sources with MS-DOS support restored,
targeting era-appropriate hardware from the time of Quake's release.

486quake does not add substantial functionality or bugfixes over the original Quake release. instead, it
focuses on further optimizing the engine, and re-optimizing portions of it to run better on non-Pentium
processors.

despite the name, 486quake is not exclusively targeted at 486 processors. it has specific assembly
optimizations for Intel 486, Pentium, and Cyrix 486 processors, and most other x86-compatible processors
will work with at least one of these builds. non-intel processors are also supported, though they will
only benefit from broader engine optimizations in 486quake, and not dedicated hand-optimized assembly.

486quake does not currently address 64-bit portability issues, and is not tested on 64-bit systems. it 
will likely only work properly on 32-bit platforms.

building
========

on a unix-like host machine with a djgpp cross-compiler, source djgpp's environment script.

then, from this source directory, you can just run

    make

this will build the standard 486quake binary by default.

to build all binaries, you can run the `build_all.sh` script.

advanced build options
======================

you can pass the following options to `make` to change parameters of the build:

OLEVEL: optimization level passed to compiler. defaults to "-O3".
OCPU: CPU target. valid options are "386, 486, cx4, 586, mmx, 686". defaults to 486.
OLTO: controls whether LTO is used. defaults to "yes", any other value means no.
OASM: controls whether hand-written assembly is used. defaults to "yes", any other value means no.
OSTRIP: strip options passed to compiler. defaults to "-s".

results
=======

the following tables list some known results for 486quake on different machines. there is wide variation between different boards even with the same cpu, so bear that in mind.

these benchmarks are all taken with default screen size and rendering settings.

## PC Chips M919 (Socket 3)
* 48MiB 60ns EDO RAM
* S3 Trio64V+ 2MiB PCI
* no L2 cache

|         CPU                   |  Stock FPS    | 486quake r6   |
|         ---                   |      ---      |      ---      |
| AMD 5x86/133                  | 16.4          | 18.4          |
| Intel 486DX4/100              | 9.6           | 10.9          |
| Cyrix 486DX2/66               | 6.3           | 7.1           |

## PC Chips M560 (Socket 7)
* 128MiB Kingston SDRAM
* S3 Trio64V+ 2MiB PCI

|         CPU                   |  Stock FPS    | 486quake r6   | 586quake r6   |
|         ---                   |      ---      |      ---      |     ---       |
| Pentium 133 (P54C)            | 35.6          | 39.6          | **41.0**      |
| AMD K6/166                    | 32.5 |        | **37.8**      | 36.9          |
| AMD K6/133                    | 28.5          | **33.0**      | 32.2          |
| Cyrix 6x86MX PR166            | 26.3          | **30.3**      | 29.7          |
| AMD K5 PR133                  | 25.8          | 28.9          | **29.0**      |
| Cyrix 6x86 PR166              | 23.9          | **27.9**      | 27.1          |
| Cyrix 6x86L PR166             | 23.5          | **27.6**      | 27.1          |
