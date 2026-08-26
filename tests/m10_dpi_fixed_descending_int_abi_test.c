#include <stdint.h>

void c_mutate_descending_ints(int32_t values[8], int32_t*status)
{
      int bad = 0;
      int slot;

      for (slot = 0; slot < 8; slot += 1) {
            int sv_index = slot + 3;
            if (values[slot] != sv_index * 100 + 7)
                  bad |= 1;
            values[slot] = INT32_C(0x00010000) + sv_index * 17;
      }

      *status = bad;
}
