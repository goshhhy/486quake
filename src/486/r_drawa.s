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
// r_drawa.s
// x86 assembly-language edge clipping and emission code
//

#include "../asm_i386.h"
#include "../quakeasm.h"
#include "../asm_draw.h"
#include "../d_ifacea.h"

#if	id386

// !!! if these are changed, they must be changed in r_draw.c too !!!
#define FULLY_CLIPPED_CACHED	0x80000000
#define FRAMECOUNT_MASK			0x7FFFFFFF

	.data

Ld0:			.single		0.0
Ld1:			.single		0.0
Lstack:			.long		0
Lfp_near_clip:	.single		NEAR_CLIP
Lceilv0:		.long		0
Lv:				.long		0
Lu0:			.long		0
Lv0:			.long		0
Lzi0:			.long		0

	.text

//----------------------------------------------------------------------
// edge clipping code
//----------------------------------------------------------------------

#define pv0		4+12
#define pv1		8+12
#define clip	12+12

	.align 4
.globl C(R_ClipEdge)
C(R_ClipEdge):
	pushl	%esi				// preserve register variables
	pushl	%edi
	pushl	%ebx
	movl	%esp,Lstack			// for clearing the stack later

//	float		d0, d1, f;
//	mvertex_t	clipvert;

	movl	clip(%esp),%ebx
	movl	pv0(%esp),%esi
	movl	pv1(%esp),%edx

//	if (clip)
//	{
	testl	%ebx,%ebx
	jz		Lemit

//		do
//		{

Lcliploop:

//			d0 = DotProduct (pv0->position, clip->normal) - clip->dist;
//			d1 = DotProduct (pv1->position, clip->normal) - clip->dist;
	flds	mv_position+0(%esi)   	// p0
	fmuls	cp_normal+0(%ebx)     	// d0mul0
	flds	mv_position+8(%esi)   	// p2 | d0mul0
	fmuls	cp_normal+8(%ebx)		// d0mul2 | d0mul0
	flds	mv_position+4(%esi)   	// p1 | d0mul2 | d0mul0
	fmuls	cp_normal+4(%ebx)     	// d0mul1 | d0mul2 | d0mul0
	faddp	%st(0),%st(2)			// d0mul2 | d0add0
	faddp	%st(0),%st(1)			// dot0
	fsubs	cp_dist(%ebx)			// d0
	fstps	Ld0

	flds	mv_position+0(%edx)		// p0
	fmuls	cp_normal+0(%ebx)		// d1mul0
	flds	mv_position+8(%edx)		// p2 | d1mul0
	fmuls	cp_normal+8(%ebx)		// d1mul2 | d1mul0
	flds	mv_position+4(%edx)		// p1 | d1mul2 | d1mul0
	fmuls	cp_normal+4(%ebx)		// d1mul1 | d1mul2 | d1add0
	faddp	%st(0),%st(2)			// d1mul2 | d1add0
	faddp	%st(0),%st(1)			// dot1
	fsubs	cp_dist(%ebx)			// d1
	
	movl	Ld0,%eax
	fstps	Ld1
	movl	Ld1,%ecx
//			if (d0 >= 0)
//			{
	orl		%eax,%ecx
	js		Lp2

// both points are unclipped

Lcontinue:

//
//				R_ClipEdge (&clipvert, pv1, clip->next);
//				return;
//			}
//		} while ((clip = clip->next) != NULL);
	movl	cp_next(%ebx),%ebx
	testl	%ebx,%ebx
	jnz		Lcliploop

//	}

//// add the edge
//	R_EmitEdge (pv0, pv1);
Lemit:

//
// set integer rounding to ceil mode, set to single precision
//
// FIXME: do away with by manually extracting integers from floats?
// FIXME: set less often
	fldcw	ceil_cw

//	edge_t	*edge, *pcheck;
//	int		u_check;
//	float	u, u_step;
//	vec3_t	local, transformed;
//	float	*world;
//	int		v, v2, ceilv0;
//	float	scale, lzi0, u0, v0;
//	int		side;

//	if (r_lastvertvalid)
//	{
	cmpl	$0,C(r_lastvertvalid)
	jz		LCalcFirst

//		u0 = r_u1;
//		v0 = r_v1;
//		lzi0 = r_lzi1;
//		ceilv0 = r_ceilv1;
	movl	C(r_lzi1),%eax
	movl	C(r_u1),%ecx
	movl	%eax,Lzi0
	movl	%ecx,Lu0
	movl	C(r_v1),%ecx
	movl	C(r_ceilv1),%eax
	movl	%ecx,Lv0
	movl	%eax,Lceilv0

	flds	Lu0						// u0 
	flds	Lzi0					// lzi0 | u0
	flds	Lv0						// v0 | lzi0 | u0

	jmp		LCalcSecond

