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
// r_alias.c: routines for setting up to draw alias models

#include "quakedef.h"
#include "r_local.h"
#include "d_local.h"	// FIXME: shouldn't be needed (is needed for patch
						// right now, but that should move)

#define LIGHT_MIN	5		// lowest light value we'll allow, to avoid the
							//  need for inner-loop light clamping

mtriangle_t		*ptriangles;
affinetridesc_t		r_affinetridesc;

void *			acolormap;	// FIXME: should go away

trivertx_t		*r_apverts;

// TODO: these probably will go away with optimized rasterization
mdl_t				*pmdl;

vec3_t				r_plightvec;

int					r_ambientlight;

float				r_shadelight;

aliashdr_t			*paliashdr;

finalvert_t			*pfinalverts;

auxvert_t			*pauxverts;

static float			ziscale;

static model_t		*pmodel;

static vec3_t		alias_forward, alias_right, alias_up;

static maliasskindesc_t	*pskindesc;

int				r_amodels_drawn;
int				a_skinwidth;
int				r_anumverts;

float				aliastransform[3][4];

#ifdef USEFPM
mdl_FPM_t			*pmdlFPM;
vec3_FPM_t			r_plightvecFPM;
fixedpoint_t		r_shadelightFPM;
auxvert_FPM_t		*pauxvertsFPM;
static unsigned __int64	ziscaleFPM;
static model_FPM_t	*pmodelFPM;
static vec3_FPM_t	alias_forwardFPM, alias_rightFPM, alias_upFPM;
fixedpoint8_24_t	aliastransformFPM[3][4];
#endif //USEFPM


typedef struct {
	int	index0;
	int	index1;
} aedge_t;

static aedge_t	aedges[12] = {
{0, 1}, {1, 2}, {2, 3}, {3, 0},
{4, 5}, {5, 6}, {6, 7}, {7, 4},
{0, 5}, {1, 4}, {2, 7}, {3, 6}
};

#define NUMVERTEXNORMALS	162

float	r_avertexnormals[NUMVERTEXNORMALS][3] = {
#include "anorms.h"
};

#ifdef USEFPM
//Dan: TODO: convert anorms.h to fixed point 16.16 values, instead of filling
//this array by converting the r_avertexnormals array.
fixedpoint_t	r_avertexnormalsFPM[NUMVERTEXNORMALS][3];
#endif //USEFPM

void R_AliasTransformAndProjectFinalVerts (finalvert_t *fv,
	stvert_t *pstverts);
void R_AliasSetUpTransform (int trivial_accept);
void R_AliasTransformVector (vec3_t in, vec3_t out);
void R_AliasTransformFinalVert (finalvert_t *fv, auxvert_t *av,
	trivertx_t *pverts, stvert_t *pstverts);
void R_AliasProjectFinalVert (finalvert_t *fv, auxvert_t *av);

#ifdef USEFPM
void R_AliasSetUpTransformFPM (int trivial_accept);
void R_AliasTransformVectorFPM (vec3_FPM_t in, vec3_FPM_t out);
void R_AliasTransformFinalVertFPM (finalvert_t *fv, auxvert_FPM_t *av,
	trivertx_t *pverts, stvert_t *pstverts);
void R_AliasProjectFinalVertFPM (finalvert_t *fv, auxvert_FPM_t *av);
#endif //USEFPM
/*
================
R_AliasCheckBBox
================
*/
qboolean R_AliasCheckBBox (void)
{
	int					i, flags, frame, numv;
	aliashdr_t			*pahdr;
	float				zi, basepts[8][3], v0, v1, frac;
	finalvert_t			*pv0, *pv1, viewpts[16];
	auxvert_t			*pa0, *pa1, viewaux[16];
	maliasframedesc_t	*pframedesc;
	qboolean			zclipped, zfullyclipped;
	unsigned			anyclip, allclip;
	int					minz;
	
// expand, rotate, and translate points into worldspace

	currententity->trivial_accept = 0;
	pmodel = currententity->model;
	pahdr = Mod_Extradata (pmodel);
	pmdl = (mdl_t *)((byte *)pahdr + pahdr->model);

	R_AliasSetUpTransform (0);

// construct the base bounding box for this frame
	frame = currententity->frame;
// TODO: don't repeat this check when drawing?
	if ((frame >= pmdl->numframes) || (frame < 0))
	{
		Con_DPrintf ("No such frame %d %s\n", frame,
				pmodel->name);
		frame = 0;
	}

	pframedesc = &pahdr->frames[frame];

// x worldspace coordinates
	basepts[0][0] = basepts[1][0] = basepts[2][0] = basepts[3][0] =
			(float)pframedesc->bboxmin.v[0];
	basepts[4][0] = basepts[5][0] = basepts[6][0] = basepts[7][0] =
			(float)pframedesc->bboxmax.v[0];

// y worldspace coordinates
	basepts[0][1] = basepts[3][1] = basepts[5][1] = basepts[6][1] =
			(float)pframedesc->bboxmin.v[1];
	basepts[1][1] = basepts[2][1] = basepts[4][1] = basepts[7][1] =
			(float)pframedesc->bboxmax.v[1];

// z worldspace coordinates
	basepts[0][2] = basepts[1][2] = basepts[4][2] = basepts[5][2] =
			(float)pframedesc->bboxmin.v[2];
	basepts[2][2] = basepts[3][2] = basepts[6][2] = basepts[7][2] =
			(float)pframedesc->bboxmax.v[2];

	zclipped = false;
	zfullyclipped = true;

	minz = 9999;
	for (i=0; i<8 ; i++)
	{
		R_AliasTransformVector  (&basepts[i][0], &viewaux[i].fv[0]);

		if (viewaux[i].fv[2] < ALIAS_Z_CLIP_PLANE)
		{
		// we must clip points that are closer than the near clip plane
			viewpts[i].flags = ALIAS_Z_CLIP;
			zclipped = true;
		}
		else
		{
			if (viewaux[i].fv[2] < minz)
				minz = (int)viewaux[i].fv[2];
			viewpts[i].flags = 0;
			zfullyclipped = false;
		}
	}

	
	if (zfullyclipped)
	{
		return false;	// everything was near-z-clipped
	}

	numv = 8;

	if (zclipped)
	{
	// organize points by edges, use edges to get new points (possible trivial
	// reject)
		for (i=0 ; i<12 ; i++)
		{
		// edge endpoints
			pv0 = &viewpts[aedges[i].index0];
			pv1 = &viewpts[aedges[i].index1];
			pa0 = &viewaux[aedges[i].index0];
			pa1 = &viewaux[aedges[i].index1];

		// if one end is clipped and the other isn't, make a new point
			if (pv0->flags ^ pv1->flags)
			{
				frac = (ALIAS_Z_CLIP_PLANE - pa0->fv[2]) /
					   (pa1->fv[2] - pa0->fv[2]);
				viewaux[numv].fv[0] = pa0->fv[0] +
						(pa1->fv[0] - pa0->fv[0]) * frac;
				viewaux[numv].fv[1] = pa0->fv[1] +
						(pa1->fv[1] - pa0->fv[1]) * frac;
				viewaux[numv].fv[2] = ALIAS_Z_CLIP_PLANE;
				viewpts[numv].flags = 0;
				numv++;
			}
		}
	}

// project the vertices that remain after clipping
	anyclip = 0;
	allclip = ALIAS_XY_CLIP_MASK;

// TODO: probably should do this loop in ASM, especially if we use floats
	for (i=0 ; i<numv ; i++)
	{
	// we don't need to bother with vertices that were z-clipped
		if (viewpts[i].flags & ALIAS_Z_CLIP)
			continue;

		zi = (float)(1.0 / viewaux[i].fv[2]);

	// FIXME: do with chop mode in ASM, or convert to float
		v0 = (viewaux[i].fv[0] * xscale * zi) + xcenter;
		v1 = (viewaux[i].fv[1] * yscale * zi) + ycenter;

		flags = 0;

		if (v0 < r_refdef.fvrectx)
			flags |= ALIAS_LEFT_CLIP;
		if (v1 < r_refdef.fvrecty)
			flags |= ALIAS_TOP_CLIP;
		if (v0 > r_refdef.fvrectright)
			flags |= ALIAS_RIGHT_CLIP;
		if (v1 > r_refdef.fvrectbottom)
			flags |= ALIAS_BOTTOM_CLIP;

		anyclip |= flags;
		allclip &= flags;
	}

	if (allclip)
		return false;	// trivial reject off one side

	currententity->trivial_accept = !anyclip & !zclipped;

	if (currententity->trivial_accept)
	{
		if (minz > (r_aliastransition + (pmdl->size * r_resfudge)))
		{
			currententity->trivial_accept |= 2;
		}
	}

	return true;
}

