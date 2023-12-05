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
// d_scan.c
//
// Portable C scan-level rasterization code, all pixel depths.

#include "quakedef.h"
#include "r_local.h"
#include "d_local.h"

unsigned char	*r_turb_pbase, *r_turb_pdest;
fixed16_t		r_turb_s, r_turb_t, r_turb_sstep, r_turb_tstep;
int				*r_turb_turb;
int				r_turb_spancount;

void D_DrawTurbulent8Span (void);


/*
=============
D_WarpScreen

// this performs a slight compression of the screen at the same time as
// the sine warp, to keep the edges from wrapping
=============
*/
void D_WarpScreen (void)
{
	int		w, h;
	int		u,v;
	byte	*dest;
	int		*turb;
	int		*col;
	byte	**row;
	byte	*rowptr[MAXHEIGHT+(AMP2*2)];
	int		column[MAXWIDTH+(AMP2*2)];
	float	wratio, hratio;

	w = r_refdef.vrect.width;
	h = r_refdef.vrect.height;

	wratio = w / (float)scr_vrect.width;
	hratio = h / (float)scr_vrect.height;

	for (v=0 ; v<scr_vrect.height+AMP2*2 ; v++)
	{
		rowptr[v] = d_viewbuffer + (r_refdef.vrect.y * screenwidth) +
				 (screenwidth * (int)((float)v * hratio * h / (h + AMP2 * 2)));
	}

	for (u=0 ; u<scr_vrect.width+AMP2*2 ; u++)
	{
		column[u] = r_refdef.vrect.x +
				(int)((float)u * wratio * w / (w + AMP2 * 2));
	}

	turb = intsintable + ((int)(cl.time*SPEED)&(CYCLE-1));
	dest = vid.buffer + scr_vrect.y * vid.rowbytes + scr_vrect.x;

	for (v=0 ; v<scr_vrect.height ; v++, dest += vid.rowbytes)
	{
		col = &column[turb[v]];
		row = &rowptr[v];

		for (u=0 ; u<scr_vrect.width ; u+=4)
		{
			dest[u+0] = row[turb[u+0]][col[u+0]];
			dest[u+1] = row[turb[u+1]][col[u+1]];
			dest[u+2] = row[turb[u+2]][col[u+2]];
			dest[u+3] = row[turb[u+3]][col[u+3]];
		}
		R_Slowdraw();
	}
}


#if	!id386

/*
=============
D_DrawTurbulent8Span
=============
*/
void D_DrawTurbulent8Span (void)
{
	int		sturb, tturb;

	do
	{
		sturb = ((r_turb_s + r_turb_turb[(r_turb_t>>16)&(CYCLE-1)])>>16)&63;
		tturb = ((r_turb_t + r_turb_turb[(r_turb_s>>16)&(CYCLE-1)])>>16)&63;
		*r_turb_pdest++ = *(r_turb_pbase + (tturb<<6) + sturb);
		r_turb_s += r_turb_sstep;
		r_turb_t += r_turb_tstep;
		R_Slowdraw();
	} while (--r_turb_spancount > 0);
}

#endif	// !id386


