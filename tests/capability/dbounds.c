#include <stdio.h>
#include "svdpi.h"
static void dump(const char*tag, const svOpenArrayHandle h, int dims)
{
      int d;
      printf("%s: dims=%d sizeOfArray=%d\n", tag, svDimensions(h), svSizeOfArray(h));
      for (d = 1; d <= dims; d++)
            printf("  %s dim%d: size=%d low=%d high=%d left=%d right=%d incr=%d\n",
                   tag, d, svSize(h,d), svLow(h,d), svHigh(h,d),
                   svLeft(h,d), svRight(h,d), svIncrement(h,d));
      fflush(stdout);
}
void probe1(const svOpenArrayHandle h){ dump("1d", h, 1); }
void probe2(const svOpenArrayHandle h){ dump("2d", h, 2); }
