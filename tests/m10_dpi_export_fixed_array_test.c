#include "svdpi.h"

#include <stdio.h>
#include <stdint.h>

extern int32_t sv_mutate_fixed_arrays(const int32_t input_values[2],
                                      int32_t inout_values[2],
                                      int32_t output_values[2],
                                      svLogicVecVal packed_values[2]);

int c_check_export_arrays(void)
{
      const int32_t input_values[2] = {11, -12};
      int32_t inout_values[2] = {21, -22};
      int32_t output_values[2] = {0, 0};
      svLogicVecVal packed_values[2] = {{0x12, 0}, {0x34, 0}};
      int32_t result;

      result = sv_mutate_fixed_arrays(input_values, inout_values,
                                      output_values, packed_values);
      if (result != 0 || inout_values[0] != 31 || inout_values[1] != -32
          || output_values[0] != 41 || output_values[1] != -42
          || packed_values[0].aval != 0xf3 || packed_values[0].bval != 0xf0
          || packed_values[1].aval != 0x05 || packed_values[1].bval != 0xf0) {
            printf("export fixed arrays: result=%d inout=%d,%d output=%d,%d "
                   "packed=%08x/%08x,%08x/%08x\n", result,
                   inout_values[0], inout_values[1], output_values[0],
                   output_values[1], packed_values[0].aval,
                   packed_values[0].bval, packed_values[1].aval,
                   packed_values[1].bval);
            return 1;
      }
      return 0;
}
