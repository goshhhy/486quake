//Fixed Point Math Routines
//Copyright 2/2/01 Dan East
#include "FixedPointMath.h"
#include <math.h>

#if defined(DEBUG)&&defined(_X86_)
#include "windows.h"
#define FPM_VALIDATE
#endif

 fixedpoint_t fpm_FromFloat(double f) {

#	if  defined(DEBUG)&&defined(FPM_VALIDATE)
	 fixedpoint_t fxp=(fixedpoint_t) (f*65536.0);
	 if (f) ASSERT(fxp);
#	endif

	return (fixedpoint_t) (f*65536.0);
}


float fpm_ToFloat(fixedpoint_t fxp) {
	return (float)(fxp/65536.0);
}

fixedpoint_t fpm_FromLong(long l) {
#	if  defined(DEBUG)&&defined(FPM_VALIDATE)
	 if (l>0) ASSERT((l<<16)>0);
	 else if (l<0) ASSERT((l<<16)<0);
#	endif

	return l<<16;
}

 long fpm_ToLong(fixedpoint_t fxp) {
	if (fxp<0)
		return -((long)((fxp^0xffffffff)>>16)+1);
	else 
		return (fxp>>16)&0x0000ffff;
}

 fixedpoint_t fpm_Add(fixedpoint_t fxp1, fixedpoint_t fxp2) {
#	if  defined(DEBUG)&&defined(FPM_VALIDATE)
	 if (fxp1>0&&fxp2>0) ASSERT((fxp1+fxp2)>0);
	 if (fxp1<0&&fxp2<0) ASSERT((fxp1+fxp2)<0);
#	endif

	return fxp1+fxp2;
}

 fixedpoint_t fpm_Add3(fixedpoint_t fxp1, fixedpoint_t fxp2, fixedpoint_t fxp3) {
	return fxp1+fxp2+fxp3;
}
/*
 fixedpoint_t fpm_Inc(fixedpoint_t fxp) {
	return fxp=fxp+FPM_FROMLONG(1);
}
*/
 fixedpoint_t fpm_Sub(fixedpoint_t fxp1, fixedpoint_t fxp2) {
	return fxp1-fxp2;
}
/*
 fixedpoint_t fpm_Dec(fixedpoint_t &fxp) {
	return fxp=fxp-FPM_FROMLONG(1);
}
*/
fixedpoint_t fpm_Mul(fixedpoint_t fxp1, fixedpoint_t fxp2) {
	 long long tmp=fxp1;

#	if  defined(DEBUG)&&defined(FPM_VALIDATE)
	fixedpoint_t fxp;
	tmp*=fxp2;
	fxp=(fixedpoint_t)(tmp>>16);
	if (fxp1&&fxp2) {
/*
		//Dan: Temp hack
		if (!fxp) {
			if ((fxp1>0&&fxp2>0)||(fxp1<0&&fxp2<0)) fxp=1;
			else fxp=-1;
			return fxp;
		}
*/
		ASSERT(fxp);
		if ((fxp1>0&&fxp2>0)||(fxp1<0&&fxp2<0)) ASSERT(fxp>0);
		else ASSERT(fxp<0);
	}
	return fxp;
#	endif

	tmp*=fxp2;

	return (fixedpoint_t)(tmp>>16);
}

 fixedpoint_t fpm_Div(fixedpoint_t fxp1, fixedpoint_t fxp2) {
	long long tmp=fxp1;
#	if  defined(DEBUG)&&defined(FPM_VALIDATE)
	fixedpoint_t fxp;

	ASSERT(fxp2);
	tmp<<=16;
	fxp=(fixedpoint_t)(tmp/fxp2);

	if (fxp1) {
/*
		//Dan: Temp hack
		if (!fxp) {
			if ((fxp1>0&&fxp2>0)||(fxp1<0&&fxp2<0)) fxp=1;
			else fxp=-1;
			return fxp;
		}
*/
		ASSERT(fxp);
		if ((fxp1>0&&fxp2>0)||(fxp1<0&&fxp2<0)) ASSERT(fxp>0);
		else ASSERT(fxp<0);
	}

	return fxp;
#endif
	tmp<<=16;
	return (fixedpoint_t)(tmp/fxp2);
}

 fixedpoint_t fpm_DivInt(fixedpoint_t fxp1, long l) {
	return fxp1/l;
}

 fixedpoint_t fpm_Abs(fixedpoint_t fxp) {
	return abs(fxp);
}

