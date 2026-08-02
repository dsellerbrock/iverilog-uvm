#include <stdint.h>

typedef uint32_t svBitVecVal;

extern int simutil_get_scramble_key(svBitVecVal* val);

int run_generate_export_test(void)
{
      svBitVecVal val[4] = {0, 0, 0, 0};
      int status = simutil_get_scramble_key(val);
      return status != 7
          || val[0] != UINT32_C(0x76543210)
          || val[1] != UINT32_C(0xfedcba98)
          || val[2] != UINT32_C(0x89abcdef)
          || val[3] != UINT32_C(0x01234567);
}