/*
=============
Turbulent8
=============
*/
void Turbulent8 (espan_t *pspan)
{
	int				count;
	fixed16_t		snext, tnext;
	float			sdivz, tdivz, zi, z, du, dv, spancountminus1;
	float			sdivz16stepu, tdivz16stepu, zi16stepu;
	
	r_turb_turb = sintable + ((int)(cl.time*SPEED)&(CYCLE-1));

	r_turb_sstep = 0;	// keep compiler happy
	r_turb_tstep = 0;	// ditto

	r_turb_pbase = (unsigned char *)cacheblock;

	sdivz16stepu = d_sdivzstepu * 16;
	tdivz16stepu = d_tdivzstepu * 16;
	zi16stepu = d_zistepu * 16;

	R_Slowdraw();

	do
	{
		r_turb_pdest = (unsigned char *)((byte *)d_viewbuffer +
				(screenwidth * pspan->v) + pspan->u);

		count = pspan->count;

	// calculate the initial s/z, t/z, 1/z, s, and t and clamp
		du = (float)pspan->u;
		dv = (float)pspan->v;

		sdivz = d_sdivzorigin + dv*d_sdivzstepv + du*d_sdivzstepu;
		tdivz = d_tdivzorigin + dv*d_tdivzstepv + du*d_tdivzstepu;
		zi = d_ziorigin + dv*d_zistepv + du*d_zistepu;
		z = (float)0x10000 / zi;	// prescale to 16.16 fixed-point

		r_turb_s = (int)(sdivz * z) + sadjust;
		if (r_turb_s > bbextents)
			r_turb_s = bbextents;
		else if (r_turb_s < 0)
			r_turb_s = 0;

		r_turb_t = (int)(tdivz * z) + tadjust;
		if (r_turb_t > bbextentt)
			r_turb_t = bbextentt;
		else if (r_turb_t < 0)
			r_turb_t = 0;

		do
		{
		// calculate s and t at the far end of the span
			if (count >= 16)
				r_turb_spancount = 16;
			else
				r_turb_spancount = count;

			count -= r_turb_spancount;

			if (count)
			{
			// calculate s/z, t/z, zi->fixed s and t at far end of span,
			// calculate s and t steps across span by shifting
				sdivz += sdivz16stepu;
				tdivz += tdivz16stepu;
				zi += zi16stepu;
				z = (float)0x10000 / zi;	// prescale to 16.16 fixed-point

				snext = (int)(sdivz * z) + sadjust;
				if (snext > bbextents)
					snext = bbextents;
				else if (snext < 16)
					snext = 16;	// prevent round-off error on <0 steps from
								//  from causing overstepping & running off the
								//  edge of the texture

				tnext = (int)(tdivz * z) + tadjust;
				if (tnext > bbextentt)
					tnext = bbextentt;
				else if (tnext < 16)
					tnext = 16;	// guard against round-off error on <0 steps

				r_turb_sstep = (snext - r_turb_s) >> 4;
				r_turb_tstep = (tnext - r_turb_t) >> 4;
			}
			else
			{
			// calculate s/z, t/z, zi->fixed s and t at last pixel in span (so
			// can't step off polygon), clamp, calculate s and t steps across
			// span by division, biasing steps low so we don't run off the
			// texture
				spancountminus1 = (float)(r_turb_spancount - 1);
				sdivz += d_sdivzstepu * spancountminus1;
				tdivz += d_tdivzstepu * spancountminus1;
				zi += d_zistepu * spancountminus1;
				z = (float)0x10000 / zi;	// prescale to 16.16 fixed-point
				snext = (int)(sdivz * z) + sadjust;
				if (snext > bbextents)
					snext = bbextents;
				else if (snext < 16)
					snext = 16;	// prevent round-off error on <0 steps from
								//  from causing overstepping & running off the
								//  edge of the texture

				tnext = (int)(tdivz * z) + tadjust;
				if (tnext > bbextentt)
					tnext = bbextentt;
				else if (tnext < 16)
					tnext = 16;	// guard against round-off error on <0 steps

				if (r_turb_spancount > 1)
				{
					r_turb_sstep = (snext - r_turb_s) / (r_turb_spancount - 1);
					r_turb_tstep = (tnext - r_turb_t) / (r_turb_spancount - 1);
				}
			}

			r_turb_s = r_turb_s & ((CYCLE<<16)-1);
			r_turb_t = r_turb_t & ((CYCLE<<16)-1);

			D_DrawTurbulent8Span ();

			r_turb_s = snext;
			r_turb_t = tnext;

		} while (count > 0);

	} while ((pspan = pspan->pnext) != NULL);
}


#if	!id386

