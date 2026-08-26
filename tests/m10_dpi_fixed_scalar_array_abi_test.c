#include "svdpi.h"

#include <stdint.h>

enum {
      E_INPUT_BIT     = 1 << 0,
      E_INPUT_LOGIC   = 1 << 1,
      E_INOUT_BIT     = 1 << 2,
      E_INOUT_LOGIC   = 1 << 3,
      E_PACKED_BIT    = 1 << 4,
      E_PACKED_LOGIC  = 1 << 5
};

void c_mutate_fixed_scalar_arrays(const svBit in_bits[4],
                                  const svLogic in_logic[4],
                                  svBit io_bits[4], svLogic io_logic[4],
                                  svBit out_bits[4], svLogic out_logic[4],
                                  svBitVecVal packed_bits[4],
                                  svLogicVecVal packed_logic[4],
                                  int32_t*status)
{
      static const svBit expected_in_bits[4] = {sv_0, sv_1, sv_1, sv_0};
      static const svLogic expected_in_logic[4] = {sv_0, sv_1, sv_z, sv_x};
      static const svBit expected_io_bits[4] = {sv_1, sv_0, sv_1, sv_0};
      static const svLogic expected_io_logic[4] = {sv_x, sv_z, sv_1, sv_0};
      static const uint32_t expected_packed_bits[4] = {0, 1, 0, 1};
      static const svLogic expected_packed_logic[4] = {sv_0, sv_1, sv_z, sv_x};
      int bad = 0;
      int idx;

      for (idx = 0; idx < 4; idx += 1) {
            svLogic got;
            if (in_bits[idx] != expected_in_bits[idx]) bad |= E_INPUT_BIT;
            if (in_logic[idx] != expected_in_logic[idx]) bad |= E_INPUT_LOGIC;
            if (io_bits[idx] != expected_io_bits[idx]) bad |= E_INOUT_BIT;
            if (io_logic[idx] != expected_io_logic[idx]) bad |= E_INOUT_LOGIC;

            /* Explicit packed [0:0] elements occupy canonical vector words,
             * not the one-byte scalar representation used above. */
            if ((packed_bits[idx] & 1u) != expected_packed_bits[idx])
                  bad |= E_PACKED_BIT;
            got = (packed_logic[idx].bval & 1u)
                    ? ((packed_logic[idx].aval & 1u) ? sv_x : sv_z)
                    : ((packed_logic[idx].aval & 1u) ? sv_1 : sv_0);
            if (got != expected_packed_logic[idx]) bad |= E_PACKED_LOGIC;
      }

      {
            static const svBit io_bit_result[4] = {sv_0, sv_1, sv_0, sv_1};
            static const svLogic io_logic_result[4] = {sv_1, sv_x, sv_z, sv_0};
            static const svBit out_bit_result[4] = {sv_1, sv_1, sv_0, sv_0};
            static const svLogic out_logic_result[4] = {sv_z, sv_x, sv_0, sv_1};
            static const svBit packed_bit_result[4] = {sv_1, sv_1, sv_0, sv_0};
            static const svLogic packed_logic_result[4] = {sv_x, sv_z, sv_1, sv_0};

            for (idx = 0; idx < 4; idx += 1) {
                  svLogic value = packed_logic_result[idx];
                  io_bits[idx] = io_bit_result[idx];
                  io_logic[idx] = io_logic_result[idx];
                  out_bits[idx] = out_bit_result[idx];
                  out_logic[idx] = out_logic_result[idx];
                  packed_bits[idx] = packed_bit_result[idx];
                  packed_logic[idx].aval = (value == sv_1 || value == sv_x);
                  packed_logic[idx].bval = (value == sv_z || value == sv_x);
            }
      }

      *status = bad;
}
