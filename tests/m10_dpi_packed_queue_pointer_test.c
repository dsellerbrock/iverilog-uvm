#include "svdpi.h"

#include <stdint.h>

int check_queue_bytes(const svOpenArrayHandle data)
{
      static const uint8_t expected[3] = {0x12, 0xa5, 0x5a};
      if (svDimensions(data) != 1 || svSize(data, 1) != 3 ||
          svLow(data, 1) != 0 || svHigh(data, 1) != 2)
            return 1;
      if (svGetArrayPtr(data) || svSizeOfArray(data) != 0)
            return 2;
      if (svGetArrElemPtr1(data, -1) || svGetArrElemPtr1(data, 3))
            return 3;

      for (int idx = 0; idx < 3; idx += 1) {
            const svBitVecVal*word =
                  (const svBitVecVal*)svGetArrElemPtr1(data, idx);
            if (!word || ((*word & 0xffu) != expected[idx]))
                  return 20 + idx;
      }
      return 0;
}

int mutate_queue_bytes(const svOpenArrayHandle data)
{
      svBitVecVal*word = (svBitVecVal*)svGetArrElemPtr1(data, 1);
      if (!word)
            return 1;
      *word = 0x3cu;

      svBitVecVal value = 0xe1u;
      svPutBitArrElem1VecVal(data, &value, 0);
      value = 0;
      svGetBitArrElem1VecVal(&value, data, 1);
      if ((value & 0xffu) != 0x3cu)
            return 2;
      value = 0xe2u;
      svPutBitArrElem1VecVal(data, &value, 2);
      return 0;
}

int mutate_queue_wide(const svOpenArrayHandle data)
{
      if (svGetArrayPtr(data) || svSizeOfArray(data) != 0 ||
          svSize(data, 1) != 2)
            return 1;
      svBitVecVal*first = (svBitVecVal*)svGetArrElemPtr1(data, 0);
      if (!first || first[0] != 0x3456789au || (first[1] & 0xffu) != 0x12u)
            return 2;
      first[0] = 0x89abcdefu;
      first[1] = 0x55u;

      svBitVecVal value[2] = {0, 0};
      svGetBitArrElem1VecVal(value, data, 0);
      if (value[0] != 0x89abcdefu || (value[1] & 0xffu) != 0x55u)
            return 3;
      value[0] = 0x01234567u;
      value[1] = 0xaau;
      svPutBitArrElem1VecVal(data, value, 1);
      return 0;
}

int mutate_queue_logic(const svOpenArrayHandle data)
{
      if (svGetArrayPtr(data) || svSizeOfArray(data) != 0 ||
          svSize(data, 1) != 1)
            return 1;
      svLogicVecVal*word = (svLogicVecVal*)svGetArrElemPtr1(data, 0);
      if (!word || ((uint32_t)word[0].aval & 0xfu) != 0xcu ||
          ((uint32_t)word[0].bval & 0xfu) != 0x6u)
            return 2;
      word[0].aval = 0x5u;
      word[0].bval = 0x6u;

      svLogicVecVal value = {0, 0};
      svGetLogicArrElem1VecVal(&value, data, 0);
      if (((uint32_t)value.aval & 0xfu) != 0x5u ||
          ((uint32_t)value.bval & 0xfu) != 0x6u)
            return 3;
      return 0;
}
