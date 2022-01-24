486quake
========

this repository contains a fork of the original Quake sources, with build support for MS-DOS restored.

functionality remains almost identical. the primary goal is to re-optimize the assembly sources, focusing on non-pentium processors common in the mid-90s, such as the 486, Cyrix 6x86, and AMD K5/K6, focusing specifically on the 486 as a baseline.

this is both for fun, and in the interest of exploring the question of whether these competitors might have been more dominant if Quake had not so strongly favored the Pentium.

building
========

on a unix or posix-like host machine with a djgpp cross-compiler, source djgpp's environment script.

then, from this source directory, you can just run

    make

this will build the standard 486quake binary by default.

to build all binaries, you can run the `build_all.sh` script.

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