//	}

LCalcFirst:

//	else
//	{
//		world = &pv0->position[0];
	call	LTransformAndProject	// v0 | lzi0 | u0
	//		ceilv0 = (int)(v0 - 2000) + 2000; // ceil(v0);
	fistl	Lceilv0					// lzi0 | u0				
//	}

LCalcSecond:

//	world = &pv1->position[0];
	movl	%edx,%esi
	call	LTransformAndProject	// v1 | lzi1 | u1 | v0 | lzi0 | u0

//	r_ceilv1 = (int)(r_v1 - 2000) + 2000; // ceil(r_v1);
	fistl	C(r_ceilv1)
	
	fldcw	single_cw				// put back normal floating-point state

	fsts	C(r_v1)
	fxch	%st(4)					// lzi0 | lzi1 | u1 | v0 | v1 | u0

//	if (r_lzi1 > lzi0)
//		lzi0 = r_lzi1;
	fcom	%st(1)
	fnstsw	%ax
	testb	$1,%ah
	jz		LP0
	fstp	%st(0)
	fld		%st(0)
LP0:

	fxch	%st(1)					// lzi1 | lzi0 | u1 | v0 | v1 | u0
	fstps	C(r_lzi1)				// lzi0 | u1 | v0 | v1 | u0
	fxch	%st(1)					// u1 | lzi0 | v0 | v1 | u0
	fsts	C(r_u1)					// u1 | lzi0 | v0 | v1 | u0
	fxch	%st(1)					// lzi0 | ui | v0 | v1 | u0

//	if (lzi0 > r_nearzi)	// for mipmap finding
//		r_nearzi = lzi0;
	fcoms	C(r_nearzi)
	fnstsw	%ax
	testb	$0x45,%ah
	jnz		LP1
	fsts	C(r_nearzi)
LP1:

// // for right edges, all we want is the effect on 1/z
//	if (r_nearzionly)
//		return;
	movl	C(r_nearzionly),%eax
	testl	%eax,%eax
	jz		LP2
LPop5AndDone:
	movl	C(cacheoffset),%eax
	movl	C(r_framecount),%edx
	cmpl	$0x7FFFFFFF,%eax
	jz		LDoPop
	andl	$(FRAMECOUNT_MASK),%edx
	orl		$(FULLY_CLIPPED_CACHED),%edx
	movl	%edx,C(cacheoffset)

LDoPop:
	fstp	%st(0)			// u1 | v0 | v1 | u0
	fstp	%st(0)			// v0 | v1 | u0
	fstp	%st(0)			// v1 | u0
	fstp	%st(0)			// u0
	fstp	%st(0)
	jmp		Ldone

LP2:

// // create the edge
//	if (ceilv0 == r_ceilv1)
//		return;		// horizontal edge
	movl	Lceilv0,%ebx
	movl	C(edge_p),%edi
	movl	C(r_ceilv1),%ecx
	movl	%edi,%edx
	movl	C(r_pedge),%esi
	addl	$(et_size),%edx
	cmpl	%ecx,%ebx
	jz		LPop5AndDone

	movl	C(r_pedge),%eax
	movl	%eax,et_owner(%edi)

//	side = ceilv0 > r_ceilv1;
//
//	edge->nearzi = lzi0;
	fstps	et_nearzi(%edi)		// u1 | v0 | v1 | u0

//	if (side == 1)
//	{
	jc		LSide0

LSide1:

//	// leading edge (go from p2 to p1)

//		u_step = ((u0 - r_u1) / (v0 - r_v1));
	fsubrp	%st(0),%st(3)		// v0 | v1 | u0-u1
	fsub	%st(1),%st(0)		// v0-v1 | v1 | u0-u1
	fdivrp	%st(0),%st(2)		// v1 | ustep

//	r_emitted = 1;
	movl	$1,C(r_emitted)

//	edge = edge_p++;
	movl	%edx,C(edge_p)

// pretouch next edge
	movl	(%edx),%eax

//		v2 = ceilv0 - 1;
//		v = r_ceilv1;
	movl	%ecx,%eax
	leal	-1(%ebx),%ecx
	movl	%eax,%ebx