/*
=============
D_DrawSpans8
=============
*/
void D_DrawSpans8 (espan_t *pspan)
{
	int				count, spancount;
	unsigned char	*pbase, *pdest;
	unsigned short	*zsrc;
	fixed16_t		s, t, snext, tnext, sstep, tstep;
	float			sdivz, tdivz, zi, z, du, dv, spancountminus1;
	float			sdivz8stepu, tdivz8stepu, zi8stepu;
	int				izi;

	sstep = 0;	// keep compiler happy
	tstep = 0;	// ditto

	pbase = (unsigned char *)cacheblock;

	sdivz8stepu = d_sdivzstepu * 8;
	tdivz8stepu = d_tdivzstepu * 8;
	zi8stepu = d_zistepu * 8;

	do
	{
		pdest = (unsigned char *)((byte *)d_viewbuffer + (screenwidth * pspan->v) + pspan->u);
		zsrc = d_pzbuffer + (d_zwidth * pspan->v) + pspan->u;
		
		count = pspan->count;

	// calculate the initial s/z, t/z, 1/z, s, and t and clamp
		du = (float)pspan->u;
		dv = (float)pspan->v;

		sdivz = d_sdivzorigin + dv*d_sdivzstepv + du*d_sdivzstepu;
		tdivz = d_tdivzorigin + dv*d_tdivzstepv + du*d_tdivzstepu;
		izi = *zsrc << 16;
		zi = (((double)izi) / 0x10000) / 0x8000;
		//zi = d_ziorigin + dv*d_zistepv + du*d_zistepu;
		
		z = (float)0x10000 / zi;	// prescale to 16.16 fixed-point

		s = (int)(sdivz * z) + sadjust;
		if (s > bbextents)
			s = bbextents;
		else if (s < 0)
			s = 0;

		t = (int)(tdivz * z) + tadjust;
		if (t > bbextentt)
			t = bbextentt;
		else if (t < 0)
			t = 0;

		do
		{
		// calculate s and t at the far end of the span
			if (count >= 8)
				spancount = 8;
			else
				spancount = count;

			count -= spancount;

			if (count)
			{
			// calculate s/z, t/z, zi->fixed s and t at far end of span,
			// calculate s and t steps across span by shifting
				sdivz += sdivz8stepu;
				tdivz += tdivz8stepu;
				zi += zi8stepu;
				z = (float)0x10000 / zi;	// prescale to 16.16 fixed-point

				snext = (int)(sdivz * z) + sadjust;
				if (snext > bbextents)
					snext = bbextents;
				else if (snext < 8)
					snext = 8;	// prevent round-off error on <0 steps from
								//  from causing overstepping & running off the
								//  edge of the texture

				tnext = (int)(tdivz * z) + tadjust;
				if (tnext > bbextentt)
					tnext = bbextentt;
				else if (tnext < 8)
					tnext = 8;	// guard against round-off error on <0 steps

				sstep = (snext - s) >> 3;
				tstep = (tnext - t) >> 3;
			}
			else
			{
			// calculate s/z, t/z, zi->fixed s and t at last pixel in span (so
			// can't step off polygon), clamp, calculate s and t steps across
			// span by division, biasing steps low so we don't run off the
			// texture
				spancountminus1 = (float)(spancount - 1);
				sdivz += d_sdivzstepu * spancountminus1;
				tdivz += d_tdivzstepu * spancountminus1;
				zi += d_zistepu * spancountminus1;
				z = (float)0x10000 / zi;	// prescale to 16.16 fixed-point
				snext = (int)(sdivz * z) + sadjust;
				if (snext > bbextents)
					snext = bbextents;
				else if (snext < 8)
					snext = 8;	// prevent round-off error on <0 steps from
								//  from causing overstepping & running off the
								//  edge of the texture

				tnext = (int)(tdivz * z) + tadjust;
				if (tnext > bbextentt)
					tnext = bbextentt;
				else if (tnext < 8)
					tnext = 8;	// guard against round-off error on <0 steps

				if (spancount > 1)
				{
					sstep = (snext - s) / (spancount - 1);
					tstep = (tnext - t) / (spancount - 1);
				}
			}

			do
			{
				*pdest++ = *(pbase + (s >> 16) + (t >> 16) * cachewidth);
				s += sstep;
				t += tstep;
			} while (--spancount > 0);

			s = snext;
			t = tnext;

		} while (count > 0);

	} while ((pspan = pspan->pnext) != NULL);
}

#endif

