/*
Copyright (C) 1996-1997 Id Software, Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

*/
//
// math.s
// x86 assembly-language math routines.

#define GLQUAKE	1	// don't include unneeded defs
#include "../asm_i386.h"
#include "../quakeasm.h"


#if	id386

	.data

	.align	4
Ljmptab:	.long	Lcase0, Lcase1, Lcase2, Lcase3
			.long	Lcase4, Lcase5, Lcase6, Lcase7

	.text

// TODO: rounding needed?
// stack parameter offset
#define	val	4

.globl C(Invert24To16)
C(Invert24To16):

	movl	val(%esp),%ecx
	movl	$0x100,%edx		// 0x10000000000 as dividend
	cmpl	%edx,%ecx
	jle		LOutOfRange

	subl	%eax,%eax
	divl	%ecx

	ret

LOutOfRange:
	movl	$0xFFFFFFFF,%eax
	ret

#define	in	8
#define out	12

.globl C(fm_a)
.globl C(fm_b)
.globl C(fm_outf)
.globl C(fm_outi)

	.align 2
.globl C(TransformVector)
C(TransformVector):
							//															START CYRIX TIMING
	pushl	%edi			//															::				2
	movl	8(%esp),%edi	//															::				2
	// fpu: do first round of dot product multiplies
	flds	C(vright)		// vright[0]												::	5
	flds	C(vup)			// vup[0] | vright[0]										::	5
	flds	C(vpn)			// vpn[0] | vup[0] | vright[0]								::	5
	flds	(%edi)			// in[0] | vpn[0] | vup[0] | vright[0]						::	5
	fmul	%st(0),%st(1)	// in[0] | in[0]*vpn[0] | vup[0] | vright[0]				::	12(10)
		// integer: setup
		pushl	%ebx																//	::				2
		movl	16(%esp),%ebx														//	::				2
		pushl	%esi																//	::				2
		pushl	%eax																//	::				2
		movl	8(%edi), %ecx														//	:: 				2

	fmul	%st(0),%st(2)	// in[0] | in[0]*vpn[0] | in[0]*vup[0] | vright[0]			::	12(10)
		// integer: in[2] * vpn[2]
		movl	C(vpn)+8, %esi													//	:: 				2
		movl	%ecx, %edx															//	:: 				1
		movl	%ecx, C(fm_a)

		movl	%esi, %eax															//	:: 				1
		movl	%esi, C(fm_b)

		pushf

        andl    $0x7fffffff, %edx                               //              :: 1
        cmpl    $0, %edx                                        //              :: 1
        jz      FmulZero

        andl    $0x7fffffff, %eax                               //              :: 1
        cmpl    $0, %eax                                        //              :: 1
        jz      FmulZero

		popf

        shrl    $8, %eax                                      		    //              :: 				1
        orw     $0x8000, %ax                                            //              :: 				1
		shrl    $8, %edx                                        		//              :: 				1
        orw     $0x8000, %dx                                    		//              :: 				1

	fmulp	%st(0),%st(3)	// in[0]*vpn[0] | in[0]*vup[0] | in[0]*vright[0]			::	12(10)
        mul     %dx                 // dx = unnormalized mantissa result   			    :: 				3
        mov     %esi, %eax                                      		//              :: 				1
        shrl    $23, %ecx           // ecx = (a) 1s.8e                          		:: 				1
        shrl    $23, %eax           // eax = (b) 1s.8e                         			:: 				1
	 	addb    %cl, %al           //            add 8 bit exponents            		:: 				1
        movb    %dh, %cl                                        //              		:: 				1
        shrb    $7, %cl                                         //              		:: 				1
        addb    %cl, %al           //            normalization correction       		:: 				1
        xor     $1, %cl                                         //              		:: 				1

	// fpu: do second round of dot product multiplies
	flds	C(vpn)+4		// vpn[1]													::	5
	flds	C(vup)+4		// vup[1] | vpn[1]											::	5
	flds	C(vright)+4		// vright[1] | vup[1] | vpn[1]								::	5
	flds	4(%edi)			// in[1] | vright[1] | vup[1] | vpn[1]						::	5	fmuls	C(vpn)+4		// in[1]*vpn[1] | ...										::	13(8)
	fmul	%st(0), %st(1)	// in[1] | in[1]*vright[1] | vup[1] | vpn[1]				::	12(10)
        addb    $-127, %al         //            exponent bias correction       		:: 				1
        addb    $8, %cl             //      cl = normalization shift amount     		:: 				1
        xorb    %ch, %ah            //          sign calculation                		:: 				1
		shll    $23, %eax           //      esi = 1s.8e.23blank                 		:: 				1
        shll    %cl, %edx                                       //              		:: 				1
        andl    $0x7fffff, %edx     //      edx = mantissa                      		:: 				1
        orl     %edx, %eax                                      //              		:: 				1
        movl    %eax, C(fm_outi)                                    //              		:: 				2
	fmul	%st(0), %st(2)	// in[1] | in[1]*vright[1] | in[1]*vup[1] | vpn[1]			::	12(10)
	fmulp	%st(0), %st(3)	// in[1]*vright[1] | in[1]*vup[1] | in[1]*vpn[1]				::	12(10)

	faddp	%st(0),%st(5)	// in[1]*vup[1] | in[1]*vpn[1] | ...						::	10-16(8-14)
	faddp	%st(0),%st(3)	// in[1]*vpn[1] | ...										::	10-16(8-14)
	faddp	%st(0),%st(1)	// vpn_accum | vup_accum | vright_accum						::	10-16(8-14)
 
	flds	C(vpn)+8		// vpn[2]													::	5
	flds	C(vup)+8		// vup[2] | vpn[2]											::	5
	flds	C(vright)+8		// vright[2] | vup[2] | vpn[2]								::	5
	flds	8(%edi)			// in[2] | vright[2] | vup[2] | vpn[2]						::	5
	fmul	%st(0), %st(1)			// in[2] | in[2]*vright[2] | vup[2] | vpn[2]				::	12(10)
	fmul	%st(0), %st(2)			// in[2] | in[2]*vright[2] | in[2]*vup[2] | vpn[2]			::	12(10)
	fmulp	%st(0), %st(3)			// in[2]*vright[2] | in[2]*vup[2] | in[2]*vpn[2]			::	12(10)
	
	faddp	%st(0),%st(5)	// in[2]*vup[2] | in[2]*vpn[2] | ...						::	8-20(7)
	faddp	%st(0),%st(3)	// in[2]*vpn[2] | ...										::	8-20(7)
	fsts	C(fm_outf)
	//flds	C(fm_outi)
	faddp	%st(0),%st(1)
	//fadds	ftmp	// vpn_accum | vup_accum | vright_accum						::	8-20(7)

		popl %eax
		popl %esi

	fstps	8(%ebx)			// out[2]													::	7
	fstps	4(%ebx)			// out[1]													::	7
	fstps	(%ebx)			// out[0]													::	7

	popl	%ebx
	popl	%edi

	ret																				//	:: 10
	//																					:: TOTAL 261-299 (156-192? concurrent, 0 used)

