extern int sv_fauto(int); extern int sv_tauto(int);
int c_call1(int v){ return sv_fauto(v); }
int c_slow1(int d){ return sv_tauto(d); }