#ifdef USEFPM
qboolean R_AliasCheckBBoxFPM (void)
{
	int					i, flags, frame, numv;
	aliashdr_t			*pahdr;
	fixedpoint_t		zi, basepts[8][3], frac; //v0, v1;
	finalvert_t			*pv0, *pv1, viewpts[16];
	auxvert_FPM_t		*pa0, *pa1, viewaux[16];
	maliasframedesc_t	*pframedesc;
	qboolean			zclipped, zfullyclipped;
	unsigned			anyclip, allclip;
	int					minz;
	
// expand, rotate, and translate points into worldspace

	currententityFPM->trivial_accept = 0;
	pmodelFPM = currententityFPM->model;
	pahdr = Mod_ExtradataFPM (pmodelFPM);
	pmdlFPM = (mdl_FPM_t *)((byte *)pahdr + pahdr->model);

	R_AliasSetUpTransformFPM (0);

// construct the base bounding box for this frame
	frame = currententityFPM->frame;
// TODO: don't repeat this check when drawing?
	if ((frame >= pmdlFPM->numframes) || (frame < 0))
	{
		Con_DPrintf ("No such frame %d %s\n", frame,
				pmodelFPM->name);
		frame = 0;
	}

	pframedesc = &pahdr->frames[frame];

// x worldspace coordinates
	basepts[0][0] = basepts[1][0] = basepts[2][0] = basepts[3][0] =
			FPM_FROMLONG(pframedesc->bboxmin.v[0]);
	basepts[4][0] = basepts[5][0] = basepts[6][0] = basepts[7][0] =
			FPM_FROMLONG(pframedesc->bboxmax.v[0]);

// y worldspace coordinates
	basepts[0][1] = basepts[3][1] = basepts[5][1] = basepts[6][1] =
			FPM_FROMLONG(pframedesc->bboxmin.v[1]);
	basepts[1][1] = basepts[2][1] = basepts[4][1] = basepts[7][1] =
			FPM_FROMLONG(pframedesc->bboxmax.v[1]);

// z worldspace coordinates
	basepts[0][2] = basepts[1][2] = basepts[4][2] = basepts[5][2] =
			FPM_FROMLONG(pframedesc->bboxmin.v[2]);
	basepts[2][2] = basepts[3][2] = basepts[6][2] = basepts[7][2] =
			FPM_FROMLONG(pframedesc->bboxmax.v[2]);

	zclipped = false;
	zfullyclipped = true;

	minz = 9999;
	for (i=0; i<8 ; i++)
	{
		R_AliasTransformVectorFPM  (&basepts[i][0], &viewaux[i].fv[0]);

		if (viewaux[i].fv[2] < ALIAS_Z_CLIP_PLANE)
		{
		// we must clip points that are closer than the near clip plane
			viewpts[i].flags = ALIAS_Z_CLIP;
			zclipped = true;
		}
		else
		{
			if (viewaux[i].fv[2] < minz)
				minz = FPM_TOLONG(viewaux[i].fv[2]);
			viewpts[i].flags = 0;
			zfullyclipped = false;
		}
	}

	
	if (zfullyclipped)
	{
		return false;	// everything was near-z-clipped
	}

	numv = 8;

	if (zclipped)
	{
	// organize points by edges, use edges to get new points (possible trivial
	// reject)
		for (i=0 ; i<12 ; i++)
		{
		// edge endpoints
			pv0 = &viewpts[aedges[i].index0];
			pv1 = &viewpts[aedges[i].index1];
			pa0 = &viewaux[aedges[i].index0];
			pa1 = &viewaux[aedges[i].index1];

		// if one end is clipped and the other isn't, make a new point
			if (pv0->flags ^ pv1->flags)
			{
				frac = FPM_DIV(FPM_SUB(ALIAS_Z_CLIP_PLANE_FPM, pa0->fv[2]),
					   FPM_SUB(pa1->fv[2], pa0->fv[2]));
				viewaux[numv].fv[0] = FPM_ADD(pa0->fv[0],
						FPM_MUL(FPM_SUB(pa1->fv[0], pa0->fv[0]), frac));
				viewaux[numv].fv[1] = FPM_ADD(pa0->fv[1],
						FPM_MUL(FPM_SUB(pa1->fv[1], pa0->fv[1]), frac));
				viewaux[numv].fv[2] = ALIAS_Z_CLIP_PLANE_FPM;
				viewpts[numv].flags = 0;
				numv++;
			}
		}
	}

// project the vertices that remain after clipping
	anyclip = 0;
	allclip = ALIAS_XY_CLIP_MASK;

// TODO: probably should do this loop in ASM, especially if we use floats
	for (i=0 ; i<numv ; i++)
	{
		__int64 i1,i2;
	// we don't need to bother with vertices that were z-clipped
		if (viewpts[i].flags & ALIAS_Z_CLIP)
			continue;

		zi = FPM_INV(viewaux[i].fv[2]);

	// FIXME: do with chop mode in ASM, or convert to float
		//Dan: Overflow / underflow with 16.16, so using 32.32
		i1=viewaux[i].fv[0];
		i1<<=16;
		i2=xscaleFPM;
		i2<<=16;
		i1*=i2;
		i1>>=16;
		i2=zi;
		i2<<=16;
		i1*=i2;
		i1>>=16;
		i2=xcenterFPM;
		i2<<=16;
		i1+=i2;
		if (i1 < r_refdefFPM.fvrectx)
			flags |= ALIAS_LEFT_CLIP;
		if (i1 > r_refdefFPM.fvrectright)
			flags |= ALIAS_RIGHT_CLIP;

		//v0 = FPM_ADD(FPM_MUL(FPM_MUL(viewaux[i].fv[0], xscaleFPM), zi), xcenterFPM);

		i1=viewaux[i].fv[1];
		i1<<=16;
		i2=yscaleFPM;
		i2<<=16;
		i1*=i2;
		i1>>=16;
		i2=zi;
		i2<<=16;
		i1*=i2;
		i1>>=16;
		i2=ycenterFPM;
		i2<<=16;
		i1+=i2;

		if (i1 < r_refdefFPM.fvrecty)
			flags |= ALIAS_TOP_CLIP;
		if (i1 > r_refdefFPM.fvrectbottom)
			flags |= ALIAS_BOTTOM_CLIP;

		//v1 = FPM_ADD(FPM_MUL(FPM_MUL(viewaux[i].fv[1], yscaleFPM), zi), ycenterFPM);

		flags = 0;

//		if (v0 < r_refdefFPM.fvrectx)
//			flags |= ALIAS_LEFT_CLIP;
//		if (v1 < r_refdefFPM.fvrecty)
//			flags |= ALIAS_TOP_CLIP;
//		if (v0 > r_refdefFPM.fvrectright)
//			flags |= ALIAS_RIGHT_CLIP;
//		if (v1 > r_refdefFPM.fvrectbottom)
//			flags |= ALIAS_BOTTOM_CLIP;

		anyclip |= flags;
		allclip &= flags;
	}

	if (allclip)
		return false;	// trivial reject off one side

	currententityFPM->trivial_accept = !anyclip & !zclipped;

	if (currententityFPM->trivial_accept)
	{
		if (minz > FPM_TOLONG(FPM_ADD(r_aliastransitionFPM, FPM_MUL(pmdlFPM->size, r_resfudgeFPM))))
		{
			currententityFPM->trivial_accept |= 2;
		}
	}

	return true;
}
#endif //USEFPM