/*
=============
D_DrawSpans8
=============
*/
void D_DrawSpansZIndexed (espan_t *pspan)
{
	int				count, spancount;
	unsigned char	*pbase, *pdest;
	unsigned short	*zsrc;
	fixed16_t		s, t, snext, tnext, sstep, tstep;
	float			sdivz, tdivz, zi, z, du, dv, spancountminus1;
	float			sdivz8stepu, tdivz8stepu, zi8stepu;
	int				izi;

	sstep = 0;	// keep compiler happy
	tstep = 0;	// ditto

	pbase = (unsigned char *)cacheblock;

	sdivz8stepu = d_sdivzstepu * 8;
	tdivz8stepu = d_tdivzstepu * 8;
	zi8stepu = d_zistepu * 8;

	do
	{
		pdest = (unsigned char *)((byte *)d_viewbuffer + (screenwidth * pspan->v) + pspan->u);
		zsrc = d_pzbuffer + (d_zwidth * pspan->v) + pspan->u;
		
		count = pspan->count;

	// calculate the initial s/z, t/z, 1/z, s, and t and clamp
		du = (float)pspan->u;
		dv = (float)pspan->v;

		sdivz = d_sdivzorigin + dv*d_sdivzstepv + du*d_sdivzstepu;
		tdivz = d_tdivzorigin + dv*d_tdivzstepv + du*d_tdivzstepu;
		izi = *zsrc << 16;
		zi = (((double)izi) / 0x10000) / 0x8000;		
		z = (float)0x10000 / zi;	// prescale to 16.16 fixed-point

		s = (int)(sdivz * z) + sadjust;
		if (s > bbextents)
			s = bbextents;
		else if (s < 0)
			s = 0;

		t = (int)(tdivz * z) + tadjust;
		if (t > bbextentt)
			t = bbextentt;
		else if (t < 0)
			t = 0;

		do
		{
		// calculate s and t at the far end of the span
			if (count >= 8)
				spancount = 8;
			else
				spancount = count;

			count -= spancount;

			if (count)
			{
			// calculate s/z, t/z, zi->fixed s and t at far end of span,
			// calculate s and t steps across span by shifting
				sdivz += sdivz8stepu;
				tdivz += tdivz8stepu;
				zi += zi8stepu;
				z = (float)0x10000 / zi;	// prescale to 16.16 fixed-point

				snext = (int)(sdivz * z) + sadjust;
				if (snext > bbextents)
					snext = bbextents;
				else if (snext < 8)
					snext = 8;	// prevent round-off error on <0 steps from
								//  from causing overstepping & running off the
								//  edge of the texture

				tnext = (int)(tdivz * z) + tadjust;
				if (tnext > bbextentt)
					tnext = bbextentt;
				else if (tnext < 8)
					tnext = 8;	// guard against round-off error on <0 steps

				sstep = (snext - s) >> 3;
				tstep = (tnext - t) >> 3;
			}
			else
			{
			// calculate s/z, t/z, zi->fixed s and t at last pixel in span (so
			// can't step off polygon), clamp, calculate s and t steps across
			// span by division, biasing steps low so we don't run off the
			// texture
				spancountminus1 = (float)(spancount - 1);
				sdivz += d_sdivzstepu * spancountminus1;
				tdivz += d_tdivzstepu * spancountminus1;
				zi += d_zistepu * spancountminus1;
				z = (float)0x10000 / zi;	// prescale to 16.16 fixed-point
				snext = (int)(sdivz * z) + sadjust;
				if (snext > bbextents)
					snext = bbextents;
				else if (snext < 8)
					snext = 8;	// prevent round-off error on <0 steps from
								//  from causing overstepping & running off the
								//  edge of the texture

				tnext = (int)(tdivz * z) + tadjust;
				if (tnext > bbextentt)
					tnext = bbextentt;
				else if (tnext < 8)
					tnext = 8;	// guard against round-off error on <0 steps

				if (spancount > 1)
				{
					sstep = (snext - s) / (spancount - 1);
					tstep = (tnext - t) / (spancount - 1);
				}
			}

			do
			{
				*pdest++ = ((int)z) % 256;
				s += sstep;
				t += tstep;
			} while (--spancount > 0);

			s = snext;
			t = tnext;

		} while (count > 0);

	} while ((pspan = pspan->pnext) != NULL);
}