FmulZero:
	fmulp	%st(0),%st(3)	// in[0]*vpn[0] | in[0]*vup[0] | in[0]*vright[0]			::	12(10)
		popf
		
	// fpu: do second round of dot product multiplies
	flds	C(vpn)+4		// vpn[1]													::	5
	flds	C(vup)+4		// vup[1] | vpn[1]											::	5
	flds	C(vright)+4		// vright[1] | vup[1] | vpn[1]								::	5
	flds	4(%edi)			// in[1] | vright[1] | vup[1] | vpn[1]						::	5	fmuls	C(vpn)+4		// in[1]*vpn[1] | ...										::	13(8)
	fmul	%st(0), %st(1)	// in[1] | in[1]*vright[1] | vup[1] | vpn[1]				::	12(10)
	fmul	%st(0), %st(2)	// in[1] | in[1]*vright[1] | in[1]*vup[1] | vpn[1]			::	12(10)
	fmulp	%st(0), %st(3)	// in[1]*vright[1] | in[1]*vup[1] | in[1]*vpn[1]				::	12(10)
		mov		$0, %eax
		mov		%eax, C(fm_outi)

	faddp	%st(0),%st(5)	// in[1]*vup[1] | in[1]*vpn[1] | ...						::	10-16(8-14)
	faddp	%st(0),%st(3)	// in[1]*vpn[1] | ...										::	10-16(8-14)
	faddp	%st(0),%st(1)	// vpn_accum | vup_accum | vright_accum						::	10-16(8-14)
 
	flds	C(vpn)+8		// vpn[2]													::	5
	flds	C(vup)+8		// vup[2] | vpn[2]											::	5
	flds	C(vright)+8		// vright[2] | vup[2] | vpn[2]								::	5
	flds	8(%edi)			// in[2] | vright[2] | vup[2] | vpn[2]						::	5
	fmul	%st(0), %st(1)			// in[2] | in[2]*vright[2] | vup[2] | vpn[2]				::	12(10)
	fmul	%st(0), %st(2)			// in[2] | in[2]*vright[2] | in[2]*vup[2] | vpn[2]			::	12(10)
	fmulp	%st(0), %st(3)			// in[2]*vright[2] | in[2]*vup[2] | in[2]*vpn[2]			::	12(10)
	
	faddp	%st(0),%st(5)	// in[2]*vup[2] | in[2]*vpn[2] | ...						::	8-20(7)
	faddp	%st(0),%st(3)	// in[2]*vpn[2] | ...										::	8-20(7)
	fstp	%st(0)
	fldz
	fsts	C(fm_outf)
	faddp	%st(0),%st(1)
	//fadds	ftmp	// vpn_accum | vup_accum | vright_accum						::	8-20(7)

		popl %eax
		popl %esi

	fstps	8(%ebx)			// out[2]													::	7
	fstps	4(%ebx)			// out[1]													::	7
	fstps	(%ebx)			// out[0]													::	7

	popl	%ebx
	popl	%edi

	ret																				//	:: 10

