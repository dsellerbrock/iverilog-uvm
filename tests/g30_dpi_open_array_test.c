/*
 * g30_dpi_open_array_test.c
 * C-side DPI implementation that exercises the svdpi.h open-array API.
 * The five int arguments represent a SV unpacked int[0:4] array.
 */
#include "svdpi.h"
#include <stdio.h>

/* Declared in vvp/svdpi_impl.cc and resolved at runtime from vvp binary */
extern svOpenArrayHandle svdpi_new_array(void* data, size_t elem_bytes,
                                          unsigned ndims, ...);
extern void svdpi_free_array(svOpenArrayHandle h);

/*
 * Receives the five elements of a SV int[0:4], assembles a C array,
 * wraps it in an svOpenArrayHandle, and exercises the full accessor API.
 * Returns 1 on pass, 0 on any failure.
 */
int c_test_open_array(int a0, int a1, int a2, int a3, int a4)
{
    int data[5] = { a0, a1, a2, a3, a4 };
    /* Create handle over a 1-D array with range [0:4] */
    svOpenArrayHandle h = svdpi_new_array(data, sizeof(int), 1, 0, 4);
    if (!h) return 0;

    int ok = 1;

    /* Dimension metadata */
    if (svDimensions(h) != 1) { ok = 0; goto done; }
    if (svSize(h, 1) != 5)    { ok = 0; goto done; }
    if (svLow(h, 1)  != 0)    { ok = 0; goto done; }
    if (svHigh(h, 1) != 4)    { ok = 0; goto done; }
    if (svLeft(h, 1) != 0)    { ok = 0; goto done; }
    if (svRight(h, 1)!= 4)    { ok = 0; goto done; }
    if (svIncrement(h, 1)!= 1){ ok = 0; goto done; }
    if (svSizeOfArray(h) != 5 * (int)sizeof(int)) { ok = 0; goto done; }
    if (svGetArrayPtr(h) != data) { ok = 0; goto done; }

    /* Element iteration via svGetArrElemPtr1 */
    {
        int expected = 10; /* a0 */
        int sum = 0;
        for (int i = svLow(h, 1); i <= svHigh(h, 1); i++) {
            int* ep = (int*)svGetArrElemPtr1(h, i);
            if (!ep) { ok = 0; goto done; }
            sum += *ep;
        }
        if (sum != 150) { ok = 0; goto done; } /* 10+20+30+40+50 */
        (void)expected;
    }

    /* Verify first and last element pointers */
    {
        int* ep0 = (int*)svGetArrElemPtr1(h, 0);
        int* ep4 = (int*)svGetArrElemPtr1(h, 4);
        if (!ep0 || *ep0 != a0) { ok = 0; goto done; }
        if (!ep4 || *ep4 != a4) { ok = 0; goto done; }
    }

done:
    svdpi_free_array(h);
    return ok;
}

/*
 * Tests 2-D array iteration: [0:2][0:1] (3 rows × 2 cols), row-major.
 * Elements are supplied as individual ints (rNcM).
 * Returns 1 on pass, 0 on failure.
 */
int c_test_open_array_2d(int r0c0, int r0c1,
                          int r1c0, int r1c1,
                          int r2c0, int r2c1)
{
    int data[3][2] = { {r0c0, r0c1}, {r1c0, r1c1}, {r2c0, r2c1} };
    /* 2-D handle: dim1=[0:2], dim2=[0:1] */
    svOpenArrayHandle h = svdpi_new_array(data, sizeof(int), 2,
                                          0, 2, /* dim 1 */
                                          0, 1  /* dim 2 */);
    if (!h) return 0;

    int ok = 1;

    if (svDimensions(h) != 2) { ok = 0; goto done; }
    if (svSize(h, 1) != 3)    { ok = 0; goto done; }
    if (svSize(h, 2) != 2)    { ok = 0; goto done; }
    if (svLow(h, 1)  != 0)    { ok = 0; goto done; }
    if (svHigh(h, 1) != 2)    { ok = 0; goto done; }
    if (svLow(h, 2)  != 0)    { ok = 0; goto done; }
    if (svHigh(h, 2) != 1)    { ok = 0; goto done; }

    /* Sum all elements via svGetArrElemPtr2 */
    {
        int sum = 0;
        for (int r = svLow(h,1); r <= svHigh(h,1); r++) {
            for (int c = svLow(h,2); c <= svHigh(h,2); c++) {
                int* ep = (int*)svGetArrElemPtr2(h, r, c);
                if (!ep) { ok = 0; goto done; }
                sum += *ep;
            }
        }
        if (sum != 21) { ok = 0; goto done; } /* 1+2+3+4+5+6 */
    }

    /* Spot-check svGetArrElemPtr (generic N-D) */
    {
        int idx[2] = { 1, 0 };
        int* ep = (int*)svGetArrElemPtr(h, idx);
        if (!ep || *ep != r1c0) { ok = 0; goto done; }
    }

done:
    svdpi_free_array(h);
    return ok;
}
