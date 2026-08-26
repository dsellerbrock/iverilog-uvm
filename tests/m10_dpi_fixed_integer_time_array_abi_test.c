#include "svdpi.h"

#include <stdint.h>

enum {
      E_INTEGER = 1 << 0,
      E_TIME    = 1 << 1
};

static int same_word(const svLogicVecVal*word, uint32_t aval, uint32_t bval)
{
      return (uint32_t)word->aval == aval && (uint32_t)word->bval == bval;
}

void c_mutate_fixed_integer_time_arrays(svLogicVecVal integers[3],
                                        svLogicVecVal times[4],
                                        int32_t*status)
{
      int bad = 0;

      if (!same_word(&integers[0], UINT32_C(0x00000081),
                     UINT32_C(0x00000080)) ||
          !same_word(&integers[1], UINT32_C(0x80000000),
                     UINT32_C(0x00008000)) ||
          !same_word(&integers[2], UINT32_C(0x89abcdef), 0))
            bad |= E_INTEGER;

      /* Each time element contributes two canonical words, low word first. */
      if (!same_word(&times[0], UINT32_C(0x00000002), 0) ||
          !same_word(&times[1], UINT32_C(0x00000008),
                     UINT32_C(0x80000008)) ||
          !same_word(&times[2], UINT32_C(0x89a9cdef),
                     UINT32_C(0x00020000)) ||
          !same_word(&times[3], UINT32_C(0x01334567),
                     UINT32_C(0x00100000)))
            bad |= E_TIME;

      integers[0].aval = UINT32_C(0x40000004);
      integers[0].bval = UINT32_C(0x00000004);
      integers[1].aval = UINT32_C(0x135799df);
      integers[1].bval = UINT32_C(0x00000200);
      integers[2].aval = UINT32_C(0x80000000);
      integers[2].bval = UINT32_C(0x80000001);

      times[0].aval = UINT32_C(0x00000001);
      times[0].bval = UINT32_C(0x00000001);
      times[1].aval = UINT32_C(0x40000000);
      times[1].bval = UINT32_C(0x00000001);
      times[2].aval = UINT32_C(0x76543210);
      times[2].bval = UINT32_C(0x00000020);
      times[3].aval = UINT32_C(0xfedcba98);
      times[3].bval = UINT32_C(0x10000000);

      *status = bad;
}