#define EMINS	4+4
#define EMAXS	4+8
#define P		4+12

	.align 2
.globl C(BoxOnPlaneSide)
C(BoxOnPlaneSide):
	pushl	%ebx

	movl	P(%esp),%edx
	movl	EMINS(%esp),%ecx
	xorl	%eax,%eax
	movl	EMAXS(%esp),%ebx
	movb	pl_signbits(%edx),%al
	cmpb	$8,%al
	jge		Lerror
	flds	pl_normal(%edx)		// p->normal[0]
	fld		%st(0)				// p->normal[0] | p->normal[0]
	jmp		Ljmptab(,%eax,4)


//dist1= p->normal[0]*emaxs[0] + p->normal[1]*emaxs[1] + p->normal[2]*emaxs[2];
//dist2= p->normal[0]*emins[0] + p->normal[1]*emins[1] + p->normal[2]*emins[2];
Lcase0:
	fmuls	(%ebx)				// p->normal[0]*emaxs[0] | p->normal[0]
	flds	pl_normal+4(%edx)	// p->normal[1] | p->normal[0]*emaxs[0] |
								//  p->normal[0]
	fxch	%st(2)				// p->normal[0] | p->normal[0]*emaxs[0] |
								//  p->normal[1]
	fmuls	(%ecx)				// p->normal[0]*emins[0] |
								//  p->normal[0]*emaxs[0] | p->normal[1]
	fxch	%st(2)				// p->normal[1] | p->normal[0]*emaxs[0] |
								//  p->normal[0]*emins[0]
	fld		%st(0)				// p->normal[1] | p->normal[1] |
								//  p->normal[0]*emaxs[0] |
								//  p->normal[0]*emins[0]
	fmuls	4(%ebx)				// p->normal[1]*emaxs[1] | p->normal[1] |
								//  p->normal[0]*emaxs[0] |
								//  p->normal[0]*emins[0]
	flds	pl_normal+8(%edx)	// p->normal[2] | p->normal[1]*emaxs[1] |
								//  p->normal[1] | p->normal[0]*emaxs[0] |
								//  p->normal[0]*emins[0]
	fxch	%st(2)				// p->normal[1] | p->normal[1]*emaxs[1] |
								//  p->normal[2] | p->normal[0]*emaxs[0] |
								//  p->normal[0]*emins[0]
	fmuls	4(%ecx)				// p->normal[1]*emins[1] |
								//  p->normal[1]*emaxs[1] |
								//  p->normal[2] | p->normal[0]*emaxs[0] |
								//  p->normal[0]*emins[0]
	fxch	%st(2)				// p->normal[2] | p->normal[1]*emaxs[1] |
								//  p->normal[1]*emins[1] |
								//  p->normal[0]*emaxs[0] |
								//  p->normal[0]*emins[0]
	fld		%st(0)				// p->normal[2] | p->normal[2] |
								//  p->normal[1]*emaxs[1] |
								//  p->normal[1]*emins[1] |
								//  p->normal[0]*emaxs[0] |
								//  p->normal[0]*emins[0]
	fmuls	8(%ebx)				// p->normal[2]*emaxs[2] |
								//  p->normal[2] |
								//  p->normal[1]*emaxs[1] |
								//  p->normal[1]*emins[1] |
								//  p->normal[0]*emaxs[0] |
								//  p->normal[0]*emins[0]
	fxch	%st(5)				// p->normal[0]*emins[0] |
								//  p->normal[2] |
								//  p->normal[1]*emaxs[1] |
								//  p->normal[1]*emins[1] |
								//  p->normal[0]*emaxs[0] |
								//  p->normal[2]*emaxs[2]
	faddp	%st(0),%st(3)		//p->normal[2] |
								// p->normal[1]*emaxs[1] |
								// p->normal[1]*emins[1]+p->normal[0]*emins[0]|
								// p->normal[0]*emaxs[0] |
								// p->normal[2]*emaxs[2]
	fmuls	8(%ecx)				//p->normal[2]*emins[2] |
								// p->normal[1]*emaxs[1] |
								// p->normal[1]*emins[1]+p->normal[0]*emins[0]|
								// p->normal[0]*emaxs[0] |
								// p->normal[2]*emaxs[2]
	fxch	%st(1)				//p->normal[1]*emaxs[1] |
								// p->normal[2]*emins[2] |
								// p->normal[1]*emins[1]+p->normal[0]*emins[0]|
								// p->normal[0]*emaxs[0] |
								// p->normal[2]*emaxs[2]
	faddp	%st(0),%st(3)		//p->normal[2]*emins[2] |
								// p->normal[1]*emins[1]+p->normal[0]*emins[0]|
								// p->normal[0]*emaxs[0]+p->normal[1]*emaxs[1]|
								// p->normal[2]*emaxs[2]
	fxch	%st(3)				//p->normal[2]*emaxs[2] +
								// p->normal[1]*emins[1]+p->normal[0]*emins[0]|
								// p->normal[0]*emaxs[0]+p->normal[1]*emaxs[1]|
								// p->normal[2]*emins[2]
	faddp	%st(0),%st(2)		//p->normal[1]*emins[1]+p->normal[0]*emins[0]|
								// dist1 | p->normal[2]*emins[2]

	jmp		LSetSides

