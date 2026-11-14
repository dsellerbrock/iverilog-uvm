#include <string.h>
#include "vpi_user.h"

static int errors;

static void check_reference(vpiHandle it, vpiHandle expected, const char *label)
{
      vpiHandle actual;
      if (!it) {
            vpi_printf("FAIL: missing %s iterator\n", label);
            ++errors;
            return;
      }
      actual = vpi_handle(vpiUse, it);
      if (expected ? (!actual || !vpi_compare_objects(actual, expected)) : actual != 0) {
            vpi_printf("FAIL: wrong %s iterator reference\n", label);
            ++errors;
      }
}

static PLI_INT32 inspect(PLI_BYTE8 *user_data)
{
      vpiHandle mod = vpi_handle_by_name((PLI_BYTE8 *)"top.c", 0);
      vpiHandle top = vpi_handle_by_name((PLI_BYTE8 *)"top", 0);
      vpiHandle ports = mod ? vpi_iterate(vpiPort, mod) : 0;
      vpiHandle children = top ? vpi_iterate(vpiModule, top) : 0;
      vpiHandle roots = vpi_iterate(vpiModule, 0);
      int count = 0;
      (void)user_data;

      check_reference(ports, mod, "port");
      check_reference(children, top, "child");
      check_reference(roots, 0, "root");
      if (ports && vpi_scan(ports)) ++count;
      if (ports) check_reference(ports, mod, "partially scanned port");
      while (ports && vpi_scan(ports)) ++count;
      if (count != 2) {
            vpi_printf("FAIL: expected two ports, got %d\n", count);
            ++errors;
      }
      if (children) vpi_free_object(children);
      if (roots) vpi_free_object(roots);
      vpi_printf(errors ? "FAILED\n" : "PASSED\n");
      return 0;
}

static void register_inspect(void)
{
      s_vpi_systf_data data;
      memset(&data, 0, sizeof data);
      data.type = vpiSysTask;
      data.tfname = (PLI_BYTE8 *)"$inspect_iterator";
      data.calltf = inspect;
      vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_inspect, 0 };
