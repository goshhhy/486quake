extern void Qm_PointTransformNi (vec3_t in, vec3_t out);
extern void Qm_PointTransformFx (vec3_t in, vec3_t out);

extern void Qm_DotProductNi (vec3_t in, vec3_t out);

extern int Qm_FpIntStd( float in );
extern int Qm_FpIntTerje( float in );

extern float Qm_FpIuSequential( float a, float b );
extern float Qm_FpIuInterleaved( float a, float b );

extern int Qm_FpIuEmulatorCheck( int i );

extern float Qm_FpRegSpeedTest( float f );
extern float Qm_FpMemSpeedTest( float f );