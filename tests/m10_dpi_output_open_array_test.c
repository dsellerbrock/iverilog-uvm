/*
 * M10-6: an OUTPUT (or INOUT) open-array formal must arrive in C with
 * the ACTUAL's shape (IEEE 1800-2017 35.5.6.1, H.10.2). Only the
 * element values are outputs; the array itself has to be there, or the
 * C model has nothing to size its loop from.
 *
 * Each routine returns a bitmask of what it found wrong, so a wrong
 * shape is a test failure rather than something a human has to spot in
 * a log:
 *
 *   bit 0  size wrong
 *   bit 1  low wrong
 *   bit 2  high wrong
 *   bit 3  an element pointer came back NULL
 *
 * The routines are VOID and the mask comes back through an output
 * scalar, because a void DPI function called as a STATEMENT is the shape
 * that was broken: it goes through the task-call path, which decided
 * copy-in on direction alone. A value-returning import used in an
 * expression takes the function path and always copied every argument
 * in, which is why the defect never showed there.
 */

#include "svdpi.h"

void c_out_fill(const svOpenArrayHandle h, int want_size, int*status)
{
      int bad = 0;
      int i;

      if (svSize(h, 1) != want_size)   bad |= 1;
      if (svLow(h, 1)  != 0)           bad |= 2;
      if (svHigh(h, 1) != want_size-1) bad |= 4;

      for (i = 0; i < want_size; i += 1) {
            int*p = (int*)svGetArrElemPtr1(h, i);
            if (!p) { bad |= 8; continue; }
            *p = i * 7;
      }
      *status = bad;
}

void c_inout_bump(const svOpenArrayHandle h, int want_size, int*status)
{
      int bad = 0;
      int i;

      if (svSize(h, 1) != want_size)   bad |= 1;
      if (svLow(h, 1)  != 0)           bad |= 2;
      if (svHigh(h, 1) != want_size-1) bad |= 4;

      for (i = 0; i < want_size; i += 1) {
            int*p = (int*)svGetArrElemPtr1(h, i);
            if (!p) { bad |= 8; continue; }
            *p = *p + 1000;
      }
      *status = bad;
}

void c_out_real(const svOpenArrayHandle h, int want_size, int*status)
{
      int bad = 0;
      int i;

      if (svSize(h, 1) != want_size)   bad |= 1;
      if (svLow(h, 1)  != 0)           bad |= 2;
      if (svHigh(h, 1) != want_size-1) bad |= 4;

      for (i = 0; i < want_size; i += 1) {
            double*p = (double*)svGetArrElemPtr1(h, i);
            if (!p) { bad |= 8; continue; }
            *p = i * 1.5;
      }
      *status = bad;
}
