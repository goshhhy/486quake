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
// d_draw16.s
// x86 assembly-language horizontal 8-bpp span-drawing code, with 16-pixel
// subdivision.
//

#include "../asm_i386.h"
#include "../quakeasm.h"
#include "../asm_draw.h"
#include "../d_ifacea.h"

#if	id386

//----------------------------------------------------------------------
// 8-bpp horizontal span drawing code for polygons, with no transparency and
// 16-pixel subdivision.
//
// Assumes there is at least one span in pspans, and that every span
// contains at least one pixel
//----------------------------------------------------------------------

	.data
	.text

// out-of-line, rarely-needed clamping code

LClampHigh0:
	movl	C(bbextents),%esi
	jmp		LClampReentry0
LClampHighOrLow0:
	jg		LClampHigh0
	xorl	%esi,%esi
	jmp		LClampReentry0

LClampHigh1:
	movl	C(bbextentt),%edx
	jmp		LClampReentry1
LClampHighOrLow1:
	jg		LClampHigh1
	xorl	%edx,%edx
	jmp		LClampReentry1

LClampLow2:
	movl	$4096,%ebp
	jmp		LClampReentry2
LClampHigh2:
	movl	C(bbextents),%ebp
	jmp		LClampReentry2

LClampLow3:
	movl	$4096,%ecx
	jmp		LClampReentry3
LClampHigh3:
	movl	C(bbextentt),%ecx
	jmp		LClampReentry3

LClampLow4:
	movl	$4096,%eax
	jmp		LClampReentry4
LClampHigh4:
	movl	C(bbextents),%eax
	jmp		LClampReentry4

LClampLow5:
	movl	$4096,%ebx
	jmp		LClampReentry5
LClampHigh5:
	movl	C(bbextentt),%ebx
	jmp		LClampReentry5


#define pspans	4+16

	.align 4
.globl C(D_DrawSpansCHorz)
C(D_DrawSpansCHorz):

//
// set up scaled-by-16 steps, for 16-long segments; also set up cacheblock
// and span list pointers
//
	pushl	%ebp				// preserve caller's stack frame
	pushl	%edi
	pushl	%esi				// preserve register variables
	pushl	%ebx
	movl	C(cacheblock),%edx
	movl	pspans(%esp),%ebx	// point to the first span descriptor
	movl	%edx,pbase			// pbase = 
	
	//	this was originally on fpu, but doing it in integer is faster
	
	// sdivz16stepu = d_sdivzstepu * 16.0
	movl    $0x2000000, %eax
	addl    C(d_sdivzstepu), %eax
    movl    %eax, sdivz16stepu
	// tdivz16stepu = d_tdivzstepu * 16.0
	movl    $0x2000000, %eax
	addl    C(d_tdivzstepu), %eax
    movl    %eax, tdivz16stepu
	// zi16stepu = d_zistepu * 16.0
	movl    $0x2000000, %eax
	addl    C(d_zistepu), %eax
    movl    %eax, zi16stepu

LSpanLoop:
//
// set up the initial s/z, t/z, and 1/z on the FP stack, and generate the
// initial s and t values
//
// FIXME: pipeline FILD?
//																						:: START
	fildl	espan_t_v(%ebx)     // dv                                                   :: 9-12 : 4 (2-4)
	fsts	ftmp				// dv													:: 7
	fmuls	C(d_sdivzstepv)		// dv*d_sdivzstepv 				                        :: 11	: 8
    fildl	espan_t_u(%ebx)     // du | dv*d_sdivzstepv                              	:: 9-12 : 4 (2-4)
	fsts	ftmp2				// du | dv*d_sdivzstepv									:: 7
	fmuls	C(d_sdivzstepu)		// du*d_sdivzstepu | dv*d_sdivzstepv 			        :: 11	: 8
	faddp	%st(0),%st(1)		// du*d_sdivzstepu + dv*d_sdivzstepv 			        :: 8-20	: 7
	fadds	C(d_sdivzorigin)	// s/z 			                                     	:: 8-20	: 7

	fld		C(d_tdivzstepv)		// d_tdivzstepv | s/z 			                        :: 3
	fmuls	ftmp				// dv*d_tdivzstepv | s/z  			                    :: 11	: 8
	fld		C(d_tdivzstepu)		// d_tdivzstepu | dv*d_tdivzstepv | s/z                 :: 3
	fmuls	ftmp2				// du*d_tdivzstepu | dv*d_tdivzstepv | s/z    			:: 11	: 8
	faddp	%st(0),%st(1)		// du*d_tdivzstepu + dv*d_tdivzstepv | s/z				:: 8-20	: 7
	fadds	C(d_tdivzorigin)	// t/z | s/z 											:: 8-20	: 7

	fld		C(d_zistepv)		// d_zistepv | t/z | s/z                        		:: 3
	fmuls	ftmp				// dv*d_zistepv | t/z | s/z								:: 11	: 8
	fld		C(d_zistepu)		// d_zistepu | dv*d_zistepv | t/z | s/z					:: 3
	fmuls	ftmp2				// du*d_zistepu | dv*d_zistepv | t/z | s/z              :: 11	: 8
	faddp	%st(0),%st(1)		// du*d_zistepu + dv*d_zistepv | t/z | s/z             	:: 8-20	: 7
	fadds	C(d_ziorigin)		// 1/z | t/z | s/z                                      :: 8-20	: 7

	flds	fp_64k				// fp_64k | 1/z | t/z | s/z								:: 3
