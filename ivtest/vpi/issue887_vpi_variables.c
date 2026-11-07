#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

static PLI_INT32 check_variables(PLI_BYTE8 *userdata)
{
      static const char *expected[] = { "v", "r", "i", "mem", "y" };
      int seen[5] = { 0, 0, 0, 0, 0 };
      int count = 0, bad = 0;
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle scope = vpi_handle(vpiScope, call);
      vpiHandle iter = vpi_iterate(vpiVariables, scope);
      vpiHandle item;
      (void)userdata;

      while (iter && (item = vpi_scan(iter))) {
            const char *name = vpi_get_str(vpiName, item);
            int idx, found = 0;
            for (idx = 0; idx < 5; idx += 1)
                  if (name && strcmp(name, expected[idx]) == 0) {
                        seen[idx] += 1;
                        found = 1;
                  }
            if (!found) {
                  vpi_printf("FAIL unexpected variable %s\n",
                             name ? name : "<null>");
                  bad = 1;
            }
            count += 1;
      }
      for (int idx = 0; idx < 5; idx += 1)
            if (seen[idx] != 1) {
                  vpi_printf("FAIL %s seen %d times\n", expected[idx], seen[idx]);
                  bad = 1;
            }
      if (!bad && count == 5)
            vpi_printf("PASSED\n");
      else
            vpi_printf("FAIL vpiVariables count=%d\n", count);
      return 0;
}

static void register_check(void)
{
      s_vpi_systf_data task = {0};
      task.type = vpiSysTask;
      task.tfname = "$check_vpi_variables";
      task.calltf = check_variables;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
