#include <string.h>
#include <svdpi.h>
#include <vpi_user.h>

/* IEEE 1800-2017/2023 H.7.4: a string element is a const char*. */
int c_str_total(const svOpenArrayHandle a)
{
    int total = 0;
    int low = svLow(a, 1);
    for (int idx = 0; idx < svSize(a, 1); idx += 1)
        total += (int)strlen(*(const char **)svGetArrElemPtr1(a, low + idx));
    return total;
}

int c_str_size(const svOpenArrayHandle a)
{
    return svSize(a, 1) * 100 + svDimensions(a);
}

void c_str_fill(const svOpenArrayHandle a)
{
    static const char *words[] = { "alpha", "beta", "gamma", "delta" };
    int low = svLow(a, 1);
    for (int idx = 0; idx < svSize(a, 1); idx += 1)
        *(const char **)svGetArrElemPtr1(a, low + idx) = words[idx % 4];
}

void c_str_swap_ends(const svOpenArrayHandle a)
{
    int low = svLow(a, 1), high = svHigh(a, 1);
    const char **first = (const char **)svGetArrElemPtr1(a, low);
    const char **last = (const char **)svGetArrElemPtr1(a, high);
    const char *tmp = *first;
    *first = *last;
    *last = tmp;
}

int c_str_fixed_total(const char **a)
{
    return (int)(strlen(a[0]) + strlen(a[1]) * 10 + strlen(a[2]) * 100);
}

void (*vlog_startup_routines[])(void) = { 0 };