//dist1= p->normal[0]*emins[0] + p->normal[1]*emaxs[1] + p->normal[2]*emaxs[2];
//dist2= p->normal[0]*emaxs[0] + p->normal[1]*emins[1] + p->normal[2]*emins[2];
Lcase1:
	fmuls	(%ecx)				// emins[0]
	flds	pl_normal+4(%edx)
	fxch	%st(2)
	fmuls	(%ebx)				// emaxs[0]
	fxch	%st(2)
	fld		%st(0)
	fmuls	4(%ebx)				// emaxs[1]
	flds	pl_normal+8(%edx)
	fxch	%st(2)
	fmuls	4(%ecx)				// emins[1]
	fxch	%st(2)
	fld		%st(0)
	fmuls	8(%ebx)				// emaxs[2]
	fxch	%st(5)
	faddp	%st(0),%st(3)
	fmuls	8(%ecx)				// emins[2]
	fxch	%st(1)
	faddp	%st(0),%st(3)
	fxch	%st(3)
	faddp	%st(0),%st(2)

	jmp		LSetSides

//dist1= p->normal[0]*emaxs[0] + p->normal[1]*emins[1] + p->normal[2]*emaxs[2];
//dist2= p->normal[0]*emins[0] + p->normal[1]*emaxs[1] + p->normal[2]*emins[2];
Lcase2:
	fmuls	(%ebx)				// emaxs[0]
	flds	pl_normal+4(%edx)
	fxch	%st(2)
	fmuls	(%ecx)				// emins[0]
	fxch	%st(2)
	fld		%st(0)
	fmuls	4(%ecx)				// emins[1]
	flds	pl_normal+8(%edx)
	fxch	%st(2)
	fmuls	4(%ebx)				// emaxs[1]
	fxch	%st(2)
	fld		%st(0)
	fmuls	8(%ebx)				// emaxs[2]
	fxch	%st(5)
	faddp	%st(0),%st(3)
	fmuls	8(%ecx)				// emins[2]
	fxch	%st(1)
	faddp	%st(0),%st(3)
	fxch	%st(3)
	faddp	%st(0),%st(2)

	jmp		LSetSides

