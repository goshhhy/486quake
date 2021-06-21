486quake
========

this is an attempt to ressurect the original Quake DOS sources, clean up the bitrot, build using modern compilers and optimizations, and rewrite the hand-tuned assembly with 486 machines in mind - to see just how fast quake can go.

so far, i already consider it a mild success, and i still believe there to be much room for improvement.

results
=======

the following table lists some known results for 486quake on different machines. there is wide variation between different 486 machines even with the same cpu, so bear that in mind.

these benchmarks are all taken with default settings for screen size and rendering settings.

|         CPU                   |   486quake version    |  Stock FPS    | 486Quake FPS  |
|         ---                   |          ---          |      ---      |      ---      |
| AMD 5x86/133 (Evergreen, WT)  | 1.09 r4               | 10.7          | 12.0          |
| Intel 486 Overdrive DX4/100   | 1.09 r4               | 9.6           | 10.9          |
| Cyrix 486DX2/66               | 1.09 r4               | 6.3           | 7.1           |