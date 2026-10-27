#include <stdlib.h>
#include <string.h>
#include <stdio.h>
void*  mk_h(int v){ int*p = (int*)malloc(sizeof(int)); *p = v; return p; }
int    rd_h(void*h){ return h ? *(int*)h : -1; }
void   fr_h(void*h){ free(h); }
double rmul(double a, double b){ return a*b; }
static char buf[64];
const char* scat(const char*a, const char*b){ snprintf(buf,sizeof buf,"%s%s",a,b); return buf; }