//dist1= p->normal[0]*emins[0] + p->normal[1]*emins[1] + p->normal[2]*emaxs[2];
//dist2= p->normal[0]*emaxs[0] + p->normal[1]*emaxs[1] + p->normal[2]*emins[2];
Lcase3:
	fmuls	(%ecx)				// emins[0]
	flds	pl_normal+4(%edx)
	fxch	%st(2)
	fmuls	(%ebx)				// emaxs[0]
	fxch	%st(2)
	fld		%st(0)
	fmuls	4(%ecx)				// emins[1]
	flds	pl_normal+8(%edx)
	fxch	%st(2)
	fmuls	4(%ebx)				// emaxs[1]
	fxch	%st(2)
	fld		%st(0)
	fmuls	8(%ebx)				// emaxs[2]
	fxch	%st(5)
	faddp	%st(0),%st(3)
	fmuls	8(%ecx)				// emins[2]
	fxch	%st(1)
	faddp	%st(0),%st(3)
	fxch	%st(3)
	faddp	%st(0),%st(2)

	jmp		LSetSides

//dist1= p->normal[0]*emaxs[0] + p->normal[1]*emaxs[1] + p->normal[2]*emins[2];
//dist2= p->normal[0]*emins[0] + p->normal[1]*emins[1] + p->normal[2]*emaxs[2];
Lcase4:
	fmuls	(%ebx)				// emaxs[0]
	flds	pl_normal+4(%edx)
	fxch	%st(2)
	fmuls	(%ecx)				// emins[0]
	fxch	%st(2)
	fld		%st(0)
	fmuls	4(%ebx)				// emaxs[1]
	flds	pl_normal+8(%edx)
	fxch	%st(2)
	fmuls	4(%ecx)				// emins[1]
	fxch	%st(2)
	fld		%st(0)
	fmuls	8(%ecx)				// emins[2]
	fxch	%st(5)
	faddp	%st(0),%st(3)
	fmuls	8(%ebx)				// emaxs[2]
	fxch	%st(1)
	faddp	%st(0),%st(3)
	fxch	%st(3)
	faddp	%st(0),%st(2)

	jmp		LSetSides

