/* An open array of unpacked structs (IEEE 1800-2017/2023 H.7.8). */
#include "svdpi.h"

typedef struct { int a; int b; } s_t;

int c_struct_size(const svOpenArrayHandle h)
{
      const s_t*last = (const s_t*)svGetArrElemPtr1(h, svHigh(h, 1));
      return svSize(h, 1) * 1000 + (last ? last->b : -1);
}
