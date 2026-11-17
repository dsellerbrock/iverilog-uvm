/*
 * IEEE 1800-2023 36.12: the same design seen through four VPI
 * compatibility modes. Table 36-10 rows 1-7 decide what each mode reports.
 */
#include "vpi_user.h"

extern void issue1254_probe_1364v1995(void);
extern void issue1254_probe_1364v2001(void);
extern void issue1254_probe_1364v2005(void);
extern void issue1254_probe_1800v2023(void);

static PLI_INT32 probe_calltf(PLI_BYTE8*user_data)
{
      (void)user_data;
      issue1254_probe_1364v1995();
      issue1254_probe_1364v2001();
      issue1254_probe_1364v2005();
      issue1254_probe_1800v2023();
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf = { vpiSysTask, 0, "$probe_modes", probe_calltf,
                              0, 0, 0 };
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
