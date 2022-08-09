

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


.align 2
.globl C(Qm_FpIuRealFmul)
C(Qm_FpIuRealFmul):
        flds    4(%esp)
        fmuls   8(%esp)
        ret

.align 2
.globl C(Qm_FpIuEmuFmul)
C(Qm_FpIuEmuFmul):
        pushl   %edi                                                    //      :: 4
        pushl   %esi                                                    //      :: 4
        pushl   %eax                                                    //      :: 4

        movl    16(%esp), %eax                                          //      :: 1
        movl    %eax, %ecx                                              //      :: 1
        shrl    $8, %ecx                                                //      :: 2
        orl     $32768, %ecx                    # imm = 0x8000          //      :: 1
        movzwl  %cx, %ecx                                               //      :: 3
        movl    20(%esp), %edx                                          //      :: 1
        movl    %eax, %esi                                              //      :: 1
        movl    %edx, %edi                                              //      :: 1
        andl    $-2147483648, %eax              # imm = 0x80000000      //      :: 1
        addl    %edx, %eax                                              //      :: 1
        shrl    $8, %edx                                                //      :: 2
        orl     $32768, %edx                    # imm = 0x8000          //      :: 1
        movzwl  %dx, %edx                                               //      :: 3
        imull   %ecx, %edx                                              //      :: 25-26
        movl    %edx, %ecx                                              //      :: 1
        shrl    $31, %ecx                                               //      :: 2
        shrl    $23, %esi                                               //      :: 2
        shrl    $23, %edi                                               //      :: 2
        addl    %esi, %edi                                              //      :: 1
        addl    %ecx, %edi                                              //      :: 1
        addb    $7, %cl                                                 //      :: 1
        shrl    %cl, %edx                                               //      :: 3
        andl    $8388607, %edx                  # imm = 0x7fffff        //      :: 1
        shll    $23, %edi                                               //      :: 2
        addl    $1082130432, %edi               # imm = 0x40800000      //      :: 1
        andl    $2139095040, %edi               # imm = 0x7F800000      //      :: 1
        andl    $-2147483648, %eax              # imm = 0x80000000      //      :: 1
        orl     %edi, %eax                                              //      :: 1
        orl     %edx, %eax                                              //      :: 1
        movl    %eax, (%esp)                                            //      :: 1
        flds    (%esp)                                                  //      :: 3
        addl    $4, %esp                                                //      :: 1
        popl    %esi                                                    //      :: 4
        popl    %edi                                                    //      :: 4
        retl                                                            //      :: 3

                                                                        //      TOTAL 93-94


/*              FMUL emulation for Cyrix
        
                This routine is meant as a reference, for interleaving within real FPU
                instructions (e.g. vector transforms) to offload calculations to the
                integer unit when no other suitable work is available. 

                works at "two thirds" precision: exponent is retained, but multiply
                result is only 16 bits, not 24. this is plenty good enough for Quake. */
.align 2
.globl C(Qm_FpIuEmuFmulCyrixNoZero)
C(Qm_FpIuEmuFmulCyrixNoZero):
        // setup
        pushl   %esi                                            //              :: 2
        pushl   %eax                                            //              :: 2
        
        // the actual multiplication code
        movl    12(%esp), %ecx                                  //              :: 2
        movl    16(%esp), %esi                                  //              :: 2
        movl    %ecx, %edx                                      //              :: 1
        movl    %esi, %eax                                      //              :: 1
        shrl    $8, %eax                                        //              :: 1
        orw     $0x8000, %ax                                    //              :: 1
        shrl    $8, %edx                                        //              :: 1
        orw     $0x8000, %dx                                    //              :: 1
        mul     %dx                 // dx = unnormalized mantissa result        :: 3
        mov     %esi, %eax                                      //              :: 1
        shrl    $23, %ecx           // ecx = (a) 1s.8e                          :: 1
        shrl    $23, %eax           // eax = (b) 1s.8e                          :: 1
        addb    %cl, %al           //            add 8 bit exponents            :: 1
        movb    %dh, %cl                                        //              :: 1
        shrb    $7, %cl                                         //              :: 1
        addb    %cl, %al           //            normalization correction       :: 1
        xor     $1, %cl                                         //              :: 1
        addb    $-127, %al         //            exponent bias correction       :: 1
        addb    $8, %cl             //      cl = normalization shift amount     :: 1
        xorb    %ch, %ah            //          sign calculation                :: 1
        shll    $23, %eax           //      esi = 1s.8e.23blank                 :: 1
        shll    %cl, %edx                                       //              :: 1
        andl    $0x7fffff, %edx     //      edx = mantissa                      :: 1
        orl     %edx, %eax                                      //              :: 1
        movl    %eax, (%esp)                                    //              :: 2
                                                                //              :: SUBTOTAL 30
        // cleanup
        flds    (%esp)                                          //              :: 5
        addl    $4, %esp                                        //              :: 1
        popl    %esi                                            //              :: 3
        ret                                                     //              :: 10
                                                                //              :: TOTAL 53 

