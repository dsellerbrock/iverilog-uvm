#include "svdpi.h"

#include <string.h>

int c_svdpi_bitsel_selfcheck(void)
{
      const int indices[] = {0, 1, 30, 31, 32, 33, 62, 63, 64, 95};
      const svBitVecVal initial[] = {0xa5a55a5au, 0x12345678u, 0xf0f00f0fu};
      for (unsigned n = 0; n < sizeof(indices) / sizeof(indices[0]); ++n) {
            svBitVecVal bits[3];
            const int i = indices[n];
            const svBitVecVal mask = (svBitVecVal)1u << (i % 32);
            const svBit old_bit = (initial[i / 32] & mask) != 0;
            memcpy(bits, initial, sizeof(bits));
            if (svGetBitselBit(bits, i) != old_bit) return 1;
            svPutBitselBit(bits, i, old_bit ^ 1u);
            if (svGetBitselBit(bits, i) != (old_bit ^ 1u)) return 2;
            for (int word = 0; word < 3; ++word) {
                  const svBitVecVal expected = word == i / 32
                        ? initial[word] ^ mask : initial[word];
                  if (bits[word] != expected) return 3;
            }
            svPutBitselBit(bits, i, old_bit);
            if (memcmp(bits, initial, sizeof(bits)) != 0) return 4;
      }
      return 0;
}