/*
================
R_AliasTransformVector
================
*/
void R_AliasTransformVector (vec3_t in, vec3_t out)
{
	out[0] = DotProduct(in, aliastransform[0]) + aliastransform[0][3];
	out[1] = DotProduct(in, aliastransform[1]) + aliastransform[1][3];
	out[2] = DotProduct(in, aliastransform[2]) + aliastransform[2][3];
}
/*
void R_AliasTransformVectorFPM (vec3_FPM_t in, vec3_FPM_t out)
{
	out[0] = fpm_Add(DotProductFPM(in, aliastransformFPM[0]), aliastransformFPM[0][3]);
	out[1] = fpm_Add(DotProductFPM(in, aliastransformFPM[1]), aliastransformFPM[1][3]);
	out[2] = fpm_Add(DotProductFPM(in, aliastransformFPM[2]), aliastransformFPM[2][3]);
}
*/

#ifdef USEFPM
void R_AliasTransformVectorFPM (vec3_FPM_t in, vec3_FPM_t out)
{
	out[0] = fpm_Add(DotProduct8_24FPM(aliastransformFPM[0], in), (fixedpoint_t)aliastransformFPM[0][3]);
	out[1] = fpm_Add(DotProduct8_24FPM(aliastransformFPM[1], in), (fixedpoint_t)aliastransformFPM[1][3]);
	out[2] = fpm_Add(DotProduct8_24FPM(aliastransformFPM[2], in), (fixedpoint_t)aliastransformFPM[2][3]);
}
#endif //USEFPM

/*
================
R_AliasPreparePoints

General clipped case
================
*/

void R_AliasPreparePoints (void)
{
	int			i;
	stvert_t	*pstverts;
	finalvert_t	*fv;
	auxvert_t	*av;
	mtriangle_t	*ptri;
	finalvert_t	*pfv[3];

	pstverts = (stvert_t *)((byte *)paliashdr + paliashdr->stverts);
	r_anumverts = pmdl->numverts;
 	fv = pfinalverts;
	av = pauxverts;

	for (i=0 ; i<r_anumverts ; i++, fv++, av++, r_apverts++, pstverts++)
	{
		R_AliasTransformFinalVert (fv, av, r_apverts, pstverts);
		if (av->fv[2] < ALIAS_Z_CLIP_PLANE)
			fv->flags |= ALIAS_Z_CLIP;
		else
		{
			 R_AliasProjectFinalVert (fv, av);

			if (fv->v[0] < r_refdef.aliasvrect.x)
				fv->flags |= ALIAS_LEFT_CLIP;
			if (fv->v[1] < r_refdef.aliasvrect.y)
				fv->flags |= ALIAS_TOP_CLIP;
			if (fv->v[0] > r_refdef.aliasvrectright)
				fv->flags |= ALIAS_RIGHT_CLIP;
			if (fv->v[1] > r_refdef.aliasvrectbottom)
				fv->flags |= ALIAS_BOTTOM_CLIP;	
		}
	}

//
// clip and draw all triangles
//
	r_affinetridesc.numtriangles = 1;

	ptri = (mtriangle_t *)((byte *)paliashdr + paliashdr->triangles);
	for (i=0 ; i<pmdl->numtris ; i++, ptri++)
	{
		pfv[0] = &pfinalverts[ptri->vertindex[0]];
		pfv[1] = &pfinalverts[ptri->vertindex[1]];
		pfv[2] = &pfinalverts[ptri->vertindex[2]];

		if ( pfv[0]->flags & pfv[1]->flags & pfv[2]->flags & (ALIAS_XY_CLIP_MASK | ALIAS_Z_CLIP) )
			continue;		// completely clipped
		
		if ( ! ( (pfv[0]->flags | pfv[1]->flags | pfv[2]->flags) &
			(ALIAS_XY_CLIP_MASK | ALIAS_Z_CLIP) ) )
		{	// totally unclipped
			r_affinetridesc.pfinalverts = pfinalverts;
			r_affinetridesc.ptriangles = ptri;
			D_PolysetDraw ();
		}
		else		
		{	// partially clipped
			R_AliasClipTriangle (ptri);
		}
	}
}

