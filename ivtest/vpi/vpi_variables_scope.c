#include <string.h>
#include <vpi_user.h>

static int collect_names(vpiHandle iterator, int *found_v, int *found_y)
{
      vpiHandle item;
      int count = 0;

      while (iterator && (item = vpi_scan(iterator))) {
            const char *name = vpi_get_str(vpiName, item);
            if (name && strcmp(name, "v") == 0)
                  *found_v = 1;
            else if (name && strcmp(name, "y") == 0)
                  *found_y = 1;
            else {
                  vpi_printf("FAIL unexpected variable name %s\n",
                             name ? name : "<null>");
                  return -1;
            }
            count++;
      }
      return count;
}

static PLI_INT32 check_variables(PLI_BYTE8 *userdata)
{
      vpiHandle call, scope, iterator;
      int found_v = 0, found_y = 0, count;
      (void)userdata;

      call = vpi_handle(vpiSysTfCall, 0);
      scope = vpi_handle(vpiScope, call);
      iterator = vpi_iterate(vpiVariables, scope);
      count = collect_names(iterator, &found_v, &found_y);
      if (count != 2 || !found_v || !found_y) {
            vpi_printf("FAIL vpiVariables count=%d v=%d y=%d\n",
                       count, found_v, found_y);
            return 0;
      }

      found_v = found_y = 0;
      iterator = vpi_iterate(vpiReg, scope);
      count = collect_names(iterator, &found_v, &found_y);
      if (count != 2 || !found_v || !found_y) {
            vpi_printf("FAIL vpiReg count=%d v=%d y=%d\n",
                       count, found_v, found_y);
            return 0;
      }

      vpi_printf("PASS vpiVariables includes v and variable port y\n");
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
