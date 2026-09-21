#include <stdio.h>
#include "sv_vpi_user.h"

static PLI_INT32 check(char *unused)
{
  (void)unused;
  vpiHandle prefix = vpi_handle_by_name("forward_net.sum[1]", 0);
  s_vpi_value value = {vpiIntVal, {0}};
  if (!prefix || vpi_get(vpiSize, prefix) != 4) {
    vpi_printf("FORWARD_NET FAIL missing prefix\n");
    vpi_sim_control(vpiFinish, 1);
    return 0;
  }
  vpi_get_value(prefix, &value);
  if (value.value.integer != 3) {
    vpi_printf("FORWARD_NET FAIL value=%d\n", value.value.integer);
    vpi_sim_control(vpiFinish, 1);
    return 0;
  }
  vpi_printf("FORWARD_NET PASS value=%d\n", value.value.integer);
  return 0;
}

static void reg(void)
{
  s_vpi_systf_data tf = {vpiSysTask, 0, "$forward_net_check", check, 0, 0, 0};
  vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {reg, 0};
