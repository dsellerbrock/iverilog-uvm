#include <stdio.h>
#include "svdpi.h"

extern int sv_cb(int);

int c_add(int a, int b) { return a + b; }
double c_scale(double x) { return x * 2.0; }
const char *c_greet(const char *s) {
  static char b[64];
  snprintf(b, sizeof b, "hi %s", s);
  return b;
}
void c_out(int *o) { *o = 7; }
int c_call_sv(void) { return sv_cb(5); }
