#include <string.h>
#include "svdpi.h"

typedef struct {
    signed char tag;
    int data;
    svLogic flag;
} item_t;

typedef struct {
    signed char tag;
    const char* text;
    double data;
} text_item_t;

static int range_is(svOpenArrayHandle h, int dim, int left, int right)
{
    int low = left < right ? left : right;
    int high = left > right ? left : right;
    return svLeft(h, dim) == left && svRight(h, dim) == right &&
           svLow(h, dim) == low && svHigh(h, dim) == high &&
           svSize(h, dim) == high - low + 1 &&
           svIncrement(h, dim) == (left >= right ? 1 : -1);
}

static int matrix_bounds(svOpenArrayHandle h)
{
    return svDimensions(h) == 2 && range_is(h, 1, 2, 1) &&
           range_is(h, 2, -2, 0) && !svGetArrayPtr(h) && !svSizeOfArray(h) &&
           !svGetArrElemPtr1(h, 1) && !svGetArrElemPtr2(h, 0, -2) &&
           !svGetArrElemPtr2(h, 2, -3) && !svGetArrElemPtr(h, 1, 1) &&
           !svGetArrElemPtr3(h, 2, -2, 0);
}

static item_t value_at(int i, int j)
{
    return (item_t){-10 * i + j, 1000 * i + j,
                    j == -1 ? sv_1 : (i == 2 ? sv_x : sv_z)};
}

int issue3917_fill(svOpenArrayHandle h)
{
    if (!matrix_bounds(h)) return 0;
    for (int i = 1; i <= 2; ++i) {
        item_t* row = svGetArrElemPtr2(h, i, -2);
        if (!row) return 0;
        for (int j = -2; j <= 0; ++j) {
            item_t* item = svGetArrElemPtr(h, i, j);
            if (item != row + (j + 2)) return 0;
            *item = value_at(i, j);
        }
    }
    return 1;
}

int issue3917_update(svOpenArrayHandle h)
{
    if (!matrix_bounds(h)) return 0;
    for (int i = 1; i <= 2; ++i) {
        for (int j = -2; j <= 0; ++j) {
            const item_t* item = svGetArrElemPtr2(h, i, j);
            item_t expected = value_at(i, j);
            if (!item || item->tag != expected.tag || item->data != expected.data ||
                item->flag != expected.flag)
                return 0;
        }
    }
    item_t* first = svGetArrElemPtr2(h, 2, -2);
    item_t* last = svGetArrElemPtr(h, 1, 0);
    first->data = -12345;
    first->flag = sv_z;
    last->tag = 49;
    last->flag = sv_x;
    return 1;
}

int issue3917_swap_text(svOpenArrayHandle h)
{
    if (svDimensions(h) != 3 || !range_is(h, 1, 2, 1) ||
        !range_is(h, 2, -1, -1) || !range_is(h, 3, 0, 1))
        return 0;
    text_item_t* first = svGetArrElemPtr3(h, 2, -1, 0);
    text_item_t* last = svGetArrElemPtr(h, 1, -1, 1);
    const text_item_t* empty = svGetArrElemPtr3(h, 2, -1, 1);
    if (!first || first->tag != 7 || first->data != 1.25 ||
        !first->text || strcmp(first->text, "a longer string from the first row") ||
        !last || last->tag != 8 || last->data != 2.5 ||
        !last->text || strcmp(last->text, "last") ||
        !empty || !empty->text || strcmp(empty->text, ""))
        return 0;
    const char* saved = first->text;
    first->text = last->text;
    last->text = saved;
    return 1;
}

int issue3917_rank4(svOpenArrayHandle h)
{
    if (svDimensions(h) != 4 || !range_is(h, 1, 3, 4) ||
        !range_is(h, 2, 1, 1) || !range_is(h, 3, 0, -1) ||
        !range_is(h, 4, 10, 11) || svGetArrElemPtr3(h, 4, 1, -1))
        return 0;
    const item_t* item = svGetArrElemPtr(h, 4, 1, -1, 11);
    return item && item->tag == -4 && item->data == 42 && item->flag == sv_z &&
           !svGetArrElemPtr(h, 4, 1, -1, 12);
}

int issue3917_dynamic(svOpenArrayHandle h, int rows)
{
    if (svDimensions(h) != 2 || svSize(h, 1) != rows ||
        svGetArrayPtr(h) || svSizeOfArray(h))
        return 0;
    if (!rows) return !svGetArrElemPtr2(h, 0, 0);
    if (svSize(h, 2) != 2) return 0;
    item_t* first = svGetArrElemPtr2(h, 0, 0);
    item_t* second = svGetArrElemPtr(h, 0, 1);
    if (!first || !second) return 0;
    *first = (item_t){-1, 27, sv_z};
    *second = (item_t){2, -81, sv_x};
    return 1;
}