#ifdef USEFPM
void R_AliasPreparePointsFPM (void)
{
	int				i;
	stvert_t		*pstverts;	//Ok, no floats
	finalvert_t	*fv;		//.reserved
	auxvert_FPM_t	*av;		//all floats
	mtriangle_t		*ptri;		//ok
	finalvert_t	*pfv[3];	//.reserved

	pstverts = (stvert_t *)((byte *)paliashdr + paliashdr->stverts);
	r_anumverts = pmdlFPM->numverts;
 	fv = pfinalverts;
	av = pauxvertsFPM;

	for (i=0 ; i<r_anumverts ; i++, fv++, av++, r_apverts++, pstverts++)
	{
		R_AliasTransformFinalVertFPM (fv, av, r_apverts, pstverts);
		if (av->fv[2] < ALIAS_Z_CLIP_PLANE_FPM)
			fv->flags |= ALIAS_Z_CLIP;
		else
		{
			 R_AliasProjectFinalVertFPM (fv, av);

			if (fv->v[0] < r_refdefFPM.aliasvrect.x)
				fv->flags |= ALIAS_LEFT_CLIP;
			if (fv->v[1] < r_refdefFPM.aliasvrect.y)
				fv->flags |= ALIAS_TOP_CLIP;
			if (fv->v[0] > r_refdefFPM.aliasvrectright)
				fv->flags |= ALIAS_RIGHT_CLIP;
			if (fv->v[1] > r_refdefFPM.aliasvrectbottom)
				fv->flags |= ALIAS_BOTTOM_CLIP;	
		}
	}

//
// clip and draw all triangles
//
	r_affinetridesc.numtriangles = 1;

	ptri = (mtriangle_t *)((byte *)paliashdr + paliashdr->triangles);
	for (i=0 ; i<pmdlFPM->numtris ; i++, ptri++)
	{
		pfv[0] = &pfinalverts[ptri->vertindex[0]];
		pfv[1] = &pfinalverts[ptri->vertindex[1]];
		pfv[2] = &pfinalverts[ptri->vertindex[2]];

		if ( pfv[0]->flags & pfv[1]->flags & pfv[2]->flags & (ALIAS_XY_CLIP_MASK | ALIAS_Z_CLIP) )
			continue;		// completely clipped
		
		if ( ! ( (pfv[0]->flags | pfv[1]->flags | pfv[2]->flags) &
			(ALIAS_XY_CLIP_MASK | ALIAS_Z_CLIP) ) )
		{	// totally unclipped
			r_affinetridesc.pfinalverts = pfinalverts;
			r_affinetridesc.ptriangles = ptri;
			D_PolysetDraw ();	//TODO: Dan
		}
		else		
		{	// partially clipped
			R_AliasClipTriangleFPM (ptri);
		}
	}
}
#endif //USEFPM

/*
================
R_AliasSetUpTransform
================
*/
void R_AliasSetUpTransform (int trivial_accept)
{
	int				i;
	float			rotationmatrix[3][4], t2matrix[3][4];
	static float	tmatrix[3][4];
	static float	viewmatrix[3][4];
	vec3_t			angles;

// TODO: should really be stored with the entity instead of being reconstructed
// TODO: should use a look-up table
// TODO: could cache lazily, stored in the entity

	angles[ROLL] = currententity->angles[ROLL];
	angles[PITCH] = -currententity->angles[PITCH];
	angles[YAW] = currententity->angles[YAW];
	AngleVectors (angles, alias_forward, alias_right, alias_up);

	tmatrix[0][0] = pmdl->scale[0];
	tmatrix[1][1] = pmdl->scale[1];
	tmatrix[2][2] = pmdl->scale[2];

	tmatrix[0][3] = pmdl->scale_origin[0];
	tmatrix[1][3] = pmdl->scale_origin[1];
	tmatrix[2][3] = pmdl->scale_origin[2];

// TODO: can do this with simple matrix rearrangement

	for (i=0 ; i<3 ; i++)
	{
		t2matrix[i][0] = alias_forward[i];
		t2matrix[i][1] = -alias_right[i];
		t2matrix[i][2] = alias_up[i];
	}

	t2matrix[0][3] = -modelorg[0];
	t2matrix[1][3] = -modelorg[1];
	t2matrix[2][3] = -modelorg[2];

// FIXME: can do more efficiently than full concatenation
	R_ConcatTransforms (t2matrix, tmatrix, rotationmatrix);

// TODO: should be global, set when vright, etc., set
	VectorCopy (vright, viewmatrix[0]);
	VectorCopy (vup, viewmatrix[1]);
	VectorInverse (viewmatrix[1]);
	VectorCopy (vpn, viewmatrix[2]);

//	viewmatrix[0][3] = 0;
//	viewmatrix[1][3] = 0;
//	viewmatrix[2][3] = 0;

	R_ConcatTransforms (viewmatrix, rotationmatrix, aliastransform);

// do the scaling up of x and y to screen coordinates as part of the transform
// for the unclipped case (it would mess up clipping in the clipped case).
// Also scale down z, so 1/z is scaled 31 bits for free, and scale down x and y
// correspondingly so the projected x and y come out right
// FIXME: make this work for clipped case too?
	if (trivial_accept)
	{
		for (i=0 ; i<4 ; i++)
		{
			aliastransform[0][i] *= aliasxscale *
					(((float)1.0) / ((float)0x8000 * 0x10000));
			aliastransform[1][i] *= aliasyscale *
					(((float)1.0) / ((float)0x8000 * 0x10000));
			aliastransform[2][i] *= 1.0 / ((float)0x8000 * 0x10000);

		}
	}
}

