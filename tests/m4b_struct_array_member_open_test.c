#include "svdpi.h"
#include <stdint.h>
#include <stdio.h>

#define E_DIMS  0x001
#define E_SIZE  0x002
#define E_LEFT  0x004
#define E_RIGHT 0x008
#define E_LOW   0x010
#define E_HIGH  0x020
#define E_INCR  0x040
#define E_ELEM  0x080
#define E_SIZE2 0x100
#define E_BYTES 0x200

static int chk(int got, int want, int bit, const char*what)
{
      if (got == want) return 0;
      printf("  c: %s=%d, expected %d\n", what, got, want);
      fflush(stdout);
      return bit;
}

static int shape1(const svOpenArrayHandle h, int left, int right)
{
      int low = left < right ? left : right;
      int high = left < right ? right : left;
      int bad = 0;
      bad |= chk(svDimensions(h), 1, E_DIMS, "dimensions");
      bad |= chk(svSize(h, 1), high-low+1, E_SIZE, "size");
      bad |= chk(svLeft(h, 1), left, E_LEFT, "left");
      bad |= chk(svRight(h, 1), right, E_RIGHT, "right");
      bad |= chk(svLow(h, 1), low, E_LOW, "low");
      bad |= chk(svHigh(h, 1), high, E_HIGH, "high");
      bad |= chk(svIncrement(h, 1), left >= right ? 1 : -1,
                 E_INCR, "increment");
      return bad;
}

int c_member_int(const svOpenArrayHandle h, int left, int right, int base)
{
      int low = left < right ? left : right;
      int high = left < right ? right : left;
      int bad = shape1(h, left, right);
      int i;
      for (i = low; i <= high; i += 1) {
            int32_t*p = (int32_t*)svGetArrElemPtr1(h, i);
            if (!p || *p != base+i) bad |= E_ELEM;
      }
      return bad;
}

int c_member_md(const svOpenArrayHandle h)
{
      int bad = 0;
      int i, j;
      bad |= chk(svDimensions(h), 2, E_DIMS, "md dimensions");
      bad |= chk(svSize(h, 1), 2, E_SIZE, "md size 1");
      bad |= chk(svLeft(h, 1), 1, E_LEFT, "md left 1");
      bad |= chk(svRight(h, 1), 2, E_RIGHT, "md right 1");
      bad |= chk(svIncrement(h, 1), -1, E_INCR, "md increment 1");
      bad |= chk(svSize(h, 2), 3, E_SIZE2, "md size 2");
      bad |= chk(svLeft(h, 2), 7, E_LEFT, "md left 2");
      bad |= chk(svRight(h, 2), 5, E_RIGHT, "md right 2");
      bad |= chk(svLow(h, 2), 5, E_LOW, "md low 2");
      bad |= chk(svHigh(h, 2), 7, E_HIGH, "md high 2");
      bad |= chk(svIncrement(h, 2), 1, E_INCR, "md increment 2");
      bad |= chk(svSizeOfArray(h), 6*(int)sizeof(int32_t),
                 E_BYTES, "md bytes");
      for (i = 1; i <= 2; i += 1)
            for (j = 5; j <= 7; j += 1) {
                  int32_t*p = (int32_t*)svGetArrElemPtr2(h, i, j);
                  if (!p || *p != 100*i+j) bad |= E_ELEM;
            }
      return bad;
}

void c_member_md_bump(const svOpenArrayHandle h, int delta, int*status)
{
      int bad = c_member_md(h);
      int i, j;
      for (i = 1; i <= 2; i += 1)
            for (j = 5; j <= 7; j += 1) {
                  int32_t*p = (int32_t*)svGetArrElemPtr2(h, i, j);
                  if (!p) bad |= E_ELEM;
                  else *p += delta;
            }
      *status = bad;
}

int c_member_byte(const svOpenArrayHandle h)
{
      int bad = shape1(h, -1, 1);
      int i;
      for (i = -1; i <= 1; i += 1) {
            int8_t*p = (int8_t*)svGetArrElemPtr1(h, i);
            if (!p || *p != (int8_t)(10+i)) bad |= E_ELEM;
      }
      return bad;
}

int c_member_short(const svOpenArrayHandle h)
{
      int bad = shape1(h, 9, 7);
      int i;
      for (i = 7; i <= 9; i += 1) {
            int16_t*p = (int16_t*)svGetArrElemPtr1(h, i);
            if (!p || *p != (int16_t)(20+i)) bad |= E_ELEM;
      }
      return bad;
}

int c_member_real(const svOpenArrayHandle h)
{
      int bad = shape1(h, 2, 3);
      int i;
      for (i = 2; i <= 3; i += 1) {
            double*p = (double*)svGetArrElemPtr1(h, i);
            if (!p || *p != 0.5+i) bad |= E_ELEM;
      }
      return bad;
}

void c_member_bump(const svOpenArrayHandle h, int left, int right,
                   int delta, int*status)
{
      int low = left < right ? left : right;
      int high = left < right ? right : left;
      int bad = shape1(h, left, right);
      int i;
      for (i = low; i <= high; i += 1) {
            int32_t*p = (int32_t*)svGetArrElemPtr1(h, i);
            if (!p) bad |= E_ELEM;
            else *p += delta;
      }
      *status = bad;
}

void c_member_fill(const svOpenArrayHandle h, int left, int right,
                   int base, int*status)
{
      int low = left < right ? left : right;
      int high = left < right ? right : left;
      int bad = shape1(h, left, right);
      int i;
      for (i = low; i <= high; i += 1) {
            int32_t*p = (int32_t*)svGetArrElemPtr1(h, i);
            if (!p) bad |= E_ELEM;
            else *p = base+i;
      }
      *status = bad;
}
