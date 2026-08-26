#include "svdpi.h"

#include <stdint.h>

enum {
      E_BIT_INPUT    = 1 << 0,
      E_LOGIC_INPUT  = 1 << 1
};

static int same_logic_word(const svLogicVecVal*word,
                           uint32_t aval, uint32_t bval)
{
      return (uint32_t)word->aval == aval && (uint32_t)word->bval == bval;
}

void c_mutate_fixed_wide_elements(svBitVecVal bit_data[16],
                                  svLogicVecVal logic_data[24],
                                  int32_t*status)
{
      svLogicVecVal expected[24] = {{0, 0}};
      int bad = 0;
      int elem;
      int word;

      for (elem = 0; elem < 2; elem += 1) {
            for (word = 0; word < 8; word += 1) {
                  uint32_t value = UINT32_C(0x10000000) +
                                   (uint32_t)elem * UINT32_C(0x00010000) +
                                   (uint32_t)word;
                  if ((uint32_t)bit_data[elem * 8 + word] != value)
                        bad |= E_BIT_INPUT;
            }
      }

      expected[0].aval = UINT32_C(0x00000001);
      expected[3].aval = UINT32_C(0x80000000);
      expected[3].bval = UINT32_C(0x80000000);
      expected[7].bval = UINT32_C(0x80000000);
      expected[11].aval = UINT32_C(0x80000000);
      expected[12].bval = UINT32_C(0x80000000);
      expected[18].aval = UINT32_C(0x00000001);
      expected[18].bval = UINT32_C(0x00000001);
      expected[21].aval = UINT32_C(0x00001000);
      for (word = 0; word < 24; word += 1) {
            if (!same_logic_word(&logic_data[word], expected[word].aval,
                                 expected[word].bval))
                  bad |= E_LOGIC_INPUT;
      }

      for (elem = 0; elem < 2; elem += 1) {
            for (word = 0; word < 8; word += 1) {
                  bit_data[elem * 8 + word] = UINT32_C(0xa0000000) +
                                              (uint32_t)elem *
                                                UINT32_C(0x00010000) +
                                              (uint32_t)word;
            }
      }

      for (word = 0; word < 24; word += 1) {
            logic_data[word].aval = 0;
            logic_data[word].bval = 0;
      }
      logic_data[0].aval = UINT32_C(0x00000004);
      logic_data[0].bval = UINT32_C(0x00000004);
      logic_data[5].bval = UINT32_C(0x80000000);
      logic_data[11].aval = UINT32_C(0x40000000);
      logic_data[12].bval = UINT32_C(0x00000001);
      logic_data[16].aval = UINT32_C(0x00000002);
      logic_data[16].bval = UINT32_C(0x00000002);
      logic_data[23].aval = UINT32_C(0x80000000);

      *status = bad;
}