#ifdef USEFPM
void R_AliasSetUpTransformFPM (int trivial_accept)
{
	int					i;
	fixedpoint_t		rotationmatrix[3][4], t2matrix[3][4];
	static fixedpoint_t	tmatrix[3][4];
	static fixedpoint_t	viewmatrix[3][4];
	vec3_FPM_t			angles;

// TODO: should really be stored with the entity instead of being reconstructed
// TODO: should use a look-up table
// TODO: could cache lazily, stored in the entity

	angles[ROLL] = currententityFPM->angles[ROLL];
	angles[PITCH] = -currententityFPM->angles[PITCH];
	angles[YAW] = currententityFPM->angles[YAW];
	AngleVectorsFPM (angles, alias_forwardFPM, alias_rightFPM, alias_upFPM);

	tmatrix[0][0] = pmdlFPM->scale[0];
	tmatrix[1][1] = pmdlFPM->scale[1];
	tmatrix[2][2] = pmdlFPM->scale[2];

	tmatrix[0][3] = pmdlFPM->scale_origin[0];
	tmatrix[1][3] = pmdlFPM->scale_origin[1];
	tmatrix[2][3] = pmdlFPM->scale_origin[2];

// TODO: can do this with simple matrix rearrangement

	for (i=0 ; i<3 ; i++)
	{
		t2matrix[i][0] = alias_forwardFPM[i];
		t2matrix[i][1] = -alias_rightFPM[i];
		t2matrix[i][2] = alias_upFPM[i];
	}

	t2matrix[0][3] = -modelorgFPM[0];
	t2matrix[1][3] = -modelorgFPM[1];
	t2matrix[2][3] = -modelorgFPM[2];

// FIXME: can do more efficiently than full concatenation
	R_ConcatTransformsFPM (t2matrix, tmatrix, rotationmatrix);

// TODO: should be global, set when vright, etc., set
	VectorCopy (vrightFPM, viewmatrix[0]);
	VectorCopy (vupFPM, viewmatrix[1]);
	VectorInverseFPM (viewmatrix[1]);
	VectorCopy (vpnFPM, viewmatrix[2]);

//	viewmatrix[0][3] = 0;
//	viewmatrix[1][3] = 0;
//	viewmatrix[2][3] = 0;

	R_ConcatTransforms8_24FPM (viewmatrix, rotationmatrix, aliastransformFPM);

// do the scaling up of x and y to screen coordinates as part of the transform
// for the unclipped case (it would mess up clipping in the clipped case).
// Also scale down z, so 1/z is scaled 31 bits for free, and scale down x and y
// correspondingly so the projected x and y come out right
// FIXME: make this work for clipped case too?
	if (trivial_accept)
	{
		for (i=0 ; i<4 ; i++)
		{
			//Debug: deleteme:
			fixedpoint8_24_t tmp=FPM_FROMFLOATC8_24(((float)1.0) / ((float)0x8000 * 0x10000));
			float f=((float)1.0) / ((float)0x8000 * 0x10000);
			float f2=((float)0x8000 * 0x10000);
			//Dan: potential bug area (overflow / underflow)
			aliastransformFPM[0][i] = fpm_DivInt64_8_24(fpm_Mul8_24(aliastransformFPM[0][i], fpm_FromFixedPoint(aliasxscaleFPM)),
											(0x8000 * (__int64)0x10000));
			aliastransformFPM[1][i] = fpm_Mul8_24(aliastransformFPM[1][i],
										fpm_DivInt64_8_24(fpm_FromFixedPoint(aliasyscaleFPM),
											(0x8000 * (__int64)0x10000)));
			aliastransformFPM[2][i] = fpm_DivInt64_8_24(aliastransformFPM[2][i], (0x8000 * (__int64)0x10000));

//			aliastransformFPM[0][i] = fpm_Mul8_24(fpm_Mul8_24(aliastransformFPM[0][i], fpm_FromFixedPoint(aliasxscaleFPM)),
//					FPM_FROMFLOATC8_24(((float)1.0) / ((float)0x8000 * 0x10000)));
//			aliastransformFPM[1][i] = fpm_Mul8_24(fpm_Mul8_24(aliastransformFPM[1][i], fpm_FromFixedPoint(aliasyscaleFPM)),
//					FPM_FROMFLOATC8_24(((float)1.0) / ((float)0x8000 * 0x10000)));
//			aliastransformFPM[2][i] = fpm_Mul8_24(aliastransformFPM[2][i], FPM_FROMFLOATC8_24(((float)1.0) / ((float)0x8000 * 0x10000)));
//			aliastransformFPM[1][i] = FPM_FROMFLOAT(FPM_TOFLOAT(aliastransformFPM[1][i]) * FPM_TOFLOAT(aliasyscaleFPM)*
//					(((float)1.0) / ((float)0x8000 * 0x10000)));
//			aliastransformFPM[2][i] = FPM_FROMFLOAT(FPM_TOFLOAT(aliastransformFPM[2][i])* ((float)1.0) / ((float)0x8000 * 0x10000));

		}
	}
}
#endif //USEFPM

/*
================
R_AliasTransformFinalVert
================
*/
void R_AliasTransformFinalVert (finalvert_t *fv, auxvert_t *av,
	trivertx_t *pverts, stvert_t *pstverts)
{
	int		temp;
	float	lightcos, *plightnormal;

	av->fv[0] = DotProduct(pverts->v, aliastransform[0]) +
			aliastransform[0][3];
	av->fv[1] = DotProduct(pverts->v, aliastransform[1]) +
			aliastransform[1][3];
	av->fv[2] = DotProduct(pverts->v, aliastransform[2]) +
			aliastransform[2][3];

	fv->v[2] = pstverts->s;
	fv->v[3] = pstverts->t;

	fv->flags = pstverts->onseam;

// lighting
	plightnormal = r_avertexnormals[pverts->lightnormalindex];
	lightcos = DotProduct (plightnormal, r_plightvec);
	temp = r_ambientlight;

	if (lightcos < 0)
	{
		temp += (int)(r_shadelight * lightcos);

	// clamp; because we limited the minimum ambient and shading light, we
	// don't have to clamp low light, just bright
		if (temp < 0)
			temp = 0;
	}

	fv->v[4] = temp;
}


/*
================
R_AliasTransformFinalVert
================
*/
#ifdef USEFPM
void R_AliasTransformFinalVertFPM (finalvert_t *fv, auxvert_FPM_t *av,
	trivertx_t *pverts, stvert_t *pstverts)
{
	int		temp;
	fixedpoint_t	lightcos, *plightnormal;

	av->fv[0] = FPM_ADD(DotProduct8_24FPM(pverts->v, aliastransformFPM[0]),
			aliastransformFPM[0][3]);
	av->fv[1] = FPM_ADD(DotProduct8_24FPM(pverts->v, aliastransformFPM[1]),
			aliastransformFPM[1][3]);
	av->fv[2] = FPM_ADD(DotProduct8_24FPM(pverts->v, aliastransformFPM[2]),
			aliastransformFPM[2][3]);

	fv->v[2] = pstverts->s;
	fv->v[3] = pstverts->t;

	fv->flags = pstverts->onseam;

// lighting
	plightnormal = r_avertexnormalsFPM[pverts->lightnormalindex];
	lightcos = DotProductFPM (plightnormal, r_plightvecFPM);
	temp = r_ambientlight;

	if (lightcos < 0)
	{
		temp += FPM_TOLONG(FPM_MUL(r_shadelightFPM, lightcos));

	// clamp; because we limited the minimum ambient and shading light, we
	// don't have to clamp low light, just bright
		if (temp < 0)
			temp = 0;
	}

	fv->v[4] = temp;
}
#endif //USEFPM

#if	!id386

