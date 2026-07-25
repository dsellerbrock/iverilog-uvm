#include <stdio.h>
#include "svdpi.h"
void probe(const svOpenArrayHandle h, int lo, int hi)
{
      int i;
      printf("C: left=%d right=%d low=%d high=%d incr=%d\n",
             svLeft(h,1), svRight(h,1), svLow(h,1), svHigh(h,1), svIncrement(h,1));
      printf("C: by DECLARED index %d..%d: ", lo, hi);
      for (i = lo; i <= hi; i++) {
            int*p = (int*)svGetArrElemPtr1(h, i);
            printf("[%d]=%s%d ", i, p?"":"NULL", p?*p:0);
      }
      printf("\n"); fflush(stdout);
}