// calculate and clamp s & t
	fdiv	%st(1),%st(0)		// z*64k | 1/z | t/z | s/z								:: 73 	: 70
// point %edi to the first pixel in the span
		movl	C(d_viewbuffer),%ecx												//	:: 1
		movl	espan_t_v(%ebx),%eax												// 	:: 1
		movl	%ebx,pspantemp	// preserve spans pointer							//	:: 1

		movl	C(tadjust),%edx														//	:: 1
		movl	C(sadjust),%esi														//	:: 1
		movl	C(d_scantable)(,%eax,4),%edi	// v * screenwidth						:: 1
		addl	%ecx,%edi															//	:: 1
		movl	espan_t_u(%ebx),%ecx												//	:: 1
		addl	%ecx,%edi				// pdest = &pdestspan[scans->u];				:: 1
		movl	espan_t_count(%ebx),%ecx											//	:: 1
                                //                                                      :: TOTAL 234-312
								//														::		10 of 168 concurrent cycles filled

//
// now start the FDIV for the end of the span
//
// finish up the s and t calcs
	fld		%st(0)			// z*64k | z*64k | 1/z | t/z | s/z
	fmul	%st(4),%st(0)	// s | z*64k | 1/z | t/z | s/z
	fistpl	s				// z*64k | 1/z | t/z | s/z
	fmul	%st(2),%st(0)	// t | 1/z | t/z | s/z
		cmpl	$16,%ecx
		ja		LCleanup1

		decl	%ecx
		jz		LCleanup1		// if only one pixel, no need to start an FDIV
		movl	%ecx,spancountminus1
	fistpl	t				// 1/z | t/z | s/z

	fildl	spancountminus1		//														:: 9-12
	fsts	ftmp				//														:: 7
	flds	C(d_zistepu)		// C(d_zistepu) | scm1 | 1/z | t/z | s/z				:: 3
	fmuls	ftmp				// C(d_zistepu)*scm1 | scm1 | 1/z | t/z | s/z			:: 11
	faddp	%st(0),%st(2)		// scm1 | 1/z adj | t/z | s/z							:: 8-20
	flds	C(d_tdivzstepu)		// C(d_tdivzstepu) | scm1 | 1/z adj | t/z | s/z			:: 3
	fmuls	ftmp				// C(d_tdivzstepu)*scm1 | scm1 | 1/z adj | t/z | s/z	:: 11
	faddp	%st(0),%st(3)		// scm1 | 1/z adj | t/z adj | s/z						:: 8-20
	fmuls	C(d_sdivzstepu)		// C(d_sdivzstepu)*scm1 | 1/z adj | t/z adj | s/z		:: 11
	faddp	%st(0),%st(3)		// 1/z adj | t/z adj | s/z adj							:: 8-20
								//														:: TOTAL 79-118
								
	flds	fp_64k				// 64k | 1/z adj | t/z adj | s/z adj
	fdiv	%st(1),%st(0)	// this is what we've gone to all this trouble to
							//  overlap

	/*
	fsts	ftmp				// 1/z | t/z | s/z
	movl	$0x86ef72e6,%eax
	subl	ftmp,%eax 
	movl	%eax, ftmp
	flds	ftmp				// z*64k | 1/z | t/z | s/z
	*/

	jmp		LFDIVInFlight1

LCleanup1:
// finish finishing up the s and t calcs
	fistpl	t				// 1/z | t/z | s/z

