/* C side of m10_dpi_open_array_layout_range_test.
 *
 * Checks that an open-array formal reports the declared range of the fixed
 * actual it was marshaled from (IEEE 1800-2017 H.10.2) and that element
 * access uses the declared index (H.10.3). Returns 0 or a bitmask.
 */
#include <svdpi.h>

#define E_SIZE  0x001
#define E_LEFT  0x002
#define E_RIGHT 0x004
#define E_LOW   0x008
#define E_HIGH  0x010
#define E_INCR  0x020
#define E_ELEM  0x040
#define E_OOR   0x080

static int chk(int got, int want, int bit)
{
      return (got == want) ? 0 : bit;
}

static int check_range(const svOpenArrayHandle h,
                       int left, int right, int incr)
{
      int low  = (left <= right) ? left : right;
      int high = (left <= right) ? right : left;
      int bad  = 0;
      int i;

      bad |= chk(svSize(h, 1), high - low + 1, E_SIZE);
      bad |= chk(svLeft(h, 1), left, E_LEFT);
      bad |= chk(svRight(h, 1), right, E_RIGHT);
      bad |= chk(svLow(h, 1), low, E_LOW);
      bad |= chk(svHigh(h, 1), high, E_HIGH);
      bad |= chk(svIncrement(h, 1), incr, E_INCR);

      /* Element access uses the DECLARED index, and the value stored at
         declared index i is i*100. */
      for (i = low; i <= high; i += 1) {
            int*p = (int*)svGetArrElemPtr1(h, i);
            if (!p || *p != i * 100) {
                  bad |= E_ELEM;
                  break;
            }
      }

      /* Just outside the declared range must not resolve. */
      if (svGetArrElemPtr1(h, low - 1))  bad |= E_OOR;
      if (svGetArrElemPtr1(h, high + 1)) bad |= E_OOR;

      return bad;
}

/* int a[3:10] -- ascending: left is the low bound, increment -1. */
int c_layout_range_asc(const svOpenArrayHandle h)
{
      return check_range(h, /*left*/3, /*right*/10, /*incr*/-1);
}

/* int a[10:3] -- descending: left is the high bound, increment +1. */
int c_layout_range_desc(const svOpenArrayHandle h)
{
      return check_range(h, /*left*/10, /*right*/3, /*incr*/1);
}
