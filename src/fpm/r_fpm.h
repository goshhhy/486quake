//===========================================================================
// viewmodel lighting

#include "FixedPointMath.h"

typedef struct {
	int				ambientlight;
	int				shadelight;
	fixedpoint_t	*plightvec;
} alight_FPM_t;

void R_AliasDrawModelFPM (alight_FPM_t *plighting);