#include <svdpi.h>
#include <vpi_user.h>

int c_sum(const svOpenArrayHandle array)
{
    int sum = 0;
    int low = svLow(array, 1);
    int size = svSize(array, 1);
    for (int idx = 0; idx < size; idx += 1)
        sum += *(int *)svGetArrElemPtr1(array, low + idx);
    return sum;
}

void (*vlog_startup_routines[])(void) = { 0 };
