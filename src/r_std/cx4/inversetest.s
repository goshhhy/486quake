
	.data


LTmp0:			.single		0.0
LTmp1:			.single		0.0
fp_64k:			.single		65536.0
fp_1:           .single     1.0

	.text


// returns 65536/x, where x is the float stored in %st(0)
// in: %st(0), out: %st(0), clobber: %eax
Inverse64k:
	flds	fp_64k                  // :: 3 cycles
	fdiv	%st(1),%st(0)           // :: 73 cycles
    ret                             // :: 5 cycles
    // Total on i486: 81 cycles  

// same as Inverse64k, but faster (and less accurate)
// in: %st(0), out: %st(0), clobber: %eax, %ecx, LTmp0, LTmp1
FastInverse64k:
    fsts    LTmp0                                           // :: 3 cycles
    // evil divide N by 65536.0
    movl    LTmp0,%eax                                      // :: 1 cycle
    leal    0xf8000000(%eax),%ecx                          // :: 1 cycle
    movl    %ecx,LTmp1                                      // :: 1 cycle
    // evil divide 65536.0 by N
    movl    $0x86f311c4, %ecx                               // :: 1 cycle
    subl    %eax,%ecx                                       // :: 1 cycle
    movl    %ecx,Ltmp0                                     // :: 1 cycle
    // standard boring newton's method to refine the result
    flds    Ltmp0           // y                            // :: 7 cycles
    fmuls   Ltmp1           // y * x                        // :: 11 cycles
    fsubr   fp_1            // 1 - (y * x)                  // :: 10 cycles
    fmul    Ltmp0           // y * ( 1 - (y * x ) )         // :: 11 cycles
    fadd    Ltmp0           // y + ( y * ( 1 - (y * x ) ) ) // :: 10 cycles
    ret                                                     // :: 5 cycles
    // Total on i486: 63 cycles
    // for typical inputs, relative error is 0.123% avg 0.255% max
    // (~0.8 screenspace pixels of distortion for texture mapping)

// same as Inverse64k, but much faster (and less accurate)
// in: %st(0), out: %st(0), clobber: %eax, LTmp0
VeryFastInverse64k:
	fsts	LTmp0				    // :: 7 cycles
    // wtf???
	movl	$0x86f311c4,%eax        // :: 1 cycle
	subl	LTmp0,%eax               // :: 1 cycle
	movl	%eax, LTmp0              // :: 1 cycle
	flds	LTmp0                    // :: 3 cycles
    ret                             // :: 5 cycles
    // Total on i486: 18 cycles
    // for typical inputs, relative error is 3.12% avg, 5.05% max
    // (~16 screenspace pixels of distortion for texture mapping)