/*
================
R_AliasTransformAndProjectFinalVerts
================
*/
void R_AliasTransformAndProjectFinalVerts (finalvert_t *fv, stvert_t *pstverts)
{
	int			i, temp;
	float		lightcos, *plightnormal, zi;
	trivertx_t	*pverts;

	pverts = r_apverts;

	for (i=0 ; i<r_anumverts ; i++, fv++, pverts++, pstverts++)
	{
	// transform and project
		zi = ((float)1.0) / (DotProduct(pverts->v, aliastransform[2]) +
				aliastransform[2][3]);

	// x, y, and z are scaled down by 1/2**31 in the transform, so 1/z is
	// scaled up by 1/2**31, and the scaling cancels out for x and y in the
	// projection
		fv->v[5] = (int)zi;

		fv->v[0] = (int)(((DotProduct(pverts->v, aliastransform[0]) +
				aliastransform[0][3]) * zi) + aliasxcenter);
		fv->v[1] = (int)(((DotProduct(pverts->v, aliastransform[1]) +
				aliastransform[1][3]) * zi) + aliasycenter);

		fv->v[2] = pstverts->s;
		fv->v[3] = pstverts->t;
		fv->flags = pstverts->onseam;

	// lighting
		plightnormal = r_avertexnormals[pverts->lightnormalindex];
		lightcos = DotProduct (plightnormal, r_plightvec);
		temp = r_ambientlight;

		if (lightcos < 0)
		{
			temp += (int)(r_shadelight * lightcos);

		// clamp; because we limited the minimum ambient and shading light, we
		// don't have to clamp low light, just bright
			if (temp < 0)
				temp = 0;
		}

		fv->v[4] = temp;
	}
}

#ifdef USEFPM
void R_AliasTransformAndProjectFinalVertsFPM (finalvert_t *fv, stvert_t *pstverts)
{
	int				i, temp;
	fixedpoint_t	lightcos, *plightnormal, zi;
	trivertx_t		*pverts;
	vec3_FPM_t		danTmp;


	pverts = r_apverts;

	for (i=0 ; i<r_anumverts ; i++, fv++, pverts++, pstverts++)
	{
	// transform and project
		danTmp[0]=FPM_FROMLONG(pverts->v[0]);
		danTmp[1]=FPM_FROMLONG(pverts->v[1]);
		danTmp[2]=FPM_FROMLONG(pverts->v[2]);

		zi = FPM_INV(FPM_ADD(DotProduct8_24FPM(danTmp, aliastransformFPM[2]),
				aliastransformFPM[2][3]));

	// x, y, and z are scaled down by 1/2**31 in the transform, so 1/z is
	// scaled up by 1/2**31, and the scaling cancels out for x and y in the
	// projection
		fv->v[5] = FPM_TOLONG(zi);

		fv->v[0] = FPM_TOLONG(FPM_ADD(FPM_MUL(FPM_ADD(DotProduct8_24FPM(danTmp, aliastransformFPM[0]),
				aliastransformFPM[0][3]), zi), aliasxcenterFPM));
		fv->v[1] = FPM_TOLONG(FPM_ADD(FPM_MUL(FPM_ADD(DotProduct8_24FPM(danTmp, aliastransformFPM[1]),
				aliastransformFPM[1][3]), zi), aliasycenterFPM));

		fv->v[2] = pstverts->s;
		fv->v[3] = pstverts->t;
		fv->flags = pstverts->onseam;

	// lighting
		plightnormal = r_avertexnormalsFPM[pverts->lightnormalindex];
		lightcos = DotProductFPM (plightnormal, r_plightvecFPM);
		temp = r_ambientlight;

		if (lightcos < 0)
		{
			temp += FPM_TOLONG(FPM_MUL(r_shadelightFPM, lightcos));

		// clamp; because we limited the minimum ambient and shading light, we
		// don't have to clamp low light, just bright
			if (temp < 0)
				temp = 0;
		}

		fv->v[4] = temp;
	}
}
#endif //USEFPM
#endif


/*
================
R_AliasProjectFinalVert
================
*/
void R_AliasProjectFinalVert (finalvert_t *fv, auxvert_t *av)
{
	float	zi;

// project points
	zi = ((float)1.0) / av->fv[2];

	fv->v[5] = (int) (zi * ziscale);

	fv->v[0] = (int)((av->fv[0] * aliasxscale * zi) + aliasxcenter);
	fv->v[1] = (int)((av->fv[1] * aliasyscale * zi) + aliasycenter);
}

#ifdef USEFPM
void R_AliasProjectFinalVertFPM (finalvert_t *fv, auxvert_FPM_t *av)
{
	fixedpoint8_24_t	zi;
// project points
	zi = av->fv[2];
	zi = fpm_Inv8_24(zi);

	fv->v[5] = (long)(ziscaleFPM/fpm_ToLong(av->fv[2]));
//		fpm_ToFixedPoint(fpm_Mul8_24(ziscaleFPM, zi));

	fv->v[0] = FPM_TOLONG(FPM_ADD(fpm_MulMixed8_24(zi, fpm_Mul(av->fv[0],aliasxscaleFPM)), aliasxcenterFPM));
//	fv->v[0] = FPM_TOLONG(FPM_MUL(FPM_MUL(av->fv[0],aliasxscaleFPM),zi)) + aliasxcenterFPM;
//	fv->v[0] = (av->fv[0] * aliasxscale * zi) + aliasxcenter;
	fv->v[1] = FPM_TOLONG(FPM_ADD(fpm_MulMixed8_24(zi, fpm_Mul(av->fv[1],aliasxscaleFPM)), aliasycenterFPM));
//	fv->v[1] = FPM_TOLONG(FPM_MUL(FPM_MUL(av->fv[1],aliasxscaleFPM),zi)) + aliasycenterFPM;
//	fv->v[1] = (av->fv[1] * aliasyscale * zi) + aliasycenter;
}
#endif //USEFPM

/*
================
R_AliasPrepareUnclippedPoints
================
*/
void R_AliasPrepareUnclippedPoints (void)
{
	stvert_t	*pstverts;
	finalvert_t	*fv;

	pstverts = (stvert_t *)((byte *)paliashdr + paliashdr->stverts);
	r_anumverts = pmdl->numverts;
// FIXME: just use pfinalverts directly?
	fv = pfinalverts;

	R_AliasTransformAndProjectFinalVerts (fv, pstverts);

	if (r_affinetridesc.drawtype)
		D_PolysetDrawFinalVerts (fv, r_anumverts);

	r_affinetridesc.pfinalverts = pfinalverts;
	r_affinetridesc.ptriangles = (mtriangle_t *)
			((byte *)paliashdr + paliashdr->triangles);
	r_affinetridesc.numtriangles = pmdl->numtris;

	D_PolysetDraw ();
}

