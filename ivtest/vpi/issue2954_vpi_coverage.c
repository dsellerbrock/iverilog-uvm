#include <string.h>
#include "vpi_user.h"

#define IEEE_vpiFsmStateCoverage 761
#define IEEE_vpiStatementCoverage 762
#define IEEE_vpiToggleCoverage 763

static PLI_INT32 probe(PLI_BYTE8 *ud)
{
      static const int props[] = { IEEE_vpiFsmStateCoverage,
            IEEE_vpiStatementCoverage, IEEE_vpiToggleCoverage };
      static const char *names[] = { "top", "top.u" };
      unsigned i, k;
      int failed = 0;
      (void)ud;
      for (i = 0; i < sizeof names / sizeof names[0]; i++) {
            vpiHandle instance = vpi_handle_by_name((PLI_BYTE8*)names[i], 0);
            if (!instance) {
                  vpi_printf("missing instance %s\n", names[i]);
                  failed = 1;
                  continue;
            }
            for (k = 0; k < sizeof props / sizeof props[0]; k++) {
                  s_vpi_error_info info;
                  int value = vpi_get(props[k], instance);
                  int error = vpi_chk_error(&info);
                  if (value != 0 || error != 0) failed = 1;
                  vpi_printf("%s prop=%d value=%d chk_error=%d\n",
                             names[i], props[k], value, error);
            }
      }
      if (!failed) vpi_printf("PASSED\n");
      return 0;
}

static void reg(void)
{
      s_vpi_systf_data d;
      memset(&d, 0, sizeof d);
      d.type = vpiSysTask;
      d.tfname = (PLI_BYTE8*)"$probe";
      d.calltf = probe;
      vpi_register_systf(&d);
}

void (*vlog_startup_routines[])(void) = { reg, 0 };
