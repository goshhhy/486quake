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
// r_aliasa.s
// x86 assembly-language Alias model transform and project code.
//

#include "../asm_i386.h"
#include "../quakeasm.h"
#include "../asm_draw.h"
#include "../d_ifacea.h"

#if id386

	.data
Ltemp0:	.long	0
Ltemp1:	.long	0

	.text

#define pfv0		8+4
#define pfv1		8+8
#define out			8+12

.globl C(R_Alias_clip_bottom)
C(R_Alias_clip_bottom):
	pushl	%esi
	pushl	%edi

	movl	pfv0(%esp),%esi
	movl	pfv1(%esp),%edi

	movl	C(r_refdef)+rd_aliasvrectbottom,%eax

LDoForwardOrBackward:

	movl	fv_v+4(%esi),%edx
	movl	fv_v+4(%edi),%ecx

	cmpl	%ecx,%edx
	jl		LDoForward

	movl	fv_v+4(%esi),%ecx
	movl	fv_v+4(%edi),%edx
	movl	pfv0(%esp),%edi
	movl	pfv1(%esp),%esi

LDoForward:

	subl	%edx,%ecx
	subl	%edx,%eax
	movl	%ecx,Ltemp1
	movl	%eax,Ltemp0
	fildl	Ltemp1
	fildl	Ltemp0
	movl	out(%esp),%edx
	movl	$2,%eax

	fdivp	%st(0),%st(1)					// scale
// takes 7 cycles to write scale to ftmp, but saves 5 cycles per fmul + 3 cycles for later `fstp %st(0)` = 18 cycles, net 11 saved
	fstps	ftmp	

LDo3Forward:
	fildl	fv_v+0(%esi)	// fv0v0
	fildl	fv_v+0(%edi)	// fv1v0 | fv0v0
	fsub	%st(1),%st(0)	// fv1v0-fv0v0 | fv0v0
	fmuls	ftmp			// (fv1v0-fv0v0)*scale | fv0v0
	faddp	%st(0), %st(1)	// fv0v0+(fv1v0-fv0v0)*scale
	fadds	float_point5

	fildl	fv_v+4(%esi)	// fv0v1 | 
	fildl	fv_v+4(%edi)	// fv1v1 | fv0v1 | fv0v0+(fv1v0-fv0v0)*scale
	fsub	%st(1),%st(0)	// fv1v1-fv0v1 | fv0v1 | fv0v0+(fv1v0-fv0v0)*scale
	fmuls	ftmp			// (fv1v1-fv0v1)*scale | fv0v0+(fv1v0-fv0v0)*scale
	faddp	%st(0), %st(1)	// fv0v1+(fv1v1-fv0v1)*scale | fv0v0+(fv1v0-fv0v0)*scale
	fadds	float_point5

	fildl	fv_v+8(%esi)	// fv0v2 | fv0v1+(fv1v1-fv0v1)*scale | fv0v0+(fv1v0-fv0v0)*scale
	fildl	fv_v+8(%edi)	// fv1v2 | fv0v2 | fv0v1+(fv1v1-fv0v1)*scale | fv0v0+(fv1v0-fv0v0)*scale
	fsub	%st(1),%st(0)	// fv1v2-fv0v2 | fv0v1+(fv1v1-fv0v1)*scale | fv0v0+(fv1v0-fv0v0)*scale
	fmuls	ftmp			// (fv1v2-fv0v2)*scale | fv0v1+(fv1v1-fv0v1)*scale | fv0v0+(fv1v0-fv0v0)*scale
		addl	$12,%edi
		addl	$12,%esi
		addl	$12,%edx
	faddp	%st(0), %st(1)	// fv0v2+(fv1v2-fv0v2)*scale | fv0v1+(fv1v1-fv0v1)*scale | fv0v0+(fv1v0-fv0v0)*scale
	fadds	float_point5
	
	fistpl	fv_v+8-12(%edx) // fv0v1+(fv1v1-fv0v1)*scale | fv0v0+(fv1v0-fv0v0)*scale
	fistpl	fv_v+4-12(%edx) // fv0v0+(fv1v0-fv0v0)*scale
	fistpl	fv_v+0-12(%edx)

	decl	%eax
	jnz		LDo3Forward

	//fstp	%st(0)

	popl	%edi
	popl	%esi

	ret


.globl C(R_Alias_clip_top)
C(R_Alias_clip_top):
	pushl	%esi
	pushl	%edi

	movl	pfv0(%esp),%esi
	movl	pfv1(%esp),%edi

	movl	C(r_refdef)+rd_aliasvrect+4,%eax
	jmp		LDoForwardOrBackward



.globl C(R_Alias_clip_right)
C(R_Alias_clip_right):
	pushl	%esi
	pushl	%edi

	movl	pfv0(%esp),%esi
	movl	pfv1(%esp),%edi

	movl	C(r_refdef)+rd_aliasvrectright,%eax

LRightLeftEntry:


	movl	fv_v+4(%esi),%edx
	movl	fv_v+4(%edi),%ecx

	cmpl	%ecx,%edx
	movl	fv_v+0(%esi),%edx

	movl	fv_v+0(%edi),%ecx
	jl		LDoForward2

	movl	fv_v+0(%esi),%ecx
	movl	fv_v+0(%edi),%edx
	movl	pfv0(%esp),%edi
	movl	pfv1(%esp),%esi

LDoForward2:

	jmp		LDoForward


.globl C(R_Alias_clip_left)
C(R_Alias_clip_left):
	pushl	%esi
	pushl	%edi

	movl	pfv0(%esp),%esi
	movl	pfv1(%esp),%edi

	movl	C(r_refdef)+rd_aliasvrect+0,%eax
	jmp		LRightLeftEntry


#endif	// id386

