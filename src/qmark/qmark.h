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

extern float Qm_FpIuEmuFmulCyrix( float a, float b );
extern float Qm_FpIuEmuFmul( float a, float b );
extern float Qm_FpIuRealFmul( float a, float b );

extern void Qm_FmulStConcurrencyTest0( void );
extern void Qm_FmulStConcurrencyTest1( void );
extern void Qm_FmulStConcurrencyTest2( void );
extern void Qm_FmulStConcurrencyTest3( void );
extern void Qm_FmulStConcurrencyTest4( void );
extern void Qm_FmulStConcurrencyTest5( void );
extern void Qm_FmulStConcurrencyTest6( void );
extern void Qm_FmulStConcurrencyTest7( void );
extern void Qm_FmulStConcurrencyTest8( void );
extern void Qm_FmulStConcurrencyTest9( void );
extern void Qm_FmulStConcurrencyTest10( void );