LFDIVInFlight1:

	addl	s,%esi
	addl	t,%edx
	movl	C(bbextents),%ebx
	movl	C(bbextentt),%ebp
	cmpl	%ebx,%esi
	ja		LClampHighOrLow0
LClampReentry0:
	movl	%esi,s
	movl	pbase,%ebx
	shll	$16,%esi
	cmpl	%ebp,%edx
	movl	%esi,sfracf
	ja		LClampHighOrLow1
LClampReentry1:
	movl	%edx,t
	movl	s,%esi					// sfrac = scans->sfrac;
	shll	$16,%edx
	movl	t,%eax					// tfrac = scans->tfrac;
	sarl	$16,%esi
	movl	%edx,tfracf

//
// calculate the texture starting address
//
	sarl	$16,%eax
	movl	C(cachewidth),%edx
	// FIXME: can we force cachewidth to always be a power of two and turn this into a shift?
	imull	%edx,%eax				// (tfrac >> 16) * cachewidth
	addl	%ebx,%esi
	addl	%eax,%esi				// psource = pbase + (sfrac >> 16) +
									//           ((tfrac >> 16) * cachewidth);
//
// determine whether last span or not
//
	cmpl	$16,%ecx
	jna		LLastSegment

//
// not the last segment; do full 16-wide segment
//
LNotLastSegment:
//
// advance s/z, t/z, and 1/z, and calculate s & t at end of span and steps to
// get there
//

// pick up after the FDIV that was left in flight previously
	fld		%st(0)			// duplicate the z*64k
	fmul	%st(4),%st(0)	// s = s/z * z
		// while that fmul happens (16 cycles, 13 cycle concurrency):
		movb	(%esi),%bl	// get first source texel
		subl	$16,%ecx		// count off this segments' pixels
		movl	C(sadjust),%ebp
		movl	%ecx,counttemp	// remember count of remaining pixels
		movl	C(tadjust),%ecx
		movb	%bl,(%edi)	// store first dest pixel
	fistpl	snext
	fmul	%st(2),%st(0)	// t = t/z * z
		movl	snext,%eax
		addl	%eax,%ebp
		movl	C(bbextents),%eax
	fistpl	tnext

	movl	tnext,%edx
	addl	%edx,%ecx
	movl	C(bbextentt),%edx

	cmpl	$4096,%ebp
	jl		LClampLow2
	cmpl	%eax,%ebp
	ja		LClampHigh2
LClampReentry2:

	cmpl	$4096,%ecx
	jl		LClampLow3
	cmpl	%edx,%ecx
	ja		LClampHigh3
LClampReentry3:

	movl	%ebp,snext
	movl	%ecx,tnext

	subl	s,%ebp
	subl	t,%ecx
	
//
// set up advancetable
//
	movl	%ecx,%eax
	movl	%ebp,%edx
	sarl	$20,%eax			// tstep >>= 16;
	jz		LZero
	sarl	$20,%edx			// sstep >>= 16;
	movl	C(cachewidth),%ebx
	imull	%ebx,%eax
	jmp		LSetUp1

LZero:
	sarl	$20,%edx			// sstep >>= 16;
	movl	C(cachewidth),%ebx

