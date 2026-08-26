#include "svdpi.h"

#include <stdint.h>

/* Match OpenTitan's cryptoc_dpi.c prototype exactly: open-array handle,
 * uint64_t length, and a direct fixed-array pointer. */
void c_dpi_SHA384_hash(const svOpenArrayHandle msg, uint64_t len,
                       uint32_t hash[12])
{
      static const uint8_t expected[6] = {
            0x4f, 0x70, 0x65, 0x6e, 0x54, 0x69
      };
      unsigned bad = 0;
      int idx;

      if (len != UINT64_C(0x0000000100000006))
            bad |= 1u;
      if (svDimensions(msg) != 1 || svSize(msg, 1) != 6 ||
          svLow(msg, 1) != 0 || svHigh(msg, 1) != 5)
            bad |= 2u;

      for (idx = 0; idx < 6; idx += 1) {
            const svBitVecVal*word =
                  (const svBitVecVal*)svGetArrElemPtr1(msg, idx);
            if (!word || ((*word & 0xffu) != expected[idx]))
                  bad |= 4u;
      }

      for (idx = 0; idx < 12; idx += 1) {
            if (bad)
                  hash[idx] = 0xbad00000u | bad;
            else
                  hash[idx] = 0x3840005au +
                              (uint32_t)idx * UINT32_C(0x00010203);
      }
}