//		edge->surfs[0] = 0;
//		edge->surfs[1] = surface_p - surfaces;
	movl	C(surface_p),%eax
	movl	C(surfaces),%esi
	subl	%edx,%edx
	subl	%esi,%eax
	shrl	$(SURF_T_SHIFT),%eax
	movl	%edx,et_surfs(%edi)
	movl	%eax,et_surfs+2(%edi)

	subl	%esi,%esi

//		u = r_u1 + ((float)v - r_v1) * u_step;
	movl	%ebx,Lv
	fildl	Lv					// v | v1 | ustep
	fsubp	%st(0),%st(1)		// v-v1 | ustep
	fmul	%st(1),%st(0)		// (v-v1)*ustep | ustep
	fadds	C(r_u1)				// u | ustep

	jmp		LSideDone

//	}

LSide0:

//	else
//	{
//	// trailing edge (go from p1 to p2)

//		u_step = ((r_u1 - u0) / (r_v1 - v0));
	fsub	%st(3),%st(0)		// u1-u0 | v0 | v1 | u0
	fxch	%st(2)				// v1 | v0 | u1-u0 | u0
	fsub	%st(1),%st(0)		// v1-v0 | v0 | u1-u0 | u0
	fdivrp	%st(0),%st(2)		// v0 | ustep | u0

//	r_emitted = 1;
	movl	$1,C(r_emitted)

//	edge = edge_p++;
	movl	%edx,C(edge_p)

// pretouch next edge
	movl	(%edx),%eax

//		v = ceilv0;
//		v2 = r_ceilv1 - 1;
	decl	%ecx

//		edge->surfs[0] = surface_p - surfaces;
//		edge->surfs[1] = 0;
	movl	C(surface_p),%eax
	movl	C(surfaces),%esi
	subl	%edx,%edx
	subl	%esi,%eax
	shrl	$(SURF_T_SHIFT),%eax
	movl	%edx,et_surfs+2(%edi)
	movl	%eax,et_surfs(%edi)

	movl	$1,%esi

//		u = u0 + ((float)v - v0) * u_step;
	movl	%ebx,Lv
	fildl	Lv					// v | v0 | ustep | u0
	fsubp	%st(0),%st(1)		// v-v0 | ustep | u0
	fmul	%st(1),%st(0)		// (v-v0)*ustep | ustep | u0
	faddp	%st(0),%st(2)		// ustep | u
	fxch	%st(1)				// u | ustep

//	}

LSideDone:

//	edge->u_step = u_step*0x100000;
//	edge->u = u*0x100000 + 0xFFFFF;

	fmuls	fp_1m				// u*0x100000 | ustep
	fadds	fp_1m_minus_1		// u*0x100000 + 0xFFFFF | ustep
	fistpl	et_u(%edi)			// ustep
	fmuls	fp_1m				// ustep*0x100000
	fistpl	et_u_step(%edi)		// 

// // we need to do this to avoid stepping off the edges if a very nearly
// // horizontal edge is less than epsilon above a scan, and numeric error
// // causes it to incorrectly extend to the scan, and the extension of the
// // line goes off the edge of the screen
// // FIXME: is this actually needed?
//	if (edge->u < r_refdef.vrect_x_adj_shift20)
//		edge->u = r_refdef.vrect_x_adj_shift20;
//	if (edge->u > r_refdef.vrectright_adj_shift20)
//		edge->u = r_refdef.vrectright_adj_shift20;
	movl	et_u(%edi),%eax
	movl	C(r_refdef)+rd_vrect_x_adj_shift20,%edx
	cmpl	%edx,%eax
	jl		LP4
	movl	C(r_refdef)+rd_vrectright_adj_shift20,%edx
	cmpl	%edx,%eax
	jng		LP5
LP4:
	movl	%edx,et_u(%edi)
	movl	%edx,%eax
LP5:

// // sort the edge in normally
//	u_check = edge->u;
//
//	if (edge->surfs[0])
//		u_check++;	// sort trailers after leaders
	addl	%esi,%eax

//	if (!newedges[v] || newedges[v]->u >= u_check)
//	{
	movl	C(newedges)(,%ebx,4),%esi
	testl	%esi,%esi
	jz		LDoFirst
	cmpl	%eax,et_u(%esi)
	jl		LNotFirst
LDoFirst:

//		edge->next = newedges[v];
//		newedges[v] = edge;
	movl	%esi,et_next(%edi)
	movl	%edi,C(newedges)(,%ebx,4)

	jmp		LSetRemove

//	}

LNotFirst:

