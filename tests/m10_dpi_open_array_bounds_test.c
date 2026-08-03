/* M10-1/R7: C side of the open-array bounds test.
 *
 * Each entry point returns 0 on success or a bitmask naming the wrong
 * query, so a bad value fails the test instead of merely printing.
 * The expected values are all chosen to differ from the old hardcoded
 * answers (svIncrement used one hardcoded direction, svSizeOfArray 0 for
 * multidim). */

# include  <stdio.h>
# include  "svdpi.h"

# define E_DIMS   0x001
# define E_SIZE   0x002
# define E_LOW    0x004
# define E_HIGH   0x008
# define E_LEFT   0x010
# define E_RIGHT  0x020
# define E_INCR   0x040
# define E_BYTES  0x080
# define E_SIZE2  0x100
# define E_ORDER  0x200
# define E_COUNT  0x400

static int chk(int got, int want, int bit, const char*what)
{
      if (got == want) return 0;
      printf("  c: %s = %d, expected %d\n", what, got, want);
      fflush(stdout);
      return bit;
}

int c_bounds_1d(const svOpenArrayHandle h)
{
      int bad = 0;
      bad |= chk(svDimensions(h),   1,  E_DIMS,  "svDimensions");
      bad |= chk(svSize(h, 1),      8,  E_SIZE,  "svSize(1)");
      bad |= chk(svLow(h, 1),       0,  E_LOW,   "svLow(1)");
      bad |= chk(svHigh(h, 1),      7,  E_HIGH,  "svHigh(1)");
      bad |= chk(svLeft(h, 1),      0,  E_LEFT,  "svLeft(1)");
      bad |= chk(svRight(h, 1),     7,  E_RIGHT, "svRight(1)");
	/* $increment/svIncrement is right-to-left: ascending is -1. */
      bad |= chk(svIncrement(h, 1), -1, E_INCR,  "svIncrement(1)");
      bad |= chk(svSizeOfArray(h),  32, E_BYTES, "svSizeOfArray");
      return bad;
}

/* Walk from low to high by subtracting the right-to-left increment. */
int c_walk_by_increment(const svOpenArrayHandle h)
{
      int lo   = svLow(h, 1);
      int hi   = svHigh(h, 1);
      int incr = svIncrement(h, 1);
      int seen = 0;
      int bad  = 0;
      int i;

      if (incr == 0) return E_INCR;

      for (i = lo ; (incr < 0) ? (i <= hi) : (i >= hi) ; i -= incr) {
            int*p = (int*)svGetArrElemPtr1(h, i);
            if (!p) { bad |= E_ORDER; break; }
              /* The SV side filled element i with i*3. */
            if (*p != i * 3) {
                  printf("  c: element %d = %d, expected %d\n", i, *p, i * 3);
                  fflush(stdout);
                  bad |= E_ORDER;
            }
            seen += 1;
      }

      bad |= chk(seen, 8, E_COUNT, "elements visited");
      return bad;
}

int c_bounds_2d(const svOpenArrayHandle h)
{
      int bad = 0;
      bad |= chk(svDimensions(h), 2, E_DIMS,  "svDimensions");
      bad |= chk(svSize(h, 1),    2, E_SIZE,  "svSize(1)");
      bad |= chk(svSize(h, 2),    3, E_SIZE2, "svSize(2)");
      bad |= chk(svIncrement(h, 1), -1, E_INCR, "svIncrement(1)");
      bad |= chk(svIncrement(h, 2), -1, E_INCR, "svIncrement(2)");
	/* 2 * 3 * sizeof(int). This used to be 0. */
      bad |= chk(svSizeOfArray(h), 24, E_BYTES, "svSizeOfArray");
      return bad;
}

int c_bounds_real(const svOpenArrayHandle h)
{
      int bad = 0;
      bad |= chk(svDimensions(h), 1, E_DIMS,  "svDimensions");
      bad |= chk(svSize(h, 1),    4, E_SIZE,  "svSize(1)");
      bad |= chk(svIncrement(h, 1), -1, E_INCR, "svIncrement(1)");
      bad |= chk(svSizeOfArray(h), (int)(4 * sizeof(double)), E_BYTES,
                 "svSizeOfArray");
      return bad;
}
