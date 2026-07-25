/* M10-1: C side of the fixed-array marshaling test.
 *
 * Each entry point returns 0 on success or a bitmask naming what was
 * wrong, so a bad value fails the test rather than needing a human to
 * read a log. The expected bounds are the DECLARED ranges (H.10.2) and
 * element access uses the DECLARED index (H.10.3). */

# include  <stdio.h>
# include  "svdpi.h"

# define E_SIZE   0x001
# define E_LOW    0x002
# define E_HIGH   0x004
# define E_LEFT   0x008
# define E_RIGHT  0x010
# define E_INCR   0x020
# define E_BYTES  0x040
# define E_ELEM   0x080
# define E_WALK   0x100
# define E_OOR    0x200

static int chk(int got, int want, int bit, const char*what)
{
      if (got == want) return 0;
      printf("  c: %s = %d, expected %d\n", what, got, want);
      fflush(stdout);
      return bit;
}

/* Common geometry + element checks. The SV side filled every element with
 * (declared index * 100), so a wrong index translation shows up as a wrong
 * value rather than merely a wrong pointer. */
static int check_range(const svOpenArrayHandle h,
                       int left, int right, int low, int high, int incr)
{
      int bad = 0;
      int i;
      int seen = 0;

      bad |= chk(svSize(h, 1),      high - low + 1, E_SIZE,  "svSize(1)");
      bad |= chk(svLow(h, 1),       low,   E_LOW,   "svLow(1)");
      bad |= chk(svHigh(h, 1),      high,  E_HIGH,  "svHigh(1)");
      bad |= chk(svLeft(h, 1),      left,  E_LEFT,  "svLeft(1)");
      bad |= chk(svRight(h, 1),     right, E_RIGHT, "svRight(1)");
      bad |= chk(svIncrement(h, 1), incr,  E_INCR,  "svIncrement(1)");
      bad |= chk(svSizeOfArray(h),
                 (int)((high - low + 1) * sizeof(int)), E_BYTES, "svSizeOfArray");

        /* Element access by DECLARED index. */
      for (i = low; i <= high; i++) {
            int*p = (int*)svGetArrElemPtr1(h, i);
            if (!p) {
                  printf("  c: svGetArrElemPtr1(%d) returned NULL\n", i);
                  fflush(stdout);
                  bad |= E_ELEM;
                  continue;
            }
            bad |= chk(*p, i * 100, E_ELEM, "element value");
            seen += 1;
      }
      bad |= chk(seen, high - low + 1, E_ELEM, "elements read");

        /* Walk the way a C model would, from svLeft by svIncrement. This
         * is the loop that breaks if bounds and element access disagree. */
      seen = 0;
      for (i = svLeft(h, 1);
           (incr > 0) ? (i <= svRight(h, 1)) : (i >= svRight(h, 1));
           i += incr) {
            int*p = (int*)svGetArrElemPtr1(h, i);
            if (!p || *p != i * 100) { bad |= E_WALK; break; }
            seen += 1;
      }
      bad |= chk(seen, high - low + 1, E_WALK, "elements walked");

        /* Outside the declared range must be rejected, not wrapped. */
      if (svGetArrElemPtr1(h, low - 1))  bad |= E_OOR;
      if (svGetArrElemPtr1(h, high + 1)) bad |= E_OOR;

      return bad;
}

/* int a[3:10] -- ascending, non-zero based. */
int c_fixed_asc(const svOpenArrayHandle h)
{
      return check_range(h, /*left*/3, /*right*/10, /*low*/3, /*high*/10,
                         /*incr*/1);
}

/* int a[10:3] -- descending: left/right swap and the increment is -1. */
int c_fixed_desc(const svOpenArrayHandle h)
{
      return check_range(h, /*left*/10, /*right*/3, /*low*/3, /*high*/10,
                         /*incr*/-1);
}

/* An ordinary dynamic array has no declared range: 0-based, and the
 * declared-index translation must be the identity for it. */
int c_dyn_plain(const svOpenArrayHandle h)
{
      int bad = 0;
      int i;

      bad |= chk(svSize(h, 1),      5, E_SIZE,  "svSize(1)");
      bad |= chk(svLow(h, 1),       0, E_LOW,   "svLow(1)");
      bad |= chk(svHigh(h, 1),      4, E_HIGH,  "svHigh(1)");
      bad |= chk(svLeft(h, 1),      0, E_LEFT,  "svLeft(1)");
      bad |= chk(svRight(h, 1),     4, E_RIGHT, "svRight(1)");
      bad |= chk(svIncrement(h, 1), 1, E_INCR,  "svIncrement(1)");

      for (i = 0; i < 5; i++) {
            int*p = (int*)svGetArrElemPtr1(h, i);
            if (!p) { bad |= E_ELEM; continue; }
            bad |= chk(*p, i * 7, E_ELEM, "element value");
      }
      return bad;
}