//	else
//	{
//		pcheck = newedges[v];
//
//		while (pcheck->next && pcheck->next->u < u_check)
//			pcheck = pcheck->next;
LFindInsertLoop:
	movl	%esi,%edx
	movl	et_next(%esi),%esi
	testl	%esi,%esi
	jz		LInsertFound
	cmpl	%eax,et_u(%esi)
	jl		LFindInsertLoop

LInsertFound:

//		edge->next = pcheck->next;
//		pcheck->next = edge;
	movl	%esi,et_next(%edi)
	movl	%edi,et_next(%edx)

//	}

LSetRemove:

//	edge->nextremove = removeedges[v2];
//	removeedges[v2] = edge;
	movl	C(removeedges)(,%ecx,4),%eax
	movl	%edi,C(removeedges)(,%ecx,4)
	movl	%eax,et_nextremove(%edi)

Ldone:
	movl	Lstack,%esp			// clear temporary variables from stack

	popl	%ebx				// restore register variables
	popl	%edi
	popl	%esi
	ret

// at least one point is clipped

Lp2:
	testl	%eax,%eax
	jns		Lp1

//			else
//			{
//			// point 0 is clipped

//				if (d1 < 0)
//				{
	movl	Ld1,%eax
	testl	%eax,%eax
	jns		Lp3

//				// both points are clipped
//				// we do cache fully clipped edges
//					if (!leftclipped)
	movl	C(r_leftclipped),%eax
	movl	C(r_pedge),%ecx
	testl	%eax,%eax
	jnz		Ldone

//						r_pedge->framecount = r_framecount;
	movl	C(r_framecount),%eax
	andl	$(FRAMECOUNT_MASK),%eax
	orl		$(FULLY_CLIPPED_CACHED),%eax
	movl	%eax,C(cacheoffset)

//					return;
	jmp		Ldone

//				}

Lp1:

//			// point 0 is unclipped
//				if (d1 >= 0)
//				{
//				// both points are unclipped
//					continue;

//			// only point 1 is clipped

//				f = d0 / (d0 - d1);
	flds	Ld0
	flds	Ld1
	fsubr	%st(1),%st(0)

//			// we don't cache partially clipped edges
	movl	$0x7FFFFFFF,C(cacheoffset)

	fdivrp	%st(0),%st(1)

	subl	$(mv_size),%esp			// allocate space for clipvert

//				clipvert.position[0] = pv0->position[0] +
//						f * (pv1->position[0] - pv0->position[0]);
//				clipvert.position[1] = pv0->position[1] +
//						f * (pv1->position[1] - pv0->position[1]);
//				clipvert.position[2] = pv0->position[2] +
//						f * (pv1->position[2] - pv0->position[2]);
	flds	mv_position+8(%edx)
	fsubs	mv_position+8(%esi)
	flds	mv_position+4(%edx)
	fsubs	mv_position+4(%esi)
	flds	mv_position+0(%edx)
	fsubs	mv_position+0(%esi)		// 0 | 1 | 2 | f

// replace pv1 with the clip point
	movl	%esp,%edx
	movl	cp_leftedge(%ebx),%eax
	testb	%al,%al

	fmul	%st(3),%st(0)			// 0f | 1 | 2 | f
	fadds	mv_position+0(%esi)		// 0fa | 1 | 2 | f
	fstps	mv_position+0(%esp)		// 1 | 2 | f

	fmul	%st(2),%st(0)			// 1f | 2 | f
	fadds	mv_position+4(%esi)		// 1fa | 2 | f
	fstps	mv_position+4(%esp)		// 2 | f

	fmulp	%st(0),%st(1)			// 2f
	fadds	mv_position+8(%esi)		// 2fa
	fstps	mv_position+8(%esp)		// 

//				if (clip->leftedge)
//				{
	jz		Ltestright

//					r_leftclipped = true;
//					r_leftexit = clipvert;

	movl	$1,C(r_leftclipped)
	movl	mv_position+0(%esp),%eax
	movl	%eax,C(r_leftexit)+mv_position+0
	movl	mv_position+4(%esp),%eax
	movl	%eax,C(r_leftexit)+mv_position+4
	movl	mv_position+8(%esp),%eax
	movl	%eax,C(r_leftexit)+mv_position+8

	jmp		Lcontinue

//				}

Ltestright:
//				else if (clip->rightedge)
//				{
	testb	%ah,%ah
	jz		Lcontinue

