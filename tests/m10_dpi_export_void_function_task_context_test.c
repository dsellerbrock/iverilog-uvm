#include "svdpi.h"

#include <string.h>

extern void sv_void_copyout(int addend, float *out_shortreal,
                            int *inout_value, svLogic *out_logic,
                            const char **out_string,
                            const char **inout_string);

int c_check_void_export(int *failures)
{
      int count = 0;
      float out_shortreal;
      int inout_value = 10;
      svLogic out_logic;
      const char *out_string;
      const char *inout_string = "seed";

      sv_void_copyout(5, &out_shortreal, &inout_value, &out_logic,
                      &out_string, &inout_string);
      if (out_shortreal != 2.5f)
            count += 1;
      if (inout_value != 15)
            count += 1;
      if (out_logic != sv_z)
            count += 1;
      if (out_string == 0 || strcmp(out_string, "out:sv") != 0)
            count += 1;
      if (inout_string == 0 || strcmp(inout_string, "seed:sv") != 0)
            count += 1;

      *failures = count;
      return 0;
}
