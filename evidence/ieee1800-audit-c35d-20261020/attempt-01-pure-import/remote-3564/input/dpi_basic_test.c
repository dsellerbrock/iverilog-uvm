/* C implementation of DPI functions for dpi_basic_test.sv */
#include <stdio.h>

int c_add(int a, int b)
{
    return a + b;
}

int c_mul(int a, int b)
{
    return a * b;
}

int c_factorial(int n)
{
    if (n <= 1) return 1;
    return n * c_factorial(n - 1);
}
