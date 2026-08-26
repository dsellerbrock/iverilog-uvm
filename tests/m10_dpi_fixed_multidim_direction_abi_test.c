#include <stdint.h>

void c_mutate_fixed_multidim_direction(int32_t values[6], int32_t*status)
{
      /* C slots are the FORMAL's canonical order:
       *   [4][-1], [4][0], [4][1], [5][-1], [5][0], [5][1].
       * Copy-in maps those to caller actuals by declared position, yielding
       *   [11][7], [11][6], [11][5], [10][7], [10][6], [10][5]. */
      static const int32_t expected[6] = {
            1107, 1106, 1105, 1007, 1006, 1005
      };
      int bad = 0;
      int slot;

      for (slot = 0; slot < 6; slot += 1) {
            if (values[slot] != expected[slot])
                  bad |= 1;
            values[slot] = INT32_C(0x00005000) + slot;
      }
      *status = bad;
}
