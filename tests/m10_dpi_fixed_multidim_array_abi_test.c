#include "svdpi.h"

#include <stdint.h>

enum {
      E_SCALAR_BIT    = 1 << 0,
      E_SCALAR_LOGIC  = 1 << 1,
      E_ATOM          = 1 << 2,
      E_PACKED_BIT    = 1 << 3,
      E_PACKED_LOGIC  = 1 << 4
};

static svLogic decode_logic(const svLogicVecVal*word, uint32_t mask)
{
      if ((uint32_t)word->bval & mask)
            return ((uint32_t)word->aval & mask) ? sv_x : sv_z;
      return ((uint32_t)word->aval & mask) ? sv_1 : sv_0;
}

void c_mutate_fixed_multidim_arrays(svBit scalar_bits[6],
                                    svLogic scalar_logic[6],
                                    int32_t atoms[6],
                                    svBitVecVal packed_bits[12],
                                    svLogicVecVal packed_logic[12],
                                    int32_t*status)
{
      static const svLogic logic_input[6] = {
            sv_0, sv_1, sv_z, sv_x, sv_1, sv_0
      };
      static const svLogic logic_output[6] = {
            sv_x, sv_z, sv_1, sv_0, sv_x, sv_z
      };
      int bad = 0;
      int slot;

      /* Slots are normalized by declared index, not declaration direction:
       * outer low index first and rightmost dimension varying fastest. */
      for (slot = 0; slot < 6; slot += 1) {
            uint32_t low;
            uint32_t high;
            uint32_t xmask;
            uint32_t zmask;
            const svLogicVecVal*logic_word = &packed_logic[slot * 2];

            if (scalar_bits[slot] != (svBit)(slot & 1))
                  bad |= E_SCALAR_BIT;
            if (scalar_logic[slot] != logic_input[slot])
                  bad |= E_SCALAR_LOGIC;
            if (atoms[slot] != 1000 + slot * 17)
                  bad |= E_ATOM;

            if ((uint32_t)packed_bits[slot * 2] !=
                    UINT32_C(0x10000000) + (uint32_t)slot ||
                ((uint32_t)packed_bits[slot * 2 + 1] & UINT32_C(0xff)) !=
                    UINT32_C(0x80) + (uint32_t)slot)
                  bad |= E_PACKED_BIT;

            low = UINT32_C(0x20000000) + (uint32_t)slot;
            high = UINT32_C(0x20) + (uint32_t)slot;
            xmask = UINT32_C(1) << (slot % 32);
            zmask = UINT32_C(1) << (slot % 8);
            if ((uint32_t)logic_word[0].aval != (low | xmask) ||
                (uint32_t)logic_word[0].bval != xmask ||
                ((uint32_t)logic_word[1].aval & UINT32_C(0xff)) !=
                    ((high & UINT32_C(0xff)) & ~zmask) ||
                ((uint32_t)logic_word[1].bval & UINT32_C(0xff)) != zmask)
                  bad |= E_PACKED_LOGIC;

            scalar_bits[slot] = (svBit)((slot & 1) ^ 1);
            scalar_logic[slot] = logic_output[slot];
            atoms[slot] = -2000 + slot * 31;
            packed_bits[slot * 2] =
                  UINT32_C(0xa0000000) + (uint32_t)slot;
            packed_bits[slot * 2 + 1] =
                  UINT32_C(0x40) + (uint32_t)slot;

            low = UINT32_C(0xb0000000) + (uint32_t)slot;
            high = UINT32_C(0x60) + (uint32_t)slot;
            xmask = UINT32_C(1) << ((slot + 3) % 32);
            zmask = UINT32_C(1) << ((slot + 2) % 8);
            packed_logic[slot * 2].aval = low | xmask;
            packed_logic[slot * 2].bval = xmask;
            packed_logic[slot * 2 + 1].aval = high & ~zmask;
            packed_logic[slot * 2 + 1].bval = zmask;
      }

      /* Keep this helper live so a compiler warns if svLogic constants and
       * canonical vector encoding diverge in the test itself. */
      if (decode_logic(&packed_logic[0], UINT32_C(1) << 3) != sv_x)
            bad |= E_PACKED_LOGIC;

      *status = bad;
}