//qbism: pointer to pbase and macroize idea from mankrip
#define WRITEPDEST(i)   { pdest[i] = *(pbase + (s >> 16) + (t >> 16) * cachewidth); s+=sstep; t+=tstep;}

#if	!id386

/*
=============
D_DrawSpans16

FIXME: actually make this subdivide by 16 instead of 8!!!  qb:  OK!!!!
=============
*/

/*==============================================
//unrolled- mh, MK, qbism
//============================================*/


//qb: this one does a simple motion blur, but leaves artificacts (smears on walls) due to alphamap imperfections.
//#define WRITEPDEST_MB(i)  { pdest[i] = vid.alphamap[*(pbase + (s >> 16) + (t >> 16) * cachewidth)*256+pdest[i]]; s+=sstep; t+=tstep;}

void D_DrawSpans16(espan_t *pspan) //qb: up it from 8 to 16.  This + unroll = big speed gain!
{
	int				count, spancount;
	unsigned char	*pbase, *pdest;
	unsigned short	*zsrc;
	fixed16_t		s, t, snext, tnext, sstep, tstep;
	float			sdivz, tdivz, zi, z, du, dv, spancountminus1;
	float			sdivzstepu, tdivzstepu, zistepu;
	int				izi;

	sstep = 0;   // keep compiler happy
	tstep = 0;   // ditto

	pbase = (byte *)cacheblock;
	sdivzstepu = d_sdivzstepu * 16;
	tdivzstepu = d_tdivzstepu * 16;
	zistepu = d_zistepu * 16;

	do
	{
		pdest = (byte *)((byte *)d_viewbuffer + (screenwidth * pspan->v) + pspan->u);
		count = pspan->count >> 4;

		spancount = pspan->count % 16;

		// calculate the initial s/z, t/z, 1/z, s, and t and clamp
		du = (float)pspan->u;
		dv = (float)pspan->v;

		sdivz = d_sdivzorigin + dv*d_sdivzstepv + du*d_sdivzstepu;
		tdivz = d_tdivzorigin + dv*d_tdivzstepv + du*d_tdivzstepu;
		zi = d_ziorigin + dv*d_zistepv + du*d_zistepu;
		z = (float)0x10000 / zi;   // prescale to 16.16 fixed-point

		s = (int)(sdivz * z) + sadjust;
		if (s < 0) s = 0;
		else if (s > bbextents) s = bbextents;

		t = (int)(tdivz * z) + tadjust;
		if (t < 0) t = 0;
		else if (t > bbextentt) t = bbextentt;

		R_Slowdraw();
		
		while (count-- > 0) // Manoel Kasimier
		{
			sdivz += sdivzstepu;
			tdivz += tdivzstepu;
			zi += zistepu;
			z = (float)0x10000 / zi;   // prescale to 16.16 fixed-point

			snext = (int)(sdivz * z) + sadjust;
			if (snext < 16) snext = 16;
			else if (snext > bbextents) snext = bbextents;

			tnext = (int)(tdivz * z) + tadjust;
			if (tnext < 16) tnext = 16;
			else if (tnext > bbextentt) tnext = bbextentt;

			sstep = (snext - s) >> 4;
			tstep = (tnext - t) >> 4;
			pdest += 16;
			WRITEPDEST(-16);
			WRITEPDEST(-15);
			WRITEPDEST(-14);
			WRITEPDEST(-13);
			WRITEPDEST(-12);
			WRITEPDEST(-11);
			WRITEPDEST(-10);
			WRITEPDEST(-9);
			WRITEPDEST(-8);
			WRITEPDEST(-7);
			WRITEPDEST(-6);
			WRITEPDEST(-5);
			WRITEPDEST(-4);
			WRITEPDEST(-3);
			WRITEPDEST(-2);
			WRITEPDEST(-1);
			s = snext;
			t = tnext;

			R_Slowdraw();
		}
		if (spancount > 0)
		{
			spancountminus1 = (float)(spancount - 1);
			sdivz += d_sdivzstepu * spancountminus1;
			tdivz += d_tdivzstepu * spancountminus1;
			zi += d_zistepu * spancountminus1;
			z = (float)0x10000 / zi;   // prescale to 16.16 fixed-point

			snext = (int)(sdivz * z) + sadjust;
			if (snext < 16) snext = 16;
			else if (snext > bbextents) snext = bbextents;

			tnext = (int)(tdivz * z) + tadjust;
			if (tnext < 16) tnext = 16;
			else if (tnext > bbextentt) tnext = bbextentt;

			if (spancount > 1)
			{
				sstep = (snext - s) / (spancount - 1);
				tstep = (tnext - t) / (spancount - 1);
			}

			pdest += spancount;

			switch (spancount)
			{
			case 16:
				WRITEPDEST(-16);
			case 15:
				WRITEPDEST(-15);
			case 14:
				WRITEPDEST(-14);
			case 13:
				WRITEPDEST(-13);
			case 12:
				WRITEPDEST(-12);
			case 11:
				WRITEPDEST(-11);
			case 10:
				WRITEPDEST(-10);
			case  9:
				WRITEPDEST(-9);
			case  8:
				WRITEPDEST(-8);
			case  7:
				WRITEPDEST(-7);
			case  6:
				WRITEPDEST(-6);
			case  5:
				WRITEPDEST(-5);
			case  4:
				WRITEPDEST(-4);
			case  3:
				WRITEPDEST(-3);
			case  2:
				WRITEPDEST(-2);
			case  1:
				WRITEPDEST(-1);
				break;
			}
			R_Slowdraw();
		}
	} while ((pspan = pspan->pnext) != NULL);
}

