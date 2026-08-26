#include "svdpi.h"

#include <stdint.h>
#include <stdio.h>

void c_mutate_fixed_packed_arrays(uint32_t bytes[3], uint32_t wide[4],
                                  svLogicVecVal states[4], int32_t*status)
{
      int bad = 0;

      /* bit[7:0] still has one full svBitVecVal word per element. */
      if (bytes[0] != 0x12u || bytes[1] != 0xa5u || bytes[2] != 0x5au)
            bad |= 1;

      /* bit[39:0] has two words per element, low word first. */
      if (wide[0] != 0x3456789au || (wide[1] & 0xffu) != 0x12u ||
          wide[2] != 0xcdef0123u || (wide[3] & 0xffu) != 0xabu) {
            printf("fixed bit[39:0] words=%08x/%08x/%08x/%08x\n",
                   wide[0], wide[1], wide[2], wide[3]);
            bad |= 2;
      }

      /* logic[39:0] has two {aval,bval} entries per element. */
      if ((uint32_t)states[0].aval != 0x3456789au ||
          (uint32_t)states[0].bval != 0x00000008u ||
          ((uint32_t)states[1].aval & 0xffu) != 0x00000012u ||
          ((uint32_t)states[1].bval & 0xffu) != 0x00000020u ||
          (uint32_t)states[2].aval != 0xcdef0122u ||
          (uint32_t)states[2].bval != 0x00000001u ||
          ((uint32_t)states[3].aval & 0xffu) != 0x000000abu ||
          ((uint32_t)states[3].bval & 0xffu) != 0x00000080u) {
            printf("fixed logic[39:0] words="
                   "%08x/%08x %08x/%08x %08x/%08x %08x/%08x\n",
                   (uint32_t)states[0].aval, (uint32_t)states[0].bval,
                   (uint32_t)states[1].aval, (uint32_t)states[1].bval,
                   (uint32_t)states[2].aval, (uint32_t)states[2].bval,
                   (uint32_t)states[3].aval, (uint32_t)states[3].bval);
            bad |= 4;
      }

      bytes[0] = 0xe1u;
      bytes[1] = 0x3cu;
      bytes[2] = 0xe2u;

      wide[0] = 0x89abcdefu;
      wide[1] = 0x55u;
      wide[2] = 0x01234567u;
      wide[3] = 0xaau;

      states[0].aval = 0x89abcdefu;
      states[0].bval = 0x00000002u;
      states[1].aval = 0x00000051u;
      states[1].bval = 0x00000004u;
      states[2].aval = 0x01234547u;
      states[2].bval = 0x00000020u;
      states[3].aval = 0x000000eau;
      states[3].bval = 0x00000040u;

      *status = bad;
}
