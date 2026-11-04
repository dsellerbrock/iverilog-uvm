#include <stdio.h>
#include <string.h>
#include <vpi_user.h>

#ifndef vpiImport
#define vpiImport 726
#endif

static PLI_INT32 probe_calltf(PLI_BYTE8 *user_data)
{
      vpiHandle top, iter, item, expected;
      unsigned count = 0;
      int used = 0, unused = 0, identity = 0;
      (void)user_data;

      top = vpi_handle_by_name((PLI_BYTE8*)"top", NULL);
      expected = vpi_handle_by_name((PLI_BYTE8*)"pkg::used", NULL);
      iter = top ? vpi_iterate(vpiImport, top) : NULL;
      while (iter && (item = vpi_scan(iter))) {
            char *name = vpi_get_str(vpiName, item);
            count += 1;
            if (name && strcmp(name, "used") == 0) {
                  used += 1;
                  identity = expected && vpi_compare_objects(item, expected);
            } else if (name && strcmp(name, "unused") == 0) {
                  unused += 1;
            }
      }

      int passed = count == 1 && used == 1 && unused == 0 && identity;
      vpi_printf("ISSUE1268 count=%u used=%d unused=%d identity=%d %s\n",
                 count, used, unused, identity, passed ? "PASSED" : "FAILED");
      if (passed) vpi_printf("PASSED\n");
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data data = { vpiSysTask, 0, "$probe", probe_calltf,
                                0, 0, 0 };
      vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
