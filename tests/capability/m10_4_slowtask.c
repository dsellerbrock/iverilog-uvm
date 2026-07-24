#include <stdio.h>
extern int sv_wait(int);
int c_slow(int d){ sv_wait(d); return 0; }
