

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
        fwait
        movl    (%esp), %eax
        addl    $12, %esp
        addl    $-2147483648, %eax
        ret


.LCPI4_0:
        .long   0x40a00000                      # float 5
a:
        .long   0                               # 0x0
        
.align 2
.globl C(Qm_FpIuEmulatorCheck)
C(Qm_FpIuEmulatorCheck):
        subl    $8, %esp
        movl    12(%esp), %eax
        movl    $0, a
        movl    %eax, (%esp)
        fildl   (%esp)
        fadds   .LCPI4_0
        fistpl  a
        movl    a, %eax
        addl    $8, %esp
        retl


.align 2
.globl C(Qm_FpRegSpeedTest)
C(Qm_FpRegSpeedTest):
        subl    $8, %esp
        movl    12(%esp), %eax
        movl    $0, a
        movl    %eax, (%esp)
        flds   (%esp)
        fldl    %st(0)
        fmul    %st(1)
        fmul    %st(1)
        fmul    %st(1)
        fmul    %st(1)
        fmul    %st(1)
        fmul    %st(1)
        fmul    %st(1)
        fmulp    %st(1)
        fistp   a
        movl    a, %eax
        addl    $8, %esp
        retl

.align 2
.globl C(Qm_FpMemSpeedTest)
C(Qm_FpMemSpeedTest):
        subl    $8, %esp
        movl    12(%esp), %eax
        movl    $0, a
        movl    %eax, (%esp)
        flds   (%esp)
        fldl    %st(0)
        fmul    a
        fmul    a
        fmul    a
        fmul    a
        fmul    a
        fmul    a
        fmul    a
        fmul    a
        fistp   a
        movl    a, %eax
        addl    $8, %esp
        retl