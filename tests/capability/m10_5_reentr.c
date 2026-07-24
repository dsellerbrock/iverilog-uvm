#include <stdio.h>
extern int sv_mid(int);
extern int sv_leaf(int);
int c_inner(int v){ return sv_leaf(v); }
int c_outer(int v){ return sv_mid(v) + 100; }
