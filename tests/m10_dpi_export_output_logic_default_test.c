#include "svdpi.h"

#include <stdio.h>

extern svLogic sv_output_logic_default(svLogic *untouched,
                                       svLogic *observed);

int c_check_output_logic_default(void)
{
      svLogic untouched = sv_1;
      svLogic observed = sv_z;
      svLogic result = sv_output_logic_default(&untouched, &observed);

      printf("  scalar output defaults: untouched=%d observed=%d result=%d\n",
             (int)untouched, (int)observed, (int)result);
      return untouched == sv_x && observed == sv_x && result == sv_x ? 0 : 1;
}