#ifdef USEFPM
void R_AliasPrepareUnclippedPointsFPM (void)
{
	stvert_t	*pstverts;
	finalvert_t	*fv;

	pstverts = (stvert_t *)((byte *)paliashdr + paliashdr->stverts);
	r_anumverts = pmdlFPM->numverts;
// FIXME: just use pfinalverts directly?
	fv = pfinalverts;

	R_AliasTransformAndProjectFinalVertsFPM (fv, pstverts);

	if (r_affinetridesc.drawtype)
		D_PolysetDrawFinalVertsFPM (fv, r_anumverts);

	r_affinetridesc.pfinalverts = pfinalverts;
	r_affinetridesc.ptriangles = (mtriangle_t *)
			((byte *)paliashdr + paliashdr->triangles);
	r_affinetridesc.numtriangles = pmdlFPM->numtris;

	D_PolysetDraw ();
}
#endif //USEFPM
/*
===============
R_AliasSetupSkin
===============
*/
void R_AliasSetupSkin (void)
{
	int					skinnum;
	int					i, numskins;
	maliasskingroup_t	*paliasskingroup;
	float				*pskinintervals, fullskininterval;
	float				skintargettime, skintime;

	skinnum = currententity->skinnum;
	if ((skinnum >= pmdl->numskins) || (skinnum < 0))
	{
		Con_DPrintf ("R_AliasSetupSkin: no such skin # %d\n", skinnum);
		skinnum = 0;
	}

	pskindesc = ((maliasskindesc_t *)
			((byte *)paliashdr + paliashdr->skindesc)) + skinnum;
	a_skinwidth = pmdl->skinwidth;

	if (pskindesc->type == ALIAS_SKIN_GROUP)
	{
		paliasskingroup = (maliasskingroup_t *)((byte *)paliashdr +
				pskindesc->skin);
		pskinintervals = (float *)
				((byte *)paliashdr + paliasskingroup->intervals);
		numskins = paliasskingroup->numskins;
		fullskininterval = pskinintervals[numskins-1];
	
		skintime = ((float)cl.time) + currententity->syncbase;
	
	// when loading in Mod_LoadAliasSkinGroup, we guaranteed all interval
	// values are positive, so we don't have to worry about division by 0
		skintargettime = skintime -
				((int)(skintime / fullskininterval)) * fullskininterval;
	
		for (i=0 ; i<(numskins-1) ; i++)
		{
			if (pskinintervals[i] > skintargettime)
				break;
		}
	
		pskindesc = &paliasskingroup->skindescs[i];
	}

	r_affinetridesc.pskindesc = pskindesc;
	r_affinetridesc.pskin = (void *)((byte *)paliashdr + pskindesc->skin);
	r_affinetridesc.skinwidth = a_skinwidth;
	r_affinetridesc.seamfixupX16 =  (a_skinwidth >> 1) << 16;
	r_affinetridesc.skinheight = pmdl->skinheight;
}

#ifdef USEFPM
void R_AliasSetupSkinFPM (void)
{
	int					skinnum;
	int					i, numskins;
	maliasskingroup_t	*paliasskingroup;
	fixedpoint_t		*pskinintervals, fullskininterval;
	float				skintargettime, skintime;

	skinnum = currententityFPM->skinnum;
	if ((skinnum >= pmdlFPM->numskins) || (skinnum < 0))
	{
		Con_DPrintf ("R_AliasSetupSkin: no such skin # %d\n", skinnum);
		skinnum = 0;
	}

	pskindesc = ((maliasskindesc_t *)
			((byte *)paliashdr + paliashdr->skindesc)) + skinnum;
	a_skinwidth = pmdlFPM->skinwidth;

	if (pskindesc->type == ALIAS_SKIN_GROUP)
	{
		paliasskingroup = (maliasskingroup_t *)((byte *)paliashdr +
				pskindesc->skin);
		//Dan: I'm not sure about the following...
		pskinintervals = (fixedpoint_t *)
				((byte *)paliashdr + paliasskingroup->intervals);
		numskins = paliasskingroup->numskins;
		fullskininterval = pskinintervals[numskins-1];
	
		skintime = ((float)clFPM.time) + currententityFPM->syncbase;
	
	// when loading in Mod_LoadAliasSkinGroup, we guaranteed all interval
	// values are positive, so we don't have to worry about division by 0
		skintargettime = skintime -
				((int)(skintime / fullskininterval)) * fullskininterval;
	
		for (i=0 ; i<(numskins-1) ; i++)
		{
			if (pskinintervals[i] > skintargettime)
				break;
		}
	
		pskindesc = &paliasskingroup->skindescs[i];
	}

	r_affinetridesc.pskindesc = pskindesc;
	r_affinetridesc.pskin = (void *)((byte *)paliashdr + pskindesc->skin);
	r_affinetridesc.skinwidth = a_skinwidth;
	r_affinetridesc.seamfixupX16 =  (a_skinwidth >> 1) << 16;
	r_affinetridesc.skinheight = pmdlFPM->skinheight;
}
#endif //USEFPM
/*
================
R_AliasSetupLighting
================
*/
void R_AliasSetupLighting (alight_t *plighting)
{

// guarantee that no vertex will ever be lit below LIGHT_MIN, so we don't have
// to clamp off the bottom
	r_ambientlight = plighting->ambientlight;

	if (r_ambientlight < LIGHT_MIN)
		r_ambientlight = LIGHT_MIN;

	r_ambientlight = (255 - r_ambientlight) << VID_CBITS;

	if (r_ambientlight < LIGHT_MIN)
		r_ambientlight = LIGHT_MIN;

	r_shadelight = (float)plighting->shadelight;

	if (r_shadelight < 0)
		r_shadelight = 0;

	r_shadelight *= VID_GRADES;

// rotate the lighting vector into the model's frame of reference
	r_plightvec[0] = DotProduct (plighting->plightvec, alias_forward);
	r_plightvec[1] = -DotProduct (plighting->plightvec, alias_right);
	r_plightvec[2] = DotProduct (plighting->plightvec, alias_up);
}

