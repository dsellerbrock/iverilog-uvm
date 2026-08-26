#include "svdpi.h"

#include <stdint.h>
#include <string.h>

extern float sv_shortreal(float value, float *out_value,
                          float *inout_value);
extern void *sv_chandle(void *value, void **out_value,
                        void **inout_value);
extern svBit sv_bit(svBit value, svBit *out_value, svBit *inout_value);
extern svLogic sv_logic(svLogic value, svLogic *out_value,
                        svLogic *inout_value);
extern const char *sv_string(const char *value, const char **out_value,
                             const char **inout_value);
extern int sv_bit_vector(const svBitVecVal *value, svBitVecVal *out_value,
                         svBitVecVal *inout_value);
extern int sv_logic_vector(const svLogicVecVal *value,
                           svLogicVecVal *out_value,
                           svLogicVecVal *inout_value);

int c_check_small_exports(void)
{
      int fails = 0;
      float sr_out;
      float sr_inout = 2.0f;
      float sr_result = sv_shortreal(1.25f, &sr_out, &sr_inout);
      if (sr_result != 5.25f || sr_out != -2.5f || sr_inout != 2.5f)
            fails += 1;

      void *token = (void *)(uintptr_t)0x12340u;
      void *ch_out;
      void *ch_inout = (void *)(uintptr_t)0x56780u;
      void *ch_result = sv_chandle(token, &ch_out, &ch_inout);
      if (ch_result != token || ch_out != token || ch_inout != token)
            fails += 1;

      svBit bit_out;
      svBit bit_inout = sv_0;
      svBit bit_result = sv_bit(sv_1, &bit_out, &bit_inout);
      if (bit_result != sv_1 || bit_out != sv_1 || bit_inout != sv_1)
            fails += 1;

      const svLogic logic_values[4] = {sv_0, sv_1, sv_z, sv_x};
      for (unsigned idx = 0; idx < 4; idx += 1) {
            svLogic logic_out;
            svLogic logic_inout = sv_z;
            svLogic logic_result = sv_logic(logic_values[idx], &logic_out,
                                            &logic_inout);
            if (logic_result != logic_values[idx] || logic_out != sv_z ||
                logic_inout != sv_x)
                  fails += 1;
      }

      const char *string_out;
      const char *string_inout = "seed";
      const char *string_result = sv_string("value", &string_out,
                                            &string_inout);
      if (string_result == 0 || strcmp(string_result, "ret:value") != 0 ||
          string_out == 0 || strcmp(string_out, "out:value") != 0 ||
          string_inout == 0 || strcmp(string_inout, "seed:io") != 0)
            fails += 1;

      const svBitVecVal bit_value[3] = {
            UINT32_C(0x13579bdf), UINT32_C(0x2468ace0),
            UINT32_C(0x0badf00d)
      };
      svBitVecVal bit_out[3] = {0, 0, 0};
      svBitVecVal bit_inout[3] = {
            UINT32_C(0xffffffff), UINT32_C(0xaaaaaaaa),
            UINT32_C(0x55555555)
      };
      const svBitVecVal expected_bit_out[3] = {
            UINT32_C(0xfedcba98), UINT32_C(0x89abcdef),
            UINT32_C(0x01234567)
      };
      const svBitVecVal expected_bit_inout[3] = {
            UINT32_C(0xeca86420), UINT32_C(0x8ec2064a),
            UINT32_C(0x5ef8a558)
      };
      int bit_vector_result = sv_bit_vector(bit_value, bit_out, bit_inout);
      if (bit_vector_result != 17 ||
          memcmp(bit_out, expected_bit_out, sizeof bit_out) != 0 ||
          memcmp(bit_inout, expected_bit_inout, sizeof bit_inout) != 0)
            fails += 1;

      const svLogicVecVal logic_value[3] = {
            {UINT32_C(0x89abcdef), UINT32_C(0x0f0f0f0f)},
            {UINT32_C(0x13579bdf), UINT32_C(0x33333333)},
            {UINT32_C(0x00000002), UINT32_C(0x00000001)}
      };
      svLogicVecVal logic_out[3] = {{0, 0}, {0, 0}, {0, 0}};
      svLogicVecVal logic_inout[3] = {
            {UINT32_C(0xffffffff), 0},
            {UINT32_C(0xffffffff), 0},
            {UINT32_C(0x00000003), 0}
      };
      int logic_vector_result = sv_logic_vector(logic_value, logic_out,
                                                logic_inout);
      if (logic_vector_result != 23 ||
          memcmp(logic_out, logic_value, sizeof logic_out) != 0 ||
          memcmp(logic_inout, logic_value, sizeof logic_inout) != 0)
            fails += 1;

      return fails;
}