LSetUp1:

	addl	%edx,%eax			// add in sstep
								// (tstep >> 16) * cachewidth + (sstep >> 16);
	movl	tfracf,%edx
	movl	%eax,advancetable+4	// advance base in t
	addl	%ebx,%eax			// ((tstep >> 16) + 1) * cachewidth +
								//  (sstep >> 16);
	shll	$12,%ebp			// left-justify sstep fractional part
	movl	sfracf,%ebx
	shll	$12,%ecx			// left-justify tstep fractional part
	movl	%eax,advancetable	// advance extra in t

	movl	%ecx,tstep
	addl	%ecx,%edx			// advance tfrac fractional part by tstep frac

	sbbl	%ecx,%ecx			// turn tstep carry into -1 (0 if none)
	addl	%ebp,%ebx			// advance sfrac fractional part by sstep frac
	adcl	advancetable+4(,%ecx,4),%esi	// point to next source texel

	addl	tstep,%edx
	sbbl	%ecx,%ecx
	movb	(%esi),%al
	addl	%ebp,%ebx
	movb	%al,1(%edi)
	adcl	advancetable+4(,%ecx,4),%esi

	addl	tstep,%edx
	sbbl	%ecx,%ecx
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi

	addl	tstep,%edx
	sbbl	%ecx,%ecx
	movb	%al,2(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi

	addl	tstep,%edx
	sbbl	%ecx,%ecx
	movb	%al,3(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi

	addl	tstep,%edx
	sbbl	%ecx,%ecx
	movb	%al,4(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi

	addl	tstep,%edx
	sbbl	%ecx,%ecx
	movb	%al,5(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi

	addl	tstep,%edx
	sbbl	%ecx,%ecx
	movb	%al,6(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi

	addl	tstep,%edx
	sbbl	%ecx,%ecx
	movb	%al,7(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi


//
// start FDIV for end of next segment in flight, so it can overlap
//
	movl	counttemp,%ecx
	cmpl	$16,%ecx			// more than one segment after this?
	ja		LFDIVInFlight2		

	decl	%ecx
	jz		LFDIVInFlight2	// if only one pixel, no need to start an FDIV
	movl	%ecx,spancountminus1

	// this is the last segment; start the fdiv for the next line

	fildl	spancountminus1		//														:: 9-12
	fsts	ftmp				//														:: 7
	flds	C(d_zistepu)		// C(d_zistepu) | scm1 | 1/z | t/z | s/z				:: 3
	fmuls	ftmp				// C(d_zistepu)*scm1 | scm1 | 1/z | t/z | s/z			:: 11
	faddp	%st(0),%st(2)		// scm1 | 1/z adj | t/z | s/z							:: 8-20
	flds	C(d_tdivzstepu)		// C(d_tdivzstepu) | scm1 | 1/z adj | t/z | s/z			:: 3
	fmuls	ftmp				// C(d_tdivzstepu)*scm1 | scm1 | 1/z adj | t/z | s/z	:: 11
	faddp	%st(0),%st(3)		// scm1 | 1/z adj | t/z adj | s/z						:: 8-20
	fmuls	C(d_sdivzstepu)		// C(d_sdivzstepu)*scm1 | 1/z adj | t/z adj | s/z		:: 11
	faddp	%st(0),%st(3)		// 1/z adj | t/z adj | s/z adj							:: 8-20
								//														:: TOTAL 79-118


	flds	fp_64k				// 64k | 1/z adj | t/z adj | s/z adj
	fdiv	%st(1),%st(0)	// this is what we've gone to all this trouble to
							//  overlap

LFDIVInFlight2:
	movl	%ecx,counttemp

	addl	tstep,%edx
	sbbl	%ecx,%ecx
	movb	%al,8(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi

	addl	tstep,%edx
	sbbl	%ecx,%ecx
	movb	%al,9(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi

	addl	tstep,%edx
	sbbl	%ecx,%ecx
	movb	%al,10(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi

	addl	tstep,%edx
	sbbl	%ecx,%ecx
	movb	%al,11(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi

	addl	tstep,%edx
	sbbl	%ecx,%ecx
	movb	%al,12(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi

	addl	tstep,%edx
	sbbl	%ecx,%ecx
	movb	%al,13(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi

	addl	tstep,%edx
	sbbl	%ecx,%ecx
	movb	%al,14(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi

	addl	$16,%edi
	movl	%edx,tfracf
	movl	snext,%edx
	movl	%ebx,sfracf
	movl	tnext,%ebx
	movl	%edx,s
	movl	%ebx,t

	movl	counttemp,%ecx		// retrieve count

//
// determine whether last span or not
//
	cmpl	$16,%ecx				// are there multiple segments remaining?
	movb	%al,-1(%edi)
	ja		LNotLastSegment		// yes

//
// last segment of scan
//
LLastSegment:
//
// advance s/z, t/z, and 1/z, and calculate s & t at end of span and steps to
// get there. The number of pixels left is variable, and we want to land on the
// last pixel, not step one past it, so we can't run into arithmetic problems
//
	testl	%ecx,%ecx
	jz		LNoSteps		// just draw the last pixel and we're done
// pick up after the FDIV that was left in flight previously
	fld		%st(0)			// duplicate the z*64k
	fmul	%st(4),%st(0)	// s = s/z * z
		// during that fmul... (16 cycles, 13 concurrent)
		movb	(%esi),%al		// load first texel in segment
		movl	C(tadjust),%ebx
		movb	%al,(%edi)		// store first pixel in segment
		movl	C(sadjust),%eax
	fistpl	snext
	fmul	%st(2),%st(0)	// t = t/z * z
		// during that fmul...
		addl	snext,%eax
		movl	C(bbextents),%ebp
	fistpl	tnext

	addl	tnext,%ebx
	movl	C(bbextentt),%edx

	cmpl	$4096,%eax
	jl		LClampLow4
	cmpl	%ebp,%eax
	ja		LClampHigh4
LClampReentry4:
	movl	%eax,snext

	cmpl	$4096,%ebx
	jl		LClampLow5
	cmpl	%edx,%ebx
	ja		LClampHigh5
LClampReentry5:

	cmpl	$1,%ecx			// don't bother 
	je		LOnlyOneStep	// if two pixels in segment, there's only one step,
							//  of the segment length
	subl	s,%eax
	subl	t,%ebx

	addl	%eax,%eax		// convert to 15.17 format so multiply by 1.31
	addl	%ebx,%ebx		//  reciprocal yields 16.48

	imull	reciprocal_table_16-8(,%ecx,4)	// sstep = (snext - s) /
											//  (spancount-1)
	movl	%edx,%ebp

	movl	%ebx,%eax
	imull	reciprocal_table_16-8(,%ecx,4)	// tstep = (tnext - t) /
											//  (spancount-1)
LSetEntryvec:
//
// set up advancetable
//
	movl	entryvec_table_16(,%ecx,4),%ebx
	movl	%edx,%eax
	movl	%ebx,jumptemp		// entry point into code for RET later
	movl	%ebp,%ecx
	sarl	$16,%edx			// tstep >>= 16;
	movl	C(cachewidth),%ebx
	sarl	$16,%ecx			// sstep >>= 16;
	imull	%ebx,%edx

	addl	%ecx,%edx			// add in sstep
								// (tstep >> 16) * cachewidth + (sstep >> 16);
	movl	tfracf,%ecx
	movl	%edx,advancetable+4	// advance base in t
	addl	%ebx,%edx			// ((tstep >> 16) + 1) * cachewidth +
								//  (sstep >> 16);
	shll	$16,%ebp			// left-justify sstep fractional part
	movl	sfracf,%ebx
	shll	$16,%eax			// left-justify tstep fractional part
	movl	%edx,advancetable	// advance extra in t

	movl	%eax,tstep
	movl	%ecx,%edx
	addl	%eax,%edx
	sbbl	%ecx,%ecx
	addl	%ebp,%ebx
	adcl	advancetable+4(,%ecx,4),%esi

	jmp		*jumptemp			// jump to the number-of-pixels handler

//----------------------------------------

LNoSteps:
	movb	(%esi),%al		// load first texel in segment
	subl	$15,%edi			// adjust for hardwired offset
	jmp		LEndSpan


LOnlyOneStep:
	subl	s,%eax
	subl	t,%ebx
	movl	%eax,%ebp
	movl	%ebx,%edx
	jmp		LSetEntryvec

//----------------------------------------

.globl	Entry2_16, Entry3_16, Entry4_16, Entry5_16
.globl	Entry6_16, Entry7_16, Entry8_16, Entry9_16
.globl	Entry10_16, Entry11_16, Entry12_16, Entry13_16
.globl	Entry14_16, Entry15_16, Entry16_16

Entry2_16:
	subl	$14,%edi		// adjust for hardwired offsets
	movb	(%esi),%al
	jmp		LEntry2_16

//----------------------------------------

Entry3_16:
	subl	$13,%edi		// adjust for hardwired offsets
	addl	%eax,%edx
	movb	(%esi),%al
	sbbl	%ecx,%ecx
	addl	%ebp,%ebx
	adcl	advancetable+4(,%ecx,4),%esi
	jmp		LEntry3_16

//----------------------------------------

Entry4_16:
	subl	$12,%edi		// adjust for hardwired offsets
	addl	%eax,%edx
	movb	(%esi),%al
	sbbl	%ecx,%ecx
	addl	%ebp,%ebx
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
	jmp		LEntry4_16

//----------------------------------------

Entry5_16:
	subl	$11,%edi		// adjust for hardwired offsets
	addl	%eax,%edx
	movb	(%esi),%al
	sbbl	%ecx,%ecx
	addl	%ebp,%ebx
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
	jmp		LEntry5_16

//----------------------------------------

Entry6_16:
	subl	$10,%edi		// adjust for hardwired offsets
	addl	%eax,%edx
	movb	(%esi),%al
	sbbl	%ecx,%ecx
	addl	%ebp,%ebx
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
	jmp		LEntry6_16

//----------------------------------------

Entry7_16:
	subl	$9,%edi		// adjust for hardwired offsets
	addl	%eax,%edx
	movb	(%esi),%al
	sbbl	%ecx,%ecx
	addl	%ebp,%ebx
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
	jmp		LEntry7_16

//----------------------------------------

Entry8_16:
	subl	$8,%edi		// adjust for hardwired offsets
	addl	%eax,%edx
	movb	(%esi),%al
	sbbl	%ecx,%ecx
	addl	%ebp,%ebx
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
	jmp		LEntry8_16

//----------------------------------------

Entry9_16:
	subl	$7,%edi		// adjust for hardwired offsets
	addl	%eax,%edx
	movb	(%esi),%al
	sbbl	%ecx,%ecx
	addl	%ebp,%ebx
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
	jmp		LEntry9_16

//----------------------------------------

Entry10_16:
	subl	$6,%edi		// adjust for hardwired offsets
	addl	%eax,%edx
	movb	(%esi),%al
	sbbl	%ecx,%ecx
	addl	%ebp,%ebx
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
	jmp		LEntry10_16

//----------------------------------------

Entry11_16:
	subl	$5,%edi		// adjust for hardwired offsets
	addl	%eax,%edx
	movb	(%esi),%al
	sbbl	%ecx,%ecx
	addl	%ebp,%ebx
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
	jmp		LEntry11_16

//----------------------------------------

Entry12_16:
	subl	$4,%edi		// adjust for hardwired offsets
	addl	%eax,%edx
	movb	(%esi),%al
	sbbl	%ecx,%ecx
	addl	%ebp,%ebx
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
	jmp		LEntry12_16

//----------------------------------------

Entry13_16:
	subl	$3,%edi		// adjust for hardwired offsets
	addl	%eax,%edx
	movb	(%esi),%al
	sbbl	%ecx,%ecx
	addl	%ebp,%ebx
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
	jmp		LEntry13_16

//----------------------------------------

Entry14_16:
	subl	$2,%edi		// adjust for hardwired offsets
	addl	%eax,%edx
	movb	(%esi),%al
	sbbl	%ecx,%ecx
	addl	%ebp,%ebx
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
	jmp		LEntry14_16

//----------------------------------------

Entry15_16:
	decl	%edi		// adjust for hardwired offsets
	addl	%eax,%edx
	movb	(%esi),%al
	sbbl	%ecx,%ecx
	addl	%ebp,%ebx
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
	jmp		LEntry15_16

//----------------------------------------

Entry16_16:
	addl	%eax,%edx
	movb	(%esi),%al
	sbbl	%ecx,%ecx
	addl	%ebp,%ebx
	adcl	advancetable+4(,%ecx,4),%esi

	addl	tstep,%edx
	sbbl	%ecx,%ecx
	movb	%al,1(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
LEntry15_16:
	sbbl	%ecx,%ecx
	movb	%al,2(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
LEntry14_16:
	sbbl	%ecx,%ecx
	movb	%al,3(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
LEntry13_16:
	sbbl	%ecx,%ecx
	movb	%al,4(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
LEntry12_16:
	sbbl	%ecx,%ecx
	movb	%al,5(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
LEntry11_16:
	sbbl	%ecx,%ecx
	movb	%al,6(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
LEntry10_16:
	sbbl	%ecx,%ecx
	movb	%al,7(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
LEntry9_16:
	sbbl	%ecx,%ecx
	movb	%al,8(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
LEntry8_16:
	sbbl	%ecx,%ecx
	movb	%al,9(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
LEntry7_16:
	sbbl	%ecx,%ecx
	movb	%al,10(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
LEntry6_16:
	sbbl	%ecx,%ecx
	movb	%al,11(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
LEntry5_16:
	sbbl	%ecx,%ecx
	movb	%al,12(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi
	addl	tstep,%edx
LEntry4_16:
	sbbl	%ecx,%ecx
	movb	%al,13(%edi)
	addl	%ebp,%ebx
	movb	(%esi),%al
	adcl	advancetable+4(,%ecx,4),%esi
LEntry3_16:
	movb	%al,14(%edi)
	movb	(%esi),%al
LEntry2_16:

LEndSpan:

//
// clear s/z, t/z, 1/z from FP stack
//
	fstp %st(0)
	fstp %st(0)
	fstp %st(0)

	movl	pspantemp,%ebx				// restore spans pointer
	movl	espan_t_pnext(%ebx),%ebx	// point to next span
	testl	%ebx,%ebx			// any more spans?
	movb	%al,15(%edi)
	jnz		LSpanLoop			// more spans

	popl	%ebx				// restore register variables
	popl	%esi
	popl	%edi
	popl	%ebp				// restore the caller's stack frame
	ret

#endif	// id386