#ifdef USEFPM
void R_AliasSetupLightingFPM (alight_FPM_t *plighting)
{

// guarantee that no vertex will ever be lit below LIGHT_MIN, so we don't have
// to clamp off the bottom
	r_ambientlight = plighting->ambientlight;

	if (r_ambientlight < LIGHT_MIN)
		r_ambientlight = LIGHT_MIN;

	r_ambientlight = (255 - r_ambientlight) << VID_CBITS;

	if (r_ambientlight < LIGHT_MIN)
		r_ambientlight = LIGHT_MIN;

	r_shadelightFPM = FPM_FROMLONG(plighting->shadelight);

	if (r_shadelightFPM < 0)
		r_shadelightFPM = 0;

	r_shadelightFPM = FPM_MUL(r_shadelightFPM, FPM_FROMLONG(VID_GRADES));

// rotate the lighting vector into the model's frame of reference
	r_plightvecFPM[0] = DotProductFPM (plighting->plightvec, alias_forwardFPM);
	r_plightvecFPM[1] = -DotProductFPM (plighting->plightvec, alias_rightFPM);
	r_plightvecFPM[2] = DotProductFPM (plighting->plightvec, alias_upFPM);
}
#endif //USEFPM
/*
=================
R_AliasSetupFrame

set r_apverts
=================
*/
void R_AliasSetupFrame (void)
{
	int				frame;
	int				i, numframes;
	maliasgroup_t	*paliasgroup;
	float			*pintervals, fullinterval, targettime, time;

	frame = currententity->frame;
	if ((frame >= pmdl->numframes) || (frame < 0))
	{
		Con_DPrintf ("R_AliasSetupFrame: no such frame %d\n", frame);
		frame = 0;
	}

	if (paliashdr->frames[frame].type == ALIAS_SINGLE)
	{
		r_apverts = (trivertx_t *)
				((byte *)paliashdr + paliashdr->frames[frame].frame);
		return;
	}
	
	paliasgroup = (maliasgroup_t *)
				((byte *)paliashdr + paliashdr->frames[frame].frame);
	pintervals = (float *)((byte *)paliashdr + paliasgroup->intervals);
	numframes = paliasgroup->numframes;
	fullinterval = pintervals[numframes-1];

	time = ((float)cl.time) + currententity->syncbase;

//
// when loading in Mod_LoadAliasGroup, we guaranteed all interval values
// are positive, so we don't have to worry about division by 0
//
	targettime = time - ((int)(time / fullinterval)) * fullinterval;

	for (i=0 ; i<(numframes-1) ; i++)
	{
		if (pintervals[i] > targettime)
			break;
	}

	r_apverts = (trivertx_t *)
				((byte *)paliashdr + paliasgroup->frames[i].frame);
}

#ifdef USEFPM
void R_AliasSetupFrameFPM (void)
{
	int				frame;
	int				i, numframes;
	maliasgroup_t	*paliasgroup;
	float			*pintervals, fullinterval, targettime, time;

	frame = currententityFPM->frame;
	if ((frame >= pmdlFPM->numframes) || (frame < 0))
	{
		Con_DPrintf ("R_AliasSetupFrame: no such frame %d\n", frame);
		frame = 0;
	}

	if (paliashdr->frames[frame].type == ALIAS_SINGLE)
	{
		r_apverts = (trivertx_t *)
				((byte *)paliashdr + paliashdr->frames[frame].frame);
		return;
	}
	
	paliasgroup = (maliasgroup_t *)
				((byte *)paliashdr + paliashdr->frames[frame].frame);
	pintervals = (float *)((byte *)paliashdr + paliasgroup->intervals);
	numframes = paliasgroup->numframes;
	fullinterval = pintervals[numframes-1];

	time = ((float)clFPM.time) + currententityFPM->syncbase;

//
// when loading in Mod_LoadAliasGroup, we guaranteed all interval values
// are positive, so we don't have to worry about division by 0
//
	targettime = time - ((int)(time / fullinterval)) * fullinterval;

	for (i=0 ; i<(numframes-1) ; i++)
	{
		if (pintervals[i] > targettime)
			break;
	}

	r_apverts = (trivertx_t *)
				((byte *)paliashdr + paliasgroup->frames[i].frame);
}
#endif //USEFPM
/*
================
R_AliasDrawModel
================
*/
void R_AliasDrawModel (alight_t *plighting)
{
	finalvert_t		finalverts[MAXALIASVERTS +
						((CACHE_SIZE - 1) / sizeof(finalvert_t)) + 1];
	auxvert_t		auxverts[MAXALIASVERTS];

	r_amodels_drawn++;

// cache align
	pfinalverts = (finalvert_t *)
			(((long)&finalverts[0] + CACHE_SIZE - 1) & ~(CACHE_SIZE - 1));
	pauxverts = &auxverts[0];

	paliashdr = (aliashdr_t *)Mod_Extradata (currententity->model);
	pmdl = (mdl_t *)((byte *)paliashdr + paliashdr->model);

	R_AliasSetupSkin ();
	R_AliasSetUpTransform (currententity->trivial_accept);
	R_AliasSetupLighting (plighting);
	R_AliasSetupFrame ();

	if (!currententity->colormap)
		Sys_Error ("R_AliasDrawModel: !currententity->colormap");

	r_affinetridesc.drawtype = (currententity->trivial_accept == 3) &&
			r_recursiveaffinetriangles;

	if (r_affinetridesc.drawtype)
	{
		D_PolysetUpdateTables ();		// FIXME: precalc...
	}
	else
	{
#if	id386
		D_Aff8Patch (currententity->colormap);
#endif
	}

	acolormap = currententity->colormap;

	if (currententity != &cl.viewent)
		ziscale = (float)0x8000 * (float)0x10000;
	else
		ziscale = (float)0x8000 * (float)0x10000 * 3.0;

	if (currententity->trivial_accept)
		R_AliasPrepareUnclippedPoints ();
	else
		R_AliasPreparePoints ();
}

#ifdef USEFPM
void R_AliasDrawModelFPM (alight_FPM_t *plighting)
{
	finalvert_t		finalverts[MAXALIASVERTS +
						((CACHE_SIZE - 1) / sizeof(finalvert_t)) + 1];
	auxvert_FPM_t	auxverts[MAXALIASVERTS];

	return;

	r_amodels_drawn++;

// cache align
	pfinalverts = (finalvert_t *)
			(((long)&finalverts[0] + CACHE_SIZE - 1) & ~(CACHE_SIZE - 1));
	pauxvertsFPM = &auxverts[0];

	paliashdr = (aliashdr_t *)Mod_ExtradataFPM (currententityFPM->model);
	pmdlFPM = (mdl_FPM_t *)((byte *)paliashdr + paliashdr->model);

	R_AliasSetupSkinFPM ();
	R_AliasSetUpTransformFPM (currententityFPM->trivial_accept);
	R_AliasSetupLightingFPM (plighting);
	R_AliasSetupFrameFPM ();

	if (!currententityFPM->colormap)
		Sys_Error ("R_AliasDrawModel: !currententity->colormap");

	r_affinetridesc.drawtype = (currententityFPM->trivial_accept == 3) &&
			r_recursiveaffinetriangles;

	if (r_affinetridesc.drawtype)
	{
		D_PolysetUpdateTables ();		// FIXME: precalc...
	}
	else
	{
#if	id386
		D_Aff8Patch (currententityFPM->colormap);
#endif
	}

	acolormap = currententityFPM->colormap;

	if (currententityFPM != &clFPM.viewent)
		ziscaleFPM = ((unsigned long)0x8000 * (unsigned long)0x10000);
	else {
		ziscaleFPM = ((unsigned long)0x8000 * (unsigned long)0x10000);
		ziscaleFPM *= 3;
	}

	if (currententityFPM->trivial_accept)
		R_AliasPrepareUnclippedPointsFPM ();
	else
		R_AliasPreparePointsFPM ();
}
#endif //USEFPM