//dist1= p->normal[0]*emins[0] + p->normal[1]*emaxs[1] + p->normal[2]*emins[2];
//dist2= p->normal[0]*emaxs[0] + p->normal[1]*emins[1] + p->normal[2]*emaxs[2];
Lcase5:
	fmuls	(%ecx)				// emins[0]
	flds	pl_normal+4(%edx)
	fxch	%st(2)
	fmuls	(%ebx)				// emaxs[0]
	fxch	%st(2)
	fld		%st(0)
	fmuls	4(%ebx)				// emaxs[1]
	flds	pl_normal+8(%edx)
	fxch	%st(2)
	fmuls	4(%ecx)				// emins[1]
	fxch	%st(2)
	fld		%st(0)
	fmuls	8(%ecx)				// emins[2]
	fxch	%st(5)
	faddp	%st(0),%st(3)
	fmuls	8(%ebx)				// emaxs[2]
	fxch	%st(1)
	faddp	%st(0),%st(3)
	fxch	%st(3)
	faddp	%st(0),%st(2)

	jmp		LSetSides

//dist1= p->normal[0]*emaxs[0] + p->normal[1]*emins[1] + p->normal[2]*emins[2];
//dist2= p->normal[0]*emins[0] + p->normal[1]*emaxs[1] + p->normal[2]*emaxs[2];
Lcase6:
	fmuls	(%ebx)				// emaxs[0]
	flds	pl_normal+4(%edx)
	fxch	%st(2)
	fmuls	(%ecx)				// emins[0]
	fxch	%st(2)
	fld		%st(0)
	fmuls	4(%ecx)				// emins[1]
	flds	pl_normal+8(%edx)
	fxch	%st(2)
	fmuls	4(%ebx)				// emaxs[1]
	fxch	%st(2)
	fld		%st(0)
	fmuls	8(%ecx)				// emins[2]
	fxch	%st(5)
	faddp	%st(0),%st(3)
	fmuls	8(%ebx)				// emaxs[2]
	fxch	%st(1)
	faddp	%st(0),%st(3)
	fxch	%st(3)
	faddp	%st(0),%st(2)

	jmp		LSetSides

//dist1= p->normal[0]*emins[0] + p->normal[1]*emins[1] + p->normal[2]*emins[2];
//dist2= p->normal[0]*emaxs[0] + p->normal[1]*emaxs[1] + p->normal[2]*emaxs[2];
Lcase7:
	fmuls	(%ecx)				// emins[0]
	flds	pl_normal+4(%edx)
	fxch	%st(2)
	fmuls	(%ebx)				// emaxs[0]
	fxch	%st(2)
	fld		%st(0)
	fmuls	4(%ecx)				// emins[1]
	flds	pl_normal+8(%edx)
	fxch	%st(2)
	fmuls	4(%ebx)				// emaxs[1]
	fxch	%st(2)
	fld		%st(0)
	fmuls	8(%ecx)				// emins[2]
	fxch	%st(5)
	faddp	%st(0),%st(3)
	fmuls	8(%ebx)				// emaxs[2]
	fxch	%st(1)
	faddp	%st(0),%st(3)
	fxch	%st(3)
	faddp	%st(0),%st(2)

LSetSides:

//	sides = 0;
//	if (dist1 >= p->dist)
//		sides = 1;
//	if (dist2 < p->dist)
//		sides |= 2;

	faddp	%st(0),%st(2)		// dist1 | dist2
	fcomps	pl_dist(%edx)
	xorl	%ecx,%ecx
	fnstsw	%ax
	fcomps	pl_dist(%edx)
	andb	$1,%ah
	xorb	$1,%ah
	addb	%ah,%cl

	fnstsw	%ax
	andb	$1,%ah
	addb	%ah,%ah
	addb	%ah,%cl

//	return sides;

	popl	%ebx
	movl	%ecx,%eax	// return status

	ret


Lerror:
	call	C(BOPS_Error)

#endif	// id386
