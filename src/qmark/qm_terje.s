

#include "../asm_i386.h"
#include "../quakeasm.h"

#define	in	4
#define out	8

.MAGIC:
        .long   0x59800004  

.align 2
.globl C(Qm_FpIntStd)
C(Qm_FpIntStd):
        subl    $8, %esp
        fnstcw  6(%esp)
        movw    6(%esp), %ax
        orb     $12, %ah
        movw    %ax, 4(%esp)
        flds    12(%esp)
        fldcw   4(%esp)

        fistpl  (%esp)          //28-34 cycles
        
        fldcw   6(%esp)
        movl    (%esp), %eax
        addl    $8, %esp
        ret

.align 2
.globl C(Qm_FpIntTerje)
C(Qm_FpIntTerje):
        subl    $12, %esp
        
        flds    .MAGIC          // 3 cycles
        fadds   16(%esp)        // 8-20 cycles
        fstpl   (%esp)          // 7 cycles
        
        movl    (%esp), %eax
        addl    $12, %esp
        addl    $-2147483648, %eax
        ret