//TODO: could be more efficient
 fixedpoint_t fpm_Ceil(fixedpoint_t fxp) {
	if (fxp&0x0000ffff) {
		if (fxp<=0) return -(fixedpoint_t)((-fxp)&0xffff0000);
		return (fxp&0xffff0000)+FPM_FROMLONGC(1);
	}
	return fxp;
}
//TODO: could be more efficient
 fixedpoint_t fpm_Floor(fixedpoint_t fxp) {
	if (fxp&0x0000ffff) {
		if (fxp<0) return -(long)(((-fxp)&0xffff0000)+FPM_FROMLONGC(1));
		return fxp&0xffff0000;
	}
	return fxp;
}

//TODO: Implement sqrt mathematically instead of converting to float and back
 fixedpoint_t fpm_Sqrt(fixedpoint_t fxp) {
	return fpm_FromFloat(sqrt(fpm_ToFloat(fxp)));
}

 fixedpoint_t fpm_Sqr(fixedpoint_t fxp) {
	return fpm_Mul(fxp,fxp);
}

 fixedpoint_t fpm_Inv(fixedpoint_t fxp) {
#	if  defined(DEBUG)&&defined(FPM_VALIDATE)
	ASSERT(fxp);
#	endif

	return fpm_Div(FPM_FROMLONGC(1),fxp);
}

//TODO: Calc trig functions (or lookup) instead of converting to float and back
//These take radians
 fixedpoint_t fpm_Sin(fixedpoint_t fxp) {
	return fpm_FromFloat(sin(fpm_ToFloat(fxp)));
}
 fixedpoint_t fpm_Cos(fixedpoint_t fxp) {
	return fpm_FromFloat(cos(fpm_ToFloat(fxp)));
}
 fixedpoint_t fpm_Tan(fixedpoint_t fxp) {
	return fpm_FromFloat(tan(fpm_ToFloat(fxp)));
}
 fixedpoint_t fpm_ATan(fixedpoint_t fxp) {
	return fpm_FromFloat(atan(fpm_ToFloat(fxp)));
}

//These take degrees
 fixedpoint_t fpm_SinDeg(fixedpoint_t fxp) {
	return fpm_Sin(fpm_DivInt(fpm_Mul(fxp, FPM_PI), 180));
}
 fixedpoint_t fpm_CosDeg(fixedpoint_t fxp) {
	return fpm_Cos(fpm_DivInt(fpm_Mul(fxp, FPM_PI), 180));
}
 fixedpoint_t fpm_TanDeg(fixedpoint_t fxp) {
	return fpm_Tan(fpm_DivInt(fpm_Mul(fxp, FPM_PI), 180));
}
 fixedpoint_t fpm_ATanDeg(fixedpoint_t fxp) {
	return fpm_ATan(fpm_DivInt(fpm_Mul(fxp, FPM_PI), 180));
}

/*********************************************/
/* 8.24 routines:                            */
/*********************************************/

fixedpoint8_24_t fpm_FromFloat8_24(double f) {
#	if  defined(DEBUG)&&defined(FPM_VALIDATE)
	 if (f) ASSERT((fixedpoint_t) (f*16777216.0));
#	endif

	return (fixedpoint8_24_t) (f*16777216.0);
}

float fpm_ToFloat8_24(fixedpoint8_24_t fxp) {
	return (float)(fxp/16777216.0);
}

fixedpoint8_24_t fpm_FromLong8_24(long l) {
#	if  defined(DEBUG)&&defined(FPM_VALIDATE)
	 if (l>0) ASSERT((l<<24)>0);
	 else if (l<0) ASSERT((l<<24)<0);
#	endif

	return l<<24;
}

long fpm_ToLong8_24(fixedpoint8_24_t fxp) {
	if (fxp<0)
		return -((long)((fxp^0xffffffff)>>24)+1);
	else 
		return (fxp>>24)&0x000000ff;
}

fixedpoint8_24_t fpm_FromFixedPoint(fixedpoint_t fxp) {
	return fxp<<8;
}

fixedpoint_t fpm_ToFixedPoint(fixedpoint8_24_t fxp) {
	if (fxp<0)
		return -((long)((fxp^0xffffffff)>>8)+1);
	else 
		return (fxp>>8)&0x00ffffff;
}

fixedpoint8_24_t fpm_Add8_24(fixedpoint8_24_t fxp1, fixedpoint8_24_t fxp2) {
	return fxp1+fxp2;
}

