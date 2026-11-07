#include <stdio.h>
#include <string.h>
#include <vpi_user.h>

#ifndef vpiTypespec
# define vpiTypespec 605
#endif
#ifndef vpiTypeParameter
# define vpiTypeParameter 609
#endif
#ifndef vpiBitTypespec
# define vpiBitTypespec 640
#endif

static PLI_INT32 probe(p_cb_data cb)
{
      (void)cb;
      vpiHandle u = vpi_handle_by_name((PLI_BYTE8*)"top.u", NULL);
      vpiHandle it = u ? vpi_iterate(vpiTypeParameter, u) : NULL;
      vpiHandle param = it ? vpi_scan(it) : NULL;
      vpiHandle extra = it ? vpi_scan(it) : NULL;
      vpiHandle named = vpi_handle_by_name((PLI_BYTE8*)"top.u.T", NULL);
      vpiHandle type = param ? vpi_handle(vpiTypespec, param) : NULL;
      if (u && param && !extra && named == param
          && vpi_get(vpiType, param) == vpiTypeParameter
          && strcmp(vpi_get_str(vpiName, param), "T") == 0
          && type && vpi_get(vpiType, type) == vpiBitTypespec) {
            vpi_printf("PASSED\n");
            vpi_printf("type parameter T exposes its effective bit typespec\n");
      } else {
            vpi_printf("FAIL: type parameter VPI handle/typespec missing\n");
            vpi_control(vpiFinish, 1);
      }
      return 0;
}

static void startup(void)
{
      s_cb_data cb = {0};
      cb.reason = cbStartOfSimulation;
      cb.cb_rtn = probe;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