//					r_rightclipped = true;
//					r_rightexit = clipvert;
	movl	$1,C(r_rightclipped)
	movl	mv_position+0(%esp),%eax
	movl	%eax,C(r_rightexit)+mv_position+0
	movl	mv_position+4(%esp),%eax
	movl	%eax,C(r_rightexit)+mv_position+4
	movl	mv_position+8(%esp),%eax
	movl	%eax,C(r_rightexit)+mv_position+8

//				}
//
//				R_ClipEdge (pv0, &clipvert, clip->next);
//				return;
//			}
	jmp		Lcontinue

//			}

Lp3:

//			// only point 0 is clipped
//				r_lastvertvalid = false;

	movl	$0,C(r_lastvertvalid)

//				f = d0 / (d0 - d1);
	flds	Ld0
	flds	Ld1
	fsubr	%st(1),%st(0)

//			// we don't cache partially clipped edges
	movl	$0x7FFFFFFF,C(cacheoffset)

	fdivrp	%st(0),%st(1)

	subl	$(mv_size),%esp			// allocate space for clipvert

//				clipvert.position[0] = pv0->position[0] +
//						f * (pv1->position[0] - pv0->position[0]);
//				clipvert.position[1] = pv0->position[1] +
//						f * (pv1->position[1] - pv0->position[1]);
//				clipvert.position[2] = pv0->position[2] +
//						f * (pv1->position[2] - pv0->position[2]);
	flds	mv_position+8(%edx)
	fsubs	mv_position+8(%esi)
	flds	mv_position+4(%edx)
	fsubs	mv_position+4(%esi)
	flds	mv_position+0(%edx)
	fsubs	mv_position+0(%esi)		// 0 | 1 | 2 | f

	movl	cp_leftedge(%ebx),%eax
	testb	%al,%al

	fmul	%st(3),%st(0)			// 0f | 1 | 2 | f
	fadds	mv_position+0(%esi)		// 0fa | 1 | 2 | f
	fstps	mv_position+0(%esp)		// 1 | 2 | f

	fmul	%st(2),%st(0)			// 1f | 2 | f
	fadds	mv_position+4(%esi)		// 1fa | 2 | f
	fstps	mv_position+4(%esp)		// 2 | f

	fmulp	%st(0),%st(1)			// 2f
	fadds	mv_position+8(%esi)		// 2fa
	fstps	mv_position+8(%esp)		// 

// replace pv0 with the clip point
	movl	%esp,%esi

//				if (clip->leftedge)
//				{
	jz		Ltestright2

//					r_leftclipped = true;
//					r_leftenter = clipvert;
	movl	$1,C(r_leftclipped)
	movl	mv_position+0(%esp),%eax
	movl	%eax,C(r_leftenter)+mv_position+0
	movl	mv_position+4(%esp),%eax
	movl	%eax,C(r_leftenter)+mv_position+4
	movl	mv_position+8(%esp),%eax
	movl	%eax,C(r_leftenter)+mv_position+8

	jmp		Lcontinue

//				}

Ltestright2:
//				else if (clip->rightedge)
//				{
	testb	%ah,%ah
	jz		Lcontinue

//					r_rightclipped = true;
//					r_rightenter = clipvert;
	movl	$1,C(r_rightclipped)
	movl	mv_position+0(%esp),%eax
	movl	%eax,C(r_rightenter)+mv_position+0
	movl	mv_position+4(%esp),%eax
	movl	%eax,C(r_rightenter)+mv_position+4
	movl	mv_position+8(%esp),%eax
	movl	%eax,C(r_rightenter)+mv_position+8

//				}
	jmp		Lcontinue

// %esi = vec3_t point to transform and project
// %edx preserved
LTransformAndProject:

