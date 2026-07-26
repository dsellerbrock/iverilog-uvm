#include "svdpi.h"
#include <stdio.h>

/* bit 0 size wrong, bit 1 low wrong, bit 2 high wrong, bit 3 null elem,
   bit 4 a value came back wrong */
int c_take_open(const svOpenArrayHandle h, int want_size, int base)
{
      int bad = 0, i;
      if (svSize(h, 1) != want_size) bad |= 1;
      if (svLow(h, 1)  != 0)         bad |= 2;
      if (svHigh(h, 1) != want_size-1) bad |= 4;
      for (i = 0; i < want_size; i += 1) {
            int*p = (int*)svGetArrElemPtr1(h, i);
            if (!p) { bad |= 8; continue; }
            if (*p != base + i) {
                  bad |= 16;
                  printf("  elem[%d] = %d, want %d\n", i, *p, base + i);
            }
      }
      return bad;
}

int c_take_byte(const svOpenArrayHandle h, int want_size, int base)
{
      int bad = 0, i;
      if (svSize(h, 1) != want_size) bad |= 1;
      for (i = 0; i < want_size; i += 1) {
            unsigned char*p = (unsigned char*)svGetArrElemPtr1(h, i);
            if (!p) { bad |= 8; continue; }
            if (*p != (unsigned char)(base + i)) {
                  bad |= 16;
                  printf("  byte[%d] = %u, want %u\n", i, *p,
                         (unsigned)(unsigned char)(base + i));
            }
      }
      return bad;
}

int c_take_short(const svOpenArrayHandle h, int want_size, int base)
{
      int bad = 0, i;
      if (svSize(h, 1) != want_size) bad |= 1;
      for (i = 0; i < want_size; i += 1) {
            short*p = (short*)svGetArrElemPtr1(h, i);
            if (!p) { bad |= 8; continue; }
            if (*p != (short)(base + i)) {
                  bad |= 16;
                  printf("  short[%d] = %d, want %d\n", i, *p, base + i);
            }
      }
      return bad;
}
