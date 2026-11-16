#include <string.h>
#include "vpi_user.h"

static PLI_INT32 probe(PLI_BYTE8 *unused)
{
      static const unsigned expected[3][3] = {{2000,4000,2000}, {5000,5000,5000}, {0,0,0}};
      vpiHandle top = vpi_handle_by_name((PLI_BYTE8*)"top", 0);
      vpiHandle iter = vpi_iterate(vpiContAssign, top), ca;
      unsigned seen = 0, failures = 0;
      (void)unused;
      while (iter && (ca = vpi_scan(iter))) {
            int line = vpi_get(vpiLineNo, ca);
            int row = line - 5;
            int count, i;
            if (row < 0 || row > 2 || (seen & (1u << row))) {
                  vpi_printf("unexpected assignment line %d\n", line);
                  failures++;
                  continue;
            }
            seen |= 1u << row;
            for (count = 1; count <= 3; count++) {
                  s_vpi_time t[4];
                  s_vpi_delay d;
                  memset(t, 0, sizeof t);
                  for (i = 0; i < 4; i++) { t[i].low = 999; t[i].real = -999.0; }
                  memset(&d, 0, sizeof d);
                  d.da = t; d.no_of_delays = count; d.time_type = vpiSimTime;
                  vpi_get_delays(ca, &d);
                  for (i = 0; i < count; i++)
                        if (t[i].high != 0 || t[i].low != expected[row][i]) failures++;
                  if (t[count].low != 999) failures++;
                  d.time_type = vpiScaledRealTime;
                  vpi_get_delays(ca, &d);
                  for (i = 0; i < count; i++)
                        if (t[i].real != expected[row][i] / 1000.0) failures++;
                  if (t[count].real != -999.0) failures++;
            }
      }
      if (seen != 7 || failures)
            vpi_printf("VPI CONTASSIGN DELAY FAIL seen=%u failures=%u\n", seen, failures);
      else
            vpi_printf("VPI CONTASSIGN DELAY PASSED\nPASSED\n");
      return 0;
}
static void reg(void)
{
      s_vpi_systf_data d;
      memset(&d, 0, sizeof d);
      d.type = vpiSysTask; d.tfname = (PLI_BYTE8*)"$probe_delays"; d.calltf = probe;
      vpi_register_systf(&d);
}
void (*vlog_startup_routines[])(void) = {reg, 0};
