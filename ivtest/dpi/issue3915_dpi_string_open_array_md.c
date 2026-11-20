#include "svdpi.h"
#include <limits.h>
#include <string.h>

static int range_is(svOpenArrayHandle a, int dim, int left, int right)
{
    int low = left < right ? left : right;
    int high = left > right ? left : right;
    return svLeft(a, dim) == left && svRight(a, dim) == right &&
           svLow(a, dim) == low && svHigh(a, dim) == high &&
           svSize(a, dim) == high - low + 1 &&
           svIncrement(a, dim) == (left >= right ? 1 : -1);
}

static int string_is(const char* const* slot, const char* value)
{
    return slot && *slot && strcmp(*slot, value) == 0;
}

int issue3915_read(const svOpenArrayHandle a)
{
    const char* expected[2][3] = {{"dddd", "", "ffffff"}, {"a", "bb", "ccc"}};
    if (svDimensions(a) != 2 || !range_is(a, 1, 2, 1) ||
        !range_is(a, 2, -4, -2) || svGetArrayPtr(a) || svSizeOfArray(a))
        return 0;
    for (int i = 1; i <= 2; ++i) {
        for (int j = -4; j <= -2; ++j) {
            const char* const* slot = svGetArrElemPtr2(a, i, j);
            if (!string_is(slot, expected[i - 1][j + 4]) ||
                slot != svGetArrElemPtr(a, i, j))
                return 0;
        }
    }
    return !svGetArrElemPtr2(a, 0, -3) && !svGetArrElemPtr2(a, 3, -3) &&
           !svGetArrElemPtr2(a, 1, -5) && !svGetArrElemPtr(a, 1, -1) &&
           !svGetArrElemPtr2(a, 2, INT_MAX);
}

int issue3915_fill(const svOpenArrayHandle a)
{
    const char* values[2][3] = {
        {"delta", "echo", "foxtrot"}, {"alpha", "bravo", "charlie"}
    };
    for (int i = 1; i <= 2; ++i) {
        for (int j = -4; j <= -2; ++j) {
            const char** slot = svGetArrElemPtr2(a, i, j);
            if (!slot)
                return 0;
            *slot = values[i - 1][j + 4];
        }
    }
    return 1;
}

int issue3915_swap(const svOpenArrayHandle a)
{
    const char** first = svGetArrElemPtr2(a, 2, -4);
    const char** last = svGetArrElemPtr(a, 1, -2);
    if (!string_is(first, "alpha") || !string_is(last, "foxtrot"))
        return 0;
    const char* saved = *first;
    *first = *last;
    *last = saved;
    return 1;
}

int issue3915_rank3(const svOpenArrayHandle a)
{
    return svDimensions(a) == 3 &&
           string_is(svGetArrElemPtr3(a, 6, 3, -2), "third");
}

int issue3915_rank4(const svOpenArrayHandle a)
{
    return svDimensions(a) == 4 && range_is(a, 1, 4, 3) &&
           range_is(a, 2, 5, 6) && range_is(a, 3, -7, -6) &&
           range_is(a, 4, 9, 8) &&
           string_is(svGetArrElemPtr(a, 3, 6, -7, 9), "nine") &&
           string_is(svGetArrElemPtr(a, 3, 6, -7, 8), "eight") &&
           !svGetArrElemPtr(a, 3, 6, -7, 7);
}

int issue3915_empty(const svOpenArrayHandle a, int rows)
{
    return svDimensions(a) == 2 && svSize(a, 1) == rows &&
           !svGetArrayPtr(a) && !svSizeOfArray(a) &&
           !svGetArrElemPtr2(a, 0, 0) && !svGetArrElemPtr(a, 0, 0);
}