//	// transform and project
//		VectorSubtract (world, modelorg, local);
//		TransformVector (local, transformed);
	flds	mv_position+0(%esi)	
	fsubs	C(modelorg)+0		// local[0]
	fld		%st(0)				// local[0] | local[0]
	fmuls	C(vright)+0			// xm0 | local[0]
	fld		%st(1)				// local[0] | xm0 | local[0]
	fmuls	C(vup)+0			// ym0 | xm0 | local[0]
	fxch	%st(2)				// local[0] | xm0 | ym0
	fmuls	C(vpn)+0			// zm0 | xm0 | ym0

	flds	mv_position+4(%esi)
	fsubs	C(modelorg)+4		// local[1] | zm0 | xm0 | ym0
	fld		%st(0)				// local[1] | local[1] | zm0 | xm0 | ym0
	fmuls	C(vpn)+4			// zm1 | local[1] | zm0 | xm0 | ym0
	faddp	%st(0),%st(2)		// local[1] | zm2 | xm0 | ym0
	fld		%st(0)				// local[1] | local[1] | zm2 | xm0 | ym0
	fmuls	C(vright)+4			// xm1 | local[1] | zm2 | xm0 | ym0
	faddp	%st(0),%st(3)		// local[1] | zm2 | xm2 | ym0
	fmuls	C(vup)+4			// ym1 | zm2 | xm2 | ym0
	faddp	%st(0),%st(3)		// zm2 | xm2 | ym2

	flds	mv_position+8(%esi)
	fsubs	C(modelorg)+8		// local[2] | zm2 | xm2 | ym2
	fld		%st(0)				// local[2] | local[2] | zm2 | xm2 | ym2
	fmuls	C(vpn)+8			// zm3 | local[2] | zm2 | xm2 | ym2
	faddp	%st(0),%st(2)		// local[2] | zm4 | xm2 | ym2
	fld		%st(0)				// local[2] | local[2] | zm4 | xm2 | ym2
	fmuls	C(vright)+8			// xm3 | local[2] | zm4 | xm2 | ym2
	faddp	%st(0),%st(3)		// local[2] | zm4 | xm4 | ym2
	fmuls	C(vup)+8			// ym3 | zm4 | xm4 | ym2
	faddp	%st(0),%st(3)		// zm4 | xm4 | ym4
	// zm4 | xm4 | ym4

//		if (transformed[2] < NEAR_CLIP)
//			transformed[2] = NEAR_CLIP;
//	
//		lzi0 = 1.0 / transformed[2];

	fcoms	Lfp_near_clip
	fnstsw	%ax
	testb	$1,%ah
	jz		LNoClip
	fstp	%st(0)
	flds	Lfp_near_clip

LNoClip:

	fdivrs	float_1				// lzi0 | x | y
	fxch	%st(1)				// x | lzi0 | y

//	// FIXME: build x/yscale into transform?
//		scale = xscale * lzi0;
//		u0 = (xcenter + scale*transformed[0]);
	flds	C(xscale)			// xscale | x | lzi0 | y
	fmul	%st(2),%st(0)		// scale | x | lzi0 | y
	fmulp	%st(0),%st(1)		// scale*x | lzi0 | y
	fadds	C(xcenter)			// u0 | lzi0 | y

//		if (u0 < r_refdef.fvrectx_adj)
//			u0 = r_refdef.fvrectx_adj;
//		if (u0 > r_refdef.fvrectright_adj)
//			u0 = r_refdef.fvrectright_adj;
// FIXME: use integer compares of floats?
	fcoms	C(r_refdef)+rd_fvrectx_adj
	fnstsw	%ax
	testb	$1,%ah
	jz		LClampP0
	fstp	%st(0)
	flds	C(r_refdef)+rd_fvrectx_adj
LClampP0:
	fcoms	C(r_refdef)+rd_fvrectright_adj
	fnstsw	%ax
	testb	$0x45,%ah
	jnz		LClampP1
	fstp	%st(0)
	flds	C(r_refdef)+rd_fvrectright_adj
LClampP1:

	fld		%st(1)				// lzi0 | u0 | lzi0 | y

//		scale = yscale * lzi0;
//		v0 = (ycenter - scale*transformed[1]);
	fmuls	C(yscale)			// scale | u0 | lzi0 | y
	fmulp	%st(0),%st(3)		// u0 | lzi0 | scale*y
	fxch	%st(2)				// scale*y | lzi0 | u0
	fsubrs	C(ycenter)			// v0 | lzi0 | u0

//		if (v0 < r_refdef.fvrecty_adj)
//			v0 = r_refdef.fvrecty_adj;
//		if (v0 > r_refdef.fvrectbottom_adj)
//			v0 = r_refdef.fvrectbottom_adj;
// FIXME: use integer compares of floats?
	fcoms	C(r_refdef)+rd_fvrecty_adj
	fnstsw	%ax
	testb	$1,%ah
	jz		LClampP2
	fstp	%st(0)
	flds	C(r_refdef)+rd_fvrecty_adj
LClampP2:
	fcoms	C(r_refdef)+rd_fvrectbottom_adj
	fnstsw	%ax
	testb	$0x45,%ah
	jnz		LClampP3
	fstp	%st(0)
	flds	C(r_refdef)+rd_fvrectbottom_adj
LClampP3:
	ret

#endif	// id386

