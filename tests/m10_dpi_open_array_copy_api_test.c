#include "svdpi.h"

#include <stdint.h>

enum {
      E_GEOMETRY = 1 << 0,
      E_BIT      = 1 << 1,
      E_LOGIC    = 1 << 2,
      E_BYTE     = 1 << 3,
      E_WIDE     = 1 << 4,
      E_LOGVEC   = 1 << 5,
      E_MATRIX   = 1 << 6
};

int c_dpi_open_array_copy_api(const svOpenArrayHandle bits,
                              const svOpenArrayHandle logic_bits,
                              const svOpenArrayHandle bytes,
                              const svOpenArrayHandle wide,
                              const svOpenArrayHandle logic_words,
                              const svOpenArrayHandle matrix)
{
      int bad = 0;
      svBitVecVal bit_value[2] = {0, 0};
      svLogicVecVal logic_value[2] = {{0, 0}, {0, 0}};

      if (svDimensions(bits) != 1 || svDimensions(matrix) != 2 ||
          svSize(wide, 1) != 1 || svSize(matrix, 2) != 2)
            bad |= E_GEOMETRY;

      if (svGetBitArrElem1(bits, 0) != sv_0 ||
          svGetBitArrElem(bits, 1) != sv_1)
            bad |= E_BIT;
      svPutBitArrElem1(bits, sv_1, 0);
      svPutBitArrElem(bits, sv_0, 1);

      if (svGetLogicArrElem1(logic_bits, 0) != sv_z ||
          svGetLogicArrElem(logic_bits, 1) != sv_x)
            bad |= E_LOGIC;
      svPutLogicArrElem1(logic_bits, sv_x, 0);
      svPutLogicArrElem(logic_bits, sv_z, 1);

      svGetBitArrElem1VecVal(bit_value, bytes, 0);
      if ((bit_value[0] & 0xffu) != 0x12u) bad |= E_BYTE;
      bit_value[0] = 0xa5u;
      svPutBitArrElem1VecVal(bytes, bit_value, 1);
      bit_value[0] = 0;
      svGetBitArrElemVecVal(bit_value, bytes, 2);
      if ((bit_value[0] & 0xffu) != 0x56u) bad |= E_BYTE;
      bit_value[0] = 0x5au;
      svPutBitArrElemVecVal(bytes, bit_value, 2);

      bit_value[0] = bit_value[1] = 0;
      svGetBitArrElem1VecVal(bit_value, wide, 0);
      if (bit_value[0] != 0x3456789au || (bit_value[1] & 0xffu) != 0x12u)
            bad |= E_WIDE;
      bit_value[0] = 0x89abcdefu;
      bit_value[1] = 0x55u;
      svPutBitArrElem1VecVal(wide, bit_value, 0);

      svGetLogicArrElem1VecVal(logic_value, logic_words, 0);
      if (((uint32_t)logic_value[0].aval & 0xfu) != 0xcu ||
          ((uint32_t)logic_value[0].bval & 0xfu) != 0x6u)
            bad |= E_LOGVEC;
      logic_value[0].aval = 0x5u;
      logic_value[0].bval = 0x6u;
      svPutLogicArrElem1VecVal(logic_words, logic_value, 0);

      bit_value[0] = 0;
      svGetBitArrElem2VecVal(bit_value, matrix, 1, 0);
      if ((bit_value[0] & 0xffu) != 0x41u) bad |= E_MATRIX;
      bit_value[0] = 0xe1u;
      svPutBitArrElem2VecVal(matrix, bit_value, 0, 0);
      bit_value[0] = 0xe2u;
      svPutBitArrElemVecVal(matrix, bit_value, 1, 1);

      return bad;
}