.align 2
.globl C(Qm_FpIuEmuFmulCyrix)
C(Qm_FpIuEmuFmulCyrix):
        // setup
        pushl   %esi                                            //              :: 2
        pushl   %eax                                            //              :: 2
        
        // the actual multiplication code
        movl    12(%esp), %ecx                                  //              :: 2
        movl    16(%esp), %esi                                  //              :: 2
        movl    %ecx, %edx                                      //              :: 1
        movl    %esi, %eax                                      //              :: 1

        andl    $0x7fffffff, %edx                               //              :: 1
        cmpl    $0, %edx                                        //              :: 1
        jz      FmulZero

        andl    $0x7fffffff, %eax                               //              :: 1
        cmpl    $0, %eax                                        //              :: 1
        jz      FmulZero

        shrl    $8, %eax                                        //              :: 1
        orw     $0x8000, %ax                                    //              :: 1
        shrl    $8, %edx                                        //              :: 1
        orw     $0x8000, %dx                                    //              :: 1
        mul     %dx                 // dx = unnormalized mantissa result        :: 3
        mov     %esi, %eax                                      //              :: 1
        shrl    $23, %ecx           // ecx = (a) 1s.8e                          :: 1
        shrl    $23, %eax           // eax = (b) 1s.8e                          :: 1
        addb    %cl, %al           //            add 8 bit exponents            :: 1
        movb    %dh, %cl                                        //              :: 1
        shrb    $7, %cl                                         //              :: 1
        addb    %cl, %al           //            normalization correction       :: 1
        xor     $1, %cl                                         //              :: 1
        addb    $-127, %al         //            exponent bias correction       :: 1
        addb    $8, %cl             //      cl = normalization shift amount     :: 1
        xorb    %ch, %ah            //          sign calculation                :: 1
        shll    $23, %eax           //      esi = 1s.8e.23blank                 :: 1
        shll    %cl, %edx                                       //              :: 1
        andl    $0x7fffff, %edx     //      edx = mantissa                      :: 1
        orl     %edx, %eax                                      //              :: 1
        movl    %eax, (%esp)                                    //              :: 2
                                                                //              :: SUBTOTAL 30
        // cleanup
        flds    (%esp)                                          //              :: 5
        addl    $4, %esp                                        //              :: 1
        popl    %esi                                            //              :: 3
        ret                                                     //              :: 10
                                                                //              :: TOTAL 53 
FmulZero:

        fldz                                                    //              :: 5
        addl    $4, %esp                                        //              :: 1
        popl    %esi                                            //              :: 3
        ret                                                     //              :: 10

.macro nops count=1
nop
.if \count>1
nops "(\count-1)"
.endif
.endm

.macro Qm_FmulStConcurrencyTest count=1
.align 2
.globl C(Qm_FmulStConcurrencyTest\count)
C(Qm_FmulStConcurrencyTest\count):
        fld1
        fldpi
        fmulp %st(1),%st(0)
        nops \count
        fstp %st(0)
        ret
.endm

Qm_FmulStConcurrencyTest 0
Qm_FmulStConcurrencyTest 1
Qm_FmulStConcurrencyTest 2
Qm_FmulStConcurrencyTest 3
Qm_FmulStConcurrencyTest 4
Qm_FmulStConcurrencyTest 5
Qm_FmulStConcurrencyTest 6
Qm_FmulStConcurrencyTest 7
Qm_FmulStConcurrencyTest 8
Qm_FmulStConcurrencyTest 9
Qm_FmulStConcurrencyTest 10