#endif

//#if	!id386

/*
=============
D_DrawSpansCHorz

draw spans for surfaces with horizontal constant-z
=============
*/
void D_DrawSpansCHorz (espan_t *pspan)
{
	int				spancount, i;
	unsigned char	*pbase, *pdest;
	fixed16_t		s, t, snext, tnext, sstep, tstep;
	float			sdivz, tdivz, zi, z, du, dv, spancountminus1;
	float			sdivzstepu, tdivzstepu;
	int				izi;

	sstep = 0;   // keep compiler happy
	tstep = 0;   // ditto

	pbase = (byte *)cacheblock;
	sdivzstepu = d_sdivzstepu * 16;
	tdivzstepu = d_tdivzstepu * 16;

	do
	{
		pdest = (byte *)((byte *)d_viewbuffer + (screenwidth * pspan->v) + pspan->u);

		spancount = pspan->count;

		// calculate the initial s/z, t/z, 1/z, s, and t and clamp
		du = (float)pspan->u;
		dv = (float)pspan->v;

		sdivz = d_sdivzorigin + dv*d_sdivzstepv + du*d_sdivzstepu;
		tdivz = d_tdivzorigin + dv*d_tdivzstepv + du*d_tdivzstepu;
		zi = d_ziorigin + dv*d_zistepv + du*d_zistepu;
		z = (float)0x10000 / zi;   // prescale to 16.16 fixed-point

		s = (int)(sdivz * z) + sadjust;
		if (s < 0) s = 0;
		else if (s > bbextents) s = bbextents;

		t = (int)(tdivz * z) + tadjust;
		if (t < 0) t = 0;
		else if (t > bbextentt) t = bbextentt;
		
		R_Slowdraw();
		
		// {
			spancountminus1 = (float)(spancount - 1);
			sdivz += d_sdivzstepu * spancountminus1;
			tdivz += d_tdivzstepu * spancountminus1;

			snext = (int)(sdivz * z) + sadjust;
			if (snext > bbextents) snext = bbextents;

			tnext = (int)(tdivz * z) + tadjust;
			if (tnext > bbextentt) tnext = bbextentt;

			if (spancount > 1)
			{
				sstep = (snext - s) / (spancount - 1);
				tstep = (tnext - t) / (spancount - 1);
			}

			i = 0;
			switch( spancount % 16 ) {
				case 0: do {	WRITEPDEST(i++);
				case 15:		WRITEPDEST(i++);
				case 14:		WRITEPDEST(i++);
				case 13:		WRITEPDEST(i++);
				case 12:		WRITEPDEST(i++);
				case 11:		WRITEPDEST(i++);
				case 10:		WRITEPDEST(i++);
				case 9:			WRITEPDEST(i++);
				case 8:			WRITEPDEST(i++);
				case 7: 		WRITEPDEST(i++);
				case 6: 		WRITEPDEST(i++);
				case 5: 		WRITEPDEST(i++);
				case 4: 		WRITEPDEST(i++);
				case 3: 		WRITEPDEST(i++);
				case 2: 		WRITEPDEST(i++);
				case 1: 		WRITEPDEST(i++);
				} while ( i < spancount );
				break;
			}

			R_Slowdraw();
		// }
	} while ((pspan = pspan->pnext) != NULL);
}