fixedpoint8_24_t fpm_Add38_24(fixedpoint8_24_t fxp1, fixedpoint8_24_t fxp2, fixedpoint8_24_t fxp3) {
	return fxp1+fxp2+fxp3;
}
/*
 fixedpoint_t fpm_Inc(fixedpoint_t fxp) {
	return fxp=fxp+FPM_FROMLONG(1);
}
*/
fixedpoint8_24_t fpm_Sub8_24(fixedpoint8_24_t fxp1, fixedpoint8_24_t fxp2) {
	return fxp1-fxp2;
}
/*
 fixedpoint_t fpm_Dec(fixedpoint_t &fxp) {
	return fxp=fxp-FPM_FROMLONG(1);
}
*/
fixedpoint8_24_t fpm_Mul8_24(fixedpoint8_24_t fxp1, fixedpoint8_24_t fxp2) {
	 long long tmp=fxp1;

#	if  defined(DEBUG)&&defined(FPM_VALIDATE)
	 fixedpoint8_24_t fxp;
	 tmp*=fxp2;
	 fxp=(fixedpoint8_24_t)(tmp>>24);
	 if (fxp1&&fxp2) {
		 ASSERT(fxp);
		 if ((fxp1>0&&fxp2>0)||(fxp1<0&&fxp2<0)) ASSERT(fxp>0);
		 else ASSERT(fxp<0);
	 }
	 return fxp;
#	endif

	tmp*=fxp2;
	return (fixedpoint_t)(tmp>>24);
}

fixedpoint_t fpm_MulMixed8_24(fixedpoint8_24_t fxp1, fixedpoint_t fxp2) {
	long long tmp=fxp1;
	tmp*=fxp2;
	
	return (fixedpoint_t)(tmp>>24);
}

 fixedpoint8_24_t fpm_Div8_24(fixedpoint8_24_t fxp1, fixedpoint8_24_t fxp2) {
	long long tmp=fxp1;
#	if  defined(DEBUG)&&defined(FPM_VALIDATE)
	//The purpose of this is to cause an exception in Windows CE
	//that will be handled right here by the debugger.  Otherwise a
	//divide by zero will be thrown which cannot be used to find
	//where the exception actually occured with the debugger.
	ASSERT(fxp2);
	if (!fxp2) 
		(*(int *)fxp2)=0;
#	endif
	tmp<<=24;
	return (fixedpoint8_24_t)(tmp/fxp2);
}

fixedpoint8_24_t fpm_DivInt8_24(fixedpoint8_24_t fxp1, long l) {
	return fxp1/l;
}

fixedpoint8_24_t fpm_DivInt64_8_24(fixedpoint8_24_t fxp1, long long l) {
	return (fixedpoint8_24_t) (fxp1/l);
}

 fixedpoint8_24_t fpm_Abs8_24(fixedpoint8_24_t fxp) {
	return abs(fxp);
}

//TODO: could be more efficient
 fixedpoint8_24_t fpm_Ceil8_24(fixedpoint8_24_t fxp) {
	if (fxp&0x00ffffff) {
		if (fxp<=0) return (fxp&0xff000000);
		return (fxp&0xff000000)+FPM_FROMLONGC8_24(1);
	}
	return fxp;
}
//TODO: could be more efficient
 fixedpoint8_24_t fpm_Floor8_24(fixedpoint8_24_t fxp) {
	if (fxp&0x00ffffff) {
		if (fxp<0) return -(long)((fxp&0xff000000)+FPM_FROMLONG8_24(1));
		return fxp&0xff000000;
	}
	return fxp;
}

//TODO: Implement sqrt mathematically instead of converting to float and back
 fixedpoint8_24_t fpm_Sqrt8_24(fixedpoint8_24_t fxp) {
	return fpm_FromFloat8_24(sqrt(fpm_ToFloat8_24(fxp)));
}

 fixedpoint8_24_t fpm_Sqr8_24(fixedpoint8_24_t fxp) {
	return fpm_Mul8_24(fxp,fxp);
}

 fixedpoint8_24_t fpm_Inv8_24(fixedpoint8_24_t fxp) {
#	if  defined(DEBUG)&&defined(FPM_VALIDATE)
	 ASSERT(fxp);
#	endif

	return fpm_Div8_24(FPM_FROMLONGC8_24(1), fxp);
}
