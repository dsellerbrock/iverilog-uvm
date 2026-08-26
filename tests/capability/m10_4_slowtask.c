#include <stdio.h>
extern int sv_wait(int);
int c_slow(int d){ return sv_wait(d); }