//#endif

#if	!id386

/*
=============
D_DrawZSpans
=============
*/

#ifdef USE_MMX
#include <mmintrin.h>

void D_DrawZSpans( espan_t *pspan ) {
    int count, doublecount, izistep, izistepv, iziorigin;
    int izi, idu, idv;
    short *pdest;
    __m64 ltemp, mzero, mstep, mizi;

    // convert zistepu, zistepv, and ziorigin to 16.16 fixed point
    // FIXME: check for clamping/range problems
    // we count on FP exceptions being turned off to avoid range problems
    izistep = (int)( d_zistepu * 0x8000 * 0x10000 );
    izistepv = (int)( d_zistepv * 0x8000 * 0x10000 );
    iziorigin = (int)( d_ziorigin * 0x8000 * 0x10000 );

    mstep = _mm_set_pi32( izistep, izistep );
    mzero = _mm_set_pi32( 0, 0 );

    do {
        pdest = d_pzbuffer + ( d_zwidth * pspan->v ) + pspan->u;
        count = pspan->count;

        // calculate the initial 1/z value
        izi = iziorigin + pspan->v * izistepv + pspan->u * izistep;

        // if the destination is not 32-bit aligned, do one pixel (16-bit) to align to 32 bit
        if ( (long)pdest & 0x02 ) {
            *pdest++ = (short)( izi >> 16 );
            izi += izistep;
            count--;
        }

        // do the thing
        if ( ( doublecount = count >> 1 ) > 0 ) {
            mizi = _mm_set_pi32( izi + izistep, izi );
            do {
                mizi = _mm_add_pi32(mizi, mstep);
                ltemp = _mm_unpacklo_pi16( mzero, mizi );
                ltemp = _mm_unpackhi_pi16( ltemp, mizi );
                ltemp = _mm_srli_si64 (ltemp, 32);
                *(int *)pdest = _m_to_int( ltemp );
                pdest += 2;
            } while ( --doublecount > 0 );
        }

        // if there's a stray pixel left, deal with it
        if ( count & 1 )
            *pdest = (short)( izi >> 16 );

    } while ( ( pspan = pspan->pnext ) != NULL );

    _mm_empty();
}
#else
void D_DrawZSpans (espan_t *pspan)
{
	int				count, doublecount, izistep;
	int				izi;
	short			*pdest;
	unsigned		ltemp;
	double			zi;
	float			du, dv;

// FIXME: check for clamping/range problems
// we count on FP exceptions being turned off to avoid range problems
	izistep = (int)(d_zistepu * 0x8000 * 0x10000);

	do
	{
		pdest = d_pzbuffer + (d_zwidth * pspan->v) + pspan->u;

		count = pspan->count;

	// calculate the initial 1/z
		du = (float)pspan->u;
		dv = (float)pspan->v;

		zi = d_ziorigin + dv*d_zistepv + du*d_zistepu;
	// we count on FP exceptions being turned off to avoid range problems
		izi = (int)(zi * 0x8000 * 0x10000);

		if ((long)pdest & 0x02)
		{
			*pdest++ = (short)(izi >> 16);
			izi += izistep;
			count--;
		}

		if ((doublecount = count >> 1) > 0)
		{
			do
			{
				ltemp = izi >> 16;
				izi += izistep;
				ltemp |= izi & 0xFFFF0000;
				izi += izistep;
				*(int *)pdest = ltemp;
				pdest += 2;
			} while (--doublecount > 0);
		}

		if (count & 1)
			*pdest = (short)(izi >> 16);

	} while ((pspan = pspan->pnext) != NULL);
}
#endif //USE_MMX

#endif

