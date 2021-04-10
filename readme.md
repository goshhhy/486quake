486quake
========

this is an attempt at building quake in a way that allows it to be faster on 486-class machines.

additional changes of note:
- Win95 MPATH net driver removed
    - not easy/possible to build without win95 sdk
    - this means no tcp/ip networking is available without the Beame & Whiteside tcp/ip stack (QKEPPP20.ZIP)