486quake
========

this is an attempt to ressurect the original Quake DOS sources, clean up the bitrot, build using modern compilers and optimizations, and rewrite the hand-tuned assembly with 486 machines in mind - to see just how fast quake can go.

so far, i already consider it a mild success, and i still believe there to be much room for improvement.

building
=======

first, install a working copy of djgpp somewhere on your host build machine, and
source its environment script as in the djgpp instructions.

then, simply run "make" on a shell in this source directory.

running
=======

to give you an idea what executable to run, you can use the "qmark" benchmarking
tool. if it says that your cpu benefits from fxch optimizations, then you should
run the 586quake binary. otherwise, the 486quake binary should get you the best
results.

if your cpu is new enough to support the CMOV instructions (pentium pro or later)
then you might achieve better results with the 686quake binary.

if you have a 386-class machine, you should only need to run the 386quake binary
if the 486quake one crashes - though there is a slight chance that the 386quake
binary may run faster for you.

fpm (fixed point math)
===

the "fpm" variant is an experimental version which replaces the standard floating
point rendering code with a fixed-point math implementation. unlike the standard
version, which is an attempt to improve speed without any compromises, this may
result in lower visual quality in some scenarios. this is based on code written
by Dan East for PocketQuake.

this will be faster than the standard version on 486-class machines, but keep in
mind that it is not an apples-to-apples comparison between this and the standard
version of the code, or to stock quake. 

results
=======

the following table lists some known results for 486quake on different machines. there is wide variation between different 486 machines even with the same cpu, so bear that in mind.

these benchmarks are all taken with default settings for screen size and rendering settings.

|         CPU                   |   486quake version    |  Stock FPS    | 486Quake FPS  |
|         ---                   |          ---          |      ---      |      ---      |
| AMD 5x86/133 (Evergreen, WT)  | 1.09 r4               | 10.7          | 12.0          |
| Intel 486 Overdrive DX4/100   | 1.09 r4               | 9.6           | 10.9          |
| Cyrix 486DX2/66               | 1.09 r4               | 6.3           | 7.1           |