

#include "../asm_i386.h"
#include "../quakeasm.h"

#define	in	4
#define out	8

.LC0:
        .long   1077936128
.LC1:
        .long   1084227584
.LC2:
        .long   1073741824
.LC3:
        .long   2143289344
.align 2
.globl C(Qm_FpIuSequential)
C(Qm_FpIuSequential):
        pushl   %ebx
        subl    $24, %esp
        flds    36(%esp)
        flds    32(%esp)
        fnstcw  6(%esp)
        movw    6(%esp), %ax
        orb     $12, %ah
        movw    %ax, 4(%esp)
        fldcw   4(%esp)
        fistl   (%esp)
        fldcw   6(%esp)
        fxch    %st(1)
        movl    (%esp), %eax
        fldcw   4(%esp)
        fistl   (%esp)
        fldcw   6(%esp)
        movl    (%esp), %ecx
        leal    3(%ecx), %edx
        leal    5(%eax), %ebx
        imull   %ebx, %edx
        imull   %ecx, %eax
        leal    2(%edx,%eax), %eax
        movl    %eax, 20(%esp)
        flds    .LC0
        fadd    %st(1), %st
        flds    .LC1
        fadd    %st(3), %st
        fmulp   %st, %st(1)
        fxch    %st(2)
        fmulp   %st, %st(1)
        faddp   %st, %st(1)
        fadds   .LC2
        addl    $24, %esp
        popl    %ebx
        ret

.align 2
.globl C(Qm_FpIuInterleaved)
C(Qm_FpIuInterleaved):
        pushl   %ebx
        subl    $24, %esp
        flds    36(%esp)
        flds    32(%esp)

        fnstcw  6(%esp)
        movw    6(%esp), %ax
        orb     $12, %ah
        movw    %ax, 4(%esp)
        fldcw   4(%esp)
        fistl   (%esp)
        fldcw   6(%esp)
        fxch    %st(1)
        movl    (%esp), %eax
        fldcw   4(%esp)
        fistl   (%esp)
        fldcw   6(%esp)
        movl    (%esp), %ecx

        leal    3(%ecx), %edx
        leal    5(%eax), %ebx

                    flds    .LC0
                    fadd    %st(1), %st
        imull   %ebx, %edx
                    flds    .LC1
                    fadd    %st(3), %st
        imull   %ecx, %eax
                    fmulp   %st, %st(1)
        leal    2(%edx,%eax), %eax
                    fxch    %st(2)
                    fmulp   %st, %st(1)
        movl    %eax, 20(%esp)
                    faddp   %st, %st(1)
        addl    $24, %esp
                    fadds   .LC2
        popl    %ebx
        ret