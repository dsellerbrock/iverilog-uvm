#include <stdlib.h>
#include <string.h>
#include "svdpi.h"
void mk_out(int v, void**h){ int*p=(int*)malloc(sizeof(int)); *p=v; *h=p; }
int  rd_h(void*h){ return h ? *(int*)h : -1; }
void bump_io(int*v){ *v += 1; }
void rbump(double*r){ *r += 1.0; }
static char sb[8];
void sout(const char**s){ strcpy(sb,"hi"); *s = sb; }
